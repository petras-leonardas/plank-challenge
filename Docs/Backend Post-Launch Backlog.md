# Backend Post-Launch Backlog

*Tracking remaining improvements deferred from the Phase 8 hardening audit*

---

## Overview

During the comprehensive audit before launch, we identified **65 issues** across severity levels. All CRITICAL (7), HIGH (10), and MEDIUM (~22) priority issues have been fixed. This document tracks the remaining LOW priority items that were intentionally deferred as non-blockers for launch.

These items represent quality-of-life improvements, additional safety nets, and operational tooling that can be addressed incrementally based on real-world usage patterns.

---

## Deferred Items

### 0. Password Reset Flow (REQUIRES EMAIL SERVICE)

**Current State:** `POST /auth/forgot-password` and `POST /auth/reset-password` are NOT implemented. Email authentication users cannot recover their accounts if they forget their password.

**Workaround:** Users with email accounts should link their Apple or Google accounts for account recovery.

**Required for Implementation:**
- Email service integration (SendGrid, Resend, Mailgun, or Cloudflare Email Workers)
- Password reset tokens table in schema
- Rate limiting for reset requests (prevent enumeration)
- Token expiration (15-30 minutes)
- Secure token generation

**Endpoints to Implement:**
```
POST /auth/forgot-password { email }
  - Rate limit: 3 requests per hour per email
  - Always return success (prevent email enumeration)
  - Send email with reset link containing secure token

POST /auth/reset-password { token, newPassword }
  - Validate token exists and not expired
  - Hash new password with Argon2
  - Invalidate token after use
  - Optionally invalidate all existing sessions
```

**Priority:** Medium (blocking for email-only users)
**Effort:** Medium (requires email service setup)

---

### 1. Deprecated Code Cleanup

**File:** `backend/src/utils/streak.ts:483`

The legacy `useFreezeToken()` function is marked `@deprecated` but still exists for backwards compatibility. It wraps the new `useFreezeTokenAtomic()` function.

**Action:** Remove after confirming no code paths use it directly.

**Priority:** Low
**Effort:** Small

---

### 2. Admin Dashboard

**Current State:** All administrative tasks (user management, content moderation, data fixes) are performed via direct D1 database queries.

**Desired State:** Web-based admin dashboard for:
- Viewing/searching users
- Moderating content (flagged planks, inappropriate usernames)
- Managing groups (resolving disputes, removing bad actors)
- Viewing system metrics

**Priority:** Low (until user base grows)
**Effort:** Large

---

### 3. External Analytics Integration

**Current State:** Basic console logging with structured JSON format.

**Desired State:** Integration with analytics platform (e.g., Cloudflare Analytics, custom solution) for:
- Request volume tracking
- Error rate monitoring
- Endpoint performance metrics
- User behavior patterns

**Priority:** Low
**Effort:** Medium

---

### 4. Monitoring & Alerting

**Current State:** Logs are available in Cloudflare dashboard but require manual review.

**Desired State:** 
- Automated alerts for error rate spikes
- Alerts for unusual traffic patterns
- Database performance monitoring
- R2 storage usage alerts

**Priority:** Low (Cloudflare provides basic monitoring)
**Effort:** Medium

---

### 5. Load Testing

**Current State:** No synthetic load testing performed. Performance assumptions based on Cloudflare Workers' documented capabilities.

**Desired State:**
- Load test scripts for critical endpoints
- Baseline performance metrics documented
- Capacity planning data

**Priority:** Low (Workers auto-scale)
**Effort:** Medium

---

### 6. Automated Test Suite

**Current State:** No automated tests. Validation done through manual testing and TypeScript type checking.

**Desired State:**
- Unit tests for utility functions (streak calculation, badge logic)
- Integration tests for critical flows (auth, plank creation, sync)
- CI/CD pipeline running tests on PR

**Priority:** Medium (but deferred)
**Effort:** Large

---

### 7. API Documentation

**Current State:** Endpoints documented in implementation plan markdown files.

**Desired State:**
- OpenAPI/Swagger specification
- Interactive API documentation
- SDK generation for iOS client

**Priority:** Low
**Effort:** Medium

---

### 8. Database Migrations System

**Current State:** Single `schema.sql` file. Schema changes require manual migration scripts.

**Desired State:**
- Versioned migration system
- Rollback capability
- Migration history tracking

**Priority:** Low (schema is stable)
**Effort:** Medium

---

### 9. R2 Orphan Cleanup Job

**Current State:** Orphaned files in R2 (from failed uploads) are logged but not automatically cleaned up.

**File:** `backend/src/routes/media.ts` - logs orphans but doesn't delete them

**Desired State:**
- Scheduled job to identify and remove orphaned R2 objects
- Metrics on storage reclaimed

**Priority:** Low (storage is cheap)
**Effort:** Small

---

### 10. Notification Delivery System

**Current State:** Push notification infrastructure is in place (device registration, token management) but actual delivery via APNs is not implemented.

**Desired State:**
- APNs integration for iOS push notifications
- Notification scheduling
- Delivery status tracking

**Priority:** Medium (but separate project)
**Effort:** Large

---

### 11. Email Verification Flow

**Current State:** `email_verified` field exists but no verification flow implemented.

**Desired State:**
- Send verification email on signup
- Verification link handling
- Resend verification option

**Priority:** Low (OAuth handles identity)
**Effort:** Medium

---

### 12. Account Deletion (GDPR)

**Current State:** Soft delete exists but no full data purge flow.

**Desired State:**
- User-initiated account deletion
- Full data purge (planks, groups, follows, etc.)
- Confirmation flow
- Grace period before permanent deletion

**Priority:** Medium (legal requirement in some jurisdictions)
**Effort:** Medium

---

### 13. Rate Limit Tuning

**Current State:** Rate limits are set to reasonable defaults based on estimates.

**Desired State:**
- Review limits based on actual usage patterns
- Adjust limits that are too restrictive or too permissive
- Add rate limiting to any endpoints that show abuse

**Priority:** Low
**Effort:** Small (ongoing)

---

### 14. Caching Strategy

**Current State:** No explicit caching. Relies on Cloudflare's edge caching for static assets.

**Desired State:**
- Cache leaderboard results (they don't change frequently)
- Cache user profile data
- Cache group metadata
- Implement cache invalidation strategy

**Priority:** Low (performance is good)
**Effort:** Medium

---

### 15. Batch Operation Improvements

**Current State:** Some batch operations (e.g., deleting all notifications) don't have progress tracking.

**Desired State:**
- Progress indication for large batch operations
- Chunked processing for very large datasets
- Timeout handling for long-running operations

**Priority:** Low
**Effort:** Small

---

## Completed Fixes (Reference)

### CRITICAL (All Fixed)
1. Transaction handling for plank creation with stats update
2. Atomic operations for follow/unfollow count updates
3. Group member count consistency
4. Streak calculation edge cases
5. Token refresh race conditions
6. Media upload transaction handling
7. Badge award atomicity

### HIGH (All Fixed)
1. IP spoofing in rate limiting - now uses CF-Connecting-IP
2. Error message sanitization - no stack traces in production
3. JWT type field for token differentiation
4. Missing database indexes for performance
5. Input validation gaps in search endpoints
6. CORS configuration hardening
7. Password hash timing attacks
8. Session invalidation on password change
9. Group invite code entropy
10. Soft delete cascade handling

### MEDIUM (All Fixed)
1. parseInt validation in pagination (users.ts, groups.ts)
2. Error message config leakage in OAuth (auth.ts)
3. CORS rejection logging (index.ts)
4. Deprecation headers for old endpoints (devices.ts)
5. R2 orphan handling logging (media.ts)
6. Plank delete transaction handling (planks.ts)
7. Streak freeze partial failure - atomic operation (streaks.ts)
8. Notification cleanup query performance (notifications.ts)
9. CHECK constraints in database schema (schema.sql)
10. Type safety with ContentfulStatusCode (response.ts)
11. Integer overflow prevention in streak calculations (streak.ts)
12. Corrupted deprecated endpoint code (devices.ts)

### SCHEMA FIXES (All Fixed - March 2026)
Critical schema/code mismatches that would have caused SQL CHECK constraint violations:

1. `users.preferred_plank_type`: Changed from `'elbow', 'straight_arm', 'side_left', 'side_right'` to `'elbow', 'straightArm', 'parallettes'`
2. `plank_sessions.plank_type`: Changed from `'elbow', 'straight_arm', 'side_left', 'side_right'` to `'elbow', 'high', 'side_left', 'side_right', 'reverse'`
3. `plank_sessions.input_method`: Added `'watch'` to `'timer', 'manual'`
4. `groups.group_type`: Changed from `'friends', 'family', 'coworkers'...` to `'public', 'private'`
5. `groups.join_mode`: Changed from `'open', 'invite_only', 'approval_required'` to `'open', 'request'`
6. `group_members.status`: Changed from `'active', 'muted', 'left'` to `'active', 'banned'`
7. `join_requests.status`: Changed from `'pending', 'approved', 'rejected'` to `'pending', 'approved', 'denied'`
8. `notifications.type`: Expanded from 7 types to 14 types to match `NotificationType` in api.ts
9. `follows` table: Added `CHECK (follower_id != following_id)` constraint

---

## How to Use This Document

1. **Before starting work:** Review this list to understand outstanding items
2. **When prioritizing:** Consider user impact and effort required
3. **After completing an item:** Move it to the "Completed" section with date
4. **When discovering new issues:** Add them here with appropriate priority

---

*Last updated: March 15, 2026*
*Status: Launch-ready with deferred improvements*

---

## Quick Reference: What's NOT Implemented

For quick scanning, here are features mentioned in the Backend Implementation Plan that are NOT yet implemented:

| Feature | Status | Blocking? |
|---------|--------|-----------|
| `POST /auth/forgot-password` | Not implemented | No (use OAuth) |
| `POST /auth/reset-password` | Not implemented | No (use OAuth) |
| Push notification delivery (APNs) | Infrastructure only | No |
| Email verification flow | Field exists, no flow | No |
| Thumbnail generation | Not implemented | No |
| Queue consumers (badge/notification) | Not used (sync works) | No |
| Durable Objects | Not used (KV works) | No |
| Account linking (Apple+Google) | Not implemented | No |
| User blocking | Not implemented | No |
| Data export | Not implemented | No |

All of these can be added incrementally post-launch based on user feedback and priorities.
