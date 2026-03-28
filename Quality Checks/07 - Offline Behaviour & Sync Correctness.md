# Quality Check: Offline Behaviour & Sync Correctness

## Your Task

You are an AI code editor tasked with auditing and fixing offline behaviour and sync correctness across the Plank Challenge iOS app. Your goal is to ensure that a user can complete a plank with no network connection, that it will be reliably delivered to the server when connectivity is restored, that the sync engine handles edge cases correctly, and that the app never silently loses a plank record.

A missed plank sync is not a minor bug — it directly breaks the user's streak, which is the app's core motivational mechanic. Treat every finding in this document as high priority.

Work through this document top to bottom. For each section, search the codebase, identify the problems, implement the fixes, and move on. Do not skip sections.

---

## Project Context

**App**: Plank Challenge — a social fitness iOS app where users log a daily plank and maintain a streak.

**Platform**: iOS, SwiftUI, Swift 5.9+, `@Observable`, Swift Concurrency. Backend: Cloudflare Workers + Hono + Drizzle ORM + D1 (SQLite).

**Key architectural facts you need to know:**
- Screen views: `PlankChallenge/` top level. Services: `PlankChallenge/Services/`. API client: `PlankChallenge/Services/API/APIClient.swift`
- The backend accepts planks at `POST /planks` with a `clientId` (UUID) field for idempotent deduplication — this is the foundation of safe offline retry
- A sync endpoint exists at `GET /planks/sync?since=<timestamp>` for incremental sync — it returns planks modified after the given timestamp, including soft-deleted ones (`deletedAt` field)
- `@AppStorage` (UserDefaults) is used in `PlankTimerView.swift` to persist today's plank count and times across cold launches
- `PlankSession` model includes: `id`, `date`, `durationSeconds`, `plankTypeRaw`, `inputMethodRaw`, `timezoneIdentifier`, `createdAt`, `modifiedAt`
- `KeychainService` stores JWT tokens — network requests require authentication
- There is currently no persistent offline queue — failed plank saves are lost if the app is closed before connectivity returns
- The sync cursor (last sync timestamp) is stored somewhere in `PlankService` — identify its exact storage mechanism (likely `@AppStorage` or `UserDefaults`)

---

## Step 1 — Understand the Current Sync Architecture

Before making any changes, read and fully understand the existing sync implementation:

1. `PlankChallenge/Services/PlankService.swift` — find:
   - Where the sync cursor (last sync timestamp) is stored and how it is updated
   - How `POST /planks` is called and what happens on failure
   - How `GET /planks/sync` is called and how results are merged into local state
   - Whether `clientId` is generated per-plank and how
2. `PlankChallenge/Services/API/APIClient.swift` — find:
   - How network errors are surfaced (does it throw on timeout? On no connection?)
   - Whether there is any retry logic built in at the API client level
3. `PlankChallenge/Services/API/Models/APIModels.swift` — find:
   - The exact shape of `CreatePlankRequest` and `CreatePlankResponse`
   - The exact shape of the sync response

Document your findings. You will need this understanding for every step that follows.

---

## Step 2 — Implement a Persistent Offline Queue

This is the most important step in this quality check. The offline queue ensures that a plank saved without network connectivity is not lost — it is persisted to disk and retried automatically when connectivity returns.

### Step 2a — Define the Queue Entry Model

Create `PlankChallenge/Services/OfflinePlankQueue.swift`:

```swift
import Foundation

/// A plank save request that failed due to network unavailability
/// and is waiting to be retried when connectivity is restored.
struct PendingPlank: Codable, Identifiable {
    let id: String           // clientId — used for deduplication on the server
    let date: Date
    let durationSeconds: Int
    let plankTypeRaw: String
    let inputMethodRaw: String
    let timezoneIdentifier: String
    let createdAt: Date
    let attemptCount: Int    // how many times we have tried to send this
    let firstAttemptAt: Date // when the user originally completed the plank

    /// Maximum number of retry attempts before giving up and alerting the user
    static let maxAttempts = 10

    func withIncrementedAttempt() -> PendingPlank {
        PendingPlank(
            id: id,
            date: date,
            durationSeconds: durationSeconds,
            plankTypeRaw: plankTypeRaw,
            inputMethodRaw: inputMethodRaw,
            timezoneIdentifier: timezoneIdentifier,
            createdAt: createdAt,
            attemptCount: attemptCount + 1,
            firstAttemptAt: firstAttemptAt
        )
    }
}
```

### Step 2b — Implement the Queue Manager

Add the following to `OfflinePlankQueue.swift`:

```swift
/// Manages a persistent queue of plank saves that failed due to network issues.
/// Persists to disk so the queue survives app restarts.
@Observable @MainActor
final class OfflinePlankQueue {
    static let shared = OfflinePlankQueue()

    private(set) var pendingPlanks: [PendingPlank] = []

    /// True if there are planks waiting to be synced
    var hasPendingPlanks: Bool { !pendingPlanks.isEmpty }

    /// Number of planks that have exceeded maxAttempts and need user attention
    var failedPlanks: [PendingPlank] {
        pendingPlanks.filter { $0.attemptCount >= PendingPlank.maxAttempts }
    }

    private let storageURL: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("offline_plank_queue.json")
    }()

    private init() {
        load()
    }

    /// Adds a plank to the queue after a failed network save.
    func enqueue(_ plank: PendingPlank) {
        // Avoid duplicates — if this clientId is already queued, don't add again
        guard !pendingPlanks.contains(where: { $0.id == plank.id }) else { return }
        pendingPlanks.append(plank)
        persist()
    }

    /// Removes a successfully synced plank from the queue.
    func dequeue(id: String) {
        pendingPlanks.removeAll { $0.id == id }
        persist()
    }

    /// Increments the attempt count for a plank that failed to sync.
    func recordFailedAttempt(id: String) {
        guard let index = pendingPlanks.firstIndex(where: { $0.id == id }) else { return }
        pendingPlanks[index] = pendingPlanks[index].withIncrementedAttempt()
        persist()
    }

    /// Clears the queue — called on logout to prevent one user's
    /// pending planks from being submitted under a different account.
    func clear() {
        pendingPlanks.removeAll()
        persist()
    }

    // MARK: - Persistence

    private func persist() {
        do {
            let data = try JSONEncoder().encode(pendingPlanks)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            // Non-fatal: if persistence fails, the queue exists in memory
            // and will be retried this session, but won't survive a restart
        }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return }
        do {
            let data = try Data(contentsOf: storageURL)
            pendingPlanks = try JSONDecoder().decode([PendingPlank].self, from: data)
        } catch {
            // Corrupt queue file — start fresh
            pendingPlanks = []
        }
    }
}
```

### Step 2c — Enqueue Failed Plank Saves

In `PlankService.savePlank()`, after a network failure, instead of only rolling back the optimistic update, also enqueue the failed plank:

```swift
func savePlank(duration: Int, type: PlankType, inputMethod: InputMethod) async {
    let clientId = UUID().uuidString
    let now = Date()

    // Optimistic update
    let optimisticSession = PlankSession(
        id: clientId, date: now, durationSeconds: duration,
        plankTypeRaw: type.rawValue, inputMethodRaw: inputMethod.rawValue,
        timezoneIdentifier: TimeZone.current.identifier,
        createdAt: now, modifiedAt: now
    )
    planks.insert(optimisticSession, at: 0)

    do {
        let response = try await apiClient.createPlank(
            CreatePlankRequest(
                clientId: clientId, date: now, durationSeconds: duration,
                plankType: type.rawValue, inputMethod: inputMethod.rawValue,
                timezone: TimeZone.current.identifier
            )
        )
        // Replace optimistic entry with server-confirmed entry
        planks = planks.map { $0.id == clientId ? PlankSession(from: response.plank) : $0 }
        // Apply cascade updates (see State Consistency quality check)
        NotificationCenter.default.post(name: .plankSaved, object: nil, userInfo: ["response": response])

    } catch {
        guard !Task.isCancelled else { return }

        // Check if this is a network error (worth retrying) or a permanent error
        let appError = AppError.from(error)

        if case .network = appError {
            // Keep the optimistic entry visible — it's in the queue
            // Mark it as pending so the UI can show a "pending sync" indicator
            if let index = planks.firstIndex(where: { $0.id == clientId }) {
                // Optionally mark the session as pending — requires a `isPendingSync` field on PlankSession
            }
            // Enqueue for retry
            OfflinePlankQueue.shared.enqueue(PendingPlank(
                id: clientId, date: now, durationSeconds: duration,
                plankTypeRaw: type.rawValue, inputMethodRaw: inputMethod.rawValue,
                timezoneIdentifier: TimeZone.current.identifier,
                createdAt: now, attemptCount: 1, firstAttemptAt: now
            ))
        } else {
            // Permanent error — roll back the optimistic update
            planks.removeAll { $0.id == clientId }
            self.error = appError
        }
    }
}
```

---

## Step 3 — Implement Automatic Queue Draining

The queue must be drained automatically when network connectivity is restored. Use `Network.framework`'s `NWPathMonitor` to observe connectivity.

### Step 3a — Add a Connectivity Monitor

Create `PlankChallenge/Services/ConnectivityMonitor.swift`:

```swift
import Network
import Foundation

/// Observes network connectivity and posts notifications when it changes.
@Observable @MainActor
final class ConnectivityMonitor {
    static let shared = ConnectivityMonitor()

    private(set) var isConnected: Bool = true
    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "connectivity.monitor")

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                let wasConnected = self?.isConnected ?? true
                self?.isConnected = path.status == .satisfied
                if !wasConnected && path.status == .satisfied {
                    // Just regained connectivity — drain the offline queue
                    NotificationCenter.default.post(name: .connectivityRestored, object: nil)
                }
            }
        }
        monitor.start(queue: monitorQueue)
    }

    deinit {
        monitor.cancel()
    }
}

extension Notification.Name {
    static let connectivityRestored = Notification.Name("connectivityRestored")
}
```

### Step 3b — Drain the Queue on Connectivity Restore

In `PlankService`, observe `.connectivityRestored` and drain the queue:

```swift
// In PlankService.init() or a setup() method
NotificationCenter.default.addObserver(
    forName: .connectivityRestored,
    object: nil,
    queue: .main
) { [weak self] _ in
    Task { @MainActor in
        await self?.drainOfflineQueue()
    }
}

// Also drain on app foreground — covers the case where the app was
// backgrounded without connectivity and relaunched with it
NotificationCenter.default.addObserver(
    forName: UIApplication.didBecomeActiveNotification,
    object: nil,
    queue: .main
) { [weak self] _ in
    Task { @MainActor in
        await self?.drainOfflineQueue()
    }
}
```

### Step 3c — Implement the Drain Function

```swift
/// Attempts to send all pending planks in the offline queue to the server.
/// Called automatically when connectivity is restored or the app becomes active.
private func drainOfflineQueue() async {
    let queue = OfflinePlankQueue.shared
    guard queue.hasPendingPlanks else { return }

    // Process planks in chronological order (oldest first)
    let pending = queue.pendingPlanks
        .filter { $0.attemptCount < PendingPlank.maxAttempts }
        .sorted { $0.firstAttemptAt < $1.firstAttemptAt }

    for pendingPlank in pending {
        guard !Task.isCancelled else { break }

        do {
            let response = try await apiClient.createPlank(
                CreatePlankRequest(
                    clientId: pendingPlank.id,
                    date: pendingPlank.date,
                    durationSeconds: pendingPlank.durationSeconds,
                    plankType: pendingPlank.plankTypeRaw,
                    inputMethod: pendingPlank.inputMethodRaw,
                    timezone: pendingPlank.timezoneIdentifier
                )
            )
            // Success — remove from queue and update local state
            queue.dequeue(id: pendingPlank.id)

            // Replace the optimistic local entry with the confirmed server entry
            if let index = planks.firstIndex(where: { $0.id == pendingPlank.id }) {
                planks[index] = PlankSession(from: response.plank)
            }

            // Cascade streak/badge updates
            NotificationCenter.default.post(name: .plankSaved, object: nil, userInfo: ["response": response])

        } catch {
            let appError = AppError.from(error)
            if case .network = appError {
                // Still no connectivity — record the failed attempt and stop trying
                queue.recordFailedAttempt(id: pendingPlank.id)
                break // No point continuing — all remaining planks will also fail
            } else if case .server(let code, _) = appError, code == "DUPLICATE" {
                // Server already has this plank (clientId deduplication) — remove from queue
                queue.dequeue(id: pendingPlank.id)
            } else {
                // Unexpected error — record and continue to next plank
                queue.recordFailedAttempt(id: pendingPlank.id)
            }
        }
    }

    // Alert the user if any planks have exceeded max attempts
    if !queue.failedPlanks.isEmpty {
        self.error = AppError.permanent(
            message: "\(queue.failedPlanks.count) plank(s) could not be synced after multiple attempts. Please contact support."
        )
    }
}
```

---

## Step 4 — Show Pending Sync State in the UI

The user should know when a plank has been recorded locally but not yet confirmed by the server. This prevents confusion ("did my plank save?") and gives confidence that it will sync.

### Step 4a — Add a Pending Sync Indicator

In `PlankTimerView.swift`, observe `OfflinePlankQueue.shared.hasPendingPlanks` and show an indicator:

```swift
// In PlankTimerView, when state is .completedToday
if offlineQueue.hasPendingPlanks {
    HStack(spacing: 6) {
        ProgressView()
            .scaleEffect(0.7)
        Text("Syncing \(offlineQueue.pendingPlanks.count) plank(s)...")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
    .padding(.horizontal)
}
```

In `PlankHistoryListView.swift`, mark pending (not-yet-synced) planks with a visual indicator — a small clock icon or a "Pending" badge:

```swift
// PlankSession needs a way to identify pending entries
// Option A: cross-reference with OfflinePlankQueue
let isPending = OfflinePlankQueue.shared.pendingPlanks.contains { $0.id == plank.id }

PlankRowView(plank: plank)
    .overlay(alignment: .trailing) {
        if isPending {
            Image(systemName: "clock.arrow.circlepath")
                .foregroundStyle(.orange)
                .padding(.trailing)
        }
    }
```

### Step 4b — Inject `ConnectivityMonitor` and `OfflinePlankQueue` into the Environment

Add both to `PlankChallengeApp.swift` environment injection and make them available to views that need them. Add environment keys following the same pattern as the other services.

---

## Step 5 — Audit the Sync Engine for Edge Cases

The existing `GET /planks/sync?since=<timestamp>` endpoint is the right approach. Audit its implementation for the following edge cases:

### Edge Case A — First sync after install

On a fresh install with no stored sync cursor, the `since` parameter should be `nil` or a zero timestamp — meaning "give me everything". Verify this is handled:

```swift
// In PlankService
private var lastSyncTimestamp: Date? {
    get { UserDefaults.standard.object(forKey: "lastSyncTimestamp") as? Date }
    set { UserDefaults.standard.set(newValue, forKey: "lastSyncTimestamp") }
}

func sync() async {
    let since = lastSyncTimestamp // nil on first sync
    let response = try await apiClient.syncPlanks(since: since)
    // merge response...
    lastSyncTimestamp = response.meta.timestamp // update cursor to server's response time
}
```

Verify that when `since` is `nil`, the request either omits the parameter or sends `since=0`, and that the backend handles this correctly by returning all planks.

### Edge Case B — Soft-deleted planks

The sync response includes planks with a `deletedAt` field. Verify the sync merge logic:
1. If a plank exists locally and the server returns it with `deletedAt != nil` → remove it from the local list
2. If a plank does not exist locally and the server returns it with `deletedAt != nil` → ignore it (do not add then remove)

```swift
for serverPlank in response.planks {
    if serverPlank.deletedAt != nil {
        // Remove from local list if present
        planks.removeAll { $0.id == serverPlank.id }
    } else {
        // Upsert — add if new, update if existing
        if let index = planks.firstIndex(where: { $0.id == serverPlank.id }) {
            planks[index] = PlankSession(from: serverPlank)
        } else {
            planks.append(PlankSession(from: serverPlank))
        }
    }
}
// Re-sort by date descending after merge
planks.sort { $0.date > $1.date }
```

### Edge Case C — Clock skew

The sync cursor is a timestamp from the client's clock. If the client clock is wrong (significantly behind the server), some planks may never appear in sync results because `modifiedAt > since` evaluates differently on the server.

Fix: always use the server's `meta.timestamp` from the sync response as the new cursor — not the client's current time. This ensures the next sync's `since` value is always in the server's time reference.

```swift
// Wrong — uses client clock
lastSyncTimestamp = Date()

// Correct — uses server's timestamp from response meta
lastSyncTimestamp = response.meta.timestamp
```

Verify this is implemented correctly in `PlankService.sync()`.

### Edge Case D — Timezone change mid-day

The user travels across a timezone boundary. "Today" in their new timezone is different from "today" in their previous timezone. The `@AppStorage` today-state (plank count, plank times) was computed in the old timezone.

On app foreground, compare `TimeZone.current.identifier` against the stored timezone identifier. If changed:
1. Reset `@AppStorage` today-state
2. Trigger a fresh sync to get the authoritative server state for the new "today"
3. Update the stored timezone identifier

```swift
// In PlankService or PlankTimerView's .task {}
private func handleTimezoneChangeIfNeeded() async {
    let storedTimezone = UserDefaults.standard.string(forKey: "lastKnownTimezone") ?? TimeZone.current.identifier
    let currentTimezone = TimeZone.current.identifier

    if storedTimezone != currentTimezone {
        // Timezone has changed — reset today state and re-sync
        UserDefaults.standard.set(currentTimezone, forKey: "lastKnownTimezone")
        // Reset @AppStorage today counters (see State Consistency quality check for key names)
        await sync()
    }
}
```

### Edge Case E — Large sync payloads (offline for multiple days)

If the app is offline for several days, the sync response may return a very large number of planks. Verify the sync endpoint supports — and the client uses — pagination:

```swift
// Paginated sync request
GET /planks/sync?since=<timestamp>&limit=100&cursor=<cursor>
```

If the backend does not yet support cursor-based pagination on the sync endpoint, add a `limit` parameter and implement client-side looping:

```swift
func sync() async throws {
    var cursor: String? = nil
    var hasMore = true

    while hasMore {
        let response = try await apiClient.syncPlanks(since: lastSyncTimestamp, limit: 100, cursor: cursor)
        mergeSyncResults(response.planks)
        cursor = response.meta.nextCursor
        hasMore = response.meta.nextCursor != nil
    }

    lastSyncTimestamp = // server timestamp from final response
}
```

---

## Step 6 — Audit Logout Behaviour

When the user signs out, the offline queue must be cleared. A pending plank from one user must never be submitted under a different user's account.

Verify `AuthService.signOut()` calls:

```swift
OfflinePlankQueue.shared.clear()
ConnectivityMonitor.shared // no action needed — monitoring continues
```

Also verify that the queue drain (`drainOfflineQueue`) checks that the user is still authenticated before submitting:

```swift
private func drainOfflineQueue() async {
    guard authService.isAuthenticated else {
        // User signed out — do not submit pending planks
        return
    }
    // ... drain logic
}
```

---

## Step 7 — Add Sync Status to the UI

Expose the sync status to the user in `SettingsView.swift` or `ProfileView.swift`:

```swift
// In SettingsView or a dedicated "Account" section
Section("Sync Status") {
    if offlineQueue.hasPendingPlanks {
        Label(
            "\(offlineQueue.pendingPlanks.count) plank(s) pending sync",
            systemImage: "clock.arrow.circlepath"
        )
        .foregroundStyle(.orange)

        Button("Sync Now") {
            Task { await plankService.drainOfflineQueue() }
        }
        .disabled(!connectivityMonitor.isConnected)
    } else {
        Label("All planks synced", systemImage: "checkmark.circle.fill")
            .foregroundStyle(.green)
    }

    if !connectivityMonitor.isConnected {
        Label("No internet connection", systemImage: "wifi.slash")
            .foregroundStyle(.red)
    }

    // Last sync timestamp
    if let lastSync = plankService.lastSyncTimestamp {
        Text("Last synced \(lastSync.formatted(.relative(presentation: .named)))")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}
```

---

## Step 8 — Final Verification Checklist

Before considering this quality check complete, confirm each of the following:

- [ ] `OfflinePlankQueue` exists, persists to disk as JSON, and survives app restarts
- [ ] `PendingPlank` is `Codable` and includes `clientId`, `attemptCount`, and `firstAttemptAt`
- [ ] `PlankService.savePlank()` enqueues the plank to `OfflinePlankQueue` on network failure (not on permanent/server errors)
- [ ] Optimistic UI entries remain visible while a plank is in the queue (not rolled back)
- [ ] `ConnectivityMonitor` uses `NWPathMonitor` and posts `.connectivityRestored` when connectivity is regained
- [ ] `PlankService` observes `.connectivityRestored` and `UIApplication.didBecomeActiveNotification` and calls `drainOfflineQueue()`
- [ ] `drainOfflineQueue()` processes planks oldest-first, stops on network error, dequeues on server deduplication response
- [ ] Planks that exceed `maxAttempts` surface an error to the user rather than silently failing forever
- [ ] Pending planks are shown with a visual indicator in `PlankTimerView` and `PlankHistoryListView`
- [ ] The sync engine uses the server's `meta.timestamp` as the new cursor — not the client's clock
- [ ] Soft-deleted planks returned by sync are removed from local state; absent + deleted planks are ignored
- [ ] Sync supports pagination via `limit` + cursor to handle large offline periods
- [ ] Timezone change detection triggers a fresh sync and resets `@AppStorage` today-state
- [ ] `OfflinePlankQueue.clear()` is called on logout
- [ ] `drainOfflineQueue()` checks `authService.isAuthenticated` before submitting
- [ ] `SettingsView` or `ProfileView` shows sync status, pending count, last sync time, and a manual "Sync Now" button
- [ ] `ConnectivityMonitor` and `OfflinePlankQueue` are injected into the environment and accessible to views that need them
