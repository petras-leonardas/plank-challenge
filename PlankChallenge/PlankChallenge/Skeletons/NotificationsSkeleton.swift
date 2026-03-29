//
//  NotificationsSkeleton.swift
//  PlankChallenge
//

import SwiftUI

// MARK: - Notifications Screen Skeleton

struct NotificationsSkeleton: View {
    var body: some View {
        List {
            ForEach(0..<8, id: \.self) { _ in
                SkeletonNotificationRow()
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .disabled(true)
    }
}

#Preview {
    NavigationStack {
        NotificationsSkeleton()
            .navigationTitle("Notifications")
    }
}
