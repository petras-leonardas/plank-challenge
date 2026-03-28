//
//  UserRowView.swift
//  PlankChallenge
//
//  Unified user row component for lists (followers, following, group members, etc.)
//

import SwiftUI

// MARK: - User Row Size

enum UserRowSize {
    case regular
    case compact
    
    var avatarSize: CGFloat {
        switch self {
        case .regular: return 44
        case .compact: return 36
        }
    }
    
    var nameFont: Font {
        switch self {
        case .regular: return .body
        case .compact: return .subheadline
        }
    }
    
    var subtitleFont: Font {
        switch self {
        case .regular: return .caption
        case .compact: return .caption2
        }
    }
    
    var spacing: CGFloat {
        switch self {
        case .regular: return 12
        case .compact: return 10
        }
    }
}

// MARK: - User Row View

struct UserRowView: View {
    let name: String
    let subtitle: String?
    let avatarText: String
    let avatarImageName: String?
    let size: UserRowSize
    let showChevron: Bool
    let trailingContent: AnyView?
    
    init(
        name: String,
        subtitle: String? = nil,
        avatarText: String? = nil,
        avatarImageName: String? = nil,
        size: UserRowSize = .regular,
        showChevron: Bool = false,
        @ViewBuilder trailingContent: () -> some View = { EmptyView() }
    ) {
        self.name = name
        self.subtitle = subtitle
        self.avatarText = avatarText ?? String(name.prefix(1))
        self.avatarImageName = avatarImageName
        self.size = size
        self.showChevron = showChevron
        
        let content = trailingContent()
        if content is EmptyView {
            self.trailingContent = nil
        } else {
            self.trailingContent = AnyView(content)
        }
    }
    
    var body: some View {
        HStack(spacing: size.spacing) {
            // Avatar
            AvatarView(
                text: avatarText,
                imageName: avatarImageName,
                size: size.avatarSize
            )
            
            // Name and subtitle
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(size.nameFont)
                    .foregroundStyle(.primary)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(size.subtitleFont)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // Trailing content or chevron
            if let trailingContent = trailingContent {
                trailingContent
            } else if showChevron {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

// MARK: - User Row with Follow Button

struct UserRowWithFollowButton: View {
    let name: String
    let subtitle: String?
    let avatarText: String
    let avatarImageName: String?
    let isFollowing: Bool
    let onFollowTap: () -> Void
    
    init(
        name: String,
        subtitle: String? = nil,
        avatarText: String? = nil,
        avatarImageName: String? = nil,
        isFollowing: Bool = false,
        onFollowTap: @escaping () -> Void
    ) {
        self.name = name
        self.subtitle = subtitle
        self.avatarText = avatarText ?? String(name.prefix(1))
        self.avatarImageName = avatarImageName
        self.isFollowing = isFollowing
        self.onFollowTap = onFollowTap
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            AvatarView(
                text: avatarText,
                imageName: avatarImageName,
                size: 44
            )
            
            // Name and subtitle
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.body)
                    .foregroundStyle(.primary)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // Follow Button
            Button(action: onFollowTap) {
                Text(isFollowing ? "Following" : "Follow")
            }
            .pillButtonStyle(isSelected: !isFollowing)
        }
    }
}

// MARK: - User Row with Admin Badge

struct UserRowWithAdminBadge: View {
    let name: String
    let subtitle: String?
    let avatarText: String
    let avatarImageName: String?
    let isAdmin: Bool
    let showChevron: Bool
    
    init(
        name: String,
        subtitle: String? = nil,
        avatarText: String? = nil,
        avatarImageName: String? = nil,
        isAdmin: Bool = false,
        showChevron: Bool = true
    ) {
        self.name = name
        self.subtitle = subtitle
        self.avatarText = avatarText ?? String(name.prefix(1))
        self.avatarImageName = avatarImageName
        self.isAdmin = isAdmin
        self.showChevron = showChevron
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            AvatarView(
                text: avatarText,
                imageName: avatarImageName,
                size: 44
            )
            
            // Name, admin badge, and subtitle
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(name)
                        .font(.body)
                        .foregroundStyle(.primary)
                    
                    if isAdmin {
                        AdminBadge()
                    }
                }
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

// MARK: - Preview

#Preview("User Rows") {
    List {
        Section("Regular User Rows") {
            UserRowView(
                name: "Sarah Johnson",
                subtitle: "45 day streak"
            )
            
            UserRowView(
                name: "Mike Chen",
                subtitle: "38 day streak",
                showChevron: true
            )
        }
        
        Section("With Follow Button") {
            UserRowWithFollowButton(
                name: "Emma Wilson",
                subtitle: "35 day streak",
                isFollowing: false,
                onFollowTap: {}
            )
            
            UserRowWithFollowButton(
                name: "James Lee",
                subtitle: "28 day streak",
                isFollowing: true,
                onFollowTap: {}
            )
        }
        
        Section("With Admin Badge") {
            UserRowWithAdminBadge(
                name: "Leo B",
                subtitle: "Group Admin",
                isAdmin: true
            )
            
            UserRowWithAdminBadge(
                name: "Regular Member",
                subtitle: "Member since 2024",
                isAdmin: false
            )
        }
        
        Section("Compact Size") {
            UserRowView(
                name: "Compact User",
                subtitle: "12 day streak",
                size: .compact
            )
        }
    }
}
