//
//  GroupsView.swift
//  PlankChallenge
//
//  Created by Leo Bacevicius on 08/03/2026.
//

import SwiftUI
import PhotosUI

// MARK: - Group Section Enum

enum GroupSection: String, CaseIterable {
    case myGroups = "My Groups"
    case discover = "Discover"
    case rankings = "Rankings"
}

// MARK: - Groups View

struct GroupsView: View {
    @Environment(\.groupService) private var groupService
    @State private var showingCreateGroup = false
    @State private var selectedSection: GroupSection = .myGroups

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                Group {
                    if groupService.isLoading && !groupService.hasLoaded {
                        GroupsSkeleton()
                    } else if let error = groupService.error, !groupService.hasLoaded {
                        ErrorView(error: error) {
                            await loadData()
                        }
                    } else {
                        contentView
                    }
                }
            }
            .navigationTitle("Groups")
            .appNavigationBarStyle()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingCreateGroup = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Create new group")
                }
            }
            .sheet(isPresented: $showingCreateGroup) {
                CreateGroupView()
            }
            .task {
                if !groupService.hasLoaded {
                    await loadData()
                }
            }
        }
    }

    // MARK: - Content

    private var contentView: some View {
        VStack(spacing: 0) {
            // Segmented section picker
            Picker("Section", selection: $selectedSection) {
                ForEach(GroupSection.allCases, id: \.self) { section in
                    Text(section.rawValue).tag(section)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            // Active section content
            switch selectedSection {
            case .myGroups:
                myGroupsContent
            case .discover:
                discoverContent
            case .rankings:
                rankingsContent
            }
        }
    }

    // MARK: - My Groups

    private var myGroupsContent: some View {
        ScrollView {
            VStack(spacing: 8) {
                if groupService.myGroups.isEmpty {
                    emptyMyGroupsState
                        .padding(.top, 8)
                } else {
                    ForEach(sortedMyGroups) { group in
                        NavigationLink {
                            GroupDetailView(groupId: group.id)
                        } label: {
                            MyGroupRowCard(group: group)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .refreshable {
            await loadData()
        }
    }

    private var sortedMyGroups: [APIGroup] {
        groupService.myGroups.sorted { $0.updatedDate > $1.updatedDate }
    }

    private var emptyMyGroupsState: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.3")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)

            Text("No groups yet")
                .font(.headline)

            Text("Groups are where things get competitive. Create one or join an existing group to get on a shared leaderboard.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                showingCreateGroup = true
            } label: {
                Text("Create a group")
            }
            .pillButtonStyle(isSelected: true)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .appCardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No groups yet. Join a group or create your own to compete with others.")
    }

    // MARK: - Discover

    private var discoverContent: some View {
        ScrollView {
            VStack(spacing: 8) {
                if groupService.discoverGroups.isEmpty {
                    emptyDiscoverState
                        .padding(.top, 8)
                } else {
                    ForEach(groupService.discoverGroups) { group in
                        NavigationLink {
                            GroupDetailView(groupId: group.id)
                        } label: {
                            DiscoverGroupRowCard(group: group)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .refreshable {
            await loadData()
        }
    }

    private var emptyDiscoverState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)

            Text("No groups to discover")
                .font(.headline)

            Text("There are no public groups available right now. Create one and others will find you.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .appCardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No public groups available.")
    }

    // MARK: - Rankings

    private var rankingsContent: some View {
        RankingsContent()
    }

    // MARK: - Data Loading

    private func loadData() async {
        do {
            async let myGroupsTask: () = groupService.fetchMyGroups()
            async let discoverTask: () = groupService.fetchDiscoverGroups()
            _ = try await (myGroupsTask, discoverTask)
        } catch {
            // Errors are stored in service
        }
    }
}

// MARK: - My Group Row Card (uses APIGroup)

struct MyGroupRowCard: View {
    let group: APIGroup
    
    var body: some View {
        HStack(spacing: 12) {
            // Group image placeholder
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.appAccent.opacity(0.15))
                    .frame(width: 56, height: 56)
                
                if let imageUrl = group.imageUrl, let url = URL(string: imageUrl) {
                    CachedGroupImage(url: url, size: 56, cornerRadius: 12)
                } else {
                    Image(systemName: "person.3.fill")
                        .font(.title3)
                        .foregroundStyle(Color.appAccent)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(group.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    
                    if group.isPrivate {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Text("\(group.memberCount) members")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .appCardStyleCompact()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(group.name), \(group.memberCount) members")
        .accessibilityHint("Tap to view group details")
    }
}

// MARK: - Discover Group Row Card (uses APIGroup)

struct DiscoverGroupRowCard: View {
    let group: APIGroup
    
    var body: some View {
        HStack(spacing: 12) {
            // Group image
            ZStack {
                RoundedRectangle(cornerRadius: Constants.UI.cardRadius)
                    .fill(Color.appAccent.opacity(0.15))
                    .frame(width: 56, height: 56)
                
                if let imageUrl = group.imageUrl, let url = URL(string: imageUrl) {
                    CachedGroupImage(url: url, size: 56, cornerRadius: Constants.UI.cardRadius)
                } else {
                    Image(systemName: "person.3.fill")
                        .font(.title3)
                        .foregroundStyle(Color.appAccent)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(group.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    
                    if group.isPrivate {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                
                HStack(spacing: 8) {
                    Text("\(group.memberCount) members")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    if group.requiresApproval {
                        Text("· Approval required")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .appCardStyleCompact()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(group.name), \(group.memberCount) members\(group.requiresApproval ? ", approval required" : "")")
        .accessibilityHint("Tap to view group details")
    }
}

// MARK: - Create Group View

struct CreateGroupView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.groupService) private var groupService
    @Environment(\.mediaService) private var mediaService
    
    @State private var groupName = ""
    @State private var groupDescription = ""
    @State private var isPrivate = false
    @State private var requiresApproval = false
    @State private var isCreating = false
    @State private var createError: Error?
    
    // Photo picker state
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    
    private var isValid: Bool {
        !groupName.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Photo picker — centred above the form fields in its own section
                Section {
                    HStack {
                        Spacer()
                        PhotosPicker(
                            selection: $selectedPhotoItem,
                            matching: .images,
                            photoLibrary: .shared()
                        ) {
                            ZStack {
                                Circle()
                                    .fill(Color.appAccent.opacity(0.15))
                                    .frame(width: 100, height: 100)
                                
                                if let image = selectedImage {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 100, height: 100)
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(Color.appAccent, lineWidth: 2))
                                } else {
                                    VStack(spacing: 4) {
                                        Image(systemName: "camera.fill")
                                            .font(.title2)
                                            .foregroundStyle(Color.appAccent)
                                        Text("Add Photo")
                                            .font(.caption2)
                                            .foregroundStyle(Color.appAccent)
                                    }
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                    .padding(.vertical, 8)
                }
                
                Section("Group Info") {
                    LabeledContent("Name") {
                        TextField("e.g. Office Core Club", text: $groupName)
                            .multilineTextAlignment(.trailing)
                    }
                    .accessibilityLabel("Group name")
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Description")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        TextField("Optional", text: $groupDescription, axis: .vertical)
                            .lineLimit(2...5)
                    }
                    .padding(.vertical, 4)
                    .accessibilityLabel("Group description, optional")
                }
                
                Section {
                    Toggle("Private group", isOn: $isPrivate)
                        .accessibilityHint("Private groups are not searchable. You'll need to invite members.")
                    
                    if !isPrivate {
                        Toggle("Require approval to join", isOn: $requiresApproval)
                            .accessibilityHint("You'll need to approve each join request.")
                    }
                } header: {
                    Text("Privacy")
                } footer: {
                    if isPrivate {
                        Text("Only people you invite can find or join this group.")
                    } else if requiresApproval {
                        Text("Anyone can find it, but you'll approve each request.")
                    } else {
                        Text("Anyone can find and join this group.")
                    }
                }
                
                if let error = createError {
                    Section {
                        CompactErrorView(error.localizedDescription)
                    }
                }
            }
            .navigationTitle("New Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isCreating)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isCreating {
                        ProgressView()
                    } else {
                        Button("Create Group") {
                            Task { await createGroup() }
                        }
                        .disabled(!isValid)
                    }
                }
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        selectedImage = image
                    }
                }
            }
        }
    }
    
    private func createGroup() async {
        isCreating = true
        createError = nil
        defer { isCreating = false }
        
        // Backend accepts: groupType = "public"|"private", joinMode = "open"|"request"
        let groupType: APIGroupType = isPrivate ? .private : .public
        let joinMode: APIJoinMode = (isPrivate || requiresApproval) ? .request : .open
        
        do {
            let newGroup = try await groupService.createGroup(
                name: groupName.trimmingCharacters(in: .whitespaces),
                description: groupDescription.isEmpty ? nil : groupDescription,
                groupType: groupType,
                joinMode: joinMode
            )
            
            // Upload group photo if one was selected (non-fatal — group is created regardless).
            // Capture the returned URL and patch the in-memory list immediately so the
            // group card shows the photo without needing a full re-fetch.
            if let image = selectedImage,
               let newImageUrl = try? await mediaService.uploadGroupImage(groupId: newGroup.id, image: image) {
                groupService.updateGroupImage(groupId: newGroup.id, imageUrl: newImageUrl)
            }
            
            dismiss()
        } catch {
            createError = error
        }
    }
}

#Preview {
    GroupsView()
        .withMockServices()
}
