//
//  NotificationsView.swift
//  PlankChallenge
//
//  Created by Leo Bacevicius on 08/03/2026.
//

import SwiftUI

struct NotificationsView: View {
    @Environment(\.notificationService) private var notificationService
    
    @State private var isMarkingAllRead = false
    @State private var isLoadingMore = false
    
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
        LoadingView("Loading notifications...")
    }
    
    private var notificationsList: some View {
        List {
            ForEach(notificationService.notifications) { notification in
                NotificationRow(notification: notification) {
                    await markAsRead(id: notification.id)
                }
                .onAppear {
                    // Trigger pagination when this notification appears
                    // Check if this is one of the last 5 items
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
}

// MARK: - Notification Row

struct NotificationRow: View {
    let notification: APINotification
    let onTap: () async -> Void
    
    var body: some View {
        Button {
            Task { await onTap() }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                // Icon
                Image(systemName: notification.iconName)
                    .font(.title2)
                    .foregroundStyle(iconColor)
                    .frame(width: 32)
                
                // Content
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
                }
                
                Spacer()
                
                // Unread indicator
                if !notification.isRead {
                    Circle()
                        .fill(Color.appAccent)
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(notification.title). \(notification.message). \(notification.date.relativeFormatted)")
        .accessibilityHint(notification.isRead ? "Notification is read" : "Tap to mark as read")
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
