//
//  ProgressView.swift
//  PlankChallenge
//
//  Created by Leo Bacevicius on 08/03/2026.
//

import SwiftUI

struct PlankProgressView: View {
    private var mockData: MockDataService { MockDataService.shared }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // App background with subtle gradient
                AppBackground()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // 1. STREAK + STATS ROW (streak left, stats right)
                        StreakStatsRow(
                            currentStreak: mockData.currentUser.currentStreak,
                            longestStreak: mockData.currentUser.longestStreak,
                            bestPlankTime: mockData.longestPlank?.durationSeconds.formattedDuration ?? "0:00",
                            totalPlanks: mockData.totalPlanks
                        )
                        
                        // 2. MONTHLY CALENDAR
                        StreakCalendarView(
                            plankSessions: mockData.plankHistory
                        )
                        
                        // 4. BADGES
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Badges")
                                    .font(.headline)
                                
                                Spacer()
                                
                                NavigationLink {
                                    BadgesView()
                                } label: {
                                    Text("See All")
                                        .font(.subheadline)
                                        .foregroundStyle(Color.appAccent)
                                }
                            }
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(Badge.BadgeType.allCases, id: \.self) { badgeType in
                                        let earned = mockData.badges.contains { $0.badgeType == badgeType }
                                        let earnedBadge = mockData.badges.first { $0.badgeType == badgeType }
                                        
                                        BadgeView(
                                            badgeType: badgeType,
                                            isEarned: earned,
                                            dateEarned: earnedBadge?.dateEarned
                                        )
                                    }
                                }
                                .padding(.horizontal, 4)
                            }
                        }
                        .appCardStyle()
                        
                        // 5. RECENT PLANKS
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Recent Planks")
                                    .font(.headline)
                                
                                Spacer()
                                
                                NavigationLink {
                                    PlankHistoryListView()
                                } label: {
                                    Text("See All")
                                        .font(.subheadline)
                                        .foregroundStyle(Color.appAccent)
                                }
                            }
                            
                            ForEach(mockData.plankSessions.prefix(5)) { session in
                                NavigationLink {
                                    PlankDetailView(session: session)
                                } label: {
                                    PlankHistoryRow(session: session)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .appCardStyle()
                    }
                    .padding()
                }
            }
            .navigationTitle("Progress")
            .toolbarBackground(Color.subtleBlueGradientStart.opacity(0.5), for: .navigationBar)
        }
    }
}

// MARK: - History Row

struct PlankHistoryRow: View {
    let session: PlankSession
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.date.relativeFormatted)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(session.plankType.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Text(session.durationSeconds.formattedDuration)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(Color.appAccent)
            
            Image(systemName: session.inputMethod == .timer ? "timer" : "hand.tap")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    PlankProgressView()
}
