//
//  MainTabView.swift
//  PlankChallenge
//
//  Created by Leo Bacevicius on 08/03/2026.
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            PlankTimerView()
                .tabItem {
                    Label("Plank", systemImage: "figure.core.training")
                }
                .tag(0)
            
            PlankProgressView()
                .tabItem {
                    Label("Progress", systemImage: "chart.bar.fill")
                }
                .tag(1)
            
            GroupsView()
                .tabItem {
                    Label("Groups", systemImage: "person.3.fill")
                }
                .tag(2)
            
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.circle.fill")
                }
                .tag(3)
            
            // Design System tab - only visible in DEBUG builds
            #if DEBUG
            DesignSystemCatalog()
                .tabItem {
                    Label("Design", systemImage: "paintbrush")
                }
                .tag(4)
            #endif
        }
        .tint(Color.appAccent)
    }
}

#Preview {
    MainTabView()
}
