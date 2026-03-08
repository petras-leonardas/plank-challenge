import Foundation
import SwiftData

/// Service for managing local data operations
@MainActor
class DataService: ObservableObject {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - User Profile
    
    func getOrCreateUserProfile() -> UserProfile {
        let descriptor = FetchDescriptor<UserProfile>()
        
        if let existingProfile = try? modelContext.fetch(descriptor).first {
            return existingProfile
        }
        
        // Create new profile
        let newProfile = UserProfile()
        modelContext.insert(newProfile)
        try? modelContext.save()
        return newProfile
    }
    
    // MARK: - Plank Sessions
    
    func savePlankSession(_ session: PlankSession) {
        modelContext.insert(session)
        try? modelContext.save()
    }
    
    func getPlankSessions() -> [PlankSession] {
        let descriptor = FetchDescriptor<PlankSession>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    func getTodaysPlank() -> PlankSession? {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let predicate = #Predicate<PlankSession> { session in
            session.date >= startOfDay && session.date < endOfDay
        }
        
        let descriptor = FetchDescriptor<PlankSession>(predicate: predicate)
        return try? modelContext.fetch(descriptor).first
    }
    
    func hasPlankToday() -> Bool {
        getTodaysPlank() != nil
    }
    
    func deletePlankSession(_ session: PlankSession) {
        modelContext.delete(session)
        try? modelContext.save()
    }
    
    // MARK: - Badges
    
    func awardBadge(_ badgeType: Badge.BadgeType) {
        // Check if already earned
        let descriptor = FetchDescriptor<Badge>()
        let existingBadges = (try? modelContext.fetch(descriptor)) ?? []
        
        guard !existingBadges.contains(where: { $0.badgeTypeRaw == badgeType.rawValue }) else {
            return
        }
        
        let badge = Badge(badgeType: badgeType)
        modelContext.insert(badge)
        try? modelContext.save()
    }
    
    func getEarnedBadges() -> [Badge] {
        let descriptor = FetchDescriptor<Badge>(
            sortBy: [SortDescriptor(\.dateEarned, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    // MARK: - Notifications
    
    func addNotification(_ notification: AppNotification) {
        modelContext.insert(notification)
        try? modelContext.save()
    }
    
    func getNotifications() -> [AppNotification] {
        let descriptor = FetchDescriptor<AppNotification>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    func markNotificationAsRead(_ notification: AppNotification) {
        notification.isRead = true
        try? modelContext.save()
    }
    
    func getUnreadNotificationCount() -> Int {
        let predicate = #Predicate<AppNotification> { notification in
            notification.isRead == false
        }
        let descriptor = FetchDescriptor<AppNotification>(predicate: predicate)
        return (try? modelContext.fetch(descriptor).count) ?? 0
    }
}
