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
    
    // Earned badges from API
    private var earnedAPIBadges: [APIBadgeWithProgress] {
        badgeService.availableBadges.filter { $0.earned }
    }
    
    // Locked badges from API
    private var lockedAPIBadges: [APIBadgeWithProgress] {
        badgeService.availableBadges.filter { !$0.earned }
    }
    
    var body: some View {
        ZStack {
            AppBackground()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Use API data if loaded
                    if badgeService.hasLoaded {
                        // Earned badges from API
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
                        
                        // Locked badges from API
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
                        // Loading state
                        ProgressView("Loading badges...")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                            .accessibilityLabel("Loading badges")
                    }
                }
                .padding(.vertical)
            }
        }
        .navigationTitle("Badges")
        .appNavigationBarStyle()
        .task {
            if !badgeService.hasLoaded {
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
