import SwiftUI

/// A continuously shifting vertical gradient background.
///
/// The bottom color cycles through four deep jewel tones
/// (blue → gold → teal → rose) every 80 seconds with smooth 20-second
/// linear transitions. The top stays fixed at the deep navy
/// `plankGradientStart`. All phase colors are dark enough to ensure
/// white text meets WCAG AA contrast across the entire gradient.
///
/// Used across the app: auth screen, onboarding, and plank timer.
///
/// Performance: ~4 SwiftUI body evaluations per 80-second cycle. The actual
/// color interpolation runs in Core Animation, not SwiftUI diffing.
struct AnimatedGradientBackground: View {
    /// Called each time the phase advances, with the new glow color.
    /// Used by `PlankTimerView` to synchronize the button glow.
    var onPhaseChange: ((Color) -> Void)?
    
    @State private var currentBottomColor = Color.plankPhaseBottomColors[0]
    @State private var cycleTask: Task<Void, Never>?
    
    var body: some View {
        LinearGradient(
            colors: [Color.plankGradientStart, currentBottomColor],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
        .onAppear { startCycle() }
        .onDisappear { cycleTask?.cancel() }
    }
    
    private func startCycle() {
        cycleTask?.cancel()
        cycleTask = Task {
            var phase = 0
            do {
                while !Task.isCancelled {
                    phase = (phase + 1) % Color.plankPhaseBottomColors.count
                    let nextBottom = Color.plankPhaseBottomColors[phase]
                    let nextGlow = Color.plankPhaseGlowColors[phase]
                    
                    await MainActor.run {
                        withAnimation(.linear(duration: 20)) {
                            currentBottomColor = nextBottom
                        }
                        onPhaseChange?(nextGlow)
                    }
                    
                    try await Task.sleep(nanoseconds: 20_000_000_000)
                }
            } catch {
                // Task cancelled — nothing to do
            }
        }
    }
}

#Preview {
    AnimatedGradientBackground()
}
