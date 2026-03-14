//
//  AvatarsShowcase.swift
//  PlankChallenge
//
//  Design System - Avatar component showcase
//

import SwiftUI

struct AvatarsShowcase: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                
                // MARK: - Avatar Sizes
                ShowcaseSectionHeader("Sizes", icon: "person.crop.circle")
                
                ComponentShowcase(
                    "Size Variations",
                    description: "AvatarView adapts font size based on container size",
                    code: """
                    AvatarView("John Doe", size: 32)
                    AvatarView("John Doe", size: 44)
                    AvatarView("John Doe", size: 72)
                    AvatarView("John Doe", size: 100)
                    """
                ) {
                    HStack(spacing: 16) {
                        VStack {
                            AvatarView("John Doe", size: 32)
                            Text("32pt")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        
                        VStack {
                            AvatarView("John Doe", size: 44)
                            Text("44pt")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        
                        VStack {
                            AvatarView("John Doe", size: 72)
                            Text("72pt")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        
                        VStack {
                            AvatarView("John Doe", size: 100)
                            Text("100pt")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                // MARK: - Avatar Styles
                ShowcaseSectionHeader("Styles", icon: "paintbrush")
                
                ComponentShowcase(
                    "Standard Style",
                    description: "Default gray background with secondary text",
                    code: """
                    AvatarView("John Doe", size: 60)
                    // or
                    AvatarView("John Doe", size: 60, style: .standard)
                    """
                ) {
                    HStack(spacing: 24) {
                        AvatarView("Alice Brown", size: 60)
                        AvatarView("Bob Smith", size: 60)
                        AvatarView("Carol White", size: 60)
                    }
                }
                
                ComponentShowcase(
                    "Gradient Style",
                    description: "Pink-to-magenta gradient for current user",
                    code: """
                    AvatarView.gradient(name: "Leo Bacevicius", size: 60)
                    // or
                    AvatarView("Leo", size: 60, style: .gradient)
                    """
                ) {
                    HStack(spacing: 24) {
                        AvatarView.gradient(name: "Leo Bacevicius", size: 60)
                        AvatarView.gradient(name: "Current User", size: 60)
                        AvatarView.gradient(name: "Me", size: 60)
                    }
                }
                
                ComponentShowcase(
                    "Accent Style",
                    description: "Blue accent color background",
                    code: """
                    AvatarView.accent(name: "Featured User", size: 60)
                    // or
                    AvatarView("User", size: 60, style: .accent)
                    """
                ) {
                    HStack(spacing: 24) {
                        AvatarView.accent(name: "Featured", size: 60)
                        AvatarView.accent(name: "Admin", size: 60)
                        AvatarView.accent(name: "VIP", size: 60)
                    }
                }
                
                // MARK: - Initials Generation
                ShowcaseSectionHeader("Initials", icon: "textformat")
                
                ComponentShowcase(
                    "Automatic Initials",
                    description: "Extracts first letter of first and last name",
                    code: """
                    AvatarView("John Doe")     // "JD"
                    AvatarView("Alice")        // "A"
                    AvatarView("Bob C. Smith") // "BS"
                    """
                ) {
                    HStack(spacing: 16) {
                        VStack {
                            AvatarView("John Doe", size: 50)
                            Text("John Doe")
                                .font(.caption)
                        }
                        
                        VStack {
                            AvatarView("Alice", size: 50)
                            Text("Alice")
                                .font(.caption)
                        }
                        
                        VStack {
                            AvatarView("Bob C. Smith", size: 50)
                            Text("Bob C. Smith")
                                .font(.caption)
                        }
                        
                        VStack {
                            AvatarView("", size: 50)
                            Text("(empty)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                // MARK: - In Context
                ShowcaseSectionHeader("In Context", icon: "person.2")
                
                ComponentShowcase(
                    "User Row",
                    description: "Avatar in a typical list row context",
                    code: """
                    HStack(spacing: 12) {
                        AvatarView(user.name, size: 44)
                        VStack(alignment: .leading) {
                            Text(user.name)
                            Text(user.username)
                        }
                    }
                    """
                ) {
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            AvatarView.gradient(name: "Leo Bacevicius", size: 44)
                            VStack(alignment: .leading) {
                                Text("Leo Bacevicius")
                                    .font(.body)
                                Text("@leo")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        
                        Divider()
                        
                        HStack(spacing: 12) {
                            AvatarView("Sarah Connor", size: 44)
                            VStack(alignment: .leading) {
                                Text("Sarah Connor")
                                    .font(.body)
                                Text("@sarah")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }
                }
                
                Spacer(minLength: 40)
            }
        }
        .navigationTitle("Avatars")
        .background(Color(.systemGroupedBackground))
    }
}

#Preview {
    NavigationStack {
        AvatarsShowcase()
    }
}
