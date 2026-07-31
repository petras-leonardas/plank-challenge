import Foundation
import Observation

/// Service responsible for user profile and social features
///
/// This service handles:
/// - User profile management (fetch, update)
/// - Following/unfollowing users
/// - User search and discovery
/// - Fetching followers/following lists
///
/// Usage:
/// ```swift
/// @Environment(UserService.self) private var userService
///
/// // Update profile
/// try await userService.updateProfile(displayName: "New Name")
///
/// // Search users
/// try await userService.searchUsers(query: "john")
///
/// // Follow a user
/// try await userService.followUser(id: userId)
/// ```
@Observable
@MainActor
final class UserService: UserServiceProtocol {
    
    // MARK: - Singleton
    
    static let shared = UserService()
    
    // MARK: - State
    
    /// The current user's full profile (fetched from /users/me)
    private(set) var currentUserProfile: APIUser?
    
    /// Search results
    private(set) var searchResults: [APIPublicUser] = []
    
    /// Suggested users to follow
    private(set) var suggestedUsers: [SuggestedUser] = []
    
    /// Followers list
    private(set) var followers: [APIPublicUser] = []
    
    /// Following list
    private(set) var following: [APIPublicUser] = []
    
    /// Whether a fetch/update operation is in progress
    private(set) var isLoading = false
    
    /// Whether a search is in progress
    private(set) var isSearching = false
    
    /// Whether the initial profile has been loaded
    private(set) var hasLoaded = false
    
    /// Current error, if any
    private(set) var error: UserServiceError?
    
    // MARK: - Types
    
    /// A user suggested for following with reason
    struct SuggestedUser: Identifiable, Equatable {
        let user: APIPublicUser
        let suggestionReason: String
        let mutualFollows: Int
        
        var id: String { user.id }
        
        static func == (lhs: SuggestedUser, rhs: SuggestedUser) -> Bool {
            lhs.user.id == rhs.user.id &&
            lhs.suggestionReason == rhs.suggestionReason &&
            lhs.mutualFollows == rhs.mutualFollows
        }
    }
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Profile Methods
    
    /// Fetches the current user's full profile
    func fetchProfile() async throws {
        isLoading = true
        error = nil
        defer { isLoading = false }
        
        do {
            // GET /users/me returns the APIUser directly in `data`,
            // not nested under a `user` key — decode as APIUser directly.
            let user: APIUser = try await APIClient.shared.get("/users/me")
            currentUserProfile = user
            hasLoaded = true
        } catch let apiError as APIClientError {
            let serviceError = UserServiceError.fromAPIError(apiError)
            self.error = serviceError
            throw serviceError
        } catch {
            let serviceError = UserServiceError.unknown(error.localizedDescription)
            self.error = serviceError
            throw serviceError
        }
    }
    
    /// Updates the current user's profile
    /// - Parameters:
    ///   - displayName: New display name (optional)
    ///   - location: New location (optional, pass nil to clear)
    ///   - bio: New bio (optional, pass nil to clear)
    ///   - preferredPlankType: New preferred plank type (optional)
    /// - Returns: The updated user profile
    @discardableResult
    func updateProfile(
        displayName: String? = nil,
        location: String? = nil,
        bio: String? = nil,
        preferredPlankType: String? = nil,
        plankGoalSeconds: Int? = nil,
        reminderEnabled: Bool? = nil,
        reminderTime: String? = nil,
        timezone: String? = nil
    ) async throws -> APIUser {
        isLoading = true
        error = nil
        defer { isLoading = false }
        
        let request = UpdateProfileRequest(
            displayName: displayName,
            location: location,
            bio: bio,
            preferredPlankType: preferredPlankType,
            timezone: timezone,
            plankGoalSeconds: plankGoalSeconds,
            reminderEnabled: reminderEnabled,
            reminderTime: reminderTime
        )
        
        do {
            // PATCH /users/me returns the updated APIUser directly in `data`,
            // not nested under a `user` key — decode as APIUser directly.
            let updatedUser: APIUser = try await APIClient.shared.patch("/users/me", body: request)
            currentUserProfile = updatedUser
            return updatedUser
        } catch let apiError as APIClientError {
            let serviceError = UserServiceError.fromAPIError(apiError)
            self.error = serviceError
            throw serviceError
        } catch {
            let serviceError = UserServiceError.unknown(error.localizedDescription)
            self.error = serviceError
            throw serviceError
        }
    }
    
    // MARK: - Search
    
    /// Searches for users by name or username
    /// - Parameter query: Search query (minimum 2 characters)
    func searchUsers(query: String) async throws {
        guard query.count >= 2 else {
            searchResults = []
            return
        }
        
        isSearching = true
        error = nil
        defer { isSearching = false }
        
        do {
            let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
            let response: UserSearchResponse = try await APIClient.shared.get("/users/search?q=\(encodedQuery)")
            searchResults = response.users
        } catch let apiError as APIClientError {
            let serviceError = UserServiceError.fromAPIError(apiError)
            self.error = serviceError
            throw serviceError
        } catch {
            let serviceError = UserServiceError.unknown(error.localizedDescription)
            self.error = serviceError
            throw serviceError
        }
    }
    
    /// Clears search results
    func clearSearchResults() {
        searchResults = []
    }
    
    // MARK: - Discover
    
    /// Fetches suggested users to follow
    func fetchSuggestedUsers() async throws {
        isLoading = true
        error = nil
        defer { isLoading = false }
        
        do {
            let response: DiscoverUsersResponse = try await APIClient.shared.get("/users/discover")
            suggestedUsers = response.users.map { suggested in
                SuggestedUser(
                    user: suggested.toPublicUser(),
                    suggestionReason: suggested.suggestionReason,
                    mutualFollows: suggested.mutualFollows
                )
            }
        } catch let apiError as APIClientError {
            let serviceError = UserServiceError.fromAPIError(apiError)
            self.error = serviceError
            throw serviceError
        } catch {
            let serviceError = UserServiceError.unknown(error.localizedDescription)
            self.error = serviceError
            throw serviceError
        }
    }
    
    // MARK: - Follow/Unfollow
    
    /// Follows a user
    /// - Parameter userId: The ID of the user to follow
    /// - Throws: `UserServiceError.validationError` if userId is invalid
    func followUser(id userId: String) async throws {
        // Validate user ID to prevent path injection
        guard isValidUserId(userId) else {
            let serviceError = UserServiceError.validationError("Invalid user ID")
            self.error = serviceError
            throw serviceError
        }
        
        error = nil
        
        do {
            let response: FollowResponse = try await APIClient.shared.post("/users/\(userId)/follow", body: EmptyBody())
            
            // Verify the response confirms we're now following
            guard response.following else {
                // Unexpected state - log but don't fail
                #if DEBUG
                print("[UserService] Warning: Follow API returned following=false")
                #endif
                return
            }
            
            // Update local state atomically using helper methods
            updateUserFollowState(userId: userId, isFollowing: true, followerDelta: 1)
            
            // Refresh current user's profile to sync followingCount in YOUR COMMUNITY tile
            await refreshCurrentUserProfile()
            
            // Add to following list — find the user from any cached collection
            if !following.contains(where: { $0.id == userId }) {
                if let user = searchResults.first(where: { $0.id == userId }) {
                    following.insert(user, at: 0)
                } else if let suggestion = suggestedUsers.first(where: { $0.user.id == userId }) {
                    following.insert(suggestion.user, at: 0)
                }
            }
        } catch let apiError as APIClientError {
            let serviceError = UserServiceError.fromAPIError(apiError)
            self.error = serviceError
            throw serviceError
        } catch {
            let serviceError = UserServiceError.unknown(error.localizedDescription)
            self.error = serviceError
            throw serviceError
        }
    }
    
    /// Unfollows a user
    /// - Parameter userId: The ID of the user to unfollow
    /// - Throws: `UserServiceError.validationError` if userId is invalid
    func unfollowUser(id userId: String) async throws {
        // Validate user ID to prevent path injection
        guard isValidUserId(userId) else {
            let serviceError = UserServiceError.validationError("Invalid user ID")
            self.error = serviceError
            throw serviceError
        }
        
        error = nil
        
        do {
            let response: FollowResponse = try await APIClient.shared.delete("/users/\(userId)/follow")
            
            // Verify the response confirms we're no longer following
            guard !response.following else {
                #if DEBUG
                print("[UserService] Warning: Unfollow API returned following=true")
                #endif
                return
            }
            
            // Update local state atomically using helper methods
            updateUserFollowState(userId: userId, isFollowing: false, followerDelta: -1)
            
            // Refresh current user's profile to sync followingCount in YOUR COMMUNITY tile
            await refreshCurrentUserProfile()
            
            // Remove from following list
            following.removeAll { $0.id == userId }
        } catch let apiError as APIClientError {
            let serviceError = UserServiceError.fromAPIError(apiError)
            self.error = serviceError
            throw serviceError
        } catch {
            let serviceError = UserServiceError.unknown(error.localizedDescription)
            self.error = serviceError
            throw serviceError
        }
    }
    
    // MARK: - Followers/Following
    
    /// Fetches followers for a user
    /// - Parameter userId: The user ID (use current user's ID for own followers)
    /// - Throws: `UserServiceError.validationError` if userId is invalid
    func fetchFollowers(for userId: String) async throws {
        // Validate user ID to prevent path injection
        guard isValidUserId(userId) else {
            let serviceError = UserServiceError.validationError("Invalid user ID")
            self.error = serviceError
            throw serviceError
        }
        
        isLoading = true
        error = nil
        defer { isLoading = false }
        
        do {
            let response: FollowersResponse = try await APIClient.shared.get("/users/\(userId)/followers")
            followers = response.users
        } catch let apiError as APIClientError {
            let serviceError = UserServiceError.fromAPIError(apiError)
            self.error = serviceError
            throw serviceError
        } catch {
            let serviceError = UserServiceError.unknown(error.localizedDescription)
            self.error = serviceError
            throw serviceError
        }
    }
    
    /// Fetches users that a user follows
    /// - Parameter userId: The user ID (use current user's ID for own following)
    /// - Throws: `UserServiceError.validationError` if userId is invalid
    func fetchFollowing(for userId: String) async throws {
        // Validate user ID to prevent path injection
        guard isValidUserId(userId) else {
            let serviceError = UserServiceError.validationError("Invalid user ID")
            self.error = serviceError
            throw serviceError
        }
        
        isLoading = true
        error = nil
        defer { isLoading = false }
        
        do {
            let response: FollowersResponse = try await APIClient.shared.get("/users/\(userId)/following")
            following = response.users
            #if DEBUG
            print("[UserService] fetchFollowing for \(userId): got \(response.users.count) users")
            #endif
        } catch let apiError as APIClientError {
            #if DEBUG
            if case .decodingError(let decodingError, _) = apiError {
                print("[UserService] fetchFollowing DECODE error: \(decodingError)")
            } else {
                print("[UserService] fetchFollowing API error: \(apiError)")
            }
            #endif
            let serviceError = UserServiceError.fromAPIError(apiError)
            self.error = serviceError
            throw serviceError
        } catch {
            #if DEBUG
            print("[UserService] fetchFollowing unknown error: \(error)")
            #endif
            let serviceError = UserServiceError.unknown(error.localizedDescription)
            self.error = serviceError
            throw serviceError
        }
    }
    
    // MARK: - Other User Profiles
    
    /// Fetches a user's public profile
    /// - Parameter userId: The user ID
    /// - Returns: The user's public profile
    /// - Throws: `UserServiceError.validationError` if userId is invalid
    func fetchUserProfile(id userId: String) async throws -> APIPublicUser {
        // Validate user ID to prevent path injection
        guard isValidUserId(userId) else {
            let serviceError = UserServiceError.validationError("Invalid user ID")
            self.error = serviceError
            throw serviceError
        }
        
        error = nil
        
        do {
            // GET /users/:id returns APIPublicUser directly in `data` —
            // not nested under a `user` key. Decode as APIPublicUser directly.
            let user: APIPublicUser = try await APIClient.shared.get("/users/\(userId)")
            return user
        } catch let apiError as APIClientError {
            let serviceError = UserServiceError.fromAPIError(apiError)
            self.error = serviceError
            throw serviceError
        } catch {
            let serviceError = UserServiceError.unknown(error.localizedDescription)
            self.error = serviceError
            throw serviceError
        }
    }
    
    // MARK: - Local State Update Helpers
    
    /// Atomically updates the follow state for a user across all cached collections
    /// - Parameters:
    ///   - userId: The user ID being followed/unfollowed
    ///   - isFollowing: Whether the user is now being followed
    ///   - followerDelta: Change in follower count (+1 for follow, -1 for unfollow)
    private func updateUserFollowState(userId: String, isFollowing: Bool, followerDelta: Int) {
        // Use map to create new arrays atomically, avoiding race conditions
        // from index-based access between reads and writes
        
        // Update search results
        searchResults = searchResults.map { user in
            guard user.id == userId else { return user }
            return APIPublicUser(
                id: user.id,
                displayName: user.displayName,
                username: user.username,
                profileImageUrl: user.profileImageUrl,
                bio: user.bio,
                location: user.location,
                currentStreak: user.currentStreak,
                longestStreak: user.longestStreak,
                totalPlanks: user.totalPlanks,
                longestPlankSeconds: user.longestPlankSeconds,
                followerCount: max(0, user.followerCount + followerDelta),
                followingCount: user.followingCount,
                isFollowing: isFollowing
            )
        }
        
        // Update suggested users
        suggestedUsers = suggestedUsers.map { suggestion in
            guard suggestion.user.id == userId else { return suggestion }
            let updatedUser = APIPublicUser(
                id: suggestion.user.id,
                displayName: suggestion.user.displayName,
                username: suggestion.user.username,
                profileImageUrl: suggestion.user.profileImageUrl,
                bio: suggestion.user.bio,
                location: suggestion.user.location,
                currentStreak: suggestion.user.currentStreak,
                longestStreak: suggestion.user.longestStreak,
                totalPlanks: suggestion.user.totalPlanks,
                longestPlankSeconds: suggestion.user.longestPlankSeconds,
                followerCount: max(0, suggestion.user.followerCount + followerDelta),
                followingCount: suggestion.user.followingCount,
                isFollowing: isFollowing
            )
            return SuggestedUser(
                user: updatedUser,
                suggestionReason: suggestion.suggestionReason,
                mutualFollows: suggestion.mutualFollows
            )
        }
    }
    
    /// Re-fetches the current user's profile from the server to sync counts
    /// after a follow/unfollow action. Non-throwing — failure is silent since
    /// the count will correct itself on the next natural profile load.
    func refreshCurrentUserProfile() async {
        try? await fetchProfile()
    }
    
    // MARK: - Validation Helpers
    
    /// Validates that a user ID is safe to use in URL paths
    /// - Parameter userId: The user ID to validate
    /// - Returns: True if the ID is valid (alphanumeric, hyphens, underscores only)
    private func isValidUserId(_ userId: String) -> Bool {
        // User IDs should be non-empty and contain only safe characters
        // This prevents path traversal and injection attacks
        guard !userId.isEmpty else { return false }
        
        // Allow alphanumeric characters, hyphens, and underscores (common in UUIDs and user IDs)
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        return userId.unicodeScalars.allSatisfy { allowedCharacters.contains($0) }
    }
    
    /// Clears local data (call on logout)
    func clearData() {
        currentUserProfile = nil
        searchResults = []
        suggestedUsers = []
        followers = []
        following = []
        hasLoaded = false
        error = nil
    }
    
    // MARK: - Error Handling
    
    func clearError() {
        error = nil
    }
}

// MARK: - Empty Body for POST requests without body

private struct EmptyBody: Encodable {}

// MARK: - Response Types

/// Response from /users/discover
private struct DiscoverUsersResponse: Decodable {
    let users: [SuggestedUserResponse]
    
    struct SuggestedUserResponse: Decodable {
        let id: String
        let displayName: String
        let username: String?
        let profileImageUrl: String?
        let bio: String?
        let location: String?
        let currentStreak: Int
        let longestStreak: Int
        let totalPlanks: Int
        let longestPlankSeconds: Double
        let followerCount: Int
        let followingCount: Int
        let suggestionReason: String
        let mutualFollows: Int
        
        func toPublicUser() -> APIPublicUser {
            APIPublicUser(
                id: id,
                displayName: displayName,
                username: username,
                profileImageUrl: profileImageUrl,
                bio: bio,
                location: location,
                currentStreak: currentStreak,
                longestStreak: longestStreak,
                totalPlanks: totalPlanks,
                longestPlankSeconds: longestPlankSeconds,
                followerCount: followerCount,
                followingCount: followingCount,
                isFollowing: nil
            )
        }
    }
}

/// Response from follow/unfollow endpoints
private struct FollowResponse: Decodable {
    let following: Bool
}

/// Response from followers/following list endpoints
private struct FollowersResponse: Decodable {
    let users: [APIPublicUser]
    let pagination: PaginationMeta?
}

// MARK: - User Service Errors

enum UserServiceError: LocalizedError, Equatable {
    case unauthorized
    case notFound
    case usernameTaken
    case validationError(String)
    case networkError(String)
    case serverError(String)
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Sign in to continue."
        case .notFound:
            return "User not found."
        case .usernameTaken:
            return "This username is already taken."
        case .validationError(let message):
            return message
        case .networkError(let message):
            return "Network error: \(message)"
        case .serverError(let message):
            return message
        case .unknown(let message):
            return message
        }
    }
    
    static func fromAPIError(_ error: APIClientError) -> UserServiceError {
        switch error {
        case .unauthorized:
            return .unauthorized
            
        case .networkError(let underlyingError):
            return .networkError(underlyingError.localizedDescription)
            
        case .apiError(let apiError):
            switch apiError.error.code {
            case "NOT_FOUND":
                return .notFound
            case "CONFLICT":
                return .usernameTaken
            case "VALIDATION_ERROR":
                return .validationError(apiError.error.message)
            default:
                return .serverError(apiError.error.message)
            }
            
        default:
            return .unknown(error.localizedDescription ?? "An unknown error occurred")
        }
    }
}
