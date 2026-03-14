//
//  ResultsCard.swift
//  PlankChallenge
//
//  Created by Leo Bacevicius on 14/03/2026.
//

import SwiftUI

/// A card showing the user's personal best plank time, inspired by Strava's FTP/Results card
struct ResultsCard: View {
    let title: String
    let value: String
    let subtitle: String?
    
    init(title: String = "Personal Best", value: String, subtitle: String? = nil) {
        self.title = title
        self.value = value
        self.subtitle = subtitle
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(.white.opacity(0.8))
            
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .frame(width: 100, height: 100)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [Color.appAccent, Color.appAccent.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    HStack {
        ResultsCard(
            title: "Personal Best",
            value: "2:45",
            subtitle: "Mar 10, 2026"
        )
        .frame(width: 120, height: 120)
    }
    .padding()
}
