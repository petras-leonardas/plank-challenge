//
//  GroupSettingsView.swift
//  PlankChallenge
//
//  Created by Leo Bacevicius on 08/03/2026.
//

import SwiftUI
import UIKit
import PhotosUI

struct GroupSettingsView: View {
    let groupId: String
    
    @Environment(\.groupService) private var groupService
    @Environment(\.mediaService) private var mediaService
    @Environment(\.dismiss) private var dismiss
    
    @State private var groupName: String = ""
    @State private var groupDescription: String = ""
    @State private var requiresApproval: Bool = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var showingDeleteConfirmation = false
    @State private var isSaving = false
    @State private var isDeleting = false
    @State private var showingSaveError = false
    @State private var saveError: Error?
    @State private var deleteError: Error?
    @State private var showingDeleteError = false
    @State private var joinRequestActionError: String?
    @State private var showingJoinRequestError = false
    @State private var isLoadingRequests = false
    @State private var loadRequestsError: String?
    @State private var showingLoadRequestsError = false
    /// IDs of requests currently being approved or denied — prevents double-taps.
    @State private var actioningRequestIds: Set<String> = []
    
    var body: some View {
        NavigationStack {
            Group {
                if let group = groupService.currentGroup {
                    settingsForm(group)
                } else if groupService.isLoading {
                    loadingView
                } else {
                    Text("Group not found")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Group Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isSaving || isDeleting)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Save") {
                            Task { await saveSettings() }
                        }
                        .fontWeight(.semibold)
                        .disabled(groupName.trimmingCharacters(in: .whitespaces).isEmpty || isDeleting)
                    }
                }
            }
        }
        // Photo picker handler at the NavigationStack level — idiomatic placement,
        // matches the CreateGroupView pattern in GroupsView.swift.
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    selectedImage = image
                }
            }
        }
        .alert("Delete this group?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete Group", role: .destructive) {
                Task { await deleteGroup() }
            }
        } message: {
            if let group = groupService.currentGroup {
                Text("All \(group.memberCount) members will be removed and notified. This can't be undone.")
            }
        }
        .alert("Couldn't save changes", isPresented: $showingSaveError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveError?.localizedDescription ?? "Something went wrong. Try again.")
        }
        .alert("Couldn't delete group", isPresented: $showingDeleteError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deleteError?.localizedDescription ?? "Something went wrong. Try again.")
        }
        .alert("Couldn't process request", isPresented: $showingJoinRequestError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(joinRequestActionError ?? "Something went wrong. Try again.")
        }
        .alert("Couldn't load requests", isPresented: $showingLoadRequestsError) {
            Button("Retry") { Task { await loadJoinRequests() } }
            Button("OK", role: .cancel) {}
        } message: {
            Text(loadRequestsError ?? "The pending requests couldn't be loaded. Try again.")
        }
        .onAppear {
            // Initialize form when view appears (works even if group already loaded)
            if let group = groupService.currentGroup {
                initializeForm(from: group)
            }
            // Load pending join requests for admins
            if groupService.isCurrentUserAdmin {
                Task { await loadJoinRequests() }
            }
        }
        .onChange(of: groupService.currentGroup?.id) { _, newGroupId in
            // Re-initialize if group changes (compare by ID since APIGroup isn't Equatable)
            if newGroupId != nil, let group = groupService.currentGroup {
                initializeForm(from: group)
            }
        }
    }
    
    // MARK: - Subviews

    private var groupImagePlaceholder: some View {
        VStack(spacing: 4) {
            Image(systemName: "camera.fill")
                .font(.title2)
                .foregroundStyle(Color.appAccent)
            Text("Add Photo")
                .font(.caption2)
                .foregroundStyle(Color.appAccent)
        }
    }

    private var loadingView: some View {
        ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func settingsForm(_ group: APIGroup) -> some View {
        Form {
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
                            } else if let imageUrl = group.imageUrl, !imageUrl.isEmpty {
                                AsyncImage(url: URL(string: imageUrl)) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 100, height: 100)
                                            .clipShape(Circle())
                                            .overlay(Circle().stroke(Color.appAccent, lineWidth: 2))
                                    default:
                                        groupImagePlaceholder
                                    }
                                }
                                .frame(width: 100, height: 100)
                            } else {
                                groupImagePlaceholder
                            }
                        }
                    }
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }

            Section("Group Info") {
                TextField("Group Name", text: $groupName)
                    .accessibilityLabel("Group name")
                
                TextField("Description", text: $groupDescription, axis: .vertical)
                    .lineLimit(3...6)
                    .accessibilityLabel("Group description")
            }
            
            if !group.isPrivate {
                Section("Join Settings") {
                    Toggle("Require approval to join", isOn: $requiresApproval)
                        .accessibilityHint("When enabled, you'll need to approve each join request")
                }
            }
            
            // Pending requests — visible to admins only when there are pending requests
            // or when the group uses request-based joining
            if groupService.isCurrentUserAdmin && (group.requiresApproval || !groupService.currentGroupJoinRequests.isEmpty) {
                pendingRequestsSection
            }
            
            Section("Members") {
                NavigationLink {
                    GroupMembersListView(groupId: groupId)
                } label: {
                    HStack {
                        Text("Manage Members")
                        Spacer()
                        Text("\(group.memberCount)")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Section("Invite") {
                if let inviteCode = group.inviteCode {
                    Button {
                        shareInviteLink(code: inviteCode)
                    } label: {
                        Label("Share Invite Link", systemImage: "square.and.arrow.up")
                    }
                } else {
                    Text("Invite link unavailable")
                        .foregroundStyle(.secondary)
                }
            }
            
            SwiftUI.Section {
                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    HStack {
                        Spacer()
                        if isDeleting {
                            ProgressView()
                        } else {
                            Text("Delete Group")
                        }
                        Spacer()
                    }
                }
                .disabled(isDeleting)
            } header: {
                Text("Danger Zone")
            } footer: {
                Text("Permanently deletes this group and removes all members. This can't be undone.")
            }
        }
    }
    
    // MARK: - Pending Requests Section
    
    @ViewBuilder
    private var pendingRequestsSection: some View {
        Section {
            if isLoadingRequests {
                HStack {
                    ProgressView()
                    Text("Loading requests...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else if groupService.currentGroupJoinRequests.isEmpty {
                Text("No pending requests")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(groupService.currentGroupJoinRequests) { request in
                    pendingRequestRow(request)
                }
            }
        } header: {
            HStack {
                Text("Pending Requests")
                if !groupService.currentGroupJoinRequests.isEmpty {
                    Text("(\(groupService.currentGroupJoinRequests.count))")
                        .foregroundStyle(Color.appAccent)
                }
            }
        }
    }
    
    @ViewBuilder
    private func pendingRequestRow(_ request: APIJoinRequest) -> some View {
        HStack(spacing: 12) {
            AvatarView(
                text: request.user?.displayName ?? "?",
                imageName: nil,
                imageUrl: request.user?.profileImageUrl,
                size: 36
            )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(request.user?.displayName ?? "Unknown")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if let username = request.user?.username {
                    Text("@\(username)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            let isActioning = actioningRequestIds.contains(request.id)
            HStack(spacing: 8) {
                if isActioning {
                    ProgressView()
                        .scaleEffect(0.8)
                        .frame(width: 44, height: 44)
                } else {
                    Button {
                        actioningRequestIds.insert(request.id)
                        Task { await handleRequest(request, approve: true) }
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.successColor)
                            .font(.title2)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Approve \(request.user?.displayName ?? "request")")

                    Button {
                        actioningRequestIds.insert(request.id)
                        Task { await handleRequest(request, approve: false) }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.errorColor)
                            .font(.title2)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Deny \(request.user?.displayName ?? "request")")
                }
            }
        }
        .padding(.vertical, 2)
    }
    
    // MARK: - Helpers
    
    private func initializeForm(from group: APIGroup) {
        groupName = group.name
        groupDescription = group.description ?? ""
        requiresApproval = group.requiresApproval
        // Reset any pending photo selection so stale picks don't carry over
        selectedImage = nil
        selectedPhotoItem = nil
    }
    
    private func shareInviteLink(code: String) {
        let inviteUrl = "https://plankchallenge.app/join/\(code)"
        let activityVC = UIActivityViewController(
            activityItems: [inviteUrl],
            applicationActivities: nil
        )
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = scene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
    
    // MARK: - Actions
    
    private func saveSettings() async {
        isSaving = true
        saveError = nil
        defer { isSaving = false }
        
        guard let currentGroup = groupService.currentGroup else { return }
        
        let trimmedName = groupName.trimmingCharacters(in: .whitespaces)
        let trimmedDescription = groupDescription.trimmingCharacters(in: .whitespaces)
        
        let nameChanged = trimmedName != currentGroup.name
        let descriptionChanged = trimmedDescription != (currentGroup.description ?? "")
        let approvalChanged = requiresApproval != currentGroup.requiresApproval
        let imageChanged = selectedImage != nil

        guard nameChanged || descriptionChanged || approvalChanged || imageChanged else {
            // Nothing changed — just dismiss
            dismiss()
            return
        }

        do {
            if nameChanged || descriptionChanged || approvalChanged {
                try await groupService.updateGroup(
                    id: groupId,
                    name: nameChanged ? trimmedName : nil,
                    description: descriptionChanged ? trimmedDescription : nil,
                    joinMode: approvalChanged ? (requiresApproval ? "request" : "open") : nil
                )
            }

            if let image = selectedImage {
                let newImageUrl = try await mediaService.uploadGroupImage(groupId: groupId, image: image)
                groupService.updateGroupImage(groupId: groupId, imageUrl: newImageUrl)
            }

            dismiss()
        } catch {
            saveError = error
            showingSaveError = true
        }
    }
    
    private func deleteGroup() async {
        isDeleting = true
        deleteError = nil
        defer { isDeleting = false }
        
        do {
            try await groupService.deleteGroup(id: groupId)
            // GroupService already cleared currentGroup on success.
            // Dismissing the sheet returns to GroupDetailView, which will
            // show the error/empty state and the user can pop back.
            dismiss()
        } catch {
            deleteError = error
            showingDeleteError = true
        }
    }
    
    private func loadJoinRequests() async {
        isLoadingRequests = true
        loadRequestsError = nil
        defer { isLoadingRequests = false }
        do {
            try await groupService.fetchJoinRequests(groupId: groupId)
        } catch {
            loadRequestsError = error.localizedDescription
            showingLoadRequestsError = true
        }
    }
    
    private func handleRequest(_ request: APIJoinRequest, approve: Bool) async {
        defer { actioningRequestIds.remove(request.id) }
        do {
            if approve {
                try await groupService.approveJoinRequest(groupId: groupId, requestId: request.id)
            } else {
                try await groupService.denyJoinRequest(groupId: groupId, requestId: request.id)
            }
        } catch {
            joinRequestActionError = error.localizedDescription
            showingJoinRequestError = true
        }
    }
}

#Preview {
    NavigationStack {
        GroupSettingsView(groupId: "preview-group")
            .withMockServices()
    }
}
