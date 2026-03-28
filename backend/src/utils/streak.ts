/**
 * Streak calculation utilities
 * 
 * Handles server-side streak calculation based on plank history.
 * The streak is timezone-aware - a day is determined by each plank's stored timezone.
 * 
 * IMPORTANT: Each plank stores its own timezone because users may travel or change
 * timezones. We use the plank's timezone to determine what "day" it was performed on.
 */

export interface StreakInfo {
  currentStreak: number;
  longestStreak: number;
  lastPlankDate: string | null;
  freezeTokens: number;
  streakProtectedUntil: string | null;
}

export interface StreakCalculationResult {
  currentStreak: number;
  longestStreak: number;
  lastPlankDate: string | null;
}

/**
 * Validate that a timezone string is a valid IANA timezone
 */
export function isValidTimezone(timezone: string): boolean {
  try {
    Intl.DateTimeFormat(undefined, { timeZone: timezone });
    return true;
  } catch {
    return false;
  }
}

/**
 * Get the date string (YYYY-MM-DD) for a given timestamp in a specific timezone
 */
export function getDateInTimezone(date: Date, timezone: string): string {
  try {
    const formatter = new Intl.DateTimeFormat('en-CA', {
      timeZone: timezone,
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
    });
    return formatter.format(date);
  } catch {
    // Fallback to UTC if timezone is invalid
    console.warn(`Invalid timezone "${timezone}", falling back to UTC`);
    return date.toISOString().split('T')[0];
  }
}

/**
 * Get today's date string in a specific timezone
 */
export function getTodayInTimezone(timezone: string): string {
  return getDateInTimezone(new Date(), timezone);
}

/**
 * Get yesterday's date string in a specific timezone
 */
export function getYesterdayInTimezone(timezone: string): string {
  const yesterday = new Date();
  yesterday.setDate(yesterday.getDate() - 1);
  return getDateInTimezone(yesterday, timezone);
}

/** Maximum reasonable streak value (10 years of daily planks) */
const MAX_STREAK = 3650;

/** Maximum reasonable total planks (100 planks/day for 10 years) */
const MAX_TOTAL_PLANKS = 365000;

/** Maximum reasonable plank duration in seconds (24 hours) */
const MAX_PLANK_DURATION = 86400;

/**
 * Safely bound a number to prevent integer overflow/unreasonable values
 */
function boundValue(value: number, min: number, max: number): number {
  if (!Number.isFinite(value)) return min;
  return Math.max(min, Math.min(max, Math.floor(value)));
}

/**
 * Calculate consecutive days between two dates
 * Returns the number of days difference (0 = same day, 1 = consecutive, >1 = gap)
 */
function daysDifference(dateStr1: string, dateStr2: string): number {
  const date1 = new Date(dateStr1 + 'T00:00:00Z');
  const date2 = new Date(dateStr2 + 'T00:00:00Z');
  
  // Guard against invalid dates
  if (isNaN(date1.getTime()) || isNaN(date2.getTime())) {
    return Number.MAX_SAFE_INTEGER; // Treat as a gap to break streak
  }
  
  const diffTime = Math.abs(date2.getTime() - date1.getTime());
  return Math.floor(diffTime / (1000 * 60 * 60 * 24));
}

/**
 * Get yesterday's date from a date string
 */
function getYesterdayFromDateString(dateStr: string): string {
  const date = new Date(dateStr + 'T00:00:00Z');
  date.setDate(date.getDate() - 1);
  return date.toISOString().split('T')[0];
}

/**
 * Calculate streak from a list of plank dates
 * 
 * @param plankDates - Array of date strings (YYYY-MM-DD) when planks occurred, already converted to local dates
 * @param todayDate - Today's date string in user's timezone
 * @param existingLongestStreak - The user's existing longest streak (optional, we now recalculate from history)
 * @returns StreakCalculationResult
 */
export function calculateStreakFromDates(
  plankDates: string[],
  todayDate: string,
  existingLongestStreak: number = 0
): StreakCalculationResult {
  if (plankDates.length === 0) {
    return {
      currentStreak: 0,
      longestStreak: existingLongestStreak,
      lastPlankDate: null,
    };
  }

  // Get unique dates and sort descending (most recent first)
  const uniqueDates = [...new Set(plankDates)].sort().reverse();
  const lastPlankDate = uniqueDates[0];

  // Calculate days since last plank
  const daysSinceLastPlank = daysDifference(lastPlankDate, todayDate);

  // If last plank was more than 1 day ago, streak is broken
  if (daysSinceLastPlank > 1) {
    // Recalculate longest streak from all dates to ensure accuracy
    const longestFromHistory = calculateLongestStreakFromDates(uniqueDates);
    return {
      currentStreak: 0,
      longestStreak: Math.max(longestFromHistory, existingLongestStreak),
      lastPlankDate,
    };
  }

  // Count consecutive days for current streak
  let currentStreak = 1;
  for (let i = 1; i < uniqueDates.length; i++) {
    const diff = daysDifference(uniqueDates[i], uniqueDates[i - 1]);
    if (diff === 1) {
      currentStreak++;
    } else {
      break;
    }
  }

  // Calculate longest streak from history (more accurate than just comparing to existing)
  const longestFromHistory = calculateLongestStreakFromDates(uniqueDates);
  const longestStreak = Math.max(currentStreak, longestFromHistory, existingLongestStreak);

  return {
    // Bound streak values to prevent overflow/corruption
    currentStreak: boundValue(currentStreak, 0, MAX_STREAK),
    longestStreak: boundValue(longestStreak, 0, MAX_STREAK),
    lastPlankDate,
  };
}

/**
 * Calculate the longest streak from a list of unique dates
 * This scans through all dates to find the longest consecutive sequence
 */
function calculateLongestStreakFromDates(uniqueDatesSortedDesc: string[]): number {
  if (uniqueDatesSortedDesc.length === 0) return 0;
  if (uniqueDatesSortedDesc.length === 1) return 1;

  let longestStreak = 1;
  let currentStreak = 1;

  for (let i = 1; i < uniqueDatesSortedDesc.length; i++) {
    const diff = daysDifference(uniqueDatesSortedDesc[i], uniqueDatesSortedDesc[i - 1]);
    if (diff === 1) {
      currentStreak++;
      longestStreak = Math.max(longestStreak, currentStreak);
    } else {
      currentStreak = 1;
    }
  }

  return longestStreak;
}

/**
 * Convert a plank's performed_at timestamp to a local date string using its stored timezone
 * 
 * This is the critical function that fixes the timezone bug. Each plank knows what
 * timezone it was performed in, so we use that timezone to determine the local date.
 */
function getPlankLocalDate(performedAt: string, timezone: string): string {
  const date = new Date(performedAt);
  return getDateInTimezone(date, timezone);
}

/**
 * Recalculate and update user streak based on their plank history
 * 
 * This is the main function to call after plank creation/deletion.
 * 
 * CRITICAL FIX: We now fetch both performed_at and timezone for each plank,
 * then convert to local dates using each plank's timezone. This handles:
 * - Users in different timezones
 * - Users who travel and plank in different timezones
 * - Edge cases around midnight UTC
 */
export async function recalculateUserStreak(
  db: D1Database,
  userId: string,
  userTimezone: string = 'UTC'
): Promise<StreakCalculationResult> {
  // FIXED: Fetch performed_at AND timezone for each plank
  // We need the raw timestamp and timezone to properly calculate local dates
  const planks = await db
    .prepare(`
      SELECT performed_at, timezone
      FROM plank_sessions
      WHERE user_id = ? AND deleted_at IS NULL
      ORDER BY performed_at DESC
    `)
    .bind(userId)
    .all<{ performed_at: string; timezone: string }>();

  // Get user's existing longest streak (as a fallback/floor)
  const user = await db
    .prepare('SELECT longest_streak FROM users WHERE id = ?')
    .bind(userId)
    .first<{ longest_streak: number }>();

  const existingLongestStreak = user?.longest_streak || 0;

  // Convert each plank's performed_at to its local date using its timezone
  const plankDates = planks.results.map((p) => 
    getPlankLocalDate(p.performed_at, p.timezone || 'UTC')
  );

  // Use the user's current timezone for determining "today"
  const todayDate = getTodayInTimezone(userTimezone);

  const result = calculateStreakFromDates(plankDates, todayDate, existingLongestStreak);

  // Update user record
  await db
    .prepare(`
      UPDATE users SET
        current_streak = ?,
        longest_streak = ?,
        last_plank_date = ?,
        updated_at = ?
      WHERE id = ?
    `)
    .bind(
      result.currentStreak,
      result.longestStreak,
      result.lastPlankDate,
      new Date().toISOString(),
      userId
    )
    .run();

  return result;
}

/**
 * Update user statistics after a plank is created
 * 
 * Returns the prepared statements for use in a batch transaction
 */
export function prepareStatsUpdateAfterPlank(
  db: D1Database,
  userId: string,
  durationSeconds: number,
  currentStats: { total_planks: number; total_plank_seconds: number; longest_plank_seconds: number }
): D1PreparedStatement {
  // Bound all values to prevent overflow
  const safeDuration = boundValue(durationSeconds, 0, MAX_PLANK_DURATION);
  const newTotalPlanks = boundValue((currentStats.total_planks || 0) + 1, 0, MAX_TOTAL_PLANKS);
  const newTotalSeconds = boundValue((currentStats.total_plank_seconds || 0) + safeDuration, 0, MAX_TOTAL_PLANKS * MAX_PLANK_DURATION);
  const newLongestPlank = boundValue(Math.max(currentStats.longest_plank_seconds || 0, safeDuration), 0, MAX_PLANK_DURATION);

  return db
    .prepare(`
      UPDATE users SET
        total_planks = ?,
        total_plank_seconds = ?,
        longest_plank_seconds = ?,
        updated_at = ?
      WHERE id = ?
    `)
    .bind(
      newTotalPlanks,
      newTotalSeconds,
      newLongestPlank,
      new Date().toISOString(),
      userId
    );
}

/**
 * Update user statistics after a plank is created (standalone version)
 */
export async function updateUserStatsAfterPlank(
  db: D1Database,
  userId: string,
  durationSeconds: number
): Promise<void> {
  const user = await db
    .prepare(`
      SELECT total_planks, total_plank_seconds, longest_plank_seconds
      FROM users WHERE id = ?
    `)
    .bind(userId)
    .first<{
      total_planks: number;
      total_plank_seconds: number;
      longest_plank_seconds: number;
    }>();

  if (!user) return;

  // Bound all values to prevent overflow
  const safeDuration = boundValue(durationSeconds, 0, MAX_PLANK_DURATION);
  const newTotalPlanks = boundValue((user.total_planks || 0) + 1, 0, MAX_TOTAL_PLANKS);
  const newTotalSeconds = boundValue((user.total_plank_seconds || 0) + safeDuration, 0, MAX_TOTAL_PLANKS * MAX_PLANK_DURATION);
  const newLongestPlank = boundValue(Math.max(user.longest_plank_seconds || 0, safeDuration), 0, MAX_PLANK_DURATION);

  await db
    .prepare(`
      UPDATE users SET
        total_planks = ?,
        total_plank_seconds = ?,
        longest_plank_seconds = ?,
        updated_at = ?
      WHERE id = ?
    `)
    .bind(
      newTotalPlanks,
      newTotalSeconds,
      newLongestPlank,
      new Date().toISOString(),
      userId
    )
    .run();
}

/**
 * Update user statistics after a plank is deleted
 * 
 * Note: We recalculate from scratch to ensure accuracy.
 * The durationSeconds parameter is kept for API compatibility but not used.
 */
export async function updateUserStatsAfterDelete(
  db: D1Database,
  userId: string,
  _durationSeconds?: number // Kept for backwards compatibility, not used
): Promise<void> {
  // Recalculate stats from remaining planks (most accurate approach)
  const stats = await db
    .prepare(`
      SELECT 
        COUNT(*) as total_planks,
        COALESCE(SUM(duration_seconds), 0) as total_plank_seconds,
        COALESCE(MAX(duration_seconds), 0) as longest_plank_seconds
      FROM plank_sessions
      WHERE user_id = ? AND deleted_at IS NULL
    `)
    .bind(userId)
    .first<{
      total_planks: number;
      total_plank_seconds: number;
      longest_plank_seconds: number;
    }>();

  if (!stats) return;

  await db
    .prepare(`
      UPDATE users SET
        total_planks = ?,
        total_plank_seconds = ?,
        longest_plank_seconds = ?,
        updated_at = ?
      WHERE id = ?
    `)
    .bind(
      stats.total_planks,
      stats.total_plank_seconds,
      stats.longest_plank_seconds,
      new Date().toISOString(),
      userId
    )
    .run();
}

/**
 * Use a freeze token to protect streak (ATOMIC VERSION)
 * 
 * Uses a single UPDATE with a WHERE clause to atomically check and decrement.
 * This prevents race conditions where two requests could both decrement.
 * 
 * @returns success: true if freeze was used, false otherwise
 */
export async function useFreezeTokenAtomic(
  db: D1Database,
  userId: string
): Promise<{ success: boolean; remainingTokens: number; error?: string }> {
  // First, get current state to validate business rules
  const user = await db
    .prepare('SELECT freeze_tokens, current_streak FROM users WHERE id = ?')
    .bind(userId)
    .first<{ freeze_tokens: number; current_streak: number }>();

  if (!user) {
    return { success: false, remainingTokens: 0, error: 'User not found' };
  }

  if (user.freeze_tokens <= 0) {
    return { success: false, remainingTokens: 0, error: 'No freeze tokens available' };
  }

  if (user.current_streak === 0) {
    return { success: false, remainingTokens: user.freeze_tokens, error: 'No active streak to protect' };
  }

  // ATOMIC: Decrement only if freeze_tokens > 0 and current_streak > 0
  // The WHERE clause ensures we only decrement if conditions are still valid
  const result = await db
    .prepare(`
      UPDATE users SET
        freeze_tokens = freeze_tokens - 1,
        updated_at = ?
      WHERE id = ? AND freeze_tokens > 0 AND current_streak > 0
    `)
    .bind(new Date().toISOString(), userId)
    .run();

  // Check if the update actually happened
  if (result.meta.changes === 0) {
    // Race condition: another request got there first, or state changed
    // Re-fetch to get current state
    const updatedUser = await db
      .prepare('SELECT freeze_tokens FROM users WHERE id = ?')
      .bind(userId)
      .first<{ freeze_tokens: number }>();
    
    return { 
      success: false, 
      remainingTokens: updatedUser?.freeze_tokens || 0,
      error: 'Freeze token could not be used (conditions changed)'
    };
  }

  // Success! Get the new token count
  const updatedUser = await db
    .prepare('SELECT freeze_tokens FROM users WHERE id = ?')
    .bind(userId)
    .first<{ freeze_tokens: number }>();

  return { 
    success: true, 
    remainingTokens: updatedUser?.freeze_tokens || 0 
  };
}

/**
 * Legacy function kept for backwards compatibility
 * @deprecated Use useFreezeTokenAtomic instead
 */
export async function useFreezeToken(
  db: D1Database,
  userId: string
): Promise<{ success: boolean; remainingTokens: number }> {
  const result = await useFreezeTokenAtomic(db, userId);
  return { success: result.success, remainingTokens: result.remainingTokens };
}

/**
 * Use a freeze token AND update streak protection dates in a SINGLE atomic operation
 * 
 * This fixes the partial failure issue where the token could be decremented
 * but the streak protection dates not updated (if the second UPDATE failed).
 * 
 * Now both operations happen in a single UPDATE statement, ensuring atomicity.
 * 
 * @returns success: true if freeze was used and dates updated, false otherwise
 */
export async function useFreezeTokenAndProtectStreak(
  db: D1Database,
  userId: string,
  today: string
): Promise<{ success: boolean; remainingTokens: number; error?: string }> {
  // First, get current state to validate business rules and provide good error messages
  const user = await db
    .prepare('SELECT freeze_tokens, current_streak, last_freeze_date FROM users WHERE id = ?')
    .bind(userId)
    .first<{ freeze_tokens: number; current_streak: number; last_freeze_date: string | null }>();

  if (!user) {
    return { success: false, remainingTokens: 0, error: 'User not found' };
  }

  if (user.freeze_tokens <= 0) {
    return { success: false, remainingTokens: 0, error: 'No freeze tokens available' };
  }

  if (user.current_streak === 0) {
    return { success: false, remainingTokens: user.freeze_tokens, error: 'No active streak to protect' };
  }

  if (user.last_freeze_date === today) {
    return { success: false, remainingTokens: user.freeze_tokens, error: 'Already used a freeze today' };
  }

  // ATOMIC: Decrement freeze_tokens AND update dates in a SINGLE statement
  // The WHERE clause ensures we only update if all conditions are still valid
  const result = await db
    .prepare(`
      UPDATE users SET
        freeze_tokens = freeze_tokens - 1,
        last_plank_date = ?,
        last_freeze_date = ?,
        updated_at = ?
      WHERE id = ? 
        AND freeze_tokens > 0 
        AND current_streak > 0
        AND (last_freeze_date IS NULL OR last_freeze_date != ?)
    `)
    .bind(today, today, new Date().toISOString(), userId, today)
    .run();

  // Check if the update actually happened
  if (result.meta.changes === 0) {
    // Race condition: another request got there first, or state changed
    // Re-fetch to get current state and provide accurate error
    const updatedUser = await db
      .prepare('SELECT freeze_tokens, last_freeze_date FROM users WHERE id = ?')
      .bind(userId)
      .first<{ freeze_tokens: number; last_freeze_date: string | null }>();
    
    if (updatedUser?.last_freeze_date === today) {
      return { 
        success: false, 
        remainingTokens: updatedUser.freeze_tokens,
        error: 'Already used a freeze today (concurrent request)'
      };
    }
    
    return { 
      success: false, 
      remainingTokens: updatedUser?.freeze_tokens || 0,
      error: 'Freeze token could not be used (conditions changed)'
    };
  }

  // Success! Get the new token count
  const updatedUser = await db
    .prepare('SELECT freeze_tokens FROM users WHERE id = ?')
    .bind(userId)
    .first<{ freeze_tokens: number }>();

  return { 
    success: true, 
    remainingTokens: updatedUser?.freeze_tokens || 0 
  };
}

/**
 * Award a freeze token to user (e.g., for completing weekly goal)
 * Uses atomic increment with a cap
 */
export async function awardFreezeToken(
  db: D1Database,
  userId: string,
  maxTokens: number = 5
): Promise<number> {
  // Atomic increment with cap using CASE expression
  await db
    .prepare(`
      UPDATE users SET
        freeze_tokens = CASE 
          WHEN freeze_tokens < ? THEN freeze_tokens + 1 
          ELSE freeze_tokens 
        END,
        updated_at = ?
      WHERE id = ?
    `)
    .bind(maxTokens, new Date().toISOString(), userId)
    .run();

  // Get new count
  const user = await db
    .prepare('SELECT freeze_tokens FROM users WHERE id = ?')
    .bind(userId)
    .first<{ freeze_tokens: number }>();

  return user?.freeze_tokens || 0;
}
