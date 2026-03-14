//
//  PlankGroup.swift
//  PlankChallenge
//
//  Created by Leo Bacevicius on 08/03/2026.
//

import Foundation

struct PlankGroup: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var descriptionText: String
    var groupTypeRaw: String
    var joinModeRaw: String
    var imageData: Data?
    var memberCount: Int
    var isCurrentUserAdmin: Bool
    var isCurrentUserMember: Bool
    var createdAt: Date
    
    var groupType: GroupType {
        get { GroupType(rawValue: groupTypeRaw) ?? .publicOpen }
        set { groupTypeRaw = newValue.rawValue }
    }
    
    var joinMode: JoinMode {
        get { JoinMode(rawValue: joinModeRaw) ?? .open }
        set { joinModeRaw = newValue.rawValue }
    }
    
    enum GroupType: String, Codable {
        case publicOpen = "public"
        case privateInvite = "private"
    }
    
    enum JoinMode: String, Codable {
        case open = "open"
        case requestToJoin = "request"
    }
    
    init(
        name: String,
        description: String = "",
        groupType: GroupType = .publicOpen,
        joinMode: JoinMode = .open
    ) {
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
