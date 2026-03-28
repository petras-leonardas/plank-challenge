# SwiftUI Common Pitfalls & Best Practices

A reference document covering the most frequently overlooked areas in new SwiftUI apps — based on analysis of the Plank Challenge codebase. Each section describes the problem, why it matters, and what good looks like.

---

## 1. Error Handling — The Most Forgotten Layer

### The Problem

Most apps implement the happy path thoroughly and treat error handling as an afterthought. The result:

- API failures are caught but never surfaced to the user — the screen just stays empty or stale
- Fire-and-forget `Task { }` closures swallow errors silently
- No distinction between transient errors (network timeout, 503) and permanent errors (404, 403, deleted resource) — both get the same generic "Something went wrong" message
- No retry affordance — the user taps a button, nothing happens, taps again, now two requests are in flight

### What Good Looks Like

Every user-initiated async operation should have three explicit states in the view: **loading**, **success**, and **error**. The error state should:

1. Tell the user what went wrong (at a human level, not a technical one)
2. Offer a retry action where appropriate
3. Distinguish between "try again" errors and "nothing you can do" errors

```swift
// Bad — error is swallowed
func loadPlanks() {
    Task {
        let planks = try? await plankService.fetchPlanks()
        self.planks = planks ?? []
    }
}

// Better — error state is explicit and exposed to the view
func loadPlanks() {
    Task {
        isLoading = true
        error = nil
        do {
            planks = try await plankService.fetchPlanks()
        } catch {
            self.error = error
        }
        isLoading = false
    }
}
```

**Error classification matters:**

```swift
enum AppError: Error {
    case transient(underlying: Error)   // retry makes sense
    case permanent(message: String)     // retry will not help
    case unauthenticated                // requires sign-in flow
}
```

---

## 2. Task Cancellation & Concurrency Hazards

### The Problem

`@MainActor` services that store state and spawn `Task { }` internally are a common source of subtle bugs:

- **Double mutations**: rapid taps enqueue multiple API calls; responses arrive out of order and overwrite each other
- **Leaked tasks**: if tasks are owned by a service (not a view), they outlive the view that triggered them — wasting network resources and potentially mutating state the user no longer cares about
- **Missing cancellation**: `.task {}` view modifier is cancellation-aware (it cancels when the view disappears). `onAppear` is not. Mixing them inconsistently causes orphaned network calls
- **Partial failures in `withTaskGroup`**: if one child task fails, do the other results still render, or does the whole screen fail? This needs an explicit decision

### What Good Looks Like

- Store task references when you need manual cancellation control:

```swift
private var loadTask: Task<Void, Never>?

func load() {
    loadTask?.cancel()
    loadTask = Task {
        await fetchData()
    }
}
```

- Prefer `.task {}` over `onAppear` for async work in views — it gets cancelled automatically
- In `withTaskGroup`, decide explicitly: fail fast (throw on first error) vs. partial success (collect results, ignore failures)
- Debounce rapid user actions (e.g. button taps) to prevent enqueuing multiple identical requests

---

## 3. State Consistency Across Services

### The Problem

When multiple singleton services hold overlapping data, mutations in one service don't automatically update others. Classic example: a user logs a plank (`PlankService`), which changes their streak (`StreakService`), which might unlock a badge (`BadgeService`), which changes their profile stats (`UserService`). If each service manages its own cache independently, screens can show inconsistent numbers simultaneously.

The `@AppStorage` today-state is a second source of truth that can diverge from server state — particularly across timezone boundaries or if the device clock is wrong.

### What Good Looks Like

- Define a clear **invalidation strategy**: after a plank is saved, which services need to refresh?
- Consider a lightweight event/notification bus for cross-service coordination:

```swift
// After plank is saved successfully
NotificationCenter.default.post(name: .plankSaved, object: nil)

// StreakService, BadgeService, UserService each observe this
// and refresh their relevant cached data
```

- `@AppStorage` today-state should have an explicit staleness check: on app foreground, compare the stored date against today's date in the user's timezone. If it's a different day, reset.

---

## 4. Testability — Concrete Singletons vs. Protocol Abstractions

### The Problem

Services implemented as concrete singletons (`static let shared`) that are referenced directly cannot be substituted in unit tests or Xcode Previews without hitting real network calls. This means:

- Logic inside services is untestable in isolation
- Xcode Previews require either real data or hardcoded mock data patched in ad-hoc
- Bugs in service logic (streak calculation edge cases, badge award conditions) can only be caught by manually testing the full app

### What Good Looks Like

Define a protocol for each service and inject the concrete implementation via environment:

```swift
protocol PlankServiceProtocol {
    var planks: [PlankSession] { get }
    var isLoading: Bool { get }
    func fetchPlanks() async throws
    func savePlank(duration: Int) async throws -> PlankSession
}

// Production
final class PlankService: PlankServiceProtocol { ... }

// Tests & Previews
final class MockPlankService: PlankServiceProtocol {
    var planks: [PlankSession] = PlankSession.mocks
    var isLoading = false
    func fetchPlanks() async throws { }
    func savePlank(duration: Int) async throws -> PlankSession { .mock }
}
```

Inject at the root with the concrete type; swap in mocks for tests and previews. This also makes the Design System Catalog genuinely useful — every component can be previewed with controlled mock data.

---

## 5. Accessibility

### The Problem

Accessibility is almost universally deferred to "after launch" and rarely revisited. This creates real risks:

- App Store rejection if VoiceOver renders the app completely unusable
- WCAG contrast failures in custom color palettes (deep blue themes are especially prone to this for secondary/disabled text)
- Custom animated components (`ActivePlankRing`, `LavaBubblesView`, celebration overlays) have no VoiceOver labels and no reduced-motion fallback
- Layouts built for standard font sizes can break badly at accessibility sizes

### What Good Looks Like

**Reduced Motion** — every decorative animation should check this:

```swift
@Environment(\.accessibilityReduceMotion) var reduceMotion

var body: some View {
    if reduceMotion {
        StaticPlankRing()
    } else {
        AnimatedPlankRing()
    }
}
```

**VoiceOver labels** on custom components:

```swift
ActivePlankRing(progress: 0.6)
    .accessibilityLabel("Plank timer: 60% complete")
    .accessibilityHint("Double tap to stop timer")
```

**Minimum tap targets** — ensure all interactive elements are at least 44×44pt, using `.contentShape()` if needed.

**Contrast** — test the color palette with Xcode's Accessibility Inspector. Pay particular attention to secondary text on dark backgrounds.

**Dynamic Type** — test layouts at the largest accessibility font size (AX5). Use `scaledMetric` for spacing and avoid fixed-height containers for text.

---

## 6. SwiftUI-Specific Pitfalls

### 6a. `@Observable` Rendering Trap

`@Observable` (Swift 5.9+) only tracks properties that are *read* during a view's `body` evaluation. If a property is conditionally read (inside an `if`, or only in a child view that isn't always rendered), changes to it won't trigger a re-render of the parent.

```swift
// This parent will NOT re-render when badgeCount changes
// because badgeCount is only read inside the conditional child
var body: some View {
    if showBadges {
        BadgeView(count: service.badgeCount) // only read conditionally
    }
}
```

Be explicit about which properties a view depends on, and test re-render behaviour after state changes.

### 6b. View Body Complexity

Large view bodies (hundreds of lines, many conditional branches) slow down SwiftUI's diffing and make the compiler struggle with type inference — resulting in "expression too complex" errors and slow build times.

Extract meaningful sub-views aggressively. This isn't just style — it's a performance and build-time concern:

```swift
// Instead of one giant body, extract:
var body: some View {
    VStack {
        TimerHeader()
        TimerDisplay(state: timerState)
        TimerControls(state: timerState, onTap: handleTap)
        if case .celebration = timerState {
            CelebrationOverlay()
        }
    }
}
```

### 6c. Navigation — Ad-hoc Links vs. Path-based Routing

Ad-hoc `NavigationLink` scattered through views doesn't compose well:

- Deep linking (from a push notification to a specific screen) requires reconstructing the full navigation stack manually
- State restoration on app relaunch is nearly impossible
- Testing navigation flows requires UI tests, not unit tests

**Best practice:** Use `NavigationStack` with a typed path enum from the start:

```swift
enum AppRoute: Hashable {
    case plankDetail(id: String)
    case userProfile(userId: String)
    case groupDetail(groupId: String)
    case badgeDetail(badge: Badge)
}

// In root view
@State private var path: [AppRoute] = []

NavigationStack(path: $path) {
    MainTabView()
        .navigationDestination(for: AppRoute.self) { route in
            switch route {
            case .plankDetail(let id): PlankDetailView(id: id)
            case .userProfile(let userId): UserProfileView(userId: userId)
            // ...
            }
        }
}
```

This makes deep linking from push notifications a single `path.append(.plankDetail(id: notif.plankId))` call.

### 6d. `.task {}` vs `onAppear`

| | `.task {}` | `onAppear` |
|---|---|---|
| Cancellation | Cancelled when view disappears | Not cancelled |
| Async support | Native | Requires wrapping in `Task { }` |
| Re-runs on value change | Yes, with `id:` parameter | No |

Default to `.task {}` for all async work triggered by a view appearing. Only use `onAppear` for synchronous setup.

---

## 7. Offline Behaviour & Sync Correctness

### The Problem

A sync endpoint and `clientId` deduplication exist, which is the right foundation. But there are several edge cases that commonly go unaddressed:

- **No offline queue**: if the user completes a plank with no network, it fails. The `@AppStorage` counter goes up, but the server never receives the plank — the streak is at risk
- **Timezone transitions**: a user travels across a timezone boundary mid-day. "Today" changes. The local `@AppStorage` state no longer matches the server's definition of today
- **Sync cursor staleness**: if the app is offline for multiple days, the `since=` cursor may return a very large payload — there's no upper bound or chunking strategy

### What Good Looks Like

- **Offline queue**: persist failed plank submissions to disk (SwiftData or a simple JSON file in the app's documents directory). On next app foreground with connectivity, drain the queue in order
- **Timezone detection**: store the user's timezone at plank-save time (already done), and on app launch compare `TimeZone.current.identifier` against the last stored value. If changed, recalculate "today" boundary and reset `@AppStorage` state accordingly
- **Sync chunking**: cap the `limit` on sync requests and implement cursor-based pagination even for the sync endpoint

---

## 8. Security Considerations

### The Problem

The Keychain is used correctly for token storage. But several areas warrant attention as the app grows:

- **No certificate pinning**: a sophisticated attacker on the same network can MITM the API with a rogue certificate. This matters more for a social app where friend lists, DMs, and user locations may be involved
- **`@AppStorage` is UserDefaults — not encrypted**: today's plank count is low-sensitivity, but if any personal data migrates to `@AppStorage`, it's stored in plaintext in the app sandbox
- **Rate limiting on the backend**: the KV-based rate limiter needs to be confirmed present on all mutating endpoints — especially plank creation, which is the core integrity mechanism. Leaderboard fairness depends on it

### What Good Looks Like

- For a fitness app at this stage, certificate pinning is optional but worth planning for. Use `URLSession` trust evaluation callbacks when it becomes a priority
- Audit `@AppStorage` keys regularly — only store truly ephemeral, non-sensitive UI state there
- Ensure the backend rate limiter is applied as middleware to all routes that mutate data, not just the most obvious ones

---

## Summary & Priority Matrix

| Priority | Area | Risk if Ignored |
|----------|------|-----------------|
| **High** | Error handling & retry UI | Silent failures; users think app is broken |
| **High** | Task cancellation & concurrency | Memory leaks, double mutations, race conditions |
| **High** | Service protocol abstractions | No path to unit testing without major refactor |
| **Medium** | State invalidation strategy | Inconsistent numbers shown across screens after mutations |
| **Medium** | Accessibility (Reduce Motion, VoiceOver, contrast) | App Store rejection risk; excludes users |
| **Medium** | Path-based `NavigationStack` routing | Deep linking and state restoration very hard to add later |
| **Low** | Offline plank queuing | Poor UX on flaky connections; streak integrity risk |
| **Low** | SwiftUI view decomposition | Build time and diffing performance at scale |
| **Low** | Certificate pinning | Advanced threat model; not urgent at launch |

---

*Last updated: March 2026*
