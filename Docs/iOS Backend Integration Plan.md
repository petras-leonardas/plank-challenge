# iOS App Backend Integration Plan

*Connecting the PlankChallenge iOS app to the Cloudflare Workers backend*

**Version:** 1.0  
**Created:** March 15, 2026  
**Status:** Ready for Implementation

---

## Executive Summary

The PlankChallenge iOS app has a complete UI but currently uses `MockDataService` with hardcoded fake data. The backend (Cloudflare Workers) is fully implemented and production-ready. This plan details the work needed to connect them.

### Current State

| Component | Status |
|-----------|--------|
| Backend API | ✅ Fully implemented (65 endpoints) |
| iOS UI | ✅ Fully implemented |
| iOS API Client | ❌ Not implemented |
| iOS Auth Flow | ❌ Not implemented |
| iOS Data Sync | ❌ Uses mock data |

### Estimated Effort

| Phase | Effort | Priority |
|-------|--------|----------|
| Phase 1: Project Setup | 2-4 hours | Critical |
| Phase 2: Networking Layer | 1 day | Critical |
| Phase 3: Authentication | 1-2 days | Critical |
| Phase 4: Core Features | 2-3 days | Critical |
| Phase 5: Social Features | 1-2 days | High |
| Phase 6: Final Polish | 1 day | High |
| **Total** | **7-10 days** | |

---

## Phase 1: Project Configuration (2-4 hours)

### 1.1 Fix Deployment Target

**File:** `PlankChallenge.xcodeproj/project.pbxproj`

**Current:** `IPHONEOS_DEPLOYMENT_TARGET = 26.2` (invalid)  
**Change to:** `IPHONEOS_DEPLOYMENT_TARGET = 17.0`

**Why iOS 17.0:**
- SwiftData requires iOS 17+
- Observation framework requires iOS 17+
- Covers ~75% of active iOS devices
- Access to latest APIs

### 1.2 Add App Icon

**Location:** `Assets.xcassets/AppIcon.appiconset/`

**Current:** Folder exists but no images

**Required:**
- 1024x1024 PNG icon (required for App Store)
- Update `Contents.json` with filename

### 1.3 Add Entitlements File

**Create:** `PlankChallenge/PlankChallenge.entitlements`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.applesignin</key>
    <array>
        <string>Default</string>
    </array>
    <key>aps-environment</key>
    <string>development</string>
</dict>
</plist>
```

**Xcode Steps:**
1. Select project → Signing & Capabilities
2. Add "Sign in with Apple" capability
3. Add "Push Notifications" capability

### 1.4 Add Privacy Manifest

**Create:** `PlankChallenge/PrivacyInfo.xcprivacy`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSPrivacyTracking</key>
    <false/>
    <key>NSPrivacyCollectedDataTypes</key>
    <array/>
    <key>NSPrivacyTrackingDomains</key>
    <array/>
    <key>NSPrivacyAccessedAPITypes</key>
    <array>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>CA92.1</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
```

### 1.5 Update AppConfig.swift

**Add API configuration:**

```swift
enum AppConfig {
    enum Environment {
        case development
        case staging
        case production
        
        var apiBaseURL: String {
            switch self {
            case .development:
                return "http://localhost:8787"
            case .staging:
                return "https://staging-api.plankchallenge.app"
            case .production:
                return "https://api.plankchallenge.app"
            }
        }
    }
    
    static let currentEnvironment: Environment = .development
    
    enum API {
        static var baseURL: String { currentEnvironment.apiBaseURL }
        static let timeoutInterval: TimeInterval = 30
        static let maxRetries: Int = 3
    }
    
    enum Features {
        static var useMockData: Bool {
            #if DEBUG
            return false  // Set to true for UI development without backend
            #else
            return false
            #endif
        }
        static let syncEnabled: Bool = true
        static let analyticsEnabled: Bool = true
    }
}
```

---

## Phase 2: Networking Layer (1 day)

### 2.1 Create API Models

**Create:** `PlankChallenge/Services/API/Models/`

These models match the backend's `types/api.ts`:

```swift
// APIModels.swift

// MARK: - Response Wrappers
struct APIResponse<T: Decodable>: Decodable {
    let success: Bool
    let data: T
    let meta: ResponseMeta
}

struct APIError: Decodable, Error {
    let success: Bool
    let error: ErrorDetail
    let meta: ResponseMeta
    
    struct ErrorDetail: Decodable {
        let code: String
        let message: String
        let details: [String: AnyCodable]?
    }
}

struct ResponseMeta: Decodable {
    let timestamp: String
    let requestId: String
}

// MARK: - Auth Models
struct AuthResponse: Decodable {
    let user: APIUser
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
}

struct TokenRefreshResponse: Decodable {
    let accessToken: String
    let expiresIn: Int
}

// MARK: - User Models
struct APIUser: Decodable {
    let id: String
    let email: String
    let emailVerified: Bool
    let displayName: String
    let username: String?
    let location: String?
    let bio: String?
    let profileImageUrl: String?
    let preferredPlankType: String
    let currentStreak: Int
    let longestStreak: Int
    let freezeTokens: Int
    let lastPlankDate: String?
    let totalPlanks: Int
    let totalPlankSeconds: Double
    let longestPlankSeconds: Double
    let followerCount: Int
    let followingCount: Int
    let timezone: String
    let createdAt: String
    let updatedAt: String
}

struct APIPublicUser: Decodable {
    let id: String
    let displayName: String
    let username: String?
    let profileImageUrl: String?
    let currentStreak: Int
    let longestStreak: Int
    let totalPlanks: Int
    let longestPlankSeconds: Double
    let followerCount: Int
    let followingCount: Int
    let isFollowing: Bool?
}

// MARK: - Plank Models
struct APIPlankSession: Codable {
    let id: String?
    let clientId: String
    let userId: String?
    let durationSeconds: Double
    let plankType: String
    let inputMethod: String
    let performedAt: String
    let timezone: String
    let createdAt: String?
    let updatedAt: String?
    let deletedAt: String?
}

// MARK: - Pagination
struct PaginatedResponse<T: Decodable>: Decodable {
    let items: T
    let pagination: PaginationMeta
}

struct PaginationMeta: Decodable {
    let total: Int
    let limit: Int
    let offset: Int
    let hasMore: Bool
}
```

### 2.2 Create APIClient

**Create:** `PlankChallenge/Services/API/APIClient.swift`

```swift
import Foundation

actor APIClient {
    static let shared = APIClient()
    
    private let baseURL: String
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    
    private var accessToken: String?
    private var refreshToken: String?
    
    private init() {
        self.baseURL = AppConfig.API.baseURL
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = AppConfig.API.timeoutInterval
        self.session = URLSession(configuration: config)
        
        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        self.encoder = JSONEncoder()
        self.encoder.keyEncodingStrategy = .convertToSnakeCase
    }
    
    // MARK: - Token Management
    
    func setTokens(access: String, refresh: String) {
        self.accessToken = access
        self.refreshToken = refresh
        // Also save to Keychain
        KeychainService.shared.saveTokens(access: access, refresh: refresh)
    }
    
    func clearTokens() {
        self.accessToken = nil
        self.refreshToken = nil
        KeychainService.shared.clearTokens()
    }
    
    func loadTokensFromKeychain() {
        if let tokens = KeychainService.shared.loadTokens() {
            self.accessToken = tokens.access
            self.refreshToken = tokens.refresh
        }
    }
    
    var isAuthenticated: Bool {
        accessToken != nil
    }
    
    // MARK: - Request Building
    
    private func buildRequest(
        endpoint: String,
        method: HTTPMethod,
        body: Encodable? = nil,
        requiresAuth: Bool = true
    ) throws -> URLRequest {
        guard let url = URL(string: baseURL + endpoint) else {
            throw APIClientError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if requiresAuth, let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        if let body = body {
            request.httpBody = try encoder.encode(body)
        }
        
        return request
    }
    
    // MARK: - Request Execution
    
    func request<T: Decodable>(
        endpoint: String,
        method: HTTPMethod = .get,
        body: Encodable? = nil,
        requiresAuth: Bool = true
    ) async throws -> T {
        let request = try buildRequest(
            endpoint: endpoint,
            method: method,
            body: body,
            requiresAuth: requiresAuth
        )
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIClientError.invalidResponse
        }
        
        // Handle 401 - try to refresh token
        if httpResponse.statusCode == 401 && requiresAuth {
            if try await refreshAccessToken() {
                // Retry with new token
                return try await self.request(
                    endpoint: endpoint,
                    method: method,
                    body: body,
                    requiresAuth: requiresAuth
                )
            } else {
                throw APIClientError.unauthorized
            }
        }
        
        // Handle error responses
        if httpResponse.statusCode >= 400 {
            if let apiError = try? decoder.decode(APIError.self, from: data) {
                throw apiError
            }
            throw APIClientError.httpError(statusCode: httpResponse.statusCode)
        }
        
        // Decode success response
        let apiResponse = try decoder.decode(APIResponse<T>.self, from: data)
        return apiResponse.data
    }
    
    // MARK: - Token Refresh
    
    private func refreshAccessToken() async throws -> Bool {
        guard let refreshToken = refreshToken else {
            return false
        }
        
        struct RefreshBody: Encodable {
            let refreshToken: String
        }
        
        let request = try buildRequest(
            endpoint: "/auth/refresh",
            method: .post,
            body: RefreshBody(refreshToken: refreshToken),
            requiresAuth: false
        )
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            clearTokens()
            return false
        }
        
        let tokenResponse = try decoder.decode(
            APIResponse<TokenRefreshResponse>.self,
            from: data
        )
        
        self.accessToken = tokenResponse.data.accessToken
        KeychainService.shared.updateAccessToken(tokenResponse.data.accessToken)
        
        return true
    }
}

// MARK: - Supporting Types

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

enum APIClientError: Error {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case unauthorized
    case decodingError(Error)
}
```

### 2.3 Create KeychainService

**Create:** `PlankChallenge/Services/KeychainService.swift`

```swift
import Foundation
import Security

class KeychainService {
    static let shared = KeychainService()
    
    private let accessTokenKey = "com.leo.PlankChallenge.accessToken"
    private let refreshTokenKey = "com.leo.PlankChallenge.refreshToken"
    
    func saveTokens(access: String, refresh: String) {
        save(key: accessTokenKey, value: access)
        save(key: refreshTokenKey, value: refresh)
    }
    
    func loadTokens() -> (access: String, refresh: String)? {
        guard let access = load(key: accessTokenKey),
              let refresh = load(key: refreshTokenKey) else {
            return nil
        }
        return (access, refresh)
    }
    
    func updateAccessToken(_ token: String) {
        save(key: accessTokenKey, value: token)
    }
    
    func clearTokens() {
        delete(key: accessTokenKey)
        delete(key: refreshTokenKey)
    }
    
    // MARK: - Private Keychain Operations
    
    private func save(key: String, value: String) {
        let data = value.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
    
    private func load(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return string
    }
    
    private func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
```

---

## Phase 3: Authentication (1-2 days)

### 3.1 Create AuthService

**Create:** `PlankChallenge/Services/AuthService.swift`

```swift
import Foundation
import AuthenticationServices
import Observation

@Observable
@MainActor
class AuthService {
    static let shared = AuthService()
    
    enum AuthState {
        case unknown
        case unauthenticated
        case authenticated(APIUser)
    }
    
    private(set) var state: AuthState = .unknown
    private(set) var isLoading = false
    private(set) var error: Error?
    
    var isAuthenticated: Bool {
        if case .authenticated = state { return true }
        return false
    }
    
    var currentUser: APIUser? {
        if case .authenticated(let user) = state { return user }
        return nil
    }
    
    private init() {}
    
    // MARK: - Session Restoration
    
    func restoreSession() async {
        await APIClient.shared.loadTokensFromKeychain()
        
        guard await APIClient.shared.isAuthenticated else {
            state = .unauthenticated
            return
        }
        
        do {
            let user: APIUser = try await APIClient.shared.request(
                endpoint: "/users/me"
            )
            state = .authenticated(user)
        } catch {
            // Token invalid or expired
            await APIClient.shared.clearTokens()
            state = .unauthenticated
        }
    }
    
    // MARK: - Sign in with Apple
    
    func signInWithApple(credential: ASAuthorizationAppleIDCredential) async throws {
        isLoading = true
        defer { isLoading = false }
        
        guard let identityToken = credential.identityToken,
              let tokenString = String(data: identityToken, encoding: .utf8) else {
            throw AuthError.invalidCredential
        }
        
        struct AppleAuthRequest: Encodable {
            let identityToken: String
            let authorizationCode: String?
            let displayName: String?
        }
        
        let displayName: String?
        if let fullName = credential.fullName {
            displayName = [fullName.givenName, fullName.familyName]
                .compactMap { $0 }
                .joined(separator: " ")
                .nilIfEmpty
        } else {
            displayName = nil
        }
        
        let authCode = credential.authorizationCode.flatMap {
            String(data: $0, encoding: .utf8)
        }
        
        let response: AuthResponse = try await APIClient.shared.request(
            endpoint: "/auth/apple",
            method: .post,
            body: AppleAuthRequest(
                identityToken: tokenString,
                authorizationCode: authCode,
                displayName: displayName
            ),
            requiresAuth: false
        )
        
        await APIClient.shared.setTokens(
            access: response.accessToken,
            refresh: response.refreshToken
        )
        
        state = .authenticated(response.user)
    }
    
    // MARK: - Email Authentication
    
    func signInWithEmail(email: String, password: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        struct LoginRequest: Encodable {
            let email: String
            let password: String
        }
        
        let response: AuthResponse = try await APIClient.shared.request(
            endpoint: "/auth/login",
            method: .post,
            body: LoginRequest(email: email, password: password),
            requiresAuth: false
        )
        
        await APIClient.shared.setTokens(
            access: response.accessToken,
            refresh: response.refreshToken
        )
        
        state = .authenticated(response.user)
    }
    
    func signUpWithEmail(email: String, password: String, displayName: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        struct RegisterRequest: Encodable {
            let email: String
            let password: String
            let displayName: String
        }
        
        let response: AuthResponse = try await APIClient.shared.request(
            endpoint: "/auth/register",
            method: .post,
            body: RegisterRequest(
                email: email,
                password: password,
                displayName: displayName
            ),
            requiresAuth: false
        )
        
        await APIClient.shared.setTokens(
            access: response.accessToken,
            refresh: response.refreshToken
        )
        
        state = .authenticated(response.user)
    }
    
    // MARK: - Sign Out
    
    func signOut() async {
        do {
            try await APIClient.shared.request(
                endpoint: "/auth/logout",
                method: .post
            ) as EmptyResponse
        } catch {
            // Ignore logout errors - clear local state anyway
        }
        
        await APIClient.shared.clearTokens()
        state = .unauthenticated
    }
}

// MARK: - Supporting Types

enum AuthError: Error {
    case invalidCredential
    case networkError
    case serverError(String)
}

struct EmptyResponse: Decodable {}

extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
```

### 3.2 Create Authentication Views

**Create:** `PlankChallenge/Views/Auth/`

#### AuthenticationView.swift
```swift
import SwiftUI
import AuthenticationServices

struct AuthenticationView: View {
    @Environment(AuthService.self) private var authService
    @State private var showEmailSignIn = false
    @State private var showEmailSignUp = false
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Logo and title
            VStack(spacing: 16) {
                Image(systemName: "figure.core.training")
                    .font(.system(size: 80))
                    .foregroundStyle(.accent)
                
                Text("Plank Challenge")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Build your core strength\none day at a time")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
            
            // Sign in buttons
            VStack(spacing: 16) {
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.email, .fullName]
                } onCompletion: { result in
                    handleAppleSignIn(result)
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 50)
                
                Button {
                    showEmailSignIn = true
                } label: {
                    HStack {
                        Image(systemName: "envelope.fill")
                        Text("Continue with Email")
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 24)
            
            // Sign up link
            HStack {
                Text("Don't have an account?")
                    .foregroundStyle(.secondary)
                Button("Sign Up") {
                    showEmailSignUp = true
                }
            }
            .font(.footnote)
            
            Spacer()
                .frame(height: 40)
        }
        .sheet(isPresented: $showEmailSignIn) {
            EmailSignInView()
        }
        .sheet(isPresented: $showEmailSignUp) {
            EmailSignUpView()
        }
    }
    
    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            if let credential = auth.credential as? ASAuthorizationAppleIDCredential {
                Task {
                    try await authService.signInWithApple(credential: credential)
                }
            }
        case .failure(let error):
            print("Apple Sign-In failed: \(error)")
        }
    }
}
```

#### EmailSignInView.swift
```swift
import SwiftUI

struct EmailSignInView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthService.self) private var authService
    
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    
                    SecureField("Password", text: $password)
                        .textContentType(.password)
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
                
                Section {
                    Button("Sign In") {
                        signIn()
                    }
                    .disabled(email.isEmpty || password.isEmpty || authService.isLoading)
                }
            }
            .navigationTitle("Sign In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    private func signIn() {
        errorMessage = nil
        Task {
            do {
                try await authService.signInWithEmail(email: email, password: password)
                dismiss()
            } catch {
                errorMessage = "Invalid email or password"
            }
        }
    }
}
```

#### EmailSignUpView.swift
```swift
import SwiftUI

struct EmailSignUpView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthService.self) private var authService
    
    @State private var displayName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Display Name", text: $displayName)
                        .textContentType(.name)
                    
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    
                    SecureField("Password", text: $password)
                        .textContentType(.newPassword)
                    
                    SecureField("Confirm Password", text: $confirmPassword)
                        .textContentType(.newPassword)
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
                
                Section {
                    Button("Create Account") {
                        signUp()
                    }
                    .disabled(!isValid || authService.isLoading)
                }
            }
            .navigationTitle("Create Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    private var isValid: Bool {
        !displayName.isEmpty &&
        !email.isEmpty &&
        password.count >= 8 &&
        password == confirmPassword
    }
    
    private func signUp() {
        errorMessage = nil
        
        guard password == confirmPassword else {
            errorMessage = "Passwords don't match"
            return
        }
        
        Task {
            do {
                try await authService.signUpWithEmail(
                    email: email,
                    password: password,
                    displayName: displayName
                )
                dismiss()
            } catch let error as APIError {
                errorMessage = error.error.message
            } catch {
                errorMessage = "Something went wrong. Please try again."
            }
        }
    }
}
```

### 3.3 Create RootView with Auth State

**Create:** `PlankChallenge/Views/RootView.swift`

```swift
import SwiftUI

struct RootView: View {
    @Environment(AuthService.self) private var authService
    @State private var isCheckingAuth = true
    
    var body: some View {
        Group {
            if isCheckingAuth {
                ProgressView()
                    .scaleEffect(1.5)
            } else {
                switch authService.state {
                case .unknown, .unauthenticated:
                    AuthenticationView()
                case .authenticated:
                    MainTabView()
                }
            }
        }
        .task {
            await authService.restoreSession()
            isCheckingAuth = false
        }
    }
}
```

### 3.4 Update PlankChallengeApp.swift

```swift
import SwiftUI
import SwiftData

@main
struct PlankChallengeApp: App {
    @State private var authService = AuthService.shared
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            // Add your SwiftData models here
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )
        
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(authService)
        }
        .modelContainer(sharedModelContainer)
    }
}
```

---

## Phase 4: Core Features (2-3 days)

### 4.1 Create PlankService

**Create:** `PlankChallenge/Services/PlankService.swift`

```swift
import Foundation
import Observation

@Observable
@MainActor
class PlankService {
    static let shared = PlankService()
    
    private(set) var sessions: [PlankSession] = []
    private(set) var isLoading = false
    private(set) var error: Error?
    
    private var lastSyncTimestamp: Date?
    
    private init() {}
    
    // MARK: - Fetch Sessions
    
    func fetchSessions(forceRefresh: Bool = false) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            struct PlanksResponse: Decodable {
                let planks: [APIPlankSession]
                let pagination: PaginationMeta
            }
            
            let response: PlanksResponse = try await APIClient.shared.request(
                endpoint: "/planks?limit=100"
            )
            
            self.sessions = response.planks.map { PlankSession(from: $0) }
            self.lastSyncTimestamp = Date()
        } catch {
            self.error = error
        }
    }
    
    // MARK: - Create Session
    
    func createSession(
        duration: TimeInterval,
        plankType: Constants.Plank.PlankType,
        inputMethod: PlankSession.InputMethod
    ) async throws -> PlankSession {
        let clientId = UUID().uuidString
        
        struct CreatePlankRequest: Encodable {
            let clientId: String
            let durationSeconds: Double
            let plankType: String
            let inputMethod: String
            let performedAt: String
            let timezone: String
        }
        
        let request = CreatePlankRequest(
            clientId: clientId,
            durationSeconds: duration,
            plankType: plankType.rawValue,
            inputMethod: inputMethod.rawValue,
            performedAt: ISO8601DateFormatter().string(from: Date()),
            timezone: TimeZone.current.identifier
        )
        
        struct CreateResponse: Decodable {
            let plank: APIPlankSession
        }
        
        let response: CreateResponse = try await APIClient.shared.request(
            endpoint: "/planks",
            method: .post,
            body: request
        )
        
        let session = PlankSession(from: response.plank)
        sessions.insert(session, at: 0)
        
        return session
    }
    
    // MARK: - Delete Session
    
    func deleteSession(_ session: PlankSession) async throws {
        guard let serverId = session.serverId else { return }
        
        try await APIClient.shared.request(
            endpoint: "/planks/\(serverId)",
            method: .delete
        ) as EmptyResponse
        
        sessions.removeAll { $0.id == session.id }
    }
}

// MARK: - Model Conversion

extension PlankSession {
    init(from api: APIPlankSession) {
        self.init(
            date: ISO8601DateFormatter().date(from: api.performedAt) ?? Date(),
            durationSeconds: api.durationSeconds,
            plankType: Constants.Plank.PlankType(rawValue: api.plankType) ?? .elbow,
            inputMethod: InputMethod(rawValue: api.inputMethod) ?? .timer
        )
        // Store server ID for sync
        self.serverId = api.id
    }
    
    var serverId: String? {
        get { UserDefaults.standard.string(forKey: "plank_\(id)_serverId") }
        set { UserDefaults.standard.set(newValue, forKey: "plank_\(id)_serverId") }
    }
}
```

### 4.2 Create StreakService

**Create:** `PlankChallenge/Services/StreakService.swift`

```swift
import Foundation
import Observation

@Observable
@MainActor
class StreakService {
    static let shared = StreakService()
    
    private(set) var currentStreak: Int = 0
    private(set) var longestStreak: Int = 0
    private(set) var freezeTokens: Int = 0
    private(set) var hasPlankkedToday: Bool = false
    private(set) var isStreakAtRisk: Bool = false
    private(set) var recentActivity: [DayActivity] = []
    
    struct DayActivity: Identifiable {
        let id = UUID()
        let date: String
        let planks: Int
        let totalSeconds: Double
    }
    
    private init() {}
    
    func fetchStreak() async throws {
        struct StreakResponse: Decodable {
            let currentStreak: Int
            let longestStreak: Int
            let freezeTokens: Int
            let hasPlankkedToday: Bool
            let isStreakAtRisk: Bool
            let recentActivity: [Activity]
            
            struct Activity: Decodable {
                let date: String
                let planks: Int
                let totalSeconds: Double
            }
        }
        
        let response: StreakResponse = try await APIClient.shared.request(
            endpoint: "/streaks/me"
        )
        
        self.currentStreak = response.currentStreak
        self.longestStreak = response.longestStreak
        self.freezeTokens = response.freezeTokens
        self.hasPlankkedToday = response.hasPlankkedToday
        self.isStreakAtRisk = response.isStreakAtRisk
        self.recentActivity = response.recentActivity.map {
            DayActivity(date: $0.date, planks: $0.planks, totalSeconds: $0.totalSeconds)
        }
    }
    
    func useFreeze() async throws {
        struct FreezeResponse: Decodable {
            let freezeTokensRemaining: Int
            let streakProtected: Bool
        }
        
        let response: FreezeResponse = try await APIClient.shared.request(
            endpoint: "/streaks/freeze",
            method: .post
        )
        
        self.freezeTokens = response.freezeTokensRemaining
        self.isStreakAtRisk = false
    }
}
```

### 4.3 Create BadgeService

**Create:** `PlankChallenge/Services/BadgeService.swift`

```swift
import Foundation
import Observation

@Observable
@MainActor
class BadgeService {
    static let shared = BadgeService()
    
    private(set) var earnedBadges: [APIBadge] = []
    private(set) var allBadges: [BadgeDefinition] = []
    private(set) var isLoading = false
    
    struct APIBadge: Decodable, Identifiable {
        let id: String
        let badgeType: String
        let earnedAt: String
    }
    
    struct BadgeDefinition: Decodable, Identifiable {
        var id: String { badgeType }
        let badgeType: String
        let name: String
        let description: String
        let category: String
        let achieved: Bool
        let progress: Int
    }
    
    private init() {}
    
    func fetchBadges() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            struct BadgesResponse: Decodable {
                let badges: [APIBadge]
            }
            
            let response: BadgesResponse = try await APIClient.shared.request(
                endpoint: "/badges"
            )
            self.earnedBadges = response.badges
        } catch {
            print("Failed to fetch badges: \(error)")
        }
    }
    
    func fetchAllBadges() async {
        do {
            struct AllBadgesResponse: Decodable {
                let badges: [BadgeDefinition]
            }
            
            let response: AllBadgesResponse = try await APIClient.shared.request(
                endpoint: "/badges/all"
            )
            self.allBadges = response.badges
        } catch {
            print("Failed to fetch all badges: \(error)")
        }
    }
}
```

### 4.4 Update Views to Use Services

Update views to use the new services instead of `MockDataService`. Example for `PlankTimerView`:

```swift
// In PlankTimerView.swift, replace MockDataService usage:

// Before:
// let mockService = MockDataService.shared

// After:
@Environment(AuthService.self) private var authService
private let plankService = PlankService.shared
private let streakService = StreakService.shared

// When plank completes:
func savePlank(duration: TimeInterval) async {
    do {
        let session = try await plankService.createSession(
            duration: duration,
            plankType: selectedPlankType,
            inputMethod: .timer
        )
        // Update streak
        try await streakService.fetchStreak()
    } catch {
        // Handle error
    }
}
```

---

## Phase 5: Social Features (1-2 days)

### 5.1 Create UserService

**Create:** `PlankChallenge/Services/UserService.swift`

```swift
import Foundation
import Observation

@Observable
@MainActor
class UserService {
    static let shared = UserService()
    
    private(set) var searchResults: [APIPublicUser] = []
    private(set) var isSearching = false
    
    private init() {}
    
    // MARK: - Search
    
    func searchUsers(query: String) async {
        guard query.count >= 2 else {
            searchResults = []
            return
        }
        
        isSearching = true
        defer { isSearching = false }
        
        do {
            struct SearchResponse: Decodable {
                let users: [APIPublicUser]
            }
            
            let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
            let response: SearchResponse = try await APIClient.shared.request(
                endpoint: "/users/search?q=\(encoded)"
            )
            self.searchResults = response.users
        } catch {
            print("Search failed: \(error)")
        }
    }
    
    // MARK: - Follow/Unfollow
    
    func followUser(id: String) async throws {
        try await APIClient.shared.request(
            endpoint: "/users/\(id)/follow",
            method: .post
        ) as EmptyResponse
    }
    
    func unfollowUser(id: String) async throws {
        try await APIClient.shared.request(
            endpoint: "/users/\(id)/follow",
            method: .delete
        ) as EmptyResponse
    }
    
    // MARK: - Profile
    
    func getProfile(id: String) async throws -> APIPublicUser {
        struct ProfileResponse: Decodable {
            let user: APIPublicUser
        }
        
        let response: ProfileResponse = try await APIClient.shared.request(
            endpoint: "/users/\(id)"
        )
        return response.user
    }
}
```

### 5.2 Create GroupService

**Create:** `PlankChallenge/Services/GroupService.swift`

```swift
import Foundation
import Observation

@Observable
@MainActor
class GroupService {
    static let shared = GroupService()
    
    private(set) var myGroups: [APIGroup] = []
    private(set) var discoverGroups: [APIGroup] = []
    private(set) var isLoading = false
    
    struct APIGroup: Decodable, Identifiable {
        let id: String
        let name: String
        let description: String?
        let imageUrl: String?
        let groupType: String
        let joinMode: String
        let memberCount: Int
        let createdBy: String
    }
    
    private init() {}
    
    func fetchMyGroups() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            struct GroupsResponse: Decodable {
                let groups: [APIGroup]
            }
            
            let response: GroupsResponse = try await APIClient.shared.request(
                endpoint: "/groups"
            )
            self.myGroups = response.groups
        } catch {
            print("Failed to fetch groups: \(error)")
        }
    }
    
    func fetchDiscoverGroups() async {
        do {
            struct DiscoverResponse: Decodable {
                let groups: [APIGroup]
            }
            
            let response: DiscoverResponse = try await APIClient.shared.request(
                endpoint: "/groups/discover"
            )
            self.discoverGroups = response.groups
        } catch {
            print("Failed to fetch discover groups: \(error)")
        }
    }
    
    func joinGroup(id: String) async throws {
        try await APIClient.shared.request(
            endpoint: "/groups/\(id)/join",
            method: .post
        ) as EmptyResponse
        
        await fetchMyGroups()
    }
    
    func leaveGroup(id: String) async throws {
        try await APIClient.shared.request(
            endpoint: "/groups/\(id)/leave",
            method: .post
        ) as EmptyResponse
        
        await fetchMyGroups()
    }
}
```

### 5.3 Create LeaderboardService

**Create:** `PlankChallenge/Services/LeaderboardService.swift`

```swift
import Foundation
import Observation

@Observable
@MainActor
class LeaderboardService {
    static let shared = LeaderboardService()
    
    private(set) var globalLeaderboard: [LeaderboardEntry] = []
    private(set) var followingLeaderboard: [LeaderboardEntry] = []
    private(set) var isLoading = false
    
    struct LeaderboardEntry: Decodable, Identifiable {
        var id: String { odId }
        let odId: String
        let rank: Int
        let displayName: String
        let username: String?
        let profileImageUrl: String?
        let score: LeaderboardScore
        
        struct LeaderboardScore: Decodable {
            let value: Int
            let formatted: String
        }
    }
    
    private init() {}
    
    func fetchGlobalLeaderboard(type: String = "streak", period: String = "all_time") async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            struct LeaderboardResponse: Decodable {
                let leaderboard: [LeaderboardEntry]
                let userRank: LeaderboardEntry?
            }
            
            let response: LeaderboardResponse = try await APIClient.shared.request(
                endpoint: "/leaderboards/global?type=\(type)&period=\(period)"
            )
            self.globalLeaderboard = response.leaderboard
        } catch {
            print("Failed to fetch leaderboard: \(error)")
        }
    }
    
    func fetchFollowingLeaderboard() async {
        do {
            struct LeaderboardResponse: Decodable {
                let leaderboard: [LeaderboardEntry]
            }
            
            let response: LeaderboardResponse = try await APIClient.shared.request(
                endpoint: "/leaderboards/following"
            )
            self.followingLeaderboard = response.leaderboard
        } catch {
            print("Failed to fetch following leaderboard: \(error)")
        }
    }
}
```

---

## Phase 6: Final Polish (1 day)

### 6.1 Update SettingsView URLs

Replace placeholder URLs in `SettingsView.swift`:

```swift
// Replace:
Link(destination: URL(string: "https://example.com/privacy")!)

// With:
Link(destination: URL(string: "https://plankchallenge.app/privacy")!)
Link(destination: URL(string: "https://plankchallenge.app/terms")!)
```

### 6.2 Remove MockDataService Dependencies

1. Search for all `MockDataService.shared` usages
2. Replace with appropriate service (PlankService, UserService, etc.)
3. Delete `MockDataService.swift` and `MockUser.swift` when done

### 6.3 Add Error Handling UI

Create a reusable error view:

```swift
struct ErrorView: View {
    let error: Error
    let retryAction: () async -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            
            Text("Something went wrong")
                .font(.headline)
            
            Text(errorMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Try Again") {
                Task { await retryAction() }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
    
    private var errorMessage: String {
        if let apiError = error as? APIError {
            return apiError.error.message
        }
        return "Please check your connection and try again."
    }
}
```

### 6.4 Add Loading States

Ensure all views show loading indicators:

```swift
// Example pattern
struct MyView: View {
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else {
                // Content
            }
        }
        .task {
            await loadData()
            isLoading = false
        }
    }
}
```

### 6.5 Deploy Backend to Production

1. **Set up production secrets:**
```bash
cd backend
wrangler secret put JWT_SECRET
wrangler secret put APPLE_CLIENT_ID
wrangler secret put GOOGLE_CLIENT_ID
```

2. **Deploy:**
```bash
wrangler deploy
```

3. **Update AppConfig with production URL:**
```swift
case .production:
    return "https://plank-challenge-api.<your-subdomain>.workers.dev"
```

---

## File Structure Summary

After implementation, the new files will be:

```
PlankChallenge/
├── PlankChallenge.entitlements          # NEW
├── PrivacyInfo.xcprivacy                # NEW
├── Services/
│   ├── API/
│   │   ├── APIClient.swift              # NEW
│   │   └── Models/
│   │       └── APIModels.swift          # NEW
│   ├── AuthService.swift                # NEW
│   ├── KeychainService.swift            # NEW
│   ├── PlankService.swift               # NEW
│   ├── StreakService.swift              # NEW
│   ├── BadgeService.swift               # NEW
│   ├── UserService.swift                # NEW
│   ├── GroupService.swift               # NEW
│   └── LeaderboardService.swift         # NEW
├── Views/
│   ├── Auth/
│   │   ├── AuthenticationView.swift     # NEW
│   │   ├── EmailSignInView.swift        # NEW
│   │   └── EmailSignUpView.swift        # NEW
│   └── RootView.swift                   # NEW
└── (existing files - modified)
    ├── PlankChallengeApp.swift          # MODIFIED
    ├── AppConfig.swift                  # MODIFIED
    └── (other views using new services) # MODIFIED
```

---

## Testing Checklist

Before App Store submission:

### Authentication
- [ ] Sign in with Apple works
- [ ] Email sign up works
- [ ] Email sign in works
- [ ] Sign out works
- [ ] Session persists after app restart
- [ ] Token refresh works after expiry

### Core Features
- [ ] Can complete a plank and save to server
- [ ] Plank history loads from server
- [ ] Streak updates after plank
- [ ] Freeze token can be used
- [ ] Badges display correctly

### Social Features
- [ ] Can search for users
- [ ] Can follow/unfollow users
- [ ] Can view other profiles
- [ ] Groups list loads
- [ ] Can join/leave groups
- [ ] Leaderboards display

### Error Handling
- [ ] Offline mode shows appropriate message
- [ ] API errors display user-friendly messages
- [ ] Network timeout handled gracefully

---

## Notes

- **Google Sign-In:** Requires additional SDK integration (GoogleSignIn). Can be added later if needed.
- **Push Notifications:** Device registration is ready, but APNs delivery requires separate implementation.
- **Offline Mode:** Current plan is online-only. Full offline sync can be added in future iteration.

---

*Last updated: March 15, 2026*
