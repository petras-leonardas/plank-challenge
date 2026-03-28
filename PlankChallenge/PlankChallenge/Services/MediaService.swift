import Foundation
import UIKit
import Observation

/// Service responsible for media uploads (profile avatar).
///
/// Usage:
/// ```swift
/// let imageUrl = try await mediaService.uploadAvatar(image: selectedImage)
/// ```
@Observable
@MainActor
final class MediaService: MediaServiceProtocol {
    
    // MARK: - Singleton
    
    static let shared = MediaService()
    
    // MARK: - State
    
    /// Whether an upload is in progress
    private(set) var isUploading = false
    
    /// Current upload error, if any
    private(set) var error: MediaServiceError?
    
    // MARK: - Configuration
    
    /// Maximum avatar size (5 MB after compression)
    private let maxSizeBytes = 5 * 1024 * 1024
    
    /// Target JPEG compression quality (produces ~200-400 KB for most photos)
    private let compressionQuality: CGFloat = 0.75
    
    /// Maximum dimension (width or height) for uploaded avatars
    private let maxDimension: CGFloat = 1024
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Uploads a profile photo to the backend and returns the new URL.
    ///
    /// The image is resized to at most `maxDimension` in either dimension,
    /// then JPEG-compressed before upload.
    ///
    /// - Parameter image: The `UIImage` to upload.
    /// - Returns: The public URL of the uploaded avatar.
    func uploadAvatar(image: UIImage) async throws -> String {
        isUploading = true
        error = nil
        defer { isUploading = false }
        
        do {
            // 1. Resize & compress
            let imageData = try compress(image: image)
            
            // 2. Upload raw binary
            let response: AvatarUploadResponse = try await APIClient.shared.uploadBinary(
                "/media/avatar",
                data: imageData,
                contentType: "image/jpeg"
            )
            
            return response.profileImageUrl
        } catch let mediaError as MediaServiceError {
            self.error = mediaError
            throw mediaError
        } catch {
            let wrapped = MediaServiceError.uploadFailed(error.localizedDescription)
            self.error = wrapped
            throw wrapped
        }
    }
    
    /// Deletes the current profile avatar.
    func deleteAvatar() async throws {
        isUploading = true
        error = nil
        defer { isUploading = false }
        
        do {
            try await APIClient.shared.request(
                endpoint: "/media/avatar",
                method: .delete
            ) as EmptyResponse
        } catch {
            let wrapped = MediaServiceError.uploadFailed(error.localizedDescription)
            self.error = wrapped
            throw wrapped
        }
    }
    
    // MARK: - State Reset
    
    /// Clears all cached state. Called on logout.
    func clearData() {
        error = nil
    }
    
    /// Clears the current error.
    func clearError() {
        error = nil
    }
    
    // MARK: - Private Helpers
    
    /// Resizes and JPEG-compresses the image. Throws if the result exceeds maxSizeBytes.
    private func compress(image: UIImage) throws -> Data {
        // Resize if either dimension exceeds maxDimension
        let resized = resizedImage(image, maxDimension: maxDimension)
        
        guard let data = resized.jpegData(compressionQuality: compressionQuality) else {
            throw MediaServiceError.compressionFailed
        }
        
        if data.count > maxSizeBytes {
            // Try harder compression
            guard let smallerData = resized.jpegData(compressionQuality: 0.5),
                  smallerData.count <= maxSizeBytes else {
                throw MediaServiceError.fileTooLarge(maxSizeMB: maxSizeBytes / (1024 * 1024))
            }
            return smallerData
        }
        
        return data
    }
    
    private func resizedImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        guard size.width > maxDimension || size.height > maxDimension else {
            return image
        }
        
        let scale = min(maxDimension / size.width, maxDimension / size.height)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

// MARK: - Errors

enum MediaServiceError: LocalizedError {
    case compressionFailed
    case fileTooLarge(maxSizeMB: Int)
    case uploadFailed(String)
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .compressionFailed:
            return "Failed to process the selected image."
        case .fileTooLarge(let maxMB):
            return "The image is too large. Please choose an image under \(maxMB) MB."
        case .uploadFailed(let message):
            return "Upload failed: \(message)"
        case .networkError:
            return "Network error. Please check your connection and try again."
        }
    }
}
