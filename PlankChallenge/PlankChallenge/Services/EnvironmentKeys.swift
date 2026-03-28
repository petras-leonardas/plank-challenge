import SwiftUI

// MARK: - Private Environment Key Types

private struct PlankServiceKey: EnvironmentKey {
    static let defaultValue: any PlankServiceProtocol = PlankService.shared
}

private struct StreakServiceKey: EnvironmentKey {
    static let defaultValue: any StreakServiceProtocol = StreakService.shared
}

private struct BadgeServiceKey: EnvironmentKey {
    static let defaultValue: any BadgeServiceProtocol = BadgeService.shared
}

private struct UserServiceKey: EnvironmentKey {
    static let defaultValue: any UserServiceProtocol = UserService.shared
}

private struct GroupServiceKey: EnvironmentKey {
    static let defaultValue: any GroupServiceProtocol = GroupService.shared
}

private struct LeaderboardServiceKey: EnvironmentKey {
    static let defaultValue: any LeaderboardServiceProtocol = LeaderboardService.shared
}

private struct AuthServiceKey: EnvironmentKey {
    static let defaultValue: any AuthServiceProtocol = AuthService.shared
}

private struct MediaServiceKey: EnvironmentKey {
    static let defaultValue: any MediaServiceProtocol = MediaService.shared
}

private struct NotificationServiceKey: EnvironmentKey {
    static let defaultValue: any InAppNotificationServiceProtocol = InAppNotificationService.shared
}

// MARK: - EnvironmentValues Extensions

extension EnvironmentValues {
    var plankService: any PlankServiceProtocol {
        get { self[PlankServiceKey.self] }
        set { self[PlankServiceKey.self] = newValue }
    }

    var streakService: any StreakServiceProtocol {
        get { self[StreakServiceKey.self] }
        set { self[StreakServiceKey.self] = newValue }
    }

    var badgeService: any BadgeServiceProtocol {
        get { self[BadgeServiceKey.self] }
        set { self[BadgeServiceKey.self] = newValue }
    }

    var userService: any UserServiceProtocol {
        get { self[UserServiceKey.self] }
        set { self[UserServiceKey.self] = newValue }
    }

    var groupService: any GroupServiceProtocol {
        get { self[GroupServiceKey.self] }
        set { self[GroupServiceKey.self] = newValue }
    }

    var leaderboardService: any LeaderboardServiceProtocol {
        get { self[LeaderboardServiceKey.self] }
        set { self[LeaderboardServiceKey.self] = newValue }
    }

    var authService: any AuthServiceProtocol {
        get { self[AuthServiceKey.self] }
        set { self[AuthServiceKey.self] = newValue }
    }

    var mediaService: any MediaServiceProtocol {
        get { self[MediaServiceKey.self] }
        set { self[MediaServiceKey.self] = newValue }
    }

    var notificationService: any InAppNotificationServiceProtocol {
        get { self[NotificationServiceKey.self] }
        set { self[NotificationServiceKey.self] = newValue }
    }
}
