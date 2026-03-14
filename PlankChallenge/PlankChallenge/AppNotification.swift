//
//  AppNotification.swift
//  PlankChallenge
//
//  Created by Leo Bacevicius on 08/03/2026.
//

import Foundation

struct AppNotification: Identifiable, Codable {
    var id: UUID = UUID()
    var notificationTypeRaw: String
    var title: String
    var message: String
    var isRead: Bool
    var createdAt: Date
    var relatedEntityId: String?
    
    var notificationType: NotificationType? {
        NotificationType(rawValue: notificationTypeRaw)
    }
    
    enum NotificationType: String, Codable {
        case streakFreezeUsed = "streak_freeze_used"
        case badgeEarned = "badge_earned"
        case groupJoined = "group_joined"
        case groupRemoved = "group_removed"
        case groupDeleted = "group_deleted"
        case joinRequestApproved = "join_request_approved"
        case joinRequestDenied = "join_request_denied"
        case promotedToAdmin = "promoted_to_admin"
        case tokenEarned = "token_earned"
        
        var iconName: String {
            switch self {
            case .streakFreezeUsed: return "snowflake"
            case .badgeEarned: return "medal.fill"
            case .groupJoined: return "person.3.fill"
            case .groupRemoved: return "person.fill.xmark"
            case .groupDeleted: return "trash.fill"
            case .joinRequestApproved: return "checkmark.circle.fill"
            case .joinRequestDenied: return "xmark.circle.fill"
            case .promotedToAdmin: return "star.fill"
            case .tokenEarned: return "snowflake.circle.fill"
            }
        }
    }
    
    init(
        type: NotificationType,
        title: String,
        message: String,
        relatedEntityId: String? = nil
    ) {
        self.notificationTypeRaw = type.rawValue
        self.title = title
        self.message = message
        self.isRead = false
        self.createdAt = Date()
        self.relatedEntityId = relatedEntityId
    }
}
