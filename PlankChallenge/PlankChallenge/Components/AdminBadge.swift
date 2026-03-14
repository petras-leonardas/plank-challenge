//
//  AdminBadge.swift
//  PlankChallenge
//
//  Created by Leo Bacevicius on 14/03/2026.
//

import SwiftUI

/// A small pill badge indicating admin status
struct AdminBadge: View {
    var body: some View {
        Text("Admin")
            .font(.caption)
            .fontWeight(.medium)
            .foregroundStyle(Color.appAccent)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.appAccent.opacity(0.1))
            .clipShape(Capsule())
    }
}

/// A generic pill badge that can be used for various labels
struct PillBadge: View {
    let text: String
    var color: Color = .appAccent
    var style: PillBadgeStyle = .light
    
    enum PillBadgeStyle {
        case light  // Light background, colored text
        case solid  // Solid colored background, white text
    }
    
    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundStyle(style == .light ? color : .white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(style == .light ? color.opacity(0.1) : color)
            .clipShape(Capsule())
    }
}

// MARK: - Previews

#Preview("Admin Badge") {
    VStack(spacing: 20) {
        HStack {
            Text("Leo Bacevicius")
                .font(.headline)
            AdminBadge()
        }
        
        HStack {
            Text("Sarah Chen")
                .font(.headline)
            AdminBadge()
        }
    }
    .padding()
}

#Preview("Pill Badge Variants") {
    VStack(spacing: 12) {
        HStack(spacing: 8) {
            PillBadge(text: "Admin", color: .blue)
            PillBadge(text: "Pro", color: .purple)
            PillBadge(text: "New", color: .green)
        }
        
        HStack(spacing: 8) {
            PillBadge(text: "Admin", color: .blue, style: .solid)
            PillBadge(text: "Pro", color: .purple, style: .solid)
            PillBadge(text: "New", color: .green, style: .solid)
        }
    }
    .padding()
}
