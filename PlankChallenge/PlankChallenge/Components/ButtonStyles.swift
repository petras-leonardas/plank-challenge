//
//  ButtonStyles.swift
//  PlankChallenge
//
//  Unified button styles for the app
//

import SwiftUI

// MARK: - Onboarding Primary Button Style

/// White-background, accent-foreground full-width button used on dark gradient onboarding screens.
/// Height: 56pt. Corner radius: `Constants.UI.sheetRadius` (16). Horizontal padding managed by the call site.
struct OnboardingPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundStyle(Color.appAccent)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: Constants.UI.sheetRadius))
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Primary Button Style

/// Full-width primary action button with blue background
/// Use for main CTAs like "Save", "Continue", "Start"
struct PrimaryButtonStyle: ButtonStyle {
    var isEnabled: Bool = true
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                isEnabled
                    ? Color.appAccent.opacity(configuration.isPressed ? 0.8 : 1.0)
                    : Color.gray.opacity(0.3)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Secondary Button Style

/// Outlined button with border, transparent background
/// Use for secondary actions like "Cancel", "Skip"
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .fontWeight(.medium)
            .foregroundStyle(Color.appAccent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.appAccent.opacity(0.3), lineWidth: 1.5)
            )
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Destructive Button Style

/// Red button for destructive actions
/// Use for "Delete", "Leave Group", "Remove"
struct DestructiveButtonStyle: ButtonStyle {
    var filled: Bool = true
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundStyle(filled ? .white : Color.errorColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                Group {
                    if filled {
                        Color.errorColor.opacity(configuration.isPressed ? 0.8 : 1.0)
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.errorColor.opacity(0.3), lineWidth: 1.5)
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Pill Button Style

/// Compact pill-shaped button
/// Use for tags, filter chips, small actions
struct PillButtonStyle: ButtonStyle {
    var isSelected: Bool = false
    var color: Color = .appAccent
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundStyle(isSelected ? .white : color)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                isSelected
                    ? color.opacity(configuration.isPressed ? 0.8 : 1.0)
                    : color.opacity(configuration.isPressed ? 0.15 : 0.1)
            )
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Success Button Style

/// Green button for positive/success actions
/// Use for "Save Plank", "Complete", "Confirm"
struct SuccessButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.successColor.opacity(configuration.isPressed ? 0.8 : 1.0))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Text Button Style

/// Plain text button (like "Discard", "Forgot Password")
/// Use for tertiary actions
struct TextButtonStyle: ButtonStyle {
    var color: Color = .secondary
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundStyle(color)
            .opacity(configuration.isPressed ? 0.6 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Icon Button Style

/// Circular button with icon
/// Use for toolbar actions, small icon buttons
struct IconButtonStyle: ButtonStyle {
    var size: CGFloat = 44
    var backgroundColor: Color = Color.gray.opacity(0.1)
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: size, height: size)
            .background(backgroundColor.opacity(configuration.isPressed ? 0.2 : 1.0))
            .clipShape(Circle())
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Plank Button Style

/// Scale-down press effect for the main plank circle button
/// Provides subtle tactile feedback without changing the button's appearance
struct PlankButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Button Extensions

extension View {
    /// Apply primary button styling
    func primaryButtonStyle(isEnabled: Bool = true) -> some View {
        self.buttonStyle(PrimaryButtonStyle(isEnabled: isEnabled))
    }
    
    /// Apply secondary button styling
    func secondaryButtonStyle() -> some View {
        self.buttonStyle(SecondaryButtonStyle())
    }
    
    /// Apply destructive button styling
    func destructiveButtonStyle(filled: Bool = true) -> some View {
        self.buttonStyle(DestructiveButtonStyle(filled: filled))
    }
    
    /// Apply pill button styling
    func pillButtonStyle(isSelected: Bool = false, color: Color = .appAccent) -> some View {
        self.buttonStyle(PillButtonStyle(isSelected: isSelected, color: color))
    }
    
    /// Apply success button styling
    func successButtonStyle() -> some View {
        self.buttonStyle(SuccessButtonStyle())
    }
    
    /// Apply text button styling
    func textButtonStyle(color: Color = .secondary) -> some View {
        self.buttonStyle(TextButtonStyle(color: color))
    }
}

// MARK: - Preview

#Preview("Button Styles") {
    ScrollView {
        VStack(spacing: 24) {
            // Primary
            VStack(alignment: .leading, spacing: 8) {
                Text("Primary Button")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Button("Continue") {}
                    .buttonStyle(PrimaryButtonStyle())
                
                Button("Disabled") {}
                    .buttonStyle(PrimaryButtonStyle(isEnabled: false))
            }
            
            // Secondary
            VStack(alignment: .leading, spacing: 8) {
                Text("Secondary Button")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Button("Cancel") {}
                    .buttonStyle(SecondaryButtonStyle())
            }
            
            // Destructive
            VStack(alignment: .leading, spacing: 8) {
                Text("Destructive Button")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Button("Delete") {}
                    .buttonStyle(DestructiveButtonStyle())
                
                Button("Remove") {}
                    .buttonStyle(DestructiveButtonStyle(filled: false))
            }
            
            // Success
            VStack(alignment: .leading, spacing: 8) {
                Text("Success Button")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Button("Save Plank") {}
                    .buttonStyle(SuccessButtonStyle())
            }
            
            // Pill
            VStack(alignment: .leading, spacing: 8) {
                Text("Pill Buttons")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                HStack {
                    Button("All") {}
                        .buttonStyle(PillButtonStyle(isSelected: true))
                    
                    Button("Following") {}
                        .buttonStyle(PillButtonStyle(isSelected: false))
                    
                    Button("Groups") {}
                        .buttonStyle(PillButtonStyle(isSelected: false))
                }
            }
            
            // Text
            VStack(alignment: .leading, spacing: 8) {
                Text("Text Button")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Button("Discard") {}
                    .buttonStyle(TextButtonStyle())
            }
            
            // Icon
            VStack(alignment: .leading, spacing: 8) {
                Text("Icon Buttons")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 16) {
                    Button {} label: {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .medium))
                    }
                    .buttonStyle(IconButtonStyle())
                    
                    Button {} label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 18, weight: .medium))
                    }
                    .buttonStyle(IconButtonStyle())
                    
                    Button {} label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 18, weight: .medium))
                    }
                    .buttonStyle(IconButtonStyle())
                }
            }
        }
        .padding()
    }
    .background(Color.softBlueBackground)
}
