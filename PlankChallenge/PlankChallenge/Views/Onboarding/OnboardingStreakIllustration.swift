import SwiftUI

/// Animated streak illustration for the "Build your streak" onboarding screen.
///
/// A large number counts from 0 → 30 to reinforce "watch the number climb."
/// The chart icon rises into position with a spring animation.
/// A subtle glow pulses behind the number in blue tones.
struct OnboardingStreakIllustration: View {
    @State private var displayedCount = 0
    @State private var chartRisen = false
    @State private var glowPulse = false
    @State private var finalPop = false
    @State private var countingTask: Task<Void, Never>?
    
    private let targetCount = 30
    
    var body: some View {
        ZStack {
            // Pulsing glow behind the number
            Circle()
                .fill(Color.cyan.opacity(0.08))
                .frame(width: 180, height: 180)
                .scaleEffect(glowPulse ? 1.1 : 0.9)
                .opacity(glowPulse ? 0.4 : 0.8)
            
            Circle()
                .fill(Color.blue.opacity(0.1))
                .frame(width: 140, height: 140)
                .scaleEffect(glowPulse ? 0.95 : 1.05)
                .opacity(glowPulse ? 0.6 : 0.3)
            
            VStack(spacing: 4) {
                // Counting number
                Text("\(displayedCount)")
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.cyan, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .contentTransition(.numericText())
                    .scaleEffect(finalPop ? 1.15 : 1.0)
                
                // Chart icon rises up
                HStack(spacing: 6) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 16))
                    Text("day streak")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .foregroundStyle(.white.opacity(0.5))
                .offset(y: chartRisen ? 0 : 20)
                .opacity(chartRisen ? 1 : 0)
            }
        }
        .onAppear {
            // Reset for replay on swipe-back
            displayedCount = 0
            chartRisen = false
            finalPop = false
            
            // Start glow pulse
            withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                glowPulse = true
            }
            
            // Rise the chart label
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.3)) {
                chartRisen = true
            }
            
            // Count up from 0 → 30
            startCounting()
        }
        .onDisappear {
            countingTask?.cancel()
            countingTask = nil
        }
    }
    
    /// Tick delay in nanoseconds using ease-in-out curve:
    /// starts slow (~120ms), speeds up to ~25ms at midpoint, slows to ~120ms at the end.
    private func tickDelay(for step: Int) -> UInt64 {
        let progress = Double(step) / Double(targetCount)
        // Sine-based ease: fast in the middle, slow at edges
        let factor = 1.0 - sin(progress * .pi)
        let minDelay: Double = 25_000_000   // 25ms at fastest
        let maxDelay: Double = 120_000_000  // 120ms at slowest
        return UInt64(minDelay + factor * (maxDelay - minDelay))
    }
    
    private func startCounting() {
        countingTask?.cancel()
        finalPop = false
        countingTask = Task {
            for i in 1...targetCount {
                do {
                    try await Task.sleep(nanoseconds: tickDelay(for: i))
                } catch { return }
                guard !Task.isCancelled else { return }
                withAnimation(.snappy(duration: 0.15)) {
                    displayedCount = i
                }
            }
            // Scale pop on landing
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                finalPop = true
            }
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                finalPop = false
            }
        }
    }
}

#Preview {
    ZStack {
        Color(red: 10/255, green: 22/255, blue: 40/255).ignoresSafeArea()
        OnboardingStreakIllustration()
    }
}
