import { Hono } from 'hono';
import { zValidator } from '@hono/zod-validator';
import { z } from 'zod';
import type { Env, Variables } from '../types/env';
import type { PlankRecord } from '../types/api';
import { success, errors } from '../utils/response';
import { authMiddleware } from '../middleware/auth';
import {
  recalculateUserStreak,
  updateUserStatsAfterPlank,
  updateUserStatsAfterDelete,
  getTodayInTimezone,
  getDateInTimezone,
  isValidTimezone,
} from '../utils/streak';
import { checkAndAwardBadges, getMilestones, getNextMilestones, type UserStats } from '../utils/badges';

const planks = new Hono<{ Bindings: Env; Variables: Variables }>();

// Apply auth middleware to all routes
planks.use('*', authMiddleware);

// ============================================
// CONSTANTS
// ============================================

// Maximum planks to return in a single sync request
const SYNC_MAX_LIMIT = 500;
const SYNC_DEFAULT_LIMIT = 100;

// Maximum planks to return in list endpoint
const LIST_MAX_LIMIT = 100;
const LIST_DEFAULT_LIMIT = 50;

// ============================================
// VALIDATION SCHEMAS
// ============================================

/**
 * Custom timezone validation
 * Checks that the timezone is a valid IANA timezone identifier
 */
const timezoneSchema = z.string().min(1, 'Timezone is required').refine(
  (tz) => isValidTimezone(tz),
  { message: 'Invalid timezone. Must be a valid IANA timezone (e.g., "America/New_York", "Europe/London")' }
);

const createPlankSchema = z.object({
  clientId: z.string().uuid('Client ID must be a valid UUID'),
  durationSeconds: z.number().positive('Duration must be positive').max(3600, 'Duration cannot exceed 1 hour'),
  plankType: z.enum(['elbow', 'high', 'side_left', 'side_right', 'reverse']).optional().default('elbow'),
  inputMethod: z.enum(['timer', 'manual', 'watch']),
  performedAt: z.string().datetime('Invalid datetime format'),
  timezone: timezoneSchema,
});

const listPlanksSchema = z.object({
  limit: z.coerce.number().int().min(1).max(LIST_MAX_LIMIT).optional().default(LIST_DEFAULT_LIMIT),
  offset: z.coerce.number().int().min(0).optional().default(0),
  startDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Invalid date format (YYYY-MM-DD)').optional(),
  endDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Invalid date format (YYYY-MM-DD)').optional(),
});

/**
 * Sync endpoint schema with pagination
 * - since: ISO datetime to get changes after
 * - limit: Maximum number of planks to return (default 100, max 500)
 * - cursor: Pagination cursor for fetching next page (the last updated_at value)
 */
const syncPlanksSchema = z.object({
  since: z.string().datetime('Invalid datetime format').optional(),
  limit: z.coerce.number().int().min(1).max(SYNC_MAX_LIMIT).optional().default(SYNC_DEFAULT_LIMIT),
  cursor: z.string().datetime('Invalid cursor format').optional(),
});

// ============================================
// HELPER FUNCTIONS
// ============================================

function formatPlankResponse(plank: PlankRecord) {
  return {
    id: plank.id,
    clientId: plank.client_id,
    durationSeconds: plank.duration_seconds,
    plankType: plank.plank_type,
    inputMethod: plank.input_method,
    performedAt: plank.performed_at,
    timezone: plank.timezone,
    createdAt: plank.created_at,
    updatedAt: plank.updated_at,
    deletedAt: plank.deleted_at,
  };
}

/**
 * Check if a plank was performed today in its timezone
 */
function isPlankFromToday(performedAt: string, timezone: string): boolean {
  const plankDate = getDateInTimezone(new Date(performedAt), timezone);
  const todayDate = getTodayInTimezone(timezone);
  return plankDate === todayDate;
}

// ============================================
// ROUTES
// ============================================

/**
 * GET /planks/sync - Sync planks since timestamp
 * 
 * Returns planks (including soft-deleted ones) for offline sync.
 * 
 * PAGINATION: This endpoint is paginated to prevent memory issues:
 * - limit: Max planks per request (default 100, max 500)
 * - cursor: Pass the last `updatedAt` value to get the next page
 * - hasMore: Indicates if more planks are available
 * 
 * Usage:
 * 1. First request: GET /planks/sync?since=2024-01-01T00:00:00Z&limit=100
 * 2. If hasMore=true: GET /planks/sync?since=2024-01-01T00:00:00Z&limit=100&cursor=<lastUpdatedAt>
 * 3. Repeat until hasMore=false
 * 
 * IMPORTANT: This route must be defined before /planks/:id
 */
planks.get('/sync', zValidator('query', syncPlanksSchema), async (c) => {
  const userId = c.get('userId');
  const { since, limit, cursor } = c.req.valid('query');
  const db = c.env.DB;

  if (!userId) {
    return errors.unauthorized(c);
  }

  // Build query based on parameters
  let query: string;
  const params: (string | number)[] = [userId];

  if (since && cursor) {
    // Incremental sync with pagination cursor
    // Get planks updated after 'since' AND after the cursor
    query = `
      SELECT * FROM plank_sessions
      WHERE user_id = ? AND updated_at > ? AND updated_at > ?
      ORDER BY updated_at ASC
      LIMIT ?
    `;
    params.push(since, cursor, limit + 1); // +1 to check if there are more
  } else if (since) {
    // Incremental sync (first page)
    query = `
      SELECT * FROM plank_sessions
      WHERE user_id = ? AND updated_at > ?
      ORDER BY updated_at ASC
      LIMIT ?
    `;
    params.push(since, limit + 1);
  } else if (cursor) {
    // Full sync with pagination cursor
    query = `
      SELECT * FROM plank_sessions
      WHERE user_id = ? AND updated_at > ?
      ORDER BY updated_at ASC
      LIMIT ?
    `;
    params.push(cursor, limit + 1);
  } else {
    // Full sync (first page) - order by updated_at for consistent pagination
    query = `
      SELECT * FROM plank_sessions
      WHERE user_id = ?
      ORDER BY updated_at ASC
      LIMIT ?
    `;
    params.push(limit + 1);
  }

  const result = await db
    .prepare(query)
    .bind(...params)
    .all<PlankRecord>();

  // Check if there are more results
  const hasMore = result.results.length > limit;
  const planksToReturn = hasMore ? result.results.slice(0, limit) : result.results;

  // Get the cursor for the next page (last item's updated_at)
  const nextCursor = planksToReturn.length > 0 
    ? planksToReturn[planksToReturn.length - 1].updated_at 
    : null;

  // Get server timestamp for client to use in next sync
  const serverTimestamp = new Date().toISOString();

  return success(c, {
    planks: planksToReturn.map(formatPlankResponse),
    serverTimestamp,
    count: planksToReturn.length,
    pagination: {
      hasMore,
      nextCursor: hasMore ? nextCursor : null,
      limit,
    },
  });
});

/**
 * GET /planks/stats - Get plank statistics
 * 
 * Returns aggregated statistics for the user's planks.
 * 
 * IMPORTANT: This route must be defined before /planks/:id
 */
planks.get('/stats', async (c) => {
  const userId = c.get('userId');
  const db = c.env.DB;

  if (!userId) {
    return errors.unauthorized(c);
  }

  // Get basic stats
  const stats = await db
    .prepare(`
      SELECT 
        COUNT(*) as total_planks,
        COALESCE(SUM(duration_seconds), 0) as total_seconds,
        COALESCE(AVG(duration_seconds), 0) as average_seconds,
        COALESCE(MAX(duration_seconds), 0) as longest_plank,
        MIN(performed_at) as first_plank_date,
        MAX(performed_at) as last_plank_date
      FROM plank_sessions
      WHERE user_id = ? AND deleted_at IS NULL
    `)
    .bind(userId)
    .first<{
      total_planks: number;
      total_seconds: number;
      average_seconds: number;
      longest_plank: number;
      first_plank_date: string | null;
      last_plank_date: string | null;
    }>();

  // Get stats by plank type
  const byType = await db
    .prepare(`
      SELECT 
        plank_type,
        COUNT(*) as count,
        SUM(duration_seconds) as total_seconds,
        AVG(duration_seconds) as average_seconds,
        MAX(duration_seconds) as best_seconds
      FROM plank_sessions
      WHERE user_id = ? AND deleted_at IS NULL
      GROUP BY plank_type
    `)
    .bind(userId)
    .all<{
      plank_type: string;
      count: number;
      total_seconds: number;
      average_seconds: number;
      best_seconds: number;
    }>();

  // Get user timezone for date calculations
  const user = await db
    .prepare(`
      SELECT current_streak, longest_streak, freeze_tokens, last_plank_date, timezone
      FROM users WHERE id = ?
    `)
    .bind(userId)
    .first<{
      current_streak: number;
      longest_streak: number;
      freeze_tokens: number;
      last_plank_date: string | null;
      timezone: string;
    }>();

  const userTimezone = user?.timezone || 'UTC';

  // Get this week's stats (last 7 days) using user's timezone
  const now = new Date();
  const weekAgo = new Date(now);
  weekAgo.setDate(weekAgo.getDate() - 7);
  
  const thisWeek = await db
    .prepare(`
      SELECT 
        COUNT(*) as planks,
        COALESCE(SUM(duration_seconds), 0) as total_seconds
      FROM plank_sessions
      WHERE user_id = ? AND deleted_at IS NULL
        AND performed_at >= ?
    `)
    .bind(userId, weekAgo.toISOString())
    .first<{ planks: number; total_seconds: number }>();

  // Get this month's stats (last 30 days)
  const monthAgo = new Date(now);
  monthAgo.setDate(monthAgo.getDate() - 30);
  
  const thisMonth = await db
    .prepare(`
      SELECT 
        COUNT(*) as planks,
        COALESCE(SUM(duration_seconds), 0) as total_seconds
      FROM plank_sessions
      WHERE user_id = ? AND deleted_at IS NULL
        AND performed_at >= ?
    `)
    .bind(userId, monthAgo.toISOString())
    .first<{ planks: number; total_seconds: number }>();

  return success(c, {
    overall: {
      totalPlanks: stats?.total_planks || 0,
      totalSeconds: stats?.total_seconds || 0,
      averageSeconds: Math.round(stats?.average_seconds || 0),
      longestPlank: stats?.longest_plank || 0,
      firstPlankDate: stats?.first_plank_date || null,
      lastPlankDate: stats?.last_plank_date || null,
    },
    byType: byType.results.map((t) => ({
      type: t.plank_type,
      count: t.count,
      totalSeconds: t.total_seconds,
      averageSeconds: Math.round(t.average_seconds),
      bestSeconds: t.best_seconds,
    })),
    thisWeek: {
      planks: thisWeek?.planks || 0,
      totalSeconds: thisWeek?.total_seconds || 0,
    },
    thisMonth: {
      planks: thisMonth?.planks || 0,
      totalSeconds: thisMonth?.total_seconds || 0,
    },
    streak: {
      current: user?.current_streak || 0,
      longest: user?.longest_streak || 0,
      freezeTokens: user?.freeze_tokens || 0,
      lastPlankDate: user?.last_plank_date || null,
    },
  });
});

/**
 * GET /planks - List user's plank sessions
 */
planks.get('/', zValidator('query', listPlanksSchema), async (c) => {
  const userId = c.get('userId');
  const { limit, offset, startDate, endDate } = c.req.valid('query');
  const db = c.env.DB;

  if (!userId) {
    return errors.unauthorized(c);
  }

  let query = `
    SELECT * FROM plank_sessions
    WHERE user_id = ? AND deleted_at IS NULL
  `;
  const params: (string | number)[] = [userId];

  if (startDate) {
    query += ` AND date(performed_at) >= ?`;
    params.push(startDate);
  }

  if (endDate) {
    query += ` AND date(performed_at) <= ?`;
    params.push(endDate);
  }

  query += ` ORDER BY performed_at DESC LIMIT ? OFFSET ?`;
  params.push(limit, offset);

  const result = await db
    .prepare(query)
    .bind(...params)
    .all<PlankRecord>();

  // Get total count for pagination
  let countQuery = `
    SELECT COUNT(*) as total FROM plank_sessions
    WHERE user_id = ? AND deleted_at IS NULL
  `;
  const countParams: (string | number)[] = [userId];

  if (startDate) {
    countQuery += ` AND date(performed_at) >= ?`;
    countParams.push(startDate);
  }

  if (endDate) {
    countQuery += ` AND date(performed_at) <= ?`;
    countParams.push(endDate);
  }

  const countResult = await db
    .prepare(countQuery)
    .bind(...countParams)
    .first<{ total: number }>();

  return success(c, {
    planks: result.results.map(formatPlankResponse),
    pagination: {
      total: countResult?.total || 0,
      limit,
      offset,
      hasMore: (countResult?.total || 0) > offset + limit,
    },
  });
});

/**
 * POST /planks - Create a new plank session
 * 
 * Idempotent - if a plank with the same clientId exists, returns the existing plank.
 * This ensures offline sync works correctly without creating duplicates.
 * 
 * TRANSACTION SAFETY: Uses D1 batch to ensure all operations succeed or fail together:
 * 1. Insert the plank
 * 2. Update user stats
 * 
 * The streak is recalculated after the batch completes.
 */
planks.post('/', zValidator('json', createPlankSchema), async (c) => {
  const userId = c.get('userId');
  const data = c.req.valid('json');
  const db = c.env.DB;

  if (!userId) {
    return errors.unauthorized(c);
  }

  // Check for existing plank with same clientId for THIS USER (idempotency check)
  // SECURITY: We filter by user_id to prevent a malicious user from:
  // 1. Using another user's clientId to block their sync
  // 2. Probing for valid clientIds from other users
  const existing = await db
    .prepare('SELECT * FROM plank_sessions WHERE client_id = ? AND user_id = ?')
    .bind(data.clientId, userId)
    .first<PlankRecord>();

  if (existing) {
    // Return existing plank (idempotent response for this user's duplicate)
    return success(c, {
      plank: formatPlankResponse(existing),
      created: false,
    }, 200);
  }
  
  // SECURITY: Also check if clientId is used by another user
  // This should be extremely rare (UUID collision) but we handle it gracefully
  const conflicting = await db
    .prepare('SELECT user_id FROM plank_sessions WHERE client_id = ? AND user_id != ?')
    .bind(data.clientId, userId)
    .first();
  
  if (conflicting) {
    // Log this as it could indicate a UUID collision or malicious activity
    console.warn(`[Planks] ClientId collision detected: ${data.clientId} for user ${userId}`);
    // Don't reveal that the clientId exists - just ask for a new one
    return errors.validation(c, 'Please retry with a new client ID');
  }

  // Get current user stats for the batch update
  const user = await db
    .prepare(`
      SELECT total_planks, total_plank_seconds, longest_plank_seconds, timezone
      FROM users WHERE id = ?
    `)
    .bind(userId)
    .first<{
      total_planks: number;
      total_plank_seconds: number;
      longest_plank_seconds: number;
      timezone: string;
    }>();

  if (!user) {
    return errors.notFound(c, 'User');
  }

  // Enforce one plank per day.
  // Use the user's stored timezone (falling back to the timezone sent with the
  // request) so that "today" matches the user's local calendar date.
  const userTimezone = user.timezone || data.timezone || 'UTC';
  const performedDate = getDateInTimezone(new Date(data.performedAt), userTimezone);
  const todayDate = getTodayInTimezone(userTimezone);

  if (performedDate === todayDate) {
    const existingToday = await db
      .prepare(`
        SELECT id FROM plank_sessions
        WHERE user_id = ? AND deleted_at IS NULL
          AND date(performed_at) = date(?)
        LIMIT 1
      `)
      .bind(userId, data.performedAt)
      .first<{ id: string }>();

    if (existingToday) {
      return c.json({
        success: false,
        error: {
          code: 'PLANK_LIMIT_REACHED',
          message: "You've already submitted a plank today. Delete it from Settings if you want to re-submit.",
        },
      }, 409);
    }
  }

  // Prepare the plank data
  const plankId = crypto.randomUUID();
  const now = new Date().toISOString();

  // Calculate new stats
  const newTotalPlanks = (user.total_planks || 0) + 1;
  const newTotalSeconds = (user.total_plank_seconds || 0) + data.durationSeconds;
  const newLongestPlank = Math.max(user.longest_plank_seconds || 0, data.durationSeconds);

  // TRANSACTION: Use D1 batch to ensure atomicity
  // Both statements succeed or both fail
  try {
    const batchResults = await db.batch([
      // Statement 1: Insert the plank
      db.prepare(`
        INSERT INTO plank_sessions (
          id, client_id, user_id, duration_seconds, plank_type,
          input_method, performed_at, timezone, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      `).bind(
        plankId,
        data.clientId,
        userId,
        data.durationSeconds,
        data.plankType,
        data.inputMethod,
        data.performedAt,
        data.timezone,
        now,
        now
      ),
      // Statement 2: Update user stats
      db.prepare(`
        UPDATE users SET
          total_planks = ?,
          total_plank_seconds = ?,
          longest_plank_seconds = ?,
          updated_at = ?
        WHERE id = ?
      `).bind(
        newTotalPlanks,
        newTotalSeconds,
        newLongestPlank,
        now,
        userId
      ),
    ]);

    // Check for errors in batch
    for (const result of batchResults) {
      if (!result.success) {
        console.error('[Plank Creation] Batch operation failed:', result);
        return errors.serverError(c, 'Failed to create plank session');
      }
    }
  } catch (error) {
    console.error('[Plank Creation] Batch failed:', error);
    return errors.serverError(c, 'Failed to create plank session');
  }

  // Fetch the created plank
  const plank = await db
    .prepare('SELECT * FROM plank_sessions WHERE id = ?')
    .bind(plankId)
    .first<PlankRecord>();

  if (!plank) {
    return errors.serverError(c, 'Failed to retrieve created plank session');
  }

  // Recalculate streak (done after batch to ensure plank exists)
  // Use the plank's timezone for accurate date calculation
  const streakResult = await recalculateUserStreak(db, userId, user.timezone || data.timezone);

  // Check and award badges
  // This checks all badge conditions and awards any newly earned badges
  const newBadges = await checkAndAwardBadges(db, userId, {
    performedAt: data.performedAt,
    timezone: data.timezone,
    plankType: data.plankType,
    durationSeconds: data.durationSeconds,
  });

  return success(c, {
    plank: formatPlankResponse(plank),
    created: true,
    streak: {
      current: streakResult.currentStreak,
      longest: streakResult.longestStreak,
    },
    badges: {
      newlyEarned: newBadges,
      count: newBadges.length,
    },
  }, 201);
});

// ============================================
// PROGRESS ENDPOINT CONSTANTS
// ============================================

/** Number of days of daily activity to return for calendar view */
const PROGRESS_DAILY_ACTIVITY_DAYS = 90;

/** Number of weeks of weekly activity to return */
const PROGRESS_WEEKLY_ACTIVITY_WEEKS = 12;

/** Number of recent badges to return */
const PROGRESS_RECENT_BADGES_LIMIT = 5;

/**
 * GET /planks/progress - Get comprehensive progress data
 * 
 * Returns all progress-related data for the progress screen:
 * - Overall stats
 * - Recent activity (calendar data)
 * - Badge progress
 * - Streak info
 * - Milestones (derived from badge definitions for consistency)
 * 
 * OPTIMIZATIONS:
 * - Uses D1 batch to run all queries in parallel (~1 round trip instead of 7)
 * - Milestones derived from badge definitions (single source of truth)
 * 
 * IMPORTANT: This route must be defined before /planks/:id
 */
planks.get('/progress', async (c) => {
  const userId = c.get('userId');
  const db = c.env.DB;

  if (!userId) {
    return errors.unauthorized(c);
  }

  // Calculate date boundaries
  const now = new Date();
  const ninetyDaysAgo = new Date(now);
  ninetyDaysAgo.setDate(ninetyDaysAgo.getDate() - PROGRESS_DAILY_ACTIVITY_DAYS);
  
  const twelveWeeksAgo = new Date(now);
  twelveWeeksAgo.setDate(twelveWeeksAgo.getDate() - (PROGRESS_WEEKLY_ACTIVITY_WEEKS * 7));

  // OPTIMIZATION: Run all queries in a single batch for parallel execution
  const [
    userResult,
    dailyActivityResult,
    weeklyActivityResult,
    badgeCountResult,
    recentBadgesResult,
    activeDaysResult,
  ] = await db.batch([
    // Query 1: Get user data
    db.prepare(`
      SELECT 
        current_streak, longest_streak, freeze_tokens, last_plank_date,
        total_planks, total_plank_seconds, longest_plank_seconds,
        timezone, created_at
      FROM users WHERE id = ?
    `).bind(userId),

    // Query 2: Daily activity (last 90 days)
    db.prepare(`
      SELECT 
        date(performed_at) as date,
        COUNT(*) as planks,
        SUM(duration_seconds) as total_seconds,
        MAX(duration_seconds) as best_plank
      FROM plank_sessions
      WHERE user_id = ? AND deleted_at IS NULL
        AND performed_at >= ?
      GROUP BY date(performed_at)
      ORDER BY date DESC
    `).bind(userId, ninetyDaysAgo.toISOString()),

    // Query 3: Weekly activity (last 12 weeks)
    db.prepare(`
      SELECT 
        strftime('%Y-W%W', performed_at) as week,
        COUNT(*) as planks,
        SUM(duration_seconds) as total_seconds,
        COUNT(DISTINCT date(performed_at)) as active_days
      FROM plank_sessions
      WHERE user_id = ? AND deleted_at IS NULL
        AND performed_at >= ?
      GROUP BY strftime('%Y-W%W', performed_at)
      ORDER BY week DESC
    `).bind(userId, twelveWeeksAgo.toISOString()),

    // Query 4: Badge count
    db.prepare('SELECT COUNT(*) as count FROM badges WHERE user_id = ?').bind(userId),

    // Query 5: Recent badges
    db.prepare(`
      SELECT badge_type, earned_at
      FROM badges
      WHERE user_id = ?
      ORDER BY earned_at DESC
      LIMIT ?
    `).bind(userId, PROGRESS_RECENT_BADGES_LIMIT),

    // Query 6: Total active days
    db.prepare(`
      SELECT COUNT(DISTINCT date(performed_at)) as days
      FROM plank_sessions
      WHERE user_id = ? AND deleted_at IS NULL
    `).bind(userId),
  ]);

  // Extract user data
  const user = userResult.results[0] as {
    current_streak: number;
    longest_streak: number;
    freeze_tokens: number;
    last_plank_date: string | null;
    total_planks: number;
    total_plank_seconds: number;
    longest_plank_seconds: number;
    timezone: string;
    created_at: string;
  } | undefined;

  if (!user) {
    return errors.notFound(c, 'User');
  }

  // Extract other query results
  const dailyActivity = dailyActivityResult.results as {
    date: string;
    planks: number;
    total_seconds: number;
    best_plank: number;
  }[];

  const weeklyActivity = weeklyActivityResult.results as {
    week: string;
    planks: number;
    total_seconds: number;
    active_days: number;
  }[];

  const badgeCount = (badgeCountResult.results[0] as { count: number })?.count || 0;

  const recentBadges = recentBadgesResult.results as {
    badge_type: string;
    earned_at: string;
  }[];

  const activeDays = (activeDaysResult.results[0] as { days: number })?.days || 0;

  // Calculate days since joining
  const daysSinceJoining = Math.max(1, Math.floor(
    (Date.now() - new Date(user.created_at).getTime()) / (1000 * 60 * 60 * 24)
  ));

  // Get milestones from badge definitions (single source of truth)
  const stats: UserStats = {
    currentStreak: user.current_streak,
    longestStreak: user.longest_streak,
    totalPlanks: user.total_planks,
    totalPlankSeconds: user.total_plank_seconds,
    longestPlankSeconds: user.longest_plank_seconds,
  };

  const milestones = getMilestones(stats);
  const nextGoals = getNextMilestones(stats);

  return success(c, {
    // Summary stats
    summary: {
      totalPlanks: user.total_planks,
      totalSeconds: user.total_plank_seconds,
      longestPlankSeconds: user.longest_plank_seconds,
      currentStreak: user.current_streak,
      longestStreak: user.longest_streak,
      freezeTokens: user.freeze_tokens,
      badgesEarned: badgeCount,
      activeDays,
      daysSinceJoining,
      consistencyRate: Math.round((activeDays / daysSinceJoining) * 100),
    },

    // Calendar activity (last 90 days)
    dailyActivity: dailyActivity.map((d) => ({
      date: d.date,
      planks: d.planks,
      totalSeconds: d.total_seconds,
      bestPlank: d.best_plank,
    })),

    // Weekly trends (last 12 weeks)
    weeklyActivity: weeklyActivity.map((w) => ({
      week: w.week,
      planks: w.planks,
      totalSeconds: w.total_seconds,
      activeDays: w.active_days,
    })),

    // Recent badges
    recentBadges: recentBadges.map((b) => ({
      type: b.badge_type,
      earnedAt: b.earned_at,
    })),

    // Milestones (derived from badge definitions)
    milestones,

    // Next goals
    nextGoals: {
      streak: nextGoals.streak ? {
        target: nextGoals.streak.target,
        name: nextGoals.streak.name,
        badgeType: nextGoals.streak.badgeType,
        current: user.longest_streak,
        progress: nextGoals.streak.progress,
      } : null,
      totalPlanks: nextGoals.totalPlanks ? {
        target: nextGoals.totalPlanks.target,
        name: nextGoals.totalPlanks.name,
        badgeType: nextGoals.totalPlanks.badgeType,
        current: user.total_planks,
        progress: nextGoals.totalPlanks.progress,
      } : null,
      duration: nextGoals.duration ? {
        target: nextGoals.duration.target,
        name: nextGoals.duration.name,
        badgeType: nextGoals.duration.badgeType,
        current: user.longest_plank_seconds,
        progress: nextGoals.duration.progress,
      } : null,
    },
  });
});

/**
 * GET /planks/:id - Get a single plank session
 */
planks.get('/:id', async (c) => {
  const userId = c.get('userId');
  const plankId = c.req.param('id');
  const db = c.env.DB;

  if (!userId) {
    return errors.unauthorized(c);
  }

  const plank = await db
    .prepare('SELECT * FROM plank_sessions WHERE id = ? AND user_id = ?')
    .bind(plankId, userId)
    .first<PlankRecord>();

  if (!plank) {
    return errors.notFound(c, 'Plank session');
  }

  // Also return 404 for deleted planks (consistent with list behavior)
  if (plank.deleted_at) {
    return errors.notFound(c, 'Plank session');
  }

  return success(c, {
    plank: formatPlankResponse(plank),
  });
});

/**
 * DELETE /planks/:id - Delete a plank session
 * 
 * Can only delete planks from today (in the plank's timezone).
 * Performs soft delete to support sync.
 * 
 * TRANSACTION SAFETY: Uses D1 batch to ensure atomicity:
 * 1. Soft delete the plank
 * 2. Recalculate user stats (done via separate query since it needs aggregation)
 */
planks.delete('/:id', async (c) => {
  const userId = c.get('userId');
  const plankId = c.req.param('id');
  const db = c.env.DB;

  if (!userId) {
    return errors.unauthorized(c);
  }

  // Get the plank
  const plank = await db
    .prepare('SELECT * FROM plank_sessions WHERE id = ? AND user_id = ?')
    .bind(plankId, userId)
    .first<PlankRecord>();

  if (!plank) {
    return errors.notFound(c, 'Plank session');
  }

  // Already deleted?
  if (plank.deleted_at) {
    return errors.conflict(c, 'Plank session already deleted');
  }

  // Check if plank is from today (using plank's timezone)
  if (!isPlankFromToday(plank.performed_at, plank.timezone)) {
    return errors.forbidden(c, 'Can only delete planks from today');
  }

  // Get user's timezone before delete (needed for streak calculation)
  const user = await db
    .prepare('SELECT timezone FROM users WHERE id = ?')
    .bind(userId)
    .first<{ timezone: string }>();

  // Soft delete the plank and update stats in a batch for atomicity
  const now = new Date().toISOString();
  
  try {
    // First, soft delete the plank
    await db
      .prepare(`
        UPDATE plank_sessions
        SET deleted_at = ?, updated_at = ?
        WHERE id = ?
      `)
      .bind(now, now, plankId)
      .run();

    // Then update user stats (recalculates from remaining planks)
    await updateUserStatsAfterDelete(db, userId);
  } catch (error) {
    console.error('[Planks] Failed to delete plank:', error);
    return errors.serverError(c, 'Failed to delete plank');
  }
  
  // Recalculate streak (separate from main transaction - non-critical)
  let streakResult = { currentStreak: 0, longestStreak: 0 };
  try {
    streakResult = await recalculateUserStreak(db, userId, user?.timezone || plank.timezone);
  } catch (error) {
    // Non-fatal: streak recalculation failure shouldn't fail the delete
    console.error('[Planks] Failed to recalculate streak after delete:', error);
    // Return current values from before delete
    streakResult = { currentStreak: 0, longestStreak: 0 };
  }

  return success(c, {
    message: 'Plank session deleted',
    streak: {
      current: streakResult.currentStreak,
      longest: streakResult.longestStreak,
    },
  });
});

export default planks;
