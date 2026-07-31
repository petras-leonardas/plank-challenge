import { Hono } from 'hono';
import { cors } from 'hono/cors';
import type { Env, Variables } from './types/env';
import { loggerMiddleware } from './middleware/logger';
import { errorMiddleware } from './middleware/error';
import { rateLimitMiddleware } from './middleware/rate-limit';
import { success } from './utils/response';

// Import routes
import authRoutes from './routes/auth';
import userRoutes from './routes/users';
import plankRoutes from './routes/planks';
import streakRoutes from './routes/streaks';
import badgeRoutes from './routes/badges';
import notificationRoutes from './routes/notifications';
import mediaRoutes from './routes/media';
import groupRoutes from './routes/groups';
import leaderboardRoutes from './routes/leaderboards';
import deviceRoutes from './routes/devices';
import legalRoutes from './routes/legal';

// Create the main Hono app
const app = new Hono<{ Bindings: Env; Variables: Variables }>();

// ============================================
// GLOBAL MIDDLEWARE
// ============================================

/**
 * CORS Configuration
 * 
 * For iOS-only apps, CORS is not enforced by native URLSession.
 * We restrict CORS to prevent unauthorized web clients from accessing the API.
 * 
 * - Development: Allow all origins for testing with tools like Postman/curl
 * - Production: Reject browser requests (iOS apps don't send Origin header)
 */
app.use('*', async (c, next) => {
  const corsMiddleware = cors({
    origin: (origin) => {
      // Development: allow all origins for testing
      if (c.env.ENVIRONMENT === 'development') {
        return origin || '*';
      }
      
      // Production: iOS apps don't send Origin header
      // If there's an Origin header, it's likely a browser - reject it
      // Only allow if there's no origin (native app) or if it's from our domain
      if (!origin) {
        return '*'; // No origin = native app request
      }
      
      // Allow only specific web origins if needed (e.g., admin dashboard)
      const allowedOrigins = [
        'https://plankchallenge.app',
        'https://www.plankchallenge.app',
        'https://admin.plankchallenge.app',
      ];
      
      if (allowedOrigins.includes(origin)) {
        return origin;
      }
      
      // SECURITY: Log rejected CORS origins for monitoring
      // This helps detect potential attacks or misconfigured clients
      console.warn(`[CORS] Rejected browser origin: ${origin?.slice(0, 100)}`);
      
      // Reject other browser origins
      return '';
    },
    allowMethods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowHeaders: ['Content-Type', 'Authorization'],
    exposeHeaders: ['X-Request-Id', 'X-RateLimit-Limit', 'X-RateLimit-Remaining', 'X-RateLimit-Reset', 'Retry-After'],
    maxAge: 86400,
    credentials: false,
  });
  
  return corsMiddleware(c, next);
});

// Request logging (adds requestId to context)
app.use('*', loggerMiddleware);

// Global error handling
app.use('*', errorMiddleware);

// Rate limiting (checks limits before processing requests)
app.use('*', rateLimitMiddleware);

// ============================================
// ENVIRONMENT VALIDATION MIDDLEWARE
// ============================================

/**
 * Validate critical environment variables on first request
 * This ensures the app fails fast if misconfigured
 */
let envValidated = false;
app.use('*', async (c, next) => {
  if (!envValidated) {
    // CRITICAL: Validate JWT_SECRET has sufficient entropy
    const jwtSecret = c.env.JWT_SECRET;
    if (!jwtSecret || jwtSecret.length < 32) {
      console.error('[SECURITY] CRITICAL: JWT_SECRET must be at least 32 characters');
      return c.json({
        success: false,
        error: {
          code: 'SERVER_MISCONFIGURED',
          message: 'Server is not properly configured',
        },
      }, 500);
    }
    
    // Warn about missing OAuth configuration in production
    if (c.env.ENVIRONMENT !== 'development') {
      if (!c.env.APPLE_CLIENT_ID) {
        console.warn('[CONFIG] APPLE_CLIENT_ID not set - Apple Sign-In will be unavailable');
      }
      if (!c.env.GOOGLE_CLIENT_ID) {
        console.warn('[CONFIG] GOOGLE_CLIENT_ID not set - Google Sign-In will be unavailable');
      }
    }
    
    envValidated = true;
  }
  return next();
});

// ============================================
// HEALTH CHECK ENDPOINTS
// ============================================

/**
 * GET / - API info
 */
app.get('/', (c) => {
  return success(c, {
    name: 'Plank Challenge API',
    version: c.env.API_VERSION || 'v1',
    environment: c.env.ENVIRONMENT || 'development',
    status: 'healthy',
  });
});

/**
 * GET /health - Health check
 */
app.get('/health', (c) => {
  return success(c, { status: 'ok' });
});

// ============================================
// ROUTE MOUNTING
// ============================================

app.route('/auth', authRoutes);
app.route('/users', userRoutes);
app.route('/planks', plankRoutes);
app.route('/streaks', streakRoutes);
app.route('/badges', badgeRoutes);
app.route('/notifications', notificationRoutes);
app.route('/media', mediaRoutes);
app.route('/groups', groupRoutes);
app.route('/leaderboards', leaderboardRoutes);
app.route('/devices', deviceRoutes);
app.route('/legal', legalRoutes);

// ============================================
// 404 HANDLER
// ============================================

app.notFound((c) => {
  return c.json({
    success: false,
    error: {
      code: 'NOT_FOUND',
      message: 'Endpoint not found',
    },
    meta: {
      timestamp: new Date().toISOString(),
      requestId: c.get('requestId') || 'unknown',
    },
  }, 404);
});

// ============================================
// EXPORTS — fetch (HTTP) + scheduled (cron)
// ============================================

import { handleReminders } from './scheduled/reminders';

export default {
  fetch: app.fetch,

  /**
   * Cron handler — runs every 5 minutes.
   * Sends daily plank reminders to users who haven't planked yet.
   */
  async scheduled(
    _event: ScheduledEvent,
    env: Env,
    ctx: ExecutionContext,
  ) {
    ctx.waitUntil(handleReminders(env));
  },
};
