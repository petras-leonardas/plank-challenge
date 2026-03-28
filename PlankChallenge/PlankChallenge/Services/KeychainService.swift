import Foundation
import Security

/// Service for secure storage of authentication tokens in the iOS Keychain
///
/// The Keychain provides secure, encrypted storage that persists across app
/// reinstalls (if backed up) and is protected by the device's secure enclave.
///
/// This is implemented as a final class with thread-safe operations since
/// Keychain operations are already atomic at the system level.
final class KeychainService: @unchecked Sendable {
    static let shared = KeychainService()
    
    // MARK: - Keychain Keys
    
    private let accessTokenKey = AppConfig.Keychain.accessTokenKey
    private let refreshTokenKey = AppConfig.Keychain.refreshTokenKey
    private let tokenExpirationKey = AppConfig.Keychain.tokenExpirationKey
    
    /// Serial queue for coordinating keychain operations
    private let queue = DispatchQueue(label: "com.leo.PlankChallenge.keychain", qos: .userInitiated)
    
    /// Cached ISO8601 formatter for performance
    private let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    
    private init() {}
    
    // MARK: - Token Storage
    
    /// Saves both access and refresh tokens securely
    /// - Parameters:
    ///   - access: The JWT access token
    ///   - refresh: The JWT refresh token
    ///   - expiresIn: Token expiration time in seconds (optional)
    func saveTokens(access: String, refresh: String, expiresIn: Int? = nil) {
        queue.sync {
            _save(key: accessTokenKey, value: access)
            _save(key: refreshTokenKey, value: refresh)
            
            if let expiresIn = expiresIn {
                let expirationDate = Date().addingTimeInterval(TimeInterval(expiresIn))
                _save(key: tokenExpirationKey, value: dateFormatter.string(from: expirationDate))
            }
        }
    }
    
    /// Loads both tokens from the Keychain
    /// - Returns: Tuple containing access and refresh tokens, or nil if not found
    func loadTokens() -> (access: String, refresh: String)? {
        queue.sync {
            guard let access = _load(key: accessTokenKey),
                  let refresh = _load(key: refreshTokenKey) else {
                return nil
            }
            return (access, refresh)
        }
    }
    
    /// Updates only the access token (used after token refresh)
    /// - Parameters:
    ///   - token: The new access token
    ///   - expiresIn: New expiration time in seconds (optional)
    func updateAccessToken(_ token: String, expiresIn: Int? = nil) {
        queue.sync {
            _save(key: accessTokenKey, value: token)
            
            if let expiresIn = expiresIn {
                let expirationDate = Date().addingTimeInterval(TimeInterval(expiresIn))
                _save(key: tokenExpirationKey, value: dateFormatter.string(from: expirationDate))
            }
        }
    }
    
    /// Retrieves the access token
    /// - Returns: The access token string, or nil if not found
    func getAccessToken() -> String? {
        queue.sync {
            _load(key: accessTokenKey)
        }
    }
    
    /// Retrieves the refresh token
    /// - Returns: The refresh token string, or nil if not found
    func getRefreshToken() -> String? {
        queue.sync {
            _load(key: refreshTokenKey)
        }
    }
    
    /// Checks if the stored access token is expired or about to expire
    /// - Parameter buffer: Time buffer in seconds before actual expiration (default 60s)
    /// - Returns: True if token is definitively expired, false if valid or expiry unknown
    func isAccessTokenExpired(buffer: TimeInterval = 60) -> Bool {
        queue.sync {
            guard let expirationString = _load(key: tokenExpirationKey),
                  let expirationDate = dateFormatter.date(from: expirationString) else {
                // No expiry date stored — assume NOT expired and let the server
                // decide via a 401 response. Returning true here would trigger a
                // refresh attempt on every launch, which clears tokens if it fails
                // and wrongly signs the user out.
                return false
            }
            
            return Date().addingTimeInterval(buffer) >= expirationDate
        }
    }
    
    /// Removes all stored tokens from the Keychain
    func clearTokens() {
        queue.sync {
            _delete(key: accessTokenKey)
            _delete(key: refreshTokenKey)
            _delete(key: tokenExpirationKey)
        }
    }
    
    /// Checks if tokens exist in the Keychain
    /// - Returns: True if both access and refresh tokens are stored
    var hasStoredTokens: Bool {
        var result = false
        queue.sync {
            result = _load(key: accessTokenKey) != nil && _load(key: refreshTokenKey) != nil
        }
        return result
    }
    
    // MARK: - Private Keychain Operations
    
    /// Internal save operation (not thread-safe, must be called within queue.sync)
    private func _save(key: String, value: String) {
        guard let data = value.data(using: .utf8) else {
            logError("Failed to encode value for key: \(key)")
            return
        }
        
        // Build base query for finding/deleting existing item
        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: AppConfig.appBundleId
        ]
        
        // Delete any existing item first
        let deleteStatus = SecItemDelete(baseQuery as CFDictionary)
        if deleteStatus != errSecSuccess && deleteStatus != errSecItemNotFound {
            logError("Failed to delete existing item for key \(key): \(deleteStatus)")
        }
        
        // Build query with data for adding
        var addQuery = baseQuery
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        
        // Add the new item
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        
        if addStatus != errSecSuccess {
            logError("Failed to save key \(key): \(addStatus) - \(securityErrorMessage(addStatus))")
        }
    }
    
    /// Internal load operation (not thread-safe, must be called within queue.sync)
    private func _load(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: AppConfig.appBundleId,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else {
            if status != errSecItemNotFound {
                logError("Failed to load key \(key): \(status) - \(securityErrorMessage(status))")
            }
            return nil
        }
        
        guard let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            logError("Failed to decode data for key: \(key)")
            return nil
        }
        
        return string
    }
    
    /// Internal delete operation (not thread-safe, must be called within queue.sync)
    private func _delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: AppConfig.appBundleId
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        if status != errSecSuccess && status != errSecItemNotFound {
            logError("Failed to delete key \(key): \(status) - \(securityErrorMessage(status))")
        }
    }
    
    // MARK: - Error Logging
    
    private func logError(_ message: String) {
        #if DEBUG
        print("KeychainService Error: \(message)")
        #endif
        // In production, you might want to log to a crash reporting service
        // but NEVER log the actual token values
    }
    
    /// Converts Security framework status codes to human-readable messages
    private func securityErrorMessage(_ status: OSStatus) -> String {
        switch status {
        case errSecSuccess:
            return "Success"
        case errSecItemNotFound:
            return "Item not found"
        case errSecDuplicateItem:
            return "Duplicate item"
        case errSecAuthFailed:
            return "Authentication failed"
        case errSecParam:
            return "Invalid parameter"
        case errSecAllocate:
            return "Memory allocation failed"
        case errSecNotAvailable:
            return "Keychain not available"
        case errSecInteractionNotAllowed:
            return "Interaction not allowed (device locked?)"
        case errSecDecode:
            return "Unable to decode data"
        default:
            return "Unknown error (\(status))"
        }
    }
    
    // MARK: - Debug Helpers
    
    #if DEBUG
    /// Prints the current token state for debugging (does not print actual tokens)
    func debugPrintState() {
        let hasAccess = getAccessToken() != nil
        let hasRefresh = getRefreshToken() != nil
        let isExpired = isAccessTokenExpired()
        
        print("""
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        KeychainService State:
        - Has Access Token: \(hasAccess)
        - Has Refresh Token: \(hasRefresh)
        - Is Expired: \(isExpired)
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        """)
    }
    
    /// Clears all keychain items for this app (USE WITH CAUTION)
    func debugClearAll() {
        clearTokens()
        print("KeychainService: All tokens cleared")
    }
    #endif
}
