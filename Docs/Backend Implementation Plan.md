# Plank Challenge - Backend Implementation Plan

**Version:** 1.0  
**Created:** March 14, 2026  
**Last Updated:** March 14, 2026  
**Author:** Leo Bacevicius + Claude

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Architecture Overview](#2-architecture-overview)
3. [Technology Stack](#3-technology-stack)
4. [Database Schema](#4-database-schema)
5. [API Design](#5-api-design)
6. [Authentication](#6-authentication)
7. [Offline Sync Strategy](#7-offline-sync-strategy)
8. [Media Storage](#8-media-storage)
9. [Real-time Features](#9-real-time-features)
10. [Implementation Phases](#10-implementation-phases)
11. [Security Considerations](#11-security-considerations)
12. [Cost Estimates](#12-cost-estimates)
13. [Open Questions](#13-open-questions)

---

## 1. Executive Summary

### Project Goal
Build a production-ready backend for Plank Challenge, enabling user authentication, cross-device sync, social features, and leaderboards while maintaining full offline functionality.

### Key Decisions Made
| Decision | Choice | Rationale |
|----------|--------|-----------|
| Infrastructure | Cloudflare Stack | Familiarity, edge-first, serverless |
| Authentication | Apple + Google + Email | Full coverage, App Store compliance |
| Guest Mode | No | Account required to use app |
| Offline Support | Essential | Must work fully offline, sync when connected |
| Sync Strategy | Event-sourcing | Each plank is a unique event, no conflicts |
| Deletion Policy | Today only | Users can only delete planks from current day |

### Timeline Overview
- **Total Estimated Duration:** 8-10 weeks
- **Phase 1-2 (Foundation + Core):** Weeks 1-3
- **Phase 3-4 (Achievements + Media):** Weeks 3-4
- **Phase 5-6 (Social + Groups):** Weeks 5-7
- **Phase 7-8 (Leaderboards + Polish):** Weeks 7-10

---

## 2. Architecture Overview

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        iOS App (SwiftUI)                         │
│                                                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌────────────────────────┐ │
│  │  SwiftData   │  │  SyncEngine  │  │  AuthManager           │ │
│  │  (Local DB)  │  │  (Offline)   │  │  (Apple/Google/Email)  │ │
│  └──────────────┘  └──────────────┘  └────────────────────────┘ │
│                                                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌────────────────────────┐ │
│  │  APIClient   │  │  MediaCache  │  │  PushNotifications     │ │
│  │  (HTTP)      │  │  (Images)    │  │  (APNs)                │ │
│  └──────────────┘  └──────────────┘  └────────────────────────┘ │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             │ HTTPS (REST + JSON)
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Cloudflare Edge Network                       │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                    Cloudflare Workers                       │ │
│  │                                                             │ │
│  │  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐           │ │
│  │  │  Auth   │ │ Planks  │ │ Groups  │ │ Social  │           │ │
│  │  │ Routes  │ │ Routes  │ │ Routes  │ │ Routes  │           │ │
│  │  └─────────┘ └─────────┘ └─────────┘ └─────────┘           │ │
│  │                                                             │ │
│  │  ┌─────────┐ ┌─────────┐ ┌─────────┐                       │ │
│  │  │ Users   │ │ Badges  │ │ Search  │                       │ │
│  │  │ Routes  │ │ Routes  │ │ Routes  │                       │ │
│  │  └─────────┘ └─────────┘ └─────────┘                       │ │
│  │                                                             │ │
│  │  ┌──────────────────────────────────────────────────────┐  │ │
│  │  │              Middleware Layer                         │  │ │
│  │  │  - JWT Validation                                     │  │ │
│  │  │  - Rate Limiting                                      │  │ │
│  │  │  - Request Logging                                    │  │ │
│  │  │  - Error Handling                                     │  │ │
│  │  └──────────────────────────────────────────────────────┘  │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                   Durable Objects                           │ │
│  │  - Leaderboard (real-time rankings)                        │ │
│  │  - GroupActivity (live updates)                            │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                       Queues                                │ │
│  │  - Badge calculation                                        │ │
│  │  - Push notification delivery                               │ │
│  │  - Streak recalculation                                     │ │
│  │  - Email sending                                            │ │
│  └────────────────────────────────────────────────────────────┘ │
└────────────────────────────┬────────────────────────────────────┘
                             │
         ┌───────────────────┼───────────────────┐
         ▼                   ▼                   ▼
    ┌─────────┐         ┌─────────┐         ┌─────────┐
    │   D1    │         │   R2    │         │   KV    │
    │ SQLite  │         │ Objects │         │  Cache  │
    └─────────┘         └─────────┘         └─────────┘
    
    Tables:             Buckets:            Namespaces:
    - users             - profile-images    - sessions
    - plank_sessions    - group-images      - leaderboards
    - badges            - media-gallery     - rate-limits
    - groups                                - feature-flags
    - group_members
    - follows
    - notifications
    - devices
```

### Request Flow Example

```
User completes plank → App saves to SwiftData (local)
                     → SyncEngine queues sync request
                     → When online: POST /api/planks
                     → Worker validates JWT
                     → Worker inserts into D1
                     → Queue: Calculate badges
                     → Queue: Update leaderboard
                     → Response: { id, serverTimestamp }
                     → App marks as synced
```

---

## 3. Technology Stack

### Cloudflare Services

| Service | Purpose | Limits (Free Tier) |
|---------|---------|-------------------|
| **Workers** | API endpoints, business logic | 100K requests/day |
| **D1** | Primary database (SQLite) | 5GB storage, 5M rows read/day |
| **R2** | Image/media storage | 10GB storage, 10M Class A ops/month |
| **KV** | Session tokens, caches | 100K reads/day, 1K writes/day |
| **Queues** | Background jobs | 1M messages/month |
| **Durable Objects** | Real-time state | 1M requests/month |

### iOS App Dependencies

| Library | Purpose |
|---------|---------|
| **SwiftData** | Local persistence |
| **AuthenticationServices** | Sign in with Apple |
| **GoogleSignIn** | Sign in with Google |
| **URLSession** | HTTP networking |
| **BackgroundTasks** | Background sync |

### Development Tools

| Tool | Purpose |
|------|---------|
| **Wrangler** | Cloudflare CLI |
| **Miniflare** | Local development |
| **Hono** | Worker routing framework |
| **Drizzle ORM** | Type-safe D1 queries |
| **Zod** | Request validation |

---

## 4. Database Schema

### Entity Relationship Diagram

```
┌─────────────┐       ┌─────────────────┐       ┌─────────────┐
│   users     │       │ plank_sessions  │       │   badges    │
├─────────────┤       ├─────────────────┤       ├─────────────┤
│ id (PK)     │──┐    │ id (PK)         │       │ id (PK)     │
│ email       │  │    │ user_id (FK)    │───────│ user_id (FK)│
│ display_name│  │    │ client_id       │       │ badge_type  │
│ ...         │  │    │ duration_seconds│       │ earned_at   │
└─────────────┘  │    │ plank_type      │       └─────────────┘
                 │    │ input_method    │
                 │    │ performed_at    │
                 │    │ ...             │
                 │    └─────────────────┘
                 │
                 │    ┌─────────────────┐       ┌─────────────────┐
                 │    │     groups      │       │  group_members  │
                 │    ├─────────────────┤       ├─────────────────┤
                 │    │ id (PK)         │───┐   │ id (PK)         │
                 │    │ name            │   │   │ group_id (FK)   │
                 │    │ created_by (FK) │   │   │ user_id (FK)    │
                 │    │ ...             │   │   │ role            │
                 │    └─────────────────┘   │   │ joined_at       │
                 │                          │   └─────────────────┘
                 │                          │
                 │    ┌─────────────────┐   │
                 └────│     follows     │   │
                      ├─────────────────┤   │
                      │ follower_id(FK) │   │
                      │ following_id(FK)│   │
                      │ created_at      │   │
                      └─────────────────┘   │
                                            │
                      ┌─────────────────────┘
                      │
                      ▼
┌─────────────────┐       ┌─────────────────┐
│  notifications  │       │     devices     │
├─────────────────┤       ├─────────────────┤
│ id (PK)         │       │ id (PK)         │
│ user_id (FK)    │       │ user_id (FK)    │
│ type            │       │ device_token    │
│ ...             │       │ platform        │
└─────────────────┘       └─────────────────┘
```

### Table Definitions

#### users
```sql
CREATE TABLE users (
    id TEXT PRIMARY KEY,                    -- UUID
    email TEXT UNIQUE NOT NULL,
    email_verified INTEGER DEFAULT 0,
    display_name TEXT NOT NULL,
    username TEXT UNIQUE,                   -- @handle for discovery
    location TEXT,
    bio TEXT,
    profile_image_url TEXT,                 -- R2 URL
    
    -- Auth providers
    apple_id TEXT UNIQUE,
    google_id TEXT UNIQUE,
    password_hash TEXT,                     -- For email auth
    
    -- Plank preferences
    preferred_plank_type TEXT DEFAULT 'elbow',
    
    -- Streak data (denormalized for performance)
    current_streak INTEGER DEFAULT 0,
    longest_streak INTEGER DEFAULT 0,
    freeze_tokens INTEGER DEFAULT 2,
    last_plank_date TEXT,                   -- ISO date string
    
    -- Stats (denormalized)
    total_planks INTEGER DEFAULT 0,
    total_plank_seconds REAL DEFAULT 0,
    longest_plank_seconds REAL DEFAULT 0,
    
    -- Social counts (denormalized)
    follower_count INTEGER DEFAULT 0,
    following_count INTEGER DEFAULT 0,
    
    -- Metadata
    timezone TEXT DEFAULT 'UTC',
    created_at TEXT NOT NULL,               -- ISO timestamp
    updated_at TEXT NOT NULL,
    deleted_at TEXT,                        -- Soft delete
    
    -- Indexes defined below
);

CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_apple_id ON users(apple_id);
CREATE INDEX idx_users_google_id ON users(google_id);
CREATE INDEX idx_users_current_streak ON users(current_streak DESC);
CREATE INDEX idx_users_longest_streak ON users(longest_streak DESC);
```

#### plank_sessions
```sql
CREATE TABLE plank_sessions (
    id TEXT PRIMARY KEY,                    -- Server UUID
    client_id TEXT UNIQUE NOT NULL,         -- Client UUID (for idempotency)
    user_id TEXT NOT NULL REFERENCES users(id),
    
    duration_seconds REAL NOT NULL,
    plank_type TEXT NOT NULL,               -- 'elbow', 'straightArm', 'parallettes'
    input_method TEXT NOT NULL,             -- 'timer', 'manual'
    
    performed_at TEXT NOT NULL,             -- When plank was done (user's time)
    timezone TEXT NOT NULL,
    
    -- Sync metadata
    created_at TEXT NOT NULL,               -- Server receive time
    updated_at TEXT NOT NULL,
    deleted_at TEXT,                        -- Soft delete (only today's planks)
    
    -- Indexes
    FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE INDEX idx_sessions_user_date ON plank_sessions(user_id, performed_at);
CREATE INDEX idx_sessions_client_id ON plank_sessions(client_id);
CREATE INDEX idx_sessions_user_id ON plank_sessions(user_id);
```

#### badges
```sql
CREATE TABLE badges (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL REFERENCES users(id),
    badge_type TEXT NOT NULL,               -- 'streak7', 'streak14', etc.
    earned_at TEXT NOT NULL,
    
    UNIQUE(user_id, badge_type),            -- One badge per type per user
    FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE INDEX idx_badges_user_id ON badges(user_id);
```

#### groups
```sql
CREATE TABLE groups (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    image_url TEXT,                         -- R2 URL
    
    group_type TEXT NOT NULL,               -- 'public', 'private'
    join_mode TEXT NOT NULL,                -- 'open', 'request'
    
    created_by TEXT NOT NULL REFERENCES users(id),
    
    -- Denormalized counts
    member_count INTEGER DEFAULT 1,
    
    -- Invite code for private groups
    invite_code TEXT UNIQUE,
    
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    deleted_at TEXT,
    
    FOREIGN KEY (created_by) REFERENCES users(id)
);

CREATE INDEX idx_groups_type ON groups(group_type);
CREATE INDEX idx_groups_invite_code ON groups(invite_code);
CREATE INDEX idx_groups_created_by ON groups(created_by);
```

#### group_members
```sql
CREATE TABLE group_members (
    id TEXT PRIMARY KEY,
    group_id TEXT NOT NULL REFERENCES groups(id),
    user_id TEXT NOT NULL REFERENCES users(id),
    
    role TEXT NOT NULL DEFAULT 'member',    -- 'admin', 'member'
    status TEXT NOT NULL DEFAULT 'active',  -- 'active', 'pending', 'banned'
    
    joined_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    
    UNIQUE(group_id, user_id),
    FOREIGN KEY (group_id) REFERENCES groups(id),
    FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE INDEX idx_group_members_group ON group_members(group_id);
CREATE INDEX idx_group_members_user ON group_members(user_id);
CREATE INDEX idx_group_members_status ON group_members(group_id, status);
```

#### follows
```sql
CREATE TABLE follows (
    id TEXT PRIMARY KEY,
    follower_id TEXT NOT NULL REFERENCES users(id),
    following_id TEXT NOT NULL REFERENCES users(id),
    created_at TEXT NOT NULL,
    
    UNIQUE(follower_id, following_id),
    CHECK(follower_id != following_id),     -- Can't follow yourself
    FOREIGN KEY (follower_id) REFERENCES users(id),
    FOREIGN KEY (following_id) REFERENCES users(id)
);

CREATE INDEX idx_follows_follower ON follows(follower_id);
CREATE INDEX idx_follows_following ON follows(following_id);
```

#### notifications
```sql
CREATE TABLE notifications (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL REFERENCES users(id),
    
    type TEXT NOT NULL,                     -- 'badge_earned', 'streak_freeze', etc.
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    
    related_entity_type TEXT,               -- 'badge', 'group', 'user'
    related_entity_id TEXT,
    
    is_read INTEGER DEFAULT 0,
    
    created_at TEXT NOT NULL,
    
    FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE INDEX idx_notifications_user ON notifications(user_id, created_at DESC);
CREATE INDEX idx_notifications_unread ON notifications(user_id, is_read);
```

#### devices (for push notifications)
```sql
CREATE TABLE devices (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL REFERENCES users(id),
    
    device_token TEXT NOT NULL,             -- APNs token
    platform TEXT NOT NULL,                 -- 'ios', 'ipados'
    
    app_version TEXT,
    os_version TEXT,
    device_model TEXT,
    
    last_active_at TEXT NOT NULL,
    created_at TEXT NOT NULL,
    
    UNIQUE(device_token),
    FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE INDEX idx_devices_user ON devices(user_id);
CREATE INDEX idx_devices_token ON devices(device_token);
```

#### join_requests (for request-to-join groups)
```sql
CREATE TABLE join_requests (
    id TEXT PRIMARY KEY,
    group_id TEXT NOT NULL REFERENCES groups(id),
    user_id TEXT NOT NULL REFERENCES users(id),
    
    status TEXT NOT NULL DEFAULT 'pending', -- 'pending', 'approved', 'denied'
    reviewed_by TEXT REFERENCES users(id),
    reviewed_at TEXT,
    
    created_at TEXT NOT NULL,
    
    UNIQUE(group_id, user_id),
    FOREIGN KEY (group_id) REFERENCES groups(id),
    FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE INDEX idx_join_requests_group ON join_requests(group_id, status);
```

---

## 5. API Design

### Base URL
```
Production: https://api.plankchallenge.app
Development: http://localhost:8787
```

### Authentication Header
```
Authorization: Bearer <jwt_token>
```

### Standard Response Format
```json
{
    "success": true,
    "data": { ... },
    "meta": {
        "timestamp": "2026-03-14T12:00:00Z",
        "requestId": "req_abc123"
    }
}
```

### Error Response Format
```json
{
    "success": false,
    "error": {
        "code": "VALIDATION_ERROR",
        "message": "Invalid email format",
        "details": { ... }
    },
    "meta": {
        "timestamp": "2026-03-14T12:00:00Z",
        "requestId": "req_abc123"
    }
}
```

### API Endpoints

#### Authentication

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/auth/apple` | Sign in with Apple |
| POST | `/auth/google` | Sign in with Google |
| POST | `/auth/register` | Email registration |
| POST | `/auth/login` | Email login |
| POST | `/auth/logout` | Logout (invalidate token) |
| POST | `/auth/refresh` | Refresh access token |
| POST | `/auth/forgot-password` | Request password reset |
| POST | `/auth/reset-password` | Reset password with token |
| DELETE | `/auth/account` | Delete account |

#### Users

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/users/me` | Get current user profile |
| PATCH | `/users/me` | Update current user profile |
| POST | `/users/me/avatar` | Upload profile image |
| DELETE | `/users/me/avatar` | Remove profile image |
| GET | `/users/:id` | Get user public profile |
| GET | `/users/search?q=` | Search users by name/username |

#### Planks

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/planks` | Create plank session |
| GET | `/planks` | List user's plank sessions |
| GET | `/planks/:id` | Get single plank session |
| DELETE | `/planks/:id` | Delete plank (today only) |
| GET | `/planks/sync?since=` | Sync planks since timestamp |
| GET | `/planks/stats` | Get plank statistics |

#### Streaks

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/streaks/me` | Get current streak info |
| POST | `/streaks/freeze` | Use freeze token |

#### Badges

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/badges` | List earned badges |
| GET | `/badges/available` | List all available badges |

#### Groups

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/groups` | Create group |
| GET | `/groups` | List user's groups |
| GET | `/groups/discover` | Discover public groups |
| GET | `/groups/:id` | Get group details |
| PATCH | `/groups/:id` | Update group (admin) |
| DELETE | `/groups/:id` | Delete group (admin) |
| POST | `/groups/:id/join` | Join group |
| POST | `/groups/:id/leave` | Leave group |
| GET | `/groups/:id/members` | List group members |
| POST | `/groups/:id/members/:userId/promote` | Promote to admin |
| POST | `/groups/:id/members/:userId/demote` | Demote from admin |
| DELETE | `/groups/:id/members/:userId` | Remove member (admin) |
| GET | `/groups/:id/leaderboard` | Group leaderboard |
| GET | `/groups/:id/requests` | List join requests (admin) |
| POST | `/groups/:id/requests/:id/approve` | Approve request |
| POST | `/groups/:id/requests/:id/deny` | Deny request |
| POST | `/groups/join/:inviteCode` | Join via invite code |

#### Social

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/users/:id/follow` | Follow user |
| DELETE | `/users/:id/follow` | Unfollow user |
| GET | `/users/:id/followers` | List followers |
| GET | `/users/:id/following` | List following |

#### Leaderboards

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/leaderboards/streak` | Global streak leaderboard |
| GET | `/leaderboards/duration` | Global longest plank leaderboard |

#### Notifications

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/notifications` | List notifications |
| POST | `/notifications/:id/read` | Mark as read |
| POST | `/notifications/read-all` | Mark all as read |
| GET | `/notifications/unread-count` | Get unread count |

#### Devices (Push Notifications)

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/devices` | Register device token |
| DELETE | `/devices/:token` | Unregister device |

---

## 6. Authentication

### JWT Token Structure

```json
{
    "header": {
        "alg": "HS256",
        "typ": "JWT"
    },
    "payload": {
        "sub": "user_uuid",
        "email": "user@example.com",
        "iat": 1710424800,
        "exp": 1710511200,
        "jti": "unique_token_id"
    }
}
```

### Token Lifecycle

| Token Type | Lifespan | Storage |
|------------|----------|---------|
| Access Token | 1 hour | iOS Keychain |
| Refresh Token | 30 days | iOS Keychain |

### Sign in with Apple Flow

```
1. iOS App: Request Apple Sign-In
2. Apple: Return identityToken + authorizationCode
3. iOS App: POST /auth/apple { identityToken, authorizationCode }
4. Worker: Verify token with Apple's public keys
5. Worker: Extract email + Apple ID
6. Worker: Create/update user in D1
7. Worker: Generate JWT tokens
8. Worker: Store refresh token in KV
9. Return: { accessToken, refreshToken, user }
```

### Sign in with Google Flow

```
1. iOS App: Request Google Sign-In
2. Google: Return idToken
3. iOS App: POST /auth/google { idToken }
4. Worker: Verify token with Google's public keys
5. Worker: Extract email + Google ID
6. Worker: Create/update user in D1
7. Worker: Generate JWT tokens
8. Worker: Store refresh token in KV
9. Return: { accessToken, refreshToken, user }
```

### Email Authentication Flow

```
Registration:
1. POST /auth/register { email, password, displayName }
2. Hash password with Argon2
3. Store user with email_verified = false
4. Send verification email (via Queue)
5. Return: { accessToken, refreshToken, user }

Login:
1. POST /auth/login { email, password }
2. Fetch user by email
3. Verify password hash
4. Generate tokens
5. Return: { accessToken, refreshToken, user }
```

### Token Refresh Flow

```
1. Access token expires
2. POST /auth/refresh { refreshToken }
3. Verify refresh token exists in KV
4. Verify not revoked/expired
5. Generate new access token
6. Optionally rotate refresh token
7. Return: { accessToken, refreshToken? }
```

### Session Invalidation

Refresh tokens stored in KV with structure:
```
Key: session:{userId}:{tokenId}
Value: { createdAt, deviceInfo, lastUsed }
TTL: 30 days
```

Logout removes the specific session. "Logout all devices" removes all sessions for user.

---

## 7. Offline Sync Strategy

### Principles

1. **Local-first**: App works fully offline
2. **Event-sourced**: Each plank is a unique event
3. **Idempotent**: Same request can be sent multiple times safely
4. **Conflict-free**: No merge conflicts by design

### Local Data Model (SwiftData)

```swift
@Model
class LocalPlankSession {
    @Attribute(.unique) var id: UUID           // Local ID
    var serverId: String?                       // Server ID (after sync)
    var clientId: UUID                          // Idempotency key
    
    var durationSeconds: TimeInterval
    var plankType: String
    var inputMethod: String
    var performedAt: Date
    var timezone: String
    
    var syncStatus: SyncStatus                  // .pending, .syncing, .synced, .failed
    var lastSyncAttempt: Date?
    var syncError: String?
    
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?                        // Soft delete
}

enum SyncStatus: String, Codable {
    case pending    // Not yet synced
    case syncing    // Currently syncing
    case synced     // Successfully synced
    case failed     // Sync failed (will retry)
}
```

### Sync Engine

```swift
class SyncEngine {
    // Called when app becomes active or network available
    func sync() async {
        // 1. Push pending changes
        await pushPendingPlanks()
        
        // 2. Pull remote changes
        await pullRemoteChanges()
        
        // 3. Recalculate local streak
        await recalculateStreak()
    }
    
    func pushPendingPlanks() async {
        let pending = fetchPlanks(where: .syncStatus == .pending)
        
        for plank in pending {
            plank.syncStatus = .syncing
            
            do {
                let response = try await api.createPlank(plank)
                plank.serverId = response.id
                plank.syncStatus = .synced
            } catch {
                plank.syncStatus = .failed
                plank.syncError = error.localizedDescription
            }
        }
    }
    
    func pullRemoteChanges() async {
        let lastSync = UserDefaults.lastSyncTimestamp
        let changes = try await api.syncPlanks(since: lastSync)
        
        for remotePlank in changes {
            if let local = findByClientId(remotePlank.clientId) {
                // Already exists locally, update serverId
                local.serverId = remotePlank.id
                local.syncStatus = .synced
            } else {
                // New from another device
                createLocalPlank(from: remotePlank)
            }
        }
        
        UserDefaults.lastSyncTimestamp = Date()
    }
}
```

### Sync Triggers

| Trigger | Action |
|---------|--------|
| App launch | Full sync |
| App becomes active | Full sync |
| Network becomes available | Push pending |
| Plank completed | Immediate push (if online) |
| Background refresh | Full sync |
| Pull-to-refresh | Full sync |

### Conflict Scenarios

| Scenario | Resolution |
|----------|------------|
| Same plank from 2 devices | Impossible (different clientIds) |
| Delete on device A, not synced | Delete syncs, server deletes |
| Delete on server, not pulled | Pull deletes local copy |
| User deletes on device A while offline, planks on device B | Both planks exist, delete syncs for that specific plank |

### Deletion Rules

```swift
func deletePlank(_ plank: LocalPlankSession) throws {
    // Rule: Can only delete today's planks
    guard Calendar.current.isDateInToday(plank.performedAt) else {
        throw PlankError.cannotDeletePastPlanks
    }
    
    if plank.syncStatus == .synced {
        // Mark for server deletion
        plank.deletedAt = Date()
        plank.syncStatus = .pending
        scheduleSync()
    } else {
        // Not yet synced, just remove locally
        modelContext.delete(plank)
    }
}
```

---

## 8. Media Storage

### R2 Bucket Structure

```
plank-challenge-media/
├── profiles/
│   └── {userId}/
│       ├── avatar.jpg              # Current avatar
│       └── avatar_thumb.jpg        # 100x100 thumbnail
├── groups/
│   └── {groupId}/
│       ├── cover.jpg               # Group image
│       └── cover_thumb.jpg         # Thumbnail
└── gallery/
    └── {userId}/
        └── {mediaId}/
            ├── original.jpg        # Full resolution
            ├── medium.jpg          # 800px wide
            └── thumb.jpg           # 200x200 thumbnail
```

### Upload Flow

```
1. iOS App: Select image
2. iOS App: Compress/resize locally (max 2048px)
3. iOS App: POST /users/me/avatar/upload-url
4. Worker: Generate presigned R2 URL
5. Return: { uploadUrl, imageKey }
6. iOS App: PUT image directly to R2 URL
7. iOS App: POST /users/me/avatar { imageKey }
8. Worker: Update user.profile_image_url
9. Worker: Queue thumbnail generation
```

### Presigned URL Generation

```typescript
async function generateUploadUrl(userId: string, type: 'avatar' | 'gallery') {
    const key = `${type}s/${userId}/${crypto.randomUUID()}.jpg`;
    
    const url = await r2.createPresignedUrl(key, {
        method: 'PUT',
        expiresIn: 300, // 5 minutes
        headers: {
            'Content-Type': 'image/jpeg',
            'Content-Length-Range': '1,5242880' // Max 5MB
        }
    });
    
    return { url, key };
}
```

### Thumbnail Generation

Using Cloudflare Images or a Worker:

```typescript
// Queue consumer for thumbnail generation
async function generateThumbnail(message: { bucket: string, key: string }) {
    const original = await r2.get(message.key);
    
    // Use sharp or similar (via Wasm)
    const thumb = await resizeImage(original, { width: 100, height: 100 });
    
    const thumbKey = message.key.replace('.jpg', '_thumb.jpg');
    await r2.put(thumbKey, thumb);
}
```

### CDN URLs

All R2 objects served via Cloudflare CDN:
```
https://media.plankchallenge.app/profiles/{userId}/avatar.jpg
```

With automatic caching and image transformations.

---

## 9. Real-time Features

### Durable Objects for Leaderboards

```typescript
export class LeaderboardDO implements DurableObject {
    private rankings: Map<string, LeaderboardEntry> = new Map();
    
    async fetch(request: Request) {
        const url = new URL(request.url);
        
        if (url.pathname === '/update') {
            const { userId, score } = await request.json();
            this.rankings.set(userId, { userId, score, updatedAt: Date.now() });
            await this.persistToD1();
            return new Response('OK');
        }
        
        if (url.pathname === '/top') {
            const top = Array.from(this.rankings.values())
                .sort((a, b) => b.score - a.score)
                .slice(0, 100);
            return Response.json(top);
        }
    }
    
    async alarm() {
        // Periodic persistence to D1
        await this.persistToD1();
    }
}
```

### KV Caching for Leaderboards

For read-heavy leaderboard queries:

```typescript
async function getLeaderboard(type: 'streak' | 'duration') {
    const cacheKey = `leaderboard:${type}`;
    
    // Try cache first
    const cached = await KV.get(cacheKey, 'json');
    if (cached) return cached;
    
    // Compute from D1
    const leaderboard = await computeLeaderboard(type);
    
    // Cache for 1 minute
    await KV.put(cacheKey, JSON.stringify(leaderboard), { expirationTtl: 60 });
    
    return leaderboard;
}
```

### Push Notifications via APNs

```typescript
// Queue consumer for push notifications
async function sendPushNotification(message: {
    userId: string,
    title: string,
    body: string,
    data?: object
}) {
    const devices = await db.query(
        'SELECT device_token FROM devices WHERE user_id = ?',
        [message.userId]
    );
    
    for (const device of devices) {
        await sendAPNs({
            deviceToken: device.device_token,
            payload: {
                aps: {
                    alert: { title: message.title, body: message.body },
                    sound: 'default',
                    badge: await getUnreadCount(message.userId)
                },
                data: message.data
            }
        });
    }
}
```

---

## 10. Implementation Phases

### Phase 1: Foundation (Week 1-2)

**Goal:** Set up infrastructure and basic auth

**Tasks:**
- [ ] Initialize Cloudflare Workers project
- [ ] Set up D1 database with schema
- [ ] Configure R2 bucket
- [ ] Set up KV namespaces
- [ ] Implement JWT utilities
- [ ] Create middleware (auth, logging, errors)
- [ ] Implement Sign in with Apple
- [ ] Implement Sign in with Google
- [ ] Implement email auth (register, login)
- [ ] User CRUD endpoints
- [ ] Basic iOS auth integration

**Deliverables:**
- Working auth flow (all 3 methods)
- User can sign up, log in, view profile
- JWT tokens stored in iOS Keychain

**Success Criteria:**
- [ ] Can create account via Apple Sign-In
- [ ] Can create account via Google Sign-In
- [ ] Can create account via email
- [ ] Can log in and receive valid JWT
- [ ] Can refresh expired token

---

### Phase 2: Core Plank Features (Week 2-3)

**Goal:** Sync plank sessions with offline support

**Tasks:**
- [ ] Implement SwiftData models in iOS
- [ ] Create SyncEngine in iOS
- [ ] Plank CRUD API endpoints
- [ ] Sync endpoint with timestamp filtering
- [ ] Server-side streak calculation
- [ ] Freeze token management
- [ ] Background sync (iOS)
- [ ] Conflict-free sync testing

**Deliverables:**
- Planks sync across devices
- App works fully offline
- Streak calculated correctly

**Success Criteria:**
- [ ] Plank on device A, appears on device B
- [ ] Offline plank syncs when online
- [ ] Streak updates after each plank
- [ ] Freeze token can be used
- [ ] Delete today's plank works

---

### Phase 3: Achievements & Progress (Week 3-4)

**Goal:** Badge system and progress tracking

**Tasks:**
- [ ] Badge calculation logic
- [ ] Queue for async badge processing
- [ ] Badge API endpoints
- [ ] In-app notification system
- [ ] Notification API endpoints
- [ ] Progress history API
- [ ] Stats aggregation

**Deliverables:**
- Badges awarded automatically
- In-app notifications work
- Progress page shows real data

**Success Criteria:**
- [ ] Badge earned at 7-day streak
- [ ] Notification appears for badge
- [ ] Progress history loads from server
- [ ] Stats are accurate

---

### Phase 4: Media & Images (Week 4)

**Goal:** Image upload and storage

**Tasks:**
- [ ] R2 bucket configuration
- [ ] Presigned URL generation
- [ ] Profile image upload flow
- [ ] Thumbnail generation (queue)
- [ ] Group image upload
- [ ] CDN URL configuration
- [ ] iOS image picker integration
- [ ] Image caching (iOS)

**Deliverables:**
- Can upload profile picture
- Can upload group image
- Images load fast via CDN

**Success Criteria:**
- [ ] Profile image uploads and displays
- [ ] Thumbnail generated automatically
- [ ] Images cached locally
- [ ] Group images work

---

### Phase 5: Social Features (Week 5-6)

**Goal:** Follow system and user discovery

**Tasks:**
- [ ] Follow/unfollow API
- [ ] Followers/following lists
- [ ] User search API
- [ ] Public user profiles
- [ ] Follower count denormalization
- [ ] User discovery algorithm
- [ ] iOS social UI integration

**Deliverables:**
- Can follow/unfollow users
- Can search for users
- Can view others' profiles

**Success Criteria:**
- [ ] Follow user, count updates
- [ ] Search finds users
- [ ] Other user's profile loads
- [ ] Followers list accurate

---

### Phase 6: Groups (Week 6-7)

**Goal:** Full group functionality

**Tasks:**
- [ ] Group CRUD API
- [ ] Membership management
- [ ] Join modes (open, request)
- [ ] Admin functionality
- [ ] Invite code system
- [ ] Group leaderboards
- [ ] Join request workflow
- [ ] Member removal
- [ ] iOS group UI integration

**Deliverables:**
- Can create/join/leave groups
- Admins can manage members
- Group leaderboards work

**Success Criteria:**
- [ ] Create public group
- [ ] Create private group with invite
- [ ] Request to join works
- [ ] Admin can approve/deny
- [ ] Group leaderboard accurate

---

### Phase 7: Leaderboards & Real-time (Week 7-8)

**Goal:** Global leaderboards and push notifications

**Tasks:**
- [ ] Global leaderboard API
- [ ] Durable Object for rankings
- [ ] KV caching layer
- [ ] APNs integration
- [ ] Device registration API
- [ ] Push notification queue
- [ ] Notification triggers
- [ ] iOS push handling

**Deliverables:**
- Global leaderboards work
- Push notifications delivered
- Real-time-ish updates

**Success Criteria:**
- [ ] Global streak leaderboard loads
- [ ] User rank displayed
- [ ] Push notification received
- [ ] Leaderboard updates after plank

---

### Phase 8: Polish & Launch (Week 8+)

**Goal:** Production readiness

**Tasks:**
- [ ] Error handling audit
- [ ] Rate limiting implementation
- [ ] Security audit
- [ ] Performance optimization
- [ ] Logging and monitoring
- [ ] Analytics integration
- [ ] Admin dashboard (optional)
- [ ] Load testing
- [ ] Documentation
- [ ] App Store preparation

**Deliverables:**
- Production-ready backend
- Monitoring in place
- App ready for review

**Success Criteria:**
- [ ] No unhandled errors
- [ ] Rate limits prevent abuse
- [ ] Latency < 200ms P95
- [ ] Can handle 1000 concurrent users

---

## 11. Security Considerations

### Authentication Security

| Concern | Mitigation |
|---------|------------|
| JWT token theft | Short expiry (1h), secure storage (Keychain) |
| Brute force login | Rate limiting, account lockout |
| Password storage | Argon2 hashing |
| Token replay | JTI (unique token ID) in blacklist |

### API Security

| Concern | Mitigation |
|---------|------------|
| Unauthorized access | JWT validation on all routes |
| SQL injection | Parameterized queries (D1) |
| XSS | JSON responses only, no HTML |
| CORS | Strict origin policy |
| Rate limiting | Per-user and per-IP limits |

### Data Security

| Concern | Mitigation |
|---------|------------|
| Data at rest | D1 encryption (Cloudflare managed) |
| Data in transit | HTTPS only |
| PII exposure | Minimal data in JWTs |
| Account deletion | Full data purge on request |

### iOS Security

| Concern | Mitigation |
|---------|------------|
| Token storage | iOS Keychain |
| Certificate pinning | Optional for high security |
| Jailbreak detection | Optional |
| Debug builds | Separate API endpoints |

---

## 12. Cost Estimates

### Cloudflare (Free Tier Limits)

| Service | Free Tier | Estimated Usage | Status |
|---------|-----------|-----------------|--------|
| Workers | 100K req/day | ~50K/day | ✅ OK |
| D1 | 5M reads/day | ~1M/day | ✅ OK |
| R2 | 10GB storage | ~2GB | ✅ OK |
| KV | 100K reads/day | ~50K/day | ✅ OK |
| Queues | 1M msg/month | ~500K/month | ✅ OK |
| Durable Objects | 1M req/month | ~200K/month | ✅ OK |

### Paid Tier Estimates (if needed)

| Service | Price | Notes |
|---------|-------|-------|
| Workers Paid | $5/mo + usage | 10M requests included |
| D1 | $0.75/M reads | Very cheap |
| R2 | $0.015/GB storage | No egress fees |
| KV | $0.50/M reads | |

### Total Estimated Monthly Cost

| Scale | Users | Est. Cost |
|-------|-------|-----------|
| Launch | 0-1K | $0 (free tier) |
| Growth | 1K-10K | $5-20/mo |
| Scale | 10K-100K | $50-200/mo |

---

## 13. Open Questions

### Technical Questions

1. **Email provider**: Which service for transactional emails (verification, password reset)?
   - Options: SendGrid, Mailgun, Resend, Cloudflare Email Workers
   
2. **Analytics**: What analytics do we need?
   - Options: Cloudflare Analytics, Plausible, custom
   
3. **Error tracking**: How to track production errors?
   - Options: Sentry, custom logging

4. **Username system**: Should users have @usernames?
   - Currently optional in schema, need to decide rules

### Product Questions

1. **Account linking**: Can user link Apple + Google to same account?

2. **Data export**: Should users be able to export their data?

3. **Account recovery**: What if user loses access to Apple/Google?

4. **Moderation**: How to handle inappropriate usernames/group names?

5. **Blocking**: Should users be able to block other users?

---

## Appendix A: API Error Codes

| Code | HTTP Status | Description |
|------|-------------|-------------|
| `AUTH_REQUIRED` | 401 | No valid auth token |
| `AUTH_EXPIRED` | 401 | Token expired |
| `AUTH_INVALID` | 401 | Token invalid |
| `FORBIDDEN` | 403 | Not authorized for action |
| `NOT_FOUND` | 404 | Resource not found |
| `VALIDATION_ERROR` | 400 | Request validation failed |
| `RATE_LIMITED` | 429 | Too many requests |
| `SERVER_ERROR` | 500 | Internal server error |
| `CONFLICT` | 409 | Resource already exists |
| `PLANK_DELETE_FORBIDDEN` | 403 | Cannot delete past planks |
| `GROUP_FULL` | 400 | Group at max capacity |
| `ALREADY_MEMBER` | 409 | Already in group |

---

## Appendix B: Webhook Events (Future)

For potential third-party integrations:

| Event | Payload |
|-------|---------|
| `plank.completed` | `{ userId, duration, type }` |
| `badge.earned` | `{ userId, badgeType }` |
| `streak.milestone` | `{ userId, days }` |
| `group.joined` | `{ userId, groupId }` |

---

## Document History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-03-14 | Initial version |

---

*This document is the source of truth for Plank Challenge backend implementation. All technical decisions should reference this plan.*
