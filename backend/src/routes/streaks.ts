import { Hono } from 'hono';
import type { Env, Variables } from '../types/env';
import { success, errors } from '../utils/response';
import { authMiddleware } from '../middleware/auth';
import {
  recalculateUserStreak,
  useFreezeTokenAndProtectStreak,
  getTodayInTimezone,
  getYesterdayInTimezone,
} from '../utils/streak';

const streaks = new Hono<{ Bindings: Env; Variables: Variables }>();

// Apply auth middleware to all routes
streaks.use('*', authMiddleware);

// ============================================
// HELPER FUNCTIONS
// ============================================

interface UserStreakData {
  current_streak: number;
  longest_streak: number;
  freeze_tokens: number;
  last_plank_date: string | null;
  last_freeze_date: string | null;
  timezone: string;
}

/**
 * Determine if the streak is at risk (no plank today, had one yesterday)
 */
function isStreakAtRisk(lastPlankDate: string | null, timezone: string): boolean {
  if (!lastPlankDate) return false;
  
  const today = getTodayInTimezone(timezone);
  const yesterday = getYesterdayInTimezone(timezone);
  
  // Streak is at risk if last plank was yesterday (need to plank today to maintain)
  return lastPlankDate === yesterday;
}

/**
 * Determine if the streak is active (planked today or yesterday)
 */
function isStreakActive(lastPlankDate: string | null, timezone: string): boolean {
  if (!lastPlankDate) return false;
  
  const today = getTodayInTimezone(timezone);
  const yesterday = getYesterdayInTimezone(timezone);
  
  return lastPlankDate === today || lastPlankDate === yesterday;
}

/**
 * Check if user has planked today
 */
function hasPlankkedToday(lastPlankDate: string | null, timezone: string): boolean {
  if (!lastPlankDate) return false;
  const today = getTodayInTimezone(timezone);
  return lastPlankDate === today;
}

// ============================================
// ROUTES
// ============================================

/**
 * GET /streaks/me - Get current streak information
 * 
 * Returns detailed streak information including:
 * - Current streak count
 * - Longest streak ever
 * - Available freeze tokens
 * - Whether streak is at risk
 * - Whether user has planked today
 */
streaks.get('/me', async (c) => {
  const userId = c.get('userId');
  const db = c.env.DB;

  if (!userId) {
    return errors.unauthorized(c);
  }

  // Get user streak data
  const user = await db
    .prepare(`
      SELECT current_streak, longest_streak, freeze_tokens, last_plank_date, last_freeze_date, timezone
      FROM users WHERE id = ?
    `)
    .bind(userId)
    .first<UserStreakData>();

  if (!user) {
    return errors.notFound(c, 'User');
  }

  const timezone = user.timezone || 'UTC';
  const today = getTodayInTimezone(timezone);

  // Check if today's streak protection came from a freeze (not a real plank)
  const usedFreezeToday = user.last_freeze_date === today;

  // Get today's planks count (actual planks, not freeze)
  const todayPlanks = await db
    .prepare(`
      SELECT COUNT(*) as count, COALESCE(SUM(duration_seconds), 0) as total_seconds
      FROM plank_sessions
      WHERE user_id = ? AND deleted_at IS NULL
        AND date(performed_at) = ?
    `)
    .bind(userId, today)
    .first<{ count: number; total_seconds: number }>();

  // Determine if user has actually planked today (not just used freeze)
  const actuallyPlankkedToday = (todayPlanks?.count || 0) > 0;

  // Get streak history (last 30 days of plank activity)
  const thirtyDaysAgo = new Date();
  thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
  
  const recentActivity = await db
    .prepare(`
      SELECT date(performed_at) as date, COUNT(*) as planks, SUM(duration_seconds) as seconds
      FROM plank_sessions
      WHERE user_id = ? AND deleted_at IS NULL
        AND performed_at >= ?
      GROUP BY date(performed_at)
      ORDER BY date DESC
    `)
    .bind(userId, thirtyDaysAgo.toISOString())
    .all<{ date: string; planks: number; seconds: number }>();

  return success(c, {
    currentStreak: user.current_streak,
    longestStreak: user.longest_streak,
    freezeTokens: user.freeze_tokens,
    lastPlankDate: user.last_plank_date,
    lastFreezeDate: user.last_freeze_date,
    
    // Status flags
    hasPlankkedToday: actuallyPlankkedToday, // True only if actually planked (not freeze)
    usedFreezeToday, // True if freeze was used today
    streakProtectedToday: actuallyPlankkedToday || usedFreezeToday, // True if streak is safe
    isStreakAtRisk: !actuallyPlankkedToday && !usedFreezeToday && isStreakAtRisk(user.last_plank_date, timezone),
    isStreakActive: isStreakActive(user.last_plank_date, timezone),
    
    // Today's activity
    today: {
      date: today,
      planks: todayPlanks?.count || 0,
      totalSeconds: todayPlanks?.total_seconds || 0,
      usedFreeze: usedFreezeToday,
    },
    
    // Recent activity for calendar view
    recentActivity: recentActivity.results.map((day) => ({
      date: day.date,
      planks: day.planks,
      totalSeconds: day.seconds,
    })),
  });
});

/**
 * POST /streaks/freeze - Use a freeze token to protect streak
 * 
 * Freeze tokens allow users to skip a day without breaking their streak.
 * Users start with 2 tokens and can earn more through achievements.
 * 
 * Rules:
 * - Must have an active streak to use freeze
 * - Must have at least 1 freeze token
 * - Can only use freeze if you haven't planked today
 * - Streak must be at risk (last plank was yesterday)
 * 
 * RACE CONDITION FIX: Uses atomic update to prevent double-spending of tokens.
 * The freeze token decrement happens in a single UPDATE with WHERE conditions.
 */
streaks.post('/freeze', async (c) => {
  const userId = c.get('userId');
  const db = c.env.DB;

  if (!userId) {
    return errors.unauthorized(c);
  }

  // Get user data for validation
  const user = await db
    .prepare(`
      SELECT current_streak, longest_streak, freeze_tokens, last_plank_date, last_freeze_date, timezone
      FROM users WHERE id = ?
    `)
    .bind(userId)
    .first<UserStreakData>();

  if (!user) {
    return errors.notFound(c, 'User');
  }

  const timezone = user.timezone || 'UTC';
  const today = getTodayInTimezone(timezone);

  // Check if user has already used a freeze today
  if (user.last_freeze_date === today) {
    return errors.conflict(c, 'Cannot use freeze - already used a freeze today');
  }

  // Check if user has planked today (can't use freeze if already planked)
  if (hasPlankkedToday(user.last_plank_date, timezone)) {
    return errors.conflict(c, 'Cannot use freeze - you already planked today');
  }

  // Check if streak is at risk (only can use freeze if streak needs protection)
  if (!isStreakAtRisk(user.last_plank_date, timezone)) {
    return errors.conflict(c, 'Cannot use freeze - your streak is not at risk');
  }

  // Check if user has freeze tokens (early check for better UX)
  if (user.freeze_tokens <= 0) {
    return errors.conflict(c, 'No freeze tokens available');
  }

  // Use the freeze token AND update streak dates ATOMICALLY in a single operation
  // This prevents partial failures where token is spent but streak isn't protected
  const result = await useFreezeTokenAndProtectStreak(db, userId, today);

  if (!result.success) {
    // Return the specific error from the atomic operation
    return errors.conflict(c, result.error || 'Failed to use freeze token');
  }

  return success(c, {
    message: 'Freeze token used successfully',
    freezeTokensRemaining: result.remainingTokens,
    streakProtected: true,
    currentStreak: user.current_streak,
    freezeUsedToday: true,
  });
});

/**
 * GET /streaks/history - Get streak history and milestones
 * 
 * Returns historical streak data including:
 * - All-time stats
 * - Streak milestones achieved
 * - Monthly breakdown
 */
streaks.get('/history', async (c) => {
  const userId = c.get('userId');
  const db = c.env.DB;

  if (!userId) {
    return errors.unauthorized(c);
  }

  // Get user data
  const user = await db
    .prepare(`
      SELECT current_streak, longest_streak, created_at
      FROM users WHERE id = ?
    `)
    .bind(userId)
    .first<{ current_streak: number; longest_streak: number; created_at: string }>();

  if (!user) {
    return errors.notFound(c, 'User');
  }

  // Get monthly plank counts
  const monthlyStats = await db
    .prepare(`
      SELECT 
        strftime('%Y-%m', performed_at) as month,
        COUNT(*) as planks,
        SUM(duration_seconds) as total_seconds,
        COUNT(DISTINCT date(performed_at)) as active_days
      FROM plank_sessions
      WHERE user_id = ? AND deleted_at IS NULL
      GROUP BY strftime('%Y-%m', performed_at)
      ORDER BY month DESC
      LIMIT 12
    `)
    .bind(userId)
    .all<{
      month: string;
      planks: number;
      total_seconds: number;
      active_days: number;
    }>();

  // Calculate total days since joining
  const daysSinceJoining = Math.floor(
    (Date.now() - new Date(user.created_at).getTime()) / (1000 * 60 * 60 * 24)
  );

  // Get total active days
  const activeDays = await db
    .prepare(`
      SELECT COUNT(DISTINCT date(performed_at)) as days
      FROM plank_sessions
      WHERE user_id = ? AND deleted_at IS NULL
    `)
    .bind(userId)
    .first<{ days: number }>();

  // Define streak milestones
  const milestones = [
    { days: 7, name: 'Week Warrior', achieved: user.longest_streak >= 7 },
    { days: 14, name: 'Fortnight Fighter', achieved: user.longest_streak >= 14 },
    { days: 30, name: 'Monthly Master', achieved: user.longest_streak >= 30 },
    { days: 60, name: 'Two Month Titan', achieved: user.longest_streak >= 60 },
    { days: 90, name: 'Quarter Champion', achieved: user.longest_streak >= 90 },
    { days: 180, name: 'Half Year Hero', achieved: user.longest_streak >= 180 },
    { days: 365, name: 'Year-Long Legend', achieved: user.longest_streak >= 365 },
  ];

  return success(c, {
    currentStreak: user.current_streak,
    longestStreak: user.longest_streak,
    
    allTime: {
      daysSinceJoining,
      activeDays: activeDays?.days || 0,
      consistencyRate: daysSinceJoining > 0 
        ? Math.round(((activeDays?.days || 0) / daysSinceJoining) * 100) 
        : 0,
    },
    
    milestones: milestones.map((m) => ({
      ...m,
      progress: Math.min(100, Math.round((user.longest_streak / m.days) * 100)),
    })),
    
    monthlyHistory: monthlyStats.results.map((m) => ({
      month: m.month,
      planks: m.planks,
      totalSeconds: m.total_seconds,
      activeDays: m.active_days,
    })),
  });
});

export default streaks;
