---
name: backend-deploy
description: Deploy the Cloudflare Workers backend and verify the deployment picked up the latest source
license: MIT
compatibility: opencode
---

## What I do

Deploy the Plank Challenge backend to Cloudflare Workers and confirm the deployed version actually contains the latest code changes. I enforce the correct commit-before-deploy order to avoid the silent failure mode where wrangler deploys stale source.

## When to use me

Use me whenever backend TypeScript files have been changed. Typical triggers:
- "Deploy the backend"
- "Push the backend changes"
- After any edits to files under `backend/src/`
- After a D1 schema migration

## Critical: commit BEFORE deploying

The single most important rule. Wrangler deploys whatever is on disk at the moment you run it — not necessarily what is committed. If you deploy before committing, the live Worker may run code that differs from the git history, making rollback unreliable.

**Correct sequence every time:**
1. Commit the backend changes to git
2. Deploy to Cloudflare
3. Verify the deployment version ID

## Step-by-step workflow

### Step 1 — Commit changes first

```bash
cd "/Users/lbaceviciuscloudflare.com/Developer/Personal projects/plank-challenge" && \
git add backend/ && \
git commit -m "<description of backend changes>" && \
git push
```

Only proceed to Step 2 once the commit succeeds.

### Step 2 — Deploy

```bash
cd "/Users/lbaceviciuscloudflare.com/Developer/Personal projects/plank-challenge/backend" && \
npx wrangler deploy 2>&1 | tail -10
```

A successful deploy shows:
```
Uploaded plank-challenge-api (Xs)
Deployed plank-challenge-api triggers (Xs)
  https://plank-challenge-api.petras-leonardas.workers.dev
Current Version ID: <uuid>
```

Note the `Current Version ID` — this is the deployed version fingerprint.

### Step 3 — Verify (when needed)

If the deployment fixed a bug that was previously failing, hit the relevant live endpoint with curl to confirm the new behaviour:

```bash
# Example: verify an endpoint returns the expected shape
curl -s "https://plank-challenge-api.petras-leonardas.workers.dev/<endpoint>" \
  -H "Authorization: Bearer <token>" | python3 -m json.tool | head -30
```

For schema changes, check the deployment list to confirm timing:

```bash
cd "/Users/lbaceviciuscloudflare.com/Developer/Personal projects/plank-challenge/backend" && \
npx wrangler deployments list 2>&1 | tail -10
```

## D1 migrations

If the backend change requires a database schema change, run the SQL against the live D1 database **after** deploying (or before, depending on whether the new code expects the new schema):

```bash
cd "/Users/lbaceviciuscloudflare.com/Developer/Personal projects/plank-challenge/backend" && \
npx wrangler d1 execute DB --remote --command "YOUR SQL HERE"
```

The D1 database binding name is `DB`. The database name is `plank-challenge-db`.

## What's deployed where

- **Worker name:** `plank-challenge-api`
- **Live URL:** `https://plank-challenge-api.petras-leonardas.workers.dev`
- **Database:** Cloudflare D1 — `plank-challenge-db`
- **Image storage:** Cloudflare R2 — `plank-challenge-media`
- **Cache / rate limiting:** Cloudflare KV — `CACHE`, `RATE_LIMIT`

## There is no local dev server in the normal workflow

The iOS app always points to the production Worker URL. There is no `wrangler dev` step in the standard workflow. Deploy directly to production for all changes.
