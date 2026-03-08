import Foundation
import SwiftData

@Model
final class Badge {
    /// Unique identifier
    var id: UUID
    
    /// Badge type
    var badgeTypeRaw: String
    
    /// Date the badge was earned
    var dateEarned: Date
    
    // MARK: - Computed Properties
    
    var badgeType: BadgeType? {
        BadgeType(rawValue: badgeTypeRaw)
    }
    
    // MARK: - Badge Types
    
    enum BadgeType: String, CaseIterable, Codable {
        case streak7 = "streak_7"
        case streak14 = "streak_14"
        case streak30 = "streak_30"
        case streak60 = "streak_60"
        case streak90 = "streak_90"
        case streak180 = "streak_180"
        case streak365 = "streak_365"
        
        var streakDays: Int {
            switch self {
            case .streak7: return 7
            case .streak14: return 14
            case .streak30: return 30
            case .streak60: return 60
            case .streak90: return 90
            case .streak180: return 180
            case .streak365: return 365
            }
        }
        
        var displayName: String {
            switch self {
            case .streak7: return "1 Week Warrior"
            case .streak14: return "2 Week Champion"
            case .streak30: return "Monthly Master"
            case .streak60: return "60 Day Dedication"
            case .streak90: return "Quarter Year Quest"
            case .streak180: return "Half Year Hero"
            case .streak365: return "Year of Planking"
            }
        }
        
        var description: String {
            "\(streakDays) day streak achieved"
        }
        
        var iconName: String {
            "medal.fill" // SF Symbol
        }
        
        static func badgeFor(streakDays: Int) -> BadgeType? {
            // Return the highest badge earned for given streak
            let sortedTypes = BadgeType.allCases.sorted { $0.streakDays > $1.streakDays }
            return sortedTypes.first { streakDays >= $0.streakDays }
        }
    }
    
    // MARK: - Initializer
    
    init(badgeType: BadgeType) {
        self.id = UUID()
        self.badgeTypeRaw = badgeType.rawValue
        self.dateEarned = Date()
    }
}
