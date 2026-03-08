import SwiftUI

/// A card displaying a single statistic (Apple Health-inspired)
struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String?
    let icon: String?
    let color: Color
    
    init(
        title: String,
        value: String,
        subtitle: String? = nil,
        icon: String? = nil,
        color: Color = .blue
    ) {
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.icon = icon
        self.color = color
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if let icon = icon {
                    Image(systemName: icon)
                        .foregroundStyle(color)
                }
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Text(value)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}

#Preview {
    VStack {
        StatCard(
            title: "Current Streak",
            value: "14",
            subtitle: "days",
            icon: "flame.fill",
            color: .orange
        )
        
        StatCard(
            title: "Longest Plank",
            value: "3:45",
            subtitle: "personal best",
            icon: "trophy.fill",
            color: .yellow
        )
    }
    .padding()
}
