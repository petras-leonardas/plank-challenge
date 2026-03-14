//
//  AnimationsShowcase.swift
//  PlankChallenge
//
//  Design System - Animation components showcase
//

import SwiftUI

struct AnimationsShowcase: View {
    @State private var showLavaBubbles = false
    @State private var showActivePlank = false
    @State private var showCelebration = false
    @State private var animatedFlameActive = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                
                // MARK: - Pulsing Glow
                ShowcaseSectionHeader("Pulsing Glow", icon: "rays")
                
                ComponentShowcase(
                    "pulsingGlow Modifier",
                    description: "Ambient glow effect for the plank button",
                    code: """
                    Circle()
                        .pulsingGlow(
                            color: .plankButtonGlow,
                            isAnimating: true
                        )
                    """
                ) {
                    HStack(spacing: 40) {
                        VStack {
                            Circle()
                                .fill(Color.plankButtonInner)
                                .frame(width: 80, height: 80)
                                .pulsingGlow(color: .plankButtonGlow, isAnimating: true)
                            Text("Animating")
                                .font(.caption)
                        }
                        
                        VStack {
                            Circle()
                                .fill(Color.plankButtonInner)
                                .frame(width: 80, height: 80)
                                .pulsingGlow(color: .plankButtonGlow, isAnimating: false)
                            Text("Static")
                                .font(.caption)
                        }
                    }
                    .padding(.vertical, 20)
                }
                
                // MARK: - Animated Flame
                ShowcaseSectionHeader("Animated Flame", icon: "flame")
                
                ComponentShowcase(
                    "AnimatedFlameIcon",
                    description: "Flickering flame for protected streak",
                    code: """
                    AnimatedFlameIcon(isAnimating: true)
                    AnimatedFlameIcon(isAnimating: false)
                    """
                ) {
                    HStack(spacing: 40) {
                        VStack {
                            AnimatedFlameIcon(isAnimating: true)
                                .font(.system(size: 40))
                            Text("Protected")
                                .font(.caption)
                        }
                        
                        VStack {
                            AnimatedFlameIcon(isAnimating: false)
                                .font(.system(size: 40))
                            Text("Not Protected")
                                .font(.caption)
                        }
                    }
                    .padding(.vertical, 20)
                }
                
                // MARK: - Streak Hero
                ShowcaseSectionHeader("Streak Hero", icon: "star")
                
                ComponentShowcase(
                    "StreakHeroView",
                    description: "Animated streak display with pulsing flame",
                    code: """
                    StreakHeroView(
                        currentStreak: 14,
                        longestStreak: 21
                    )
                    """
                ) {
                    VStack(spacing: 20) {
                        StreakHeroView(currentStreak: 14, longestStreak: 21)
                        
                        Divider()
                        
                        // Personal best - current equals longest
                        StreakHeroView(currentStreak: 21, longestStreak: 21)
                    }
                }
                
                // MARK: - Blue Flame Animation
                ShowcaseSectionHeader("Calendar Flame", icon: "calendar")
                
                ComponentShowcase(
                    "BlueFlameIcon",
                    description: "Static flame for calendar days",
                    code: """
                    BlueFlameIcon(size: 20)
                    """
                ) {
                    HStack(spacing: 8) {
                        ForEach(0..<7) { _ in
                            BlueFlameIcon(size: 20)
                        }
                    }
                }
                
                // MARK: - Interactive Demos
                ShowcaseSectionHeader("Interactive Demos", icon: "play.circle")
                
                ComponentShowcase(
                    "Lava Bubbles",
                    description: "Celebration effect - tap to preview",
                    code: """
                    LavaBubblesView(
                        isCountdown: false,
                        isActive: true
                    )
                    """
                ) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(LinearGradient.plankGradient)
                            .frame(height: 200)
                        
                        if showLavaBubbles {
                            LavaBubblesView(isCountdown: false, isActive: true)
                        }
                        
                        Button(showLavaBubbles ? "Reset" : "Show Bubbles") {
                            if showLavaBubbles {
                                showLavaBubbles = false
                            } else {
                                showLavaBubbles = true
                                // Auto-reset after animation
                                DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                                    showLavaBubbles = false
                                }
                            }
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Capsule())
                    }
                }
                
                ComponentShowcase(
                    "Active Plank Ring",
                    description: "Ripple effect during active plank - tap to preview",
                    code: """
                    ActivePlankRing(buttonSize: 150)
                    """
                ) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(LinearGradient.plankGradient)
                            .frame(height: 200)
                        
                        ZStack {
                            if showActivePlank {
                                ActivePlankRing(buttonSize: 100)
                            }
                            
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [.plankButtonInner, .plankButtonGlow],
                                        center: .center,
                                        startRadius: 0,
                                        endRadius: 50
                                    )
                                )
                                .frame(width: 100, height: 100)
                        }
                        
                        VStack {
                            Spacer()
                            Button(showActivePlank ? "Stop" : "Start Ring") {
                                showActivePlank.toggle()
                            }
                            .font(.caption)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Capsule())
                            .padding(.bottom, 12)
                        }
                    }
                }
                
                ComponentShowcase(
                    "Celebration Overlay",
                    description: "Flash and particles on plank completion",
                    code: """
                    CelebrationOverlayView(isActive: true)
                    """
                ) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(LinearGradient.plankGradient)
                            .frame(height: 200)
                        
                        if showCelebration {
                            CelebrationOverlayView(isActive: true)
                        }
                        
                        Button(showCelebration ? "Reset" : "Celebrate!") {
                            if showCelebration {
                                showCelebration = false
                            } else {
                                showCelebration = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    showCelebration = false
                                }
                            }
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Capsule())
                    }
                }
                
                // MARK: - Animation Timing
                ShowcaseSectionHeader("Timing Reference", icon: "clock")
                
                ComponentShowcase(
                    "Animation Durations",
                    description: "Standard timing values used across the app"
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        TimingRow(name: "Button press", duration: "0.1s")
                        TimingRow(name: "Pulsing glow cycle", duration: "1.5s")
                        TimingRow(name: "Celebration flash", duration: "0.15s in / 0.5s out")
                        TimingRow(name: "Lava bubble rise", duration: "8-12s")
                        TimingRow(name: "Active ring expansion", duration: "6-9s")
                        TimingRow(name: "State transitions", duration: "0.3-0.4s")
                    }
                }
                
                Spacer(minLength: 40)
            }
        }
        .navigationTitle("Animations")
        .background(Color(.systemGroupedBackground))
    }
}

struct TimingRow: View {
    let name: String
    let duration: String
    
    var body: some View {
        HStack {
            Text(name)
                .font(.subheadline)
            Spacer()
            Text(duration)
                .font(.caption)
                .fontDesign(.monospaced)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack {
        AnimationsShowcase()
    }
}
