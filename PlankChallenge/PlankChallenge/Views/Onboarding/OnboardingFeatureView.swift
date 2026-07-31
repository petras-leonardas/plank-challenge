import SwiftUI

/// A single onboarding feature screen with a custom animated illustration,
/// headline, and concise description. Used for the three value prop screens:
/// Hold a plank, Build your streak, Beat your friends.
struct OnboardingFeatureView<Illustration: View>: View {
    let headline: String
    let description: String
    @ViewBuilder let illustration: () -> Illustration
    
    @State private var showIllustration = false
    @State private var showHeadline = false
    @State private var showDescription = false
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Custom animated illustration — enters first
            illustration()
                .frame(height: 200)
                .opacity(showIllustration ? 1 : 0)
                .scaleEffect(showIllustration ? 1 : 0.8)
                .padding(.bottom, 48)
            
            // Headline — enters second
            Text(headline)
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.bottom, 16)
                .opacity(showHeadline ? 1 : 0)
                .offset(y: showHeadline ? 0 : 12)
            
            // Description — enters last
            Text(description)
                .font(.body)
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 40)
                .opacity(showDescription ? 1 : 0)
                .offset(y: showDescription ? 0 : 10)
            
            Spacer()
            Spacer()
            
            // Bottom space for navigation controls (managed by container)
            Spacer()
                .frame(height: 120)
        }
        .onAppear {
            // Reset for replay on swipe-back
            showIllustration = false
            showHeadline = false
            showDescription = false
            
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1)) {
                showIllustration = true
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.35)) {
                showHeadline = true
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.55)) {
                showDescription = true
            }
        }
    }
}

// MARK: - Feature Screen Factories

extension OnboardingFeatureView where Illustration == OnboardingFlameIllustration {
    static var holdAPlank: some View {
        OnboardingFeatureView(
            headline: "Hold a plank",
            description: "One exercise. Every day. That's the whole thing."
        ) {
            OnboardingFlameIllustration()
        }
    }
}

extension OnboardingFeatureView where Illustration == OnboardingStreakIllustration {
    static var buildYourStreak: some View {
        OnboardingFeatureView(
            headline: "Build your streak",
            description: "Do it daily and watch the number climb."
        ) {
            OnboardingStreakIllustration()
        }
    }
}

extension OnboardingFeatureView where Illustration == OnboardingTrophyIllustration {
    static var beatYourFriends: some View {
        OnboardingFeatureView(
            headline: "Beat your friends",
            description: "Groups, leaderboards, and badges. A little competition makes the habit stick."
        ) {
            OnboardingTrophyIllustration()
        }
    }
}

#Preview("Hold a plank") {
    ZStack {
        Color(red: 10/255, green: 22/255, blue: 40/255).ignoresSafeArea()
        OnboardingFeatureView.holdAPlank
    }
}

#Preview("Build your streak") {
    ZStack {
        Color(red: 10/255, green: 22/255, blue: 40/255).ignoresSafeArea()
        OnboardingFeatureView.buildYourStreak
    }
}

#Preview("Beat your friends") {
    ZStack {
        Color(red: 10/255, green: 22/255, blue: 40/255).ignoresSafeArea()
        OnboardingFeatureView.beatYourFriends
    }
}
