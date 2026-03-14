//
//  CountdownOverlayView.swift
//  PlankChallenge
//
//  Created by Leo Bacevicius on 14/03/2026.
//

import SwiftUI

/// Radiating ring animation that plays during countdown
struct CountdownOverlayView: View {
    let countdownValue: Int
    let buttonSize: CGFloat
    
    @State private var ringScale: CGFloat = 1.0
    @State private var ringOpacity: Double = 0.6
    
    var body: some View {
        ZStack {
            // Multiple expanding rings for each countdown tick
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .stroke(Color.plankButtonGlow.opacity(ringOpacity * (1.0 - Double(index) * 0.25)), lineWidth: 3 - CGFloat(index))
                    .frame(width: buttonSize + 30 + CGFloat(index * 20), height: buttonSize + 30 + CGFloat(index * 20))
                    .scaleEffect(ringScale + CGFloat(index) * 0.1)
            }
        }
        .onAppear {
            startRingAnimation()
        }
        .onChange(of: countdownValue) { _, _ in
            // Reset and animate on each countdown tick
            resetAndAnimate()
        }
    }
    
    private func startRingAnimation() {
        ringScale = 1.0
        ringOpacity = 0.6
        
        withAnimation(.easeOut(duration: 0.8)) {
            ringScale = 1.4
            ringOpacity = 0.0
        }
    }
    
    private func resetAndAnimate() {
        // Quick reset
        ringScale = 1.0
        ringOpacity = 0.6
        
        // Animate outward
        withAnimation(.easeOut(duration: 0.8)) {
            ringScale = 1.4
            ringOpacity = 0.0
        }
    }
}

/// A single ring that expands and fades out
struct ExpandingRing: View {
    let size: CGFloat
    let delay: Double
    
    @State private var scale: CGFloat = 1.0
    @State private var opacity: Double = 0.5
    
    var body: some View {
        Circle()
            .stroke(Color.plankButtonGlow, lineWidth: 2)
            .frame(width: size, height: size)
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    withAnimation(.easeOut(duration: 0.7)) {
                        scale = 1.5
                        opacity = 0
                    }
                }
            }
    }
}

#Preview {
    ZStack {
        LinearGradient.plankGradient
            .ignoresSafeArea()
        
        CountdownOverlayView(countdownValue: 5, buttonSize: 220)
    }
}
