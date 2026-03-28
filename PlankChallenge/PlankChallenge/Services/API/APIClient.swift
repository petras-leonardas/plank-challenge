import Foundation
import UIKit

/// Main API client for communicating with the PlankChallenge backend
///
/// This actor-based client handles:
/// - Request building with proper headers and encoding
/// - Token management and automatic refresh
/// - Retry logic for transient failures
/// - Error handling and mapping
///
/// Usage:
/// ```swift
/// let user: APIUser = try await APIClient.shared.request(endpoint: "/users/me")
/// ```
actor APIClient {
    static let shared = APIClient()
    
    // MARK: - Properties
    
    private let baseURL: String
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    
    private var accessToken: String?
    private var refreshToken: String?
    private var isRefreshing = false
    private var refreshWaiters: [CheckedContinuation<Bool, Never>] = []
    
    // MARK: - Initialization
    
    private init() {
        self.baseURL = AppConfig.API.baseURL
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = AppConfig.API.timeoutInterval
        config.timeoutIntervalForResource = AppConfig.API.timeoutInterval * 2
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config)
        
        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder.dateDecodingStrategy = .iso8601
        
        self.encoder = JSONEncoder()
        // No keyEncodingStrategy — backend expects camelCase keys.
        // The decoder uses convertFromSnakeCase because backend responses use snake_case.
        self.encoder.dateEncodingStrategy = .iso8601
    }
    
    // MARK: - Token Management
    
    /// Sets authentication tokens after login
    /// - Parameters:
    ///   - access: JWT access token
    ///   - refresh: JWT refresh token
    ///   - expiresIn: Token expiration time in seconds
    func setTokens(access: String, refresh: String, expiresIn: Int? = nil) {
        self.accessToken = access
        self.refreshToken = refresh
        KeychainService.shared.saveTokens(access: access, refresh: refresh, expiresIn: expiresIn)
    }
    
    /// Clears all authentication tokens (logout)
    func clearTokens() {
        self.accessToken = nil
        self.refreshToken = nil
        KeychainService.shared.clearTokens()
    }
    
    /// Loads tokens from Keychain on app launch
    func loadTokensFromKeychain() {
        if let tokens = KeychainService.shared.loadTokens() {
            self.accessToken = tokens.access
            self.refreshToken = tokens.refresh
        }
    }
    
    /// Whether the client has valid authentication tokens
    var isAuthenticated: Bool {
        accessToken != nil
    }
    
    /// Returns the current access token (for external use if needed)
    var currentAccessToken: String? {
        accessToken
    }
    
    /// Returns the current refresh token (needed for logout)
    var currentRefreshToken: String? {
        refreshToken
    }
    
    // MARK: - Request Building
    
    private func buildRequest(
        endpoint: String,
        method: HTTPMethod,
        body: AnyEncodable? = nil,
        queryItems: [URLQueryItem]? = nil,
        requiresAuth: Bool = true
    ) throws -> URLRequest {
        // Build URL with query parameters
        var urlString = baseURL + endpoint
        
        if let queryItems = queryItems, !queryItems.isEmpty {
            var components = URLComponents(string: urlString)
            components?.queryItems = queryItems
            urlString = components?.string ?? urlString
        }
        
        guard let url = URL(string: urlString) else {
            throw APIClientError.invalidURL(urlString)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // Add user agent for analytics
        let userAgent = "\(AppConfig.AppInfo.appName)/\(AppConfig.AppInfo.appVersion) iOS/\(UIDevice.current.systemVersion)"
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        
        // Add timezone header
        request.setValue(TimeZone.current.identifier, forHTTPHeaderField: "X-Timezone")
        
        // Add request ID for debugging/correlation
        let requestId = UUID().uuidString
        request.setValue(requestId, forHTTPHeaderField: "X-Request-ID")
        
        // Add auth header if required
        if requiresAuth, let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Encode body if present
        if let body = body {
            request.httpBody = try encoder.encode(body)
        }
        
        return request
    }
    
    // MARK: - Request Execution (Generic)
    
    /// Performs an API request and decodes the response
    /// - Parameters:
    ///   - endpoint: API endpoint (e.g., "/users/me")
    ///   - method: HTTP method (default: GET)
    ///   - body: Request body (optional)
    ///   - queryItems: URL query parameters (optional)
    ///   - requiresAuth: Whether to include auth token (default: true)
    /// - Returns: Decoded response data
    func request<T: Decodable>(
        endpoint: String,
        method: HTTPMethod = .get,
        body: (some Encodable)? = nil as AnyEncodable?,
        queryItems: [URLQueryItem]? = nil,
        requiresAuth: Bool = true
    ) async throws -> T {
        // Wrap body in AnyEncodable if present
        let wrappedBody: AnyEncodable? = body.map { AnyEncodable($0) }
        
        // Check for token expiration before making request
        if requiresAuth && KeychainService.shared.isAccessTokenExpired() {
            let refreshed = try await refreshAccessToken()
            if !refreshed {
                throw APIClientError.unauthorized
            }
        }
        
        return try await executeRequest(
            endpoint: endpoint,
            method: method,
            body: wrappedBody,
            queryItems: queryItems,
            requiresAuth: requiresAuth,
            retryCount: 0
        )
    }
    
    private func executeRequest<T: Decodable>(
        endpoint: String,
        method: HTTPMethod,
        body: AnyEncodable?,
        queryItems: [URLQueryItem]?,
        requiresAuth: Bool,
        retryCount: Int
    ) async throws -> T {
        let request = try buildRequest(
            endpoint: endpoint,
            method: method,
            body: body,
            queryItems: queryItems,
            requiresAuth: requiresAuth
        )
        
        #if DEBUG
        logRequest(request)
        #endif
        
        let (data, response): (Data, URLResponse)
        
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            // Network error - retry if appropriate
            if retryCount < AppConfig.API.maxRetries && isRetryableError(error) {
                try await Task.sleep(nanoseconds: UInt64(AppConfig.API.retryDelay * 1_000_000_000))
                return try await executeRequest(
                    endpoint: endpoint,
                    method: method,
                    body: body,
                    queryItems: queryItems,
                    requiresAuth: requiresAuth,
                    retryCount: retryCount + 1
                )
            }
            throw APIClientError.networkError(error)
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIClientError.invalidResponse
        }
        
        #if DEBUG
        logResponse(httpResponse, data: data)
        #endif
        
        // Handle 401 - try to refresh token
        if httpResponse.statusCode == 401 && requiresAuth {
            let refreshed = try await refreshAccessToken()
            if refreshed {
                // Retry with new token
                return try await executeRequest(
                    endpoint: endpoint,
                    method: method,
                    body: body,
                    queryItems: queryItems,
                    requiresAuth: requiresAuth,
                    retryCount: 0
                )
            } else {
                throw APIClientError.unauthorized
            }
        }
        
        // Handle error responses
        if httpResponse.statusCode >= 400 {
            if let apiError = try? decoder.decode(APIErrorResponse.self, from: data) {
                throw APIClientError.apiError(apiError)
            }
            throw APIClientError.httpError(statusCode: httpResponse.statusCode, data: data)
        }
        
        // Handle empty response for EmptyResponse type
        if T.self == EmptyResponse.self {
            // swiftlint:disable:next force_cast
            return EmptyResponse() as! T
        }
        
        // Decode success response
        do {
            let apiResponse = try decoder.decode(APIResponse<T>.self, from: data)
            return apiResponse.data
        } catch {
            // Try decoding without wrapper for some endpoints
            do {
                return try decoder.decode(T.self, from: data)
            } catch let decodingError {
                throw APIClientError.decodingError(decodingError, data: data)
            }
        }
    }
    
    // MARK: - Token Refresh
    
    private func refreshAccessToken() async throws -> Bool {
        // If already refreshing, wait for that to complete
        if isRefreshing {
            return await withCheckedContinuation { continuation in
                refreshWaiters.append(continuation)
            }
        }
        
        guard let refreshToken = refreshToken else {
            return false
        }
        
        isRefreshing = true
        defer {
            isRefreshing = false
            // Resume all waiters with the result
            let waiters = refreshWaiters
            refreshWaiters.removeAll()
            for waiter in waiters {
                waiter.resume(returning: accessToken != nil)
            }
        }
        
        let body = AnyEncodable(RefreshTokenRequest(refreshToken: refreshToken))
        let request = try buildRequest(
            endpoint: "/auth/refresh",
            method: .post,
            body: body,
            requiresAuth: false
        )
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                clearTokens()
                return false
            }
            
            let tokenResponse = try decoder.decode(
                APIResponse<TokenRefreshResponse>.self,
                from: data
            )
            
            // Update both tokens (backend returns new refresh token too)
            self.accessToken = tokenResponse.data.accessToken
            self.refreshToken = tokenResponse.data.refreshToken
            KeychainService.shared.saveTokens(
                access: tokenResponse.data.accessToken,
                refresh: tokenResponse.data.refreshToken,
                expiresIn: tokenResponse.data.expiresIn
            )
            
            return true
        } catch {
            clearTokens()
            return false
        }
    }
    
    // MARK: - Retry Logic
    
    private func isRetryableError(_ error: Error) -> Bool {
        let nsError = error as NSError
        
        // Network connectivity errors
        let retryableCodes = [
            NSURLErrorTimedOut,
            NSURLErrorCannotFindHost,
            NSURLErrorCannotConnectToHost,
            NSURLErrorNetworkConnectionLost,
            NSURLErrorNotConnectedToInternet
        ]
        
        return retryableCodes.contains(nsError.code)
    }
    
    // MARK: - Logging
    
    #if DEBUG
    private nonisolated func logRequest(_ request: URLRequest) {
        let method = request.httpMethod ?? "?"
        let url = request.url?.absoluteString ?? "?"
        let headers = request.allHTTPHeaderFields?.filter { $0.key != "Authorization" } ?? [:]
        let body = request.httpBody.flatMap { String(data: $0, encoding: .utf8) } ?? "none"
        
        print("""
        
        ➡️ API Request: \(method) \(url)
        Headers: \(headers)
        Body: \(body)
        """)
    }
    
    private nonisolated func logResponse(_ response: HTTPURLResponse, data: Data) {
        let statusEmoji = response.statusCode < 400 ? "✅" : "❌"
        let bodyPreview = String(data: data.prefix(500), encoding: .utf8) ?? "binary"
        let truncated = data.count > 500 ? "... (\(data.count) bytes total)" : ""
        
        print("""
        \(statusEmoji) API Response: \(response.statusCode)
        Body: \(bodyPreview)\(truncated)
        """)
    }
    #endif
}

// MARK: - Supporting Types

/// HTTP methods supported by the API
enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

/// Errors that can occur during API requests
enum APIClientError: LocalizedError, @unchecked Sendable {
    case invalidURL(String)
    case invalidResponse
    case httpError(statusCode: Int, data: Data)
    case unauthorized
    case networkError(Error)
    case decodingError(Error, data: Data)
    case apiError(APIErrorResponse)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL(let url):
            return "Invalid URL: \(url)"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let statusCode, _):
            return "HTTP error: \(statusCode)"
        case .unauthorized:
            return "Your session has expired. Please sign in again."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error, _):
            return "Failed to decode response: \(error.localizedDescription)"
        case .apiError(let error):
            return error.error.message
        }
    }
    
    /// Returns true if this error indicates the user needs to re-authenticate
    var requiresReauthentication: Bool {
        if case .unauthorized = self { return true }
        if case .apiError(let error) = self {
            return error.error.code == "AUTH_REQUIRED" ||
                   error.error.code == "AUTH_EXPIRED" ||
                   error.error.code == "AUTH_INVALID"
        }
        return false
    }
    
    /// The API error code if this is an API error
    var apiErrorCode: String? {
        if case .apiError(let error) = self {
            return error.error.code
        }
        return nil
    }
    
    /// The HTTP status code if available
    var statusCode: Int? {
        switch self {
        case .httpError(let code, _):
            return code
        case .unauthorized:
            return 401
        default:
            return nil
        }
    }
}

// MARK: - Convenience Extensions

extension APIClient {
    /// Performs a GET request
    func get<T: Decodable>(
        _ endpoint: String,
        queryItems: [URLQueryItem]? = nil,
        requiresAuth: Bool = true
    ) async throws -> T {
        try await request(
            endpoint: endpoint,
            method: .get,
            body: nil as AnyEncodable?,
            queryItems: queryItems,
            requiresAuth: requiresAuth
        )
    }
    
    /// Performs a POST request with a body
    func post<T: Decodable, B: Encodable>(
        _ endpoint: String,
        body: B,
        requiresAuth: Bool = true
    ) async throws -> T {
        try await request(
            endpoint: endpoint,
            method: .post,
            body: body,
            requiresAuth: requiresAuth
        )
    }
    
    /// Performs a POST request without a body
    func post<T: Decodable>(
        _ endpoint: String,
        requiresAuth: Bool = true
    ) async throws -> T {
        try await request(
            endpoint: endpoint,
            method: .post,
            body: nil as AnyEncodable?,
            requiresAuth: requiresAuth
        )
    }
    
    /// Performs a PUT request
    func put<T: Decodable, B: Encodable>(
        _ endpoint: String,
        body: B,
        requiresAuth: Bool = true
    ) async throws -> T {
        try await request(
            endpoint: endpoint,
            method: .put,
            body: body,
            requiresAuth: requiresAuth
        )
    }
    
    /// Performs a PATCH request
    func patch<T: Decodable, B: Encodable>(
        _ endpoint: String,
        body: B,
        requiresAuth: Bool = true
    ) async throws -> T {
        try await request(
            endpoint: endpoint,
            method: .patch,
            body: body,
            requiresAuth: requiresAuth
        )
    }
    
    /// Performs a DELETE request
    func delete<T: Decodable>(
        _ endpoint: String,
        requiresAuth: Bool = true
    ) async throws -> T {
        try await request(
            endpoint: endpoint,
            method: .delete,
            body: nil as AnyEncodable?,
            requiresAuth: requiresAuth
        )
    }
    
    /// Uploads raw binary data (e.g., image) to the given endpoint.
    ///
    /// The backend for avatar upload expects the raw image bytes in the body
    /// with an appropriate Content-Type (image/jpeg, image/png, image/webp).
    ///
    /// - Parameters:
    ///   - endpoint: API endpoint (e.g., "/media/avatar")
    ///   - data: Raw binary data to upload
    ///   - contentType: MIME type of the data (e.g., "image/jpeg")
    /// - Returns: Decoded response
    func uploadBinary<T: Decodable>(
        _ endpoint: String,
        data: Data,
        contentType: String
    ) async throws -> T {
        guard let url = URL(string: baseURL + endpoint) else {
            throw APIClientError.invalidURL(baseURL + endpoint)
        }
        
        // Ensure we have a valid token
        if KeychainService.shared.isAccessTokenExpired() {
            let refreshed = try await refreshAccessToken()
            if !refreshed {
                throw APIClientError.unauthorized
            }
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = HTTPMethod.post.rawValue
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue("\(data.count)", forHTTPHeaderField: "Content-Length")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let userAgent = "\(AppConfig.AppInfo.appName)/\(AppConfig.AppInfo.appVersion) iOS/\(UIDevice.current.systemVersion)"
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(TimeZone.current.identifier, forHTTPHeaderField: "X-Timezone")
        request.setValue(UUID().uuidString, forHTTPHeaderField: "X-Request-ID")
        
        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            throw APIClientError.unauthorized
        }
        
        request.httpBody = data
        
        #if DEBUG
        print("➡️ Upload: POST \(endpoint) (\(data.count) bytes, \(contentType))")
        #endif
        
        let (responseData, response): (Data, URLResponse)
        do {
            (responseData, response) = try await session.data(for: request)
        } catch {
            throw APIClientError.networkError(error)
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIClientError.invalidResponse
        }
        
        // Handle 401 - try token refresh once
        if httpResponse.statusCode == 401 {
            let refreshed = try await refreshAccessToken()
            if refreshed {
                return try await uploadBinary(endpoint, data: data, contentType: contentType)
            }
            throw APIClientError.unauthorized
        }
        
        if httpResponse.statusCode >= 400 {
            if let apiError = try? decoder.decode(APIErrorResponse.self, from: responseData) {
                throw APIClientError.apiError(apiError)
            }
            throw APIClientError.httpError(statusCode: httpResponse.statusCode, data: responseData)
        }
        
        do {
            let apiResponse = try decoder.decode(APIResponse<T>.self, from: responseData)
            return apiResponse.data
        } catch {
            return try decoder.decode(T.self, from: responseData)
        }
    }
}
