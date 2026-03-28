# Backend Implementation Plan - Phase 7 Completion

**Phase:** 7 - Leaderboards & Device Registration  
**Version:** 1.1 (with robustness fixes)  
**Completed:** March 15, 2026  
**Author:** Leo Bacevicius + Claude

---

## Overview

Phase 7 implements global leaderboards with KV caching for performance, and device token registration for push notification support. While APNs integration itself is deferred to a future iteration (requires Apple Developer account setup), all the backend infrastructure is now in place.

---

## Implemented Features

### 1. Global Leaderboards (`/leaderboards`)

Four leaderboard types implemented:

| Endpoint | Description | Metrics |
|----------|-------------|---------|
| `GET /leaderboards/streak` | Streak rankings | Longest streak (all-time) or current streak (weekly/monthly) |
| `GET /leaderboards/duration` | Longest plank rankings | Longest single plank duration |
| `GET /leaderboards/total-planks` | Most planks rankings | Total plank count |
| `GET /leaderboards/total-time` | Most time rankings | Total time spent planking |
| `GET /leaderboards/friends` | Friends leaderboard | Supports all metrics via `type` param |

**Query Parameters:**
- `limit` (1-100, default 50): Number of entries to return
- `offset` (default 0): Pagination offset
- `period` (`all_time` | `monthly` | `weekly`, default `all_time`): Time filter
- `type` (friends only): `streak` | `duration` | `total_planks` | `total_time`

**Response Features:**
- User rank with score and formatted label
- `isCurrentUser` flag for highlighting
- `currentUserRank` if authenticated user is not in visible results
- Pagination with `hasMore` indicator
- Cache metadata (`cachedAt`, `cacheTtl`)

### 2. Device Registration (`/devices`)

Full device management for push notifications:

| Endpoint | Description |
|----------|-------------|
| `POST /devices` | Register device token (idempotent) |
| `GET /devices` | List user's registered devices |
| `PATCH /devices/:id` | Update device metadata |
| `POST /devices/ping` | Update activity timestamp |
| `POST /devices/unregister` | Remove device (preferred) |
| `DELETE /devices/:token` | Remove device (deprecated) |
| `DELETE /devices/all` | Unregister all devices |

**Features:**
- Automatic device limit (10 per user, oldest auto-removed)
- Device transfer when user switches accounts
- Token normalization (lowercase)
- Platform validation (ios, ipados, watchos)

### 3. KV Caching Layer

Implemented caching for leaderboard performance:

- **Cache TTL:** 60 seconds (configurable)
- **Cache Key Format:** `leaderboard:{type}:{period}:{dateBucket}:{limit}:{offset}` (hourly buckets for period queries)
- **Eventual Consistency:** Noted in documentation
- **Cache Bypass:** Friends leaderboard is personalized, not cached

---

## Robustness Fixes Applied (v1.0)

### Issue 1: Route Ordering Conflict
**Problem:** `DELETE /devices/all` and `POST /devices/ping` could match `DELETE /devices/:token`  
**Fix:** Moved specific routes before parameterized routes with documentation comments

### Issue 2: Device Token in URL
**Problem:** `DELETE /devices/:token` puts sensitive token in URL which may be logged  
**Fix:** Added `POST /devices/unregister` as preferred method, deprecated the DELETE endpoint

### Issue 3: Empty Update Allowed
**Problem:** `PATCH /devices/:id` could be called with no fields  
**Fix:** Added validation to require at least one field

### Issue 4: Friends Leaderboard Limited
**Problem:** Friends leaderboard only supported streak rankings  
**Fix:** Added `type` parameter supporting all four leaderboard metrics

### Issue 5: Cache Documentation
**Problem:** No documentation about eventual consistency  
**Fix:** Added comments explaining cache TTL and consistency model

---

## Robustness Fixes Applied (v1.1)

### Issue 6: SQL Injection in Friends Leaderboard (CRITICAL)
**Problem:** `periodStart` was interpolated directly into SQL string using string concatenation (`'${periodStart}'`)  
**Fix:** Refactored to use parameterized queries with proper `?` placeholders and `.bind()` calls

### Issue 7: Offset Without Upper Bound
**Problem:** Offset could be set to extreme values (e.g., 999999999) causing performance issues  
**Fix:** Added `LEADERBOARD_MAX_OFFSET = 10000` validation in Zod schema

### Issue 8: Cache Key Didn't Include Date for Period Queries
**Problem:** Weekly/monthly caches used the same key regardless of when `periodStart` was calculated, leading to stale data  
**Fix:** Added hourly date bucket to cache keys for period-based queries: `leaderboard:{type}:{period}:{dateBucket}:{limit}:{offset}`

### Issue 9: Device Registration Race Condition
**Problem:** Between checking device count and deleting oldest device, another request could insert a device, exceeding the limit  
**Fix:** Used D1 batch to atomically delete excess devices and insert new one in a single transaction

### Issue 10: Missing Device ID Format Validation
**Problem:** `PATCH /devices/:id` accepted any string as ID, could cause unexpected behavior  
**Fix:** Added UUID format validation with regex before processing

### Issue 11: Missing Null Check After Insert
**Problem:** After inserting a new device, the code assumed the fetch would succeed (`formatDevice(newDevice!)`)  
**Fix:** Added explicit null check with proper error response

### Issue 12: Incorrect Route Ordering Comment
**Problem:** Comment said PATCH should be before specific routes, but it should be after  
**Fix:** Moved PATCH and DELETE /:token routes to the end after specific routes, updated comments

---

## API Examples

### Get Global Streak Leaderboard
```bash
curl https://api.plankchallenge.app/leaderboards/streak
```

Response:
```json
{
  "success": true,
  "data": {
    "type": "streak",
    "period": "all_time",
    "entries": [
      {
        "rank": 1,
        "user": {
          "id": "...",
          "displayName": "Top Planker",
          "username": "topplanker",
          "profileImageUrl": "..."
        },
        "score": 365,
        "scoreLabel": "365 days",
        "isCurrentUser": false
      }
    ],
    "currentUserRank": {
      "rank": 42,
      "score": 14,
      "scoreLabel": "14 days"
    },
    "pagination": {
      "total": 1000,
      "limit": 50,
      "offset": 0,
      "hasMore": true
    },
    "meta": {
      "cachedAt": "2026-03-15T12:00:00Z",
      "cacheTtl": 60
    }
  }
}
```

### Register Device for Push Notifications
```bash
curl -X POST https://api.plankchallenge.app/devices \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "deviceToken": "abc123...",
    "platform": "ios",
    "appVersion": "1.0.0",
    "osVersion": "17.4",
    "deviceModel": "iPhone15,2"
  }'
```

Response:
```json
{
  "success": true,
  "data": {
    "device": {
      "id": "...",
      "platform": "ios",
      "appVersion": "1.0.0",
      "osVersion": "17.4",
      "deviceModel": "iPhone15,2",
      "lastActiveAt": "2026-03-15T12:00:00Z",
      "createdAt": "2026-03-15T12:00:00Z"
    },
    "action": "created"
  }
}
```

### Unregister Device (Preferred Method)
```bash
curl -X POST https://api.plankchallenge.app/devices/unregister \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"deviceToken": "abc123..."}'
```

---

## Files Changed

### New Files
- `backend/src/routes/leaderboards.ts` (1068 lines)
- `backend/src/routes/devices.ts` (485 lines)

### Modified Files
- `backend/src/index.ts` - Added route imports and mounting

---

## Database Tables Used

### Existing Tables
- `users` - For leaderboard rankings (uses denormalized stats)
- `plank_sessions` - For period-based calculations
- `follows` - For friends leaderboard
- `devices` - For push notification tokens

### No Schema Changes Required
All tables already existed from Phase 1 schema.

---

## Performance Considerations

1. **KV Caching:** Reduces D1 load for popular leaderboard queries
2. **Denormalized Stats:** Uses `users` table stats for all-time rankings (O(1) per user)
3. **Period Queries:** Joins with `plank_sessions` for weekly/monthly (indexed on `performed_at`)
4. **Pagination:** All endpoints support limit/offset pagination
5. **Count Caching:** Total counts cached with leaderboard data

---

## What's NOT Implemented (Deferred)

### APNs Integration
The plan called for full push notification delivery. This requires:
- Apple Developer account credentials
- APNs certificate or key configuration
- Queue consumers for notification delivery

**Current State:** Device tokens are stored and ready. APNs can be added later without API changes.

### Durable Objects
The plan mentioned Durable Objects for real-time rankings. For the current scale, KV caching provides sufficient performance. Durable Objects can be added for:
- Real-time leaderboard updates
- WebSocket connections
- Live competition features

---

## Testing Checklist

- [x] GET /leaderboards/streak - Returns ranked users
- [x] GET /leaderboards/streak?period=weekly - Filters to active users
- [x] GET /leaderboards/duration - Returns longest plank rankings
- [x] GET /leaderboards/total-planks - Returns plank count rankings
- [x] GET /leaderboards/total-time - Returns total time rankings
- [x] GET /leaderboards/friends - Returns friends rankings (requires auth)
- [x] GET /leaderboards/friends?type=duration - Different metric types work
- [x] POST /devices - Creates new device
- [x] POST /devices (same token) - Updates existing device
- [x] GET /devices - Lists user's devices
- [x] PATCH /devices/:id - Updates device metadata
- [x] PATCH /devices/:id (empty body) - Returns validation error
- [x] POST /devices/ping - Updates last active timestamp
- [x] POST /devices/unregister - Removes device
- [x] DELETE /devices/all - Removes all user's devices
- [x] Cache hit - Second request returns cached data
- [x] Current user rank - Shows rank when not in visible results

---

## Next Steps (Phase 8)

1. **Production Hardening**
   - Error handling audit
   - Security audit
   - Performance optimization

2. **APNs Integration** (when ready)
   - Configure Apple Developer credentials
   - Implement notification queue consumer
   - Add notification triggers

3. **Monitoring & Analytics**
   - Logging improvements
   - Analytics integration
   - Admin dashboard (optional)

---

## Summary

Phase 7 successfully implements:
- 5 leaderboard endpoints with caching
- 7 device management endpoints
- Period-based filtering (all-time, monthly, weekly)
- Friends leaderboard with multiple metrics
- Robustness fixes for route ordering, security, and validation

The backend is now feature-complete for leaderboards and ready for push notification integration when Apple Developer credentials are configured.
