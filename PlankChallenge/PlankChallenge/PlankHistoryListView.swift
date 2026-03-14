//
//  PlankHistoryListView.swift
//  PlankChallenge
//
//  Created by Leo Bacevicius on 08/03/2026.
//

import SwiftUI

struct PlankHistoryListView: View {
    private var mockData: MockDataService { MockDataService.shared }
    
    var body: some View {
        List {
            ForEach(mockData.plankHistoryGroupedByMonth, id: \.key) { month, sessions in
                Section(month) {
                    ForEach(sessions) { session in
                        NavigationLink {
                            PlankDetailView(session: session)
                        } label: {
                            PlankHistoryRowFull(session: session)
                        }
                    }
                }
            }
        }
        .navigationTitle("Plank History")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PlankHistoryRowFull: View {
    let session: PlankSession
    
    var body: some View {
        HStack {
            // Date
            VStack(alignment: .leading, spacing: 2) {
                Text(session.date.relativeFormatted)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(session.plankType.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Duration
            Text(session.durationSeconds.formattedDuration)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(Color.colorForPlankType(session.plankType))
            
            // Input method indicator
            Image(systemName: session.inputMethod == .timer ? "timer" : "hand.tap")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        PlankHistoryListView()
    }
}
