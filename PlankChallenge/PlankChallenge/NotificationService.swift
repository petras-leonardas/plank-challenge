import Foundation
import UserNotifications

/// Manages daily plank reminder preferences.
///
/// Reminders are delivered as server-side APNs alert pushes (not local
/// notifications). The backend cron checks whether the user has planked
/// today before sending, so reminders are automatically suppressed on
/// days when the user has already completed their plank.
///
/// This service handles:
///   - Requesting notification permission from the OS
///   - Persisting the enabled flag and chosen time to UserDefaults
///   - Syncing preferences to the backend via PATCH /users/me
///
/// Both the onboarding flow and Settings call into this service.
@MainActor
@Observable
final class NotificationService {
    static let shared = NotificationService()

    // MARK: - Observable State

    /// Whether the user has granted notification permission at the OS level.
    private(set) var isAuthorized: Bool = false

    // MARK: - Init

    private init() {
        Task { await refreshAuthorizationStatus() }
    }

    // MARK: - Authorization

    /// Re-reads the current authorization status from the system.
    func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized
    }

    /// Requests notification permission. Returns `true` if granted.
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            isAuthorized = granted
            return granted
        } catch {
            #if DEBUG
            print("[NotificationService] Authorization error: \(error)")
            #endif
            return false
        }
    }

    // MARK: - Daily Reminder

    /// Enables the daily reminder at the given time.
    /// Persists locally and syncs to the backend.
    func scheduleDailyReminder(at time: Date) {
        // Persist locally
        UserDefaults.standard.set(true, forKey: AppConfig.UserDefaultsKeys.notificationsEnabled)
        UserDefaults.standard.set(time, forKey: AppConfig.UserDefaultsKeys.dailyReminderTime)

        // Sync to backend — the cron uses these to decide when to send
        let timeString = Self.formatTimeForBackend(time)
        syncToBackend(enabled: true, time: timeString)
    }

    /// Disables the daily reminder.
    /// Persists locally and syncs to the backend.
    func cancelDailyReminder() {
        UserDefaults.standard.set(false, forKey: AppConfig.UserDefaultsKeys.notificationsEnabled)

        // Sync to backend
        syncToBackend(enabled: false, time: nil)
    }

    // MARK: - Backend Sync

    /// Syncs reminder preferences to the backend via PATCH /users/me.
    /// Fire-and-forget — errors are logged but don't affect the user experience.
    /// Skips sync if not authenticated (the post-login flow in RootView
    /// will pick up the local prefs and sync them).
    private func syncToBackend(enabled: Bool, time: String?) {
        Task {
            guard await APIClient.shared.isAuthenticated else { return }
            do {
                let _: APIUser = try await APIClient.shared.patch(
                    "/users/me",
                    body: UpdateProfileRequest(reminderEnabled: enabled, reminderTime: time)
                )
            } catch {
                #if DEBUG
                print("[NotificationService] Backend sync failed: \(error)")
                #endif
            }
        }
    }

    /// Formats a Date's hour:minute as "HH:mm" for the backend.
    static func formatTimeForBackend(_ date: Date) -> String {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", components.hour ?? 19, components.minute ?? 0)
    }

    // MARK: - Persisted Preferences

    /// Whether the daily reminder is currently enabled (persisted).
    var isReminderEnabled: Bool {
        UserDefaults.standard.bool(forKey: AppConfig.UserDefaultsKeys.notificationsEnabled)
    }

    /// The persisted reminder time, defaulting to 7:00 PM if never set.
    var reminderTime: Date {
        UserDefaults.standard.object(forKey: AppConfig.UserDefaultsKeys.dailyReminderTime) as? Date
            ?? Self.defaultReminderTime
    }

    /// Clears persisted reminder preferences (called on sign-out so the
    /// next account doesn't inherit the previous user's settings).
    func clearPreferences() {
        UserDefaults.standard.removeObject(forKey: AppConfig.UserDefaultsKeys.notificationsEnabled)
        UserDefaults.standard.removeObject(forKey: AppConfig.UserDefaultsKeys.dailyReminderTime)
    }

    /// 7:00 PM today — used as the default before the user picks a time.
    static var defaultReminderTime: Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = 19
        components.minute = 0
        return Calendar.current.date(from: components) ?? Date()
    }
}
