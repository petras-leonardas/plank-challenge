//
//  BlueFlameIcon.swift
//  PlankChallenge
//
//  A blue flame icon using the plank screen gradient colors.
//  Used in the streak calendar to indicate days with completed planks.
//

import SwiftUI

/// A blue flame icon with gradient coloring matching the plank timer screen
struct BlueFlameIcon: View {
    var size: CGFloat = 14
    
    var body: some View {
        Image(systemName: "flame.fill")
            .font(.system(size: size))
            .foregroundStyle(
                LinearGradient(
                    colors: [Color.plankButtonInner, Color.plankGradientEnd],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
    }
}

/// A smaller variant for compact displays
struct BlueFlameIconSmall: View {
    var body: some View {
        BlueFlameIcon(size: 12)
    }
}

// MARK: - Preview

#Preview("Blue Flame Sizes") {
    HStack(spacing: 20) {
        VStack {
            BlueFlameIcon(size: 12)
            Text("12pt").font(.caption2)
        }
        VStack {
            BlueFlameIcon(size: 14)
            Text("14pt").font(.caption2)
        }
        VStack {
            BlueFlameIcon(size: 18)
            Text("18pt").font(.caption2)
        }
        VStack {
            BlueFlameIcon(size: 24)
            Text("24pt").font(.caption2)
        }
    }
    .padding()
}

#Preview("In Context") {
    VStack(spacing: 16) {
        // Simulating calendar day cells
        HStack(spacing: 12) {
            VStack(spacing: 4) {
                Text("10")
                    .font(.callout)
                BlueFlameIcon()
            }
            VStack(spacing: 4) {
                Text("11")
                    .font(.callout)
                BlueFlameIcon()
            }
            VStack(spacing: 4) {
                Text("12")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                // No flame - missed day
            }
            VStack(spacing: 4) {
                Text("13")
                    .font(.callout)
                BlueFlameIcon()
            }
        }
    }
    .padding()
}
