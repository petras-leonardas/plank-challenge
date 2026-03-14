//
//  ColorsShowcase.swift
//  PlankChallenge
//
//  Design System - Color palette showcase
//

import SwiftUI

struct ColorsShowcase: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                
                // MARK: - App Colors (Basic)
                ShowcaseSectionHeader("App Colors", icon: "paintbrush")
                
                ComponentShowcase(
                    "Primary Colors",
                    description: "Core app colors for key UI elements",
                    code: """
                    Color.appAccent     // Primary accent
                    Color.streakColor   // Streak indicators
                    Color.successColor  // Success states
                    Color.warningColor  // Warning states
                    Color.errorColor    // Error states
                    """
                ) {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ColorSwatch("appAccent", color: .appAccent, hex: "System Blue")
                        ColorSwatch("streakColor", color: .streakColor, hex: "System Orange")
                        ColorSwatch("successColor", color: .successColor, hex: "System Green")
                        ColorSwatch("warningColor", color: .warningColor, hex: "System Yellow")
                        ColorSwatch("errorColor", color: .errorColor, hex: "System Red")
                    }
                }
                
                // MARK: - Soft Blue Palette
                ShowcaseSectionHeader("Soft Blue Palette", icon: "drop")
                
                ComponentShowcase(
                    "Background Colors",
                    description: "Unified soft blue theme for app backgrounds",
                    code: """
                    Color.softBlueBackground  // Main page background
                    Color.warmWhiteCard       // Card backgrounds
                    """
                ) {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ColorSwatch("softBlueBackground", color: .softBlueBackground, hex: "RGB(240, 245, 251)")
                        ColorSwatch("warmWhiteCard", color: .warmWhiteCard, hex: "RGB(250, 251, 253)")
                    }
                }
                
                ComponentShowcase(
                    "Gradient Colors",
                    description: "Colors for subtle background gradients",
                    code: """
                    Color.subtleBlueGradientStart  // Top of secondary screens
                    Color.subtleBlueGradientEnd    // Matches softBlueBackground
                    """
                ) {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ColorSwatch("subtleBlueGradientStart", color: .subtleBlueGradientStart, hex: "RGB(229, 238, 250)")
                        ColorSwatch("subtleBlueGradientEnd", color: .subtleBlueGradientEnd, hex: "RGB(240, 245, 251)")
                    }
                }
                
                // MARK: - Plank Screen Colors
                ShowcaseSectionHeader("Plank Screen", icon: "timer")
                
                ComponentShowcase(
                    "Plank Timer Colors",
                    description: "Shazam-inspired deep blue gradient for the timer screen",
                    code: """
                    Color.plankGradientStart  // Deep dark blue
                    Color.plankGradientEnd    // Electric blue
                    Color.plankButtonGlow     // Button glow effect
                    Color.plankButtonInner    // Button inner color
                    """
                ) {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ColorSwatch("plankGradientStart", color: .plankGradientStart, hex: "RGB(10, 22, 40)")
                        ColorSwatch("plankGradientEnd", color: .plankGradientEnd, hex: "RGB(0, 102, 255)")
                        ColorSwatch("plankButtonGlow", color: .plankButtonGlow, hex: "RGB(0, 150, 255)")
                        ColorSwatch("plankButtonInner", color: .plankButtonInner, hex: "RGB(30, 120, 255)")
                    }
                }
                
                // MARK: - Gradients
                ShowcaseSectionHeader("Gradients", icon: "square.stack.3d.down.right")
                
                ComponentShowcase(
                    "Plank Gradient",
                    description: "Full screen gradient for timer screen",
                    code: """
                    LinearGradient.plankGradient
                        .ignoresSafeArea()
                    """
                ) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(LinearGradient.plankGradient)
                        .frame(height: 120)
                }
                
                ComponentShowcase(
                    "Subtle Blue Gradient",
                    description: "Background gradient for Progress, Groups, Profile screens",
                    code: """
                    LinearGradient.subtleBlueGradient
                        .ignoresSafeArea()
                    """
                ) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(LinearGradient.subtleBlueGradient)
                        .frame(height: 120)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                }
                
                ComponentShowcase(
                    "Avatar Gradient",
                    description: "Pink to magenta gradient for current user avatars",
                    code: """
                    LinearGradient.avatarGradient
                    """
                ) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(LinearGradient.avatarGradient)
                        .frame(height: 80)
                }
                
                // MARK: - Discover Card Colors
                ShowcaseSectionHeader("Discover Cards", icon: "rectangle.stack")
                
                ComponentShowcase(
                    "Card Accent Colors",
                    description: "Vibrant gradients for discover section cards",
                    code: """
                    Color.discoverBlueStart / .discoverBlueEnd
                    Color.discoverOrangeStart / .discoverOrangeEnd
                    Color.discoverPurpleStart / .discoverPurpleEnd
                    """
                ) {
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                LinearGradient(
                                    colors: [.discoverBlueStart, .discoverBlueEnd],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(height: 60)
                            .overlay(Text("Blue").foregroundStyle(.white).font(.caption))
                        
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                LinearGradient(
                                    colors: [.discoverOrangeStart, .discoverOrangeEnd],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(height: 60)
                            .overlay(Text("Orange").foregroundStyle(.white).font(.caption))
                        
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                LinearGradient(
                                    colors: [.discoverPurpleStart, .discoverPurpleEnd],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(height: 60)
                            .overlay(Text("Purple").foregroundStyle(.white).font(.caption))
                    }
                }
                
                Spacer(minLength: 40)
            }
        }
        .navigationTitle("Colors")
        .background(Color(.systemGroupedBackground))
    }
}

#Preview {
    NavigationStack {
        ColorsShowcase()
    }
}
