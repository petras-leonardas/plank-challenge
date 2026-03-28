import { Context } from 'hono';
import type { ContentfulStatusCode } from 'hono/utils/http-status';
import type { ApiResponse, ApiError, ErrorCode, ResponseMeta } from '../types/api';
import type { Env, Variables } from '../types/env';

/**
 * Create response metadata
 */
function createMeta(c: Context<{ Bindings: Env; Variables: Variables }>): ResponseMeta {
  return {
    timestamp: new Date().toISOString(),
    requestId: c.get('requestId') || crypto.randomUUID(),
  };
}

/**
 * Send a successful JSON response
 */
export function success<T>(
  c: Context<{ Bindings: Env; Variables: Variables }>,
  data: T,
  status: ContentfulStatusCode = 200
) {
  const response: ApiResponse<T> = {
    success: true,
    data,
    meta: createMeta(c),
  };
  return c.json(response, status);
}

/**
 * Send an error JSON response
 */
export function error(
  c: Context<{ Bindings: Env; Variables: Variables }>,
  code: ErrorCode,
  message: string,
  status: ContentfulStatusCode = 400,
  details?: Record<string, unknown>
) {
  const response: ApiError = {
    success: false,
    error: {
      code,
      message,
      ...(details && { details }),
    },
    meta: createMeta(c),
  };
  return c.json(response, status);
}

/**
 * Common error responses
 */
export const errors = {
  unauthorized: (c: Context<{ Bindings: Env; Variables: Variables }>, message = 'Authentication required') =>
    error(c, 'AUTH_REQUIRED', message, 401),

  tokenExpired: (c: Context<{ Bindings: Env; Variables: Variables }>) =>
    error(c, 'AUTH_EXPIRED', 'Token has expired', 401),

  tokenInvalid: (c: Context<{ Bindings: Env; Variables: Variables }>) =>
    error(c, 'AUTH_INVALID', 'Invalid token', 401),

  forbidden: (c: Context<{ Bindings: Env; Variables: Variables }>, message = 'Access denied') =>
    error(c, 'FORBIDDEN', message, 403),

  notFound: (c: Context<{ Bindings: Env; Variables: Variables }>, resource = 'Resource') =>
    error(c, 'NOT_FOUND', `${resource} not found`, 404),

  validation: (c: Context<{ Bindings: Env; Variables: Variables }>, message: string, details?: Record<string, unknown>) =>
    error(c, 'VALIDATION_ERROR', message, 400, details),

  conflict: (c: Context<{ Bindings: Env; Variables: Variables }>, message: string) =>
    error(c, 'CONFLICT', message, 409),

  rateLimited: (c: Context<{ Bindings: Env; Variables: Variables }>) =>
    error(c, 'RATE_LIMITED', 'Too many requests. Please try again later.', 429),

  serverError: (c: Context<{ Bindings: Env; Variables: Variables }>, message = 'Internal server error') =>
    error(c, 'SERVER_ERROR', message, 500),

  plankDeleteForbidden: (c: Context<{ Bindings: Env; Variables: Variables }>) =>
    error(c, 'PLANK_DELETE_FORBIDDEN', 'Cannot delete planks from previous days', 403),

  groupFull: (c: Context<{ Bindings: Env; Variables: Variables }>) =>
    error(c, 'GROUP_FULL', 'This group has reached its maximum capacity', 400),

  alreadyMember: (c: Context<{ Bindings: Env; Variables: Variables }>) =>
    error(c, 'ALREADY_MEMBER', 'You are already a member of this group', 409),
};
