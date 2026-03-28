import SwiftUI

/// Onboarding Screen 3 — How It Works
///
/// Briefly explains the core mechanic before the user reaches the notifications screen.
/// Covers: how the timer works, the daily streak concept, and streak shields.
/// No data collected on this screen.
struct OnboardingHowItWorksView: View {
    let onContinue: () -> Void

    @State private var showHeadline = false
    @State private var showStep1 = false
    @State private var showStep2 = false
    @State private var showStep3 = false
    @State private var showButton = false

    var body: some View {
        ZStack {
            LinearGradient.plankGradient
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Headline
                Text("Here's how it works")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 48)
                    .opacity(showHeadline ? 1 : 0)
                    .offset(y: showHeadline ? 0 : 12)

                // Three steps
                VStack(spacing: 28) {
                    stepRow(
                        icon: "hand.tap.fill",
                        iconColor: .white.opacity(0.9),
                        title: "Hold a plank",
                        detail: "Tap the big button. Hold as long as you can. Done.",
                        show: showStep1
                    )
                    stepRow(
                        icon: "flame.fill",
                        iconColor: .orange,
                        title: "Do it every day",
                        detail: "One plank a day keeps your streak alive.",
                        show: showStep2
                    )
                    stepRow(
                        icon: "shield.fill",
                        iconColor: Color(red: 0.4, green: 0.85, blue: 0.9),
                        title: "Miss a day? No panic",
                        detail: "Streak shields automatically cover missed days. You start with two.",
                        show: showStep3
                    )
                }
                .padding(.horizontal, 40)

                Spacer()
                Spacer()

                // CTA button
                Button(action: onContinue) {
                    Text("Got it, let's go")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.appAccent)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
                .opacity(showButton ? 1 : 0)
                .offset(y: showButton ? 0 : 16)
            }
        }
        .onAppear { runAnimations() }
    }

    // MARK: - Step Row

    private func stepRow(
        icon: String,
        iconColor: Color,
        title: String,
        detail: String,
        show: Bool
    ) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(iconColor)
                .frame(width: 28)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)

                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .opacity(show ? 1 : 0)
        .offset(x: show ? 0 : -16)
    }

    // MARK: - Animations

    private func runAnimations() {
        withAnimation(.easeOut(duration: 0.5).delay(0.2)) {
            showHeadline = true
        }
        withAnimation(.easeOut(duration: 0.4).delay(0.6)) {
            showStep1 = true
        }
        withAnimation(.easeOut(duration: 0.4).delay(0.85)) {
            showStep2 = true
        }
        withAnimation(.easeOut(duration: 0.4).delay(1.1)) {
            showStep3 = true
        }
        withAnimation(.easeOut(duration: 0.4).delay(1.5)) {
            showButton = true
        }
    }
}

#Preview {
    OnboardingHowItWorksView(onContinue: {})
}
