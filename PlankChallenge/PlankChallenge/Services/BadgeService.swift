import Foundation
import Observation

/// Service responsible for managing badges
///
/// This service handles:
/// - Fetching user's earned badges
/// - Fetching all available badges with progress
/// - Fetching badge details
/// - Checking badge progress for other users
///
/// Usage:
/// ```swift
/// @Environment(BadgeService.self) private var badgeService
///
/// // Get all earned badges
/// try await badgeService.fetchBadges()
///
/// // Check progress towards all badges
/// try await badgeService.fetchAvailableBadges()
/// ```
@Observable
@MainActor
final class BadgeService: BadgeServiceProtocol {
    
    // MARK: - Singleton
    
    static let shared = BadgeService()
    
    // MARK: - State
    
    /// User's earned badges
    private(set) var earnedBadges: [APIBadge] = []
    
    /// All available badges with progress
    private(set) var availableBadges: [APIBadgeWithProgress] = []
    
    /// Badge summary (earned/total counts)
    private(set) var summary: BadgesAvailableResponse.BadgeSummary?
    
    /// Next achievable badges
    private(set) var nextAchievable: [APIBadgeWithProgress] = []
    
    /// Whether a fetch operation is in progress
    private(set) var isLoading = false
    
    /// Whether the initial data has been loaded
    private(set) var hasLoaded = false
    
    /// Current error, if any
    private(set) var error: BadgeServiceError?
    
    // MARK: - Computed Properties
    
    /// Total number of earned badges
    var earnedCount: Int {
        summary?.earned ?? earnedBadges.count
    }
    
    /// Total number of available badges
    var totalCount: Int {
        summary?.total ?? availableBadges.count
    }
    
    /// Percentage of badges earned
    var earnedPercentage: Int {
        summary?.percentage ?? (totalCount > 0 ? Int((Double(earnedCount) / Double(totalCount)) * 100) : 0)
    }
    
    /// Badges grouped by category
    var badgesByCategory: [APIBadgeCategory: [APIBadgeWithProgress]] {
        var grouped: [APIBadgeCategory: [APIBadgeWithProgress]] = [
            .streak: [],
            .count: [],
            .duration: [],
            .special: []
        ]
        
        for badge in availableBadges {
            if let category = APIBadgeCategory(rawValue: badge.category) {
                grouped[category]?.append(badge)
            }
        }
        
        return grouped
    }
    
    /// Recently earned badges (last 5)
    var recentBadges: [APIBadge] {
        Array(earnedBadges.prefix(5))
    }
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Fetches the user's earned badges
    func fetchBadges() async throws {
        isLoading = true
        error = nil
        defer { isLoading = false }
        
        do {
            let response: BadgesListResponse = try await APIClient.shared.get("/badges")
            earnedBadges = response.badges
            hasLoaded = true
        } catch let apiError as APIClientError {
            self.error = BadgeServiceError.fromAPIError(apiError)
            throw self.error!
        } catch {
            self.error = BadgeServiceError.unknown(error.localizedDescription)
            throw self.error!
        }
    }
    
    /// Fetches all available badges with progress information
    func fetchAvailableBadges() async throws {
        isLoading = true
        error = nil
        defer { isLoading = false }
        
        do {
            let response: BadgesAvailableResponse = try await APIClient.shared.get("/badges/available")
            availableBadges = response.badges
            summary = response.summary
            nextAchievable = response.nextAchievable
            hasLoaded = true
        } catch let apiError as APIClientError {
            self.error = BadgeServiceError.fromAPIError(apiError)
            throw self.error!
        } catch {
            self.error = BadgeServiceError.unknown(error.localizedDescription)
            throw self.error!
        }
    }
    
    /// Fetches details for a specific badge type
    /// - Parameter badgeType: The badge type identifier
    /// - Returns: Detailed badge information
    func fetchBadgeDetail(_ badgeType: String) async throws -> BadgeDetailResponse.BadgeDetail {
        error = nil
        
        do {
            let response: BadgeDetailResponse = try await APIClient.shared.get("/badges/\(badgeType)")
            return response.badge
        } catch let apiError as APIClientError {
            self.error = BadgeServiceError.fromAPIError(apiError)
            throw self.error!
        } catch {
            self.error = BadgeServiceError.unknown(error.localizedDescription)
            throw self.error!
        }
    }
    
    /// Fetches another user's earned badges
    /// - Parameter userId: The user ID to fetch badges for
    /// - Returns: The user's badge information
    func fetchUserBadges(_ userId: String) async throws -> UserBadgesResponse {
        error = nil
        
        do {
            let response: UserBadgesResponse = try await APIClient.shared.get("/badges/user/\(userId)")
            return response
        } catch let apiError as APIClientError {
            self.error = BadgeServiceError.fromAPIError(apiError)
            throw self.error!
        } catch {
            self.error = BadgeServiceError.unknown(error.localizedDescription)
            throw self.error!
        }
    }
    
    /// Checks if a specific badge has been earned
    /// - Parameter badgeType: The badge type to check
    /// - Returns: True if the badge has been earned
    func hasBadge(_ badgeType: String) -> Bool {
        earnedBadges.contains { $0.type == badgeType }
    }
    
    /// Gets the progress towards a specific badge
    /// - Parameter badgeType: The badge type to check
    /// - Returns: Progress percentage (0-100) or nil if badge not found
    func progress(for badgeType: String) -> Double? {
        availableBadges.first { $0.type == badgeType }?.progress
    }
    
    /// Clears local data (call on logout)
    func clearData() {
        earnedBadges = []
        availableBadges = []
        summary = nil
        nextAchievable = []
        hasLoaded = false
        error = nil
    }
    
    // MARK: - Error Handling
    
    func clearError() {
        error = nil
    }
}

// MARK: - User Badges Response (for viewing other users' badges)

struct UserBadgesResponse: Decodable {
    let user: UserInfo
    let badges: [APIBadge]
    let count: Int
    
    struct UserInfo: Decodable {
        let id: String
        let displayName: String
    }
}

// MARK: - Badge Service Errors

enum BadgeServiceError: LocalizedError, Equatable {
    case unauthorized
    case badgeNotFound
    case userNotFound
    case networkError(String)
    case serverError(String)
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Please sign in to continue."
        case .badgeNotFound:
            return "Badge not found."
        case .userNotFound:
            return "User not found."
        case .networkError(let message):
            return "Network error: \(message)"
        case .serverError(let message):
            return message
        case .unknown(let message):
            return message
        }
    }
    
    static func fromAPIError(_ error: APIClientError) -> BadgeServiceError {
        switch error {
        case .unauthorized:
            return .unauthorized
            
        case .networkError(let underlyingError):
            return .networkError(underlyingError.localizedDescription)
            
        case .apiError(let apiError):
            switch apiError.error.code {
            case "NOT_FOUND":
                // Could be badge or user not found
                if apiError.error.message.lowercased().contains("user") {
                    return .userNotFound
                }
                return .badgeNotFound
            default:
                return .serverError(apiError.error.message)
            }
            
        default:
            return .unknown(error.localizedDescription ?? "An unknown error occurred")
        }
    }
}
