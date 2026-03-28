//
//  LeaderboardRowView.swift
//  PlankChallenge
//
//  Unified leaderboard row component for consistent styling
//

import SwiftUI

// MARK: - Row Size

enum LeaderboardRowSize {
    case regular
    case compact
    
    var avatarSize: CGFloat {
        switch self {
        case .regular: return 44
        case .compact: return 32
        }
    }
    
    var rankBadgeSize: CGFloat {
        switch self {
        case .regular: return 36
        case .compact: return 28
        }
    }
    
    var nameFont: Font {
        switch self {
        case .regular: return .body
        case .compact: return .subheadline
        }
    }
    
    var valueFont: Font {
        switch self {
        case .regular: return .body
        case .compact: return .subheadline
        }
    }
    
    var rankFont: Font {
        switch self {
        case .regular: return .subheadline
        case .compact: return .caption
        }
    }
    
    var horizontalPadding: CGFloat {
        switch self {
        case .regular: return 16
        case .compact: return 12
        }
    }
    
    var verticalPadding: CGFloat {
        switch self {
        case .regular: return 12
        case .compact: return 10
        }
    }
    
    var spacing: CGFloat {
        switch self {
        case .regular: return 16
        case .compact: return 12
        }
    }
}

// MARK: - Leaderboard Row View

struct LeaderboardRowView: View {
    let rank: Int
    let name: String
    let avatarText: String
    let displayValue: String
    let isCurrentUser: Bool
    let avatarImageName: String?
    let size: LeaderboardRowSize
    
    init(
        rank: Int,
        name: String,
        avatarText: String? = nil,
        displayValue: String,
        isCurrentUser: Bool = false,
        avatarImageName: String? = nil,
        size: LeaderboardRowSize = .regular
    ) {
        self.rank = rank
        self.name = name
        self.avatarText = avatarText ?? String(name.prefix(1))
        self.displayValue = displayValue
        self.isCurrentUser = isCurrentUser
        self.avatarImageName = avatarImageName
        self.size = size
    }
    
    var body: some View {
        HStack(spacing: size.spacing) {
            // Rank Badge
            RankBadge(rank: rank, size: size.rankBadgeSize, font: size.rankFont)
            
            // Avatar — avatarImageName holds a remote URL for profile photos
            AvatarView(
                text: avatarText,
                imageUrl: avatarImageName,
                size: size.avatarSize
            )
            
            // Name
            HStack(spacing: 4) {
                Text(name)
                    .font(size.nameFont)
                    .fontWeight(isCurrentUser ? .semibold : .regular)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                if isCurrentUser {
                    Text("(You)")
                        .font(size == .compact ? .caption2 : .caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // Value
            Text(displayValue)
                .font(size.valueFont)
                .fontWeight(.semibold)
                .foregroundStyle(isCurrentUser ? Color.appAccent : .primary)
        }
        .padding(.horizontal, size.horizontalPadding)
        .padding(.vertical, size.verticalPadding)
        .background(isCurrentUser ? Color.appAccent.opacity(0.08) : Color.clear)
    }
}

// MARK: - Rank Badge

struct RankBadge: View {
    let rank: Int
    var size: CGFloat = 36
    var font: Font = .subheadline
    
    var body: some View {
        ZStack {
            Circle()
                .fill(rankColor)
                .frame(width: size, height: size)
            
            Text("\(rank)")
                .font(font)
                .fontWeight(.bold)
                .foregroundStyle(rank <= 3 ? .white : .primary)
        }
    }
    
    private var rankColor: Color {
        switch rank {
        case 1: return Color.rankGold
        case 2: return Color.rankSilver
        case 3: return Color.rankBronze
        default: return .gray.opacity(0.2)
        }
    }
}

// MARK: - Preview

#Preview("Leaderboard Rows") {
    VStack(spacing: 0) {
        // Regular size
        Text("Regular Size")
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        
        VStack(spacing: 0) {
            LeaderboardRowView(
                rank: 1,
                name: "Sarah Johnson",
                displayValue: "45 days",
                isCurrentUser: false
            )
            Divider().padding(.horizontal)
            LeaderboardRowView(
                rank: 2,
                name: "Mike Chen",
                displayValue: "38 days",
                isCurrentUser: true
            )
            Divider().padding(.horizontal)
            LeaderboardRowView(
                rank: 3,
                name: "Emma Wilson",
                displayValue: "35 days",
                isCurrentUser: false
            )
        }
        .background(Color.warmWhiteCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        
        // Compact size
        Text("Compact Size")
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        
        VStack(spacing: 0) {
            LeaderboardRowView(
                rank: 1,
                name: "Sarah Johnson",
                displayValue: "45 days",
                isCurrentUser: false,
                size: .compact
            )
            Divider().padding(.horizontal)
            LeaderboardRowView(
                rank: 2,
                name: "Mike Chen",
                displayValue: "38 days",
                isCurrentUser: true,
                size: .compact
            )
        }
        .background(Color.warmWhiteCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        
        Spacer()
    }
    .background(Color.softBlueBackground)
}
