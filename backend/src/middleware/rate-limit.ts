/**
 * Rate Limiting Middleware using Sliding Window Counter Algorithm
 * 
 * Uses Cloudflare KV for distributed rate limiting across edge locations.
 * Implements sliding window counter for accurate rate limiting with minimal storage.
 */

import { Context, Next } from 'hono';
import type { Env, Variables } from '../types/env';

// ============================================
// TYPES
// ============================================

export interface RateLimitConfig {
  /** Window size in seconds */
  windowSeconds: number;
  /** Maximum requests allowed per window */
  maxRequests: number;
  /** How long to block after limit exceeded (seconds) */
  blockDurationSeconds: number;
  /** Identifier for this endpoint type (used in KV keys) */
  endpointType: string;
}

export interface RateLimitResult {
  /** Whether the request is allowed */
  allowed: boolean;
  /** Remaining requests in current window */
  remaining: number;
  /** Unix timestamp when the limit resets */
  resetAt: number;
  /** Seconds until retry is allowed (only set if blocked) */
  retryAfter?: number;
}

interface WindowData {
  count: number;
  timestamp: number;
}

// ============================================
// RATE LIMIT CONFIGURATIONS
// ============================================

export const RATE_LIMITS: Record<string, RateLimitConfig> = {
  // Auth endpoints - strict limits to prevent brute force
  'auth:login': {
    endpointType: 'auth:login',
    windowSeconds: 60,
    maxRequests: 5,
    blockDurationSeconds: 300, // 5 minute block
  },
  'auth:register': {
    endpointType: 'auth:register',
    windowSeconds: 3600,
    maxRequests: 5,
    blockDurationSeconds: 3600, // 1 hour block
  },
  'auth:refresh': {
    endpointType: 'auth:refresh',
    windowSeconds: 60,
    maxRequests: 10,
    blockDurationSeconds: 60,
  },
  'auth:apple': {
    endpointType: 'auth:apple',
    windowSeconds: 60,
    maxRequests: 10,
    blockDurationSeconds: 300,
  },
  'auth:google': {
    endpointType: 'auth:google',
    windowSeconds: 60,
    maxRequests: 10,
    blockDurationSeconds: 300,
  },
  'auth:logout': {
    endpointType: 'auth:logout',
    windowSeconds: 60,
    maxRequests: 10,
    blockDurationSeconds: 60,
  },
  'auth:delete': {
    endpointType: 'auth:delete',
    windowSeconds: 3600,
    maxRequests: 3,
    blockDurationSeconds: 3600,
  },
  
  // API endpoints - more generous limits
  'api:read': {
    endpointType: 'api:read',
    windowSeconds: 60,
    maxRequests: 100,
    blockDurationSeconds: 60,
  },
  'api:write': {
    endpointType: 'api:write',
    windowSeconds: 60,
    maxRequests: 30,
    blockDurationSeconds: 60,
  },
  'api:search': {
    endpointType: 'api:search',
    windowSeconds: 60,
    maxRequests: 20,
    blockDurationSeconds: 120,
  },
  
  // Plank-specific limits - prevent spam while allowing legitimate offline sync
  'plank:create': {
    endpointType: 'plank:create',
    windowSeconds: 60,
    maxRequests: 20, // 20 planks per minute (enough for batch sync)
    blockDurationSeconds: 120,
  },
  'plank:sync': {
    endpointType: 'plank:sync',
    windowSeconds: 60,
    maxRequests: 30, // Allow frequent sync requests
    blockDurationSeconds: 60,
  },
  
  // Streak operations - more restrictive
  'streak:freeze': {
    endpointType: 'streak:freeze',
    windowSeconds: 3600,
    maxRequests: 5, // 5 freeze attempts per hour
    blockDurationSeconds: 3600,
  },
  
  // Badge and notification endpoints
  'badges:read': {
    endpointType: 'badges:read',
    windowSeconds: 60,
    maxRequests: 60, // Allow frequent badge checks
    blockDurationSeconds: 60,
  },
  'notifications:read': {
    endpointType: 'notifications:read',
    windowSeconds: 60,
    maxRequests: 60, // Allow frequent notification checks
    blockDurationSeconds: 60,
  },
  'notifications:write': {
    endpointType: 'notifications:write',
    windowSeconds: 60,
    maxRequests: 30, // Mark read, delete, etc.
    blockDurationSeconds: 60,
  },
  
  // Social endpoints - prevent follow spam
  'follow:create': {
    endpointType: 'follow:create',
    windowSeconds: 60,
    maxRequests: 10, // 10 follows per minute
    blockDurationSeconds: 300, // 5 minute block
  },
  'follow:delete': {
    endpointType: 'follow:delete',
    windowSeconds: 60,
    maxRequests: 10, // 10 unfollows per minute
    blockDurationSeconds: 300,
  },
  
  // Group endpoints - prevent group spam
  'group:create': {
    endpointType: 'group:create',
    windowSeconds: 3600,
    maxRequests: 5, // 5 groups per hour
    blockDurationSeconds: 3600,
  },
  'group:join': {
    endpointType: 'group:join',
    windowSeconds: 3600,
    maxRequests: 20, // 20 join requests per hour
    blockDurationSeconds: 1800, // 30 minute block
  },
  
  // Media endpoints - prevent upload spam
  'media:upload': {
    endpointType: 'media:upload',
    windowSeconds: 3600,
    maxRequests: 10, // 10 uploads per hour
    blockDurationSeconds: 3600,
  },
  
  // Leaderboard endpoints - prevent scraping
  'leaderboard:read': {
    endpointType: 'leaderboard:read',
    windowSeconds: 60,
    maxRequests: 30, // 30 leaderboard requests per minute
    blockDurationSeconds: 120,
  },
  
  // Device endpoints
  'device:register': {
    endpointType: 'device:register',
    windowSeconds: 3600,
    maxRequests: 20, // 20 device registrations per hour
    blockDurationSeconds: 1800,
  },
};

// ============================================
// RATE LIMITER CLASS
// ============================================

/**
 * Sliding Window Rate Limiter using Cloudflare KV
 * 
 * KNOWN LIMITATION: The check-then-increment pattern is not atomic.
 * Under extreme concurrent load, the actual request count may slightly exceed the limit.
 * This is acceptable because:
 * 1. KV's eventual consistency model doesn't support atomic increments
 * 2. The overage would be minimal (a few requests at most)
 * 3. True atomicity would require Durable Objects (more complex/costly)
 * 4. We increment BEFORE returning to be conservative
 * 
 * For most use cases, this provides sufficient protection against abuse.
 */
export class SlidingWindowRateLimiter {
  private kv: KVNamespace;
  
  constructor(kv: KVNamespace) {
    this.kv = kv;
  }
  
  /**
   * Check if a request should be rate limited
   */
  async checkLimit(
    config: RateLimitConfig,
    identifier: string
  ): Promise<RateLimitResult> {
    const now = Math.floor(Date.now() / 1000);
    const windowStart = Math.floor(now / config.windowSeconds) * config.windowSeconds;
    const previousWindowStart = windowStart - config.windowSeconds;
    const windowProgress = (now - windowStart) / config.windowSeconds;
    
    // Generate keys
    const currentKey = `rl:${config.endpointType}:${identifier}:${windowStart}`;
    const previousKey = `rl:${config.endpointType}:${identifier}:${previousWindowStart}`;
    const blockKey = `rl:block:${config.endpointType}:${identifier}`;
    
    // Check if currently blocked
    const blockData = await this.kv.get(blockKey);
    if (blockData) {
      const blockExpiry = parseInt(blockData, 10);
      if (blockExpiry > now) {
        return {
          allowed: false,
          remaining: 0,
          resetAt: blockExpiry,
          retryAfter: blockExpiry - now,
        };
      }
    }
    
    // Fetch both windows in parallel
    const [currentData, previousData] = await Promise.all([
      this.kv.get(currentKey, 'json') as Promise<WindowData | null>,
      this.kv.get(previousKey, 'json') as Promise<WindowData | null>,
    ]);
    
    const currentCount = currentData?.count ?? 0;
    const previousCount = previousData?.count ?? 0;
    
    // Calculate weighted count using sliding window formula
    // Weight previous window by how much time is left in current window
    const weightedCount = Math.floor(
      previousCount * (1 - windowProgress) + currentCount
    );
    
    const resetAt = windowStart + config.windowSeconds;
    
    // Check if limit exceeded
    if (weightedCount >= config.maxRequests) {
      // Set block
      await this.kv.put(
        blockKey,
        String(now + config.blockDurationSeconds),
        { expirationTtl: config.blockDurationSeconds }
      );
      
      return {
        allowed: false,
        remaining: 0,
        resetAt: now + config.blockDurationSeconds,
        retryAfter: config.blockDurationSeconds,
      };
    }
    
    // IMPORTANT: Increment counter BEFORE returning success
    // This is conservative - we count the request even before processing completes
    // This helps mitigate race conditions by counting requests as early as possible
    const newCount = currentCount + 1;
    const newData: WindowData = { count: newCount, timestamp: now };
    
    // Store updated count (with TTL for automatic cleanup)
    // Note: We don't await this - fire and forget for better latency
    // The slight risk of under-counting on failure is acceptable
    this.kv.put(currentKey, JSON.stringify(newData), {
      expirationTtl: config.windowSeconds * 2,
    }).catch(err => {
      console.error('[RateLimit] Failed to update counter:', err);
    });
    
    return {
      allowed: true,
      remaining: Math.max(0, config.maxRequests - weightedCount - 1),
      resetAt,
    };
  }
}

// ============================================
// HELPER FUNCTIONS
// ============================================

/**
 * Get client identifier for rate limiting
 * Priority: User ID > IP Address
 * 
 * SECURITY: Only trust CF-Connecting-IP which is set by Cloudflare.
 * X-Forwarded-For can be spoofed by clients and should not be used for rate limiting.
 */
export function getClientIdentifier(c: Context<{ Bindings: Env; Variables: Variables }>): string {
  // If authenticated, use user ID (most reliable)
  const userId = c.get('userId');
  if (userId) {
    return `user:${userId}`;
  }
  
  // Use CF-Connecting-IP (Cloudflare sets this, cannot be spoofed by client)
  const cfIp = c.req.header('CF-Connecting-IP');
  if (cfIp) {
    return `ip:${cfIp}`;
  }
  
  // In development or non-Cloudflare environments, fall back carefully
  // SECURITY: Do NOT trust X-Forwarded-For in production as it can be spoofed
  if (c.env.ENVIRONMENT === 'development') {
    const xff = c.req.header('X-Forwarded-For')?.split(',')[0]?.trim();
    if (xff) {
      return `ip:${xff}`;
    }
  }
  
  // If we reach here in production, something is wrong (Cloudflare should always set CF-Connecting-IP)
  // Use a fixed identifier to ensure some rate limiting still applies
  console.warn('[RateLimit] No IP address found - using fallback identifier');
  return 'ip:unknown';
}

/**
 * Determine the rate limit type based on the request path and method
 */
export function getRateLimitType(method: string, path: string): string | null {
  // Auth endpoints
  if (path === '/auth/login') return 'auth:login';
  if (path === '/auth/register') return 'auth:register';
  if (path === '/auth/refresh') return 'auth:refresh';
  if (path === '/auth/apple') return 'auth:apple';
  if (path === '/auth/google') return 'auth:google';
  if (path === '/auth/logout') return 'auth:logout';
  if (path === '/auth/account' && method === 'DELETE') return 'auth:delete';
  
  // Plank endpoints - specific limits
  if (path === '/planks' && method === 'POST') return 'plank:create';
  if (path === '/planks/sync' && method === 'GET') return 'plank:sync';
  
  // Streak endpoints
  if (path === '/streaks/freeze' && method === 'POST') return 'streak:freeze';
  
  // Follow endpoints - specific limits
  if (path.match(/^\/users\/[^/]+\/follow$/) && method === 'POST') return 'follow:create';
  if (path.match(/^\/users\/[^/]+\/follow$/) && method === 'DELETE') return 'follow:delete';
  
  // Group endpoints - specific limits
  if (path === '/groups' && method === 'POST') return 'group:create';
  if (path.match(/^\/groups\/[^/]+\/join$/) && method === 'POST') return 'group:join';
  if (path.match(/^\/groups\/join\/[^/]+$/) && method === 'POST') return 'group:join';
  
  // Media endpoints - specific limits
  if (path === '/media/avatar' && method === 'POST') return 'media:upload';
  if (path.match(/^\/media\/group\/[^/]+$/) && method === 'POST') return 'media:upload';
  
  // Leaderboard endpoints - specific limits
  if (path.startsWith('/leaderboards') && method === 'GET') return 'leaderboard:read';
  
  // Device endpoints - specific limits
  if (path === '/devices' && method === 'POST') return 'device:register';
  
  // Badge endpoints
  if (path.startsWith('/badges')) {
    return method === 'GET' ? 'badges:read' : 'api:write';
  }
  
  // Notification endpoints
  if (path.startsWith('/notifications')) {
    if (method === 'GET') return 'notifications:read';
    return 'notifications:write';
  }
  
  // Search endpoint
  if (path.includes('/search')) return 'api:search';
  
  // General API endpoints
  if (method === 'GET') return 'api:read';
  if (['POST', 'PUT', 'PATCH', 'DELETE'].includes(method)) return 'api:write';
  
  return null;
}

/**
 * Add rate limit headers to response
 */
export function addRateLimitHeaders(
  c: Context,
  result: RateLimitResult,
  config: RateLimitConfig
): void {
  c.header('X-RateLimit-Limit', String(config.maxRequests));
  c.header('X-RateLimit-Remaining', String(result.remaining));
  c.header('X-RateLimit-Reset', String(result.resetAt));
  
  if (result.retryAfter !== undefined) {
    c.header('Retry-After', String(result.retryAfter));
  }
}

// ============================================
// MIDDLEWARE
// ============================================

/**
 * Rate limiting middleware
 * 
 * Applies sliding window rate limiting based on endpoint type.
 * Skips rate limiting for health check endpoints.
 */
export async function rateLimitMiddleware(
  c: Context<{ Bindings: Env; Variables: Variables }>,
  next: Next
) {
  const path = new URL(c.req.url).pathname;
  const method = c.req.method;
  
  // Skip rate limiting for health checks
  if (path === '/' || path === '/health') {
    return next();
  }
  
  // Determine rate limit type
  const limitType = getRateLimitType(method, path);
  if (!limitType) {
    return next();
  }
  
  const config = RATE_LIMITS[limitType];
  if (!config) {
    return next();
  }
  
  // Get client identifier
  const identifier = getClientIdentifier(c);
  
  // Check rate limit
  const limiter = new SlidingWindowRateLimiter(c.env.RATE_LIMIT);
  const result = await limiter.checkLimit(config, identifier);
  
  // Add rate limit headers to all responses
  addRateLimitHeaders(c, result, config);
  
  if (!result.allowed) {
    return c.json({
      success: false,
      error: {
        code: 'RATE_LIMITED',
        message: `Too many requests. Please try again in ${result.retryAfter} seconds.`,
        retryAfter: result.retryAfter,
      },
      meta: {
        timestamp: new Date().toISOString(),
        requestId: c.get('requestId') || crypto.randomUUID(),
      },
    }, 429);
  }
  
  return next();
}

/**
 * Create a rate limit middleware for a specific endpoint type
 * Use this for fine-grained control over specific routes
 */
export function createRateLimiter(limitType: string) {
  return async (c: Context<{ Bindings: Env; Variables: Variables }>, next: Next) => {
    const config = RATE_LIMITS[limitType];
    if (!config) {
      return next();
    }
    
    const identifier = getClientIdentifier(c);
    const limiter = new SlidingWindowRateLimiter(c.env.RATE_LIMIT);
    const result = await limiter.checkLimit(config, identifier);
    
    addRateLimitHeaders(c, result, config);
    
    if (!result.allowed) {
      return c.json({
        success: false,
        error: {
          code: 'RATE_LIMITED',
          message: `Too many requests. Please try again in ${result.retryAfter} seconds.`,
          retryAfter: result.retryAfter,
        },
        meta: {
          timestamp: new Date().toISOString(),
          requestId: c.get('requestId') || crypto.randomUUID(),
        },
      }, 429);
    }
    
    return next();
  };
}
