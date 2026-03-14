//
//  ActivePlankRing.swift
//  PlankChallenge
//
//  Created by Leo Bacevicius on 14/03/2026.
//

import SwiftUI

/// Subtle animated ripple rings that emanate from the button during active plank
/// Creates a gentle water drop ripple effect with randomized timing
struct ActivePlankRing: View {
    let buttonSize: CGFloat
    
    @State private var ripples: [Ripple] = []
    @State private var timer: Timer?
    
    private var ringSize: CGFloat {
        buttonSize + 30
    }
    
    var body: some View {
        ZStack {
            // Ripple waves spreading outward
            ForEach(ripples) { ripple in
                RippleView(ripple: ripple, startSize: ringSize)
            }
            
            // Base ring (always visible) with subtle glow
            ZStack {
                Circle()
                    .stroke(Color.plankButtonGlow.opacity(0.15), lineWidth: 12)
                    .blur(radius: 8)
                    .frame(width: ringSize, height: ringSize)
                
                Circle()
                    .stroke(Color.plankButtonGlow.opacity(0.3), lineWidth: 2)
                    .frame(width: ringSize, height: ringSize)
            }
        }
        .onAppear {
            startRipples()
        }
        .onDisappear {
            stopRipples()
        }
    }
    
    private func startRipples() {
        // Create first ripple after a short random delay
        let initialDelay = Double.random(in: 0.5...1.5)
        DispatchQueue.main.asyncAfter(deadline: .now() + initialDelay) {
            addRipple()
            scheduleNextRipple()
        }
    }
    
    private func scheduleNextRipple() {
        // Random interval between ripples (2-5 seconds)
        let nextInterval = Double.random(in: 2.0...5.0)
        
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: nextInterval, repeats: false) { _ in
            Task { @MainActor in
                addRipple()
                scheduleNextRipple()
            }
        }
    }
    
    private func addRipple() {
        let newRipple = Ripple(
            id: UUID(),
            duration: Double.random(in: 6.0...9.0),  // Slow: 6-9 seconds
            maxOpacity: Double.random(in: 0.08...0.15),  // Very subtle
            maxScale: CGFloat.random(in: 3.0...5.0)  // Variable expansion
        )
        ripples.append(newRipple)
        
        // Remove ripple after animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + newRipple.duration + 0.5) { [id = newRipple.id] in
            ripples.removeAll { $0.id == id }
        }
        
        // Safety limit
        if ripples.count > 5 {
            ripples.removeFirst()
        }
    }
    
    private func stopRipples() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - Ripple Model

struct Ripple: Identifiable {
    let id: UUID
    let duration: Double
    let maxOpacity: Double
    let maxScale: CGFloat
}

// MARK: - Individual Ripple View

struct RippleView: View {
    let ripple: Ripple
    let startSize: CGFloat
    
    @State private var scale: CGFloat = 1.0
    @State private var opacity: Double = 0
    
    var body: some View {
        ZStack {
            // Outer glow layer (creates depth/3D effect)
            Circle()
                .stroke(Color.plankButtonGlow.opacity(opacity * 0.3), lineWidth: 30)
                .frame(width: startSize, height: startSize)
                .blur(radius: 20)
                .scaleEffect(scale)
            
            // Middle glow layer
            Circle()
                .stroke(Color.plankButtonGlow.opacity(opacity * 0.5), lineWidth: 20)
                .frame(width: startSize, height: startSize)
                .blur(radius: 12)
                .scaleEffect(scale)
            
            // Inner bright core
            Circle()
                .stroke(Color.plankButtonGlow.opacity(opacity * 0.8), lineWidth: 8)
                .frame(width: startSize, height: startSize)
                .blur(radius: 4)
                .scaleEffect(scale)
        }
        .onAppear {
            // Fade in gently, then fade out as it expands
            withAnimation(.easeIn(duration: ripple.duration * 0.1)) {
                opacity = ripple.maxOpacity
            }
            
            // Expand outward slowly
            withAnimation(.easeOut(duration: ripple.duration)) {
                scale = ripple.maxScale
            }
            
            // Start fading out after initial appearance
            DispatchQueue.main.asyncAfter(deadline: .now() + ripple.duration * 0.15) {
                withAnimation(.easeOut(duration: ripple.duration * 0.85)) {
                    opacity = 0
                }
            }
        }
    }
}

#Preview {
    ZStack {
        Color(red: 20/255, green: 30/255, blue: 70/255)
            .ignoresSafeArea()
        
        ZStack {
            ActivePlankRing(buttonSize: 220)
            
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.blue.opacity(0.8), Color.blue],
                        center: .center,
                        startRadius: 0,
                        endRadius: 110
                    )
                )
                .frame(width: 220, height: 220)
        }
    }
}
