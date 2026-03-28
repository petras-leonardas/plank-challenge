# Backend Implementation Plan - Phase 5 Completion

**Version:** 1.1  
**Created:** March 15, 2026  
**Last Updated:** March 15, 2026  
**Status:** Phase 5 Complete (with robustness improvements)

---

## Table of Contents

1. [Overview](#1-overview)
2. [Phase 5 Summary](#2-phase-5-summary)
3. [What Was Implemented](#3-what-was-implemented)
4. [User Discovery Algorithm](#4-user-discovery-algorithm)
5. [API Endpoints](#5-api-endpoints)
6. [Testing Results](#6-testing-results)
7. [Files Modified](#7-files-modified)
8. [Next Steps](#8-next-steps)

---

## 1. Overview

Phase 5 focused on social features - specifically the follow system, user discovery, and user search functionality.

### Key Context

- **Primary Plan Document:** `Docs/Backend Implementation Plan.md`
- **Production URL:** `https://plank-challenge-api.petras-leonardas.workers.dev`
- **Phase 4 Document:** `Docs/Backend Implementation Plan - Phase 4 Completion.md`

### Important Note

Most of Phase 5 was already implemented in Phase 2. The remaining work was the **User Discovery Algorithm** - a "suggested users to follow" feature.

---

## 2. Phase 5 Summary

### Original Phase 5 Goals (from Implementation Plan)

| Goal | Status | Notes |
|------|--------|-------|
| Follow/unfollow API | Done (Phase 2) | `POST/DELETE /users/:id/follow` |
| Followers/following lists | Done (Phase 2) | `GET /users/:id/followers`, `GET /users/:id/following` |
| User search API | Done (Phase 2) | `GET /users/search?q=` |
| Public user profiles | Done (Phase 2) | `GET /users/:id` |
| Follower count denormalization | Done (Phase 2) | Counts updated atomically |
| User discovery algorithm | **Done (Phase 5)** | `GET /users/discover` |
| iOS social UI integration | Future | iOS work |

---

## 3. What Was Implemented

### New Endpoint: GET /users/discover

Returns a list of suggested users the current user might want to follow.

**Features:**
- Personalized suggestions based on social graph
- Multiple scoring factors
- Human-readable "suggestion reason" for each user
- Excludes users already followed
- Excludes the current user

---

## 4. User Discovery Algorithm

### Scoring System

Each potential suggestion is scored based on multiple factors:

| Factor | Points | Description |
|--------|--------|-------------|
| **Mutual follows** | 100 per connection | Users followed by people you follow ("friends of friends") |
| **Similar streak** | 50 | Users with similar current streak (±50% or ±3 days) |
| **Recently active** | 30 | Users who planked in the last 7 days |
| **Popularity** | follower_count / 10 (max 20) | Base score from follower count |

### Suggestion Reasons

The API returns a human-readable reason for each suggestion:

| Condition | Reason Text |
|-----------|-------------|
| 1 mutual follow | "Followed by someone you follow" |
| N mutual follows | "Followed by N people you follow" |
| Similar streak | "Similar streak level" |
| Recently active | "Recently active" |
| Fallback | "Popular in the community" |

### Exclusions

The algorithm excludes:
1. The current user (yourself)
2. Users you already follow
3. Deleted users (`deleted_at IS NOT NULL`)

### SQL Implementation

The query uses CTEs (Common Table Expressions) for clarity:

```sql
WITH 
  -- Users the current user follows
  my_following AS (
    SELECT following_id FROM follows WHERE follower_id = ?
  ),
  -- "Friends of friends": users followed BY people you follow
  friends_of_friends AS (
    SELECT 
      f.following_id as user_id, 
      COUNT(DISTINCT f.follower_id) as mutual_count
    FROM follows f
    WHERE f.follower_id IN (SELECT following_id FROM my_following)
      AND f.following_id != ?
      AND f.following_id NOT IN (SELECT following_id FROM my_following)
    GROUP BY f.following_id
  )
SELECT 
  u.*,
  COALESCE(fof.mutual_count, 0) as mutual_count,
  (
    COALESCE(fof.mutual_count, 0) * 100 +
    CASE WHEN u.current_streak BETWEEN ? AND ? THEN 50 ELSE 0 END +
    CASE WHEN u.last_plank_date >= ? THEN 30 ELSE 0 END +
    MIN(u.follower_count / 10, 20)
  ) as score
FROM users u
LEFT JOIN friends_of_friends fof ON u.id = fof.user_id
WHERE u.id != ?
  AND u.deleted_at IS NULL
  AND u.id NOT IN (SELECT following_id FROM my_following)
ORDER BY score DESC, u.follower_count DESC
LIMIT ?
```

---

## 5. API Endpoints

### Complete Social Endpoints

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| GET | `/users/me` | Required | Get current user's profile |
| PATCH | `/users/me` | Required | Update current user's profile |
| GET | `/users/search?q=` | Required | Search users by name/username |
| GET | `/users/discover` | Required | Get suggested users to follow |
| GET | `/users/:id` | Optional | Get user's public profile |
| POST | `/users/:id/follow` | Required | Follow a user |
| DELETE | `/users/:id/follow` | Required | Unfollow a user |
| GET | `/users/:id/followers` | Optional | Get user's followers |
| GET | `/users/:id/following` | Optional | Get users that user follows |

### GET /users/discover

**Request:**
```
GET /users/discover?limit=10
Authorization: Bearer <token>
```

**Response (200):**
```json
{
  "success": true,
  "data": {
    "users": [
      {
        "id": "abc123",
        "displayName": "Jane Doe",
        "username": "janedoe",
        "profileImageUrl": "profiles/abc123/avatar_123.jpg",
        "currentStreak": 15,
        "longestStreak": 30,
        "totalPlanks": 45,
        "longestPlankSeconds": 180,
        "followerCount": 25,
        "followingCount": 12,
        "suggestionReason": "Followed by 3 people you follow",
        "mutualFollows": 3
      }
    ],
    "meta": {
      "yourStreak": 10,
      "streakRange": { "min": 5, "max": 15 }
    }
  }
}
```

**Parameters:**
- `limit` (optional): Number of suggestions to return (default: 10, max: 30)

---

## 6. Testing Results

### Local Tests

| Test | Expected | Result |
|------|----------|--------|
| Alice follows Bob, Bob follows Carol | Carol suggested to Alice with "Followed by someone you follow" | Pass |
| Alice follows Carol | Carol no longer in suggestions | Pass |
| No auth header | 401 AUTH_REQUIRED | Pass |
| New user with no follows | Returns popular/active users | Pass |

### Production Tests

| Test | Result |
|------|--------|
| New user discover | Returns suggestions with "Recently active" and "Popular in the community" reasons |
| Endpoint accessible | Pass |

---

## 7. Files Modified

| File | Change |
|------|--------|
| `src/routes/users.ts` | Added `GET /users/discover` endpoint with discovery algorithm |

---

## 8. Next Steps

### Phase 6: Groups (Week 6-7)

| Task | Priority |
|------|----------|
| Group CRUD API | High |
| Membership management | High |
| Join modes (open, request) | High |
| Admin functionality | High |
| Invite code system | Medium |
| Group leaderboards | Medium |
| Join request workflow | Medium |
| Member removal | Medium |

**Note:** Group image upload was already implemented in Phase 4 (`POST /media/group/:groupId`).

---

## Appendix: iOS Integration Guide

### Fetching Suggestions

```swift
func fetchSuggestions() async throws -> [SuggestedUser] {
    var request = URLRequest(url: URL(string: "\(baseURL)/users/discover?limit=10")!)
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    
    let (data, _) = try await URLSession.shared.data(for: request)
    let response = try JSONDecoder().decode(DiscoverResponse.self, from: data)
    return response.data.users
}

struct SuggestedUser: Decodable {
    let id: String
    let displayName: String
    let username: String?
    let profileImageUrl: String?
    let currentStreak: Int
    let followerCount: Int
    let suggestionReason: String
    let mutualFollows: Int
}
```

### Displaying Suggestions

The `suggestionReason` field provides ready-to-use text for the UI:
- "Followed by someone you follow"
- "Followed by 3 people you follow"
- "Similar streak level"
- "Recently active"
- "Popular in the community"

---

## Document History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-03-15 | Initial version - Phase 5 complete |
