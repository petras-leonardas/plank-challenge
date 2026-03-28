//
//  Constants.swift
//  PlankChallenge
//
//  Created by Leo Bacevicius on 08/03/2026.
//

import Foundation

enum Constants {
    
    // MARK: - Plank Rules
    enum Plank {
        /// Minimum duration is 1 second - every plank counts!
        static let minimumDurationSeconds: TimeInterval = 1
        static let maximumDurationSeconds: TimeInterval = 3600
        
        /// All plank types supported by the app (matches backend's PlankType)
        enum PlankType: String, CaseIterable, Codable {
            case elbow = "Elbow Plank"
            case high = "High Plank"
            case sideLeft = "Side Plank (Left)"
            case sideRight = "Side Plank (Right)"
            case reverse = "Reverse Plank"
            
            var imageName: String {
                switch self {
                case .elbow: return "plank_elbow"
                case .high: return "plank_high"
                case .sideLeft: return "plank_side_left"
                case .sideRight: return "plank_side_right"
                case .reverse: return "plank_reverse"
                }
            }
            
            var description: String {
                switch self {
                case .elbow: return "Forearms on ground"
                case .high: return "Hands on ground, arms extended"
                case .sideLeft: return "Side plank on left arm"
                case .sideRight: return "Side plank on right arm"
                case .reverse: return "Face up, hands behind"
                }
            }
            
            /// Converts to the API plank type for backend communication
            func toAPIPlankType() -> APIPlankType {
                switch self {
                case .elbow: return .elbow
                case .high: return .high
                case .sideLeft: return .sideLeft
                case .sideRight: return .sideRight
                case .reverse: return .reverse
                }
            }
            
            /// Creates from an API plank type (lossless conversion)
            static func from(_ apiType: APIPlankType) -> PlankType {
                switch apiType {
                case .elbow: return .elbow
                case .high: return .high
                case .sideLeft: return .sideLeft
                case .sideRight: return .sideRight
                case .reverse: return .reverse
                }
            }
        }
    }
    
    // MARK: - Streak System
    enum Streak {
        static let maxFreezeTokens: Int = 2
        static let initialFreezeTokens: Int = 2
        static let streakForBonusToken: Int = 20
        static let badgeMilestones: [Int] = [7, 14, 30, 60, 90, 180, 365]
    }
    
    // MARK: - Groups
    enum Groups {
        static let maxGroupsPerUser: Int = 50
        static let maxMembersPerGroup: Int = 1000
    }
    
    // MARK: - Notifications
    enum Notifications {
        static let defaultReminderHour: Int = 15
        static let defaultReminderMinute: Int = 0
    }
    
    // MARK: - UI
    enum UI {
        static let timerUpdateInterval: TimeInterval = 0.01
        
        // MARK: Spacing
        /// Standard screen horizontal padding
        static let screenPadding: CGFloat = 16
        /// Standard card internal padding
        static let cardPadding: CGFloat = 16
        /// Compact card internal padding
        static let cardPaddingCompact: CGFloat = 12
        /// Spacing between major sections on a screen
        static let sectionSpacing: CGFloat = 24
        /// Spacing between items within a section
        static let itemSpacing: CGFloat = 8
        /// Medium spacing between items within a section
        static let itemSpacingMedium: CGFloat = 12
        
        // MARK: Corner Radius
        /// Standard corner radius for cards and input fields
        static let cardRadius: CGFloat = 12
        /// Larger corner radius for modals and onboarding cards
        static let sheetRadius: CGFloat = 16
        
        // MARK: Avatar Sizes
        static let avatarXSmall: CGFloat = 28
        static let avatarSmall: CGFloat = 32
        static let avatarMedium: CGFloat = 44
        static let avatarLarge: CGFloat = 72
        /// Extra-large avatar — used on other users' profile pages
        static let avatarXLarge: CGFloat = 80
        
        // MARK: Misc
        /// Standard app icon display size (onboarding, auth screen)
        static let appIconSize: CGFloat = 80
    }
    
    // MARK: - Storage Keys
    enum StorageKeys {
        static let preferredPlankType = "preferredPlankType"
        static let notificationsEnabled = "notificationsEnabled"
        static let notificationHour = "notificationHour"
        static let notificationMinute = "notificationMinute"
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let soundEnabled = "soundEnabled"
    }
    
    // MARK: - Timer
    enum Timer {
        static let countdownDuration: Int = 3
        static let celebrationDuration: TimeInterval = 1.5
    }
}
