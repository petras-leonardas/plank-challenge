//
//  UserProfileView.swift
//  PlankChallenge
//
//  Created by Leo Bacevicius on 08/03/2026.
//

import SwiftUI

/// View displaying another user's profile
///
/// Fetches the user's public profile from the API and allows following/unfollowing.
struct UserProfileView: View {
    let userId: String
    
    @Environment(\.userService) private var userService
    @Environment(\.authService) private var authService
    
    private var isOwnProfile: Bool {
        userId == (userService.currentUserProfile?.id ?? authService.currentUser?.id)
    }
    
    @State private var user: APIPublicUser?
    @State private var isLoading = true
    @State private var loadError: Error?
    @State private var isFollowLoading = false
    @State private var followError: String?
    @State private var showingFollowError = false
    
    var body: some View {
        ZStack {
            AppBackground()
            
            if isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
                    .accessibilityLabel("Loading profile")
            } else if let error = loadError {
                ErrorView(error: error) {
                    await loadProfile()
                }
            } else if let user {
                ScrollView {
                    VStack(spacing: 20) {
                        // Profile header
                        profileHeader(for: user)
                        
                        // Stats
                        statsSection(for: user)
                    }
                    .padding()
                }
            }
        }
        .navigationTitle(user?.displayName ?? "Profile")
        .navigationBarTitleDisplayMode(.inline)
        .appNavigationBarStyle()
        .task {
            await loadProfile()
        }
        .alert("Something went wrong", isPresented: $showingFollowError) {
            Button("OK", role: .cancel) { followError = nil }
        } message: {
            Text(followError ?? "Couldn't complete that action. Try again.")
        }
    }
    
    // MARK: - Data Loading
    
    private func loadProfile() async {
        isLoading = true
        loadError = nil
        
        do {
            user = try await userService.fetchUserProfile(id: userId)
        } catch is CancellationError {
            // View disappeared before load completed — do not mutate state further
            return
        } catch {
            loadError = error
        }
        
        isLoading = false
    }
    
    // MARK: - Profile Header
    
    private func profileHeader(for user: APIPublicUser) -> some View {
        VStack(spacing: 16) {
            // Avatar
            AvatarView.gradient(
                name: user.displayName,
                imageUrl: user.profileImageUrl,
                size: Constants.UI.avatarXLarge
            )
            .accessibilityHidden(true)
            
            // Name, username, location, bio
            VStack(spacing: 6) {
                Text(user.displayName)
                    .font(.title2)
                    .fontWeight(.bold)
                
                if let username = user.username {
                    Text("@\(username)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                if let location = user.location, !location.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(location)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                
                if let bio = user.bio, !bio.isEmpty {
                    Text(bio)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(user.displayName)\(user.username.map { ", @\($0)" } ?? "")\(user.location.map { ", \($0)" } ?? "")")
            
            // Social counts
            HStack(spacing: 24) {
                VStack(spacing: 2) {
                    Text("\(user.followerCount)")
                        .font(.headline)
                    Text("Followers")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(user.followerCount) followers")
                
                VStack(spacing: 2) {
                    Text("\(user.followingCount)")
                        .font(.headline)
                    Text("Following")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Following \(user.followingCount)")
            }
            
            // Follow button — hidden on own profile
            if !isOwnProfile {
                followButton(for: user)
            }
        }
        .frame(maxWidth: .infinity)
        .appCardStyle()
    }
    
    private func followButton(for user: APIPublicUser) -> some View {
        let isFollowing = user.isFollowing ?? false
        
        return Button {
            Task {
                await toggleFollow(for: user)
            }
        } label: {
            ZStack {
                // Fixed-width ghost keeps the pill from resizing when text changes
                Text("Following").opacity(0)
                
                HStack(spacing: 6) {
                    if isFollowLoading {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(0.7)
                            .frame(width: 16, height: 16)
                    }
                    Text(isFollowing ? "Following" : "Follow")
                        .opacity(isFollowLoading ? 0.5 : 1)
                }
            }
        }
        .pillButtonStyle(isSelected: !isFollowing)
        .disabled(isFollowLoading)
        .accessibilityLabel(isFollowing ? "Following \(user.displayName)" : "Follow \(user.displayName)")
        .accessibilityHint(isFollowing ? "Double tap to unfollow" : "Double tap to follow")
    }
    
    private func toggleFollow(for user: APIPublicUser) async {
        isFollowLoading = true
        defer { isFollowLoading = false }
        
        do {
            let isCurrentlyFollowing = user.isFollowing ?? false
            
            if isCurrentlyFollowing {
                try await userService.unfollowUser(id: user.id)
            } else {
                try await userService.followUser(id: user.id)
            }
            
            // Refresh the profile to get updated state from server
            // This ensures we have the correct follower count and follow state
            await loadProfile()
        } catch is CancellationError {
            // Cancelled — not a user error
        } catch {
            followError = error.localizedDescription
            showingFollowError = true
            #if DEBUG
            print("[UserProfileView] Follow toggle failed: \(error)")
            #endif
        }
    }
    
    // MARK: - Stats Section
    
    private func statsSection(for user: APIPublicUser) -> some View {
        HStack(spacing: 12) {
            StatCard(
                title: "Current streak",
                value: "\(user.currentStreak)",
                subtitle: "days",
                icon: "flame.fill",
                color: .orange
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(user.currentStreak) day streak")
            
            StatCard(
                title: "Longest plank",
                value: formatDuration(user.longestPlankSeconds),
                icon: "timer",
                color: .green
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Longest plank: \(formatDurationAccessible(user.longestPlankSeconds))")
        }
    }
    
    // MARK: - Helpers
    
    private func formatDuration(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        if minutes > 0 {
            return "\(minutes):\(String(format: "%02d", secs))"
        } else {
            return "\(secs)s"
        }
    }
    
    private func formatDurationAccessible(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        if minutes > 0 && secs > 0 {
            return "\(minutes) minutes \(secs) seconds"
        } else if minutes > 0 {
            return "\(minutes) minutes"
        } else {
            return "\(secs) seconds"
        }
    }
}

#Preview {
    NavigationStack {
        UserProfileView(userId: "preview-user-id")
            .withMockServices()
    }
}
