import { Hono } from 'hono';
import type { Env, Variables } from '../types/env';
import type { BadgeRecord, FormattedBadge, BadgeCategory } from '../types/api';
import { success, errors } from '../utils/response';
import { authMiddleware } from '../middleware/auth';
import {
  BADGE_DEFINITIONS,
  BADGE_MAP,
  getBadgeProgress,
  type UserStats,
} from '../utils/badges';

const badges = new Hono<{ Bindings: Env; Variables: Variables }>();

// Apply auth middleware to all routes
badges.use('*', authMiddleware);

// ============================================
// HELPER FUNCTIONS
// ============================================

function formatBadgeResponse(badge: BadgeRecord): FormattedBadge | null {
  const definition = BADGE_MAP.get(badge.badge_type);
  if (!definition) return null;

  return {
    id: badge.id,
    type: badge.badge_type,
    name: definition.name,
    description: definition.description,
    category: definition.category,
    icon: definition.icon,
    earnedAt: badge.earned_at,
  };
}

// ============================================
// ROUTES
// ============================================

/**
 * GET /badges - List user's earned badges
 * 
 * Returns all badges the authenticated user has earned,
 * sorted by earned date (most recent first).
 */
badges.get('/', async (c) => {
  const userId = c.get('userId');
  const db = c.env.DB;

  if (!userId) {
    return errors.unauthorized(c);
  }

  const result = await db
    .prepare(`
      SELECT id, user_id, badge_type, earned_at
      FROM badges
      WHERE user_id = ?
      ORDER BY earned_at DESC
    `)
    .bind(userId)
    .all<BadgeRecord>();

  const formattedBadges = result.results
    .map(formatBadgeResponse)
    .filter((b): b is FormattedBadge => b !== null);

  // Group by category
  const byCategory: Record<BadgeCategory, FormattedBadge[]> = {
    streak: [],
    count: [],
    duration: [],
    special: [],
  };

  for (const badge of formattedBadges) {
    byCategory[badge.category].push(badge);
  }

  return success(c, {
    badges: formattedBadges,
    byCategory,
    count: formattedBadges.length,
    totalAvailable: BADGE_DEFINITIONS.length,
  });
});

/**
 * GET /badges/available - List all available badges with progress
 * 
 * Returns all badges in the system, whether earned or not,
 * along with progress towards each unearned badge.
 */
badges.get('/available', async (c) => {
  const userId = c.get('userId');
  const db = c.env.DB;

  if (!userId) {
    return errors.unauthorized(c);
  }

  // Get user stats
  const user = await db
    .prepare(`
      SELECT 
        current_streak,
        longest_streak,
        total_planks,
        total_plank_seconds,
        longest_plank_seconds
      FROM users WHERE id = ?
    `)
    .bind(userId)
    .first<{
      current_streak: number;
      longest_streak: number;
      total_planks: number;
      total_plank_seconds: number;
      longest_plank_seconds: number;
    }>();

  if (!user) {
    return errors.notFound(c, 'User');
  }

  // Get existing badges
  const existingBadgesResult = await db
    .prepare('SELECT badge_type, earned_at FROM badges WHERE user_id = ?')
    .bind(userId)
    .all<{ badge_type: string; earned_at: string }>();

  const existingBadges = new Set(existingBadgesResult.results.map((b) => b.badge_type));
  const earnedAtMap = new Map(
    existingBadgesResult.results.map((b) => [b.badge_type, b.earned_at])
  );

  // Calculate progress for all badges
  const stats: UserStats = {
    currentStreak: user.current_streak,
    longestStreak: user.longest_streak,
    totalPlanks: user.total_planks,
    totalPlankSeconds: user.total_plank_seconds,
    longestPlankSeconds: user.longest_plank_seconds,
  };

  const badgeProgress = getBadgeProgress(stats, existingBadges);

  // Format response
  const formattedBadges = badgeProgress.map(({ badge, earned, progress }) => ({
    type: badge.type,
    name: badge.name,
    description: badge.description,
    category: badge.category,
    icon: badge.icon,
    earned,
    earnedAt: earned ? earnedAtMap.get(badge.type) : null,
    progress,
    order: badge.order,
  }));

  // Group by category and sort within each category
  const byCategory: Record<BadgeCategory, typeof formattedBadges> = {
    streak: [],
    count: [],
    duration: [],
    special: [],
  };

  for (const badge of formattedBadges) {
    byCategory[badge.category].push(badge);
  }

  // Sort each category by order
  for (const category of Object.keys(byCategory) as BadgeCategory[]) {
    byCategory[category].sort((a, b) => a.order - b.order);
  }

  // Calculate summary stats
  const earnedCount = formattedBadges.filter((b) => b.earned).length;
  const totalCount = formattedBadges.length;

  // Find next achievable badges (closest to 100% progress, not yet earned)
  const nextAchievable = formattedBadges
    .filter((b) => !b.earned && b.progress > 0)
    .sort((a, b) => b.progress - a.progress)
    .slice(0, 3);

  return success(c, {
    badges: formattedBadges,
    byCategory,
    summary: {
      earned: earnedCount,
      total: totalCount,
      percentage: Math.round((earnedCount / totalCount) * 100),
    },
    nextAchievable,
  });
});

/**
 * GET /badges/user/:userId - Get another user's earned badges
 * 
 * Returns all badges another user has earned.
 * Only returns earned badges (no progress info for privacy).
 * 
 * IMPORTANT: This route must be defined BEFORE /:type to prevent
 * "user" from being matched as a badge type.
 */
badges.get('/user/:userId', async (c) => {
  const requestingUserId = c.get('userId');
  const targetUserId = c.req.param('userId');
  const db = c.env.DB;

  if (!requestingUserId) {
    return errors.unauthorized(c);
  }

  // Check if target user exists
  const targetUser = await db
    .prepare('SELECT id, display_name FROM users WHERE id = ? AND deleted_at IS NULL')
    .bind(targetUserId)
    .first<{ id: string; display_name: string }>();

  if (!targetUser) {
    return errors.notFound(c, 'User');
  }

  // Get their badges
  const result = await db
    .prepare(`
      SELECT id, user_id, badge_type, earned_at
      FROM badges
      WHERE user_id = ?
      ORDER BY earned_at DESC
    `)
    .bind(targetUserId)
    .all<BadgeRecord>();

  const formattedBadges = result.results
    .map(formatBadgeResponse)
    .filter((b): b is FormattedBadge => b !== null);

  return success(c, {
    user: {
      id: targetUser.id,
      displayName: targetUser.display_name,
    },
    badges: formattedBadges,
    count: formattedBadges.length,
  });
});

/**
 * GET /badges/:type - Get details for a specific badge
 * 
 * Returns details for a specific badge type, including
 * whether the user has earned it and their progress.
 * 
 * IMPORTANT: This route must be defined AFTER /user/:userId
 * because /:type would otherwise match "user" as a badge type.
 */
badges.get('/:type', async (c) => {
  const userId = c.get('userId');
  const badgeType = c.req.param('type');
  const db = c.env.DB;

  if (!userId) {
    return errors.unauthorized(c);
  }

  // Get badge definition
  const definition = BADGE_MAP.get(badgeType);
  if (!definition) {
    return errors.notFound(c, 'Badge type');
  }

  // Check if user has earned this badge
  const earned = await db
    .prepare('SELECT id, earned_at FROM badges WHERE user_id = ? AND badge_type = ?')
    .bind(userId, badgeType)
    .first<{ id: string; earned_at: string }>();

  // Get user stats for progress calculation
  const user = await db
    .prepare(`
      SELECT 
        current_streak,
        longest_streak,
        total_planks,
        total_plank_seconds,
        longest_plank_seconds
      FROM users WHERE id = ?
    `)
    .bind(userId)
    .first<{
      current_streak: number;
      longest_streak: number;
      total_planks: number;
      total_plank_seconds: number;
      longest_plank_seconds: number;
    }>();

  if (!user) {
    return errors.notFound(c, 'User');
  }

  // Calculate progress
  const stats: UserStats = {
    currentStreak: user.current_streak,
    longestStreak: user.longest_streak,
    totalPlanks: user.total_planks,
    totalPlankSeconds: user.total_plank_seconds,
    longestPlankSeconds: user.longest_plank_seconds,
  };

  const existingBadges = earned ? new Set([badgeType]) : new Set<string>();
  const progress = getBadgeProgress(stats, existingBadges).find(
    (b) => b.badge.type === badgeType
  );

  // Get requirement details for display
  let requirementText = '';
  const req = definition.requirement;
  switch (req.kind) {
    case 'streak':
      requirementText = `Maintain a ${req.days}-day streak`;
      break;
    case 'plank_count':
      requirementText = `Complete ${req.count} planks`;
      break;
    case 'single_plank_duration':
      requirementText = `Hold a plank for ${req.seconds / 60} minutes`;
      break;
    case 'total_duration':
      requirementText = `Plank for ${req.seconds / 3600} hours total`;
      break;
    case 'special':
      requirementText = definition.description;
      break;
  }

  return success(c, {
    badge: {
      type: definition.type,
      name: definition.name,
      description: definition.description,
      category: definition.category,
      icon: definition.icon,
      requirement: requirementText,
      earned: !!earned,
      earnedAt: earned?.earned_at || null,
      earnedId: earned?.id || null,
      progress: progress?.progress || 0,
    },
  });
});

export default badges;
