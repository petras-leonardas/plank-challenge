//
//  MyGroupsListView.swift
//  PlankChallenge
//
//  Created by Leo Bacevicius on 14/03/2026.
//

import SwiftUI

/// Full list view of all groups the user has joined
struct MyGroupsListView: View {
    private var mockData: MockDataService { MockDataService.shared }
    
    var body: some View {
        ZStack {
            // App background with subtle gradient
            AppBackground()
            
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(mockData.myGroupsSortedByActivity) { group in
                        NavigationLink {
                            GroupDetailView(group: group)
                        } label: {
                            MyGroupRowCard(group: group)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
        }
        .navigationTitle("My Groups")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.subtleBlueGradientStart.opacity(0.5), for: .navigationBar)
    }
}

/// Compact row card for My Groups list
struct MyGroupRowCard: View {
    let group: MockGroup
    
    var body: some View {
        HStack(spacing: 12) {
            // Group image placeholder
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.appAccent.opacity(0.15))
                    .frame(width: 56, height: 56)
                
                Image(systemName: "person.3.fill")
                    .font(.title3)
                    .foregroundStyle(Color.appAccent)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(group.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    
                    if group.groupType == .privateInvite {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                
                HStack(spacing: 8) {
                    Text("\(group.memberCount) members")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    if group.isCurrentUserAdmin {
                        Text("Admin")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.appAccent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.appAccent.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(Color.warmWhiteCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
}

#Preview {
    NavigationStack {
        MyGroupsListView()
    }
}
