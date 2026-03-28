//
//  BadgeView.swift
//  PlankChallenge
//
//  Created by Leo Bacevicius on 08/03/2026.
//

import SwiftUI

/// Legacy badge view using the local `Badge.BadgeType` model.
/// For the API-powered badge display use `APIBadgeDisplayView` in Components/BadgeView.swift.
struct LegacyBadgeView: View {
    let badgeType: Badge.BadgeType
    let isEarned: Bool
    let dateEarned: Date?
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(isEarned ? Color.yellow.opacity(0.2) : Color.gray.opacity(0.1))
                    .frame(width: 70, height: 70)
                
                Image(systemName: badgeType.iconName)
                    .font(.system(size: 30))
                    .foregroundStyle(isEarned ? .yellow : .gray.opacity(0.5))
            }
            
            Text(badgeType.displayName)
                .font(.caption)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .foregroundStyle(isEarned ? .primary : .secondary)
            
            if isEarned, let date = dateEarned {
                Text(date.formattedDate)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text("\(badgeType.streakDays) days")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 100)
        .opacity(isEarned ? 1.0 : 0.6)
    }
}

#Preview {
    HStack {
        LegacyBadgeView(
            badgeType: .streak7,
            isEarned: true,
            dateEarned: Date()
        )
        
        LegacyBadgeView(
            badgeType: .streak30,
            isEarned: false,
            dateEarned: nil
        )
    }
}
