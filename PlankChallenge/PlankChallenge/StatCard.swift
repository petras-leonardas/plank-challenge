//
//  StatCard.swift
//  PlankChallenge
//
//  A unified stat display component supporting three layout variants:
//    .card   — Full-width card with left-aligned large value. Used in ProgressView.
//    .grid   — Compact centered tile for 3-up grids. Used in ProfileView stats section.
//    .mini   — Horizontal row with icon + value + label. Used in StreakStatsRow.
//

import SwiftUI

// MARK: - Stat Card Style

enum StatCardStyle {
    /// Full-width card with left-aligned large value and own card background.
    /// Apply `.appCardStyle()` yourself, or let the component do it (default: true).
    case card
    
    /// Compact centered tile for use in a 3-up HStack grid inside a parent card.
    /// Has its own soft-blue tinted background. Does NOT add a card shadow.
    case grid
    
    /// Horizontal row with icon + value + label. Use inside a parent card.
    /// Has its own soft-blue tinted background. Does NOT add a card shadow.
    case mini
}

// MARK: - Stat Card View

struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String?
    let icon: String?
    let color: Color
    let style: StatCardStyle
    
    init(
        title: String,
        value: String,
        subtitle: String? = nil,
        icon: String? = nil,
        color: Color = .appAccent,
        style: StatCardStyle = .card
    ) {
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.icon = icon
        self.color = color
        self.style = style
    }
    
    var body: some View {
        switch style {
        case .card:
            cardLayout
        case .grid:
            gridLayout
        case .mini:
            miniLayout
        }
    }
    
    // MARK: - Card Layout (full-width, left-aligned)
    
    private var cardLayout: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if let icon = icon {
                    Image(systemName: icon)
                        .foregroundStyle(color)
                }
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Text(value)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardStyle()
    }
    
    // MARK: - Grid Layout (compact centered tile)
    
    private var gridLayout: some View {
        VStack(spacing: 8) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.statCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Constants.UI.cardRadius))
    }
    
    // MARK: - Mini Layout (horizontal row)
    
    private var miniLayout: some View {
        HStack(spacing: 10) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(color)
                    .frame(width: 24)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.headline)
                    .fontWeight(.bold)
                
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding(Constants.UI.cardPaddingCompact)
        .background(Color.statCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Constants.UI.cardRadius))
    }
}

// MARK: - Preview

#Preview("All Styles") {
    ZStack {
        AppBackground()
        
        ScrollView {
            VStack(spacing: 20) {
                
                // Card style (full-width)
                VStack(alignment: .leading) {
                    Text("CARD STYLE")
                        .font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                    
                    StatCard(
                        title: "Current Streak",
                        value: "14",
                        subtitle: "days",
                        icon: "flame.fill",
                        color: .orange
                    )
                    .padding(.horizontal, 16)
                    
                    StatCard(
                        title: "Longest Plank",
                        value: "3:45",
                        subtitle: "personal best",
                        icon: "trophy.fill",
                        color: .yellow
                    )
                    .padding(.horizontal, 16)
                }
                
                // Grid style (3-up)
                VStack(alignment: .leading) {
                    Text("GRID STYLE (3-UP)")
                        .font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                    
                    HStack(spacing: 12) {
                        StatCard(title: "Day Streak", value: "14", icon: "flame.fill", color: .orange, style: .grid)
                        StatCard(title: "Total Planks", value: "127", icon: "figure.core.training", color: .appAccent, style: .grid)
                        StatCard(title: "Best Plank", value: "3:45", icon: "trophy.fill", color: .yellow, style: .grid)
                    }
                    .padding(16)
                    .background(Color.warmWhiteCard)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
                    .padding(.horizontal, 16)
                }
                
                // Mini style (stacked rows)
                VStack(alignment: .leading) {
                    Text("MINI STYLE")
                        .font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                    
                    VStack(spacing: 8) {
                        StatCard(title: "Best Plank", value: "3:45", icon: "star.fill", color: .purple, style: .mini)
                        StatCard(title: "Total Planks", value: "127", icon: "checkmark.circle.fill", color: .green, style: .mini)
                    }
                    .padding(16)
                    .background(Color.warmWhiteCard)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
                    .padding(.horizontal, 16)
                }
            }
            .padding(.vertical, 20)
        }
    }
}
