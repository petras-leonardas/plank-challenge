import Foundation

enum AppConfig {
    /// Current app environment
    enum Environment {
        case development
        case staging
        case production
    }
    
    static let currentEnvironment: Environment = .development
    
    /// Feature flags
    enum Features {
        /// Whether to use mock data (Phase 1-4: true, Phase 5: false)
        static let useMockData: Bool = true
        
        /// Whether backend sync is enabled
        static let syncEnabled: Bool = false
        
        /// Whether analytics are enabled
        static let analyticsEnabled: Bool = false
    }
    
    /// App information
    enum AppInfo {
        static let appName = "Plank Challenge"
        static let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        static let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}
