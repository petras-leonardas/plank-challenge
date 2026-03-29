import Foundation
import Observation

/// Service responsible for fetching and managing in-app notifications from the API
///
/// This service handles:
/// - Fetching notifications from the API
/// - Marking notifications as read
/// - Tracking unread count
///
/// Note: This service handles API-based in-app notifications.
/// For local push notification scheduling, see `NotificationService`.
///
/// Usage:
/// ```swift
/// @Environment(InAppNotificationService.self) private var inAppNotificationService
///
/// // Fetch notifications
/// try await inAppNotificationService.fetchNotifications()
///
/// // Mark as read
/// try await inAppNotificationService.markAsRead(id: notificationId)
/// ```
@Observable
@MainActor
final class InAppNotificationService: InAppNotificationServiceProtocol {
    
    // MARK: - Singleton
    
    static let shared = InAppNotificationService()
    
    // MARK: - State
    
    /// All notifications
    private(set) var notifications: [APINotification] = []
    
    /// Count of unread notifications
    private(set) var unreadCount: Int = 0
    
    /// Whether a fetch operation is in progress
    private(set) var isLoading = false
    
    /// Whether notifications have been initially loaded
    private(set) var hasLoaded = false
    
    /// Current error, if any
    private(set) var error: InAppNotificationServiceError?
    
    /// Pagination state
    private var currentOffset: Int = 0
    private var hasMore: Bool = true
    private let pageSize: Int = 20
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Fetch Notifications
    
    /// Fetches notifications from the API (refreshes from start)
    func fetchNotifications() async throws {
        isLoading = true
        error = nil
        currentOffset = 0
        defer { isLoading = false }
        
        do {
            let response: NotificationsListResponse = try await APIClient.shared.get(
                "/notifications?limit=\(pageSize)&offset=0"
            )
            notifications = response.notifications
            // Backend list endpoint does not return unreadCount — keep existing value
            // (it's populated by fetchUnreadCount() called at login)
            hasMore = response.pagination.hasMore
            currentOffset = response.notifications.count
            hasLoaded = true
        } catch let apiError as APIClientError {
            let serviceError = InAppNotificationServiceError.fromAPIError(apiError)
            self.error = serviceError
            throw serviceError
        } catch {
            let serviceError = InAppNotificationServiceError.unknown(error.localizedDescription)
            self.error = serviceError
            throw serviceError
        }
    }
    
    /// Loads more notifications (pagination)
    /// 
    /// Note: On error, `currentOffset` is not incremented, so retrying will fetch
    /// the same page. This is intentional to allow recovery from transient failures.
    func loadMoreNotifications() async throws {
        guard hasMore, !isLoading else { return }
        
        isLoading = true
        error = nil
        defer { isLoading = false }
        
        do {
            let response: NotificationsListResponse = try await APIClient.shared.get(
                "/notifications?limit=\(pageSize)&offset=\(currentOffset)"
            )
            
            // Deduplicate: only add notifications we don't already have
            let existingIds = Set(notifications.map { $0.id })
            let newNotifications = response.notifications.filter { !existingIds.contains($0.id) }
            notifications.append(contentsOf: newNotifications)
            
            hasMore = response.pagination.hasMore
            currentOffset += response.notifications.count
        } catch let apiError as APIClientError {
            let serviceError = InAppNotificationServiceError.fromAPIError(apiError)
            self.error = serviceError
            throw serviceError
        } catch {
            let serviceError = InAppNotificationServiceError.unknown(error.localizedDescription)
            self.error = serviceError
            throw serviceError
        }
    }
    
    // MARK: - Mark as Read
    
    /// Marks a single notification as read
    /// - Parameter notificationId: The notification ID to mark as read
    /// - Throws: `InAppNotificationServiceError.validationError` if notificationId is invalid
    func markAsRead(id notificationId: String) async throws {
        guard isValidNotificationId(notificationId) else {
            let serviceError = InAppNotificationServiceError.validationError("Invalid notification ID")
            self.error = serviceError
            throw serviceError
        }
        
        error = nil
        
        do {
            let _: MarkNotificationReadResponse = try await APIClient.shared.post(
                "/notifications/\(notificationId)/read",
                body: EmptyNotificationBody()
            )
            
            // Update local state
            if let index = notifications.firstIndex(where: { $0.id == notificationId }) {
                let oldNotification = notifications[index]
                if !oldNotification.isRead {
                    unreadCount = max(0, unreadCount - 1)
                }
                // Create updated notification with isRead = true
                notifications[index] = APINotification(
                    id: oldNotification.id,
                    type: oldNotification.type,
                    title: oldNotification.title,
                    message: oldNotification.message,
                    relatedEntity: oldNotification.relatedEntity,
                    actorImageUrl: oldNotification.actorImageUrl,
                    isRead: true,
                    createdAt: oldNotification.createdAt
                )
            }
        } catch let apiError as APIClientError {
            let serviceError = InAppNotificationServiceError.fromAPIError(apiError)
            self.error = serviceError
            throw serviceError
        } catch {
            let serviceError = InAppNotificationServiceError.unknown(error.localizedDescription)
            self.error = serviceError
            throw serviceError
        }
    }
    
    /// Marks all notifications as read
    func markAllAsRead() async throws {
        error = nil
        
        do {
            let _: MarkAllNotificationsReadResponse = try await APIClient.shared.post(
                "/notifications/read-all",
                body: EmptyNotificationBody()
            )
            
            // Update local state - mark all as read
            notifications = notifications.map { notification in
                if notification.isRead {
                    return notification
                }
                return APINotification(
                    id: notification.id,
                    type: notification.type,
                    title: notification.title,
                    message: notification.message,
                    relatedEntity: notification.relatedEntity,
                    actorImageUrl: notification.actorImageUrl,
                    isRead: true,
                    createdAt: notification.createdAt
                )
            }
            unreadCount = 0
        } catch let apiError as APIClientError {
            let serviceError = InAppNotificationServiceError.fromAPIError(apiError)
            self.error = serviceError
            throw serviceError
        } catch {
            let serviceError = InAppNotificationServiceError.unknown(error.localizedDescription)
            self.error = serviceError
            throw serviceError
        }
    }
    
    // MARK: - Unread Count
    
    /// Fetches only the unread count from the API — lightweight call for badge display.
    /// Updates `unreadCount` without touching the notifications list.
    func fetchUnreadCount() async {
        do {
            let response: UnreadCountResponse = try await APIClient.shared.get(
                "/notifications/unread-count"
            )
            unreadCount = response.unreadCount
        } catch {
            // Silently fail — unread count is non-critical
        }
    }
    
    // MARK: - Validation Helpers
    
    /// Validates that a notification ID is safe to use in URL paths
    /// - Parameter notificationId: The notification ID to validate
    /// - Returns: True if the ID is valid (alphanumeric, hyphens, underscores only)
    private func isValidNotificationId(_ notificationId: String) -> Bool {
        guard !notificationId.isEmpty else { return false }
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        return notificationId.unicodeScalars.allSatisfy { allowedCharacters.contains($0) }
    }
    
    // MARK: - Utility
    
    /// Clears local data (call on logout)
    func clearData() {
        notifications = []
        unreadCount = 0
        currentOffset = 0
        hasMore = true
        hasLoaded = false
        error = nil
    }
    
    // MARK: - Error Handling
    
    func clearError() {
        error = nil
    }
}

// MARK: - Request/Response Types

private struct EmptyNotificationBody: Encodable {}

private struct UnreadCountResponse: Decodable {
    let unreadCount: Int
}

private struct MarkNotificationReadResponse: Decodable {
    let success: Bool
}

private struct MarkAllNotificationsReadResponse: Decodable {
    let success: Bool
    let count: Int?
}

// MARK: - In-App Notification Service Errors

enum InAppNotificationServiceError: LocalizedError, Equatable {
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
            return "Notification not found."
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
    
    static func fromAPIError(_ error: APIClientError) -> InAppNotificationServiceError {
        switch error {
        case .unauthorized:
            return .unauthorized
            
        case .networkError(let underlyingError):
            return .networkError(underlyingError.localizedDescription)
            
        case .apiError(let apiError):
            switch apiError.error.code {
            case "NOT_FOUND":
                return .notFound
            case "VALIDATION_ERROR":
                return .validationError(apiError.error.message)
            default:
                return .serverError(apiError.error.message)
            }
            
        default:
            return .unknown(error.localizedDescription)
        }
    }
}

// MARK: - APINotification Helpers

extension APINotification {
    /// Maps API notification type string to AppNotification.NotificationType for icon display
    var displayType: AppNotification.NotificationType? {
        // Map API types to app types
        switch type {
        case "badge_earned":
            return .badgeEarned
        case "streak_at_risk", "streak_broken", "freeze_reminder":
            return .streakFreezeUsed
        case "streak_milestone":
            return .tokenEarned
        case "group_invite", "group_joined":
            return .groupJoined
        case "group_join_request", "group_request_denied":
            return .joinRequestDenied
        case "group_promoted":
            return .promotedToAdmin
        case "group_removed", "group_banned":
            return .groupRemoved
        case "follow":
            return .groupJoined // Use group joined icon for follows (people icon)
        case "system":
            return nil
        default:
            return nil
        }
    }
    
    /// Icon name for this notification type
    var iconName: String {
        displayType?.iconName ?? "bell.fill"
    }
    
    /// Parsed createdAt date
    var date: Date {
        createdAt.toDateOrDistantPast()
    }
}
