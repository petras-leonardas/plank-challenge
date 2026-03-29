# Plank Challenge - Execution Plan

This document outlines the high-level execution plan for building the Plank Challenge iOS app. The plan is divided into five phases, progressing from project setup through to full backend integration.

---

## Phase 1: Project Setup & Foundation

**Goal:** Set up the complete project structure, install all necessary dependencies, configure the development environment, and establish the foundation for the app.

### 1.1 Xcode Project Setup
- [ ] Create new Xcode project with SwiftUI
- [ ] Configure for iOS 16+ minimum deployment target
- [ ] Set up bundle identifier and app name ("Plank Challenge")
- [ ] Configure app signing and development team

### 1.2 Project Structure
- [ ] Create folder/group structure:
  ```
  PlankChallenge/
  ├── App/
  │   └── PlankChallengeApp.swift
  ├── Models/
  │   ├── PlankSession.swift
  │   ├── User.swift
  │   ├── Group.swift
  │   ├── Badge.swift
  │   ├── Streak.swift
  │   └── Notification.swift
  ├── Views/
  │   ├── Plank/
  │   ├── Progress/
  │   ├── Leaderboards/
  │   ├── Groups/
  │   ├── Profile/
  │   ├── Settings/
  │   └── Components/
  ├── ViewModels/
  ├── Services/
  │   ├── DataService.swift
  │   ├── NotificationService.swift
  │   └── TimerService.swift
  ├── Utilities/
  │   ├── Extensions/
  │   ├── Constants.swift
  │   └── Helpers.swift
  ├── Resources/
  │   ├── Assets.xcassets
  │   ├── Fonts/
  │   └── Images/
  └── MockData/
  ```

### 1.3 Dependencies & Packages
- [ ] Set up Swift Package Manager
- [ ] Add packages (if needed):
  - [ ] Charts (Swift Charts is built-in for iOS 16+)
  - [ ] Consider any other utility packages

### 1.4 Local Data Persistence
- [ ] Set up SwiftData (or Core Data) for local storage
- [ ] Create data models:
  - [ ] PlankSession (date, duration, timezone, plankType, inputMethod)
  - [ ] UserProfile (preferredPlankType, bio, etc.)
  - [ ] StreakData (currentStreak, longestStreak, freezeTokens)
  - [ ] Badge (type, dateEarned)

### 1.5 App Configuration
- [ ] Configure app icons (placeholder for now)
- [ ] Configure launch screen
- [ ] Set up Info.plist for required permissions:
  - [ ] Push notifications
  - [ ] Photo library (for future profile pictures)
- [ ] Configure app to prevent screen sleep (for timer)

### 1.6 Base UI Setup
- [ ] Set up app-wide color scheme (Apple Health-inspired)
- [ ] Define typography styles
- [ ] Create reusable UI components structure
- [ ] Set up tab bar navigation structure

### 1.7 Constants & Configuration
- [ ] Create Constants file with configurable values:
  - [ ] Minimum plank duration (10 seconds)
  - [ ] Maximum plank duration (1 hour)
  - [ ] Maximum groups per user (50)
  - [ ] Maximum members per group (1,000)
  - [ ] Default notification time (3:00 PM)
  - [ ] Streak freeze token max (2)
  - [ ] Streak milestone for token reward (20 days)
  - [ ] Badge milestone days (7, 14, 30, 60, 90, 180, 365)

---

## Phase 2: Mock Data & Individual Screens

**Goal:** Create all mock data needed to visualize the app, and build individual screens/pages as standalone components. Focus on visual design and layout, not connectivity.

### 2.1 Mock Data Creation
- [ ] Create MockData service/files:
  - [ ] Mock users (20-30 users with names, avatars, stats)
  - [ ] Mock plank history (varied durations, types, dates)
  - [ ] Mock groups (5-10 groups with members, different types)
  - [ ] Mock leaderboard data
  - [ ] Mock badges
  - [ ] Mock notifications
  - [ ] Mock following/followers

### 2.2 Plank Timer Screen
- [ ] Build timer display (MM:SS:ms format)
- [ ] Start Plank button
- [ ] Stop button
- [ ] Plank type selector (elbow, straight arm, parallettes)
- [ ] Plank form image display area
- [ ] Create/source plank form images (3 types)

### 2.3 Manual Entry Screen
- [ ] Duration input UI (minutes, seconds picker or input)
- [ ] Plank type selector
- [ ] Submit button
- [ ] Validation feedback UI

### 2.4 Progress/History Screen
- [ ] Plank history list view
- [ ] Individual plank entry row component
- [ ] Statistics summary cards (Apple Health-inspired)
  - [ ] Current streak card
  - [ ] Longest plank card
  - [ ] Total planks card
- [ ] Progress chart (duration over time)
- [ ] Trend indicator (improving/plateau/declining)

### 2.5 Streak & Tokens Display
- [ ] Streak count display component
- [ ] Freeze tokens indicator (visual tokens remaining)
- [ ] Streak calendar/heatmap view (optional)

### 2.6 Badges Screen
- [ ] Badge grid/collection view
- [ ] Individual badge component (earned vs locked state)
- [ ] Badge detail view (milestone info)

### 2.7 Leaderboards Screen
- [ ] Tab/segment control for Active Streak vs Longest Plank
- [ ] Leaderboard list view
- [ ] Leaderboard row component (rank, avatar, name, stat)
- [ ] Current user highlight in list
- [ ] "Active streak required" indicator

### 2.8 Groups List Screen
- [ ] My Groups list view
- [ ] Group row component (image, name, member count)
- [ ] Discover Groups section
- [ ] Search bar for groups

### 2.9 Group Detail Screen
- [ ] Group header (image, name, description)
- [ ] Group leaderboards (Active Streak, Longest Plank)
- [ ] Time filter selector (All-time, Last 7 days, Last 30 days)
- [ ] Members list
- [ ] Admin actions area (placeholder)
- [ ] Leave group button

### 2.10 Group Creation Screen
- [ ] Group name input
- [ ] Group image picker
- [ ] Public/Private toggle
- [ ] Join mode selector (Open vs Request to join)
- [ ] Create button

### 2.11 User Profile Screen
- [ ] Profile header (avatar, name, bio)
- [ ] Social links section
- [ ] Stats summary (streak, longest plank, total planks)
- [ ] Badges display
- [ ] Plank history section
- [ ] Follow/Unfollow button (for other users)

### 2.12 Following/Followers Screen
- [ ] Following list
- [ ] Followers list
- [ ] User row component

### 2.13 Settings Screen
- [ ] Preferred plank type setting
- [ ] Notification settings
  - [ ] Enable/disable toggle
  - [ ] Time picker
- [ ] Profile edit section
- [ ] Honesty disclaimer display
- [ ] About/version info

### 2.14 Notification Center Screen
- [ ] Notification list view
- [ ] Notification row component (icon, message, timestamp)
- [ ] Different notification types (group events, etc.)

### 2.15 Onboarding/Welcome Screens (Optional)
- [ ] Welcome screen
- [ ] Quick tutorial/feature highlights

---

## Phase 3: Connect Screens & Navigation

**Goal:** Wire all screens together with navigation, connect mock data to views, and create a fully navigable prototype using local storage for user's own data.

### 3.1 Tab Bar Navigation
- [ ] Set up main tab bar with tabs:
  - [ ] Plank (timer/main action)
  - [ ] Progress (history & stats)
  - [ ] Leaderboards
  - [ ] Groups
  - [ ] Profile

### 3.2 Navigation Flows
- [ ] Plank tab:
  - [ ] Timer screen �� Completion confirmation
  - [ ] Manual entry option
- [ ] Progress tab:
  - [ ] History list → Session detail (edit plank type)
  - [ ] Stats view
  - [ ] Badges view
- [ ] Leaderboards tab:
  - [ ] Global leaderboards
  - [ ] Tap user → User profile
- [ ] Groups tab:
  - [ ] My groups list → Group detail
  - [ ] Group detail → Member profiles
  - [ ] Discover groups → Join flow
  - [ ] Create group flow
- [ ] Profile tab:
  - [ ] My profile
  - [ ] Settings
  - [ ] Following/Followers
  - [ ] Notification center

### 3.3 Connect Mock Data to Views
- [ ] Inject mock data service into views
- [ ] Leaderboards display mock users
- [ ] Groups display mock groups with mock members
- [ ] Following/Followers show mock users
- [ ] Notification center shows mock notifications

### 3.4 Local Data Integration
- [ ] Save user's plank sessions to local storage
- [ ] Load and display user's real plank history
- [ ] Calculate and display user's real streak
- [ ] Calculate and award badges based on real data
- [ ] Save and load user preferences (plank type, notification settings)

### 3.5 Streak Logic Implementation
- [ ] Implement streak calculation (consecutive days)
- [ ] Handle timezone boundaries correctly
- [ ] Implement freeze token auto-application
- [ ] Implement token replenishment at 20-day streak

### 3.6 Badge Logic Implementation
- [ ] Check and award badges at milestones
- [ ] Persist earned badges
- [ ] Display earned vs locked badges

### 3.7 One Plank Per Day Logic
- [ ] Prevent multiple planks per day
- [ ] Allow deletion and re-entry same day
- [ ] Lock entries after day ends

### 3.8 User Appears in Mock Leaderboards
- [ ] Insert current user's real data into mock leaderboard
- [ ] Calculate correct ranking among mock users
- [ ] Highlight current user in leaderboard

### 3.9 Notification System (Local)
- [ ] Request notification permissions
- [ ] Schedule daily reminder at user's preferred time
- [ ] Handle notification settings changes
- [ ] Build in-app notification center (mock events for now)

---

## Phase 4: Perfect the Core Plank Experience

**Goal:** Focus entirely on perfecting the plank timer experience, manual entry, and personal tracking. Polish UX, animations, and edge cases. All data remains local (no backend yet).

### 4.1 Plank Timer Polish
- [ ] Smooth timer animations
- [ ] Millisecond precision display
- [ ] Screen stays awake reliably
- [ ] Plank type image transitions
- [ ] Satisfying start/stop interactions
- [ ] Haptic feedback on start/stop
- [ ] Audio cues (optional, user setting)

### 4.2 Plank Completion Flow
- [ ] Completion celebration screen
- [ ] Show duration achieved
- [ ] Show streak update
- [ ] Show if new personal best
- [ ] Badge earned celebration (if applicable)
- [ ] Token earned notification (if applicable)

### 4.3 Edge Cases & Error Handling
- [ ] App backgrounded during plank — handle gracefully
- [ ] App killed during plank — recover or handle
- [ ] Timer reaches 1 hour max — auto-stop
- [ ] Plank under 10 seconds — show message, don't save
- [ ] Already planked today — show appropriate message
- [ ] Timezone change handling

### 4.4 Manual Entry Polish
- [ ] Intuitive duration input
- [ ] Validation feedback
- [ ] Same guardrails as timer (10s min, 1hr max)
- [ ] Clear same-day-only messaging

### 4.5 Progress & History Polish
- [ ] Smooth chart animations
- [ ] Clear trend visualization
- [ ] Easy history browsing
- [ ] Edit plank type flow
- [ ] Delete same-day plank flow

### 4.6 Streak Display Polish
- [ ] Prominent streak display
- [ ] Token indicator clear and intuitive
- [ ] Streak milestone celebrations
- [ ] Clear messaging when token is used

### 4.7 Design Polish (Apple Health-Inspired)
- [ ] Refine all spacing and typography
- [ ] Consistent card designs
- [ ] Proper use of SF Symbols
- [ ] Light/dark mode support
- [ ] Smooth transitions throughout
- [ ] Accessibility audit (VoiceOver, Dynamic Type)

### 4.8 Performance Optimization
- [ ] Ensure timer runs smoothly
- [ ] Optimize data loading
- [ ] Test on older supported devices (iOS 16 compatible)

---

## Phase 5: Backend Integration & Real Functionality

**Goal:** Set up backend infrastructure and systematically replace all mock data with real functionality. Implement authentication, sync, and all social features.

### 5.1 Backend Setup
- [ ] Choose backend platform (Firebase, Supabase, or custom)
- [ ] Set up project and configuration
- [ ] Design database schema:
  - [ ] Users
  - [ ] Plank sessions
  - [ ] Streaks
  - [ ] Badges
  - [ ] Groups
  - [ ] Group memberships
  - [ ] Notifications
  - [ ] Follows
- [ ] Set up image storage (avatars, group images)
- [ ] Configure API/SDK in app

### 5.2 Authentication
- [ ] Implement Google Sign-In
- [ ] Implement Facebook Login
- [ ] Implement email/password registration
- [ ] Implement email/password login
- [ ] Password reset flow
- [ ] Secure session management
- [ ] Logout functionality
- [ ] Account deletion (for App Store compliance)

### 5.3 User Profile — Real Implementation
- [ ] Sync local profile to backend on signup
- [ ] Profile picture upload
- [ ] Bio and social links save/load
- [ ] View other users' real profiles

### 5.4 Plank Data Sync
- [ ] Sync local plank sessions to backend
- [ ] Handle offline entries — sync when back online
- [ ] Multi-day offline handling (backdate correctly)
- [ ] Conflict resolution (keep first entry per day)
- [ ] Real-time or periodic sync

### 5.5 Leaderboards — Real Implementation
- [ ] Replace mock leaderboard data with real users
- [ ] Backend calculates rankings:
  - [ ] Active Streak leaderboard
  - [ ] Longest Plank leaderboard
- [ ] Active streak required to appear
- [ ] Remove users when streak lost
- [ ] Efficient querying/caching for performance

### 5.6 Groups — Real Implementation
- [ ] Create group (save to backend)
- [ ] Unique group name validation
- [ ] Group image upload
- [ ] Public vs Private groups
- [ ] Open join vs Request to join
- [ ] Group discovery and search
- [ ] Join group flows:
  - [ ] Direct join
  - [ ] Request to join + admin approval
  - [ ] Email invitation (private groups)
- [ ] Group leaderboards (real data, time filters)
- [ ] Group administration:
  - [ ] Promote to admin
  - [ ] Remove members
  - [ ] Delete group
  - [ ] Admin delegation when leaving
  - [ ] Auto-delegate to earliest member
- [ ] Leave group functionality
- [ ] Rejoin starts fresh
- [ ] Enforce limits (50 groups/user, 1,000 members/group)
- [ ] Member join date tracking

### 5.7 Follow System — Real Implementation
- [ ] Follow/unfollow functionality
- [ ] Followers/following lists (real data)
- [ ] View followed users' activity

### 5.8 Notifications — Real Implementation
- [ ] Push notification: streak freeze token used
- [ ] In-app notifications with real events:
  - [ ] Group joined
  - [ ] Removed from group
  - [ ] Group deleted
  - [ ] Join request approved/denied
  - [ ] Promoted to admin
- [ ] Email service for private group invitations
- [ ] Mark notifications as read

### 5.9 Reporting & Moderation
- [ ] Report User functionality
- [ ] Backend flagging for suspicious patterns
- [ ] Admin review tools (if needed)

### 5.10 Analytics Integration
- [ ] Integrate Amplitude SDK
- [ ] Track key events:
  - [ ] Plank completed (duration, type)
  - [ ] Streak milestones
  - [ ] Badge earned
  - [ ] Group joined/created
  - [ ] App opens, session duration
  - [ ] Feature usage

### 5.11 Final Testing & QA
- [ ] End-to-end testing of all flows
- [ ] Offline mode testing
- [ ] Multi-device sync testing
- [ ] Edge case testing
- [ ] Performance testing
- [ ] Security review

### 5.12 App Store Preparation
- [ ] App Store listing copy
- [ ] Screenshots for all device sizes
- [ ] App preview video (optional)
- [ ] Privacy policy
- [ ] Terms of service
- [ ] App Store review preparation
- [ ] TestFlight beta testing

---

## Future Considerations (Post-Launch)

- **Monetization:** Subscription model after 1,000+ users
- **Additional plank types:** Side plank, reverse plank, weighted plank, etc.
- **Social features:** Comments, reactions, cheering
- **Advanced notifications:** "About to lose streak", "Someone beat your record"
- **Apple Watch companion app**
- **Android version**
- **Advanced verification:** Motion detection, photo/video proof (if cheating becomes problematic)
- **Widgets:** Home screen streak widget

---

## Summary

| Phase | Focus | Backend Required | Outcome |
|-------|-------|------------------|---------|
| Phase 1 | Project setup, structure, dependencies | No | Solid foundation ready for development |
| Phase 2 | Mock data, individual screens/pages | No | All UI components built in isolation |
| Phase 3 | Connect screens, navigation, local data | No | Fully navigable prototype with local storage |
| Phase 4 | Perfect core plank experience | No | Polished, delightful plank tracking UX |
| Phase 5 | Backend, auth, sync, replace all mock data | Yes | Production-ready app with full functionality |

**Each phase builds on the previous one, allowing for testing and validation at every stage.**
