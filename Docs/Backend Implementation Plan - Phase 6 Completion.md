# Plank Challenge - Backend Implementation Plan - Phase 6 Completion

**Version:** 1.2  
**Phase:** 6 - Groups  
**Completed:** March 15, 2026  
**Author:** Leo Bacevicius + Claude

---

## Phase 6 Summary

Phase 6 implemented the complete group functionality for Plank Challenge, enabling users to create and join groups, compete on leaderboards, and manage membership through various join modes.

---

## Implemented Features

### 1. Group CRUD Operations

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/groups` | POST | Create a new group (public or private) |
| `/groups` | GET | List current user's groups |
| `/groups/discover` | GET | Discover public groups with search |
| `/groups/:id` | GET | Get group details |
| `/groups/:id` | PATCH | Update group (admin only) |
| `/groups/:id` | DELETE | Delete group (creator only) |

**Group Types:**
- **Public**: Discoverable by all users
- **Private**: Only accessible via invite code

**Join Modes:**
- **Open**: Anyone can join directly
- **Request**: Requires admin approval

### 2. Membership Management

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/groups/:id/join` | POST | Join a group or request to join |
| `/groups/:id/leave` | POST | Leave a group |
| `/groups/:id/members` | GET | List group members |

**Membership Rules:**
- Group creator cannot leave (must delete or transfer ownership)
- Private groups require invite code to join
- Groups have a maximum capacity of 100 members

### 3. Admin Functions

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/groups/:id/members/:userId/promote` | POST | Promote member to admin |
| `/groups/:id/members/:userId/demote` | POST | Demote admin to member |
| `/groups/:id/members/:userId` | DELETE | Remove member from group |
| `/groups/:id/members/:userId/ban` | POST | Ban member (cannot rejoin) |
| `/groups/:id/members/:userId/unban` | POST | Unban previously banned member |

**Admin Rules:**
- Only admins can promote/demote/remove members
- Cannot demote or remove the group creator
- Only the creator can remove other admins
- Banned users cannot rejoin even with invite codes

### 4. Join Request Workflow

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/groups/:id/requests` | GET | List pending join requests (admin only) |
| `/groups/:id/requests/:requestId/approve` | POST | Approve join request |
| `/groups/:id/requests/:requestId/deny` | POST | Deny join request |

**Request Flow:**
1. User requests to join a "request" mode group
2. All group admins receive a notification
3. Any admin can approve or deny the request
4. User receives notification of decision

### 5. Invite Code System

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/groups/join/:inviteCode` | POST | Join group via invite code |
| `/groups/:id/invite-code/regenerate` | POST | Generate new invite code (admin only) |

**Invite Code Details:**
- 8 alphanumeric characters (excludes confusing chars like 0, O, 1, I)
- Only private groups have invite codes
- Invite codes bypass join mode (direct join)
- Admins can regenerate codes to invalidate old ones

### 6. Group Leaderboards

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/groups/:id/leaderboard` | GET | Get group leaderboard |

**Leaderboard Features:**
- Time periods: `day`, `week`, `month`, `all`
- Ranks by total plank duration
- Shows plank count and best plank time
- Includes current user's rank even if outside top N
- Private group leaderboards only visible to members

---

## Robustness Improvements (v1.1)

### First Pass Issues Found & Fixed

1. **SQL Injection in Leaderboard Date Filter**
   - **Problem**: Date values were interpolated directly into SQL strings
   - **Fix**: Refactored to use parameterized queries with CASE statements
   - **Added**: `buildDateFilter()` helper function for safe date handling

2. **Invalid Period Parameter**
   - **Problem**: Arbitrary period values were accepted without validation
   - **Fix**: Added `VALID_PERIODS` constant and validation logic
   - **Behavior**: Invalid periods default to 'week'

3. **Missing Group Existence Check in Requests**
   - **Problem**: `/groups/:id/requests` didn't verify group existed before checking admin status
   - **Fix**: Added group existence check before admin verification

4. **Banned User Handling**
   - **Problem**: No way to ban users or prevent banned users from rejoining
   - **Fix**: Added `/ban` and `/unban` endpoints, status checks in join flows

5. **Rejoin After Removal**
   - **Problem**: Users who were removed could have stale membership records
   - **Fix**: Updated UPSERT queries to properly reset `joined_at` and `role` on rejoin

6. **Invite Code Join Edge Cases**
   - **Problem**: Invite code joins didn't check for banned status
   - **Fix**: Added banned status check before allowing invite code joins

---

## Robustness Improvements (v1.2)

### Second Pass Issues Found & Fixed

7. **Member Count Race Condition / Double Counting**
   - **Problem**: UPSERT operations always incremented member_count, even when updating existing records
   - **Fix**: Check for existing membership record before deciding whether to increment count
   - **Logic**: Only increment count when `existingMembership` is null (truly new member)

8. **Approving Request for Banned User**
   - **Problem**: Approving a join request didn't check if user was banned in the meantime
   - **Fix**: Added banned status check before approval; auto-denies if user is banned

9. **Missing Group Name Sanitization**
   - **Problem**: Names with only whitespace were accepted
   - **Fix**: Added `.transform(s => s.trim())` and `.refine()` to validate non-empty after trim

10. **Stale Join Requests After Ban**
    - **Problem**: Banning a user didn't clean up their pending join requests
    - **Fix**: Added DELETE statement for join_requests in ban batch operation

11. **Discover Shows Groups User Is Banned From**
    - **Problem**: Banned users could still see groups they were banned from in discover
    - **Fix**: Added LEFT JOIN on banned status and filter `AND gm_banned.id IS NULL`

12. **Invite Code Leaked to Non-Admin Members**
    - **Problem**: `/groups` endpoint returned invite code to all members, not just admins
    - **Fix**: Check role and use `formatPublicGroup()` for non-admins (hides invite code)

13. **Misleading "Transfer Ownership" Error Message**
    - **Problem**: Error mentioned "transfer ownership" but feature doesn't exist
    - **Fix**: Simplified to "Delete the group instead."

14. **Inefficient N Database Calls for Admin Notifications**
    - **Problem**: Looping through admins with individual notification inserts
    - **Fix**: Added `createNotificationBatch()` helper using D1 batch with chunking

---

## Notifications Created

| Type | Trigger | Recipient |
|------|---------|-----------|
| `group_join_request` | User requests to join | All group admins |
| `group_joined` | Request approved | Requesting user |
| `group_request_denied` | Request denied | Requesting user |
| `group_promoted` | Promoted to admin | Promoted user |
| `group_removed` | Removed from group | Removed user |
| `group_banned` | Banned from group | Banned user |

---

## API Response Examples

### Create Group Response
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "name": "Morning Plankers",
    "description": "Early birds who plank",
    "imageUrl": null,
    "groupType": "public",
    "joinMode": "open",
    "createdBy": "user-uuid",
    "memberCount": 1,
    "inviteCode": null,
    "createdAt": "2026-03-15T12:00:00Z",
    "updatedAt": "2026-03-15T12:00:00Z",
    "isMember": true,
    "role": "admin"
  }
}
```

### Group Leaderboard Response
```json
{
  "success": true,
  "data": {
    "leaderboard": [
      {
        "rank": 1,
        "user": {
          "id": "user-uuid",
          "displayName": "Jane Doe",
          "username": "janedoe",
          "profileImageUrl": "https://...",
          "currentStreak": 45
        },
        "stats": {
          "totalDuration": 3600,
          "plankCount": 30,
          "bestPlank": 180
        }
      }
    ],
    "period": "week",
    "currentUser": {
      "rank": 5,
      "user": { ... },
      "stats": { ... }
    }
  }
}
```

---

## Files Modified

### New Files
- `backend/src/routes/groups.ts` - Complete groups route implementation (1489 lines)

### Modified Files
- `backend/src/index.ts` - Added groups route mounting
- `backend/src/types/api.ts` - Added new notification types

---

## Database Tables Used

- `groups` - Group metadata (name, type, join mode, invite code)
- `group_members` - Membership records (role, status, join date)
- `join_requests` - Join request tracking (status, reviewer, review date)
- `notifications` - Group-related notifications
- `users` - User details for member lists
- `plank_sessions` - Plank data for leaderboards

---

## Constants & Limits

| Constant | Value | Description |
|----------|-------|-------------|
| `MAX_GROUP_MEMBERS` | 100 | Maximum members per group |
| `INVITE_CODE_LENGTH` | 8 | Characters in invite code |
| Valid invite code chars | A-Z (no O, I), 2-9 (no 0, 1) | Avoids confusion |

---

## Next Steps (Phase 7)

Phase 7 will implement:
- Global leaderboards (streak, duration)
- Durable Objects for real-time rankings
- KV caching layer for performance
- APNs integration for push notifications
- Device registration API

---

## Testing Summary

All endpoints tested and working:
- Group creation (public + private)
- Group listing and discovery
- Join flows (open + request modes)
- Invite code joins
- Admin functions (promote, demote, remove, ban, unban)
- Join request approval/denial
- Group leaderboards with all time periods
- Private group access controls

---

## Document History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-03-15 | Initial Phase 6 implementation |
| 1.1 | 2026-03-15 | Robustness fixes: SQL injection prevention, period validation, ban system, rejoin handling |
| 1.2 | 2026-03-15 | Additional fixes: Member count race condition, banned user approval check, name sanitization, stale requests cleanup, discover filtering, invite code visibility, batch notifications |
