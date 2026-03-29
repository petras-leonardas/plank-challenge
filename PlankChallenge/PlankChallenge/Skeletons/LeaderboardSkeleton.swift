//
//  LeaderboardSkeleton.swift
//  PlankChallenge
//

import SwiftUI

// MARK: - Leaderboard Screen Skeleton

struct LeaderboardSkeleton: View {
    var body: some View {
        VStack(spacing: 0) {
            // Tab picker placeholder
            SkeletonBlock(height: 32)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal)
                .padding(.top, 16)
                .padding(.bottom, 4)

            // Period picker placeholder
            SkeletonBlock(height: 32)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal)
                .padding(.bottom, 8)

            // Leaderboard rows
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(0..<12, id: \.self) { index in
                        SkeletonLeaderboardRow()
                            .padding(.horizontal)

                        if index < 11 {
                            Divider().padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
        }
        .shimmer()
        .disabled(true)
        .accessibilityLabel("Loading leaderboard")
    }
}

// MARK: - Friends Leaderboard Skeleton (inline)

struct FriendsLeaderboardSkeleton: View {
    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<6, id: \.self) { index in
                SkeletonLeaderboardRow()
                    .padding(.horizontal)
                if index < 5 {
                    Divider().padding(.horizontal)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .shimmer()
    }
}

#Preview {
    LeaderboardSkeleton()
}
