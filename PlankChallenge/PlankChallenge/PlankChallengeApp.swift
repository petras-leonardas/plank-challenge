//
//  PlankChallengeApp.swift
//  PlankChallenge
//
//  Created by Leo Bacevicius on 08/03/2026.
//

import SwiftUI
import SwiftData
import UIKit
import GoogleSignIn

// MARK: - App Delegate (APNs token registration + Google Sign-In URL handling)

final class AppDelegate: NSObject, UIApplicationDelegate {
    
    /// Called when APNs successfully registers and issues a device token.
    /// We forward it to the backend via `POST /devices` so push notifications
    /// can be delivered when APNs delivery is enabled in a future release.
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let tokenString = deviceToken.map { String(format: "%02x", $0) }.joined()
        
        Task {
            await DeviceRegistrationService.shared.registerToken(tokenString)
        }
    }
    
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        #if DEBUG
        print("[AppDelegate] Failed to register for remote notifications: \(error.localizedDescription)")
        #endif
    }
    
    /// Called when a silent push (content-available: 1) is received.
    /// The backend sends these whenever a new notification is created for the user.
    /// We use it to refresh the unread count and update the tab badge without
    /// requiring the user to open the app manually.
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        Task {
            await InAppNotificationService.shared.fetchUnreadCount()
            completionHandler(.newData)
        }
    }
    
    /// Handles the OAuth redirect URL from Google Sign-In.
    /// The Google SDK intercepts the URL if it matches the reversed client ID scheme.
    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }
}

// MARK: - Device Registration Service

/// Handles sending the APNs device token to the backend.
/// Kept lightweight and separate from other services — it only runs once per token.
@MainActor
final class DeviceRegistrationService {
    
    static let shared = DeviceRegistrationService()
    private init() {}
    
    /// Last token we successfully registered, to avoid redundant uploads.
    private var registeredToken: String?
    
    func registerToken(_ token: String) async {
        // Skip if this exact token was already registered this session
        guard token != registeredToken else { return }
        
        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let osVersion = UIDevice.current.systemVersion
        let deviceModel = UIDevice.current.model
        
        let body = RegisterDeviceRequest(
            deviceToken: token,
            platform: "ios",
            appVersion: appVersion,
            osVersion: osVersion,
            deviceModel: deviceModel
        )
        
        do {
            let _: EmptyResponse = try await APIClient.shared.post("/devices", body: body)
            registeredToken = token
            #if DEBUG
            print("[DeviceRegistration] Token registered successfully")
            #endif
        } catch {
            // Non-fatal — push notifications won't work but the app continues normally.
            #if DEBUG
            print("[DeviceRegistration] Failed to register token: \(error.localizedDescription)")
            #endif
        }
    }
}

// MARK: - App Entry Point

@main
struct PlankChallengeApp: App {
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    
    // MARK: - Services
    
    /// Shared authentication service instance
    @State private var authService = AuthService.shared
    
    /// Core feature services
    @State private var plankService = PlankService.shared
    @State private var streakService = StreakService.shared
    @State private var badgeService = BadgeService.shared
    @State private var userService = UserService.shared
    
    /// Social feature services
    @State private var groupService = GroupService.shared
    @State private var leaderboardService = LeaderboardService.shared
    
    /// In-app notification service
    @State private var notificationService = InAppNotificationService.shared
    
    /// Media service for photo uploads
    @State private var mediaService = MediaService.shared

    // MARK: - App Body
    
    var body: some Scene {
        WindowGroup {
            RootView()
                // Inject via both the concrete-type key (for views not yet migrated
                // to protocol-based injection) and the key-path key (for all views
                // using @Environment(\.serviceName)). Both are needed during the
                // migration period; the concrete-type injections can be removed once
                // all views use the key-path style.
                .environment(authService)
                .environment(plankService)
                .environment(streakService)
                .environment(badgeService)
                .environment(userService)
                .environment(groupService)
                .environment(leaderboardService)
                .environment(notificationService)
                .environment(mediaService)
                // Key-path injections for protocol-based @Environment(\.keyPath) access
                .environment(\.authService, authService)
                .environment(\.plankService, plankService)
                .environment(\.streakService, streakService)
                .environment(\.badgeService, badgeService)
                .environment(\.userService, userService)
                .environment(\.groupService, groupService)
                .environment(\.leaderboardService, leaderboardService)
                .environment(\.notificationService, notificationService)
                .environment(\.mediaService, mediaService)
                .onChange(of: authService.state) { oldState, newState in
                    handleAuthStateChange(from: oldState, to: newState)
                }
                .onAppear {
                    // Request permission and register for remote notifications.
                    // The token is delivered to AppDelegate and forwarded to the backend.
                    UIApplication.shared.registerForRemoteNotifications()
                }
        }
    }
    
    // MARK: - Auth State Handling
    
    /// Clears all service data when user logs out.
    /// This prevents data from the previous user showing to a new user.
    private func handleAuthStateChange(from oldState: AuthService.AuthState, to newState: AuthService.AuthState) {
        if case .authenticated = oldState, case .unauthenticated = newState {
            clearAllServices()
        }
    }
    
    /// Clears cached data from all services.
    private func clearAllServices() {
        plankService.clearData()
        streakService.clearData()
        badgeService.clearData()
        userService.clearData()
        groupService.clearData()
        leaderboardService.clearData()
        
        #if DEBUG
        print("[PlankChallengeApp] Cleared all service data on logout")
        #endif
    }
}
