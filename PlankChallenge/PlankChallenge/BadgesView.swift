//
//  BadgesView.swift
//  PlankChallenge
//
//  Created by Leo Bacevicius on 08/03/2026.
//

import SwiftUI

struct BadgesView: View {
    @Environment(\.badgeService) private var badgeService
    
    @State private var showingError = false
    @State private var errorMessage: String?
    
    private let columns = [
        GridItem(.adaptive(minimum: 100), spacing: 16)
    ]
    
    // Earned badges — most recently earned first
    private var earnedAPIBadges: [APIBadgeWithProgress] {
        badgeService.availableBadges
            .filter { $0.earned }
            .sorted {
                // Most recently earned first; fall back to definition order
                switch ($0.earnedAt, $1.earnedAt) {
                case let (a?, b?): return a > b
                case (nil, _): return false
                case (_, nil): return true
                }
            }
    }

    // Unearned badges with some progress — closest to earning first
    private var inProgressAPIBadges: [APIBadgeWithProgress] {
        badgeService.availableBadges
            .filter { !$0.earned && $0.progress > 0 }
            .sorted {
                if $0.progress != $1.progress { return $0.progress > $1.progress }
                return $0.order < $1.order
            }
    }

    // Unearned badges with zero progress — definition order
    private var lockedAPIBadges: [APIBadgeWithProgress] {
        badgeService.availableBadges
            .filter { !$0.earned && $0.progress == 0 }
            .sorted { $0.order < $1.order }
    }
    
    var body: some View {
        ZStack {
            AppBackground()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if badgeService.hasLoaded {
                        // 1. Earned badges
                        if !earnedAPIBadges.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                AppSectionHeader<EmptyView>(title: "EARNED (\(earnedAPIBadges.count))")
                                    .padding(.horizontal)

                                LazyVGrid(columns: columns, spacing: 20) {
                                    ForEach(earnedAPIBadges) { badge in
                                        APIBadgeDisplayView(badge: badge, size: .large)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }

                        // 2. In-progress badges (some progress, not yet earned)
                        if !inProgressAPIBadges.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                AppSectionHeader<EmptyView>(title: "IN PROGRESS (\(inProgressAPIBadges.count))")
                                    .padding(.horizontal)

                                LazyVGrid(columns: columns, spacing: 20) {
                                    ForEach(inProgressAPIBadges) { badge in
                                        APIBadgeDisplayView(badge: badge, size: .large)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }

                        // 3. Locked badges (zero progress)
                        if !lockedAPIBadges.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                AppSectionHeader<EmptyView>(title: "LOCKED (\(lockedAPIBadges.count))")
                                    .padding(.horizontal)

                                LazyVGrid(columns: columns, spacing: 20) {
                                    ForEach(lockedAPIBadges) { badge in
                                        APIBadgeDisplayView(badge: badge, size: .large)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    } else {
                        BadgesSkeleton()
                            .accessibilityLabel("Loading badges")
                    }
                }
                .padding(.vertical)
            }
        }
        .navigationTitle("Badges")
        .appNavigationBarStyle()
        .task {
            // Fetch available badges if we don't yet have them.
            // Note: hasLoaded may already be true if fetchBadges() (earned-only endpoint)
            // was called from ProfileView, but that doesn't populate availableBadges.
            // So we check availableBadges.isEmpty directly.
            if badgeService.availableBadges.isEmpty {
                do {
                    try await badgeService.fetchAvailableBadges()
                } catch is CancellationError {
                    // View disappeared before load completed — not a user error
                } catch {
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
        .alert("Couldn't load badges", isPresented: $showingError) {
            Button("Retry") {
                errorMessage = nil
                Task {
                    do {
                        try await badgeService.fetchAvailableBadges()
                    } catch is CancellationError {
                        // Cancelled — not a user error
                    } catch {
                        errorMessage = error.localizedDescription
                        showingError = true
                    }
                }
            }
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Something went wrong. Try again.")
        }
    }
}



#Preview {
    NavigationStack {
        BadgesView()
            .withMockServices()
    }
}
