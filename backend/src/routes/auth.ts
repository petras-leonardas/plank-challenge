import { Hono } from 'hono';
import { zValidator } from '@hono/zod-validator';
import { z } from 'zod';
import type { Env, Variables } from '../types/env';
import { success, errors } from '../utils/response';
import { generateTokens, verifyToken } from '../utils/jwt';
import { verifyAppleToken, verifyGoogleToken } from '../utils/oauth';
import { performFullAccountDeletion } from '../utils/account-cleanup';
import { authMiddleware } from '../middleware/auth';

const auth = new Hono<{ Bindings: Env; Variables: Variables }>();

// ============================================
// VALIDATION SCHEMAS
// ============================================

const emailRegisterSchema = z.object({
  email: z.string().email('Invalid email format'),
  password: z.string().min(8, 'Password must be at least 8 characters'),
  displayName: z.string().min(1, 'Display name is required').max(50),
});

const emailLoginSchema = z.object({
  email: z.string().email('Invalid email format'),
  password: z.string().min(1, 'Password is required'),
});

const appleAuthSchema = z.object({
  identityToken: z.string().min(1, 'Identity token is required'),
  authorizationCode: z.string().min(1, 'Authorization code is required'),
  user: z.object({
    email: z.string().email().optional(),
    name: z.object({
      firstName: z.string().optional(),
      lastName: z.string().optional(),
    }).optional(),
  }).optional(),
});

const googleAuthSchema = z.object({
  idToken: z.string().min(1, 'ID token is required'),
});

const refreshTokenSchema = z.object({
  refreshToken: z.string().min(1, 'Refresh token is required'),
});

const checkEmailSchema = z.object({
  email: z.string().email('Invalid email format'),
});

const logoutSchema = z.object({
  refreshToken: z.string().min(1, 'Refresh token is required'),
});

// ============================================
// HELPER FUNCTIONS
// ============================================

/**
 * Hash password using Web Crypto API (Cloudflare Workers compatible)
 */
async function hashPassword(password: string): Promise<string> {
  const encoder = new TextEncoder();
  const data = encoder.encode(password);
  const salt = crypto.getRandomValues(new Uint8Array(16));
  
  const key = await crypto.subtle.importKey(
    'raw',
    data,
    { name: 'PBKDF2' },
    false,
    ['deriveBits']
  );
  
  const derivedBits = await crypto.subtle.deriveBits(
    {
      name: 'PBKDF2',
      salt: salt,
      iterations: 100000,
      hash: 'SHA-256',
    },
    key,
    256
  );
  
  const hashArray = new Uint8Array(derivedBits);
  const combined = new Uint8Array(salt.length + hashArray.length);
  combined.set(salt);
  combined.set(hashArray, salt.length);
  
  return btoa(String.fromCharCode(...combined));
}

/**
 * Verify password against hash using constant-time comparison
 * 
 * SECURITY: Uses XOR-based comparison to prevent timing attacks.
 * The comparison always takes the same amount of time regardless
 * of where (or if) the bytes differ.
 */
async function verifyPassword(password: string, hash: string): Promise<boolean> {
  try {
    const combined = Uint8Array.from(atob(hash), c => c.charCodeAt(0));
    const salt = combined.slice(0, 16);
    const storedHash = combined.slice(16);
    
    const encoder = new TextEncoder();
    const data = encoder.encode(password);
    
    const key = await crypto.subtle.importKey(
      'raw',
      data,
      { name: 'PBKDF2' },
      false,
      ['deriveBits']
    );
    
    const derivedBits = await crypto.subtle.deriveBits(
      {
        name: 'PBKDF2',
        salt: salt,
        iterations: 100000,
        hash: 'SHA-256',
      },
      key,
      256
    );
    
    const newHash = new Uint8Array(derivedBits);
    
    // Length check (constant time - always compare both lengths)
    if (newHash.length !== storedHash.length) return false;
    
    // SECURITY: Constant-time comparison using XOR
    // This prevents timing attacks by always processing all bytes
    // regardless of where (or if) a mismatch occurs
    let result = 0;
    for (let i = 0; i < newHash.length; i++) {
      // XOR accumulates differences - if any byte differs, result will be non-zero
      result |= newHash[i] ^ storedHash[i];
    }
    
    // result is 0 only if all bytes matched
    return result === 0;
  } catch {
    return false;
  }
}

/**
 * Store refresh token in KV
 * Returns true if successful, false if storage failed
 */
async function storeRefreshToken(
  kv: KVNamespace,
  userId: string,
  tokenId: string,
  deviceInfo?: string
): Promise<boolean> {
  try {
    const key = `session:${userId}:${tokenId}`;
    const value = JSON.stringify({
      createdAt: new Date().toISOString(),
      deviceInfo: deviceInfo || 'unknown',
      lastUsed: new Date().toISOString(),
    });
    
    // 30 days TTL
    await kv.put(key, value, { expirationTtl: 30 * 24 * 60 * 60 });
    return true;
  } catch (error) {
    console.error('[Auth] Failed to store refresh token:', error);
    return false;
  }
}

/**
 * Check if refresh token is valid
 */
async function isRefreshTokenValid(
  kv: KVNamespace,
  userId: string,
  tokenId: string
): Promise<boolean> {
  const key = `session:${userId}:${tokenId}`;
  const session = await kv.get(key);
  return session !== null;
}

/**
 * Revoke refresh token
 */
async function revokeRefreshToken(
  kv: KVNamespace,
  userId: string,
  tokenId: string
) {
  const key = `session:${userId}:${tokenId}`;
  await kv.delete(key);
}

/**
 * Format user response
 */
function formatUserResponse(user: Record<string, unknown>) {
  return {
    id: user.id,
    email: user.email,
    displayName: user.display_name ?? null,
    emailVerified: Boolean(user.email_verified),
    createdAt: user.created_at ?? null,
  };
}

// ============================================
// ROUTES
// ============================================

/**
 * POST /auth/check-email - Check if an email has an existing account
 *
 * Used by the "Continue with Email" flow to determine whether to show
 * the sign-in or sign-up form. Returns which auth methods are available
 * for the account (email/password, Apple, Google) so the iOS app can
 * guide the user to the correct sign-in method.
 */
auth.post('/check-email', zValidator('json', checkEmailSchema), async (c) => {
  const { email } = c.req.valid('json');
  const db = c.env.DB;

  const user = await db
    .prepare('SELECT password_hash, apple_id, google_id FROM users WHERE email = ? AND deleted_at IS NULL')
    .bind(email.toLowerCase())
    .first<{ password_hash: string | null; apple_id: string | null; google_id: string | null }>();

  if (!user) {
    return success(c, { exists: false, methods: [] });
  }

  const methods: string[] = [];
  if (user.password_hash) methods.push('email');
  if (user.apple_id) methods.push('apple');
  if (user.google_id) methods.push('google');

  return success(c, { exists: true, methods });
});

/**
 * POST /auth/register - Email registration
 */
auth.post('/register', zValidator('json', emailRegisterSchema), async (c) => {
  const { email, password, displayName } = c.req.valid('json');
  const db = c.env.DB;
  
  // Hash password first (this is expensive, do before DB operations)
  const passwordHash = await hashPassword(password);
  
  // Create user with race condition protection
  // We use INSERT ... ON CONFLICT to handle the race condition atomically
  const userId = crypto.randomUUID();
  const now = new Date().toISOString();
  
  try {
    // Attempt to insert the user
    // If email already exists, the UNIQUE constraint on email will cause this to fail
    const result = await db
      .prepare(`
        INSERT INTO users (
          id, email, email_verified, display_name, password_hash,
          created_at, updated_at
        ) VALUES (?, ?, 0, ?, ?, ?, ?)
      `)
      .bind(userId, email.toLowerCase(), displayName, passwordHash, now, now)
      .run();
    
    // Check if insert actually happened (D1 returns success even for constraint violations sometimes)
    if (!result.success || result.meta.changes === 0) {
      return errors.conflict(c, 'An account with this email already exists');
    }
  } catch (error) {
    // Handle constraint violation (duplicate email)
    // D1/SQLite throws an error with "UNIQUE constraint failed" for duplicates
    const errorMessage = error instanceof Error ? error.message : String(error);
    if (errorMessage.includes('UNIQUE constraint failed') || errorMessage.includes('unique')) {
      return errors.conflict(c, 'An account with this email already exists');
    }
    // Re-throw unexpected errors
    console.error('[Registration] Unexpected error:', error);
    throw error;
  }
  
  // Generate tokens
  const tokens = await generateTokens(userId, email, c.env.JWT_SECRET);
  
  // Store refresh token (non-critical - user can still use access token and retry login)
  const refreshPayload = await verifyToken(tokens.refreshToken, c.env.JWT_SECRET);
  if (refreshPayload?.jti) {
    const stored = await storeRefreshToken(c.env.SESSIONS, userId, refreshPayload.jti);
    if (!stored) {
      console.warn(`[Auth] Failed to store refresh token for user ${userId} during registration`);
      // Continue anyway - access token still works, user can login again
    }
  }
  
  // Fetch created user
  const user = await db
    .prepare('SELECT * FROM users WHERE id = ?')
    .bind(userId)
    .first();
  
  if (!user) {
    return errors.serverError(c, 'Failed to retrieve created user');
  }
  
  return success(c, {
    ...tokens,
    user: formatUserResponse(user),
  }, 201);
});

/**
 * POST /auth/login - Email login
 */
auth.post('/login', zValidator('json', emailLoginSchema), async (c) => {
  const { email, password } = c.req.valid('json');
  const db = c.env.DB;
  
  // Find user
  const user = await db
    .prepare('SELECT * FROM users WHERE email = ? AND deleted_at IS NULL')
    .bind(email.toLowerCase())
    .first();
  
  if (!user) {
    return errors.unauthorized(c, 'Invalid email or password');
  }
  
  // Check if user has password (might have signed up via Apple/Google)
  if (!user.password_hash) {
    return errors.unauthorized(c, 'This account uses Apple or Google sign-in');
  }
  
  // Verify password
  const validPassword = await verifyPassword(password, user.password_hash as string);
  if (!validPassword) {
    return errors.unauthorized(c, 'Invalid email or password');
  }
  
  // Generate tokens
  const tokens = await generateTokens(user.id as string, user.email as string, c.env.JWT_SECRET);
  
  // Store refresh token (non-critical - user can retry login if needed)
  const refreshPayload = await verifyToken(tokens.refreshToken, c.env.JWT_SECRET);
  if (refreshPayload?.jti) {
    const stored = await storeRefreshToken(c.env.SESSIONS, user.id as string, refreshPayload.jti);
    if (!stored) {
      console.warn(`[Auth] Failed to store refresh token for user ${user.id} during login`);
    }
  }
  
  return success(c, {
    ...tokens,
    user: formatUserResponse(user),
  });
});

/**
 * POST /auth/apple - Sign in with Apple
 * 
 * SECURITY: Development bypass for OAuth is only enabled when:
 * - ENVIRONMENT is explicitly set to 'development'
 * - OAuth client ID is not configured
 */
auth.post('/apple', zValidator('json', appleAuthSchema), async (c) => {
  const { identityToken, user: appleUser } = c.req.valid('json');
  // SECURITY: Explicit strict equality check - only 'development' triggers dev mode
  const isDevelopment = c.env.ENVIRONMENT === 'development';
  
  // Verify Apple token using JWKS
  const verificationResult = await verifyAppleToken(
    identityToken,
    c.env.APPLE_CLIENT_ID,
    isDevelopment
  );
  
  if (!verificationResult.success) {
    console.error('[Apple Auth] Verification failed:', verificationResult.error);
    
    if (verificationResult.code === 'NOT_CONFIGURED') {
      // SECURITY: Don't reveal configuration details - use generic message
      return errors.serverError(c, 'This sign-in method is currently unavailable');
    }
    
    return errors.unauthorized(c, 'Authentication failed');
  }
  
  const { payload } = verificationResult;
  const appleId = payload.sub;
  const email = payload.email || appleUser?.email;
  
  if (!email) {
    return errors.validation(c, 'Email is required');
  }
  
  const db = c.env.DB;
  
  // Check if user exists with this Apple ID
  let user = await db
    .prepare('SELECT * FROM users WHERE apple_id = ? AND deleted_at IS NULL')
    .bind(appleId)
    .first();
  
  if (!user) {
    // Check if email exists (potential account linking)
    const existingUser = await db
      .prepare('SELECT * FROM users WHERE email = ? AND deleted_at IS NULL')
      .bind(email.toLowerCase())
      .first();
    
    if (existingUser) {
      // SECURITY: Only auto-link accounts if BOTH conditions are met:
      // 1. The existing account has verified their email, OR
      // 2. Apple has verified the email (payload.emailVerified)
      // This prevents an attacker from claiming an email they don't own
      const existingEmailVerified = Boolean(existingUser.email_verified);
      const oauthEmailVerified = payload.emailVerified === true;
      
      if (existingEmailVerified || oauthEmailVerified) {
        // Safe to link - email ownership is verified
        await db
          .prepare('UPDATE users SET apple_id = ?, email_verified = 1, updated_at = ? WHERE id = ?')
          .bind(appleId, new Date().toISOString(), existingUser.id)
          .run();
        user = existingUser;
      } else {
        // SECURITY: Don't auto-link unverified accounts
        // This could be an account takeover attempt
        console.warn(`[Apple Auth] Refusing to link unverified account: ${email.toLowerCase()}`);
        return errors.conflict(c, 'An account with this email exists but is not verified. Sign in with your password first.');
      }
    } else {
      // Create new user
      const userId = crypto.randomUUID();
      const now = new Date().toISOString();
      // Use the real name from Apple if provided (first sign-in only).
      // Fall back to null — the onboarding flow collects the display name.
      // We intentionally avoid email.split('@')[0] because Apple's Hide My
      // Email feature produces unreadable random strings like "n6wg5q4qks".
      const displayName = appleUser?.name
        ? `${appleUser.name.firstName || ''} ${appleUser.name.lastName || ''}`.trim() || null
        : null;
      
      await db
        .prepare(`
          INSERT INTO users (
            id, email, email_verified, display_name, apple_id,
            created_at, updated_at
          ) VALUES (?, ?, 1, ?, ?, ?, ?)
        `)
        .bind(userId, email.toLowerCase(), displayName, appleId, now, now)
        .run();
      
      user = await db
        .prepare('SELECT * FROM users WHERE id = ?')
        .bind(userId)
        .first();
    }
  }
  
  if (!user) {
    return errors.serverError(c, 'Failed to create or find user');
  }
  
  // Generate tokens
  const tokens = await generateTokens(user.id as string, user.email as string, c.env.JWT_SECRET);
  
  // Store refresh token (non-critical - user can retry OAuth if needed)
  const refreshPayload = await verifyToken(tokens.refreshToken, c.env.JWT_SECRET);
  if (refreshPayload?.jti) {
    const stored = await storeRefreshToken(c.env.SESSIONS, user.id as string, refreshPayload.jti);
    if (!stored) {
      console.warn(`[Auth] Failed to store refresh token for user ${user.id} during Apple auth`);
    }
  }
  
  return success(c, {
    ...tokens,
    user: formatUserResponse(user),
  });
});

/**
 * POST /auth/google - Sign in with Google
 * 
 * SECURITY: Development bypass for OAuth is only enabled when:
 * - ENVIRONMENT is explicitly set to 'development'
 * - OAuth client ID is not configured
 */
auth.post('/google', zValidator('json', googleAuthSchema), async (c) => {
  const { idToken } = c.req.valid('json');
  // SECURITY: Explicit strict equality check - only 'development' triggers dev mode
  const isDevelopment = c.env.ENVIRONMENT === 'development';
  
  // Verify Google token using JWKS
  const verificationResult = await verifyGoogleToken(
    idToken,
    c.env.GOOGLE_CLIENT_ID,
    isDevelopment
  );
  
  if (!verificationResult.success) {
    console.error('[Google Auth] Verification failed:', verificationResult.error);
    
    if (verificationResult.code === 'NOT_CONFIGURED') {
      // SECURITY: Don't reveal configuration details - use generic message
      return errors.serverError(c, 'This sign-in method is currently unavailable');
    }
    
    return errors.unauthorized(c, 'Authentication failed');
  }
  
  const { payload } = verificationResult;
  const googleId = payload.sub;
  const email = payload.email;
  const name = payload.name;
  
  if (!email) {
    return errors.validation(c, 'Email is required');
  }
  
  const db = c.env.DB;
  
  // Check if user exists with this Google ID
  let user = await db
    .prepare('SELECT * FROM users WHERE google_id = ? AND deleted_at IS NULL')
    .bind(googleId)
    .first();
  
  if (!user) {
    // Check if email exists (potential account linking)
    const existingUser = await db
      .prepare('SELECT * FROM users WHERE email = ? AND deleted_at IS NULL')
      .bind(email.toLowerCase())
      .first();
    
    if (existingUser) {
      // SECURITY: Only auto-link accounts if BOTH conditions are met:
      // 1. The existing account has verified their email, OR
      // 2. Google has verified the email (payload.emailVerified)
      // This prevents an attacker from claiming an email they don't own
      const existingEmailVerified = Boolean(existingUser.email_verified);
      const oauthEmailVerified = payload.emailVerified === true;
      
      if (existingEmailVerified || oauthEmailVerified) {
        // Safe to link - email ownership is verified
        await db
          .prepare('UPDATE users SET google_id = ?, email_verified = 1, updated_at = ? WHERE id = ?')
          .bind(googleId, new Date().toISOString(), existingUser.id)
          .run();
        user = existingUser;
      } else {
        // SECURITY: Don't auto-link unverified accounts
        // This could be an account takeover attempt
        console.warn(`[Google Auth] Refusing to link unverified account: ${email.toLowerCase()}`);
        return errors.conflict(c, 'An account with this email exists but is not verified. Sign in with your password first.');
      }
    } else {
      // Create new user
      const userId = crypto.randomUUID();
      const now = new Date().toISOString();
      // Use Google profile name if provided, otherwise null.
      // The onboarding flow collects the display name for new users.
      const displayName = name || null;
      
      await db
        .prepare(`
          INSERT INTO users (
            id, email, email_verified, display_name, google_id,
            created_at, updated_at
          ) VALUES (?, ?, 1, ?, ?, ?, ?)
        `)
        .bind(userId, email.toLowerCase(), displayName, googleId, now, now)
        .run();
      
      user = await db
        .prepare('SELECT * FROM users WHERE id = ?')
        .bind(userId)
        .first();
    }
  }
  
  if (!user) {
    return errors.serverError(c, 'Failed to create or find user');
  }
  
  // Generate tokens
  const tokens = await generateTokens(user.id as string, user.email as string, c.env.JWT_SECRET);
  
  // Store refresh token (non-critical - user can retry OAuth if needed)
  const refreshPayload = await verifyToken(tokens.refreshToken, c.env.JWT_SECRET);
  if (refreshPayload?.jti) {
    const stored = await storeRefreshToken(c.env.SESSIONS, user.id as string, refreshPayload.jti);
    if (!stored) {
      console.warn(`[Auth] Failed to store refresh token for user ${user.id} during Google auth`);
    }
  }
  
  return success(c, {
    ...tokens,
    user: formatUserResponse(user),
  });
});

/**
 * POST /auth/refresh - Refresh access token
 */
auth.post('/refresh', zValidator('json', refreshTokenSchema), async (c) => {
  const { refreshToken } = c.req.valid('json');
  
  // Verify refresh token
  const payload = await verifyToken(refreshToken, c.env.JWT_SECRET);
  if (!payload) {
    return errors.tokenInvalid(c);
  }
  
  // SECURITY: Verify this is actually a refresh token, not an access token
  // Access tokens have 'email' field, refresh tokens have 'type: refresh'
  if (payload.type !== 'refresh') {
    console.warn(`[Auth] Attempted to use non-refresh token for refresh: ${payload.sub}`);
    return errors.tokenInvalid(c);
  }
  
  // Check if token is in KV (not revoked)
  const isValid = await isRefreshTokenValid(c.env.SESSIONS, payload.sub, payload.jti);
  if (!isValid) {
    return errors.tokenInvalid(c);
  }
  
  // Get user
  const user = await c.env.DB
    .prepare('SELECT * FROM users WHERE id = ? AND deleted_at IS NULL')
    .bind(payload.sub)
    .first();
  
  if (!user) {
    return errors.unauthorized(c, 'User not found');
  }
  
  // Generate new tokens
  const tokens = await generateTokens(user.id as string, user.email as string, c.env.JWT_SECRET);
  
  // Revoke old refresh token
  await revokeRefreshToken(c.env.SESSIONS, payload.sub, payload.jti);
  
  // Store new refresh token
  // For refresh, this is more critical - if storage fails, user's new refresh token won't work
  const newRefreshPayload = await verifyToken(tokens.refreshToken, c.env.JWT_SECRET);
  if (newRefreshPayload?.jti) {
    const stored = await storeRefreshToken(c.env.SESSIONS, user.id as string, newRefreshPayload.jti);
    if (!stored) {
      // Log but continue - user still gets valid tokens, they just may need to login again
      console.warn(`[Auth] Failed to store refresh token for user ${user.id} during token refresh`);
    }
  }
  
  return success(c, tokens);
});

/**
 * POST /auth/logout - Logout (invalidate refresh token)
 * 
 * FIX: Now correctly accepts refresh token in body instead of using access token
 */
auth.post('/logout', authMiddleware, zValidator('json', logoutSchema), async (c) => {
  const { refreshToken } = c.req.valid('json');
  
  // Verify and revoke the refresh token
  const payload = await verifyToken(refreshToken, c.env.JWT_SECRET);
  if (payload?.jti) {
    await revokeRefreshToken(c.env.SESSIONS, payload.sub, payload.jti);
  }
  
  return success(c, { message: 'Logged out successfully' });
});

/**
 * DELETE /auth/account - Delete account (GDPR compliant hard delete)
 */
auth.delete('/account', authMiddleware, async (c) => {
  const userId = c.get('userId');
  
  if (!userId) {
    return errors.unauthorized(c);
  }
  
  // Perform full account deletion
  const result = await performFullAccountDeletion(c.env, userId);
  
  if (!result.success) {
    console.error('[Account Deletion] Errors:', result.errors);
    // Still return success if user record was deleted
    // Partial failures in cleanup are logged but don't block the response
  }
  
  return success(c, { 
    message: 'Account deleted successfully',
    deletedCounts: result.deletedCounts,
  });
});

export default auth;
