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
        .alert("Couldn't process request", isPresented: $showingJoinRequestError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(joinRequestActionError ?? "Something went wrong. Try again.")
        }
        .refreshable {
            // Explicit pull-to-refresh bypasses the isLoading guard — the user
            // intentionally wants fresh data regardless of any in-flight fetch.
            await fetchNotifications(force: true)
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
            // Always show Approve/Decline buttons on join request notifications.
            // We do NOT gate on isRead here because markAllAsRead fires when the
            // admin leaves the tab — hiding buttons on return even though they
            // haven't acted yet. The backend returns a clear error if the request
            // has already been actioned (404), which surfaces via the alert.
            // The NotificationRow itself tracks actionResult locally so buttons
            // disappear immediately after a successful approve/decline within
            // the same session without needing to rely on isRead.
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
        // Wrapped in a ScrollView so .refreshable works — without a scroll
        // container the pull-to-refresh gesture has nowhere to attach.
        ScrollView {
            EmptyStateView(
                icon: "bell.slash",
                title: "You're all caught up",
                message: "Nothing new right now"
            )
        }
    }
    
    // MARK: - Actions
    
    private func fetchNotifications(force: Bool = false) async {
        do {
            try await notificationService.fetchNotifications(force: force)
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
    ///
    /// New format (related_entity_type == "join_request"):
    ///   related_entity_id == "groupId:requestId" — split on ':' to act directly.
    ///
    /// Legacy format (related_entity_type == "group"):
    ///   related_entity_id == groupId only — fetch pending requests and match by
    ///   requester name (notification title) to find the correct requestId.
    ///
    /// Throws on failure so the row stays in pending state.
    private func handleJoinRequest(notification: APINotification, approve: Bool) async throws {
        guard let entity = notification.relatedEntity else {
            throw GroupServiceError.validationError("Notification has no related entity")
        }

        do {
            try? await notificationService.markAsRead(id: notification.id)

            let groupId: String
            let requestId: String

            if entity.type == "join_request" {
                // New format: "groupId:requestId"
                let parts = entity.id.split(separator: ":", maxSplits: 1).map(String.init)
                guard parts.count == 2 else {
                    throw GroupServiceError.validationError("Malformed join_request entity id")
                }
                groupId = parts[0]
                requestId = parts[1]
            } else {
                // Legacy format: entity.id is just the groupId.
                // These notifications predate the "join_request" entity type (introduced
                // when the new-format notifications were deployed). Match by the requester's
                // display name stored in notification.title — do NOT fall back to the first
                // pending request, as that could approve/deny the wrong person.
                groupId = entity.id
                try await groupService.fetchJoinRequests(groupId: groupId)
                let requesterName = notification.title
                guard let match = groupService.currentGroupJoinRequests.first(where: {
                    $0.user?.displayName == requesterName
                }) else {
                    throw GroupServiceError.validationError("Couldn't find a pending request matching this notification. It may have already been actioned.")
                }
                requestId = match.id
            }

            if approve {
                try await groupService.approveJoinRequest(groupId: groupId, requestId: requestId)
            } else {
                try await groupService.denyJoinRequest(groupId: groupId, requestId: requestId)
            }

            // Refresh in background — row already shows confirmed state locally
            try? await notificationService.fetchNotifications(force: false)
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
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .padding(.top, 8)
        } else {
            // .disabled is applied to the whole HStack so both buttons go dead
            // the instant either is tapped — prevents double-tap sending both
            // approve AND deny before SwiftUI re-renders with isActioning = true.
            HStack(spacing: 12) {
                if let onApprove {
                    Button {
                        // Set synchronously — before the Task runs — so the
                        // .disabled modifier takes effect in the same render cycle.
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
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.successColor, in: RoundedRectangle(cornerRadius: 10))
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
                        Text("Decline")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.errorColor)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.errorColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                    }
                    .accessibilityLabel("Decline join request")
                }
            }
            .padding(.top, 10)
            // Disable the entire button group as soon as either button is tapped.
            // This prevents the ~1 render-cycle window where both buttons could
            // receive taps before isActioning = true propagates to the UI.
            .disabled(isActioning)
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
