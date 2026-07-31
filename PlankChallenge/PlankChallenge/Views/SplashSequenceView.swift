import SwiftUI

/// Cinematic launch sequence with a prominent white logo.
///
/// Three acts in ~3 seconds:
///   1. **Emerge** (0–0.5s) — White logo fades in large (160pt) on black
///      with a spring scale and a glow ring pulse.
///   2. **Hold** (0.5–2.0s) — The logo breathes gently at centre screen.
///      The animated gradient background slowly fades in behind it.
///      The logo remains white, bold, and fully visible throughout.
///   3. **Wind down** (2.0–3.2s) — The logo shrinks (160→120pt), fades
///      to fully transparent, and stops breathing. By the time the crossfade
///      begins, the splash is just the gradient — identical to the next screen.
///
/// The white logo is the dominant visual for the entire sequence.
/// The gradient fills in behind it, not through it.
struct SplashSequenceView: View {
    
    // MARK: - Animation State
    
    @State private var logoVisible = false
    @State private var logoPulse = false
    @State private var glowPulse = false
    @State private var backgroundRevealed = false
    @State private var windingDown = false
    @State private var choreographyTask: Task<Void, Never>?
    
    /// Called when the full sequence finishes.
    var onComplete: (() -> Void)?
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Layer 1: Black base
            Color.black
                .ignoresSafeArea()
            
            // Layer 2: Animated gradient — fades in during Act 2
            AnimatedGradientBackground()
                .opacity(backgroundRevealed ? 1.0 : 0.0)
            
            // Layer 3: Glow ring behind logo
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.plankButtonGlow.opacity(0.25), .clear],
                        center: .center,
                        startRadius: 50,
                        endRadius: 150
                    )
                )
                .frame(width: 300, height: 300)
                .scaleEffect(glowPulse ? 1.3 : 0.8)
                .opacity(glowPulse ? 0.0 : 0.5)
            
            // Layer 4: White logo — prominent and visible throughout
            Image("AppLogoWhite")
                .resizable()
                .scaledToFit()
                .frame(width: windingDown ? 120 : 160, height: windingDown ? 120 : 160)
                .opacity(logoVisible ? (windingDown ? 0.0 : 1.0) : 0)
                .scaleEffect(logoVisible ? 1 : 0.7)
                .scaleEffect(logoPulse ? 1.03 : 0.97)
        }
        .onAppear { startSequence() }
        .onDisappear {
            choreographyTask?.cancel()
            choreographyTask = nil
        }
    }
    
    // MARK: - Choreography
    
    private func startSequence() {
        choreographyTask?.cancel()
        choreographyTask = Task {
            do {
                // === Act 1: Emerge (0 – 0.5s) ===
                // White logo springs in, glow ring pulses once
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                    logoVisible = true
                }
                withAnimation(.easeOut(duration: 0.8)) {
                    glowPulse = true
                }
                
                try await sleep(0.5)
                
                // === Act 2: Hold (0.5 – 2.0s) ===
                // Background gradient fades in. Logo breathes gently.
                withAnimation(.easeInOut(duration: 1.2)) {
                    backgroundRevealed = true
                }
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    logoPulse = true
                }
                
                // Brand moment — logo sits prominently for 1.5s
                try await sleep(1.5)
                
                // === Act 3: Wind down (2.0 – 3.2s) ===
                // Logo slowly shrinks and fades to transparent. By the end,
                // the screen is just the gradient — the crossfade is invisible.
                withAnimation(.easeInOut(duration: 1.2)) {
                    windingDown = true
                    logoPulse = false
                }
                
                try await sleep(1.2)
                
                guard !Task.isCancelled else { return }
                onComplete?()
            } catch {
                // CancellationError — exit cleanly
            }
        }
    }
    
    private func sleep(_ seconds: Double) async throws {
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
}

#Preview {
    SplashSequenceView {
        print("Sequence complete")
    }
}
