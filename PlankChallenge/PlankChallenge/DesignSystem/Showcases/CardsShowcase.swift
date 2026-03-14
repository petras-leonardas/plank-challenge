//
//  CardsShowcase.swift
//  PlankChallenge
//
//  Design System - Card components showcase
//

import SwiftUI

struct CardsShowcase: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                
                // MARK: - Card Style Modifier
                ShowcaseSectionHeader("Card Style", icon: "rectangle.portrait")
                
                ComponentShowcase(
                    "appCardStyle()",
                    description: "Standard card with padding, corner radius, and shadow",
                    code: """
                    VStack {
                        // Your content
                    }
                    .appCardStyle()
                    """
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Card Content")
                            .font(.headline)
                        Text("This is an example of content inside a card with the standard app card style applied.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .appCardStyle()
                }
                
                ComponentShowcase(
                    "appCardStyleCompact()",
                    description: "Compact card with smaller padding",
                    code: """
                    VStack {
                        // Your content
                    }
                    .appCardStyleCompact()
                    """
                ) {
                    HStack {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(.orange)
                        Text("Compact card example")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.secondary)
                    }
                    .appCardStyleCompact()
                }
                
                // MARK: - Stat Card
                ShowcaseSectionHeader("Stat Card", icon: "number")
                
                ComponentShowcase(
                    "StatCard",
                    description: "Display statistics with icon and label",
                    code: """
                    StatCard(
                        title: "Current Streak",
                        value: "14",
                        icon: "flame.fill",
                        color: .orange
                    )
                    """
                ) {
                    HStack(spacing: 12) {
                        StatCard(
                            title: "Current Streak",
                            value: "14",
                            icon: "flame.fill",
                            color: .orange
                        )
                        
                        StatCard(
                            title: "Best Streak",
                            value: "21",
                            icon: "trophy.fill",
                            color: .yellow
                        )
                    }
                }
                
                ComponentShowcase(
                    "StatCard with Subtitle",
                    description: "StatCard with additional context",
                    code: """
                    StatCard(
                        title: "Total Time",
                        value: "45:30",
                        subtitle: "This week",
                        icon: "clock.fill",
                        color: .blue
                    )
                    """
                ) {
                    StatCard(
                        title: "Total Time",
                        value: "45:30",
                        subtitle: "This week",
                        icon: "clock.fill",
                        color: .blue
                    )
                }
                
                // MARK: - Results Card
                ShowcaseSectionHeader("Results Card", icon: "medal")
                
                ComponentShowcase(
                    "ResultsCard",
                    description: "Strava-inspired personal best display",
                    code: """
                    ResultsCard(
                        title: "Personal Best",
                        value: "2:45",
                        subtitle: "Elbow Plank"
                    )
                    """
                ) {
                    ResultsCard(
                        title: "Personal Best",
                        value: "2:45",
                        subtitle: "Elbow Plank"
                    )
                }
                
                // MARK: - Card Layout Patterns
                ShowcaseSectionHeader("Layout Patterns", icon: "rectangle.3.group")
                
                ComponentShowcase(
                    "Card Grid",
                    description: "Common pattern for stat displays",
                    code: """
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        StatCard(...)
                        StatCard(...)
                    }
                    """
                ) {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        StatCard(title: "Planks", value: "42", icon: "figure.core.training", color: .blue)
                        StatCard(title: "Streak", value: "14", icon: "flame.fill", color: .orange)
                        StatCard(title: "Best", value: "2:45", icon: "trophy.fill", color: .yellow)
                        StatCard(title: "Total", value: "1:23:45", icon: "clock.fill", color: .green)
                    }
                }
                
                Spacer(minLength: 40)
            }
        }
        .navigationTitle("Cards")
        .background(Color(.systemGroupedBackground))
    }
}

#Preview {
    NavigationStack {
        CardsShowcase()
    }
}
