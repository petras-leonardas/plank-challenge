# Integration Completion Plan

*Completing the Frontend-Backend Integration for Plank Challenge*

**Created:** March 15, 2026  
**Status:** Ready for Implementation  
**Estimated Total Effort:** 16-21 hours

---

## Executive Summary

The iOS app is ~90% integrated with the backend. This plan addresses the remaining gaps:

1. **StreakCalendarView** - Currently uses mock data
2. **4 Views with mock fallbacks** - Show fake data while loading
3. **ProfileView location/bio** - Uses mock instead of API
4. **MediaGallery** - Profile photo upload (single image)
5. **Cleanup** - Remove MockDataService files

---

## Phase Overview

| Phase | Description | Effort | Priority |
|-------|-------------|--------|----------|
| **Phase A** | StreakCalendarView - Use API data | 2-3 hours | P0 |
| **Phase B** | Remove mock fallbacks (4 views) | 3-4 hours | P1 |
| **Phase C** | ProfileView location/bio fix | 1 hour | P2 |
| **Phase D** | Profile photo upload implementation | 8-12 hours | P3 |
| **Phase E** | Delete MockDataService & cleanup | 30 min | P4 |
| **Phase F** | Final verification & build test | 30 min | P5 |

---

## Phase A: StreakCalendarView Update

### Goal
Replace mock `plankSessions` data with real API data from `StreakService.recentActivity`

### Current State

**File: `Components/StreakCalendarView.swift`**
- Takes `plankSessions: [PlankSession]` as input parameter
- Extracts dates from `PlankSession.date` (a `Date` object)
- Determines which days of the current month had planks

**File: `ProgressView.swift` (lines 51-53)**
```swift
// TODO: Update StreakCalendarView to use API data
StreakCalendarView(
    plankSessions: mockData.plankHistory
)
```

### API Data Available

`StreakService.recentActivity` returns `[StreakMeResponse.DayActivity]`:
```swift
struct DayActivity: Decodable {
    let date: String      // Format: "YYYY-MM-DD"
    let planks: Int       // Count of planks that day
    let totalSeconds: Double
}
```

The backend returns the last 30 days of activity from `/streaks/me`.

### Implementation Steps

#### Step A.1: Modify StreakCalendarView.swift

**Location:** `PlankChallenge/PlankChallenge/Components/StreakCalendarView.swift`

1. **Remove the parameter** (line 12):
   ```swift
   // DELETE THIS LINE:
   let plankSessions: [PlankSession]
   ```

2. **Add StreakService environment** (after line 11):
   ```swift
   @Environment(StreakService.self) private var streakService
   ```

3. **Add date formatter** (after line 15):
   ```swift
   private static let dateFormatter: DateFormatter = {
       let formatter = DateFormatter()
       formatter.dateFormat = "yyyy-MM-dd"
       formatter.locale = Locale(identifier: "en_US_POSIX")
       return formatter
   }()
   
   private func parseDate(_ dateString: String) -> Date? {
       Self.dateFormatter.date(from: dateString)
   }
   ```

4. **Replace `daysWithPlanks` computed property** (lines 33-46):
   ```swift
   private var daysWithPlanks: Set<Int> {
       let currentComponents = calendar.dateComponents([.year, .month], from: currentDate)
       var days = Set<Int>()
       
       for activity in streakService.recentActivity {
           guard activity.planks > 0,
                 let date = parseDate(activity.date) else { continue }
           
           let activityComponents = calendar.dateComponents([.year, .month, .day], from: date)
           
           if activityComponents.year == currentComponents.year &&
              activityComponents.month == currentComponents.month,
              let day = activityComponents.day {
               days.insert(day)
           }
       }
       return days
   }
   ```

5. **Update Preview** (lines 184-195):
   ```swift
   #Preview("Streak Calendar") {
       ScrollView {
           VStack(spacing: 20) {
               StreakCalendarView()
                   .padding(.horizontal, 16)
           }
           .padding(.vertical, 20)
       }
       .background(Color.softBlueBackground)
       .environment(StreakService.shared)
   }
   ```

6. **Remove or keep the mock helper function** (lines 198-228):
   - Can be deleted since preview now uses the real service
   - Or keep for reference during development

#### Step A.2: Update ProgressView.swift

**Location:** `PlankChallenge/PlankChallenge/ProgressView.swift`

1. **Remove mockData property** (lines 15-16):
   ```swift
   // DELETE THESE LINES:
   // Fallback to MockDataService for views not yet converted
   private var mockData: MockDataService { MockDataService.shared }
   ```

2. **Simplify StreakCalendarView call** (lines 49-53):
   ```swift
   // CHANGE FROM:
   // TODO: Update StreakCalendarView to use API data
   StreakCalendarView(
       plankSessions: mockData.plankHistory
   )
   
   // CHANGE TO:
   StreakCalendarView()
   ```

   Note: ProgressView already has `@Environment(StreakService.self)` at line 12, and the data is already being fetched in `loadDataIfNeeded()`.

### Design Decisions

1. **Loading behavior**: The calendar displays normally even when empty (no flames shown). The parent `ProgressView` already handles loading states, so no additional loading UI is needed in the calendar.

2. **Error handling**: If streak data fails to load, the calendar remains empty. Errors are handled by the parent view.

3. **Empty state**: A calendar with no flames is a valid state (new user with no planks).

### Testing Checklist

- [ ] Calendar displays current month correctly
- [ ] Days with planks show blue flame icon (from API data)
- [ ] Today is highlighted with accent circle
- [ ] Future days are dimmed
- [ ] Empty state (no planks) shows calendar without flames
- [ ] Pull-to-refresh updates calendar data
- [ ] Build succeeds with no warnings
- [ ] Preview works in Xcode

### Files Modified

| File | Type | Changes |
|------|------|---------|
| `Components/StreakCalendarView.swift` | Modify | Remove parameter, add Environment, update date logic, fix preview |
| `ProgressView.swift` | Modify | Remove mockData reference, simplify calendar call |

---

## Phase B: Remove Mock Fallbacks (4 Views)

### Goal
Replace mock data fallbacks with proper loading/empty states in 4 views that currently fall back to MockDataService while API data loads.

### Pattern to Apply

All fixes follow this pattern:

```swift
// BEFORE (mock fallback - BAD)
if service.data.isEmpty {
    ForEach(mockData.items) { ... }  // Shows fake data
}

// AFTER (proper states - GOOD)
if service.isLoading && !service.hasLoaded {
    LoadingView()  // Shows spinner
} else if service.data.isEmpty {
    EmptyStateView()  // Shows helpful message
} else {
    ForEach(service.data) { ... }  // Shows real data
}
```

### View 1: LeaderboardView.swift

**Location:** `PlankChallenge/PlankChallenge/LeaderboardView.swift`

**Current Mock Usage:**
- Line 41: `private var mockData: MockDataService { MockDataService.shared }`
- Lines 103-114: Falls back to `mockData.leaderboardEntries` when API data is empty

**Changes Required:**

1. Remove `mockData` property (line 41)

2. Update the leaderboard display logic to show:
   - Loading state while `leaderboardService.isLoading && !leaderboardService.hasLoaded`
   - Empty state: "No leaderboard data yet" when loaded but empty
   - Real data when available

3. Ensure `hasLoaded` flag exists in LeaderboardService (verify this)

### View 2: BadgesView.swift

**Location:** `PlankChallenge/PlankChallenge/BadgesView.swift`

**Current Mock Usage:**
- Line 14: `private var mockData: MockDataService { MockDataService.shared }`
- Lines 77-112: Falls back to mock badges when `badgeService.earnedBadges.isEmpty`

**Changes Required:**

1. Remove `mockData` property (line 14)

2. Update badge display to use `badgeService.hasLoaded`:
   - Loading: Show progress indicator
   - Empty: "No badges earned yet - keep planking!"
   - Has badges: Show real badges from API

3. Consider showing available badges (not just earned) from `badgeService.availableBadges`

### View 3: PlankProgressView (badges section)

**Location:** `PlankChallenge/PlankChallenge/ProgressView.swift`

**Current Mock Usage:**
- Lines 113-119: In badges section, falls back to mock when `!badgeService.hasLoaded`

**Changes Required:**

1. After Phase A removes `mockData`, the badges section fallback will break

2. Update badges section (around lines 105-140):
   - Loading: Show skeleton or placeholder badges
   - Empty: Show "Earn your first badge!" message
   - Has badges: Show real badges

### View 4: PlankHistoryListView.swift

**Location:** `PlankChallenge/PlankChallenge/PlankHistoryListView.swift`

**Current Mock Usage:**
- Line 14: `private var mockData: MockDataService { MockDataService.shared }`
- Lines 67-78: Falls back to `mockData.plankHistory` when empty

**Changes Required:**

1. Remove `mockData` property (line 14)

2. Update history display:
   - Loading: Show "Loading plank history..."
   - Empty: "No planks yet - start your first plank!"
   - Has data: Show real plank history

3. Use `plankService.hasLoaded` for state detection

### Testing Checklist

- [ ] LeaderboardView shows loading spinner during fetch
- [ ] LeaderboardView shows empty state when no data
- [ ] LeaderboardView shows real leaderboard data
- [ ] BadgesView shows loading spinner during fetch
- [ ] BadgesView shows empty state for new users
- [ ] BadgesView shows earned badges from API
- [ ] ProgressView badges section handles loading/empty states
- [ ] PlankHistoryListView shows loading spinner during fetch
- [ ] PlankHistoryListView shows empty state for new users
- [ ] PlankHistoryListView shows real plank history
- [ ] No `MockDataService` references in these 4 files
- [ ] Build succeeds

### Files Modified

| File | Changes |
|------|---------|
| `LeaderboardView.swift` | Remove mockData, add loading/empty states |
| `BadgesView.swift` | Remove mockData, add loading/empty states |
| `ProgressView.swift` | Fix badges section fallback |
| `PlankHistoryListView.swift` | Remove mockData, add loading/empty states |

---

## Phase C: ProfileView Location/Bio Fix

### Goal
Display user's real location and bio from the API instead of mock data.

### Current State

**File: `ProfileView.swift`**

Lines 188-199 use mock data for location and bio:
```swift
if let location = mockData.currentUser.location, !location.isEmpty {
    // ... display location
}
if !mockData.currentUser.bio.isEmpty {
    // ... display bio
}
```

### API Data Available

The `APIUser` model (in `APIModels.swift`) has:
```swift
struct APIUser: Decodable {
    // ...
    let location: String?
    let bio: String?
    // ...
}
```

This is accessible via:
- `authService.currentUser?.location`
- `authService.currentUser?.bio`
- Or `userService.currentUserProfile?.location` / `bio`

### Implementation Steps

1. **Identify the correct service** to use:
   - Check if `authService.currentUser` has location/bio populated
   - Or if `userService.currentUserProfile` should be used
   - The ProfileView already has both services available via `@Environment`

2. **Replace mock data access** (lines 188-199):
   ```swift
   // Get user from the appropriate service
   let user = authService.currentUser
   
   if let location = user?.location, !location.isEmpty {
       // Display location
   }
   if let bio = user?.bio, !bio.isEmpty {
       // Display bio  
   }
   ```

3. **Remove mockData reference** from ProfileView (lines 17-18):
   ```swift
   // DELETE:
   private var mockData: MockDataService { MockDataService.shared }
   ```

   Note: Only do this AFTER confirming nothing else in ProfileView uses mockData. The media gallery (line 315) still uses it, but that's addressed in Phase D.

### Testing Checklist

- [ ] Profile shows user's real location (or nothing if not set)
- [ ] Profile shows user's real bio (or nothing if not set)
- [ ] Build succeeds

### Files Modified

| File | Changes |
|------|---------|
| `ProfileView.swift` | Replace mock location/bio with API data |

---

## Phase D: Profile Photo Upload Implementation

### Goal
Allow users to upload a single profile photo that displays on their profile and throughout the app.

### Scope Clarification
- **Single photo only** (profile picture, not gallery)
- Users can upload, view, and replace their profile photo
- Photo displays on profile and in any avatar views

### Backend API Available

The backend has media upload support at `/media/upload`:

```
POST /media/upload
Content-Type: multipart/form-data

Body:
- file: The image file
- type: "avatar" | "plank_photo"

Response:
{
  "success": true,
  "data": {
    "media": {
      "id": "string",
      "url": "string",
      "thumbnailUrl": "string",
      "type": "avatar",
      "mimeType": "image/jpeg",
      "sizeBytes": 123456,
      "createdAt": "2026-03-15T..."
    }
  }
}
```

### Sub-Phases

#### Phase D.1: Research & Verification (30 min)

1. Verify the exact backend API contract in `backend/src/routes/media.ts`
2. Check how profile image URL is returned in user endpoints
3. Confirm image size limits and accepted formats
4. Understand if R2 bucket is configured for media storage

#### Phase D.2: Create MediaService (2 hours)

**New File: `Services/MediaService.swift`**

```swift
import Foundation
import Observation

@Observable
@MainActor
final class MediaService {
    static let shared = MediaService()
    
    private(set) var isUploading = false
    private(set) var uploadProgress: Double = 0
    private(set) var error: MediaServiceError?
    
    private init() {}
    
    /// Uploads a profile photo
    /// - Parameter imageData: JPEG image data
    /// - Returns: The uploaded media object with URL
    func uploadProfilePhoto(imageData: Data) async throws -> APIMedia {
        isUploading = true
        uploadProgress = 0
        error = nil
        defer { isUploading = false }
        
        // Use APIClient.upload() for multipart form data
        // Return the media URL
    }
    
    /// Deletes the current profile photo
    func deleteProfilePhoto() async throws {
        // Call DELETE /media/{id}
    }
}

enum MediaServiceError: LocalizedError {
    case fileTooLarge(maxSizeMB: Int)
    case invalidFormat
    case uploadFailed(String)
    case networkError
    // ...
}
```

#### Phase D.3: Add API Models (30 min)

**Modify: `Services/API/Models/APIModels.swift`**

Add if not already present:

```swift
/// Media object returned from upload
struct APIMedia: Decodable, Identifiable {
    let id: String
    let url: String
    let thumbnailUrl: String?
    let type: String  // "avatar" or "plank_photo"
    let mimeType: String
    let sizeBytes: Int
    let createdAt: String
}

/// Response from media upload
struct MediaUploadResponse: Decodable {
    let media: APIMedia
}
```

#### Phase D.4: Add Multipart Upload to APIClient (1 hour)

**Modify: `Services/API/APIClient.swift`**

Add method for multipart form data uploads:

```swift
/// Uploads a file using multipart form data
func upload<T: Decodable>(
    endpoint: String,
    fileData: Data,
    fileName: String,
    mimeType: String,
    fieldName: String = "file",
    additionalFields: [String: String] = [:]
) async throws -> T {
    // Build multipart request
    // Handle upload progress if possible
    // Return decoded response
}
```

#### Phase D.5: Create ImagePicker Component (2 hours)

**New File: `Components/ImagePicker.swift`**

Use `PhotosPicker` (iOS 16+) for photo selection:

```swift
import SwiftUI
import PhotosUI

struct ProfilePhotoPicker: View {
    @Binding var selectedImage: UIImage?
    @State private var selectedItem: PhotosPickerItem?
    
    var body: some View {
        PhotosPicker(selection: $selectedItem, matching: .images) {
            // Picker label/button
        }
        .onChange(of: selectedItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    selectedImage = image
                }
            }
        }
    }
}
```

Also handle:
- Image compression before upload (target ~500KB)
- Crop to square aspect ratio (optional)
- Camera capture option

#### Phase D.6: Create ProfilePhotoEditor View (2 hours)

**New File: `Views/Profile/ProfilePhotoEditorView.swift`**

A sheet/modal for editing profile photo:

```swift
struct ProfilePhotoEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(MediaService.self) private var mediaService
    @Environment(UserService.self) private var userService
    
    @State private var selectedImage: UIImage?
    @State private var isUploading = false
    @State private var showError = false
    
    var body: some View {
        NavigationStack {
            VStack {
                // Current photo preview
                // Photo picker
                // Upload button
                // Delete button (if has photo)
            }
            .navigationTitle("Profile Photo")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { uploadPhoto() }
                        .disabled(selectedImage == nil || isUploading)
                }
            }
        }
    }
    
    private func uploadPhoto() {
        // Compress image
        // Call mediaService.uploadProfilePhoto()
        // Update userService.currentUserProfile with new URL
        // Dismiss on success
    }
}
```

#### Phase D.7: Update ProfileView (1 hour)

**Modify: `ProfileView.swift`**

1. Remove `MediaGalleryView` usage (line ~315)
2. Add tap gesture to profile avatar to open editor
3. Show current profile photo from `authService.currentUser?.profileImageUrl`
4. Add "Edit Photo" button or overlay

```swift
// Replace MediaGalleryView with simple profile photo display
if let imageUrl = authService.currentUser?.profileImageUrl {
    AsyncImage(url: URL(string: imageUrl)) { ... }
} else {
    // Default avatar
}

// Add button to change photo
Button("Change Photo") {
    showingPhotoEditor = true
}
.sheet(isPresented: $showingPhotoEditor) {
    ProfilePhotoEditorView()
}
```

#### Phase D.8: Update AvatarView Component (30 min)

**Modify: `Components/AvatarView.swift`** (if exists)

Ensure avatar views throughout the app can display:
- Profile image URL from API
- Fallback to initials/default avatar

#### Phase D.9: Remove MediaGalleryView (30 min)

**Delete or Archive:**
- `MediaGalleryView.swift` - No longer needed for single photo
- `MediaItem` model - No longer needed

**Or keep for future:**
- If plank photos feature is planned, keep the gallery code but don't use it in ProfileView

### Testing Checklist

- [ ] User can tap to change profile photo
- [ ] Photo picker shows user's photo library
- [ ] Selected photo previews before upload
- [ ] Upload progress shows during upload
- [ ] Success updates profile immediately
- [ ] New photo appears in profile avatar
- [ ] User can delete profile photo
- [ ] Error states show appropriate messages
- [ ] Works with large images (compression)
- [ ] Works offline (shows error, doesn't crash)
- [ ] Build succeeds

### Files Created

| File | Description |
|------|-------------|
| `Services/MediaService.swift` | Media upload/delete service |
| `Components/ImagePicker.swift` | Photo selection component |
| `Views/Profile/ProfilePhotoEditorView.swift` | Photo editing sheet |

### Files Modified

| File | Changes |
|------|---------|
| `Services/API/APIClient.swift` | Add multipart upload method |
| `Services/API/Models/APIModels.swift` | Add APIMedia model |
| `ProfileView.swift` | Replace gallery with single photo, add edit |
| `Components/AvatarView.swift` | Support URL images |
| `PlankChallengeApp.swift` | Add MediaService to environment |

### Files Removed (or archived)

| File | Reason |
|------|--------|
| `MediaGalleryView.swift` | Replaced with single photo |

---

## Phase E: Delete MockDataService & Cleanup

### Goal
Remove all mock data infrastructure now that nothing uses it.

### Prerequisites
- [ ] Phase A complete (StreakCalendarView)
- [ ] Phase B complete (4 views)
- [ ] Phase C complete (ProfileView location/bio)
- [ ] Phase D complete (MediaGallery removed)

### Implementation Steps

1. **Search for remaining references:**
   ```
   Search for: MockDataService
   Search for: mockData
   Search for: MockUser
   ```

2. **Verify no usages remain** in any view or service

3. **Delete files:**
   - `MockDataService.swift`
   - `MockUser.swift` (if exists)
   - Any other mock-related files

4. **Build and verify** no compilation errors

### Files to Delete

| File | Reason |
|------|--------|
| `MockDataService.swift` | No longer used |
| `MockUser.swift` | No longer used (if exists) |

---

## Phase F: Final Verification & Build Test

### Goal
Ensure everything works together after all changes.

### Project Settings Verification

1. **Deployment Target:**
   - Open Xcode project settings
   - Verify iOS Deployment Target is `17.0` (not `26.2`)
   - Fix if incorrect

2. **App Icon:**
   - Check `Assets.xcassets/AppIcon.appiconset/`
   - Verify icon images exist
   - Add 1024x1024 icon if missing

3. **Entitlements:**
   - Verify `PlankChallenge.entitlements` exists
   - Contains Sign in with Apple capability
   - Contains Push Notifications capability

4. **Privacy Manifest:**
   - Verify `PrivacyInfo.xcprivacy` exists

### Build Test

1. Clean build folder: `Cmd+Shift+K`
2. Build: `Cmd+B`
3. Verify no errors
4. Review warnings (fix any new ones from our changes)

### Functional Testing (Simulator)

Run through these flows manually:

| Flow | Test |
|------|------|
| **Authentication** | Sign in with Apple works |
| **Timer** | Complete a plank, verify it saves |
| **Progress** | Calendar shows plank days from API |
| **Progress** | Badges section loads from API |
| **History** | Shows real plank history |
| **Leaderboards** | Loads from API, shows real data |
| **Profile** | Shows real user data (name, streak, stats) |
| **Profile** | Location/bio from API (or empty) |
| **Profile Photo** | Can upload new photo |
| **Profile Photo** | Photo displays after upload |
| **Groups** | List loads, can view details |
| **Notifications** | List loads from API |

### Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| New user (no planks) | Empty states shown, not mock data |
| Network error | Error state shown, not crash |
| Slow network | Loading indicators visible |
| Large photo upload | Compression works, upload succeeds |

### Final Checklist

- [ ] No `MockDataService` references in codebase
- [ ] All views use real API data
- [ ] Build succeeds with no errors
- [ ] All main flows work in simulator
- [ ] Edge cases handled gracefully

---

## Appendix: Quick Reference

### MockDataService Usage Locations (Before Cleanup)

| File | Lines | Usage |
|------|-------|-------|
| `ProgressView.swift` | 15-16, 52 | Calendar, badges fallback |
| `ProfileView.swift` | 17-18, 188-199, 315 | Location/bio, media gallery |
| `LeaderboardView.swift` | 41, 103-114 | Leaderboard fallback |
| `BadgesView.swift` | 14, 77-112 | Badges fallback |
| `PlankHistoryListView.swift` | 14, 67-78 | History fallback |

### Services Already Implemented

| Service | File | Status |
|---------|------|--------|
| APIClient | `Services/API/APIClient.swift` | Complete |
| AuthService | `Services/AuthService.swift` | Complete |
| PlankService | `Services/PlankService.swift` | Complete |
| StreakService | `Services/StreakService.swift` | Complete |
| BadgeService | `Services/BadgeService.swift` | Complete |
| UserService | `Services/UserService.swift` | Complete |
| GroupService | `Services/GroupService.swift` | Complete |
| LeaderboardService | `Services/LeaderboardService.swift` | Complete |
| InAppNotificationService | `Services/InAppNotificationService.swift` | Complete |
| MediaService | `Services/MediaService.swift` | **To Create (Phase D)** |

### API Models Reference

Key models in `Services/API/Models/APIModels.swift`:

- `APIUser` - Full user with location, bio, profileImageUrl
- `StreakMeResponse.DayActivity` - Date + plank count for calendar
- `APIMedia` - **To Add (Phase D)** - Uploaded media object

---

## Execution Summary

```
Day 1: Phase A (StreakCalendarView) - 2-3 hours
        └── Removes mockData from ProgressView calendar

Day 1/2: Phase B (Mock Fallbacks) - 3-4 hours
        └── LeaderboardView, BadgesView, ProgressView badges, PlankHistoryListView

Day 2: Phase C (ProfileView) - 1 hour
        └── Location/bio from API

Day 2-3: Phase D (Profile Photo) - 8-12 hours
        └── D.1: Research (30 min)
        └── D.2: MediaService (2 hours)
        └── D.3: API Models (30 min)
        └── D.4: APIClient upload (1 hour)
        └── D.5: ImagePicker (2 hours)
        └── D.6: ProfilePhotoEditor (2 hours)
        └── D.7: ProfileView update (1 hour)
        └── D.8: AvatarView update (30 min)
        └── D.9: Remove MediaGalleryView (30 min)

Day 3: Phase E (Cleanup) - 30 min
        └── Delete MockDataService files

Day 3: Phase F (Verification) - 30 min
        └── Build test, functional testing
```

**Total: ~16-21 hours over 2-3 days**

---

*Ready for implementation. Start with Phase A: StreakCalendarView.*
