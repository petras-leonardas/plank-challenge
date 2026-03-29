//
//  BadgesSkeleton.swift
//  PlankChallenge
//

import SwiftUI

// MARK: - Badges Screen Skeleton

struct BadgesSkeleton: View {
    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 16)]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                // Section header placeholder
                SkeletonLine(width: 120, height: 11)
                    .padding(.horizontal)

                // Badge grid
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(0..<9, id: \.self) { _ in
                        VStack(spacing: 8) {
                            SkeletonCircle(size: 64)
                            SkeletonLine(width: 70, height: 12)
                            SkeletonLine(width: 50, height: 10, muted: true)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .shimmer()
        .disabled(true)
        .accessibilityLabel("Loading badges")
    }
}

// MARK: - Profile Badges Section Skeleton

/// Skeleton for the badges section inside ProfileView (horizontal scroll).
struct ProfileBadgesSectionSkeleton: View {
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(0..<5, id: \.self) { _ in
                    VStack(spacing: 8) {
                        SkeletonCircle(size: 48)
                        SkeletonLine(width: 52, height: 10)
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .shimmer()
    }
}

#Preview {
    NavigationStack {
        ZStack {
            AppBackground()
            BadgesSkeleton()
        }
        .navigationTitle("Badges")
    }
}
