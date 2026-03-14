//
//  GroupMembersListView.swift
//  PlankChallenge
//
//  Created by Leo Bacevicius on 08/03/2026.
//

import SwiftUI

struct GroupMembersListView: View {
    let group: MockGroup
    @State private var searchText = ""
    
    var body: some View {
        List {
            ForEach(filteredMembers) { member in
                NavigationLink {
                    UserProfileView(user: member)
                } label: {
                    MemberRow(member: member, isAdmin: group.members.first?.id == member.id)
                }
            }
        }
        .navigationTitle("Members")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search members")
    }
    
    private var filteredMembers: [MockUser] {
        if searchText.isEmpty {
            return group.members
        }
        return group.members.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText)
        }
    }
}

struct MemberRow: View {
    let member: MockUser
    let isAdmin: Bool
    
    var body: some View {
        UserRowWithAdminBadge(
            name: member.displayName,
            subtitle: "\(member.currentStreak) day streak",
            avatarText: String(member.displayName.prefix(1)),
            avatarImageName: member.profileImageName,
            isAdmin: isAdmin,
            showChevron: false
        )
    }
}

#Preview {
    NavigationStack {
        GroupMembersListView(group: MockDataService.shared.groups[0])
    }
}
