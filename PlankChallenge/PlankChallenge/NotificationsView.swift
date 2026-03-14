//
//  NotificationsView.swift
//  PlankChallenge
//
//  Created by Leo Bacevicius on 08/03/2026.
//

import SwiftUI

struct NotificationsView: View {
    private var mockData: MockDataService { MockDataService.shared }
    
    var body: some View {
        List {
            if mockData.notifications.isEmpty {
                emptyState
            } else {
                ForEach(mockData.notifications) { notification in
                    NotificationRow(notification: notification)
                }
            }
        }
        .navigationTitle("Notifications")
        .toolbar {
            if !mockData.notifications.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Mark All Read") {
                        // Mark all as read
                    }
                    .font(.subheadline)
                }
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bell.slash")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            
            Text("No notifications")
                .font(.headline)
            
            Text("You're all caught up!")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .listRowBackground(Color.clear)
    }
}

struct NotificationRow: View {
    let notification: MockNotification
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Icon
            Image(systemName: notification.type.iconName)
                .font(.title2)
                .foregroundStyle(iconColor)
                .frame(width: 32)
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(notification.title)
                    .font(.subheadline)
                    .fontWeight(notification.isRead ? .regular : .semibold)
                
                Text(notification.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                
                Text(notification.createdAt.relativeFormatted)
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
    }
    
    private var iconColor: Color {
        switch notification.type {
        case .badgeEarned, .tokenEarned:
            return .yellow
        case .streakFreezeUsed:
            return .cyan
        case .groupJoined, .joinRequestApproved, .promotedToAdmin:
            return .green
        case .groupRemoved, .groupDeleted, .joinRequestDenied:
            return .red
        @unknown default:
            return .gray
        }
    }
}

#Preview {
    NavigationStack {
        NotificationsView()
    }
}
