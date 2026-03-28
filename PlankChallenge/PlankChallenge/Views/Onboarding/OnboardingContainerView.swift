import SwiftUI

/// Root container for the onboarding flow.
///
/// Manages the four-screen sequence:
///   1. Welcome
///   2. Your Name
///   3. How It Works
///   4. Notifications
///
/// Uses a `TabView` with `.page` style for smooth horizontal transitions.
/// Navigation is programmatic only — the user cannot swipe back.
/// Completion writes `hasCompletedOnboarding` to UserDefaults and triggers
/// `RootView` to transition to `MainTabView`.
struct OnboardingContainerView: View {
    @Environment(\.authService) private var authService
    @Environment(\.userService) private var userService
    
    @State private var currentPage = 0
    
    var body: some View {
        TabView(selection: $currentPage) {
            // Screen 1 — Welcome
            OnboardingWelcomeView {
                advance()
            }
            .tag(0)
            // Disable swipe navigation — users must tap the CTA button
            .highPriorityGesture(DragGesture())
            
            // Screen 2 — Your Name
            OnboardingNameView {
                advance()
            }
            .tag(1)
            .highPriorityGesture(DragGesture())
            
            // Screen 3 — How It Works
            OnboardingHowItWorksView {
                advance()
            }
            .tag(2)
            .highPriorityGesture(DragGesture())
            
            // Screen 4 — Notifications (also completes onboarding)
            OnboardingNotificationsView {
                // hasCompletedOnboarding is written inside OnboardingNotificationsView
                // RootView observes needsOnboarding which will now return false
                // SwiftUI automatically transitions to MainTabView
            }
            .tag(3)
            .highPriorityGesture(DragGesture())
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.4), value: currentPage)
    }
    
    // MARK: - Navigation
    
    private func advance() {
        withAnimation(.easeInOut(duration: 0.4)) {
            currentPage += 1
        }
    }
}

#Preview {
    OnboardingContainerView()
        .withMockServices()
}
