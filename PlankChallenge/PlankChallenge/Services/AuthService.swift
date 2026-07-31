import Foundation
import AuthenticationServices
import Observation
import GoogleSignIn
import UIKit

/// Service responsible for managing authentication state and operations
///
/// This service handles:
/// - Sign in with Apple
/// - Email/password authentication
/// - Session restoration on app launch
/// - Token management via APIClient
/// - Sign out
///
/// Usage:
/// ```swift
/// @Environment(AuthService.self) private var authService
///
/// if authService.isAuthenticated {
///     // Show main content
/// }
/// ```
@Observable
@MainActor
final class AuthService: AuthServiceProtocol {
    
    // MARK: - Singleton
    
    static let shared = AuthService()
    
    // MARK: - Auth State
    
    /// Represents the current authentication state
    enum AuthState: Equatable {
        /// Initial state, checking for existing session
        case unknown
        /// No valid session, user needs to sign in
        case unauthenticated
        /// User is authenticated with their profile loaded
        case authenticated(AuthUser)
        
        static func == (lhs: AuthState, rhs: AuthState) -> Bool {
            switch (lhs, rhs) {
            case (.unknown, .unknown):
                return true
            case (.unauthenticated, .unauthenticated):
                return true
            case (.authenticated(let lhsUser), .authenticated(let rhsUser)):
                return lhsUser.id == rhsUser.id
            default:
                return false
            }
        }
    }
    
    // MARK: - Published State
    
    /// Current authentication state
    private(set) var state: AuthState = .unknown
    
    /// Whether an authentication operation is in progress
    private(set) var isLoading = false
    
    /// Current error, if any
    private(set) var error: AuthError?
    
    // MARK: - Computed Properties
    
    /// Whether the user is currently authenticated
    var isAuthenticated: Bool {
        if case .authenticated = state { return true }
        return false
    }
    
    /// The current authenticated user, if any
    var currentUser: AuthUser? {
        if case .authenticated(let user) = state {
            return user
        }
        return nil
    }
    
    /// Whether the current user needs to complete onboarding.
    ///
    /// Relies on the device-local `hasCompletedOnboarding` flag in UserDefaults.
    /// Sign-up flows reset this flag to `false` so new accounts always see onboarding,
    /// even on a device where a previous account already completed it.
    var needsOnboarding: Bool {
        guard case .authenticated = state else { return false }
        let hasCompleted = UserDefaults.standard.bool(forKey: AppConfig.UserDefaultsKeys.hasCompletedOnboarding)
        return !hasCompleted
    }
    
    /// User ID of the current user
    var currentUserId: String? {
        currentUser?.id
    }
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Session Restoration
    
    /// Attempts to restore a previous session from stored tokens on app launch.
    ///
    /// Strategy:
    /// - If no tokens in Keychain → show sign-in screen
    /// - If tokens exist, fetch /users/me to get full profile → stay signed in
    /// - If /users/me returns 401 → token is definitively invalid → clear & show sign-in
    /// - If /users/me fails for ANY other reason (network error, timeout, server error)
    ///   → stay signed in using a minimal user decoded from the JWT payload
    ///   → full profile will load once the network recovers
    func restoreSession() async {
        // Load tokens from Keychain into APIClient's in-memory store
        await APIClient.shared.loadTokensFromKeychain()
        
        // No tokens stored — user has never signed in or explicitly signed out
        guard await APIClient.shared.isAuthenticated else {
            state = .unauthenticated
            return
        }
        
        // Tokens exist — try to validate them and fetch the full profile
        do {
            let response: UserMeResponse = try await APIClient.shared.get("/users/me")
            state = .authenticated(AuthUser(
                id: response.user.id,
                email: response.user.email,
                displayName: response.user.displayName ?? "",
                emailVerified: response.user.emailVerified,
                createdAt: response.user.createdAt
            ))
        } catch let apiError as APIClientError {
            switch apiError {
            case .unauthorized:
                // Server confirmed the token is invalid — sign the user out
                await APIClient.shared.clearTokens()
                state = .unauthenticated
                
            default:
                // Network failure, timeout, server error etc.
                // The token may be perfectly valid — don't punish the user.
                // Restore a minimal session from the JWT claims so they land
                // in the app. Services will reload their data once the network recovers.
                if let minimalUser = decodeUserFromStoredToken() {
                    state = .authenticated(minimalUser)
                } else {
                    // Can't decode token at all — clear and show sign-in
                    await APIClient.shared.clearTokens()
                    state = .unauthenticated
                }
            }
        } catch {
            // Any other unexpected error — same logic as network failure above
            if let minimalUser = decodeUserFromStoredToken() {
                state = .authenticated(minimalUser)
            } else {
                await APIClient.shared.clearTokens()
                state = .unauthenticated
            }
        }
    }
    
    /// Decodes a minimal AuthUser from the stored access token JWT payload.
    /// This allows session restoration without a network call when the server
    /// is unreachable. Returns nil if the token is missing or malformed.
    private func decodeUserFromStoredToken() -> AuthUser? {
        guard let token = KeychainService.shared.getAccessToken() else { return nil }
        
        // JWT format: header.payload.signature — we only need the payload
        let parts = token.split(separator: ".")
        guard parts.count == 3 else { return nil }
        
        // Base64URL decode the payload
        var base64 = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        // Pad to a multiple of 4
        while base64.count % 4 != 0 { base64 += "=" }
        
        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sub = json["sub"] as? String else { return nil }
        
        let email = json["email"] as? String ?? ""
        // JWT doesn't store displayName — use email prefix as fallback
        // until /users/me loads successfully
        let displayName = String(email.split(separator: "@").first ?? "User")
        
        return AuthUser(
            id: sub,
            email: email,
            displayName: displayName,
            emailVerified: true,
            createdAt: nil
        )
    }
    
    // MARK: - Sign in with Apple
    
    /// Handles Sign in with Apple credential
    /// - Parameter credential: The Apple ID credential from ASAuthorizationController
    func signInWithApple(credential: ASAuthorizationAppleIDCredential) async throws {
        isLoading = true
        error = nil
        defer { isLoading = false }
        
        // Extract identity token
        guard let identityTokenData = credential.identityToken,
              let identityToken = String(data: identityTokenData, encoding: .utf8) else {
            throw AuthError.invalidCredential("Missing identity token")
        }
        
        // Extract authorization code
        guard let authCodeData = credential.authorizationCode,
              let authorizationCode = String(data: authCodeData, encoding: .utf8) else {
            throw AuthError.invalidCredential("Missing authorization code")
        }
        
        // Build user info if provided (only on first sign-in)
        var userInfo: AppleAuthRequest.AppleUserInfo?
        if let email = credential.email {
            let name: AppleAuthRequest.AppleUserInfo.AppleName?
            if let fullName = credential.fullName,
               (fullName.givenName != nil || fullName.familyName != nil) {
                name = AppleAuthRequest.AppleUserInfo.AppleName(
                    firstName: fullName.givenName,
                    lastName: fullName.familyName
                )
            } else {
                name = nil
            }
            userInfo = AppleAuthRequest.AppleUserInfo(email: email, name: name)
        }
        
        // Build request
        let request = AppleAuthRequest(
            identityToken: identityToken,
            authorizationCode: authorizationCode,
            user: userInfo
        )
        
        // Call API
        do {
            let response: AuthResponse = try await APIClient.shared.post(
                "/auth/apple",
                body: request,
                requiresAuth: false
            )
            
            // Store tokens
            await APIClient.shared.setTokens(
                access: response.accessToken,
                refresh: response.refreshToken,
                expiresIn: response.expiresIn
            )
            
            resetOnboardingIfNewAccount(response.user)
            state = .authenticated(response.user)
            
        } catch let apiError as APIClientError {
            self.error = AuthError.fromAPIError(apiError)
            throw self.error!
        } catch {
            self.error = AuthError.unknown(error.localizedDescription)
            throw self.error!
        }
    }
    
    // MARK: - Sign in with Google
    
    /// Handles Sign in with Google using the GoogleSignIn SDK.
    ///
    /// This method presents the Google OAuth consent screen, retrieves the ID token,
    /// and exchanges it with the backend at `POST /auth/google`.
    ///
    /// - Parameter viewController: The presenting view controller (obtain via UIApplication window).
    /// - Throws: `AuthError.notConfigured` if the Google client ID hasn't been set in AppConfig.
    func signInWithGoogle(presenting viewController: UIViewController) async throws {
        guard AppConfig.Google.isConfigured else {
            throw AuthError.notConfigured("Google Sign-In is not configured. Set AppConfig.Google.clientId.")
        }
        
        error = nil
        
        // Configure the GIDSignIn client
        let config = GIDConfiguration(clientID: AppConfig.Google.clientId)
        GIDSignIn.sharedInstance.configuration = config
        
        // Step 1: Present the Google OAuth sheet and wait for it to complete.
        // IMPORTANT: We do NOT set isLoading = true here — doing so triggers a SwiftUI
        // re-render that adds an overlay, which can intercept touches and prevent the
        // Google sheet from receiving the dismiss/callback signal correctly.
        print("[GoogleAuth] Step 1 — presenting OAuth sheet")
        let result: GIDSignInResult
        do {
            result = try await withCheckedThrowingContinuation { continuation in
                print("[GoogleAuth] Step 1a — calling GIDSignIn.signIn")
                GIDSignIn.sharedInstance.signIn(withPresenting: viewController) { signInResult, error in
                    print("[GoogleAuth] Step 1b — GIDSignIn callback fired")
                    if let error = error {
                        print("[GoogleAuth] Step 1b — error: \(error.localizedDescription) domain=\((error as NSError).domain) code=\((error as NSError).code)")
                        continuation.resume(throwing: error)
                    } else if let signInResult = signInResult {
                        print("[GoogleAuth] Step 1b — got result, idToken present: \(signInResult.user.idToken != nil)")
                        continuation.resume(returning: signInResult)
                    } else {
                        print("[GoogleAuth] Step 1b — no result and no error")
                        continuation.resume(throwing: AuthError.invalidCredential("Google Sign-In returned no result"))
                    }
                }
            }
        } catch {
            let nsError = error as NSError
            print("[GoogleAuth] Step 1 catch — domain=\(nsError.domain) code=\(nsError.code) msg=\(nsError.localizedDescription)")
            if nsError.domain == "com.google.GIDSignIn" && nsError.code == -5 {
                throw AuthError.cancelled
            }
            let authErr = AuthError.unknown(error.localizedDescription)
            self.error = authErr
            throw authErr
        }
        
        // Step 2: Google sheet has dismissed — NOW show the loading indicator
        // while we exchange the token with our backend.
        print("[GoogleAuth] Step 2 — OAuth complete, starting backend exchange")
        isLoading = true
        defer { isLoading = false }
        
        // Extract the ID token
        guard let idToken = result.user.idToken?.tokenString else {
            print("[GoogleAuth] Step 2 — ERROR: no idToken in result")
            throw AuthError.invalidCredential("Google sign-in did not return an ID token")
        }
        print("[GoogleAuth] Step 2 — idToken extracted (\(idToken.prefix(20))...)")
        
        // Exchange with our backend
        do {
            let request = GoogleAuthRequest(idToken: idToken)
            print("[GoogleAuth] Step 3 — posting to /auth/google")
            
            let response: AuthResponse = try await APIClient.shared.post(
                "/auth/google",
                body: request,
                requiresAuth: false
            )
            
            print("[GoogleAuth] Step 3 — backend success, userId: \(response.user.id)")
            await APIClient.shared.setTokens(
                access: response.accessToken,
                refresh: response.refreshToken,
                expiresIn: response.expiresIn
            )
            
            resetOnboardingIfNewAccount(response.user)
            state = .authenticated(response.user)
            print("[GoogleAuth] Step 4 — state set to authenticated")
            
        } catch let apiError as APIClientError {
            print("[GoogleAuth] Step 3 — APIClientError: \(apiError)")
            self.error = AuthError.fromAPIError(apiError)
            throw self.error!
        } catch let authError as AuthError {
            print("[GoogleAuth] Step 3 — AuthError: \(authError)")
            self.error = authError
            throw authError
        } catch {
            print("[GoogleAuth] Step 3 — unknown error: \(error)")
            self.error = AuthError.unknown(error.localizedDescription)
            throw self.error!
        }
    }
    
    // MARK: - Email Authentication
    
    /// Checks whether an email address has an existing account and which
    /// sign-in methods are available (email/password, Apple, Google).
    func checkEmail(_ email: String) async throws -> CheckEmailResponse {
        let request = CheckEmailRequest(email: email)
        let response: CheckEmailResponse = try await APIClient.shared.post(
            "/auth/check-email",
            body: request,
            requiresAuth: false
        )
        return response
    }
    
    /// Signs in with email and password
    /// - Parameters:
    ///   - email: User's email address
    ///   - password: User's password
    func signInWithEmail(email: String, password: String) async throws {
        isLoading = true
        error = nil
        defer { isLoading = false }
        
        let request = EmailLoginRequest(email: email, password: password)
        
        do {
            let response: AuthResponse = try await APIClient.shared.post(
                "/auth/login",
                body: request,
                requiresAuth: false
            )
            
            // Store tokens
            await APIClient.shared.setTokens(
                access: response.accessToken,
                refresh: response.refreshToken,
                expiresIn: response.expiresIn
            )
            
            // Update state
            state = .authenticated(response.user)
            
        } catch let apiError as APIClientError {
            self.error = AuthError.fromAPIError(apiError)
            throw self.error!
        } catch {
            self.error = AuthError.unknown(error.localizedDescription)
            throw self.error!
        }
    }
    
    /// Resets the onboarding flag so new accounts see the onboarding flow,
    /// even on a device where a previous account already completed it.
    private func resetOnboardingForNewAccount() {
        UserDefaults.standard.set(false, forKey: AppConfig.UserDefaultsKeys.hasCompletedOnboarding)
    }
    
    /// Resets onboarding if the account was just created (within 10 seconds).
    /// Used for Apple/Google sign-in where the same endpoint handles both
    /// new account creation and existing account login.
    private func resetOnboardingIfNewAccount(_ user: AuthUser) {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let createdAtString = user.createdAt,
           let createdAt = formatter.date(from: createdAtString),
           Date().timeIntervalSince(createdAt) < 10 {
            resetOnboardingForNewAccount()
        }
    }
    
    /// Creates a new account with email and password
    /// - Parameters:
    ///   - email: User's email address
    ///   - password: User's password (minimum 8 characters)
    ///   - displayName: User's display name
    func signUpWithEmail(email: String, password: String, displayName: String) async throws {
        isLoading = true
        error = nil
        defer { isLoading = false }
        
        let request = EmailRegisterRequest(
            email: email,
            password: password,
            displayName: displayName
        )
        
        do {
            let response: AuthResponse = try await APIClient.shared.post(
                "/auth/register",
                body: request,
                requiresAuth: false
            )
            
            // Store tokens
            await APIClient.shared.setTokens(
                access: response.accessToken,
                refresh: response.refreshToken,
                expiresIn: response.expiresIn
            )
            
            // New account — ensure onboarding runs even if a previous
            // account on this device already completed it.
            resetOnboardingForNewAccount()
            
            // Update state
            state = .authenticated(response.user)
            
        } catch let apiError as APIClientError {
            self.error = AuthError.fromAPIError(apiError)
            throw self.error!
        } catch {
            self.error = AuthError.unknown(error.localizedDescription)
            throw self.error!
        }
    }
    
    // MARK: - Sign Out
    
    /// Signs out the current user
    /// Clears local tokens and notifies the backend
    func signOut() async {
        isLoading = true
        defer { isLoading = false }
        
        // Unregister APNs device token before clearing auth — the API call
        // needs a valid token to authenticate. Stale tokens cause silent pushes
        // to be delivered to the wrong user's device.
        await DeviceRegistrationService.shared.unregisterToken()
        
        // Try to notify backend (non-critical - we'll clear local state regardless)
        if let refreshToken = await APIClient.shared.currentRefreshToken {
            do {
                let _: EmptyResponse = try await APIClient.shared.post(
                    "/auth/logout",
                    body: LogoutRequest(refreshToken: refreshToken)
                )
            } catch {
                // Ignore logout errors - we'll clear local state anyway
                #if DEBUG
                print("Logout API call failed: \(error)")
                #endif
            }
        }
        
        // Clear tokens
        await APIClient.shared.clearTokens()
        
        // Update state
        state = .unauthenticated
        error = nil
    }
    
    // MARK: - Account Deletion
    
    /// Permanently deletes the user's account
    /// This is irreversible and removes all user data
    func deleteAccount() async throws {
        isLoading = true
        error = nil
        defer { isLoading = false }
        
        do {
            let _: EmptyResponse = try await APIClient.shared.delete("/auth/account")
            
            // Clear tokens
            await APIClient.shared.clearTokens()
            
            // Update state
            state = .unauthenticated
            
        } catch let apiError as APIClientError {
            self.error = AuthError.fromAPIError(apiError)
            throw self.error!
        } catch {
            self.error = AuthError.unknown(error.localizedDescription)
            throw self.error!
        }
    }
    
    // MARK: - Error Handling
    
    /// Clears the current error
    func clearError() {
        error = nil
    }
}

// MARK: - Auth Errors

/// Errors that can occur during authentication
enum AuthError: LocalizedError, Equatable {
    case invalidCredential(String)
    case invalidEmailOrPassword
    case emailAlreadyExists
    case networkError(String)
    case serverError(String)
    case sessionExpired
    case unknown(String)
    /// The sign-in flow was cancelled by the user (no error to show).
    case cancelled
    /// A third-party sign-in provider is not yet configured.
    case notConfigured(String)
    /// The endpoint is temporarily rate limited.
    case rateLimited(retryAfter: Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidCredential(let message):
            return message
        case .invalidEmailOrPassword:
            return "Invalid email or password. Please try again."
        case .emailAlreadyExists:
            return "An account with this email already exists."
        case .networkError(let message):
            return "Network error: \(message)"
        case .serverError(let message):
            return message
        case .sessionExpired:
            return "Your session has expired. Please sign in again."
        case .unknown(let message):
            return message
        case .cancelled:
            return nil
        case .notConfigured(let message):
            return message
        case .rateLimited(let retryAfter):
            return "We're unable to complete this right now. Please try again in \(Self.formatRetryAfter(retryAfter))."
        }
    }
    
    /// Formats a retryAfter value in seconds into a human-readable string.
    /// e.g. 3600 → "1 hour", 300 → "5 minutes", 90 → "1 minute", 30 → "30 seconds"
    private static func formatRetryAfter(_ seconds: Int) -> String {
        if seconds >= 3600 {
            let hours = seconds / 3600
            return hours == 1 ? "1 hour" : "\(hours) hours"
        } else if seconds >= 60 {
            let minutes = seconds / 60
            return minutes == 1 ? "1 minute" : "\(minutes) minutes"
        } else {
            return seconds == 1 ? "1 second" : "\(seconds) seconds"
        }
    }
    
    /// Creates an AuthError from an APIClientError
    static func fromAPIError(_ error: APIClientError) -> AuthError {
        switch error {
        case .unauthorized:
            return .sessionExpired
            
        case .networkError(let underlyingError):
            return .networkError(underlyingError.localizedDescription)
            
        case .apiError(let apiError):
            switch apiError.error.code {
            case "AUTH_INVALID":
                return .invalidEmailOrPassword
            case "AUTH_REQUIRED":
                return .invalidCredential("Sign in failed. Please try again.")
            case "CONFLICT":
                return .emailAlreadyExists
            case "RATE_LIMITED":
                let retryAfter = apiError.error.retryAfter ?? 3600
                return .rateLimited(retryAfter: retryAfter)
            default:
                return .serverError(apiError.error.message)
            }
            
        default:
            return .unknown(error.localizedDescription ?? "An unknown error occurred")
        }
    }
}


