//
//  MockUser.swift
//  PlankChallenge
//
//  Created by Leo Bacevicius on 08/03/2026.
//

import Foundation

/// Model for mock users in leaderboards and social features
/// Not persisted with SwiftData - loaded from mock data
struct MockUser: Identifiable, Sendable {
    let id: UUID
    let displayName: String
    let profileImageName: String? // Asset name or SF Symbol
    let currentStreak: Int
    let longestPlankSeconds: TimeInterval
    let totalPlanks: Int
    let badges: [Badge.BadgeType]
    
    var longestPlankFormatted: String {
        let minutes = Int(longestPlankSeconds) / 60
        let seconds = Int(longestPlankSeconds) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    init(
        id: UUID = UUID(),
        displayName: String,
        profileImageName: String? = nil,
        currentStreak: Int,
        longestPlankSeconds: TimeInterval,
        totalPlanks: Int,
        badges: [Badge.BadgeType] = []
    ) {
        self.id = id
        self.displayName = displayName
        self.profileImageName = profileImageName
        self.currentStreak = currentStreak
        self.longestPlankSeconds = longestPlankSeconds
        self.totalPlanks = totalPlanks
        self.badges = badges
    }
}
