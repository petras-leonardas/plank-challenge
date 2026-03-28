//
//  GroupDetailView.swift
//  PlankChallenge
//
//  Created by Leo Bacevicius on 08/03/2026.
//

import SwiftUI

struct GroupDetailView: View {
    let groupId: String
    
    @Environment(\.groupService) private var groupService
    @Environment(\.leaderboardService) private var leaderboardService
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedLeaderboard: LeaderboardType = .streak
    @State private var showingLeaveConfirmation = false
    @State private var isLeaving = false
    @State private var isJoining = false
    @State private var actionError: Error?
    @State private var showingActionError = false
    /// Set to true once loadGroupData() has completed at least once.
    /// Used to guard .task(id: selectedLeaderboard) against firing before
    /// the initial group load has finished.
    @State private var hasInitiallyLoaded = false
    @State private var showingSettings = false
    
    enum LeaderboardType: String, CaseIterable {
        case streak = "Streak"
        case longestPlank = "Longest"
    }
    
    var body: some View {
        ZStack {
            AppBackground()
            
            Group {
                if groupService.isLoading && groupService.currentGroup == nil {
                    loadingView
                } else if let error = groupService.error, groupService.currentGroup == nil {
                    ErrorView(error: error) {
                        await loadGroupData()
                    }
                } else if let group = groupService.currentGroup {
                    groupContent(group)
                } else {
                    // Fallback empty state
                    Text("Group not found")
                    .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(groupService.currentGroup?.name ?? "Group")
        .navigationBarTitleDisplayMode(.inline)
        .appNavigationBarStyle()
        .toolbar {
            if groupService.isCurrentUserAdmin {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Group settings")
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            GroupSettingsView(groupId: groupId)
        }
        // When the settings sheet closes after a delete, currentGroup will be nil.
        // Pop back to the groups list automatically.
        .onChange(of: showingSettings) { _, isShowing in
            if !isShowing && groupService.currentGroup == nil && !groupService.isLoading {
                dismiss()
            }
        }
        .alert("Leave this group?", isPresented: $showingLeaveConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Leave", role: .destructive) {
                Task { await leaveGroup() }
            }
        } message: {
            Text("You'll be removed from the leaderboard. You can always rejoin.")
        }
        .alert("Something went wrong", isPresented: $showingActionError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(actionError?.localizedDescription ?? "Couldn't complete that action. Try again.")
        }
        .refreshable {
            await loadGroupData()
        }
        .task {
            await loadGroupData()
        }
        // Re-fetches leaderboard and cancels the previous fetch whenever the
        // leaderboard type picker changes — prevents racing concurrent fetches.
        // hasInitiallyLoaded guards against firing before the initial group load
        // has completed (avoids a race with the initial .task above).
        .task(id: selectedLeaderboard) {
            guard hasInitiallyLoaded else { return }
            await loadLeaderboard()
        }
        .onDisappear {
            groupService.clearCurrentGroup()
        }
    }
    
    // MARK: - Subviews
    
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading group...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func groupContent(_ group: APIGroup) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                groupHeader(group)
                
                // Leaderboard section
                leaderboardSection
                
                // Members section
                membersSection(group)
                
                // Actions
                actionsSection(group)
            }
            .padding()
        }
    }
    
    // MARK: - Header
    
    private func groupHeader(_ group: APIGroup) -> some View {
        VStack(spacing: 12) {
            // Group image
            ZStack {
                Circle()
                    .fill(Color.appAccent.opacity(0.2))
                    .frame(width: 80, height: 80)
                
                if let imageUrl = group.imageUrl {
                    AsyncImage(url: URL(string: imageUrl)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Image(systemName: "person.3.fill")
                            .font(.largeTitle)
                            .foregroundStyle(Color.appAccent)
                    }
                    .frame(width: 80, height: 80)
                    .clipShape(Circle())
                } else {
                    Image(systemName: "person.3.fill")
                        .font(.largeTitle)
                        .foregroundStyle(Color.appAccent)
                }
            }
            
            // Group info
            VStack(spacing: 4) {
                HStack {
                    Text(group.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if group.isPrivate {
                        Image(systemName: "lock.fill")
                            .foregroundStyle(.secondary)
                    }
                }
                
                Text("\(group.memberCount) members")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            // Description
            if let description = group.description, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .appCardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(group.name), \(group.memberCount) members")
    }
    
    // MARK: - Leaderboard Section
    
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
            if leaderboardService.isLoading {
                ProgressView()
                    .padding(.vertical, 20)
            } else if let leaderboardError = leaderboardService.error {
                // Leaderboard-only error — show inline rather than blocking the whole screen
                Text("Couldn't load leaderboard: \(leaderboardError.localizedDescription)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 20)
            } else if leaderboardService.groupLeaderboard.isEmpty {
                Text("No data yet — complete planks to get on the board")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 20)
            } else {
                let topEntries = Array(leaderboardService.groupLeaderboard.prefix(10))
                let currentUserInTop = leaderboardService.groupCurrentUserRank.map { rank in
                    topEntries.contains(where: { $0.user.id == rank.user.id })
                } ?? true
                
                VStack(spacing: 0) {
                    ForEach(Array(topEntries.enumerated()), id: \.element.id) { index, entry in
                        let isCurrentUser = leaderboardService.groupCurrentUserRank?.user.id == entry.user.id
                        GroupLeaderboardRow(
                            entry: entry,
                            isCurrentUser: isCurrentUser,
                            metric: selectedLeaderboard
                        )
                        
                        if index < topEntries.count - 1 {
                            Divider()
                                .padding(.leading, 60)
                        }
                    }
                    
                    // Show the current user's rank if they fall outside the top list
                    if let myRank = leaderboardService.groupCurrentUserRank, !currentUserInTop {
                        Divider()
                            .padding(.leading, 60)
                        GroupLeaderboardRow(
                            entry: myRank,
                            isCurrentUser: true,
                            metric: selectedLeaderboard
                        )
                    }
                }
            }
        }
        .appCardStyle()
    }
    
    // MARK: - Members Section
    
    private func membersSection(_ group: APIGroup) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            AppSectionHeader(title: "MEMBERS") {
                GroupMembersListView(groupId: groupId)
            }
            
            // Preview of members using AvatarView
            if groupService.currentGroupMembers.isEmpty {
                Text("Loading members...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Loading members")
            } else {
                HStack(spacing: -10) {
                    ForEach(groupService.currentGroupMembers.prefix(5)) { member in
                        AvatarView(
                            text: member.displayName,
                            imageUrl: member.profileImageUrl,
                            size: Constants.UI.avatarSmall
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
        }
        .appCardStyle()
    }
    
    // MARK: - Actions Section
    
    @ViewBuilder
    private func actionsSection(_ group: APIGroup) -> some View {
        if groupService.isCurrentUserMember && !groupService.isCurrentUserAdmin {
            Button(role: .destructive) {
                showingLeaveConfirmation = true
            } label: {
                if isLeaving {
                    ProgressView()
                } else {
                    Text("Leave Group")
                }
            }
            .buttonStyle(DestructiveButtonStyle(filled: false))
            .disabled(isLeaving)
        } else {
            Button {
                Task { await joinGroup() }
            } label: {
                if isJoining {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(group.requiresApproval ? "Request to Join" : "Join Group")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(isJoining)
        }
    }
    
    // MARK: - Data Loading
    
    private func loadGroupData() async {
        // Load the critical group data (detail + members) together.
        // These two share state in GroupService and must both succeed for the
        // group screen to be usable, so we keep them coupled.
        do {
            async let groupTask: APIGroup = groupService.fetchGroup(id: groupId)
            async let membersTask: Void = groupService.fetchGroupMembers(groupId: groupId)
            _ = try await (groupTask, membersTask)
        } catch is CancellationError {
            // View disappeared mid-load — not a user error, do not surface
            return
        } catch {
            // Error is stored in groupService.error and shown via ErrorView
        }
        
        // Load the leaderboard independently so a decode failure there does NOT
        // prevent the group screen from showing. The leaderboard section handles
        // its own error/loading state.
        await loadLeaderboard()
        
        // Mark initial load complete so the .task(id: selectedLeaderboard) can fire
        hasInitiallyLoaded = true
    }
    
    private func loadLeaderboard() async {
        let metric: LeaderboardService.LeaderboardMetric = selectedLeaderboard == .streak ? .streak : .longestPlank
        do {
            try await leaderboardService.fetchGroupLeaderboard(groupId: groupId, metric: metric, period: .weekly)
        } catch is CancellationError {
            // Cancelled — not a user error
        } catch {
            // Error is stored in leaderboardService.error and shown in the leaderboard section
        }
    }
    
    private func leaveGroup() async {
        isLeaving = true
        defer { isLeaving = false }
        
        do {
            try await groupService.leaveGroup(id: groupId)
            // Successfully left - navigate back
            dismiss()
        } catch is CancellationError {
            // Cancelled — not a user error
        } catch {
            actionError = error
            showingActionError = true
        }
    }
    
    private func joinGroup() async {
        isJoining = true
        defer { isJoining = false }
        
        do {
            try await groupService.joinGroup(id: groupId)
            // Refresh to show updated membership status
            await loadGroupData()
        } catch is CancellationError {
            // Cancelled — not a user error
        } catch {
            actionError = error
            showingActionError = true
        }
    }
}

// MARK: - Group Leaderboard Row

struct GroupLeaderboardRow: View {
    let entry: GroupLeaderboardEntry
    /// When true the row is highlighted as the current user's own entry.
    var isCurrentUser: Bool = false
    /// Controls which stat value is shown (streak vs. duration).
    var metric: GroupDetailView.LeaderboardType = .streak
    
    var body: some View {
        HStack(spacing: 12) {
            // Rank Badge
            RankBadge(rank: entry.rank, size: 28, font: .caption)
                .frame(width: 32)
            
            // Avatar
            AvatarView.accent(
                name: entry.user.displayName,
                imageUrl: entry.user.profileImageUrl,
                size: Constants.UI.avatarSmall
            )
            
            // Name
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.user.displayName)
                    .font(.body)
                    .fontWeight(isCurrentUser ? .semibold : .regular)
                
                if isCurrentUser {
                    Text("You")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // Value — derived from stats based on the selected metric
            Text(scoreLabel)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(Color.appAccent)
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Rank \(entry.rank), \(entry.user.displayName), \(scoreLabel)")
    }
    
    private var scoreLabel: String {
        switch metric {
        case .streak:
            let streak = entry.user.currentStreak ?? 0
            return streak == 1 ? "1 day" : "\(streak) days"
        case .longestPlank:
            return formatDuration(entry.stats.bestPlank)
        }
    }
    
    private func formatDuration(_ seconds: Double) -> String {
        let total = Int(seconds)
        if total >= 60 {
            let mins = total / 60
            let secs = total % 60
            return secs > 0 ? "\(mins)m \(secs)s" : "\(mins)m"
        }
        return "\(total)s"
    }
}

#Preview {
    NavigationStack {
        GroupDetailView(groupId: "preview-group-id")
            .withMockServices()
    }
}
