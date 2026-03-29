//
//  SearchSkeleton.swift
//  PlankChallenge
//

import SwiftUI

// MARK: - Search Screen Suggested People Skeleton

/// Replaces the hardcoded static placeholder in SearchView with the animated shimmer version.
struct SuggestedPeopleSkeleton: View {
    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { _ in
                SkeletonUserRow(avatarSize: 48, nameLine: 120, subtitleLine: 80)
            }
        }
        .shimmer()
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        Text("SUGGESTED PEOPLE")
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
        SuggestedPeopleSkeleton()
    }
    .padding(20)
    .background(Color.softBlueBackground)
}
