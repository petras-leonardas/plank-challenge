//
//  SkeletonShapes.swift
//  PlankChallenge
//

import SwiftUI

// MARK: - Skeleton Colour

/// The base fill colour for all skeleton placeholder shapes.
/// Uses secondary label at low opacity so it respects light / dark mode.
private extension Color {
    static let skeletonBase = Color.secondary.opacity(0.18)
    static let skeletonMuted = Color.secondary.opacity(0.11)
}

// MARK: - Primitive Shapes

/// A rounded-rectangle placeholder for a line of text.
struct SkeletonLine: View {
    var width: CGFloat
    var height: CGFloat = 13
    var cornerRadius: CGFloat = 5
    var muted: Bool = false

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(muted ? Color.skeletonMuted : Color.skeletonBase)
            .frame(width: width, height: height)
            .shimmer()
    }
}

/// A circular placeholder for avatars and icons.
struct SkeletonCircle: View {
    var size: CGFloat = 44

    var body: some View {
        Circle()
            .fill(Color.skeletonBase)
            .frame(width: size, height: size)
            .shimmer()
    }
}

/// A full-width (or fixed-height) rounded-rectangle placeholder for cards or images.
struct SkeletonBlock: View {
    var height: CGFloat
    var cornerRadius: CGFloat = 12

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.skeletonBase)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .shimmer()
    }
}

/// A single skeleton row representing a user (avatar + two text lines).
struct SkeletonUserRow: View {
    var avatarSize: CGFloat = 44
    var nameLine: CGFloat = 110
    var subtitleLine: CGFloat = 75

    var body: some View {
        HStack(spacing: 12) {
            SkeletonCircle(size: avatarSize)
            VStack(alignment: .leading, spacing: 6) {
                SkeletonLine(width: nameLine, height: 14)
                SkeletonLine(width: subtitleLine, height: 11, muted: true)
            }
            Spacer()
        }
        .padding(.vertical, 6)
    }
}

/// A single skeleton row for a group (image + two text lines + chevron hint).
struct SkeletonGroupRow: View {
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.skeletonBase)
                .frame(width: 56, height: 56)
                .shimmer()
            VStack(alignment: .leading, spacing: 6) {
                SkeletonLine(width: 130, height: 14)
                SkeletonLine(width: 80, height: 11, muted: true)
            }
            Spacer()
        }
        .padding(.vertical, 6)
    }
}

/// A single skeleton row for a leaderboard entry (rank + avatar + name + score).
struct SkeletonLeaderboardRow: View {
    var body: some View {
        HStack(spacing: 12) {
            SkeletonLine(width: 28, height: 18, cornerRadius: 6)
            SkeletonCircle(size: 36)
            VStack(alignment: .leading, spacing: 6) {
                SkeletonLine(width: 100, height: 14)
                SkeletonLine(width: 60, height: 11, muted: true)
            }
            Spacer()
            SkeletonLine(width: 50, height: 14)
        }
        .padding(.vertical, 8)
    }
}

/// A single skeleton row for a plank history entry (date + duration).
struct SkeletonPlankHistoryRow: View {
    var body: some View {
        HStack {
            SkeletonLine(width: 90, height: 14)
            Spacer()
            SkeletonLine(width: 50, height: 18, cornerRadius: 6)
        }
        .padding(.vertical, 8)
    }
}

/// A single skeleton row for a notification (icon + two text lines + timestamp).
struct SkeletonNotificationRow: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            SkeletonCircle(size: 32)
            VStack(alignment: .leading, spacing: 6) {
                SkeletonLine(width: 150, height: 13)
                SkeletonLine(width: 200, height: 11, muted: true)
                SkeletonLine(width: 60, height: 10, muted: true)
            }
            Spacer()
        }
        .padding(.vertical, 6)
    }
}
