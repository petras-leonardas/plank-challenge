//
//  SectionHeader.swift
//  PlankChallenge
//
//  Created by Leo Bacevicius on 14/03/2026.
//

import SwiftUI

/// A unified section header component used throughout the app.
/// Uses Title case styling (e.g., "Badges", "Recent Planks")
struct SectionHeader<Destination: View>: View {
    let title: String
    var actionLabel: String = "See All"
    var destination: (() -> Destination)? = nil
    var action: (() -> Void)? = nil
    
    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
            
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

/// A simpler section header without navigation/action
struct SimpleSectionHeader: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(.headline)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Convenience Initializers

extension SectionHeader where Destination == EmptyView {
    /// Creates a section header with just a title (no action)
    init(title: String) {
        self.title = title
        self.actionLabel = ""
        self.destination = nil
        self.action = nil
    }
    
    /// Creates a section header with a title and action closure
    init(title: String, actionLabel: String = "See All", action: @escaping () -> Void) {
        self.title = title
        self.actionLabel = actionLabel
        self.destination = nil
        self.action = action
    }
}

// MARK: - Previews

#Preview("With Navigation") {
    NavigationStack {
        VStack(spacing: 20) {
            SectionHeader(title: "Badges", actionLabel: "See All") {
                Text("All Badges")
            }
            .padding(.horizontal)
            
            SectionHeader(title: "Recent Planks", actionLabel: "View History") {
                Text("History")
            }
            .padding(.horizontal)
        }
    }
}

#Preview("With Action") {
    VStack(spacing: 20) {
        SectionHeader(title: "My Groups", actionLabel: "See All") {
            print("Tapped See All")
        }
        .padding(.horizontal)
    }
}

#Preview("Simple") {
    VStack(spacing: 20) {
        SimpleSectionHeader(title: "Your Stats")
            .padding(.horizontal)
        
        SectionHeader<EmptyView>(title: "Members")
            .padding(.horizontal)
    }
}
