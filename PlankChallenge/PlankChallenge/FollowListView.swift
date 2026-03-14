//
//  FollowListView.swift
//  PlankChallenge
//
//  Created by Leo Bacevicius on 08/03/2026.
//

import SwiftUI

struct FollowListView: View {
    let type: FollowType
    private var mockData: MockDataService { MockDataService.shared }
    @State private var searchText = ""
    
    enum FollowType {
        case following
        case followers
        
        var title: String {
            switch self {
            case .following: return "Following"
            case .followers: return "Followers"
            }
        }
    }
    
    var body: some View {
        List {
            ForEach(filteredUsers) { user in
                NavigationLink {
                    UserProfileView(user: user)
                } label: {
                    FollowUserRow(user: user)
                }
            }
        }
        .navigationTitle(type.title)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search")
    }
    
    private var users: [MockUser] {
        switch type {
        case .following:
            return mockData.following
        case .followers:
            return mockData.followers
        }
    }
    
    private var filteredUsers: [MockUser] {
        if searchText.isEmpty {
            return users
        }
        return users.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText)
        }
    }
}

struct FollowUserRow: View {
    let user: MockUser
    
    var body: some View {
        UserRowView(
            name: user.displayName,
            subtitle: "\(user.currentStreak) day streak",
            avatarText: String(user.displayName.prefix(1)),
            avatarImageName: user.profileImageName
        )
    }
}

#Preview {
    NavigationStack {
        FollowListView(type: .following)
    }
}
