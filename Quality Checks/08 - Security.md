# Quality Check: Security

## Your Task

You are an AI code editor tasked with auditing and fixing security vulnerabilities across the Plank Challenge iOS app — both the iOS client and the Cloudflare Workers backend. Your goal is to ensure that sensitive data is stored correctly, that the network layer is appropriately hardened, that the backend enforces rate limiting and input validation on all mutating endpoints, and that no user data leaks between sessions or across API boundaries.

Work through this document top to bottom. For each section, search the codebase, identify the problems, implement the fixes, and move on. Do not skip sections.

---

## Project Context

**App**: Plank Challenge — a social fitness iOS app where users log a daily plank and maintain a streak.

**Platform (iOS)**: SwiftUI, Swift 5.9+, `@Observable`, Swift Concurrency. No third-party networking libraries — `URLSession` only.

**Platform (Backend)**: Cloudflare Workers, TypeScript, Hono framework, Drizzle ORM, D1 (SQLite), KV (rate limiting, caching), R2 (media), Cloudflare Queues.

**Key architectural facts you need to know:**

*iOS:*
- `KeychainService` at `PlankChallenge/Services/KeychainService.swift` — wraps Security framework directly, stores JWT access token, refresh token, and expiry
- `APIClient` at `PlankChallenge/Services/API/APIClient.swift` — all network requests go through this actor; uses `URLSession`
- `@AppStorage` (UserDefaults) used in `PlankTimerView.swift` — stores today's plank count/times
- User-generated content: display name, bio, location, group name, group description
- Media: profile photos uploaded via `MediaService` to the backend, which stores them in Cloudflare R2

*Backend:*
- Entry point: `backend/src/index.ts` — Hono app with all route modules
- Routes: `backend/src/routes/` — `auth.ts`, `badges.ts`, `devices.ts`, `groups.ts`, `leaderboards.ts`, `media.ts`, `notifications.ts`, `planks.ts`, `streaks.ts`, `users.ts`
- Middleware: `backend/src/middleware/` — look for auth middleware and rate limiting middleware
- Rate limiting: implemented via Cloudflare KV (`RATE_LIMIT` binding)
- Auth: JWT via `jose` library — access + refresh token pattern
- DB schema: `backend/src/db/` — Drizzle ORM schema for all tables

---

## Step 1 — Audit Keychain Usage on iOS

The Keychain is the correct place for all sensitive credentials. Audit what is stored where.

### Step 1a — Verify all tokens are in the Keychain

Read `PlankChallenge/Services/KeychainService.swift` and verify:

1. The JWT **access token** is stored in the Keychain — not in `UserDefaults` or `@AppStorage`
2. The **refresh token** is stored in the Keychain — not in `UserDefaults` or `@AppStorage`
3. The token **expiry date** is stored in the Keychain (acceptable to also store in `UserDefaults` since it is not sensitive, but must not be the only place if the token itself is in the Keychain)
4. No token is stored in a property list, flat file, or anywhere in the app's documents directory

Search the entire `PlankChallenge/` directory for these strings which indicate tokens stored outside the Keychain:
- `UserDefaults.standard.set` combined with `token`, `accessToken`, `refreshToken`, `jwt`
- `@AppStorage` combined with `token`, `accessToken`, `refreshToken`
- `FileManager` combined with `token`

For any match found: move the storage to `KeychainService`.

### Step 1b — Verify Keychain access control

Read `KeychainService.swift` and check the `kSecAttrAccessible` attribute used when storing items. The correct value for authentication tokens is:

```swift
kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
```

This means:
- Tokens are accessible after the device is unlocked once after boot (correct for background token refresh)
- Tokens do NOT migrate to a new device via iCloud backup (correct — tokens are device-specific)
- `ThisDeviceOnly` prevents the Keychain item from being backed up (correct for security)

If the current value is `kSecAttrAccessibleAlways` or `kSecAttrAccessibleWhenUnlocked` without `ThisDeviceOnly`, update it. If it is `kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly`, that is also acceptable but may cause issues for users without a device passcode.

### Step 1c — Verify Keychain items are deleted on logout

Read `AuthService.signOut()` and verify that `KeychainService` is called to delete all stored items — access token, refresh token, and expiry — when the user signs out.

If any item is not deleted on logout, add the deletion call. Leftover tokens in the Keychain after logout allow a subsequent user (on a shared device) or a malicious actor with physical access to potentially reuse the session.

### Step 1d — Verify Keychain items are deleted on account deletion

Read `AuthService.deleteAccount()` and verify the same — all Keychain items must be cleared when the user deletes their account.

---

## Step 2 — Audit `@AppStorage` and `UserDefaults` for Sensitive Data

`@AppStorage` and `UserDefaults` store data in an unencrypted plist file in the app's sandbox. This is readable by anyone with access to an unencrypted device backup (e.g. iTunes backup to a Mac without encryption enabled).

### Acceptable in `UserDefaults` / `@AppStorage`

- Today's plank count and timestamps (low sensitivity)
- Last sync timestamp (not sensitive)
- UI preferences (theme, selected tab, notification settings)
- The user's timezone identifier (not sensitive)
- Last known connectivity state (not sensitive)

### Not acceptable in `UserDefaults` / `@AppStorage`

- Any authentication token
- The user's email address
- The user's full profile data (name, bio, location) — especially if it could be used for identity correlation
- Push notification device tokens (these are not security-sensitive but should be in Keychain for integrity)

Search `PlankChallenge/` for `@AppStorage` and `UserDefaults.standard.set` and audit each key. For any sensitive value found outside the Keychain, move it.

### Step 2a — Verify `UserDefaults` does not persist sensitive profile data

It is tempting to cache the user's profile in `UserDefaults` for instant display on cold launch. If `UserProfile` or `AuthUser` is serialised to `UserDefaults`, audit what fields it contains. At minimum, ensure the user's **email address** is not cached in `UserDefaults`. If it is, remove it or encrypt it before storage.

---

## Step 3 — Audit Input Validation on iOS (User-Generated Content)

The app accepts user-generated text in several places. While a native iOS app is not vulnerable to XSS (there is no DOM), user-generated content is sent to the server and may be rendered in other contexts (web views, future web app, push notification bodies). Validate and sanitise on both client and server.

### Step 3a — Identify all user text input fields

Search `PlankChallenge/` for `TextField`, `TextEditor` — these are user input surfaces. List them:

Likely locations:
- `EmailSignUpView.swift` — display name, email, password
- `EmailSignInView.swift` — email, password
- `ManualEntryView.swift` — duration input (numeric)
- `GroupSettingsView.swift` — group name, group description
- `SettingsView.swift` or a profile edit view — display name, bio, location, social links

### Step 3b — Apply client-side input limits

For every text field, enforce a maximum length that matches the backend's validation. If the backend validates display name to 50 characters, the text field must also enforce 50 characters. This prevents the user from typing a long string, seeing it accepted in the UI, and then receiving a cryptic server error.

```swift
TextField("Display Name", text: $displayName)
    .onChange(of: displayName) { _, newValue in
        if newValue.count > 50 {
            displayName = String(newValue.prefix(50))
        }
    }
```

Or more cleanly, define character limits as constants:

```swift
// In Constants.swift
enum InputLimit {
    static let displayName = 50
    static let bio = 200
    static let location = 100
    static let groupName = 80
    static let groupDescription = 500
    static let socialLink = 200
}
```

Apply these limits to every relevant `TextField` and `TextEditor`.

### Step 3c — Trim whitespace before submission

User-entered text should be trimmed of leading and trailing whitespace before being sent to the server. A display name of `"  Alex  "` should be stored as `"Alex"`. A bio that is entirely whitespace should be treated as empty.

Add a trimming step to every service method that submits user text:

```swift
func updateProfile(_ update: ProfileUpdate) async {
    let sanitised = ProfileUpdate(
        displayName: update.displayName?.trimmingCharacters(in: .whitespacesAndNewlines),
        bio: update.bio?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
        location: update.location?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    )
    // submit sanitised
}

extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
```

### Step 3d — Validate social links as URLs

If users can enter social links (Instagram, Twitter/X, Strava URLs), validate that submitted strings are valid URLs before sending to the server:

```swift
func isValidURL(_ string: String) -> Bool {
    guard let url = URL(string: string) else { return false }
    return url.scheme == "https" && url.host != nil
}
```

Reject non-HTTPS URLs and display an inline validation error.

---

## Step 4 — Audit Backend Rate Limiting

Rate limiting prevents abuse of the API — spam plank creation to inflate leaderboard scores, credential stuffing on the auth endpoints, and DoS via expensive queries.

### Step 4a — Read the existing rate limiting middleware

Read `backend/src/middleware/` and identify the rate limiting implementation. Determine:
1. Which endpoints it is applied to
2. What the rate limits are (requests per minute/hour per IP or per user)
3. Whether it is applied as global middleware or per-route middleware

### Step 4b — Verify rate limiting on all mutating endpoints

Rate limiting **must** be applied to every endpoint that creates, updates, or deletes data. Search `backend/src/routes/` and verify each of the following routes has rate limiting:

| Route | Method | Endpoint | Sensitivity |
|-------|--------|----------|-------------|
| `auth.ts` | POST | `/auth/login` | **Critical** — credential stuffing |
| `auth.ts` | POST | `/auth/register` | **Critical** — spam account creation |
| `auth.ts` | POST | `/auth/refresh` | High — token refresh abuse |
| `auth.ts` | POST | `/auth/apple` | High |
| `planks.ts` | POST | `/planks` | **Critical** — leaderboard integrity |
| `planks.ts` | DELETE | `/planks/:id` | Medium |
| `users.ts` | PUT/PATCH | `/users/me` | Medium — profile spam |
| `users.ts` | POST | `/users/:id/follow` | Medium — follow spam |
| `groups.ts` | POST | `/groups` | Medium — group creation spam |
| `groups.ts` | POST | `/groups/:id/join` | Medium |
| `media.ts` | POST | `/media/upload` | High — storage cost abuse |
| `notifications.ts` | POST | `/devices` | Low |

For any route missing rate limiting, add it. The rate limiting middleware likely looks like:

```typescript
// Applying rate limit middleware to a route
app.post('/planks', rateLimit({ limit: 10, window: '1m' }), async (c) => {
    // handler
})
```

Read the existing `rateLimit` middleware implementation to understand its exact API and apply it consistently.

### Step 4c — Verify rate limits are per-user, not per-IP only

IP-based rate limiting is easily bypassed by rotating IPs (VPNs, proxies). For authenticated endpoints, rate limits must be applied **per authenticated user ID**, not per IP.

Read the rate limiting middleware and verify it uses the authenticated user's ID (from the JWT) as the rate limit key for authenticated routes, and falls back to IP for unauthenticated routes (login, register).

```typescript
// Correct — rate limit key is user ID for authenticated requests
const rateLimitKey = c.get('userId') ?? c.req.header('CF-Connecting-IP') ?? 'unknown'
```

If the current implementation uses only IP: update it to use the user ID from the JWT payload for authenticated endpoints.

### Step 4d — Verify plank creation has fraud detection

The plank endpoint is the most sensitive from an integrity standpoint — it feeds the leaderboard. Verify the backend applies the minimum duration threshold (the plan specifies 10 seconds; the code may have relaxed this to 1 second — verify and set it correctly):

```typescript
// In planks.ts POST handler
const MIN_PLANK_DURATION_SECONDS = 10

if (body.durationSeconds < MIN_PLANK_DURATION_SECONDS) {
    return c.json({ success: false, error: { code: 'INVALID_DURATION', message: 'Plank must be at least 10 seconds.' } }, 400)
}
```

Also verify the backend checks that the plank's `date` is not in the future (beyond a small clock-skew tolerance of ~5 minutes):

```typescript
const MAX_FUTURE_SKEW_MS = 5 * 60 * 1000 // 5 minutes

if (new Date(body.date).getTime() > Date.now() + MAX_FUTURE_SKEW_MS) {
    return c.json({ success: false, error: { code: 'INVALID_DATE', message: 'Plank date cannot be in the future.' } }, 400)
}
```

---

## Step 5 — Audit Backend Input Validation

Every route that accepts a request body must validate it with Zod (already used in the project via `@hono/zod-validator`). Read each route file and verify validation is present and complete.

### Step 5a — Verify Zod schemas exist for all request bodies

Search `backend/src/routes/` for routes that accept POST/PUT/PATCH bodies. For each, verify there is a corresponding Zod schema applied via `zValidator('json', schema)`.

If any route accepts a body without Zod validation, it is accepting arbitrary JSON from clients — add a schema immediately.

### Step 5b — Verify string fields have max length constraints in Zod schemas

Zod schemas must enforce the same length limits as the iOS client:

```typescript
const updateProfileSchema = z.object({
    displayName: z.string().min(1).max(50).trim().optional(),
    bio: z.string().max(200).trim().optional(),
    location: z.string().max(100).trim().optional(),
    // social links must be valid HTTPS URLs
    instagramUrl: z.string().url().startsWith('https://').max(200).optional().nullable(),
})
```

Verify `.trim()` is applied in Zod schemas so that whitespace-only strings are caught before hitting the database.

### Step 5c — Verify numeric fields have range constraints

```typescript
const createPlankSchema = z.object({
    clientId: z.string().uuid(),
    durationSeconds: z.number().int().min(10).max(86400), // 10s min, 24h max
    date: z.string().datetime(),
    plankType: z.enum(['elbow', 'high', 'side_left', 'side_right', 'reverse']),
    inputMethod: z.enum(['timer', 'manual', 'watch']),
    timezone: z.string().max(50),
})
```

Read the existing schema for `POST /planks` and verify it includes all these constraints.

### Step 5d — Verify enum fields are strictly validated

Any field that should be one of a fixed set of values must use `z.enum(...)`. A field that accepts `plankType: z.string()` with no further restriction allows arbitrary strings into the database. Search for `z.string()` on fields that should be enums and tighten them.

---

## Step 6 — Audit JWT Security

The app uses JWTs for authentication. Read `backend/src/` and `backend/src/middleware/` to verify the following:

### Step 6a — Verify access token expiry is short

Access tokens should expire in **15 minutes to 1 hour** maximum. A stolen access token is valid until it expires — shorter expiry limits the damage window.

Find where the access token expiry is set (likely in `auth.ts` or a utility function) and verify it is not set to days or weeks.

### Step 6b — Verify refresh token rotation

When a refresh token is used to obtain a new access token, the old refresh token should be invalidated and a new one issued. This limits the damage if a refresh token is stolen — using a stolen token will invalidate the legitimate session and alert the user (their next refresh will fail).

Verify this pattern in `auth.ts` refresh endpoint:

```typescript
// POST /auth/refresh
// 1. Validate the submitted refresh token
// 2. Issue new access token + new refresh token
// 3. Invalidate the old refresh token in the database/KV
// 4. Return both new tokens
```

If the current implementation issues a new access token but reuses the same refresh token — fix it to rotate.

### Step 6c — Verify the JWT signing secret is strong and from environment

The JWT signing secret must be:
1. At least 256 bits (32 bytes) of random data
2. Stored as a Cloudflare Worker secret (`wrangler secret put JWT_SECRET`), not hardcoded in source code

Search `backend/src/` for any hardcoded secret strings:
- Strings that look like base64-encoded secrets
- Variables named `secret`, `jwtSecret`, `signingKey` assigned a string literal

If found: replace with `c.env.JWT_SECRET` and ensure the secret is set via `wrangler secret`.

### Step 6d — Verify JWT algorithm is specified explicitly

The `jose` library must be configured with an explicit algorithm. Never use `"HS256"` as a string without validating it matches what was used for signing:

```typescript
// Signing (in auth.ts)
const token = await new SignJWT(payload)
    .setProtectedHeader({ alg: 'HS256' })
    .setExpirationTime('15m')
    .sign(secret)

// Verifying (in middleware)
const { payload } = await jwtVerify(token, secret, {
    algorithms: ['HS256'] // explicitly allowlist the algorithm
})
```

Verify `algorithms` is explicitly specified in the `jwtVerify` call. Without it, a crafted token could potentially specify `alg: none` and bypass verification (the `none` algorithm attack).

---

## Step 7 — Audit Media Upload Security

Profile photos are uploaded via `POST /media/upload` to Cloudflare R2. Audit this endpoint for:

### Step 7a — Verify file type validation

The backend must validate that uploaded files are actually images, not executable code or malicious files disguised with an image extension:

```typescript
// In media.ts
const ALLOWED_MIME_TYPES = ['image/jpeg', 'image/png', 'image/webp', 'image/heic']
const MAX_FILE_SIZE_BYTES = 5 * 1024 * 1024 // 5MB

const contentType = c.req.header('Content-Type') ?? ''
if (!ALLOWED_MIME_TYPES.includes(contentType)) {
    return c.json({ error: 'Invalid file type' }, 400)
}

const body = await c.req.arrayBuffer()
if (body.byteLength > MAX_FILE_SIZE_BYTES) {
    return c.json({ error: 'File too large' }, 400)
}
```

Verify both MIME type and file size checks exist. Note: MIME type validation based on `Content-Type` header alone is insufficient — a client can send `Content-Type: image/jpeg` with a non-image payload. If possible, add magic byte validation (checking the first few bytes of the file against known image signatures).

### Step 7b — Verify uploaded files are stored with random names

Profile photos must not be stored with predictable filenames (e.g. the user's ID or email). Use a random UUID as the filename:

```typescript
const fileKey = `avatars/${crypto.randomUUID()}.jpg`
await c.env.MEDIA.put(fileKey, body, { httpMetadata: { contentType } })
```

Verify this is the case in `media.ts`. A predictable filename allows anyone to enumerate or access other users' photos directly from R2.

### Step 7c — Verify R2 bucket is not publicly accessible

Verify in `wrangler.toml` or Cloudflare dashboard that the R2 bucket does not have public access enabled unless files are explicitly served through a Worker that checks authentication. Profile photos should be served through signed URLs or a Worker proxy, not directly from a public R2 URL.

---

## Step 8 — Audit CORS and Header Security on the Backend

### Step 8a — Verify CORS is locked down

The backend should not accept requests from arbitrary origins. Read `backend/src/index.ts` for CORS middleware configuration:

```typescript
// Correct — restrict to known origins
app.use('*', cors({
    origin: [
        'https://plankchallenge.app', // production web (if any)
    ],
    allowMethods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowHeaders: ['Content-Type', 'Authorization', 'X-Timezone'],
    credentials: true,
}))
```

If `origin: '*'` is used — tighten it. The native iOS app does not need CORS (it is not a browser), so CORS primarily applies to any web-facing surface. If there is no web app, CORS can be set to a specific non-wildcard value or disabled for non-browser clients.

### Step 8b — Verify security headers are set

Ensure the backend sets these headers on all responses (add as middleware in `index.ts`):

```typescript
app.use('*', async (c, next) => {
    await next()
    c.header('X-Content-Type-Options', 'nosniff')
    c.header('X-Frame-Options', 'DENY')
    c.header('Referrer-Policy', 'strict-origin-when-cross-origin')
    // Note: Strict-Transport-Security is handled by Cloudflare automatically for proxied domains
})
```

### Step 8c — Verify the `X-Timezone` header is validated

The iOS app sends `X-Timezone` on every request. Verify the backend validates this against a list of known IANA timezone identifiers before using it in date calculations — an arbitrary string in this field could cause unexpected behaviour:

```typescript
import { IANAZone } from 'luxon' // or use Temporal / Intl

const timezone = c.req.header('X-Timezone') ?? 'UTC'
const validTimezone = Intl.supportedValuesOf('timeZone').includes(timezone)
    ? timezone
    : 'UTC'
```

---

## Step 9 — Audit Data Exposure in API Responses

Verify the backend never returns sensitive fields in API responses that the client does not need.

### Step 9a — Verify password hashes are never returned

If user records are fetched from the database and returned directly as JSON (without field selection), password hashes could leak. Search `backend/src/routes/users.ts` and `backend/src/routes/auth.ts` for any place where a full database row is returned:

```typescript
// Dangerous — returns all columns including password hash
const user = await db.select().from(users).where(eq(users.id, userId))
return c.json(user)

// Correct — select only the columns needed
const user = await db.select({
    id: users.id,
    displayName: users.displayName,
    email: users.email,
    // explicitly exclude: passwordHash, refreshToken, etc.
}).from(users).where(eq(users.id, userId))
```

Verify every user query explicitly selects only the columns that should be in the response.

### Step 9b — Verify one user cannot access another user's private data

The app has private profile data (email, device tokens, internal IDs). Verify that every endpoint that returns user data by ID checks that either:
1. The requesting user is the owner (`c.get('userId') === params.userId`)
2. Or the data returned is the public profile only (display name, streak, badges — not email)

Search `backend/src/routes/users.ts` for routes like `GET /users/:id` and verify the response schema differs for own-profile vs. other-user requests.

---

## Step 10 — Final Verification Checklist

Before considering this quality check complete, confirm each of the following:

**iOS — Keychain & Storage**
- [ ] JWT access token stored in Keychain only — not in `UserDefaults` or `@AppStorage`
- [ ] JWT refresh token stored in Keychain only
- [ ] Keychain items use `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`
- [ ] All Keychain items deleted on logout
- [ ] All Keychain items deleted on account deletion
- [ ] No sensitive profile data (email, full profile) cached in `UserDefaults`

**iOS — Input Validation**
- [ ] All `TextField` and `TextEditor` inputs have max length limits matching backend validation
- [ ] `InputLimit` constants defined and applied consistently
- [ ] Whitespace trimmed before submission in all service methods
- [ ] Social link inputs validated as HTTPS URLs before submission

**Backend — Rate Limiting**
- [ ] Rate limiting applied to all auth endpoints (login, register, refresh, Apple)
- [ ] Rate limiting applied to `POST /planks` (plank creation)
- [ ] Rate limiting applied to all other mutating endpoints
- [ ] Rate limit key is user ID (from JWT) for authenticated endpoints, IP for unauthenticated
- [ ] Minimum plank duration enforced server-side (≥10 seconds)
- [ ] Future-dated plank creation rejected (beyond 5-minute clock skew tolerance)

**Backend — Input Validation**
- [ ] Zod schema present for every request body on POST/PUT/PATCH routes
- [ ] All string fields have `.max()` length constraints in Zod schemas
- [ ] All string fields use `.trim()` in Zod schemas
- [ ] Numeric fields have `.min()` and `.max()` range constraints
- [ ] Enum fields use `z.enum(...)` not `z.string()`

**Backend — JWT Security**
- [ ] Access token expiry is 15 minutes to 1 hour maximum
- [ ] Refresh token is rotated (invalidated and replaced) on each use
- [ ] JWT signing secret stored as Cloudflare Worker secret — not hardcoded
- [ ] `jwtVerify` explicitly specifies `algorithms: ['HS256']`

**Backend — Media Upload**
- [ ] MIME type validated against allowlist (`image/jpeg`, `image/png`, `image/webp`, `image/heic`)
- [ ] File size limit enforced (≤5MB)
- [ ] Files stored with random UUID filenames
- [ ] R2 bucket not publicly accessible without authentication

**Backend — API Hygiene**
- [ ] CORS not set to wildcard `'*'`
- [ ] Security headers set: `X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy`
- [ ] `X-Timezone` header validated against IANA timezone list before use
- [ ] No password hashes or internal fields returned in any API response
- [ ] Own-profile vs. other-user profile responses use different field sets
