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
