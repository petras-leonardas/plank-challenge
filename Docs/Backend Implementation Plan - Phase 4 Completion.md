# Backend Implementation Plan - Phase 4 Completion

**Version:** 1.1  
**Created:** March 15, 2026  
**Last Updated:** March 15, 2026  
**Status:** Phase 4 Complete (with robustness improvements)

---

## Table of Contents

1. [Overview](#1-overview)
2. [Phase 4 Summary](#2-phase-4-summary)
3. [What Was Implemented](#3-what-was-implemented)
4. [API Endpoints](#4-api-endpoints)
5. [Architecture Decisions](#5-architecture-decisions)
6. [Testing Results](#6-testing-results)
7. [Files Created/Modified](#7-files-createdmodified)
8. [Deferred Items](#8-deferred-items)
9. [Next Steps](#9-next-steps)

---

## 1. Overview

Phase 4 focused on implementing media storage and image upload functionality using Cloudflare R2.

### Key Context

- **Primary Plan Document:** `Docs/Backend Implementation Plan.md`
- **Production URL:** `https://plank-challenge-api.petras-leonardas.workers.dev`
- **Phase 3 Document:** `Docs/Backend Implementation Plan - Phase 3 Completion.md`

---

## 2. Phase 4 Summary

### Original Phase 4 Goals (from Implementation Plan)

| Goal | Status |
|------|--------|
| R2 bucket configuration | Done (was already configured) |
| Presigned URL generation | Changed approach (see below) |
| Profile image upload flow | Done |
| Thumbnail generation (queue) | Deferred |
| Group image upload | Done |
| CDN URL configuration | Partial (using R2 direct) |
| iOS image picker integration | Future (iOS work) |
| Image caching (iOS) | Future (iOS work) |

### Architecture Decision: Direct Upload vs Presigned URLs

The original plan called for presigned URL generation where:
1. Client requests a presigned URL
2. Client uploads directly to R2
3. Client confirms upload completion

**Decision:** We chose **direct upload through Worker** instead because:

1. **Simpler authentication** - Uses existing JWT auth instead of needing S3-compatible credentials
2. **Size validation** - Worker validates file size before accepting (prevents wasted R2 writes)
3. **Content-type validation** - Worker validates image type before accepting
4. **Atomic operation** - Upload + DB update in single request
5. **No credential exposure** - R2 access keys stay server-side
6. **Cleaner iOS implementation** - Single HTTP request instead of multi-step flow

**Trade-off:** Slightly higher Worker CPU usage for large uploads, but acceptable for images up to 5MB.

---

## 3. What Was Implemented

### Media Routes (`/media/*`)

#### Avatar Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/media/avatar` | Upload profile avatar (binary body) |
| DELETE | `/media/avatar` | Remove current user's avatar |
| GET | `/media/avatar/:userId` | Get user's avatar image |

#### Group Image Endpoints (Phase 6 preparation)

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/media/group/:groupId` | Upload group cover image |
| DELETE | `/media/group/:groupId` | Remove group image |
| GET | `/media/group/:groupId` | Get group's cover image |

### Media Utilities (`src/utils/media.ts`)

- `generateImageKey()` - Creates organized storage keys (e.g., `profiles/{userId}/avatar_{timestamp}.jpg`)
- `validateImageUpload()` - Validates content-type and size
- `extractKeyFromUrl()` - Parses R2 keys from stored URLs
- `getThumbnailKey()` - Generates thumbnail key from original
- `createThumbnailMessage()` - Creates queue message for thumbnail generation

### Supported Image Types

- `image/jpeg`
- `image/png`
- `image/webp`

### Size Limits

- Avatar: 5MB max
- Group images: 5MB max

---

## 4. API Endpoints

### POST /media/avatar

Upload a new profile avatar.

**Headers:**
```
Authorization: Bearer <token>
Content-Type: image/jpeg | image/png | image/webp
```

**Body:** Raw image binary

**Response (201):**
```json
{
  "success": true,
  "data": {
    "profileImageUrl": "profiles/{userId}/avatar_{timestamp}.jpg",
    "message": "Avatar uploaded successfully"
  }
}
```

**Errors:**
- `400` - Invalid content type, file too large, empty file
- `401` - Unauthorized

### DELETE /media/avatar

Remove current user's avatar.

**Headers:**
```
Authorization: Bearer <token>
```

**Response (200):**
```json
{
  "success": true,
  "data": {
    "message": "Avatar removed successfully"
  }
}
```

**Errors:**
- `404` - No avatar exists
- `401` - Unauthorized

### GET /media/avatar/:userId

Retrieve a user's avatar image (public endpoint).

**Response (200):**
- Content-Type: image/jpeg | image/png | image/webp
- Cache-Control: public, max-age=86400
- ETag header included

**Errors:**
- `404` - User not found or has no avatar

### POST /media/group/:groupId

Upload group cover image. Requires admin role.

**Headers:**
```
Authorization: Bearer <token>
Content-Type: image/jpeg | image/png | image/webp
```

**Body:** Raw image binary

**Response (201):**
```json
{
  "success": true,
  "data": {
    "imageUrl": "groups/{groupId}/cover_{timestamp}.jpg",
    "message": "Group image uploaded successfully"
  }
}
```

**Errors:**
- `403` - Not a group admin
- `400` - Invalid content type, file too large

---

## 5. Architecture Decisions

### R2 Storage Structure

```
plank-challenge-media/
├── profiles/
│   └── {userId}/
│       ├── avatar_{timestamp}.jpg      # Current avatar
│       └── avatar_{timestamp}_thumb.jpg # Thumbnail (when implemented)
├── groups/
│   └── {groupId}/
│       ├── cover_{timestamp}.jpg       # Group cover
│       └── cover_{timestamp}_thumb.jpg # Thumbnail (when implemented)
└── gallery/                            # Future: plank photos
    └── {userId}/
        └── {mediaId}.jpg
```

### Image URL Storage

We store the R2 key directly in the database (not a full URL):
```
profile_image_url = "profiles/abc123/avatar_1710432000.jpg"
```

Benefits:
1. **CDN flexibility** - Can switch CDN domains without DB migration
2. **Smaller storage** - Keys are shorter than full URLs
3. **Consistency** - Single format regardless of CDN configuration

### Old Image Cleanup

When uploading a new image:
1. New image uploaded with new timestamp
2. User profile updated with new key
3. Old image deleted from R2 (best effort)
4. Old thumbnail deleted if exists

This ensures:
- No orphaned images accumulate
- Atomic user profile update
- Graceful handling of deletion failures

### Caching Strategy

| Layer | Cache-Control | Notes |
|-------|---------------|-------|
| R2 Upload | max-age=31536000 (1 year) | Images versioned by timestamp |
| GET Response | max-age=86400 (1 day) | Edge caching via Worker |
| ETag | Included | Client-side cache validation |

Images are effectively immutable (new upload = new key), so long cache times are safe.

---

## 6. Testing Results

### Local Development Tests

All tests passed:

| Test | Result |
|------|--------|
| Upload avatar (valid JPEG) | Pass |
| Upload avatar (valid PNG) | Pass |
| Upload avatar (invalid type - GIF) | Pass (400 error) |
| Upload avatar (empty file) | Pass (400 error) |
| Upload avatar (no content-type) | Pass (400 error) |
| Get avatar by userId | Pass |
| Delete avatar | Pass |
| Delete avatar (none exists) | Pass (404 error) |
| Avatar removed from profile | Pass |
| Avatar returns 404 after deletion | Pass |

### Production Tests

| Test | Result |
|------|--------|
| Register user | Pass |
| Upload avatar | Pass |
| Retrieve avatar | Pass (HTTP 200, correct content-type) |

---

## 7. Files Created/Modified

### New Files

| File | Purpose |
|------|---------|
| `src/routes/media.ts` | All media endpoints (avatar, group images) |
| `src/utils/media.ts` | Media utilities (validation, key generation) |

### Modified Files

| File | Change |
|------|--------|
| `src/index.ts` | Added media routes import and mounting |

---

## 8. Deferred Items

### Thumbnail Generation

**Original Plan:** Generate 200x200 thumbnails via Cloudflare Queue

**Status:** Deferred to future iteration

**Reason:** 
- Requires image processing in Worker (sharp via WASM or Cloudflare Images)
- Complex setup for marginal benefit at this stage
- iOS can request specific sizes or resize locally

**Implementation path when needed:**
1. Set up THUMBNAIL_QUEUE in wrangler.toml
2. Create queue consumer with photon-rs or similar WASM library
3. Enable queue consumption in media.ts

### CDN Domain Configuration

**Original Plan:** Custom domain like `media.plankchallenge.app`

**Status:** Using Worker proxy for now

**Reason:**
- Domain not yet purchased
- Worker proxy provides same functionality
- Can add custom domain later without code changes

### iOS Integration

Deferred to iOS development phase:
- Image picker integration
- Local image compression before upload
- Image caching strategy

---

## 9. Next Steps

### Phase 5: Social Features (Week 5-6)

From the Implementation Plan:

| Task | Priority |
|------|----------|
| Follow/unfollow API | High |
| Followers/following lists | High |
| User search API | High (partially done) |
| Public user profiles | High (done in Phase 2) |
| Follower count denormalization | Medium (done in Phase 2) |
| User discovery algorithm | Medium |
| iOS social UI integration | Future |

**Note:** Several Phase 5 tasks were already implemented in Phase 2:
- User search (`GET /users/search`)
- Public profiles (`GET /users/:id`)
- Follow/unfollow (`POST/DELETE /users/:id/follow`)
- Followers/following lists (`GET /users/:id/followers`, `GET /users/:id/following`)
- Follower counts (denormalized in users table)

Phase 5 may primarily focus on:
- User discovery algorithm
- Additional social features (blocking, suggested follows)
- iOS integration

### Phase 6: Groups (Week 6-7)

Group images are already implemented in Phase 4. Phase 6 will focus on:
- Group CRUD API
- Membership management
- Join modes (open, request)
- Admin functionality
- Invite code system
- Group leaderboards

---

## Appendix: iOS Integration Guide

### Uploading an Avatar

```swift
func uploadAvatar(imageData: Data) async throws -> String {
    var request = URLRequest(url: URL(string: "\(baseURL)/media/avatar")!)
    request.httpMethod = "POST"
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
    request.httpBody = imageData
    
    let (data, response) = try await URLSession.shared.data(for: request)
    
    guard let httpResponse = response as? HTTPURLResponse,
          httpResponse.statusCode == 201 else {
        throw APIError.uploadFailed
    }
    
    let result = try JSONDecoder().decode(AvatarResponse.self, from: data)
    return result.data.profileImageUrl
}
```

### Loading an Avatar

```swift
func loadAvatar(userId: String) async throws -> UIImage? {
    let url = URL(string: "\(baseURL)/media/avatar/\(userId)")!
    let (data, response) = try await URLSession.shared.data(from: url)
    
    guard let httpResponse = response as? HTTPURLResponse,
          httpResponse.statusCode == 200 else {
        return nil
    }
    
    return UIImage(data: data)
}
```

### Recommended: Compress Before Upload

```swift
func compressImage(_ image: UIImage, maxSize: CGFloat = 1024) -> Data? {
    let size = image.size
    let scale = min(maxSize / size.width, maxSize / size.height, 1.0)
    let newSize = CGSize(width: size.width * scale, height: size.height * scale)
    
    UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
    image.draw(in: CGRect(origin: .zero, size: newSize))
    let newImage = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    
    return newImage?.jpegData(compressionQuality: 0.8)
}
```

---

## Appendix B: Robustness Improvements (v1.1)

After the initial Phase 4 implementation, a thorough review identified several areas for improvement. All were addressed:

### Issues Fixed

| Issue | Priority | Fix |
|-------|----------|-----|
| **Orphaned images on DB failure** | P1 | Added rollback logic - if DB update fails after R2 upload, the uploaded image is deleted |
| **Wrong file extension** | P2 | File extension now matches actual content type (`.jpg`, `.png`, `.webp`) |
| **No minimum file size** | P3 | Added 50-byte minimum to catch obviously invalid files |
| **No magic byte validation** | P2 | Validates file signature matches claimed Content-Type |
| **Inconsistent type usage** | P3 | Now uses centralized `UserRecord`, `GroupRecord` types from `api.ts` |
| **Debug console.log** | P3 | Removed debug logging from production code |

### Magic Byte Validation

The system now validates image files by checking their magic bytes (file signatures):

| Format | Magic Bytes | Detection |
|--------|-------------|-----------|
| JPEG | `FF D8 FF` | First 3 bytes |
| PNG | `89 50 4E 47 0D 0A 1A 0A` | First 8 bytes |
| WebP | `52 49 46 46 ... 57 45 42 50` | Bytes 0-3 = "RIFF", bytes 8-11 = "WEBP" |

This prevents:
- Uploading non-image files with spoofed Content-Type
- Storing garbage data that would fail to render on clients
- Potential client crashes when decoding invalid image data

### Rollback Logic

The upload flow now handles partial failures gracefully:

```
1. Upload to R2
2. Try: Update database
   - Success: Continue to cleanup
   - Failure: Delete just-uploaded image from R2, return error
3. Delete old image from R2 (best effort)
4. Return success
```

This ensures no orphaned images accumulate in R2 storage.

---

## Document History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-03-15 | Initial version - Phase 4 complete |
| 1.1 | 2026-03-15 | Added robustness improvements: rollback logic, magic byte validation, correct file extensions, minimum size validation, type consistency |
