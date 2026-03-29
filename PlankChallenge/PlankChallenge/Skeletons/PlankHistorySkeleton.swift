//
//  PlankHistorySkeleton.swift
//  PlankChallenge
//

import SwiftUI

// MARK: - Plank History List Screen Skeleton

struct PlankHistorySkeleton: View {
    var body: some View {
        List {
            // One section with a month header placeholder
            Section {
                ForEach(0..<5, id: \.self) { _ in
                    SkeletonPlankHistoryRow()
                        .listRowBackground(Color.clear)
                }
            } header: {
                SkeletonLine(width: 100, height: 12)
                    .padding(.vertical, 4)
            }

            Section {
                ForEach(0..<3, id: \.self) { _ in
                    SkeletonPlankHistoryRow()
                        .listRowBackground(Color.clear)
                }
            } header: {
                SkeletonLine(width: 80, height: 12)
                    .padding(.vertical, 4)
            }
        }
        .disabled(true)
    }
}

#Preview {
    NavigationStack {
        PlankHistorySkeleton()
            .navigationTitle("Plank History")
    }
}
