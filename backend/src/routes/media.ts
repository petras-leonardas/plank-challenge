import { Hono } from 'hono';
import type { Env, Variables } from '../types/env';
import type { UserRecord, GroupRecord, GroupMemberRecord } from '../types/api';
import { success, errors } from '../utils/response';
import { authMiddleware } from '../middleware/auth';
import {
  MAX_AVATAR_SIZE,
  MAX_GROUP_IMAGE_SIZE,
  generateImageKey,
  getPublicUrl,
  extractKeyFromUrl,
  getThumbnailKey,
  validateImageUploadHeaders,
  validateImageData,
} from '../utils/media';

const media = new Hono<{ Bindings: Env; Variables: Variables }>();

// ============================================
// AVATAR ROUTES
// ============================================

/**
 * POST /media/avatar - Upload profile avatar
 * 
 * This endpoint accepts the image binary directly in the request body.
 * The Content-Type header must be set to the image type (image/jpeg, image/png, image/webp).
 * 
 * Flow:
 * 1. Validate content type header
 * 2. Read and validate image data (size + magic bytes)
 * 3. Upload to R2
 * 4. Update user profile (with rollback on failure)
 * 5. Delete old avatar if exists
 */
media.post('/avatar', authMiddleware, async (c) => {
  const userId = c.get('userId')!; // Auth middleware guarantees this exists
  
  // Step 1: Validate headers
  const contentType = c.req.header('Content-Type') ?? null;
  const contentLength = c.req.header('Content-Length');
  const contentLengthNum = contentLength ? parseInt(contentLength, 10) : null;
  
  const headerValidation = validateImageUploadHeaders(contentType, contentLengthNum, MAX_AVATAR_SIZE);
  if (!headerValidation.valid) {
    return errors.validation(c, headerValidation.error!);
  }
  
  // Step 2: Read and validate image data
  const imageData = await c.req.arrayBuffer();
  
  const dataValidation = validateImageData(imageData, headerValidation.contentType!, MAX_AVATAR_SIZE);
  if (!dataValidation.valid) {
    return errors.validation(c, dataValidation.error!);
  }
  
  // Step 3: Get the current user to find old avatar
  const user = await c.env.DB
    .prepare('SELECT profile_image_url FROM users WHERE id = ?')
    .bind(userId)
    .first<Pick<UserRecord, 'profile_image_url'>>();
  
  const oldAvatarKey = user ? extractKeyFromUrl(user.profile_image_url) : null;
  
  // Generate the storage key with correct extension
  const imageKey = generateImageKey('avatar', userId, dataValidation.contentType!);
  
  try {
    // Step 4: Upload to R2
    await c.env.MEDIA.put(imageKey, imageData, {
      httpMetadata: {
        contentType: dataValidation.contentType!,
        cacheControl: 'public, max-age=31536000', // 1 year cache (images are versioned by timestamp)
      },
      customMetadata: {
        userId,
        uploadedAt: new Date().toISOString(),
      },
    });
    
    // Step 5: Update user profile with new avatar URL
    const publicUrl = getPublicUrl(imageKey, c.env.MEDIA_BASE_URL);
    
    try {
      await c.env.DB
        .prepare('UPDATE users SET profile_image_url = ?, updated_at = ? WHERE id = ?')
        .bind(publicUrl, new Date().toISOString(), userId)
        .run();
    } catch (dbError) {
      // Rollback: Delete the image we just uploaded to prevent orphans
      try {
        await c.env.MEDIA.delete(imageKey);
      } catch (rollbackError) {
        // IMPORTANT: Log orphaned file for monitoring/cleanup
        // In production, consider adding this to a cleanup queue
        console.error('[Media] ORPHANED FILE - rollback failed:', {
          imageKey,
          userId,
          error: rollbackError instanceof Error ? rollbackError.message : String(rollbackError),
        });
      }
      throw dbError;
    }
    
    // Step 6: Delete old avatar (only after DB update succeeds)
    if (oldAvatarKey && oldAvatarKey !== imageKey) {
      try {
        await c.env.MEDIA.delete(oldAvatarKey);
        // Also try to delete old thumbnail
        const oldThumbKey = getThumbnailKey(oldAvatarKey);
        await c.env.MEDIA.delete(oldThumbKey);
      } catch (deleteError) {
        // Non-fatal: old image cleanup failure shouldn't fail the upload
        // IMPORTANT: Log orphaned file for monitoring/cleanup
        console.error('[Media] ORPHANED FILE - old avatar cleanup failed:', {
          oldAvatarKey,
          userId,
          error: deleteError instanceof Error ? deleteError.message : String(deleteError),
        });
      }
    }
    
    return success(c, {
      profileImageUrl: publicUrl,
      message: 'Avatar uploaded successfully',
    }, 201);
    
  } catch (error) {
    console.error('Failed to upload avatar:', error);
    return errors.serverError(c, 'Failed to upload image');
  }
});

/**
 * DELETE /media/avatar - Remove profile avatar
 */
media.delete('/avatar', authMiddleware, async (c) => {
  const userId = c.get('userId')!;
  
  // Get current avatar URL
  const user = await c.env.DB
    .prepare('SELECT profile_image_url FROM users WHERE id = ?')
    .bind(userId)
    .first<Pick<UserRecord, 'profile_image_url'>>();
  
  if (!user?.profile_image_url) {
    return errors.notFound(c, 'Avatar');
  }
  
  const avatarKey = extractKeyFromUrl(user.profile_image_url);
  
  // Update user profile to remove avatar
  await c.env.DB
    .prepare('UPDATE users SET profile_image_url = NULL, updated_at = ? WHERE id = ?')
    .bind(new Date().toISOString(), userId)
    .run();
  
  // Delete from R2
  if (avatarKey) {
    try {
      await c.env.MEDIA.delete(avatarKey);
      // Also delete thumbnail if it exists
      const thumbKey = getThumbnailKey(avatarKey);
      await c.env.MEDIA.delete(thumbKey);
    } catch (deleteError) {
      // Non-fatal: log but don't fail the request
      // The profile is already updated, user won't see the avatar
      console.error('Failed to delete avatar from R2:', deleteError);
    }
  }
  
  return success(c, {
    message: 'Avatar removed successfully',
  });
});

/**
 * GET /media/avatar/:userId - Get user's avatar
 * 
 * This provides a stable URL that serves the image from R2.
 * Useful for caching and avoiding direct R2 URL exposure.
 */
media.get('/avatar/:userId', async (c) => {
  const targetUserId = c.req.param('userId')!;
  
  // Get user's avatar URL
  const user = await c.env.DB
    .prepare('SELECT profile_image_url FROM users WHERE id = ? AND deleted_at IS NULL')
    .bind(targetUserId)
    .first<Pick<UserRecord, 'profile_image_url'>>();
  
  if (!user?.profile_image_url) {
    return errors.notFound(c, 'Avatar');
  }
  
  const avatarKey = extractKeyFromUrl(user.profile_image_url);
  
  if (!avatarKey) {
    return errors.notFound(c, 'Avatar');
  }
  
  // Get the object from R2
  const object = await c.env.MEDIA.get(avatarKey);
  
  if (!object) {
    return errors.notFound(c, 'Avatar');
  }
  
  // Return the image with appropriate headers
  const headers = new Headers();
  headers.set('Content-Type', object.httpMetadata?.contentType || 'image/jpeg');
  headers.set('Cache-Control', 'public, max-age=86400'); // 1 day cache at edge
  headers.set('ETag', object.etag);
  
  return new Response(object.body, { headers });
});

// ============================================
// GROUP IMAGE ROUTES (Preparation for Phase 6)
// ============================================

/**
 * POST /media/group/:groupId - Upload group cover image
 * 
 * Requires admin role in the group.
 */
media.post('/group/:groupId', authMiddleware, async (c) => {
  const userId = c.get('userId')!;
  const groupId = c.req.param('groupId')!;
  
  // Check if user is admin of the group
  const membership = await c.env.DB
    .prepare('SELECT role FROM group_members WHERE group_id = ? AND user_id = ? AND status = ?')
    .bind(groupId, userId, 'active')
    .first<Pick<GroupMemberRecord, 'role'>>();
  
  if (!membership || membership.role !== 'admin') {
    return errors.forbidden(c, 'Only group admins can update the group image');
  }
  
  // Step 1: Validate headers
  const contentType = c.req.header('Content-Type') ?? null;
  const contentLength = c.req.header('Content-Length');
  const contentLengthNum = contentLength ? parseInt(contentLength, 10) : null;
  
  const headerValidation = validateImageUploadHeaders(contentType, contentLengthNum, MAX_GROUP_IMAGE_SIZE);
  if (!headerValidation.valid) {
    return errors.validation(c, headerValidation.error!);
  }
  
  // Step 2: Read and validate image data
  const imageData = await c.req.arrayBuffer();
  
  const dataValidation = validateImageData(imageData, headerValidation.contentType!, MAX_GROUP_IMAGE_SIZE);
  if (!dataValidation.valid) {
    return errors.validation(c, dataValidation.error!);
  }
  
  // Get old image URL
  const group = await c.env.DB
    .prepare('SELECT image_url FROM groups WHERE id = ?')
    .bind(groupId)
    .first<Pick<GroupRecord, 'image_url'>>();
  
  const oldImageKey = group ? extractKeyFromUrl(group.image_url) : null;
  
  // Generate the storage key with correct extension
  const imageKey = generateImageKey('group', groupId, dataValidation.contentType!);
  
  try {
    // Upload to R2
    await c.env.MEDIA.put(imageKey, imageData, {
      httpMetadata: {
        contentType: dataValidation.contentType!,
        cacheControl: 'public, max-age=31536000',
      },
      customMetadata: {
        groupId,
        uploadedBy: userId,
        uploadedAt: new Date().toISOString(),
      },
    });
    
    // Update group with new image URL
    const publicUrl = getPublicUrl(imageKey, c.env.MEDIA_BASE_URL);
    
    try {
      await c.env.DB
        .prepare('UPDATE groups SET image_url = ?, updated_at = ? WHERE id = ?')
        .bind(publicUrl, new Date().toISOString(), groupId)
        .run();
    } catch (dbError) {
      // Rollback: Delete the image we just uploaded
      try {
        await c.env.MEDIA.delete(imageKey);
      } catch (rollbackError) {
        console.error('Failed to rollback R2 upload after DB failure:', rollbackError);
      }
      throw dbError;
    }
    
    // Delete old image (only after DB update succeeds)
    if (oldImageKey && oldImageKey !== imageKey) {
      try {
        await c.env.MEDIA.delete(oldImageKey);
        await c.env.MEDIA.delete(getThumbnailKey(oldImageKey));
      } catch (deleteError) {
        console.error('Failed to delete old group image:', deleteError);
      }
    }
    
    return success(c, {
      imageUrl: publicUrl,
      message: 'Group image uploaded successfully',
    }, 201);
    
  } catch (error) {
    console.error('Failed to upload group image:', error);
    return errors.serverError(c, 'Failed to upload image');
  }
});

/**
 * DELETE /media/group/:groupId - Remove group cover image
 */
media.delete('/group/:groupId', authMiddleware, async (c) => {
  const userId = c.get('userId')!;
  const groupId = c.req.param('groupId')!;
  
  // Check if user is admin of the group
  const membership = await c.env.DB
    .prepare('SELECT role FROM group_members WHERE group_id = ? AND user_id = ? AND status = ?')
    .bind(groupId, userId, 'active')
    .first<Pick<GroupMemberRecord, 'role'>>();
  
  if (!membership || membership.role !== 'admin') {
    return errors.forbidden(c, 'Only group admins can update the group image');
  }
  
  // Get current image URL
  const group = await c.env.DB
    .prepare('SELECT image_url FROM groups WHERE id = ?')
    .bind(groupId)
    .first<Pick<GroupRecord, 'image_url'>>();
  
  if (!group?.image_url) {
    return errors.notFound(c, 'Group image');
  }
  
  const imageKey = extractKeyFromUrl(group.image_url);
  
  // Update group to remove image
  await c.env.DB
    .prepare('UPDATE groups SET image_url = NULL, updated_at = ? WHERE id = ?')
    .bind(new Date().toISOString(), groupId)
    .run();
  
  // Delete from R2
  if (imageKey) {
    try {
      await c.env.MEDIA.delete(imageKey);
      await c.env.MEDIA.delete(getThumbnailKey(imageKey));
    } catch (deleteError) {
      console.error('Failed to delete group image from R2:', deleteError);
    }
  }
  
  return success(c, {
    message: 'Group image removed successfully',
  });
});

/**
 * GET /media/group/:groupId - Get group's cover image
 */
media.get('/group/:groupId', async (c) => {
  const groupId = c.req.param('groupId')!;
  
  const group = await c.env.DB
    .prepare('SELECT image_url FROM groups WHERE id = ? AND deleted_at IS NULL')
    .bind(groupId)
    .first<Pick<GroupRecord, 'image_url'>>();
  
  if (!group?.image_url) {
    return errors.notFound(c, 'Group image');
  }
  
  const imageKey = extractKeyFromUrl(group.image_url);
  
  if (!imageKey) {
    return errors.notFound(c, 'Group image');
  }
  
  const object = await c.env.MEDIA.get(imageKey);
  
  if (!object) {
    return errors.notFound(c, 'Group image');
  }
  
  const headers = new Headers();
  headers.set('Content-Type', object.httpMetadata?.contentType || 'image/jpeg');
  headers.set('Cache-Control', 'public, max-age=86400');
  headers.set('ETag', object.etag);
  
  return new Response(object.body, { headers });
});

export default media;
