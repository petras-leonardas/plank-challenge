import { Hono } from 'hono';
import { zValidator } from '@hono/zod-validator';
import { z } from 'zod';
import type { Env, Variables } from '../types/env';
import type { UserRecord } from '../types/api';
import { success, errors } from '../utils/response';
import { authMiddleware, optionalAuthMiddleware } from '../middleware/auth';
import { sendSilentPush } from '../utils/push';

const users = new Hono<{ Bindings: Env; Variables: Variables }>();

// ============================================
// VALIDATION SCHEMAS
// ============================================

const updateProfileSchema = z.object({
  displayName: z.string().min(1).max(50).optional(),
  username: z.string().min(3).max(30).regex(/^[a-zA-Z0-9_]+$/).optional(),
  location: z.string().max(100).optional().nullable(),
  bio: z.string().max(500).optional().nullable(),
  preferredPlankType: z.enum(['elbow', 'straightArm', 'parallettes']).optional(),
  timezone: z.string().optional(),
  plankGoalSeconds: z.number().int().positive().optional().nullable(),
  reminderEnabled: z.boolean().nullish(),
  reminderTime: z.string().regex(/^(?:[01]\d|2[0-3]):[0-5]\d$/).nullish(),
});

// ============================================
// HELPER FUNCTIONS
// ============================================

/**
 * Safely parse and validate pagination parameters
 * Returns validated limit and offset with sensible defaults and bounds
 */
function parsePagination(
  limitParam: string | undefined,
  offsetParam: string | undefined,
  maxLimit: number = 50,
  defaultLimit: number = 20
): { limit: number; offset: number } {
  // Parse limit with validation
  let limit = defaultLimit;
  if (limitParam !== undefined) {
    const parsed = parseInt(limitParam, 10);
    // Check for NaN, negative, or non-integer values
    if (!Number.isNaN(parsed) && parsed > 0 && Number.isInteger(parsed)) {
      limit = Math.min(parsed, maxLimit);
    }
  }
  
  // Parse offset with validation
  let offset = 0;
  if (offsetParam !== undefined) {
    const parsed = parseInt(offsetParam, 10);
    // Check for NaN, negative, or non-integer values
    // Also cap offset to prevent extremely large values
    if (!Number.isNaN(parsed) && parsed >= 0 && Number.isInteger(parsed)) {
      offset = Math.min(parsed, 100000); // Cap at 100k to prevent abuse
    }
  }
  
  return { limit, offset };
}

/**
 * Escape special characters in LIKE patterns to prevent unexpected matching.
 * Characters % and _ have special meaning in SQL LIKE clauses.
 */
function escapeLikePattern(input: string): string {
  return input.replace(/[%_\\]/g, '\\$&');
}

/**
 * Format a full user record for the current user (includes private fields)
 */
function formatUser(user: UserRecord) {
  return {
    id: user.id,
    email: user.email,
    emailVerified: Boolean(user.email_verified),
    displayName: user.display_name,
    username: user.username,
    location: user.location,
    bio: user.bio,
    profileImageUrl: user.profile_image_url,
    preferredPlankType: user.preferred_plank_type || 'elbow',
    plankGoalSeconds: user.plank_goal_seconds ?? null,
    currentStreak: user.current_streak || 0,
    longestStreak: user.longest_streak || 0,
    freezeTokens: user.freeze_tokens || 2,
    lastPlankDate: user.last_plank_date,
    totalPlanks: user.total_planks || 0,
    totalPlankSeconds: user.total_plank_seconds || 0,
    longestPlankSeconds: user.longest_plank_seconds || 0,
    followerCount: user.follower_count || 0,
    followingCount: user.following_count || 0,
    timezone: user.timezone || 'UTC',
    reminderEnabled: Boolean(user.reminder_enabled),
    reminderTime: user.reminder_time || '19:00',
    createdAt: user.created_at,
    updatedAt: user.updated_at,
  };
}

/**
 * Format a user record for public display (excludes private fields)
 */
function formatPublicUser(
  user: UserRecord,
  options?: { isFollowing?: boolean; isFollowingYou?: boolean }
) {
  return {
    id: user.id,
    displayName: user.display_name,
    username: user.username,
    profileImageUrl: user.profile_image_url,
    bio: user.bio ?? null,
    location: user.location ?? null,
    currentStreak: user.current_streak || 0,
    longestStreak: user.longest_streak || 0,
    totalPlanks: user.total_planks || 0,
    longestPlankSeconds: user.longest_plank_seconds || 0,
    followerCount: user.follower_count || 0,
    followingCount: user.following_count || 0,
    ...(options?.isFollowing !== undefined && { isFollowing: options.isFollowing }),
    ...(options?.isFollowingYou !== undefined && { isFollowingYou: options.isFollowingYou }),
  };
}

/**
 * Create a follow notification for the followed user
 */
async function createFollowNotification(
  db: D1Database,
  followerId: string,
  followedUserId: string,
  followerDisplayName: string,
  followerImageUrl?: string | null
): Promise<void> {
  const notificationId = crypto.randomUUID();
  const now = new Date().toISOString();
  
  await db
    .prepare(`
      INSERT INTO notifications (id, user_id, type, title, message, related_entity_type, related_entity_id, actor_image_url, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    `)
    .bind(
      notificationId,
      followedUserId,
      'follow',
      followerDisplayName,
      'started following you',
      'user',
      followerId,
      followerImageUrl ?? null,
      now
    )
    .run();
}

// ============================================
// ROUTES
// ============================================

/**
 * GET /users/me - Get current user's profile
 */
users.get('/me', authMiddleware, async (c) => {
  const userId = c.get('userId')!;
  
  const user = await c.env.DB
    .prepare('SELECT * FROM users WHERE id = ? AND deleted_at IS NULL')
    .bind(userId)
    .first<UserRecord>();
  
  if (!user) {
    return errors.notFound(c, 'User');
  }
  
  return success(c, formatUser(user));
});

/**
 * PATCH /users/me - Update current user's profile
 */
users.patch('/me', authMiddleware, zValidator('json', updateProfileSchema), async (c) => {
  const userId = c.get('userId')!;
  const updates = c.req.valid('json');
  
  // Build update query dynamically
  const fields: string[] = [];
  const values: unknown[] = [];
  
  if (updates.displayName !== undefined) {
    fields.push('display_name = ?');
    values.push(updates.displayName);
  }
  
  if (updates.username !== undefined) {
    // Username uniqueness is enforced by database UNIQUE constraint
    // We handle constraint violations after the UPDATE attempt
    fields.push('username = ?');
    values.push(updates.username);
  }
  
  if (updates.location !== undefined) {
    fields.push('location = ?');
    values.push(updates.location);
  }
  
  if (updates.bio !== undefined) {
    fields.push('bio = ?');
    values.push(updates.bio);
  }
  
  if (updates.preferredPlankType !== undefined) {
    fields.push('preferred_plank_type = ?');
    values.push(updates.preferredPlankType);
  }
  
  if (updates.timezone !== undefined) {
    fields.push('timezone = ?');
    values.push(updates.timezone);
  }
  
  if (updates.plankGoalSeconds !== undefined) {
    fields.push('plank_goal_seconds = ?');
    values.push(updates.plankGoalSeconds);
  }
  
  if (updates.reminderEnabled != null) {
    fields.push('reminder_enabled = ?');
    values.push(updates.reminderEnabled ? 1 : 0);
  }
  
  if (updates.reminderTime != null) {
    fields.push('reminder_time = ?');
    values.push(updates.reminderTime);
  }
  
  if (fields.length === 0) {
    return errors.validation(c, 'No fields to update');
  }
  
  // Add updated_at
  fields.push('updated_at = ?');
  values.push(new Date().toISOString());
  
  // Add userId for WHERE clause
  values.push(userId);
  
  // SECURITY: Use try-catch to handle UNIQUE constraint violations atomically
  // This prevents race conditions where two users try to claim the same username
  try {
    await c.env.DB
      .prepare(`UPDATE users SET ${fields.join(', ')} WHERE id = ?`)
      .bind(...values)
      .run();
  } catch (error) {
    // Handle unique constraint violation for username
    const errorMessage = error instanceof Error ? error.message : String(error);
    if (errorMessage.includes('UNIQUE constraint failed') && errorMessage.includes('username')) {
      return errors.conflict(c, 'Username is already taken');
    }
    // Re-throw unexpected errors
    throw error;
  }
  
  // Fetch updated user
  const user = await c.env.DB
    .prepare('SELECT * FROM users WHERE id = ?')
    .bind(userId)
    .first<UserRecord>();
  
  if (!user) {
    return errors.serverError(c, 'Failed to retrieve updated user');
  }
  
  return success(c, formatUser(user));
});

/**
 * GET /users/search - Search users
 * NOTE: This route MUST be defined before /:id to avoid "search" being treated as an ID
 */
users.get('/search', authMiddleware, async (c) => {
  const query = c.req.query('q');
  const { limit, offset } = parsePagination(c.req.query('limit'), c.req.query('offset'));
  
  if (!query || query.length < 2) {
    return errors.validation(c, 'Search query must be at least 2 characters');
  }
  
  // Escape LIKE pattern special characters to prevent unexpected matching
  const escapedQuery = escapeLikePattern(query);
  const searchPattern = `%${escapedQuery}%`;
  
  const results = await c.env.DB
    .prepare(`
      SELECT * FROM users 
      WHERE deleted_at IS NULL 
        AND (display_name LIKE ? ESCAPE '\\' OR username LIKE ? ESCAPE '\\')
      ORDER BY follower_count DESC
      LIMIT ? OFFSET ?
    `)
    .bind(searchPattern, searchPattern, limit, offset)
    .all<UserRecord>();
  
  const usersList = (results.results || []).map(user => formatPublicUser(user));
  
  return success(c, {
    users: usersList,
    pagination: {
      limit,
      offset,
      hasMore: usersList.length === limit,
    },
  });
});

/**
 * GET /users/discover - Get suggested users to follow
 * 
 * Returns a list of users the current user might want to follow, based on:
 * 1. Mutual follows (people followed by users you follow) - highest priority
 * 2. Similar streak levels (users with similar current streaks)
 * 3. Recently active users (planked in the last 7 days)
 * 4. Popular users (high follower count) - fallback
 * 
 * Excludes: current user, already-followed users, deleted users
 * 
 * NOTE: This route MUST be defined before /:id to avoid "discover" being treated as an ID
 */
users.get('/discover', authMiddleware, async (c) => {
  const userId = c.get('userId')!;
  const { limit } = parsePagination(c.req.query('limit'), undefined, 30, 10);
  
  // Get current user's streak for similarity matching
  const currentUser = await c.env.DB
    .prepare('SELECT current_streak FROM users WHERE id = ?')
    .bind(userId)
    .first<Pick<UserRecord, 'current_streak'>>();
  
  const userStreak = currentUser?.current_streak || 0;
  
  // Calculate streak range for "similar" users (±50% or at least ±3 days)
  const streakMargin = Math.max(Math.floor(userStreak * 0.5), 3);
  const minStreak = Math.max(0, userStreak - streakMargin);
  const maxStreak = userStreak + streakMargin;
  
  // Date threshold for "recently active" (7 days ago)
  const sevenDaysAgo = new Date();
  sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);
  const recentDate = sevenDaysAgo.toISOString().split('T')[0];
  
  // Complex query that scores users based on multiple factors
  // Using a scoring system:
  // - Mutual follows: 100 points per connection (people followed by your friends)
  // - Similar streak: 50 points if within range
  // - Recently active: 30 points if planked in last 7 days
  // - Base popularity: follower_count / 10 (capped contribution)
  const suggestions = await c.env.DB
    .prepare(`
      WITH 
        -- Get IDs of users the current user follows
        my_following AS (
          SELECT following_id FROM follows WHERE follower_id = ?
        ),
        -- "Friends of friends": users followed BY people you follow
        -- For each user, count how many of your friends follow them
        friends_of_friends AS (
          SELECT 
            f.following_id as user_id, 
            COUNT(DISTINCT f.follower_id) as mutual_count
          FROM follows f
          WHERE f.follower_id IN (SELECT following_id FROM my_following)
            AND f.following_id != ?
            AND f.following_id NOT IN (SELECT following_id FROM my_following)
          GROUP BY f.following_id
        )
      SELECT 
        u.*,
        COALESCE(fof.mutual_count, 0) as mutual_count,
        -- Scoring calculation
        (
          COALESCE(fof.mutual_count, 0) * 100 +
          CASE WHEN u.current_streak BETWEEN ? AND ? THEN 50 ELSE 0 END +
          CASE WHEN u.last_plank_date >= ? THEN 30 ELSE 0 END +
          MIN(u.follower_count / 10, 20)
        ) as score
      FROM users u
      LEFT JOIN friends_of_friends fof ON u.id = fof.user_id
      WHERE u.id != ?
        AND u.deleted_at IS NULL
        AND u.id NOT IN (SELECT following_id FROM my_following)
      ORDER BY score DESC, u.follower_count DESC
      LIMIT ?
    `)
    .bind(
      userId,           // for my_following CTE
      userId,           // exclude self from friends_of_friends
      minStreak,        // streak range min
      maxStreak,        // streak range max
      recentDate,       // recently active threshold
      userId,           // exclude self from results
      limit
    )
    .all<UserRecord & { mutual_count: number; score: number }>();
  
  // Format results with suggestion reason
  const suggestedUsers = (suggestions.results || []).map((user) => {
    const mutualCount = user.mutual_count;
    const streak = user.current_streak;
    const lastPlankDate = user.last_plank_date;
    
    // Determine primary reason for suggestion
    let reason: string;
    if (mutualCount > 0) {
      reason = mutualCount === 1 
        ? 'Followed by someone you follow'
        : `Followed by ${mutualCount} people you follow`;
    } else if (streak >= minStreak && streak <= maxStreak && userStreak > 0) {
      reason = 'Similar streak level';
    } else if (lastPlankDate && lastPlankDate >= recentDate) {
      reason = 'Recently active';
    } else {
      reason = 'Popular in the community';
    }
    
    return {
      ...formatPublicUser(user),
      suggestionReason: reason,
      mutualFollows: mutualCount,
    };
  });
  
  // Determine status for empty results context
  const status = suggestedUsers.length > 0 
    ? 'suggestions_available' 
    : 'no_suggestions';
  
  return success(c, {
    users: suggestedUsers,
    meta: {
      yourStreak: userStreak,
      streakRange: { min: minStreak, max: maxStreak },
      totalCandidates: suggestedUsers.length,
      status,
    },
  });
});

/**
 * GET /users/:id - Get user's public profile
 * NOTE: This route MUST be defined after specific routes like /search, /discover, and /me
 */
users.get('/:id', optionalAuthMiddleware, async (c) => {
  const targetUserId = c.req.param('id')!;
  const currentUserId = c.get('userId');
  
  const user = await c.env.DB
    .prepare('SELECT * FROM users WHERE id = ? AND deleted_at IS NULL')
    .bind(targetUserId)
    .first<UserRecord>();
  
  if (!user) {
    return errors.notFound(c, 'User');
  }
  
  // Check follow relationships if authenticated
  let isFollowing: boolean | undefined;
  let isFollowingYou: boolean | undefined;
  
  if (currentUserId && currentUserId !== targetUserId) {
    // Batch both queries for efficiency
    const [followingResult, followedByResult] = await c.env.DB.batch([
      c.env.DB
        .prepare('SELECT id FROM follows WHERE follower_id = ? AND following_id = ?')
        .bind(currentUserId, targetUserId),
      c.env.DB
        .prepare('SELECT id FROM follows WHERE follower_id = ? AND following_id = ?')
        .bind(targetUserId, currentUserId),
    ]);
    
    isFollowing = (followingResult.results?.length || 0) > 0;
    isFollowingYou = (followedByResult.results?.length || 0) > 0;
  }
  
  return success(c, formatPublicUser(user, { isFollowing, isFollowingYou }));
});

/**
 * POST /users/:id/follow - Follow a user
 */
users.post('/:id/follow', authMiddleware, async (c) => {
  const targetUserId = c.req.param('id')!;
  const currentUserId = c.get('userId')!;
  
  if (currentUserId === targetUserId) {
    return errors.validation(c, 'You cannot follow yourself');
  }
  
  // Check if target user exists and get their info for notification
  const targetUser = await c.env.DB
    .prepare('SELECT id, display_name FROM users WHERE id = ? AND deleted_at IS NULL')
    .bind(targetUserId)
    .first<Pick<UserRecord, 'id' | 'display_name'>>();
  
  if (!targetUser) {
    return errors.notFound(c, 'User');
  }
  
  // Get current user's display name and avatar for the follow notification
  const currentUser = await c.env.DB
    .prepare('SELECT display_name, profile_image_url FROM users WHERE id = ?')
    .bind(currentUserId)
    .first<Pick<UserRecord, 'display_name' | 'profile_image_url'>>();
  
  const followerDisplayName = currentUser?.display_name || 'Someone';
  const followerImageUrl = currentUser?.profile_image_url ?? null;
  
  // Create follow relationship and update counts
  // SECURITY: Use INSERT with UNIQUE constraint to prevent race conditions
  // Two concurrent requests both checking "not following" could pass the check
  // The UNIQUE constraint ensures only one succeeds
  const followId = crypto.randomUUID();
  const now = new Date().toISOString();
  
  try {
    await c.env.DB.batch([
      c.env.DB
        .prepare('INSERT INTO follows (id, follower_id, following_id, created_at) VALUES (?, ?, ?, ?)')
        .bind(followId, currentUserId, targetUserId, now),
      c.env.DB
        .prepare('UPDATE users SET following_count = following_count + 1 WHERE id = ?')
        .bind(currentUserId),
      c.env.DB
        .prepare('UPDATE users SET follower_count = follower_count + 1 WHERE id = ?')
        .bind(targetUserId),
    ]);
  } catch (error) {
    // Handle duplicate follow (UNIQUE constraint violation)
    const errorMessage = error instanceof Error ? error.message : String(error);
    if (errorMessage.includes('UNIQUE constraint failed')) {
      return errors.conflict(c, 'You are already following this user');
    }
    console.error('Failed to create follow relationship:', error);
    return errors.serverError(c, 'Failed to follow user');
  }
  
  // Create notification for the followed user (non-blocking)
  try {
    await createFollowNotification(c.env.DB, currentUserId, targetUserId, followerDisplayName, followerImageUrl);
    sendSilentPush(c.env, targetUserId).catch(() => {});
  } catch (notificationError) {
    // Log but don't fail the follow operation
    console.error('Failed to create follow notification:', notificationError);
  }
  
  return success(c, { following: true }, 201);
});

/**
 * DELETE /users/:id/follow - Unfollow a user
 */
users.delete('/:id/follow', authMiddleware, async (c) => {
  const targetUserId = c.req.param('id')!;
  const currentUserId = c.get('userId')!;
  
  // Check if following
  const existingFollow = await c.env.DB
    .prepare('SELECT id FROM follows WHERE follower_id = ? AND following_id = ?')
    .bind(currentUserId, targetUserId)
    .first();
  
  if (!existingFollow) {
    return errors.notFound(c, 'Follow relationship');
  }
  
  try {
    await c.env.DB.batch([
      c.env.DB
        .prepare('DELETE FROM follows WHERE follower_id = ? AND following_id = ?')
        .bind(currentUserId, targetUserId),
      c.env.DB
        .prepare('UPDATE users SET following_count = MAX(0, following_count - 1) WHERE id = ?')
        .bind(currentUserId),
      c.env.DB
        .prepare('UPDATE users SET follower_count = MAX(0, follower_count - 1) WHERE id = ?')
        .bind(targetUserId),
    ]);
  } catch (error) {
    console.error('Failed to delete follow relationship:', error);
    return errors.serverError(c, 'Failed to unfollow user');
  }
  
  return success(c, { following: false });
});

/**
 * GET /users/:id/followers - Get user's followers
 */
users.get('/:id/followers', optionalAuthMiddleware, async (c) => {
  const targetUserId = c.req.param('id')!;
  const { limit, offset } = parsePagination(c.req.query('limit'), c.req.query('offset'));
  
  // First verify the target user exists
  const targetUser = await c.env.DB
    .prepare('SELECT id FROM users WHERE id = ? AND deleted_at IS NULL')
    .bind(targetUserId)
    .first();
  
  if (!targetUser) {
    return errors.notFound(c, 'User');
  }
  
  const results = await c.env.DB
    .prepare(`
      SELECT u.* FROM users u
      INNER JOIN follows f ON u.id = f.follower_id
      WHERE f.following_id = ? AND u.deleted_at IS NULL
      ORDER BY f.created_at DESC
      LIMIT ? OFFSET ?
    `)
    .bind(targetUserId, limit, offset)
    .all<UserRecord>();
  
  const followers = (results.results || []).map(user => formatPublicUser(user));
  
  return success(c, {
    users: followers,
    pagination: {
      limit,
      offset,
      hasMore: followers.length === limit,
    },
  });
});

/**
 * GET /users/:id/following - Get users that this user follows
 */
users.get('/:id/following', optionalAuthMiddleware, async (c) => {
  const targetUserId = c.req.param('id')!;
  const { limit, offset } = parsePagination(c.req.query('limit'), c.req.query('offset'));
  
  // First verify the target user exists
  const targetUser = await c.env.DB
    .prepare('SELECT id FROM users WHERE id = ? AND deleted_at IS NULL')
    .bind(targetUserId)
    .first();
  
  if (!targetUser) {
    return errors.notFound(c, 'User');
  }
  
  const results = await c.env.DB
    .prepare(`
      SELECT u.* FROM users u
      INNER JOIN follows f ON u.id = f.following_id
      WHERE f.follower_id = ? AND u.deleted_at IS NULL
      ORDER BY f.created_at DESC
      LIMIT ? OFFSET ?
    `)
    .bind(targetUserId, limit, offset)
    .all<UserRecord>();
  
  const following = (results.results || []).map(user => formatPublicUser(user));
  
  return success(c, {
    users: following,
    pagination: {
      limit,
      offset,
      hasMore: following.length === limit,
    },
  });
});

export default users;
