import Foundation
import Observation

/// Service responsible for managing streak data
///
/// This service handles:
/// - Fetching current streak information
/// - Using freeze tokens to protect streaks
/// - Fetching streak history and milestones
///
/// Usage:
/// ```swift
/// @Environment(StreakService.self) private var streakService
///
/// // Check streak status
/// if streakService.isStreakAtRisk {
///     // Show warning
/// }
///
/// // Use freeze token
/// try await streakService.useFreeze()
/// ```
@Observable
@MainActor
final class StreakService: StreakServiceProtocol {
    
    // MARK: - Singleton
    
    static let shared = StreakService()
    
    // MARK: - State
    
    /// Current streak data
    private(set) var streakData: StreakMeResponse?
    
    /// Streak history data
    private(set) var historyData: StreakHistoryResponse?
    
    /// Whether a fetch or action is in progress
    private(set) var isLoading = false
    
    /// Whether the initial data has been loaded
    private(set) var hasLoaded = false
    
    /// Current error, if any
    private(set) var error: StreakServiceError?
    
    /// Inline override for currentStreak — set immediately from plank save/delete
    /// response without a network round-trip. Cleared when a full fetchStreak() runs.
    private var inlineCurrentStreak: Int? = nil
    
    /// Inline override for longestStreak — set immediately from plank save/delete response.
    private var inlineLongestStreak: Int? = nil
    
    // MARK: - Computed Properties
    
    /// Current streak count — uses inline override if available, else streakData
    var currentStreak: Int {
        inlineCurrentStreak ?? streakData?.currentStreak ?? 0
    }
    
    /// Longest streak ever achieved — uses inline override if available, else streakData
    var longestStreak: Int {
        inlineLongestStreak ?? streakData?.longestStreak ?? 0
    }
    
    /// Number of freeze tokens available
    var freezeTokens: Int {
        streakData?.freezeTokens ?? 0
    }
    
    /// Whether the user has planked today
    var hasPlankkedToday: Bool {
        streakData?.hasPlankkedToday ?? false
    }
    
    /// Whether a freeze token was used today
    var usedFreezeToday: Bool {
        streakData?.usedFreezeToday ?? false
    }
    
    /// Whether the streak is protected for today (either planked or used freeze)
    var streakProtectedToday: Bool {
        streakData?.streakProtectedToday ?? false
    }
    
    /// Whether the streak is at risk (needs a plank today to continue)
    var isStreakAtRisk: Bool {
        streakData?.isStreakAtRisk ?? false
    }
    
    /// Whether the streak is currently active
    var isStreakActive: Bool {
        streakData?.isStreakActive ?? false
    }
    
    /// Last date a plank was performed
    var lastPlankDate: String? {
        streakData?.lastPlankDate
    }
    
    /// Today's activity summary
    var todayActivity: StreakMeResponse.TodayActivity? {
        streakData?.today
    }
    
    /// Recent activity for calendar view
    var recentActivity: [StreakMeResponse.DayActivity] {
        streakData?.recentActivity ?? []
    }
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Fetches current streak information
    func fetchStreak() async throws {
        isLoading = true
        error = nil
        defer { isLoading = false }
        
        do {
            let response: StreakMeResponse = try await APIClient.shared.get("/streaks/me")
            streakData = response
            // Clear inline overrides — full fetch is now authoritative
            inlineCurrentStreak = nil
            inlineLongestStreak = nil
            hasLoaded = true
        } catch let apiError as APIClientError {
            self.error = StreakServiceError.fromAPIError(apiError)
            throw self.error!
        } catch {
            self.error = StreakServiceError.unknown(error.localizedDescription)
            throw self.error!
        }
    }
    
    /// Uses a freeze token to protect the current streak
    /// - Returns: The response with remaining tokens and streak status
    @discardableResult
    func useFreeze() async throws -> UseFreezeResponse {
        isLoading = true
        error = nil
        defer { isLoading = false }
        
        do {
            let response: UseFreezeResponse = try await APIClient.shared.post(
                "/streaks/freeze",
                body: EmptyBody()
            )
            
            // Refetch to get accurate state after using freeze
            try await fetchStreak()
            
            return response
            
        } catch let apiError as APIClientError {
            self.error = StreakServiceError.fromAPIError(apiError)
            throw self.error!
        } catch {
            self.error = StreakServiceError.unknown(error.localizedDescription)
            throw self.error!
        }
    }
    
    /// Fetches streak history and milestones
    func fetchHistory() async throws {
        isLoading = true
        error = nil
        defer { isLoading = false }
        
        do {
            let response: StreakHistoryResponse = try await APIClient.shared.get("/streaks/history")
            historyData = response
        } catch let apiError as APIClientError {
            self.error = StreakServiceError.fromAPIError(apiError)
            throw self.error!
        } catch {
            self.error = StreakServiceError.unknown(error.localizedDescription)
            throw self.error!
        }
    }
    
    /// Applies streak numbers returned inline from a `CreatePlankResponse` or
    /// `PlankDeleteResponse` without making an additional network round-trip.
    ///
    /// Sets inline overrides so `currentStreak` and `longestStreak` reflect the
    /// new values immediately. The overrides are cleared the next time a full
    /// `fetchStreak()` completes, at which point `streakData` becomes authoritative.
    func applyInlineStreakUpdate(current: Int, longest: Int) {
        inlineCurrentStreak = current
        // Take the maximum across: the server's returned value, any previous inline
        // override, and the authoritative streakData — so we never display a number
        // lower than what the user has already seen (e.g. all-time longest).
        inlineLongestStreak = max(longest, inlineLongestStreak ?? 0, streakData?.longestStreak ?? 0)
        hasLoaded = true
    }
    
    /// Clears local data (call on logout)
    func clearData() {
        streakData = nil
        historyData = nil
        inlineCurrentStreak = nil
        inlineLongestStreak = nil
        hasLoaded = false
        error = nil
    }
    
    // MARK: - Error Handling
    
    func clearError() {
        error = nil
    }
}

// MARK: - Empty Body for POST without body

private struct EmptyBody: Encodable {}

// MARK: - Streak Service Errors

enum StreakServiceError: LocalizedError, Equatable {
    case unauthorized
    case noFreezeTokens
    case alreadyPlankkedToday
    case alreadyUsedFreezeToday
    case streakNotAtRisk
    case networkError(String)
    case serverError(String)
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Please sign in to continue."
        case .noFreezeTokens:
            return "You don't have any freeze tokens available."
        case .alreadyPlankkedToday:
            return "You've already completed a plank today!"
        case .alreadyUsedFreezeToday:
            return "You've already used a freeze token today."
        case .streakNotAtRisk:
            return "Your streak isn't at risk right now."
        case .networkError(let message):
            return "Network error: \(message)"
        case .serverError(let message):
            return message
        case .unknown(let message):
            return message
        }
    }
    
    static func fromAPIError(_ error: APIClientError) -> StreakServiceError {
        switch error {
        case .unauthorized:
            return .unauthorized
            
        case .networkError(let underlyingError):
            return .networkError(underlyingError.localizedDescription)
            
        case .apiError(let apiError):
            // The backend sends "CONFLICT" for all freeze-related errors,
            // distinguishing them only via the human-readable message.
            // Sub-match on message content for these specific cases.
            if apiError.error.code == "CONFLICT" {
                let message = apiError.error.message.lowercased()
                if message.contains("no freeze tokens") {
                    return .noFreezeTokens
                } else if message.contains("already planked today") {
                    return .alreadyPlankkedToday
                } else if message.contains("already used a freeze today") {
                    return .alreadyUsedFreezeToday
                } else if message.contains("not at risk") {
                    return .streakNotAtRisk
                }
            }
            
            return .serverError(apiError.error.message)
            
        default:
            return .unknown(error.localizedDescription ?? "An unknown error occurred")
        }
    }
}
