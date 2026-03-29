//
//  FollowListView.swift
//  PlankChallenge
//
//  Created by Leo Bacevicius on 08/03/2026.
//

import SwiftUI

struct FollowListView: View {
    let userId: String
    let type: FollowType
    
    @Environment(UserService.self) private var userService
    @State private var searchText = ""
    
    enum FollowType {
        case following
        case followers
        
        var title: String {
            switch self {
            case .following: return "Following"
            case .followers: return "Followers"
            }
        }
    }
    
    var body: some View {
        Group {
            if userService.isLoading && users.isEmpty {
                loadingView
            } else if users.isEmpty {
                emptyState
            } else {
                userList
            }
        }
        .navigationTitle(type.title)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search")
        .refreshable {
            await loadUsers()
        }
        .task(id: userId) {
            await loadUsers()
        }
        .onAppear {
            // Always reload on appear to reflect follow/unfollow changes
            Task { await loadUsers() }
        }
    }
    
    // MARK: - Subviews
    
    private var loadingView: some View {
        FollowListSkeleton()
    }
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: type == .followers ? "person.2.slash" : "person.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text(type == .followers ? "No followers yet" : "Not following anyone yet")
                .font(.headline)
            
            Text(type == .followers
                 ? "When someone follows you, they'll appear here"
                 : "Search for people to follow")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            if type == .following {
                NavigationLink {
                    SearchView()
                } label: {
                    Label("Find People", systemImage: "person.badge.plus")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.appAccent)
                        .clipShape(Capsule())
                }
                .padding(.top, 4)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
        .accessibilityElement(children: .combine)
    }
    
    private var userList: some View {
        List {
            // Find People button at the top when showing following list
            if type == .following {
                NavigationLink {
                    SearchView()
                } label: {
                    Label("Find People", systemImage: "magnifyingglass")
                        .font(.body.weight(.medium))
                        .foregroundStyle(Color.appAccent)
                }
                .accessibilityHint("Search for new people to follow")
            }
            
            ForEach(filteredUsers) { user in
                NavigationLink {
                    UserProfileView(userId: user.id)
                } label: {
                    FollowUserRow(user: user)
                }
                .accessibilityHint("Double tap to view profile")
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var users: [APIPublicUser] {
        switch type {
        case .following:
            return userService.following
        case .followers:
            return userService.followers
        }
    }
    
    private var filteredUsers: [APIPublicUser] {
        if searchText.isEmpty {
            return users
        }
        return users.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    // MARK: - Actions
    
    private func loadUsers() async {
        do {
            switch type {
            case .following:
                try await userService.fetchFollowing(for: userId)
            case .followers:
                try await userService.fetchFollowers(for: userId)
            }
        } catch {
            // Error stored in service
        }
    }
}

// MARK: - Follow User Row

struct FollowUserRow: View {
    let user: APIPublicUser
    
    var body: some View {
        UserRowView(
            name: user.displayName,
            subtitle: "\(user.currentStreak) day streak",
            avatarImageUrl: user.profileImageUrl
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(user.displayName), \(user.currentStreak) day streak")
    }
}

#Preview {
    NavigationStack {
        FollowListView(userId: "preview-user", type: .following)
            .withMockServices()
    }
}
