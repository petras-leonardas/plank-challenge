//
//  SearchView.swift
//  PlankChallenge
//
//  Created by Leo Bacevicius on 08/03/2026.
//

import SwiftUI

struct SearchView: View {
    @Environment(\.userService) private var userService
    @Environment(\.groupService) private var groupService
    
    @State private var searchText = ""
    @State private var searchTask: Task<Void, Never>?
    @State private var showingError = false
    @State private var errorMessage: String?
    @FocusState private var isSearchFocused: Bool
    @State private var hasLoadedSuggestions = false
    
    var body: some View {
        NavigationStack {
        VStack(spacing: 0) {
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if !searchText.isEmpty {
                        searchResults
                    } else {
                        discoverSection
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 100)
            }
            
            Spacer()
            
            // Bottom Search Bar
            bottomSearchBar
        }
        .background(Color.softBlueBackground)
        .navigationTitle("Find People")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            isSearchFocused = true
        }
        .task {
            guard !hasLoadedSuggestions else { return }
            hasLoadedSuggestions = true
            try? await userService.fetchSuggestedUsers()
        }
        .onChange(of: searchText) { _, newValue in
            performSearch()
        }
        .onDisappear {
            searchTask?.cancel()
            userService.clearSearchResults()
        }
        .alert("Search failed", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Couldn't run that search. Try again.")
        }
        } // NavigationStack
    }
    
    // MARK: - Discover Section
    
    private var discoverSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Suggested People
            suggestedPeopleSection
        }
    }
    
    @ViewBuilder
    private var suggestedPeopleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            AppSectionHeader<EmptyView>(title: "SUGGESTED PEOPLE")
            
            if userService.isLoading && userService.suggestedUsers.isEmpty {
                SuggestedPeopleSkeleton()
            } else if userService.suggestedUsers.isEmpty {
                // Empty state — prompt user to search
                VStack(spacing: 8) {
                    Image(systemName: "person.2")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No suggestions yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Search above to find people to follow")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                ForEach(userService.suggestedUsers) { suggestion in
                    NavigationLink {
                        UserProfileView(userId: suggestion.user.id)
                    } label: {
                        SuggestedUserRow(suggestion: suggestion)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    // MARK: - Search Results
    
    private var searchResults: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Loading indicator
            if userService.isSearching {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding(.top, 20)
            }
            
            // People Results from API
            if !userService.searchResults.isEmpty {
                AppSectionHeader<EmptyView>(title: "PEOPLE")
                
                ForEach(userService.searchResults) { user in
                    NavigationLink {
                        UserProfileView(userId: user.id)
                    } label: {
                        SearchResultRow(
                            title: user.displayName,
                            subtitle: "\(user.currentStreak) day streak",
                            icon: "person.circle.fill"
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Groups Results from GroupService
            if !filteredGroups.isEmpty {
                AppSectionHeader<EmptyView>(title: "GROUPS")
                    .padding(.top, 8)
                
                ForEach(filteredGroups) { group in
                    NavigationLink {
                        GroupDetailView(groupId: group.id)
                    } label: {
                        SearchResultRow(
                            title: group.name,
                            subtitle: "\(group.memberCount) members",
                            icon: "person.3.fill"
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // No Results
            if !userService.isSearching && userService.searchResults.isEmpty && filteredGroups.isEmpty && searchText.count >= 2 {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    
                    Text("No results for \"\(searchText)\"")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    
                    Text("Try a different name or check your spelling")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
            }
            
            // Minimum characters hint
            if searchText.count > 0 && searchText.count < 2 {
                Text("Type at least 2 characters to search")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 20)
            }
        }
    }
    
    // MARK: - Bottom Search Bar
    
    private var bottomSearchBar: some View {
        HStack(spacing: 12) {
            // Search Field
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                TextField("People, groups...", text: $searchText)
                    .font(.body)
                    .focused($isSearchFocused)
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.warmWhiteCard)
            .clipShape(Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Color.softBlueBackground
                .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: -5)
        )
    }
    
    // MARK: - Filtered Data
    
    private var filteredGroups: [APIGroup] {
        guard !searchText.isEmpty else { return [] }
        // Search through both user's groups and discoverable groups
        let allGroups = groupService.myGroups + groupService.discoverGroups
        return allGroups.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    // MARK: - Search Logic
    
    private func performSearch() {
        // Cancel previous search task
        searchTask?.cancel()
        
        // Clear results if search text is too short
        guard searchText.count >= 2 else {
            userService.clearSearchResults()
            return
        }
        
        // Debounce search with 300ms delay
        searchTask = Task {
            do {
                try await Task.sleep(nanoseconds: 300_000_000) // 300ms
            } catch {
                // Task was cancelled during sleep - this is expected behavior
                return
            }
            
            // Double-check cancellation after sleep
            guard !Task.isCancelled else { return }
            
            // Capture current search text to verify it hasn't changed
            let currentQuery = searchText
            
            do {
                try await userService.searchUsers(query: currentQuery)
                
                // Final cancellation check - don't update state if cancelled
                guard !Task.isCancelled else { return }
            } catch is CancellationError {
                // Task was cancelled - this is expected during rapid typing
                return
            } catch {
                // Final cancellation check before showing error
                guard !Task.isCancelled else { return }
                
                // Only show error alert for actual errors, not cancellations
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
}

// MARK: - Suggested User Row

struct SuggestedUserRow: View {
    let suggestion: UserService.SuggestedUser
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            AvatarView.accent(
                name: suggestion.user.displayName,
                imageUrl: suggestion.user.profileImageUrl,
                size: Constants.UI.avatarMedium
            )
            
            // Name + reason
            VStack(alignment: .leading, spacing: 3) {
                Text(suggestion.user.displayName)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                
                Text(suggestion.suggestionReason)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Streak badge
            if suggestion.user.currentStreak > 0 {
                HStack(spacing: 3) {
                    Image(systemName: "flame.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                    Text("\(suggestion.user.currentStreak)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }
            }
            
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Search Result Row

struct SearchResultRow: View {
    let title: String
    let subtitle: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(Color.appAccent)
                .frame(width: 44, height: 44)
                .background(Color.appAccent.opacity(0.1))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    SearchView()
        .withMockServices()
}
