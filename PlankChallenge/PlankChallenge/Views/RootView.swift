import SwiftUI

/// Root view that switches between authentication, onboarding, and main content.
///
/// State machine:
/// - `.unknown`        → Loading spinner (session restore in progress)
/// - `.unauthenticated` → AuthenticationView
/// - `.authenticated` + needs onboarding → OnboardingContainerView
/// - `.authenticated` + onboarding done  → MainTabView
struct RootView: View {
    @Environment(\.authService) private var authService
    @Environment(\.userService) private var userService
    @Environment(\.plankService) private var plankService
    @Environment(\.streakService) private var streakService
    @Environment(\.badgeService) private var badgeService
    @Environment(\.groupService) private var groupService
    @Environment(\.leaderboardService) private var leaderboardService
    @Environment(\.notificationService) private var notificationService
    @Environment(\.mediaService) private var mediaService
    
    /// Observing this via @AppStorage ensures SwiftUI re-renders when
    /// OnboardingNotificationsView writes `true` to UserDefaults on completion,
    /// which flips `needsOnboarding` to `false` and transitions to MainTabView.
    @AppStorage(AppConfig.UserDefaultsKeys.hasCompletedOnboarding)
    private var hasCompletedOnboarding = false
    
    /// Set to `true` when the splash animation sequence finishes.
    /// The splash stays visible until both this flag is true AND
    /// the session restore has completed.
    @State private var splashSequenceComplete = false
    
    /// True when the splash should still be visible — either the session
    /// restore hasn't finished OR the splash animation hasn't completed.
    private var showSplash: Bool {
        if case .unknown = authService.state { return true }
        return !splashSequenceComplete
    }
    
    var body: some View {
        Group {
            if showSplash {
                SplashSequenceView {
                    splashSequenceComplete = true
                }
            } else {
                switch authService.state {
                case .unknown:
                    // Unreachable — showSplash is true when state is .unknown.
                    // Included for exhaustive switch.
                    EmptyView()
                    
                case .unauthenticated:
                    AuthenticationView()
                        .transition(.opacity)
                    
                case .authenticated:
                    if authService.needsOnboarding {
                        OnboardingContainerView()
                            .transition(.opacity)
                    } else {
                        MainTabView()
                            .transition(.opacity)
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 1.0), value: showSplash)
        .animation(.easeInOut(duration: 0.3), value: authService.state)
        .animation(.easeInOut(duration: 0.3), value: hasCompletedOnboarding)
        .task {
            // Session restore runs concurrently with the splash animation.
            // The splash stays until BOTH the animation sequence completes
            // (via SplashSequenceView.onComplete) AND session restore finishes.
            await authService.restoreSession()
        }
        .onChange(of: authService.state) { _, newState in
            switch newState {
            case .authenticated:
                // Pre-warm streak, plank, badge, and notification data as soon as the
                // session is confirmed — before any tab renders. This ensures PlankTimerView
                // shows the correct streak immediately on cold launch instead of briefly
                // displaying "0 day streak" until the Progress tab is visited, and ensures
                // the Notifications tab badge is accurate without requiring a tab visit.
                Task {
                    async let streakFetch: () = {
                        guard !streakService.hasLoaded else { return }
                        try? await streakService.fetchStreak()
                    }()
                    async let plankFetch: () = {
                        guard !plankService.hasLoaded else { return }
                        try? await plankService.fetchPlanks(refresh: false)
                    }()
                    async let badgeFetch: () = {
                        guard !badgeService.hasLoaded else { return }
                        try? await badgeService.fetchBadges()
                    }()
                    async let unreadFetch: () = {
                        await notificationService.fetchUnreadCount()
                    }()
                    async let tzSync: () = syncTimezoneAndReminders()
                    _ = await (streakFetch, plankFetch, badgeFetch, unreadFetch, tzSync)
                }
                
            case .unauthenticated:
                // When the user signs out or their session expires, clear all
                // service caches to prevent data leaking into the next session.
                plankService.clearData()
                streakService.clearData()
                badgeService.clearData()
                userService.clearData()
                groupService.clearData()
                leaderboardService.clearData()
                notificationService.clearData()
                mediaService.clearData()
                
                // Clear @AppStorage today-plank state so a different user signing
                // in on the same device on the same day doesn't see the previous
                // user's plank count and timer state.
                UserDefaults.standard.removeObject(forKey: "todayPlankDate")
                UserDefaults.standard.removeObject(forKey: "todayPlankTotalTime")
                UserDefaults.standard.removeObject(forKey: "todayPlankCount")
                UserDefaults.standard.removeObject(forKey: "todayPlankTimesJSON")
                // Note: "soundEnabled" (@AppStorage in PlankTimerView) is intentionally
                // NOT cleared on logout — it is a device-level UI preference, not user
                // data. A user who prefers silent mode should not have to reconfigure it
                // after every login.
                
            case .unknown:
                break
            }
        }
    }
    
    // MARK: - Post-Login Sync
    
    /// Syncs the device timezone and local reminder preferences to the backend
    /// on every login. This ensures the cron job sends reminders at the correct
    /// local time, and covers preferences set during onboarding before auth.
    private func syncTimezoneAndReminders() async {
        let tz = TimeZone.current.identifier
        let service = NotificationService.shared
        let enabled = service.isReminderEnabled
        let time = enabled ? NotificationService.formatTimeForBackend(service.reminderTime) : nil
        _ = try? await userService.updateProfile(
            displayName: nil,
            location: nil,
            bio: nil,
            preferredPlankType: nil,
            plankGoalSeconds: nil,
            reminderEnabled: enabled,
            reminderTime: time,
            timezone: tz
        )
    }
}

// MARK: - Preview

#Preview("Loading") {
    RootView()
        .environment(AuthService.shared)
}
