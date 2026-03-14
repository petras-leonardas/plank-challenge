//
//  UserProfileView.swift
//  PlankChallenge
//
//  Created by Leo Bacevicius on 08/03/2026.
//

import SwiftUI

struct UserProfileView: View {
    let user: MockUser
    @State private var isFollowing = false
    
    var body: some View {
        ZStack {
            AppBackground()
            
            ScrollView {
                VStack(spacing: 20) {
                    // Profile header
                    profileHeader
                    
                    // Stats
                    statsSection
                    
                    // Badges
                    if !user.badges.isEmpty {
                        badgesSection
                    }
                }
                .padding()
            }
        }
        .navigationTitle(user.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.subtleBlueGradientStart.opacity(0.5), for: .navigationBar)
    }
    
    // MARK: - Profile Header
    
    private var profileHeader: some View {
        VStack(spacing: 16) {
            // Avatar
            AvatarView(
                text: String(user.displayName.prefix(1)),
                imageName: user.profileImageName,
                size: 80
            )
            
            // Name
            Text(user.displayName)
                .font(.title2)
                .fontWeight(.bold)
            
            // Follow button
            Button {
                isFollowing.toggle()
            } label: {
                Text(isFollowing ? "Following" : "Follow")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 8)
                    .background(isFollowing ? Color.gray.opacity(0.15) : Color.appAccent)
                    .foregroundStyle(isFollowing ? Color.primary : Color.white)
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.warmWhiteCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Stats Section
    
    private var statsSection: some View {
        HStack(spacing: 12) {
            StatCard(
                title: "Current Streak",
                value: "\(user.currentStreak)",
                subtitle: "days",
                icon: "flame.fill",
                color: .orange
            )
            
            StatCard(
                title: "Longest Plank",
                value: user.longestPlankFormatted,
                icon: "timer",
                color: .green
            )
        }
    }
    
    // MARK: - Badges Section
    
    private var badgesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Badges")
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(user.badges, id: \.self) { badgeType in
                        BadgeView(
                            badgeType: badgeType,
                            isEarned: true,
                            dateEarned: nil
                        )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.warmWhiteCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
}

#Preview {
    NavigationStack {
        UserProfileView(user: MockDataService.shared.mockUsers[0])
    }
}
