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
                        HStack(spacing: 12) {
                            // Rank placeholder
                            SkeletonLine(width: 36, height: 18, cornerRadius: 6)
                                .frame(width: 40)

                            // Avatar
                            SkeletonCircle(size: 40)

                            // Name + username
                            VStack(alignment: .leading, spacing: 5) {
                                SkeletonLine(width: 110, height: 14)
                                SkeletonLine(width: 70, height: 11, muted: true)
                            }

                            Spacer()

                            // Score
                            SkeletonLine(width: 55, height: 16)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)

                        if index < 11 {
                            Divider().padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
        }
        .disabled(true)
    }
}

// MARK: - Friends Leaderboard Skeleton (inline)

struct FriendsLeaderboardSkeleton: View {
    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<6, id: \.self) { index in
                HStack(spacing: 12) {
                    SkeletonLine(width: 36, height: 18, cornerRadius: 6)
                        .frame(width: 40)
                    SkeletonCircle(size: 40)
                    VStack(alignment: .leading, spacing: 5) {
                        SkeletonLine(width: 110, height: 14)
                        SkeletonLine(width: 70, height: 11, muted: true)
                    }
                    Spacer()
                    SkeletonLine(width: 55, height: 16)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)

                if index < 5 {
                    Divider().padding(.horizontal)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

#Preview {
    LeaderboardSkeleton()
}
