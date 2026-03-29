//
//  ProgressSkeleton.swift
//  PlankChallenge
//

import SwiftUI

// MARK: - Progress Screen Skeleton

/// Full-screen skeleton for PlankProgressView — mirrors the streak hero,
/// badges section, and recent planks section.
struct ProgressSkeleton: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                // Streak + Stats row
                streakStatsSkeleton

                // Calendar block
                SkeletonBlock(height: 220)

                // Badges section
                badgesSectionSkeleton

                // Recent planks section
                recentPlanksSectionSkeleton
            }
            .padding()
        }
        .disabled(true) // prevent interaction while skeleton is showing
    }

    // MARK: - Streak + Stats

    private var streakStatsSkeleton: some View {
        HStack(spacing: 12) {
            // Streak hero (left)
            VStack(spacing: 8) {
                SkeletonCircle(size: 64)
                SkeletonLine(width: 80, height: 13)
                SkeletonLine(width: 55, height: 11, muted: true)
            }
            .frame(maxWidth: .infinity)

            // Divider
            Rectangle()
                .fill(Color.secondary.opacity(0.1))
                .frame(width: 1, height: 60)

            // Stats (right): 3 mini stat tiles
            VStack(spacing: 10) {
                ForEach(0..<3, id: \.self) { _ in
                    HStack {
                        SkeletonLine(width: 70, height: 12)
                        Spacer()
                        SkeletonLine(width: 40, height: 12)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(Color.warmWhiteCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }

    // MARK: - Badges Section

    private var badgesSectionSkeleton: some View {
        VStack(alignment: .leading, spacing: 12) {
            SkeletonLine(width: 70, height: 11)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(0..<5, id: \.self) { _ in
                        VStack(spacing: 6) {
                            SkeletonCircle(size: 52)
                            SkeletonLine(width: 52, height: 10)
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(16)
        .background(Color.warmWhiteCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }

    // MARK: - Recent Planks Section

    private var recentPlanksSectionSkeleton: some View {
        VStack(alignment: .leading, spacing: 12) {
            SkeletonLine(width: 100, height: 11)

            VStack(spacing: 0) {
                ForEach(0..<4, id: \.self) { index in
                    SkeletonPlankHistoryRow()
                    if index < 3 {
                        Divider().opacity(0.4)
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

// MARK: - Badge Section Inline Skeleton

/// Skeleton for just the badges section inside PlankProgressView.
struct BadgesSectionSkeleton: View {
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(0..<5, id: \.self) { _ in
                    VStack(spacing: 6) {
                        SkeletonCircle(size: 52)
                        SkeletonLine(width: 52, height: 10)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Recent Planks Section Inline Skeleton

/// Skeleton for just the recent planks section inside PlankProgressView.
struct RecentPlanksSectionSkeleton: View {
    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<4, id: \.self) { index in
                SkeletonPlankHistoryRow()
                if index < 3 {
                    Divider().opacity(0.4)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    ZStack {
        AppBackground()
        ProgressSkeleton()
    }
}
