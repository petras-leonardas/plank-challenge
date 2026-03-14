//
//  LeaderboardView.swift
//  PlankChallenge
//
//  Created by Leo Bacevicius on 08/03/2026.
//

import SwiftUI

// MARK: - Leaderboard Tab Enum

enum LeaderboardTab: String, CaseIterable {
    case streak = "Active Streak"
    case longestPlank = "Longest Plank"
}

// MARK: - Standalone Leaderboard View (for backwards compatibility)

struct LeaderboardView: View {
    var body: some View {
        NavigationStack {
            LeaderboardContent()
                .navigationTitle("Leaderboard")
        }
    }
}

// MARK: - Leaderboard Content (Embeddable)

struct LeaderboardContent: View {
    private var mockData: MockDataService { MockDataService.shared }
    @State private var selectedTab: LeaderboardTab = .streak
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab Picker
            Picker("Leaderboard", selection: $selectedTab) {
                ForEach(LeaderboardTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()
            
            // Leaderboard List
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(sortedUsers) { user in
                        LeaderboardRow(
                            user: user,
                            displayValue: displayValue(for: user)
                        )
                        
                        if user.id != sortedUsers.last?.id {
                            Divider()
                                .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
        }
    }
    
    private var sortedUsers: [LeaderboardUser] {
        switch selectedTab {
        case .streak:
            return mockData.leaderboardUsers.sorted { $0.currentStreak > $1.currentStreak }
        case .longestPlank:
            return mockData.leaderboardUsers.sorted { $0.longestPlankSeconds > $1.longestPlankSeconds }
        }
    }
    
    private func displayValue(for user: LeaderboardUser) -> String {
        switch selectedTab {
        case .streak:
            return "\(user.currentStreak) days"
        case .longestPlank:
            return user.longestPlankFormatted
        }
    }
}

// MARK: - Leaderboard Row
// Now uses LeaderboardRowView component from Components/LeaderboardRowView.swift

struct LeaderboardRow: View {
    let user: LeaderboardUser
    let displayValue: String
    
    var body: some View {
        LeaderboardRowView(
            user: user,
            displayValue: displayValue,
            size: .regular
        )
    }
}

#Preview {
    LeaderboardView()
}
