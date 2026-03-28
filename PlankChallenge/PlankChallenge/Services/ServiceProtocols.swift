import Foundation
import UIKit
import AuthenticationServices

// MARK: - PlankServiceProtocol

/// Protocol describing the public interface of PlankService.
/// Used as the environment key type to enable mock injection in previews and tests.
@MainActor
protocol PlankServiceProtocol: AnyObject {
    // MARK: State
    var planks: [APIPlankSession] { get }
    var isLoading: Bool { get }
    var hasLoaded: Bool { get }
    var error: PlankServiceError? { get }

    // MARK: Computed
    var todaysPlank: APIPlankSession? { get }
    var hasPlankToday: Bool { get }
    var todayPlankCountFromServer: Int { get }
    var totalPlanks: Int { get }
    var totalPlankTime: TimeInterval { get }
    var longestPlank: APIPlankSession? { get }

    // MARK: Methods
    func fetchPlanks(refresh: Bool) async throws
    func createPlank(durationSeconds: Double, inputMethod: APIInputMethod) async throws -> CreatePlankResponse
    func deletePlank(_ plankId: String) async throws -> PlankDeleteResponse
    func clearData()
    func clearError()
}

// MARK: - StreakServiceProtocol

/// Protocol describing the public interface of StreakService.
@MainActor
protocol StreakServiceProtocol: AnyObject {
    // MARK: State
    var isLoading: Bool { get }
    var hasLoaded: Bool { get }
    var error: StreakServiceError? { get }

    // MARK: Computed (derived from streakData)
    var currentStreak: Int { get }
    var longestStreak: Int { get }
    var freezeTokens: Int { get }
    var hasPlankkedToday: Bool { get }
    var usedFreezeToday: Bool { get }
    var streakProtectedToday: Bool { get }
    var isStreakAtRisk: Bool { get }
    var isStreakActive: Bool { get }
    var lastPlankDate: String? { get }
    var todayActivity: StreakMeResponse.TodayActivity? { get }
    var recentActivity: [StreakMeResponse.DayActivity] { get }

    // MARK: Methods
    func fetchStreak() async throws
    func useFreeze() async throws -> UseFreezeResponse
    func fetchHistory() async throws
    func applyInlineStreakUpdate(current: Int, longest: Int)
    func clearData()
    func clearError()
}

// MARK: - BadgeServiceProtocol

/// Protocol describing the public interface of BadgeService.
@MainActor
protocol BadgeServiceProtocol: AnyObject {
    // MARK: State
    var earnedBadges: [APIBadge] { get }
    var availableBadges: [APIBadgeWithProgress] { get }
    var isLoading: Bool { get }
    var hasLoaded: Bool { get }
    var error: BadgeServiceError? { get }

    // MARK: Computed
    var earnedCount: Int { get }
    var totalCount: Int { get }

    // MARK: Methods
    func fetchBadges() async throws
    func fetchAvailableBadges() async throws
    func hasBadge(_ badgeType: String) -> Bool
    func clearData()
    func clearError()
}

// MARK: - UserServiceProtocol

/// Protocol describing the public interface of UserService.
@MainActor
protocol UserServiceProtocol: AnyObject {
    // MARK: State
    var currentUserProfile: APIUser? { get }
    var searchResults: [APIPublicUser] { get }
    var suggestedUsers: [UserService.SuggestedUser] { get }
    var followers: [APIPublicUser] { get }
    var following: [APIPublicUser] { get }
    var isLoading: Bool { get }
    var isSearching: Bool { get }
    var hasLoaded: Bool { get }
    var error: UserServiceError? { get }

    // MARK: Methods
    func fetchProfile() async throws
    func updateProfile(displayName: String?, location: String?, bio: String?, preferredPlankType: String?) async throws -> APIUser
    func searchUsers(query: String) async throws
    func clearSearchResults()
    func fetchSuggestedUsers() async throws
    func followUser(id userId: String) async throws
    func unfollowUser(id userId: String) async throws
    func fetchFollowers(for userId: String) async throws
    func fetchFollowing(for userId: String) async throws
    func fetchUserProfile(id userId: String) async throws -> APIPublicUser
    func refreshCurrentUserProfile() async
    func clearData()
    func clearError()
}

// MARK: - GroupServiceProtocol

/// Protocol describing the public interface of GroupService.
@MainActor
protocol GroupServiceProtocol: AnyObject {
    // MARK: State
    var myGroups: [APIGroup] { get }
    var discoverGroups: [APIGroup] { get }
    var currentGroupMembers: [APIGroupMember] { get }
    var currentGroup: APIGroup? { get }
    var isLoading: Bool { get }
    var hasLoaded: Bool { get }
    var error: GroupServiceError? { get }

    // MARK: Computed
    var isCurrentUserAdmin: Bool { get }
    var isCurrentUserMember: Bool { get }

    // MARK: Methods
    func fetchMyGroups() async throws
    func fetchDiscoverGroups() async throws
    func fetchGroup(id groupId: String) async throws -> APIGroup
    func isMemberOf(groupId: String) -> Bool
    func fetchGroupMembers(groupId: String) async throws
    func joinGroup(id groupId: String) async throws
    func leaveGroup(id groupId: String) async throws
    func createGroup(name: String, description: String?, groupType: APIGroupType, joinMode: APIJoinMode) async throws -> APIGroup
    func clearData()
    func clearCurrentGroup()
    func clearError()
}

// MARK: - LeaderboardServiceProtocol

/// Protocol describing the public interface of LeaderboardService.
@MainActor
protocol LeaderboardServiceProtocol: AnyObject {
    // MARK: State
    var globalLeaderboard: [APILeaderboardEntry] { get }
    var userGlobalRank: APILeaderboardEntry? { get }
    var currentUserRank: APILeaderboardEntry? { get }
    var followingLeaderboard: [APILeaderboardEntry] { get }
    var groupLeaderboard: [GroupLeaderboardEntry] { get }
    var groupCurrentUserRank: GroupLeaderboardEntry? { get }
    var currentType: LeaderboardService.LeaderboardType { get }
    var currentPeriod: LeaderboardService.LeaderboardPeriod { get }
    var isLoading: Bool { get }
    var hasLoaded: Bool { get }
    var isStale: Bool { get }
    var error: LeaderboardServiceError? { get }

    // MARK: Methods
    func fetchGlobalLeaderboard(type: LeaderboardService.LeaderboardType, period: LeaderboardService.LeaderboardPeriod, limit: Int) async throws
    func fetchGlobalLeaderboard(metric: LeaderboardService.LeaderboardMetric, period: LeaderboardService.LeaderboardPeriod, limit: Int) async throws
    func fetchFollowingLeaderboard(type: LeaderboardService.LeaderboardType, period: LeaderboardService.LeaderboardPeriod) async throws
    func fetchGroupLeaderboard(groupId: String, type: LeaderboardService.LeaderboardType, period: LeaderboardService.LeaderboardPeriod) async throws
    func fetchGroupLeaderboard(groupId: String, metric: LeaderboardService.LeaderboardMetric, period: LeaderboardService.LeaderboardPeriod) async throws
    func markStale()
    func clearData()
    func clearError()
}

// MARK: - AuthServiceProtocol

/// Protocol describing the public interface of AuthService.
@MainActor
protocol AuthServiceProtocol: AnyObject {
    // MARK: State
    var state: AuthService.AuthState { get }
    var isLoading: Bool { get }
    var error: AuthError? { get }

    // MARK: Computed
    var isAuthenticated: Bool { get }
    var currentUser: AuthUser? { get }
    var needsOnboarding: Bool { get }
    var currentUserId: String? { get }

    // MARK: Methods
    func restoreSession() async
    func signInWithEmail(email: String, password: String) async throws
    func signUpWithEmail(email: String, password: String, displayName: String) async throws
    func signInWithGoogle(presenting viewController: UIViewController) async throws
    func signInWithApple(credential: ASAuthorizationAppleIDCredential) async throws
    func signOut() async
    func deleteAccount() async throws
    func clearError()
}

// MARK: - MediaServiceProtocol

/// Protocol describing the public interface of MediaService.
@MainActor
protocol MediaServiceProtocol: AnyObject {
    // MARK: State
    var isUploading: Bool { get }
    var error: MediaServiceError? { get }

    // MARK: Methods
    func uploadAvatar(image: UIImage) async throws -> String
    func uploadGroupImage(groupId: String, image: UIImage) async throws -> String
    func deleteAvatar() async throws
    func clearData()
    func clearError()
}

// MARK: - InAppNotificationServiceProtocol

/// Protocol describing the public interface of InAppNotificationService.
@MainActor
protocol InAppNotificationServiceProtocol: AnyObject {
    // MARK: State
    var notifications: [APINotification] { get }
    var unreadCount: Int { get }
    var isLoading: Bool { get }
    var hasLoaded: Bool { get }
    var error: InAppNotificationServiceError? { get }

    // MARK: Methods
    func fetchNotifications() async throws
    func loadMoreNotifications() async throws
    func markAsRead(id notificationId: String) async throws
    func markAllAsRead() async throws
    func clearData()
    func clearError()
}
