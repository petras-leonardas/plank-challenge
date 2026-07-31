//
//  GroupDetailView.swift
//  PlankChallenge
//
//  Created by Leo Bacevicius on 08/03/2026.
//

import SwiftUI

// MARK: - Group Ranked Group (view-layer tie grouping for group leaderboards)

struct GroupRankedGroup: Identifiable {
    let rank: Int
    let entries: [GroupLeaderboardEntry]
    let containsCurrentUser: Bool
    var id: Int { rank }
}

func groupGroupsByRank(
    _ entries: [GroupLeaderboardEntry],
    currentUserId: String?
) -> [GroupRankedGroup] {
    var groups: [GroupRankedGroup] = []
    var i = 0
    while i < entries.count {
        let currentRank = entries[i].rank
        var group: [GroupLeaderboardEntry] = []
        while i < entries.count && entries[i].rank == currentRank {
            group.append(entries[i])
            i += 1
        }
        groups.append(GroupRankedGroup(
            rank: currentRank,
            entries: group,
            containsCurrentUser: group.contains(where: { $0.user.id == currentUserId })
        ))
    }
    return groups
}

// MARK: - Group Tied Avatar Stack

struct GroupTiedAvatarStack: View {
    let entries: [GroupLeaderboardEntry]
    var size: CGFloat = 32

    private var visible: [GroupLeaderboardEntry] { Array(entries.prefix(3)) }
    private var overflow: Int { max(0, entries.count - 3) }

    var body: some View {
        HStack(spacing: -(size * 0.3)) {
            ForEach(Array(visible.enumerated()), id: \.element.id) { index, entry in
                AvatarView.accent(
                    name: entry.user.displayName,
                    imageUrl: entry.user.profileImageUrl,
                    size: size
                )
                .overlay(Circle().stroke(Color.warmWhiteCard, lineWidth: 2))
                .zIndex(Double(visible.count - index))
            }

            if overflow > 0 {
                ZStack {
                    Circle()
                        .fill(Color.appAccent.opacity(0.15))
                        .frame(width: size, height: size)
                    Text("+\(overflow)")
                        .font(.system(size: size * 0.35, weight: .semibold))
                        .foregroundStyle(Color.appAccent)
                }
                .overlay(Circle().stroke(Color.warmWhiteCard, lineWidth: 2))
                }
            }
        }
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
            if !leaderboardService.hasLoaded && leaderboardService.groupLeaderboard.isEmpty {
                GroupLeaderboardSectionSkeleton()
                    .transition(.opacity)
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
                let currentUserId = leaderboardService.groupCurrentUserRank?.user.id
                let groups = groupGroupsByRank(topEntries, currentUserId: currentUserId)
                let currentUserInTop = leaderboardService.groupCurrentUserRank.map { rank in
                    topEntries.contains(where: { $0.user.id == rank.user.id })
                } ?? true

                VStack(spacing: 0) {
                    ForEach(Array(groups.enumerated()), id: \.element.id) { index, group in
                        if group.entries.count == 1 {
                            // Single user at this rank — tappable to profile
                            let entry = group.entries[0]
                            let isCurrentUser = entry.user.id == currentUserId
                            NavigationLink {
                                UserProfileView(userId: entry.user.id)
                            } label: {
                                GroupLeaderboardRow(
                                    entry: entry,
                                    isCurrentUser: isCurrentUser,
                                    metric: selectedLeaderboard
                                )
                            }
                            .buttonStyle(.plain)
                        } else {
                            // Multiple tied users — tappable to tied list
                            NavigationLink {
                                GroupTiedUsersListView(group: group, metric: selectedLeaderboard)
                            } label: {
                                GroupTiedLeaderboardRow(
                                    group: group,
                                    metric: selectedLeaderboard
                                )
                            }
                            .buttonStyle(.plain)
                        }

                        if index < groups.count - 1 {
                            Divider().padding(.leading, 60)
                        }
                    }

                    // Show the current user's rank if they fall outside the top list
                    if let myRank = leaderboardService.groupCurrentUserRank, !currentUserInTop {
                        Divider().padding(.leading, 60)
                        GroupLeaderboardRow(
                            entry: myRank,
                            isCurrentUser: true,
                            metric: selectedLeaderboard
                        )
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: leaderboardService.hasLoaded)
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
        if groupService.isCurrentUserMember {
            // Members (including admin) manage the group via the gear icon in the toolbar.
            EmptyView()
        } else if group.pendingRequest == true {
            // User already has a pending join request — non-actionable state
            Button { } label: {
                Label("Request sent", systemImage: "clock")
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(true)
            .opacity(0.6)
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

// MARK: - Group Tied Leaderboard Row

/// A leaderboard row for a rank position shared by multiple group members.
struct GroupTiedLeaderboardRow: View {
    let group: GroupRankedGroup
    let metric: GroupDetailView.LeaderboardType

    var body: some View {
        HStack(spacing: 12) {
            RankBadge(rank: group.rank, size: 28, font: .caption)
                .frame(width: 32)

            GroupTiedAvatarStack(entries: group.entries)

            Text("\(group.entries.count) tied")
                .font(.body)
                .fontWeight(group.containsCurrentUser ? .semibold : .regular)
                .foregroundStyle(.primary)

            Spacer()

            Text(scoreLabel)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(Color.appAccent)
        }
        .padding(.vertical, 8)
        .background(group.containsCurrentUser ? Color.appAccent.opacity(0.08) : Color.clear)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Rank \(group.rank), \(group.entries.count) tied users, \(scoreLabel)")
    }

    private var scoreLabel: String {
        guard let first = group.entries.first else { return "" }
        switch metric {
        case .streak:
            let streak = first.user.currentStreak ?? 0
            return streak == 1 ? "1 day" : "\(streak) days"
        case .longestPlank:
            return formatDuration(first.stats.bestPlank)
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
