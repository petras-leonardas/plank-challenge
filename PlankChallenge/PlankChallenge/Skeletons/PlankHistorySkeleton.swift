//
//  PlankHistorySkeleton.swift
//  PlankChallenge
//

import SwiftUI

// MARK: - Plank History List Screen Skeleton

struct PlankHistorySkeleton: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                // Month header placeholder
                SkeletonLine(width: 100, height: 12)
                    .padding(.horizontal)
                    .padding(.top, 20)
                    .padding(.bottom, 8)

                VStack(spacing: 0) {
                    ForEach(0..<5, id: \.self) { index in
                        SkeletonPlankHistoryRow()
                            .padding(.horizontal)
                        if index < 4 {
                            Divider().padding(.horizontal)
                        }
                    }
                }

                // Second month section
                SkeletonLine(width: 80, height: 12)
                    .padding(.horizontal)
                    .padding(.top, 24)
                    .padding(.bottom, 8)

                VStack(spacing: 0) {
                    ForEach(0..<3, id: \.self) { index in
                        SkeletonPlankHistoryRow()
                            .padding(.horizontal)
                        if index < 2 {
                            Divider().padding(.horizontal)
                        }
                    }
                }
            }
            .padding(.bottom, 16)
        }
        .shimmer()
        .disabled(true)
        .accessibilityLabel("Loading plank history")
    }
}

#Preview {
    NavigationStack {
        PlankHistorySkeleton()
            .navigationTitle("Plank History")
    }
}
