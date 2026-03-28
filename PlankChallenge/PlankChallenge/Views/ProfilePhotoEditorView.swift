import SwiftUI
import PhotosUI

/// A sheet that lets the user pick and upload a profile photo.
///
/// Presents a photo picker, previews the selected image, and
/// uploads it via MediaService when the user taps "Save".
struct ProfilePhotoEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.authService) private var authService
    @Environment(\.userService) private var userService
    @Environment(\.mediaService) private var mediaService
    @Environment(\.leaderboardService) private var leaderboardService
    
    /// Existing profile image URL (shown as the current photo)
    let currentImageUrl: String?
    
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var isUploading = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()
                
                // Current / selected photo preview
                photoPreview
                
                // Photo picker
                PhotosPicker(
                    selection: $selectedItem,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    Label("Choose Photo", systemImage: "photo.on.rectangle")
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.appAccent)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.appAccent, lineWidth: 1.5)
                        )
                }
                
                // Remove photo button (only when there's a current photo and nothing new selected)
                if currentImageUrl != nil && selectedImage == nil {
                    Button(role: .destructive) {
                        removePhoto()
                    } label: {
                        Label("Remove Photo", systemImage: "trash")
                            .font(.subheadline)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Profile Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isUploading)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    if isUploading {
                        ProgressView()
                    } else {
                        Button("Save") {
                            Task { await uploadPhoto() }
                        }
                        .disabled(selectedImage == nil || isUploading)
                        .fontWeight(.semibold)
                    }
                }
            }
            .onChange(of: selectedItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        selectedImage = image
                    }
                }
            }
            .alert("Upload Failed", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .interactiveDismissDisabled(isUploading)
        }
    }
    
    // MARK: - Photo Preview
    
    @ViewBuilder
    private var photoPreview: some View {
        ZStack {
            // Show selected image first, then current URL, then placeholder
            if let selected = selectedImage {
                Image(uiImage: selected)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 120, height: 120)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.appAccent, lineWidth: 2))
            } else if let urlString = currentImageUrl, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 120, height: 120)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.appAccent, lineWidth: 2))
                    case .failure, .empty:
                        avatarPlaceholder
                    @unknown default:
                        avatarPlaceholder
                    }
                }
            } else {
                avatarPlaceholder
            }
        }
        .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 3)
    }
    
    private var avatarPlaceholder: some View {
        Circle()
            .fill(LinearGradient.avatarGradient)
            .frame(width: 120, height: 120)
            .overlay {
                let initial = (userService.currentUserProfile?.displayName
                               ?? authService.currentUser?.displayName
                               ?? "?").prefix(1)
                Text(String(initial))
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundStyle(.white)
            }
    }
    
    // MARK: - Actions
    
    private func uploadPhoto() async {
        guard let image = selectedImage else { return }
        
        isUploading = true
        defer { isUploading = false }
        
        do {
            let newUrl = try await mediaService.uploadAvatar(image: image)
            // Refresh user profile to pick up the new URL
            try? await userService.fetchProfile()
            // Avatar changed — mark leaderboard stale so the user's entry
            // shows the updated avatar on next leaderboard view
            leaderboardService.markStale()
            dismiss()
        } catch let error as MediaServiceError {
            errorMessage = error.localizedDescription
            showingError = true
        } catch {
            errorMessage = "Something went wrong. Please try again."
            showingError = true
        }
    }
    
    private func removePhoto() {
        Task {
            isUploading = true
            defer { isUploading = false }
            
            do {
                try await mediaService.deleteAvatar()
                try? await userService.fetchProfile()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
}

#Preview {
    ProfilePhotoEditorView(currentImageUrl: nil)
        .withMockServices()
}
