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
                // Streak card
                leaderboardCard(
                    title: "STREAK",
                    entries: leaderboardService.globalLeaderboard,
                    userRank: leaderboardService.userGlobalRank,
                    tab: .streak
                )

                // Longest Plank card
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
            // Header row with See All
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

            if leaderboardService.isLoading && !leaderboardService.hasLoaded {
                RankingsCardSkeleton()
                    .padding(.bottom, 12)
            } else if entries.isEmpty {
                Text("No data yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            } else {
                let top5 = Array(entries.prefix(5))
                VStack(spacing: 0) {
                    ForEach(Array(top5.enumerated()), id: \.element.id) { index, entry in
                        APILeaderboardRow(entry: entry)
                        if index < top5.count - 1 {
                            Divider().padding(.horizontal)
                        }
                    }

                    // Pin current user's row if they fall outside the top 5
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
            // Task cancelled — not a user-visible error
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
                if leaderboardService.isLoading && entries.isEmpty {
                    LeaderboardSkeleton()
                } else if entries.isEmpty {
                    EmptyStateView(
                        icon: "trophy",
                        title: "No one here yet",
                        message: "Complete planks to appear on the leaderboard"
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(entries) { entry in
                                NavigationLink {
                                    UserProfileView(userId: entry.user.id)
                                } label: {
                                    APILeaderboardRow(entry: entry)
                                }
                                .buttonStyle(.plain)

                                if entry.id != entries.last?.id {
                                    Divider().padding(.horizontal)
                                }
                            }

                            // Pin current user's rank if outside the loaded window
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
            // fetchGlobalLeaderboardBoth fetches both streak and longest-plank
            // in parallel and stores them in their respective service properties,
            // so both full lists stay consistent regardless of which tab is open.
            try await leaderboardService.fetchGlobalLeaderboardBoth(limit: 100)
        } catch is CancellationError { }
        catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
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

// MARK: - API Leaderboard Row

struct APILeaderboardRow: View {
    let entry: APILeaderboardEntry

    var body: some View {
        HStack(spacing: 12) {
            // Rank
            Text("#\(entry.rank)")
                .font(.headline)
                .foregroundStyle(rankColor)
                .frame(width: 40)

            // Avatar
            AvatarView.accent(
                name: entry.user.displayName,
                imageUrl: entry.user.profileImageUrl,
                size: Constants.UI.avatarMedium
            )

            // Name
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.user.displayName)
                    .font(.body)
                    .fontWeight(.medium)

                if let username = entry.user.username {
                    Text("@\(username)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Score
            Text(entry.scoreLabel)
                .font(.headline)
                .foregroundStyle(Color.appAccent)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
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
