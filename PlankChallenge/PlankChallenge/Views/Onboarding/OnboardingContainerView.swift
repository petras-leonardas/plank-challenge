import SwiftUI

/// Root container for the onboarding flow.
///
/// Four-screen sequence:
///   0. Hold a plank — core mechanic
///   1. Build your streak — daily consistency
///   2. Beat your friends — social features
///   3. Notifications — daily reminder setup, then into the app
///
/// The user can swipe between screens or use the back/next buttons.
/// Page indicator dots and a back button are visible on every screen
/// so the flow feels like a single cohesive wizard. On the final screen,
/// the "Next" button is replaced by the notification CTAs within the page.
///
/// Completion writes `hasCompletedOnboarding` to UserDefaults and triggers
/// `RootView` to transition to `MainTabView`.
struct OnboardingContainerView: View {
    @State private var currentPage = 0
    
    private let totalPages = 4
    private var isLastPage: Bool { currentPage == totalPages - 1 }
    
    var body: some View {
        ZStack {
            // Animated shifting gradient (same as the plank timer)
            AnimatedGradientBackground()
            
            VStack(spacing: 0) {
                // Page content
                TabView(selection: $currentPage) {
                    OnboardingFeatureView.holdAPlank
                        .tag(0)
                    
                    OnboardingFeatureView.buildYourStreak
                        .tag(1)
                    
                    OnboardingFeatureView.beatYourFriends
                        .tag(2)
                    
                    OnboardingNotificationsView {
                        // hasCompletedOnboarding is written inside OnboardingNotificationsView
                        // RootView observes needsOnboarding which will now return false
                        // SwiftUI automatically transitions to MainTabView
                    }
                    .tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.35), value: currentPage)
                
                // Navigation controls — visible on every page
                navigationControls
            }
        }
    }
    
    // MARK: - Navigation Controls
    
    private var navigationControls: some View {
        VStack(spacing: 20) {
            // Page indicator dots
            HStack(spacing: 8) {
                ForEach(0..<totalPages, id: \.self) { index in
                    Circle()
                        .fill(index == currentPage ? .white : .white.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .scaleEffect(index == currentPage ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 0.2), value: currentPage)
                }
            }
            
            // Back / Next buttons
            HStack {
                // Back button (hidden on first page)
                if currentPage > 0 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            currentPage -= 1
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.white.opacity(0.7))
                    }
                } else {
                    Spacer()
                }
                
                Spacer()
                
                // Next button (hidden on the last page — the notification CTAs handle it)
                if !isLastPage {
                    Button {
                        guard currentPage < totalPages - 1 else { return }
                        withAnimation(.easeInOut(duration: 0.35)) {
                            currentPage += 1
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(currentPage == 2 ? "Set up reminders" : "Next")
                            Image(systemName: "chevron.right")
                        }
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(.white.opacity(0.2), in: Capsule())
                    }
                }
            }
            .padding(.horizontal, 24)
        }
        .padding(.bottom, 48)
    }
}

#Preview {
    OnboardingContainerView()
        .withMockServices()
}
