/**
 * Standard API response types
 */

export interface ApiResponse<T = unknown> {
  success: true;
  data: T;
  meta: ResponseMeta;
}

export interface ApiError {
  success: false;
  error: {
    code: ErrorCode;
    message: string;
    details?: Record<string, unknown>;
  };
  meta: ResponseMeta;
}

export interface ResponseMeta {
  timestamp: string;
  requestId: string;
}

export type ErrorCode =
  | 'AUTH_REQUIRED'
  | 'AUTH_EXPIRED'
  | 'AUTH_INVALID'
  | 'FORBIDDEN'
  | 'NOT_FOUND'
  | 'VALIDATION_ERROR'
  | 'RATE_LIMITED'
  | 'SERVER_ERROR'
  | 'CONFLICT'
  | 'PLANK_DELETE_FORBIDDEN'
  | 'GROUP_FULL'
  | 'ALREADY_MEMBER';

/**
 * User types
 */
export interface User {
  id: string;
  email: string;
  emailVerified: boolean;
  displayName: string;
  username: string | null;
  location: string | null;
  bio: string | null;
  profileImageUrl: string | null;
  preferredPlankType: PlankType;
  currentStreak: number;
  longestStreak: number;
  freezeTokens: number;
  lastPlankDate: string | null;
  totalPlanks: number;
  totalPlankSeconds: number;
  longestPlankSeconds: number;
  followerCount: number;
  followingCount: number;
  timezone: string;
  createdAt: string;
  updatedAt: string;
}

export interface PublicUser {
  id: string;
  displayName: string;
  username: string | null;
  profileImageUrl: string | null;
  currentStreak: number;
  longestStreak: number;
  totalPlanks: number;
  longestPlankSeconds: number;
  followerCount: number;
  followingCount: number;
  isFollowing?: boolean;
}

export type PlankType = 'elbow' | 'straightArm' | 'parallettes';
export type InputMethod = 'timer' | 'manual';

/**
 * Plank session types
 */
export interface PlankSession {
  id: string;
  clientId: string;
  userId: string;
  durationSeconds: number;
  plankType: PlankType;
  inputMethod: InputMethod;
  performedAt: string;
  timezone: string;
  createdAt: string;
  updatedAt: string;
}

/**
 * Badge types
 */
export type BadgeType = 
  | 'streak7'
  | 'streak14'
  | 'streak30'
  | 'streak60'
  | 'streak90'
  | 'streak180'
  | 'streak365';

export interface Badge {
  id: string;
  userId: string;
  badgeType: BadgeType;
  earnedAt: string;
}

/**
 * Auth types
 */
export interface AuthTokens {
  accessToken: string;
  refreshToken: string;
  expiresIn: number;
}

export interface JwtPayload {
  sub: string;
  email?: string;           // Only present in access tokens
  type?: 'refresh';         // Only present in refresh tokens
  iat: number;
  exp: number;
  jti: string;
}

export interface AppleAuthRequest {
  identityToken: string;
  authorizationCode: string;
  user?: {
    email?: string;
    name?: {
      firstName?: string;
      lastName?: string;
    };
  };
}

export interface GoogleAuthRequest {
  idToken: string;
}

export interface EmailRegisterRequest {
  email: string;
  password: string;
  displayName: string;
}

export interface EmailLoginRequest {
  email: string;
  password: string;
}

// ============================================
// DATABASE RECORD TYPES
// ============================================
// These types represent the raw data from D1 database queries.
// Use these instead of defining record types locally in each route file.

/**
 * Raw user record from the users table
 */
export interface UserRecord {
  id: string;
  email: string;
  email_verified: number;
  display_name: string;
  username: string | null;
  location: string | null;
  bio: string | null;
  profile_image_url: string | null;
  apple_id: string | null;
  google_id: string | null;
  password_hash: string | null;
  preferred_plank_type: string;
  plank_goal_seconds: number | null;
  current_streak: number;
  longest_streak: number;
  freeze_tokens: number;
  last_plank_date: string | null;
  last_freeze_date: string | null;
  total_planks: number;
  total_plank_seconds: number;
  longest_plank_seconds: number;
  follower_count: number;
  following_count: number;
  reminder_enabled: number;
  reminder_time: string;
  timezone: string;
  created_at: string;
  updated_at: string;
  deleted_at: string | null;
}

/**
 * Raw plank session record from the plank_sessions table
 */
export interface PlankRecord {
  id: string;
  client_id: string;
  user_id: string;
  duration_seconds: number;
  plank_type: string;
  input_method: string;
  performed_at: string;
  timezone: string;
  created_at: string;
  updated_at: string;
  deleted_at: string | null;
}

/**
 * Raw badge record from the badges table
 */
export interface BadgeRecord {
  id: string;
  user_id: string;
  badge_type: string;
  earned_at: string;
}

/**
 * Raw notification record from the notifications table
 */
export interface NotificationRecord {
  id: string;
  user_id: string;
  type: string;
  title: string;
  message: string;
  related_entity_type: string | null;
  related_entity_id: string | null;
  actor_image_url: string | null;
  is_read: number;
  created_at: string;
}

/**
 * Raw group record from the groups table
 */
export interface GroupRecord {
  id: string;
  name: string;
  description: string | null;
  image_url: string | null;
  group_type: string;
  join_mode: string;
  created_by: string;
  member_count: number;
  invite_code: string | null;
  created_at: string;
  updated_at: string;
  deleted_at: string | null;
}

/**
 * Raw group member record from the group_members table
 */
export interface GroupMemberRecord {
  id: string;
  group_id: string;
  user_id: string;
  role: string;
  status: string;
  joined_at: string;
  updated_at: string;
}

/**
 * Raw follow record from the follows table
 */
export interface FollowRecord {
  id: string;
  follower_id: string;
  following_id: string;
  created_at: string;
}

/**
 * Raw device record from the devices table
 */
export interface DeviceRecord {
  id: string;
  user_id: string;
  device_token: string;
  platform: string;
  app_version: string | null;
  os_version: string | null;
  device_model: string | null;
  last_active_at: string;
  created_at: string;
}

/**
 * Raw join request record from the join_requests table
 */
export interface JoinRequestRecord {
  id: string;
  group_id: string;
  user_id: string;
  status: string;
  reviewed_by: string | null;
  reviewed_at: string | null;
  created_at: string;
}

// ============================================
// FORMATTED RESPONSE TYPES
// ============================================
// These types represent the formatted/camelCase data returned in API responses.

/**
 * Formatted plank session for API responses
 */
export interface FormattedPlank {
  id: string;
  clientId: string;
  durationSeconds: number;
  plankType: string;
  inputMethod: string;
  performedAt: string;
  timezone: string;
  createdAt: string;
  updatedAt: string;
  deletedAt: string | null;
}

/**
 * Formatted badge for API responses
 */
export interface FormattedBadge {
  id: string;
  type: string;
  name: string;
  description: string;
  category: BadgeCategory;
  icon: string;
  earnedAt: string;
}

/**
 * Formatted notification for API responses
 */
export interface FormattedNotification {
  id: string;
  type: string;
  title: string;
  message: string;
  relatedEntity: {
    type: string;
    id: string;
  } | null;
  actorImageUrl: string | null;
  isRead: boolean;
  createdAt: string;
}

// ============================================
// NOTIFICATION TYPES
// ============================================

export type NotificationType =
  | 'badge_earned'
  | 'streak_at_risk'
  | 'streak_broken'
  | 'streak_milestone'
  | 'freeze_reminder'
  | 'group_invite'
  | 'group_joined'
  | 'group_join_request'
  | 'group_promoted'
  | 'group_removed'
  | 'group_banned'
  | 'group_request_denied'
  | 'follow'
  | 'system';

// ============================================
// BADGE CATEGORY TYPE
// ============================================

export type BadgeCategory = 'streak' | 'count' | 'duration' | 'special';
