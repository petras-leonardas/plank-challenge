import Foundation
import Observation

/// Service responsible for managing plank sessions
///
/// This service handles:
/// - Creating new plank sessions (with optimistic local updates)
/// - Listing and fetching plank sessions
/// - Syncing offline planks with the server
/// - Deleting today's planks
/// - Fetching plank statistics and progress
///
/// Usage:
/// ```swift
/// @Environment(PlankService.self) private var plankService
///
/// // Record a new plank
/// try await plankService.createPlank(
///     durationSeconds: 90,
///     plankType: .elbow,
///     inputMethod: .timer
/// )
/// ```
@Observable
@MainActor
final class PlankService: PlankServiceProtocol {
    
    // MARK: - Singleton
    
    static let shared = PlankService()
    
    // MARK: - State
    
    /// All plank sessions for the current user (sorted by date descending)
    private(set) var planks: [APIPlankSession] = []
    
    /// Whether a sync or fetch operation is in progress
    private(set) var isLoading = false
    
    /// Whether the initial data has been loaded
    private(set) var hasLoaded = false
    
    /// Last sync timestamp from server
    private(set) var lastSyncTimestamp: String?
    
    /// Current error, if any
    private(set) var error: PlankServiceError?
    
    // MARK: - Computed Properties
    
    /// Today's plank session, if any
    var todaysPlank: APIPlankSession? {
        let today = formatDateString(Date())
        return planks.first { plank in
            guard let performedAt = parseISO8601Date(plank.performedAt) else { return false }
            return formatDateString(performedAt) == today
        }
    }
    
    /// Whether the user has completed a plank today
    var hasPlankToday: Bool {
        todaysPlank != nil
    }
    
    /// Number of planks completed today according to server-synced data.
    /// Used by PlankTimerView to reconcile @AppStorage today-count on cold launch.
    var todayPlankCountFromServer: Int {
        let today = formatDateString(Date())
        return planks.filter { plank in
            guard let performedAt = parseISO8601Date(plank.performedAt) else { return false }
            return formatDateString(performedAt) == today
        }.count
    }
    
    /// Total number of planks
    var totalPlanks: Int {
        planks.count
    }
    
    /// Total plank time in seconds
    var totalPlankTime: TimeInterval {
        planks.reduce(0) { $0 + $1.durationSeconds }
    }
    
    /// Average plank duration in seconds
    var averageDuration: TimeInterval {
        guard !planks.isEmpty else { return 0 }
        return totalPlankTime / Double(planks.count)
    }
    
    /// Longest plank session
    var longestPlank: APIPlankSession? {
        planks.max { $0.durationSeconds < $1.durationSeconds }
    }
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Fetches all planks for the current user
    /// - Parameter refresh: If true, forces a full refresh from server
    func fetchPlanks(refresh: Bool = false) async throws {
        isLoading = true
        error = nil
        defer { isLoading = false }
        
        do {
            // Use sync endpoint for efficiency (includes pagination support)
            let since = refresh ? nil : lastSyncTimestamp
            var allPlanks: [APIPlankSession] = refresh ? [] : planks
            var cursor: String? = nil
            var hasMore = true
            
            while hasMore {
                var path = "/planks/sync?limit=100"
                if let since = since {
                    path += "&since=\(since)"
                }
                if let cursor = cursor {
                    path += "&cursor=\(cursor)"
                }
                
                let response: PlankSyncResponse = try await APIClient.shared.get(path)
                
                // Merge synced planks with local (handle updates and soft deletes)
                for syncedPlank in response.planks {
                    if let index = allPlanks.firstIndex(where: { $0.clientId == syncedPlank.clientId }) {
                        // Update existing plank
                        if syncedPlank.deletedAt != nil {
                            allPlanks.remove(at: index)
                        } else {
                            allPlanks[index] = syncedPlank
                        }
                    } else if syncedPlank.deletedAt == nil {
                        // Add new plank
                        allPlanks.append(syncedPlank)
                    }
                }
                
                hasMore = response.pagination.hasMore
                cursor = response.pagination.nextCursor
                lastSyncTimestamp = response.serverTimestamp
            }
            
            // Sort by performed date (newest first)
            planks = allPlanks.sorted { plank1, plank2 in
                guard let date1 = parseISO8601Date(plank1.performedAt),
                      let date2 = parseISO8601Date(plank2.performedAt) else {
                    return false
                }
                return date1 > date2
            }
            
            hasLoaded = true
            
        } catch let apiError as APIClientError {
            self.error = PlankServiceError.fromAPIError(apiError)
            throw self.error!
        } catch {
            self.error = PlankServiceError.unknown(error.localizedDescription)
            throw self.error!
        }
    }
    
    /// Creates a new plank session.
    /// - Parameters:
    ///   - durationSeconds: Duration of the plank in seconds
    ///   - inputMethod: How the duration was recorded (timer or manual)
    /// - Returns: The created plank session and any newly earned badges
    @discardableResult
    func createPlank(
        durationSeconds: Double,
        inputMethod: APIInputMethod
    ) async throws -> CreatePlankResponse {
        error = nil
        
        // Generate client ID for idempotency
        let clientId = UUID().uuidString
        let now = Date()
        let timezone = TimeZone.current.identifier
        
        let request = CreatePlankRequest(
            clientId: clientId,
            durationSeconds: durationSeconds,
            inputMethod: inputMethod.rawValue,
            performedAt: formatISO8601Date(now),
            timezone: timezone
        )
        
        do {
            let response: CreatePlankResponse = try await APIClient.shared.post(
                "/planks",
                body: request
            )
            
            // Add to local list if newly created
            if response.created {
                planks.insert(response.plank, at: 0)
            }
            
            return response
            
        } catch let apiError as APIClientError {
            self.error = PlankServiceError.fromAPIError(apiError)
            throw self.error!
        } catch {
            self.error = PlankServiceError.unknown(error.localizedDescription)
            throw self.error!
        }
    }
    
    /// Deletes a plank session (only today's planks can be deleted)
    /// - Parameter plankId: The ID of the plank to delete
    /// - Returns: Updated streak information
    func deletePlank(_ plankId: String) async throws -> PlankDeleteResponse {
        error = nil
        
        do {
            let response: PlankDeleteResponse = try await APIClient.shared.delete(
                "/planks/\(plankId)"
            )
            
            // Remove from local list
            planks.removeAll { $0.id == plankId }
            
            return response
            
        } catch let apiError as APIClientError {
            self.error = PlankServiceError.fromAPIError(apiError)
            throw self.error!
        } catch {
            self.error = PlankServiceError.unknown(error.localizedDescription)
            throw self.error!
        }
    }
    
    /// Fetches plank statistics
    func fetchStats() async throws -> PlankStatsResponse {
        error = nil
        
        do {
            let response: PlankStatsResponse = try await APIClient.shared.get("/planks/stats")
            return response
        } catch let apiError as APIClientError {
            self.error = PlankServiceError.fromAPIError(apiError)
            throw self.error!
        } catch {
            self.error = PlankServiceError.unknown(error.localizedDescription)
            throw self.error!
        }
    }
    
    /// Fetches comprehensive progress data
    func fetchProgress() async throws -> ProgressResponse {
        error = nil
        
        do {
            let response: ProgressResponse = try await APIClient.shared.get("/planks/progress")
            return response
        } catch let apiError as APIClientError {
            self.error = PlankServiceError.fromAPIError(apiError)
            throw self.error!
        } catch {
            self.error = PlankServiceError.unknown(error.localizedDescription)
            throw self.error!
        }
    }
    
    /// Fetches a single plank by ID
    func fetchPlank(_ plankId: String) async throws -> APIPlankSession {
        error = nil
        
        do {
            let response: PlankDetailResponse = try await APIClient.shared.get("/planks/\(plankId)")
            return response.plank
        } catch let apiError as APIClientError {
            self.error = PlankServiceError.fromAPIError(apiError)
            throw self.error!
        } catch {
            self.error = PlankServiceError.unknown(error.localizedDescription)
            throw self.error!
        }
    }
    
    /// Lists planks with pagination and optional date filtering
    /// - Parameters:
    ///   - limit: Maximum number of planks to return
    ///   - offset: Number of planks to skip
    ///   - startDate: Optional start date filter (YYYY-MM-DD)
    ///   - endDate: Optional end date filter (YYYY-MM-DD)
    func listPlanks(
        limit: Int = 50,
        offset: Int = 0,
        startDate: String? = nil,
        endDate: String? = nil
    ) async throws -> PlanksListResponse {
        error = nil
        
        var path = "/planks?limit=\(limit)&offset=\(offset)"
        if let startDate = startDate {
            path += "&startDate=\(startDate)"
        }
        if let endDate = endDate {
            path += "&endDate=\(endDate)"
        }
        
        do {
            let response: PlanksListResponse = try await APIClient.shared.get(path)
            return response
        } catch let apiError as APIClientError {
            self.error = PlankServiceError.fromAPIError(apiError)
            throw self.error!
        } catch {
            self.error = PlankServiceError.unknown(error.localizedDescription)
            throw self.error!
        }
    }
    
    /// Clears local data (call on logout)
    func clearData() {
        planks = []
        lastSyncTimestamp = nil
        isLoading = false
        hasLoaded = false
        error = nil
    }
    
    // MARK: - Error Handling
    
    func clearError() {
        error = nil
    }
    
    // MARK: - Private Helpers
    
    private func formatISO8601Date(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
    
    private func parseISO8601Date(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) {
            return date
        }
        // Try without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }
    
    private func formatDateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

// MARK: - Plank Service Errors

enum PlankServiceError: LocalizedError, Equatable {
    case unauthorized
    case notFound
    case cannotDeleteOldPlank
    case networkError(String)
    case serverError(String)
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Please sign in to continue."
        case .notFound:
            return "Plank session not found."
        case .cannotDeleteOldPlank:
            return "You can only delete planks from today."
        case .networkError(let message):
            return "Network error: \(message)"
        case .serverError(let message):
            return message
        case .unknown(let message):
            return message
        }
    }
    
    static func fromAPIError(_ error: APIClientError) -> PlankServiceError {
        switch error {
        case .unauthorized:
            return .unauthorized
            
        case .networkError(let underlyingError):
            return .networkError(underlyingError.localizedDescription)
            
        case .apiError(let apiError):
            switch apiError.error.code {
            case "NOT_FOUND":
                return .notFound
            case "PLANK_DELETE_FORBIDDEN", "FORBIDDEN":
                return .cannotDeleteOldPlank
            default:
                return .serverError(apiError.error.message)
            }
            
        default:
            return .unknown(error.localizedDescription ?? "An unknown error occurred")
        }
    }
}
