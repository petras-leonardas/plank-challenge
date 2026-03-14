//
//  ButtonsShowcase.swift
//  PlankChallenge
//
//  Design System - Button styles showcase
//

import SwiftUI

struct ButtonsShowcase: View {
    @State private var isToggled = false
    @State private var selectedPill: String? = "Week"
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                
                // MARK: - Primary Button
                ShowcaseSectionHeader("Primary Button", icon: "hand.tap")
                
                ComponentShowcase(
                    "Primary Button",
                    description: "Main call-to-action, full width",
                    code: """
                    Button("Start Plank") { }
                        .primaryButtonStyle()
                    """
                ) {
                    VStack(spacing: 12) {
                        Button("Start Plank") { }
                            .primaryButtonStyle()
                        
                        Button("Disabled State") { }
                            .primaryButtonStyle(isEnabled: false)
                    }
                }
                
                // MARK: - Secondary Button
                ShowcaseSectionHeader("Secondary Button", icon: "square.dashed")
                
                ComponentShowcase(
                    "Secondary Button",
                    description: "Outlined style for secondary actions",
                    code: """
                    Button("Cancel") { }
                        .secondaryButtonStyle()
                    """
                ) {
                    VStack(spacing: 12) {
                        Button("Cancel") { }
                            .secondaryButtonStyle()
                        
                        Button("Skip for Now") { }
                            .secondaryButtonStyle()
                    }
                }
                
                // MARK: - Destructive Button
                ShowcaseSectionHeader("Destructive Button", icon: "trash")
                
                ComponentShowcase(
                    "Destructive Buttons",
                    description: "For delete, remove, and dangerous actions",
                    code: """
                    Button("Delete") { }
                        .destructiveButtonStyle(filled: true)
                    
                    Button("Remove") { }
                        .destructiveButtonStyle(filled: false)
                    """
                ) {
                    VStack(spacing: 12) {
                        Button("Delete Plank") { }
                            .destructiveButtonStyle(filled: true)
                        
                        Button("Remove from Group") { }
                            .destructiveButtonStyle(filled: false)
                    }
                }
                
                // MARK: - Success Button
                ShowcaseSectionHeader("Success Button", icon: "checkmark.circle")
                
                ComponentShowcase(
                    "Success Button",
                    description: "For confirmation and save actions",
                    code: """
                    Button("Save") { }
                        .successButtonStyle()
                    """
                ) {
                    Button("Save Changes") { }
                        .successButtonStyle()
                }
                
                // MARK: - Pill Buttons
                ShowcaseSectionHeader("Pill Buttons", icon: "capsule")
                
                ComponentShowcase(
                    "Pill Button (Toggleable)",
                    description: "Compact capsule buttons for filters and tags",
                    code: """
                    Button("Week") { }
                        .pillButtonStyle(isSelected: true)
                    
                    Button("Month") { }
                        .pillButtonStyle(isSelected: false)
                    """
                ) {
                    HStack(spacing: 8) {
                        ForEach(["Week", "Month", "Year"], id: \.self) { period in
                            Button(period) {
                                selectedPill = period
                            }
                            .pillButtonStyle(isSelected: selectedPill == period)
                        }
                    }
                }
                
                ComponentShowcase(
                    "Colored Pills",
                    description: "Pills with custom accent colors",
                    code: """
                    Button("Elbow") { }
                        .pillButtonStyle(isSelected: true, color: .blue)
                    """
                ) {
                    HStack(spacing: 8) {
                        Button("Elbow") { }
                            .pillButtonStyle(isSelected: true, color: .blue)
                        
                        Button("Straight Arm") { }
                            .pillButtonStyle(isSelected: true, color: .green)
                        
                        Button("Parallettes") { }
                            .pillButtonStyle(isSelected: true, color: .purple)
                    }
                }
                
                // MARK: - Text Button
                ShowcaseSectionHeader("Text Button", icon: "text.cursor")
                
                ComponentShowcase(
                    "Text Button",
                    description: "Minimal style for tertiary actions",
                    code: """
                    Button("See All") { }
                        .textButtonStyle()
                    
                    Button("Learn More") { }
                        .textButtonStyle(color: .secondary)
                    """
                ) {
                    HStack(spacing: 24) {
                        Button("See All") { }
                            .textButtonStyle()
                        
                        Button("Learn More") { }
                            .textButtonStyle(color: .secondary)
                        
                        Button("Cancel") { }
                            .textButtonStyle(color: .red)
                    }
                }
                
                // MARK: - Icon Button
                ShowcaseSectionHeader("Icon Button", icon: "square.grid.2x2")
                
                ComponentShowcase(
                    "Icon Buttons",
                    description: "Circular icon buttons for toolbar actions",
                    code: """
                    Button { } label: {
                        Image(systemName: "gear")
                    }
                    .buttonStyle(IconButtonStyle())
                    """
                ) {
                    HStack(spacing: 16) {
                        Button { } label: {
                            Image(systemName: "gear")
                        }
                        .buttonStyle(IconButtonStyle())
                        
                        Button { } label: {
                            Image(systemName: "plus")
                        }
                        .buttonStyle(IconButtonStyle())
                        
                        Button { } label: {
                            Image(systemName: "bell")
                        }
                        .buttonStyle(IconButtonStyle())
                        
                        Button { } label: {
                            Image(systemName: "magnifyingglass")
                        }
                        .buttonStyle(IconButtonStyle())
                    }
                }
                
                // MARK: - Button States
                ShowcaseSectionHeader("Button States", icon: "switch.2")
                
                ComponentShowcase(
                    "Interactive States",
                    description: "Buttons respond to press with scale animation",
                    code: """
                    // All button styles include:
                    // - Press state (scale to 0.98)
                    // - Disabled state (opacity 0.6)
                    """
                ) {
                    VStack(spacing: 12) {
                        Text("Tap the buttons to see press animation")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Button("Press Me") { }
                            .primaryButtonStyle()
                    }
                }
                
                Spacer(minLength: 40)
            }
        }
        .navigationTitle("Buttons")
        .background(Color(.systemGroupedBackground))
    }
}

#Preview {
    NavigationStack {
        ButtonsShowcase()
    }
}
