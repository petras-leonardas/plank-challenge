//
//  DataService.swift
//  PlankChallenge
//
//  Created by Leo Bacevicius on 08/03/2026.
//

import Foundation
import SwiftData

/// Service for managing local data operations
@MainActor
@Observable
final class DataService {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - User Profile
    
    func getOrCreateUserProfile() -> UserProfile {
        // For now, return a default profile
        // In Phase 3+, this will use SwiftData persistence
        return UserProfile(displayName: "Planker")
    }
    
    func saveUserProfile(_ profile: inout UserProfile) {
        // Will be implemented with SwiftData in Phase 3
        profile.modifiedAt = Date()
    }
    
    // MARK: - Plank Sessions
    
    func savePlankSession(_ session: PlankSession) {
        // Will be implemented with SwiftData in Phase 3
    }
    
    func getPlankSessions() -> [PlankSession] {
        // Will be implemented with SwiftData in Phase 3
        return []
    }
    
    func getTodaysPlank() -> PlankSession? {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        
        return getPlankSessions().first { session in
            session.date >= startOfDay
        }
    }
    
    func hasPlankToday() -> Bool {
        getTodaysPlank() != nil
    }
    
    func deletePlankSession(_ session: PlankSession) {
        // Will be implemented with SwiftData in Phase 3
    }
    
    func getLongestPlank() -> PlankSession? {
        getPlankSessions().max { $0.durationSeconds < $1.durationSeconds }
    }
    
    func getTotalPlankCount() -> Int {
        getPlankSessions().count
    }
    
    func getAveragePlankDuration() -> TimeInterval {
        let sessions = getPlankSessions()
        guard !sessions.isEmpty else { return 0 }
        let total = sessions.reduce(0) { $0 + $1.durationSeconds }
        return total / Double(sessions.count)
    }
    
    // MARK: - Badges
    
    func awardBadge(_ badgeType: Badge.BadgeType) {
        // Check if already earned
        let existingBadges = getEarnedBadges()
        
        guard !existingBadges.contains(where: { $0.badgeTypeRaw == badgeType.rawValue }) else {
            return
        }
        
        let badge = Badge(badgeType: badgeType)
        // Will be implemented with SwiftData in Phase 3
    }
    
    func getEarnedBadges() -> [Badge] {
        // Will be implemented with SwiftData in Phase 3
        return []
    }
    
    func checkAndAwardBadges(forStreak streak: Int) {
        // Check each badge milestone
        for badgeType in Badge.BadgeType.allCases {
            if streak >= badgeType.streakDays {
                awardBadge(badgeType)
            }
        }
    }
    
    // MARK: - Notifications
    
    func addNotification(_ notification: AppNotification) {
        // Will be implemented with SwiftData in Phase 3
    }
    
    func getNotifications() -> [AppNotification] {
        // Will be implemented with SwiftData in Phase 3
        return []
    }
    
    func markNotificationAsRead(_ notification: AppNotification) {
        // Will be implemented with SwiftData in Phase 3
    }
    
    func getUnreadNotificationCount() -> Int {
        getNotifications().filter { !$0.isRead }.count
    }
    
    func markAllNotificationsAsRead() {
        for notification in getNotifications() {
            markNotificationAsRead(notification)
        }
    }
    
    // MARK: - Streak Calculation
    
    func calculateCurrentStreak() -> Int {
        let sessions = getPlankSessions().sorted { $0.date > $1.date }
        guard !sessions.isEmpty else { return 0 }
        
        let calendar = Calendar.current
        var streak = 0
        var currentDate = calendar.startOfDay(for: Date())
        
        // Check if there's a plank today or yesterday
        let hasPlankToday = sessions.contains { calendar.isDate($0.date, inSameDayAs: currentDate) }
        
        if !hasPlankToday {
            // Check yesterday
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: currentDate) else {
                return 0
            }
            let hasPlankYesterday = sessions.contains { calendar.isDate($0.date, inSameDayAs: yesterday) }
            if !hasPlankYesterday {
                return 0
            }
            currentDate = yesterday
        }
        
        // Count consecutive days
        while true {
            let hasPlank = sessions.contains { calendar.isDate($0.date, inSameDayAs: currentDate) }
            if hasPlank {
                streak += 1
                guard let previousDay = calendar.date(byAdding: .day, value: -1, to: currentDate) else {
                    break
                }
                currentDate = previousDay
            } else {
                break
            }
        }
        
        return streak
    }
    
    // MARK: - Groups
    
    func getJoinedGroups() -> [PlankGroup] {
        // Will be implemented with SwiftData in Phase 3
        return []
    }
    
    func joinGroup(_ group: PlankGroup) {
        // Will be implemented in Phase 5
    }
    
    func leaveGroup(_ group: PlankGroup) {
        // Will be implemented in Phase 5
    }
}
