/**
 * Media utility functions for R2 storage
 * 
 * Design decisions:
 * - Use direct upload through Worker (not presigned URLs) for simplicity and security
 * - Worker validates auth, content type, size, and magic bytes before accepting upload
 * - Thumbnails generated asynchronously via queue
 * - CDN URLs constructed from known bucket patterns
 */

// ============================================
// CONSTANTS
// ============================================

// File size limits
export const MAX_AVATAR_SIZE = 5 * 1024 * 1024; // 5MB
export const MAX_GROUP_IMAGE_SIZE = 5 * 1024 * 1024; // 5MB
export const MIN_IMAGE_SIZE = 50; // bytes - smallest valid image (tiny PNGs can be ~67 bytes)

// Allowed content types
export const ALLOWED_IMAGE_TYPES = [
  'image/jpeg',
  'image/png',
  'image/webp',
] as const;

export type AllowedImageType = typeof ALLOWED_IMAGE_TYPES[number];

/**
 * Media types for organizing storage
 */
export type MediaType = 'avatar' | 'group' | 'gallery';

// ============================================
// MAGIC BYTE VALIDATION
// ============================================

/**
 * Validate image file by checking magic bytes (file signature)
 * 
 * This prevents clients from uploading non-image files with spoofed Content-Type headers.
 * 
 * Magic bytes:
 * - JPEG: FF D8 FF
 * - PNG: 89 50 4E 47 0D 0A 1A 0A
 * - WebP: 52 49 46 46 [4 bytes] 57 45 42 50
 */
export function detectImageType(data: ArrayBuffer): AllowedImageType | null {
  if (data.byteLength < 12) {
    return null; // Too small to be a valid image
  }
  
  const bytes = new Uint8Array(data.slice(0, 12));
  
  // JPEG: FF D8 FF
  if (bytes[0] === 0xFF && bytes[1] === 0xD8 && bytes[2] === 0xFF) {
    return 'image/jpeg';
  }
  
  // PNG: 89 50 4E 47 0D 0A 1A 0A (first 8 bytes)
  if (
    bytes[0] === 0x89 &&
    bytes[1] === 0x50 &&
    bytes[2] === 0x4E &&
    bytes[3] === 0x47 &&
    bytes[4] === 0x0D &&
    bytes[5] === 0x0A &&
    bytes[6] === 0x1A &&
    bytes[7] === 0x0A
  ) {
    return 'image/png';
  }
  
  // WebP: RIFF [4 bytes size] WEBP
  // Bytes 0-3: "RIFF" (52 49 46 46)
  // Bytes 8-11: "WEBP" (57 45 42 50)
  if (
    bytes[0] === 0x52 &&
    bytes[1] === 0x49 &&
    bytes[2] === 0x46 &&
    bytes[3] === 0x46 &&
    bytes[8] === 0x57 &&
    bytes[9] === 0x45 &&
    bytes[10] === 0x42 &&
    bytes[11] === 0x50
  ) {
    return 'image/webp';
  }
  
  return null;
}

/**
 * Validate that claimed content type matches actual file content
 */
export function validateMagicBytes(
  data: ArrayBuffer,
  claimedContentType: AllowedImageType
): { valid: boolean; detectedType: AllowedImageType | null; error?: string } {
  const detectedType = detectImageType(data);
  
  if (!detectedType) {
    return {
      valid: false,
      detectedType: null,
      error: 'File does not appear to be a valid image',
    };
  }
  
  if (detectedType !== claimedContentType) {
    return {
      valid: false,
      detectedType,
      error: `Content-Type mismatch: claimed ${claimedContentType} but file is ${detectedType}`,
    };
  }
  
  return { valid: true, detectedType };
}

// ============================================
// FILE EXTENSION HANDLING
// ============================================

/**
 * Get file extension from content type
 */
export function getExtensionFromContentType(contentType: AllowedImageType): string {
  switch (contentType) {
    case 'image/jpeg':
      return 'jpg';
    case 'image/png':
      return 'png';
    case 'image/webp':
      return 'webp';
    default:
      // TypeScript exhaustiveness check
      const _exhaustive: never = contentType;
      return _exhaustive;
  }
}

// ============================================
// STORAGE KEY GENERATION
// ============================================

/**
 * Generate storage key for an image
 * 
 * Keys include:
 * - Type-based folder structure (profiles/, groups/, gallery/)
 * - Entity ID for organization
 * - Timestamp for cache busting and versioning
 * - Correct file extension based on actual content type
 */
export function generateImageKey(
  type: MediaType,
  entityId: string,
  contentType: AllowedImageType,
  variant: 'original' | 'thumb' = 'original'
): string {
  const timestamp = Date.now();
  const suffix = variant === 'thumb' ? '_thumb' : '';
  const extension = getExtensionFromContentType(contentType);
  
  switch (type) {
    case 'avatar':
      return `profiles/${entityId}/avatar${suffix}_${timestamp}.${extension}`;
    case 'group':
      return `groups/${entityId}/cover${suffix}_${timestamp}.${extension}`;
    case 'gallery':
      return `gallery/${entityId}/${crypto.randomUUID()}${suffix}.${extension}`;
    default:
      throw new Error(`Unknown media type: ${type}`);
  }
}

// ============================================
// URL HANDLING
// ============================================

/**
 * Get the public CDN URL for an R2 object
 * 
 * For now, we return just the key. The frontend constructs full URLs.
 * This allows flexibility in CDN configuration without database migrations.
 */
export function getPublicUrl(key: string, bucketPublicUrl?: string): string {
  if (bucketPublicUrl) {
    return `${bucketPublicUrl}/${key}`;
  }
  return key;
}

/**
 * Extract the R2 key from a stored URL or key
 */
export function extractKeyFromUrl(url: string | null): string | null {
  if (!url) return null;
  
  try {
    // If it's already just a key (no protocol), return as-is
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      return url;
    }
    
    const urlObj = new URL(url);
    // Remove leading slash
    return urlObj.pathname.startsWith('/') ? urlObj.pathname.slice(1) : urlObj.pathname;
  } catch {
    // If URL parsing fails, assume it's already a key
    return url;
  }
}

/**
 * Get the thumbnail key from an original image key
 */
export function getThumbnailKey(originalKey: string): string {
  const lastDot = originalKey.lastIndexOf('.');
  if (lastDot === -1) {
    return `${originalKey}_thumb`;
  }
  return `${originalKey.slice(0, lastDot)}_thumb${originalKey.slice(lastDot)}`;
}

// ============================================
// VALIDATION
// ============================================

/**
 * Validate content type is an allowed image type
 */
export function isValidImageType(contentType: string | null): contentType is AllowedImageType {
  if (!contentType) return false;
  return ALLOWED_IMAGE_TYPES.includes(contentType as AllowedImageType);
}

/**
 * Result of image upload validation
 */
export interface ImageValidationResult {
  valid: boolean;
  error?: string;
  contentType?: AllowedImageType;
  contentLength?: number;
}

/**
 * Validate image upload request headers
 * 
 * This performs preliminary validation before reading the body.
 * Full validation (including magic bytes) happens after reading the body.
 */
export function validateImageUploadHeaders(
  contentType: string | null,
  contentLength: number | null,
  maxSize: number
): ImageValidationResult {
  if (!contentType) {
    return { valid: false, error: 'Content-Type header is required' };
  }
  
  if (!isValidImageType(contentType)) {
    return {
      valid: false,
      error: `Invalid content type. Allowed: ${ALLOWED_IMAGE_TYPES.join(', ')}`,
    };
  }
  
  if (contentLength !== null && contentLength > maxSize) {
    return {
      valid: false,
      error: `File too large. Maximum size: ${Math.round(maxSize / 1024 / 1024)}MB`,
    };
  }
  
  return {
    valid: true,
    contentType,
    contentLength: contentLength ?? undefined,
  };
}

/**
 * Full validation result including magic byte check
 */
export interface FullImageValidationResult {
  valid: boolean;
  error?: string;
  contentType?: AllowedImageType;
  size?: number;
}

/**
 * Perform full validation on image data
 * 
 * This validates:
 * 1. File size (min and max)
 * 2. Magic bytes match claimed content type
 */
export function validateImageData(
  data: ArrayBuffer,
  claimedContentType: AllowedImageType,
  maxSize: number
): FullImageValidationResult {
  // Check minimum size
  if (data.byteLength < MIN_IMAGE_SIZE) {
    return {
      valid: false,
      error: 'File is too small to be a valid image',
    };
  }
  
  // Check maximum size
  if (data.byteLength > maxSize) {
    return {
      valid: false,
      error: `File too large. Maximum size: ${Math.round(maxSize / 1024 / 1024)}MB`,
    };
  }
  
  // Validate magic bytes
  const magicValidation = validateMagicBytes(data, claimedContentType);
  if (!magicValidation.valid) {
    return {
      valid: false,
      error: magicValidation.error,
    };
  }
  
  return {
    valid: true,
    contentType: claimedContentType,
    size: data.byteLength,
  };
}

// ============================================
// THUMBNAIL QUEUE (DEFERRED)
// ============================================

/**
 * Queue message for thumbnail generation
 */
export interface ThumbnailQueueMessage {
  type: 'generate_thumbnail';
  originalKey: string;
  thumbnailKey: string;
  width: number;
  height: number;
}

/**
 * Create a thumbnail queue message
 */
export function createThumbnailMessage(originalKey: string, size: number = 200): ThumbnailQueueMessage {
  return {
    type: 'generate_thumbnail',
    originalKey,
    thumbnailKey: getThumbnailKey(originalKey),
    width: size,
    height: size,
  };
}
