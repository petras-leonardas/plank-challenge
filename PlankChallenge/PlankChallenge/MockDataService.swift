//
//  MockDataService.swift
//  PlankChallenge
//
//  Created by Leo Bacevicius on 08/03/2026.
//

import Foundation
import Observation

@Observable
@MainActor
final class MockDataService {
    static let shared = MockDataService()
    
    var currentUser: UserProfile
    var plankSessions: [PlankSession]
    var badges: [Badge]
    var notifications: [MockNotification]
    var groups: [MockGroup]
    var leaderboardUsers: [LeaderboardUser]
    var mockUsers: [MockUser]
    var following: [MockUser]
    var followers: [MockUser]
    
    private init() {
        // Create mock users first (for leaderboards, groups, social)
        let users: [MockUser] = [
            MockUser(displayName: "Sarah Chen", profileImageName: "person.circle.fill", currentStreak: 127, longestPlankSeconds: 312, totalPlanks: 245, badges: [.streak7, .streak14, .streak30, .streak60, .streak90]),
            MockUser(displayName: "Marcus Johnson", profileImageName: "person.circle.fill", currentStreak: 89, longestPlankSeconds: 285, totalPlanks: 156, badges: [.streak7, .streak14, .streak30, .streak60]),
            MockUser(displayName: "Emma Wilson", profileImageName: "person.circle.fill", currentStreak: 73, longestPlankSeconds: 248, totalPlanks: 198, badges: [.streak7, .streak14, .streak30, .streak60]),
            MockUser(displayName: "David Park", profileImageName: "person.circle.fill", currentStreak: 56, longestPlankSeconds: 421, totalPlanks: 89, badges: [.streak7, .streak14, .streak30]),
            MockUser(displayName: "Lisa Martinez", profileImageName: "person.circle.fill", currentStreak: 45, longestPlankSeconds: 195, totalPlanks: 112, badges: [.streak7, .streak14, .streak30]),
            MockUser(displayName: "James Thompson", profileImageName: "person.circle.fill", currentStreak: 34, longestPlankSeconds: 267, totalPlanks: 78, badges: [.streak7, .streak14, .streak30]),
            MockUser(displayName: "Nina Patel", profileImageName: "person.circle.fill", currentStreak: 28, longestPlankSeconds: 183, totalPlanks: 65, badges: [.streak7, .streak14]),
            MockUser(displayName: "Chris Anderson", profileImageName: "person.circle.fill", currentStreak: 21, longestPlankSeconds: 156, totalPlanks: 43, badges: [.streak7, .streak14]),
            MockUser(displayName: "Amy Zhang", profileImageName: "person.circle.fill", currentStreak: 18, longestPlankSeconds: 201, totalPlanks: 52, badges: [.streak7, .streak14]),
            MockUser(displayName: "Robert Kim", profileImageName: "person.circle.fill", currentStreak: 14, longestPlankSeconds: 142, totalPlanks: 31, badges: [.streak7, .streak14]),
            MockUser(displayName: "Michelle Brown", profileImageName: "person.circle.fill", currentStreak: 11, longestPlankSeconds: 178, totalPlanks: 27, badges: [.streak7]),
            MockUser(displayName: "Kevin Lee", profileImageName: "person.circle.fill", currentStreak: 9, longestPlankSeconds: 124, totalPlanks: 19, badges: [.streak7]),
            MockUser(displayName: "Jennifer Davis", profileImageName: "person.circle.fill", currentStreak: 7, longestPlankSeconds: 98, totalPlanks: 14, badges: [.streak7]),
            MockUser(displayName: "Michael Scott", profileImageName: "person.circle.fill", currentStreak: 5, longestPlankSeconds: 67, totalPlanks: 8, badges: []),
            MockUser(displayName: "Rachel Green", profileImageName: "person.circle.fill", currentStreak: 3, longestPlankSeconds: 45, totalPlanks: 5, badges: [])
        ]
        self.mockUsers = users
        
        // Create current user
        var user = UserProfile(displayName: "Leo", location: "London, UK")
        user.currentStreak = 14
        user.longestStreak = 21
        user.freezeTokens = 2
        user.bio = "Plank enthusiast. Building core strength one day at a time."
        self.currentUser = user
        
        // Create mock plank sessions (last 30 days with some gaps)
        var sessions: [PlankSession] = []
        for i in 0..<30 {
            // Skip some days randomly to simulate missed days
            if i > 14 && Int.random(in: 0...10) < 3 {
                continue
            }
            
            let date = Calendar.current.date(byAdding: .day, value: -i, to: Date())!
            let baseDuration: TimeInterval = 60 + Double(30 - i) * 3
            let variation = Double.random(in: -15...15)
            let duration = max(30, baseDuration + variation)
            let plankType = Constants.Plank.PlankType.allCases.randomElement() ?? .elbow
            let inputMethod: PlankSession.InputMethod = Int.random(in: 0...10) < 8 ? .timer : .manual
            
            let session = PlankSession(
                date: date,
                durationSeconds: duration,
                plankType: plankType,
                inputMethod: inputMethod
            )
            sessions.append(session)
        }
        self.plankSessions = sessions
        
        // Create earned badges
        self.badges = [
            Badge(badgeType: .streak7),
            Badge(badgeType: .streak14)
        ]
        
        // Create mock notifications
        self.notifications = [
            MockNotification(type: .badgeEarned, title: "New Badge Earned!", message: "Congratulations! You've earned the '2 Week Champion' badge for your 14-day streak!", isRead: false, createdAt: Date().addingTimeInterval(-3600)),
            MockNotification(type: .groupJoined, title: "Welcome to Cloudflare Plankers!", message: "You've successfully joined the group. Start planking to appear on the leaderboard!", isRead: true, createdAt: Date().addingTimeInterval(-86400 * 2)),
            MockNotification(type: .tokenEarned, title: "Freeze Token Earned!", message: "Amazing! You've reached a 20-day streak and earned a freeze token.", isRead: true, createdAt: Date().addingTimeInterval(-86400 * 5)),
            MockNotification(type: .streakFreezeUsed, title: "Streak Saved!", message: "Your streak freeze token was used yesterday. You have 1 token remaining. Don't forget to plank today!", isRead: true, createdAt: Date().addingTimeInterval(-86400 * 10)),
            MockNotification(type: .promotedToAdmin, title: "You're Now an Admin", message: "You've been promoted to admin in 'Weekend Warriors'. You can now manage group settings.", isRead: true, createdAt: Date().addingTimeInterval(-86400 * 15))
        ]
        
        // Create mock groups
        self.groups = [
            MockGroup(name: "Cloudflare Plankers", description: "Official Cloudflare employee plank challenge. Let's build core strength together!", groupType: .privateInvite, joinMode: .open, memberCount: 47, isCurrentUserMember: true, isCurrentUserAdmin: true, members: Array(users.prefix(10)), lastActivityDate: Date().addingTimeInterval(-3600)), // 1 hour ago
            MockGroup(name: "Weekend Warriors", description: "Friends challenging each other to stay consistent. No excuses!", groupType: .privateInvite, joinMode: .open, memberCount: 8, isCurrentUserMember: true, isCurrentUserAdmin: false, members: Array(users.prefix(8)), lastActivityDate: Date().addingTimeInterval(-86400)), // 1 day ago
            MockGroup(name: "NYC Fitness Club", description: "New York City fitness enthusiasts. Open to all NYC plankers!", groupType: .publicOpen, joinMode: .open, memberCount: 234, isCurrentUserMember: false, isCurrentUserAdmin: false, members: Array(users.shuffled().prefix(15)), lastActivityDate: Date().addingTimeInterval(-7200)),
            MockGroup(name: "Morning Plankers", description: "We plank before 7am. Early bird gets the strong core!", groupType: .publicOpen, joinMode: .requestToJoin, memberCount: 89, isCurrentUserMember: false, isCurrentUserAdmin: false, members: Array(users.shuffled().prefix(12)), lastActivityDate: Date().addingTimeInterval(-14400)),
            MockGroup(name: "Tech Industry Plank Off", description: "Engineers, designers, and PMs competing for plank supremacy.", groupType: .publicOpen, joinMode: .open, memberCount: 312, isCurrentUserMember: false, isCurrentUserAdmin: false, members: Array(users.shuffled().prefix(15)), lastActivityDate: Date().addingTimeInterval(-28800)),
            MockGroup(name: "Beginner Plankers", description: "Just starting out? This is a supportive group for beginners!", groupType: .publicOpen, joinMode: .open, memberCount: 156, isCurrentUserMember: false, isCurrentUserAdmin: false, members: Array(users.suffix(10)), lastActivityDate: Date().addingTimeInterval(-43200))
        ]
        
        // Create leaderboard users
        self.leaderboardUsers = [
            LeaderboardUser(rank: 1, displayName: "Sarah Chen", currentStreak: 127, longestPlankSeconds: 312, badges: [.streak7, .streak14, .streak30, .streak60, .streak90]),
            LeaderboardUser(rank: 2, displayName: "Marcus Johnson", currentStreak: 89, longestPlankSeconds: 285, badges: [.streak7, .streak14, .streak30, .streak60]),
            LeaderboardUser(rank: 3, displayName: "Emma Wilson", currentStreak: 73, longestPlankSeconds: 248, badges: [.streak7, .streak14, .streak30, .streak60]),
            LeaderboardUser(rank: 4, displayName: "David Park", currentStreak: 56, longestPlankSeconds: 421, badges: [.streak7, .streak14, .streak30]),
            LeaderboardUser(rank: 5, displayName: "Lisa Martinez", currentStreak: 45, longestPlankSeconds: 195, badges: [.streak7, .streak14, .streak30]),
            LeaderboardUser(rank: 6, displayName: "James Thompson", currentStreak: 34, longestPlankSeconds: 267, badges: [.streak7, .streak14, .streak30]),
            LeaderboardUser(rank: 7, displayName: "Nina Patel", currentStreak: 28, longestPlankSeconds: 183, badges: [.streak7, .streak14]),
            LeaderboardUser(rank: 8, displayName: "Leo", currentStreak: 14, longestPlankSeconds: 180, isCurrentUser: true, badges: [.streak7, .streak14]),
            LeaderboardUser(rank: 9, displayName: "Chris Anderson", currentStreak: 21, longestPlankSeconds: 156, badges: [.streak7, .streak14]),
            LeaderboardUser(rank: 10, displayName: "Amy Zhang", currentStreak: 18, longestPlankSeconds: 201, badges: [.streak7, .streak14])
        ]
        
        // Create following/followers
        self.following = Array(users.prefix(6))
        self.followers = Array(users.shuffled().prefix(8))
    }
    
    // MARK: - Helper Methods
    
    var todaysPlank: PlankSession? {
        plankSessions.first { Calendar.current.isDateInToday($0.date) }
    }
    
    var hasPlankToday: Bool {
        todaysPlank != nil
    }
    
    var longestPlank: PlankSession? {
        plankSessions.max { $0.durationSeconds < $1.durationSeconds }
    }
    
    var totalPlanks: Int {
        plankSessions.count
    }
    
    var totalPlankTime: TimeInterval {
        plankSessions.reduce(0) { $0 + $1.durationSeconds }
    }
    
    var averageDuration: TimeInterval {
        guard !plankSessions.isEmpty else { return 0 }
        let total = plankSessions.reduce(0) { $0 + $1.durationSeconds }
        return total / Double(plankSessions.count)
    }
    
    /// All plank sessions sorted by date (most recent first)
    var plankHistory: [PlankSession] {
        plankSessions.sorted { $0.date > $1.date }
    }
    
    func addPlankSession(_ session: PlankSession) {
        plankSessions.insert(session, at: 0)
    }
    
    // MARK: - Leaderboard Helpers
    
    var streakLeaderboard: [LeaderboardUser] {
        leaderboardUsers.sorted { $0.currentStreak > $1.currentStreak }
    }
    
    var longestPlankLeaderboard: [LeaderboardUser] {
        leaderboardUsers.sorted { $0.longestPlankSeconds > $1.longestPlankSeconds }
    }
    
    // MARK: - Group Helpers
    
    var myGroups: [MockGroup] {
        groups.filter { $0.isCurrentUserMember }
    }
    
    /// My groups sorted by most recent activity first
    var myGroupsSortedByActivity: [MockGroup] {
        myGroups.sorted { $0.lastActivityDate > $1.lastActivityDate }
    }
    
    var discoverGroups: [MockGroup] {
        groups.filter { $0.groupType == .publicOpen && !$0.isCurrentUserMember }
    }
    
    // MARK: - Plank History Helpers
    
    func plankHistory(days: Int = 60) -> [PlankSession] {
        plankSessions.sorted { $0.date > $1.date }
    }
    
    var plankHistoryGroupedByMonth: [(key: String, sessions: [PlankSession])] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        
        let grouped = Dictionary(grouping: plankSessions) { session in
            formatter.string(from: session.date)
        }
        
        return grouped.map { (key: $0.key, sessions: $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.sessions.first?.date ?? Date() > $1.sessions.first?.date ?? Date() }
    }
    
    // MARK: - Current User Stats
    
    var currentUserStats: CurrentUserStats {
        CurrentUserStats(
            currentStreak: currentUser.currentStreak,
            longestStreak: currentUser.longestStreak,
            longestPlankSeconds: longestPlank?.durationSeconds ?? 0,
            totalPlanks: totalPlanks,
            freezeTokens: currentUser.freezeTokens,
            preferredPlankType: .elbow
        )
    }
}

// MARK: - Supporting Mock Models

struct LeaderboardUser: Identifiable, Sendable {
    let id = UUID()
    let rank: Int
    let displayName: String
    let currentStreak: Int
    let longestPlankSeconds: TimeInterval
    var isCurrentUser: Bool = false
    var badges: [Badge.BadgeType] = []
    
    var longestPlankFormatted: String {
        let minutes = Int(longestPlankSeconds) / 60
        let seconds = Int(longestPlankSeconds) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct MockGroup: Identifiable, Sendable {
    let id = UUID()
    let name: String
    let description: String
    let groupType: PlankGroup.GroupType
    let joinMode: PlankGroup.JoinMode
    let memberCount: Int
    let isCurrentUserMember: Bool
    let isCurrentUserAdmin: Bool
    let members: [MockUser]
    let lastActivityDate: Date
    
    init(name: String, description: String, groupType: PlankGroup.GroupType, joinMode: PlankGroup.JoinMode, memberCount: Int, isCurrentUserMember: Bool, isCurrentUserAdmin: Bool, members: [MockUser], lastActivityDate: Date = Date()) {
        self.name = name
        self.description = description
        self.groupType = groupType
        self.joinMode = joinMode
        self.memberCount = memberCount
        self.isCurrentUserMember = isCurrentUserMember
        self.isCurrentUserAdmin = isCurrentUserAdmin
        self.members = members
        self.lastActivityDate = lastActivityDate
    }
    
    var streakLeaderboard: [MockUser] {
        members.sorted { $0.currentStreak > $1.currentStreak }
    }
    
    var longestPlankLeaderboard: [MockUser] {
        members.sorted { $0.longestPlankSeconds > $1.longestPlankSeconds }
    }
}

struct MockNotification: Identifiable, Sendable {
    let id = UUID()
    let type: AppNotification.NotificationType
    let title: String
    let message: String
    var isRead: Bool
    let createdAt: Date
}

struct CurrentUserStats: Sendable {
    let currentStreak: Int
    let longestStreak: Int
    let longestPlankSeconds: TimeInterval
    let totalPlanks: Int
    let freezeTokens: Int
    let preferredPlankType: Constants.Plank.PlankType
    
    var longestPlankFormatted: String {
        let minutes = Int(longestPlankSeconds) / 60
        let seconds = Int(longestPlankSeconds) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
