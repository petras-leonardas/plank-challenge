import SwiftUI
import AuthenticationServices
import GoogleSignIn

/// Main authentication view shown when user is not logged in
/// Provides options for Sign in with Apple and email authentication
struct AuthenticationView: View {
    @Environment(\.authService) private var authService
    
    @State private var isSigningInWithApple = false
    @State private var showError = false
    @State private var errorMessage: String?
    @State private var showEmailSignIn = false
    @State private var showEmailSignUp = false
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    Spacer()
                        .frame(minHeight: geometry.size.height * 0.1)
                    
                    // Logo and branding
                    brandingSection
                    
                    Spacer()
                        .frame(minHeight: geometry.size.height * 0.1)
                    
                    // Sign in buttons
                    signInButtonsSection
                    
                    // Sign up link
                    signUpSection
                    
                    Spacer()
                        .frame(minHeight: 40)
                }
                .frame(minHeight: geometry.size.height)
            }
        }
        .background(AppBackground())
        .alert("Couldn't sign you in", isPresented: $showError) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            if let error = errorMessage {
                Text(error)
            }
        }
        .onChange(of: errorMessage) { _, newValue in
            showError = newValue != nil
        }
        .overlay {
            // Show loading overlay during Apple Sign In or backend token exchange.
            // Google's OAuth sheet manages its own UI — we only show this after it dismisses.
            if isSigningInWithApple || authService.isLoading {
                ZStack {
                    Color.overlayScrim
                        .ignoresSafeArea()
                    
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                        
                        Text("Signing you in...")
                            .font(.headline)
                            .foregroundStyle(.white)
                    }
                    .padding(32)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
            }
        }
    }
    
    // MARK: - Branding Section
    
    private var brandingSection: some View {
        VStack(spacing: 16) {
            // App logo
            Image("AppLogoColour")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
            
            // App name
            Text("Plank Challenge")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            // Tagline
            Text("One exercise.\nEvery day.\nThat's it.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
    }
    
    // MARK: - Sign In Buttons Section
    
    private var signInButtonsSection: some View {
        VStack(spacing: 16) {
            // Sign in with Apple
            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.email, .fullName]
            } onCompletion: { result in
                handleAppleSignIn(result)
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)
            .cornerRadius(10)
            .disabled(isSigningInWithApple || authService.isLoading)
            
            // Sign in with Google
            Button {
                handleGoogleSignIn()
            } label: {
                HStack(spacing: 10) {
                    GoogleLogoMark()
                        .frame(width: 20, height: 20)
                     Text("Continue with Google")
                         .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
            }
            .buttonStyle(.bordered)
            .tint(.primary)
            .disabled(isSigningInWithApple || authService.isLoading)
            
            // Sign in with email
            Button {
                showEmailSignIn = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "envelope")
                        .frame(width: 20, height: 20)
                    Text("Sign in with email")
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
            }
            .buttonStyle(.bordered)
            .tint(.primary)
            .disabled(isSigningInWithApple || authService.isLoading)
        }
        .padding(.horizontal, 24)
        .sheet(isPresented: $showEmailSignIn) {
            EmailSignInView()
        }
    }
    
    // MARK: - Sign Up Section
    
    private var signUpSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                Text("Don't have an account?")
                    .foregroundStyle(.secondary)
                Button("Create one") {
                    showEmailSignUp = true
                }
            }
            .font(.subheadline)
            
            Text("By continuing, you agree to our Terms of Service and Privacy Policy.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
        .padding(.top, 24)
        .sheet(isPresented: $showEmailSignUp) {
            EmailSignUpView()
        }
    }
    
    // MARK: - Google Sign In Handler
    
    private func handleGoogleSignIn() {
        guard let presentingVC = topmostViewController() else {
            errorMessage = "Something went wrong. Try again, or use a different sign-in method."
            return
        }
        
        // Do NOT set isSigningInWithGoogle = true here.
        // The overlay must not appear during the OAuth sheet — it blocks touches.
        // authService.isLoading will become true only after the sheet dismisses
        // (during the backend token exchange), which is when we show the overlay.
        Task {
            do {
                try await authService.signInWithGoogle(presenting: presentingVC)
                // Success — AuthService updates state, RootView transitions automatically
            } catch let error as AuthError {
                if case .cancelled = error { } else {
                    errorMessage = error.localizedDescription
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    /// Walks the VC hierarchy to find the topmost presented view controller.
    /// This is required on iOS 26 / SwiftUI where the root VC may have
    /// presented children that Google Sign-In needs to present on top of.
    private func topmostViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let root = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController
        else { return nil }
        
        return topmost(of: root)
    }
    
    private func topmost(of vc: UIViewController) -> UIViewController {
        if let presented = vc.presentedViewController {
            return topmost(of: presented)
        }
        if let nav = vc as? UINavigationController, let visible = nav.visibleViewController {
            return topmost(of: visible)
        }
        if let tab = vc as? UITabBarController, let selected = tab.selectedViewController {
            return topmost(of: selected)
        }
        return vc
    }
    
    // MARK: - Apple Sign In Handler
    
    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                errorMessage = "Invalid credential type received"
                return
            }
            
            isSigningInWithApple = true
            
            Task {
                defer { isSigningInWithApple = false }
                do {
                    try await authService.signInWithApple(credential: credential)
                    // Success - AuthService will update state
                } catch let error as AuthError {
                    // Don't show error for user cancellation
                    if case .invalidCredential(let message) = error,
                       message.contains("cancelled") {
                        // User cancelled, do nothing
                    } else {
                        errorMessage = error.localizedDescription
                    }
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
            
        case .failure(let error):
            // Check if user cancelled
            if let authError = error as? ASAuthorizationError,
               authError.code == .canceled {
                // User cancelled, don't show error
                return
            }
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Google Logo Mark

/// A simple SwiftUI recreation of the Google "G" logo using coloured arcs.
/// Avoids the need for an image asset while remaining recognisable.
private struct GoogleLogoMark: View {
    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let r = size / 2
            
            ZStack {
                // Blue arc (right portion)
                ArcSegment(startAngle: -30, endAngle: 30, color: Color(red: 0.26, green: 0.52, blue: 0.96))
                // Red arc (top-left)
                ArcSegment(startAngle: 150, endAngle: 270, color: Color(red: 0.92, green: 0.26, blue: 0.21))
                // Yellow arc (bottom-left)
                ArcSegment(startAngle: 270, endAngle: 330, color: Color(red: 0.99, green: 0.74, blue: 0.02))
                // Green arc (bottom-right)
                ArcSegment(startAngle: 30, endAngle: 150, color: Color(red: 0.20, green: 0.66, blue: 0.33))
                
                // White inner circle (creates the ring)
                Circle()
                    .fill(Color(.systemBackground))
                    .frame(width: size * 0.55, height: size * 0.55)
                
                // Blue bar for the cross-bar of the G
                Rectangle()
                    .fill(Color(red: 0.26, green: 0.52, blue: 0.96))
                    .frame(width: r * 0.95, height: size * 0.22)
                    .offset(x: r * 0.22)
            }
        }
    }
}

private struct ArcSegment: View {
    let startAngle: Double
    let endAngle: Double
    let color: Color
    
    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            Path { path in
                let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                path.move(to: center)
                path.addArc(
                    center: center,
                    radius: size / 2,
                    startAngle: .degrees(startAngle),
                    endAngle: .degrees(endAngle),
                    clockwise: false
                )
                path.closeSubpath()
            }
            .fill(color)
        }
    }
}

// MARK: - Preview

#Preview {
    AuthenticationView()
        .withMockServices()
}
