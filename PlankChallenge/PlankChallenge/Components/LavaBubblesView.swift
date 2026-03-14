//
//  LavaBubblesView.swift
//  PlankChallenge
//
//  Created by Leo Bacevicius on 14/03/2026.
//

import SwiftUI

/// Animated lava lamp bubbles that rise slowly from bottom to top
/// Used as a celebration effect when plank is completed
/// Spawns a single burst of bubbles that exit off the top of the screen
struct LavaBubblesView: View {
    let isCountdown: Bool
    let isActive: Bool
    
    @State private var bubbles: [LavaBubble] = []
    @State private var hasSpawnedBubbles = false
    
    // Bubble colors - vibrant and celebratory
    private let bubbleColors: [Color] = [
        Color(red: 255/255, green: 100/255, blue: 130/255).opacity(0.6),  // Coral pink
        Color(red: 255/255, green: 150/255, blue: 80/255).opacity(0.6),   // Orange
        Color(red: 255/255, green: 200/255, blue: 100/255).opacity(0.55), // Golden yellow
        Color(red: 100/255, green: 220/255, blue: 180/255).opacity(0.6),  // Teal/mint
        Color(red: 100/255, green: 180/255, blue: 255/255).opacity(0.55), // Sky blue
        Color(red: 180/255, green: 130/255, blue: 255/255).opacity(0.6),  // Purple
        Color(red: 100/255, green: 255/255, blue: 150/255).opacity(0.55), // Mint green (celebration!)
    ]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(bubbles) { bubble in
                    BubbleView(
                        bubble: bubble,
                        screenHeight: geometry.size.height,
                        screenWidth: geometry.size.width
                    )
                }
            }
            .onAppear {
                // Spawn bubbles once when view appears
                if isActive && !hasSpawnedBubbles {
                    hasSpawnedBubbles = true
                    spawnBubbleBurst()
                }
            }
            .onDisappear {
                bubbles.removeAll()
                hasSpawnedBubbles = false
            }
        }
        .allowsHitTesting(false)
    }
    
    /// Spawn a single burst of bubbles (8-12 bubbles staggered over ~1 second)
    private func spawnBubbleBurst() {
        let bubbleCount = Int.random(in: 8...12)
        
        for i in 0..<bubbleCount {
            // Stagger bubble spawns over about 1 second
            let delay = Double(i) * 0.1 + Double.random(in: 0...0.05)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                addBubble()
            }
        }
    }
    
    private func addBubble() {
        let newBubble = LavaBubble(
            id: UUID(),
            x: CGFloat.random(in: 0.05...0.95),
            size: CGFloat.random(in: 50...130),
            color: bubbleColors.randomElement()!,
            // Duration 8-12 seconds for the journey
            duration: Double.random(in: 8...12),
            wobbleAmount: CGFloat.random(in: 0.02...0.05),
            wobbleSpeed: Double.random(in: 2.5...4.5)
        )
        bubbles.append(newBubble)
        
        // Remove bubble after it has fully exited the screen
        // Add extra buffer to ensure it's completely gone
        DispatchQueue.main.asyncAfter(deadline: .now() + newBubble.duration + 1.0) { [id = newBubble.id] in
            bubbles.removeAll { $0.id == id }
        }
    }
}

// MARK: - Bubble Model

struct LavaBubble: Identifiable {
    let id: UUID
    let x: CGFloat
    let size: CGFloat
    let color: Color
    let duration: Double
    let wobbleAmount: CGFloat
    let wobbleSpeed: Double
}

// MARK: - Individual Bubble View

struct BubbleView: View {
    let bubble: LavaBubble
    let screenHeight: CGFloat
    let screenWidth: CGFloat
    
    @State private var yOffset: CGFloat = 0
    @State private var opacity: Double = 0
    @State private var wobblePhase: Double = 0
    
    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        bubble.color.opacity(0.9),
                        bubble.color.opacity(0.5),
                        bubble.color.opacity(0.1)
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: bubble.size / 2
                )
            )
            .frame(width: bubble.size, height: bubble.size)
            .blur(radius: bubble.size * 0.1)
            .position(
                x: screenWidth * bubble.x + sin(wobblePhase) * screenWidth * bubble.wobbleAmount,
                y: screenHeight + bubble.size / 2 - yOffset
            )
            .opacity(opacity)
            .onAppear {
                startAnimations()
            }
    }
    
    private func startAnimations() {
        // Total distance: from below screen to fully above screen
        // Start: screenHeight + bubble.size/2 (just below bottom)
        // End: -bubble.size (fully above top, including the bubble's full diameter)
        let totalDistance = screenHeight + bubble.size * 1.5
        
        // Fade in quickly
        withAnimation(.easeIn(duration: 0.6)) {
            opacity = 1.0
        }
        
        // Rise from bottom to fully off the top
        withAnimation(.easeInOut(duration: bubble.duration)) {
            yOffset = totalDistance
        }
        
        // Wobble side to side continuously
        withAnimation(.easeInOut(duration: bubble.wobbleSpeed).repeatForever(autoreverses: true)) {
            wobblePhase = .pi * 2
        }
        
        // Fade out only as it exits off the top (last 15% of journey)
        // This ensures the bubble is mostly off-screen when it starts fading
        let fadeOutDelay = bubble.duration * 0.85
        DispatchQueue.main.asyncAfter(deadline: .now() + fadeOutDelay) {
            withAnimation(.easeOut(duration: bubble.duration * 0.15)) {
                opacity = 0
            }
        }
    }
}

#Preview {
    ZStack {
        LinearGradient(
            colors: [
                Color(red: 20/255, green: 30/255, blue: 70/255),
                Color(red: 40/255, green: 60/255, blue: 120/255)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
        
        LavaBubblesView(isCountdown: false, isActive: true)
    }
}
