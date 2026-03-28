import SwiftUI

/// Onboarding Screen 1 — Welcome
///
/// Sets the tone for the app. No data collected.
/// Animates the headline and three value proposition lines in sequence.
struct OnboardingWelcomeView: View {
    let onContinue: () -> Void
    
    @State private var showIcon = false
    @State private var showHeadline = false
    @State private var showLine1 = false
    @State private var showLine2 = false
    @State private var showLine3 = false
    @State private var showButton = false
    
    var body: some View {
        ZStack {
            // Background gradient — matches the plank timer's dark blue gradient
            LinearGradient.plankGradient
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // App icon
                Image("AppLogoWhite")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 140, height: 140)
                    .opacity(showIcon ? 1 : 0)
                    .scaleEffect(showIcon ? 1 : 0.7)
                    .padding(.bottom, 40)
                
                // Headline
                Text("Welcome to\nPlank Challenge")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .opacity(showHeadline ? 1 : 0)
                    .offset(y: showHeadline ? 0 : 12)
                    .padding(.bottom, 40)
                
                // Three value proposition lines
                VStack(spacing: 20) {
                    valueRow(
                        icon: "flame.fill",
                        iconColor: .orange,
                        text: "Hold a plank",
                        subtitle: "One exercise. Timed right in the app.",
                        show: showLine1
                    )
                    valueRow(
                        icon: "chart.line.uptrend.xyaxis",
                        iconColor: .white.opacity(0.9),
                        text: "Build your streak",
                        subtitle: "Miss a day, use a shield. Your streak survives.",
                        show: showLine2
                    )
                    valueRow(
                        icon: "trophy.fill",
                        iconColor: .yellow,
                        text: "Beat your friends",
                        subtitle: "Leaderboards, groups, and badges. Optional but addictive.",
                        show: showLine3
                    )
                }
                .padding(.horizontal, 40)
                
                Spacer()
                Spacer()
                
                // CTA button
                Button("Get started", action: onContinue)
                    .buttonStyle(OnboardingPrimaryButtonStyle())
                    .padding(.horizontal, 32)
                .opacity(showButton ? 1 : 0)
                .offset(y: showButton ? 0 : 16)
                .padding(.bottom, 48)
            }
        }
        .onAppear { runAnimations() }
    }
    
    // MARK: - Helpers
    
    private func valueRow(icon: String, iconColor: Color, text: String, subtitle: String, show: Bool) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(iconColor)
                .frame(width: 28)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(text)
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))
            }
            
            Spacer()
        }
        .opacity(show ? 1 : 0)
        .offset(x: show ? 0 : -16)
    }
    
    private func runAnimations() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1)) {
            showIcon = true
        }
        withAnimation(.easeOut(duration: 0.5).delay(0.5)) {
            showHeadline = true
        }
        withAnimation(.easeOut(duration: 0.4).delay(0.9)) {
            showLine1 = true
        }
        withAnimation(.easeOut(duration: 0.4).delay(1.1)) {
            showLine2 = true
        }
        withAnimation(.easeOut(duration: 0.4).delay(1.3)) {
            showLine3 = true
        }
        withAnimation(.easeOut(duration: 0.4).delay(1.7)) {
            showButton = true
        }
    }
}

#Preview {
    OnboardingWelcomeView(onContinue: {})
}
