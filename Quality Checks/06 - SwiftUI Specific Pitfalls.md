# Quality Check: SwiftUI-Specific Pitfalls

## Your Task

You are an AI code editor tasked with auditing and fixing SwiftUI-specific pitfalls across the Plank Challenge iOS app. Your goal is to address four distinct areas: the `@Observable` rendering trap, view body complexity, navigation architecture, and correct use of `.task {}` vs `onAppear`. Each of these is a common source of subtle bugs, performance problems, and technical debt that compounds as the app grows.

Work through this document top to bottom. For each section, search the codebase, identify the problems, implement the fixes, and move on. Do not skip sections.

---

## Project Context

**App**: Plank Challenge — a social fitness iOS app where users log a daily plank and maintain a streak.

**Platform**: iOS, SwiftUI, Swift 5.9+, `@Observable` (not `ObservableObject`), Swift Concurrency (`async/await`, `Task`, `actor`).

**Key architectural facts you need to know:**
- All domain logic lives in service classes annotated `@Observable @MainActor final class`
- Services are singletons injected via `.environment()` and consumed with `@Environment(ServiceType.self)` (or `@Environment(\.serviceName)` if the Testability quality check has been applied)
- Screen views live at `PlankChallenge/` top level; components at `PlankChallenge/Components/`; services at `PlankChallenge/Services/`
- The timer state machine uses a `PlankTimerState` enum: `ready`, `countdown(Int)`, `active`, `celebration`, `completedToday`
- Navigation is currently handled with `NavigationStack` and `NavigationLink` — the goal of this check is to migrate to typed path-based routing
- The app has 4 main tabs: Plank (timer), Progress, Groups, Profile
- Deep linking targets include: a specific plank detail, a user profile, a group detail, and a badge detail — these arrive via push notifications

---

## Step 1 — Audit the `@Observable` Rendering Trap

`@Observable` (Swift Observation framework) tracks property access during a view's `body` evaluation and re-renders only when a tracked property changes. This is more efficient than `ObservableObject` + `@Published`, but it has a critical pitfall: **properties that are read conditionally or only inside child views that aren't always rendered will not trigger re-renders of the parent**.

### How to identify the problem

Search all screen views and components for these patterns:

**Pattern A — Conditional property access:**
```swift
// If showBadges starts as false, badgeCount is never read during initial render.
// When badgeCount later changes, this view will NOT re-render.
var body: some View {
    if showBadges {
        Text("\(badgeService.badgeCount)") // only read conditionally
    }
}
```

**Pattern B — Property read only inside a lazy container:**
```swift
// Properties read only inside List/LazyVStack rows may not be tracked
// until the row is actually rendered (scrolled into view)
List(plankService.planks) { plank in
    Text(plank.duration) // planks array is tracked, but individual plank properties are not
}
```

**Pattern C — Property read in a subview that isn't always present:**
```swift
// If ErrorBannerView is only shown when error != nil, the parent
// may not track `error` correctly on first render when error IS nil
if let error = plankService.error {
    ErrorBannerView(message: error.localizedDescription)
}
```

### The fix

For Pattern A and C: ensure that every `@Observable` property your view depends on is read **unconditionally** during `body` evaluation — even if only to check its value:

```swift
// Force tracking by reading the property unconditionally
var body: some View {
    let hasError = plankService.error != nil  // read unconditionally — now tracked
    let badgeCount = badgeService.earnedBadges.count  // read unconditionally

    return VStack {
        if showBadges {
            Text("\(badgeCount)")
        }
        if hasError {
            ErrorBannerView(message: plankService.error!.localizedDescription)
        }
    }
}
```

For Pattern B: when iterating over a collection from an `@Observable` service, the collection itself is tracked. Individual item properties are tracked when the item's row view reads them — which is correct behaviour for lazy containers. No fix needed, but document this with a comment.

### Specific files to audit

Read each of the following files and apply the fix where the pattern is detected:

- `PlankTimerView.swift` — check if `plankService.error` and `streakService.currentStreak` are read conditionally
- `PlankProgressView.swift` — check if badge/streak data is only read inside conditional or lazy sub-views
- `GroupsView.swift` — check if `groupService.error` and `groupService.discoverGroups` are conditionally read
- `ProfileView.swift` — check if `userService.profile` properties are only read inside `if let profile = ...` blocks without unconditional access
- `LeaderboardView.swift` — check if period-specific properties are conditionally accessed

---

## Step 2 — Audit and Reduce View Body Complexity

Large `body` implementations cause three concrete problems:
1. **Slow Swift compiler type inference** — the compiler struggles with deeply nested generic types, producing "expression too complex" errors and slow incremental builds
2. **Slow SwiftUI diffing** — SwiftUI must diff the entire view tree on every state change; a 500-line body diffed 60 times per second during an animation is a performance problem
3. **Poor maintainability** — bugs in large views are harder to isolate and fix

### How to identify oversized views

Search all files in `PlankChallenge/` for `var body: some View`. For each, estimate the line count of the body. Any body exceeding **100 lines** is a candidate for decomposition. Any body exceeding **200 lines** must be decomposed.

Files most likely to need decomposition based on the app's feature set:
- `PlankTimerView.swift` — multiple timer states, animated components, overlays
- `PlankProgressView.swift` — streak hero, calendar, badge scroll, recent planks list
- `ProfileView.swift` — header, avatar, stats, media gallery, badges, settings navigation
- `GroupDetailView.swift` — group info, member list, leaderboard, join/leave button
- `GroupSettingsView.swift` — multiple settings sections with forms

### The decomposition pattern

Extract meaningful sub-views as private computed properties or private nested structs. Prefer private nested structs (they are separate SwiftUI nodes and diffed independently):

```swift
// Before — everything in one body
struct PlankProgressView: View {
    var body: some View {
        ScrollView {
            VStack {
                // 50 lines of streak hero UI
                // 80 lines of calendar UI
                // 60 lines of badge scroll UI
                // 40 lines of recent planks UI
            }
        }
    }
}

// After — decomposed into focused sub-views
struct PlankProgressView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                StreakSection()
                CalendarSection()
                BadgesSection()
                RecentPlanksSection()
            }
        }
    }
}

// Each section is a private nested struct
private extension PlankProgressView {
    struct StreakSection: View {
        @Environment(\.streakService) var streakService
        var body: some View {
            // streak hero + stats row only
        }
    }

    struct CalendarSection: View {
        @Environment(\.streakService) var streakService
        var body: some View {
            // calendar only
        }
    }
    // ...
}
```

**Important**: each sub-view should declare only the `@Environment` services it actually needs — not all services. This ensures SwiftUI only re-renders the sub-view when the specific data it uses changes, not when any service changes.

### Apply decomposition to

For each file that exceeds 100 lines in its body:

1. Identify the logical sections of the UI
2. Extract each section as a private nested struct
3. Move only the relevant `@Environment` dependencies into each nested struct
4. Verify the view renders identically after decomposition (use Xcode Previews)
5. Verify the build succeeds without "expression too complex" errors

---

## Step 3 — Migrate to Path-Based Navigation

The current navigation likely uses ad-hoc `NavigationLink` scattered through views. This must be migrated to a typed `NavigationPath` with a route enum. This is the single most impactful structural change in this quality check — do it carefully.

### Step 3a — Define the Route Enum

Create a new file `PlankChallenge/Navigation/AppRouter.swift`:

```swift
import SwiftUI

// MARK: - App Routes

/// All navigable destinations in the app.
/// Must be Hashable for NavigationStack path compatibility.
enum AppRoute: Hashable {
    // Plank tab
    case plankDetail(id: String)
    case manualEntry
    case plankHistory

    // Progress tab
    case badgeDetail(badgeType: String)
    case allBadges

    // Groups tab
    case groupDetail(groupId: String)
    case groupSettings(groupId: String)
    case groupMembers(groupId: String)
    case createGroup

    // Profile & social
    case userProfile(userId: String)
    case followList(userId: String, mode: FollowListMode)
    case mediaGallery(userId: String)
    case notifications
    case settings
    case searchUsers

    // Leaderboard
    case leaderboard
}

enum FollowListMode: String, Hashable {
    case followers
    case following
}

// MARK: - AppRouter

/// Central navigation state. One instance per tab.
@Observable @MainActor
final class AppRouter {
    var path: [AppRoute] = []

    func navigate(to route: AppRoute) {
        path.append(route)
    }

    func navigateBack() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    func navigateToRoot() {
        path.removeAll()
    }

    func navigate(to route: AppRoute, replacing current: AppRoute) {
        if let index = path.lastIndex(of: current) {
            path[index] = route
        } else {
            path.append(route)
        }
    }
}
```

### Step 3b — Create One Router Per Tab

Each tab needs its own navigation stack and its own `AppRouter` instance so that navigating within one tab does not affect others. Update `MainTabView.swift`:

```swift
struct MainTabView: View {
    @State private var plankRouter = AppRouter()
    @State private var progressRouter = AppRouter()
    @State private var groupsRouter = AppRouter()
    @State private var profileRouter = AppRouter()

    var body: some View {
        TabView {
            NavigationStack(path: $plankRouter.path) {
                PlankTimerView()
                    .navigationDestination(for: AppRoute.self) { route in
                        AppRouteView(route: route)
                    }
            }
            .environment(\.appRouter, plankRouter)
            .tabItem { Label("Plank", systemImage: "figure.core.training") }

            NavigationStack(path: $progressRouter.path) {
                PlankProgressView()
                    .navigationDestination(for: AppRoute.self) { route in
                        AppRouteView(route: route)
                    }
            }
            .environment(\.appRouter, progressRouter)
            .tabItem { Label("Progress", systemImage: "chart.bar.fill") }

            // repeat for Groups and Profile tabs
        }
    }
}
```

### Step 3c — Create the Route Resolver View

Create `PlankChallenge/Navigation/AppRouteView.swift` — a single view that resolves every `AppRoute` to its destination view:

```swift
import SwiftUI

/// Resolves an AppRoute to its destination view.
/// Used as the navigationDestination handler for all NavigationStacks.
struct AppRouteView: View {
    let route: AppRoute

    var body: some View {
        switch route {
        case .plankDetail(let id):
            PlankDetailView(plankId: id)
        case .manualEntry:
            ManualEntryView()
        case .plankHistory:
            PlankHistoryListView()
        case .badgeDetail(let badgeType):
            BadgeDetailView(badgeType: badgeType)
        case .allBadges:
            BadgesView()
        case .groupDetail(let groupId):
            GroupDetailView(groupId: groupId)
        case .groupSettings(let groupId):
            GroupSettingsView(groupId: groupId)
        case .groupMembers(let groupId):
            GroupMembersListView(groupId: groupId)
        case .createGroup:
            CreateGroupView()
        case .userProfile(let userId):
            UserProfileView(userId: userId)
        case .followList(let userId, let mode):
            FollowListView(userId: userId, mode: mode)
        case .mediaGallery(let userId):
            MediaGalleryView(userId: userId)
        case .notifications:
            NotificationsView()
        case .settings:
            SettingsView()
        case .searchUsers:
            SearchView()
        case .leaderboard:
            LeaderboardView()
        }
    }
}
```

### Step 3d — Add Router to Environment

Create `PlankChallenge/Navigation/RouterEnvironmentKey.swift`:

```swift
import SwiftUI

private struct AppRouterKey: EnvironmentKey {
    static let defaultValue: AppRouter = AppRouter()
}

extension EnvironmentValues {
    var appRouter: AppRouter {
        get { self[AppRouterKey.self] }
        set { self[AppRouterKey.self] = newValue }
    }
}
```

### Step 3e — Replace All `NavigationLink` with Router Calls

Search all files in `PlankChallenge/` for `NavigationLink`. For each:

1. Remove the `NavigationLink` wrapper
2. Replace it with a `Button` that calls `router.navigate(to: .destination)`
3. If the original `NavigationLink` used a `label:` closure for its visual content, keep that content inside the `Button`

```swift
// Before
NavigationLink(destination: PlankDetailView(plankId: plank.id)) {
    PlankRowView(plank: plank)
}

// After
@Environment(\.appRouter) var router

Button {
    router.navigate(to: .plankDetail(id: plank.id))
} label: {
    PlankRowView(plank: plank)
}
.buttonStyle(.plain) // preserve the row's visual style
```

### Step 3f — Implement Deep Link Handling

With path-based routing, deep links from push notifications become trivial. Update `PlankChallengeApp.swift` to handle deep links:

```swift
// In PlankChallengeApp.swift
@State private var plankRouter = AppRouter()
// ... other routers

// Handle deep links from push notifications
func handleDeepLink(_ url: URL) {
    // Parse the URL and navigate
    // e.g. plankchallenge://plank/abc123 -> .plankDetail(id: "abc123")
    // e.g. plankchallenge://user/xyz456 -> .userProfile(userId: "xyz456")
    // e.g. plankchallenge://group/grp789 -> .groupDetail(groupId: "grp789")
    guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }

    switch components.host {
    case "plank":
        if let id = components.path.split(separator: "/").first.map(String.init) {
            plankRouter.navigateToRoot()
            plankRouter.navigate(to: .plankDetail(id: id))
        }
    case "user":
        if let id = components.path.split(separator: "/").first.map(String.init) {
            profileRouter.navigateToRoot()
            profileRouter.navigate(to: .userProfile(userId: id))
        }
    case "group":
        if let id = components.path.split(separator: "/").first.map(String.init) {
            groupsRouter.navigateToRoot()
            groupsRouter.navigate(to: .groupDetail(groupId: id))
        }
    default:
        break
    }
}
```

Register this handler with `.onOpenURL` on the root view.

---

## Step 4 — Audit `.task {}` vs `onAppear` (Comprehensive Pass)

This is covered in detail in the Task Cancellation quality check, but this pass focuses specifically on the SwiftUI API correctness and idiomatic usage.

### Correct usage rules

| Scenario | Correct API |
|----------|-------------|
| Async work on view appearance | `.task { await ... }` |
| Sync work on view appearance | `.onAppear { ... }` |
| Async work that re-runs when a value changes | `.task(id: value) { await ... }` |
| Async work triggered by a user action | `Button { Task { await ... } }` |
| Async work that should NOT cancel on disappear | `Task { await ... }` stored as a property |

### Search and fix

Search all files in `PlankChallenge/` for `onAppear` and audit each one:

```swift
// Fix 1 — async work inside onAppear
.onAppear {
    Task { await viewModel.load() }  // Bad
}
// Replace with:
.task {
    await viewModel.load()  // Good — auto-cancelled on disappear
}

// Fix 2 — sync work inside onAppear (leave as-is)
.onAppear {
    selectedTab = 0  // Fine — synchronous
}

// Fix 3 — async work that should re-run on selection change
.onAppear {
    Task { await leaderboardService.fetch(period: selectedPeriod) }
}
// Replace with:
.task(id: selectedPeriod) {
    await leaderboardService.fetch(period: selectedPeriod)
}
// Now it auto-cancels and re-runs whenever selectedPeriod changes
```

### Specific views to audit for `.task(id:)` opportunities

These views have filter/period/selection state that should trigger a re-fetch when changed:

- `LeaderboardView.swift` — `selectedPeriod` and `selectedType` pickers
- `PlankHistoryListView.swift` — if it has a filter or sort selection
- `GroupDetailView.swift` — if it has a tab selection (members / leaderboard)
- `SearchView.swift` — the search query string (debounced with `Task.sleep`)

For `SearchView.swift`, implement debounced search using `.task(id:)`:

```swift
@State private var searchQuery = ""

var body: some View {
    // ...
    .task(id: searchQuery) {
        // Debounce: wait 300ms before firing the search
        // If searchQuery changes again within 300ms, this task is cancelled and restarted
        guard !searchQuery.isEmpty else {
            searchResults = []
            return
        }
        try? await Task.sleep(for: .milliseconds(300))
        guard !Task.isCancelled else { return }
        await searchService.search(query: searchQuery)
    }
}
```

This is a clean, cancellation-safe debounce with zero additional dependencies.

---

## Step 5 — Audit `@State` vs `@Environment` Placement

A common SwiftUI mistake is placing state in a parent view that only a deeply nested child view uses — causing the parent to re-render unnecessarily when the state changes. Conversely, some state is placed in child views that should be owned by a parent (making it reset unexpectedly when the child is recreated).

### Rules

- **State that controls navigation** → owned by the router (`AppRouter`) or the root tab view
- **State that is shared between siblings** → owned by the lowest common ancestor, or moved to a service
- **State that is local to a single view's interaction** (e.g. `isShowingSheet`, `selectedTab`, `searchText`) → `@State` on that view, nowhere higher
- **State that must survive navigation back-and-forth** → moved to a service or the router

### Audit

Search for `@State private var` in screen views. For each, ask:
1. Is this state used only within this view? → correct placement
2. Is this state passed down to a child view as a `Binding`? → consider if it belongs in the child instead
3. Is this state shared between two sibling views? → move to their parent or to a service
4. Does this state need to persist when the user navigates away and returns? → move to a service

Common incorrect placements to look for:
- `isLoading` duplicated in both a view and its service — the service's `isLoading` is the source of truth; remove it from the view
- `selectedPeriod` in a parent view that passes it to a child — if only the child uses it, move it to the child
- Pagination state (`currentPage`, `hasMorePages`) in a view — this belongs in the service

---

## Step 6 — Final Verification Checklist

Before considering this quality check complete, confirm each of the following:

- [ ] Every `@Observable` service property that a view depends on is read unconditionally during `body` evaluation (not only inside `if`, `if let`, or lazy containers)
- [ ] No view body exceeds 200 lines; bodies over 100 lines have been reviewed and decomposed where appropriate
- [ ] Decomposed sub-views declare only the `@Environment` services they actually use
- [ ] `AppRoute` enum exists in `PlankChallenge/Navigation/AppRouter.swift` covering all navigable destinations
- [ ] `AppRouter` class exists with `navigate(to:)`, `navigateBack()`, and `navigateToRoot()` methods
- [ ] `MainTabView` creates one `AppRouter` per tab and injects it via `@Environment(\.appRouter)`
- [ ] `AppRouteView` resolves all `AppRoute` cases to their destination views
- [ ] All `NavigationLink` usages replaced with `Button { router.navigate(to: ...) }` calls
- [ ] Deep link handler exists in `PlankChallengeApp.swift` and parses notification URLs into `AppRoute` cases
- [ ] All async work on view appearance uses `.task {}` (not `onAppear { Task { } }`)
- [ ] Views with filter/period/search state use `.task(id: value) {}` to auto-cancel and re-run on value change
- [ ] `SearchView` implements debounced search using `.task(id: searchQuery)` with `Task.sleep`
- [ ] No `isLoading` state duplicated between a view and its service
- [ ] Pagination state lives in services, not views
- [ ] The app builds without "expression too complex" compiler errors
- [ ] All Xcode Previews render correctly after navigation refactor
