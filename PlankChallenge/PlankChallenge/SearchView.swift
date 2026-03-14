//
//  SearchView.swift
//  PlankChallenge
//
//  Created by Leo Bacevicius on 08/03/2026.
//

import SwiftUI

struct SearchView: View {
    @Binding var isPresented: Bool
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool
    
    private var mockData: MockDataService { MockDataService.shared }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Search")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 8)
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Search Results (when searching)
                    if !searchText.isEmpty {
                        searchResults
                    } else {
                        // Discover Section
                        discoverSection
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 100) // Space for bottom bar
            }
            
            Spacer()
            
            // Bottom Search Bar
            bottomSearchBar
        }
        .background(Color.softBlueBackground)
        .onAppear {
            isSearchFocused = true
        }
    }
    
    // MARK: - Discover Section
    
    private var discoverSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Discover")
                .font(.headline)
                .foregroundStyle(.primary)
            
            // Popular Groups Card
            DiscoverCard(
                title: "Popular Groups",
                subtitle: "Join trending fitness communities",
                icon: "trophy.fill",
                gradientColors: [.discoverBlueStart, .discoverBlueEnd]
            ) {
                // Action: Show popular groups
            }
            
            // Find People Card
            DiscoverCard(
                title: "Find People",
                subtitle: "Search for friends to follow",
                icon: "person.2.fill",
                gradientColors: [.discoverPurpleStart, .discoverPurpleEnd]
            ) {
                // Action: Show people search
            }
            
            // Public Groups Card
            DiscoverCard(
                title: "Public Groups",
                subtitle: "Open groups you can join instantly",
                icon: "globe",
                gradientColors: [.discoverOrangeStart, .discoverOrangeEnd]
            ) {
                // Action: Show public groups
            }
        }
    }
    
    // MARK: - Search Results
    
    private var searchResults: some View {
        VStack(alignment: .leading, spacing: 16) {
            // People Results
            if !filteredUsers.isEmpty {
                Text("People")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                
                ForEach(filteredUsers) { user in
                    SearchResultRow(
                        title: user.displayName,
                        subtitle: "\(user.currentStreak) day streak",
                        icon: "person.circle.fill"
                    )
                }
            }
            
            // Groups Results
            if !filteredGroups.isEmpty {
                Text("Groups")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
                
                ForEach(filteredGroups) { group in
                    SearchResultRow(
                        title: group.name,
                        subtitle: "\(group.memberCount) members",
                        icon: "person.3.fill"
                    )
                }
            }
            
            // No Results
            if filteredUsers.isEmpty && filteredGroups.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    
                    Text("No results found")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    
                    Text("Try searching for people or groups")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
            }
        }
    }
    
    // MARK: - Bottom Search Bar
    
    private var bottomSearchBar: some View {
        HStack(spacing: 12) {
            // Back Button
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isPresented = false
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44)
                    .background(Color.warmWhiteCard)
                    .clipShape(Circle())
            }
            
            // Search Field
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                
                TextField("People, Groups...", text: $searchText)
                    .font(.body)
                    .focused($isSearchFocused)
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
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
    
    private var filteredUsers: [LeaderboardUser] {
        guard !searchText.isEmpty else { return [] }
        return mockData.leaderboardUsers.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private var filteredGroups: [MockGroup] {
        guard !searchText.isEmpty else { return [] }
        let allGroups = mockData.myGroups + mockData.discoverGroups
        return allGroups.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }
}

// MARK: - Discover Card

struct DiscoverCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let gradientColors: [Color]
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                    
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                }
                
                Spacer()
                
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(20)
            .background(
                LinearGradient(
                    colors: gradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
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
    SearchView(isPresented: .constant(true))
}
