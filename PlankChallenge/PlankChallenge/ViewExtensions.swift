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
    
    /// Plank gradient start (deep dark blue) — fixed top color, never changes
    static let plankGradientStart = Color(red: 10/255, green: 22/255, blue: 40/255)
    
    /// Plank gradient end (electric blue) — phase 0 bottom color
    static let plankGradientEnd = Color(red: 0/255, green: 102/255, blue: 255/255)
    
    /// Plank button glow color — phase 0 glow
    static let plankButtonGlow = Color(red: 0/255, green: 150/255, blue: 255/255)
    
    /// Plank button inner color — phase 0 inner
    static let plankButtonInner = Color(red: 30/255, green: 120/255, blue: 255/255)
    
    // MARK: - Plank Gradient Phase Palette
    // 6 phases cycling through blue-family hues. Top color is always plankGradientStart.
    // Each phase has a bottom gradient color and a matching button glow color (lighter/brighter).
    
    /// Bottom gradient colors for each phase (top is always plankGradientStart)
    static let plankPhaseBottomColors: [Color] = [
        Color(red:   0/255, green: 102/255, blue: 255/255), // Phase 0: Electric blue  #0066FF
        Color(red:  43/255, green:   0/255, blue: 255/255), // Phase 1: Royal indigo   #2B00FF
        Color(red:  68/255, green:  34/255, blue: 204/255), // Phase 2: Cobalt violet  #4422CC
        Color(red:   0/255, green:  51/255, blue: 128/255), // Phase 3: Deep sapphire  #003380
        Color(red:   0/255, green: 102/255, blue: 153/255), // Phase 4: Ocean teal     #006699
        Color(red:   0/255, green: 153/255, blue: 204/255), // Phase 5: Cyan-teal      #0099CC
    ]
    
    /// Button glow colors for each phase — lighter/brighter version tracking the bottom hue
    static let plankPhaseGlowColors: [Color] = [
        Color(red:   0/255, green: 150/255, blue: 255/255), // Phase 0: Sky blue       #0096FF
        Color(red: 102/255, green:  68/255, blue: 255/255), // Phase 1: Light indigo   #6644FF
        Color(red: 119/255, green:  85/255, blue: 255/255), // Phase 2: Soft violet    #7755FF
        Color(red:  30/255, green: 120/255, blue: 255/255), // Phase 3: Mid blue       #1E78FF
        Color(red:   0/255, green: 170/255, blue: 204/255), // Phase 4: Bright teal    #00AACC
        Color(red:  51/255, green: 187/255, blue: 238/255), // Phase 5: Light cyan     #33BBEE
    ]
    
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
    
    // MARK: - Rank Colors (Leaderboard)
    
    /// Gold rank badge color (rank #1)
    static let rankGold = Color.yellow
    
    /// Silver rank badge color (rank #2)
    static let rankSilver = Color(red: 192/255, green: 192/255, blue: 192/255)
    
    /// Bronze rank badge color (rank #3)
    static let rankBronze = Color(red: 205/255, green: 127/255, blue: 50/255)
    
    // MARK: - Overlay / Scrim
    
    /// Standard dark overlay for modals and loading screens
    static let overlayScrim = Color.black.opacity(0.3)
    
    // MARK: - Stat Card Background
    
    /// Soft background for inline stat boxes (inside cards)
    static let statCardBackground = Color(red: 240/255, green: 245/255, blue: 251/255) // same as softBlueBackground
    
    // MARK: - Plank Type Colors
    
    static func colorForPlankType(_ type: Constants.Plank.PlankType) -> Color {
        switch type {
        case .elbow:
            return .blue
        case .high:
            return .green
        case .sideLeft:
            return .orange
        case .sideRight:
            return .orange
        case .reverse:
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

// MARK: - Time Formatting

extension TimeInterval {
    /// Formats a plank duration as "mm:ss" (e.g. "01:05", "00:30")
    var formattedPlankTime: String {
        let minutes = Int(self) / 60
        let seconds = Int(self) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Navigation Bar Style

extension View {
    /// Applies the standard app navigation bar background tint.
    /// Use on the outermost `NavigationStack` or embedded view.
    func appNavigationBarStyle() -> some View {
        self.toolbarBackground(Color.subtleBlueGradientStart.opacity(0.5), for: .navigationBar)
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
