/**
 * Badge System
 * 
 * Defines all available badges and the logic to check if they've been earned.
 * Badges are awarded based on:
 * - Streak milestones (7, 14, 30, 60, 90, 180, 365 days)
 * - Plank count milestones (1, 10, 50, 100, 500, 1000 planks)
 * - Duration milestones (1, 2, 3, 5, 10 minute planks)
 * - Special achievements (first plank, perfect week, etc.)
 */

import type { BadgeCategory } from '../types/api';

// Re-export BadgeCategory for backwards compatibility
export type { BadgeCategory };

// ============================================
// BADGE DEFINITIONS
// ============================================

export interface BadgeDefinition {
  type: string;
  name: string;
  description: string;
  category: BadgeCategory;
  icon: string; // Emoji or icon name for iOS
  requirement: BadgeRequirement;
  order: number; // Display order within category
}

export type BadgeRequirement =
  | { kind: 'streak'; days: number }
  | { kind: 'plank_count'; count: number }
  | { kind: 'single_plank_duration'; seconds: number }
  | { kind: 'total_duration'; seconds: number }
  | { kind: 'special'; check: string }; // Special badges checked by name

/**
 * All available badges in the system
 * 
 * Badge types follow a naming convention:
 * - streak_{days}: Streak milestones
 * - count_{number}: Plank count milestones
 * - duration_{minutes}m: Single plank duration
 * - total_{hours}h: Total plank time
 * - special_{name}: Special achievements
 */
export const BADGE_DEFINITIONS: BadgeDefinition[] = [
  // ============================================
  // STREAK BADGES
  // ============================================
  {
    type: 'streak_7',
    name: 'Week Warrior',
    description: 'Complete a 7-day streak',
    category: 'streak',
    icon: 'flame',
    requirement: { kind: 'streak', days: 7 },
    order: 1,
  },
  {
    type: 'streak_14',
    name: 'Fortnight Fighter',
    description: 'Complete a 14-day streak',
    category: 'streak',
    icon: 'flame.fill',
    requirement: { kind: 'streak', days: 14 },
    order: 2,
  },
  {
    type: 'streak_30',
    name: 'Monthly Master',
    description: 'Complete a 30-day streak',
    category: 'streak',
    icon: 'calendar',
    requirement: { kind: 'streak', days: 30 },
    order: 3,
  },
  {
    type: 'streak_60',
    name: 'Two Month Titan',
    description: 'Complete a 60-day streak',
    category: 'streak',
    icon: 'calendar.badge.plus',
    requirement: { kind: 'streak', days: 60 },
    order: 4,
  },
  {
    type: 'streak_90',
    name: 'Quarter Champion',
    description: 'Complete a 90-day streak',
    category: 'streak',
    icon: 'trophy',
    requirement: { kind: 'streak', days: 90 },
    order: 5,
  },
  {
    type: 'streak_180',
    name: 'Half Year Hero',
    description: 'Complete a 180-day streak',
    category: 'streak',
    icon: 'trophy.fill',
    requirement: { kind: 'streak', days: 180 },
    order: 6,
  },
  {
    type: 'streak_365',
    name: 'Year-Long Legend',
    description: 'Complete a 365-day streak',
    category: 'streak',
    icon: 'crown',
    requirement: { kind: 'streak', days: 365 },
    order: 7,
  },

  // ============================================
  // PLANK COUNT BADGES
  // ============================================
  {
    type: 'count_1',
    name: 'First Plank',
    description: 'Complete your first plank',
    category: 'count',
    icon: 'star',
    requirement: { kind: 'plank_count', count: 1 },
    order: 1,
  },
  {
    type: 'count_10',
    name: 'Getting Started',
    description: 'Complete 10 planks',
    category: 'count',
    icon: 'star.fill',
    requirement: { kind: 'plank_count', count: 10 },
    order: 2,
  },
  {
    type: 'count_50',
    name: 'Dedicated',
    description: 'Complete 50 planks',
    category: 'count',
    icon: 'bolt',
    requirement: { kind: 'plank_count', count: 50 },
    order: 3,
  },
  {
    type: 'count_100',
    name: 'Century Club',
    description: 'Complete 100 planks',
    category: 'count',
    icon: 'bolt.fill',
    requirement: { kind: 'plank_count', count: 100 },
    order: 4,
  },
  {
    type: 'count_500',
    name: 'Plank Master',
    description: 'Complete 500 planks',
    category: 'count',
    icon: 'medal',
    requirement: { kind: 'plank_count', count: 500 },
    order: 5,
  },
  {
    type: 'count_1000',
    name: 'Plank Legend',
    description: 'Complete 1000 planks',
    category: 'count',
    icon: 'medal.fill',
    requirement: { kind: 'plank_count', count: 1000 },
    order: 6,
  },

  // ============================================
  // SINGLE PLANK DURATION BADGES
  // ============================================
  {
    type: 'duration_1m',
    name: 'One Minute Wonder',
    description: 'Hold a plank for 1 minute',
    category: 'duration',
    icon: 'timer',
    requirement: { kind: 'single_plank_duration', seconds: 60 },
    order: 1,
  },
  {
    type: 'duration_2m',
    name: 'Two Minute Triumph',
    description: 'Hold a plank for 2 minutes',
    category: 'duration',
    icon: 'timer',
    requirement: { kind: 'single_plank_duration', seconds: 120 },
    order: 2,
  },
  {
    type: 'duration_3m',
    name: 'Three Minute Champion',
    description: 'Hold a plank for 3 minutes',
    category: 'duration',
    icon: 'stopwatch',
    requirement: { kind: 'single_plank_duration', seconds: 180 },
    order: 3,
  },
  {
    type: 'duration_5m',
    name: 'Five Minute Fighter',
    description: 'Hold a plank for 5 minutes',
    category: 'duration',
    icon: 'stopwatch.fill',
    requirement: { kind: 'single_plank_duration', seconds: 300 },
    order: 4,
  },
  {
    type: 'duration_10m',
    name: 'Iron Core',
    description: 'Hold a plank for 10 minutes',
    category: 'duration',
    icon: 'figure.core.training',
    requirement: { kind: 'single_plank_duration', seconds: 600 },
    order: 5,
  },

  // ============================================
  // TOTAL DURATION BADGES
  // ============================================
  {
    type: 'total_1h',
    name: 'Hour of Power',
    description: 'Plank for a total of 1 hour',
    category: 'duration',
    icon: 'clock',
    requirement: { kind: 'total_duration', seconds: 3600 },
    order: 10,
  },
  {
    type: 'total_5h',
    name: 'Five Hour Force',
    description: 'Plank for a total of 5 hours',
    category: 'duration',
    icon: 'clock.fill',
    requirement: { kind: 'total_duration', seconds: 18000 },
    order: 11,
  },
  {
    type: 'total_24h',
    name: 'Full Day Dedication',
    description: 'Plank for a total of 24 hours',
    category: 'duration',
    icon: 'sun.max',
    requirement: { kind: 'total_duration', seconds: 86400 },
    order: 12,
  },

  // ============================================
  // SPECIAL BADGES
  // ============================================
  {
    type: 'special_early_bird',
    name: 'Early Bird',
    description: 'Complete a plank before 6 AM',
    category: 'special',
    icon: 'sunrise',
    requirement: { kind: 'special', check: 'early_bird' },
    order: 1,
  },
  {
    type: 'special_night_owl',
    name: 'Night Owl',
    description: 'Complete a plank after 11 PM',
    category: 'special',
    icon: 'moon.stars',
    requirement: { kind: 'special', check: 'night_owl' },
    order: 2,
  },
  {
    type: 'special_perfect_week',
    name: 'Perfect Week',
    description: 'Plank every day for 7 consecutive days',
    category: 'special',
    icon: 'checkmark.seal',
    requirement: { kind: 'special', check: 'perfect_week' },
    order: 3,
  },
  {
    type: 'special_variety',
    name: 'Variety Pack',
    description: 'Try all plank types',
    category: 'special',
    icon: 'square.grid.3x3',
    requirement: { kind: 'special', check: 'variety' },
    order: 4,
  },
];

// Create a lookup map for efficient access
export const BADGE_MAP = new Map<string, BadgeDefinition>(
  BADGE_DEFINITIONS.map((b) => [b.type, b])
);

// ============================================
// BADGE CHECKING UTILITIES
// ============================================

export interface UserStats {
  currentStreak: number;
  longestStreak: number;
  totalPlanks: number;
  totalPlankSeconds: number;
  longestPlankSeconds: number;
}

export interface PlankInfo {
  performedAt: string;
  timezone: string;
  plankType: string;
  durationSeconds: number;
}

/**
 * Get all badges that a user has newly earned based on their stats
 * 
 * @param stats - Current user statistics
 * @param existingBadges - Set of badge types the user already has
 * @param recentPlank - Optional: the plank that triggered this check (for special badges)
 * @param allPlankTypes - Optional: set of all plank types the user has done (for variety badge)
 * @param specialContext - Optional: additional context for special badge checking (historical data)
 * @returns Array of badge types that were newly earned
 */
export function checkNewBadges(
  stats: UserStats,
  existingBadges: Set<string>,
  recentPlank?: PlankInfo,
  allPlankTypes?: Set<string>,
  specialContext?: SpecialBadgeContext
): string[] {
  const newBadges: string[] = [];

  for (const badge of BADGE_DEFINITIONS) {
    // Skip if already earned
    if (existingBadges.has(badge.type)) {
      continue;
    }

    // Check if badge requirement is met
    if (checkBadgeRequirement(badge.requirement, stats, recentPlank, allPlankTypes, specialContext)) {
      newBadges.push(badge.type);
    }
  }

  return newBadges;
}

/**
 * Check if a specific badge requirement is met
 */
function checkBadgeRequirement(
  requirement: BadgeRequirement,
  stats: UserStats,
  recentPlank?: PlankInfo,
  allPlankTypes?: Set<string>,
  specialContext?: SpecialBadgeContext
): boolean {
  switch (requirement.kind) {
    case 'streak':
      // Use longest streak (not current) so badges aren't lost if streak breaks
      return stats.longestStreak >= requirement.days;

    case 'plank_count':
      return stats.totalPlanks >= requirement.count;

    case 'single_plank_duration':
      return stats.longestPlankSeconds >= requirement.seconds;

    case 'total_duration':
      return stats.totalPlankSeconds >= requirement.seconds;

    case 'special':
      return checkSpecialBadge(requirement.check, recentPlank, allPlankTypes, specialContext);

    default:
      return false;
  }
}

/**
 * Extended context for special badge checking
 * Includes historical data for badges that can be awarded retroactively
 */
export interface SpecialBadgeContext {
  recentPlank?: PlankInfo;
  allPlankTypes?: Set<string>;
  hasEarlyBirdPlank?: boolean;  // Any plank before 6 AM in history
  hasNightOwlPlank?: boolean;   // Any plank after 11 PM in history
  currentStreak?: number;       // For perfect_week check
}

/**
 * Check special badge conditions
 * 
 * Special badges can be checked against:
 * 1. The recent plank (for real-time awarding)
 * 2. Historical data (for retroactive awarding)
 */
function checkSpecialBadge(
  check: string,
  recentPlank?: PlankInfo,
  allPlankTypes?: Set<string>,
  context?: SpecialBadgeContext
): boolean {
  switch (check) {
    case 'early_bird':
      // Check recent plank first
      if (recentPlank && isEarlyBird(recentPlank.performedAt, recentPlank.timezone)) {
        return true;
      }
      // Fall back to historical check
      return context?.hasEarlyBirdPlank === true;

    case 'night_owl':
      // Check recent plank first
      if (recentPlank && isNightOwl(recentPlank.performedAt, recentPlank.timezone)) {
        return true;
      }
      // Fall back to historical check
      return context?.hasNightOwlPlank === true;

    case 'perfect_week':
      // Perfect week is achieved when current streak reaches 7
      // This is separate from streak_7 badge which tracks longest streak
      return (context?.currentStreak || 0) >= 7;

    case 'variety':
      if (!allPlankTypes) return false;
      // All plank types: elbow, high, side_left, side_right, reverse
      return allPlankTypes.size >= 5;

    default:
      return false;
  }
}

/**
 * Check if a plank was done before 6 AM local time
 */
function isEarlyBird(performedAt: string, timezone: string): boolean {
  try {
    const date = new Date(performedAt);
    const formatter = new Intl.DateTimeFormat('en-US', {
      timeZone: timezone,
      hour: 'numeric',
      hour12: false,
    });
    const hour = parseInt(formatter.format(date), 10);
    return hour < 6;
  } catch {
    return false;
  }
}

/**
 * Check if a plank was done after 11 PM local time
 */
function isNightOwl(performedAt: string, timezone: string): boolean {
  try {
    const date = new Date(performedAt);
    const formatter = new Intl.DateTimeFormat('en-US', {
      timeZone: timezone,
      hour: 'numeric',
      hour12: false,
    });
    const hour = parseInt(formatter.format(date), 10);
    return hour >= 23;
  } catch {
    return false;
  }
}

// ============================================
// BADGE AWARDING
// ============================================

export interface EarnedBadge {
  id: string;
  userId: string;
  badgeType: string;
  earnedAt: string;
}

/**
 * Award badges to a user and create notifications
 * 
 * Returns prepared statements for use in a batch transaction
 */
export function prepareAwardBadges(
  db: D1Database,
  userId: string,
  badgeTypes: string[]
): { badgeStatements: D1PreparedStatement[]; notificationStatements: D1PreparedStatement[] } {
  const now = new Date().toISOString();
  const badgeStatements: D1PreparedStatement[] = [];
  const notificationStatements: D1PreparedStatement[] = [];

  for (const badgeType of badgeTypes) {
    const badge = BADGE_MAP.get(badgeType);
    if (!badge) continue;

    const badgeId = crypto.randomUUID();
    const notificationId = crypto.randomUUID();

    // Insert badge
    badgeStatements.push(
      db
        .prepare(`
          INSERT INTO badges (id, user_id, badge_type, earned_at)
          VALUES (?, ?, ?, ?)
        `)
        .bind(badgeId, userId, badgeType, now)
    );

    // Create notification
    notificationStatements.push(
      db
        .prepare(`
          INSERT INTO notifications (id, user_id, type, title, message, related_entity_type, related_entity_id, created_at)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        `)
        .bind(
          notificationId,
          userId,
          'badge_earned',
          `Badge Earned: ${badge.name}`,
          badge.description,
          'badge',
          badgeId,
          now
        )
    );
  }

  return { badgeStatements, notificationStatements };
}

/**
 * Check and award badges for a user after a plank
 * 
 * This is the main function to call after creating a plank.
 * It checks all badges, awards any newly earned ones, and creates notifications.
 * 
 * OPTIMIZATIONS:
 * - Uses D1 batch to run all read queries in parallel
 * - Proper error handling to prevent silent failures
 * - Returns empty array on any error (badge failure shouldn't block plank creation)
 * 
 * SPECIAL BADGES:
 * - early_bird and night_owl are checked against historical planks
 * - perfect_week is checked against current streak
 */
export async function checkAndAwardBadges(
  db: D1Database,
  userId: string,
  recentPlank?: PlankInfo
): Promise<string[]> {
  try {
    // OPTIMIZATION: Run all read queries in a single batch for parallel execution
    const [
      userResult,
      badgesResult,
      plankTypesResult,
      earlyBirdResult,
      nightOwlResult,
    ] = await db.batch([
      // Query 1: Get user stats
      db.prepare(`
        SELECT 
          current_streak,
          longest_streak,
          total_planks,
          total_plank_seconds,
          longest_plank_seconds
        FROM users WHERE id = ?
      `).bind(userId),
      
      // Query 2: Get existing badges
      db.prepare('SELECT badge_type FROM badges WHERE user_id = ?').bind(userId),
      
      // Query 3: Get all plank types user has done (for variety badge)
      db.prepare(`
        SELECT DISTINCT plank_type FROM plank_sessions 
        WHERE user_id = ? AND deleted_at IS NULL
      `).bind(userId),

      // Query 4: Check for any early bird plank (before 6 AM local time)
      // We check if any plank was performed in hours 0-5 in its timezone
      // Using a simplified check: look for planks with time component suggesting early morning
      db.prepare(`
        SELECT 1 as found FROM plank_sessions 
        WHERE user_id = ? AND deleted_at IS NULL
          AND CAST(strftime('%H', performed_at) AS INTEGER) < 6
        LIMIT 1
      `).bind(userId),

      // Query 5: Check for any night owl plank (after 11 PM local time)
      db.prepare(`
        SELECT 1 as found FROM plank_sessions 
        WHERE user_id = ? AND deleted_at IS NULL
          AND CAST(strftime('%H', performed_at) AS INTEGER) >= 23
        LIMIT 1
      `).bind(userId),
    ]);

    // Extract user data
    const user = userResult.results[0] as {
      current_streak: number;
      longest_streak: number;
      total_planks: number;
      total_plank_seconds: number;
      longest_plank_seconds: number;
    } | undefined;

    if (!user) {
      console.warn('[Badge Check] User not found:', userId);
      return [];
    }

    // Extract existing badges
    const existingBadges = new Set(
      (badgesResult.results as { badge_type: string }[]).map((b) => b.badge_type)
    );

    // Extract plank types
    const allPlankTypes = new Set(
      (plankTypesResult.results as { plank_type: string }[]).map((p) => p.plank_type)
    );

    // Check for historical special badge eligibility
    const hasEarlyBirdPlank = earlyBirdResult.results.length > 0;
    const hasNightOwlPlank = nightOwlResult.results.length > 0;

    // Build special badge context
    const specialContext: SpecialBadgeContext = {
      recentPlank,
      allPlankTypes,
      hasEarlyBirdPlank,
      hasNightOwlPlank,
      currentStreak: user.current_streak,
    };

    // Check for new badges
    const stats: UserStats = {
      currentStreak: user.current_streak,
      longestStreak: user.longest_streak,
      totalPlanks: user.total_planks,
      totalPlankSeconds: user.total_plank_seconds,
      longestPlankSeconds: user.longest_plank_seconds,
    };

    const newBadgeTypes = checkNewBadges(stats, existingBadges, recentPlank, allPlankTypes, specialContext);

    if (newBadgeTypes.length === 0) {
      return [];
    }

    // Award badges and create notifications
    const { badgeStatements, notificationStatements } = prepareAwardBadges(
      db,
      userId,
      newBadgeTypes
    );

    // Execute all inserts in a batch with error handling
    const allStatements = [...badgeStatements, ...notificationStatements];
    if (allStatements.length > 0) {
      try {
        const results = await db.batch(allStatements);
        
        // Check if any statement failed
        const failedStatements = results.filter((r) => !r.success);
        if (failedStatements.length > 0) {
          console.error('[Badge Award] Some badge inserts failed:', failedStatements);
          // We still return the badges we attempted to award
          // The ones that failed might be duplicates (race condition)
        }
      } catch (batchError) {
        console.error('[Badge Award] Batch insert failed:', batchError);
        // Don't throw - badge failure shouldn't break plank creation
        // Return empty since we couldn't confirm badges were awarded
        return [];
      }
    }

    return newBadgeTypes;
  } catch (error) {
    // Log error but don't throw - badge check failure shouldn't break plank creation
    console.error('[Badge Check] Error checking/awarding badges:', error);
    return [];
  }
}

/**
 * Get badge progress for a user
 * 
 * Returns all badges with their progress percentage
 */
export function getBadgeProgress(
  stats: UserStats,
  existingBadges: Set<string>
): Array<{
  badge: BadgeDefinition;
  earned: boolean;
  progress: number;
}> {
  return BADGE_DEFINITIONS.map((badge) => {
    const earned = existingBadges.has(badge.type);
    let progress = earned ? 100 : 0;

    if (!earned) {
      progress = calculateProgress(badge.requirement, stats);
    }

    return { badge, earned, progress };
  });
}

/**
 * Calculate progress percentage for a badge requirement
 */
function calculateProgress(requirement: BadgeRequirement, stats: UserStats): number {
  switch (requirement.kind) {
    case 'streak':
      return Math.min(100, Math.round((stats.longestStreak / requirement.days) * 100));

    case 'plank_count':
      return Math.min(100, Math.round((stats.totalPlanks / requirement.count) * 100));

    case 'single_plank_duration':
      return Math.min(100, Math.round((stats.longestPlankSeconds / requirement.seconds) * 100));

    case 'total_duration':
      return Math.min(100, Math.round((stats.totalPlankSeconds / requirement.seconds) * 100));

    case 'special':
      // Special badges are binary - either earned or 0%
      return 0;

    default:
      return 0;
  }
}

// ============================================
// MILESTONE HELPERS (for progress screen)
// ============================================

export interface Milestone {
  target: number;
  name: string;
  badgeType: string;
  achieved: boolean;
  progress: number;
}

export interface MilestoneSet {
  streak: Milestone[];
  totalPlanks: Milestone[];
  duration: Milestone[];
}

/**
 * Get milestone data derived from badge definitions
 * 
 * This ensures milestones shown on the progress screen are always
 * in sync with the actual badge definitions.
 */
export function getMilestones(stats: UserStats): MilestoneSet {
  const streakBadges = BADGE_DEFINITIONS.filter(
    (b) => b.requirement.kind === 'streak'
  ).sort((a, b) => {
    const aReq = a.requirement as { kind: 'streak'; days: number };
    const bReq = b.requirement as { kind: 'streak'; days: number };
    return aReq.days - bReq.days;
  });

  const countBadges = BADGE_DEFINITIONS.filter(
    (b) => b.requirement.kind === 'plank_count'
  ).sort((a, b) => {
    const aReq = a.requirement as { kind: 'plank_count'; count: number };
    const bReq = b.requirement as { kind: 'plank_count'; count: number };
    return aReq.count - bReq.count;
  });

  const durationBadges = BADGE_DEFINITIONS.filter(
    (b) => b.requirement.kind === 'single_plank_duration'
  ).sort((a, b) => {
    const aReq = a.requirement as { kind: 'single_plank_duration'; seconds: number };
    const bReq = b.requirement as { kind: 'single_plank_duration'; seconds: number };
    return aReq.seconds - bReq.seconds;
  });

  return {
    streak: streakBadges.map((badge) => {
      const req = badge.requirement as { kind: 'streak'; days: number };
      const achieved = stats.longestStreak >= req.days;
      return {
        target: req.days,
        name: badge.name,
        badgeType: badge.type,
        achieved,
        progress: achieved ? 100 : Math.round((stats.longestStreak / req.days) * 100),
      };
    }),
    totalPlanks: countBadges.map((badge) => {
      const req = badge.requirement as { kind: 'plank_count'; count: number };
      const achieved = stats.totalPlanks >= req.count;
      return {
        target: req.count,
        name: badge.name,
        badgeType: badge.type,
        achieved,
        progress: achieved ? 100 : Math.round((stats.totalPlanks / req.count) * 100),
      };
    }),
    duration: durationBadges.map((badge) => {
      const req = badge.requirement as { kind: 'single_plank_duration'; seconds: number };
      const achieved = stats.longestPlankSeconds >= req.seconds;
      return {
        target: req.seconds,
        name: badge.name,
        badgeType: badge.type,
        achieved,
        progress: achieved ? 100 : Math.round((stats.longestPlankSeconds / req.seconds) * 100),
      };
    }),
  };
}

/**
 * Get the next unachieved milestone in each category
 */
export function getNextMilestones(stats: UserStats): {
  streak: Milestone | null;
  totalPlanks: Milestone | null;
  duration: Milestone | null;
} {
  const milestones = getMilestones(stats);

  return {
    streak: milestones.streak.find((m) => !m.achieved) || null,
    totalPlanks: milestones.totalPlanks.find((m) => !m.achieved) || null,
    duration: milestones.duration.find((m) => !m.achieved) || null,
  };
}
