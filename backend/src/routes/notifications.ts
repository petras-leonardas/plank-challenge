import { Hono } from 'hono';
import { zValidator } from '@hono/zod-validator';
import { z } from 'zod';
import type { Env, Variables } from '../types/env';
import type { NotificationRecord, FormattedNotification, NotificationType } from '../types/api';
import { success, errors } from '../utils/response';
import { authMiddleware } from '../middleware/auth';

const notifications = new Hono<{ Bindings: Env; Variables: Variables }>();

// Apply auth middleware to all routes
notifications.use('*', authMiddleware);

// ============================================
// VALIDATION SCHEMAS
// ============================================

const listNotificationsSchema = z.object({
  limit: z.coerce.number().int().min(1).max(100).optional().default(50),
  offset: z.coerce.number().int().min(0).optional().default(0),
  unreadOnly: z.coerce.boolean().optional().default(false),
});

// ============================================
// HELPER FUNCTIONS
// ============================================

function formatNotification(notification: NotificationRecord): FormattedNotification {
  return {
    id: notification.id,
    type: notification.type,
    title: notification.title,
    message: notification.message,
    relatedEntity:
      notification.related_entity_type && notification.related_entity_id
        ? {
            type: notification.related_entity_type,
            id: notification.related_entity_id,
          }
        : null,
    actorImageUrl: notification.actor_image_url ?? null,
    isRead: notification.is_read === 1,
    createdAt: notification.created_at,
  };
}

// ============================================
// ROUTES
// ============================================

/**
 * GET /notifications - List user's notifications
 * 
 * Returns paginated notifications for the authenticated user.
 * Supports filtering to show only unread notifications.
 * 
 * RETENTION: Opportunistically cleans up old notifications on first page load.
 */
notifications.get('/', zValidator('query', listNotificationsSchema), async (c) => {
  const userId = c.get('userId');
  const { limit, offset, unreadOnly } = c.req.valid('query');
  const db = c.env.DB;

  if (!userId) {
    return errors.unauthorized(c);
  }

  // Opportunistic cleanup: on first page load, clean up old notifications
  // This runs asynchronously and doesn't block the response
  if (offset === 0) {
    // Fire and forget - don't await
    cleanupOldNotifications(db, userId).catch((err) => {
      console.error('[Notification Cleanup] Background cleanup failed:', err);
    });
  }

  // Build query
  let query = `
    SELECT id, user_id, type, title, message, related_entity_type, related_entity_id, actor_image_url, is_read, created_at
    FROM notifications
    WHERE user_id = ?
  `;
  const params: (string | number)[] = [userId];

  if (unreadOnly) {
    query += ' AND is_read = 0';
  }

  query += ' ORDER BY created_at DESC LIMIT ? OFFSET ?';
  params.push(limit, offset);

  const result = await db
    .prepare(query)
    .bind(...params)
    .all<NotificationRecord>();

  // Get total count
  let countQuery = 'SELECT COUNT(*) as total FROM notifications WHERE user_id = ?';
  const countParams: (string | number)[] = [userId];

  if (unreadOnly) {
    countQuery += ' AND is_read = 0';
  }

  const countResult = await db
    .prepare(countQuery)
    .bind(...countParams)
    .first<{ total: number }>();

  return success(c, {
    notifications: result.results.map(formatNotification),
    pagination: {
      total: countResult?.total || 0,
      limit,
      offset,
      hasMore: (countResult?.total || 0) > offset + limit,
    },
  });
});

/**
 * GET /notifications/unread-count - Get count of unread notifications
 * 
 * Returns a simple count for badge display on notification icon.
 */
notifications.get('/unread-count', async (c) => {
  const userId = c.get('userId');
  const db = c.env.DB;

  if (!userId) {
    return errors.unauthorized(c);
  }

  const result = await db
    .prepare('SELECT COUNT(*) as count FROM notifications WHERE user_id = ? AND is_read = 0')
    .bind(userId)
    .first<{ count: number }>();

  return success(c, {
    unreadCount: result?.count || 0,
  });
});

/**
 * GET /notifications/:id - Get a single notification
 */
notifications.get('/:id', async (c) => {
  const userId = c.get('userId');
  const notificationId = c.req.param('id');
  const db = c.env.DB;

  if (!userId) {
    return errors.unauthorized(c);
  }

  const notification = await db
    .prepare(`
      SELECT id, user_id, type, title, message, related_entity_type, related_entity_id, actor_image_url, is_read, created_at
      FROM notifications
      WHERE id = ? AND user_id = ?
    `)
    .bind(notificationId, userId)
    .first<NotificationRecord>();

  if (!notification) {
    return errors.notFound(c, 'Notification');
  }

  return success(c, {
    notification: formatNotification(notification),
  });
});

/**
 * POST /notifications/:id/read - Mark a single notification as read
 */
notifications.post('/:id/read', async (c) => {
  const userId = c.get('userId');
  const notificationId = c.req.param('id');
  const db = c.env.DB;

  if (!userId) {
    return errors.unauthorized(c);
  }

  // Check if notification exists and belongs to user
  const notification = await db
    .prepare('SELECT id, is_read FROM notifications WHERE id = ? AND user_id = ?')
    .bind(notificationId, userId)
    .first<{ id: string; is_read: number }>();

  if (!notification) {
    return errors.notFound(c, 'Notification');
  }

  // Already read? Just return success
  if (notification.is_read === 1) {
    return success(c, { message: 'Notification already marked as read' });
  }

  // Mark as read
  await db
    .prepare('UPDATE notifications SET is_read = 1 WHERE id = ?')
    .bind(notificationId)
    .run();

  return success(c, { message: 'Notification marked as read' });
});

/**
 * POST /notifications/read-all - Mark all notifications as read
 */
notifications.post('/read-all', async (c) => {
  const userId = c.get('userId');
  const db = c.env.DB;

  if (!userId) {
    return errors.unauthorized(c);
  }

  const result = await db
    .prepare('UPDATE notifications SET is_read = 1 WHERE user_id = ? AND is_read = 0')
    .bind(userId)
    .run();

  return success(c, {
    message: 'All notifications marked as read',
    count: result.meta.changes,
  });
});

/**
 * DELETE /notifications/:id - Delete a notification
 */
notifications.delete('/:id', async (c) => {
  const userId = c.get('userId');
  const notificationId = c.req.param('id');
  const db = c.env.DB;

  if (!userId) {
    return errors.unauthorized(c);
  }

  // Check if notification exists and belongs to user
  const notification = await db
    .prepare('SELECT id FROM notifications WHERE id = ? AND user_id = ?')
    .bind(notificationId, userId)
    .first<{ id: string }>();

  if (!notification) {
    return errors.notFound(c, 'Notification');
  }

  // Delete
  await db
    .prepare('DELETE FROM notifications WHERE id = ?')
    .bind(notificationId)
    .run();

  return success(c, { message: 'Notification deleted' });
});

/**
 * DELETE /notifications - Delete all notifications for user
 * 
 * Optionally can delete only read notifications.
 */
notifications.delete('/', zValidator('query', z.object({
  readOnly: z.coerce.boolean().optional().default(false),
})), async (c) => {
  const userId = c.get('userId');
  const { readOnly } = c.req.valid('query');
  const db = c.env.DB;

  if (!userId) {
    return errors.unauthorized(c);
  }

  let query = 'DELETE FROM notifications WHERE user_id = ?';
  if (readOnly) {
    query += ' AND is_read = 1';
  }

  const result = await db
    .prepare(query)
    .bind(userId)
    .run();

  return success(c, {
    message: readOnly ? 'Read notifications deleted' : 'All notifications deleted',
    count: result.meta.changes,
  });
});

// ============================================
// UTILITY FUNCTIONS (exported for use in other routes)
// ============================================

/**
 * Create a notification for a user
 * 
 * This is a helper function that can be called from other parts of the app.
 */
export async function createNotification(
  db: D1Database,
  userId: string,
  type: NotificationType,
  title: string,
  message: string,
  relatedEntity?: { type: string; id: string }
): Promise<string> {
  const id = crypto.randomUUID();
  const now = new Date().toISOString();

  await db
    .prepare(`
      INSERT INTO notifications (id, user_id, type, title, message, related_entity_type, related_entity_id, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    `)
    .bind(
      id,
      userId,
      type,
      title,
      message,
      relatedEntity?.type || null,
      relatedEntity?.id || null,
      now
    )
    .run();

  return id;
}

/**
 * Create a notification for streak being at risk
 */
export async function createStreakAtRiskNotification(
  db: D1Database,
  userId: string,
  currentStreak: number
): Promise<string> {
  return createNotification(
    db,
    userId,
    'streak_at_risk',
    'Streak at Risk!',
    `Your ${currentStreak}-day streak will break if you don't plank today. You have freeze tokens available!`,
  );
}

/**
 * Create a notification for streak milestone
 */
export async function createStreakMilestoneNotification(
  db: D1Database,
  userId: string,
  streakDays: number
): Promise<string> {
  const milestones = [7, 14, 30, 60, 90, 180, 365];
  
  if (!milestones.includes(streakDays)) {
    throw new Error('Not a streak milestone');
  }

  return createNotification(
    db,
    userId,
    'streak_milestone',
    `${streakDays}-Day Streak!`,
    `Congratulations! You've reached a ${streakDays}-day plank streak. Keep it going!`,
  );
}

// ============================================
// NOTIFICATION CLEANUP/RETENTION
// ============================================

/** Maximum age of notifications in days before they're eligible for cleanup */
const NOTIFICATION_RETENTION_DAYS = 90;

/** Maximum number of notifications to keep per user (oldest are deleted first) */
const NOTIFICATION_MAX_PER_USER = 500;

/** Maximum notifications to delete in a single cleanup run (to avoid timeouts) */
const CLEANUP_BATCH_SIZE = 100;

/**
 * Clean up old notifications for a user
 * 
 * Retention policy:
 * 1. Delete all read notifications older than 90 days
 * 2. Keep at most 500 notifications per user (delete oldest first)
 * 
 * This should be called:
 * - When user loads notifications (opportunistic cleanup)
 * - Via a scheduled cron job (if needed)
 * 
 * @returns Number of notifications deleted
 */
export async function cleanupOldNotifications(
  db: D1Database,
  userId: string
): Promise<number> {
  const cutoffDate = new Date();
  cutoffDate.setDate(cutoffDate.getDate() - NOTIFICATION_RETENTION_DAYS);
  const cutoffIso = cutoffDate.toISOString();

  let totalDeleted = 0;

  try {
    // Step 1: Delete old READ notifications (older than retention period)
    const oldReadResult = await db
      .prepare(`
        DELETE FROM notifications 
        WHERE user_id = ? AND is_read = 1 AND created_at < ?
      `)
      .bind(userId, cutoffIso)
      .run();

    totalDeleted += oldReadResult.meta.changes || 0;

    // Step 2: Check if user has too many notifications
    const countResult = await db
      .prepare('SELECT COUNT(*) as count FROM notifications WHERE user_id = ?')
      .bind(userId)
      .first<{ count: number }>();

    const totalCount = countResult?.count || 0;

    if (totalCount > NOTIFICATION_MAX_PER_USER) {
      // Delete oldest notifications beyond the limit (prefer deleting read ones first)
      // Strategy: Delete read notifications first (is_read=1), then oldest unread
      const toDelete = Math.min(totalCount - NOTIFICATION_MAX_PER_USER, CLEANUP_BATCH_SIZE);
      
      // First, try to delete oldest READ notifications
      // This is more efficient as it can use the idx_notifications_cleanup index
      const readDeleteResult = await db
        .prepare(`
          DELETE FROM notifications 
          WHERE user_id = ? AND is_read = 1 
          AND id IN (
            SELECT id FROM notifications 
            WHERE user_id = ? AND is_read = 1
            ORDER BY created_at ASC 
            LIMIT ?
          )
        `)
        .bind(userId, userId, toDelete)
        .run();

      let deletedFromExcess = readDeleteResult.meta.changes || 0;

      // If we still need to delete more (not enough read notifications), delete oldest unread
      if (deletedFromExcess < toDelete) {
        const remaining = toDelete - deletedFromExcess;
        const unreadDeleteResult = await db
          .prepare(`
            DELETE FROM notifications 
            WHERE user_id = ? AND is_read = 0
            AND id IN (
              SELECT id FROM notifications 
              WHERE user_id = ? AND is_read = 0
              ORDER BY created_at ASC 
              LIMIT ?
            )
          `)
          .bind(userId, userId, remaining)
          .run();
        
        deletedFromExcess += unreadDeleteResult.meta.changes || 0;
      }

      totalDeleted += deletedFromExcess;
    }

    if (totalDeleted > 0) {
      console.log(`[Notification Cleanup] Deleted ${totalDeleted} notifications for user ${userId}`);
    }

    return totalDeleted;
  } catch (error) {
    console.error('[Notification Cleanup] Error cleaning up notifications:', error);
    return 0;
  }
}

/**
 * Global cleanup for all users (for scheduled jobs)
 * 
 * This performs bulk cleanup across all users:
 * - Deletes read notifications older than retention period
 * - Logs cleanup statistics
 * 
 * Note: Does not enforce per-user limits (too expensive for bulk operation)
 */
export async function cleanupAllOldNotifications(db: D1Database): Promise<{
  deletedCount: number;
  success: boolean;
}> {
  const cutoffDate = new Date();
  cutoffDate.setDate(cutoffDate.getDate() - NOTIFICATION_RETENTION_DAYS);
  const cutoffIso = cutoffDate.toISOString();

  try {
    // Delete all old read notifications across all users
    const result = await db
      .prepare(`
        DELETE FROM notifications 
        WHERE is_read = 1 AND created_at < ?
      `)
      .bind(cutoffIso)
      .run();

    const deletedCount = result.meta.changes || 0;
    
    console.log(`[Notification Cleanup] Global cleanup deleted ${deletedCount} old notifications`);
    
    return { deletedCount, success: true };
  } catch (error) {
    console.error('[Notification Cleanup] Global cleanup failed:', error);
    return { deletedCount: 0, success: false };
  }
}

export default notifications;
