//
//  AppConfig.swift
//  PlankChallenge
//
//  Created by Leo Bacevicius on 08/03/2026.
//

import Foundation

/// Application configuration constants
/// All values are compile-time constants or derived from Bundle info,
/// making them safe to access from any context.
enum AppConfig: Sendable {
    
    // MARK: - Environment
    
    /// Current app environment
    enum Environment: String {
        case development
        case staging
        case production
        
        /// API base URL for each environment
        /// NOTE: After deploying with `wrangler deploy`, update production URL
        /// Format: https://<worker-name>.<account-subdomain>.workers.dev
        /// Or use a custom domain if configured
        var apiBaseURL: String {
            switch self {
            case .development:
                // Points to the deployed worker so physical device testing works.
                // Switch back to "http://localhost:8787" when running wrangler dev locally.
                return "https://plank-challenge-api.petras-leonardas.workers.dev"
            case .staging:
                // Staging environment - update after setting up staging worker
                return "https://staging-plank-challenge-api.workers.dev"
            case .production:
                return "https://plank-challenge-api.petras-leonardas.workers.dev"
            }
        }
        
        /// Whether debug features are enabled
        var isDebug: Bool {
            switch self {
            case .development, .staging:
                return true
            case .production:
                return false
            }
        }
    }
    
    /// Current environment - change this for different builds
    #if DEBUG
    static let currentEnvironment: Environment = .development
    #else
    static let currentEnvironment: Environment = .production
    #endif
    
    // MARK: - API Configuration
    
    enum API: Sendable {
        /// Base URL for API requests
        static nonisolated var baseURL: String {
            currentEnvironment.apiBaseURL
        }
        
        /// Request timeout interval in seconds
        static nonisolated let timeoutInterval: TimeInterval = 30
        
        /// Maximum number of retry attempts for failed requests
        static nonisolated let maxRetries: Int = 3
        
        /// Delay between retry attempts (in seconds)
        static nonisolated let retryDelay: TimeInterval = 1.0
    }
    
    // MARK: - Feature Flags
    
    enum Features {
        /// Whether to use mock data instead of real API calls
        /// Set to false to enable backend integration
        static var useMockData: Bool {
            #if DEBUG
            // In debug builds, can be toggled for testing
            // Set to false to test real backend
            return false
            #else
            return false
            #endif
        }
        
        /// Whether backend sync is enabled
        static var syncEnabled: Bool {
            !useMockData
        }
        
        /// Whether analytics are enabled
        static var analyticsEnabled: Bool {
            currentEnvironment == .production
        }
        
        /// Whether to show debug UI elements
        static var showDebugUI: Bool {
            currentEnvironment.isDebug
        }
    }
    
    // MARK: - App Information
    
    enum AppInfo: Sendable {
        static nonisolated let appName = "Plank Challenge"
        
        static nonisolated var appVersion: String {
            Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        }
        
        static nonisolated var buildNumber: String {
            Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        }
        
        static nonisolated var fullVersion: String {
            "\(appVersion) (\(buildNumber))"
        }
        
        /// Bundle identifier
        static nonisolated var bundleIdentifier: String {
            Bundle.main.bundleIdentifier ?? "com.leo.PlankChallenge"
        }
    }
    
    // MARK: - Bundle ID
    
    static nonisolated var appBundleId: String {
        AppInfo.bundleIdentifier
    }
    
    // MARK: - Google Sign-In
    
    enum Google: Sendable {
        /// iOS OAuth Client ID from Google Cloud Console.
        ///
        /// How to find this:
        ///   1. Go to https://console.cloud.google.com
        ///   2. Select your "Plank Challenge" project
        ///   3. Navigate to APIs & Services → Credentials
        ///   4. Find the iOS OAuth 2.0 Client ID (type: iOS)
        ///   5. Copy the "Client ID" value (ends in .apps.googleusercontent.com)
        ///
        /// - Important: Also add the reversed client ID as a URL scheme in Xcode:
        ///   Target → Info → URL Types → add a new entry with the reversed client ID
        ///   (e.g. com.googleusercontent.apps.XXXXXXXXXX-xxxx)
        ///
        /// - Note: The same client ID must match what is set as GOOGLE_CLIENT_ID
        ///   in Cloudflare Workers secrets (already configured).
        static nonisolated let clientId = "880495806560-i4bangtnrragntvnqjese4s6kf920s7i.apps.googleusercontent.com"
        
        /// Reversed client ID — used as the URL scheme for OAuth redirect.
        /// This is the clientId with dot-separated components reversed.
        /// e.g. "com.googleusercontent.apps.XXXXXXXXXX-xxxx"
        static nonisolated var reversedClientId: String {
            clientId
                .split(separator: ".")
                .reversed()
                .joined(separator: ".")
        }
        
        /// Whether Google Sign-In is properly configured (client ID has been set).
        static nonisolated var isConfigured: Bool {
            !clientId.hasPrefix("YOUR_GOOGLE_CLIENT_ID")
        }
    }
    
    // MARK: - Keychain Keys
    
    enum Keychain: Sendable {
        static nonisolated let accessTokenKey = "com.leo.PlankChallenge.accessToken"
        static nonisolated let refreshTokenKey = "com.leo.PlankChallenge.refreshToken"
        static nonisolated let tokenExpirationKey = "com.leo.PlankChallenge.tokenExpiration"
        static nonisolated let userIdKey = "com.leo.PlankChallenge.userId"
    }
    
    // MARK: - User Defaults Keys
    
    enum UserDefaultsKeys: Sendable {
        static nonisolated let lastSyncTimestamp = "lastSyncTimestamp"
        static nonisolated let hasCompletedOnboarding = "hasCompletedOnboarding"
        static nonisolated let preferredPlankType = "preferredPlankType"
        static nonisolated let notificationsEnabled = "notificationsEnabled"
        static nonisolated let dailyReminderTime = "dailyReminderTime"
    }
}
