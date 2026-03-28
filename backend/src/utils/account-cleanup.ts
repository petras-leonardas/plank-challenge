/**
 * Account Cleanup Utility
 * 
 * Handles GDPR-compliant hard deletion of all user data.
 * Called when a user deletes their account.
 */

import type { Env } from '../types/env';

// ============================================
// TYPES
// ============================================

export interface CleanupResult {
  success: boolean;
  deletedCounts: {
    plankSessions: number;
    badges: number;
    groupMemberships: number;
    follows: number;
    notifications: number;
    devices: number;
    joinRequests: number;
  };
  errors: string[];
}

// ============================================
// MAIN CLEANUP FUNCTION
// ============================================

/**
 * Hard delete all user data from the database
 * 
 * This function removes all data associated with a user account:
 * - Plank sessions
 * - Badges
 * - Group memberships (and updates group member counts)
 * - Follow relationships (and updates follower/following counts)
 * - Notifications
 * - Devices (push notification tokens)
 * - Join requests
 * - Finally, the user record itself
 * 
 * @param db - D1 Database instance
 * @param userId - The user ID to clean up
 * @returns CleanupResult with counts of deleted records
 */
export async function deleteAllUserData(
  db: D1Database,
  userId: string
): Promise<CleanupResult> {
  const errors: string[] = [];
  const deletedCounts = {
    plankSessions: 0,
    badges: 0,
    groupMemberships: 0,
    follows: 0,
    notifications: 0,
    devices: 0,
    joinRequests: 0,
  };

  try {
    // 1. Delete plank sessions
    const plankResult = await db
      .prepare('DELETE FROM plank_sessions WHERE user_id = ?')
      .bind(userId)
      .run();
    deletedCounts.plankSessions = plankResult.meta.changes || 0;
  } catch (err) {
    errors.push(`Failed to delete plank sessions: ${err}`);
  }

  try {
    // 2. Delete badges
    const badgeResult = await db
      .prepare('DELETE FROM badges WHERE user_id = ?')
      .bind(userId)
      .run();
    deletedCounts.badges = badgeResult.meta.changes || 0;
  } catch (err) {
    errors.push(`Failed to delete badges: ${err}`);
  }

  try {
    // 3. Delete group memberships and update member counts
    // First, get all groups the user is a member of
    const memberships = await db
      .prepare('SELECT group_id FROM group_members WHERE user_id = ?')
      .bind(userId)
      .all();
    
    if (memberships.results && memberships.results.length > 0) {
      // Delete memberships
      const memberResult = await db
        .prepare('DELETE FROM group_members WHERE user_id = ?')
        .bind(userId)
        .run();
      deletedCounts.groupMemberships = memberResult.meta.changes || 0;
      
      // Update member counts for affected groups
      for (const membership of memberships.results) {
        await db
          .prepare('UPDATE groups SET member_count = MAX(0, member_count - 1) WHERE id = ?')
          .bind(membership.group_id)
          .run();
      }
    }
  } catch (err) {
    errors.push(`Failed to delete group memberships: ${err}`);
  }

  try {
    // 4. Delete follows and update follower/following counts
    // Get users this person follows
    const following = await db
      .prepare('SELECT following_id FROM follows WHERE follower_id = ?')
      .bind(userId)
      .all();
    
    // Get users who follow this person
    const followers = await db
      .prepare('SELECT follower_id FROM follows WHERE following_id = ?')
      .bind(userId)
      .all();
    
    // Delete all follow relationships involving this user
    const followResult = await db
      .prepare('DELETE FROM follows WHERE follower_id = ? OR following_id = ?')
      .bind(userId, userId)
      .run();
    deletedCounts.follows = followResult.meta.changes || 0;
    
    // Update follower counts for users this person followed
    if (following.results && following.results.length > 0) {
      for (const follow of following.results) {
        await db
          .prepare('UPDATE users SET follower_count = MAX(0, follower_count - 1) WHERE id = ?')
          .bind(follow.following_id)
          .run();
      }
    }
    
    // Update following counts for users who followed this person
    if (followers.results && followers.results.length > 0) {
      for (const follow of followers.results) {
        await db
          .prepare('UPDATE users SET following_count = MAX(0, following_count - 1) WHERE id = ?')
          .bind(follow.follower_id)
          .run();
      }
    }
  } catch (err) {
    errors.push(`Failed to delete follows: ${err}`);
  }

  try {
    // 5. Delete notifications
    const notificationResult = await db
      .prepare('DELETE FROM notifications WHERE user_id = ?')
      .bind(userId)
      .run();
    deletedCounts.notifications = notificationResult.meta.changes || 0;
  } catch (err) {
    errors.push(`Failed to delete notifications: ${err}`);
  }

  try {
    // 6. Delete devices (push notification tokens)
    const deviceResult = await db
      .prepare('DELETE FROM devices WHERE user_id = ?')
      .bind(userId)
      .run();
    deletedCounts.devices = deviceResult.meta.changes || 0;
  } catch (err) {
    errors.push(`Failed to delete devices: ${err}`);
  }

  try {
    // 7. Delete join requests
    const joinRequestResult = await db
      .prepare('DELETE FROM join_requests WHERE user_id = ?')
      .bind(userId)
      .run();
    deletedCounts.joinRequests = joinRequestResult.meta.changes || 0;
  } catch (err) {
    errors.push(`Failed to delete join requests: ${err}`);
  }

  try {
    // 8. Handle groups created by this user
    // Option 1: Transfer ownership (not implemented - would need to decide new owner)
    // Option 2: Delete the group if user is sole admin
    // For now, we'll delete groups where this user is the creator and sole member
    const createdGroups = await db
      .prepare('SELECT id FROM groups WHERE created_by = ?')
      .bind(userId)
      .all();
    
    if (createdGroups.results && createdGroups.results.length > 0) {
      for (const group of createdGroups.results) {
        // Check if there are other members
        const otherMembers = await db
          .prepare('SELECT COUNT(*) as count FROM group_members WHERE group_id = ? AND user_id != ?')
          .bind(group.id, userId)
          .first();
        
        if (otherMembers && (otherMembers.count as number) === 0) {
          // No other members, delete the group
          await db.prepare('DELETE FROM groups WHERE id = ?').bind(group.id).run();
        } else {
          // There are other members - just remove the creator reference
          // The group continues with remaining members
          // In a real app, you might want to assign a new admin
          await db
            .prepare('UPDATE groups SET created_by = NULL WHERE id = ?')
            .bind(group.id)
            .run();
        }
      }
    }
  } catch (err) {
    errors.push(`Failed to handle created groups: ${err}`);
  }

  try {
    // 9. Finally, hard delete the user record
    await db
      .prepare('DELETE FROM users WHERE id = ?')
      .bind(userId)
      .run();
  } catch (err) {
    errors.push(`Failed to delete user record: ${err}`);
  }

  return {
    success: errors.length === 0,
    deletedCounts,
    errors,
  };
}

/**
 * Revoke all sessions for a user from KV
 * 
 * @param kv - KV Namespace for sessions
 * @param userId - The user ID whose sessions should be revoked
 */
export async function revokeAllUserSessions(
  kv: KVNamespace,
  userId: string
): Promise<number> {
  // KV doesn't support listing keys by prefix efficiently in Workers
  // In a production app, you might want to:
  // 1. Store session IDs in the user record
  // 2. Use a different data structure
  // 3. Accept that old sessions will expire naturally (30 days)
  
  // For now, we'll rely on the JWT expiration
  // Sessions are stored as: session:{userId}:{tokenId}
  // They will expire naturally based on their TTL
  
  // If you need immediate revocation, consider storing a "revoked_at" timestamp
  // for the user and checking it during token verification
  
  console.log(`[Account Cleanup] Sessions for user ${userId} will expire naturally`);
  return 0;
}

/**
 * Delete user media from R2 bucket
 * 
 * @param bucket - R2 Bucket instance
 * @param userId - The user ID whose media should be deleted
 */
export async function deleteUserMedia(
  bucket: R2Bucket,
  userId: string
): Promise<number> {
  let deletedCount = 0;
  
  try {
    // List all objects with the user's prefix
    const profilePrefix = `profiles/${userId}/`;
    const galleryPrefix = `gallery/${userId}/`;
    
    // Delete profile images
    const profileObjects = await bucket.list({ prefix: profilePrefix });
    for (const obj of profileObjects.objects) {
      await bucket.delete(obj.key);
      deletedCount++;
    }
    
    // Delete gallery images
    const galleryObjects = await bucket.list({ prefix: galleryPrefix });
    for (const obj of galleryObjects.objects) {
      await bucket.delete(obj.key);
      deletedCount++;
    }
  } catch (err) {
    console.error(`[Account Cleanup] Failed to delete media for user ${userId}:`, err);
  }
  
  return deletedCount;
}

/**
 * Complete account deletion - removes all user data from all services
 */
export async function performFullAccountDeletion(
  env: Env,
  userId: string
): Promise<CleanupResult & { mediaDeleted: number; sessionsRevoked: number }> {
  // 1. Delete all database records
  const dbResult = await deleteAllUserData(env.DB, userId);
  
  // 2. Revoke all sessions (or let them expire)
  const sessionsRevoked = await revokeAllUserSessions(env.SESSIONS, userId);
  
  // 3. Delete media from R2
  const mediaDeleted = await deleteUserMedia(env.MEDIA, userId);
  
  return {
    ...dbResult,
    mediaDeleted,
    sessionsRevoked,
  };
}
