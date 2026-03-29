---
name: debug-api
description: Authenticate against the live API and inspect endpoint responses to diagnose schema mismatches and unexpected behaviour
license: MIT
compatibility: opencode
---

## What I do

Get a real auth token from the live API and use it to curl any endpoint, inspect the raw JSON response, and compare it against the iOS model to find schema mismatches. This is the correct first step whenever a decode error or unexpected response is suspected.

## When to use me

Use me whenever:
- An iOS view shows "Failed to decode response" or "the data couldn't be read because it is missing"
- A `DecodingError.keyNotFound` or `typeMismatch` error is suspected
- You want to verify what the backend actually returns before writing an iOS model
- An endpoint seems to return empty data when it shouldn't
- You need to confirm a backend fix was actually deployed

**Rule:** Always check the real JSON before writing or modifying an iOS model. Do not assume the response shape from reading the backend source alone — hit the live API and verify.

## Live API base URL

```
https://plank-challenge-api.petras-leonardas.workers.dev
```

## Step 1 — Get an auth token

### Option A: Create a throwaway test account (no existing credentials needed)

```bash
curl -s -X POST "https://plank-challenge-api.petras-leonardas.workers.dev/auth/register" \
  -H "Content-Type: application/json" \
  -d '{"email":"debugtest@plank.dev","password":"Debug1234!","displayName":"Debug Test"}' \
  | python3 -m json.tool 2>/dev/null | head -20
```

If that email already exists (returns 409), log in instead:

```bash
curl -s -X POST "https://plank-challenge-api.petras-leonardas.workers.dev/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"email":"debugtest@plank.dev","password":"Debug1234!"}' \
  | python3 -m json.tool 2>/dev/null | head -20
```

Extract the `accessToken` from the response `data` object. Store it:

```bash
TOKEN="<paste accessToken here>"
```

### Option B: Use an existing account

Ask the owner for their email/password for the test account, or use whatever credentials are appropriate for the session.

## Step 2 — Hit the endpoint

```bash
curl -s "<BASE_URL>/<endpoint>" \
  -H "Authorization: Bearer $TOKEN" \
  | python3 -m json.tool 2>/dev/null
```

Examples:

```bash
# Get groups list
curl -s "https://plank-challenge-api.petras-leonardas.workers.dev/groups/my" \
  -H "Authorization: Bearer $TOKEN" | python3 -m json.tool

# Get a specific group (replace GROUP_ID)
curl -s "https://plank-challenge-api.petras-leonardas.workers.dev/groups/GROUP_ID" \
  -H "Authorization: Bearer $TOKEN" | python3 -m json.tool

# Get group leaderboard (replace GROUP_ID)
curl -s "https://plank-challenge-api.petras-leonardas.workers.dev/groups/GROUP_ID/leaderboard?period=week" \
  -H "Authorization: Bearer $TOKEN" | python3 -m json.tool

# Get global leaderboard
curl -s "https://plank-challenge-api.petras-leonardas.workers.dev/leaderboards/streak?period=week&limit=10" \
  -H "Authorization: Bearer $TOKEN" | python3 -m json.tool

# Get today's planks
curl -s "https://plank-challenge-api.petras-leonardas.workers.dev/planks/sync" \
  -H "Authorization: Bearer $TOKEN" | python3 -m json.tool
```

## Step 3 — Diagnose the mismatch

Compare the raw JSON against the iOS model in `APIModels.swift`. Work through this checklist:

### Key naming
- Are the JSON keys camelCase or snake_case?
- `convertFromSnakeCase` converts `snake_case` → camelCase automatically — so `display_name` maps to `displayName` ✓
- But it does NOT rename arbitrary keys — if JSON has `"entries"` and Swift has `let leaderboard`, they will never match regardless of casing

### Nesting
- Is the response a flat object or does it have nested keys?
- Many backend responses are flat — there is no wrapper key
- Check whether the iOS model has nested structs that don't exist in the JSON

### Types
- Are numeric fields `Int` or `Double` in the JSON?
- SQLite `SUM()` and `MAX()` on `duration_seconds` (a REAL column) return floating-point — e.g. `11.801993...`
- If the iOS model uses `Int` for these fields, it will crash with `typeMismatch`

### Optional vs required
- If a field is sometimes absent from the JSON, the Swift property must be `Optional` (`?`)
- Group `role` field is absent for regular members — it is not `null`, it is simply not present

### The `data` wrapper
- All backend responses are wrapped: `{ "success": true, "data": {...}, "meta": {...} }`
- `APIClient` unwraps this automatically — the iOS model only needs to match what's inside `data`
- Do not add a wrapper struct around the model

## Step 4 — Fix the model

Once the mismatch is identified, update the relevant struct in:

```
PlankChallenge/PlankChallenge/Services/API/Models/APIModels.swift
```

Then rebuild and redeploy iOS using the `ios-deploy` skill.

## Common mismatches we have hit before

| Symptom | Likely cause |
|---|---|
| `keyNotFound("leaderboard")` | Backend sends `"entries"` — field renamed |
| `keyNotFound("userRank")` | Backend sends `"currentUserRank"` |
| `keyNotFound("group")` | Backend returns flat object, not `{ group: {...} }` |
| `typeMismatch(Int, Double)` | Stat field is a SQLite REAL — change to `Double` |
| `keyNotFound("role")` | Regular group members don't get a `role` field — make it `Optional` |
| `AvatarView` shows placeholder | URL passed to `imageName` instead of `imageUrl` |
