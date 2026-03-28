//
//  AppSectionHeader.swift
//  PlankChallenge
//
//  Created by Leo Bacevicius on 14/03/2026.
//

import SwiftUI

/// A unified section header component used throughout the app.
///
/// Uses ALL-CAPS caption style matching iOS native section headers (e.g. "YOUR STATS", "MY GROUPS").
/// Pass the title in uppercase — the component does not auto-uppercase.
///
/// Usage examples:
/// ```swift
/// // Title only
/// AppSectionHeader(title: "YOUR STATS")
///
/// // With NavigationLink "See All"
/// AppSectionHeader(title: "EARNED BADGES") { BadgesView() }
///
/// // With action closure "See All"
/// AppSectionHeader(title: "MY GROUPS", actionLabel: "See All") { showAll() }
/// ```
struct AppSectionHeader<Destination: View>: View {
    let title: String
    var actionLabel: String = "See All"
    var destination: (() -> Destination)? = nil
    var action: (() -> Void)? = nil
    
    // Explicit memberwise init to prevent auto-synthesis conflicting with SwiftUI's Section.
    init(
        title: String,
        actionLabel: String = "See All",
        destination: (() -> Destination)? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.actionLabel = actionLabel
        self.destination = destination
        self.action = action
    }
    
    var body: some View {
        HStack {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            if let destination = destination {
                NavigationLink {
                    destination()
                } label: {
                    Text(actionLabel)
                        .font(.subheadline)
                        .foregroundStyle(Color.appAccent)
                }
            } else if let action = action {
                Button {
                    action()
                } label: {
                    Text(actionLabel)
                        .font(.subheadline)
                        .foregroundStyle(Color.appAccent)
                }
            }
        }
    }
}

// MARK: - Convenience Initializers

extension AppSectionHeader where Destination == EmptyView {
    /// Creates a section header with just a title (no action)
    init(title: String) {
        self.title = title
        self.actionLabel = ""
        self.destination = nil
        self.action = nil
    }
    
    /// Creates a section header with a title and action closure.
    /// Use `onAction:` label to disambiguate from SwiftUI's `Section` init.
    init(title: String, actionLabel: String = "See All", onAction: @escaping () -> Void) {
        self.title = title
        self.actionLabel = actionLabel
        self.destination = nil
        self.action = onAction
    }
}

// MARK: - Previews

#Preview("With Navigation") {
    NavigationStack {
        VStack(spacing: 20) {
            AppSectionHeader(title: "EARNED BADGES") {
                Text("All Badges").navigationTitle("Badges")
            }
            .padding(.horizontal)
            
            AppSectionHeader(title: "RECENT PLANKS", actionLabel: "View History") {
                Text("History").navigationTitle("History")
            }
            .padding(.horizontal)
        }
    }
}


#Preview("Title Only") {
    VStack(spacing: 20) {
        AppSectionHeader<EmptyView>(title: "YOUR STATS")
            .padding(.horizontal)
        
        AppSectionHeader<EmptyView>(title: "MEMBERS")
            .padding(.horizontal)
    }
}
