//
//  ProgressView.swift
//  PlankChallenge
//
//  Created by Leo Bacevicius on 08/03/2026.
//

import SwiftUI

struct PlankProgressView: View {
    @Environment(\.plankService) private var plankService
    @Environment(\.streakService) private var streakService
    @Environment(\.badgeService) private var badgeService
    
    @State private var isLoading = false
    @State private var loadError: String?
    @State private var showingError = false
    @State private var showingAllBadges = false
    @State private var showingPlankHistory = false
    
    /// Best plank duration formatted
    private var bestPlankTime: String {
        guard let longestPlank = plankService.longestPlank else { return "0:00" }
        return longestPlank.durationSeconds.formattedDuration
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // App background with subtle gradient
                AppBackground()
                
                if isLoading && !plankService.hasLoaded {
                    // Show skeleton for initial load
                    ProgressSkeleton()
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            // 1. STREAK + STATS ROW (streak left, stats right)
                            StreakStatsRow(
                                currentStreak: streakService.currentStreak,
                                longestStreak: streakService.longestStreak,
                                bestPlankTime: bestPlankTime,
                                totalPlanks: plankService.totalPlanks
                            )
                            
                            // 2. MONTHLY CALENDAR
                            StreakCalendarView()
                            
                            // 4. BADGES
                            badgesSection
                            
                            // 5. RECENT PLANKS
                            recentPlanksSection
                        }
                        .padding()
                    }
                    .refreshable {
                        await refreshData()
                    }
                }
            }
            .navigationTitle("Progress")
            .appNavigationBarStyle()
            .navigationDestination(isPresented: $showingAllBadges) {
                BadgesView()
            }
            .navigationDestination(isPresented: $showingPlankHistory) {
                PlankHistoryListView()
            }
            .task {
                await loadDataIfNeeded()
            }
            .alert("Couldn't load your progress", isPresented: $showingError) {
                Button("Retry") {
                    Task {
                        await refreshData()
                    }
                }
                Button("OK", role: .cancel) {}
            } message: {
                Text(loadError ?? "Something went wrong. Pull down to try again.")
            }
        }
    }
    
    // MARK: - Sections
    
    /// Earned badges sorted most-recently-earned first.
    private var widgetEarnedBadges: [APIBadgeWithProgress] {
        badgeService.availableBadges
            .filter { $0.earned }
            .sorted {
                switch ($0.earnedAt, $1.earnedAt) {
                case let (a?, b?): return a > b
                case (nil, _): return false
                case (_, nil): return true
                }
            }
    }

    /// Unearned badges with some progress, closest-to-earning first.
    private var widgetInProgressBadges: [APIBadgeWithProgress] {
        badgeService.availableBadges
            .filter { !$0.earned && $0.progress > 0 }
            .sorted {
                if $0.progress != $1.progress { return $0.progress > $1.progress }
                return $0.order < $1.order
            }
    }

    /// Badges to show in the widget: earned + in-progress, zero-progress excluded.
    private var widgetBadges: [APIBadgeWithProgress] {
        widgetEarnedBadges + widgetInProgressBadges
    }

    private var badgesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            AppSectionHeader<EmptyView>(title: "BADGES", onAction: {
                showingAllBadges = true
            })

            if badgeService.isLoading && !badgeService.hasLoaded {
                BadgesSectionSkeleton()
            } else if badgeService.hasLoaded && widgetBadges.isEmpty {
                Text("Keep planking to earn badges")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(widgetBadges) { badge in
                            APIBadgeDisplayView(badge: badge, size: .medium)
                        }
                    }
                        .padding(.horizontal, 4)
                    }
            }
        }
        .appCardStyle()
    }
    
    private var recentPlanksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            AppSectionHeader<EmptyView>(title: "RECENT PLANKS", onAction: {
                showingPlankHistory = true
            })
            
            if plankService.isLoading && !plankService.hasLoaded {
                RecentPlanksSectionSkeleton()
            } else if plankService.hasLoaded && plankService.planks.isEmpty {
                Text("No planks yet — your first one is the hardest")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(plankService.planks.prefix(5)) { session in
                    APIPlankHistoryRow(session: session)
                }
            }
        }
        .appCardStyle()
    }
    
    // MARK: - Data Loading
    
    private func loadDataIfNeeded() async {
        // Check each service independently so a pre-warmed service is not
        // forced to reload, and an un-loaded service is never skipped.
        let needsPlanks = !plankService.hasLoaded
        let needsStreak = !streakService.hasLoaded
        let needsBadges = badgeService.availableBadges.isEmpty
        
        guard needsPlanks || needsStreak || needsBadges else { return }
        
        isLoading = true
        loadError = nil
        showingError = false
        defer { isLoading = false }
        
        // Load required data in parallel and collect errors
        var errors: [Error] = []
        
        await withTaskGroup(of: Error?.self) { group in
            if needsPlanks {
                group.addTask {
                    do {
                        try await plankService.fetchPlanks(refresh: false)
                        return nil
                    } catch {
                        return error
                    }
                }
            }
            if needsStreak {
                group.addTask {
                    do {
                        try await streakService.fetchStreak()
                        return nil
                    } catch {
                        return error
                    }
                }
            }
            if needsBadges {
                group.addTask {
                    do {
                        try await badgeService.fetchAvailableBadges()
                        return nil
                    } catch {
                        return error
                    }
                }
            }
            
            for await error in group {
                if let error = error {
                    errors.append(error)
                }
            }
        }
        
        // Surface the first error from any service — all three are shown on this screen
        if let firstError = errors.first {
            loadError = firstError.localizedDescription
            showingError = true
        }
    }
    
    private func refreshData() async {
        isLoading = true
        loadError = nil
        showingError = false
        defer { isLoading = false }
        
        // Refresh all data in parallel and collect errors
        var errors: [Error] = []
        
        await withTaskGroup(of: Error?.self) { group in
            group.addTask {
                do {
                    try await plankService.fetchPlanks(refresh: true)
                    return nil
                } catch {
                    return error
                }
            }
            group.addTask {
                do {
                    try await streakService.fetchStreak()
                    return nil
                } catch {
                    return error
                }
            }
            group.addTask {
                do {
                    try await badgeService.fetchAvailableBadges()
                    return nil
                } catch {
                    return error
                }
            }
            
            for await error in group {
                if let error = error {
                    errors.append(error)
                }
            }
        }
        
        // Surface the first error from any service
        if let firstError = errors.first {
            loadError = firstError.localizedDescription
            showingError = true
        }
    }
}



// MARK: - API Plank History Row

struct APIPlankHistoryRow: View {
    let session: APIPlankSession
    
    private static let iso8601Formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    
    private static let iso8601FormatterBasic: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
    
    private var performedDate: Date {
        if let date = Self.iso8601Formatter.date(from: session.performedAt) {
            return date
        }
        return Self.iso8601FormatterBasic.date(from: session.performedAt) ?? Date()
    }
    
    private var isTimerInput: Bool {
        session.inputMethod == "timer"
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(performedDate.relativeFormatted)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            Spacer()
            
            Text(session.durationSeconds.formattedDuration)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(Color.appAccent)
            
            Image(systemName: isTimerInput ? "timer" : "hand.tap")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }
}



#Preview("Populated") {
    PlankProgressView()
        .withMockServices()
}
