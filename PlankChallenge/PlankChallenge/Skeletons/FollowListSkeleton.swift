//
//  FollowListSkeleton.swift
//  PlankChallenge
//

import SwiftUI

// MARK: - Follow List Screen Skeleton

struct FollowListSkeleton: View {
    var body: some View {
        List {
            ForEach(0..<6, id: \.self) { _ in
                SkeletonUserRow(avatarSize: 44, nameLine: 120, subtitleLine: 80)
                    .listRowBackground(Color.clear)
                    .listRowSeparatorTint(Color.secondary.opacity(0.15))
            }
        }
        .listStyle(.plain)
        .disabled(true)
    }
}

#Preview {
    NavigationStack {
        FollowListSkeleton()
            .navigationTitle("Following")
            .navigationBarTitleDisplayMode(.inline)
    }
}
