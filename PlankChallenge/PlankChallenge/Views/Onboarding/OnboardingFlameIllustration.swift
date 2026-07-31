import SwiftUI

/// Animated flame illustration for the "Hold a plank" onboarding screen.
///
/// Concentric glow rings pulse outward and fade like heat radiating from a fire.
/// The flame icon gently flickers with a subtle rotation and scale animation.
struct OnboardingFlameIllustration: View {
    @State private var pulse1 = false
    @State private var pulse2 = false
    @State private var pulse3 = false
    @State private var flicker = false
    
    var body: some View {
        ZStack {
            // Pulsing glow rings — autoreverse for smooth breathing, never fully transparent
            Circle()
                .fill(Color.orange.opacity(0.06))
                .frame(width: 200, height: 200)
                .scaleEffect(pulse1 ? 1.15 : 0.9)
                .opacity(pulse1 ? 0.1 : 0.6)
            
            Circle()
                .fill(Color.orange.opacity(0.08))
                .frame(width: 160, height: 160)
                .scaleEffect(pulse2 ? 1.1 : 0.92)
                .opacity(pulse2 ? 0.15 : 0.7)
            
            Circle()
                .fill(Color.red.opacity(0.1))
                .frame(width: 120, height: 120)
                .scaleEffect(pulse3 ? 1.06 : 0.94)
                .opacity(pulse3 ? 0.3 : 0.8)
            
            // Flame icon with flicker
            Image(systemName: "flame.fill")
                .font(.system(size: 64))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.orange, .red],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .rotationEffect(.degrees(flicker ? 3 : -3))
                .scaleEffect(flicker ? 1.05 : 0.95)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                pulse1 = true
            }
            withAnimation(.easeInOut(duration: 3.5).repeatForever(autoreverses: true).delay(0.8)) {
                pulse2 = true
            }
            withAnimation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true).delay(1.6)) {
                pulse3 = true
            }
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                flicker = true
            }
        }
    }
}

#Preview {
    ZStack {
        Color(red: 10/255, green: 22/255, blue: 40/255).ignoresSafeArea()
        OnboardingFlameIllustration()
    }
}
