//
//  MyGroupsListSkeleton.swift
//  PlankChallenge
//

import SwiftUI

// MARK: - My Groups List Screen Skeleton

struct MyGroupsListSkeleton: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 12) {
                ForEach(0..<5, id: \.self) { _ in
                    SkeletonGroupRow()
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.warmWhiteCard)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
                }
            }
            .padding()
        }
        .disabled(true)
    }
}

#Preview {
    NavigationStack {
        ZStack {
            AppBackground()
            MyGroupsListSkeleton()
        }
        .navigationTitle("My Groups")
    }
}
