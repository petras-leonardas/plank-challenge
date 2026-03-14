//
//  CelebrationOverlayView.swift
//  PlankChallenge
//
//  Created by Leo Bacevicius on 14/03/2026.
//

import SwiftUI

/// Celebration animation overlay with ripple, particles, and background flash
struct CelebrationOverlayView: View {
    let isActive: Bool
    
    @State private var rippleScale: CGFloat = 1.0
    @State private var rippleOpacity: Double = 0.8
    @State private var flashOpacity: Double = 0.0
    @State private var particles: [Particle] = []
    
    var body: some View {
        ZStack {
            // Background flash (green tint)
            Color.green.opacity(flashOpacity)
                .ignoresSafeArea()
            
            // Ripple rings
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [.green, .green.opacity(0.5)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 4 - CGFloat(index)
                    )
                    .frame(width: 100 + CGFloat(index * 30), height: 100 + CGFloat(index * 30))
                    .scaleEffect(rippleScale + CGFloat(index) * 0.2)
                    .opacity(rippleOpacity * (1.0 - Double(index) * 0.2))
            }
            
            // Particle burst
            ForEach(particles) { particle in
                ParticleView(particle: particle)
            }
        }
        .onChange(of: isActive) { _, newValue in
            if newValue {
                startCelebration()
            } else {
                resetCelebration()
            }
        }
        .onAppear {
            if isActive {
                startCelebration()
            }
        }
    }
    
    private func startCelebration() {
        // Background flash
        withAnimation(.easeOut(duration: 0.15)) {
            flashOpacity = 0.3
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.easeOut(duration: 0.5)) {
                flashOpacity = 0.0
            }
        }
        
        // Ripple animation
        rippleScale = 1.0
        rippleOpacity = 0.8
        withAnimation(.easeOut(duration: 1.2)) {
            rippleScale = 4.0
            rippleOpacity = 0.0
        }
        
        // Generate particles
        generateParticles()
    }
    
    private func resetCelebration() {
        rippleScale = 1.0
        rippleOpacity = 0.0
        flashOpacity = 0.0
        particles = []
    }
    
    private func generateParticles() {
        particles = (0..<20).map { _ in
            Particle(
                id: UUID(),
                angle: Double.random(in: 0..<360),
                distance: CGFloat.random(in: 100...250),
                size: CGFloat.random(in: 6...14),
                color: [Color.green, Color.yellow, Color.white, Color.cyan].randomElement()!,
                delay: Double.random(in: 0...0.1)
            )
        }
    }
}

// MARK: - Particle Model

struct Particle: Identifiable {
    let id: UUID
    let angle: Double
    let distance: CGFloat
    let size: CGFloat
    let color: Color
    let delay: Double
    
    var endOffset: CGSize {
        let radians = angle * .pi / 180
        return CGSize(
            width: CGFloat(cos(radians)) * distance,
            height: CGFloat(sin(radians)) * distance
        )
    }
}

// MARK: - Particle View

struct ParticleView: View {
    let particle: Particle
    
    @State private var offset: CGSize = .zero
    @State private var opacity: Double = 1.0
    @State private var scale: CGFloat = 0.0
    
    var body: some View {
        Circle()
            .fill(particle.color)
            .frame(width: particle.size, height: particle.size)
            .scaleEffect(scale)
            .opacity(opacity)
            .offset(offset)
            .onAppear {
                // Initial pop
                withAnimation(.spring(response: 0.2, dampingFraction: 0.5).delay(particle.delay)) {
                    scale = 1.0
                }
                
                // Move outward
                withAnimation(.easeOut(duration: 0.8).delay(particle.delay)) {
                    offset = particle.endOffset
                }
                
                // Fade out
                withAnimation(.easeIn(duration: 0.4).delay(particle.delay + 0.4)) {
                    opacity = 0.0
                    scale = 0.5
                }
            }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        LinearGradient.plankGradient
            .ignoresSafeArea()
        
        CelebrationOverlayView(isActive: true)
    }
}
