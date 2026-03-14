//
//  GroupSettingsView.swift
//  PlankChallenge
//
//  Created by Leo Bacevicius on 08/03/2026.
//

import SwiftUI

struct GroupSettingsView: View {
    let group: MockGroup
    @Environment(\.dismiss) private var dismiss
    @State private var groupName: String
    @State private var groupDescription: String
    @State private var requiresApproval: Bool
    @State private var showingDeleteConfirmation = false
    
    init(group: MockGroup) {
        self.group = group
        _groupName = State(initialValue: group.name)
        _groupDescription = State(initialValue: group.description)
        _requiresApproval = State(initialValue: group.joinMode == .requestToJoin)
    }
    
    var body: some View {
        Form {
            Section("Group Info") {
                TextField("Group Name", text: $groupName)
                TextField("Description", text: $groupDescription, axis: .vertical)
                    .lineLimit(3...6)
            }
            
            if group.groupType == .publicOpen {
                Section("Join Settings") {
                    Toggle("Require Approval", isOn: $requiresApproval)
                }
            }
            
            Section("Members") {
                NavigationLink {
                    GroupMembersListView(group: group)
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
                Button {
                    // Share invite link
                } label: {
                    Label("Share Invite Link", systemImage: "square.and.arrow.up")
                }
            }
            
            Section {
                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    HStack {
                        Spacer()
                        Text("Delete Group")
                        Spacer()
                    }
                }
            } footer: {
                Text("This will permanently delete the group and remove all members.")
            }
        }
        .navigationTitle("Group Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    // Save in Phase 5
                    dismiss()
                }
            }
        }
        .alert("Delete Group?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                // Delete in Phase 5
                dismiss()
            }
        } message: {
            Text("All \(group.memberCount) members will be removed and notified. This cannot be undone.")
        }
    }
}

#Preview {
    NavigationStack {
        GroupSettingsView(group: MockDataService.shared.groups[0])
    }
}
