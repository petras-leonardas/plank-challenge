//
//  UserProfile.swift
//  PlankChallenge
//
//  Created by Leo Bacevicius on 08/03/2026.
//

import Foundation

struct UserProfile: Identifiable, Codable {
    var id: UUID = UUID()
    var displayName: String
    var location: String?
    var bio: String
    var preferredPlankTypeRaw: String
    var profileImageData: Data?
    var socialLink: String?
    var linkedInLink: String?
    var currentStreak: Int
    var longestStreak: Int
    var freezeTokens: Int
    var lastPlankDate: Date?
    var createdAt: Date
    var modifiedAt: Date
    
    var preferredPlankType: Constants.Plank.PlankType {
        get { Constants.Plank.PlankType(rawValue: preferredPlankTypeRaw) ?? .elbow }
        set { preferredPlankTypeRaw = newValue.rawValue }
    }
    
    init(displayName: String = "Planker", location: String? = nil) {
        self.displayName = displayName
        self.location = location
        self.bio = ""
        self.preferredPlankTypeRaw = Constants.Plank.PlankType.elbow.rawValue
        self.profileImageData = nil
        self.socialLink = nil
        self.linkedInLink = nil
        self.currentStreak = 0
        self.longestStreak = 0
        self.freezeTokens = Constants.Streak.initialFreezeTokens
        self.lastPlankDate = nil
        self.createdAt = Date()
        self.modifiedAt = Date()
    }
}
