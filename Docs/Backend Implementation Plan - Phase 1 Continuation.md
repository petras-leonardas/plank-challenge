# Backend Implementation Plan - Phase 1 Continuation

**Version:** 1.1  
**Created:** March 14, 2026  
**Last Updated:** March 15, 2026  
**Status:** Phase 1 Complete

---

## Table of Contents

1. [Overview](#1-overview)
2. [Phase 1 Summary](#2-phase-1-summary)
3. [What Was Implemented](#3-what-was-implemented)
4. [Security Fixes Applied](#4-security-fixes-applied)
5. [Pending Tasks](#5-pending-tasks)
6. [File Structure](#6-file-structure)
7. [Cloudflare Resources](#7-cloudflare-resources)
8. [API Endpoints](#8-api-endpoints)
9. [Testing Commands](#9-testing-commands)
10. [Next Steps](#10-next-steps)

---

## 1. Overview

This document serves as a continuation record for Phase 1 of the Plank Challenge backend implementation. It captures what was accomplished, what issues were identified and fixed during the audit, and what remains to be completed before Phase 1 can be considered fully done.

### Key Context

- **Primary Plan Document:** `Docs/Backend Implementation Plan.md`
- **Production URL:** `https://plank-challenge-api.petras-leonardas.workers.dev`
- **Cloudflare Account:** My personal domain account (`0644b2da0e70bd12883572fd98db4874`)

---

## 2. Phase 1 Summary

### Original Phase 1 Goals (from Implementation Plan)

| Goal | Status |
|------|--------|
| Initialize Cloudflare Workers project | Done |
| Set up D1 database with schema | Done |
| Configure R2 bucket | Done |
| Set up KV namespaces | Done |
| Implement JWT utilities | Done |
| Create middleware (auth, logging, errors) | Done |
| Implement Sign in with Apple | Done (Pending Config) |
| Implement Sign in with Google | Done (Pending Config) |
| Implement email auth (register, login) | Done |
| User CRUD endpoints | Done |

### Phase 1 Audit & Fixes

After initial implementation, an audit was performed that identified several gaps, shortcuts, and security issues. All of these have been addressed:

| Issue Identified | Fix Applied | Status |
|------------------|-------------|--------|
| Apple/Google tokens not verified | Added JWKS-based verification | Done |
| No rate limiting | Sliding window rate limiter | Done |
| CORS wide open | Restricted for iOS-only API | Done |
| Logout bug (wrong token revoked) | Fixed to use refresh token | Done |
| Search route conflict | Reordered routes | Done |
| Account deletion incomplete | GDPR hard delete | Done |
| No dev bypass for OAuth | Added development mode bypass | Done |

---

## 3. What Was Implemented

### 3.1 Initial Implementation (Session 1)

**Backend Foundation:**
- Created `/backend` folder with full project structure
- Set up npm project with dependencies (hono, zod, jose, drizzle-orm, wrangler)
- Created TypeScript configuration
- Created Cloudflare Workers configuration (wrangler.toml)

**Database:**
- Created D1 schema with 9 tables:
  - `users` - User accounts and profiles
  - `plank_sessions` - Plank workout records
  - `badges` - Earned achievements
  - `groups` - Challenge groups
  - `group_members` - Group membership
  - `follows` - Social follow relationships
  - `notifications` - In-app notifications
  - `devices` - Push notification tokens
  - `join_requests` - Group join requests
- Deployed schema to production D1

**Authentication:**
- JWT generation and verification utilities
- Email registration endpoint
- Email login endpoint
- Token refresh endpoint
- Logout endpoint
- Account deletion endpoint
- Apple Sign-In endpoint (stub)
- Google Sign-In endpoint (stub)

**User Management:**
- Get current user profile
- Update user profile
- Get public user profile
- Search users
- Follow/unfollow users
- Get followers/following lists

**Infrastructure:**
- Request logging middleware
- Error handling middleware
- Auth middleware (JWT validation)

### 3.2 Audit Fixes (Session 2)

**New Files Created:**

| File | Purpose | Lines |
|------|---------|-------|
| `src/utils/oauth.ts` | Apple & Google JWKS token verification | ~150 |
| `src/middleware/rate-limit.ts` | Sliding window rate limiter | ~280 |
| `src/utils/account-cleanup.ts` | GDPR-compliant hard delete | ~200 |

**Files Modified:**

| File | Changes |
|------|---------|
| `src/types/env.ts` | Added `RATE_LIMIT` KV binding, OAuth client ID types |
| `src/routes/auth.ts` | Proper OAuth verification, fixed logout, integrated cleanup |
| `src/routes/users.ts` | Fixed route ordering (search before :id) |
| `src/index.ts` | Added rate limiting middleware, restricted CORS |
| `wrangler.toml` | Added RATE_LIMIT KV namespace |
| `.dev.vars` | Added OAuth placeholder comments |

---

## 4. Security Fixes Applied

### 4.1 OAuth Token Verification

**Problem:** Apple and Google identity tokens were being decoded without signature verification. Anyone could forge a token.

**Solution:** Implemented proper JWKS-based verification using the `jose` library:

```typescript
// Apple JWKS: https://appleid.apple.com/auth/keys
// Google JWKS: https://www.googleapis.com/oauth2/v3/certs

const { payload } = await jose.jwtVerify(idToken, jwks, {
  issuer: 'https://appleid.apple.com',
  audience: clientId,
});
```

**Development Bypass:** When `ENVIRONMENT=development` and client IDs are not set, the system allows unverified tokens for testing purposes. This is disabled in production.

### 4.2 Rate Limiting

**Problem:** No rate limiting existed, leaving the API vulnerable to brute force attacks and abuse.

**Solution:** Implemented sliding window counter algorithm using KV:

| Endpoint | Limit | Block Duration |
|----------|-------|----------------|
| `/auth/login` | 5 req/min | 5 minutes |
| `/auth/register` | 5 req/hour | 1 hour |
| `/auth/apple` | 10 req/min | 5 minutes |
| `/auth/google` | 10 req/min | 5 minutes |
| `/auth/refresh` | 10 req/min | 1 minute |
| API reads | 100 req/min | 1 minute |
| API writes | 30 req/min | 1 minute |

Rate limit headers are included in all responses:
- `X-RateLimit-Limit`
- `X-RateLimit-Remaining`
- `X-RateLimit-Reset`
- `Retry-After` (when blocked)

### 4.3 CORS Restriction

**Problem:** CORS was set to `origin: '*'`, allowing any website to access the API.

**Solution:** Restricted CORS for iOS-only API:
- Development: Allow all origins for testing
- Production: Reject browser requests (iOS apps don't send Origin header)
- Only allow specific web origins if needed (e.g., admin dashboard)

### 4.4 Logout Bug Fix

**Problem:** Logout was trying to revoke the access token's JTI, but refresh tokens have different JTIs.

**Solution:** Changed logout to accept refresh token in request body:

```typescript
// Before (broken)
auth.post('/logout', authMiddleware, async (c) => {
  const token = c.req.header('Authorization')?.slice(7); // Access token
  // Revoked wrong token
});

// After (fixed)
auth.post('/logout', authMiddleware, zValidator('json', logoutSchema), async (c) => {
  const { refreshToken } = c.req.valid('json');
  // Revokes correct refresh token
});
```

### 4.5 Route Ordering Fix

**Problem:** `/users/:id` was defined before `/users/search`, causing "search" to be treated as a user ID.

**Solution:** Reordered routes so specific routes come before parameterized routes:
1. `/users/me`
2. `/users/search` 
3. `/users/:id`

### 4.6 GDPR-Compliant Account Deletion

**Problem:** Account deletion only soft-deleted the user record, leaving orphaned data.

**Solution:** Implemented hard delete that removes all user data:
- Plank sessions
- Badges
- Group memberships (updates group member counts)
- Follow relationships (updates follower/following counts)
- Notifications
- Devices
- Join requests
- User record
- R2 media files

---

## 5. Pending Tasks

### 5.1 Apple Developer Account ✅ COMPLETE

**Status:** Configured on March 15, 2026

**Completed Steps:**
1. ✅ Apple Developer enrollment approved
2. ✅ Created App ID: `com.leobacevicius.plankchallenge`
3. ✅ Enabled "Sign in with Apple" capability
4. ✅ Set `APPLE_CLIENT_ID` secret in Cloudflare

### 5.2 Google Sign-In ✅ COMPLETE

**Status:** Configured on March 15, 2026

**Completed Steps:**
1. ✅ Created Google Cloud project: "Plank Challenge"
2. ✅ Configured OAuth consent screen
3. ✅ Created iOS OAuth Client ID
4. ✅ Set `GOOGLE_CLIENT_ID` secret in Cloudflare

---

## 6. File Structure

```
backend/
├── .dev.vars                    # Local development secrets (gitignored)
├── .gitignore                   # Git ignore rules
├── .npmrc                       # npm registry override (for Cloudflare internal)
├── package.json                 # Dependencies & scripts
├── tsconfig.json                # TypeScript configuration
├── wrangler.toml                # Cloudflare Workers configuration
└── src/
    ├── index.ts                 # Main Hono app entry point
    ├── db/
    │   └── schema.sql           # D1 database schema (9 tables)
    ├── types/
    │   ├── env.ts               # Cloudflare bindings types
    │   └── api.ts               # API response/request types
    ├── utils/
    │   ├── jwt.ts               # JWT generation/verification
    │   ├── response.ts          # API response helpers
    │   ├── oauth.ts             # Apple/Google JWKS verification
    │   └── account-cleanup.ts   # GDPR hard delete
    ├── middleware/
    │   ├── auth.ts              # JWT auth middleware
    │   ├── logger.ts            # Request logging
    │   ├── error.ts             # Global error handling
    │   └── rate-limit.ts        # Sliding window rate limiter
    └── routes/
        ├── auth.ts              # Auth endpoints
        └── users.ts             # User endpoints
```

---

## 7. Cloudflare Resources

### 7.1 Created Resources

| Resource | Type | ID/Name |
|----------|------|---------|
| Worker | Cloudflare Worker | `plank-challenge-api` |
| Database | D1 | `plank-challenge-db` (`3cb80504-ac23-4bba-bdf3-77cfed3de736`) |
| KV (Sessions) | KV Namespace | `SESSIONS` (`421154a5d19b429e8b9aebfe49d04206`) |
| KV (Cache) | KV Namespace | `CACHE` (`29960987c76947ecbff018e87c2b8a77`) |
| KV (Rate Limit) | KV Namespace | `RATE_LIMIT` (`14d4a11ce21f4ee2b3a27b03922817e8`) |
| Storage | R2 Bucket | `plank-challenge-media` |
| Queue | Cloudflare Queue | `badge-calculation` |
| Queue | Cloudflare Queue | `push-notifications` |

### 7.2 Secrets Configured

| Secret | Status | Purpose |
|--------|--------|---------|
| `JWT_SECRET` | ✅ Set | JWT signing key |
| `APPLE_CLIENT_ID` | ✅ Set | Apple Sign-In verification (`com.leobacevicius.plankchallenge`) |
| `GOOGLE_CLIENT_ID` | ✅ Set | Google Sign-In verification |

---

## 8. API Endpoints

### 8.1 Authentication

| Method | Endpoint | Status | Notes |
|--------|----------|--------|-------|
| POST | `/auth/register` | ✅ Working | Email/password registration |
| POST | `/auth/login` | ✅ Working | Email/password login |
| POST | `/auth/apple` | ✅ Working | Apple Sign-In (configured March 15, 2026) |
| POST | `/auth/google` | ✅ Working | Google Sign-In (configured March 15, 2026) |
| POST | `/auth/refresh` | ✅ Working | Token refresh |
| POST | `/auth/logout` | ✅ Working | Fixed: uses refresh token in body |
| DELETE | `/auth/account` | ✅ Working | GDPR hard delete |

### 8.2 Users

| Method | Endpoint | Status | Notes |
|--------|----------|--------|-------|
| GET | `/users/me` | Working | Current user profile |
| PATCH | `/users/me` | Working | Update profile |
| GET | `/users/search` | Working | Fixed: route ordering |
| GET | `/users/:id` | Working | Public profile |
| POST | `/users/:id/follow` | Working | Follow user |
| DELETE | `/users/:id/follow` | Working | Unfollow user |
| GET | `/users/:id/followers` | Working | List followers |
| GET | `/users/:id/following` | Working | List following |

### 8.3 Health

| Method | Endpoint | Status |
|--------|----------|--------|
| GET | `/` | Working |
| GET | `/health` | Working |

---

## 9. Testing Commands

### Local Development

```bash
cd backend

# Start local dev server
npm run dev

# Run TypeScript checks
npm run typecheck

# Run database migration (local)
npm run db:migrate:local
```

### Production Testing

```bash
# Health check
curl https://plank-challenge-api.petras-leonardas.workers.dev/health

# Register
curl -X POST https://plank-challenge-api.petras-leonardas.workers.dev/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"TestPass123!","displayName":"Test User"}'

# Login
curl -X POST https://plank-challenge-api.petras-leonardas.workers.dev/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"TestPass123!"}'

# Search (with token)
curl "https://plank-challenge-api.petras-leonardas.workers.dev/users/search?q=test" \
  -H "Authorization: Bearer <token>"

# Test rate limiting (6 requests should trigger 429)
for i in {1..6}; do
  curl -s -w "HTTP:%{http_code}\n" -X POST \
    https://plank-challenge-api.petras-leonardas.workers.dev/auth/login \
    -H "Content-Type: application/json" \
    -d '{"email":"wrong@example.com","password":"wrong"}'
done
```

### Deployment

```bash
cd backend

# Deploy to production
npm run deploy

# Set a secret
npx wrangler secret put SECRET_NAME

# Run remote database migration
npm run db:migrate -- --remote
```

---

## 10. Next Steps

### ~~Immediate (When Apple Enrollment Approved)~~ ✅ DONE

~~1. Configure Apple Sign-In~~ ✅ Completed March 15, 2026
~~2. Test Apple Sign-In~~ Requires iOS app integration

### ~~Optional (Before Phase 2)~~ ✅ DONE

~~1. Configure Google Sign-In~~ ✅ Completed March 15, 2026

### Optional (Nice to Have)

1. **Set Up Custom Domain:**
   - Configure `api.plankchallenge.app` (or similar)
   - Update CORS allowed origins

### Phase 2: Core Plank Features

Reference: `Docs/Backend Implementation Plan.md` - Section 10, Phase 2

**Scope:**
- Implement SwiftData models in iOS
- Create SyncEngine in iOS
- Plank CRUD API endpoints (`/planks`)
- Sync endpoint with timestamp filtering
- Server-side streak calculation
- Freeze token management
- Background sync (iOS)
- Conflict-free sync testing

**Success Criteria:**
- Plank on device A appears on device B
- Offline plank syncs when online
- Streak updates after each plank
- Freeze token can be used
- Delete today's plank works

---

## Document History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-03-14 | Initial Phase 1 continuation document |
| 1.1 | 2026-03-15 | Apple & Google OAuth configured, Phase 1 marked complete |

---

*This document should be referenced when continuing Phase 1 completion or starting Phase 2. For the full implementation plan, see `Docs/Backend Implementation Plan.md`.*
