//
//  Badge.swift
//  PlankChallenge
//
//  Created by Leo Bacevicius on 08/03/2026.
//

import Foundation

struct Badge: Identifiable, Codable {
    var id: UUID = UUID()
    var badgeTypeRaw: String
    var dateEarned: Date
    
    var badgeType: BadgeType? {
        BadgeType(rawValue: badgeTypeRaw)
    }
    
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
            "medal.fill"
        }
    }
    
    init(badgeType: BadgeType) {
        self.badgeTypeRaw = badgeType.rawValue
        self.dateEarned = Date()
    }
}
