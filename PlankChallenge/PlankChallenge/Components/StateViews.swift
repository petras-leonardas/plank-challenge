//
//  StateViews.swift
//  PlankChallenge
//
//  Shared loading and empty state components used throughout the app.
//  Replaces the dozens of inline VStack(ProgressView + Text) and
//  icon + headline + body patterns scattered across screens.
//

import SwiftUI

// MARK: - Loading View

/// A centred spinner with an optional label.
/// Drop-in replacement for the recurring `VStack { ProgressView(); Text("Loading...") }` pattern.
///
/// Usage:
/// ```swift
/// LoadingView()
/// LoadingView("Loading notifications...")
/// ```
struct LoadingView: View {
    let message: String?
    
    init(_ message: String? = nil) {
        self.message = message
    }
    
    var body: some View {
        VStack(spacing: Constants.UI.itemSpacingMedium) {
            ProgressView()
                .scaleEffect(1.1)
            
            if let message = message {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message ?? "Loading")
    }
}

// MARK: - Empty State View

/// A centred icon + headline + optional body text empty state.
/// Supports an optional primary action button via `actionLabel` + `action` closure.
///
/// Usage:
/// ```swift
/// // Icon + title only
/// EmptyStateView(icon: "bell.slash", title: "No notifications", message: "You're all caught up!")
///
/// // With action button
/// EmptyStateView(
///     icon: "person.2",
///     title: "No friends yet",
///     message: "Follow people to see how you compare!",
///     actionLabel: "Find people"
/// ) { findPeople() }
/// ```
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String?
    let actionLabel: String?
    let onAction: (() -> Void)?
    
    init(
        icon: String,
        title: String,
        message: String? = nil,
        actionLabel: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionLabel = actionLabel
        self.onAction = action
    }
    
    var body: some View {
        VStack(spacing: Constants.UI.itemSpacingMedium) {
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            
            Text(title)
                .font(.headline)
                .multilineTextAlignment(.center)
            
            if let message = message {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            if let actionLabel = actionLabel, let onAction = onAction {
                Button(actionLabel, action: onAction)
                    .pillButtonStyle(isSelected: true)
                    .padding(.top, Constants.UI.itemSpacing)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, Constants.UI.screenPadding)
        .accessibilityElement(children: .combine)
        .accessibilityLabel([title, message].compactMap { $0 }.joined(separator: ". "))
    }
}

// MARK: - Previews

#Preview("Loading") {
    ZStack {
        AppBackground()
        VStack(spacing: 40) {
            LoadingView()
            LoadingView("Loading leaderboard...")
        }
    }
}

#Preview("Empty State") {
    ZStack {
        AppBackground()
        VStack(spacing: 40) {
            EmptyStateView(
                icon: "bell.slash",
                title: "No notifications",
                message: "You're all caught up!"
            )
            
            EmptyStateView(
                icon: "person.2",
                title: "No friends yet",
                message: "Follow people to see how you compare!",
                actionLabel: "Find people"
            ) {
                // action
            }
        }
    }
}
