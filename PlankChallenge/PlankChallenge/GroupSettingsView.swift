//
//  GroupSettingsView.swift
//  PlankChallenge
//
//  Created by Leo Bacevicius on 08/03/2026.
//

import SwiftUI
import UIKit

struct GroupSettingsView: View {
    let groupId: String
    
    @Environment(\.groupService) private var groupService
    @Environment(\.dismiss) private var dismiss
    
    @State private var groupName: String = ""
    @State private var groupDescription: String = ""
    @State private var requiresApproval: Bool = false
    @State private var showingDeleteConfirmation = false
    @State private var isSaving = false
    @State private var isDeleting = false
    @State private var saveError: Error?
    @State private var deleteError: Error?
    @State private var showingDeleteError = false
    
    var body: some View {
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
            ToolbarItem(placement: .confirmationAction) {
                if isSaving {
                    ProgressView()
                } else {
                    Button("Save") {
                        Task { await saveSettings() }
                    }
                    .disabled(groupName.trimmingCharacters(in: .whitespaces).isEmpty)
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
        .alert("Couldn't delete group", isPresented: $showingDeleteError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deleteError?.localizedDescription ?? "Something went wrong. Try again.")
        }
        .onAppear {
            // Initialize form when view appears (works even if group already loaded)
            if let group = groupService.currentGroup {
                initializeForm(from: group)
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
    
    private var loadingView: some View {
        ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func settingsForm(_ group: APIGroup) -> some View {
        Form {
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
            
            if let error = saveError {
                SwiftUI.Section {
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundStyle(.red)
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
    
    // MARK: - Helpers
    
    private func initializeForm(from group: APIGroup) {
        groupName = group.name
        groupDescription = group.description ?? ""
        requiresApproval = group.requiresApproval
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
        
        guard nameChanged || descriptionChanged || approvalChanged else {
            // Nothing changed — just dismiss
            dismiss()
            return
        }
        
        do {
            try await groupService.updateGroup(
                id: groupId,
                name: nameChanged ? trimmedName : nil,
                description: descriptionChanged ? trimmedDescription : nil,
                joinMode: approvalChanged ? (requiresApproval ? "request" : "open") : nil
            )
            dismiss()
        } catch {
            saveError = error
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
}

#Preview {
    NavigationStack {
        GroupSettingsView(groupId: "preview-group")
            .withMockServices()
    }
}
