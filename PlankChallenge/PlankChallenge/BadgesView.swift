//
//  BadgesView.swift
//  PlankChallenge
//
//  Created by Leo Bacevicius on 08/03/2026.
//

import SwiftUI

struct BadgesView: View {
    private var mockData: MockDataService { MockDataService.shared }
    
    private let columns = [
        GridItem(.adaptive(minimum: 100), spacing: 16)
    ]
    
    private var earnedBadgeTypes: [Badge.BadgeType] {
        mockData.badges.compactMap { $0.badgeType }
    }
    
    var body: some View {
        ZStack {
            AppBackground()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Earned badges
                    if !mockData.badges.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader(title: "Earned")
                                .padding(.horizontal)
                            
                            LazyVGrid(columns: columns, spacing: 20) {
                                ForEach(earnedBadgeTypes, id: \.self) { badgeType in
                                    let earnedBadge = mockData.badges.first { $0.badgeType == badgeType }
                                    BadgeView(
                                        badgeType: badgeType,
                                        isEarned: true,
                                        dateEarned: earnedBadge?.dateEarned
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    // Locked badges
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "Locked")
                            .padding(.horizontal)
                        
                        LazyVGrid(columns: columns, spacing: 20) {
                            ForEach(Badge.BadgeType.allCases.filter { !earnedBadgeTypes.contains($0) }, id: \.self) { badgeType in
                                BadgeView(
                                    badgeType: badgeType,
                                    isEarned: false,
                                    dateEarned: nil
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
        }
        .navigationTitle("Badges")
        .toolbarBackground(Color.subtleBlueGradientStart.opacity(0.5), for: .navigationBar)
    }
}

#Preview {
    NavigationStack {
        BadgesView()
    }
}
