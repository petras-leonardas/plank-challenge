//
//  MainTabView.swift
//  PlankChallenge
//
//  Created by Leo Bacevicius on 08/03/2026.
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @Environment(\.notificationService) private var notificationService
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.authService) private var authService
    
    var body: some View {
        TabView(selection: $selectedTab) {
            PlankTimerView()
                .tabItem {
                    Label("Plank", image: "AppLogoTabBar")
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
            
            NavigationStack {
                NotificationsView()
            }
            .tabItem {
                Label("Notifications", systemImage: "bell.fill")
            }
            .badge(notificationService.unreadCount > 0 ? notificationService.unreadCount : 0)
            .tag(3)
            
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.circle.fill")
                }
                .tag(4)
        }
        .tint(Color.appAccent)
        .onChange(of: selectedTab) { _, tab in
            // Refresh unread count whenever the Notifications tab is selected
            if tab == 3 {
                Task { await notificationService.fetchUnreadCount() }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            // Refresh unread count every time the app comes to the foreground
            if phase == .active, case .authenticated = authService.state {
                Task { await notificationService.fetchUnreadCount() }
            }
        }
    }
}

#Preview {
    MainTabView()
}
