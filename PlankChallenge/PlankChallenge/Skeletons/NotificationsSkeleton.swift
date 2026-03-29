//
//  NotificationsSkeleton.swift
//  PlankChallenge
//

import SwiftUI

// MARK: - Notifications Screen Skeleton

struct NotificationsSkeleton: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                ForEach(0..<8, id: \.self) { index in
                    SkeletonNotificationRow()
                        .padding(.horizontal)
                    if index < 7 {
                        Divider()
                            .padding(.leading, 56) // matches real notification row indent
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .shimmer()
        .disabled(true)
        .accessibilityLabel("Loading notifications")
    }
}

#Preview {
    NavigationStack {
        NotificationsSkeleton()
            .navigationTitle("Notifications")
    }
}
