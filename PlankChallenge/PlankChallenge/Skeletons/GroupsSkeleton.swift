//
//  GroupsSkeleton.swift
//  PlankChallenge
//

import SwiftUI

// MARK: - Groups Screen Skeleton

struct GroupsSkeleton: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                myGroupsSkeleton
                discoverGroupsSkeleton
                compactLeaderboardSkeleton
            }
            .padding(.vertical, 16)
        }
        .disabled(true)
    }

    // MARK: - My Groups

    private var myGroupsSkeleton: some View {
        VStack(alignment: .leading, spacing: 12) {
            SkeletonLine(width: 80, height: 11)
                .padding(.horizontal, 16)

            VStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { _ in
                    SkeletonGroupRow()
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.warmWhiteCard)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Discover Groups

    private var discoverGroupsSkeleton: some View {
        VStack(alignment: .leading, spacing: 12) {
            SkeletonLine(width: 110, height: 11)
                .padding(.horizontal, 16)

            VStack(spacing: 8) {
                ForEach(0..<2, id: \.self) { _ in
                    SkeletonGroupRow()
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.warmWhiteCard)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Compact Leaderboard

    private var compactLeaderboardSkeleton: some View {
        VStack(alignment: .leading, spacing: 12) {
            SkeletonLine(width: 120, height: 11)
                .padding(.horizontal, 16)

            VStack(spacing: 0) {
                // Picker placeholder
                SkeletonBlock(height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal, 12)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                VStack(spacing: 0) {
                    ForEach(0..<5, id: \.self) { index in
                        SkeletonLeaderboardRow()
                            .padding(.horizontal, 12)
                        if index < 4 {
                            Divider().padding(.horizontal, 12)
                        }
                    }
                }
                .padding(.bottom, 12)
            }
            .background(Color.warmWhiteCard)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - Compact Leaderboard Skeleton (for inline use)

struct CompactLeaderboardSkeleton: View {
    var body: some View {
        VStack(spacing: 0) {
            SkeletonBlock(height: 32)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 8)

            VStack(spacing: 0) {
                ForEach(0..<5, id: \.self) { index in
                    SkeletonLeaderboardRow()
                        .padding(.horizontal, 12)
                    if index < 4 {
                        Divider().padding(.horizontal, 12)
                    }
                }
            }
            .padding(.bottom, 12)
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    ZStack {
        AppBackground()
        GroupsSkeleton()
    }
}
