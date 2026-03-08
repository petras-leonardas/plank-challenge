# Phase 5: Backend Integration & Real Functionality

**Goal:** Set up backend infrastructure and systematically replace all mock data with real functionality. Implement authentication, data sync, real leaderboards, groups, and all social features.

**Outcome:** A production-ready app with full backend integration, ready for App Store submission.

**Prerequisites:** Phase 4 complete — polished core plank experience with local data storage.

---

## Step 1: Choose and Set Up Backend Platform

### 1.1 Evaluate Backend Options

**Option A: Firebase (Recommended for MVP)**
- Pros: Quick setup, built-in auth, real-time database, good iOS SDK, free tier
- Cons: Vendor lock-in, costs can scale quickly
- Best for: Fast MVP, small-medium user base

**Option B: Supabase**
- Pros: Open source, PostgreSQL, good free tier, similar to Firebase
- Cons: Newer platform, smaller community
- Best for: Those preferring open source

**Option C: Custom Backend (Node.js/Python + PostgreSQL)**
- Pros: Full control, no vendor lock-in
- Cons: More development time, need to manage infrastructure
- Best for: Long-term scaling, specific requirements

**Recommendation:** Start with **Firebase** for fastest time-to-market.

### 1.2 Set Up Firebase Project
- [ ] Go to [Firebase Console](https://console.firebase.google.com)
- [ ] Create new project: "PlankChallenge"
- [ ] Enable Google Analytics (optional but recommended)
- [ ] Add iOS app:
  - Bundle ID: `com.yourname.plankchallenge`
  - Download `GoogleService-Info.plist`
- [ ] Add `GoogleService-Info.plist` to Xcode project (ensure it's in the target)

### 1.3 Install Firebase SDK
- [ ] In Xcode: File → Add Packages
- [ ] Add Firebase iOS SDK: `https://github.com/firebase/firebase-ios-sdk`
- [ ] Select these packages:
  - [ ] FirebaseAuth
  - [ ] FirebaseFirestore
  - [ ] FirebaseStorage
  - [ ] FirebaseMessaging (for push notifications)
  - [ ] FirebaseAnalytics (optional)

### 1.4 Initialize Firebase in App
- [ ] Update `PlankChallengeApp.swift`:

```swift
import SwiftUI
import SwiftData
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        return true
    }
}

@main
struct PlankChallengeApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            PlankSession.self,
            UserProfile.self,
            Badge.self,
            AppNotification.self,
            PlankGroup.self
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
                .environment(\.modelContext, sharedModelContainer.mainContext)
        }
        .modelContainer(sharedModelContainer)
    }
}
```

### 1.5 Create RootView for Auth State
- [ ] Create `RootView.swift` in **Views/**:

```swift
import SwiftUI

struct RootView: View {
    @StateObject private var authService = AuthService.shared
    
    var body: some View {
        Group {
            if authService.isLoading {
                LoadingView()
            } else if authService.isAuthenticated {
                MainTabView()
            } else {
                AuthenticationView()
            }
        }
        .animation(.easeInOut, value: authService.isAuthenticated)
    }
}

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Loading...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    RootView()
}
```

### 1.6 Commit
- [ ] `git add .`
- [ ] `git commit -m "Set up Firebase and create RootView for auth state"`

---

## Step 2: Implement Authentication Service

### 2.1 Create AuthService
- [ ] Create `AuthService.swift` in **Services/**:

```swift
import Foundation
import FirebaseAuth
import FirebaseFirestore
import AuthenticationServices
import GoogleSignIn
import FirebaseCore

@MainActor
class AuthService: ObservableObject {
    static let shared = AuthService()
    
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var isLoading = true
    @Published var error: AuthError?
    
    private var authStateListener: AuthStateDidChangeListenerHandle?
    private let db = Firestore.firestore()
    
    enum AuthError: LocalizedError {
        case signInFailed(String)
        case signUpFailed(String)
        case signOutFailed(String)
        case userNotFound
        case invalidEmail
        case weakPassword
        case emailAlreadyInUse
        case unknown(Error)
        
        var errorDescription: String? {
            switch self {
            case .signInFailed(let message): return "Sign in failed: \(message)"
            case .signUpFailed(let message): return "Sign up failed: \(message)"
            case .signOutFailed(let message): return "Sign out failed: \(message)"
            case .userNotFound: return "No account found with this email"
            case .invalidEmail: return "Please enter a valid email address"
            case .weakPassword: return "Password must be at least 6 characters"
            case .emailAlreadyInUse: return "An account already exists with this email"
            case .unknown(let error): return error.localizedDescription
            }
        }
    }
    
    private init() {
        setupAuthStateListener()
    }
    
    private func setupAuthStateListener() {
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.currentUser = user
                self?.isAuthenticated = user != nil
                self?.isLoading = false
                
                if let user = user {
                    await self?.ensureUserProfileExists(userId: user.uid, email: user.email)
                }
            }
        }
    }
    
    // MARK: - Email/Password Authentication
    
    func signUp(email: String, password: String, displayName: String) async throws {
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            
            // Update display name
            let changeRequest = result.user.createProfileChangeRequest()
            changeRequest.displayName = displayName
            try await changeRequest.commitChanges()
            
            // Create user profile in Firestore
            try await createUserProfile(
                userId: result.user.uid,
                email: email,
                displayName: displayName
            )
        } catch let error as NSError {
            throw mapFirebaseError(error)
        }
    }
    
    func signIn(email: String, password: String) async throws {
        do {
            try await Auth.auth().signIn(withEmail: email, password: password)
        } catch let error as NSError {
            throw mapFirebaseError(error)
        }
    }
    
    // MARK: - Google Sign In
    
    func signInWithGoogle() async throws {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw AuthError.signInFailed("Missing client ID")
        }
        
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            throw AuthError.signInFailed("No root view controller")
        }
        
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
            
            guard let idToken = result.user.idToken?.tokenString else {
                throw AuthError.signInFailed("Missing ID token")
            }
            
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: result.user.accessToken.tokenString
            )
            
            let authResult = try await Auth.auth().signIn(with: credential)
            
            // Create/update user profile
            try await createUserProfile(
                userId: authResult.user.uid,
                email: authResult.user.email ?? "",
                displayName: result.user.profile?.name ?? "Planker"
            )
        } catch let error as NSError {
            throw mapFirebaseError(error)
        }
    }
    
    // MARK: - Apple Sign In
    
    func signInWithApple(credential: ASAuthorizationAppleIDCredential, nonce: String) async throws {
        guard let appleIDToken = credential.identityToken,
              let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            throw AuthError.signInFailed("Invalid Apple ID token")
        }
        
        let firebaseCredential = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: nonce,
            fullName: credential.fullName
        )
        
        do {
            let authResult = try await Auth.auth().signIn(with: firebaseCredential)
            
            // Get display name from Apple credential or use default
            var displayName = "Planker"
            if let fullName = credential.fullName {
                let formatter = PersonNameComponentsFormatter()
                displayName = formatter.string(from: fullName)
            }
            
            try await createUserProfile(
                userId: authResult.user.uid,
                email: authResult.user.email ?? "",
                displayName: displayName
            )
        } catch let error as NSError {
            throw mapFirebaseError(error)
        }
    }
    
    // MARK: - Sign Out
    
    func signOut() throws {
        do {
            try Auth.auth().signOut()
            GIDSignIn.sharedInstance.signOut()
        } catch {
            throw AuthError.signOutFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Password Reset
    
    func sendPasswordReset(email: String) async throws {
        try await Auth.auth().sendPasswordReset(withEmail: email)
    }
    
    // MARK: - Delete Account
    
    func deleteAccount() async throws {
        guard let user = Auth.auth().currentUser else {
            throw AuthError.userNotFound
        }
        
        // Delete user data from Firestore
        try await deleteUserData(userId: user.uid)
        
        // Delete Firebase Auth account
        try await user.delete()
    }
    
    // MARK: - Helper Methods
    
    private func createUserProfile(userId: String, email: String, displayName: String) async throws {
        let userRef = db.collection("users").document(userId)
        
        let userData: [String: Any] = [
            "id": userId,
            "email": email,
            "displayName": displayName,
            "bio": "",
            "preferredPlankType": "Elbow Plank",
            "currentStreak": 0,
            "longestStreak": 0,
            "freezeTokens": Constants.Streak.initialFreezeTokens,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ]
        
        try await userRef.setData(userData, merge: true)
    }
    
    private func ensureUserProfileExists(userId: String, email: String?) async {
        let userRef = db.collection("users").document(userId)
        
        do {
            let document = try await userRef.getDocument()
            if !document.exists {
                try await createUserProfile(
                    userId: userId,
                    email: email ?? "",
                    displayName: Auth.auth().currentUser?.displayName ?? "Planker"
                )
            }
        } catch {
            print("Error checking user profile: \(error)")
        }
    }
    
    private func deleteUserData(userId: String) async throws {
        let batch = db.batch()
        
        // Delete user profile
        batch.deleteDocument(db.collection("users").document(userId))
        
        // Delete user's plank sessions
        let sessionsSnapshot = try await db.collection("plankSessions")
            .whereField("userId", isEqualTo: userId)
            .getDocuments()
        
        for doc in sessionsSnapshot.documents {
            batch.deleteDocument(doc.reference)
        }
        
        // Delete user's badges
        let badgesSnapshot = try await db.collection("badges")
            .whereField("userId", isEqualTo: userId)
            .getDocuments()
        
        for doc in badgesSnapshot.documents {
            batch.deleteDocument(doc.reference)
        }
        
        try await batch.commit()
    }
    
    private func mapFirebaseError(_ error: NSError) -> AuthError {
        switch error.code {
        case AuthErrorCode.invalidEmail.rawValue:
            return .invalidEmail
        case AuthErrorCode.weakPassword.rawValue:
            return .weakPassword
        case AuthErrorCode.emailAlreadyInUse.rawValue:
            return .emailAlreadyInUse
        case AuthErrorCode.userNotFound.rawValue:
            return .userNotFound
        default:
            return .unknown(error)
        }
    }
}
```

### 2.2 Create Apple Sign In Helper
- [ ] Create `AppleSignInHelper.swift` in **Services/**:

```swift
import Foundation
import CryptoKit
import AuthenticationServices

class AppleSignInHelper: NSObject, ObservableObject {
    @Published var nonce: String?
    
    func createNonce() -> String {
        let nonce = randomNonceString()
        self.nonce = nonce
        return sha256(nonce)
    }
    
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce")
        }
        
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        let nonce = randomBytes.map { byte in
            charset[Int(byte) % charset.count]
        }
        
        return String(nonce)
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
}
```

### 2.3 Add Google Sign-In Package
- [ ] In Xcode: File → Add Packages
- [ ] Add: `https://github.com/google/GoogleSignIn-iOS`
- [ ] Configure URL scheme in Info.plist:
  - Add URL Types with your reversed client ID from `GoogleService-Info.plist`

### 2.4 Commit
- [ ] `git add .`
- [ ] `git commit -m "Implement AuthService with email, Google, and Apple sign-in"`

---

## Step 3: Create Authentication Views

### 3.1 Create AuthenticationView
- [ ] Create `AuthenticationView.swift` in **Views/Auth/**:

```swift
import SwiftUI
import AuthenticationServices

struct AuthenticationView: View {
    @State private var showingSignUp = false
    @State private var showingSignIn = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()
                
                // Logo and welcome
                VStack(spacing: 16) {
                    Image(systemName: "figure.core.training")
                        .font(.system(size: 80))
                        .foregroundStyle(.appAccent)
                    
                    Text("Plank Challenge")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Build core strength with daily planks")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Sign in options
                VStack(spacing: 16) {
                    // Apple Sign In
                    SignInWithAppleButton(
                        onRequest: { request in
                            let helper = AppleSignInHelper()
                            request.requestedScopes = [.fullName, .email]
                            request.nonce = helper.createNonce()
                        },
                        onCompletion: { result in
                            handleAppleSignIn(result)
                        }
                    )
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 50)
                    .cornerRadius(12)
                    
                    // Google Sign In
                    Button {
                        signInWithGoogle()
                    } label: {
                        HStack {
                            Image(systemName: "g.circle.fill")
                                .font(.title2)
                            Text("Continue with Google")
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color(.systemBackground))
                        .foregroundStyle(.primary)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                        .cornerRadius(12)
                    }
                    
                    // Divider
                    HStack {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 1)
                        Text("or")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 1)
                    }
                    
                    // Email Sign In
                    Button {
                        showingSignIn = true
                    } label: {
                        Text("Sign in with Email")
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.appAccent)
                            .foregroundStyle(.white)
                            .cornerRadius(12)
                    }
                    
                    // Sign Up Link
                    Button {
                        showingSignUp = true
                    } label: {
                        HStack {
                            Text("Don't have an account?")
                                .foregroundStyle(.secondary)
                            Text("Sign Up")
                                .fontWeight(.medium)
                                .foregroundStyle(.appAccent)
                        }
                        .font(.subheadline)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .navigationDestination(isPresented: $showingSignIn) {
                EmailSignInView()
            }
            .navigationDestination(isPresented: $showingSignUp) {
                EmailSignUpView()
            }
        }
    }
    
    private func signInWithGoogle() {
        Task {
            do {
                try await AuthService.shared.signInWithGoogle()
            } catch {
                print("Google sign in error: \(error)")
            }
        }
    }
    
    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                Task {
                    let helper = AppleSignInHelper()
                    if let nonce = helper.nonce {
                        try await AuthService.shared.signInWithApple(
                            credential: appleIDCredential,
                            nonce: nonce
                        )
                    }
                }
            }
        case .failure(let error):
            print("Apple sign in error: \(error)")
        }
    }
}

#Preview {
    AuthenticationView()
}
```

### 3.2 Create EmailSignInView
- [ ] Create `EmailSignInView.swift` in **Views/Auth/**:

```swift
import SwiftUI

struct EmailSignInView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingForgotPassword = false
    
    private var isValid: Bool {
        !email.isEmpty && !password.isEmpty && email.contains("@")
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Text("Welcome Back")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Sign in to continue your plank journey")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 32)
                
                // Form
                VStack(spacing: 16) {
                    // Email
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Email")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        TextField("your@email.com", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .padding()
                            .background(Color(.secondarySystemGroupedBackground))
                            .cornerRadius(12)
                    }
                    
                    // Password
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Password")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        SecureField("Enter password", text: $password)
                            .textContentType(.password)
                            .padding()
                            .background(Color(.secondarySystemGroupedBackground))
                            .cornerRadius(12)
                    }
                    
                    // Forgot password
                    HStack {
                        Spacer()
                        Button("Forgot Password?") {
                            showingForgotPassword = true
                        }
                        .font(.subheadline)
                        .foregroundStyle(.appAccent)
                    }
                }
                
                // Error message
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
                
                // Sign in button
                Button {
                    signIn()
                } label: {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Sign In")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(isValid ? Color.appAccent : Color.gray)
                .foregroundStyle(.white)
                .cornerRadius(12)
                .disabled(!isValid || isLoading)
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle("Sign In")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingForgotPassword) {
            ForgotPasswordView()
        }
    }
    
    private func signIn() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await AuthService.shared.signIn(email: email, password: password)
                dismiss()
            } catch let error as AuthService.AuthError {
                errorMessage = error.errorDescription
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

#Preview {
    NavigationStack {
        EmailSignInView()
    }
}
```

### 3.3 Create EmailSignUpView
- [ ] Create `EmailSignUpView.swift` in **Views/Auth/**:

```swift
import SwiftUI

struct EmailSignUpView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var displayName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    private var isValid: Bool {
        !displayName.isEmpty &&
        !email.isEmpty &&
        email.contains("@") &&
        password.count >= 6 &&
        password == confirmPassword
    }
    
    private var passwordsMatch: Bool {
        password == confirmPassword || confirmPassword.isEmpty
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Text("Create Account")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Start your plank challenge journey")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 32)
                
                // Form
                VStack(spacing: 16) {
                    // Display Name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Display Name")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        TextField("Your name", text: $displayName)
                            .textContentType(.name)
                            .padding()
                            .background(Color(.secondarySystemGroupedBackground))
                            .cornerRadius(12)
                    }
                    
                    // Email
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Email")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        TextField("your@email.com", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .padding()
                            .background(Color(.secondarySystemGroupedBackground))
                            .cornerRadius(12)
                    }
                    
                    // Password
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Password")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        SecureField("At least 6 characters", text: $password)
                            .textContentType(.newPassword)
                            .padding()
                            .background(Color(.secondarySystemGroupedBackground))
                            .cornerRadius(12)
                        
                        if !password.isEmpty && password.count < 6 {
                            Text("Password must be at least 6 characters")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                    
                    // Confirm Password
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Confirm Password")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        SecureField("Re-enter password", text: $confirmPassword)
                            .textContentType(.newPassword)
                            .padding()
                            .background(Color(.secondarySystemGroupedBackground))
                            .cornerRadius(12)
                        
                        if !passwordsMatch {
                            Text("Passwords do not match")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }
                
                // Error message
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
                
                // Sign up button
                Button {
                    signUp()
                } label: {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Create Account")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(isValid ? Color.appAccent : Color.gray)
                .foregroundStyle(.white)
                .cornerRadius(12)
                .disabled(!isValid || isLoading)
                
                // Terms
                Text("By signing up, you agree to our Terms of Service and Privacy Policy")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle("Sign Up")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func signUp() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await AuthService.shared.signUp(
                    email: email,
                    password: password,
                    displayName: displayName
                )
                dismiss()
            } catch let error as AuthService.AuthError {
                errorMessage = error.errorDescription
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

#Preview {
    NavigationStack {
        EmailSignUpView()
    }
}
```

### 3.4 Create ForgotPasswordView
- [ ] Create `ForgotPasswordView.swift` in **Views/Auth/**:

```swift
import SwiftUI

struct ForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var isLoading = false
    @State private var showingSuccess = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "lock.rotation")
                        .font(.system(size: 50))
                        .foregroundStyle(.appAccent)
                    
                    Text("Reset Password")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Enter your email and we'll send you a link to reset your password")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 32)
                
                // Email field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Email")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    TextField("your@email.com", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .padding()
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(12)
                }
                
                // Error message
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                
                // Submit button
                Button {
                    sendResetEmail()
                } label: {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Send Reset Link")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(!email.isEmpty ? Color.appAccent : Color.gray)
                .foregroundStyle(.white)
                .cornerRadius(12)
                .disabled(email.isEmpty || isLoading)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Forgot Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Email Sent", isPresented: $showingSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Check your email for a link to reset your password.")
            }
        }
    }
    
    private func sendResetEmail() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await AuthService.shared.sendPasswordReset(email: email)
                showingSuccess = true
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

#Preview {
    ForgotPasswordView()
}
```

### 3.5 Commit
- [ ] `git add .`
- [ ] `git commit -m "Create authentication views: sign in, sign up, forgot password"`

---

## Step 4: Create Firestore Data Service

### 4.1 Create FirestoreService
- [ ] Create `FirestoreService.swift` in **Services/**:

```swift
import Foundation
import FirebaseFirestore
import FirebaseAuth

class FirestoreService: ObservableObject {
    static let shared = FirestoreService()
    
    private let db = Firestore.firestore()
    
    private var userId: String? {
        Auth.auth().currentUser?.uid
    }
    
    // MARK: - User Profile
    
    func getUserProfile() async throws -> FirestoreUserProfile? {
        guard let userId = userId else { return nil }
        
        let document = try await db.collection("users").document(userId).getDocument()
        return try? document.data(as: FirestoreUserProfile.self)
    }
    
    func updateUserProfile(_ profile: FirestoreUserProfile) async throws {
        guard let userId = userId else { return }
        
        try db.collection("users").document(userId).setData(from: profile, merge: true)
    }
    
    // MARK: - Plank Sessions
    
    func savePlankSession(_ session: FirestorePlankSession) async throws {
        guard let userId = userId else { return }
        
        var sessionWithUser = session
        sessionWithUser.userId = userId
        
        try db.collection("plankSessions").addDocument(from: sessionWithUser)
        
        // Update user stats
        try await updateUserStats(newPlankDuration: session.durationSeconds)
    }
    
    func getPlankSessions(limit: Int = 50) async throws -> [FirestorePlankSession] {
        guard let userId = userId else { return [] }
        
        let snapshot = try await db.collection("plankSessions")
            .whereField("userId", isEqualTo: userId)
            .order(by: "date", descending: true)
            .limit(to: limit)
            .getDocuments()
        
        return snapshot.documents.compactMap { try? $0.data(as: FirestorePlankSession.self) }
    }
    
    func getTodaysPlank() async throws -> FirestorePlankSession? {
        guard let userId = userId else { return nil }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let snapshot = try await db.collection("plankSessions")
            .whereField("userId", isEqualTo: userId)
            .whereField("date", isGreaterThanOrEqualTo: Timestamp(date: startOfDay))
            .whereField("date", isLessThan: Timestamp(date: endOfDay))
            .limit(to: 1)
            .getDocuments()
        
        return snapshot.documents.first.flatMap { try? $0.data(as: FirestorePlankSession.self) }
    }
    
    func deletePlankSession(id: String) async throws {
        try await db.collection("plankSessions").document(id).delete()
    }
    
    // MARK: - Leaderboards
    
    func getStreakLeaderboard(limit: Int = 50) async throws -> [LeaderboardEntry] {
        let snapshot = try await db.collection("users")
            .whereField("currentStreak", isGreaterThan: 0)
            .order(by: "currentStreak", descending: true)
            .limit(to: limit)
            .getDocuments()
        
        return snapshot.documents.enumerated().compactMap { index, doc in
            guard let profile = try? doc.data(as: FirestoreUserProfile.self) else { return nil }
            return LeaderboardEntry(
                rank: index + 1,
                userId: doc.documentID,
                displayName: profile.displayName,
                value: "\(profile.currentStreak) days",
                numericValue: Double(profile.currentStreak),
                profileImageUrl: profile.profileImageUrl
            )
        }
    }
    
    func getLongestPlankLeaderboard(limit: Int = 50) async throws -> [LeaderboardEntry] {
        let snapshot = try await db.collection("users")
            .whereField("currentStreak", isGreaterThan: 0)
            .order(by: "longestPlankSeconds", descending: true)
            .limit(to: limit)
            .getDocuments()
        
        return snapshot.documents.enumerated().compactMap { index, doc in
            guard let profile = try? doc.data(as: FirestoreUserProfile.self) else { return nil }
            return LeaderboardEntry(
                rank: index + 1,
                userId: doc.documentID,
                displayName: profile.displayName,
                value: profile.longestPlankSeconds.formattedDuration,
                numericValue: profile.longestPlankSeconds,
                profileImageUrl: profile.profileImageUrl
            )
        }
    }
    
    // MARK: - Groups
    
    func createGroup(_ group: FirestoreGroup) async throws -> String {
        guard let userId = userId else { throw FirestoreError.notAuthenticated }
        
        var groupWithCreator = group
        groupWithCreator.creatorId = userId
        groupWithCreator.adminIds = [userId]
        groupWithCreator.memberIds = [userId]
        
        let docRef = try db.collection("groups").addDocument(from: groupWithCreator)
        return docRef.documentID
    }
    
    func getGroup(id: String) async throws -> FirestoreGroup? {
        let document = try await db.collection("groups").document(id).getDocument()
        return try? document.data(as: FirestoreGroup.self)
    }
    
    func getMyGroups() async throws -> [FirestoreGroup] {
        guard let userId = userId else { return [] }
        
        let snapshot = try await db.collection("groups")
            .whereField("memberIds", arrayContains: userId)
            .getDocuments()
        
        return snapshot.documents.compactMap { try? $0.data(as: FirestoreGroup.self) }
    }
    
    func getPublicGroups(limit: Int = 20) async throws -> [FirestoreGroup] {
        let snapshot = try await db.collection("groups")
            .whereField("isPrivate", isEqualTo: false)
            .order(by: "memberCount", descending: true)
            .limit(to: limit)
            .getDocuments()
        
        return snapshot.documents.compactMap { try? $0.data(as: FirestoreGroup.self) }
    }
    
    func joinGroup(groupId: String) async throws {
        guard let userId = userId else { throw FirestoreError.notAuthenticated }
        
        let groupRef = db.collection("groups").document(groupId)
        
        try await groupRef.updateData([
            "memberIds": FieldValue.arrayUnion([userId]),
            "memberCount": FieldValue.increment(Int64(1))
        ])
    }
    
    func leaveGroup(groupId: String) async throws {
        guard let userId = userId else { throw FirestoreError.notAuthenticated }
        
        let groupRef = db.collection("groups").document(groupId)
        
        try await groupRef.updateData([
            "memberIds": FieldValue.arrayRemove([userId]),
            "memberCount": FieldValue.increment(Int64(-1))
        ])
    }
    
    func deleteGroup(groupId: String) async throws {
        try await db.collection("groups").document(groupId).delete()
    }
    
    // MARK: - Follow System
    
    func followUser(targetUserId: String) async throws {
        guard let userId = userId else { throw FirestoreError.notAuthenticated }
        
        let followData: [String: Any] = [
            "followerId": userId,
            "followingId": targetUserId,
            "createdAt": FieldValue.serverTimestamp()
        ]
        
        try await db.collection("follows").addDocument(data: followData)
    }
    
    func unfollowUser(targetUserId: String) async throws {
        guard let userId = userId else { throw FirestoreError.notAuthenticated }
        
        let snapshot = try await db.collection("follows")
            .whereField("followerId", isEqualTo: userId)
            .whereField("followingId", isEqualTo: targetUserId)
            .getDocuments()
        
        for doc in snapshot.documents {
            try await doc.reference.delete()
        }
    }
    
    func getFollowers() async throws -> [FirestoreUserProfile] {
        guard let userId = userId else { return [] }
        
        let followsSnapshot = try await db.collection("follows")
            .whereField("followingId", isEqualTo: userId)
            .getDocuments()
        
        let followerIds = followsSnapshot.documents.compactMap { $0.data()["followerId"] as? String }
        
        guard !followerIds.isEmpty else { return [] }
        
        let usersSnapshot = try await db.collection("users")
            .whereField(FieldPath.documentID(), in: followerIds)
            .getDocuments()
        
        return usersSnapshot.documents.compactMap { try? $0.data(as: FirestoreUserProfile.self) }
    }
    
    func getFollowing() async throws -> [FirestoreUserProfile] {
        guard let userId = userId else { return [] }
        
        let followsSnapshot = try await db.collection("follows")
            .whereField("followerId", isEqualTo: userId)
            .getDocuments()
        
        let followingIds = followsSnapshot.documents.compactMap { $0.data()["followingId"] as? String }
        
        guard !followingIds.isEmpty else { return [] }
        
        let usersSnapshot = try await db.collection("users")
            .whereField(FieldPath.documentID(), in: followingIds)
            .getDocuments()
        
        return usersSnapshot.documents.compactMap { try? $0.data(as: FirestoreUserProfile.self) }
    }
    
    // MARK: - Helper Methods
    
    private func updateUserStats(newPlankDuration: TimeInterval) async throws {
        guard let userId = userId else { return }
        
        let userRef = db.collection("users").document(userId)
        
        // Get current user data
        let document = try await userRef.getDocument()
        guard var profile = try? document.data(as: FirestoreUserProfile.self) else { return }
        
        // Update streak
        let newStreak = try await calculateStreak()
        profile.currentStreak = newStreak
        profile.longestStreak = max(profile.longestStreak, newStreak)
        
        // Update longest plank
        profile.longestPlankSeconds = max(profile.longestPlankSeconds, newPlankDuration)
        
        // Check for token reward
        if newStreak == Constants.Streak.streakForBonusToken &&
           profile.freezeTokens < Constants.Streak.maxFreezeTokens {
            profile.freezeTokens += 1
        }
        
        profile.lastPlankDate = Date()
        profile.updatedAt = Date()
        
        try userRef.setData(from: profile)
    }
    
    private func calculateStreak() async throws -> Int {
        guard let userId = userId else { return 0 }
        
        let calendar = Calendar.current
        var streak = 0
        var expectedDate = calendar.startOfDay(for: Date())
        
        // Get recent sessions
        let snapshot = try await db.collection("plankSessions")
            .whereField("userId", isEqualTo: userId)
            .order(by: "date", descending: true)
            .limit(to: 365)
            .getDocuments()
        
        let sessions = snapshot.documents.compactMap { try? $0.data(as: FirestorePlankSession.self) }
        
        for session in sessions {
            let sessionDate = calendar.startOfDay(for: session.date)
            
            if sessionDate == expectedDate {
                streak += 1
                expectedDate = calendar.date(byAdding: .day, value: -1, to: expectedDate)!
            } else if sessionDate < expectedDate {
                break
            }
        }
        
        return streak
    }
    
    // MARK: - Errors
    
    enum FirestoreError: LocalizedError {
        case notAuthenticated
        case documentNotFound
        case invalidData
        
        var errorDescription: String? {
            switch self {
            case .notAuthenticated: return "Please sign in to continue"
            case .documentNotFound: return "The requested data was not found"
            case .invalidData: return "Invalid data format"
            }
        }
    }
}
```

### 4.2 Create Firestore Models
- [ ] Create `FirestoreModels.swift` in **Models/**:

```swift
import Foundation
import FirebaseFirestore

// MARK: - User Profile

struct FirestoreUserProfile: Codable, Identifiable {
    @DocumentID var id: String?
    var email: String
    var displayName: String
    var bio: String
    var preferredPlankType: String
    var profileImageUrl: String?
    var linkedInLink: String?
    var socialLink: String?
    var currentStreak: Int
    var longestStreak: Int
    var longestPlankSeconds: TimeInterval
    var freezeTokens: Int
    var lastPlankDate: Date?
    var createdAt: Date
    var updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case displayName
        case bio
        case preferredPlankType
        case profileImageUrl
        case linkedInLink
        case socialLink
        case currentStreak
        case longestStreak
        case longestPlankSeconds
        case freezeTokens
        case lastPlankDate
        case createdAt
        case updatedAt
    }
}

// MARK: - Plank Session

struct FirestorePlankSession: Codable, Identifiable {
    @DocumentID var id: String?
    var userId: String
    var date: Date
    var durationSeconds: TimeInterval
    var plankType: String
    var inputMethod: String
    var timezoneIdentifier: String
    var createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId
        case date
        case durationSeconds
        case plankType
        case inputMethod
        case timezoneIdentifier
        case createdAt
    }
    
    init(
        userId: String = "",
        date: Date = Date(),
        durationSeconds: TimeInterval,
        plankType: Constants.Plank.PlankType,
        inputMethod: PlankSession.InputMethod
    ) {
        self.userId = userId
        self.date = date
        self.durationSeconds = durationSeconds
        self.plankType = plankType.rawValue
        self.inputMethod = inputMethod.rawValue
        self.timezoneIdentifier = TimeZone.current.identifier
        self.createdAt = Date()
    }
}

// MARK: - Group

struct FirestoreGroup: Codable, Identifiable {
    @DocumentID var id: String?
    var name: String
    var description: String
    var isPrivate: Bool
    var requiresApproval: Bool
    var imageUrl: String?
    var creatorId: String
    var adminIds: [String]
    var memberIds: [String]
    var memberCount: Int
    var createdAt: Date
    var updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case isPrivate
        case requiresApproval
        case imageUrl
        case creatorId
        case adminIds
        case memberIds
        case memberCount
        case createdAt
        case updatedAt
    }
}

// MARK: - Leaderboard Entry

struct LeaderboardEntry: Identifiable {
    let id = UUID()
    let rank: Int
    let userId: String
    let displayName: String
    let value: String
    let numericValue: Double
    let profileImageUrl: String?
}

// MARK: - Badge

struct FirestoreBadge: Codable, Identifiable {
    @DocumentID var id: String?
    var userId: String
    var badgeType: String
    var dateEarned: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId
        case badgeType
        case dateEarned
    }
}
```

### 4.3 Commit
- [ ] `git add .`
- [ ] `git commit -m "Create FirestoreService and Firestore models"`

---

## Step 5: Implement Data Sync Service

### 5.1 Create SyncService
- [ ] Create `SyncService.swift` in **Services/**:

```swift
import Foundation
import SwiftData
import FirebaseAuth

@MainActor
class SyncService: ObservableObject {
    static let shared = SyncService()
    
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncError: Error?
    
    private let firestoreService = FirestoreService.shared
    
    private init() {}
    
    // MARK: - Full Sync
    
    func performFullSync(modelContext: ModelContext) async {
        guard Auth.auth().currentUser != nil else { return }
        
        isSyncing = true
        syncError = nil
        
        do {
            // Sync user profile
            try await syncUserProfile(modelContext: modelContext)
            
            // Sync plank sessions
            try await syncPlankSessions(modelContext: modelContext)
            
            // Sync badges
            try await syncBadges(modelContext: modelContext)
            
            lastSyncDate = Date()
        } catch {
            syncError = error
            print("Sync error: \(error)")
        }
        
        isSyncing = false
    }
    
    // MARK: - Upload Local Data
    
    func uploadLocalData(modelContext: ModelContext) async throws {
        guard Auth.auth().currentUser != nil else { return }
        
        // Upload unsynced plank sessions
        let localSessions = try fetchUnsyncedSessions(modelContext: modelContext)
        
        for session in localSessions {
            let firestoreSession = FirestorePlankSession(
                date: session.date,
                durationSeconds: session.durationSeconds,
                plankType: session.plankType,
                inputMethod: session.inputMethod
            )
            
            try await firestoreService.savePlankSession(firestoreSession)
        }
    }
    
    // MARK: - Private Methods
    
    private func syncUserProfile(modelContext: ModelContext) async throws {
        guard let remoteProfile = try await firestoreService.getUserProfile() else { return }
        
        // Get or create local profile
        let descriptor = FetchDescriptor<UserProfile>()
        let localProfile = try modelContext.fetch(descriptor).first ?? UserProfile()
        
        // Update local profile with remote data
        localProfile.displayName = remoteProfile.displayName
        localProfile.bio = remoteProfile.bio
        localProfile.currentStreak = remoteProfile.currentStreak
        localProfile.longestStreak = remoteProfile.longestStreak
        localProfile.freezeTokens = remoteProfile.freezeTokens
        
        if let plankType = Constants.Plank.PlankType(rawValue: remoteProfile.preferredPlankType) {
            localProfile.preferredPlankType = plankType
        }
        
        if modelContext.hasChanges {
            try modelContext.save()
        }
    }
    
    private func syncPlankSessions(modelContext: ModelContext) async throws {
        let remoteSessions = try await firestoreService.getPlankSessions(limit: 100)
        
        for remoteSession in remoteSessions {
            // Check if session already exists locally
            let sessionDate = remoteSession.date
            let predicate = #Predicate<PlankSession> { session in
                session.date == sessionDate
            }
            let descriptor = FetchDescriptor<PlankSession>(predicate: predicate)
            let existing = try modelContext.fetch(descriptor)
            
            if existing.isEmpty {
                // Create local session
                let plankType = Constants.Plank.PlankType(rawValue: remoteSession.plankType) ?? .elbow
                let inputMethod = PlankSession.InputMethod(rawValue: remoteSession.inputMethod) ?? .timer
                
                let localSession = PlankSession(
                    date: remoteSession.date,
                    durationSeconds: remoteSession.durationSeconds,
                    plankType: plankType,
                    inputMethod: inputMethod
                )
                
                modelContext.insert(localSession)
            }
        }
        
        if modelContext.hasChanges {
            try modelContext.save()
        }
    }
    
    private func syncBadges(modelContext: ModelContext) async throws {
        // Badges are calculated locally based on streak
        // This ensures consistency
    }
    
    private func fetchUnsyncedSessions(modelContext: ModelContext) throws -> [PlankSession] {
        // For simplicity, return recent sessions
        // In production, track sync status with a flag
        let descriptor = FetchDescriptor<PlankSession>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }
}
```

### 5.2 Update PlankViewModel for Cloud Sync
- [ ] Add sync capability to `PlankViewModel.swift`:

```swift
// Add to PlankViewModel:

private let firestoreService = FirestoreService.shared

func savePlankToCloud(duration: TimeInterval, inputMethod: PlankSession.InputMethod) async throws {
    let session = FirestorePlankSession(
        date: Date(),
        durationSeconds: duration,
        plankType: selectedPlankType,
        inputMethod: inputMethod
    )
    
    try await firestoreService.savePlankSession(session)
}

func savePlankWithSync(duration: TimeInterval, inputMethod: PlankSession.InputMethod) -> SaveResult {
    // Save locally first
    let result = savePlankWithDetails(duration: duration, inputMethod: inputMethod)
    
    // Then sync to cloud in background
    if result.success && AppConfig.Features.syncEnabled {
        Task {
            try? await savePlankToCloud(duration: duration, inputMethod: inputMethod)
        }
    }
    
    return result
}
```

### 5.3 Commit
- [ ] `git add .`
- [ ] `git commit -m "Implement SyncService for local/cloud data synchronization"`

---

## Step 6: Update Views for Real Data

### 6.1 Update LeaderboardsView for Real Data
- [ ] Update `LeaderboardsView.swift`:

```swift
import SwiftUI
import SwiftData

struct LeaderboardsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab: LeaderboardTab = .streak
    @State private var streakLeaderboard: [LeaderboardEntry] = []
    @State private var longestPlankLeaderboard: [LeaderboardEntry] = []
    @State private var isLoading = true
    @State private var error: Error?
    
    private let firestoreService = FirestoreService.shared
    
    enum LeaderboardTab: String, CaseIterable {
        case streak = "Active Streak"
        case longestPlank = "Longest Plank"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Picker("Leaderboard", selection: $selectedTab) {
                ForEach(LeaderboardTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()
            
            if isLoading {
                ProgressView()
                    .frame(maxHeight: .infinity)
            } else if let error = error {
                ContentUnavailableView(
                    "Error Loading Leaderboard",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error.localizedDescription)
                )
            } else {
                leaderboardList
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Leaderboards")
        .task {
            await loadLeaderboards()
        }
        .refreshable {
            await loadLeaderboards()
        }
    }
    
    private var leaderboardList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(currentLeaderboard) { entry in
                    LeaderboardRowView(entry: entry, isCurrentUser: isCurrentUser(entry))
                    
                    if entry.id != currentLeaderboard.last?.id {
                        Divider()
                            .padding(.leading, 60)
                    }
                }
            }
            .padding()
        }
    }
    
    private var currentLeaderboard: [LeaderboardEntry] {
        switch selectedTab {
        case .streak:
            return streakLeaderboard
        case .longestPlank:
            return longestPlankLeaderboard
        }
    }
    
    private func isCurrentUser(_ entry: LeaderboardEntry) -> Bool {
        entry.userId == AuthService.shared.currentUser?.uid
    }
    
    private func loadLeaderboards() async {
        isLoading = true
        error = nil
        
        do {
            async let streaks = firestoreService.getStreakLeaderboard()
            async let planks = firestoreService.getLongestPlankLeaderboard()
            
            streakLeaderboard = try await streaks
            longestPlankLeaderboard = try await planks
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
}

struct LeaderboardRowView: View {
    let entry: LeaderboardEntry
    let isCurrentUser: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Rank
            ZStack {
                if entry.rank <= 3 {
                    Circle()
                        .fill(rankColor)
                        .frame(width: 32, height: 32)
                }
                
                Text("\(entry.rank)")
                    .font(.headline)
                    .foregroundStyle(entry.rank <= 3 ? .white : .primary)
            }
            .frame(width: 40)
            
            // Avatar
            AsyncImage(url: URL(string: entry.profileImageUrl ?? "")) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())
            
            // Name
            Text(entry.displayName)
                .font(.body)
                .fontWeight(isCurrentUser ? .semibold : .regular)
                .foregroundStyle(isCurrentUser ? .appAccent : .primary)
            
            Spacer()
            
            // Value
            Text(entry.value)
                .font(.headline)
                .foregroundStyle(isCurrentUser ? .appAccent : .primary)
        }
        .padding(.vertical, 8)
        .background(isCurrentUser ? Color.appAccent.opacity(0.1) : Color.clear)
        .cornerRadius(8)
    }
    
    private var rankColor: Color {
        switch entry.rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .clear
        }
    }
}
```

### 6.2 Update GroupsListView for Real Data
- [ ] Update groups-related views to use FirestoreService instead of MockDataService

### 6.3 Commit
- [ ] `git add .`
- [ ] `git commit -m "Update views to use real Firestore data"`

---

## Step 7: Implement Image Upload

### 7.1 Create StorageService
- [ ] Create `StorageService.swift` in **Services/**:

```swift
import Foundation
import FirebaseStorage
import FirebaseAuth
import UIKit

class StorageService {
    static let shared = StorageService()
    
    private let storage = Storage.storage()
    
    private var userId: String? {
        Auth.auth().currentUser?.uid
    }
    
    // MARK: - Profile Image
    
    func uploadProfileImage(_ image: UIImage) async throws -> String {
        guard let userId = userId else {
            throw StorageError.notAuthenticated
        }
        
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            throw StorageError.invalidImage
        }
        
        let path = "profileImages/\(userId).jpg"
        let ref = storage.reference().child(path)
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        _ = try await ref.putDataAsync(imageData, metadata: metadata)
        let downloadURL = try await ref.downloadURL()
        
        return downloadURL.absoluteString
    }
    
    func deleteProfileImage() async throws {
        guard let userId = userId else {
            throw StorageError.notAuthenticated
        }
        
        let path = "profileImages/\(userId).jpg"
        let ref = storage.reference().child(path)
        
        try await ref.delete()
    }
    
    // MARK: - Group Image
    
    func uploadGroupImage(_ image: UIImage, groupId: String) async throws -> String {
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            throw StorageError.invalidImage
        }
        
        let path = "groupImages/\(groupId).jpg"
        let ref = storage.reference().child(path)
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        _ = try await ref.putDataAsync(imageData, metadata: metadata)
        let downloadURL = try await ref.downloadURL()
        
        return downloadURL.absoluteString
    }
    
    // MARK: - Errors
    
    enum StorageError: LocalizedError {
        case notAuthenticated
        case invalidImage
        case uploadFailed(Error)
        
        var errorDescription: String? {
            switch self {
            case .notAuthenticated:
                return "Please sign in to upload images"
            case .invalidImage:
                return "Could not process the image"
            case .uploadFailed(let error):
                return "Upload failed: \(error.localizedDescription)"
            }
        }
    }
}
```

### 7.2 Update EditProfileView for Image Upload
- [ ] Update `EditProfileView.swift` to upload images to Firebase Storage

### 7.3 Commit
- [ ] `git add .`
- [ ] `git commit -m "Implement image upload with Firebase Storage"`

---

## Step 8: Implement Push Notifications

### 8.1 Configure Push Notifications
- [ ] In Firebase Console: Project Settings ��� Cloud Messaging
- [ ] Upload APNs authentication key or certificate
- [ ] In Xcode: Enable Push Notifications capability
- [ ] Enable Background Modes → Remote notifications

### 8.2 Update AppDelegate for Push Notifications
- [ ] Update the app delegate:

```swift
import UIKit
import FirebaseCore
import FirebaseMessaging
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, MessagingDelegate, UNUserNotificationCenterDelegate {
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        
        // Push notifications
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self
        
        application.registerForRemoteNotifications()
        
        return true
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }
    
    // MARK: - MessagingDelegate
    
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }
        print("FCM Token: \(token)")
        
        // Save token to user profile in Firestore
        Task {
            try? await saveFCMToken(token)
        }
    }
    
    private func saveFCMToken(_ token: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        try await Firestore.firestore()
            .collection("users")
            .document(userId)
            .updateData(["fcmToken": token])
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // Handle notification tap
        let userInfo = response.notification.request.content.userInfo
        handleNotification(userInfo)
        completionHandler()
    }
    
    private func handleNotification(_ userInfo: [AnyHashable: Any]) {
        // Handle different notification types
        if let type = userInfo["type"] as? String {
            switch type {
            case "streak_freeze":
                // Navigate to progress view
                break
            case "group_update":
                // Navigate to group
                break
            default:
                break
            }
        }
    }
}
```

### 8.3 Commit
- [ ] `git add .`
- [ ] `git commit -m "Implement push notifications with Firebase Cloud Messaging"`

---

## Step 9: Implement Analytics

### 9.1 Create AnalyticsService
- [ ] Create `AnalyticsService.swift` in **Services/**:

```swift
import Foundation
import FirebaseAnalytics

class AnalyticsService {
    static let shared = AnalyticsService()
    
    private init() {}
    
    // MARK: - Screen Tracking
    
    func logScreenView(_ screenName: String, screenClass: String? = nil) {
        Analytics.logEvent(AnalyticsEventScreenView, parameters: [
            AnalyticsParameterScreenName: screenName,
            AnalyticsParameterScreenClass: screenClass ?? screenName
        ])
    }
    
    // MARK: - Plank Events
    
    func logPlankStarted(plankType: String) {
        Analytics.logEvent("plank_started", parameters: [
            "plank_type": plankType
        ])
    }
    
    func logPlankCompleted(duration: TimeInterval, plankType: String, isPersonalBest: Bool) {
        Analytics.logEvent("plank_completed", parameters: [
            "duration_seconds": duration,
            "plank_type": plankType,
            "is_personal_best": isPersonalBest
        ])
    }
    
    func logPlankAbandoned(duration: TimeInterval) {
        Analytics.logEvent("plank_abandoned", parameters: [
            "duration_seconds": duration
        ])
    }
    
    // MARK: - Streak Events
    
    func logStreakMilestone(days: Int) {
        Analytics.logEvent("streak_milestone", parameters: [
            "streak_days": days
        ])
    }
    
    func logStreakLost(previousStreak: Int) {
        Analytics.logEvent("streak_lost", parameters: [
            "previous_streak": previousStreak
        ])
    }
    
    func logStreakFreezeUsed(tokensRemaining: Int) {
        Analytics.logEvent("streak_freeze_used", parameters: [
            "tokens_remaining": tokensRemaining
        ])
    }
    
    // MARK: - Badge Events
    
    func logBadgeEarned(badgeType: String) {
        Analytics.logEvent("badge_earned", parameters: [
            "badge_type": badgeType
        ])
    }
    
    // MARK: - Group Events
    
    func logGroupCreated(isPrivate: Bool) {
        Analytics.logEvent("group_created", parameters: [
            "is_private": isPrivate
        ])
    }
    
    func logGroupJoined(groupId: String) {
        Analytics.logEvent("group_joined", parameters: [
            "group_id": groupId
        ])
    }
    
    func logGroupLeft(groupId: String) {
        Analytics.logEvent("group_left", parameters: [
            "group_id": groupId
        ])
    }
    
    // MARK: - User Properties
    
    func setUserProperties(currentStreak: Int, totalPlanks: Int, groupCount: Int) {
        Analytics.setUserProperty("\(currentStreak)", forName: "current_streak")
        Analytics.setUserProperty("\(totalPlanks)", forName: "total_planks")
        Analytics.setUserProperty("\(groupCount)", forName: "group_count")
    }
}
```

### 9.2 Add Analytics to Key Flows
- [ ] Add analytics calls throughout the app:
  - Plank timer start/stop
  - Completion
  - Badge earned
  - Group actions
  - Screen views

### 9.3 Commit
- [ ] `git add .`
- [ ] `git commit -m "Implement analytics tracking with Firebase Analytics"`

---

## Step 10: App Store Preparation

### 10.1 App Store Connect Setup
- [ ] Log in to [App Store Connect](https://appstoreconnect.apple.com)
- [ ] Create new app
- [ ] Fill in app information:
  - Name: Plank Challenge
  - Primary language: English
  - Bundle ID: Select your bundle ID
  - SKU: plankchallenge

### 10.2 App Store Listing
- [ ] Write app description
- [ ] Prepare keywords
- [ ] Create screenshots for all device sizes:
  - iPhone 6.7" (14 Pro Max)
  - iPhone 6.5" (11 Pro Max)
  - iPhone 5.5" (8 Plus)
  - iPad Pro 12.9"
- [ ] Create app preview video (optional)
- [ ] Set app category: Health & Fitness
- [ ] Set age rating

### 10.3 Privacy Policy
- [ ] Create privacy policy page
- [ ] Host it at a public URL
- [ ] Add URL to App Store Connect

### 10.4 App Review Preparation
- [ ] Test all features thoroughly
- [ ] Ensure no crashes
- [ ] Remove all debug code
- [ ] Test on real devices
- [ ] Prepare demo account for reviewers

### 10.5 Archive and Submit
- [ ] In Xcode: Product → Archive
- [ ] Validate app
- [ ] Upload to App Store Connect
- [ ] Submit for review

### 10.6 Commit
- [ ] `git add .`
- [ ] `git commit -m "Phase 5 complete: Backend integration and App Store preparation"`
- [ ] `git tag v1.0-release`

---

## Phase 5 Completion Checklist

### Backend Setup
- [ ] Firebase project created and configured
- [ ] Firebase SDK installed
- [ ] Firestore database set up
- [ ] Firebase Storage configured
- [ ] Firebase Cloud Messaging configured

### Authentication
- [ ] Email/password sign up and sign in
- [ ] Google Sign-In
- [ ] Apple Sign-In
- [ ] Password reset
- [ ] Account deletion
- [ ] Auth state management

### Data Sync
- [ ] FirestoreService implemented
- [ ] SyncService for local/cloud sync
- [ ] Offline support with sync on reconnect
- [ ] Conflict resolution

### Features
- [ ] Real leaderboards (global)
- [ ] Real groups with all functionality
- [ ] Real follow system
- [ ] Real notifications
- [ ] Profile image upload
- [ ] Group image upload

### Push Notifications
- [ ] FCM configured
- [ ] Token management
- [ ] Streak freeze notifications
- [ ] Group notifications

### Analytics
- [ ] Firebase Analytics configured
- [ ] Key events tracked
- [ ] User properties set

### App Store
- [ ] App Store Connect set up
- [ ] Screenshots prepared
- [ ] App description written
- [ ] Privacy policy created
- [ ] App submitted for review

---

## Post-Launch Tasks

- [ ] Monitor crash reports in Firebase Crashlytics
- [ ] Monitor analytics for user behavior
- [ ] Respond to App Store reviews
- [ ] Plan feature updates based on user feedback
- [ ] Monitor backend costs and optimize if needed

---

## Future Enhancements (Post-Launch)

Refer to `PLAN.md` for future considerations:
- Monetization/subscription
- Additional plank types
- Social features (comments, reactions)
- Apple Watch app
- Android version
- Advanced verification
- Widgets

---

Congratulations! You've completed the Plank Challenge app!
