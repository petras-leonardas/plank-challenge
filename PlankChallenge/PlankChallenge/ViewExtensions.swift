//
//  ViewExtensions.swift
//  PlankChallenge
//
//  Created by Leo Bacevicius on 08/03/2026.
//

import SwiftUI

// MARK: - Card Styles

extension View {
    /// App-wide card style with warm white background and soft shadow
    /// Use this for cards on softBlueBackground
    func appCardStyle() -> some View {
        self
            .padding(16)
            .background(Color.warmWhiteCard)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
    
    /// Compact app card style (less padding)
    func appCardStyleCompact() -> some View {
        self
            .padding(12)
            .background(Color.warmWhiteCard)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
    
    /// Conditional view modifier
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

extension Color {
    // MARK: - App Colors (Apple Health-inspired)
    
    /// Primary accent color
    static let appAccent = Color.blue
    
    /// Streak color (orange/red gradient would be nice)
    static let streakColor = Color.orange
    
    /// Success color
    static let successColor = Color.green
    
    /// Warning color
    static let warningColor = Color.yellow
    
    /// Error color
    static let errorColor = Color.red
    
    // MARK: - Unified App Color Palette (Soft Blue Theme)
    
    /// Soft blue page background - echoes plank screen blue at ~5% opacity
    static let softBlueBackground = Color(red: 240/255, green: 245/255, blue: 251/255)
    
    /// Warm white card background - slightly warmer than pure white
    static let warmWhiteCard = Color(red: 250/255, green: 251/255, blue: 253/255)
    
    /// Subtle blue gradient start - for top of screens
    static let subtleBlueGradientStart = Color(red: 229/255, green: 238/255, blue: 250/255)
    
    /// Subtle blue gradient end - matches softBlueBackground
    static let subtleBlueGradientEnd = Color(red: 240/255, green: 245/255, blue: 251/255)
    
    // MARK: - Supporting Colors
    
    /// Section label color (gray)
    static let sectionLabel = Color(red: 142/255, green: 142/255, blue: 147/255)
    
    /// Teal accent (for freeze tokens, icons)
    static let tealAccent = Color(red: 90/255, green: 200/255, blue: 250/255)
    
    // MARK: - Avatar Gradient (for ProfileView)
    
    /// Avatar gradient start (pink)
    static let avatarGradientStart = Color(red: 255/255, green: 140/255, blue: 180/255)
    
    /// Avatar gradient end (magenta)
    static let avatarGradientEnd = Color(red: 220/255, green: 100/255, blue: 160/255)
    
    // MARK: - Plank Screen Colors (Shazam-inspired)
    
    /// Plank gradient start (deep dark blue)
    static let plankGradientStart = Color(red: 10/255, green: 22/255, blue: 40/255)
    
    /// Plank gradient end (electric blue)
    static let plankGradientEnd = Color(red: 0/255, green: 102/255, blue: 255/255)
    
    /// Plank button glow color
    static let plankButtonGlow = Color(red: 0/255, green: 150/255, blue: 255/255)
    
    /// Plank button inner color
    static let plankButtonInner = Color(red: 30/255, green: 120/255, blue: 255/255)
    
    /// Completed button glow color (green)
    static let completedButtonGlow = Color(red: 50/255, green: 200/255, blue: 120/255)
    
    /// Completed button inner color (green)
    static let completedButtonInner = Color(red: 30/255, green: 160/255, blue: 90/255)
    
    // MARK: - Discover Card Colors
    
    /// Discover card blue gradient start
    static let discoverBlueStart = Color(red: 30/255, green: 100/255, blue: 220/255)
    
    /// Discover card blue gradient end
    static let discoverBlueEnd = Color(red: 60/255, green: 160/255, blue: 255/255)
    
    /// Discover card orange gradient start
    static let discoverOrangeStart = Color(red: 255/255, green: 100/255, blue: 50/255)
    
    /// Discover card orange gradient end
    static let discoverOrangeEnd = Color(red: 255/255, green: 180/255, blue: 100/255)
    
    /// Discover card purple gradient start
    static let discoverPurpleStart = Color(red: 120/255, green: 60/255, blue: 200/255)
    
    /// Discover card purple gradient end
    static let discoverPurpleEnd = Color(red: 180/255, green: 100/255, blue: 255/255)
    
    // MARK: - Plank Type Colors
    
    static func colorForPlankType(_ type: Constants.Plank.PlankType) -> Color {
        switch type {
        case .elbow:
            return .blue
        case .straightArm:
            return .green
        case .parallettes:
            return .purple
        }
    }
}

// MARK: - Gradients

extension LinearGradient {
    /// Avatar gradient (pink/magenta) - used in ProfileView
    static let avatarGradient = LinearGradient(
        colors: [Color.avatarGradientStart, Color.avatarGradientEnd],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    /// Plank screen gradient (Shazam-inspired deep blue)
    static let plankGradient = LinearGradient(
        colors: [Color.plankGradientStart, Color.plankGradientEnd],
        startPoint: .top,
        endPoint: .bottom
    )
    
    /// Subtle blue gradient for secondary screens (Progress, Groups, Profile)
    /// Very subtle (5-10% opacity feel) - echoes the plank screen's blue
    static let subtleBlueGradient = LinearGradient(
        colors: [Color.subtleBlueGradientStart, Color.subtleBlueGradientEnd],
        startPoint: .top,
        endPoint: .bottom
    )
}

// MARK: - App Background View

/// A reusable background view with subtle blue gradient at the top
/// Use this as the background for Progress, Groups, Profile screens
struct AppBackground: View {
    var body: some View {
        ZStack {
            // Base soft blue background
            Color.softBlueBackground
                .ignoresSafeArea()
            
            // Subtle gradient at top
            VStack {
                LinearGradient.subtleBlueGradient
                    .frame(height: 200)
                    .ignoresSafeArea(edges: .top)
                
                Spacer()
            }
        }
    }
}

// MARK: - Animations

extension View {
    /// Pulsing glow animation for the plank button
    func pulsingGlow(color: Color, isAnimating: Bool) -> some View {
        self.modifier(PulsingGlowModifier(glowColor: color, isAnimating: isAnimating))
    }
}

struct PulsingGlowModifier: ViewModifier {
    let glowColor: Color
    let isAnimating: Bool
    
    @State private var isPulsing = false
    
    func body(content: Content) -> some View {
        content
            .shadow(color: glowColor.opacity(isPulsing ? 0.8 : 0.3), radius: isPulsing ? 30 : 15)
            .shadow(color: glowColor.opacity(isPulsing ? 0.5 : 0.2), radius: isPulsing ? 50 : 25)
            .onAppear {
                guard isAnimating else { return }
                withAnimation(
                    .easeInOut(duration: 1.5)
                    .repeatForever(autoreverses: true)
                ) {
                    isPulsing = true
                }
            }
            .onChange(of: isAnimating) { _, newValue in
                if newValue {
                    withAnimation(
                        .easeInOut(duration: 1.5)
                        .repeatForever(autoreverses: true)
                    ) {
                        isPulsing = true
                    }
                } else {
                    withAnimation(.easeOut(duration: 0.3)) {
                        isPulsing = false
                    }
                }
            }
    }
}
