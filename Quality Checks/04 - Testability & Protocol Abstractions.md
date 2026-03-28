# Quality Check: Testability & Protocol Abstractions

## Your Task

You are an AI code editor tasked with introducing protocol abstractions across the Plank Challenge iOS app's service layer. Your goal is to make every service substitutable with a mock implementation — enabling unit tests for business logic, isolated Xcode Previews for every view, and a path to a proper test suite without requiring live network calls or shared singleton state.

Work through this document top to bottom. For each section, search the codebase, identify what needs to change, implement the fixes, and move on. Do not skip sections.

---

## Project Context

**App**: Plank Challenge — a social fitness iOS app where users log a daily plank and maintain a streak.

**Platform**: iOS, SwiftUI, Swift 5.9+, `@Observable` (not `ObservableObject`), Swift Concurrency (`async/await`, `Task`, `actor`).

**Key architectural facts you need to know:**
- All domain logic lives in service classes annotated `@Observable @MainActor final class`
- Services are singletons (`static let shared`) injected via `.environment()` and consumed with `@Environment(ServiceType.self)` in views
- Services live at `PlankChallenge/Services/`; screen views at `PlankChallenge/` top level; components at `PlankChallenge/Components/`
- The Design System Catalog at `PlankChallenge/DesignSystem/` is debug-only and should be a showcase of every component with mock data — currently may be using hardcoded data instead of mock services
- There are currently **no unit tests** — the target is to make the codebase testable, not to write a full test suite (though you should add a small number of example tests to validate the approach works)
- `@Observable` classes cannot conform to protocols that include `@Observable` in the protocol definition itself — protocols must be defined without the macro, and the conforming class applies `@Observable` separately

---

## Step 1 — Audit the Current Injection Pattern

Before making changes, read and understand how services are currently wired:

1. `PlankChallenge/PlankChallengeApp.swift` — how services are instantiated and injected into the environment
2. `PlankChallenge/Views/RootView.swift` — how the root view receives and passes services
3. Two or three screen views (e.g. `PlankTimerView.swift`, `PlankProgressView.swift`, `ProfileView.swift`) — how they consume services via `@Environment`
4. `PlankChallenge/DesignSystem/DesignSystemCatalog.swift` and one or two showcase files — how they currently provide data to components

Document:
- The exact `@Environment` key type used (is it the concrete class type, e.g. `@Environment(PlankService.self)`, or a key path?)
- Whether any view references `PlankService.shared` directly (a static singleton reference bypasses environment injection entirely and must be fixed)
- Whether Xcode Previews exist for any views and how they currently provide data

---

## Step 2 — Define Service Protocols

Create a new file `PlankChallenge/Services/ServiceProtocols.swift`. Define a protocol for each service. Each protocol must:

1. Expose all `var` properties that views read (as `var` with only a getter in the protocol)
2. Expose all `func` methods that views call
3. NOT include `@Observable` — that is an implementation detail of the concrete class
4. Be annotated `@MainActor` to match the concrete class isolation

Define the following protocols:

```swift
import Foundation

// MARK: - PlankService

@MainActor
protocol PlankServiceProtocol: AnyObject {
    var planks: [PlankSession] { get }
    var isLoading: Bool { get }
    var error: AppError? { get }
    var todayPlankCountFromServer: Int { get }

    func fetchPlanks() async
    func savePlank(duration: Int, type: PlankType, inputMethod: InputMethod) async
    func deletePlank(id: String) async
    func fetchMorePlanks() async  // pagination
}

// MARK: - StreakService

@MainActor
protocol StreakServiceProtocol: AnyObject {
    var currentStreak: Int { get }
    var longestStreak: Int { get }
    var freezeTokens: Int { get }
    var recentActivity: [StreakActivity] { get }
    var isLoading: Bool { get }
    var error: AppError? { get }

    func fetchStreak() async
    func applyStreakUpdate(_ info: StreakInfo)
}

// MARK: - BadgeService

@MainActor
protocol BadgeServiceProtocol: AnyObject {
    var earnedBadges: [Badge] { get }
    var allBadges: [BadgeWithProgress] { get }
    var isLoading: Bool { get }
    var error: AppError? { get }

    func fetchBadges() async
    func applyNewBadges(_ badges: [APIBadge])
}

// MARK: - UserService

@MainActor
protocol UserServiceProtocol: AnyObject {
    var profile: UserProfile? { get }
    var isLoading: Bool { get }
    var error: AppError? { get }

    func fetchProfile() async
    func updateProfile(_ update: ProfileUpdate) async
    func fetchUserProfile(userId: String) async -> APIPublicUser?
    func followUser(userId: String) async
    func unfollowUser(userId: String) async
}

// MARK: - GroupService

@MainActor
protocol GroupServiceProtocol: AnyObject {
    var myGroups: [PlankGroup] { get }
    var discoverGroups: [PlankGroup] { get }
    var isLoading: Bool { get }
    var error: AppError? { get }

    func fetchGroups() async
    func joinGroup(id: String) async
    func leaveGroup(id: String) async
    func createGroup(name: String, description: String, type: GroupType, joinMode: JoinMode) async
    func fetchMembers(groupId: String) async -> [APIGroupMember]
}

// MARK: - LeaderboardService

@MainActor
protocol LeaderboardServiceProtocol: AnyObject {
    var entries: [APILeaderboardEntry] { get }
    var isLoading: Bool { get }
    var isStale: Bool { get }
    var error: AppError? { get }

    func fetch(type: LeaderboardType, period: LeaderboardPeriod) async
    func markStale()
}

// MARK: - AuthService

@MainActor
protocol AuthServiceProtocol: AnyObject {
    var isAuthenticated: Bool { get }
    var currentUserId: String? { get }
    var isLoading: Bool { get }
    var error: AppError? { get }

    func signInWithApple() async
    func signInWithEmail(email: String, password: String) async
    func signUpWithEmail(email: String, password: String, displayName: String) async
    func signOut() async
    func deleteAccount() async
}

// MARK: - MediaService

@MainActor
protocol MediaServiceProtocol: AnyObject {
    var isUploading: Bool { get }
    var error: AppError? { get }

    func uploadProfilePhoto(_ imageData: Data) async -> String?
}
```

**Important**: adjust the protocol method signatures to exactly match what the concrete service classes actually expose. Read each service file before writing its protocol to ensure accuracy. Do not guess method signatures — derive them from the actual implementation.

---

## Step 3 — Conform Concrete Services to Their Protocols

Open each service file and add protocol conformance. This should require minimal or no changes to the service's actual implementation — the protocol is derived from what the service already does:

```swift
// Before
@Observable @MainActor final class PlankService {
    static let shared = PlankService()
    ...
}

// After
@Observable @MainActor final class PlankService: PlankServiceProtocol {
    static let shared = PlankService()
    ...
}
```

Do this for all eight services. The Swift compiler will immediately flag any mismatch between the protocol definition and the concrete implementation — fix any mismatches by either:
- Adjusting the protocol to match the actual implementation (preferred — the protocol describes what exists, not what should exist)
- Or adding missing implementations to the service if the protocol represents a genuine requirement

---

## Step 4 — Update Environment Injection to Use Protocol Types

Currently views likely consume services as concrete types:
```swift
@Environment(PlankService.self) var plankService
```

This must change to use the protocol type as the environment key. However, SwiftUI's `@Environment` with a type key requires the type to be `Observable` — protocols are not `Observable`. The solution is to use `AnyObject` wrapper or keep using the concrete type at the injection site but type the property as the protocol.

The recommended approach for SwiftUI + `@Observable` + protocols is to use **environment values with a custom key**:

Create `PlankChallenge/Services/EnvironmentKeys.swift`:

```swift
import SwiftUI

// MARK: - Environment Keys

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
}
```

Update all views to use the new environment key path syntax:

```swift
// Before
@Environment(PlankService.self) var plankService: PlankService

// After
@Environment(\.plankService) var plankService: any PlankServiceProtocol
```

Update `PlankChallengeApp.swift` to inject via the new keys:

```swift
ContentView()
    .environment(\.plankService, PlankService.shared)
    .environment(\.streakService, StreakService.shared)
    .environment(\.badgeService, BadgeService.shared)
    .environment(\.userService, UserService.shared)
    .environment(\.groupService, GroupService.shared)
    .environment(\.leaderboardService, LeaderboardService.shared)
    .environment(\.authService, AuthService.shared)
    .environment(\.mediaService, MediaService.shared)
```

---

## Step 5 — Create Mock Service Implementations

Create a new file `PlankChallenge/Services/MockServices.swift` (mark the entire file `#if DEBUG` so it is stripped from release builds):

```swift
#if DEBUG
import Foundation

// MARK: - Mock Data

extension PlankSession {
    static let mock = PlankSession(
        id: "mock-1",
        date: Date(),
        durationSeconds: 62,
        plankTypeRaw: "elbow",
        inputMethodRaw: "timer",
        timezoneIdentifier: TimeZone.current.identifier,
        createdAt: Date(),
        modifiedAt: Date()
    )
    static let mocks: [PlankSession] = (1...10).map { i in
        PlankSession(
            id: "mock-\(i)",
            date: Calendar.current.date(byAdding: .day, value: -i, to: Date())!,
            durationSeconds: Int.random(in: 30...120),
            plankTypeRaw: "elbow",
            inputMethodRaw: "timer",
            timezoneIdentifier: TimeZone.current.identifier,
            createdAt: Date(),
            modifiedAt: Date()
        )
    }
}

// MARK: - Mock PlankService

@Observable @MainActor
final class MockPlankService: PlankServiceProtocol {
    var planks: [PlankSession] = PlankSession.mocks
    var isLoading: Bool = false
    var error: AppError? = nil
    var todayPlankCountFromServer: Int = 1

    func fetchPlanks() async { }
    func savePlank(duration: Int, type: PlankType, inputMethod: InputMethod) async {
        let session = PlankSession.mock
        planks.insert(session, at: 0)
    }
    func deletePlank(id: String) async {
        planks.removeAll { $0.id == id }
    }
    func fetchMorePlanks() async { }
}

// MARK: - Mock StreakService

@Observable @MainActor
final class MockStreakService: StreakServiceProtocol {
    var currentStreak: Int = 14
    var longestStreak: Int = 30
    var freezeTokens: Int = 2
    var recentActivity: [StreakActivity] = [] // populate with mock calendar data
    var isLoading: Bool = false
    var error: AppError? = nil

    func fetchStreak() async { }
    func applyStreakUpdate(_ info: StreakInfo) { }
}

// MARK: - Mock BadgeService

@Observable @MainActor
final class MockBadgeService: BadgeServiceProtocol {
    var earnedBadges: [Badge] = [Badge(badgeTypeRaw: "streak_7", dateEarned: Date())]
    var allBadges: [BadgeWithProgress] = []
    var isLoading: Bool = false
    var error: AppError? = nil

    func fetchBadges() async { }
    func applyNewBadges(_ badges: [APIBadge]) { }
}

// MARK: - Mock UserService

@Observable @MainActor
final class MockUserService: UserServiceProtocol {
    var profile: UserProfile? = UserProfile(
        displayName: "Alex Johnson",
        location: "London, UK",
        bio: "Daily plank challenger. Day 14 and counting.",
        preferredPlankTypeRaw: "elbow",
        profileImageData: nil,
        currentStreak: 14,
        longestStreak: 30,
        freezeTokens: 2,
        lastPlankDate: Date()
    )
    var isLoading: Bool = false
    var error: AppError? = nil

    func fetchProfile() async { }
    func updateProfile(_ update: ProfileUpdate) async { }
    func fetchUserProfile(userId: String) async -> APIPublicUser? { nil }
    func followUser(userId: String) async { }
    func unfollowUser(userId: String) async { }
}

// MARK: - Mock GroupService

@Observable @MainActor
final class MockGroupService: GroupServiceProtocol {
    var myGroups: [PlankGroup] = [
        PlankGroup(id: "g1", name: "Morning Plankers", descriptionText: "We plank at dawn.", groupTypeRaw: "public", joinModeRaw: "open", memberCount: 24, isCurrentUserAdmin: true, isCurrentUserMember: true)
    ]
    var discoverGroups: [PlankGroup] = []
    var isLoading: Bool = false
    var error: AppError? = nil

    func fetchGroups() async { }
    func joinGroup(id: String) async { }
    func leaveGroup(id: String) async { }
    func createGroup(name: String, description: String, type: GroupType, joinMode: JoinMode) async { }
    func fetchMembers(groupId: String) async -> [APIGroupMember] { [] }
}

// MARK: - Mock LeaderboardService

@Observable @MainActor
final class MockLeaderboardService: LeaderboardServiceProtocol {
    var entries: [APILeaderboardEntry] = []
    var isLoading: Bool = false
    var isStale: Bool = false
    var error: AppError? = nil

    func fetch(type: LeaderboardType, period: LeaderboardPeriod) async { }
    func markStale() { isStale = true }
}

// MARK: - Mock AuthService

@Observable @MainActor
final class MockAuthService: AuthServiceProtocol {
    var isAuthenticated: Bool = true
    var currentUserId: String? = "mock-user-1"
    var isLoading: Bool = false
    var error: AppError? = nil

    func signInWithApple() async { isAuthenticated = true }
    func signInWithEmail(email: String, password: String) async { isAuthenticated = true }
    func signUpWithEmail(email: String, password: String, displayName: String) async { isAuthenticated = true }
    func signOut() async { isAuthenticated = false }
    func deleteAccount() async { isAuthenticated = false }
}

// MARK: - Mock MediaService

@Observable @MainActor
final class MockMediaService: MediaServiceProtocol {
    var isUploading: Bool = false
    var error: AppError? = nil

    func uploadProfilePhoto(_ imageData: Data) async -> String? {
        return "https://example.com/mock-avatar.jpg"
    }
}

// MARK: - Preview Environment Helper

extension View {
    /// Injects all mock services for use in Xcode Previews
    func withMockServices() -> some View {
        self
            .environment(\.plankService, MockPlankService())
            .environment(\.streakService, MockStreakService())
            .environment(\.badgeService, MockBadgeService())
            .environment(\.userService, MockUserService())
            .environment(\.groupService, MockGroupService())
            .environment(\.leaderboardService, MockLeaderboardService())
            .environment(\.authService, MockAuthService())
            .environment(\.mediaService, MockMediaService())
    }
}

#endif
```

---

## Step 6 — Add Xcode Previews to Every Screen View

Every screen view should have at least one `#Preview` block using the mock services. Open each of the following files and add or update the preview:

- `PlankTimerView.swift`
- `PlankProgressView.swift`
- `GroupsView.swift`
- `GroupDetailView.swift`
- `ProfileView.swift`
- `LeaderboardView.swift`
- `BadgesView.swift`
- `SearchView.swift`
- `NotificationsView.swift`
- `UserProfileView.swift`
- `PlankHistoryListView.swift`
- `ManualEntryView.swift`
- `SettingsView.swift`

The preview pattern is:

```swift
#Preview {
    PlankTimerView()
        .withMockServices()
}
```

For views that show different states (loading, error, empty, populated), add multiple named previews:

```swift
#Preview("Loading") {
    PlankProgressView()
        .withMockServices()
        // Override one service to show loading state:
        .environment(\.plankService, {
            let s = MockPlankService()
            s.isLoading = true
            s.planks = []
            return s
        }())
}

#Preview("Error") {
    PlankProgressView()
        .withMockServices()
        .environment(\.streakService, {
            let s = MockStreakService()
            s.error = .network(underlying: URLError(.notConnectedToInternet))
            return s
        }())
}

#Preview("Populated") {
    PlankProgressView()
        .withMockServices()
}
```

---

## Step 7 — Update the Design System Catalog

The Design System Catalog (`PlankChallenge/DesignSystem/DesignSystemCatalog.swift` and all showcase files in `PlankChallenge/DesignSystem/Showcases/`) should use mock services and mock data rather than hardcoded values.

For each showcase file:
1. Replace any hardcoded `PlankService.shared` or direct service singleton references with mock services via `.withMockServices()`
2. Replace hardcoded model literals with the static mock instances defined in Step 5 (e.g. `PlankSession.mock`, `PlankSession.mocks`)
3. Ensure every component variant is shown — including loading, error, and empty states

---

## Step 8 — Add an Example Unit Test Target

If a unit test target does not already exist in the Xcode project, add one named `PlankChallengeTests`. Then create an example test file that demonstrates the pattern works:

Create `PlankChallengeTests/PlankServiceTests.swift`:

```swift
import Testing
@testable import PlankChallenge

@MainActor
struct PlankServiceTests {

    @Test("Mock service returns mock planks")
    func mockServiceReturnsMockPlanks() async {
        let service = MockPlankService()
        #expect(service.planks.count == 10)
        #expect(service.isLoading == false)
        #expect(service.error == nil)
    }

    @Test("Mock service save adds a plank")
    func mockServiceSaveAddsPlank() async {
        let service = MockPlankService()
        let initialCount = service.planks.count
        await service.savePlank(duration: 60, type: .elbow, inputMethod: .timer)
        #expect(service.planks.count == initialCount + 1)
    }

    @Test("Mock service delete removes a plank")
    func mockServiceDeleteRemovesPlank() async {
        let service = MockPlankService()
        let firstId = service.planks[0].id
        await service.deletePlank(id: firstId)
        #expect(!service.planks.contains { $0.id == firstId })
    }
}
```

This uses Swift Testing (`import Testing`) which is available from Xcode 16 / Swift 5.10+. If the project targets an earlier toolchain, use `XCTest` instead.

The test target does not need to be exhaustive — its purpose is to prove the protocol + mock pattern is wired correctly and that future test authors have a clear template to follow.

---

## Step 9 — Search for and Remove Direct Singleton References in Views

After completing Steps 2–4, no view should be referencing `ServiceName.shared` directly. Search the entire `PlankChallenge/` directory for `.shared` to find any remaining direct singleton accesses in view files:

```
PlankService.shared
StreakService.shared
BadgeService.shared
UserService.shared
GroupService.shared
LeaderboardService.shared
AuthService.shared
MediaService.shared
```

For each match found in a view or component file (not in a service file itself):
1. Replace it with `@Environment(\.serviceName) var serviceName`
2. Ensure the view's preview injects the mock via `.withMockServices()`

Direct singleton references in service files (e.g. `PlankService` referencing `StreakService.shared` for cross-service updates) should be replaced with the `NotificationCenter` invalidation bus described in the State Consistency quality check, or injected via initialiser if tight coupling is genuinely required.

---

## Step 10 — Final Verification Checklist

Before considering this quality check complete, confirm each of the following:

- [ ] `PlankChallenge/Services/ServiceProtocols.swift` exists with a `@MainActor` protocol for every service
- [ ] Every concrete service class declares conformance to its protocol
- [ ] `PlankChallenge/Services/EnvironmentKeys.swift` exists with custom `EnvironmentKey` for every service
- [ ] All views use `@Environment(\.serviceName)` with the protocol type — not `@Environment(ConcreteService.self)`
- [ ] `PlankChallenge/Services/MockServices.swift` exists, is gated `#if DEBUG`, and contains a mock for every service
- [ ] `View.withMockServices()` helper extension exists and injects all mocks
- [ ] Every screen view has at least one `#Preview` using `.withMockServices()`
- [ ] Key screen views (Progress, Timer, Groups) have multiple previews covering loading, error, and populated states
- [ ] Design System Catalog showcases use mock data and mock services
- [ ] No view file contains a direct `.shared` singleton reference
- [ ] A unit test target exists with at least one passing test demonstrating the mock pattern
- [ ] All mock implementations compile without errors and satisfy their protocol contracts
