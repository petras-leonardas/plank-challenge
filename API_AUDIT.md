# API Audit — Plank Challenge

**Generated:** 2026-03-28  
**Backend:** Cloudflare Workers · Hono v4 · TypeScript  
**iOS Client:** SwiftUI · URLSession via `APIClient` actor  
**Base URL (production):** `https://plank-challenge-api.petras-leonardas.workers.dev`

---

## 1. Summary

| Metric | Count |
|---|---|
| Route groups (API namespaces) | 12 |
| Total backend endpoints | 76 |
| iOS service files making API calls | 8 |
| Endpoints called from iOS client | 53 |
| Backend-only endpoints (no iOS caller) | 23 |
| Deprecated endpoints | 1 |
| Duplicate route registrations | 1 |

### Route Groups

| # | Prefix | File | Endpoints |
|---|---|---|---|
| 1 | *(root)* | `backend/src/index.ts` | 2 |
| 2 | `/auth` | `backend/src/routes/auth.ts` | 7 |
| 3 | `/users` | `backend/src/routes/users.ts` | 9 |
| 4 | `/planks` | `backend/src/routes/planks.ts` | 7 |
| 5 | `/streaks` | `backend/src/routes/streaks.ts` | 3 |
| 6 | `/badges` | `backend/src/routes/badges.ts` | 4 |
| 7 | `/leaderboards` | `backend/src/routes/leaderboards.ts` | 5 |
| 8 | `/groups` | `backend/src/routes/groups.ts` | 20 |
| 9 | `/notifications` | `backend/src/routes/notifications.ts` | 7 |
| 10 | `/media` | `backend/src/routes/media.ts` | 6 |
| 11 | `/devices` | `backend/src/routes/devices.ts` | 6 |
| **Total** | | | **76** |

---

## 2. Backend Endpoint Inventory

**Auth column key:**  
- `required` — `authMiddleware` (JWT Bearer token mandatory)  
- `optional` — `optionalAuthMiddleware` (authenticated if token present, anonymous otherwise)  
- `none` — no auth middleware applied  

**Validation column key:**  
- `body` — `zValidator('json', schema)` applied  
- `query` — `zValidator('query', schema)` applied  
- `none` — no Zod validator on this route  

---

### Root (`index.ts`)

| Method | Path | Auth | Validation | Description |
|---|---|---|---|---|
| GET | `/` | none | none | API info (name, version, environment, status) |
| GET | `/health` | none | none | Health check — returns `{ status: "ok" }` |

---

### `/auth` — Authentication (`routes/auth.ts`)

| Method | Path | Auth | Validation | Description |
|---|---|---|---|---|
| POST | `/auth/register` | none | body | Create account with email + password + displayName |
| POST | `/auth/login` | none | body | Sign in with email + password; returns JWT pair |
| POST | `/auth/apple` | none | body | Sign in / register via Sign in with Apple identity token |
| POST | `/auth/google` | none | body | Sign in / register via Google ID token |
| POST | `/auth/refresh` | none | body | Exchange refresh token for a new JWT pair |
| POST | `/auth/logout` | required | body | Revoke refresh token (invalidates session) |
| DELETE | `/auth/account` | required | none | GDPR hard-delete of the authenticated user's account |

---

### `/users` — User Profiles & Social (`routes/users.ts`)

| Method | Path | Auth | Validation | Description |
|---|---|---|---|---|
| GET | `/users/me` | required | none | Fetch the authenticated user's full profile |
| PATCH | `/users/me` | required | body | Update profile fields (displayName, username, location, bio, plankType, timezone) |
| GET | `/users/search` | required | none | Search users by displayName or username (`?q=`, `?limit=`, `?offset=`) |
| GET | `/users/discover` | required | none | Get suggested users to follow (scored by mutual follows, streak similarity, activity) |
| GET | `/users/:id` | optional | none | Fetch a user's public profile; includes follow relationship if authenticated |
| POST | `/users/:id/follow` | required | none | Follow the specified user |
| DELETE | `/users/:id/follow` | required | none | Unfollow the specified user |
| GET | `/users/:id/followers` | optional | none | List users who follow `:id` (paginated) |
| GET | `/users/:id/following` | optional | none | List users that `:id` follows (paginated) |

---

### `/planks` — Plank Sessions (`routes/planks.ts`)

All routes in this group apply `authMiddleware` via `planks.use('*', authMiddleware)`.

| Method | Path | Auth | Validation | Description |
|---|---|---|---|---|
| GET | `/planks/sync` | required | query | Delta/full sync with cursor pagination (`?since=`, `?limit=`, `?cursor=`) |
| GET | `/planks/stats` | required | none | Aggregated plank statistics (overall, by type, this week, this month, streak) |
| GET | `/planks/progress` | required | none | Comprehensive progress data — daily/weekly activity, badges, milestones, next goals |
| GET | `/planks` | required | query | List plank sessions with optional date filtering (`?startDate=`, `?endDate=`, `?limit=`, `?offset=`) |
| POST | `/planks` | required | body | Create a plank session; idempotent via `clientId`; awards badges and updates streak |
| GET | `/planks/:id` | required | none | Fetch a single plank session by server ID |
| DELETE | `/planks/:id` | required | none | Soft-delete a plank session (today's planks only) |

---

### `/streaks` — Streak Management (`routes/streaks.ts`)

All routes apply `authMiddleware` via `streaks.use('*', authMiddleware)`.

| Method | Path | Auth | Validation | Description |
|---|---|---|---|---|
| GET | `/streaks/me` | required | none | Current streak info, freeze token count, today's activity, 30-day recent activity |
| POST | `/streaks/freeze` | required | none | Use a freeze token to protect streak for today |
| GET | `/streaks/history` | required | none | All-time streak stats, milestone progress, monthly breakdown |

---

### `/badges` — Badges (`routes/badges.ts`)

All routes apply `authMiddleware` via `badges.use('*', authMiddleware)`.

| Method | Path | Auth | Validation | Description |
|---|---|---|---|---|
| GET | `/badges` | required | none | List the authenticated user's earned badges, grouped by category |
| GET | `/badges/available` | required | none | All badges with progress towards each; includes next achievable |
| GET | `/badges/user/:userId` | required | none | Another user's earned badges (no progress info) |
| GET | `/badges/:type` | required | none | Detail for a specific badge type including requirement text and current progress |

---

### `/leaderboards` — Leaderboards (`routes/leaderboards.ts`)

| Method | Path | Auth | Validation | Description |
|---|---|---|---|---|
| GET | `/leaderboards/streak` | optional | query | Global leaderboard ranked by streak (`?period=`, `?limit=`, `?offset=`); cached 60 s |
| GET | `/leaderboards/duration` | optional | query | Global leaderboard ranked by longest single plank; cached 60 s |
| GET | `/leaderboards/total-planks` | optional | query | Global leaderboard ranked by total plank count; cached 60 s |
| GET | `/leaderboards/total-time` | optional | query | Global leaderboard ranked by total plank seconds; cached 60 s |
| GET | `/leaderboards/friends` | required | query | Personalised leaderboard of followed users (`?type=`, `?period=`, `?limit=`, `?offset=`); not cached |

---

### `/groups` — Groups (`routes/groups.ts`)

| Method | Path | Auth | Validation | Description |
|---|---|---|---|---|
| POST | `/groups` | required | body | Create a new group; creator automatically becomes admin |
| GET | `/groups` | required | none | List groups the authenticated user is a member of (paginated) |
| GET | `/groups/discover` | required | none | List public groups, optionally filtered by `?q=` search term |
| GET | `/groups/:id` | optional | none | Group detail; includes invite code only for admins |
| PATCH | `/groups/:id` | required | body | Update group (name, description, joinMode) — admin only |
| DELETE | `/groups/:id` | required | none | Soft-delete a group — creator only |
| POST | `/groups/:id/join` | required | none | Join a public open group directly, or submit a join request for `request` mode |
| POST | `/groups/:id/leave` | required | none | Leave a group (creator cannot leave; must delete instead) |
| GET | `/groups/:id/members` | optional | none | List active members; private groups require membership |
| POST | `/groups/:id/members/:userId/promote` | required | none | Promote a member to admin — admin only |
| POST | `/groups/:id/members/:userId/demote` | required | none | Demote an admin to member — admin only (creator cannot be demoted) |
| DELETE | `/groups/:id/members/:userId` | required | none | Remove a member from the group — admin only |
| POST | `/groups/:id/members/:userId/ban` | required | none | Ban a member (sets status to `banned`; excluded from future joins) — admin only |
| POST | `/groups/:id/members/:userId/unban` | required | none | Remove ban record, allowing the user to re-request membership — admin only |
| GET | `/groups/:id/requests` | required | none | List pending join requests — admin only |
| POST | `/groups/:id/requests/:requestId/approve` | required | none | Approve a pending join request — admin only |
| POST | `/groups/:id/requests/:requestId/deny` | required | none | Deny a pending join request — admin only |
| POST | `/groups/join/:inviteCode` | required | none | Join a private group via invite code (bypasses join mode) |
| POST | `/groups/:id/invite-code/regenerate` | required | none | Regenerate the invite code for a private group — admin only |
| GET | `/groups/:id/leaderboard` | optional | none | Group leaderboard by total plank duration; private groups require membership |

---

### `/notifications` — Notifications (`routes/notifications.ts`)

All routes apply `authMiddleware` via `notifications.use('*', authMiddleware)`.

| Method | Path | Auth | Validation | Description |
|---|---|---|---|---|
| GET | `/notifications` | required | query | List notifications (`?unreadOnly=`, `?limit=`, `?offset=`); triggers opportunistic cleanup on first page |
| GET | `/notifications/unread-count` | required | none | Count of unread notifications for badge display |
| GET | `/notifications/:id` | required | none | Fetch a single notification |
| POST | `/notifications/:id/read` | required | none | Mark a single notification as read |
| POST | `/notifications/read-all` | required | none | Mark all notifications as read |
| DELETE | `/notifications/:id` | required | none | Delete a single notification |
| DELETE | `/notifications` | required | query | Delete all notifications, or only read ones (`?readOnly=true`) |

---

### `/media` — Media Upload (`routes/media.ts`)

| Method | Path | Auth | Validation | Description |
|---|---|---|---|---|
| POST | `/media/avatar` | required | none (header-validated) | Upload profile avatar as raw binary body; validates Content-Type + magic bytes |
| DELETE | `/media/avatar` | required | none | Remove the authenticated user's avatar from R2 and clear profile URL |
| GET | `/media/avatar/:userId` | none | none | Serve a user's avatar directly from R2 (public, no auth) |
| POST | `/media/group/:groupId` | required | none (header-validated) | Upload group cover image — admin only |
| DELETE | `/media/group/:groupId` | required | none | Remove group cover image — admin only |
| GET | `/media/group/:groupId` | none | none | Serve a group's cover image directly from R2 (public, no auth) |

---

### `/devices` — Push Notification Devices (`routes/devices.ts`)

All routes apply `authMiddleware` via `devices.use('*', authMiddleware)`.

| Method | Path | Auth | Validation | Description |
|---|---|---|---|---|
| POST | `/devices` | required | body | Register or update a device token for push notifications |
| GET | `/devices` | required | none | List all devices registered for the authenticated user |
| POST | `/devices/ping` | required | body | Update `last_active_at` for a device token |
| POST | `/devices/unregister` | required | body | Unregister a device by token (token in body — preferred method) |
| DELETE | `/devices/all` | required | none | Unregister all devices for the authenticated user |
| DELETE | `/devices/:token` | required | none | **DEPRECATED** — Unregister a device by token in URL path; see Notable Findings |

---

## 3. iOS Client Endpoint Inventory

All calls go through `APIClient.shared` (a Swift `actor`) defined in  
`PlankChallenge/PlankChallenge/Services/API/APIClient.swift`.  
Authentication is handled automatically: Bearer token injected on every call, 401 triggers a silent token refresh via `POST /auth/refresh`.

---

### `AuthService.swift`

| Function | Method | Endpoint |
|---|---|---|
| `restoreSession()` | GET | `/users/me` |
| `signInWithApple(credential:)` | POST | `/auth/apple` |
| `signInWithGoogle(presenting:)` | POST | `/auth/google` |
| `signInWithEmail(email:password:)` | POST | `/auth/login` |
| `signUpWithEmail(email:password:displayName:)` | POST | `/auth/register` |
| `signOut()` | POST | `/auth/logout` |
| `deleteAccount()` | DELETE | `/auth/account` |
| *(token refresh — internal to `APIClient`)* | POST | `/auth/refresh` |

---

### `PlankService.swift`

| Function | Method | Endpoint |
|---|---|---|
| `fetchPlanks(refresh:)` | GET | `/planks/sync` |
| `createPlank(durationSeconds:inputMethod:)` | POST | `/planks` |
| `deletePlank(_:)` | DELETE | `/planks/:id` |
| `fetchStats()` | GET | `/planks/stats` |
| `fetchProgress()` | GET | `/planks/progress` |
| `fetchPlank(_:)` | GET | `/planks/:id` |
| `listPlanks(limit:offset:startDate:endDate:)` | GET | `/planks` |

---

### `UserService.swift`

| Function | Method | Endpoint |
|---|---|---|
| `fetchProfile()` | GET | `/users/me` |
| `updateProfile(...)` | PATCH | `/users/me` |
| `searchUsers(query:)` | GET | `/users/search` |
| `fetchSuggestedUsers()` | GET | `/users/discover` |
| `fetchUserProfile(id:)` | GET | `/users/:id` |
| `followUser(id:)` | POST | `/users/:id/follow` |
| `unfollowUser(id:)` | DELETE | `/users/:id/follow` |
| `fetchFollowers(for:)` | GET | `/users/:id/followers` |
| `fetchFollowing(for:)` | GET | `/users/:id/following` |

---

### `BadgeService.swift`

| Function | Method | Endpoint |
|---|---|---|
| `fetchBadges()` | GET | `/badges` |
| `fetchAvailableBadges()` | GET | `/badges/available` |
| `fetchBadgeDetail(_:)` | GET | `/badges/:type` |
| `fetchUserBadges(_:)` | GET | `/badges/user/:userId` |

---

### `StreakService.swift`

| Function | Method | Endpoint |
|---|---|---|
| `fetchStreak()` | GET | `/streaks/me` |
| `useFreeze()` | POST | `/streaks/freeze` |
| `fetchHistory()` | GET | `/streaks/history` |

---

### `GroupService.swift`

| Function | Method | Endpoint |
|---|---|---|
| `fetchMyGroups()` | GET | `/groups` |
| `fetchDiscoverGroups()` | GET | `/groups/discover` |
| `fetchGroup(id:)` | GET | `/groups/:id` |
| `fetchGroupMembers(groupId:)` | GET | `/groups/:id/members` |
| `joinGroup(id:)` | POST | `/groups/:id/join` |
| `leaveGroup(id:)` | POST | `/groups/:id/leave` |
| `createGroup(name:description:groupType:joinMode:)` | POST | `/groups` |

---

### `LeaderboardService.swift`

| Function | Method | Endpoint |
|---|---|---|
| `fetchGlobalLeaderboard(type:period:limit:)` | GET | `/leaderboards/:type` (streak, duration, total-time, total-planks) |
| `fetchFollowingLeaderboard(type:period:)` | GET | `/leaderboards/friends` |
| `fetchGroupLeaderboard(groupId:type:period:)` | GET | `/groups/:id/leaderboard` |

---

### `MediaService.swift`

| Function | Method | Endpoint |
|---|---|---|
| `uploadAvatar(image:)` | POST | `/media/avatar` |
| `deleteAvatar()` | DELETE | `/media/avatar` |

---

## 4. Backend ↔ iOS Parity Matrix

### Called from iOS — Confirmed Present in Backend

| Endpoint | iOS Service |
|---|---|
| GET `/` | — |
| GET `/health` | — |
| POST `/auth/register` | `AuthService` |
| POST `/auth/login` | `AuthService` |
| POST `/auth/apple` | `AuthService` |
| POST `/auth/google` | `AuthService` |
| POST `/auth/refresh` | `APIClient` (internal) |
| POST `/auth/logout` | `AuthService` |
| DELETE `/auth/account` | `AuthService` |
| GET `/users/me` | `AuthService`, `UserService` |
| PATCH `/users/me` | `UserService` |
| GET `/users/search` | `UserService` |
| GET `/users/discover` | `UserService` |
| GET `/users/:id` | `UserService` |
| POST `/users/:id/follow` | `UserService` |
| DELETE `/users/:id/follow` | `UserService` |
| GET `/users/:id/followers` | `UserService` |
| GET `/users/:id/following` | `UserService` |
| GET `/planks/sync` | `PlankService` |
| GET `/planks/stats` | `PlankService` |
| GET `/planks/progress` | `PlankService` |
| GET `/planks` | `PlankService` |
| POST `/planks` | `PlankService` |
| GET `/planks/:id` | `PlankService` |
| DELETE `/planks/:id` | `PlankService` |
| GET `/streaks/me` | `StreakService` |
| POST `/streaks/freeze` | `StreakService` |
| GET `/streaks/history` | `StreakService` |
| GET `/badges` | `BadgeService` |
| GET `/badges/available` | `BadgeService` |
| GET `/badges/user/:userId` | `BadgeService` |
| GET `/badges/:type` | `BadgeService` |
| GET `/leaderboards/streak` | `LeaderboardService` |
| GET `/leaderboards/duration` | `LeaderboardService` |
| GET `/leaderboards/total-planks` | `LeaderboardService` |
| GET `/leaderboards/total-time` | `LeaderboardService` |
| GET `/leaderboards/friends` | `LeaderboardService` |
| POST `/groups` | `GroupService` |
| GET `/groups` | `GroupService` |
| GET `/groups/discover` | `GroupService` |
| GET `/groups/:id` | `GroupService` |
| POST `/groups/:id/join` | `GroupService` |
| POST `/groups/:id/leave` | `GroupService` |
| GET `/groups/:id/members` | `GroupService` |
| GET `/groups/:id/leaderboard` | `LeaderboardService` |
| POST `/media/avatar` | `MediaService` |
| DELETE `/media/avatar` | `MediaService` |

**Total: 48 endpoints confirmed called from iOS (+ `/auth/refresh` internally = 49)**

---

### Backend-Only — No iOS Caller Found

These endpoints exist in the backend but are not called by any iOS service file. They may be called by future clients, admin tooling, or are not yet wired up in the iOS app.

| Endpoint | Notes |
|---|---|
| GET `/` | Root info endpoint — informational, not needed by app |
| GET `/health` | Health check — for monitoring infrastructure, not app |
| PATCH `/groups/:id` | Group update (name/description/joinMode) — no iOS call found |
| DELETE `/groups/:id` | Delete group — no iOS call found |
| POST `/groups/:id/members/:userId/promote` | Admin promote — no iOS call found |
| POST `/groups/:id/members/:userId/demote` | Admin demote — no iOS call found |
| DELETE `/groups/:id/members/:userId` | Remove member — no iOS call found |
| POST `/groups/:id/members/:userId/ban` | Ban member — no iOS call found |
| POST `/groups/:id/members/:userId/unban` | Unban member — no iOS call found |
| GET `/groups/:id/requests` | List join requests — no iOS call found |
| POST `/groups/:id/requests/:requestId/approve` | Approve join request — no iOS call found |
| POST `/groups/:id/requests/:requestId/deny` | Deny join request — no iOS call found |
| POST `/groups/join/:inviteCode` | Join via invite code — no iOS call found |
| POST `/groups/:id/invite-code/regenerate` | Regenerate invite code — no iOS call found |
| GET `/notifications` | Notifications list — no iOS service call found |
| GET `/notifications/unread-count` | Unread badge count — no iOS service call found |
| GET `/notifications/:id` | Single notification — no iOS service call found |
| POST `/notifications/:id/read` | Mark read — no iOS service call found |
| POST `/notifications/read-all` | Mark all read — no iOS service call found |
| DELETE `/notifications/:id` | Delete notification — no iOS service call found |
| DELETE `/notifications` | Bulk delete notifications — no iOS service call found |
| POST `/devices` | Register device token — no iOS call found |
| GET `/devices` | List devices — no iOS call found |
| POST `/devices/ping` | Ping device — no iOS call found |
| POST `/devices/unregister` | Unregister device (preferred) — no iOS call found |
| DELETE `/devices/all` | Unregister all devices — no iOS call found |
| DELETE `/devices/:token` | **DEPRECATED** — no iOS call found |
| GET `/media/avatar/:userId` | Serve avatar from R2 — iOS uses direct R2 CDN URL instead |
| GET `/media/group/:groupId` | Serve group image from R2 — iOS uses direct R2 CDN URL instead |
| POST `/media/group/:groupId` | Upload group image — no iOS call found |
| DELETE `/media/group/:groupId` | Delete group image — no iOS call found |

---

## 5. Notable Findings

The items below are factual observations identified during the audit. No recommendations are included.

---

### F-1: Duplicate Route Registration — `DELETE /devices/:token`

**File:** `backend/src/routes/devices.ts`  
**Lines:** 383 and 434

`DELETE /devices/:token` is registered **twice** in the same file. Both handlers contain identical logic. In Hono, the first matching handler executes; the second registration is unreachable dead code.

---

### F-2: Deprecated Endpoint — `DELETE /devices/:token`

**File:** `backend/src/routes/devices.ts` · Line 383  
**Sunset date set in response header:** `Sat, 01 Jun 2026`

This endpoint is explicitly marked `@deprecated` in its JSDoc. The handler emits three deprecation headers on every response:
- `Deprecation: true`
- `Sunset: Sat, 01 Jun 2026 00:00:00 GMT`
- `Link: </devices/unregister>; rel="successor-version"`

The preferred replacement is `POST /devices/unregister` (token in request body, not URL).

---

### F-3: Token Refresh Called Internally — Not via a Service

**File:** `PlankChallenge/PlankChallenge/Services/API/APIClient.swift` · Lines 280–339

`POST /auth/refresh` is invoked inside `APIClient.refreshAccessToken()` — not through any named service. It is called automatically in two scenarios:
1. Before a request, when `KeychainService` detects the access token has expired.
2. After a `401` response, to attempt one transparent retry.

This means the endpoint does not appear in any of the eight service files but is in active use.

---

### F-4: Public (No-Auth) Media Serve Endpoints

**File:** `backend/src/routes/media.ts` · Lines 183, 376

`GET /media/avatar/:userId` and `GET /media/group/:groupId` have **no auth middleware** and are fully public. They stream binary image data directly from R2 storage. The iOS app does not call these endpoints — it uses the direct R2 CDN URL stored in the user/group `profileImageUrl` / `imageUrl` field instead.

---

### F-5: Optional Auth on Several Public-Facing Endpoints

The following endpoints use `optionalAuthMiddleware`. They respond to unauthenticated requests but include additional relationship context (e.g. `isFollowing`, `isMember`) when a valid token is provided:

| Endpoint | Extra data when authenticated |
|---|---|
| GET `/users/:id` | `isFollowing`, `isFollowingYou` |
| GET `/users/:id/followers` | — |
| GET `/users/:id/following` | — |
| GET `/groups/:id` | `isMember`, `role`, `pendingRequest` |
| GET `/groups/:id/members` | Required if group is private |
| GET `/groups/:id/leaderboard` | Required if group is private |
| GET `/leaderboards/streak` | `isCurrentUser` flag, `currentUserRank` |
| GET `/leaderboards/duration` | `isCurrentUser` flag, `currentUserRank` |
| GET `/leaderboards/total-planks` | `isCurrentUser` flag, `currentUserRank` |
| GET `/leaderboards/total-time` | `isCurrentUser` flag, `currentUserRank` |

---

### F-6: Entire Notifications and Devices APIs Have No iOS Callers

All 7 notification endpoints and all 6 device endpoints (11 unique, excluding the deprecated duplicate) have no corresponding calls in any iOS service file in the current codebase. These APIs are fully implemented on the backend but not yet integrated into the iOS app.

---

### F-7: Several Group Admin Endpoints Have No iOS Callers

14 group endpoints (update, delete, promote, demote, remove member, ban, unban, list requests, approve/deny request, join via invite code, regenerate invite code, and group image upload/delete) are fully implemented in the backend but have no iOS service calls. This covers most of the group administration surface area.

---

*End of audit.*
