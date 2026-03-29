//
//  FollowListSkeleton.swift
//  PlankChallenge
//

import SwiftUI

// MARK: - Follow List Screen Skeleton

struct FollowListSkeleton: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                ForEach(0..<6, id: \.self) { index in
                    SkeletonUserRow(avatarSize: 44, nameLine: 120, subtitleLine: 80)
                        .padding(.horizontal)
                    if index < 5 {
                        Divider()
                            .padding(.leading, 68) // matches real row avatar indent
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .shimmer()
        .disabled(true)
        .accessibilityLabel("Loading users")
    }
}

#Preview {
    NavigationStack {
        FollowListSkeleton()
            .navigationTitle("Following")
    }
}
