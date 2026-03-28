//
//  GroupsView.swift
//  PlankChallenge
//
//  Created by Leo Bacevicius on 08/03/2026.
//

import SwiftUI

// MARK: - Groups View

struct GroupsView: View {
    @Environment(\.groupService) private var groupService
    @State private var showingCreateGroup = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // App background with subtle gradient
                AppBackground()
                
                Group {
                    if groupService.isLoading && !groupService.hasLoaded {
                        loadingView
                    } else if let error = groupService.error, !groupService.hasLoaded {
                        ErrorView(error: error) {
                            await loadData()
                        }
                    } else {
                        contentView
                    }
                }
            }
            .navigationTitle("Groups")
            .appNavigationBarStyle()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingCreateGroup = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Create new group")
                }
            }
            .sheet(isPresented: $showingCreateGroup) {
                CreateGroupView()
            }
            .refreshable {
                await loadData()
            }
            .task {
                if !groupService.hasLoaded {
                    await loadData()
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading groups...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var contentView: some View {
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
    
    // MARK: - My Groups Section
    
    private var myGroupsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section Header
            Group {
                if groupService.myGroups.count > 3 {
                    AppSectionHeader(title: "MY GROUPS") {
                        MyGroupsListView()
                    }
                } else {
                    AppSectionHeader<EmptyView>(title: "MY GROUPS")
                }
            }
            .padding(.horizontal, 16)
            
            if groupService.myGroups.isEmpty {
                // Empty State
                emptyMyGroupsState
            } else {
                // Show top 3 groups (sorted by most recent update)
                VStack(spacing: 8) {
                    ForEach(Array(sortedMyGroups.prefix(3))) { group in
                        NavigationLink {
                            GroupDetailView(groupId: group.id)
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
    
    /// My groups sorted by most recent activity (updatedAt)
    private var sortedMyGroups: [APIGroup] {
        groupService.myGroups.sorted { $0.updatedDate > $1.updatedDate }
    }
    
    // MARK: - Empty My Groups State
    
    private var emptyMyGroupsState: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.3")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            
            Text("No groups yet")
                .font(.headline)
            
            Text("Groups are where things get competitive. Create one or join an existing group to get on a shared leaderboard.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button {
                showingCreateGroup = true
            } label: {
                Text("Create a group")
            }
            .pillButtonStyle(isSelected: true)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .appCardStyle()
        .padding(.horizontal, 16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No groups yet. Join a group or create your own to compete with others.")
    }
    
    // MARK: - Discover Groups Section
    
    private var discoverGroupsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section Header
            AppSectionHeader<EmptyView>(title: "DISCOVER GROUPS")
                .padding(.horizontal, 16)
            
            if groupService.discoverGroups.isEmpty {
                Text("No public groups available")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .appCardStyleCompact()
                    .padding(.horizontal, 16)
            } else {
                VStack(spacing: 8) {
                    ForEach(groupService.discoverGroups) { group in
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
            AppSectionHeader<EmptyView>(title: "GLOBAL LEADERBOARD")
                .padding(.horizontal, 16)
            
            CompactLeaderboardView()
                .padding(.horizontal, 16)
        }
    }
    
    // MARK: - Data Loading
    
    private func loadData() async {
        do {
            // Load both my groups and discover groups in parallel
            async let myGroupsTask: () = groupService.fetchMyGroups()
            async let discoverTask: () = groupService.fetchDiscoverGroups()
            
            _ = try await (myGroupsTask, discoverTask)
        } catch {
            // Errors are stored in service
        }
    }
}

// MARK: - My Group Row Card (uses APIGroup)

struct MyGroupRowCard: View {
    let group: APIGroup
    
    var body: some View {
        HStack(spacing: 12) {
            // Group image placeholder
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.appAccent.opacity(0.15))
                    .frame(width: 56, height: 56)
                
                if let imageUrl = group.imageUrl {
                    AsyncImage(url: URL(string: imageUrl)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Image(systemName: "person.3.fill")
                            .font(.title3)
                            .foregroundStyle(Color.appAccent)
                    }
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    Image(systemName: "person.3.fill")
                        .font(.title3)
                        .foregroundStyle(Color.appAccent)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(group.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    
                    if group.isPrivate {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Text("\(group.memberCount) members")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .appCardStyleCompact()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(group.name), \(group.memberCount) members")
        .accessibilityHint("Tap to view group details")
    }
}

// MARK: - Discover Group Row Card (uses APIGroup)

struct DiscoverGroupRowCard: View {
    let group: APIGroup
    @Environment(\.groupService) private var groupService
    
    @State private var isJoining = false
    @State private var showingJoinError = false
    @State private var joinErrorMessage: String?
    
    var body: some View {
        HStack(spacing: 12) {
            // Group image placeholder
            ZStack {
                RoundedRectangle(cornerRadius: Constants.UI.cardRadius)
                    .fill(Color.appAccent.opacity(0.15))
                    .frame(width: 56, height: 56)
                
                if let imageUrl = group.imageUrl {
                    AsyncImage(url: URL(string: imageUrl)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Image(systemName: "person.3.fill")
                            .font(.title3)
                            .foregroundStyle(Color.appAccent)
                    }
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: Constants.UI.cardRadius))
                } else {
                    Image(systemName: "person.3.fill")
                        .font(.title3)
                        .foregroundStyle(Color.appAccent)
                }
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
                    
                    if group.requiresApproval {
                        Text("Approval required")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Join button
            Group {
                if isJoining {
                    ProgressView()
                        .scaleEffect(0.8)
                        .frame(width: 70, height: 32)
                } else {
                    Button {
                        Task { await joinGroup() }
                    } label: {
                        Text(group.requiresApproval ? "Request to join" : "Join")
                    }
                    .pillButtonStyle(isSelected: false)
                    .disabled(isJoining)
                }
            }
        }
        .appCardStyleCompact()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(group.name), \(group.memberCount) members")
        .accessibilityHint(group.requiresApproval ? "Tap to request to join" : "Tap to join group")
        .alert("Couldn't join", isPresented: $showingJoinError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(joinErrorMessage ?? "Something went wrong. Try again.")
        }
    }
    
    private func joinGroup() async {
        isJoining = true
        defer { isJoining = false }
        
        do {
            try await groupService.joinGroup(id: group.id)
        } catch {
            joinErrorMessage = error.localizedDescription
            showingJoinError = true
        }
    }
}

// MARK: - Compact Leaderboard View (Top 5 + Current User)

struct CompactLeaderboardView: View {
    @Environment(\.leaderboardService) private var leaderboardService
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
            .onChange(of: selectedTab) { _, newTab in
                Task { await loadLeaderboard(for: newTab) }
            }
            
            // Leaderboard entries
            if leaderboardService.isLoading {
                ProgressView()
                    .padding(.vertical, 40)
            } else if leaderboardService.globalLeaderboard.isEmpty {
                Text("No leaderboard data")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 40)
            } else {
                leaderboardContent
            }
        }
        .appCardStyle()
        .task {
            await loadLeaderboard(for: selectedTab)
        }
    }
    
    private var leaderboardContent: some View {
        VStack(spacing: 0) {
            // Top 5
            ForEach(Array(leaderboardService.globalLeaderboard.prefix(5).enumerated()), id: \.element.id) { index, entry in
                CompactLeaderboardRow(entry: entry)
                
                if index < min(4, leaderboardService.globalLeaderboard.count - 1) {
                    Divider()
                        .padding(.horizontal, 12)
                }
            }
            
            // Separator if current user is not in top 5
            if let userRank = leaderboardService.userGlobalRank, userRank.rank > 5 {
                HStack {
                    ForEach(0..<3, id: \.self) { _ in
                        Circle()
                            .fill(Color.secondary.opacity(0.3))
                            .frame(width: 4, height: 4)
                    }
                }
                .padding(.vertical, 8)
                
                CompactLeaderboardRow(entry: userRank)
            }
        }
        .padding(.bottom, 12)
    }
    
    private func loadLeaderboard(for tab: LeaderboardTab) async {
        let type: LeaderboardService.LeaderboardType = tab == .streak ? .streak : .longestPlank
        do {
            try await leaderboardService.fetchGlobalLeaderboard(type: type, period: .weekly, limit: 5)
        } catch {
            // Error handled in service
        }
    }
}

// MARK: - Compact Leaderboard Row (uses APILeaderboardEntry)

struct CompactLeaderboardRow: View {
    let entry: APILeaderboardEntry
    
    var body: some View {
        LeaderboardRowView(
            rank: entry.rank,
            name: entry.user.displayName,
            avatarText: String(entry.user.displayName.prefix(1)),
            displayValue: entry.scoreLabel,
            isCurrentUser: entry.isCurrentUser,
            avatarImageName: nil,
            size: .compact
        )
    }
}

// MARK: - Create Group View

struct CreateGroupView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.groupService) private var groupService
    
    @State private var groupName = ""
    @State private var groupDescription = ""
    @State private var isPrivate = false
    @State private var requiresApproval = false
    @State private var isCreating = false
    @State private var createError: Error?
    
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
                    
                    LabeledContent("Group Name") {
                        TextField("e.g. Office Core Club", text: $groupName)
                            .multilineTextAlignment(.trailing)
                    }
                    .accessibilityLabel("Group name")
                    
                    TextField("What's this group about? (optional)", text: $groupDescription, axis: .vertical)
                        .lineLimit(3...6)
                        .accessibilityLabel("Group description, optional")
                }
                
                Section {
                    Toggle("Private group", isOn: $isPrivate)
                        .accessibilityHint("Private groups are not searchable. You'll need to invite members.")
                    
                    if !isPrivate {
                        Toggle("Require approval to join", isOn: $requiresApproval)
                            .accessibilityHint("You'll need to approve each join request.")
                    }
                } header: {
                    Text("Privacy")
                } footer: {
                    if isPrivate {
                        Text("Only people you invite can find or join this group.")
                    } else if requiresApproval {
                        Text("Anyone can find it, but you'll approve each request.")
                    } else {
                        Text("Anyone can find and join this group.")
                    }
                }
                
                if let error = createError {
                    Section {
                        CompactErrorView(error.localizedDescription)
                    }
                }
                
                Section {
                    Button {
                        Task { await createGroup() }
                    } label: {
                        HStack {
                            Spacer()
                            if isCreating {
                                ProgressView()
                            } else {
                                Text("Create Group")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(!isValid || isCreating)
                }
            }
            .navigationTitle("New Group")
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
    
    private func createGroup() async {
        isCreating = true
        createError = nil
        defer { isCreating = false }
        
        let joinMode: APIJoinMode
        if isPrivate {
            joinMode = .inviteOnly
        } else if requiresApproval {
            joinMode = .approval
        } else {
            joinMode = .open
        }
        
        do {
            try await groupService.createGroup(
                name: groupName.trimmingCharacters(in: .whitespaces),
                description: groupDescription.isEmpty ? nil : groupDescription,
                groupType: isPrivate ? .friends : .community,
                joinMode: joinMode
            )
            dismiss()
        } catch {
            createError = error
        }
    }
}

#Preview {
    GroupsView()
        .withMockServices()
}
