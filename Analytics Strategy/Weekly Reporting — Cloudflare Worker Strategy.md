# Weekly Reporting — Cloudflare Worker Strategy

## Overview

Plank Challenge uses Cloudflare D1 (SQLite) as its primary database, with all user,
plank, streak, and badge data already structured and queryable. Rather than introducing
a third-party analytics platform in the early stages, the recommended approach is to
build a scheduled Cloudflare Worker that queries D1 directly and delivers a weekly
email report to the product owner every Monday morning.

This keeps the entire stack within Cloudflare (zero new infrastructure), costs nothing,
and gives us exactly the metrics we care about without any SDK instrumentation.

---

## Architecture

```
Cloudflare Cron Trigger (every Monday 08:00 UTC)
        │
        ▼
Scheduled Worker (weekly-report)
        │
        ├── Query D1 → new users this week vs last week
        ├── Query D1 → verification rate, sign-in method breakdown
        ├── Query D1 → active users (plank_sessions this week)
        ├── Query D1 → total planks logged this week
        └── Query D1 → streak stats
        │
        ▼
Transactional Email Provider (Resend — recommended)
        │
        ▼
Weekly digest email → product owner inbox
```

---

## What the Report Will Cover

### User Growth
- New users registered this week
- Week-over-week change (absolute + percentage)
- Cumulative total users
- Breakdown by sign-in method (Google / Apple / Email)
- Email verification rate

### Engagement
- Users who logged at least one plank this week (WAU)
- Total planks logged this week vs last week
- Average planks per active user
- New streaks started vs streaks broken

### Badges
- Badges earned this week
- Most common badge earned

### Example Report Email

```
📊 Plank Challenge — Weekly Report
Week of 22 Mar – 28 Mar 2026

────────────────────────────────
USER GROWTH
────────────────────────────────
New users this week:     12   (+40% vs last week)
  via Google:             6
  via Apple:              4
  via Email:              2
Email verified:           9   (75%)

Cumulative total:       247 users

────────────────────────────────
ENGAGEMENT
────────────────────────────────
Weekly active users:     89   (36% of total)
Planks logged:          312   (+18% vs last week)
Avg planks / active user: 3.5

────────────────────────────────
STREAKS & BADGES
────────────────────────────────
New streaks started:     34
Streaks broken:          12
Badges earned:           28
Most earned:             🔥 7-Day Streak (11x)
────────────────────────────────
```

---

## Implementation Plan

### Step 1 — Add Resend (Email Provider)

Resend (resend.com) is the recommended transactional email provider:
- Free tier: 3,000 emails/month, 100/day
- Cloudflare Workers native support (no Node.js dependencies)
- Simple REST API — a single `fetch()` call

Sign up at resend.com, verify your sending domain, and generate an API key.
Store it as a Cloudflare secret:

```bash
npx wrangler secret put RESEND_API_KEY
```

### Step 2 — Create the Scheduled Worker

Add a new worker file at `backend/src/scheduled/weekly-report.ts`.

Register the cron trigger in `wrangler.toml`:

```toml
[triggers]
crons = ["0 8 * * 1"]  # Every Monday at 08:00 UTC
```

The worker will:
1. Calculate the current week's date range (Mon–Sun)
2. Run D1 queries for each metric section
3. Build an HTML email from the results
4. POST to the Resend API

### Step 3 — D1 Queries

New users this week vs last week:
```sql
SELECT
  COUNT(CASE WHEN created_at >= date('now', '-7 days') THEN 1 END) as this_week,
  COUNT(CASE WHEN created_at >= date('now', '-14 days')
              AND created_at < date('now', '-7 days') THEN 1 END) as last_week
FROM users
WHERE deleted_at IS NULL AND email_verified = 1;
```

Weekly active users:
```sql
SELECT COUNT(DISTINCT user_id) as wau
FROM plank_sessions
WHERE performed_at >= date('now', '-7 days');
```

Sign-in method breakdown:
```sql
SELECT
  COUNT(CASE WHEN google_id IS NOT NULL THEN 1 END) as google,
  COUNT(CASE WHEN apple_id IS NOT NULL THEN 1 END) as apple,
  COUNT(CASE WHEN google_id IS NULL AND apple_id IS NULL THEN 1 END) as email
FROM users
WHERE created_at >= date('now', '-7 days') AND deleted_at IS NULL;
```

### Step 4 — Test Locally

Wrangler supports triggering scheduled events locally:
```bash
npx wrangler dev --test-scheduled
# Then in another terminal:
curl http://localhost:8787/__scheduled?cron=0+8+*+*+1
```

### Step 5 — Deploy

```bash
npx wrangler deploy
```

The cron trigger activates automatically. You can also trigger it manually from the
Cloudflare Dashboard → Workers → weekly-report → Triggers → Test.

---

## Future Enhancements

Once we have a meaningful user base, consider layering in:

| When | What | Why |
|------|------|-----|
| 100+ users | Add PostHog iOS SDK | Retention curves, session recording, funnels |
| 500+ users | Add Amplitude | Cohort analysis, A/B testing framework |
| 1000+ users | Export D1 → Cloudflare Analytics Engine | Real-time dashboards, custom metrics |

The scheduled Worker approach scales to several thousand users before any of the above
becomes necessary. The D1 queries are fast (sub-1ms at current scale) and the Worker
execution time is well within Cloudflare's free tier limits.

---

## Email Provider Alternatives

| Provider | Free Tier | Notes |
|----------|-----------|-------|
| Resend | 3,000/month | Best DX, Cloudflare native, recommended |
| SendGrid | 100/day | Widely used, more complex setup |
| Mailgun | 1,000/month (trial) | Good API, requires credit card |
| Postmark | 100/month free | Excellent deliverability |

---

## Decision Log

| Date | Decision | Reason |
|------|----------|--------|
| Mar 2026 | Scheduled Worker over Amplitude | No SDK instrumentation needed at early stage; all data already in D1; zero cost |
| Mar 2026 | Resend as email provider | Best Cloudflare Workers compatibility; generous free tier; simplest API |
| Mar 2026 | Weekly cadence (Monday 08:00 UTC) | Aligns with start of work week; gives full previous week's data |
