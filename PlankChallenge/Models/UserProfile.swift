import Foundation
import SwiftData

@Model
final class UserProfile {
    /// Unique identifier
    var id: UUID
    
    /// User's display name
    var displayName: String
    
    /// User's bio/description
    var bio: String
    
    /// Preferred plank type
    var preferredPlankTypeRaw: String
    
    /// Profile image data (local storage)
    @Attribute(.externalStorage)
    var profileImageData: Data?
    
    /// Social link (optional)
    var socialLink: String?
    
    /// LinkedIn link (optional)
    var linkedInLink: String?
    
    /// Current streak count
    var currentStreak: Int
    
    /// Longest streak ever achieved
    var longestStreak: Int
    
    /// Number of freeze tokens remaining
    var freezeTokens: Int
    
    /// Date of last plank (for streak calculation)
    var lastPlankDate: Date?
    
    /// Date profile was created
    var createdAt: Date
    
    /// Date profile was last modified
    var modifiedAt: Date
    
    // MARK: - Computed Properties
    
    var preferredPlankType: Constants.Plank.PlankType {
        get { Constants.Plank.PlankType(rawValue: preferredPlankTypeRaw) ?? .elbow }
        set { preferredPlankTypeRaw = newValue.rawValue }
    }
    
    // MARK: - Initializer
    
    init(displayName: String = "Planker") {
        self.id = UUID()
        self.displayName = displayName
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
