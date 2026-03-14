//
//  NotificationService.swift
//  PlankChallenge
//
//  Created by Leo Bacevicius on 08/03/2026.
//

import Foundation
import UserNotifications

/// Service for managing push notifications
@MainActor
@Observable
final class NotificationService {
    var isAuthorized: Bool = false
    
    static let shared = NotificationService()
    
    private init() {
        Task {
            await checkAuthorizationStatus()
        }
    }
    
    func checkAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized
    }
    
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .badge, .sound]
            )
            isAuthorized = granted
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
    
    func sendBadgeEarnedNotification(badgeType: Badge.BadgeType) {
        guard isAuthorized else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "New Badge Earned!"
        content.body = "Congratulations! You've earned the '\(badgeType.displayName)' badge!"
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "badge_earned_\(UUID().uuidString)",
            content: content,
            trigger: nil // Deliver immediately
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    func sendStreakMilestoneNotification(days: Int) {
        guard isAuthorized else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Streak Milestone!"
        content.body = "Amazing! You've reached a \(days)-day streak. Keep up the great work!"
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "streak_milestone_\(UUID().uuidString)",
            content: content,
            trigger: nil // Deliver immediately
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    func clearAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }
    
    func setBadgeCount(_ count: Int) {
        Task {
            do {
                try await UNUserNotificationCenter.current().setBadgeCount(count)
            } catch {
                print("Error setting badge count: \(error)")
            }
        }
    }
}
