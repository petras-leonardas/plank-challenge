import SwiftUI

/// Email sign up view presented as a sheet
struct EmailSignUpView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.authService) private var authService
    
    @State private var displayName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var errorMessage: String?
    @State private var isSubmitting = false
    
    @FocusState private var focusedField: Field?
    
    private enum Field {
        case displayName
        case email
        case password
        case confirmPassword
    }
    
    private var isFormValid: Bool {
        !displayName.trimmingCharacters(in: .whitespaces).isEmpty &&
        isValidEmail(email) &&
        password.count >= 8 &&
        password == confirmPassword
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        
        // RFC 5322 compliant email regex
        let emailRegex = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return trimmed.range(of: emailRegex, options: .regularExpression) != nil
    }
    
    private var passwordsMatch: Bool {
        confirmPassword.isEmpty || password == confirmPassword
    }
    
    private var passwordLongEnough: Bool {
        password.isEmpty || password.count >= 8
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // User info section
                Section {
                    TextField("What should we call you?", text: $displayName)
                        .textContentType(.name)
                        .focused($focusedField, equals: .displayName)
                        .submitLabel(.next)
                        .onSubmit {
                            focusedField = .email
                        }
                    
                    TextField("you@example.com", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .email)
                        .submitLabel(.next)
                        .onSubmit {
                            focusedField = .password
                        }
                } header: {
                    Text("Your Info")
                }
                
                // Password section
                Section {
                    SecureField("At least 8 characters", text: $password)
                        .textContentType(.newPassword)
                        .focused($focusedField, equals: .password)
                        .submitLabel(.next)
                        .onSubmit {
                            focusedField = .confirmPassword
                        }
                    
                    SecureField("Repeat your password", text: $confirmPassword)
                        .textContentType(.newPassword)
                        .focused($focusedField, equals: .confirmPassword)
                        .submitLabel(.go)
                        .onSubmit {
                            if isFormValid {
                                signUp()
                            }
                        }
                } header: {
                    Text("Password")
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        // Password requirements
                        HStack(spacing: 6) {
                            Image(systemName: passwordLongEnough ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(passwordLongEnough ? .green : .secondary)
                                .font(.caption)
                            Text("At least 8 characters")
                        }
                        
                        HStack(spacing: 6) {
                            Image(systemName: passwordsMatch ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(passwordsMatch ? .green : .secondary)
                                .font(.caption)
                            Text("Passwords match")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                
                // Error message
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
                
                // Sign up button
                Section {
                    Button {
                        signUp()
                    } label: {
                        HStack {
                            Spacer()
                            if isSubmitting {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Create Account")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .listRowBackground(Color.accentColor)
                    .foregroundStyle(.white)
                    .disabled(!isFormValid || isSubmitting)
                }
                
                // Terms notice
                Section {
                    Text("By creating an account, you agree to our Terms of Service and Privacy Policy.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Create Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isSubmitting)
                }
            }
            .interactiveDismissDisabled(isSubmitting)
            .onAppear {
                focusedField = .displayName
            }
        }
    }
    
    // MARK: - Actions
    
    private func signUp() {
        guard isFormValid else { return }
        
        // Validate passwords match
        guard password == confirmPassword else {
            errorMessage = "Passwords don't match"
            return
        }
        
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
                // Success - dismiss the sheet
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
    EmailSignUpView()
        .withMockServices()
}
