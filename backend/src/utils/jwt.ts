import * as jose from 'jose';
import type { JwtPayload, AuthTokens } from '../types/api';

const ACCESS_TOKEN_EXPIRY = '1h';
const REFRESH_TOKEN_EXPIRY = '30d';

/**
 * Generate a JWT access token
 */
export async function generateAccessToken(
  userId: string,
  email: string,
  secret: string
): Promise<string> {
  const secretKey = new TextEncoder().encode(secret);
  
  return await new jose.SignJWT({
    sub: userId,
    email,
  })
    .setProtectedHeader({ alg: 'HS256', typ: 'JWT' })
    .setIssuedAt()
    .setExpirationTime(ACCESS_TOKEN_EXPIRY)
    .setJti(crypto.randomUUID())
    .sign(secretKey);
}

/**
 * Generate a JWT refresh token
 */
export async function generateRefreshToken(
  userId: string,
  secret: string
): Promise<string> {
  const secretKey = new TextEncoder().encode(secret);
  
  return await new jose.SignJWT({
    sub: userId,
    type: 'refresh',
  })
    .setProtectedHeader({ alg: 'HS256', typ: 'JWT' })
    .setIssuedAt()
    .setExpirationTime(REFRESH_TOKEN_EXPIRY)
    .setJti(crypto.randomUUID())
    .sign(secretKey);
}

/**
 * Generate both access and refresh tokens
 */
export async function generateTokens(
  userId: string,
  email: string,
  secret: string
): Promise<AuthTokens> {
  const [accessToken, refreshToken] = await Promise.all([
    generateAccessToken(userId, email, secret),
    generateRefreshToken(userId, secret),
  ]);

  return {
    accessToken,
    refreshToken,
    expiresIn: 3600, // 1 hour in seconds
  };
}

/**
 * Verify and decode a JWT token
 */
export async function verifyToken(
  token: string,
  secret: string
): Promise<JwtPayload | null> {
  try {
    const secretKey = new TextEncoder().encode(secret);
    const { payload } = await jose.jwtVerify(token, secretKey);
    
    return {
      sub: payload.sub as string,
      email: payload.email as string | undefined,
      type: payload.type as 'refresh' | undefined,
      iat: payload.iat as number,
      exp: payload.exp as number,
      jti: payload.jti as string,
    };
  } catch (error) {
    return null;
  }
}

/**
 * Decode a JWT token without verification (for debugging)
 */
export function decodeToken(token: string): JwtPayload | null {
  try {
    const payload = jose.decodeJwt(token);
    return {
      sub: payload.sub as string,
      email: payload.email as string,
      iat: payload.iat as number,
      exp: payload.exp as number,
      jti: payload.jti as string,
    };
  } catch {
    return null;
  }
}

/**
 * Extract the token from the Authorization header
 */
export function extractBearerToken(authHeader: string | undefined): string | null {
  if (!authHeader?.startsWith('Bearer ')) {
    return null;
  }
  return authHeader.slice(7);
}
