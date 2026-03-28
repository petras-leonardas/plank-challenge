import Testing
@testable import PlankChallenge

// MARK: - Mock Service Tests
//
// These tests validate that:
// 1. MockServices conform to their protocols correctly
// 2. Mock services behave as expected in test scenarios
// 3. Protocol-based injection works end-to-end
//
// To run these tests, you must first add a unit test target in Xcode:
//   1. File > New > Target > Unit Testing Bundle
//   2. Name it "PlankChallengeTests"
//   3. Add this file to the target membership
//   4. Ensure "PlankChallenge" is listed under "Target Dependencies"

@MainActor
struct MockPlankServiceTests {

    @Test("MockPlankService starts empty")
    func startsEmpty() async {
        let service = MockPlankService()
        #expect(service.planks.isEmpty)
        #expect(service.isLoading == false)
        #expect(service.error == nil)
        #expect(service.hasLoaded == true)
    }

    @Test("MockPlankService todayPlankCountFromServer defaults to 0")
    func todayCountDefaultsToZero() async {
        let service = MockPlankService()
        #expect(service.todayPlankCountFromServer == 0)
        #expect(service.hasPlankToday == false)
    }

    @Test("MockPlankService clearData resets state")
    func clearDataResetsState() async {
        let service = MockPlankService()
        service.clearData()
        #expect(service.planks.isEmpty)
        #expect(service.hasLoaded == false)
        #expect(service.error == nil)
    }
}

@MainActor
struct MockStreakServiceTests {

    @Test("MockStreakService has sensible defaults")
    func defaults() async {
        let service = MockStreakService()
        #expect(service.currentStreak == 14)
        #expect(service.longestStreak == 30)
        #expect(service.freezeTokens == 2)
        #expect(service.isLoading == false)
        #expect(service.error == nil)
    }

    @Test("applyInlineStreakUpdate updates currentStreak")
    func applyInlineUpdate() async {
        let service = MockStreakService()
        service.applyInlineStreakUpdate(current: 20, longest: 30)
        #expect(service.currentStreak == 20)
        #expect(service.longestStreak == 30) // max preserved
    }

    @Test("applyInlineStreakUpdate does not lower longestStreak")
    func doesNotLowerLongest() async {
        let service = MockStreakService()
        // longest is 30, try to set it lower
        service.applyInlineStreakUpdate(current: 5, longest: 10)
        #expect(service.longestStreak == 30) // preserved
    }

    @Test("MockStreakService clearData resets state")
    func clearDataResetsState() async {
        let service = MockStreakService()
        service.clearData()
        #expect(service.currentStreak == 0)
        #expect(service.longestStreak == 0)
        #expect(service.hasLoaded == false)
    }
}

@MainActor
struct MockBadgeServiceTests {

    @Test("MockBadgeService starts empty")
    func startsEmpty() async {
        let service = MockBadgeService()
        #expect(service.earnedBadges.isEmpty)
        #expect(service.availableBadges.isEmpty)
        #expect(service.earnedCount == 0)
        #expect(service.isLoading == false)
    }

    @Test("hasBadge always returns false in mock")
    func hasBadgeReturnsFalse() async {
        let service = MockBadgeService()
        #expect(service.hasBadge("streak_7") == false)
        #expect(service.hasBadge("first_plank") == false)
    }
}

@MainActor
struct MockLeaderboardServiceTests {

    @Test("MockLeaderboardService starts with empty leaderboards")
    func startsEmpty() async {
        let service = MockLeaderboardService()
        #expect(service.globalLeaderboard.isEmpty)
        #expect(service.followingLeaderboard.isEmpty)
        #expect(service.groupLeaderboard.isEmpty)
        #expect(service.isStale == false)
    }

    @Test("markStale sets isStale to true")
    func markStale() async {
        let service = MockLeaderboardService()
        #expect(service.isStale == false)
        service.markStale()
        #expect(service.isStale == true)
    }

    @Test("clearData resets isStale")
    func clearDataResetsStale() async {
        let service = MockLeaderboardService()
        service.markStale()
        service.clearData()
        #expect(service.isStale == false)
        #expect(service.hasLoaded == false)
    }
}

@MainActor
struct MockAuthServiceTests {

    @Test("MockAuthService starts unauthenticated")
    func startsUnauthenticated() async {
        let service = MockAuthService()
        #expect(service.isAuthenticated == false)
        #expect(service.currentUser == nil)
        #expect(service.currentUserId == nil)
    }

    @Test("signInWithEmail sets isAuthenticated to true")
    func signIn() async throws {
        let service = MockAuthService()
        try await service.signInWithEmail(email: "test@example.com", password: "password")
        #expect(service.isAuthenticated == true)
    }

    @Test("signOut sets isAuthenticated to false")
    func signOut() async throws {
        let service = MockAuthService()
        try await service.signInWithEmail(email: "test@example.com", password: "password")
        await service.signOut()
        #expect(service.isAuthenticated == false)
    }
}

@MainActor
struct ProtocolConformanceTests {

    // These tests verify that all mock services satisfy their protocol contracts.
    // If any protocol changes break conformance, these tests will fail to compile.

    @Test("All mocks satisfy their protocol contracts at compile time")
    func protocolConformance() async {
        // If any mock doesn't satisfy its protocol, this function won't compile.
        let _: any PlankServiceProtocol = MockPlankService()
        let _: any StreakServiceProtocol = MockStreakService()
        let _: any BadgeServiceProtocol = MockBadgeService()
        let _: any UserServiceProtocol = MockUserService()
        let _: any GroupServiceProtocol = MockGroupService()
        let _: any LeaderboardServiceProtocol = MockLeaderboardService()
        let _: any AuthServiceProtocol = MockAuthService()
        let _: any MediaServiceProtocol = MockMediaService()
        let _: any InAppNotificationServiceProtocol = MockNotificationService()
        // All 9 protocol conformances verified
        #expect(true)
    }

    @Test("Concrete services satisfy their protocol contracts at compile time")
    func concreteConformance() async {
        // If any concrete service breaks its protocol, this function won't compile.
        let _: any PlankServiceProtocol = PlankService.shared
        let _: any StreakServiceProtocol = StreakService.shared
        let _: any BadgeServiceProtocol = BadgeService.shared
        let _: any UserServiceProtocol = UserService.shared
        let _: any GroupServiceProtocol = GroupService.shared
        let _: any LeaderboardServiceProtocol = LeaderboardService.shared
        let _: any AuthServiceProtocol = AuthService.shared
        let _: any MediaServiceProtocol = MediaService.shared
        let _: any InAppNotificationServiceProtocol = InAppNotificationService.shared
        // All 9 concrete conformances verified
        #expect(true)
    }
}
