//
//  ProfileView.swift
//  PlankChallenge
//
//  Created by Leo Bacevicius on 08/03/2026.
//

import SwiftUI

struct ProfileView: View {
    @Environment(\.authService) private var authService
    @Environment(\.plankService) private var plankService
    @Environment(\.streakService) private var streakService
    @Environment(\.badgeService) private var badgeService
    @Environment(\.userService) private var userService
    @Environment(\.mediaService) private var mediaService
    
    @State private var showingEditProfile = false
    @State private var showingPhotoEditor = false
    @State private var showingAllBadges = false
    @State private var profileLoadError: String?
    @State private var showingProfileLoadError = false
    @State private var badgeLoadError: String?
    @State private var showingBadgeLoadError = false
    
    // Computed properties for API data
    private var displayName: String {
        userService.currentUserProfile?.displayName
            ?? authService.currentUser?.displayName
            ?? "Loading..."
    }
    
    private var userInitial: String {
        String(displayName.prefix(1))
    }
    
    private var currentStreak: Int {
        streakService.currentStreak
    }
    
    private var freezeTokens: Int {
        streakService.freezeTokens
    }
    
    private var totalPlanks: Int {
        plankService.totalPlanks
    }
    
    private var bestPlankTime: String {
        plankService.longestPlank?.durationSeconds.formattedDuration ?? "0:00"
    }
    
    /// Current user ID for navigation (nil if not available yet)
    private var currentUserId: String? {
        userService.currentUserProfile?.id ?? authService.currentUser?.id
    }
    
    /// Following count from API
    private var followingCount: Int {
        userService.currentUserProfile?.followingCount ?? 0
    }
    
    /// Follower count from API
    private var followerCount: Int {
        userService.currentUserProfile?.followerCount ?? 0
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // App background with subtle gradient
                AppBackground()
                
                ScrollView {
                    VStack(spacing: 0) {
                        // Profile Header (Strava-style)
                        profileHeader
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                        
                        // Action Buttons
                        actionButtons
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                        
                        // Following / Followers tiles
                        socialSection
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                        
                        // Stats Section
                        statsSection
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                        
                        // Badges Section
                        badgesSection
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                            .padding(.bottom, 24)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .appNavigationBarStyle()
            .navigationTitle("Profile")
            .navigationDestination(isPresented: $showingAllBadges) {
                BadgesView()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(.primary)
                    }
                }
            }
            .sheet(isPresented: $showingEditProfile) {
                if let apiUser = userService.currentUserProfile {
                    EditProfileView(apiUser: apiUser)
                } else if let authUser = authService.currentUser {
                    EditProfileView(
                        displayName: authUser.displayName ?? "",
                        location: "",
                        bio: ""
                    )
                }
            }
             .sheet(isPresented: $showingPhotoEditor) {
                ProfilePhotoEditorView(
                    currentImageUrl: userService.currentUserProfile?.profileImageUrl
                )
            }
            .task {
                // Fetch user profile if not already loaded
                if !userService.hasLoaded {
                    do {
                        try await userService.fetchProfile()
                    } catch is CancellationError {
                        // View disappeared before load completed — not a user error
                    } catch {
                        profileLoadError = error.localizedDescription
                        showingProfileLoadError = true
                    }
                }
                // Fetch earned badges if not already loaded
                if !badgeService.hasLoaded {
                    do {
                        try await badgeService.fetchBadges()
                    } catch is CancellationError {
                        // View disappeared before load completed — not a user error
                    } catch {
                        badgeLoadError = error.localizedDescription
                        showingBadgeLoadError = true
                    }
                }
            }
            .alert("Couldn't load your profile", isPresented: $showingProfileLoadError) {
                Button("Retry") {
                    profileLoadError = nil
                    Task {
                        do {
                            try await userService.fetchProfile()
                        } catch is CancellationError {
                            // Cancelled — not a user error
                        } catch {
                            profileLoadError = error.localizedDescription
                            showingProfileLoadError = true
                        }
                    }
                }
                Button("OK", role: .cancel) { profileLoadError = nil }
            } message: {
                Text(profileLoadError ?? "Something went wrong. Try again.")
            }
            .alert("Couldn't load badges", isPresented: $showingBadgeLoadError) {
                Button("Retry") {
                    badgeLoadError = nil
                    Task {
                        do {
                            try await badgeService.fetchBadges()
                        } catch is CancellationError {
                            // Cancelled — not a user error
                        } catch {
                            badgeLoadError = error.localizedDescription
                            showingBadgeLoadError = true
                        }
                    }
                }
                Button("OK", role: .cancel) { badgeLoadError = nil }
            } message: {
                Text(badgeLoadError ?? "Something went wrong. Try again.")
            }
        }
    }
    
    // MARK: - Profile Avatar
    
    @ViewBuilder
    private var profileAvatar: some View {
        ZStack(alignment: .bottomTrailing) {
            AvatarView.gradient(
                name: displayName,
                imageUrl: userService.currentUserProfile?.profileImageUrl,
                size: Constants.UI.avatarLarge
            )
            
            // Camera overlay badge
            Circle()
                .fill(Color.appAccent)
                .frame(width: 22, height: 22)
                .overlay {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.white)
                }
                .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
        }
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Profile Header (Strava-style)
    
    private var profileHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Avatar + Name row
            HStack(alignment: .top, spacing: 16) {
                // Profile Avatar (tappable to edit)
                Button {
                    showingPhotoEditor = true
                } label: {
                    profileAvatar
                }
                .buttonStyle(.plain)
                
                // Name and Location
                VStack(alignment: .leading, spacing: 4) {
                    Text(displayName)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if let location = userService.currentUserProfile?.location,
                       !location.isEmpty {
                        Text(location)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
            }
            
            // Bio from API
            let bio = userService.currentUserProfile?.bio
            if let bio = bio, !bio.isEmpty {
                Text(bio)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            

        }
    }
    
    // MARK: - Action Buttons (Strava-style pill buttons)
    
    private var actionButtons: some View {
        HStack(spacing: 12) {
            // Edit Profile button
            Button {
                showingEditProfile = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "pencil")
                        .font(.caption)
                    Text("Edit Profile")
                }
            }
            .pillButtonStyle(isSelected: false)
            
            Spacer()
        }
    }
    
    // MARK: - Social Section (Following / Followers)
    
    private var socialSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            AppSectionHeader<EmptyView>(title: "YOUR COMMUNITY")
            
            HStack(spacing: 12) {
                if let userId = currentUserId {
                    NavigationLink {
                        FollowListView(userId: userId, type: .following)
                    } label: {
                        StatCard(
                            title: "Following",
                            value: "\(followingCount)",
                            icon: "person.2.fill",
                            color: .appAccent,
                            style: .grid
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Following \(followingCount) users. Tap to view.")
                    
                    NavigationLink {
                        FollowListView(userId: userId, type: .followers)
                    } label: {
                        StatCard(
                            title: "Followers",
                            value: "\(followerCount)",
                            icon: "person.fill.badge.plus",
                            color: .tealAccent,
                            style: .grid
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(followerCount) followers. Tap to view.")
                } else {
                    StatCard(
                        title: "Following",
                        value: "\(followingCount)",
                        icon: "person.2.fill",
                        color: .appAccent,
                        style: .grid
                    )
                    StatCard(
                        title: "Followers",
                        value: "\(followerCount)",
                        icon: "person.fill.badge.plus",
                        color: .tealAccent,
                        style: .grid
                    )
                }
            }
        }
        .appCardStyle()
    }
    
    // MARK: - Stats Section
    
    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            AppSectionHeader<EmptyView>(title: "YOUR STATS")
            
            HStack(spacing: 12) {
                // Streak
                StatCard(
                    title: "Day Streak",
                    value: "\(currentStreak)",
                    icon: "flame.fill",
                    color: .orange,
                    style: .grid
                )
                
                // Total Planks
                StatCard(
                    title: "Total Planks",
                    value: "\(totalPlanks)",
                    icon: "figure.core.training",
                    color: .appAccent,
                    style: .grid
                )
                
                // Best Plank
                StatCard(
                    title: "Best Plank",
                    value: bestPlankTime,
                    icon: "trophy.fill",
                    color: .yellow,
                    style: .grid
                )
            }
        }
        .appCardStyle()
    }
    
    // MARK: - Streak & Tokens Section
    
    private var streakTokensSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            AppSectionHeader<EmptyView>(title: "STREAK SHIELDS")
            
            HStack {
                // Token indicators
                HStack(spacing: 8) {
                    ForEach(0..<Constants.Streak.maxFreezeTokens, id: \.self) { index in
                        Circle()
                            .fill(index < freezeTokens ? Color.tealAccent : Color.gray.opacity(0.3))
                            .frame(width: 24, height: 24)
                            .overlay {
                                Image(systemName: "snowflake")
                                    .font(.system(size: 12))
                                    .foregroundStyle(index < freezeTokens ? .white : .gray)
                            }
                    }
                }
                
                Spacer()
                
                Text("\(freezeTokens) of \(Constants.Streak.maxFreezeTokens) shields left")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Text("A shield automatically activates when you miss a day — so your streak survives.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .appCardStyle()
    }
    
    // MARK: - Badges Section
    
    private var badgesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            AppSectionHeader<EmptyView>(title: "EARNED BADGES", actionLabel: "See All", onAction: {
                showingAllBadges = true
            })
            
            // Use API badges if loaded, otherwise fall back to mock data
            if badgeService.hasLoaded {
                if badgeService.earnedBadges.isEmpty {
                    Text("Complete streaks and planks to earn your first badge")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(badgeService.earnedBadges) { badge in
                                ProfileAPIBadgeView(badge: badge)
                            }
                        }
                    }
                }
            } else {
                // Loading state
                ProfileBadgesSectionSkeleton()
            }
        }
        .appCardStyle()
    }
}

// MARK: - Profile API Badge View

struct ProfileAPIBadgeView: View {
    let badge: APIBadge
    
    var body: some View {
        VStack(spacing: 8) {
            // Badge icon circle — earned only, always full opacity
            ZStack {
                Circle()
                    .fill(Color.appAccent.opacity(0.2))
                    .frame(width: BadgeViewSize.small.circleSize,
                           height: BadgeViewSize.small.circleSize)
                
                BadgeIconView(icon: badge.icon, size: BadgeViewSize.small.emojiSize)
                    .foregroundStyle(Color.appAccent)
            }
            
            // Badge name
            Text(badge.name)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)
        }
        .frame(width: BadgeViewSize.small.frameWidth)
    }
}

// MARK: - Edit Profile View

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.userService) private var userService
    @Environment(\.authService) private var authService
    @Environment(\.leaderboardService) private var leaderboardService
    
    // Initial values from current user
    let initialDisplayName: String
    let initialLocation: String
    let initialBio: String
    
    @State private var displayName: String = ""
    @State private var location: String = ""
    @State private var bio: String = ""
    @State private var isSaving = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    init(user: UserProfile) {
        self.initialDisplayName = user.displayName
        self.initialLocation = user.location ?? ""
        self.initialBio = user.bio
    }
    
    init(apiUser: APIUser) {
        self.initialDisplayName = apiUser.displayName
        self.initialLocation = apiUser.location ?? ""
        self.initialBio = apiUser.bio ?? ""
    }
    
    /// Fallback init when only minimal auth data is available (profile not yet loaded).
    init(displayName: String, location: String, bio: String) {
        self.initialDisplayName = displayName
        self.initialLocation = location
        self.initialBio = bio
    }
    
    /// Whether any fields have been modified
    private var hasChanges: Bool {
        displayName != initialDisplayName ||
        location != initialLocation ||
        bio != initialBio
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Display Name") {
                    TextField("Your name", text: $displayName)
                        .disabled(isSaving)
                }
                
                Section("Location") {
                    TextField("e.g. London, UK", text: $location)
                        .disabled(isSaving)
                }
                
                Section("Bio") {
                    TextField("A sentence or two about you", text: $bio, axis: .vertical)
                        .lineLimit(3...6)
                        .disabled(isSaving)
                }
                
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Save") {
                            Task {
                                await saveProfile()
                            }
                        }
                        .disabled(!hasChanges)
                    }
                }
            }
            .alert("Couldn't save your profile", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage.isEmpty ? "Something went wrong. Try again." : errorMessage)
            }
            .interactiveDismissDisabled(isSaving)
            .onAppear {
                displayName = initialDisplayName
                location = initialLocation
                bio = initialBio
            }
        }
    }
    
    private func saveProfile() async {
        isSaving = true
        defer { isSaving = false }
        
        do {
            // Only send changed fields
            let newDisplayName = displayName != initialDisplayName ? displayName : nil
            let newLocation = location != initialLocation ? (location.isEmpty ? nil : location) : nil
            let newBio = bio != initialBio ? (bio.isEmpty ? nil : bio) : nil
            
            try await userService.updateProfile(
                displayName: newDisplayName,
                location: newLocation,
                bio: newBio,
                preferredPlankType: nil,
                plankGoalSeconds: nil
            )
            
            // Display name may have changed — mark leaderboard stale so the
            // user's entry shows the updated name on next leaderboard view
            leaderboardService.markStale()
            
            dismiss()
            
        } catch let error as UserServiceError {
            errorMessage = error.localizedDescription
            showingError = true
        } catch {
            errorMessage = "Failed to save profile: \(error.localizedDescription)"
            showingError = true
        }
    }
}

#Preview {
    ProfileView()
        .withMockServices()
}
