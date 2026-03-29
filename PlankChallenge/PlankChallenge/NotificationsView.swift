//
//  NotificationsView.swift
//  PlankChallenge
//
//  Created by Leo Bacevicius on 08/03/2026.
//

import SwiftUI

struct NotificationsView: View {
    @Environment(\.notificationService) private var notificationService
    @Environment(\.groupService) private var groupService
    
    @State private var isMarkingAllRead = false
    @State private var isLoadingMore = false
    @State private var joinRequestActionError: String?
    @State private var showingJoinRequestError = false
    @State private var navigatingToUserId: String? = nil
    @State private var navigatingToGroupId: String? = nil
    
    var body: some View {
        Group {
            if notificationService.isLoading && !notificationService.hasLoaded {
                loadingView
            } else if let error = notificationService.error, !notificationService.hasLoaded {
                ErrorView(error: error) {
                    await fetchNotifications()
                }
            } else if notificationService.notifications.isEmpty {
                emptyState
            } else {
                notificationsList
            }
        }
        .navigationTitle("Notifications")
        .navigationDestination(isPresented: Binding(
            get: { navigatingToUserId != nil },
            set: { if !$0 { navigatingToUserId = nil } }
        )) {
            if let userId = navigatingToUserId {
                UserProfileView(userId: userId)
            }
        }
        .navigationDestination(isPresented: Binding(
            get: { navigatingToGroupId != nil },
            set: { if !$0 { navigatingToGroupId = nil } }
        )) {
            if let groupId = navigatingToGroupId {
                GroupDetailView(groupId: groupId)
            }
        }
        .toolbar {
            if !notificationService.notifications.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    if isMarkingAllRead {
                        ProgressView()
                    } else if notificationService.unreadCount > 0 {
                        Button("Mark all as read") {
                            Task { await markAllAsRead() }
                        }
                        .font(.subheadline)
                        .accessibilityLabel("Mark all notifications as read")
                    }
                }
            }
        }
        .alert("Couldn't process request", isPresented: $showingJoinRequestError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(joinRequestActionError ?? "Something went wrong. Try again.")
        }
        .refreshable {
            await fetchNotifications()
        }
        .task {
            if !notificationService.hasLoaded {
                await fetchNotifications()
            }
        }
    }
    
    // MARK: - Subviews
    
    private var loadingView: some View {
        NotificationsSkeleton()
    }
    
    private var notificationsList: some View {
        List {
            ForEach(notificationService.notifications) { notification in
                notificationRow(for: notification)
                    .onAppear {
                        checkForPagination(notification: notification)
                    }
            }
            
            // Load more indicator at the bottom
            if notificationService.isLoading && notificationService.hasLoaded {
                HStack {
                    Spacer()
                    ProgressView()
                        .accessibilityLabel("Loading more notifications")
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }
        }
    }
    
    private func notificationRow(for notification: APINotification) -> some View {
        let entity = notification.relatedEntity
        
        // "follow" + admin's "new member" notification: relatedEntity.type == "user"
        let navigateToUserId: String? = {
            guard entity?.type == "user" else { return nil }
            guard notification.type == "follow" || notification.type == "group_joined" else { return nil }
            return entity?.id
        }()
        
        // Joiner's approval notification: group_joined with relatedEntity.type == "group"
        let navigateToGroupId: String? = {
            guard notification.type == "group_joined", entity?.type == "group" else { return nil }
            return entity?.id
        }()
        
        if notification.type == "group_join_request" {
            return AnyView(NotificationRow(
                notification: notification,
                onTap: { await markAsRead(id: notification.id) },
                onApprove: { try await handleJoinRequest(notification: notification, approve: true) },
                onDeny: { try await handleJoinRequest(notification: notification, approve: false) }
            ))
        } else if let userId = navigateToUserId {
            return AnyView(NotificationRow(
                notification: notification,
                onTap: {
                    await markAsRead(id: notification.id)
                    navigatingToUserId = userId
                }
            ))
        } else if let groupId = navigateToGroupId {
            return AnyView(NotificationRow(
                notification: notification,
                onTap: {
                    await markAsRead(id: notification.id)
                    navigatingToGroupId = groupId
                }
            ))
        } else {
            return AnyView(NotificationRow(
                notification: notification,
                onTap: { await markAsRead(id: notification.id) }
            ))
        }
    }
    
    /// Checks if we should load more notifications based on which item appeared
    private func checkForPagination(notification: APINotification) {
        let notifications = notificationService.notifications
        guard let index = notifications.firstIndex(where: { $0.id == notification.id }) else { return }
        
        // Load more when the 5th-to-last item appears
        if index >= notifications.count - 5 {
            loadMoreIfNeeded()
        }
    }
    
    private var emptyState: some View {
        EmptyStateView(
            icon: "bell.slash",
            title: "You're all caught up",
            message: "Nothing new right now"
        )
    }
    
    // MARK: - Actions
    
    private func fetchNotifications() async {
        do {
            try await notificationService.fetchNotifications()
        } catch {
            // Error is stored in service
        }
    }
    
    private func markAsRead(id: String) async {
        do {
            try await notificationService.markAsRead(id: id)
        } catch {
            // Silently fail for mark as read
        }
    }
    
    private func markAllAsRead() async {
        isMarkingAllRead = true
        defer { isMarkingAllRead = false }
        
        do {
            try await notificationService.markAllAsRead()
        } catch {
            // Error is stored in service
        }
    }
    
    private func loadMoreIfNeeded() {
        // Prevent multiple simultaneous pagination requests
        guard !isLoadingMore && !notificationService.isLoading else { return }
        
        isLoadingMore = true
        Task {
            defer { isLoadingMore = false }
            do {
                try await notificationService.loadMoreNotifications()
            } catch {
                // Silently fail for pagination
            }
        }
    }
    
    /// Handles approve/deny for a group_join_request notification.
    /// relatedEntity.id carries "groupId:requestId" — split on ':' to get both.
    /// Throws on failure so the row doesn't transition to confirmed state.
    private func handleJoinRequest(notification: APINotification, approve: Bool) async throws {
        guard let entity = notification.relatedEntity else { return }
        
        // Entity id is "groupId:requestId" encoded by the backend
        let parts = entity.id.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return }
        let groupId = parts[0]
        let requestId = parts[1]
        
        do {
            try? await notificationService.markAsRead(id: notification.id)
            
            if approve {
                try await groupService.approveJoinRequest(groupId: groupId, requestId: requestId)
            } else {
                try await groupService.denyJoinRequest(groupId: groupId, requestId: requestId)
            }
            
            // Refresh in background — row already shows confirmed state locally
            try? await notificationService.fetchNotifications()
        } catch {
            joinRequestActionError = error.localizedDescription
            showingJoinRequestError = true
            throw error
        }
    }
}

// MARK: - Notification Row

struct NotificationRow: View {
    let notification: APINotification
    let onTap: () async -> Void
    /// Non-nil only for group_join_request notifications (admin only).
    /// Should throw on failure so the row doesn't transition to confirmed state.
    var onApprove: (() async throws -> Void)? = nil
    var onDeny: (() async throws -> Void)? = nil
    
    enum ActionResult { case approved, denied }
    
    @State private var isActioning = false
    @State private var actionResult: ActionResult? = nil
    
    /// The person's name for avatar display.
    /// For "follow" and "group_joined": relatedEntity is { type: "user" }, title is the name.
    /// For "group_join_request": relatedEntity is { type: "group" }, but actorImageUrl is set
    /// and title is the requester's name.
    /// Returns a display name used to drive the AvatarView slot.
    /// Non-nil = show AvatarView (with actorImageUrl if available, initials fallback).
    /// nil     = show the system SF Symbol icon instead.
    private var personName: String? {
        switch notification.type {
        case "follow":
            // Title is the follower's name; actorImageUrl is their photo
            return notification.title
        case "group_joined":
            // Two sub-cases:
            //   admin's notification: relatedEntity.type == "user" (new member joined)
            //   joiner's notification: relatedEntity.type == "group" (request approved)
            // Both carry actorImageUrl — person photo or group image respectively.
            // title is the person's name or the group's name.
            return notification.title
        case "group_join_request":
            // Title is the requester's name; actorImageUrl is their photo
            return notification.title
        default:
            return nil
        }
    }
    
    // Show action buttons only while no decision has been made yet
    private var hasActions: Bool { (onApprove != nil || onDeny != nil) && actionResult == nil }
    
    var body: some View {
        if hasActions {
            // Action rows: plain HStack — no outer tap gesture so inner Buttons work
            rowContent
        } else {
            // Plain rows (and post-action rows): wrap in Button for tap-to-read
            Button {
                Task { await onTap() }
            } label: {
                rowContent
            }
            .buttonStyle(.plain)
        }
    }
    
    private var rowContent: some View {
        HStack(alignment: .top, spacing: 12) {
            // Avatar for person-based notifications, icon for everything else
            if let name = personName {
                AvatarView(
                    text: name,
                    imageName: Optional<String>.none,
                    imageUrl: notification.actorImageUrl,
                    size: 36
                )
            } else {
                Image(systemName: notification.iconName)
                    .font(.title2)
                    .foregroundStyle(iconColor)
                    .frame(width: 36)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(notification.title)
                    .font(.subheadline)
                    .fontWeight(notification.isRead ? .regular : .semibold)
                    .foregroundStyle(.primary)
                
                Text(notification.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                Text(notification.date.relativeFormatted)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                
                if hasActions {
                    joinRequestActions
                } else if let result = actionResult {
                    // Confirmed state — shown immediately after approve/deny
                    HStack(spacing: 4) {
                        Image(systemName: result == .approved ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(result == .approved ? Color.successColor : Color.errorColor)
                        Text(result == .approved ? "Approved" : "Declined")
                            .font(.caption)
                            .foregroundStyle(result == .approved ? Color.successColor : Color.errorColor)
                    }
                    .padding(.top, 4)
                }
            }
            
            Spacer()
            
            if !notification.isRead {
                Circle()
                    .fill(Color.appAccent)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(notification.title). \(notification.message). \(notification.date.relativeFormatted)")
        .accessibilityHint(notification.isRead ? "Notification is read" : "Tap to mark as read")
    }
    
    @ViewBuilder
    private var joinRequestActions: some View {
        if isActioning {
            HStack {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Processing...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 6)
        } else {
            HStack(spacing: 8) {
                if let onApprove {
                    Button {
                        isActioning = true
                        Task {
                            do {
                                try await onApprove()
                                actionResult = .approved
                            } catch {
                                // error surfaced by the caller via alert
                            }
                            isActioning = false
                        }
                    } label: {
                        Text("Approve")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.successColor, in: Capsule())
                    }
                    .accessibilityLabel("Approve join request")
                }
                
                if let onDeny {
                    Button {
                        isActioning = true
                        Task {
                            do {
                                try await onDeny()
                                actionResult = .denied
                            } catch {
                                // error surfaced by the caller via alert
                            }
                            isActioning = false
                        }
                    } label: {
                        Text("Deny")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.errorColor, in: Capsule())
                    }
                    .accessibilityLabel("Deny join request")
                }
            }
            .padding(.top, 6)
        }
    }
    
    private var iconColor: Color {
        guard let displayType = notification.displayType else {
            return .secondary
        }
        
        switch displayType {
        case .badgeEarned, .tokenEarned:
            return Color.warningColor
        case .streakFreezeUsed:
            return Color.tealAccent
        case .groupJoined, .joinRequestApproved, .promotedToAdmin:
            return Color.successColor
        case .groupRemoved, .groupDeleted, .joinRequestDenied:
            return Color.errorColor
        }
    }
}

#Preview {
    NavigationStack {
        NotificationsView()
            .withMockServices()
    }
}
