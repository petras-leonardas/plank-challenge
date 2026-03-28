//
//  LeaderboardView.swift
//  PlankChallenge
//
//  Created by Leo Bacevicius on 08/03/2026.
//

import SwiftUI

// MARK: - Leaderboard Tab Enum

enum LeaderboardTab: String, CaseIterable {
    case streak = "Streak"
    case longestPlank = "Longest Plank"
    case friends = "Friends"
    
    var serviceType: LeaderboardService.LeaderboardType {
        switch self {
        case .streak: return .streak
        case .longestPlank: return .longestPlank
        case .friends: return .streak  // Friends leaderboard defaults to streak type
        }
    }
}

// MARK: - Standalone Leaderboard View (for backwards compatibility)

struct LeaderboardView: View {
    var body: some View {
        NavigationStack {
            LeaderboardContent()
                .navigationTitle("Leaderboard")
        }
    }
}

// MARK: - Leaderboard Content (Embeddable)

struct LeaderboardContent: View {
    @Environment(\.leaderboardService) private var leaderboardService
    
    @State private var selectedTab: LeaderboardTab = .streak
    @State private var selectedPeriod: LeaderboardService.LeaderboardPeriod = .weekly
    @State private var showingError = false
    @State private var errorMessage: String?
    
    /// A Hashable identity combining both pickers so .task(id:) re-runs when either changes.
    private struct LeaderboardTaskID: Hashable {
        let tab: LeaderboardTab
        let period: LeaderboardService.LeaderboardPeriod
    }
    
    private var leaderboardTaskId: LeaderboardTaskID {
        LeaderboardTaskID(tab: selectedTab, period: selectedPeriod)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab Picker
            Picker("Leaderboard", selection: $selectedTab) {
                ForEach(LeaderboardTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()
            
            // Period Picker
            Picker("Period", selection: $selectedPeriod) {
                ForEach(LeaderboardService.LeaderboardPeriod.allCases, id: \.self) { period in
                    Text(period.displayName).tag(period)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.bottom, 8)
            
            // Leaderboard List
            if leaderboardService.isLoading && !leaderboardService.hasLoaded {
                Spacer()
                ProgressView("Loading leaderboard...")
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        if selectedTab == .friends {
                            friendsLeaderboardContent
                        } else {
                            globalLeaderboardContent
                        }
                    }
                    .padding(.vertical)
                }
                .refreshable {
                    await loadLeaderboard()
                }
            }
        }
        // Always fetch on appear and whenever the picker selection changes.
        // .task(id:) cancels the previous fetch and re-runs automatically —
        // this restores the original always-refresh-on-appear behaviour.
        .task(id: leaderboardTaskId) {
            await loadLeaderboard()
        }
        // Additionally re-fetch immediately if the leaderboard is marked stale
        // while this view is already on screen (e.g. user saves a plank from
        // another tab without leaving the leaderboard tab).
        .onChange(of: leaderboardService.isStale) { _, isStale in
            guard isStale else { return }
            Task {
                await loadLeaderboard()
            }
        }
        .alert("Couldn't load leaderboard", isPresented: $showingError) {
            Button("Retry") {
                errorMessage = nil
                Task {
                    await loadLeaderboard()
                }
            }
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Something went wrong. Try again.")
        }
    }
    
    // MARK: - Sub-views
    
    @ViewBuilder
    private var globalLeaderboardContent: some View {
        if leaderboardService.hasLoaded && !leaderboardService.globalLeaderboard.isEmpty {
            ForEach(leaderboardService.globalLeaderboard) { entry in
                APILeaderboardRow(entry: entry)
                if entry.id != leaderboardService.globalLeaderboard.last?.id {
                    Divider().padding(.horizontal)
                }
            }
            
            // Show current user's rank if they're outside the visible window
            if let userRank = leaderboardService.userGlobalRank,
               !leaderboardService.globalLeaderboard.contains(where: { $0.id == userRank.id }) {
                Divider().padding(.vertical, 8)
                Text("Your rank")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                APILeaderboardRow(entry: userRank)
            }
        } else {
            leaderboardEmptyState(
                icon: "trophy",
                message: "No one here yet",
                detail: "Complete planks to appear on the leaderboard"
            )
        }
    }
    
    @ViewBuilder
    private var friendsLeaderboardContent: some View {
        if leaderboardService.isLoading {
            ProgressView("Loading friends leaderboard...")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
        } else if leaderboardService.followingLeaderboard.isEmpty {
            leaderboardEmptyState(
                icon: "person.2",
                message: "No friends yet",
                detail: "Follow people to see how you stack up against them"
            )
        } else {
            ForEach(leaderboardService.followingLeaderboard) { entry in
                APILeaderboardRow(entry: entry)
                if entry.id != leaderboardService.followingLeaderboard.last?.id {
                    Divider().padding(.horizontal)
                }
            }
        }
    }
    
    private func leaderboardEmptyState(icon: String, message: String, detail: String) -> some View {
        EmptyStateView(icon: icon, title: message, message: detail)
            .frame(maxHeight: 200)
    }
    
    // MARK: - Data Loading
    
    private func loadLeaderboard() async {
        do {
            if selectedTab == .friends {
                try await leaderboardService.fetchFollowingLeaderboard(
                    type: selectedTab.serviceType,
                    period: selectedPeriod
                )
            } else {
                try await leaderboardService.fetchGlobalLeaderboard(
                    type: selectedTab.serviceType,
                    period: selectedPeriod,
                    limit: 50
                )
            }
        } catch is CancellationError {
            // Task was cancelled (e.g. tab/period changed rapidly, view disappeared) — not a user error
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
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
