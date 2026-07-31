import SwiftUI

/// Adaptive email authentication flow presented as a sheet.
///
/// Step 1: User enters their email. The app calls POST /auth/check-email
/// to determine whether the account exists and which auth methods are available.
///
/// Step 2a (account exists, has password): Sign-in form with password field.
/// Step 2b (account exists, Apple/Google only): Message guiding user to OAuth.
/// Step 2c (no account): Sign-up form with name, password, confirm password.
struct EmailContinueView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.authService) private var authService
    
    // MARK: - State
    
    private enum Step {
        case emailEntry
        case signIn
        case oauthRedirect(methods: [String])
        case createAccount
    }
    
    private enum Field: Hashable {
        case email, password, displayName, confirmPassword
    }
    
    @State private var step: Step = .emailEntry
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var displayName = ""
    @State private var errorMessage: String?
    @State private var isSubmitting = false
    
    @FocusState private var focusedField: Field?
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            Form {
                switch step {
                case .emailEntry:
                    emailEntrySection
                case .signIn:
                    signInSection
                case .oauthRedirect(let methods):
                    oauthRedirectSection(methods: methods)
                case .createAccount:
                    createAccountSection
                }
                
                if let error = errorMessage {
                    Section {
                        Label {
                            Text(error)
                                .foregroundStyle(.red)
                        } icon: {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSubmitting)
                }
            }
            .interactiveDismissDisabled(isSubmitting)
            .onAppear { focusedField = .email }
        }
    }
    
    private var navigationTitle: String {
        switch step {
        case .emailEntry: return "Continue with email"
        case .signIn: return "Welcome back"
        case .oauthRedirect: return "Account found"
        case .createAccount: return "Create your account"
        }
    }
    
    // MARK: - Step 1: Email Entry
    
    private var emailEntrySection: some View {
        Group {
            Section {
                TextField("you@example.com", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .email)
                    .submitLabel(.go)
                    .onSubmit { checkEmail() }
            }
            
            Section {
                Button {
                    checkEmail()
                } label: {
                    HStack {
                        Spacer()
                        if isSubmitting {
                            ProgressView().tint(.white)
                        } else {
                            Text("Continue")
                                .fontWeight(.semibold)
                        }
                        Spacer()
                    }
                }
                .listRowBackground(Color.accentColor)
                .foregroundStyle(.white)
                .disabled(!isValidEmail(email) || isSubmitting)
            }
        }
    }
    
    // MARK: - Step 2a: Sign In
    
    private var signInSection: some View {
        Group {
            Section {
                HStack {
                    Text(email)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Change") { goBackToEmail() }
                        .font(.subheadline)
                }
                
                SecureField("Your password", text: $password)
                    .textContentType(.password)
                    .focused($focusedField, equals: .password)
                    .submitLabel(.go)
                    .onSubmit { if canSignIn { signIn() } }
            }
            
            Section {
                Button {
                    signIn()
                } label: {
                    HStack {
                        Spacer()
                        if isSubmitting {
                            ProgressView().tint(.white)
                        } else {
                            Text("Sign In")
                                .fontWeight(.semibold)
                        }
                        Spacer()
                    }
                }
                .listRowBackground(Color.accentColor)
                .foregroundStyle(.white)
                .disabled(!canSignIn || isSubmitting)
            }
            
            Section {
                Button("Forgot password?") { }
                    .disabled(true)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    // MARK: - Step 2b: OAuth Redirect
    
    private func oauthRedirectSection(methods: [String]) -> some View {
        Section {
            VStack(spacing: 16) {
                Image(systemName: "person.badge.shield.checkmark")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
                
                Text(oauthMessage(for: methods))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                
                Button("Back to sign-in options") {
                    dismiss()
                }
                .fontWeight(.medium)
                .padding(.bottom, 8)
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    private func oauthMessage(for methods: [String]) -> String {
        if methods.contains("apple") && methods.contains("google") {
            return "This account uses Apple or Google sign-in. Go back and use one of those options to access your account."
        } else if methods.contains("apple") {
            return "This account uses Apple sign-in. Go back and tap \"Continue with Apple\" to access your account."
        } else {
            return "This account uses Google sign-in. Go back and tap \"Continue with Google\" to access your account."
        }
    }
    
    // MARK: - Step 2c: Create Account
    
    private var createAccountSection: some View {
        Group {
            Section {
                HStack {
                    Text(email)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Change") { goBackToEmail() }
                        .font(.subheadline)
                }
                
                TextField("What should we call you?", text: $displayName)
                    .textContentType(.name)
                    .focused($focusedField, equals: .displayName)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .password }
                
                SecureField("Password (at least 8 characters)", text: $password)
                    .textContentType(.newPassword)
                    .focused($focusedField, equals: .password)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .confirmPassword }
                
                SecureField("Confirm password", text: $confirmPassword)
                    .textContentType(.newPassword)
                    .focused($focusedField, equals: .confirmPassword)
                    .submitLabel(.go)
                    .onSubmit { if canCreateAccount { createAccount() } }
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    validationRow("At least 8 characters", met: password.count >= 8)
                    validationRow("Passwords match", met: !confirmPassword.isEmpty && password == confirmPassword)
                }
                .padding(.top, 4)
            }
            
            Section {
                Button {
                    createAccount()
                } label: {
                    HStack {
                        Spacer()
                        if isSubmitting {
                            ProgressView().tint(.white)
                        } else {
                            Text("Create Account")
                                .fontWeight(.semibold)
                        }
                        Spacer()
                    }
                }
                .listRowBackground(Color.accentColor)
                .foregroundStyle(.white)
                .disabled(!canCreateAccount || isSubmitting)
            }
        }
    }
    
    private func validationRow(_ text: String, met: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: met ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(met ? .green : .secondary)
                .font(.caption)
            Text(text)
                .font(.caption)
                .foregroundStyle(met ? .primary : .secondary)
        }
    }
    
    // MARK: - Validation
    
    private var canSignIn: Bool {
        !password.isEmpty
    }
    
    private var canCreateAccount: Bool {
        !displayName.trimmingCharacters(in: .whitespaces).isEmpty &&
        password.count >= 8 &&
        password == confirmPassword
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        let emailRegex = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return trimmed.range(of: emailRegex, options: .regularExpression) != nil
    }
    
    // MARK: - Actions
    
    private func goBackToEmail() {
        withAnimation {
            step = .emailEntry
            password = ""
            confirmPassword = ""
            displayName = ""
            errorMessage = nil
            focusedField = .email
        }
    }
    
    private func checkEmail() {
        guard isValidEmail(email) else { return }
        
        errorMessage = nil
        isSubmitting = true
        focusedField = nil
        
        Task {
            defer { isSubmitting = false }
            do {
                let trimmed = email.trimmingCharacters(in: .whitespaces)
                let result = try await authService.checkEmail(trimmed)
                
                withAnimation {
                    if !result.exists {
                        step = .createAccount
                        focusedField = .displayName
                    } else if result.methods.contains("email") {
                        step = .signIn
                        focusedField = .password
                    } else {
                        step = .oauthRedirect(methods: result.methods)
                    }
                }
            } catch {
                errorMessage = "Something went wrong. Try again."
            }
        }
    }
    
    private func signIn() {
        guard canSignIn else { return }
        
        errorMessage = nil
        isSubmitting = true
        focusedField = nil
        
        Task {
            defer { isSubmitting = false }
            do {
                try await authService.signInWithEmail(
                    email: email.trimmingCharacters(in: .whitespaces),
                    password: password
                )
                dismiss()
            } catch let error as AuthError {
                errorMessage = error.localizedDescription
            } catch {
                errorMessage = "Something went wrong. Try again."
            }
        }
    }
    
    private func createAccount() {
        guard canCreateAccount else { return }
        
        errorMessage = nil
        isSubmitting = true
        focusedField = nil
        
        Task {
            defer { isSubmitting = false }
            do {
                try await authService.signUpWithEmail(
                    email: email.trimmingCharacters(in: .whitespaces),
                    password: password,
                    displayName: displayName.trimmingCharacters(in: .whitespaces)
                )
                dismiss()
            } catch let error as AuthError {
                errorMessage = error.localizedDescription
            } catch {
                errorMessage = "Something went wrong. Try again."
            }
        }
    }
}

// MARK: - Preview

#Preview {
    EmailContinueView()
        .withMockServices()
}
