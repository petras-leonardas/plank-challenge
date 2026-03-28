/**
 * OAuth Token Verification for Apple and Google Sign-In
 * 
 * Uses jose library for JWKS-based JWT verification.
 * Implements proper signature verification with cached public keys.
 */

import * as jose from 'jose';

// ============================================
// TYPES
// ============================================

export interface AppleTokenPayload {
  sub: string;              // User's unique Apple ID
  email?: string;           // User's email (may be private relay)
  emailVerified?: boolean;  // Whether email is verified
  isPrivateEmail?: boolean; // Whether using Apple's private relay
  realUserStatus?: number;  // 0=unsupported, 1=unknown, 2=likely real
}

export interface GoogleTokenPayload {
  sub: string;              // User's unique Google ID
  email?: string;           // User's email
  emailVerified?: boolean;  // Whether email is verified
  name?: string;            // Full name
  givenName?: string;       // First name
  familyName?: string;      // Last name
  picture?: string;         // Profile picture URL
  hostedDomain?: string;    // Google Workspace domain (if applicable)
}

export interface OAuthVerificationResult<T> {
  success: true;
  payload: T;
}

export interface OAuthVerificationError {
  success: false;
  error: string;
  code: 'NOT_CONFIGURED' | 'INVALID_TOKEN' | 'EXPIRED' | 'INVALID_ISSUER' | 'INVALID_AUDIENCE' | 'VERIFICATION_FAILED';
}

export type OAuthResult<T> = OAuthVerificationResult<T> | OAuthVerificationError;

// ============================================
// JWKS INSTANCES (Module-level for caching)
// ============================================

// Apple's JWKS endpoint
const APPLE_JWKS_URL = new URL('https://appleid.apple.com/auth/keys');
const appleJWKS = jose.createRemoteJWKSet(APPLE_JWKS_URL, {
  cacheMaxAge: 600000,      // 10 minutes
  cooldownDuration: 30000,  // 30 seconds between fetches
  timeoutDuration: 5000,    // 5 second timeout
});

// Google's JWKS endpoint
const GOOGLE_JWKS_URL = new URL('https://www.googleapis.com/oauth2/v3/certs');
const googleJWKS = jose.createRemoteJWKSet(GOOGLE_JWKS_URL, {
  cacheMaxAge: 600000,
  cooldownDuration: 30000,
  timeoutDuration: 5000,
});

// ============================================
// APPLE TOKEN VERIFICATION
// ============================================

/**
 * Verify an Apple Sign-In identity token
 * 
 * SECURITY: Development bypass is ONLY allowed when BOTH conditions are true:
 * 1. isDevelopment is explicitly true (ENVIRONMENT === 'development')
 * 2. clientId is not configured
 * 
 * In production, missing clientId always results in an error.
 * 
 * @param idToken - The identity token from Apple Sign-In
 * @param clientId - Your app's Bundle ID (e.g., "com.plankchallenge.app")
 * @param isDevelopment - If true and clientId is empty, allows unverified tokens for testing
 */
export async function verifyAppleToken(
  idToken: string,
  clientId: string | undefined,
  isDevelopment: boolean = false
): Promise<OAuthResult<AppleTokenPayload>> {
  // Check if OAuth is configured
  if (!clientId) {
    // SECURITY: Only allow development bypass if explicitly in development mode
    // The isDevelopment flag must be explicitly set to true from the environment check
    if (isDevelopment === true) {
      // Additional safety: log a warning that will be visible in logs
      console.warn('[OAuth] DEVELOPMENT MODE: Apple token NOT verified - APPLE_CLIENT_ID not set');
      console.warn('[OAuth] WARNING: This should NEVER appear in production logs!');
      return decodeTokenWithoutVerification<AppleTokenPayload>(idToken, 'apple');
    }
    // Production: always fail if not configured
    console.error('[OAuth] Apple Sign-In not configured in production - rejecting request');
    return {
      success: false,
      error: 'Apple Sign-In is not available',
      code: 'NOT_CONFIGURED',
    };
  }

  try {
    const { payload } = await jose.jwtVerify(idToken, appleJWKS, {
      issuer: 'https://appleid.apple.com',
      audience: clientId,
    });

    return {
      success: true,
      payload: {
        sub: payload.sub as string,
        email: payload.email as string | undefined,
        emailVerified: payload.email_verified as boolean | undefined,
        isPrivateEmail: payload.is_private_email as boolean | undefined,
        realUserStatus: payload.real_user_status as number | undefined,
      },
    };
  } catch (error) {
    return handleJoseError(error, 'Apple');
  }
}

// ============================================
// GOOGLE TOKEN VERIFICATION
// ============================================

/**
 * Verify a Google Sign-In ID token
 * 
 * SECURITY: Development bypass is ONLY allowed when BOTH conditions are true:
 * 1. isDevelopment is explicitly true (ENVIRONMENT === 'development')
 * 2. clientId is not configured
 * 
 * In production, missing clientId always results in an error.
 * 
 * @param idToken - The ID token from Google Sign-In
 * @param clientId - Your app's Google OAuth Client ID
 * @param isDevelopment - If true and clientId is empty, allows unverified tokens for testing
 */
export async function verifyGoogleToken(
  idToken: string,
  clientId: string | undefined,
  isDevelopment: boolean = false
): Promise<OAuthResult<GoogleTokenPayload>> {
  // Check if OAuth is configured
  if (!clientId) {
    // SECURITY: Only allow development bypass if explicitly in development mode
    // The isDevelopment flag must be explicitly set to true from the environment check
    if (isDevelopment === true) {
      // Additional safety: log a warning that will be visible in logs
      console.warn('[OAuth] DEVELOPMENT MODE: Google token NOT verified - GOOGLE_CLIENT_ID not set');
      console.warn('[OAuth] WARNING: This should NEVER appear in production logs!');
      return decodeTokenWithoutVerification<GoogleTokenPayload>(idToken, 'google');
    }
    // Production: always fail if not configured
    console.error('[OAuth] Google Sign-In not configured in production - rejecting request');
    return {
      success: false,
      error: 'Google Sign-In is not available',
      code: 'NOT_CONFIGURED',
    };
  }

  try {
    const { payload } = await jose.jwtVerify(idToken, googleJWKS, {
      // Google uses two possible issuer values
      issuer: ['https://accounts.google.com', 'accounts.google.com'],
      audience: clientId,
    });

    return {
      success: true,
      payload: {
        sub: payload.sub as string,
        email: payload.email as string | undefined,
        emailVerified: payload.email_verified as boolean | undefined,
        name: payload.name as string | undefined,
        givenName: payload.given_name as string | undefined,
        familyName: payload.family_name as string | undefined,
        picture: payload.picture as string | undefined,
        hostedDomain: payload.hd as string | undefined,
      },
    };
  } catch (error) {
    return handleJoseError(error, 'Google');
  }
}

// ============================================
// HELPER FUNCTIONS
// ============================================

/**
 * Decode a JWT without verification (DEVELOPMENT ONLY)
 * This extracts claims from the token without verifying the signature.
 * NEVER use this in production!
 */
function decodeTokenWithoutVerification<T>(
  token: string,
  provider: 'apple' | 'google'
): OAuthResult<T> {
  try {
    const parts = token.split('.');
    if (parts.length !== 3) {
      return {
        success: false,
        error: 'Invalid token format',
        code: 'INVALID_TOKEN',
      };
    }

    // Decode the payload (middle part)
    const payloadJson = atob(parts[1].replace(/-/g, '+').replace(/_/g, '/'));
    const payload = JSON.parse(payloadJson);

    if (provider === 'apple') {
      return {
        success: true,
        payload: {
          sub: payload.sub,
          email: payload.email,
          emailVerified: payload.email_verified,
          isPrivateEmail: payload.is_private_email,
          realUserStatus: payload.real_user_status,
        } as T,
      };
    } else {
      return {
        success: true,
        payload: {
          sub: payload.sub,
          email: payload.email,
          emailVerified: payload.email_verified,
          name: payload.name,
          givenName: payload.given_name,
          familyName: payload.family_name,
          picture: payload.picture,
          hostedDomain: payload.hd,
        } as T,
      };
    }
  } catch {
    return {
      success: false,
      error: 'Failed to decode token',
      code: 'INVALID_TOKEN',
    };
  }
}

/**
 * Handle jose library errors and return appropriate error responses
 */
function handleJoseError(error: unknown, provider: string): OAuthVerificationError {
  if (error instanceof jose.errors.JWTExpired) {
    return {
      success: false,
      error: `${provider} token has expired`,
      code: 'EXPIRED',
    };
  }

  if (error instanceof jose.errors.JWTClaimValidationFailed) {
    const claim = error.claim;
    if (claim === 'iss') {
      return {
        success: false,
        error: `Invalid ${provider} token issuer`,
        code: 'INVALID_ISSUER',
      };
    }
    if (claim === 'aud') {
      return {
        success: false,
        error: `Invalid ${provider} token audience. Check your client ID configuration.`,
        code: 'INVALID_AUDIENCE',
      };
    }
    return {
      success: false,
      error: `${provider} token claim validation failed: ${claim}`,
      code: 'VERIFICATION_FAILED',
    };
  }

  if (error instanceof jose.errors.JWSSignatureVerificationFailed) {
    return {
      success: false,
      error: `${provider} token signature verification failed`,
      code: 'VERIFICATION_FAILED',
    };
  }

  if (error instanceof jose.errors.JWKSNoMatchingKey) {
    return {
      success: false,
      error: `No matching key found for ${provider} token. The token may be malformed.`,
      code: 'VERIFICATION_FAILED',
    };
  }

  // Generic error
  console.error(`[OAuth] ${provider} verification error:`, error);
  return {
    success: false,
    error: `${provider} token verification failed`,
    code: 'VERIFICATION_FAILED',
  };
}
