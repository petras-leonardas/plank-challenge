//
//  GroupsView.swift
//  PlankChallenge
//
//  Created by Leo Bacevicius on 08/03/2026.
//

import SwiftUI

// MARK: - Groups View

struct GroupsView: View {
    private var mockData: MockDataService { MockDataService.shared }
    @State private var showingCreateGroup = false
    @State private var showingSearch = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // App background with subtle gradient
                AppBackground()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // My Groups Section
                        myGroupsSection
                        
                        // Discover Groups Section
                        discoverGroupsSection
                        
                        // Global Leaderboard Section
                        globalLeaderboardSection
                    }
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("Groups")
            .toolbarBackground(Color.subtleBlueGradientStart.opacity(0.5), for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        Button {
                            showingSearch = true
                        } label: {
                            Image(systemName: "magnifyingglass")
                        }
                        
                        Button {
                            showingCreateGroup = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingCreateGroup) {
                CreateGroupView()
            }
            .fullScreenCover(isPresented: $showingSearch) {
                SearchView(isPresented: $showingSearch)
            }
        }
    }
    
    // MARK: - My Groups Section
    
    private var myGroupsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section Header
            HStack {
                Text("MY GROUPS")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                if mockData.myGroups.count > 3 {
                    NavigationLink {
                        MyGroupsListView()
                    } label: {
                        Text("See All")
                            .font(.subheadline)
                            .foregroundStyle(Color.appAccent)
                    }
                }
            }
            .padding(.horizontal, 16)
            
            if mockData.myGroups.isEmpty {
                // Empty State
                emptyMyGroupsState
            } else {
                // Show top 3 groups (sorted by recent activity)
                VStack(spacing: 8) {
                    ForEach(Array(mockData.myGroupsSortedByActivity.prefix(3))) { group in
                        NavigationLink {
                            GroupDetailView(group: group)
                        } label: {
                            MyGroupRowCard(group: group)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
    
    // MARK: - Empty My Groups State
    
    private var emptyMyGroupsState: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.3")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            
            Text("No groups yet")
                .font(.headline)
            
            Text("Join a group or create your own to compete with others!")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button {
                showingCreateGroup = true
            } label: {
                Text("Create Group")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.appAccent)
                    .clipShape(Capsule())
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 16)
        .background(Color.warmWhiteCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
        .padding(.horizontal, 16)
    }
    
    // MARK: - Discover Groups Section
    
    private var discoverGroupsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section Header
            Text("DISCOVER GROUPS")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
            
            if mockData.discoverGroups.isEmpty {
                Text("No public groups available")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(Color.warmWhiteCard)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
                    .padding(.horizontal, 16)
            } else {
                VStack(spacing: 8) {
                    ForEach(mockData.discoverGroups) { group in
                        DiscoverGroupRowCard(group: group)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
    
    // MARK: - Global Leaderboard Section
    
    private var globalLeaderboardSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section Header
            Text("GLOBAL LEADERBOARD")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
            
            CompactLeaderboardView()
                .padding(.horizontal, 16)
        }
    }
}

// MARK: - Discover Group Row Card

struct DiscoverGroupRowCard: View {
    let group: MockGroup
    @State private var isJoining = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Group image placeholder
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 56, height: 56)
                
                Image(systemName: "person.3.fill")
                    .font(.title3)
                    .foregroundStyle(.orange)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(group.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Text("\(group.memberCount) members")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    if group.joinMode == .requestToJoin {
                        Text("Request to join")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Join button
            Button {
                isJoining = true
                // TODO: Implement join logic
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isJoining = false
                }
            } label: {
                if isJoining {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Text(group.joinMode == .requestToJoin ? "Request" : "Join")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.appAccent)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.appAccent.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Color.warmWhiteCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
}

// MARK: - Compact Leaderboard View (Top 5 + Current User)

struct CompactLeaderboardView: View {
    private var mockData: MockDataService { MockDataService.shared }
    @State private var selectedTab: LeaderboardTab = .streak
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab Picker
            Picker("Leaderboard", selection: $selectedTab) {
                ForEach(LeaderboardTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 8)
            
            // Leaderboard entries
            VStack(spacing: 0) {
                // Top 5
                ForEach(Array(topUsers.prefix(5).enumerated()), id: \.element.id) { index, user in
                    CompactLeaderboardRow(
                        rank: index + 1,
                        user: user,
                        displayValue: displayValue(for: user)
                    )
                    
                    if index < 4 {
                        Divider()
                            .padding(.horizontal, 12)
                    }
                }
                
                // Separator if current user is not in top 5
                if let currentUser = currentUserEntry, currentUser.rank > 5 {
                    HStack {
                        ForEach(0..<3) { _ in
                            Circle()
                                .fill(Color.secondary.opacity(0.3))
                                .frame(width: 4, height: 4)
                        }
                    }
                    .padding(.vertical, 8)
                    
                    CompactLeaderboardRow(
                        rank: currentUser.rank,
                        user: currentUser,
                        displayValue: displayValue(for: currentUser)
                    )
                }
            }
            .padding(.bottom, 12)
        }
        .background(Color.warmWhiteCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
    
    private var topUsers: [LeaderboardUser] {
        switch selectedTab {
        case .streak:
            return mockData.leaderboardUsers.sorted { $0.currentStreak > $1.currentStreak }
        case .longestPlank:
            return mockData.leaderboardUsers.sorted { $0.longestPlankSeconds > $1.longestPlankSeconds }
        }
    }
    
    private var currentUserEntry: LeaderboardUser? {
        let sorted = topUsers
        if let index = sorted.firstIndex(where: { $0.isCurrentUser }) {
            var user = sorted[index]
            // Create a new user with updated rank
            return LeaderboardUser(
                rank: index + 1,
                displayName: user.displayName,
                currentStreak: user.currentStreak,
                longestPlankSeconds: user.longestPlankSeconds,
                isCurrentUser: true,
                badges: user.badges
            )
        }
        return nil
    }
    
    private func displayValue(for user: LeaderboardUser) -> String {
        switch selectedTab {
        case .streak:
            return "\(user.currentStreak) days"
        case .longestPlank:
            return user.longestPlankFormatted
        }
    }
}

// MARK: - Compact Leaderboard Row
// Now uses LeaderboardRowView component from Components/LeaderboardRowView.swift

struct CompactLeaderboardRow: View {
    let rank: Int
    let user: LeaderboardUser
    let displayValue: String
    
    var body: some View {
        LeaderboardRowView(
            rank: rank,
            name: user.displayName,
            avatarText: String(user.displayName.prefix(1)),
            displayValue: displayValue,
            isCurrentUser: user.isCurrentUser,
            avatarImageName: nil,
            size: .compact
        )
    }
}

// MARK: - Create Group View

struct CreateGroupView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var groupName = ""
    @State private var groupDescription = ""
    @State private var isPrivate = false
    @State private var requiresApproval = false
    
    private var isValid: Bool {
        !groupName.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Group Info") {
                    // Group image
                    HStack {
                        Spacer()
                        ZStack {
                            Circle()
                                .fill(Color.appAccent.opacity(0.2))
                                .frame(width: 100, height: 100)
                            
                            Image(systemName: "camera.fill")
                                .font(.title)
                                .foregroundStyle(Color.appAccent)
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                    
                    TextField("Group Name", text: $groupName)
                    
                    TextField("Description (optional)", text: $groupDescription, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section {
                    Toggle("Private Group", isOn: $isPrivate)
                    
                    if !isPrivate {
                        Toggle("Require Approval to Join", isOn: $requiresApproval)
                    }
                } header: {
                    Text("Privacy")
                } footer: {
                    if isPrivate {
                        Text("Private groups are not searchable. You'll need to invite members.")
                    } else if requiresApproval {
                        Text("You'll need to approve each join request.")
                    } else {
                        Text("Anyone can find and join this group.")
                    }
                }
                
                Section {
                    Button {
                        // Create group
                        dismiss()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Create Group")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(!isValid)
                }
            }
            .navigationTitle("Create Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    GroupsView()
}
