//
//  ErrorView.swift
//  PlankChallenge
//
//  Created by Leo Bacevicius on 15/03/2026.
//

import SwiftUI

/// Reusable error view component with retry functionality
///
/// Usage:
/// ```swift
/// if let error = viewModel.error {
///     ErrorView(error: error) {
///         await viewModel.retry()
///     }
/// }
/// ```
struct ErrorView: View {
    let error: Error
    let retryAction: (() async -> Void)?
    
    /// Creates an error view with an optional retry action
    /// - Parameters:
    ///   - error: The error to display
    ///   - retryAction: Optional async closure to retry the failed operation
    init(error: Error, retryAction: (() async -> Void)? = nil) {
        self.error = error
        self.retryAction = retryAction
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: iconName)
                .font(.system(size: 48))
                .foregroundStyle(iconColor)
            
            Text(title)
                .font(.headline)
            
            Text(errorMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            if let retryAction {
                Button {
                    Task { await retryAction() }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                        Text("Try Again")
                    }
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Computed Properties
    
    private var title: String {
        if isNetworkError {
            return "No connection"
        } else if isAuthError {
            return "Session expired"
        } else {
            return "Something went wrong"
        }
    }
    
    private var iconName: String {
        if isNetworkError {
            return "wifi.slash"
        } else if isAuthError {
            return "lock.circle"
        } else {
            return "exclamationmark.triangle"
        }
    }
    
    private var iconColor: Color {
        if isNetworkError {
            return Color.warningColor
        } else if isAuthError {
            return Color.appAccent
        } else {
            return Color.errorColor
        }
    }
    
    private var errorMessage: String {
        // Handle API errors with user-friendly messages
        if let apiError = error as? APIErrorResponse {
            return apiError.error.message
        }
        
        // Handle API client errors
        if let clientError = error as? APIClientError {
            switch clientError {
            case .unauthorized:
                return "Sign in again to continue."
            case .networkError:
                return "Check your internet connection and try again."
            case .invalidURL:
                return "Something went wrong. Try again."
            case .invalidResponse:
                return "Something went wrong. Try again."
            case .decodingError:
                return "Something went wrong. Try again."
            case .apiError(let apiError):
                return apiError.error.message
            case .httpError(let statusCode, _):
                return "Our servers hit a snag (error \(statusCode)). Try again in a moment."
            }
        }
        
        // Handle service-specific errors
        if let serviceError = error as? UserServiceError {
            return serviceError.localizedDescription
        }
        if let serviceError = error as? GroupServiceError {
            return serviceError.localizedDescription
        }
        if let serviceError = error as? LeaderboardServiceError {
            return serviceError.localizedDescription
        }
        if let serviceError = error as? PlankServiceError {
            return serviceError.localizedDescription
        }
        if let serviceError = error as? StreakServiceError {
            return serviceError.localizedDescription
        }
        if let serviceError = error as? BadgeServiceError {
            return serviceError.localizedDescription
        }
        if let serviceError = error as? InAppNotificationServiceError {
            return serviceError.localizedDescription
        }
        
        // Default message
        return "An unexpected error occurred. Try again."
    }
    
    private var isNetworkError: Bool {
        if let clientError = error as? APIClientError {
            if case .networkError = clientError {
                return true
            }
        }
        
        // Check for URL loading errors
        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain
    }
    
    private var isAuthError: Bool {
        if let clientError = error as? APIClientError {
            if case .unauthorized = clientError {
                return true
            }
        }
        
        if let apiError = error as? APIErrorResponse {
            return apiError.error.code == "AUTH_REQUIRED" ||
                   apiError.error.code == "AUTH_EXPIRED" ||
                   apiError.error.code == "AUTH_INVALID"
        }
        
        return false
    }
}

// MARK: - Compact Error View

/// A more compact error view for inline use
struct CompactErrorView: View {
    let message: String
    let retryAction: (() -> Void)?
    
    init(_ message: String, retryAction: (() -> Void)? = nil) {
        self.message = message
        self.retryAction = retryAction
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.red)
            
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            if let retryAction {
                Button {
                    retryAction()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.subheadline)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding()
        .background(Color.errorColor.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: Constants.UI.cardRadius))
    }
}

// MARK: - Error Banner

/// An error banner that can be shown at the top of a view
struct ErrorBanner: View {
    let message: String
    let isShowing: Binding<Bool>
    
    var body: some View {
        if isShowing.wrappedValue {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.white)
                
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                
                Spacer()
                
                Button {
                    withAnimation {
                        isShowing.wrappedValue = false
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            .padding()
            .background(Color.errorColor)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

// MARK: - Previews

#Preview("Error View - Network") {
    ErrorView(error: APIClientError.networkError(URLError(.notConnectedToInternet))) {
        // Retry action
    }
}

#Preview("Error View - Auth") {
    ErrorView(error: APIClientError.unauthorized) {
        // Retry action
    }
}

#Preview("Error View - Generic") {
    ErrorView(error: NSError(domain: "Test", code: 0, userInfo: [NSLocalizedDescriptionKey: "Test error"]))
}

#Preview("Compact Error") {
    CompactErrorView("Failed to load data") {
        // Retry
    }
    .padding()
}
