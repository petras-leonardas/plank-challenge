//
//  BadgesShowcase.swift
//  PlankChallenge
//
//  Design System - Badges and pills showcase
//

import SwiftUI

struct BadgesShowcase: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                
                // MARK: - Achievement Badges
                ShowcaseSectionHeader("Achievement Badges", icon: "medal")
                
                ComponentShowcase(
                    "BadgeView (Earned)",
                    description: "Yellow badge for earned achievements",
                    code: """
                    BadgeView(
                        badgeType: .streak7,
                        isEarned: true,
                        dateEarned: Date()
                    )
                    """
                ) {
                    HStack(spacing: 16) {
                        BadgeView(badgeType: .streak7, isEarned: true, dateEarned: Date())
                        BadgeView(badgeType: .streak14, isEarned: true, dateEarned: Date())
                        BadgeView(badgeType: .streak30, isEarned: true, dateEarned: Date())
                    }
                }
                
                ComponentShowcase(
                    "BadgeView (Not Earned)",
                    description: "Gray badge for locked achievements",
                    code: """
                    BadgeView(
                        badgeType: .streak60,
                        isEarned: false,
                        dateEarned: nil
                    )
                    """
                ) {
                    HStack(spacing: 16) {
                        BadgeView(badgeType: .streak60, isEarned: false, dateEarned: nil)
                        BadgeView(badgeType: .streak90, isEarned: false, dateEarned: nil)
                        BadgeView(badgeType: .streak180, isEarned: false, dateEarned: nil)
                    }
                }
                
                // MARK: - Admin Badge
                ShowcaseSectionHeader("Role Badges", icon: "person.badge.key")
                
                ComponentShowcase(
                    "AdminBadge",
                    description: "Small pill for admin indicator",
                    code: """
                    AdminBadge()
                    """
                ) {
                    HStack(spacing: 16) {
                        HStack {
                            Text("John Doe")
                            AdminBadge()
                        }
                        
                        HStack {
                            Text("Group Owner")
                            AdminBadge()
                        }
                    }
                }
                
                // MARK: - Pill Badges
                ShowcaseSectionHeader("Pill Badges", icon: "capsule")
                
                ComponentShowcase(
                    "PillBadge - Light Style",
                    description: "Light background with colored text",
                    code: """
                    PillBadge(text: "New", color: .blue, style: .light)
                    PillBadge(text: "Active", color: .green, style: .light)
                    """
                ) {
                    HStack(spacing: 12) {
                        PillBadge(text: "New", color: .blue, style: .light)
                        PillBadge(text: "Active", color: .green, style: .light)
                        PillBadge(text: "Pending", color: .orange, style: .light)
                        PillBadge(text: "Closed", color: .red, style: .light)
                    }
                }
                
                ComponentShowcase(
                    "PillBadge - Solid Style",
                    description: "Solid colored background with white text",
                    code: """
                    PillBadge(text: "New", color: .blue, style: .solid)
                    PillBadge(text: "Active", color: .green, style: .solid)
                    """
                ) {
                    HStack(spacing: 12) {
                        PillBadge(text: "New", color: .blue, style: .solid)
                        PillBadge(text: "Active", color: .green, style: .solid)
                        PillBadge(text: "Pending", color: .orange, style: .solid)
                        PillBadge(text: "Closed", color: .red, style: .solid)
                    }
                }
                
                // MARK: - Token Indicator
                ShowcaseSectionHeader("Token Indicator", icon: "snowflake")
                
                ComponentShowcase(
                    "TokenIndicator",
                    description: "Freeze token status display",
                    code: """
                    TokenIndicator(tokensRemaining: 2, maxTokens: 2)
                    TokenIndicator(tokensRemaining: 1, maxTokens: 2)
                    TokenIndicator(tokensRemaining: 0, maxTokens: 2)
                    """
                ) {
                    VStack(spacing: 16) {
                        HStack {
                            Text("Full tokens:")
                                .font(.caption)
                            Spacer()
                            TokenIndicator(tokensRemaining: 2, maxTokens: 2)
                        }
                        
                        HStack {
                            Text("One used:")
                                .font(.caption)
                            Spacer()
                            TokenIndicator(tokensRemaining: 1, maxTokens: 2)
                        }
                        
                        HStack {
                            Text("All used:")
                                .font(.caption)
                            Spacer()
                            TokenIndicator(tokensRemaining: 0, maxTokens: 2)
                        }
                    }
                }
                
                // MARK: - Blue Flame Icon
                ShowcaseSectionHeader("Streak Icons", icon: "flame")
                
                ComponentShowcase(
                    "BlueFlameIcon",
                    description: "Blue gradient flame for calendar and lists",
                    code: """
                    BlueFlameIcon()
                    BlueFlameIcon(size: 20)
                    BlueFlameIconSmall()
                    """
                ) {
                    HStack(spacing: 24) {
                        VStack {
                            BlueFlameIcon(size: 24)
                            Text("24pt")
                                .font(.caption2)
                        }
                        
                        VStack {
                            BlueFlameIcon(size: 18)
                            Text("18pt")
                                .font(.caption2)
                        }
                        
                        VStack {
                            BlueFlameIcon(size: 14)
                            Text("14pt")
                                .font(.caption2)
                        }
                        
                        VStack {
                            BlueFlameIconSmall()
                            Text("Small")
                                .font(.caption2)
                        }
                    }
                }
                
                // MARK: - Rank Badge
                ShowcaseSectionHeader("Rank Badges", icon: "trophy")
                
                ComponentShowcase(
                    "RankBadge",
                    description: "Leaderboard position indicator",
                    code: """
                    RankBadge(rank: 1, size: 36)  // Gold
                    RankBadge(rank: 2, size: 36)  // Silver
                    RankBadge(rank: 3, size: 36)  // Bronze
                    RankBadge(rank: 4, size: 36)  // Default
                    """
                ) {
                    HStack(spacing: 16) {
                        VStack {
                            RankBadge(rank: 1, size: 36)
                            Text("1st")
                                .font(.caption)
                        }
                        
                        VStack {
                            RankBadge(rank: 2, size: 36)
                            Text("2nd")
                                .font(.caption)
                        }
                        
                        VStack {
                            RankBadge(rank: 3, size: 36)
                            Text("3rd")
                                .font(.caption)
                        }
                        
                        VStack {
                            RankBadge(rank: 4, size: 36)
                            Text("4th+")
                                .font(.caption)
                        }
                    }
                }
                
                Spacer(minLength: 40)
            }
        }
        .navigationTitle("Badges & Pills")
        .background(Color(.systemGroupedBackground))
    }
}

#Preview {
    NavigationStack {
        BadgesShowcase()
    }
}
