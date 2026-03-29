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
    ///
    /// The backend sends a typed payload:
    ///   { aps: { "content-available": 1 }, refreshType: ["notifications", "groups", ...] }
    ///
    /// We inspect the `refreshType` array and dispatch the appropriate service
    /// refresh for each value. This keeps every device in sync without requiring
    /// the user to pull-to-refresh.
    ///
    /// Supported refresh types:
    ///   "notifications" — unread count + full notification list
    ///   "groups"        — user's group list
    ///   "leaderboard"   — global leaderboard
    ///   "badges"        — earned badges
    ///   "planks"        — today's plank state
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        // Guard: only process if the user has a valid auth token.
        // A silent push can arrive during onboarding or between logout and
        // the next login. Fetching without a token produces 401 errors that
        // can leave service state (notifications, groups, etc.) empty or
        // corrupt, causing views to show empty states on first open.
        guard APIClient.shared.isAuthenticated else {
            completionHandler(.noData)
            return
        }

        // Extract the typed refresh list. Fall back to ["notifications"] for
        // pushes sent before the typed payload was introduced.
        let refreshTypes = (userInfo["refreshType"] as? [String]) ?? ["notifications"]

        Task {
            for type in refreshTypes {
                switch type {
                case "notifications":
                    await InAppNotificationService.shared.fetchUnreadCount()
                    try? await InAppNotificationService.shared.fetchNotifications()
                case "groups":
                    try? await GroupService.shared.fetchMyGroups()
                    try? await GroupService.shared.fetchDiscoverGroups()
                case "leaderboard":
                    try? await LeaderboardService.shared.fetchGlobalLeaderboardBoth()
                case "badges":
                    try? await BadgeService.shared.fetchBadges()
                case "planks":
                    try? await PlankService.shared.fetchPlanks(refresh: true)
                default:
                    break
                }
            }
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
    
    /// Unregisters the current device token from the backend on logout.
    /// Best-effort — errors are silently ignored so logout always completes.
    func unregisterToken() async {
        guard let token = registeredToken else { return }
        do {
            struct UnregisterBody: Encodable { let deviceToken: String }
            let _: EmptyResponse = try await APIClient.shared.post(
                "/devices/unregister",
                body: UnregisterBody(deviceToken: token)
            )
            registeredToken = nil
            #if DEBUG
            print("[DeviceRegistration] Token unregistered successfully")
            #endif
        } catch {
            // Non-fatal — stale token will be cleaned up by APNs 410 response
            // on the next push attempt.
            #if DEBUG
            print("[DeviceRegistration] Failed to unregister token: \(error.localizedDescription)")
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
        notificationService.clearData()
        
        #if DEBUG
        print("[PlankChallengeApp] Cleared all service data on logout")
        #endif
    }
}
