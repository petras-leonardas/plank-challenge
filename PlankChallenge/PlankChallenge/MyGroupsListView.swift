//
//  MyGroupsListView.swift
//  PlankChallenge
//
//  Created by Leo Bacevicius on 14/03/2026.
//

import SwiftUI

/// Full list view of all groups the user has joined
struct MyGroupsListView: View {
    @Environment(\.groupService) private var groupService
    @State private var showingError = false
    @State private var errorMessage: String?
    
    var body: some View {
        ZStack {
            // App background with subtle gradient
            AppBackground()
            
            Group {
                if groupService.isLoading && !groupService.hasLoaded {
                    loadingView
                } else if let error = groupService.error, !groupService.hasLoaded {
                    // Show error state if we failed to load
                    ErrorView(error: error) {
                        await refreshGroups()
                    }
                } else if groupService.myGroups.isEmpty {
                    emptyState
                } else {
                    groupsList
                }
            }
        }
        .navigationTitle("My Groups")
        .navigationBarTitleDisplayMode(.inline)
        .appNavigationBarStyle()
        .refreshable {
            await refreshGroups()
        }
        .task {
            if !groupService.hasLoaded {
                await refreshGroups()
            }
        }
    }
    
    // MARK: - Subviews
    
    private var loadingView: some View {
        MyGroupsListSkeleton()
    }
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.3")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            
            Text("No groups yet")
                .font(.headline)
            
            Text("Join a group to see it here")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No groups yet. Join a group to see it here.")
    }
    
    private var groupsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(sortedGroups) { group in
                    NavigationLink {
                        GroupDetailView(groupId: group.id)
                    } label: {
                        MyGroupRowCard(group: group)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Double tap to view group details")
                }
            }
            .padding()
        }
    }
    
    /// Groups sorted by most recent activity
    private var sortedGroups: [APIGroup] {
        groupService.myGroups.sorted { $0.updatedDate > $1.updatedDate }
    }
    
    // MARK: - Actions
    
    private func refreshGroups() async {
        do {
            try await groupService.fetchMyGroups()
        } catch {
            // Error stored in service
        }
    }
}

#Preview {
    NavigationStack {
        MyGroupsListView()
            .withMockServices()
    }
}
