import SwiftUI

/// Animated trophy illustration for the "Beat your friends" onboarding screen.
///
/// Floating sparkle particles rise around the trophy in a continuous loop.
/// A diagonal shimmer sweeps across the icon periodically.
/// The trophy gently pulses in scale.
struct OnboardingTrophyIllustration: View {
    @State private var trophyPulse = false
    @State private var shimmerOffset: CGFloat = -100
    @State private var shimmerTask: Task<Void, Never>?
    
    var body: some View {
        ZStack {
            // Glow behind trophy
            Circle()
                .fill(Color.yellow.opacity(0.06))
                .frame(width: 180, height: 180)
                .scaleEffect(trophyPulse ? 1.05 : 0.95)
            
            Circle()
                .fill(Color.orange.opacity(0.08))
                .frame(width: 140, height: 140)
                .scaleEffect(trophyPulse ? 0.97 : 1.03)
            
            // Floating sparkle particles
            ForEach(0..<8, id: \.self) { index in
                SparkleParticle(index: index)
            }
            
            // Trophy icon with shimmer
            ZStack {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.yellow, .orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                // Shimmer highlight — wide and soft for a premium metallic gleam
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, .clear, .white.opacity(0.2), .white.opacity(0.35), .white.opacity(0.2), .clear, .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 50, height: 90)
                    .rotationEffect(.degrees(25))
                    .offset(x: shimmerOffset)
                    .mask {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 64))
                    }
            }
            .scaleEffect(trophyPulse ? 1.03 : 0.97)
        }
        .onAppear {
            // Trophy pulse
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                trophyPulse = true
            }
            // Shimmer sweep
            startShimmerLoop()
        }
        .onDisappear {
            shimmerTask?.cancel()
            shimmerTask = nil
        }
    }
    
    private func startShimmerLoop() {
        shimmerTask?.cancel()
        shimmerTask = Task {
            while !Task.isCancelled {
                await MainActor.run {
                    shimmerOffset = -100
                    withAnimation(.easeInOut(duration: 1.2)) {
                        shimmerOffset = 100
                    }
                }
                do {
                    try await Task.sleep(nanoseconds: 3_500_000_000)
                } catch { break }
            }
        }
    }
}

// MARK: - Sparkle Particle

/// A single sparkle particle that floats upward, fades, and resets.
private struct SparkleParticle: View {
    let index: Int
    
    @State private var animate = false
    
    // Randomised per-particle config
    private var xOffset: CGFloat {
        let offsets: [CGFloat] = [-45, -30, -15, 0, 15, 30, 45, 35]
        return offsets[index % offsets.count]
    }
    
    private var duration: Double {
        let durations: [Double] = [2.5, 3.0, 2.8, 3.2, 2.6, 3.4, 2.9, 3.1]
        return durations[index % durations.count]
    }
    
    private var delay: Double {
        let delays: [Double] = [0, 0.4, 0.8, 1.2, 1.6, 2.0, 2.4, 2.8]
        return delays[index % delays.count]
    }
    
    private var size: CGFloat {
        let sizes: [CGFloat] = [6, 8, 5, 7, 6, 9, 5, 7]
        return sizes[index % sizes.count]
    }
    
    private var particleColor: Color {
        let colors: [Color] = [
            .yellow.opacity(0.7), .orange.opacity(0.6), .white.opacity(0.5),
            .yellow.opacity(0.8), .orange.opacity(0.5), .yellow.opacity(0.6),
            .white.opacity(0.4), .orange.opacity(0.7),
        ]
        return colors[index % colors.count]
    }
    
    private var rotationTarget: Double {
        // Alternate clockwise and counter-clockwise
        index % 2 == 0 ? 120 : -120
    }
    
    var body: some View {
        Image(systemName: "sparkle")
            .font(.system(size: size))
            .foregroundStyle(particleColor)
            .rotationEffect(.degrees(animate ? rotationTarget : 0))
            .offset(
                x: xOffset + (animate ? CGFloat(index % 2 == 0 ? 10 : -10) : 0),
                y: animate ? -90 : 40
            )
            .opacity(animate ? 0 : 0.8)
            .onAppear {
                withAnimation(
                    .easeOut(duration: duration)
                    .repeatForever(autoreverses: false)
                    .delay(delay)
                ) {
                    animate = true
                }
            }
    }
}

#Preview {
    ZStack {
        Color(red: 10/255, green: 22/255, blue: 40/255).ignoresSafeArea()
        OnboardingTrophyIllustration()
    }
}
