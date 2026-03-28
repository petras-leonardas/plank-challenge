import SwiftUI

/// Email sign in view presented as a sheet
struct EmailSignInView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.authService) private var authService
    
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var isSubmitting = false
    
    @FocusState private var focusedField: Field?
    
    private enum Field {
        case email
        case password
    }
    
    private var isFormValid: Bool {
        isValidEmail(email) && !password.isEmpty
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        
        // RFC 5322 compliant email regex
        let emailRegex = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return trimmed.range(of: emailRegex, options: .regularExpression) != nil
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Email and password fields
                Section {
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
                    
                    SecureField("Your password", text: $password)
                        .textContentType(.password)
                        .focused($focusedField, equals: .password)
                        .submitLabel(.go)
                        .onSubmit {
                            if isFormValid {
                                signIn()
                            }
                        }
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
                
                // Sign in button
                Section {
                    Button {
                        signIn()
                    } label: {
                        HStack {
                            Spacer()
                            if isSubmitting {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Sign In")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .listRowBackground(Color.accentColor)
                    .foregroundStyle(.white)
                    .disabled(!isFormValid || isSubmitting)
                }
                
                // Forgot password hint
                Section {
                    Text("Forgot your password? Sign in with Apple or Google if you linked your account.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Sign in")
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
                focusedField = .email
            }
        }
    }
    
    // MARK: - Actions
    
    private func signIn() {
        guard isFormValid else { return }
        
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
                // Success - dismiss the sheet
                dismiss()
            } catch let error as AuthError {
                errorMessage = error.localizedDescription
            } catch {
                errorMessage = "Check your email and password and try again."
            }
        }
    }
}

// MARK: - Preview

#Preview {
    EmailSignInView()
        .withMockServices()
}
