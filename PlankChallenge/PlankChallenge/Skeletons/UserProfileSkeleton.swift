//
//  UserProfileSkeleton.swift
//  PlankChallenge
//

import SwiftUI

// MARK: - User Profile Screen Skeleton

struct UserProfileSkeleton: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                profileHeaderSkeleton
                statsSkeleton
            }
            .padding()
        }
        .disabled(true)
    }

    // MARK: - Profile Header

    private var profileHeaderSkeleton: some View {
        VStack(spacing: 16) {
            // Avatar
            SkeletonCircle(size: 80)

            // Name, username, location
            VStack(spacing: 8) {
                SkeletonLine(width: 150, height: 20)
                SkeletonLine(width: 100, height: 13, muted: true)
                SkeletonLine(width: 120, height: 11, muted: true)
            }

            // Bio lines
            VStack(spacing: 5) {
                SkeletonLine(width: 240, height: 12, muted: true)
                SkeletonLine(width: 180, height: 12, muted: true)
            }

            // Social counts
            HStack(spacing: 32) {
                VStack(spacing: 4) {
                    SkeletonLine(width: 36, height: 16)
                    SkeletonLine(width: 60, height: 11, muted: true)
                }
                VStack(spacing: 4) {
                    SkeletonLine(width: 36, height: 16)
                    SkeletonLine(width: 60, height: 11, muted: true)
                }
            }

            // Follow button placeholder
            SkeletonBlock(height: 36)
                .clipShape(Capsule())
                .frame(width: 120)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color.warmWhiteCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }

    // MARK: - Stats

    private var statsSkeleton: some View {
        HStack(spacing: 12) {
            ForEach(0..<2, id: \.self) { _ in
                VStack(spacing: 8) {
                    SkeletonLine(width: 60, height: 18)
                    SkeletonLine(width: 80, height: 11, muted: true)
                }
                .frame(maxWidth: .infinity)
                .padding(16)
                .background(Color.warmWhiteCard)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
            }
        }
    }
}

#Preview {
    NavigationStack {
        ZStack {
            AppBackground()
            UserProfileSkeleton()
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
    }
}
