//
//  GroupMembersSkeleton.swift
//  PlankChallenge
//

import SwiftUI

// MARK: - Group Members List Screen Skeleton

struct GroupMembersSkeleton: View {
    var body: some View {
        List {
            ForEach(0..<8, id: \.self) { _ in
                SkeletonUserRow(avatarSize: 40, nameLine: 120, subtitleLine: 70)
                    .listRowBackground(Color.clear)
                    .listRowSeparatorTint(Color.secondary.opacity(0.15))
            }
        }
        .listStyle(.plain)
        .disabled(true)
    }
}

#Preview {
    NavigationStack {
        GroupMembersSkeleton()
            .navigationTitle("Members")
    }
}
