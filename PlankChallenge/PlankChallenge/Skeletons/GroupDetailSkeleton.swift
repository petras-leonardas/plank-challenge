//
//  GroupDetailSkeleton.swift
//  PlankChallenge
//

import SwiftUI

// MARK: - Group Detail Screen Skeleton

struct GroupDetailSkeleton: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                headerSkeleton
                leaderboardSectionSkeleton
            }
            .padding()
        }
        .shimmer()
        .disabled(true)
        .accessibilityLabel("Loading group")
    }

    // MARK: - Header

    private var headerSkeleton: some View {
        VStack(spacing: 12) {
            SkeletonCircle(size: 80)
            VStack(spacing: 6) {
                SkeletonLine(width: 140, height: 18)
                SkeletonLine(width: 80, height: 12, muted: true)
            }
            SkeletonLine(width: 220, height: 11, muted: true)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color.warmWhiteCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }

    // MARK: - Leaderboard Section

    private var leaderboardSectionSkeleton: some View {
        VStack(spacing: 12) {
            // Picker placeholder
            SkeletonBlock(height: 32)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(spacing: 0) {
                ForEach(0..<8, id: \.self) { index in
                    SkeletonLeaderboardRow()
                    if index < 7 {
                        Divider().padding(.leading, 60)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.warmWhiteCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Group Leaderboard Section Skeleton (inline)

struct GroupLeaderboardSectionSkeleton: View {
    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<6, id: \.self) { index in
                SkeletonLeaderboardRow()
                if index < 5 {
                    Divider().padding(.leading, 60)
                }
            }
        }
        .padding(.vertical, 20)
        .shimmer()
    }
}

#Preview {
    NavigationStack {
        ZStack {
            AppBackground()
            GroupDetailSkeleton()
        }
        .navigationTitle("Group")
        .navigationBarTitleDisplayMode(.inline)
    }
}
