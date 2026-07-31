//
//  ShimmerModifier.swift
//  PlankChallenge
//

import SwiftUI

// MARK: - Shimmer Animation Modifier

/// Overlays an animated diagonal shimmer on a container.
///
/// **Usage:** apply `.shimmer()` once on the outermost skeleton container
/// (e.g. the root `VStack` of a skeleton screen), NOT on individual shapes.
/// This keeps the `GeometryReader` count to exactly one per skeleton instance.
///
/// The gradient is masked to the shape of `content`, so only the filled
/// placeholder shapes let the light through.
struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content.overlay(
            GeometryReader { geometry in
                let width = geometry.size.width
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: .clear,               location: 0.0),
                        .init(color: .white.opacity(0.25), location: 0.4),
                        .init(color: .white.opacity(0.25), location: 0.6),
                        .init(color: .clear,               location: 1.0),
                    ]),
                    startPoint: UnitPoint(x: phase,     y: 0.3),
                    endPoint:   UnitPoint(x: phase + 1, y: 0.7)
                )
                // Extend the gradient beyond the view bounds so the sweep
                // fully enters and exits rather than snapping.
                .frame(width: width * 3)
                .offset(x: -width + (phase + 1) * width * 3)
                // Mask the gradient to the shape of the content so the shimmer
                // only appears over the filled placeholder shapes.
                .mask(content)
            }
            .onAppear {
                withAnimation(
                    .linear(duration: 1.4)
                    .repeatForever(autoreverses: false)
                ) {
                    phase = 1
                }
            }
        )
    }
}

extension View {
    /// Applies a moving-gradient shimmer over this view.
    /// Apply once on the skeleton container, not on each primitive shape.
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}
