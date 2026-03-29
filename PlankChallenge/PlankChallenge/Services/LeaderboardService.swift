import Foundation
import Observation

/// Service responsible for managing leaderboards
///
/// This service handles:
/// - Global leaderboards (streak, total time, longest plank)
/// - Following leaderboards (competition among followed users)
/// - Group leaderboards
///
/// Usage:
/// ```swift
/// @Environment(LeaderboardService.self) private var leaderboardService
///
/// // Fetch global leaderboard
/// try await leaderboardService.fetchGlobalLeaderboard(type: .streak, period: .weekly)
///
/// // Fetch following leaderboard
/// try await leaderboardService.fetchFollowingLeaderboard()
/// ```
@Observable
@MainActor
final class LeaderboardService: LeaderboardServiceProtocol {
    
    // MARK: - Singleton
    
    static let shared = LeaderboardService()
    
    // MARK: - Types
    
    /// Types of leaderboards available.
    /// Raw values match the backend route segment: GET /leaderboards/{rawValue}
    enum LeaderboardType: String, CaseIterable {
        case streak = "streak"
        case totalTime = "total-time"
        case longestPlank = "duration"
        case totalPlanks = "total-planks"
        
        var displayName: String {
            switch self {
            case .streak: return "Streak"
            case .totalTime: return "Total Time"
            case .longestPlank: return "Longest Plank"
            case .totalPlanks: return "Total Planks"
            }
        }
    }
    
    /// Simplified metric type alias for common UI use cases
    enum LeaderboardMetric {
        case streak
        case longestPlank
        
        var leaderboardType: LeaderboardType {
            switch self {
            case .streak: return .streak
            case .longestPlank: return .longestPlank
            }
        }
    }
    
    /// Time periods for leaderboards.
    /// Raw values match the backend's VALID_PERIODS: ['day', 'week', 'month', 'all']
    enum LeaderboardPeriod: String, CaseIterable {
        case weekly = "week"
        case monthly = "month"
        case allTime = "all"
        
        var displayName: String {
            switch self {
            case .weekly: return "This Week"
            case .monthly: return "This Month"
            case .allTime: return "All Time"
            }
        }
    }
    
    // MARK: - State
    
    /// Current global streak leaderboard entries
    private(set) var globalLeaderboard: [APILeaderboardEntry] = []
    
    /// Current user's rank in the global streak leaderboard
    private(set) var userGlobalRank: APILeaderboardEntry?
    
    /// Alias for userGlobalRank for consistency with view naming
    var currentUserRank: APILeaderboardEntry? { userGlobalRank }

    /// Current global longest-plank leaderboard entries
    private(set) var globalLeaderboardLongestPlank: [APILeaderboardEntry] = []

    /// Current user's rank in the global longest-plank leaderboard
    private(set) var userLongestPlankRank: APILeaderboardEntry?
    
    /// Current following leaderboard entries
    private(set) var followingLeaderboard: [APILeaderboardEntry] = []
    
    /// Current group leaderboard entries.
    /// Typed as `GroupLeaderboardEntry` because the group leaderboard endpoint
    /// returns a different shape than the global/following leaderboards.
    private(set) var groupLeaderboard: [GroupLeaderboardEntry] = []
    
    /// The authenticated user's rank in the current group leaderboard
    /// (may be outside the displayed top-N list).
    private(set) var groupCurrentUserRank: GroupLeaderboardEntry?
    
    /// Currently selected leaderboard type
    private(set) var currentType: LeaderboardType = .streak
    
    /// Currently selected time period
    private(set) var currentPeriod: LeaderboardPeriod = .weekly
    
    /// Whether a fetch operation is in progress
    private(set) var isLoading = false
    
    /// Whether leaderboards have been loaded
    private(set) var hasLoaded = false
    
    /// Whether the cached leaderboard data is stale and should be re-fetched
    /// on the next view appearance. Set by mutations that affect the leaderboard
    /// (plank save, plank delete, profile update, avatar update).
    private(set) var isStale = false
    
    /// Current error, if any
    private(set) var error: LeaderboardServiceError?
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Global Leaderboard
    
    /// Fetches the global leaderboard
    /// - Parameters:
    ///   - type: Type of leaderboard (streak, total_time, etc.)
    ///   - period: Time period (daily, weekly, monthly, all_time)
    ///   - limit: Number of entries to fetch (default 50)
    func fetchGlobalLeaderboard(
        type: LeaderboardType = .streak,
        period: LeaderboardPeriod = .weekly,
        limit: Int = 50
    ) async throws {
        try await fetchGlobalLeaderboardInternal(type: type, period: period, limit: limit)
    }
    
    /// Simplified fetch for global leaderboard using metric enum
    func fetchGlobalLeaderboard(
        metric: LeaderboardMetric,
        period: LeaderboardPeriod = .weekly,
        limit: Int = 50
    ) async throws {
        try await fetchGlobalLeaderboardInternal(type: metric.leaderboardType, period: period, limit: limit)
    }

    /// Fetches both the streak and longest-plank leaderboards in parallel.
    /// Used by the Rankings tab to populate both cards simultaneously.
    func fetchGlobalLeaderboardBoth(limit: Int = 5) async throws {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            async let streakResponse: LeaderboardResponse = APIClient.shared.get(
                "/leaderboards/streak?period=all&limit=\(limit)"
            )
            async let longestResponse: LeaderboardResponse = APIClient.shared.get(
                "/leaderboards/duration?period=all&limit=\(limit)"
            )
            let (streak, longest) = try await (streakResponse, longestResponse)
            globalLeaderboard = streak.entries
            userGlobalRank = streak.currentUserRank
            globalLeaderboardLongestPlank = longest.entries
            userLongestPlankRank = longest.currentUserRank
            isStale = false
            hasLoaded = true
        } catch let apiError as APIClientError {
            let serviceError = LeaderboardServiceError.fromAPIError(apiError)
            self.error = serviceError
            throw serviceError
        } catch {
            let serviceError = LeaderboardServiceError.unknown(error.localizedDescription)
            self.error = serviceError
            throw serviceError
        }
    }
    
    private func fetchGlobalLeaderboardInternal(
        type: LeaderboardType,
        period: LeaderboardPeriod,
        limit: Int
    ) async throws {
        isLoading = true
        error = nil
        currentType = type
        currentPeriod = period
        defer { isLoading = false }
        
        do {
            // Route pattern: /leaderboards/{type}?period=...&limit=...
            // e.g. /leaderboards/streak?period=weekly&limit=50
            let response: LeaderboardResponse = try await APIClient.shared.get(
                "/leaderboards/\(type.rawValue)?period=\(period.rawValue)&limit=\(limit)"
            )
            globalLeaderboard = response.entries
            userGlobalRank = response.currentUserRank
            isStale = false
            hasLoaded = true
        } catch let apiError as APIClientError {
            let serviceError = LeaderboardServiceError.fromAPIError(apiError)
            self.error = serviceError
            throw serviceError
        } catch {
            let serviceError = LeaderboardServiceError.unknown(error.localizedDescription)
            self.error = serviceError
            throw serviceError
        }
    }
    
    // MARK: - Following Leaderboard
    
    /// Fetches the leaderboard among users you follow
    /// - Parameters:
    ///   - type: Type of leaderboard (streak, total_time, etc.)
    ///   - period: Time period (daily, weekly, monthly, all_time)
    func fetchFollowingLeaderboard(
        type: LeaderboardType = .streak,
        period: LeaderboardPeriod = .weekly
    ) async throws {
        isLoading = true
        error = nil
        defer { isLoading = false }
        
        do {
            // Backend route: /leaderboards/friends
            // Accepts same type/period params as global leaderboards
            let response: LeaderboardResponse = try await APIClient.shared.get(
                "/leaderboards/friends?type=\(type.rawValue)&period=\(period.rawValue)"
            )
            followingLeaderboard = response.entries
            isStale = false
        } catch let apiError as APIClientError {
            let serviceError = LeaderboardServiceError.fromAPIError(apiError)
            self.error = serviceError
            throw serviceError
        } catch {
            let serviceError = LeaderboardServiceError.unknown(error.localizedDescription)
            self.error = serviceError
            throw serviceError
        }
    }
    
    // MARK: - Group Leaderboard
    
    /// Fetches the leaderboard for a specific group
    /// - Parameters:
    ///   - groupId: The group ID
    ///   - type: Type of leaderboard
    ///   - period: Time period
    /// - Throws: `LeaderboardServiceError.validationError` if groupId is invalid
    func fetchGroupLeaderboard(
        groupId: String,
        type: LeaderboardType = .streak,
        period: LeaderboardPeriod = .weekly
    ) async throws {
        try await fetchGroupLeaderboardInternal(groupId: groupId, type: type, period: period)
    }
    
    /// Simplified fetch for group leaderboard using metric enum
    func fetchGroupLeaderboard(
        groupId: String,
        metric: LeaderboardMetric,
        period: LeaderboardPeriod = .weekly
    ) async throws {
        try await fetchGroupLeaderboardInternal(groupId: groupId, type: metric.leaderboardType, period: period)
    }
    
    private func fetchGroupLeaderboardInternal(
        groupId: String,
        type: LeaderboardType,
        period: LeaderboardPeriod
    ) async throws {
        // Validate group ID to prevent path injection
        guard isValidGroupId(groupId) else {
            let serviceError = LeaderboardServiceError.validationError("Invalid group ID")
            self.error = serviceError
            throw serviceError
        }
        
        isLoading = true
        error = nil
        defer { isLoading = false }
        
        do {
            // Backend route: /groups/:groupId/leaderboard
            // Decodes GroupLeaderboardResponse (not LeaderboardResponse) because
            // the group endpoint returns `stats`/`currentUser` instead of
            // `score`/`scoreLabel`/`isCurrentUser`/`userRank`.
            let response: GroupLeaderboardResponse = try await APIClient.shared.get(
                "/groups/\(groupId)/leaderboard?type=\(type.rawValue)&period=\(period.rawValue)"
            )
            groupLeaderboard = response.leaderboard
            groupCurrentUserRank = response.currentUser
        } catch let apiError as APIClientError {
            let serviceError = LeaderboardServiceError.fromAPIError(apiError)
            self.error = serviceError
            throw serviceError
        } catch {
            let serviceError = LeaderboardServiceError.unknown(error.localizedDescription)
            self.error = serviceError
            throw serviceError
        }
    }
    
    // MARK: - Validation Helpers
    
    /// Validates that a group ID is safe to use in URL paths
    private func isValidGroupId(_ groupId: String) -> Bool {
        guard !groupId.isEmpty else { return false }
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        return groupId.unicodeScalars.allSatisfy { allowedCharacters.contains($0) }
    }
    
    /// Marks the cached leaderboard data as stale.
    /// Called after mutations that may change leaderboard rankings:
    /// plank save, plank delete, profile update, avatar update.
    /// The next time RankingsContent appears it will re-fetch.
    func markStale() {
        isStale = true
    }
    
    /// Clears local data (call on logout)
    func clearData() {
        globalLeaderboard = []
        userGlobalRank = nil
        globalLeaderboardLongestPlank = []
        userLongestPlankRank = nil
        followingLeaderboard = []
        groupLeaderboard = []
        groupCurrentUserRank = nil
        currentType = .streak
        currentPeriod = .weekly
        isStale = false
        hasLoaded = false
        error = nil
    }
    
    // MARK: - Error Handling
    
    func clearError() {
        error = nil
    }
}

// MARK: - Leaderboard Service Errors

enum LeaderboardServiceError: LocalizedError, Equatable {
    case unauthorized
    case notFound
    case validationError(String)
    case networkError(String)
    case serverError(String)
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Please sign in to continue."
        case .notFound:
            return "Leaderboard not found."
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
    
    static func fromAPIError(_ error: APIClientError) -> LeaderboardServiceError {
        switch error {
        case .unauthorized:
            return .unauthorized
            
        case .networkError(let underlyingError):
            return .networkError(underlyingError.localizedDescription)
            
        case .apiError(let apiError):
            switch apiError.error.code {
            case "NOT_FOUND":
                return .notFound
            default:
                return .serverError(apiError.error.message)
            }
            
        default:
            return .unknown(error.localizedDescription ?? "An unknown error occurred")
        }
    }
}
