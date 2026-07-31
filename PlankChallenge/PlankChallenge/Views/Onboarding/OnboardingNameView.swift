import SwiftUI

/// Onboarding Screen 2 — Display Name
///
/// Asks the user what they'd like to be called on leaderboards and in groups.
/// Pre-fills with the name from Apple/Google if it looks like a real name.
/// Saves via PATCH /users/me before advancing.
struct OnboardingNameView: View {
    let onContinue: () -> Void
    
    @Environment(\.authService) private var authService
    @Environment(\.userService) private var userService
    
    @State private var name: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @FocusState private var isFocused: Bool
    
    private var isValid: Bool {
        name.trimmingCharacters(in: .whitespaces).count >= 2
    }
    
    var body: some View {
        ZStack {
            AnimatedGradientBackground()
            
            VStack(spacing: 0) {
                Spacer()
                
                // Icon
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 60, weight: .thin))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.bottom, 32)
                
                // Headline
                Text("What should we call you?")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 12)
                
                // Subtext
                Text("This shows up on leaderboards and to friends. You can change it any time.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 48)
                
                // Name input card
                VStack(spacing: 0) {
                    TextField("Your name", text: $name)
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .textContentType(.name)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.words)
                        .focused($isFocused)
                        .submitLabel(.done)
                        .onSubmit {
                            if isValid { Task { await saveName() } }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 20)
                }
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 32)
                .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
                
                // Inline error
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red.opacity(0.9))
                        .padding(.top, 12)
                        .padding(.horizontal, 32)
                }
                
                // Character hint
                if !name.isEmpty {
                    Text("\(name.trimmingCharacters(in: .whitespaces).count)/30")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.top, 8)
                }
                
                Spacer()
                Spacer()
                
                // CTA button
                Button {
                    Task { await saveName() }
                } label: {
                    HStack(spacing: 10) {
                        if isSaving {
                            ProgressView().tint(Color.appAccent)
                        } else {
                            Text("Continue")
                        }
                    }
                }
                .buttonStyle(OnboardingPrimaryButtonStyle())
                .padding(.horizontal, 32)
                .disabled(!isValid || isSaving)
                .opacity(isValid ? 1 : 0.6)
                .padding(.bottom, 48)
            }
        }
        .onAppear { prefillName() }
        .onChange(of: name) { _, newValue in
            // Enforce max length
            if newValue.count > 30 {
                name = String(newValue.prefix(30))
            }
            // Clear error as user types
            errorMessage = nil
        }
    }
    
    // MARK: - Actions
    
    /// Pre-fill with Google/Apple provided name if it looks like a real name.
    /// Reject relay email prefixes (random strings like "n6wg5q4qks").
    private func prefillName() {
        let candidate = authService.currentUser?.displayName ?? ""
        
        // Don't prefill if it contains @ (email address) or looks like a relay
        guard !candidate.isEmpty,
              !candidate.contains("@"),
              !candidate.contains("privaterelay"),
              candidate.count >= 2 else {
            // Auto-focus so keyboard appears immediately
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isFocused = true
            }
            return
        }
        
        name = candidate
    }
    
    private func saveName() async {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else { return }
        
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        
        do {
            _ = try await userService.updateProfile(displayName: trimmed, location: nil, bio: nil, preferredPlankType: nil, plankGoalSeconds: nil, reminderEnabled: nil, reminderTime: nil, timezone: nil)
            onContinue()
        } catch {
            errorMessage = "Couldn't save your name. Try again."
        }
    }
}

#Preview {
    OnboardingNameView(onContinue: {})
        .withMockServices()
}
