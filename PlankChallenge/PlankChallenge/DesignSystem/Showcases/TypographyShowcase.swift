//
//  TypographyShowcase.swift
//  PlankChallenge
//
//  Design System - Typography showcase
//

import SwiftUI

struct TypographyShowcase: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                
                // MARK: - System Fonts
                ShowcaseSectionHeader("System Font Scale", icon: "textformat.size")
                
                ComponentShowcase(
                    "Font Hierarchy",
                    description: "SwiftUI built-in font styles",
                    code: """
                    .font(.largeTitle)
                    .font(.title)
                    .font(.title2)
                    .font(.title3)
                    .font(.headline)
                    .font(.body)
                    .font(.subheadline)
                    .font(.caption)
                    .font(.caption2)
                    """
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        TypographySample(name: ".largeTitle", font: .largeTitle, description: "34pt, Regular")
                        TypographySample(name: ".title", font: .title, description: "28pt, Regular")
                        TypographySample(name: ".title2", font: .title2, description: "22pt, Regular")
                        TypographySample(name: ".title3", font: .title3, description: "20pt, Regular")
                        TypographySample(name: ".headline", font: .headline, description: "17pt, Semibold")
                        TypographySample(name: ".body", font: .body, description: "17pt, Regular")
                        TypographySample(name: ".subheadline", font: .subheadline, description: "15pt, Regular")
                        TypographySample(name: ".caption", font: .caption, description: "12pt, Regular")
                        TypographySample(name: ".caption2", font: .caption2, description: "11pt, Regular")
                    }
                }
                
                // MARK: - Custom Sizes
                ShowcaseSectionHeader("Custom Sizes", icon: "ruler")
                
                ComponentShowcase(
                    "Streak Number (Hero)",
                    description: "Large bold numbers for streak display",
                    code: """
                    Text("14")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                    """
                ) {
                    HStack(spacing: 24) {
                        VStack {
                            Text("14")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                            Text("48pt Hero")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        VStack {
                            Text("14")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                            Text("36pt Compact")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        VStack {
                            Text("14")
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                            Text("34pt Stat")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                ComponentShowcase(
                    "Timer Display",
                    description: "Monospaced font for timer readability",
                    code: """
                    Text("00:45.23")
                        .font(.system(size: 44, weight: .bold, design: .monospaced))
                    """
                ) {
                    VStack(spacing: 16) {
                        Text("00:45.23")
                            .font(.system(size: 44, weight: .bold, design: .monospaced))
                        
                        Text("00:45")
                            .font(.system(size: 28, weight: .bold, design: .monospaced))
                    }
                }
                
                // MARK: - Font Weights
                ShowcaseSectionHeader("Font Weights", icon: "bold")
                
                ComponentShowcase(
                    "Weight Variations",
                    description: "Different font weights for emphasis",
                    code: """
                    .fontWeight(.regular)
                    .fontWeight(.medium)
                    .fontWeight(.semibold)
                    .fontWeight(.bold)
                    """
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Regular weight").fontWeight(.regular)
                        Text("Medium weight").fontWeight(.medium)
                        Text("Semibold weight").fontWeight(.semibold)
                        Text("Bold weight").fontWeight(.bold)
                    }
                    .font(.body)
                }
                
                // MARK: - Font Designs
                ShowcaseSectionHeader("Font Designs", icon: "character")
                
                ComponentShowcase(
                    "Design Variations",
                    description: "Different font designs for specific contexts",
                    code: """
                    .fontDesign(.default)
                    .fontDesign(.rounded)
                    .fontDesign(.monospaced)
                    """
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Default Design 123")
                                .font(.title2)
                                .fontDesign(.default)
                            Text("Body text, general UI")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Rounded Design 123")
                                .font(.title2)
                                .fontDesign(.rounded)
                            Text("Stats, numbers, friendly elements")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Monospaced Design 123")
                                .font(.title2)
                                .fontDesign(.monospaced)
                            Text("Timers, code, tabular data")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                // MARK: - Text Styles in Context
                ShowcaseSectionHeader("In Context", icon: "doc.text")
                
                ComponentShowcase(
                    "Section Header Pattern",
                    description: "Typical section header with title and action",
                    code: """
                    HStack {
                        Text("Recent Planks")
                            .font(.headline)
                        Spacer()
                        Text("See All")
                            .font(.subheadline)
                            .foregroundStyle(.blue)
                    }
                    """
                ) {
                    HStack {
                        Text("Recent Planks")
                            .font(.headline)
                        Spacer()
                        Text("See All")
                            .font(.subheadline)
                            .foregroundStyle(.blue)
                    }
                }
                
                ComponentShowcase(
                    "Stat Card Pattern",
                    description: "Value + label hierarchy",
                    code: """
                    VStack(spacing: 4) {
                        Text("14")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                        Text("Day Streak")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    """
                ) {
                    HStack(spacing: 32) {
                        VStack(spacing: 4) {
                            Text("14")
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                            Text("Day Streak")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        VStack(spacing: 4) {
                            Text("2:45")
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                            Text("Best Time")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Spacer(minLength: 40)
            }
        }
        .navigationTitle("Typography")
        .background(Color(.systemGroupedBackground))
    }
}

#Preview {
    NavigationStack {
        TypographyShowcase()
    }
}
