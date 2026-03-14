//
//  StreakStatsRow.swift
//  PlankChallenge
//
//  A combined component showing the streak hero on the left
//  and two mini stat cards stacked on the right.
//

import SwiftUI

struct StreakStatsRow: View {
    let currentStreak: Int
    let longestStreak: Int
    let bestPlankTime: String
    let totalPlanks: Int
    
    @State private var isPulsing = false
    
    /// Whether the user has achieved a new personal best
    private var isNewRecord: Bool {
        currentStreak >= longestStreak && currentStreak > 0
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // LEFT: Streak Hero
            streakSection
            
            // RIGHT: Stat Cards (stacked)
            statsSection
        }
        .padding(16)
        .background(Color.warmWhiteCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Streak Section (Left)
    
    private var streakSection: some View {
        VStack(spacing: 6) {
            // Animated Flame Icon
            ZStack {
                // Glow effect (behind the flame)
                Image(systemName: "flame.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.plankButtonInner, Color.plankGradientEnd],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .blur(radius: isPulsing ? 15 : 10)
                    .opacity(isPulsing ? 0.6 : 0.3)
                    .scaleEffect(isPulsing ? 1.15 : 1.0)
                
                // Main flame icon
                Image(systemName: "flame.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.plankButtonInner, Color.plankGradientEnd],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 1.5)
                    .repeatForever(autoreverses: true)
                ) {
                    isPulsing = true
                }
            }
            
            // Streak Number
            Text("\(currentStreak)")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            
            // "DAY STREAK" Label
            Text("DAY STREAK")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            
            // Personal Best / New Record Message
            if isNewRecord {
                Text("🎉 New best!")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            } else {
                Text("Best: \(longestStreak) days")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Stats Section (Right)
    
    private var statsSection: some View {
        VStack(spacing: 8) {
            // Best Plank
            MiniStatCard(
                icon: "star.fill",
                iconColor: .purple,
                title: "Best Plank",
                value: bestPlankTime
            )
            
            // Total Planks
            MiniStatCard(
                icon: "checkmark.circle.fill",
                iconColor: .green,
                title: "Total Planks",
                value: "\(totalPlanks)"
            )
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Mini Stat Card

struct MiniStatCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 10) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(iconColor)
                .frame(width: 24)
            
            // Text
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
        .padding(12)
        .background(Color.softBlueBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Preview

#Preview("Streak Stats Row") {
    ZStack {
        AppBackground()
        
        VStack(spacing: 20) {
            StreakStatsRow(
                currentStreak: 14,
                longestStreak: 21,
                bestPlankTime: "3:45",
                totalPlanks: 127
            )
            .padding(.horizontal, 16)
            
            // New record state
            StreakStatsRow(
                currentStreak: 25,
                longestStreak: 21,
                bestPlankTime: "4:12",
                totalPlanks: 156
            )
            .padding(.horizontal, 16)
            
            Spacer()
        }
        .padding(.top, 20)
    }
}

#Preview("Zero Streak") {
    ZStack {
        AppBackground()
        
        StreakStatsRow(
            currentStreak: 0,
            longestStreak: 14,
            bestPlankTime: "2:30",
            totalPlanks: 45
        )
        .padding(16)
    }
}
