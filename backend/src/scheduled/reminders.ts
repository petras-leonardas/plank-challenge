/**
 * Daily Plank Reminder — Cron Handler
 *
 * Runs every 5 minutes via Cloudflare Workers cron trigger.
 * For each user who:
 *   1. Has reminders enabled (reminder_enabled = 1)
 *   2. Hasn't planked today (last_plank_date < today in their timezone)
 *   3. Has a reminder_time that falls within the current 5-minute window
 *   4. Hasn't already been sent a reminder today (KV idempotency key)
 *
 * ...sends a visible alert push via APNs.
 *
 * Timezone handling:
 *   The cron fires in UTC. For each eligible user, we convert "now" to their
 *   local timezone, extract the local HH:mm, and check if it falls within the
 *   5-minute window starting at their reminder_time. This ensures a user in
 *   UTC+9 with a 19:00 reminder gets it at 19:00 JST, not 19:00 UTC.
 *
 * Idempotency:
 *   After sending, we write a KV key `reminder-sent:{userId}:{YYYY-MM-DD}`
 *   with a 24-hour TTL. The query excludes users who already have this key.
 */

import type { Env } from '../types/env';
import { sendAlertPush } from '../utils/push';

/**
 * Returns today's date as YYYY-MM-DD in the given IANA timezone.
 */
function todayInTimezone(timezone: string): string {
  try {
    const formatter = new Intl.DateTimeFormat('en-CA', {
      timeZone: timezone,
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
    });
    return formatter.format(new Date()); // en-CA gives YYYY-MM-DD
  } catch {
    // Invalid timezone — fall back to UTC
    return new Date().toISOString().slice(0, 10);
  }
}

/**
 * Returns the current local time as "HH:mm" in the given IANA timezone.
 */
function currentTimeInTimezone(timezone: string): { hour: number; minute: number } {
  try {
    const now = new Date();
    const parts = new Intl.DateTimeFormat('en-US', {
      timeZone: timezone,
      hour: 'numeric',
      minute: 'numeric',
      hourCycle: 'h23',
    }).formatToParts(now);

    const hour = parseInt(parts.find(p => p.type === 'hour')?.value || '0', 10);
    const minute = parseInt(parts.find(p => p.type === 'minute')?.value || '0', 10);
    return { hour, minute };
  } catch {
    // Invalid timezone — return midnight so no reminder fires
    return { hour: 0, minute: 0 };
  }
}

/**
 * Checks if a reminder_time "HH:mm" falls within the 5-minute window
 * [localHour:localMinute, localHour:localMinute+4].
 */
function isInCurrentWindow(
  reminderTime: string,
  localHour: number,
  localMinute: number,
): boolean {
  const [rHour, rMinute] = reminderTime.split(':').map(Number);
  if (isNaN(rHour) || isNaN(rMinute)) return false;

  const reminderTotalMinutes = rHour * 60 + rMinute;
  const currentTotalMinutes = localHour * 60 + localMinute;

  // Window: [current, current + 4] — the cron runs every 5 minutes
  return (
    reminderTotalMinutes >= currentTotalMinutes &&
    reminderTotalMinutes <= currentTotalMinutes + 4
  );
}

/**
 * Main cron handler. Called by the scheduled export in index.ts.
 */
export async function handleReminders(env: Env): Promise<void> {
  // Step 1: Find all users with reminders enabled who have at least one device.
  // We don't filter by timezone/time in SQL — there are too many timezone
  // edge cases. Instead we fetch all reminder-enabled users and filter in JS.
  const result = await env.DB
    .prepare(`
      SELECT DISTINCT
        u.id,
        u.reminder_time,
        u.timezone,
        u.last_plank_date
      FROM users u
      INNER JOIN devices d ON u.id = d.user_id
      WHERE u.reminder_enabled = 1
        AND u.deleted_at IS NULL
    `)
    .all<{
      id: string;
      reminder_time: string;
      timezone: string;
      last_plank_date: string | null;
    }>();

  const users = result.results || [];
  if (users.length === 0) return;

  let sentCount = 0;

  // Step 2: For each user, check timezone-aware conditions.
  // Process in batches to stay within Cloudflare Workers subrequest limits.
  const BATCH_SIZE = 50;
  for (let i = 0; i < users.length; i += BATCH_SIZE) {
    const batch = users.slice(i, i + BATCH_SIZE);
    await Promise.allSettled(batch.map(async (user) => {
      const tz = user.timezone || 'UTC';
      const today = todayInTimezone(tz);
      const { hour, minute } = currentTimeInTimezone(tz);

      // Skip if already planked today
      if (user.last_plank_date === today) return;

      // Skip if not in the current 5-minute window
      if (!isInCurrentWindow(user.reminder_time || '19:00', hour, minute)) return;

      // Idempotency: check KV to avoid duplicate sends
      const kvKey = `reminder-sent:${user.id}:${today}`;
      const alreadySent = await env.CACHE.get(kvKey);
      if (alreadySent) return;

      // Send the alert push
      await sendAlertPush(
        env,
        user.id,
        'Time to plank 🔥',
        'Your streak is waiting.',
      );

      // Mark as sent with 24-hour TTL
      await env.CACHE.put(kvKey, '1', { expirationTtl: 86400 });
      sentCount++;
    }));
  }

  if (sentCount > 0) {
    console.log(`[Reminders] Sent ${sentCount} reminder(s)`);
  }
}
