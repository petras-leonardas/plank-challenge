//
//  GroupDetailView.swift
//  PlankChallenge
//
//  Created by Leo Bacevicius on 08/03/2026.
//

import SwiftUI

struct GroupDetailView: View {
    let group: MockGroup
    @State private var selectedLeaderboard: LeaderboardType = .streak
    @State private var showingLeaveConfirmation = false
    
    enum LeaderboardType: String, CaseIterable {
        case streak = "Streak"
        case longestPlank = "Longest"
    }
    
    var body: some View {
        ZStack {
            AppBackground()
            
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    groupHeader
                    
                    // Leaderboard section
                    leaderboardSection
                    
                    // Members section
                    membersSection
                    
                    // Actions
                    if group.isCurrentUserMember {
                        actionsSection
                    } else {
                        joinSection
                    }
                }
                .padding()
            }
        }
        .navigationTitle(group.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.subtleBlueGradientStart.opacity(0.5), for: .navigationBar)
        .toolbar {
            if group.isCurrentUserAdmin {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink {
                        GroupSettingsView(group: group)
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
        }
        .alert("Leave Group?", isPresented: $showingLeaveConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Leave", role: .destructive) {
                // Leave group in Phase 5
            }
        } message: {
            Text("You will be removed from this group's leaderboards.")
        }
    }
    
    // MARK: - Header
    
    private var groupHeader: some View {
        VStack(spacing: 12) {
            // Group image
            ZStack {
                Circle()
                    .fill(Color.appAccent.opacity(0.2))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "person.3.fill")
                    .font(.largeTitle)
                    .foregroundStyle(Color.appAccent)
            }
            
            // Group info
            VStack(spacing: 4) {
                HStack {
                    Text(group.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if group.groupType == .privateInvite {
                        Image(systemName: "lock.fill")
                            .foregroundStyle(.secondary)
                    }
                }
                
                Text("\(group.memberCount) members")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            // Description
            if !group.description.isEmpty {
                Text(group.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.warmWhiteCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Leaderboard Section
    
    private var topLeaderboardUsers: [MockUser] {
        Array(leaderboardData.prefix(10))
    }
    
    private var leaderboardSection: some View {
        VStack(spacing: 12) {
            // Leaderboard type picker
            Picker("Leaderboard", selection: $selectedLeaderboard) {
                ForEach(LeaderboardType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)
            
            // Leaderboard list
            VStack(spacing: 0) {
                ForEach(0..<topLeaderboardUsers.count, id: \.self) { index in
                    leaderboardRow(at: index)
                }
            }
        }
        .padding()
        .background(Color.warmWhiteCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
    
    private func leaderboardRow(at index: Int) -> some View {
        let user = topLeaderboardUsers[index]
        let value = valueForUser(user)
        
        return VStack(spacing: 0) {
            GroupLeaderboardRow(
                rank: index + 1,
                user: user,
                value: value
            )
            
            if index < topLeaderboardUsers.count - 1 {
                Divider()
                    .padding(.leading, 60)
            }
        }
    }
    
    private func valueForUser(_ user: MockUser) -> String {
        switch selectedLeaderboard {
        case .streak:
            return "\(user.currentStreak) days"
        case .longestPlank:
            return user.longestPlankFormatted
        }
    }
    
    private var leaderboardData: [MockUser] {
        let data: [MockUser]
        switch selectedLeaderboard {
        case .streak:
            data = group.streakLeaderboard
        case .longestPlank:
            data = group.longestPlankLeaderboard
        }
        return data
    }
    
    // MARK: - Members Section
    
    private var membersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Members")
                    .font(.headline)
                
                Spacer()
                
                NavigationLink {
                    GroupMembersListView(group: group)
                } label: {
                    Text("See All")
                        .font(.subheadline)
                        .foregroundStyle(Color.appAccent)
                }
            }
            
            // Preview of members using AvatarView
            HStack(spacing: -10) {
                ForEach(group.members.prefix(5)) { member in
                    AvatarView(
                        text: String(member.displayName.prefix(1)),
                        imageName: member.profileImageName,
                        size: 36
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.warmWhiteCard, lineWidth: 2)
                    )
                }
                
                if group.memberCount > 5 {
                    Text("+\(group.memberCount - 5)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 16)
                }
            }
        }
        .padding()
        .background(Color.warmWhiteCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Actions Section
    
    private var actionsSection: some View {
        Button(role: .destructive) {
            showingLeaveConfirmation = true
        } label: {
            Text("Leave Group")
        }
        .buttonStyle(DestructiveButtonStyle(filled: false))
    }
    
    // MARK: - Join Section
    
    private var joinSection: some View {
        Button {
            // Join group
        } label: {
            Text(group.joinMode == .requestToJoin ? "Request to Join" : "Join Group")
        }
        .buttonStyle(PrimaryButtonStyle())
    }
}

// MARK: - Group Leaderboard Row

struct GroupLeaderboardRow: View {
    let rank: Int
    let user: MockUser
    let value: String
    
    var body: some View {
        HStack(spacing: 12) {
            // Rank Badge
            RankBadge(rank: rank, size: 28, font: .caption)
                .frame(width: 32)
            
            // Avatar
            AvatarView(
                text: String(user.displayName.prefix(1)),
                imageName: user.profileImageName,
                size: 36
            )
            
            // Name
            Text(user.displayName)
                .font(.body)
            
            Spacer()
            
            // Value
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(Color.appAccent)
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    NavigationStack {
        GroupDetailView(group: MockDataService.shared.groups[0])
    }
}
