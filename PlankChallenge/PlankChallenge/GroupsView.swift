//
//  GroupsView.swift
//  PlankChallenge
//
//  Created by Leo Bacevicius on 08/03/2026.
//

import SwiftUI
import PhotosUI

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
                        NavigationLink {
                            GroupDetailView(groupId: group.id)
                        } label: {
                            DiscoverGroupRowCard(group: group)
                        }
                        .buttonStyle(.plain)
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
    
    var body: some View {
        HStack(spacing: 12) {
            // Group image
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
                
                HStack(spacing: 8) {
                    Text("\(group.memberCount) members")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    if group.requiresApproval {
                        Text("· Approval required")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .appCardStyleCompact()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(group.name), \(group.memberCount) members\(group.requiresApproval ? ", approval required" : "")")
        .accessibilityHint("Tap to view group details")
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
            } else if activeLeaderboard.isEmpty {
                Text(selectedTab == .friends ? "Follow people to see who's been active" : "No leaderboard data")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
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
    
    /// The leaderboard entries to display for the current tab.
    private var activeLeaderboard: [APILeaderboardEntry] {
        selectedTab == .friends
            ? leaderboardService.followingLeaderboard
            : leaderboardService.globalLeaderboard
    }
    
    /// The current user's rank entry for the current tab (nil for friends tab).
    private var activeUserRank: APILeaderboardEntry? {
        selectedTab == .friends ? nil : leaderboardService.userGlobalRank
    }
    
    private var leaderboardContent: some View {
        VStack(spacing: 0) {
            let top5 = Array(activeLeaderboard.prefix(5))
            
            ForEach(Array(top5.enumerated()), id: \.element.id) { index, entry in
                CompactLeaderboardRow(entry: entry)
                
                if index < top5.count - 1 {
                    Divider()
                        .padding(.horizontal, 12)
                }
            }
            
            // Show current user's rank if they fall outside the top 5 (global tabs only)
            if let userRank = activeUserRank, userRank.rank > 5 {
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
        do {
            switch tab {
            case .streak:
                try await leaderboardService.fetchGlobalLeaderboard(
                    type: .streak, period: .weekly, limit: 5)
            case .longestPlank:
                try await leaderboardService.fetchGlobalLeaderboard(
                    type: .longestPlank, period: .weekly, limit: 5)
            case .friends:
                try await leaderboardService.fetchFollowingLeaderboard(
                    type: .streak, period: .weekly)
            }
        } catch {
            // Error is stored in leaderboardService.error
        }
    }
}

// MARK: - Compact Leaderboard Row (uses APILeaderboardEntry)

struct CompactLeaderboardRow: View {
    let entry: APILeaderboardEntry
    
    var body: some View {
        NavigationLink {
            UserProfileView(userId: entry.user.id)
        } label: {
            LeaderboardRowView(
                rank: entry.rank,
                name: entry.user.displayName,
                avatarText: String(entry.user.displayName.prefix(1)),
                displayValue: entry.scoreLabel,
                isCurrentUser: entry.isCurrentUser,
                avatarImageName: entry.user.profileImageUrl,
                size: .compact
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Create Group View

struct CreateGroupView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.groupService) private var groupService
    @Environment(\.mediaService) private var mediaService
    
    @State private var groupName = ""
    @State private var groupDescription = ""
    @State private var isPrivate = false
    @State private var requiresApproval = false
    @State private var isCreating = false
    @State private var createError: Error?
    
    // Photo picker state
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    
    private var isValid: Bool {
        !groupName.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Photo picker — its own section so the card background
                // doesn't clip the first text field below it
                Section {
                    HStack {
                        Spacer()
                        PhotosPicker(
                            selection: $selectedPhotoItem,
                            matching: .images,
                            photoLibrary: .shared()
                        ) {
                            ZStack {
                                Circle()
                                    .fill(Color.appAccent.opacity(0.15))
                                    .frame(width: 100, height: 100)
                                
                                if let image = selectedImage {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 100, height: 100)
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(Color.appAccent, lineWidth: 2))
                                } else {
                                    VStack(spacing: 4) {
                                        Image(systemName: "camera.fill")
                                            .font(.title2)
                                            .foregroundStyle(Color.appAccent)
                                        Text("Add Photo")
                                            .font(.caption2)
                                            .foregroundStyle(Color.appAccent)
                                    }
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                    .padding(.vertical, 8)
                }
                
                Section("Group Info") {
                    LabeledContent("Name") {
                        TextField("e.g. Office Core Club", text: $groupName)
                            .multilineTextAlignment(.trailing)
                    }
                    .accessibilityLabel("Group name")
                    
                    TextField("Description (optional)", text: $groupDescription, axis: .vertical)
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
                    Button("Cancel") { dismiss() }
                        .disabled(isCreating)
                }
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        selectedImage = image
                    }
                }
            }
        }
    }
    
    private func createGroup() async {
        isCreating = true
        createError = nil
        defer { isCreating = false }
        
        // Backend accepts: groupType = "public"|"private", joinMode = "open"|"request"
        let groupType: APIGroupType = isPrivate ? .private : .public
        let joinMode: APIJoinMode = (isPrivate || requiresApproval) ? .request : .open
        
        do {
            let newGroup = try await groupService.createGroup(
                name: groupName.trimmingCharacters(in: .whitespaces),
                description: groupDescription.isEmpty ? nil : groupDescription,
                groupType: groupType,
                joinMode: joinMode
            )
            
            // Upload group photo if one was selected (non-fatal — group is created regardless).
            // Capture the returned URL and patch the in-memory list immediately so the
            // group card shows the photo without needing a full re-fetch.
            if let image = selectedImage,
               let newImageUrl = try? await mediaService.uploadGroupImage(groupId: newGroup.id, image: image) {
                groupService.updateGroupImage(groupId: newGroup.id, imageUrl: newImageUrl)
            }
            
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
