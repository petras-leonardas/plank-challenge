//
//  ListRowsShowcase.swift
//  PlankChallenge
//
//  Design System - List row components showcase
//

import SwiftUI

struct ListRowsShowcase: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                
                // MARK: - Section Headers
                ShowcaseSectionHeader("Section Headers", icon: "text.alignleft")
                
                ComponentShowcase(
                    "SectionHeader",
                    description: "Section header with optional action",
                    code: """
                    SectionHeader(
                        title: "Recent Planks",
                        destination: PlankHistoryView()
                    )
                    """
                ) {
                    VStack(spacing: 16) {
                        SectionHeader(title: "Recent Planks") {
                            Text("History")
                        }
                        
                        SimpleSectionHeader(title: "Badges")
                    }
                }
                
                // MARK: - User Rows
                ShowcaseSectionHeader("User Rows", icon: "person")
                
                ComponentShowcase(
                    "UserRowView",
                    description: "Basic user row for lists",
                    code: """
                    UserRowView(
                        name: "Alice Brown",
                        subtitle: "@alice"
                    )
                    """
                ) {
                    VStack(spacing: 0) {
                        UserRowView(
                            name: "Alice Brown",
                            subtitle: "@alice"
                        )
                        
                        Divider()
                            .padding(.leading, 56)
                        
                        UserRowView(
                            name: "Bob Smith",
                            subtitle: "14 day streak"
                        )
                    }
                    .appCardStyle()
                }
                
                ComponentShowcase(
                    "UserRowView with Chevron",
                    description: "User row with navigation chevron",
                    code: """
                    UserRowView(
                        name: "Leo Bacevicius",
                        subtitle: "@leo",
                        showChevron: true
                    )
                    """
                ) {
                    UserRowView(
                        name: "Leo Bacevicius",
                        subtitle: "@leo",
                        showChevron: true
                    )
                    .appCardStyle()
                }
                
                ComponentShowcase(
                    "UserRowWithFollowButton",
                    description: "User row with follow/following button",
                    code: """
                    UserRowWithFollowButton(
                        name: "Sarah Connor",
                        subtitle: "@sarah",
                        isFollowing: false,
                        onFollowTap: { }
                    )
                    """
                ) {
                    VStack(spacing: 0) {
                        UserRowWithFollowButton(
                            name: "Sarah Connor",
                            subtitle: "@sarah",
                            isFollowing: false,
                            onFollowTap: { }
                        )
                        
                        Divider()
                            .padding(.leading, 56)
                        
                        UserRowWithFollowButton(
                            name: "John Doe",
                            subtitle: "@john",
                            isFollowing: true,
                            onFollowTap: { }
                        )
                    }
                    .appCardStyle()
                }
                
                ComponentShowcase(
                    "UserRowWithAdminBadge",
                    description: "User row with admin indicator",
                    code: """
                    UserRowWithAdminBadge(
                        name: "Leo B",
                        subtitle: "Group Admin",
                        isAdmin: true
                    )
                    """
                ) {
                    VStack(spacing: 0) {
                        UserRowWithAdminBadge(
                            name: "Leo B",
                            subtitle: "Group Admin",
                            isAdmin: true
                        )
                        
                        Divider()
                            .padding(.leading, 56)
                        
                        UserRowWithAdminBadge(
                            name: "Regular Member",
                            subtitle: "Member since 2024",
                            isAdmin: false
                        )
                    }
                    .appCardStyle()
                }
                
                ComponentShowcase(
                    "Compact Size",
                    description: "Smaller user rows for dense lists",
                    code: """
                    UserRowView(
                        name: "Compact User",
                        subtitle: "12 day streak",
                        size: .compact
                    )
                    """
                ) {
                    UserRowView(
                        name: "Compact User",
                        subtitle: "12 day streak",
                        size: .compact
                    )
                    .appCardStyle()
                }
                
                // MARK: - Leaderboard Rows
                ShowcaseSectionHeader("Leaderboard Rows", icon: "list.number")
                
                ComponentShowcase(
                    "LeaderboardRowView",
                    description: "Ranked user row with position badge",
                    code: """
                    LeaderboardRowView(
                        rank: 1,
                        name: "Leo Bacevicius",
                        displayValue: "21 days",
                        isCurrentUser: true
                    )
                    """
                ) {
                    VStack(spacing: 0) {
                        LeaderboardRowView(
                            rank: 1,
                            name: "Leo Bacevicius",
                            displayValue: "21 days",
                            isCurrentUser: true
                        )
                        
                        Divider()
                            .padding(.leading, 80)
                        
                        LeaderboardRowView(
                            rank: 2,
                            name: "Alice Brown",
                            displayValue: "18 days",
                            isCurrentUser: false
                        )
                        
                        Divider()
                            .padding(.leading, 80)
                        
                        LeaderboardRowView(
                            rank: 3,
                            name: "Bob Smith",
                            displayValue: "14 days",
                            isCurrentUser: false
                        )
                        
                        Divider()
                            .padding(.leading, 80)
                        
                        LeaderboardRowView(
                            rank: 4,
                            name: "Carol White",
                            displayValue: "12 days",
                            isCurrentUser: false
                        )
                    }
                    .background(Color.warmWhiteCard)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                ComponentShowcase(
                    "Compact Size",
                    description: "Smaller leaderboard rows",
                    code: """
                    LeaderboardRowView(
                        rank: 1,
                        name: "User",
                        displayValue: "14 days",
                        size: .compact
                    )
                    """
                ) {
                    VStack(spacing: 0) {
                        LeaderboardRowView(
                            rank: 1,
                            name: "Leo Bacevicius",
                            displayValue: "21 days",
                            isCurrentUser: true,
                            size: .compact
                        )
                        
                        Divider()
                            .padding(.leading, 64)
                        
                        LeaderboardRowView(
                            rank: 2,
                            name: "Alice Brown",
                            displayValue: "18 days",
                            isCurrentUser: false,
                            size: .compact
                        )
                    }
                    .background(Color.warmWhiteCard)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                // MARK: - Rank Badge
                ShowcaseSectionHeader("Rank Badges", icon: "medal")
                
                ComponentShowcase(
                    "RankBadge",
                    description: "Position indicator with color coding",
                    code: """
                    RankBadge(rank: 1)
                    RankBadge(rank: 2)
                    RankBadge(rank: 3)
                    RankBadge(rank: 4)
                    """
                ) {
                    HStack(spacing: 16) {
                        RankBadge(rank: 1)
                        RankBadge(rank: 2)
                        RankBadge(rank: 3)
                        RankBadge(rank: 4)
                    }
                    .padding()
                    .appCardStyle()
                }
                
                Spacer(minLength: 40)
            }
        }
        .navigationTitle("List Rows")
        .background(Color.softBlueBackground)
    }
}

#Preview {
    NavigationStack {
        ListRowsShowcase()
    }
}
