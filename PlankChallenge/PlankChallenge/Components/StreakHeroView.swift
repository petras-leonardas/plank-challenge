//
//  StreakHeroView.swift
//  PlankChallenge
//
//  A prominent, animated streak display with a pulsing flame icon.
//  Designed to be the hero element at the top of the Progress page.
//

import SwiftUI

struct StreakHeroView: View {
    let currentStreak: Int
    let longestStreak: Int
    
    @State private var isPulsing = false
    
    /// Whether the user has achieved a new personal best
    private var isNewRecord: Bool {
        currentStreak >= longestStreak && currentStreak > 0
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Animated Flame Icon
            ZStack {
                // Glow effect (behind the flame)
                Image(systemName: "flame.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.plankButtonInner, Color.plankGradientEnd],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .blur(radius: isPulsing ? 20 : 12)
                    .opacity(isPulsing ? 0.6 : 0.3)
                    .scaleEffect(isPulsing ? 1.2 : 1.0)
                
                // Main flame icon
                Image(systemName: "flame.fill")
                    .font(.system(size: 60))
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
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            
            // "DAY STREAK" Label
            Text(currentStreak == 1 ? "DAY STREAK" : "DAY STREAK")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            
            // Personal Best / New Record Message
            if isNewRecord {
                Text("🎉 New personal best!")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(.top, 4)
            } else {
                Text("Personal best: \(longestStreak) days")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}

// MARK: - Preview

#Preview("Normal Streak") {
    ZStack {
        AppBackground()
        
        VStack {
            StreakHeroView(
                currentStreak: 14,
                longestStreak: 21
            )
            
            Spacer()
        }
        .padding()
    }
}

#Preview("New Record") {
    ZStack {
        AppBackground()
        
        VStack {
            StreakHeroView(
                currentStreak: 25,
                longestStreak: 21
            )
            
            Spacer()
        }
        .padding()
    }
}

#Preview("Zero Streak") {
    ZStack {
        AppBackground()
        
        VStack {
            StreakHeroView(
                currentStreak: 0,
                longestStreak: 14
            )
            
            Spacer()
        }
        .padding()
    }
}
