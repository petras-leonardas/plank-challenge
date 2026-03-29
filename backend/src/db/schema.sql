-- Plank Challenge Database Schema
-- Version: 1.0
-- Database: Cloudflare D1 (SQLite)

-- ============================================
-- USERS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY,
    email TEXT UNIQUE NOT NULL,
    email_verified INTEGER DEFAULT 0 CHECK (email_verified IN (0, 1)),
    display_name TEXT NOT NULL CHECK (length(display_name) >= 1 AND length(display_name) <= 100),
    username TEXT UNIQUE CHECK (username IS NULL OR (length(username) >= 3 AND length(username) <= 30)),
    location TEXT CHECK (location IS NULL OR length(location) <= 100),
    bio TEXT CHECK (bio IS NULL OR length(bio) <= 500),
    profile_image_url TEXT,
    
    -- Auth providers
    apple_id TEXT UNIQUE,
    google_id TEXT UNIQUE,
    password_hash TEXT,
    
    -- Plank preferences (matches code: 'elbow', 'straightArm', 'parallettes')
    preferred_plank_type TEXT DEFAULT 'elbow' CHECK (preferred_plank_type IN ('elbow', 'straightArm', 'parallettes')),
    
    -- Streak data (denormalized for performance)
    current_streak INTEGER DEFAULT 0 CHECK (current_streak >= 0),
    longest_streak INTEGER DEFAULT 0 CHECK (longest_streak >= 0),
    freeze_tokens INTEGER DEFAULT 2 CHECK (freeze_tokens >= 0 AND freeze_tokens <= 10),
    last_plank_date TEXT,
    last_freeze_date TEXT,  -- Tracks when freeze was last used (separate from plank)
    
    -- Stats (denormalized)
    total_planks INTEGER DEFAULT 0 CHECK (total_planks >= 0),
    total_plank_seconds REAL DEFAULT 0 CHECK (total_plank_seconds >= 0),
    longest_plank_seconds REAL DEFAULT 0 CHECK (longest_plank_seconds >= 0 AND longest_plank_seconds <= 86400),
    
    -- Social counts (denormalized)
    follower_count INTEGER DEFAULT 0 CHECK (follower_count >= 0),
    following_count INTEGER DEFAULT 0 CHECK (following_count >= 0),
    
    -- Metadata
    timezone TEXT DEFAULT 'UTC',
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    deleted_at TEXT
);

CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
CREATE INDEX IF NOT EXISTS idx_users_apple_id ON users(apple_id);
CREATE INDEX IF NOT EXISTS idx_users_google_id ON users(google_id);
CREATE INDEX IF NOT EXISTS idx_users_current_streak ON users(current_streak DESC);
CREATE INDEX IF NOT EXISTS idx_users_longest_streak ON users(longest_streak DESC);
-- Index for period-filtered leaderboards (users who planked recently)
CREATE INDEX IF NOT EXISTS idx_users_last_plank_date ON users(last_plank_date);
-- Indexes for leaderboard sorting
CREATE INDEX IF NOT EXISTS idx_users_total_planks ON users(total_planks DESC);
CREATE INDEX IF NOT EXISTS idx_users_total_plank_seconds ON users(total_plank_seconds DESC);
CREATE INDEX IF NOT EXISTS idx_users_longest_plank_seconds ON users(longest_plank_seconds DESC);

-- ============================================
-- PLANK SESSIONS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS plank_sessions (
    id TEXT PRIMARY KEY,
    client_id TEXT UNIQUE NOT NULL,
    user_id TEXT NOT NULL,
    
    -- Duration must be positive and less than 24 hours (reasonable sanity check)
    duration_seconds REAL NOT NULL CHECK (duration_seconds > 0 AND duration_seconds <= 86400),
    -- Plank types (matches planks.ts validation)
    plank_type TEXT NOT NULL CHECK (plank_type IN ('elbow', 'high', 'side_left', 'side_right', 'reverse')),
    -- Input method (matches planks.ts: 'timer', 'manual', 'watch')
    input_method TEXT NOT NULL CHECK (input_method IN ('timer', 'manual', 'watch')),
    
    performed_at TEXT NOT NULL,
    timezone TEXT NOT NULL,
    
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    deleted_at TEXT,
    
    FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE INDEX IF NOT EXISTS idx_sessions_user_date ON plank_sessions(user_id, performed_at);
CREATE INDEX IF NOT EXISTS idx_sessions_client_id ON plank_sessions(client_id);
CREATE INDEX IF NOT EXISTS idx_sessions_user_id ON plank_sessions(user_id);
-- Index for sync endpoint: queries by user_id + updated_at
CREATE INDEX IF NOT EXISTS idx_sessions_user_updated ON plank_sessions(user_id, updated_at);
-- Index for date-based queries (leaderboards, stats)
CREATE INDEX IF NOT EXISTS idx_sessions_performed_at ON plank_sessions(performed_at);
-- Index for soft-delete filtering (most queries filter on deleted_at IS NULL)
CREATE INDEX IF NOT EXISTS idx_sessions_deleted_at ON plank_sessions(deleted_at);

-- ============================================
-- BADGES TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS badges (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    badge_type TEXT NOT NULL,
    earned_at TEXT NOT NULL,
    
    UNIQUE(user_id, badge_type),
    FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE INDEX IF NOT EXISTS idx_badges_user_id ON badges(user_id);

-- ============================================
-- GROUPS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS groups (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL CHECK (length(name) >= 1 AND length(name) <= 100),
    description TEXT CHECK (description IS NULL OR length(description) <= 500),
    image_url TEXT,
    
    -- Group type (matches groups.ts: 'public', 'private')
    group_type TEXT NOT NULL CHECK (group_type IN ('public', 'private')),
    -- Join mode (matches groups.ts: 'open', 'request')
    join_mode TEXT NOT NULL CHECK (join_mode IN ('open', 'request')),
    
    created_by TEXT NOT NULL,
    
    member_count INTEGER DEFAULT 1 CHECK (member_count >= 0),
    invite_code TEXT UNIQUE,
    
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    deleted_at TEXT,
    
    FOREIGN KEY (created_by) REFERENCES users(id)
);

CREATE INDEX IF NOT EXISTS idx_groups_type ON groups(group_type);
CREATE INDEX IF NOT EXISTS idx_groups_invite_code ON groups(invite_code);
CREATE INDEX IF NOT EXISTS idx_groups_created_by ON groups(created_by);

-- ============================================
-- GROUP MEMBERS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS group_members (
    id TEXT PRIMARY KEY,
    group_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    
    role TEXT NOT NULL DEFAULT 'member' CHECK (role IN ('owner', 'admin', 'member')),
    -- Status (matches groups.ts: 'active', 'banned')
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'banned')),
    
    joined_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    
    UNIQUE(group_id, user_id),
    FOREIGN KEY (group_id) REFERENCES groups(id),
    FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE INDEX IF NOT EXISTS idx_group_members_group ON group_members(group_id);
CREATE INDEX IF NOT EXISTS idx_group_members_user ON group_members(user_id);
CREATE INDEX IF NOT EXISTS idx_group_members_status ON group_members(group_id, status);

-- ============================================
-- FOLLOWS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS follows (
    id TEXT PRIMARY KEY,
    follower_id TEXT NOT NULL,
    following_id TEXT NOT NULL,
    created_at TEXT NOT NULL,
    
    UNIQUE(follower_id, following_id),
    -- Prevent self-follow at database level (also enforced in code)
    CHECK (follower_id != following_id),
    FOREIGN KEY (follower_id) REFERENCES users(id),
    FOREIGN KEY (following_id) REFERENCES users(id)
);

CREATE INDEX IF NOT EXISTS idx_follows_follower ON follows(follower_id);
CREATE INDEX IF NOT EXISTS idx_follows_following ON follows(following_id);

-- ============================================
-- NOTIFICATIONS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS notifications (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    
    -- Notification types (matches NotificationType in api.ts)
    type TEXT NOT NULL CHECK (type IN (
        'badge_earned',
        'streak_at_risk',
        'streak_broken',
        'streak_milestone',
        'freeze_reminder',
        'group_invite',
        'group_joined',
        'group_join_request',
        'group_promoted',
        'group_removed',
        'group_banned',
        'group_request_denied',
        'follow',
        'system'
    )),
    title TEXT NOT NULL CHECK (length(title) >= 1 AND length(title) <= 200),
    message TEXT NOT NULL CHECK (length(message) >= 1 AND length(message) <= 1000),
    
    related_entity_type TEXT CHECK (related_entity_type IS NULL OR related_entity_type IN ('user', 'group', 'plank', 'badge', 'join_request')),
    related_entity_id TEXT,
    -- Profile image URL of the person who triggered the notification (follower, new member, etc.)
    actor_image_url TEXT,
    
    is_read INTEGER DEFAULT 0 CHECK (is_read IN (0, 1)),
    
    created_at TEXT NOT NULL,
    
    FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_unread ON notifications(user_id, is_read);
-- Index for cleanup: delete oldest read notifications first
CREATE INDEX IF NOT EXISTS idx_notifications_cleanup ON notifications(user_id, is_read DESC, created_at ASC);

-- ============================================
-- DEVICES TABLE (Push Notifications)
-- ============================================
CREATE TABLE IF NOT EXISTS devices (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    
    device_token TEXT NOT NULL CHECK (length(device_token) >= 10),
    platform TEXT NOT NULL CHECK (platform IN ('ios', 'android', 'web')),
    
    app_version TEXT,
    os_version TEXT,
    device_model TEXT,
    
    last_active_at TEXT NOT NULL,
    created_at TEXT NOT NULL,
    
    UNIQUE(device_token),
    FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE INDEX IF NOT EXISTS idx_devices_user ON devices(user_id);
CREATE INDEX IF NOT EXISTS idx_devices_token ON devices(device_token);

-- ============================================
-- JOIN REQUESTS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS join_requests (
    id TEXT PRIMARY KEY,
    group_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    
    -- Status (matches groups.ts: 'pending', 'approved', 'denied')
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'denied')),
    reviewed_by TEXT,
    reviewed_at TEXT,
    
    created_at TEXT NOT NULL,
    
    UNIQUE(group_id, user_id),
    FOREIGN KEY (group_id) REFERENCES groups(id),
    FOREIGN KEY (user_id) REFERENCES users(id),
    FOREIGN KEY (reviewed_by) REFERENCES users(id)
);

CREATE INDEX IF NOT EXISTS idx_join_requests_group ON join_requests(group_id, status);
