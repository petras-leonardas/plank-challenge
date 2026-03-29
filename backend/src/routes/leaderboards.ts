import { Hono } from 'hono';
import { zValidator } from '@hono/zod-validator';
import { z } from 'zod';
import type { Env, Variables } from '../types/env';
import type { UserRecord } from '../types/api';
import { success, errors } from '../utils/response';
import { authMiddleware, optionalAuthMiddleware } from '../middleware/auth';

const leaderboards = new Hono<{ Bindings: Env; Variables: Variables }>();

// ============================================
// CONSTANTS
// ============================================

/** 
 * Cache TTL for leaderboards (in seconds)
 * 
 * NOTE: Leaderboards are eventually consistent. When a user completes a plank,
 * the leaderboard may take up to this many seconds to reflect the change.
 * This is acceptable for leaderboards where exact real-time accuracy is not critical.
 */
const LEADERBOARD_CACHE_TTL = 60; // 1 minute

/** Maximum entries to return in a leaderboard */
const LEADERBOARD_MAX_LIMIT = 100;
const LEADERBOARD_DEFAULT_LIMIT = 50;

/** Leaderboard types */
type LeaderboardType = 'streak' | 'duration' | 'total_planks' | 'total_time';

/** Time periods for filtering — matches the groups leaderboard and iOS LeaderboardPeriod enum */
type LeaderboardPeriod = 'all' | 'month' | 'week';

// ============================================
// VALIDATION SCHEMAS
// ============================================

/** Maximum offset to prevent performance issues with extreme pagination */
const LEADERBOARD_MAX_OFFSET = 10000;

const leaderboardQuerySchema = z.object({
  limit: z.coerce.number().int().min(1).max(LEADERBOARD_MAX_LIMIT).optional().default(LEADERBOARD_DEFAULT_LIMIT),
  offset: z.coerce.number().int().min(0).max(LEADERBOARD_MAX_OFFSET).optional().default(0),
  period: z.enum(['all', 'month', 'week']).optional().default('all'),
});

const friendsLeaderboardQuerySchema = z.object({
  limit: z.coerce.number().int().min(1).max(LEADERBOARD_MAX_LIMIT).optional().default(LEADERBOARD_DEFAULT_LIMIT),
  offset: z.coerce.number().int().min(0).max(LEADERBOARD_MAX_OFFSET).optional().default(0),
  period: z.enum(['all', 'month', 'week']).optional().default('all'),
  type: z.enum(['streak', 'duration', 'total-planks', 'total-time']).optional().default('streak'),
});

// ============================================
// HELPER FUNCTIONS
// ============================================

/**
 * Format a user for leaderboard display
 */
function formatLeaderboardEntry(
  user: UserRecord,
  rank: number,
  score: number,
  scoreLabel: string,
  options?: { isCurrentUser?: boolean }
) {
  return {
    rank,
    user: {
      id: user.id,
      displayName: user.display_name,
      username: user.username,
      profileImageUrl: user.profile_image_url,
    },
    score,
    scoreLabel,
    isCurrentUser: options?.isCurrentUser || false,
  };
}

/**
 * Format duration in seconds to human-readable string
 */
function formatDuration(seconds: number): string {
  if (seconds < 60) {
    return `${Math.round(seconds)}s`;
  }
  const minutes = Math.floor(seconds / 60);
  const remainingSeconds = Math.round(seconds % 60);
  if (minutes < 60) {
    return remainingSeconds > 0 ? `${minutes}m ${remainingSeconds}s` : `${minutes}m`;
  }
  const hours = Math.floor(minutes / 60);
  const remainingMinutes = minutes % 60;
  return remainingMinutes > 0 ? `${hours}h ${remainingMinutes}m` : `${hours}h`;
}

/**
 * Generate cache key for leaderboard
 * 
 * NOTE: For period-based queries (weekly/monthly), we include a date bucket to ensure
 * the cache is invalidated as the period window shifts. We use hour granularity
 * to balance cache efficiency with freshness.
 */
function getCacheKey(type: LeaderboardType, period: LeaderboardPeriod, limit: number, offset: number): string {
  if (period === 'all') {
    return `leaderboard:${type}:${period}:${limit}:${offset}`;
  }
  // For period-based queries, include a date bucket (hourly) to ensure cache freshness
  const now = new Date();
  const dateBucket = `${now.getUTCFullYear()}-${String(now.getUTCMonth() + 1).padStart(2, '0')}-${String(now.getUTCDate()).padStart(2, '0')}-${String(now.getUTCHours()).padStart(2, '0')}`;
  return `leaderboard:${type}:${period}:${dateBucket}:${limit}:${offset}`;
}

/**
 * Get date boundary for period filtering
 */
function getPeriodStartDate(period: LeaderboardPeriod): string | null {
  if (period === 'all') {
    return null;
  }
  
  const now = new Date();
  if (period === 'week') {
    now.setDate(now.getDate() - 7);
  } else if (period === 'month') {
    now.setDate(now.getDate() - 30);
  }
  return now.toISOString();
}

/**
 * Try to get cached leaderboard data
 */
async function getCachedLeaderboard<T>(
  kv: KVNamespace,
  cacheKey: string
): Promise<T | null> {
  try {
    const cached = await kv.get(cacheKey, 'json');
    return cached as T | null;
  } catch {
    return null;
  }
}

/**
 * Cache leaderboard data
 */
async function cacheLeaderboard(
  kv: KVNamespace,
  cacheKey: string,
  data: unknown
): Promise<void> {
  try {
    await kv.put(cacheKey, JSON.stringify(data), { expirationTtl: LEADERBOARD_CACHE_TTL });
  } catch (error) {
    // Non-fatal: log but don't fail the request
    console.error('Failed to cache leaderboard:', error);
  }
}

// ============================================
// ROUTES
// ============================================

/**
 * GET /leaderboards/streak - Global streak leaderboard
 * 
 * Returns users ranked by their longest streak (or current streak).
 * Supports time-based filtering for weekly/monthly competitions.
 * 
 * For all_time: Uses longest_streak (historical best)
 * For weekly/monthly: Uses current_streak (active streaks only)
 */
leaderboards.get('/streak', optionalAuthMiddleware, zValidator('query', leaderboardQuerySchema), async (c) => {
  const currentUserId = c.get('userId');
  const { limit, offset, period } = c.req.valid('query');
  const db = c.env.DB;
  const cache = c.env.CACHE;
  
  const cacheKey = getCacheKey('streak', period, limit, offset);
  
  // Try cache first
  interface CachedStreakData {
    entries: ReturnType<typeof formatLeaderboardEntry>[];
    total: number;
    cachedAt: string;
  }
  
  const cached = await getCachedLeaderboard<CachedStreakData>(cache, cacheKey);
  
  let entries: ReturnType<typeof formatLeaderboardEntry>[];
  let total: number;
  
  if (cached) {
    entries = cached.entries;
    total = cached.total;
  } else {
    // Determine which streak field to use based on period
    // all_time: longest_streak (historical best)
    // weekly/monthly: current_streak (must be active)
    const streakField = period === 'all' ? 'longest_streak' : 'current_streak';
    const periodStart = getPeriodStartDate(period);
    
    // Build the query based on period
    let query: string;
    const params: (string | number)[] = [];
    
    if (period === 'all') {
      // All-time: Simple query on longest_streak
      query = `
        SELECT * FROM users
        WHERE deleted_at IS NULL AND ${streakField} > 0
        ORDER BY ${streakField} DESC, updated_at DESC
        LIMIT ? OFFSET ?
      `;
      params.push(limit, offset);
    } else {
      // Weekly/Monthly: Only include users who planked in the period AND have an active streak
      query = `
        SELECT DISTINCT u.* FROM users u
        WHERE u.deleted_at IS NULL 
          AND u.current_streak > 0
          AND u.last_plank_date >= ?
        ORDER BY u.current_streak DESC, u.last_plank_date DESC
        LIMIT ? OFFSET ?
      `;
      params.push(periodStart!, limit, offset);
    }
    
    const results = await db
      .prepare(query)
      .bind(...params)
      .all<UserRecord>();
    
    // Get total count for pagination
    let countQuery: string;
    const countParams: (string | number)[] = [];
    
    if (period === 'all') {
      countQuery = `SELECT COUNT(*) as count FROM users WHERE deleted_at IS NULL AND ${streakField} > 0`;
    } else {
      countQuery = `
        SELECT COUNT(DISTINCT u.id) as count FROM users u
        WHERE u.deleted_at IS NULL 
          AND u.current_streak > 0
          AND u.last_plank_date >= ?
      `;
      countParams.push(periodStart!);
    }
    
    const countResult = await db
      .prepare(countQuery)
      .bind(...countParams)
      .first<{ count: number }>();
    
    total = countResult?.count || 0;
    
    // Format entries with DENSE_RANK: users with the same score share the same rank
    let currentRank = offset + 1;
    entries = (results.results || []).map((user, index) => {
      const score = period === 'all' ? user.longest_streak : user.current_streak;
      if (index > 0) {
        const prevScore = period === 'all'
          ? results.results![index - 1].longest_streak
          : results.results![index - 1].current_streak;
        if (score !== prevScore) currentRank = offset + index + 1;
      }
      const rank = currentRank;
      const scoreLabel = `${score} day${score !== 1 ? 's' : ''}`;
      
      return formatLeaderboardEntry(user, rank, score, scoreLabel, {
        isCurrentUser: user.id === currentUserId,
      });
    });
    
    // Cache the results (without isCurrentUser to make cache shareable)
    const cacheEntries = entries.map(entry => ({
      ...entry,
      isCurrentUser: false, // Clear for cache
    }));
    
    await cacheLeaderboard(cache, cacheKey, {
      entries: cacheEntries,
      total,
      cachedAt: new Date().toISOString(),
    });
  }
  
  // Mark current user in cached results
  if (currentUserId && cached) {
    entries = entries.map(entry => ({
      ...entry,
      isCurrentUser: entry.user.id === currentUserId,
    }));
  }
  
  // Get current user's rank if authenticated and not in results
  let currentUserRank: { rank: number; score: number; scoreLabel: string } | null = null;
  
  if (currentUserId) {
    const isInResults = entries.some(e => e.isCurrentUser);
    
    if (!isInResults) {
      // Fetch current user's rank
      const streakField = period === 'all' ? 'longest_streak' : 'current_streak';
      const periodStart = getPeriodStartDate(period);
      
      const user = await db
        .prepare('SELECT id, current_streak, longest_streak, last_plank_date FROM users WHERE id = ?')
        .bind(currentUserId)
        .first<Pick<UserRecord, 'id' | 'current_streak' | 'longest_streak' | 'last_plank_date'>>();
      
      if (user) {
        const userScore = period === 'all' ? user.longest_streak : user.current_streak;
        
        // Only calculate rank if user has a qualifying score
        if (userScore > 0 && (period === 'all' || (user.last_plank_date && user.last_plank_date >= (periodStart || '')))) {
          let rankQuery: string;
          const rankParams: (string | number)[] = [];
          
          if (period === 'all') {
            rankQuery = `
              SELECT COUNT(DISTINCT ${streakField}) + 1 as rank FROM users
              WHERE deleted_at IS NULL AND ${streakField} > ?
            `;
            rankParams.push(userScore);
          } else {
            rankQuery = `
              SELECT COUNT(DISTINCT current_streak) + 1 as rank FROM users
              WHERE deleted_at IS NULL 
                AND current_streak > ?
                AND last_plank_date >= ?
            `;
            rankParams.push(userScore, periodStart!);
          }
          
          const rankResult = await db
            .prepare(rankQuery)
            .bind(...rankParams)
            .first<{ rank: number }>();
          
          currentUserRank = {
            rank: rankResult?.rank || 0,
            score: userScore,
            scoreLabel: `${userScore} day${userScore !== 1 ? 's' : ''}`,
          };
        }
      }
    }
  }
  
  return success(c, {
    type: 'streak',
    period,
    entries,
    currentUserRank,
    pagination: {
      total,
      limit,
      offset,
      hasMore: offset + entries.length < total,
    },
    meta: {
      cachedAt: cached?.cachedAt || null,
      cacheTtl: LEADERBOARD_CACHE_TTL,
    },
  });
});

/**
 * GET /leaderboards/duration - Global longest plank leaderboard
 * 
 * Returns users ranked by their longest single plank.
 */
leaderboards.get('/duration', optionalAuthMiddleware, zValidator('query', leaderboardQuerySchema), async (c) => {
  const currentUserId = c.get('userId');
  const { limit, offset, period } = c.req.valid('query');
  const db = c.env.DB;
  const cache = c.env.CACHE;
  
  const cacheKey = getCacheKey('duration', period, limit, offset);
  
  interface CachedDurationData {
    entries: ReturnType<typeof formatLeaderboardEntry>[];
    total: number;
    cachedAt: string;
  }
  
  const cached = await getCachedLeaderboard<CachedDurationData>(cache, cacheKey);
  
  let entries: ReturnType<typeof formatLeaderboardEntry>[];
  let total: number;
  
  if (cached) {
    entries = cached.entries;
    total = cached.total;
  } else {
    const periodStart = getPeriodStartDate(period);
    
    let query: string;
    const params: (string | number)[] = [];
    
    if (period === 'all') {
      // All-time: Use denormalized longest_plank_seconds from users table
      query = `
        SELECT * FROM users
        WHERE deleted_at IS NULL AND longest_plank_seconds > 0
        ORDER BY longest_plank_seconds DESC, updated_at DESC
        LIMIT ? OFFSET ?
      `;
      params.push(limit, offset);
    } else {
      // Weekly/Monthly: Calculate from plank_sessions within the period
      query = `
        SELECT u.*, MAX(p.duration_seconds) as period_longest
        FROM users u
        INNER JOIN plank_sessions p ON u.id = p.user_id
        WHERE u.deleted_at IS NULL 
          AND p.deleted_at IS NULL
          AND p.performed_at >= ?
        GROUP BY u.id
        ORDER BY period_longest DESC, MAX(p.performed_at) DESC
        LIMIT ? OFFSET ?
      `;
      params.push(periodStart!, limit, offset);
    }
    
    const results = await db
      .prepare(query)
      .bind(...params)
      .all<UserRecord & { period_longest?: number }>();
    
    // Get total count
    let countQuery: string;
    const countParams: (string | number)[] = [];
    
    if (period === 'all') {
      countQuery = `SELECT COUNT(*) as count FROM users WHERE deleted_at IS NULL AND longest_plank_seconds > 0`;
    } else {
      countQuery = `
        SELECT COUNT(DISTINCT u.id) as count
        FROM users u
        INNER JOIN plank_sessions p ON u.id = p.user_id
        WHERE u.deleted_at IS NULL 
          AND p.deleted_at IS NULL
          AND p.performed_at >= ?
      `;
      countParams.push(periodStart!);
    }
    
    const countResult = await db
      .prepare(countQuery)
      .bind(...countParams)
      .first<{ count: number }>();
    
    total = countResult?.count || 0;
    
    // Format entries with DENSE_RANK: users with the same score share the same rank
    let currentRank = offset + 1;
    entries = (results.results || []).map((user, index) => {
      const score = period === 'all'
        ? user.longest_plank_seconds
        : (user.period_longest || 0);
      if (index > 0) {
        const prevScore = period === 'all'
          ? results.results![index - 1].longest_plank_seconds
          : (results.results![index - 1].period_longest || 0);
        if (score !== prevScore) currentRank = offset + index + 1;
      }
      const rank = currentRank;
      const scoreLabel = formatDuration(score);
      
      return formatLeaderboardEntry(user, rank, score, scoreLabel, {
        isCurrentUser: user.id === currentUserId,
      });
    });
    
    // Cache results
    const cacheEntries = entries.map(entry => ({
      ...entry,
      isCurrentUser: false,
    }));
    
    await cacheLeaderboard(cache, cacheKey, {
      entries: cacheEntries,
      total,
      cachedAt: new Date().toISOString(),
    });
  }
  
  // Mark current user in cached results
  if (currentUserId && cached) {
    entries = entries.map(entry => ({
      ...entry,
      isCurrentUser: entry.user.id === currentUserId,
    }));
  }
  
  // Get current user's rank if not in results
  let currentUserRank: { rank: number; score: number; scoreLabel: string } | null = null;
  
  if (currentUserId) {
    const isInResults = entries.some(e => e.isCurrentUser);
    
    if (!isInResults) {
      const periodStart = getPeriodStartDate(period);
      
      if (period === 'all') {
        const user = await db
          .prepare('SELECT longest_plank_seconds FROM users WHERE id = ?')
          .bind(currentUserId)
          .first<{ longest_plank_seconds: number }>();
        
        if (user && user.longest_plank_seconds > 0) {
          const rankResult = await db
            .prepare(`
              SELECT COUNT(DISTINCT longest_plank_seconds) + 1 as rank FROM users
              WHERE deleted_at IS NULL AND longest_plank_seconds > ?
            `)
            .bind(user.longest_plank_seconds)
            .first<{ rank: number }>();
          
          currentUserRank = {
            rank: rankResult?.rank || 0,
            score: user.longest_plank_seconds,
            scoreLabel: formatDuration(user.longest_plank_seconds),
          };
        }
      } else {
        // Get user's best plank in the period
        const userBest = await db
          .prepare(`
            SELECT MAX(duration_seconds) as best
            FROM plank_sessions
            WHERE user_id = ? AND deleted_at IS NULL AND performed_at >= ?
          `)
          .bind(currentUserId, periodStart!)
          .first<{ best: number | null }>();
        
        if (userBest?.best) {
          const rankResult = await db
            .prepare(`
              SELECT COUNT(DISTINCT best) + 1 as rank
              FROM (
                SELECT u.id, MAX(p.duration_seconds) as best
                FROM users u
                INNER JOIN plank_sessions p ON u.id = p.user_id
                WHERE u.deleted_at IS NULL 
                  AND p.deleted_at IS NULL
                  AND p.performed_at >= ?
                GROUP BY u.id
                HAVING best > ?
              )
            `)
            .bind(periodStart!, userBest.best)
            .first<{ rank: number }>();
          
          currentUserRank = {
            rank: rankResult?.rank || 0,
            score: userBest.best,
            scoreLabel: formatDuration(userBest.best),
          };
        }
      }
    }
  }
  
  return success(c, {
    type: 'duration',
    period,
    entries,
    currentUserRank,
    pagination: {
      total,
      limit,
      offset,
      hasMore: offset + entries.length < total,
    },
    meta: {
      cachedAt: cached?.cachedAt || null,
      cacheTtl: LEADERBOARD_CACHE_TTL,
    },
  });
});

/**
 * GET /leaderboards/total-planks - Total plank count leaderboard
 * 
 * Returns users ranked by total number of planks completed.
 */
leaderboards.get('/total-planks', optionalAuthMiddleware, zValidator('query', leaderboardQuerySchema), async (c) => {
  const currentUserId = c.get('userId');
  const { limit, offset, period } = c.req.valid('query');
  const db = c.env.DB;
  const cache = c.env.CACHE;
  
  const cacheKey = getCacheKey('total_planks', period, limit, offset);
  
  interface CachedTotalPlanksData {
    entries: ReturnType<typeof formatLeaderboardEntry>[];
    total: number;
    cachedAt: string;
  }
  
  const cached = await getCachedLeaderboard<CachedTotalPlanksData>(cache, cacheKey);
  
  let entries: ReturnType<typeof formatLeaderboardEntry>[];
  let total: number;
  
  if (cached) {
    entries = cached.entries;
    total = cached.total;
  } else {
    const periodStart = getPeriodStartDate(period);
    
    let query: string;
    const params: (string | number)[] = [];
    
    if (period === 'all') {
      query = `
        SELECT * FROM users
        WHERE deleted_at IS NULL AND total_planks > 0
        ORDER BY total_planks DESC, updated_at DESC
        LIMIT ? OFFSET ?
      `;
      params.push(limit, offset);
    } else {
      query = `
        SELECT u.*, COUNT(p.id) as period_planks
        FROM users u
        INNER JOIN plank_sessions p ON u.id = p.user_id
        WHERE u.deleted_at IS NULL 
          AND p.deleted_at IS NULL
          AND p.performed_at >= ?
        GROUP BY u.id
        ORDER BY period_planks DESC, MAX(p.performed_at) DESC
        LIMIT ? OFFSET ?
      `;
      params.push(periodStart!, limit, offset);
    }
    
    const results = await db
      .prepare(query)
      .bind(...params)
      .all<UserRecord & { period_planks?: number }>();
    
    // Get total count
    let countQuery: string;
    const countParams: (string | number)[] = [];
    
    if (period === 'all') {
      countQuery = `SELECT COUNT(*) as count FROM users WHERE deleted_at IS NULL AND total_planks > 0`;
    } else {
      countQuery = `
        SELECT COUNT(DISTINCT u.id) as count
        FROM users u
        INNER JOIN plank_sessions p ON u.id = p.user_id
        WHERE u.deleted_at IS NULL 
          AND p.deleted_at IS NULL
          AND p.performed_at >= ?
      `;
      countParams.push(periodStart!);
    }
    
    const countResult = await db
      .prepare(countQuery)
      .bind(...countParams)
      .first<{ count: number }>();
    
    total = countResult?.count || 0;
    
    // Format entries with DENSE_RANK: users with the same score share the same rank
    let currentRank = offset + 1;
    entries = (results.results || []).map((user, index) => {
      const score = period === 'all'
        ? user.total_planks
        : (user.period_planks || 0);
      if (index > 0) {
        const prevScore = period === 'all'
          ? results.results![index - 1].total_planks
          : (results.results![index - 1].period_planks || 0);
        if (score !== prevScore) currentRank = offset + index + 1;
      }
      const rank = currentRank;
      const scoreLabel = `${score} plank${score !== 1 ? 's' : ''}`;
      
      return formatLeaderboardEntry(user, rank, score, scoreLabel, {
        isCurrentUser: user.id === currentUserId,
      });
    });
    
    const cacheEntries = entries.map(entry => ({
      ...entry,
      isCurrentUser: false,
    }));
    
    await cacheLeaderboard(cache, cacheKey, {
      entries: cacheEntries,
      total,
      cachedAt: new Date().toISOString(),
    });
  }
  
  if (currentUserId && cached) {
    entries = entries.map(entry => ({
      ...entry,
      isCurrentUser: entry.user.id === currentUserId,
    }));
  }
  
  // Get current user's rank if not in results
  let currentUserRank: { rank: number; score: number; scoreLabel: string } | null = null;
  
  if (currentUserId) {
    const isInResults = entries.some(e => e.isCurrentUser);
    
    if (!isInResults) {
      const periodStart = getPeriodStartDate(period);
      
      if (period === 'all') {
        const user = await db
          .prepare('SELECT total_planks FROM users WHERE id = ?')
          .bind(currentUserId)
          .first<{ total_planks: number }>();
        
        if (user && user.total_planks > 0) {
          const rankResult = await db
            .prepare(`
              SELECT COUNT(DISTINCT total_planks) + 1 as rank FROM users
              WHERE deleted_at IS NULL AND total_planks > ?
            `)
            .bind(user.total_planks)
            .first<{ rank: number }>();
          
          currentUserRank = {
            rank: rankResult?.rank || 0,
            score: user.total_planks,
            scoreLabel: `${user.total_planks} plank${user.total_planks !== 1 ? 's' : ''}`,
          };
        }
      } else {
        const userCount = await db
          .prepare(`
            SELECT COUNT(*) as count
            FROM plank_sessions
            WHERE user_id = ? AND deleted_at IS NULL AND performed_at >= ?
          `)
          .bind(currentUserId, periodStart!)
          .first<{ count: number }>();
        
        if (userCount && userCount.count > 0) {
          const rankResult = await db
            .prepare(`
              SELECT COUNT(DISTINCT count) + 1 as rank
              FROM (
                SELECT u.id, COUNT(p.id) as count
                FROM users u
                INNER JOIN plank_sessions p ON u.id = p.user_id
                WHERE u.deleted_at IS NULL 
                  AND p.deleted_at IS NULL
                  AND p.performed_at >= ?
                GROUP BY u.id
                HAVING count > ?
              )
            `)
            .bind(periodStart!, userCount.count)
            .first<{ rank: number }>();
          
          currentUserRank = {
            rank: rankResult?.rank || 0,
            score: userCount.count,
            scoreLabel: `${userCount.count} plank${userCount.count !== 1 ? 's' : ''}`,
          };
        }
      }
    }
  }
  
  return success(c, {
    type: 'total_planks',
    period,
    entries,
    currentUserRank,
    pagination: {
      total,
      limit,
      offset,
      hasMore: offset + entries.length < total,
    },
    meta: {
      cachedAt: cached?.cachedAt || null,
      cacheTtl: LEADERBOARD_CACHE_TTL,
    },
  });
});

/**
 * GET /leaderboards/total-time - Total plank time leaderboard
 * 
 * Returns users ranked by total time spent planking.
 */
leaderboards.get('/total-time', optionalAuthMiddleware, zValidator('query', leaderboardQuerySchema), async (c) => {
  const currentUserId = c.get('userId');
  const { limit, offset, period } = c.req.valid('query');
  const db = c.env.DB;
  const cache = c.env.CACHE;
  
  const cacheKey = getCacheKey('total_time', period, limit, offset);
  
  interface CachedTotalTimeData {
    entries: ReturnType<typeof formatLeaderboardEntry>[];
    total: number;
    cachedAt: string;
  }
  
  const cached = await getCachedLeaderboard<CachedTotalTimeData>(cache, cacheKey);
  
  let entries: ReturnType<typeof formatLeaderboardEntry>[];
  let total: number;
  
  if (cached) {
    entries = cached.entries;
    total = cached.total;
  } else {
    const periodStart = getPeriodStartDate(period);
    
    let query: string;
    const params: (string | number)[] = [];
    
    if (period === 'all') {
      query = `
        SELECT * FROM users
        WHERE deleted_at IS NULL AND total_plank_seconds > 0
        ORDER BY total_plank_seconds DESC, updated_at DESC
        LIMIT ? OFFSET ?
      `;
      params.push(limit, offset);
    } else {
      query = `
        SELECT u.*, SUM(p.duration_seconds) as period_seconds
        FROM users u
        INNER JOIN plank_sessions p ON u.id = p.user_id
        WHERE u.deleted_at IS NULL 
          AND p.deleted_at IS NULL
          AND p.performed_at >= ?
        GROUP BY u.id
        ORDER BY period_seconds DESC, MAX(p.performed_at) DESC
        LIMIT ? OFFSET ?
      `;
      params.push(periodStart!, limit, offset);
    }
    
    const results = await db
      .prepare(query)
      .bind(...params)
      .all<UserRecord & { period_seconds?: number }>();
    
    // Get total count
    let countQuery: string;
    const countParams: (string | number)[] = [];
    
    if (period === 'all') {
      countQuery = `SELECT COUNT(*) as count FROM users WHERE deleted_at IS NULL AND total_plank_seconds > 0`;
    } else {
      countQuery = `
        SELECT COUNT(DISTINCT u.id) as count
        FROM users u
        INNER JOIN plank_sessions p ON u.id = p.user_id
        WHERE u.deleted_at IS NULL 
          AND p.deleted_at IS NULL
          AND p.performed_at >= ?
      `;
      countParams.push(periodStart!);
    }
    
    const countResult = await db
      .prepare(countQuery)
      .bind(...countParams)
      .first<{ count: number }>();
    
    total = countResult?.count || 0;
    
    // Format entries with DENSE_RANK: users with the same score share the same rank
    let currentRank = offset + 1;
    entries = (results.results || []).map((user, index) => {
      const score = period === 'all'
        ? user.total_plank_seconds
        : (user.period_seconds || 0);
      if (index > 0) {
        const prevScore = period === 'all'
          ? results.results![index - 1].total_plank_seconds
          : (results.results![index - 1].period_seconds || 0);
        if (score !== prevScore) currentRank = offset + index + 1;
      }
      const rank = currentRank;
      const scoreLabel = formatDuration(score);
      
      return formatLeaderboardEntry(user, rank, score, scoreLabel, {
        isCurrentUser: user.id === currentUserId,
      });
    });
    
    const cacheEntries = entries.map(entry => ({
      ...entry,
      isCurrentUser: false,
    }));
    
    await cacheLeaderboard(cache, cacheKey, {
      entries: cacheEntries,
      total,
      cachedAt: new Date().toISOString(),
    });
  }
  
  if (currentUserId && cached) {
    entries = entries.map(entry => ({
      ...entry,
      isCurrentUser: entry.user.id === currentUserId,
    }));
  }
  
  // Get current user's rank if not in results
  let currentUserRank: { rank: number; score: number; scoreLabel: string } | null = null;
  
  if (currentUserId) {
    const isInResults = entries.some(e => e.isCurrentUser);
    
    if (!isInResults) {
      const periodStart = getPeriodStartDate(period);
      
      if (period === 'all') {
        const user = await db
          .prepare('SELECT total_plank_seconds FROM users WHERE id = ?')
          .bind(currentUserId)
          .first<{ total_plank_seconds: number }>();
        
        if (user && user.total_plank_seconds > 0) {
          const rankResult = await db
            .prepare(`
              SELECT COUNT(DISTINCT total_plank_seconds) + 1 as rank FROM users
              WHERE deleted_at IS NULL AND total_plank_seconds > ?
            `)
            .bind(user.total_plank_seconds)
            .first<{ rank: number }>();
          
          currentUserRank = {
            rank: rankResult?.rank || 0,
            score: user.total_plank_seconds,
            scoreLabel: formatDuration(user.total_plank_seconds),
          };
        }
      } else {
        const userTotal = await db
          .prepare(`
            SELECT SUM(duration_seconds) as total
            FROM plank_sessions
            WHERE user_id = ? AND deleted_at IS NULL AND performed_at >= ?
          `)
          .bind(currentUserId, periodStart!)
          .first<{ total: number | null }>();
        
        if (userTotal?.total) {
          const rankResult = await db
            .prepare(`
              SELECT COUNT(DISTINCT total) + 1 as rank
              FROM (
                SELECT u.id, SUM(p.duration_seconds) as total
                FROM users u
                INNER JOIN plank_sessions p ON u.id = p.user_id
                WHERE u.deleted_at IS NULL 
                  AND p.deleted_at IS NULL
                  AND p.performed_at >= ?
                GROUP BY u.id
                HAVING total > ?
              )
            `)
            .bind(periodStart!, userTotal.total)
            .first<{ rank: number }>();
          
          currentUserRank = {
            rank: rankResult?.rank || 0,
            score: userTotal.total,
            scoreLabel: formatDuration(userTotal.total),
          };
        }
      }
    }
  }
  
  return success(c, {
    type: 'total_time',
    period,
    entries,
    currentUserRank,
    pagination: {
      total,
      limit,
      offset,
      hasMore: offset + entries.length < total,
    },
    meta: {
      cachedAt: cached?.cachedAt || null,
      cacheTtl: LEADERBOARD_CACHE_TTL,
    },
  });
});

/**
 * GET /leaderboards/friends - Friends leaderboard (users you follow)
 * 
 * Shows rankings among users the current user follows.
 * Requires authentication.
 * 
 * Supports different leaderboard types via the `type` query param:
 * - streak (default): Longest/current streak
 * - duration: Longest single plank
 * - total_planks: Total plank count
 * - total_time: Total time spent planking
 */
leaderboards.get('/friends', authMiddleware, zValidator('query', friendsLeaderboardQuerySchema), async (c) => {
  const userId = c.get('userId')!;
  const { limit, offset, period, type } = c.req.valid('query');
  const db = c.env.DB;
  
  // Note: Friends leaderboard is not cached as it's personalized
  
  const periodStart = getPeriodStartDate(period);
  
  // Determine the field and score extraction based on type
  let orderField: string;
  let scoreExtractor: (user: UserRecord & { period_value?: number }) => number;
  let scoreFormatter: (score: number) => string;
  let minValueFilter: string;
  
  switch (type) {
    case 'duration':
      orderField = 'longest_plank_seconds';
      scoreExtractor = (user) => user.longest_plank_seconds;
      scoreFormatter = formatDuration;
      minValueFilter = 'longest_plank_seconds > 0';
      break;
    case 'total_planks':
      orderField = 'total_planks';
      scoreExtractor = (user) => user.total_planks;
      scoreFormatter = (score) => `${score} plank${score !== 1 ? 's' : ''}`;
      minValueFilter = 'total_planks > 0';
      break;
    case 'total_time':
      orderField = 'total_plank_seconds';
      scoreExtractor = (user) => user.total_plank_seconds;
      scoreFormatter = formatDuration;
      minValueFilter = 'total_plank_seconds > 0';
      break;
    case 'streak':
    default:
      orderField = period === 'all' ? 'longest_streak' : 'current_streak';
      scoreExtractor = (user) => period === 'all' ? user.longest_streak : user.current_streak;
      scoreFormatter = (score) => `${score} day${score !== 1 ? 's' : ''}`;
      minValueFilter = period === 'all' ? 'longest_streak > 0' : 'current_streak > 0';
      break;
  }
  
  // Build query - for period-based queries on non-streak types, we need to join with plank_sessions
  let query: string;
  let countQuery: string;
  const params: (string | number)[] = [];
  const countParams: (string | number)[] = [];
  
  // Following list — sorted by most recent plank date (who planked most recently appears first).
  // The current user is excluded (u.id != ?) — you already know your own stats.
  // Only people the current user follows are shown (strict following, not mutual).
  query = `
    SELECT u.* FROM users u
    WHERE u.deleted_at IS NULL
      AND u.id != ?
      AND u.id IN (SELECT following_id FROM follows WHERE follower_id = ?)
    ORDER BY u.last_plank_date DESC NULLS LAST, u.display_name ASC
    LIMIT ? OFFSET ?
  `;
  params.push(userId, userId, limit, offset);

  countQuery = `
    SELECT COUNT(*) as count FROM users u
    WHERE u.deleted_at IS NULL
      AND u.id != ?
      AND u.id IN (SELECT following_id FROM follows WHERE follower_id = ?)
  `;
  countParams.push(userId, userId);
  
  const results = await db
    .prepare(query)
    .bind(...params)
    .all<UserRecord & { period_value?: number }>();
  
  const countResult = await db
    .prepare(countQuery)
    .bind(...countParams)
    .first<{ count: number }>();
  
  const total = countResult?.count || 0;
  
  // Following list: show current streak as score, last plank date as label.
  // Sorted by recency so the displayed value (streak) is informational, not competitive.
  const now = new Date();
  const todayStr = now.toISOString().slice(0, 10); // YYYY-MM-DD
  const yesterday = new Date(now);
  yesterday.setDate(yesterday.getDate() - 1);
  const yesterdayStr = yesterday.toISOString().slice(0, 10);

  // Following list uses DENSE_RANK on streak so tied friends share the same position
  let currentRank = offset + 1;
  const entries = (results.results || []).map((user, index) => {
    const streak = user.current_streak || 0;
    const score = streak;
    if (index > 0) {
      const prevStreak = results.results![index - 1].current_streak || 0;
      if (streak !== prevStreak) currentRank = offset + index + 1;
    }
    const rank = currentRank;
    
    // Human-readable last-plank label
    let scoreLabel: string;
    if (!user.last_plank_date) {
      scoreLabel = 'No planks yet';
    } else if (user.last_plank_date >= todayStr) {
      scoreLabel = streak > 0 ? `${streak} day streak` : 'Planked today';
    } else if (user.last_plank_date >= yesterdayStr) {
      scoreLabel = streak > 0 ? `${streak} day streak` : 'Planked yesterday';
    } else {
      scoreLabel = streak > 0 ? `${streak} day streak` : `Last: ${user.last_plank_date}`;
    }
    
    return formatLeaderboardEntry(user, rank, score, scoreLabel, {
      isCurrentUser: false, // current user is excluded from this list
    });
  });
  
  return success(c, {
    type: 'following',
    metric: 'last_plank_date',
    period,
    entries,
    pagination: {
      total,
      limit,
      offset,
      hasMore: offset + entries.length < total,
    },
  });
});

export default leaderboards;
