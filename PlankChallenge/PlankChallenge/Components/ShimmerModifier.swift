//
//  ShimmerModifier.swift
//  PlankChallenge
//

import SwiftUI

// MARK: - Shimmer Animation Modifier

/// Overlays a diagonal moving-gradient shimmer on any view.
/// Apply via `.shimmer()` on any skeleton placeholder shape.
struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    let width = geometry.size.width
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: .clear,                          location: 0.0),
                            .init(color: .white.opacity(0.55),            location: 0.45),
                            .init(color: .white.opacity(0.55),            location: 0.55),
                            .init(color: .clear,                          location: 1.0),
                        ]),
                        startPoint: UnitPoint(x: phase,         y: 0),
                        endPoint:   UnitPoint(x: phase + 1,     y: 0)
                    )
                    .frame(width: width * 3)
                    .offset(x: -width + (phase + 1) * width * 3)
                }
            )
            .mask(content)
            .onAppear {
                withAnimation(
                    .linear(duration: 1.4)
                    .repeatForever(autoreverses: false)
                ) {
                    phase = 1
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}
