//
//  LeaderboardView.swift
//  PlankChallenge
//
//  Created by Leo Bacevicius on 08/03/2026.
//

import SwiftUI

// MARK: - Leaderboard Type Enum

enum LeaderboardTab: String, CaseIterable {
    case streak = "Streak"
    case longestPlank = "Longest Plank"

    var serviceType: LeaderboardService.LeaderboardType {
        switch self {
        case .streak: return .streak
        case .longestPlank: return .longestPlank
        }
    }
}

// MARK: - Ranked Group (view-layer grouping of tied entries)

/// A single rank position that may contain one or more users with identical scores.
struct RankedGroup: Identifiable {
    let rank: Int
    let scoreLabel: String
    let entries: [APILeaderboardEntry]
    let containsCurrentUser: Bool

    var id: Int { rank }
}

/// Groups a flat sorted entry list by rank number, producing one `RankedGroup` per
/// distinct rank. Call this after the backend returns DENSE_RANK-assigned entries.
func groupByRank(_ entries: [APILeaderboardEntry]) -> [RankedGroup] {
    var groups: [RankedGroup] = []
    var i = 0
    while i < entries.count {
        let currentRank = entries[i].rank
        var group: [APILeaderboardEntry] = []
        while i < entries.count && entries[i].rank == currentRank {
            group.append(entries[i])
            i += 1
        }
        groups.append(RankedGroup(
            rank: currentRank,
            scoreLabel: group[0].scoreLabel,
            entries: group,
            containsCurrentUser: group.contains(where: { $0.isCurrentUser })
        ))
    }
    return groups
}

// MARK: - Standalone Leaderboard View (for backwards compatibility)

struct LeaderboardView: View {
    var body: some View {
        NavigationStack {
            RankingsContent()
                .navigationTitle("Rankings")
        }
    }
}

// MARK: - Rankings Content (embedded in Groups → Rankings segment)

struct RankingsContent: View {
    @Environment(\.leaderboardService) private var leaderboardService
    @State private var showingError = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                leaderboardCard(
                    title: "STREAK",
                    entries: leaderboardService.globalLeaderboard,
                    userRank: leaderboardService.userGlobalRank,
                    tab: .streak
                )
                leaderboardCard(
                    title: "LONGEST PLANK",
                    entries: leaderboardService.globalLeaderboardLongestPlank,
                    userRank: leaderboardService.userLongestPlankRank,
                    tab: .longestPlank
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .refreshable {
            await loadBoth()
        }
        .task {
            await loadBoth()
        }
        .onChange(of: leaderboardService.isStale) { _, isStale in
            guard isStale else { return }
            Task { await loadBoth() }
        }
        .alert("Couldn't load rankings", isPresented: $showingError) {
            Button("Retry") {
                errorMessage = nil
                Task { await loadBoth() }
            }
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Something went wrong. Try again.")
        }
    }

    // MARK: - Card builder

    @ViewBuilder
    private func leaderboardCard(
        title: String,
        entries: [APILeaderboardEntry],
        userRank: APILeaderboardEntry?,
        tab: LeaderboardTab
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                Spacer()

                NavigationLink {
                    FullLeaderboardListView(tab: tab)
                } label: {
                    Text("See All")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.appAccent)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            if !leaderboardService.hasLoaded {
                RankingsCardSkeleton()
                    .transition(.opacity)
                    .padding(.bottom, 12)
            } else if entries.isEmpty {
                Text("No data yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            } else {
                // Show top 5 entries grouped by rank (ties share a row)
                let top5 = Array(entries.prefix(5))
                let groups = groupByRank(top5)

                VStack(spacing: 0) {
                    ForEach(Array(groups.enumerated()), id: \.element.id) { index, group in
                        TiedLeaderboardRow(group: group)
                        if index < groups.count - 1 {
                            Divider().padding(.horizontal)
                        }
                    }

                    // Pin current user if they fall outside the top 5
                    if let rank = userRank, rank.rank > 5 {
                        Divider().padding(.horizontal)
                        HStack {
                            ForEach(0..<3, id: \.self) { _ in
                                Circle()
                                    .fill(Color.secondary.opacity(0.3))
                                    .frame(width: 4, height: 4)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        APILeaderboardRow(entry: rank)
                    }
                }
                .padding(.bottom, 4)
            }
        }
        .appCardStyle()
    }

    // MARK: - Data Loading

    private func loadBoth() async {
        do {
            try await leaderboardService.fetchGlobalLeaderboardBoth(limit: 5)
        } catch is CancellationError {
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}

// MARK: - Full Leaderboard List View (See All destination)

struct FullLeaderboardListView: View {
    let tab: LeaderboardTab

    @Environment(\.leaderboardService) private var leaderboardService
    @State private var showingError = false
    @State private var errorMessage: String?

    private var entries: [APILeaderboardEntry] {
        switch tab {
        case .streak: return leaderboardService.globalLeaderboard
        case .longestPlank: return leaderboardService.globalLeaderboardLongestPlank
        }
    }

    private var userRank: APILeaderboardEntry? {
        switch tab {
        case .streak: return leaderboardService.userGlobalRank
        case .longestPlank: return leaderboardService.userLongestPlankRank
        }
    }

    var body: some View {
        ZStack {
            AppBackground()

            Group {
                if !leaderboardService.hasLoaded && entries.isEmpty {
                    LeaderboardSkeleton()
                        .transition(.opacity)
                } else if entries.isEmpty {
                    EmptyStateView(
                        icon: "trophy",
                        title: "No one here yet",
                        message: "Complete planks to appear on the leaderboard"
                    )
                } else {
                    let groups = groupByRank(entries)
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(groups.enumerated()), id: \.element.id) { index, group in
                                if group.entries.count == 1 {
                                    NavigationLink {
                                        UserProfileView(userId: group.entries[0].user.id)
                                    } label: {
                                        APILeaderboardRow(entry: group.entries[0])
                                    }
                                    .buttonStyle(.plain)
                                } else {
                                    NavigationLink {
                                        TiedUsersListView(group: group)
                                    } label: {
                                        TiedLeaderboardRow(group: group)
                                    }
                                    .buttonStyle(.plain)
                                }

                                if index < groups.count - 1 {
                                    Divider().padding(.horizontal)
                                }
                            }

                            // Pin current user if outside the loaded window
                            if let rank = userRank,
                               !entries.contains(where: { $0.id == rank.id }) {
                                Divider().padding(.vertical, 8)
                                Text("Your rank")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal)
                                NavigationLink {
                                    UserProfileView(userId: rank.user.id)
                                } label: {
                                    APILeaderboardRow(entry: rank)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical)
                    }
                    .refreshable {
                        await loadFull()
                    }
                }
            }
        }
        .navigationTitle(tab.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .appNavigationBarStyle()
        .task {
            await loadFull()
        }
        .alert("Couldn't load rankings", isPresented: $showingError) {
            Button("Retry") {
                errorMessage = nil
                Task { await loadFull() }
            }
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Something went wrong. Try again.")
        }
    }

    private func loadFull() async {
        do {
            try await leaderboardService.fetchGlobalLeaderboardBoth(limit: 100)
        } catch is CancellationError { }
        catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}

// MARK: - Tied Leaderboard Row

/// A leaderboard row for a rank position shared by two or more users.
/// Shows overlapping avatars + the shared score. Tapping navigates to TiedUsersListView.
struct TiedLeaderboardRow: View {
    let group: RankedGroup

    var body: some View {
        HStack(spacing: 12) {
            // Rank number
            Text("#\(group.rank)")
                .font(.headline)
                .foregroundStyle(rankColor)
                .frame(width: 40)

            if group.entries.count == 1 {
                // Single entry — render standard avatar
                AvatarView.accent(
                    name: group.entries[0].user.displayName,
                    imageUrl: group.entries[0].user.profileImageUrl,
                    size: Constants.UI.avatarMedium
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(group.entries[0].user.displayName)
                        .font(.body)
                        .fontWeight(group.containsCurrentUser ? .semibold : .medium)
                    if let username = group.entries[0].user.username {
                        Text("@\(username)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                // Multiple tied users — overlapping avatar stack
                TiedAvatarStack(entries: group.entries)

                Text("\(group.entries.count) tied")
                    .font(.body)
                    .fontWeight(group.containsCurrentUser ? .semibold : .medium)
                    .foregroundStyle(.primary)
            }

            Spacer()

            Text(group.scoreLabel)
                .font(.headline)
                .foregroundStyle(Color.appAccent)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(group.containsCurrentUser ? Color.appAccent.opacity(0.08) : Color.clear)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            group.entries.count == 1
                ? "Rank \(group.rank), \(group.entries[0].user.displayName), \(group.scoreLabel)"
                : "Rank \(group.rank), \(group.entries.count) tied users, \(group.scoreLabel)"
        )
    }

    private var rankColor: Color {
        switch group.rank {
        case 1: return Color.rankGold
        case 2: return Color.rankSilver
        case 3: return Color.rankBronze
        default: return Color.secondary
        }
    }
}

// MARK: - Tied Avatar Stack

/// Shows up to 3 overlapping avatars with a "+N" overflow circle.
struct TiedAvatarStack: View {
    let entries: [APILeaderboardEntry]
    var size: CGFloat = 36

    private var visible: [APILeaderboardEntry] { Array(entries.prefix(3)) }
    private var overflow: Int { max(0, entries.count - 3) }

    var body: some View {
        HStack(spacing: -(size * 0.3)) {
            ForEach(Array(visible.enumerated()), id: \.element.id) { index, entry in
                AvatarView.accent(
                    name: entry.user.displayName,
                    imageUrl: entry.user.profileImageUrl,
                    size: size
                )
                .overlay(
                    Circle().stroke(Color.warmWhiteCard, lineWidth: 2)
                )
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
}

// MARK: - Tied Users List View (push destination)

/// Full list of users sharing a particular rank, each tappable to their profile.
struct TiedUsersListView: View {
    let group: RankedGroup

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(group.entries.enumerated()), id: \.element.id) { index, entry in
                        NavigationLink {
                            UserProfileView(userId: entry.user.id)
                        } label: {
                            APILeaderboardRow(entry: entry)
                        }
                        .buttonStyle(.plain)

                        if index < group.entries.count - 1 {
                            Divider().padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
        }
        .navigationTitle("Rank #\(group.rank)")
        .navigationBarTitleDisplayMode(.inline)
        .appNavigationBarStyle()
    }
}

// MARK: - Rankings Card Skeleton

struct RankingsCardSkeleton: View {
    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<5, id: \.self) { index in
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.15))
                        .frame(width: 32, height: 16)

                    Circle()
                        .fill(Color.secondary.opacity(0.15))
                        .frame(width: 36, height: 36)

                    VStack(alignment: .leading, spacing: 4) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.secondary.opacity(0.15))
                            .frame(width: 100, height: 14)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.secondary.opacity(0.1))
                            .frame(width: 60, height: 11)
                    }

                    Spacer()

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.15))
                        .frame(width: 50, height: 16)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                if index < 4 {
                    Divider().padding(.horizontal)
                }
            }
        }
        .redacted(reason: .placeholder)
    }
}

// MARK: - API Leaderboard Row (single entry)

struct APILeaderboardRow: View {
    let entry: APILeaderboardEntry

    var body: some View {
        HStack(spacing: 12) {
            Text("#\(entry.rank)")
                .font(.headline)
                .foregroundStyle(rankColor)
                .frame(width: 40)

            AvatarView.accent(
                name: entry.user.displayName,
                imageUrl: entry.user.profileImageUrl,
                size: Constants.UI.avatarMedium
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.user.displayName)
                    .font(.body)
                    .fontWeight(entry.isCurrentUser ? .semibold : .medium)

                if let username = entry.user.username {
                    Text("@\(username)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(entry.scoreLabel)
                .font(.headline)
                .foregroundStyle(Color.appAccent)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(entry.isCurrentUser ? Color.appAccent.opacity(0.08) : Color.clear)
    }

    private var rankColor: Color {
        switch entry.rank {
        case 1: return Color.rankGold
        case 2: return Color.rankSilver
        case 3: return Color.rankBronze
        default: return Color.secondary
        }
    }
}

#Preview {
    LeaderboardView()
        .withMockServices()
}
