//
//  GroupMembersListView.swift
//  PlankChallenge
//
//  Created by Leo Bacevicius on 08/03/2026.
//

import SwiftUI

struct GroupMembersListView: View {
    let groupId: String
    
    @Environment(\.groupService) private var groupService
    @State private var searchText = ""
    @State private var lastLoadedGroupId: String?
    
    var body: some View {
        Group {
            if groupService.isLoading && groupService.currentGroupMembers.isEmpty {
                loadingView
            } else if groupService.currentGroupMembers.isEmpty {
                emptyState
            } else {
                membersList
            }
        }
        .navigationTitle("Members")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search members")
        .refreshable {
            await loadMembers()
        }
        .task(id: groupId) {
            // Only load if groupId changed or we haven't loaded for this group
            guard lastLoadedGroupId != groupId else { return }
            await loadMembers()
            lastLoadedGroupId = groupId
        }
    }
    
    // MARK: - Subviews
    
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading members...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.2.slash")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            
            Text("No members found")
                .font(.headline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var membersList: some View {
        List {
            ForEach(filteredMembers) { member in
                NavigationLink {
                    UserProfileView(userId: member.userId)
                } label: {
                    MemberRow(member: member)
                }
            }
        }
    }
    
    private var filteredMembers: [APIGroupMember] {
        if searchText.isEmpty {
            return groupService.currentGroupMembers
        }
        return groupService.currentGroupMembers.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    // MARK: - Actions
    
    private func loadMembers() async {
        do {
            try await groupService.fetchGroupMembers(groupId: groupId)
        } catch {
            // Error stored in service
        }
    }
}

// MARK: - Member Row

struct MemberRow: View {
    let member: APIGroupMember
    
    var body: some View {
        UserRowWithAdminBadge(
            name: member.displayName,
            subtitle: member.displayRole ?? "Member",
            avatarText: String(member.displayName.prefix(1)),
            avatarImageName: nil,
            isAdmin: member.isAdmin,
            showChevron: false
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(member.displayName), \(member.displayRole ?? "Member")")
    }
}

#Preview {
    NavigationStack {
        GroupMembersListView(groupId: "preview-group")
            .withMockServices()
    }
}
