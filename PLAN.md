# Plank Challenge - App Plan

## Overview

**Plank Challenge** is an iOS mobile application designed to help users build a daily plank exercise habit. The core concept is simple: one plank per day. The app tracks each user's plank sessions over time, monitoring whether their plank duration is increasing, plateauing, or declining.

Beyond personal tracking, the app has a strong social/competitive element with leaderboards at multiple levels—global, group, and custom friend groups.

## Core Concept

- Users perform **one plank per day**
- Track plank duration over time to measure progress
- Social competition through leaderboards
- Timezone-aware: each user submits their daily plank by end of day in their local timezone

## Development Approach

### Phase 1: Core Plank Experience (START HERE)
- Build the iOS app with **mock data** for groups, other users, and achievements
- Focus on creating an **amazing UX for planking and tracking your own data**
- No real backend/authentication yet — just the experience
- Validate the core user experience before building infrastructure

### Phase 2: Additional Features & Real Functionality
- Replace mock data with real functionality
- Implement authentication and backend
- Build out group features, leaderboards, etc.

## Features

### 1. Personal Progress Tracking (Always Available)
- The app **always tracks your personal progress**, regardless of group membership
- Users can view their own historical data at any time:
  - How planks have increased/decreased over time
  - When they stopped doing planks
  - Overall progress trends

### 2. Streaks System (Duolingo-style)

#### Streak Tracking
- Track consecutive days of plank completion
- Streak is the core motivational mechanic

#### Streak Freeze Tokens
- Users get **2 "streak freeze" tokens** when they join the app
- If a user misses a day, a token is **automatically used** to preserve the streak
- Tokens protect against losing streaks due to occasional missed days
- **Maximum of 2 tokens** at any time

**Token Replenishment:**
- Earn **1 token** upon reaching a **20-day streak**
- Token is only awarded if user has fewer than 2 tokens
- If user already has 2 tokens, no additional token is given
- Future consideration: subscription model may modify token mechanics

**Token Usage Notification:**
- When a token is used to save a streak, user receives a **push notification**
- Example: "Your streak was saved! 1 freeze token used. You have 1 remaining."
- Serves as a reminder to not miss the next day

#### Streak Badges
- Award badges for streak milestones:
  - **7 days** (1 week)
  - **14 days** (2 weeks)
  - **30 days** (1 month)
  - **60 days** (2 months)
  - **90 days** (3 months)
  - **180 days** (6 months)
  - **365 days** (1 year)
- Badges displayed on user profile
- Recognition for long-term commitment
- Badges are permanent once earned (kept even if streak is later lost)

### 3. Plank Types
Users can select which type of plank they are performing:
- **Elbow plank** (forearms on ground)
- **Straight arm plank** (hands on ground, arms extended)
- **Parallettes plank** (using parallettes)

*Note: Limited to these three types for initial release. Additional plank variations may be added in future updates.*

#### Plank Type Settings
- User sets a **preferred plank type** in their profile settings
- When starting a new plank, preferred type is **pre-selected**
- User confirms or changes the type before/during session
- Each session records the plank type used

#### Editing Past Sessions
- Users can **edit past plank sessions** to correct the plank type
- Example: Logged yesterday's plank as parallettes, but actually did straight arm — can go back and fix it

### 4. Plank Session Input Methods

#### Mode 1: In-App Timer
- User presses "Start Plank" button
- Timer begins counting up
- **Display static image** showing correct form for the selected plank type:
  - Elbow plank image (if elbow selected)
  - Straight arm plank image (if straight arm selected)
  - Parallettes plank image (if parallettes selected)
- **Timer shows milliseconds** in addition to minutes and seconds
- **Screen stays awake** — prevent phone from sleeping during plank session
- User presses button to stop when finished
- **No pause option** — only stop (must start over if stopped early)
- Duration is recorded automatically
- **Maximum duration: 1 hour** (configurable for future adjustment as needed)

#### One Plank Per Day Rule
- Users can only log **one plank per day**
- If a user makes a mistake (stopped too early, app crashed, etc.):
  - They can **delete their plank entry** for that day
  - They can then submit a new plank
  - Deletion only allowed **until end of that day** (user's timezone)
- After the day ends, the entry is locked and cannot be deleted/replaced

#### Mode 2: Manual Entry
- User manually enters their plank duration
- For users who plank without having the app open
- **Can only add for today** — no backdating to past dates
- Must submit before end of day (user's timezone) or lose the option
- Same deletion rules apply (can delete and re-enter until end of day)

#### Honesty & Guardrails (Honor System + Soft Guardrails)

**Honor System:**
- Display a disclaimer prominently in the app: "All statistics and charts are based on users being honest with themselves about their planks"

**Soft Guardrails:**
- **Minimum plank duration: 10 seconds** — anything less doesn't count as a valid plank
- **Maximum plank duration: 1 hour** — already enforced by timer
- **Suspicious pattern flagging** — flag accounts with unusual patterns (e.g., consistent 59-minute planks daily) for review
- **Report User option** — allow community to flag obvious cheaters

*More sophisticated verification (motion detection, photo/video) may be considered in future if cheating becomes a significant problem.*

### 5. Global Leaderboards

Users are **automatically enrolled** upon creating an account. There are **two default global leaderboards**:

#### Leaderboard 1: Active Streak
- Ranks users by their **current active streak only**
- If a user loses their streak, they are **removed from this leaderboard entirely**
- Rewards ongoing consistency — you must keep planking to stay on the board
- Highly dynamic: changes daily based on who is actively maintaining streaks

#### Leaderboard 2: Longest Plank
- Ranks users by their longest single plank duration
- Rewards endurance and personal bests
- **Requires active streak** to appear on this leaderboard
- If a user loses their streak, they are removed from this leaderboard too

### 6. Groups & Custom Leaderboards

#### Multiple Group Membership
- Users can be **members of multiple groups simultaneously**
- **Maximum of 50 groups** per user (configurable, not hard-coded)
- When a user logs a plank, it is **automatically reflected in all groups** they belong to
- User can view their ranking/performance across all their groups
- Example: User is in "Cloudflare Plankers" (work) and "Weekend Warriors" (friends) — one plank entry updates both

#### Group Leaderboards
- Each group has **two leaderboards** (same as global):
  1. **Active Streak** — ranks group members by current streak
  2. **Longest Plank** — ranks group members by longest plank duration
- Same rules apply: **active streak required** to appear on either leaderboard
- Members removed from group leaderboards if they lose their streak

**Time Filters:**
- **All-time** — cumulative since joining the group
- **Last 7 days** — rolling week
- **Last 30 days** — rolling month

*No data is deleted — filters are just different views of the same data.*

#### Group Types

**Private Groups:**
- Not searchable/discoverable
- Creator sends invites to other users
- Invites sent via email
- Invited users must accept to join

**Public Groups:**
- Searchable by any app user
- Appears in group search/listing
- **Two join modes** (configured by admin at group creation):
  1. **Open join** — anyone can join directly
  2. **Request to join** — users request access, admin must approve

**Group Size Limit:**
- **Maximum of 1,000 members** per group (configurable, not hard-coded)

#### Group Discovery
- Search for groups by name
- Browse list of all public groups

#### Group Naming
- Group names must be **unique** (no duplicates allowed)

#### Group Images
- Group admin can upload a picture/logo for the group

#### Group Administration

**Admin (Creator) Powers:**
- Close/delete the group
- Upload/change group image
- Approve/deny join requests (for request-to-join groups)
- **Promote other members to admin** (multiple admins allowed)
- **Remove/kick members** from the group
- Manage group settings

**Multiple Admins:**
- A group can have **multiple admins**
- **All admins are equal** — no distinction between creator and promoted admins
- Any admin can perform all admin actions (including deleting the group)
- Admin rights can be delegated to other members

**Admin Leaving:**
- If an admin wants to leave:
  - If there are other admins, they can simply leave
  - If they are the **only admin**, they are given options:
    1. **Delegate admin to specific member** — choose who becomes admin
    2. **Auto-delegate** — defaults to the **earliest member** (first person who joined the group)
    3. **Delete the group** — if they don't want to delegate
- Exception: If admin is the only member, they can simply delete the group

**Membership Tracking:**
- Track **join date** for each member
- Used for auto-delegation (earliest member becomes admin by default)

**Group Deletion:**
- All members must be notified when a group is deleted

**Member Actions:**
- Any member can leave a group at any time

**Leaving/Removal Behavior:**
- When a member leaves or is removed/kicked:
  - Removed from that group's leaderboards immediately
  - **Global streak and personal stats are NOT affected** — only group membership changes
  - User is notified of the removal
- If they rejoin the same group later:
  - They **start fresh in that group** — group-specific history resets
  - Personal plank data is never deleted (it belongs to the user)

### 7. User Profiles

#### Profile Information
- Profile picture (user-uploaded)
- Short profile description/bio
- Optional: Link to social media or LinkedIn
- Preferred plank type setting
- Badges earned (streak milestones, etc.)

#### Profile Visibility
- User profiles are **public** within the app
- Other users can view:
  - Full plank history
  - Statistics (streak, longest plank, etc.)
  - Badges earned
  - Profile info (bio, social links)

#### Social Features
- **No social features for initial release** (comments, reactions, cheering, etc.)
- May be added in future updates

#### Follow System (Duolingo-style)
- Users can **follow other users**
- View who follows you and whom you are following
- See followed users' activity and progress for inspiration
- Following is one-way (no approval needed — similar to Twitter/Instagram public follows)

### 8. Notifications

#### Push Notifications / Reminders
- **Daily reminder** to complete plank
  - Default time: 3:00 PM (user's local timezone)
  - User can customize reminder time
  - User can disable reminders entirely
- **Streak freeze token used** notification
  - Alerts user when a token was used to save their streak
  - Reminds them not to miss the next day
- Additional push notification types may be added in future updates

#### In-App Notification Center
Users receive notifications for group-related events:
- Joined a group successfully
- Removed/kicked from a group
- Group was deleted
- Join request approved/denied (for request-to-join groups)
- Promoted to admin
- Other relevant group activity

*Notifications visible when user opens the app, ensuring they stay informed of changes.*

### 9. Authentication (Phase 2)
Multiple login options:
- **Google/Gmail login**
- **Facebook login**
- **Email/password account creation** (we manage credentials)

### 10. Monetization

**Initial Launch:**
- **Completely free** — no paid features

**Future Consideration (1,000+ users):**
- Subscription model may be introduced
- Potential premium features TBD (e.g., extra freeze tokens, advanced stats)
- Design app architecture to support future monetization without major refactoring

## Technical Requirements

### Platform
- iOS (native mobile application)

### Design & UI
- **Native iOS look and feel** — app should feel like a first-party Apple app
- Use iOS Human Interface Guidelines / Apple Design System
- **SwiftUI** — modern, declarative framework for faster development
- **Minimum iOS version: iOS 16** — covers ~90%+ of active devices
- Standard iOS navigation patterns, typography, spacing, and interactions
- **Visual inspiration: Apple Health app** — lightweight, beautiful, excellent statistics display
- Screenshots to be added later to demonstrate specific component styles

### Analytics
- Analytics tracking to be implemented (Phase 2)
- **Platform: Amplitude**
- Track user behavior, feature usage, engagement metrics
- Not required for initial launch — add later

### Backend Needs (Phase 2)
- User accounts/authentication (Google, Facebook, email/password)
- Database for:
  - User profiles (picture, bio, social links, preferred plank type)
  - Plank session records (timestamp, duration, timezone, input method, plank type)
  - Streak data (current streak, longest streak, freeze tokens remaining)
  - Badges earned
  - Groups (membership, metadata, type, image, join settings)
  - Group membership records (user, group, join date, admin status)
  - Notifications (group events, system messages)
  - Leaderboard calculations
- Push notification service (APNs)
- Email service for group invitations
- Image storage for user avatars and group images
- Password management and security for email/password accounts

### Offline Support
**Offline-capable with sync:**
- Plank timer works fully offline
- Planks stored locally on device with timestamp
- Syncs to server when connection is restored

**Multi-day offline handling:**
- Each plank recorded with **local date/time and timezone**
- Server accepts backdated planks based on when they were actually recorded
- Streak calculated correctly based on actual dates performed
- Streak freeze tokens applied retroactively if needed

**Conflict handling:**
- Device timestamp is trusted (honor system)
- If duplicate entries exist for same day, keep the one recorded first

**Features unavailable offline:**
- Cannot view leaderboards
- Cannot view other users' profiles
- Cannot join/leave groups
- Push notifications won't work until back online

### Key Technical Considerations
- Timezone handling for daily plank deadlines
- Real-time or near-real-time leaderboard updates
- Group invitation/join flow
- Unique group name validation
- Admin delegation workflow
- Streak freeze token logic and auto-application
- Local data storage and sync mechanism

## Open Questions

*All major questions have been resolved.*




## Implementation Notes

*To be added as we progress...*
