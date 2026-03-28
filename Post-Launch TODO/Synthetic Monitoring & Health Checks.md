# Post-Launch TODO: Synthetic Monitoring & Health Checks

## What This Is

Once real users are on the app, you need automated tests running against your **live production API** on a schedule — before your users discover problems themselves. This is called **synthetic monitoring**: scripted fake requests that simulate real user behaviour and alert you immediately if something breaks.

This is not a priority before launch. Set this up within the first few weeks after going live with real users.

---

## Phase 1 — Do This at Launch (20 minutes)

### Add a `/health` endpoint to the backend

This is the foundation of everything else. Every monitoring tool in the world knows how to ping a `/health` endpoint.

Add to `backend/src/routes/` a new `health.ts` route:

```typescript
// backend/src/routes/health.ts
import { Hono } from 'hono'

const health = new Hono()

health.get('/', async (c) => {
    const checks: Record<string, 'ok' | 'error'> = {}
    const start = Date.now()

    // Check D1 database connectivity
    try {
        await c.env.DB.prepare('SELECT 1').run()
        checks.database = 'ok'
    } catch {
        checks.database = 'error'
    }

    // Check KV connectivity
    try {
        await c.env.CACHE.put('health_check', 'ok', { expirationTtl: 60 })
        checks.kv = 'ok'
    } catch {
        checks.kv = 'error'
    }

    const allHealthy = Object.values(checks).every(v => v === 'ok')
    const responseTimeMs = Date.now() - start

    return c.json({
        status: allHealthy ? 'healthy' : 'degraded',
        checks,
        responseTimeMs,
        timestamp: new Date().toISOString(),
        version: c.env.APP_VERSION ?? 'unknown',
    }, allHealthy ? 200 : 503)
})

export default health
```

Register it in `backend/src/index.ts`:
```typescript
import health from './routes/health'
app.route('/health', health)
```

Then set up a **free uptime monitor** at [UptimeRobot.com](https://uptimerobot.com) pointing at `https://your-api-domain.com/health`. It will ping it every 5 minutes and email you if it goes down. Free tier is sufficient.

---

## Phase 2 — Set Up Synthetic Tests (First Few Weeks Post-Launch)

### The Concept

A Cloudflare Workers **Cron Trigger** runs a Worker on a schedule (e.g. every night at 3am UTC). That Worker impersonates a dedicated test account and walks through real API flows — the same way a real user would. If any step fails or is too slow, it sends you an alert.

Add to `wrangler.toml`:

```toml
[triggers]
crons = ["0 3 * * *"]  # 3am UTC every night
```

The Worker's `scheduled` handler runs your test suite.

### The Test Account

Create a dedicated test account in your production database. Use an email like `synthetic-test@plankchallenge.app`. This account:
- Never appears on leaderboards (add a flag: `isSyntheticTest: true` to the users table and filter it out of all leaderboard queries)
- Has its plank data cleaned up after every test run
- Has its credentials stored as a Cloudflare Worker secret (`wrangler secret put SYNTHETIC_TEST_PASSWORD`)

---

## The Tests to Implement

Below are the specific synthetic tests that make sense for Plank Challenge, in priority order.

---

### Test 1 — Authentication Flow (Critical)

**What it tests**: users can sign in and receive valid tokens.

**Why it matters**: if auth is broken, nobody can use the app at all. This is a total outage.

**Steps**:
1. `POST /auth/login` with test account credentials
2. Assert: response is 200, access token is present, refresh token is present
3. `GET /users/me` using the returned access token
4. Assert: response is 200, user ID matches the test account
5. `POST /auth/refresh` using the refresh token
6. Assert: new access token is returned

**Alert threshold**: any step fails, or total time > 3 seconds.

---

### Test 2 — Core Plank Flow (Critical)

**What it tests**: the single most important user action — logging a plank and getting a streak update.

**Why it matters**: this is the entire product. If this breaks, the app is broken.

**Steps**:
1. Sign in as the test account (reuse token from Test 1)
2. `GET /streaks/me` — record the current streak value
3. `POST /planks` with a valid plank payload (30 seconds, elbow, timer input, today's date, a fresh UUID as `clientId`)
4. Assert: response is 200, `plank.id` is present, `streakInfo` is present
5. `GET /streaks/me` again
6. Assert: streak data is returned and plank was recorded
7. `DELETE /planks/:id` using the plank ID from step 3 — clean up
8. Assert: delete returns 200 or 204

**Alert threshold**: any step fails, or total time > 5 seconds.

---

### Test 3 — Plank Idempotency (Critical)

**What it tests**: submitting the same plank twice (same `clientId`) does not create a duplicate.

**Why it matters**: the offline queue can retry failed submissions. If deduplication is broken, users accumulate phantom planks and their stats are inflated.

**Steps**:
1. Sign in as test account
2. Generate a single UUID as `clientId`
3. `POST /planks` — first submission
4. Assert: 200, plank created
5. `POST /planks` — exact same payload and `clientId`
6. Assert: 200 (or 409 — either is acceptable), but only ONE plank exists for this `clientId`
7. `GET /planks` — verify no duplicates with this `clientId`
8. Clean up: `DELETE /planks/:id`

**Alert threshold**: duplicate plank is created (this would be a P0 data integrity failure).

---

### Test 4 — Streak Freeze Token Logic (High)

**What it tests**: if a user has freeze tokens and misses a day, their streak is preserved.

**Why it matters**: streak protection is a key retention feature. If it malfunctions, users lose streaks they shouldn't — and churn.

**Note**: this test is harder to automate because it requires simulating a missed day. Consider testing the backend logic unit-tested rather than via a synthetic test. Alternatively, test it by calling a backdated plank endpoint if the API supports it, or by directly querying the test account's streak data after a known missed day.

**Simplified version** (can be automated):
1. Sign in as test account
2. `GET /streaks/me`
3. Assert: `freezeTokens` field is present and is a number between 0 and 2
4. Assert: `lastPlankDate` field is present and is a valid ISO date

---

### Test 5 — Leaderboard Availability (High)

**What it tests**: leaderboard data is returned within acceptable time.

**Why it matters**: leaderboards involve aggregation queries across the whole users table. As the user base grows, these can become slow. A synthetic test catches degradation early.

**Steps**:
1. Sign in as test account
2. `GET /leaderboards?type=streak&period=all_time`
3. Assert: response is 200, `entries` array is present
4. `GET /leaderboards?type=streak&period=weekly`
5. Assert: response is 200
6. `GET /leaderboards?type=total-time&period=monthly`
7. Assert: response is 200

**Alert threshold**: any request takes > 2 seconds. Leaderboard latency is a leading indicator of database performance problems.

---

### Test 6 — Groups Feature (Medium)

**What it tests**: group creation, discovery, and membership work end to end.

**Steps**:
1. Sign in as test account
2. `POST /groups` — create a test group named `"Synthetic Test Group - DELETE ME"`
3. Assert: group ID is returned
4. `GET /groups/:id` — fetch the group
5. Assert: group details match what was created
6. `GET /groups?discover=true` — check discovery endpoint
7. Assert: the new group appears in results
8. `DELETE /groups/:id` (or leave group if delete is admin-only) — clean up

---

### Test 7 — Media Upload (Medium)

**What it tests**: profile photo upload pipeline (iOS → backend → R2) is functional.

**Why it matters**: R2 outages or misconfigured CORS on the R2 bucket will break photo uploads silently — users just stop being able to update their avatar with no clear error.

**Steps**:
1. Sign in as test account
2. `POST /media/upload` with a minimal valid JPEG payload (a 1×1 pixel JPEG, base64 encoded — hard-code this in the test)
3. Assert: response is 200, a URL is returned
4. `GET <returned URL>` — verify the file is actually accessible
5. Assert: response is 200, `Content-Type` is `image/jpeg`
6. Clean up: delete the uploaded file from R2 (via a `DELETE /media/:key` endpoint, or directly via R2 API in the Worker)

---

### Test 8 — Token Refresh (High)

**What it tests**: expired access tokens are correctly refreshed.

**Why it matters**: if token refresh breaks, every user gets silently logged out the next time their token expires (~15–60 minutes). This is a silent outage — the app appears to work until the first network call fails.

**Steps**:
1. Sign in as test account, obtain access token and refresh token
2. Intentionally use an **expired** access token (either wait for it to expire, or construct a JWT with a past expiry using the test signing key)
3. `GET /users/me` with the expired token
4. Assert: response is 401
5. `POST /auth/refresh` with the refresh token
6. Assert: new access token returned
7. `GET /users/me` with the new token
8. Assert: response is 200

---

## Alerting Setup

When a synthetic test fails, you need to know immediately. Set up alerts via:

**Option A — Cloudflare Workers + email (simplest)**:
```typescript
// In the synthetic test Worker, on any failure:
await fetch('https://api.sendgrid.com/v3/mail/send', {
    method: 'POST',
    headers: { Authorization: `Bearer ${env.SENDGRID_API_KEY}` },
    body: JSON.stringify({
        to: [{ email: 'you@yourdomain.com' }],
        from: { email: 'alerts@plankchallenge.app' },
        subject: `[ALERT] Synthetic test failed: ${failedTestName}`,
        content: [{ type: 'text/plain', value: errorDetails }]
    })
})
```

**Option B — Slack webhook (recommended once you have a team)**:
```typescript
await fetch(env.SLACK_WEBHOOK_URL, {
    method: 'POST',
    body: JSON.stringify({
        text: `:red_circle: Synthetic test *${failedTestName}* failed in production.\n\`\`\`${errorDetails}\`\`\``
    })
})
```

**Option C — Checkly** ([checkly.com](https://checkly.com)) — a dedicated synthetic monitoring platform with a Cloudflare Workers integration. Handles scheduling, alerting, dashboards, and test history out of the box. Has a generous free tier. Worth evaluating instead of building this yourself.

---

## Test Results Logging

Store synthetic test results in a D1 table so you have a history of what passed and failed:

```sql
CREATE TABLE synthetic_test_results (
    id TEXT PRIMARY KEY,
    test_name TEXT NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('pass', 'fail')),
    duration_ms INTEGER NOT NULL,
    error_message TEXT,
    ran_at TEXT NOT NULL DEFAULT (datetime('now'))
);
```

This gives you a dashboard view of test health over time and makes it easy to spot intermittent failures.

---

## Summary: What to Build and When

| Action | When | Time Estimate |
|--------|------|---------------|
| Add `/health` endpoint to backend | At launch | 20 minutes |
| Set up UptimeRobot free monitor on `/health` | At launch | 5 minutes |
| Create `synthetic-test` account + DB flag | Week 1 post-launch | 30 minutes |
| Implement Tests 1 & 2 (auth + core plank flow) | Week 1–2 post-launch | 2–3 hours |
| Implement Tests 3, 5, 8 (idempotency, leaderboard, token refresh) | Week 2–4 post-launch | 2–3 hours |
| Implement Tests 4, 6, 7 (streak freeze, groups, media) | Month 2 post-launch | 2–3 hours |
| Set up Slack alerting | When you have a team | 1 hour |
| Evaluate Checkly as managed alternative | Month 2 post-launch | 1–2 hours |
