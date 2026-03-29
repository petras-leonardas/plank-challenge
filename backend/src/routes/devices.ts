import { Hono } from 'hono';
import { zValidator } from '@hono/zod-validator';
import { z } from 'zod';
import type { Env, Variables } from '../types/env';
import type { DeviceRecord } from '../types/api';
import { success, errors } from '../utils/response';
import { authMiddleware } from '../middleware/auth';

const devices = new Hono<{ Bindings: Env; Variables: Variables }>();

// Apply auth middleware to all routes
devices.use('*', authMiddleware);

// ============================================
// CONSTANTS
// ============================================

/** Maximum devices per user to prevent abuse */
const MAX_DEVICES_PER_USER = 10;

/** Valid platforms — must match the D1 CHECK constraint in schema.sql */
const VALID_PLATFORMS = ['ios', 'android', 'web'] as const;

// ============================================
// VALIDATION SCHEMAS
// ============================================

const registerDeviceSchema = z.object({
  deviceToken: z.string()
    .min(32, 'Device token must be at least 32 characters')
    .max(200, 'Device token too long')
    .regex(/^[a-fA-F0-9]+$/, 'Device token must be hexadecimal'),
  platform: z.enum(VALID_PLATFORMS),
  appVersion: z.string().max(20).optional(),
  osVersion: z.string().max(20).optional(),
  deviceModel: z.string().max(50).optional(),
});

const updateDeviceSchema = z.object({
  appVersion: z.string().max(20).optional(),
  osVersion: z.string().max(20).optional(),
  deviceModel: z.string().max(50).optional(),
});

/** UUID format validation regex */
const UUID_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

// ============================================
// HELPER FUNCTIONS
// ============================================

/**
 * Format device record for API response
 */
function formatDevice(device: DeviceRecord) {
  return {
    id: device.id,
    platform: device.platform,
    appVersion: device.app_version,
    osVersion: device.os_version,
    deviceModel: device.device_model,
    lastActiveAt: device.last_active_at,
    createdAt: device.created_at,
  };
}

/**
 * Mask device token for display (show first 8 and last 4 chars)
 */
function maskToken(token: string): string {
  if (token.length <= 16) {
    return token.substring(0, 4) + '...' + token.substring(token.length - 4);
  }
  return token.substring(0, 8) + '...' + token.substring(token.length - 4);
}

// ============================================
// ROUTES
// ============================================

/**
 * POST /devices - Register a device for push notifications
 * 
 * Registers a new device token or updates an existing one.
 * If the device token already exists for this user, it updates the metadata.
 * If the token exists for a different user, it transfers ownership (token can only belong to one user).
 * 
 * This supports:
 * - New device registration
 * - Device updates (new app version, etc.)
 * - User switching (if user B logs into device that was registered for user A)
 */
devices.post('/', zValidator('json', registerDeviceSchema), async (c) => {
  const userId = c.get('userId')!;
  const { deviceToken, platform, appVersion, osVersion, deviceModel } = c.req.valid('json');
  const db = c.env.DB;
  const now = new Date().toISOString();
  
  // Normalize token to lowercase
  const normalizedToken = deviceToken.toLowerCase();
  
  // Check if device token already exists
  const existingDevice = await db
    .prepare('SELECT * FROM devices WHERE device_token = ?')
    .bind(normalizedToken)
    .first<DeviceRecord>();
  
  if (existingDevice) {
    // Token exists - check if it's for the same user
    if (existingDevice.user_id === userId) {
      // Same user - update metadata
      await db
        .prepare(`
          UPDATE devices SET
            platform = ?,
            app_version = ?,
            os_version = ?,
            device_model = ?,
            last_active_at = ?
          WHERE id = ?
        `)
        .bind(
          platform,
          appVersion || null,
          osVersion || null,
          deviceModel || null,
          now,
          existingDevice.id
        )
        .run();
      
      const updated = await db
        .prepare('SELECT * FROM devices WHERE id = ?')
        .bind(existingDevice.id)
        .first<DeviceRecord>();
      
      return success(c, {
        device: formatDevice(updated!),
        action: 'updated',
      });
    } else {
      // Different user - transfer ownership
      // This happens when user B logs into a device that was previously registered for user A
      await db
        .prepare(`
          UPDATE devices SET
            user_id = ?,
            platform = ?,
            app_version = ?,
            os_version = ?,
            device_model = ?,
            last_active_at = ?
          WHERE id = ?
        `)
        .bind(
          userId,
          platform,
          appVersion || null,
          osVersion || null,
          deviceModel || null,
          now,
          existingDevice.id
        )
        .run();
      
      const transferred = await db
        .prepare('SELECT * FROM devices WHERE id = ?')
        .bind(existingDevice.id)
        .first<DeviceRecord>();
      
      return success(c, {
        device: formatDevice(transferred!),
        action: 'transferred',
      });
    }
  }
  
  // New device - use a transaction-like batch to handle device limit atomically
  // This prevents race conditions where multiple requests could exceed the limit
  const deviceId = crypto.randomUUID();
  
  // Use batch to ensure atomicity:
  // 1. Delete oldest devices if we're at the limit (delete excess + 1 to make room)
  // 2. Insert the new device
  // This approach handles the race condition by always making room first
  try {
    await db.batch([
      // Delete oldest devices to ensure we stay under limit after insert
      // We delete any devices beyond (MAX - 1) to make room for the new one
      db.prepare(`
        DELETE FROM devices
        WHERE user_id = ? AND id IN (
          SELECT id FROM devices
          WHERE user_id = ?
          ORDER BY last_active_at ASC
          LIMIT MAX(0, (SELECT COUNT(*) FROM devices WHERE user_id = ?) - ?)
        )
      `).bind(userId, userId, userId, MAX_DEVICES_PER_USER - 1),
      
      // Insert the new device
      db.prepare(`
        INSERT INTO devices (
          id, user_id, device_token, platform,
          app_version, os_version, device_model,
          last_active_at, created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      `).bind(
        deviceId,
        userId,
        normalizedToken,
        platform,
        appVersion || null,
        osVersion || null,
        deviceModel || null,
        now,
        now
      ),
    ]);
  } catch (error) {
    console.error('Failed to register device:', error);
    return errors.serverError(c, 'Failed to register device');
  }
  
  const newDevice = await db
    .prepare('SELECT * FROM devices WHERE id = ?')
    .bind(deviceId)
    .first<DeviceRecord>();
  
  if (!newDevice) {
    return errors.serverError(c, 'Failed to retrieve registered device');
  }
  
  return success(c, {
    device: formatDevice(newDevice),
    action: 'created',
  }, 201);
});

/**
 * GET /devices - List user's registered devices
 * 
 * Returns all devices registered for push notifications for the current user.
 */
devices.get('/', async (c) => {
  const userId = c.get('userId')!;
  const db = c.env.DB;
  
  const result = await db
    .prepare(`
      SELECT * FROM devices
      WHERE user_id = ?
      ORDER BY last_active_at DESC
    `)
    .bind(userId)
    .all<DeviceRecord>();
  
  return success(c, {
    devices: (result.results || []).map(formatDevice),
    count: result.results?.length || 0,
    limit: MAX_DEVICES_PER_USER,
  });
});

/**
 * POST /devices/ping - Update device activity
 * 
 * Simple endpoint to mark a device as active without sending a full update.
 * Useful for keeping track of which devices are still in use.
 * 
 * NOTE: This route must be defined BEFORE /:token to avoid "ping" being treated as a token
 */
devices.post('/ping', zValidator('json', z.object({
  deviceToken: z.string().min(32).max(200).regex(/^[a-fA-F0-9]+$/),
})), async (c) => {
  const userId = c.get('userId')!;
  const { deviceToken } = c.req.valid('json');
  const db = c.env.DB;
  
  const normalizedToken = deviceToken.toLowerCase();
  const now = new Date().toISOString();
  
  const result = await db
    .prepare(`
      UPDATE devices
      SET last_active_at = ?
      WHERE device_token = ? AND user_id = ?
    `)
    .bind(now, normalizedToken, userId)
    .run();
  
  if (!result.meta.changes || result.meta.changes === 0) {
    return errors.notFound(c, 'Device');
  }
  
  return success(c, {
    lastActiveAt: now,
  });
});

/**
 * DELETE /devices/all - Unregister all devices for current user
 * 
 * Useful for "logout from all devices" functionality.
 * 
 * NOTE: This route must be defined BEFORE /:token to avoid "all" being treated as a token
 */
devices.delete('/all', async (c) => {
  const userId = c.get('userId')!;
  const db = c.env.DB;
  
  const countResult = await db
    .prepare('SELECT COUNT(*) as count FROM devices WHERE user_id = ?')
    .bind(userId)
    .first<{ count: number }>();
  
  const count = countResult?.count || 0;
  
  if (count === 0) {
    return success(c, {
      message: 'No devices to unregister',
      count: 0,
    });
  }
  
  await db
    .prepare('DELETE FROM devices WHERE user_id = ?')
    .bind(userId)
    .run();
  
  return success(c, {
    message: 'All devices unregistered successfully',
    count,
  });
});

/**
 * POST /devices/unregister - Unregister a device by token
 * 
 * Removes a device from push notification registration.
 * Uses POST with body instead of DELETE with token in URL to avoid logging sensitive token.
 * 
 * NOTE: This is the preferred method. DELETE /:token is kept for backwards compatibility.
 */
devices.post('/unregister', zValidator('json', z.object({
  deviceToken: z.string().min(32).max(200).regex(/^[a-fA-F0-9]+$/),
})), async (c) => {
  const userId = c.get('userId')!;
  const { deviceToken } = c.req.valid('json');
  const db = c.env.DB;
  
  const normalizedToken = deviceToken.toLowerCase();
  
  // Find and delete device (must belong to user)
  const device = await db
    .prepare('SELECT id FROM devices WHERE device_token = ? AND user_id = ?')
    .bind(normalizedToken, userId)
    .first<{ id: string }>();
  
  if (!device) {
    return errors.notFound(c, 'Device');
  }
  
  await db
    .prepare('DELETE FROM devices WHERE id = ?')
    .bind(device.id)
    .run();
  
  return success(c, {
    message: 'Device unregistered successfully',
    maskedToken: maskToken(normalizedToken),
  });
});

/**
 * DELETE /devices/:token - Unregister device (DEPRECATED)
 * 
 * DEPRECATED: Use POST /devices/unregister with token in body instead.
 * This endpoint exposes the device token in the URL, which gets logged.
 * 
 * NOTE: This route must be defined AFTER specific routes (/ping, /all, /unregister)
 * to avoid those paths being matched as :token
 */
devices.delete('/:token', async (c) => {
  // SECURITY: Log deprecation warning for monitoring
  console.warn(`[Devices] DEPRECATED endpoint used: DELETE /devices/:token by user ${c.get('userId')}`);
  
  // Add deprecation header to response
  c.header('Deprecation', 'true');
  c.header('Sunset', 'Sat, 01 Jun 2026 00:00:00 GMT');
  c.header('Link', '</devices/unregister>; rel="successor-version"');
  
  const userId = c.get('userId')!;
  const token = c.req.param('token')!;
  const db = c.env.DB;
  
  // Validate token format (should be hex string, 32-200 chars)
  if (!/^[a-fA-F0-9]{32,200}$/.test(token)) {
    return errors.validation(c, 'Invalid device token format');
  }
  
  const normalizedToken = token.toLowerCase();
  
  // Find and delete device (must belong to user)
  const device = await db
    .prepare('SELECT id FROM devices WHERE device_token = ? AND user_id = ?')
    .bind(normalizedToken, userId)
    .first<{ id: string }>();
  
  if (!device) {
    return errors.notFound(c, 'Device');
  }
  
  await db
    .prepare('DELETE FROM devices WHERE id = ?')
    .bind(device.id)
    .run();
  
  return success(c, {
    message: 'Device unregistered successfully',
    maskedToken: maskToken(normalizedToken),
  });
});

/**
 * DELETE /devices/:token - Unregister a device by token (DEPRECATED)
 * 
 * DEPRECATED: Use POST /devices/unregister instead.
 * This endpoint puts the token in the URL which may be logged.
 * Kept for backwards compatibility.
 * 
 * NOTE: This route must be defined AFTER specific routes (/ping, /all, /unregister)
 * to avoid those paths being matched as :token
 */
devices.delete('/:token', async (c) => {
  const userId = c.get('userId')!;
  const token = c.req.param('token')!;
  const db = c.env.DB;
  
  // Normalize token
  const normalizedToken = token.toLowerCase();
  
  // Find and delete device (must belong to user)
  const device = await db
    .prepare('SELECT id FROM devices WHERE device_token = ? AND user_id = ?')
    .bind(normalizedToken, userId)
    .first<{ id: string }>();
  
  if (!device) {
    return errors.notFound(c, 'Device');
  }
  
  await db
    .prepare('DELETE FROM devices WHERE id = ?')
    .bind(device.id)
    .run();
  
  return success(c, {
    message: 'Device unregistered successfully',
    maskedToken: maskToken(normalizedToken),
  });
});

export default devices;
