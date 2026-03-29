import { Hono } from 'hono';
import { zValidator } from '@hono/zod-validator';
import { z } from 'zod';
import type { Env, Variables } from '../types/env';
import type { GroupRecord, GroupMemberRecord, UserRecord, JoinRequestRecord } from '../types/api';
import { success, errors } from '../utils/response';
import { authMiddleware, optionalAuthMiddleware } from '../middleware/auth';
import { sendSilentPush } from '../utils/push';

const groups = new Hono<{ Bindings: Env; Variables: Variables }>();

// ============================================
// CONSTANTS
// ============================================

const MAX_GROUP_MEMBERS = 100;
const INVITE_CODE_LENGTH = 8;

// ============================================
// HELPER FUNCTIONS
// ============================================

/**
 * Escape special characters in LIKE patterns to prevent unexpected matching.
 * Characters % and _ have special meaning in SQL LIKE clauses.
 */
function escapeLikePattern(input: string): string {
  return input.replace(/[%_\\]/g, '\\$&');
}

// ============================================
// VALIDATION SCHEMAS
// ============================================

const createGroupSchema = z.object({
  name: z.string()
    .min(1)
    .max(50)
    .transform(s => s.trim())
    .refine(s => s.length >= 1, { message: 'Group name cannot be empty or whitespace only' }),
  description: z.string()
    .max(500)
    .transform(s => s.trim())
    .optional()
    .nullable(),
  groupType: z.enum(['public', 'private']),
  joinMode: z.enum(['open', 'request']),
});

const updateGroupSchema = z.object({
  name: z.string()
    .min(1)
    .max(50)
    .transform(s => s.trim())
    .refine(s => s.length >= 1, { message: 'Group name cannot be empty or whitespace only' })
    .optional(),
  description: z.string()
    .max(500)
    .transform(s => s.trim())
    .optional()
    .nullable(),
  joinMode: z.enum(['open', 'request']).optional(),
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
    if (!Number.isNaN(parsed) && parsed > 0 && Number.isInteger(parsed)) {
      limit = Math.min(parsed, maxLimit);
    }
  }
  
  // Parse offset with validation
  let offset = 0;
  if (offsetParam !== undefined) {
    const parsed = parseInt(offsetParam, 10);
    if (!Number.isNaN(parsed) && parsed >= 0 && Number.isInteger(parsed)) {
      offset = Math.min(parsed, 100000); // Cap at 100k to prevent abuse
    }
  }
  
  return { limit, offset };
}

/**
 * Generate a random invite code (8 alphanumeric characters)
 */
function generateInviteCode(): string {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // Exclude confusing chars like 0, O, 1, I
  let code = '';
  for (let i = 0; i < INVITE_CODE_LENGTH; i++) {
    code += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return code;
}



/**
 * Format a group record for API response
 */
function formatGroup(group: GroupRecord & { member_preview_urls?: string | null }, options?: { 
  isMember?: boolean;
  role?: string;
  pendingRequest?: boolean;
}) {
  return {
    id: group.id,
    name: group.name,
    description: group.description,
    imageUrl: group.image_url,
    groupType: group.group_type,
    joinMode: group.join_mode,
    createdBy: group.created_by,
    memberCount: group.member_count || 0,
    inviteCode: group.invite_code, // Only returned to admins
    createdAt: group.created_at,
    updatedAt: group.updated_at,
    memberPreviews: group.member_preview_urls
      ? group.member_preview_urls.split(',').filter(Boolean)
      : [],
    ...(options?.isMember !== undefined && { isMember: options.isMember }),
    ...(options?.role !== undefined && { role: options.role }),
    ...(options?.pendingRequest !== undefined && { pendingRequest: options.pendingRequest }),
  };
}

/**
 * Format a group for public listing (hides invite code)
 */
function formatPublicGroup(group: GroupRecord, options?: {
  isMember?: boolean;
  pendingRequest?: boolean;
}) {
  const formatted = formatGroup(group, options);
  // Remove invite code for public listings
  const { inviteCode, ...publicFields } = formatted;
  return publicFields;
}

/**
 * Format a group member for API response
 */
function formatGroupMember(
  member: GroupMemberRecord & Partial<UserRecord>
) {
  return {
    id: member.id,
    userId: member.user_id,
    role: member.role,
    joinedAt: member.joined_at,
    // User details if joined
    user: member.display_name ? {
      id: member.user_id,
      displayName: member.display_name,
      username: member.username || null,
      profileImageUrl: member.profile_image_url || null,
      currentStreak: member.current_streak || 0,
    } : undefined,
  };
}

/**
 * Format a join request for API response
 */
function formatJoinRequest(
  request: JoinRequestRecord & Partial<UserRecord>
) {
  return {
    id: request.id,
    userId: request.user_id,
    status: request.status,
    createdAt: request.created_at,
    reviewedAt: request.reviewed_at,
    // User details if joined
    user: request.display_name ? {
      id: request.user_id,
      displayName: request.display_name,
      username: request.username || null,
      profileImageUrl: request.profile_image_url || null,
      currentStreak: request.current_streak || 0,
    } : undefined,
  };
}

/**
 * Check if user is a member of the group and return their membership
 */
async function getMembership(
  db: D1Database,
  groupId: string,
  userId: string
): Promise<GroupMemberRecord | null> {
  return db
    .prepare(`
      SELECT * FROM group_members 
      WHERE group_id = ? AND user_id = ? AND status = 'active'
    `)
    .bind(groupId, userId)
    .first<GroupMemberRecord>();
}

/**
 * Check if user is an admin of the group
 */
async function isGroupAdmin(
  db: D1Database,
  groupId: string,
  userId: string
): Promise<boolean> {
  const membership = await getMembership(db, groupId, userId);
  // 'owner' is the group creator; 'admin' is a promoted member.
  // Both have admin-level access for group management operations.
  return membership?.role === 'admin' || membership?.role === 'owner';
}

/**
 * Create a notification for a user.
 *
 * @param extraRefreshTypes  Additional refreshType values to include alongside
 *                           "notifications" in the silent push payload. Use this
 *                           when the triggering event also requires the recipient
 *                           to refresh other data (e.g. group approval → also
 *                           refresh "groups").
 */
async function createNotification(
  db: D1Database,
  userId: string,
  type: string,
  title: string,
  message: string,
  relatedEntityType?: string,
  relatedEntityId?: string,
  actorImageUrl?: string,
  env?: Env,
  extraRefreshTypes: string[] = [],
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
      userId,
      type,
      title,
      message,
      relatedEntityType || null,
      relatedEntityId || null,
      actorImageUrl || null,
      now
    )
    .run();

  // Fire silent push, merging any extra refresh types with the default "notifications"
  if (env) {
    const refreshTypes = ['notifications', ...extraRefreshTypes];
    sendSilentPush(env, userId, refreshTypes).catch(() => {});
  }
}

/**
 * Create notifications for multiple users in a single batch.
 *
 * @param extraRefreshTypes  Additional refreshType values to include alongside
 *                           "notifications" in every recipient's silent push.
 */
async function createNotificationBatch(
  db: D1Database,
  userIds: string[],
  type: string,
  title: string,
  message: string,
  relatedEntityType?: string,
  relatedEntityId?: string,
  actorImageUrl?: string,
  env?: Env,
  extraRefreshTypes: string[] = [],
): Promise<void> {
  if (userIds.length === 0) return;
  
  const now = new Date().toISOString();
  
  const statements = userIds.map(userId => 
    db
      .prepare(`
        INSERT INTO notifications (id, user_id, type, title, message, related_entity_type, related_entity_id, actor_image_url, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      `)
      .bind(
        crypto.randomUUID(),
        userId,
        type,
        title,
        message,
        relatedEntityType || null,
        relatedEntityId || null,
        actorImageUrl || null,
        now
      )
  );
  
  // D1 batch has a limit, so chunk if needed (batch supports up to 100 statements)
  const BATCH_SIZE = 100;
  for (let i = 0; i < statements.length; i += BATCH_SIZE) {
    const chunk = statements.slice(i, i + BATCH_SIZE);
    await db.batch(chunk);
  }

  // Fire silent pushes to all recipients, merging any extra refresh types
  if (env) {
    const refreshTypes = ['notifications', ...extraRefreshTypes];
    userIds.forEach(userId => sendSilentPush(env, userId, refreshTypes).catch(() => {}));
  }
}

// ============================================
// ROUTES - Group CRUD
// ============================================

/**
 * POST /groups - Create a new group
 */
groups.post('/', authMiddleware, zValidator('json', createGroupSchema), async (c) => {
  const userId = c.get('userId')!;
  const body = c.req.valid('json');
  
  const groupId = crypto.randomUUID();
  const memberId = crypto.randomUUID();
  const now = new Date().toISOString();
  
  // Generate invite code for private groups
  let inviteCode: string | null = null;
  if (body.groupType === 'private') {
    // Ensure invite code is unique
    // With 8 chars from 32-char alphabet = 32^8 = ~1 trillion combinations
    // Collisions are extremely rare, but we handle them gracefully
    const MAX_ATTEMPTS = 10;
    let attempts = 0;
    
    while (attempts < MAX_ATTEMPTS) {
      inviteCode = generateInviteCode();
      const existing = await c.env.DB
        .prepare('SELECT id FROM groups WHERE invite_code = ?')
        .bind(inviteCode)
        .first();
      if (!existing) break;
      attempts++;
      
      // Log if we're seeing repeated collisions (could indicate a problem)
      if (attempts >= 3) {
        console.warn(`[Groups] Invite code collision on attempt ${attempts}: ${inviteCode}`);
      }
    }
    
    if (attempts >= MAX_ATTEMPTS) {
      console.error('[Groups] Failed to generate unique invite code after max attempts');
      return errors.serverError(c, 'Failed to generate unique invite code. Please try again.');
    }
  }
  
  // Create group and add creator as admin in a batch
  try {
    await c.env.DB.batch([
      c.env.DB
        .prepare(`
          INSERT INTO groups (id, name, description, group_type, join_mode, created_by, member_count, invite_code, created_at, updated_at)
          VALUES (?, ?, ?, ?, ?, ?, 1, ?, ?, ?)
        `)
        .bind(
          groupId,
          body.name,
          body.description || null,
          body.groupType,
          body.joinMode,
          userId,
          inviteCode,
          now,
          now
        ),
      c.env.DB
        .prepare(`
          INSERT INTO group_members (id, group_id, user_id, role, status, joined_at, updated_at)
          VALUES (?, ?, ?, 'owner', 'active', ?, ?)
        `)
        .bind(memberId, groupId, userId, now, now),
    ]);
  } catch (error) {
    console.error('Failed to create group:', error);
    return errors.serverError(c, 'Failed to create group');
  }
  
  // Fetch created group
  const group = await c.env.DB
    .prepare('SELECT * FROM groups WHERE id = ?')
    .bind(groupId)
    .first<GroupRecord>();
  
  if (!group) {
    return errors.serverError(c, 'Failed to retrieve created group');
  }

  // Push a "groups" refresh to the creator's other devices so the new group
  // appears immediately without requiring a pull-to-refresh.
  sendSilentPush(c.env, userId, ['groups']).catch(() => {});
  
  return success(c, formatGroup(group, { isMember: true, role: 'owner' }), 201);
});

/**
 * GET /groups - List current user's groups
 */
groups.get('/', authMiddleware, async (c) => {
  const userId = c.get('userId')!;
  const { limit, offset } = parsePagination(c.req.query('limit'), c.req.query('offset'));
  
  const results = await c.env.DB
    .prepare(`
      SELECT g.*, gm.role,
        (
          SELECT GROUP_CONCAT(u.profile_image_url)
          FROM (
            SELECT u.profile_image_url
            FROM group_members gm2
            INNER JOIN users u ON u.id = gm2.user_id
            WHERE gm2.group_id = g.id AND gm2.status = 'active'
              AND u.profile_image_url IS NOT NULL
            ORDER BY gm2.joined_at DESC
            LIMIT 4
          ) u
        ) as member_preview_urls
      FROM groups g
      INNER JOIN group_members gm ON g.id = gm.group_id
      WHERE gm.user_id = ? AND gm.status = 'active' AND g.deleted_at IS NULL
      ORDER BY gm.joined_at DESC
      LIMIT ? OFFSET ?
    `)
    .bind(userId, limit, offset)
    .all<GroupRecord & { role: string; member_preview_urls?: string | null }>();
  
  const groupsList = (results.results || []).map(group => {
    // Owners and admins see the full group (including invite code); members see the public shape
    if (group.role === 'owner' || group.role === 'admin') {
      return formatGroup(group, { isMember: true, role: group.role });
    } else {
      return formatPublicGroup(group, { isMember: true });
    }
  });
  
  return success(c, {
    groups: groupsList,
    pagination: {
      limit,
      offset,
      hasMore: groupsList.length === limit,
    },
  });
});

/**
 * GET /groups/discover - Discover public groups
 * NOTE: Must be defined before /:id route
 */
groups.get('/discover', authMiddleware, async (c) => {
  const userId = c.get('userId')!;
  const { limit, offset } = parsePagination(c.req.query('limit'), c.req.query('offset'));
  const search = c.req.query('q');
  
  // Query includes check for banned status to hide groups user is banned from
  let query = `
    SELECT g.*,
      CASE WHEN gm.id IS NOT NULL AND gm.status = 'active' THEN 1 ELSE 0 END as is_member,
      CASE WHEN jr.id IS NOT NULL AND jr.status = 'pending' THEN 1 ELSE 0 END as has_pending_request,
      CASE WHEN gm_banned.id IS NOT NULL THEN 1 ELSE 0 END as is_banned,
      (
        SELECT GROUP_CONCAT(u.profile_image_url)
        FROM (
          SELECT u.profile_image_url
          FROM group_members gm2
          INNER JOIN users u ON u.id = gm2.user_id
          WHERE gm2.group_id = g.id AND gm2.status = 'active'
            AND u.profile_image_url IS NOT NULL
          ORDER BY gm2.joined_at DESC
          LIMIT 4
        ) u
      ) as member_preview_urls
    FROM groups g
    LEFT JOIN group_members gm ON g.id = gm.group_id AND gm.user_id = ? AND gm.status = 'active'
    LEFT JOIN group_members gm_banned ON g.id = gm_banned.group_id AND gm_banned.user_id = ? AND gm_banned.status = 'banned'
    LEFT JOIN join_requests jr ON g.id = jr.group_id AND jr.user_id = ?
    WHERE g.group_type = 'public' AND g.deleted_at IS NULL
      AND gm.id IS NULL
      AND gm_banned.id IS NULL
  `;
  
  const params: (string | number)[] = [userId, userId, userId];
  
  if (search && search.length >= 2) {
    const escapedSearch = escapeLikePattern(search);
    query += ` AND (g.name LIKE ? ESCAPE '\\' OR g.description LIKE ? ESCAPE '\\')`;
    params.push(`%${escapedSearch}%`, `%${escapedSearch}%`);
  }
  
  query += ` ORDER BY g.member_count DESC, g.created_at DESC LIMIT ? OFFSET ?`;
  params.push(limit, offset);
  
  const results = await c.env.DB
    .prepare(query)
    .bind(...params)
    .all<GroupRecord & { is_member: number; has_pending_request: number; member_preview_urls?: string | null }>();
  
  const groupsList = (results.results || []).map(group => 
    formatPublicGroup(group, { 
      isMember: group.is_member === 1,
      pendingRequest: group.has_pending_request === 1,
    })
  );
  
  return success(c, {
    groups: groupsList,
    pagination: {
      limit,
      offset,
      hasMore: groupsList.length === limit,
    },
  });
});

/**
 * GET /groups/:id - Get group details
 */
groups.get('/:id', optionalAuthMiddleware, async (c) => {
  const groupId = c.req.param('id')!;
  const userId = c.get('userId');
  
  const group = await c.env.DB
    .prepare('SELECT * FROM groups WHERE id = ? AND deleted_at IS NULL')
    .bind(groupId)
    .first<GroupRecord>();
  
  if (!group) {
    return errors.notFound(c, 'Group');
  }
  
  // Check membership and pending request status
  let isMember = false;
  let role: string | undefined;
  let pendingRequest = false;
  
  if (userId) {
    const [membershipResult, requestResult] = await c.env.DB.batch([
      c.env.DB
        .prepare(`SELECT role FROM group_members WHERE group_id = ? AND user_id = ? AND status = 'active'`)
        .bind(groupId, userId),
      c.env.DB
        .prepare(`SELECT id FROM join_requests WHERE group_id = ? AND user_id = ? AND status = 'pending'`)
        .bind(groupId, userId),
    ]);
    
    const membership = membershipResult.results?.[0] as { role: string } | undefined;
    if (membership) {
      isMember = true;
      role = membership.role;
    }
    
    pendingRequest = (requestResult.results?.length || 0) > 0;
  }
  
  // Owner and admin get the full response including invite code and role.
  // Regular members and non-members get the public response (no invite code, no role).
  if (role === 'owner' || role === 'admin') {
    return success(c, formatGroup(group, { isMember, role, pendingRequest }));
  } else {
    return success(c, formatPublicGroup(group, { isMember, pendingRequest }));
  }
});

/**
 * PATCH /groups/:id - Update group (admin only)
 */
groups.patch('/:id', authMiddleware, zValidator('json', updateGroupSchema), async (c) => {
  const groupId = c.req.param('id')!;
  const userId = c.get('userId')!;
  const updates = c.req.valid('json');
  
  // Check if user is admin
  if (!await isGroupAdmin(c.env.DB, groupId, userId)) {
    return errors.forbidden(c, 'Only group admins can update the group');
  }
  
  // Verify group exists
  const group = await c.env.DB
    .prepare('SELECT * FROM groups WHERE id = ? AND deleted_at IS NULL')
    .bind(groupId)
    .first<GroupRecord>();
  
  if (!group) {
    return errors.notFound(c, 'Group');
  }
  
  // Build update query dynamically
  const fields: string[] = [];
  const values: unknown[] = [];
  
  if (updates.name !== undefined) {
    fields.push('name = ?');
    values.push(updates.name);
  }
  
  if (updates.description !== undefined) {
    fields.push('description = ?');
    values.push(updates.description);
  }
  
  if (updates.joinMode !== undefined) {
    fields.push('join_mode = ?');
    values.push(updates.joinMode);
  }
  
  if (fields.length === 0) {
    return errors.validation(c, 'No fields to update');
  }
  
  // Add updated_at
  fields.push('updated_at = ?');
  values.push(new Date().toISOString());
  
  // Add groupId for WHERE clause
  values.push(groupId);
  
  await c.env.DB
    .prepare(`UPDATE groups SET ${fields.join(', ')} WHERE id = ?`)
    .bind(...values)
    .run();
  
  // Fetch updated group
  const updatedGroup = await c.env.DB
    .prepare('SELECT * FROM groups WHERE id = ?')
    .bind(groupId)
    .first<GroupRecord>();
  
  return success(c, formatGroup(updatedGroup!, { isMember: true, role: 'admin' }));
});

/**
 * DELETE /groups/:id - Delete group (admin only, creator preferred)
 */
groups.delete('/:id', authMiddleware, async (c) => {
  const groupId = c.req.param('id')!;
  const userId = c.get('userId')!;
  
  const group = await c.env.DB
    .prepare('SELECT * FROM groups WHERE id = ? AND deleted_at IS NULL')
    .bind(groupId)
    .first<GroupRecord>();
  
  if (!group) {
    return errors.notFound(c, 'Group');
  }
  
  // Only the creator can delete the group
  if (group.created_by !== userId) {
    return errors.forbidden(c, 'Only the group creator can delete the group');
  }
  
  // Fetch all active member IDs before soft-deleting so we can notify them.
  // Exclude the creator — they initiated the deletion and their own list will
  // update from the optimistic in-memory removal on iOS.
  const membersResult = await c.env.DB
    .prepare(`SELECT user_id FROM group_members WHERE group_id = ? AND status = 'active' AND user_id != ?`)
    .bind(groupId, userId)
    .all<{ user_id: string }>();
  const memberIds = (membersResult.results || []).map(r => r.user_id);

  // Soft delete the group
  const now = new Date().toISOString();
  await c.env.DB
    .prepare('UPDATE groups SET deleted_at = ?, updated_at = ? WHERE id = ?')
    .bind(now, now, groupId)
    .run();

  // Push a "groups" refresh to all other members so the deleted group
  // disappears from their list immediately without requiring a pull-to-refresh.
  if (memberIds.length > 0) {
    memberIds.forEach(memberId => sendSilentPush(c.env, memberId, ['groups']).catch(() => {}));
  }
  
  return success(c, { deleted: true });
});

// ============================================
// ROUTES - Membership
// ============================================

/**
 * POST /groups/:id/join - Join a group or request to join
 */
groups.post('/:id/join', authMiddleware, async (c) => {
  const groupId = c.req.param('id')!;
  const userId = c.get('userId')!;
  
  const group = await c.env.DB
    .prepare('SELECT * FROM groups WHERE id = ? AND deleted_at IS NULL')
    .bind(groupId)
    .first<GroupRecord>();
  
  if (!group) {
    return errors.notFound(c, 'Group');
  }
  
  // Check if already a member or banned
  const existingMembership = await c.env.DB
    .prepare(`SELECT id, status FROM group_members WHERE group_id = ? AND user_id = ?`)
    .bind(groupId, userId)
    .first<{ id: string; status: string }>();
  
  if (existingMembership?.status === 'active') {
    return errors.alreadyMember(c);
  }
  
  // If user was banned, don't allow rejoining
  if (existingMembership?.status === 'banned') {
    return errors.forbidden(c, 'You cannot join this group');
  }
  
  // Check if group is full
  if (group.member_count >= MAX_GROUP_MEMBERS) {
    return errors.groupFull(c);
  }
  
  // For private groups, user must use invite code
  if (group.group_type === 'private') {
    return errors.forbidden(c, 'This is a private group. Use an invite code to join.');
  }
  
  const now = new Date().toISOString();
  
  // Handle based on join mode
  if (group.join_mode === 'open') {
    // Directly join the group
    // SECURITY: Uses ON CONFLICT to handle race conditions atomically
    // If two requests come in simultaneously, both succeed but member_count is only incremented once
    const memberId = crypto.randomUUID();
    
    // Only increment member count if this is a new membership (not a rejoin)
    // existingMembership check above tells us if there's ANY record (active, banned, etc.)
    // If existingMembership is null, this is a brand new member
    const isNewMember = !existingMembership;
    
    try {
      const batchOps = [
        c.env.DB
          .prepare(`
            INSERT INTO group_members (id, group_id, user_id, role, status, joined_at, updated_at)
            VALUES (?, ?, ?, 'member', 'active', ?, ?)
            ON CONFLICT(group_id, user_id) DO UPDATE SET 
              status = 'active', 
              role = 'member',
              joined_at = ?,
              updated_at = ?
          `)
          .bind(memberId, groupId, userId, now, now, now, now),
      ];
      
      // Only increment count for truly new members
      if (isNewMember) {
        batchOps.push(
          c.env.DB
            .prepare('UPDATE groups SET member_count = member_count + 1, updated_at = ? WHERE id = ?')
            .bind(now, groupId)
        );
      }
      
      await c.env.DB.batch(batchOps);
    } catch (error) {
      console.error('Failed to join group:', error);
      return errors.serverError(c, 'Failed to join group');
    }
    
    // Notify all admins/owner that a new member joined
    try {
      const joiner = await c.env.DB
        .prepare('SELECT display_name, profile_image_url FROM users WHERE id = ?')
        .bind(userId)
        .first<{ display_name: string; profile_image_url: string | null }>();

      const admins = await c.env.DB
        .prepare(`SELECT user_id FROM group_members WHERE group_id = ? AND role IN ('owner', 'admin') AND status = 'active' AND user_id != ?`)
        .bind(groupId, userId)
        .all<{ user_id: string }>();

      const adminIds = (admins.results || []).map(a => a.user_id);
      if (adminIds.length > 0) {
        const joinerName = joiner?.display_name || 'Someone';
        await createNotificationBatch(
          c.env.DB,
          adminIds,
          'group_joined',
          'New Member',
          `${joinerName} joined ${group.name}`,
          'user',
          userId,
          joiner?.profile_image_url ?? undefined,
          c.env,
          ['groups'],
        );
      }
    } catch (err) {
      console.error('Failed to notify admins of new member:', err);
    }

    // Push a "groups" refresh to the joiner's other devices so the new group
    // appears in their list immediately without a pull-to-refresh.
    sendSilentPush(c.env, userId, ['groups']).catch(() => {});

    return success(c, { 
      joined: true, 
      status: 'active',
      message: 'Successfully joined the group',
    }, 201);
  } else {
    // Create a join request
    // Check if there's already a pending request
    const existingRequest = await c.env.DB
      .prepare(`SELECT id, status FROM join_requests WHERE group_id = ? AND user_id = ?`)
      .bind(groupId, userId)
      .first<{ id: string; status: string }>();
    
    if (existingRequest?.status === 'pending') {
      return errors.conflict(c, 'You already have a pending join request');
    }
    
    const requestId = crypto.randomUUID();
    
    await c.env.DB
      .prepare(`
        INSERT INTO join_requests (id, group_id, user_id, status, created_at)
        VALUES (?, ?, ?, 'pending', ?)
        ON CONFLICT(group_id, user_id) DO UPDATE SET id = excluded.id, status = 'pending', created_at = excluded.created_at
      `)
      .bind(requestId, groupId, userId, now)
      .run();
    
    // Notify group admins and owner (using batch for efficiency)
    const admins = await c.env.DB
      .prepare(`SELECT user_id FROM group_members WHERE group_id = ? AND role IN ('owner', 'admin') AND status = 'active'`)
      .bind(groupId)
      .all<{ user_id: string }>();
    
    const requester = await c.env.DB
      .prepare('SELECT display_name, profile_image_url FROM users WHERE id = ?')
      .bind(userId)
      .first<{ display_name: string; profile_image_url: string | null }>();
    
    const requesterName = requester?.display_name || 'Someone';
    const adminIds = (admins.results || []).map(a => a.user_id);
    
    try {
      await createNotificationBatch(
        c.env.DB,
        adminIds,
        'group_join_request',
        requesterName,
        `wants to join ${group.name}`,
        'join_request',
        `${groupId}:${requestId}`,   // "groupId:requestId" — split on ':' in iOS
        requester?.profile_image_url ?? undefined,
        c.env,
        ['groups'],
      );
    } catch (err) {
      console.error('Failed to notify admins:', err);
    }
    
    return success(c, { 
      joined: false, 
      status: 'pending',
      message: 'Join request submitted. Waiting for admin approval.',
    }, 202);
  }
});

/**
 * POST /groups/:id/leave - Leave a group
 */
groups.post('/:id/leave', authMiddleware, async (c) => {
  const groupId = c.req.param('id')!;
  const userId = c.get('userId')!;
  
  const group = await c.env.DB
    .prepare('SELECT * FROM groups WHERE id = ? AND deleted_at IS NULL')
    .bind(groupId)
    .first<GroupRecord>();
  
  if (!group) {
    return errors.notFound(c, 'Group');
  }
  
  const membership = await getMembership(c.env.DB, groupId, userId);
  
  if (!membership) {
    return errors.validation(c, 'You are not a member of this group');
  }
  
  // Creator cannot leave (they must delete the group)
  if (group.created_by === userId) {
    return errors.forbidden(c, 'The group creator cannot leave. Delete the group instead.');
  }
  
  const now = new Date().toISOString();
  
  try {
    await c.env.DB.batch([
      c.env.DB
        .prepare('DELETE FROM group_members WHERE group_id = ? AND user_id = ?')
        .bind(groupId, userId),
      c.env.DB
        .prepare('UPDATE groups SET member_count = MAX(0, member_count - 1), updated_at = ? WHERE id = ?')
        .bind(now, groupId),
    ]);
  } catch (error) {
    console.error('Failed to leave group:', error);
    return errors.serverError(c, 'Failed to leave group');
  }

  // Push a "groups" refresh to the user's other devices so the group
  // disappears from their list immediately without a pull-to-refresh.
  sendSilentPush(c.env, userId, ['groups']).catch(() => {});
  
  return success(c, { left: true });
});

/**
 * GET /groups/:id/members - List group members
 */
groups.get('/:id/members', optionalAuthMiddleware, async (c) => {
  const groupId = c.req.param('id')!;
  const { limit, offset } = parsePagination(c.req.query('limit'), c.req.query('offset'));
  
  const group = await c.env.DB
    .prepare('SELECT id, group_type FROM groups WHERE id = ? AND deleted_at IS NULL')
    .bind(groupId)
    .first<{ id: string; group_type: string }>();
  
  if (!group) {
    return errors.notFound(c, 'Group');
  }
  
  // For private groups, only members can see the member list
  const userId = c.get('userId');
  if (group.group_type === 'private') {
    if (!userId) {
      return errors.forbidden(c, 'You must be logged in to view members of a private group');
    }
    const membership = await getMembership(c.env.DB, groupId, userId);
    if (!membership) {
      return errors.forbidden(c, 'Only members can view the member list of a private group');
    }
  }
  
  const results = await c.env.DB
    .prepare(`
      SELECT gm.*, u.display_name, u.username, u.profile_image_url, u.current_streak
      FROM group_members gm
      INNER JOIN users u ON gm.user_id = u.id
      WHERE gm.group_id = ? AND gm.status = 'active' AND u.deleted_at IS NULL
      ORDER BY 
        CASE gm.role WHEN 'admin' THEN 0 ELSE 1 END,
        gm.joined_at ASC
      LIMIT ? OFFSET ?
    `)
    .bind(groupId, limit, offset)
    .all<GroupMemberRecord & Pick<UserRecord, 'display_name' | 'username' | 'profile_image_url' | 'current_streak'>>();
  
  const members = (results.results || []).map(member => formatGroupMember(member));
  
  return success(c, {
    members,
    pagination: {
      limit,
      offset,
      hasMore: members.length === limit,
    },
  });
});

// ============================================
// ROUTES - Admin Functions
// ============================================

/**
 * POST /groups/:id/members/:userId/promote - Promote member to admin
 */
groups.post('/:id/members/:userId/promote', authMiddleware, async (c) => {
  const groupId = c.req.param('id')!;
  const targetUserId = c.req.param('userId')!;
  const currentUserId = c.get('userId')!;
  
  // Check if current user is admin
  if (!await isGroupAdmin(c.env.DB, groupId, currentUserId)) {
    return errors.forbidden(c, 'Only group admins can promote members');
  }
  
  // Check if target is a member
  const targetMembership = await getMembership(c.env.DB, groupId, targetUserId);
  if (!targetMembership) {
    return errors.notFound(c, 'Member');
  }
  
  if (targetMembership.role === 'admin') {
    return errors.conflict(c, 'User is already an admin');
  }
  
  const now = new Date().toISOString();
  await c.env.DB
    .prepare('UPDATE group_members SET role = ?, updated_at = ? WHERE group_id = ? AND user_id = ?')
    .bind('admin', now, groupId, targetUserId)
    .run();
  
  // Notify the promoted user — include "groups" refresh so their device
  // immediately re-fetches the group list and gains the invite code and
  // admin role that the GET /groups response now returns for admins.
  const group = await c.env.DB
    .prepare('SELECT name FROM groups WHERE id = ?')
    .bind(groupId)
    .first<{ name: string }>();
  
  try {
    await createNotification(
      c.env.DB,
      targetUserId,
      'group_promoted',
      'Promoted to Admin',
      `You are now an admin of ${group?.name || 'the group'}`,
      'group',
      groupId,
      undefined,
      c.env,
      ['groups'],
    );
  } catch (err) {
    console.error('Failed to notify promoted user:', err);
  }
  
  return success(c, { promoted: true, role: 'admin' });
});

/**
 * POST /groups/:id/members/:userId/demote - Demote admin to member
 */
groups.post('/:id/members/:userId/demote', authMiddleware, async (c) => {
  const groupId = c.req.param('id')!;
  const targetUserId = c.req.param('userId')!;
  const currentUserId = c.get('userId')!;
  
  // Check if current user is admin
  if (!await isGroupAdmin(c.env.DB, groupId, currentUserId)) {
    return errors.forbidden(c, 'Only group admins can demote members');
  }
  
  // Cannot demote the group creator
  const group = await c.env.DB
    .prepare('SELECT created_by FROM groups WHERE id = ? AND deleted_at IS NULL')
    .bind(groupId)
    .first<{ created_by: string }>();
  
  if (!group) {
    return errors.notFound(c, 'Group');
  }
  
  if (targetUserId === group.created_by) {
    return errors.forbidden(c, 'Cannot demote the group creator');
  }
  
  // Check if target is an admin
  const targetMembership = await getMembership(c.env.DB, groupId, targetUserId);
  if (!targetMembership) {
    return errors.notFound(c, 'Member');
  }
  
  if (targetMembership.role !== 'admin') {
    return errors.validation(c, 'User is not an admin');
  }
  
  const now = new Date().toISOString();
  await c.env.DB
    .prepare('UPDATE group_members SET role = ?, updated_at = ? WHERE group_id = ? AND user_id = ?')
    .bind('member', now, groupId, targetUserId)
    .run();

  // Push a "groups" refresh to the demoted user's devices so their invite
  // code and admin controls disappear immediately rather than waiting for
  // the next foreground safety net. Symmetric with the promote flow.
  sendSilentPush(c.env, targetUserId, ['groups']).catch(() => {});
  
  return success(c, { demoted: true, role: 'member' });
});

/**
 * DELETE /groups/:id/members/:userId - Remove member from group
 */
groups.delete('/:id/members/:userId', authMiddleware, async (c) => {
  const groupId = c.req.param('id')!;
  const targetUserId = c.req.param('userId')!;
  const currentUserId = c.get('userId')!;
  
  // Check if current user is admin
  if (!await isGroupAdmin(c.env.DB, groupId, currentUserId)) {
    return errors.forbidden(c, 'Only group admins can remove members');
  }
  
  // Cannot remove the group creator
  const group = await c.env.DB
    .prepare('SELECT created_by, name FROM groups WHERE id = ? AND deleted_at IS NULL')
    .bind(groupId)
    .first<{ created_by: string; name: string }>();
  
  if (!group) {
    return errors.notFound(c, 'Group');
  }
  
  if (targetUserId === group.created_by) {
    return errors.forbidden(c, 'Cannot remove the group creator');
  }
  
  // Check if target is a member
  const targetMembership = await getMembership(c.env.DB, groupId, targetUserId);
  if (!targetMembership) {
    return errors.notFound(c, 'Member');
  }
  
  // Cannot remove another admin (unless you're the creator)
  if (targetMembership.role === 'admin' && currentUserId !== group.created_by) {
    return errors.forbidden(c, 'Only the group creator can remove other admins');
  }
  
  const now = new Date().toISOString();
  
  try {
    await c.env.DB.batch([
      c.env.DB
        .prepare('DELETE FROM group_members WHERE group_id = ? AND user_id = ?')
        .bind(groupId, targetUserId),
      c.env.DB
        .prepare('UPDATE groups SET member_count = MAX(0, member_count - 1), updated_at = ? WHERE id = ?')
        .bind(now, groupId),
    ]);
  } catch (error) {
    console.error('Failed to remove member:', error);
    return errors.serverError(c, 'Failed to remove member');
  }
  
  // Notify the removed user — include "groups" refresh so the group disappears
  // from their list immediately, consistent with the ban flow.
  try {
    await createNotification(
      c.env.DB,
      targetUserId,
      'group_removed',
      'Removed from Group',
      `You have been removed from ${group.name}`,
      'group',
      groupId,
      undefined,
      c.env,
      ['groups'],
    );
  } catch (err) {
    console.error('Failed to notify removed user:', err);
  }
  
  return success(c, { removed: true });
});

/**
 * POST /groups/:id/members/:userId/ban - Ban a member from the group
 * Banned users cannot rejoin even with invite codes
 */
groups.post('/:id/members/:userId/ban', authMiddleware, async (c) => {
  const groupId = c.req.param('id')!;
  const targetUserId = c.req.param('userId')!;
  const currentUserId = c.get('userId')!;
  
  // Check if current user is admin
  if (!await isGroupAdmin(c.env.DB, groupId, currentUserId)) {
    return errors.forbidden(c, 'Only group admins can ban members');
  }
  
  // Cannot ban the group creator
  const group = await c.env.DB
    .prepare('SELECT created_by, name FROM groups WHERE id = ? AND deleted_at IS NULL')
    .bind(groupId)
    .first<{ created_by: string; name: string }>();
  
  if (!group) {
    return errors.notFound(c, 'Group');
  }
  
  if (targetUserId === group.created_by) {
    return errors.forbidden(c, 'Cannot ban the group creator');
  }
  
  // Check if target is a member
  const targetMembership = await getMembership(c.env.DB, groupId, targetUserId);
  if (!targetMembership) {
    return errors.notFound(c, 'Member');
  }
  
  // Cannot ban another admin (unless you're the creator)
  if (targetMembership.role === 'admin' && currentUserId !== group.created_by) {
    return errors.forbidden(c, 'Only the group creator can ban other admins');
  }
  
  const now = new Date().toISOString();
  
  try {
    await c.env.DB.batch([
      // Set status to banned instead of deleting
      c.env.DB
        .prepare('UPDATE group_members SET status = ?, updated_at = ? WHERE group_id = ? AND user_id = ?')
        .bind('banned', now, groupId, targetUserId),
      c.env.DB
        .prepare('UPDATE groups SET member_count = MAX(0, member_count - 1), updated_at = ? WHERE id = ?')
        .bind(now, groupId),
      // Clean up any pending join requests from this user
      c.env.DB
        .prepare('DELETE FROM join_requests WHERE group_id = ? AND user_id = ?')
        .bind(groupId, targetUserId),
    ]);
  } catch (error) {
    console.error('Failed to ban member:', error);
    return errors.serverError(c, 'Failed to ban member');
  }
  
  // Notify the banned user — include "groups" refresh so the group disappears
  // from their list immediately without requiring a pull-to-refresh.
  try {
    await createNotification(
      c.env.DB,
      targetUserId,
      'group_banned',
      'Banned from Group',
      `You have been banned from ${group.name}`,
      'group',
      groupId,
      undefined,
      c.env,
      ['groups'],
    );
  } catch (err) {
    console.error('Failed to notify banned user:', err);
  }
  
  return success(c, { banned: true });
});

/**
 * POST /groups/:id/members/:userId/unban - Unban a previously banned member
 */
groups.post('/:id/members/:userId/unban', authMiddleware, async (c) => {
  const groupId = c.req.param('id')!;
  const targetUserId = c.req.param('userId')!;
  const currentUserId = c.get('userId')!;
  
  // Check if current user is admin
  if (!await isGroupAdmin(c.env.DB, groupId, currentUserId)) {
    return errors.forbidden(c, 'Only group admins can unban members');
  }
  
  const group = await c.env.DB
    .prepare('SELECT id FROM groups WHERE id = ? AND deleted_at IS NULL')
    .bind(groupId)
    .first();
  
  if (!group) {
    return errors.notFound(c, 'Group');
  }
  
  // Check if target is banned
  const bannedMembership = await c.env.DB
    .prepare(`SELECT id FROM group_members WHERE group_id = ? AND user_id = ? AND status = 'banned'`)
    .bind(groupId, targetUserId)
    .first();
  
  if (!bannedMembership) {
    return errors.notFound(c, 'Banned member');
  }
  
  // Remove the ban record (user can now request to join again)
  await c.env.DB
    .prepare('DELETE FROM group_members WHERE group_id = ? AND user_id = ?')
    .bind(groupId, targetUserId)
    .run();
  
  return success(c, { unbanned: true });
});

// ============================================
// ROUTES - Join Requests
// ============================================

/**
 * GET /groups/:id/requests - List pending join requests (admin only)
 */
groups.get('/:id/requests', authMiddleware, async (c) => {
  const groupId = c.req.param('id')!;
  const userId = c.get('userId')!;
  const { limit, offset } = parsePagination(c.req.query('limit'), c.req.query('offset'));
  
  // Verify group exists first
  const group = await c.env.DB
    .prepare('SELECT id FROM groups WHERE id = ? AND deleted_at IS NULL')
    .bind(groupId)
    .first();
  
  if (!group) {
    return errors.notFound(c, 'Group');
  }
  
  // Check if user is admin
  if (!await isGroupAdmin(c.env.DB, groupId, userId)) {
    return errors.forbidden(c, 'Only group admins can view join requests');
  }
  
  const results = await c.env.DB
    .prepare(`
      SELECT jr.*, u.display_name, u.username, u.profile_image_url, u.current_streak
      FROM join_requests jr
      INNER JOIN users u ON jr.user_id = u.id
      WHERE jr.group_id = ? AND jr.status = 'pending' AND u.deleted_at IS NULL
      ORDER BY jr.created_at ASC
      LIMIT ? OFFSET ?
    `)
    .bind(groupId, limit, offset)
    .all<JoinRequestRecord & Pick<UserRecord, 'display_name' | 'username' | 'profile_image_url' | 'current_streak'>>();
  
  const requests = (results.results || []).map(request => formatJoinRequest(request));
  
  return success(c, {
    requests,
    pagination: {
      limit,
      offset,
      hasMore: requests.length === limit,
    },
  });
});

/**
 * POST /groups/:id/requests/:requestId/approve - Approve a join request
 */
groups.post('/:id/requests/:requestId/approve', authMiddleware, async (c) => {
  const groupId = c.req.param('id')!;
  const requestId = c.req.param('requestId')!;
  const currentUserId = c.get('userId')!;
  
  // Check if user is admin
  if (!await isGroupAdmin(c.env.DB, groupId, currentUserId)) {
    return errors.forbidden(c, 'Only group admins can approve join requests');
  }
  
  const group = await c.env.DB
    .prepare('SELECT * FROM groups WHERE id = ? AND deleted_at IS NULL')
    .bind(groupId)
    .first<GroupRecord>();
  
  if (!group) {
    return errors.notFound(c, 'Group');
  }
  
  // Check if group is full
  if (group.member_count >= MAX_GROUP_MEMBERS) {
    return errors.groupFull(c);
  }
  
  // Get the join request
  const request = await c.env.DB
    .prepare('SELECT * FROM join_requests WHERE id = ? AND group_id = ? AND status = ?')
    .bind(requestId, groupId, 'pending')
    .first<JoinRequestRecord>();
  
  if (!request) {
    return errors.notFound(c, 'Join request');
  }
  
  // Check if user was banned in the meantime
  const existingMembership = await c.env.DB
    .prepare(`SELECT id, status FROM group_members WHERE group_id = ? AND user_id = ?`)
    .bind(groupId, request.user_id)
    .first<{ id: string; status: string }>();
  
  if (existingMembership?.status === 'banned') {
    // User was banned - deny the request instead
    const now = new Date().toISOString();
    await c.env.DB
      .prepare('UPDATE join_requests SET status = ?, reviewed_by = ?, reviewed_at = ? WHERE id = ?')
      .bind('denied', currentUserId, now, requestId)
      .run();
    return errors.forbidden(c, 'This user has been banned from the group');
  }
  
  const now = new Date().toISOString();
  const memberId = crypto.randomUUID();
  
  // Only increment count if this is a new member (no existing record)
  const isNewMember = !existingMembership;
  
  const batchOps: D1PreparedStatement[] = [
    // Update request status
    c.env.DB
      .prepare('UPDATE join_requests SET status = ?, reviewed_by = ?, reviewed_at = ? WHERE id = ?')
      .bind('approved', currentUserId, now, requestId),
    // Add user as member
    c.env.DB
      .prepare(`
        INSERT INTO group_members (id, group_id, user_id, role, status, joined_at, updated_at)
        VALUES (?, ?, ?, 'member', 'active', ?, ?)
        ON CONFLICT(group_id, user_id) DO UPDATE SET status = 'active', role = 'member', updated_at = ?
      `)
      .bind(memberId, groupId, request.user_id, now, now, now),
  ];
  
  // Only increment count for new members
  if (isNewMember) {
    batchOps.push(
      c.env.DB
        .prepare('UPDATE groups SET member_count = member_count + 1, updated_at = ? WHERE id = ?')
        .bind(now, groupId)
    );
  }
  
  await c.env.DB.batch(batchOps);
  
  // Notify the approved user — include "groups" refresh so the new group
  // appears in their list immediately alongside the notification.
  try {
    await createNotification(
      c.env.DB,
      request.user_id,
      'group_joined',
      group.name,
      `Your request to join ${group.name} has been approved`,
      'group',
      groupId,
      group.image_url ?? undefined,
      c.env,
      ['groups'],
    );
  } catch (err) {
    console.error('Failed to notify approved user:', err);
  }
  
  return success(c, { approved: true });
});

/**
 * POST /groups/:id/requests/:requestId/deny - Deny a join request
 */
groups.post('/:id/requests/:requestId/deny', authMiddleware, async (c) => {
  const groupId = c.req.param('id')!;
  const requestId = c.req.param('requestId')!;
  const currentUserId = c.get('userId')!;
  
  // Check if user is admin
  if (!await isGroupAdmin(c.env.DB, groupId, currentUserId)) {
    return errors.forbidden(c, 'Only group admins can deny join requests');
  }
  
  const group = await c.env.DB
    .prepare('SELECT name, image_url FROM groups WHERE id = ? AND deleted_at IS NULL')
    .bind(groupId)
    .first<{ name: string; image_url: string | null }>();
  
  if (!group) {
    return errors.notFound(c, 'Group');
  }
  
  // Get the join request
  const request = await c.env.DB
    .prepare('SELECT * FROM join_requests WHERE id = ? AND group_id = ? AND status = ?')
    .bind(requestId, groupId, 'pending')
    .first<JoinRequestRecord>();
  
  if (!request) {
    return errors.notFound(c, 'Join request');
  }
  
  const now = new Date().toISOString();
  
  await c.env.DB
    .prepare('UPDATE join_requests SET status = ?, reviewed_by = ?, reviewed_at = ? WHERE id = ?')
    .bind('denied', currentUserId, now, requestId)
    .run();
  
  try {
    await createNotification(
      c.env.DB,
      request.user_id,
      'group_request_denied',
      group.name,
      `Your request to join ${group.name} was not approved`,
      'group',
      groupId,
      group.image_url ?? undefined,
      c.env
    );
  } catch (err) {
    console.error('Failed to notify denied user:', err);
  }
  
  return success(c, { denied: true });
});

// ============================================
// ROUTES - Invite Codes
// ============================================

/**
 * POST /groups/join/:inviteCode - Join a group via invite code
 * NOTE: Must be defined to avoid collision with /:id routes
 */
groups.post('/join/:inviteCode', authMiddleware, async (c) => {
  const inviteCode = c.req.param('inviteCode')!.toUpperCase();
  const userId = c.get('userId')!;
  
  const group = await c.env.DB
    .prepare('SELECT * FROM groups WHERE invite_code = ? AND deleted_at IS NULL')
    .bind(inviteCode)
    .first<GroupRecord>();
  
  if (!group) {
    return errors.notFound(c, 'Invalid or expired invite code');
  }
  
  // Check if already an active member
  const existingMembership = await getMembership(c.env.DB, group.id, userId);
  if (existingMembership) {
    return errors.alreadyMember(c);
  }
  
  // Check if there's a non-active membership record (e.g., user was banned)
  const anyMembership = await c.env.DB
    .prepare(`SELECT id, status FROM group_members WHERE group_id = ? AND user_id = ?`)
    .bind(group.id, userId)
    .first<{ id: string; status: string }>();
  
  // If user was banned, don't allow rejoining via invite code
  if (anyMembership?.status === 'banned') {
    return errors.forbidden(c, 'You cannot join this group');
  }
  
  // Check if group is full
  if (group.member_count >= MAX_GROUP_MEMBERS) {
    return errors.groupFull(c);
  }
  
  const now = new Date().toISOString();
  const memberId = crypto.randomUUID();
  
  // Only increment count if this is a new member (no existing record at all)
  // anyMembership was checked above for banned status
  const isNewMember = !anyMembership;
  
  // With invite code, user joins directly regardless of join mode
  // Use UPSERT to handle case where user had previous membership that was not 'active'
  const batchOps: D1PreparedStatement[] = [
    c.env.DB
      .prepare(`
        INSERT INTO group_members (id, group_id, user_id, role, status, joined_at, updated_at)
        VALUES (?, ?, ?, 'member', 'active', ?, ?)
        ON CONFLICT(group_id, user_id) DO UPDATE SET 
          status = 'active', 
          role = 'member',
          joined_at = ?,
          updated_at = ?
      `)
      .bind(memberId, group.id, userId, now, now, now, now),
    // Clean up any pending join request
    c.env.DB
      .prepare('DELETE FROM join_requests WHERE group_id = ? AND user_id = ?')
      .bind(group.id, userId),
  ];
  
  // Only increment count for truly new members
  if (isNewMember) {
    batchOps.push(
      c.env.DB
        .prepare('UPDATE groups SET member_count = member_count + 1, updated_at = ? WHERE id = ?')
        .bind(now, group.id)
    );
  }
  
  await c.env.DB.batch(batchOps);

  // Push a "groups" refresh to the joiner's other devices so the new group
  // appears in their list immediately without a pull-to-refresh.
  sendSilentPush(c.env, userId, ['groups']).catch(() => {});
  
  return success(c, { 
    joined: true,
    group: formatPublicGroup(group, { isMember: true }),
  }, 201);
});

/**
 * POST /groups/:id/invite-code/regenerate - Regenerate invite code (admin only)
 */
groups.post('/:id/invite-code/regenerate', authMiddleware, async (c) => {
  const groupId = c.req.param('id')!;
  const userId = c.get('userId')!;
  
  // Check if user is admin
  if (!await isGroupAdmin(c.env.DB, groupId, userId)) {
    return errors.forbidden(c, 'Only group admins can regenerate invite codes');
  }
  
  const group = await c.env.DB
    .prepare('SELECT * FROM groups WHERE id = ? AND deleted_at IS NULL')
    .bind(groupId)
    .first<GroupRecord>();
  
  if (!group) {
    return errors.notFound(c, 'Group');
  }
  
  if (group.group_type !== 'private') {
    return errors.validation(c, 'Only private groups have invite codes');
  }
  
  // Generate new unique invite code
  let newInviteCode: string;
  let attempts = 0;
  while (attempts < 5) {
    newInviteCode = generateInviteCode();
    const existing = await c.env.DB
      .prepare('SELECT id FROM groups WHERE invite_code = ? AND id != ?')
      .bind(newInviteCode, groupId)
      .first();
    if (!existing) break;
    attempts++;
  }
  
  if (attempts >= 5) {
    return errors.serverError(c, 'Failed to generate unique invite code');
  }
  
  const now = new Date().toISOString();
  await c.env.DB
    .prepare('UPDATE groups SET invite_code = ?, updated_at = ? WHERE id = ?')
    .bind(newInviteCode!, now, groupId)
    .run();
  
  return success(c, { inviteCode: newInviteCode! });
});

// ============================================
// ROUTES - Leaderboard
// ============================================

/**
 * Valid leaderboard period values
 */
const VALID_PERIODS = ['day', 'week', 'month', 'all'] as const;
type LeaderboardPeriod = typeof VALID_PERIODS[number];

/**
 * Get date threshold for leaderboard period filtering
 * Returns the ISO date string for filtering, or null for 'all' period
 * 
 * SECURITY: This function only returns values, not SQL fragments.
 * The SQL queries use these values as bind parameters, never string interpolation.
 */
function getDateThreshold(period: LeaderboardPeriod): string | null {
  const now = new Date();
  
  switch (period) {
    case 'day': {
      // For day filter, we use the date only (YYYY-MM-DD format)
      return now.toISOString().split('T')[0];
    }
    case 'week': {
      const weekAgo = new Date(now);
      weekAgo.setDate(weekAgo.getDate() - 7);
      return weekAgo.toISOString();
    }
    case 'month': {
      const monthAgo = new Date(now);
      monthAgo.setMonth(monthAgo.getMonth() - 1);
      return monthAgo.toISOString();
    }
    case 'all':
    default:
      return null;
  }
}

/**
 * Check if the period is 'day' (requires DATE() comparison)
 */
function isDayPeriod(period: LeaderboardPeriod): boolean {
  return period === 'day';
}

/**
 * GET /groups/:id/leaderboard - Get group leaderboard
 */
groups.get('/:id/leaderboard', optionalAuthMiddleware, async (c) => {
  const groupId = c.req.param('id')!;
  const userId = c.get('userId');
  const periodParam = c.req.query('period') || 'week';
  const { limit } = parsePagination(c.req.query('limit'), undefined, 50, 20);
  
  // Validate period parameter
  const period: LeaderboardPeriod = VALID_PERIODS.includes(periodParam as LeaderboardPeriod) 
    ? periodParam as LeaderboardPeriod 
    : 'week';
  
  const group = await c.env.DB
    .prepare('SELECT id, group_type FROM groups WHERE id = ? AND deleted_at IS NULL')
    .bind(groupId)
    .first<{ id: string; group_type: string }>();
  
  if (!group) {
    return errors.notFound(c, 'Group');
  }
  
  // For private groups, only members can see the leaderboard
  if (group.group_type === 'private') {
    if (!userId) {
      return errors.forbidden(c, 'You must be logged in to view the leaderboard of a private group');
    }
    const membership = await getMembership(c.env.DB, groupId, userId);
    if (!membership) {
      return errors.forbidden(c, 'Only members can view the leaderboard of a private group');
    }
  }
  
  // Get date threshold for period filtering (null means no filter)
  const dateThreshold = getDateThreshold(period);
  const isDay = isDayPeriod(period);
  
  // Build query with fully parameterized date filter
  // We use separate queries for each case to maintain clarity and safety
  // SECURITY: All date values are passed as bind parameters, never interpolated
  let leaderboardQuery: string;
  let leaderboardParams: (string | number)[];
  
  if (dateThreshold && isDay) {
    // Day filter: use DATE() comparison for exact date match
    leaderboardQuery = `
      SELECT 
        u.id,
        u.display_name,
        u.username,
        u.profile_image_url,
        u.current_streak,
        COALESCE(SUM(CASE WHEN ps.performed_at IS NOT NULL AND DATE(ps.performed_at) = ? THEN ps.duration_seconds ELSE 0 END), 0) as total_duration,
        COUNT(CASE WHEN ps.performed_at IS NOT NULL AND DATE(ps.performed_at) = ? THEN ps.id END) as plank_count,
        MAX(CASE WHEN ps.performed_at IS NOT NULL AND DATE(ps.performed_at) = ? THEN ps.duration_seconds END) as best_plank
      FROM group_members gm
      INNER JOIN users u ON gm.user_id = u.id
      LEFT JOIN plank_sessions ps ON u.id = ps.user_id AND ps.deleted_at IS NULL
      WHERE gm.group_id = ? AND gm.status = 'active' AND u.deleted_at IS NULL
      GROUP BY u.id, u.display_name, u.username, u.profile_image_url, u.current_streak
      ORDER BY total_duration DESC, plank_count DESC
      LIMIT ?
    `;
    leaderboardParams = [dateThreshold, dateThreshold, dateThreshold, groupId, limit];
  } else if (dateThreshold) {
    // Week/month filter: use >= comparison for date range
    leaderboardQuery = `
      SELECT 
        u.id,
        u.display_name,
        u.username,
        u.profile_image_url,
        u.current_streak,
        COALESCE(SUM(CASE WHEN ps.performed_at IS NOT NULL AND ps.performed_at >= ? THEN ps.duration_seconds ELSE 0 END), 0) as total_duration,
        COUNT(CASE WHEN ps.performed_at IS NOT NULL AND ps.performed_at >= ? THEN ps.id END) as plank_count,
        MAX(CASE WHEN ps.performed_at IS NOT NULL AND ps.performed_at >= ? THEN ps.duration_seconds END) as best_plank
      FROM group_members gm
      INNER JOIN users u ON gm.user_id = u.id
      LEFT JOIN plank_sessions ps ON u.id = ps.user_id AND ps.deleted_at IS NULL
      WHERE gm.group_id = ? AND gm.status = 'active' AND u.deleted_at IS NULL
      GROUP BY u.id, u.display_name, u.username, u.profile_image_url, u.current_streak
      ORDER BY total_duration DESC, plank_count DESC
      LIMIT ?
    `;
    leaderboardParams = [dateThreshold, dateThreshold, dateThreshold, groupId, limit];
  } else {
    // No filter (all-time)
    leaderboardQuery = `
      SELECT 
        u.id,
        u.display_name,
        u.username,
        u.profile_image_url,
        u.current_streak,
        COALESCE(SUM(ps.duration_seconds), 0) as total_duration,
        COUNT(ps.id) as plank_count,
        MAX(ps.duration_seconds) as best_plank
      FROM group_members gm
      INNER JOIN users u ON gm.user_id = u.id
      LEFT JOIN plank_sessions ps ON u.id = ps.user_id AND ps.deleted_at IS NULL
      WHERE gm.group_id = ? AND gm.status = 'active' AND u.deleted_at IS NULL
      GROUP BY u.id, u.display_name, u.username, u.profile_image_url, u.current_streak
      ORDER BY total_duration DESC, plank_count DESC
      LIMIT ?
    `;
    leaderboardParams = [groupId, limit];
  }
  
  const results = await c.env.DB
    .prepare(leaderboardQuery)
    .bind(...leaderboardParams)
    .all<{
      id: string;
      display_name: string;
      username: string | null;
      profile_image_url: string | null;
      current_streak: number;
      total_duration: number;
      plank_count: number;
      best_plank: number | null;
    }>();
  
  // Format and add rank using DENSE_RANK: same total_duration → same rank
  const leaderboardResults = results.results || [];
  let groupCurrentRank = 1;
  const leaderboard = leaderboardResults.map((entry, index) => {
    if (index > 0 && entry.total_duration !== leaderboardResults[index - 1].total_duration) {
      groupCurrentRank = index + 1;
    }
    return {
    rank: groupCurrentRank,
    user: {
      id: entry.id,
      display_name: entry.display_name,
      username: entry.username,
      profile_image_url: entry.profile_image_url,
      current_streak: entry.current_streak,
    },
    stats: {
      total_duration: entry.total_duration,
      plank_count: entry.plank_count,
      best_plank: entry.best_plank || 0,
    },
    };
  });
  
  // Find current user's rank if authenticated and a member
  let currentUserRank: typeof leaderboard[0] | null = null;
  if (userId) {
    const userEntry = leaderboard.find(entry => entry.user.id === userId);
    if (userEntry) {
      currentUserRank = userEntry;
    } else {
      // Check if user is a member before fetching their stats
      const isMember = await getMembership(c.env.DB, groupId, userId);
      if (isMember) {
        // User might be outside the top N, fetch their stats separately
        // For simplicity, calculate rank in memory with fully parameterized queries
        let allMembersQuery: string;
        let allMembersParams: (string | number)[];
        
        if (dateThreshold && isDay) {
          // Day filter with DATE() comparison
          allMembersQuery = `
            SELECT 
              gm.user_id,
              COALESCE(SUM(CASE WHEN ps.performed_at IS NOT NULL AND DATE(ps.performed_at) = ? THEN ps.duration_seconds ELSE 0 END), 0) as total_duration
            FROM group_members gm
            LEFT JOIN plank_sessions ps ON gm.user_id = ps.user_id AND ps.deleted_at IS NULL
            WHERE gm.group_id = ? AND gm.status = 'active'
            GROUP BY gm.user_id
            ORDER BY total_duration DESC
          `;
          allMembersParams = [dateThreshold, groupId];
        } else if (dateThreshold) {
          // Week/month filter with >= comparison
          allMembersQuery = `
            SELECT 
              gm.user_id,
              COALESCE(SUM(CASE WHEN ps.performed_at IS NOT NULL AND ps.performed_at >= ? THEN ps.duration_seconds ELSE 0 END), 0) as total_duration
            FROM group_members gm
            LEFT JOIN plank_sessions ps ON gm.user_id = ps.user_id AND ps.deleted_at IS NULL
            WHERE gm.group_id = ? AND gm.status = 'active'
            GROUP BY gm.user_id
            ORDER BY total_duration DESC
          `;
          allMembersParams = [dateThreshold, groupId];
        } else {
          // All-time (no filter)
          allMembersQuery = `
            SELECT 
              gm.user_id,
              COALESCE(SUM(ps.duration_seconds), 0) as total_duration
            FROM group_members gm
            LEFT JOIN plank_sessions ps ON gm.user_id = ps.user_id AND ps.deleted_at IS NULL
            WHERE gm.group_id = ? AND gm.status = 'active'
            GROUP BY gm.user_id
            ORDER BY total_duration DESC
          `;
          allMembersParams = [groupId];
        }
        
        const allMembers = await c.env.DB
          .prepare(allMembersQuery)
          .bind(...allMembersParams)
          .all<{ user_id: string; total_duration: number }>();
        
        const allMembersList = allMembers.results || [];
        const userRankIndex = allMembersList.findIndex(m => m.user_id === userId);
        
        if (userRankIndex !== -1) {
          // Compute DENSE_RANK for this user in the full sorted list
          const userDuration = allMembersList[userRankIndex].total_duration;
          const denseRank = allMembersList.slice(0, userRankIndex).reduce((rank, m, i) => {
            if (i === 0) return 1;
            return m.total_duration !== allMembersList[i - 1].total_duration ? rank + 1 : rank;
          }, 1);
          // Count distinct duration values strictly above the user's
          const distinctAbove = new Set(
            allMembersList.filter(m => m.total_duration > userDuration).map(m => m.total_duration)
          ).size;
          const computedRank = distinctAbove + 1;
          // Fetch user details
          const userDetails = await c.env.DB
            .prepare(`
              SELECT u.id, u.display_name, u.username, u.profile_image_url, u.current_streak
              FROM users u WHERE u.id = ?
            `)
            .bind(userId)
            .first<{
              id: string;
              display_name: string;
              username: string | null;
              profile_image_url: string | null;
              current_streak: number;
            }>();
          
          if (userDetails) {
            const userMemberData = allMembers.results![userRankIndex];
            
            // Get plank count and best plank for the user with fully parameterized query
            let userStatsQuery: string;
            let userStatsParams: (string | number)[];
            
            if (dateThreshold && isDay) {
              // Day filter with DATE() comparison
              userStatsQuery = `
                SELECT COUNT(ps.id) as plank_count, MAX(ps.duration_seconds) as best_plank
                FROM plank_sessions ps
                WHERE ps.user_id = ? AND ps.deleted_at IS NULL AND DATE(ps.performed_at) = ?
              `;
              userStatsParams = [userId, dateThreshold];
            } else if (dateThreshold) {
              // Week/month filter with >= comparison
              userStatsQuery = `
                SELECT COUNT(ps.id) as plank_count, MAX(ps.duration_seconds) as best_plank
                FROM plank_sessions ps
                WHERE ps.user_id = ? AND ps.deleted_at IS NULL AND ps.performed_at >= ?
              `;
              userStatsParams = [userId, dateThreshold];
            } else {
              // All-time (no filter)
              userStatsQuery = `
                SELECT COUNT(ps.id) as plank_count, MAX(ps.duration_seconds) as best_plank
                FROM plank_sessions ps
                WHERE ps.user_id = ? AND ps.deleted_at IS NULL
              `;
              userStatsParams = [userId];
            }
            
            const userPlankStats = await c.env.DB
              .prepare(userStatsQuery)
              .bind(...userStatsParams)
              .first<{ plank_count: number; best_plank: number | null }>();
            
            currentUserRank = {
              rank: computedRank,
              user: {
                id: userDetails.id,
                display_name: userDetails.display_name,
                username: userDetails.username,
                profile_image_url: userDetails.profile_image_url,
                current_streak: userDetails.current_streak,
              },
              stats: {
                total_duration: userMemberData.total_duration,
                plank_count: userPlankStats?.plank_count || 0,
                best_plank: userPlankStats?.best_plank || 0,
              },
            };
          }
        }
      }
    }
  }
  
  return success(c, {
    leaderboard,
    period,
    currentUser: currentUserRank,
  });
});

export default groups;
