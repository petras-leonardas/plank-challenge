//
//  ProfileView.swift
//  PlankChallenge
//
//  Created by Leo Bacevicius on 08/03/2026.
//

import SwiftUI

struct ProfileView: View {
    private var mockData: MockDataService { MockDataService.shared }
    @State private var showingEditProfile = false
    @State private var showingQRCodeAlert = false
    @State private var showingSearch = false
    
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
                        
                        // Media Gallery
                        mediaGallery
                            .padding(.top, 20)
                        
                        // Stats Section
                        statsSection
                            .padding(.horizontal, 16)
                            .padding(.top, 20)
                        
                        // Streak & Tokens
                        streakTokensSection
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
            .toolbarBackground(Color.subtleBlueGradientStart.opacity(0.5), for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text("Profile")
                        .font(.headline)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        Button {
                            // Share functionality
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundStyle(.primary)
                        }
                        
                        Button {
                            showingSearch = true
                        } label: {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.primary)
                        }
                        
                        NavigationLink {
                            SettingsView()
                        } label: {
                            Image(systemName: "gearshape")
                                .foregroundStyle(.primary)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingEditProfile) {
                EditProfileView(user: mockData.currentUser)
            }
            .sheet(isPresented: $showingSearch) {
                SearchView(isPresented: $showingSearch)
            }
            .alert("Coming Soon", isPresented: $showingQRCodeAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("QR code sharing will be available in a future update.")
            }
        }
    }
    
    // MARK: - Profile Header (Strava-style)
    
    private var profileHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Avatar + Name row
            HStack(alignment: .top, spacing: 16) {
                // Profile Avatar
                Circle()
                    .fill(LinearGradient.avatarGradient)
                    .frame(width: 72, height: 72)
                    .overlay {
                        Text(String(mockData.currentUser.displayName.prefix(1)))
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                
                // Name and Location
                VStack(alignment: .leading, spacing: 4) {
                    Text(mockData.currentUser.displayName)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if let location = mockData.currentUser.location, !location.isEmpty {
                        Text(location)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
            }
            
            // Bio
            if !mockData.currentUser.bio.isEmpty {
                Text(mockData.currentUser.bio)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            // Following / Followers
            HStack(spacing: 24) {
                NavigationLink {
                    FollowListView(type: .following)
                } label: {
                    HStack(spacing: 4) {
                        Text("Following")
                            .foregroundStyle(.secondary)
                        Text("\(mockData.following.count)")
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                    }
                    .font(.subheadline)
                }
                .buttonStyle(.plain)
                
                NavigationLink {
                    FollowListView(type: .followers)
                } label: {
                    HStack(spacing: 4) {
                        Text("Followers")
                            .foregroundStyle(.secondary)
                        Text("\(mockData.followers.count)")
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                    }
                    .font(.subheadline)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 4)
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
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .foregroundStyle(Color.appAccent)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.appAccent, lineWidth: 1.5)
                )
            }
            
            // Share QR Code button
            Button {
                showingQRCodeAlert = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "qrcode")
                        .font(.caption)
                    Text("Share QR Code")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .foregroundStyle(Color.appAccent)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.appAccent, lineWidth: 1.5)
                )
            }
            
            Spacer()
        }
    }
    
    // MARK: - Media Gallery
    
    private var mediaGallery: some View {
        MediaGalleryView(
            images: MediaItem.mockItems,
            personalBestTime: mockData.longestPlank?.durationSeconds.formattedDuration,
            personalBestDate: mockData.longestPlank?.date,
            onAllMediaTapped: {
                // TODO: Navigate to all media view
            }
        )
    }
    
    // MARK: - Stats Section
    
    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("YOUR STATS")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            
            HStack(spacing: 12) {
                // Streak
                StatBox(
                    icon: "flame.fill",
                    iconColor: .orange,
                    value: "\(mockData.currentUser.currentStreak)",
                    label: "Day Streak"
                )
                
                // Total Planks
                StatBox(
                    icon: "figure.core.training",
                    iconColor: .blue,
                    value: "\(mockData.totalPlanks)",
                    label: "Total Planks"
                )
                
                // Best Plank
                StatBox(
                    icon: "trophy.fill",
                    iconColor: .yellow,
                    value: mockData.longestPlank?.durationSeconds.formattedDuration ?? "0:00",
                    label: "Best Plank"
                )
            }
        }
        .padding(16)
        .background(Color.warmWhiteCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Streak & Tokens Section
    
    private var streakTokensSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("STREAK FREEZE TOKENS")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            
            HStack {
                // Token indicators
                HStack(spacing: 8) {
                    ForEach(0..<Constants.Streak.maxFreezeTokens, id: \.self) { index in
                        Circle()
                            .fill(index < mockData.currentUser.freezeTokens ? Color.cyan : Color.gray.opacity(0.3))
                            .frame(width: 24, height: 24)
                            .overlay {
                                Image(systemName: "snowflake")
                                    .font(.system(size: 12))
                                    .foregroundStyle(index < mockData.currentUser.freezeTokens ? .white : .gray)
                            }
                    }
                }
                
                Spacer()
                
                Text("\(mockData.currentUser.freezeTokens)/\(Constants.Streak.maxFreezeTokens) remaining")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Text("Tokens automatically protect your streak when you miss a day")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .background(Color.warmWhiteCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Badges Section
    
    private var badgesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("EARNED BADGES")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                NavigationLink {
                    BadgesView()
                } label: {
                    Text("See All")
                        .font(.subheadline)
                        .foregroundStyle(Color.appAccent)
                }
            }
            
            if mockData.badges.isEmpty {
                Text("Complete streaks to earn badges!")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(mockData.badges) { badge in
                            if let badgeType = badge.badgeType {
                                BadgeView(
                                    badgeType: badgeType,
                                    isEarned: true,
                                    dateEarned: badge.dateEarned
                                )
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color.warmWhiteCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Stat Box Component

struct StatBox: View {
    let icon: String
    let iconColor: Color
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(iconColor)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.softBlueBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Edit Profile View

struct EditProfileView: View {
    let user: UserProfile
    @Environment(\.dismiss) private var dismiss
    
    @State private var displayName: String = ""
    @State private var location: String = ""
    @State private var bio: String = ""
    @State private var selectedPlankType: Constants.Plank.PlankType = .elbow
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Display Name") {
                    TextField("Name", text: $displayName)
                }
                
                Section("Location") {
                    TextField("e.g. London, UK", text: $location)
                }
                
                Section("Bio") {
                    TextField("Tell us about yourself", text: $bio, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("Preferred Plank Type") {
                    Picker("Plank Type", selection: $selectedPlankType) {
                        ForEach(Constants.Plank.PlankType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        // TODO: Save changes
                        dismiss()
                    }
                }
            }
            .onAppear {
                displayName = user.displayName
                location = user.location ?? ""
                bio = user.bio
            }
        }
    }
}

#Preview {
    ProfileView()
}
