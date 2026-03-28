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
                    // Show loading state for initial load
                    ProgressView("Loading your progress...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
    
    private var badgesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            AppSectionHeader(title: "BADGES") {
                BadgesView()
            }
            
            if badgeService.isLoading && !badgeService.hasLoaded {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            } else if badgeService.hasLoaded && badgeService.availableBadges.isEmpty {
                Text("Keep planking to earn badges")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(badgeService.availableBadges.prefix(8)) { badge in
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
            AppSectionHeader(title: "RECENT PLANKS") {
                PlankHistoryListView()
            }
            
            if plankService.isLoading && !plankService.hasLoaded {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
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
        guard !plankService.hasLoaded else { return }
        
        isLoading = true
        loadError = nil
        showingError = false
        defer { isLoading = false }
        
        // Load all data in parallel and collect errors
        var errors: [Error] = []
        
        await withTaskGroup(of: Error?.self) { group in
            group.addTask {
                do {
                    try await plankService.fetchPlanks(refresh: false)
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
