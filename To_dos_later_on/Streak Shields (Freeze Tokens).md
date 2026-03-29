# Streak Shields (Freeze Tokens)

## Status: Hidden from UI — fully implemented in backend and service layer

The Streak Shields feature is **complete and working** end-to-end. It was hidden from the UI on 29 March 2026 to reduce app complexity at launch. Nothing was deleted. Re-enabling it is a UI-only change.

---

## What it does

A user gets 2 Streak Shields when they sign up. If they miss a day of planking and their streak is at risk, a shield automatically activates to cover the missed day — their streak survives. Shields are a softer alternative to simply breaking the streak and are meant to reduce anxiety around daily consistency.

### User-facing rules
- Users start with **2 shields**
- A shield is consumed automatically when the streak would otherwise break (enforced at the `POST /streaks/freeze` endpoint, which the app would need to call when the streak-at-risk condition is detected)
- Only **one shield can be used per day** (`last_freeze_date` idempotency guard)
- A shield can only be used when `current_streak > 0` (no point protecting a streak of 0)
- The DB schema allows up to 10 tokens (`CHECK freeze_tokens <= 10`), but iOS was hardcoded to display a max of 2 (`Constants.Streak.maxFreezeTokens = 2`)
- There is an un-wired constant `streakForBonusToken = 20` (earn a bonus shield at a 20-day streak) — this was planned but never wired to any award trigger

---

## Where everything lives

### Database (`backend/src/db/schema.sql`)

```sql
freeze_tokens   INTEGER DEFAULT 2 CHECK (freeze_tokens >= 0 AND freeze_tokens <= 10)
last_freeze_date TEXT   -- YYYY-MM-DD; enforces one freeze per calendar day
```

Both columns sit directly on the `users` table. No separate table exists.

---

### Backend — Core logic (`backend/src/utils/streak.ts`)

| Function | Lines | Description |
|---|---|---|
| `useFreezeTokenAndProtectStreak()` | ~503–581 | **Primary production path.** Atomically decrements `freeze_tokens`, sets `last_plank_date = today`, and `last_freeze_date = today` in a single `UPDATE`. Guards against double-use with `AND (last_freeze_date IS NULL OR last_freeze_date != ?)`. |
| `useFreezeTokenAtomic()` | ~419–491 | Lower-level atomic decrement with `WHERE freeze_tokens > 0 AND current_streak > 0` guard. |
| `awardFreezeToken()` | ~587–613 | Cap-bounded increment (`freeze_tokens + 1` up to `maxTokens`). Ready to use — just needs to be called from a reward trigger (e.g. streak milestone). |
| `StreakInfo` interface | ~11–17 | `freezeTokens` is a member of this struct returned from streak calculations. |

---

### Backend — Routes

| File | Endpoint | What it does |
|---|---|---|
| `backend/src/routes/streaks.ts` | `GET /streaks/me` | Returns `freezeTokens`, `lastFreezeDate`, `usedFreezeToday`, `streakProtectedToday`, `isStreakAtRisk` |
| `backend/src/routes/streaks.ts` | `POST /streaks/freeze` | Validates streak-at-risk, checks token balance, calls `useFreezeTokenAndProtectStreak()`. Returns `freezeTokensRemaining`, `streakProtected`, `freezeUsedToday`. |
| `backend/src/routes/planks.ts` | `GET /planks/stats` | Includes `freezeTokens` in the `streak` sub-object |
| `backend/src/routes/planks.ts` | `GET /planks/progress` | Includes `freezeTokens` in `summary.freezeTokens` |
| `backend/src/routes/users.ts` | `GET /users/me` | `formatUser()` maps `freeze_tokens` into the full user profile response |

---

### iOS — API models (`PlankChallenge/Services/API/Models/APIModels.swift`)

| Struct | Field(s) | Description |
|---|---|---|
| `APIUser` | `freezeTokens: Int` | Carried in every user profile response |
| `PlankStatsResponse.StreakStats` | `freezeTokens: Int` | Embedded in plank stats endpoint |
| `StreakMeResponse` | `freezeTokens`, `lastFreezeDate`, `usedFreezeToday`, `streakProtectedToday`, `TodayActivity.usedFreeze` | Full streak response model |
| `UseFreezeResponse` | `freezeTokensRemaining`, `streakProtected`, `freezeUsedToday` | Response model for `POST /streaks/freeze` — whole struct is freeze-specific |
| `ProgressResponse.ProgressSummary` | `freezeTokens: Int` | Embedded in progress response |
| `APINotificationType` | `.freezeReminder` | `"freeze_reminder"` notification type case |

---

### iOS — Service layer

| File | What it does |
|---|---|
| `Services/ServiceProtocols.swift` | `StreakServiceProtocol` requires `freezeTokens: Int`, `usedFreezeToday: Bool`, `streakProtectedToday: Bool`, and `useFreeze() async throws -> UseFreezeResponse` |
| `Services/StreakService.swift` | Implements the above; `useFreeze()` POSTs to `/streaks/freeze` then refreshes state via `fetchStreak()`. Three error enum cases: `noFreezeTokens`, `alreadyUsedFreezeToday`, `streakNotAtRisk`. |
| `Services/MockServices.swift` | `MockStreakService` defaults: `freezeTokens = 2`, `usedFreezeToday = false`, `streakProtectedToday = false`. `useFreeze()` is a `fatalError` stub. |
| `UserProfile.swift` | Local `UserProfile` struct carries `freezeTokens`, initialised to `Constants.Streak.initialFreezeTokens` |
| `NotificationService.swift` | `sendStreakFreezeNotification(tokensRemaining:)` — fires a local push "Streak Saved!" after a freeze is used |
| `Services/InAppNotificationService.swift` | Maps `"streak_at_risk"`, `"streak_broken"`, `"freeze_reminder"` backend notification types to the `.streakFreezeUsed` in-app display type |
| `AppNotification.swift` | `NotificationType.streakFreezeUsed` and `.tokenEarned` enum cases with snowflake SF Symbol icons |

---

### iOS — Constants (`Constants.swift`)

```swift
Constants.Streak.maxFreezeTokens     = 2   // max displayed in UI
Constants.Streak.initialFreezeTokens = 2   // default on signup
Constants.Streak.streakForBonusToken = 20  // earn a bonus shield at this streak (un-wired)
```

---

### iOS — UI (hidden)

| File | What was there |
|---|---|
| `ProfileView.swift` | `streakTokensSection` — a card showing N filled/empty snowflake circles (teal/grey) and "X of 2 shields left". Reads `streakService.freezeTokens`. **Removed from view body.** |
| `Views/Onboarding/OnboardingHowItWorksView.swift` | Step 3: `shield.fill` icon, copy "Miss a day? No panic — Streak shields automatically cover missed days. You start with two." **Removed.** |
| `Views/Onboarding/OnboardingWelcomeView.swift` | Value prop row: "Miss a day, use a shield. Your streak survives." **Removed.** |

---

## How to re-enable

1. In `ProfileView.swift`, add `streakTokensSection` back into the `body`'s `VStack` between `statsSection` and `badgesSection`. The computed property (`streakTokensSection`) is still in the file — just uncomment or re-insert the call site.
2. Restore the How It Works onboarding step and Welcome value prop row (copy is preserved in `CONTENT_STRATEGY.md`).
3. Optionally wire `awardFreezeToken()` to a streak milestone (e.g. every 20-day streak awards a bonus shield) — the function exists but was never called.

---

## How to fully remove (if decided)

This is **irreversible on production data** once the D1 column drop runs. Only do this if shields are permanently abandoned.

1. **Backend:** Delete `POST /streaks/freeze` route. Delete `useFreezeTokenAtomic`, `useFreezeTokenAndProtectStreak`, `awardFreezeToken` from `streak.ts`. Remove `freeze_tokens` from every SELECT in `streaks.ts`, `planks.ts`, `users.ts`. Remove from all response objects. Run: `ALTER TABLE users DROP COLUMN freeze_tokens; ALTER TABLE users DROP COLUMN last_freeze_date;`
2. **iOS API models:** Remove `freezeTokens` from `APIUser`, `PlankStatsResponse.StreakStats`, `StreakMeResponse` (plus all freeze sub-fields), `UseFreezeResponse` (whole struct), `ProgressResponse.ProgressSummary`. Remove `APINotificationType.freezeReminder`.
3. **iOS service layer:** Remove the four protocol requirements, computed properties, `useFreeze()`, and the three error cases from `StreakService`, `StreakServiceProtocol`, and `MockStreakService`. Remove `freezeTokens` from `UserProfile`.
4. **iOS constants:** Remove `maxFreezeTokens`, `initialFreezeTokens`, `streakForBonusToken`.
5. **iOS notifications:** Delete `sendStreakFreezeNotification`. Clean up `AppNotification.NotificationType` and `InAppNotificationService` routing.
