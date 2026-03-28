import Foundation
import Observation

/// Service responsible for managing groups
///
/// This service handles:
/// - Fetching user's groups
/// - Discovering new groups
/// - Creating, joining, and leaving groups
/// - Group details and members
///
/// Usage:
/// ```swift
/// @Environment(GroupService.self) private var groupService
///
/// // Fetch user's groups
/// try await groupService.fetchMyGroups()
///
/// // Join a group
/// try await groupService.joinGroup(id: groupId)
/// ```
@Observable
@MainActor
final class GroupService: GroupServiceProtocol {
    
    // MARK: - Singleton
    
    static let shared = GroupService()
    
    // MARK: - State
    
    /// Groups the current user is a member of
    private(set) var myGroups: [APIGroup] = []
    
    /// Discoverable public groups
    private(set) var discoverGroups: [APIGroup] = []
    
    /// Currently selected group's members
    private(set) var currentGroupMembers: [APIGroupMember] = []
    
    /// Current user's membership role for the currently viewed group (nil = not a member)
    private(set) var currentMembershipRole: String?
    
    /// The currently viewed group detail
    private(set) var currentGroup: APIGroup?
    
    /// Whether a fetch operation is in progress
    private(set) var isLoading = false
    
    /// Whether groups have been loaded
    private(set) var hasLoaded = false
    
    /// Current error, if any
    private(set) var error: GroupServiceError?
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Fetch Groups
    
    /// Fetches groups the current user is a member of
    func fetchMyGroups() async throws {
        isLoading = true
        error = nil
        defer { isLoading = false }
        
        do {
            let response: GroupsListResponse = try await APIClient.shared.get("/groups")
            myGroups = response.groups
            hasLoaded = true
        } catch let apiError as APIClientError {
            let serviceError = GroupServiceError.fromAPIError(apiError)
            self.error = serviceError
            throw serviceError
        } catch {
            let serviceError = GroupServiceError.unknown(error.localizedDescription)
            self.error = serviceError
            throw serviceError
        }
    }
    
    /// Fetches public groups available to join
    func fetchDiscoverGroups() async throws {
        isLoading = true
        error = nil
        defer { isLoading = false }
        
        do {
            let response: GroupsListResponse = try await APIClient.shared.get("/groups/discover")
            discoverGroups = response.groups
        } catch let apiError as APIClientError {
            let serviceError = GroupServiceError.fromAPIError(apiError)
            self.error = serviceError
            throw serviceError
        } catch {
            let serviceError = GroupServiceError.unknown(error.localizedDescription)
            self.error = serviceError
            throw serviceError
        }
    }
    
    /// Fetches detailed info for a specific group (also stores membership info)
    /// - Parameter groupId: The group ID
    /// - Returns: The group details
    /// - Throws: `GroupServiceError.validationError` if groupId is invalid
    @discardableResult
    func fetchGroup(id groupId: String) async throws -> APIGroup {
        guard isValidGroupId(groupId) else {
            let serviceError = GroupServiceError.validationError("Invalid group ID")
            self.error = serviceError
            throw serviceError
        }
        
        isLoading = true
        error = nil
        defer { isLoading = false }
        
        do {
            let response: GroupDetailResponse = try await APIClient.shared.get("/groups/\(groupId)")
            currentGroup = response.group
            currentMembershipRole = response.membership?.role
            return response.group
        } catch let apiError as APIClientError {
            let serviceError = GroupServiceError.fromAPIError(apiError)
            self.error = serviceError
            throw serviceError
        } catch {
            let serviceError = GroupServiceError.unknown(error.localizedDescription)
            self.error = serviceError
            throw serviceError
        }
    }
    
    /// Checks if user is a member of the group with given ID
    func isMemberOf(groupId: String) -> Bool {
        myGroups.contains { $0.id == groupId }
    }
    
    /// Checks if user is admin of the currently loaded group
    var isCurrentUserAdmin: Bool {
        currentMembershipRole == "admin" || currentMembershipRole == "owner"
    }
    
    /// Checks if user is a member of the currently loaded group
    var isCurrentUserMember: Bool {
        currentMembershipRole != nil
    }
    
    /// Fetches members of a group
    /// - Parameter groupId: The group ID
    /// - Throws: `GroupServiceError.validationError` if groupId is invalid
    func fetchGroupMembers(groupId: String) async throws {
        guard isValidGroupId(groupId) else {
            let serviceError = GroupServiceError.validationError("Invalid group ID")
            self.error = serviceError
            throw serviceError
        }
        
        isLoading = true
        error = nil
        defer { isLoading = false }
        
        do {
            let response: GroupMembersResponse = try await APIClient.shared.get("/groups/\(groupId)/members")
            currentGroupMembers = response.members
        } catch let apiError as APIClientError {
            let serviceError = GroupServiceError.fromAPIError(apiError)
            self.error = serviceError
            throw serviceError
        } catch {
            let serviceError = GroupServiceError.unknown(error.localizedDescription)
            self.error = serviceError
            throw serviceError
        }
    }
    
    // MARK: - Join/Leave
    
    /// Joins a group
    /// - Parameter groupId: The group ID to join
    /// - Throws: `GroupServiceError.validationError` if groupId is invalid
    func joinGroup(id groupId: String) async throws {
        guard isValidGroupId(groupId) else {
            let serviceError = GroupServiceError.validationError("Invalid group ID")
            self.error = serviceError
            throw serviceError
        }
        
        error = nil
        
        do {
            let _: JoinLeaveResponse = try await APIClient.shared.post("/groups/\(groupId)/join", body: EmptyGroupBody())
            
            // Refresh my groups list
            try await fetchMyGroups()
            
            // Remove from discover list if present
            discoverGroups.removeAll { $0.id == groupId }
            
        } catch let apiError as APIClientError {
            let serviceError = GroupServiceError.fromAPIError(apiError)
            self.error = serviceError
            throw serviceError
        } catch {
            let serviceError = GroupServiceError.unknown(error.localizedDescription)
            self.error = serviceError
            throw serviceError
        }
    }
    
    /// Leaves a group
    /// - Parameter groupId: The group ID to leave
    /// - Throws: `GroupServiceError.validationError` if groupId is invalid
    func leaveGroup(id groupId: String) async throws {
        guard isValidGroupId(groupId) else {
            let serviceError = GroupServiceError.validationError("Invalid group ID")
            self.error = serviceError
            throw serviceError
        }
        
        error = nil
        
        do {
            let _: JoinLeaveResponse = try await APIClient.shared.post("/groups/\(groupId)/leave", body: EmptyGroupBody())
            
            // Remove from my groups list
            myGroups.removeAll { $0.id == groupId }
            
        } catch let apiError as APIClientError {
            let serviceError = GroupServiceError.fromAPIError(apiError)
            self.error = serviceError
            throw serviceError
        } catch {
            let serviceError = GroupServiceError.unknown(error.localizedDescription)
            self.error = serviceError
            throw serviceError
        }
    }
    
    // MARK: - Create Group
    
    /// Creates a new group
    /// - Parameters:
    ///   - name: Group name (1-100 characters, cannot be empty or whitespace only)
    ///   - description: Group description (optional, max 500 characters)
    ///   - groupType: Type of group (community, friends, workplace)
    ///   - joinMode: How users can join (open, approval, invite_only)
    /// - Returns: The created group
    /// - Throws: `GroupServiceError.validationError` if inputs are invalid
    @discardableResult
    func createGroup(
        name: String,
        description: String?,
        groupType: APIGroupType = .public,
        joinMode: APIJoinMode = .open
    ) async throws -> APIGroup {
        // Validate group name
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else {
            let serviceError = GroupServiceError.validationError("Group name cannot be empty")
            self.error = serviceError
            throw serviceError
        }
        guard trimmedName.count <= 100 else {
            let serviceError = GroupServiceError.validationError("Group name must be 100 characters or less")
            self.error = serviceError
            throw serviceError
        }
        
        // Validate description if provided
        if let description = description, !description.isEmpty {
            guard description.count <= 500 else {
                let serviceError = GroupServiceError.validationError("Description must be 500 characters or less")
                self.error = serviceError
                throw serviceError
            }
        }
        
        isLoading = true
        error = nil
        defer { isLoading = false }
        
        let request = CreateGroupRequest(
            name: trimmedName,
            description: description?.trimmingCharacters(in: .whitespaces),
            groupType: groupType.rawValue,
            joinMode: joinMode.rawValue
        )
        
        do {
            let response: GroupDetailResponse = try await APIClient.shared.post("/groups", body: request)
            
            // Add to my groups
            myGroups.insert(response.group, at: 0)
            
            return response.group
            
        } catch let apiError as APIClientError {
            let serviceError = GroupServiceError.fromAPIError(apiError)
            self.error = serviceError
            throw serviceError
        } catch {
            let serviceError = GroupServiceError.unknown(error.localizedDescription)
            self.error = serviceError
            throw serviceError
        }
    }
    
    // MARK: - Validation Helpers
    
    /// Validates that a group ID is safe to use in URL paths
    /// - Parameter groupId: The group ID to validate
    /// - Returns: True if the ID is valid (alphanumeric, hyphens, underscores only)
    private func isValidGroupId(_ groupId: String) -> Bool {
        guard !groupId.isEmpty else { return false }
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        return groupId.unicodeScalars.allSatisfy { allowedCharacters.contains($0) }
    }
    
    /// Patches the imageUrl of a group in the in-memory lists without a network call.
    /// Call this immediately after a successful group image upload so the list
    /// reflects the new photo without requiring a full re-fetch.
    func updateGroupImage(groupId: String, imageUrl: String) {
        // APIGroup is a struct so we must replace the whole value
        myGroups = myGroups.map { group in
            guard group.id == groupId else { return group }
            return APIGroup(
                id: group.id, name: group.name, description: group.description,
                imageUrl: imageUrl, groupType: group.groupType, joinMode: group.joinMode,
                memberCount: group.memberCount, createdBy: group.createdBy,
                inviteCode: group.inviteCode, createdAt: group.createdAt,
                updatedAt: group.updatedAt
            )
        }
        // Also patch currentGroup if it happens to be the same group
        if currentGroup?.id == groupId {
            currentGroup = myGroups.first { $0.id == groupId }
        }
    }

    /// Clears local data (call on logout)
    func clearData() {
        myGroups = []
        discoverGroups = []
        currentGroupMembers = []
        currentMembershipRole = nil
        currentGroup = nil
        hasLoaded = false
        error = nil
    }
    
    /// Clears current group selection (call when navigating away from detail view)
    func clearCurrentGroup() {
        currentGroup = nil
        currentMembershipRole = nil
        currentGroupMembers = []
    }
    
    // MARK: - Error Handling
    
    func clearError() {
        error = nil
    }
}

// MARK: - Request/Response Types

private struct EmptyGroupBody: Encodable {}

private struct JoinLeaveResponse: Decodable {
    let success: Bool
}

private struct GroupMembersResponse: Decodable {
    let members: [APIGroupMember]
    let pagination: PaginationMeta?
}

// MARK: - Group Service Errors

enum GroupServiceError: LocalizedError, Equatable {
    case unauthorized
    case notFound
    case groupFull
    case alreadyMember
    case notMember
    case cannotLeaveOwnGroup
    case validationError(String)
    case networkError(String)
    case serverError(String)
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Please sign in to continue."
        case .notFound:
            return "Group not found."
        case .groupFull:
            return "This group is full."
        case .alreadyMember:
            return "You're already a member of this group."
        case .notMember:
            return "You're not a member of this group."
        case .cannotLeaveOwnGroup:
            return "You cannot leave a group you created. Transfer ownership first."
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
    
    static func fromAPIError(_ error: APIClientError) -> GroupServiceError {
        switch error {
        case .unauthorized:
            return .unauthorized
            
        case .networkError(let underlyingError):
            return .networkError(underlyingError.localizedDescription)
            
        case .apiError(let apiError):
            switch apiError.error.code {
            case "NOT_FOUND":
                return .notFound
            case "GROUP_FULL":
                return .groupFull
            case "ALREADY_MEMBER":
                return .alreadyMember
            default:
                return .serverError(apiError.error.message)
            }
            
        default:
            return .unknown(error.localizedDescription)
        }
    }
}
