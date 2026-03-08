import Foundation
import UserNotifications

/// Service for managing push notifications
class NotificationService: ObservableObject {
    @Published var isAuthorized: Bool = false
    
    static let shared = NotificationService()
    
    private init() {
        checkAuthorizationStatus()
    }
    
    func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }
    
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .badge, .sound]
            )
            await MainActor.run {
                self.isAuthorized = granted
            }
            return granted
        } catch {
            print("Notification authorization error: \(error)")
            return false
        }
    }
    
    func scheduleDailyReminder(hour: Int, minute: Int) {
        // Remove existing reminders
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["daily_plank_reminder"]
        )
        
        guard isAuthorized else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Time to Plank!"
        content.body = "Don't break your streak. Complete your daily plank now."
        content.sound = .default
        
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents,
            repeats: true
        )
        
        let request = UNNotificationRequest(
            identifier: "daily_plank_reminder",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error)")
            }
        }
    }
    
    func cancelDailyReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["daily_plank_reminder"]
        )
    }
    
    func sendStreakFreezeNotification(tokensRemaining: Int) {
        guard isAuthorized else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Streak Saved!"
        content.body = "Your streak freeze token was used. You have \(tokensRemaining) remaining. Don't forget to plank today!"
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "streak_freeze_\(UUID().uuidString)",
            content: content,
            trigger: nil // Deliver immediately
        )
        
        UNUserNotificationCenter.current().add(request)
    }
}
