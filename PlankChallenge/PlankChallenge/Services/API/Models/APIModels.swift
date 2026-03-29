import Foundation

// MARK: - Response Wrappers

/// Standard success response wrapper matching backend's ApiResponse<T>
struct APIResponse<T: Decodable>: Decodable {
    let success: Bool
    let data: T
    let meta: ResponseMeta
}

/// Standard error response matching backend's ApiError
struct APIErrorResponse: Decodable, Error, @unchecked Sendable {
    let success: Bool
    let error: ErrorDetail
    let meta: ResponseMeta
    
    struct ErrorDetail: Decodable, Sendable {
        let code: String
        let message: String
        let details: [String: AnyCodable]?
        let retryAfter: Int?
    }
}

/// Response metadata included in all API responses
struct ResponseMeta: Decodable, Sendable {
    let timestamp: String
    let requestId: String
}

/// Empty response for endpoints that return no data
struct EmptyResponse: Decodable {}

// MARK: - Error Codes

/// API error codes matching backend's ErrorCode type
enum APIErrorCode: String, Decodable, Sendable {
    case authRequired = "AUTH_REQUIRED"
    case authExpired = "AUTH_EXPIRED"
    case authInvalid = "AUTH_INVALID"
    case forbidden = "FORBIDDEN"
    case notFound = "NOT_FOUND"
    case validationError = "VALIDATION_ERROR"
    case rateLimited = "RATE_LIMITED"
    case serverError = "SERVER_ERROR"
    case conflict = "CONFLICT"
    case plankDeleteForbidden = "PLANK_DELETE_FORBIDDEN"
    case plankLimitReached = "PLANK_LIMIT_REACHED"
    case groupFull = "GROUP_FULL"
    case alreadyMember = "ALREADY_MEMBER"
    // Note: freeze-specific errors use "CONFLICT" as the code — see StreakService.fromAPIError()
}

// MARK: - Auth Models

/// Simplified user returned from auth endpoints (login, register, apple, google)
/// NOTE: Auth endpoints return only these 4 fields, NOT the full user profile
struct AuthUser: Decodable, Sendable {
    let id: String
    let email: String
    /// May be nil for new users who haven't completed onboarding yet.
    let displayName: String?
    let emailVerified: Bool
    /// ISO8601 timestamp of account creation — used to detect new users for onboarding.
    let createdAt: String?
}

/// Response from authentication endpoints (login, register, apple auth, google auth)
struct AuthResponse: Decodable {
    let user: AuthUser
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
}

/// Response from token refresh endpoint
struct TokenRefreshResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
}

/// Request body for Apple Sign In
struct AppleAuthRequest: Encodable {
    let identityToken: String
    let authorizationCode: String
    let user: AppleUserInfo?
    
    struct AppleUserInfo: Encodable {
        let email: String?
        let name: AppleName?
        
        struct AppleName: Encodable {
            let firstName: String?
            let lastName: String?
        }
    }
}

/// Request body for Google Sign In
struct GoogleAuthRequest: Encodable {
    let idToken: String
}

/// Request body for email registration
struct EmailRegisterRequest: Encodable {
    let email: String
    let password: String
    let displayName: String
}

/// Request body for email login
struct EmailLoginRequest: Encodable {
    let email: String
    let password: String
}

/// Request body for token refresh
struct RefreshTokenRequest: Encodable {
    let refreshToken: String
}

/// Request body for logout
struct LogoutRequest: Encodable {
    let refreshToken: String
}

// MARK: - User Models

/// Full user model for the authenticated user (from /users/me)
struct APIUser: Decodable, Identifiable, Sendable, Equatable {
    let id: String
    let email: String
    let emailVerified: Bool
    let displayName: String
    let username: String?
    let location: String?
    let bio: String?
    let profileImageUrl: String?
    let preferredPlankType: String
    /// Duration goal in seconds for countdown mode. nil = free mode (no goal set).
    let plankGoalSeconds: Int?
    let currentStreak: Int
    let longestStreak: Int
    let freezeTokens: Int
    let lastPlankDate: String?
    let totalPlanks: Int
    let totalPlankSeconds: Double
    let longestPlankSeconds: Double
    let followerCount: Int
    let followingCount: Int
    let timezone: String
    let createdAt: String
    let updatedAt: String
}

/// Public user model for viewing other users' profiles
struct APIPublicUser: Decodable, Identifiable, Sendable {
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
    let isFollowing: Bool?
}

/// Request body for updating user profile
struct UpdateProfileRequest: Encodable {
    var displayName: String?
    var username: String?
    var location: String?
    var bio: String?
    var preferredPlankType: String?
    var timezone: String?
    /// Duration goal in seconds for countdown mode. Pass nil to clear the goal.
    var plankGoalSeconds: Int?
    
    init(
        displayName: String? = nil,
        username: String? = nil,
        location: String? = nil,
        bio: String? = nil,
        preferredPlankType: String? = nil,
        timezone: String? = nil,
        plankGoalSeconds: Int? = nil
    ) {
        self.displayName = displayName
        self.username = username
        self.location = location
        self.bio = bio
        self.preferredPlankType = preferredPlankType
        self.timezone = timezone
        self.plankGoalSeconds = plankGoalSeconds
    }
}

/// Response from /users/me
struct UserMeResponse: Decodable {
    let user: APIUser
}

/// Response from /users/:id (public profile)
struct UserProfileResponse: Decodable {
    let user: APIPublicUser
}

/// Response from user search
struct UserSearchResponse: Decodable {
    let users: [APIPublicUser]
}

// MARK: - Plank Models

/// Plank type matching backend's PlankType
/// Backend supports: 'elbow', 'high', 'side_left', 'side_right', 'reverse'
enum APIPlankType: String, Codable, CaseIterable, Sendable {
    case elbow
    case high
    case sideLeft = "side_left"
    case sideRight = "side_right"
    case reverse
    
    /// Human-readable display name
    var displayName: String {
        switch self {
        case .elbow: return "Elbow Plank"
        case .high: return "High Plank"
        case .sideLeft: return "Side Plank (Left)"
        case .sideRight: return "Side Plank (Right)"
        case .reverse: return "Reverse Plank"
        }
    }
}

/// Input method matching backend's InputMethod
enum APIInputMethod: String, Codable, Sendable {
    case timer
    case manual
    case watch
}

/// Plank session model for API communication
struct APIPlankSession: Codable, Identifiable, Sendable {
    let id: String
    let clientId: String
    let durationSeconds: Double
    let plankType: String
    let inputMethod: String
    let performedAt: String
    let timezone: String
    let createdAt: String
    let updatedAt: String
    let deletedAt: String?
}

/// Request body for creating a new plank session.
/// `plankType` is omitted — the backend defaults to "elbow".
struct CreatePlankRequest: Encodable {
    let clientId: String
    let durationSeconds: Double
    let inputMethod: String
    let performedAt: String
    let timezone: String
}

/// Response from creating a plank session
struct CreatePlankResponse: Decodable {
    let plank: APIPlankSession
    let created: Bool
    let streak: StreakInfo?
    let badges: BadgesInfo?
    
    struct StreakInfo: Decodable {
        let current: Int
        let longest: Int
    }
    
    struct BadgesInfo: Decodable {
        /// Array of badge type strings (e.g. "first_plank", "streak_7")
        /// The backend returns badge type strings, not full badge objects.
        let newlyEarned: [String]
        let count: Int
    }
}

/// Response from listing planks
struct PlanksListResponse: Decodable {
    let planks: [APIPlankSession]
    let pagination: PaginationMeta
}

/// Response from getting a single plank
struct PlankDetailResponse: Decodable {
    let plank: APIPlankSession
}

/// Response from deleting a plank
struct PlankDeleteResponse: Decodable {
    let message: String
    let streak: StreakInfo
    
    struct StreakInfo: Decodable {
        let current: Int
        let longest: Int
    }
}

/// Response from plank sync endpoint
struct PlankSyncResponse: Decodable {
    let planks: [APIPlankSession]
    let serverTimestamp: String
    let count: Int
    let pagination: SyncPaginationMeta
    
    struct SyncPaginationMeta: Decodable {
        let hasMore: Bool
        let nextCursor: String?
        let limit: Int
    }
}

/// Response from plank stats endpoint
struct PlankStatsResponse: Decodable {
    let overall: OverallStats
    let byType: [TypeStats]
    let thisWeek: PeriodStats
    let thisMonth: PeriodStats
    let streak: StreakStats
    
    struct OverallStats: Decodable {
        let totalPlanks: Int
        let totalSeconds: Double
        let averageSeconds: Int
        let longestPlank: Double
        let firstPlankDate: String?
        let lastPlankDate: String?
    }
    
    struct TypeStats: Decodable {
        let type: String
        let count: Int
        let totalSeconds: Double
        let averageSeconds: Int
        let bestSeconds: Double
    }
    
    struct PeriodStats: Decodable {
        let planks: Int
        let totalSeconds: Double
    }
    
    struct StreakStats: Decodable {
        let current: Int
        let longest: Int
        let freezeTokens: Int
        let lastPlankDate: String?
    }
}

// MARK: - Badge Models

/// Badge category matching backend's BadgeCategory
enum APIBadgeCategory: String, Codable, Sendable {
    case streak
    case count
    case duration
    case special
}

/// Earned badge from the API
struct APIBadge: Decodable, Identifiable, Sendable {
    let id: String
    let type: String
    let name: String
    let description: String
    let category: String
    let icon: String
    let earnedAt: String
}

/// Response from /badges (user's earned badges)
struct BadgesListResponse: Decodable {
    let badges: [APIBadge]
    let byCategory: BadgesByCategory
    let count: Int
    let totalAvailable: Int
    
    struct BadgesByCategory: Decodable {
        let streak: [APIBadge]
        let count: [APIBadge]
        let duration: [APIBadge]
        let special: [APIBadge]
    }
}

/// Badge with progress info (from /badges/available)
struct APIBadgeWithProgress: Decodable, Identifiable, Sendable {
    var id: String { type }
    let type: String
    let name: String
    let description: String
    let category: String
    let icon: String
    let earned: Bool
    let earnedAt: String?
    let progress: Double
    let order: Int
}

/// Response from /badges/available
struct BadgesAvailableResponse: Decodable {
    let badges: [APIBadgeWithProgress]
    let byCategory: BadgesByCategory
    let summary: BadgeSummary
    let nextAchievable: [APIBadgeWithProgress]
    
    struct BadgesByCategory: Decodable {
        let streak: [APIBadgeWithProgress]
        let count: [APIBadgeWithProgress]
        let duration: [APIBadgeWithProgress]
        let special: [APIBadgeWithProgress]
    }
    
    struct BadgeSummary: Decodable {
        let earned: Int
        let total: Int
        let percentage: Int
    }
}

/// Response from /badges/:type
struct BadgeDetailResponse: Decodable {
    let badge: BadgeDetail
    
    struct BadgeDetail: Decodable {
        let type: String
        let name: String
        let description: String
        let category: String
        let icon: String
        let requirement: String
        let earned: Bool
        let earnedAt: String?
        let earnedId: String?
        let progress: Double
    }
}

// MARK: - Streak Models

/// Response from /streaks/me
struct StreakMeResponse: Decodable {
    let currentStreak: Int
    let longestStreak: Int
    let freezeTokens: Int
    let lastPlankDate: String?
    let lastFreezeDate: String?
    
    // Status flags
    let hasPlankkedToday: Bool
    let usedFreezeToday: Bool
    let streakProtectedToday: Bool
    let isStreakAtRisk: Bool
    let isStreakActive: Bool
    
    // Today's activity
    let today: TodayActivity
    
    // Recent activity for calendar view
    let recentActivity: [DayActivity]
    
    struct TodayActivity: Decodable {
        let date: String
        let planks: Int
        let totalSeconds: Double
        let usedFreeze: Bool
    }
    
    struct DayActivity: Decodable {
        let date: String
        let planks: Int
        let totalSeconds: Double
    }
}

/// Response from using a freeze token
struct UseFreezeResponse: Decodable {
    let message: String
    let freezeTokensRemaining: Int
    let streakProtected: Bool
    let currentStreak: Int
    let freezeUsedToday: Bool
}

/// Response from /streaks/history
struct StreakHistoryResponse: Decodable {
    let currentStreak: Int
    let longestStreak: Int
    let allTime: AllTimeStats
    let milestones: [Milestone]
    let monthlyHistory: [MonthlyStats]
    
    struct AllTimeStats: Decodable {
        let daysSinceJoining: Int
        let activeDays: Int
        let consistencyRate: Int
    }
    
    struct Milestone: Decodable {
        let days: Int
        let name: String
        let achieved: Bool
        let progress: Int
    }
    
    struct MonthlyStats: Decodable {
        let month: String
        let planks: Int
        let totalSeconds: Double
        let activeDays: Int
    }
}

// MARK: - Progress Models

/// Response from /planks/progress
struct ProgressResponse: Decodable {
    let summary: ProgressSummary
    let dailyActivity: [DailyActivity]
    let weeklyActivity: [WeeklyActivity]
    let recentBadges: [RecentBadge]
    let milestones: [ProgressMilestone]
    let nextGoals: NextGoals
    
    struct ProgressSummary: Decodable {
        let totalPlanks: Int
        let totalSeconds: Double
        let longestPlankSeconds: Double
        let currentStreak: Int
        let longestStreak: Int
        let freezeTokens: Int
        let badgesEarned: Int
        let activeDays: Int
        let daysSinceJoining: Int
        let consistencyRate: Int
    }
    
    struct DailyActivity: Decodable {
        let date: String
        let planks: Int
        let totalSeconds: Double
        let bestPlank: Double
    }
    
    struct WeeklyActivity: Decodable {
        let week: String
        let planks: Int
        let totalSeconds: Double
        let activeDays: Int
    }
    
    struct RecentBadge: Decodable {
        let type: String
        let earnedAt: String
    }
    
    struct ProgressMilestone: Decodable {
        let type: String
        let name: String
        let achieved: Bool
        let current: Int
        let target: Int
    }
    
    struct NextGoals: Decodable {
        let streak: GoalInfo?
        let totalPlanks: GoalInfo?
        let duration: GoalInfo?
        
        struct GoalInfo: Decodable {
            let target: Int
            let name: String
            let badgeType: String
            let current: Int
            let progress: Double
        }
    }
}

// MARK: - Notification Models

/// Notification type matching backend's NotificationType
enum APINotificationType: String, Codable, Sendable {
    case badgeEarned = "badge_earned"
    case streakAtRisk = "streak_at_risk"
    case streakBroken = "streak_broken"
    case streakMilestone = "streak_milestone"
    case freezeReminder = "freeze_reminder"
    case groupInvite = "group_invite"
    case groupJoined = "group_joined"
    case groupJoinRequest = "group_join_request"
    case groupPromoted = "group_promoted"
    case groupRemoved = "group_removed"
    case groupBanned = "group_banned"
    case groupRequestDenied = "group_request_denied"
    case follow
    case system
}

/// Notification from the API
struct APINotification: Decodable, Identifiable, Sendable {
    let id: String
    let type: String
    let title: String
    let message: String
    let relatedEntity: RelatedEntity?
    /// Profile image URL of the person who triggered the notification (follower, new member, etc.)
    let actorImageUrl: String?
    let isRead: Bool
    let createdAt: String
    
    struct RelatedEntity: Decodable, Sendable {
        let type: String
        let id: String
    }
}

/// Response from /notifications
/// Note: the backend list endpoint does NOT include unreadCount in the response body.
/// Use GET /notifications/unread-count for the badge count.
struct NotificationsListResponse: Decodable {
    let notifications: [APINotification]
    let pagination: PaginationMeta
    let unreadCount: Int?
}

// MARK: - Group Models

/// Group type
/// Group type — raw values match backend z.enum(['public', 'private'])
enum APIGroupType: String, Codable, Sendable {
    case `public` = "public"
    case `private` = "private"
}

/// Group join mode — raw values match backend z.enum(['open', 'request'])
enum APIJoinMode: String, Codable, Sendable {
    case `open` = "open"
    case request = "request"
}

/// Group model from API
struct APIGroup: Decodable, Identifiable, Sendable {
    let id: String
    let name: String
    let description: String?
    let imageUrl: String?
    let groupType: String
    let joinMode: String
    let memberCount: Int
    let createdBy: String
    let inviteCode: String?
    let createdAt: String
    let updatedAt: String
    /// `true` when the current user has a pending join request for this group.
    /// Only populated by `/groups/discover` and `/groups/:id` — absent for members.
    let pendingRequest: Bool?
    /// Up to 4 profile image URLs of recently-joined members who have a photo.
    /// Empty array when no members have photos. Used to render the avatar stack in list cards.
    let memberPreviews: [String]?
}

/// A pending join request for a group (from GET /groups/:id/requests)
struct APIJoinRequest: Decodable, Identifiable, Sendable {
    let id: String
    let userId: String
    let groupId: String?   // not returned by the list endpoint — client knows from context
    let status: String
    let createdAt: String
    let user: RequestUser?
    
    struct RequestUser: Decodable, Sendable {
        let id: String
        let displayName: String
        let username: String?
        let profileImageUrl: String?
    }
}

/// Response from GET /groups/:id/requests
struct JoinRequestsResponse: Decodable {
    let requests: [APIJoinRequest]
}

/// Group member model
/// Matches backend `formatGroupMember` shape:
/// { id, userId, role, joinedAt, user: { id, displayName, username, profileImageUrl, currentStreak } }
struct APIGroupMember: Decodable, Identifiable, Sendable {
    /// The group_members table row ID (used for Identifiable).
    let id: String
    /// The actual user ID — use this when navigating to a user profile.
    let userId: String
    let role: String
    let joinedAt: String
    let user: MemberUser?
    
    struct MemberUser: Decodable, Sendable {
        let id: String
        let displayName: String
        let username: String?
        let profileImageUrl: String?
        let currentStreak: Int?
    }
    
    // MARK: - Convenience accessors (keeps existing view code unchanged)
    var displayName: String { user?.displayName ?? "" }
    var username: String? { user?.username }
    var profileImageUrl: String? { user?.profileImageUrl }
}

/// Request body for creating a group
struct CreateGroupRequest: Encodable {
    let name: String
    let description: String?
    let groupType: String
    let joinMode: String
}

/// Request body for PATCH /groups/:id
struct UpdateGroupRequest: Encodable {
    let name: String?
    let description: String?
    let joinMode: String?
}

/// Response from /groups (user's groups)
struct GroupsListResponse: Decodable {
    let groups: [APIGroup]
}

/// Response from GET /groups/:id
/// The backend returns a flat object (all group fields at the top level) with
/// optional `isMember` and `role` fields mixed in — there is no nested "group"
/// or "membership" key. This struct decodes that flat shape and exposes
/// convenience properties so the rest of the app keeps working unchanged.
struct GroupDetailResponse: Decodable {
    // Core group fields (always present)
    let id: String
    let name: String
    let description: String?
    let imageUrl: String?
    let groupType: String
    let joinMode: String
    let memberCount: Int
    let createdBy: String
    let inviteCode: String?
    let createdAt: String
    let updatedAt: String
    // Membership fields (present only when the requester is a member)
    let isMember: Bool?
    let role: String?
    let pendingRequest: Bool?
    
    /// Convenience: reconstruct an `APIGroup` for use in the rest of the app.
    var group: APIGroup {
        APIGroup(
            id: id, name: name, description: description,
            imageUrl: imageUrl, groupType: groupType, joinMode: joinMode,
            memberCount: memberCount, createdBy: createdBy,
            inviteCode: inviteCode, createdAt: createdAt, updatedAt: updatedAt,
            pendingRequest: pendingRequest, memberPreviews: nil
        )
    }
    
    /// Convenience: membership info if the user is a member.
    /// Note: `role` is only present in the response for admins. Regular members
    /// get `isMember: true` but no `role` field — so we default to "member".
    var membership: MembershipInfo? {
        guard isMember == true else { return nil }
        return MembershipInfo(role: role ?? "member")
    }
    
    struct MembershipInfo {
        let role: String
    }
}

// MARK: - Leaderboard Models

/// Leaderboard entry (matches backend response structure)
struct APILeaderboardEntry: Decodable, Identifiable, Sendable {
    var id: String { user.id }
    let rank: Int
    let user: LeaderboardUser
    let score: Double
    let scoreLabel: String
    let isCurrentUser: Bool
    
    struct LeaderboardUser: Decodable, Sendable {
        let id: String
        let displayName: String
        let username: String?
        let profileImageUrl: String?
    }
}

/// Response from global and friends leaderboard endpoints.
/// Backend keys: "entries" (list), "currentUserRank" (caller's rank, optional).
/// convertFromSnakeCase leaves camelCase keys unchanged, so these map directly.
struct LeaderboardResponse: Decodable {
    let entries: [APILeaderboardEntry]
    let currentUserRank: APILeaderboardEntry?
    let pagination: PaginationMeta?
}

// MARK: - Group Leaderboard Models

/// A single entry in a group leaderboard.
/// The group leaderboard endpoint returns `stats` (duration/count/bestPlank) and
/// `currentUser`, which differs from the global leaderboard shape (`score`,
/// `scoreLabel`, `isCurrentUser`, `userRank`). Using a dedicated type avoids
/// a `DecodingError.keyNotFound` crash when the shared `APILeaderboardEntry`
/// model is used against the group endpoint response.
struct GroupLeaderboardEntry: Decodable, Identifiable, Sendable {
    var id: String { user.id }
    let rank: Int
    let user: GroupLeaderboardUser
    let stats: GroupLeaderboardStats
    
    struct GroupLeaderboardUser: Decodable, Sendable {
        let id: String
        let displayName: String
        let username: String?
        let profileImageUrl: String?
        let currentStreak: Int?
    }
    
    struct GroupLeaderboardStats: Decodable, Sendable {
        /// Total plank duration in seconds — stored as Double because the
        /// backend returns floating-point values from SUM(duration_seconds).
        let totalDuration: Double
        let plankCount: Int
        /// Best single plank in seconds — also floating-point from the DB.
        let bestPlank: Double
    }
}

/// Response from the `GET /groups/:id/leaderboard` endpoint.
struct GroupLeaderboardResponse: Decodable {
    let leaderboard: [GroupLeaderboardEntry]
    /// The authenticated user's own rank entry (may be outside the top-N list).
    /// Backend key is `currentUser`.
    let currentUser: GroupLeaderboardEntry?
}

// MARK: - Device Models

/// Request body for registering a device for push notifications
struct RegisterDeviceRequest: Encodable {
    let deviceToken: String
    let platform: String
    let appVersion: String?
    let osVersion: String?
    let deviceModel: String?
}

// MARK: - Pagination

/// Pagination metadata
struct PaginationMeta: Decodable, Sendable {
    let total: Int?  // Not always present (e.g. followers/following endpoints omit it)
    let limit: Int
    let offset: Int
    let hasMore: Bool
}

// MARK: - Type-Erased Encodable

/// Type-erased wrapper for Encodable values
/// Used by APIClient to encode request bodies of any Encodable type
struct AnyEncodable: Encodable {
    private let encodeClosure: (Encoder) throws -> Void
    
    init<T: Encodable>(_ wrapped: T) {
        self.encodeClosure = { encoder in
            try wrapped.encode(to: encoder)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        try encodeClosure(encoder)
    }
}

// MARK: - AnyCodable Helper

/// Type-erased codable for handling dynamic JSON values
/// Marked as @unchecked Sendable because Any isn't Sendable, but we only use JSON-safe types
struct AnyCodable: Codable, @unchecked Sendable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if container.decodeNil() {
            self.value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            self.value = bool
        } else if let int = try? container.decode(Int.self) {
            self.value = int
        } else if let double = try? container.decode(Double.self) {
            self.value = double
        } else if let string = try? container.decode(String.self) {
            self.value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            self.value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            self.value = dict.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unable to decode AnyCodable"
            )
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(
                value,
                EncodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "Unable to encode AnyCodable"
                )
            )
        }
    }
}

// MARK: - Date Parsing Helpers

// Reusable formatters — avoids allocating a new instance on every call.
// The backend uses JavaScript's Date.toISOString() which always includes
// fractional milliseconds (e.g. "2026-03-28T14:32:05.123Z"). Swift's default
// ISO8601DateFormatter cannot parse fractional seconds, so we keep a second
// formatter with .withFractionalSeconds and try both.
private let _iso8601Plain: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime]
    return f
}()

private let _iso8601Fractional: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
}()

extension String {
    /// Parses an ISO8601 date string to Date.
    /// Handles both plain ("…Z") and fractional-second ("….123Z") variants
    /// because JavaScript's Date.toISOString() always emits milliseconds.
    func toDate() -> Date? {
        _iso8601Fractional.date(from: self) ?? _iso8601Plain.date(from: self)
    }
    
    /// Parses an ISO8601 date string to Date, returning distant past if parsing fails
    func toDateOrDistantPast() -> Date {
        toDate() ?? .distantPast
    }
}

extension Date {
    /// Formats a Date to ISO8601 string
    func toISO8601String() -> String {
        ISO8601DateFormatter().string(from: self)
    }
}

// MARK: - APIGroup Helpers

extension APIGroup {
    /// Whether this is a private group.
    /// Backend sends groupType = "private" for private groups.
    var isPrivate: Bool {
        groupType == "private"
    }
    
    /// Whether joining requires approval from the group admin.
    /// Backend sends joinMode = "request" for approval-required groups.
    var requiresApproval: Bool {
        joinMode == "request"
    }
    
    /// Maps to PlankGroup.JoinMode for UI compatibility
    var joinModeType: PlankGroup.JoinMode {
        switch joinMode {
        case "open": return .open
        case "request": return .requestToJoin
        default: return .open
        }
    }
    
    /// Maps to PlankGroup.GroupType for UI compatibility
    var groupTypeEnum: PlankGroup.GroupType {
        isPrivate ? .privateInvite : .publicOpen
    }
    
    /// Parsed updated date for sorting
    var updatedDate: Date {
        updatedAt.toDateOrDistantPast()
    }
}

// MARK: - APIGroupMember Helpers

extension APIGroupMember {
    /// Whether this member is an admin
    var isAdmin: Bool {
        role == "admin" || role == "owner"
    }
    
    /// Whether this member is the owner
    var isOwner: Bool {
         role == "owner"
    }
    
    /// Formatted role for display
    var displayRole: String? {
        switch role {
        case "owner": return "Owner"
        case "admin": return "Admin"
        default: return nil
        }
    }
}

// MARK: - Media Models

/// Response returned from POST /media/avatar
struct AvatarUploadResponse: Decodable, Sendable {
    let profileImageUrl: String
    let message: String
}

/// Response returned from POST /media/group/:groupId
struct GroupImageUploadResponse: Decodable, Sendable {
    let imageUrl: String
    let message: String
}
