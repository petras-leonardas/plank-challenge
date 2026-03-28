//
//  MemberGroupSettingsView.swift
//  PlankChallenge
//

import SwiftUI

/// Settings sheet shown to regular group members (non-admin).
/// Currently exposes only the Leave Group action.
struct MemberGroupSettingsView: View {
    let groupId: String

    @Environment(\.groupService) private var groupService
    @Environment(\.dismiss) private var dismiss

    @State private var showingLeaveConfirmation = false
    @State private var isLeaving = false
    @State private var leaveError: Error?
    @State private var showingLeaveError = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button(role: .destructive) {
                        showingLeaveConfirmation = true
                    } label: {
                        HStack {
                            Spacer()
                            if isLeaving {
                                ProgressView()
                            } else {
                                Text("Leave Group")
                            }
                            Spacer()
                        }
                    }
                    .disabled(isLeaving)
                } footer: {
                    Text("You'll be removed from the leaderboard. You can always rejoin.")
                }
            }
            .navigationTitle("Group Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isLeaving)
                }
            }
            .alert("Leave this group?", isPresented: $showingLeaveConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Leave", role: .destructive) {
                    Task { await leaveGroup() }
                }
            } message: {
                Text("You'll be removed from the leaderboard. You can always rejoin.")
            }
            .alert("Couldn't leave group", isPresented: $showingLeaveError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(leaveError?.localizedDescription ?? "Something went wrong. Try again.")
            }
        }
    }

    private func leaveGroup() async {
        isLeaving = true
        defer { isLeaving = false }

        do {
            try await groupService.leaveGroup(id: groupId)
            dismiss()
        } catch {
            leaveError = error
            showingLeaveError = true
        }
    }
}
