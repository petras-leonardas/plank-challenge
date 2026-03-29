//
//  GroupMembersSkeleton.swift
//  PlankChallenge
//

import SwiftUI

// MARK: - Group Members List Screen Skeleton

struct GroupMembersSkeleton: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                ForEach(0..<8, id: \.self) { index in
                    SkeletonUserRow(avatarSize: 40, nameLine: 120, subtitleLine: 70)
                        .padding(.horizontal)
                    if index < 7 {
                        Divider()
                            .padding(.leading, 64) // matches real member row indent
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .shimmer()
        .disabled(true)
        .accessibilityLabel("Loading members")
    }
}

#Preview {
    NavigationStack {
        GroupMembersSkeleton()
            .navigationTitle("Members")
    }
}
