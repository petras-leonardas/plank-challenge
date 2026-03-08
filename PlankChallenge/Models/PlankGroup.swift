import Foundation
import SwiftData

@Model
final class PlankGroup {
    /// Unique identifier
    var id: UUID
    
    /// Group name
    var name: String
    
    /// Group description
    var descriptionText: String
    
    /// Group type
    var groupTypeRaw: String
    
    /// Join mode (for public groups)
    var joinModeRaw: String
    
    /// Group image data
    @Attribute(.externalStorage)
    var imageData: Data?
    
    /// Member count (for display)
    var memberCount: Int
    
    /// Whether current user is admin
    var isCurrentUserAdmin: Bool
    
    /// Whether current user is member
    var isCurrentUserMember: Bool
    
    /// Date group was created
    var createdAt: Date
    
    // MARK: - Computed Properties
    
    var groupType: GroupType {
        get { GroupType(rawValue: groupTypeRaw) ?? .publicOpen }
        set { groupTypeRaw = newValue.rawValue }
    }
    
    var joinMode: JoinMode {
        get { JoinMode(rawValue: joinModeRaw) ?? .open }
        set { joinModeRaw = newValue.rawValue }
    }
    
    // MARK: - Enums
    
    enum GroupType: String, Codable {
        case publicOpen = "public"
        case privateInvite = "private"
    }
    
    enum JoinMode: String, Codable {
        case open = "open"
        case requestToJoin = "request"
    }
    
    // MARK: - Initializer
    
    init(
        name: String,
        description: String = "",
        groupType: GroupType = .publicOpen,
        joinMode: JoinMode = .open
    ) {
        self.id = UUID()
        self.name = name
        self.descriptionText = description
        self.groupTypeRaw = groupType.rawValue
        self.joinModeRaw = joinMode.rawValue
        self.imageData = nil
        self.memberCount = 1
        self.isCurrentUserAdmin = true
        self.isCurrentUserMember = true
        self.createdAt = Date()
    }
}
