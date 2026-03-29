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
        .onChange(of: selectedTab) { oldTab, newTab in
            // Refresh count + list when entering the Notifications tab so the
            // user always sees fresh content regardless of hasLoaded state.
            if newTab == 3 {
                Task {
                    await notificationService.fetchUnreadCount()
                    try? await notificationService.fetchNotifications()
                }
            }
            // Mark all as read when *leaving* the Notifications tab.
            // Doing this here (not in NotificationsView.onDisappear) ensures
            // push-navigating to a profile/group from within the tab does NOT
            // trigger mark-all-read — only a genuine tab switch does.
            if oldTab == 3 && newTab != 3 {
                // Use selective mark-as-read: join request notifications stay
                // unread until the admin explicitly approves or declines them.
                Task { await notificationService.markNonActionableAsRead() }
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
