# Auth Flow — QA Test Cases

Last updated: March 2026  
Covers: Sign In with Apple, Sign In with Google, Sign Out, Delete Account, Session Persistence, Edge Cases, App Store Compliance

---

## How to Use This Document

Work through each section in order. Mark each test as:
- ✅ Pass
- ❌ Fail — note what happened
- ⏭ Skipped — note why

**Recommended test order:** 2.1 → 2.2 → 1.1 → 1.2 → 5.2 → 3.1 → 3.3 → 4.1 → 4.3 → 6.1

---

## 1. Sign In with Apple

| # | Scenario | Steps | Expected Result | Status |
|---|----------|-------|-----------------|--------|
| 1.1 | New user, first time | Tap "Sign in with Apple" → authenticate → allow name and email | Account created, lands in app, display name from Apple profile | |
| 1.2 | Returning user | Tap "Sign in with Apple" → authenticate (no name prompt this time) | Lands in app with existing account data intact | |
| 1.3 | Cancel mid-flow | Tap "Sign in with Apple" → cancel on Apple sheet | Returns to sign-in screen, no error shown, no loading spinner stuck | |
| 1.4 | Uses private relay email | Sign in with Apple using "Hide My Email" option | Account created with relay email, works normally | |
| 1.5 | Same email as existing Google account | Sign in with Apple using same email as a Google account | Accounts linked automatically, lands in app | |

---

## 2. Sign In with Google

| # | Scenario | Steps | Expected Result | Status |
|---|----------|-------|-----------------|--------|
| 2.1 | New user, first time | Tap "Continue with Google" → select account → Allow | Account created, lands in app, display name from Google profile | |
| 2.2 | Returning user | Tap "Continue with Google" → select same account | Lands in app with existing account data intact | |
| 2.3 | Cancel mid-flow | Tap "Continue with Google" → dismiss Google sheet without selecting account | Returns to sign-in screen, no error shown, no loading spinner stuck | |
| 2.4 | Select a different Google account | Tap "Continue with Google" → select a different Google account than before | New separate account created for that Google identity | |
| 2.5 | Same email as existing Apple account | Sign in with Google using same email as an Apple account | Accounts linked automatically (email must be verified), lands in app | |

---

## 3. Sign Out

| # | Scenario | Steps | Expected Result | Status |
|---|----------|-------|-----------------|--------|
| 3.1 | Normal sign out | Profile tab → gear icon → Settings → Sign Out → confirm | Returns to sign-in screen, all user data cleared from view | |
| 3.2 | Cancel sign out | Profile tab → gear icon → Settings → Sign Out → tap Cancel | Stays in Settings, account remains active | |
| 3.3 | Sign out then sign back in | Sign out → sign in with same Google or Apple account | Lands in app with all previous data (streaks, planks, badges) still intact | |
| 3.4 | Sign out clears UI state | Sign out after viewing profile and progress data | Sign-in screen shown, no previous user's data visible anywhere in the app | |

---

## 4. Delete Account

| # | Scenario | Steps | Expected Result | Status |
|---|----------|-------|-----------------|--------|
| 4.1 | Normal deletion | Profile tab → gear icon → Settings → Delete Account → confirm | Account deleted, returns to sign-in screen | |
| 4.2 | Cancel deletion | Profile tab → gear icon → Settings → Delete Account → tap Cancel | Stays in Settings, account still active, all data intact | |
| 4.3 | Try to sign back in after deletion | Delete account → sign in with same Google or Apple account | New empty account created — previous data is gone permanently | |
| 4.4 | Deletion removes all data | Delete account → check Cloudflare D1 dashboard | No rows in users, plank_sessions, streaks, badges for that user ID | |
| 4.5 | Deletion is clearly separated from sign out | Open Settings and observe layout | Delete Account and Sign Out are in separate sections with clear visual distinction. Both require confirmation. | |

---

## 5. Session Persistence

| # | Scenario | Steps | Expected Result | Status |
|---|----------|-------|-----------------|--------|
| 5.1 | App backgrounded and resumed | Sign in → press Home button → return to app after 5 minutes | Still signed in, no re-auth required | |
| 5.2 | App fully killed and relaunched | Sign in → swipe app away in app switcher → reopen app | Still signed in, lands directly in app — no sign-in screen | |
| 5.3 | App relaunched after long gap | Sign in → do not open app for several hours → reopen | Still signed in (tokens valid for 1 hour access, 30 days refresh) | |
| 5.4 | First launch, no session | Fresh install with no previous sign-in | Sign-in screen shown immediately | |
| 5.5 | Relaunch with no network | Sign in → turn on Airplane Mode → kill app → reopen | Still lands in app (session restored from Keychain without network call) | |

---

## 6. Edge Cases and Error States

| # | Scenario | Steps | Expected Result | Status |
|---|----------|-------|-----------------|--------|
| 6.1 | No network during sign-in | Turn on Airplane Mode → try Sign in with Apple | Clear error message shown, not a blank or stuck screen | |
| 6.2 | No network during sign-out | Turn on Airplane Mode → Sign Out | Still signs out locally, returns to sign-in screen (backend call fails silently, this is expected) | |
| 6.3 | No network during account deletion | Turn on Airplane Mode → Delete Account | Error message shown, account NOT deleted, user stays signed in | |
| 6.4 | Buttons disabled during loading | Tap Google → while loading, attempt to tap Apple button | Apple button is disabled while Google sign-in is in progress | |
| 6.5 | Rapid sign-out then sign-in | Sign out → immediately sign back in | Clean transition both ways, no race condition or stuck state | |

---

## 7. App Store Compliance

These must all pass before submitting to the App Store.

| # | Requirement | Guideline | How to Verify | Status |
|---|-------------|-----------|---------------|--------|
| 7.1 | Sign in with Apple is present | 4.8 | Sign-in screen shows "Sign in with Apple" button | |
| 7.2 | In-app account deletion is available | 5.1.1 | Settings → "Delete Account" button is present and functional | |
| 7.3 | Account deletion is permanent | 5.1.1 | After deletion, sign in with same account → new empty account, no old data | |
| 7.4 | No email-only sign-up without Apple option | 4.8 | Sign-in screen does not show an email sign-up path | |

---

## Notes

**Checking the database (test 4.4):**
Go to [dash.cloudflare.com](https://dash.cloudflare.com) → Workers & Pages → D1 → plank-challenge-db → run:
```sql
SELECT * FROM users WHERE email = 'your-email@example.com';
```
Should return no rows after account deletion.

**Test environment:**
- Device: iPhone 17 Pro (LeoDesignsTheWorld)
- iOS: 26.3.1
- Backend: https://plank-challenge-api.petras-leonardas.workers.dev
- App build: Debug (USB or wireless via devicectl)
