# Plank Challenge — AI Agent Context

## What this app is

Plank Challenge is an iOS fitness app for daily plank streak tracking. The core idea is simple: one plank per day, build a consecutive streak, compete with friends. Users run a timer, earn badges, join groups, and compete on leaderboards. One plank per day is enforced by both the backend and the UI.

**Stack:** Native SwiftUI iOS app (iOS 17+) + Cloudflare Workers TypeScript backend.

---

## Your dev workflow

The owner works with a **physical iPhone connected via USB**. All changes are built and deployed directly to the device — there is no simulator workflow.

**Device:** "LeoDesignsTheWorld" — ID `00008150-001E444A0AD2401C`

### Build and install iOS to device

```bash
# From: PlankChallenge/

# Step 1 — build (check output for errors before installing)
xcodebuild \
  -project PlankChallenge.xcodeproj \
  -scheme PlankChallenge \
  -destination "id=00008150-001E444A0AD2401C" \
  -configuration Debug \
  build 2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"

# Step 2 — install
xcodebuild \
  -project PlankChallenge.xcodeproj \
  -scheme PlankChallenge \
  -destination "id=00008150-001E444A0AD2401C" \
  -configuration Debug \
  install

# Step 3 — deploy to device
xcrun devicectl device install app \
  --device 00008150-001E444A0AD2401C \
  "$(find ~/Library/Developer/Xcode/DerivedData/PlankChallenge-*/Build/Intermediates.noindex/ArchiveIntermediates/PlankChallenge/InstallationBuildProductsLocation/Applications -name 'PlankChallenge.app' | head -1)"
```

**Always do all three steps** after iOS changes. Use `clean build` instead of `build` when you change a protocol, enum raw value, or type definition — Xcode's incremental build can produce misleading errors from stale artifacts. For view or logic-only changes, `build` alone is fine.

### Deploy backend to Cloudflare

```bash
# From: backend/
npx wrangler deploy
```

The backend is **always live on Cloudflare Workers** — there is no local backend dev server in the normal workflow. The iOS app always points to the production Worker URL.

**Live API URL:** `https://plank-challenge-api.petras-leonardas.workers.dev`

**D1 direct SQL** (for migrations or one-off data fixes):
```bash
npx wrangler d1 execute DB --remote --command "YOUR SQL HERE"
```

### After any change session — commit and push

```bash
git add <changed files>
git commit -m "description"
git push
```

Commit after each logical fix, not only at end of session. Never commit `UserInterfaceState.xcuserstate` — it is git-ignored and must stay that way.

---

## Architecture

### iOS

- **Language/framework:** Swift 5, SwiftUI, `@Observable` (not `ObservableObject`)
- **iOS deployment target:** 17.0
- **Bundle ID:** `com.leo.PlankChallenge`
- **Xcode scheme:** `PlankChallenge`

**Service injection:** All nine services are injected via SwiftUI `@Environment`. Never instantiate services directly in views — always use `@Environment(\.serviceName)`.

```swift
@Environment(\.plankService) private var plankService
@Environment(\.groupService) private var groupService
// etc.
```

Services are singletons created in `PlankChallengeApp.swift` and injected into the view hierarchy there.

**API calls:** All HTTP calls go through `APIClient.shared` (a Swift `actor`). It handles: Bearer token auth, `.convertFromSnakeCase` JSON decoding (backend sends snake_case, Swift models use camelCase), automatic token refresh on 401, and 3-retry on network errors. Convenience methods: `.get()`, `.post()`, `.patch()`, `.delete()`, `.uploadBinary()`.

**All API response/request models** live in one file: `PlankChallenge/PlankChallenge/Services/API/Models/APIModels.swift`

**Navigation:** `RootView` is a state machine (loading → auth → onboarding → `MainTabView`). Main app is a 4-tab `TabView`. Within tabs, `NavigationStack` push navigation is used for detail views.

### Backend

- **Runtime:** Cloudflare Workers (TypeScript, Hono framework)
- **Database:** Cloudflare D1 (SQLite) — binding name `DB`
- **Image storage:** Cloudflare R2 — binding name `MEDIA`
- **Cache + rate limiting:** Cloudflare KV — bindings `CACHE`, `RATE_LIMIT`
- **Auth:** JWT (jose library), stored in iOS Keychain
- **Validation:** Zod schemas on every endpoint
- **Response format:** All responses wrapped in `{ success: true, data: {...}, meta: {...} }`
- **JSON casing:** Backend sends snake_case (`display_name`, `profile_image_url`). iOS `JSONDecoder` uses `.convertFromSnakeCase` to map automatically. Do not change this.

---

## Feature map — where to look for what

| Feature | iOS files | Backend file |
|---|---|---|
| Plank timer + state machine | `PlankTimerView.swift` | `routes/planks.ts` |
| Manual plank entry | `ManualEntryView.swift` | `routes/planks.ts` |
| Streak tracking | `StreakService.swift`, `ProgressView.swift` | `routes/streaks.ts`, `utils/streak.ts` |
| Badges | `BadgeService.swift`, `BadgesView.swift`, `APIBadgeView.swift` | `routes/badges.ts`, `utils/badges.ts` |
| Progress screen | `ProgressView.swift`, `StreakHeroView.swift`, `StreakCalendarView.swift` | `routes/streaks.ts`, `routes/planks.ts` |
| Authentication | `AuthService.swift`, `Views/Auth/` | `routes/auth.ts`, `middleware/auth.ts` |
| Onboarding | `Views/Onboarding/` | — |
| User profiles | `UserProfileView.swift`, `ProfileView.swift`, `UserService.swift` | `routes/users.ts` |
| Follow / social | `FollowListView.swift`, `UserService.swift` | `routes/users.ts` |
| Search | `SearchView.swift`, `UserService.swift` | `routes/users.ts` |
| Groups (list, create, discover) | `GroupsView.swift`, `GroupService.swift` | `routes/groups.ts` |
| Group detail + leaderboard | `GroupDetailView.swift`, `LeaderboardService.swift` | `routes/groups.ts`, `routes/leaderboards.ts` |
| Group settings (admin) | `GroupSettingsView.swift`, `GroupService.swift` | `routes/groups.ts` |
| Group member settings | `MemberGroupSettingsView.swift` | `routes/groups.ts` |
| Global leaderboard | `LeaderboardView.swift`, `GroupsView.swift` (compact), `LeaderboardService.swift` | `routes/leaderboards.ts` |
| Notifications | `NotificationsView.swift`, `InAppNotificationService.swift` | `routes/notifications.ts` |
| Settings | `SettingsView.swift` | `routes/planks.ts` (delete plank) |
| Avatar / group image upload | `MediaService.swift`, `ProfilePhotoEditorView.swift` | `routes/media.ts` |
| API client | `Services/API/APIClient.swift` | — |
| All API models | `Services/API/Models/APIModels.swift` | — |
| Service protocols + mocks | `Services/ServiceProtocols.swift`, `Services/MockServices.swift` | — |
| Environment key injection | `Services/EnvironmentKeys.swift` | — |
| App entry point | `PlankChallengeApp.swift` | `src/index.ts` |
| App constants + config | `AppConfig.swift`, `Constants.swift` | `wrangler.toml` |

---

## Key conventions

### Content and copy

Before writing any user-facing text — button labels, empty states, alerts, error messages, notifications, badge descriptions — read `CONTENT_STRATEGY.md`. It defines the voice, terminology rules, capitalisation mechanics, and has reference copy for every screen. Do not skip this step.

Key rules to know without reading the full doc:

- Use `"Streak Shield"` not "freeze token". Use `"Add Plank"` not "manual entry". Use `"Plank"` not "session" or "workout". See §1.3 of `CONTENT_STRATEGY.md` for the full terminology table.
- No `"please"` anywhere in the UI. No exclamation marks in error states.
- **Error alert pattern:** title = what couldn't be done (`"Couldn't sign you in"`), body = what to do next, button = `"OK"` or `"Retry"`.
- **Empty state pattern:** factual heading + warm/actionable one-liner. Never blame the user for the state being empty.
- Capitalisation: primary action buttons are Title Case (`"Save Changes"`), everything else the user reads is sentence case (`"Your streak is waiting."`).

### Adding a new service
1. Define the protocol in `ServiceProtocols.swift`
2. Implement `@Observable @MainActor class MyService: MyServiceProtocol`
3. Add an `EnvironmentKey` + `EnvironmentValues` extension in `EnvironmentKeys.swift`
4. Add a mock implementation in `MockServices.swift` (inside `#if DEBUG`)
5. Instantiate in `PlankChallengeApp.swift` and inject with `.environment(\.myService, myService)`

### Adding a new API model
Add `Decodable` structs to `Services/API/Models/APIModels.swift`. Use camelCase Swift property names — `.convertFromSnakeCase` handles the backend snake_case mapping automatically.

### Adding a backend endpoint
Add to the appropriate file in `backend/src/routes/`. Use `zValidator('json', schema)` or `zValidator('query', schema)` for input validation. Use `success(c, data)` and `errors.*()` helpers from `utils/response.ts` for consistent response shapes.

### Period values for leaderboard endpoints
Both the global and group leaderboard endpoints use the same period values: `"week"`, `"month"`, `"all"`. The iOS `LeaderboardPeriod` enum raw values must match these exactly.

### LSP errors in the editor
The LSP often shows false "Cannot find type" errors in Swift files because it lacks full project context. Ignore these — they are not real compile errors. Trust the actual `xcodebuild` output to determine if the build succeeds.

### One plank per day
The app enforces one plank per day at both the backend (HTTP 409 `PLANK_LIMIT_REACHED`) and the iOS UI (button disabled when `plankService.hasPlankToday`). Do not add any UI affordance that allows submitting more than one plank per day.

---

## Schema mismatch traps

These caused significant debugging time. Read before touching `APIModels.swift` or any backend route response.

- **`AvatarView` has two separate parameters:** `imageName` (local Xcode asset catalog name) and `imageUrl` (remote HTTPS URL loaded via `AsyncImage`). Profile photos are always remote — always pass them to `imageUrl`. Passing a URL string to `imageName` silently renders only the placeholder with no error.

- **Verify the JSON shape before writing a model.** Hit the live API directly with curl before assuming a response is nested. Many backend responses return a flat object — there is no wrapper key. If the backend sends `{ "name": "...", "isMember": true }` at the top level, the iOS model must decode those fields at the top level too, not inside a nested struct.

- **SQLite aggregate functions return `Double`, not `Int`.** `SUM()` and `MAX()` on `duration_seconds` (a SQLite REAL column) produce floating-point values like `11.80199...`. iOS model fields for plank stats must be typed as `Double` — using `Int` causes a `typeMismatch` decode crash.

- **`convertFromSnakeCase` maps key format only — it does not rename keys.** If the backend sends `"entries"` and the Swift property is named `leaderboard`, they will never match regardless of casing. Always verify the exact JSON key name from the backend source or a live API call.

- **Global/following leaderboard response keys:** `entries` (the list) and `currentUserRank` (caller's position). Not `leaderboard`, not `userRank`, not `user_rank`.

---

## Group roles

- Group creator is assigned `role = "owner"` in `group_members` at creation.
- `GET /groups/:id` returns the `role` field **only** for `"owner"` and `"admin"`. Regular members receive `isMember: true` but **no `role` field** in the response — the field is simply absent, not null.
- `isCurrentUserAdmin` on `GroupService` returns `true` for both `"owner"` and `"admin"`.
- Only the owner can delete a group.
- The "promote member to admin" feature is explicitly deferred — do not add UI for it. Only the group creator has admin access for now.

---

## UI patterns

- **Settings and configuration screens must be `.sheet`, not `NavigationLink`.** A `NavigationLink` push triggers `.onDisappear` on the presenting view, which clears service state (e.g. `groupService.currentGroup = nil`) before the destination even renders. Always present settings as a modal sheet.

- **Pre-warm service data in `RootView`.** Any service whose data is needed on the first render of any tab must be fetched in `RootView.onChange(of: authService.state)` when `.authenticated` fires — before `MainTabView` appears. Streak and planks are already pre-warmed there; follow that pattern for any new service.

- **`AppStorage` keys for today's plank** (shared between `PlankTimerView` and `SettingsView`):
  - `todayPlankDate` — String (YYYY-MM-DD), used to detect day rollover
  - `todayPlankCount` — Int, drives `PlankTimerView` state machine transitions
  - `todayPlankTimesJSON` — JSON `[Double]`, array of durations read by `SettingsView`
  - `todayPlankTotalTime` — Double, cumulative duration for today

  When writing code that affects today's plank, update all four keys consistently. For the delete flow, `plankService.todaysPlank` (server-synced) is the authoritative source for the plank ID — not `AppStorage`.

---

## Database tables (D1 / SQLite)

| Table | Purpose |
|---|---|
| `users` | Accounts with denormalised stats (`current_streak`, `longest_streak`, `total_planks`, `total_plank_seconds`, `longest_plank_seconds`, `last_plank_date`, `freeze_tokens`) |
| `plank_sessions` | Individual plank records — soft-deleted via `deleted_at` |
| `badges` | Earned badges per user |
| `groups` | Plank challenge groups (`group_type`: `public`/`private`, `join_mode`: `open`/`request`) |
| `group_members` | Membership rows — `role`: `owner`/`admin`/`member`, `status`: `active`/`banned` |
| `follows` | Social follow graph |
| `notifications` | In-app notification records |
| `devices` | APNs device token registry |
| `join_requests` | Pending group join requests |

Schema file: `backend/src/db/schema.sql`

---

## GitHub repo

`https://github.com/petras-leonardas/plank-challenge.git`
