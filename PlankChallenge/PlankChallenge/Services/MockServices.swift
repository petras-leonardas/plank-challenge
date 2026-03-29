#if DEBUG
import AuthenticationServices
import SwiftUI

// MARK: - Mock PlankService

@Observable @MainActor
final class MockPlankService: PlankServiceProtocol {
    var planks: [APIPlankSession] = []
    var isLoading: Bool = false
    var hasLoaded: Bool = true
    var error: PlankServiceError? = nil
    var todaysPlank: APIPlankSession? = nil
    var hasPlankToday: Bool = false
    var todayPlankCountFromServer: Int = 0
    var totalPlanks: Int = 0
    var totalPlankTime: TimeInterval = 0
    var longestPlank: APIPlankSession? { planks.max(by: { $0.durationSeconds < $1.durationSeconds }) }

    func fetchPlanks(refresh: Bool) async throws { }
    func createPlank(durationSeconds: Double, inputMethod: APIInputMethod) async throws -> CreatePlankResponse {
        fatalError("MockPlankService.createPlank not implemented — override for specific test scenarios")
    }
    func deletePlank(_ plankId: String) async throws -> PlankDeleteResponse {
        planks.removeAll { $0.id == plankId }
        fatalError("MockPlankService.deletePlank not implemented — override for specific test scenarios")
    }
    func clearData() {
        planks = []
        error = nil
        hasLoaded = false
    }
    func clearError() { error = nil }
}

// MARK: - Mock StreakService

@Observable @MainActor
final class MockStreakService: StreakServiceProtocol {
    var isLoading: Bool = false
    var hasLoaded: Bool = true
    var error: StreakServiceError? = nil
    var currentStreak: Int = 14
    var longestStreak: Int = 30
    var freezeTokens: Int = 2
    var hasPlankkedToday: Bool = false
    var usedFreezeToday: Bool = false
    var streakProtectedToday: Bool = false
    var isStreakAtRisk: Bool = false
    var isStreakActive: Bool = true
    var lastPlankDate: String? = nil
    var todayActivity: StreakMeResponse.TodayActivity? = nil
    var recentActivity: [StreakMeResponse.DayActivity] = []

    func fetchStreak() async throws { }
    func useFreeze() async throws -> UseFreezeResponse {
        fatalError("MockStreakService.useFreeze not implemented")
    }
    func fetchHistory() async throws { }
    func applyInlineStreakUpdate(current: Int, longest: Int) {
        currentStreak = current
        longestStreak = max(longest, longestStreak)
    }
    func clearData() {
        currentStreak = 0
        longestStreak = 0
        error = nil
        hasLoaded = false
    }
    func clearError() { error = nil }
}

// MARK: - Mock BadgeService

@Observable @MainActor
final class MockBadgeService: BadgeServiceProtocol {
    var earnedBadges: [APIBadge] = []
    var availableBadges: [APIBadgeWithProgress] = []
    var isLoading: Bool = false
    var hasLoaded: Bool = true
    var error: BadgeServiceError? = nil
    var earnedCount: Int = 0
    var totalCount: Int = 0

    func fetchBadges() async throws { }
    func fetchAvailableBadges() async throws { }
    func hasBadge(_ badgeType: String) -> Bool { false }
    func clearData() {
        earnedBadges = []
        availableBadges = []
        error = nil
        hasLoaded = false
    }
    func clearError() { error = nil }
}

// MARK: - Mock UserService

@Observable @MainActor
final class MockUserService: UserServiceProtocol {
    var currentUserProfile: APIUser? = nil
    var searchResults: [APIPublicUser] = []
    var suggestedUsers: [UserService.SuggestedUser] = []
    var followers: [APIPublicUser] = []
    var following: [APIPublicUser] = []
    var isLoading: Bool = false
    var isSearching: Bool = false
    var hasLoaded: Bool = true
    var error: UserServiceError? = nil

    func fetchProfile() async throws { }
    @discardableResult
    func updateProfile(displayName: String?, location: String?, bio: String?, preferredPlankType: String?, plankGoalSeconds: Int?) async throws -> APIUser {
        fatalError("MockUserService.updateProfile not implemented")
    }
    func refreshCurrentUserProfile() async { }
    func searchUsers(query: String) async throws { }
    func clearSearchResults() { searchResults = [] }
    func fetchSuggestedUsers() async throws { }
    func followUser(id userId: String) async throws { }
    func unfollowUser(id userId: String) async throws { }
    func fetchFollowers(for userId: String) async throws { }
    func fetchFollowing(for userId: String) async throws { }
    func fetchUserProfile(id userId: String) async throws -> APIPublicUser {
        fatalError("MockUserService.fetchUserProfile not implemented")
    }
    func clearData() {
        currentUserProfile = nil
        searchResults = []
        error = nil
        hasLoaded = false
    }
    func clearError() { error = nil }
}

// MARK: - Mock GroupService

@Observable @MainActor
final class MockGroupService: GroupServiceProtocol {
    var myGroups: [APIGroup] = []
    var discoverGroups: [APIGroup] = []
    var currentGroupMembers: [APIGroupMember] = []
    var currentGroupJoinRequests: [APIJoinRequest] = []
    var currentGroup: APIGroup? = nil
    var isLoading: Bool = false
    var hasLoaded: Bool = true
    var error: GroupServiceError? = nil
    var isCurrentUserAdmin: Bool = false
    var isCurrentUserMember: Bool = false

    func fetchMyGroups() async throws { }
    func fetchDiscoverGroups() async throws { }
    func fetchGroup(id groupId: String) async throws -> APIGroup {
        fatalError("MockGroupService.fetchGroup not implemented")
    }
    func isMemberOf(groupId: String) -> Bool { false }
    func fetchGroupMembers(groupId: String) async throws { }
    func joinGroup(id groupId: String) async throws { }
    func leaveGroup(id groupId: String) async throws { }
    func createGroup(name: String, description: String?, groupType: APIGroupType, joinMode: APIJoinMode) async throws -> APIGroup {
        fatalError("MockGroupService.createGroup not implemented")
    }
    func updateGroup(id groupId: String, name: String?, description: String?, joinMode: String?) async throws -> APIGroup {
        fatalError("MockGroupService.updateGroup not implemented")
    }
    func deleteGroup(id groupId: String) async throws { }
    func updateGroupImage(groupId: String, imageUrl: String) { }
    func fetchJoinRequests(groupId: String) async throws { }
    func approveJoinRequest(groupId: String, requestId: String) async throws { }
    func denyJoinRequest(groupId: String, requestId: String) async throws { }
    func clearData() {
        myGroups = []
        discoverGroups = []
        currentGroupJoinRequests = []
        error = nil
        hasLoaded = false
    }
    func clearCurrentGroup() {
        currentGroup = nil
        currentGroupJoinRequests = []
    }
    func clearError() { error = nil }
}

// MARK: - Mock LeaderboardService

@Observable @MainActor
final class MockLeaderboardService: LeaderboardServiceProtocol {
    var globalLeaderboard: [APILeaderboardEntry] = []
    var userGlobalRank: APILeaderboardEntry? = nil
    var currentUserRank: APILeaderboardEntry? { userGlobalRank }
    var globalLeaderboardLongestPlank: [APILeaderboardEntry] = []
    var userLongestPlankRank: APILeaderboardEntry? = nil
    var followingLeaderboard: [APILeaderboardEntry] = []
    var groupLeaderboard: [GroupLeaderboardEntry] = []
    var groupCurrentUserRank: GroupLeaderboardEntry? = nil
    var currentType: LeaderboardService.LeaderboardType = .streak
    var currentPeriod: LeaderboardService.LeaderboardPeriod = .weekly
    var isLoading: Bool = false
    var hasLoaded: Bool = true
    var isStale: Bool = false
    var error: LeaderboardServiceError? = nil

    func fetchGlobalLeaderboard(type: LeaderboardService.LeaderboardType, period: LeaderboardService.LeaderboardPeriod, limit: Int) async throws { }
    func fetchGlobalLeaderboard(metric: LeaderboardService.LeaderboardMetric, period: LeaderboardService.LeaderboardPeriod, limit: Int) async throws { }
    func fetchGlobalLeaderboardBoth(limit: Int) async throws { }
    func fetchFollowingLeaderboard(type: LeaderboardService.LeaderboardType, period: LeaderboardService.LeaderboardPeriod) async throws { }
    func fetchGroupLeaderboard(groupId: String, type: LeaderboardService.LeaderboardType, period: LeaderboardService.LeaderboardPeriod) async throws { }
    func fetchGroupLeaderboard(groupId: String, metric: LeaderboardService.LeaderboardMetric, period: LeaderboardService.LeaderboardPeriod) async throws { }
    func markStale() { isStale = true }
    func clearData() {
        globalLeaderboard = []
        userGlobalRank = nil
        globalLeaderboardLongestPlank = []
        userLongestPlankRank = nil
        followingLeaderboard = []
        groupLeaderboard = []
        groupCurrentUserRank = nil
        isStale = false
        error = nil
        hasLoaded = false
    }
    func clearError() { error = nil }
}

// MARK: - Mock AuthService

@Observable @MainActor
final class MockAuthService: AuthServiceProtocol {
    var state: AuthService.AuthState = .unauthenticated
    var isLoading: Bool = false
    var error: AuthError? = nil
    var isAuthenticated: Bool = false
    var currentUser: AuthUser? = nil
    var needsOnboarding: Bool = false
    var currentUserId: String? = nil

    func restoreSession() async { }
    func signInWithEmail(email: String, password: String) async throws {
        isAuthenticated = true
    }
    func signUpWithEmail(email: String, password: String, displayName: String) async throws {
        isAuthenticated = true
    }
    func signInWithGoogle(presenting viewController: UIViewController) async throws { isAuthenticated = true }
    func signInWithApple(credential: ASAuthorizationAppleIDCredential) async throws { isAuthenticated = true }
    func signOut() async { isAuthenticated = false }
    func deleteAccount() async throws { isAuthenticated = false }
    func clearError() { error = nil }
}

// MARK: - Mock MediaService

@Observable @MainActor
final class MockMediaService: MediaServiceProtocol {
    var isUploading: Bool = false
    var error: MediaServiceError? = nil

    func uploadAvatar(image: UIImage) async throws -> String {
        return "https://example.com/mock-avatar.jpg"
    }
    func uploadGroupImage(groupId: String, image: UIImage) async throws -> String {
        return "https://example.com/mock-group-image.jpg"
    }
    func deleteAvatar() async throws { }
    func clearData() { error = nil }
    func clearError() { error = nil }
}

// MARK: - Mock InAppNotificationService

@Observable @MainActor
final class MockNotificationService: InAppNotificationServiceProtocol {
    var notifications: [APINotification] = []
    var unreadCount: Int = 0
    var isLoading: Bool = false
    var hasLoaded: Bool = true
    var error: InAppNotificationServiceError? = nil

    func fetchNotifications(force: Bool = false) async throws { }
    func loadMoreNotifications() async throws { }
    func markAsRead(id notificationId: String) async throws { }
    func markAllAsRead() async throws { }
    func markNonActionableAsRead() async { }
    func fetchUnreadCount() async { }
    func clearData() {
        notifications = []
        unreadCount = 0
        error = nil
        hasLoaded = false
    }
    func clearError() { error = nil }
}

// MARK: - Preview Environment Helper

extension View {
    /// Injects all mock services via key-path environment injection.
    /// Use in Xcode Previews to get fully isolated, network-free rendering.
    ///
    /// ```swift
    /// #Preview {
    ///     PlankTimerView()
    ///         .withMockServices()
    /// }
    /// ```
    func withMockServices() -> some View {
        self
            .environment(\.plankService, MockPlankService())
            .environment(\.streakService, MockStreakService())
            .environment(\.badgeService, MockBadgeService())
            .environment(\.userService, MockUserService())
            .environment(\.groupService, MockGroupService())
            .environment(\.leaderboardService, MockLeaderboardService())
            .environment(\.authService, MockAuthService())
            .environment(\.mediaService, MockMediaService())
            .environment(\.notificationService, MockNotificationService())
    }
}

#endif
