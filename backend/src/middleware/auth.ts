import { Context, Next } from 'hono';
import { verifyToken, extractBearerToken } from '../utils/jwt';
import { errors } from '../utils/response';
import type { Env, Variables } from '../types/env';

/**
 * Authentication middleware
 * Validates JWT token and sets userId in context
 */
export async function authMiddleware(
  c: Context<{ Bindings: Env; Variables: Variables }>,
  next: Next
) {
  const authHeader = c.req.header('Authorization');
  const token = extractBearerToken(authHeader);

  if (!token) {
    return errors.unauthorized(c);
  }

  const payload = await verifyToken(token, c.env.JWT_SECRET);

  if (!payload) {
    return errors.tokenInvalid(c);
  }

  // Check if token is expired
  if (payload.exp && payload.exp < Math.floor(Date.now() / 1000)) {
    return errors.tokenExpired(c);
  }

  // Set user ID in context for downstream handlers
  c.set('userId', payload.sub);

  await next();
}

/**
 * Optional authentication middleware
 * Sets userId if token is valid, but doesn't require it
 */
export async function optionalAuthMiddleware(
  c: Context<{ Bindings: Env; Variables: Variables }>,
  next: Next
) {
  const authHeader = c.req.header('Authorization');
  const token = extractBearerToken(authHeader);

  if (token) {
    const payload = await verifyToken(token, c.env.JWT_SECRET);
    if (payload && (!payload.exp || payload.exp >= Math.floor(Date.now() / 1000))) {
      c.set('userId', payload.sub);
    }
  }

  await next();
}
