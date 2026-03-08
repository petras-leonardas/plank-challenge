import SwiftUI

/// Displays a single badge (earned or locked)
struct BadgeView: View {
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
        BadgeView(
            badgeType: .streak7,
            isEarned: true,
            dateEarned: Date()
        )
        
        BadgeView(
            badgeType: .streak30,
            isEarned: false,
            dateEarned: nil
        )
    }
}
