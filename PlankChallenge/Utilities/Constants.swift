import Foundation

enum Constants {
    
    // MARK: - Plank Rules
    enum Plank {
        /// Minimum valid plank duration in seconds
        static let minimumDurationSeconds: TimeInterval = 10
        
        /// Maximum plank duration in seconds (1 hour)
        static let maximumDurationSeconds: TimeInterval = 3600
        
        /// Available plank types
        enum PlankType: String, CaseIterable, Codable {
            case elbow = "Elbow Plank"
            case straightArm = "Straight Arm Plank"
            case parallettes = "Parallettes Plank"
            
            var imageName: String {
                switch self {
                case .elbow: return "plank_elbow"
                case .straightArm: return "plank_straight_arm"
                case .parallettes: return "plank_parallettes"
                }
            }
            
            var description: String {
                switch self {
                case .elbow: return "Forearms on ground"
                case .straightArm: return "Hands on ground, arms extended"
                case .parallettes: return "Using parallettes"
                }
            }
        }
    }
    
    // MARK: - Streak System
    enum Streak {
        /// Maximum number of freeze tokens a user can have
        static let maxFreezeTokens: Int = 2
        
        /// Initial freeze tokens for new users
        static let initialFreezeTokens: Int = 2
        
        /// Streak length required to earn a bonus token
        static let streakForBonusToken: Int = 20
        
        /// Badge milestone days
        static let badgeMilestones: [Int] = [7, 14, 30, 60, 90, 180, 365]
    }
    
    // MARK: - Groups
    enum Groups {
        /// Maximum number of groups a user can join
        static let maxGroupsPerUser: Int = 50
        
        /// Maximum members per group
        static let maxMembersPerGroup: Int = 1000
    }
    
    // MARK: - Notifications
    enum Notifications {
        /// Default reminder hour (24-hour format)
        static let defaultReminderHour: Int = 15 // 3:00 PM
        
        /// Default reminder minute
        static let defaultReminderMinute: Int = 0
    }
    
    // MARK: - UI
    enum UI {
        /// Timer update interval in seconds
        static let timerUpdateInterval: TimeInterval = 0.01 // 10ms for smooth milliseconds
    }
    
    // MARK: - Storage Keys
    enum StorageKeys {
        static let preferredPlankType = "preferredPlankType"
        static let notificationsEnabled = "notificationsEnabled"
        static let notificationHour = "notificationHour"
        static let notificationMinute = "notificationMinute"
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
    }
}
