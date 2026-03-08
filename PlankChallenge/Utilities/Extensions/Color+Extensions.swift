import SwiftUI

extension Color {
    // MARK: - App Colors (Apple Health-inspired)
    
    /// Primary accent color
    static let appAccent = Color.blue
    
    /// Streak color (orange/red gradient would be nice)
    static let streakColor = Color.orange
    
    /// Success color
    static let successColor = Color.green
    
    /// Warning color
    static let warningColor = Color.yellow
    
    /// Error color
    static let errorColor = Color.red
    
    // MARK: - Plank Type Colors
    
    static func colorForPlankType(_ type: Constants.Plank.PlankType) -> Color {
        switch type {
        case .elbow:
            return .blue
        case .straightArm:
            return .green
        case .parallettes:
            return .purple
        }
    }
}
