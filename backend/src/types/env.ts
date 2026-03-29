/**
 * Environment bindings for Cloudflare Workers
 */
export interface Env {
  // D1 Database
  DB: D1Database;
  
  // KV Namespaces
  SESSIONS: KVNamespace;
  CACHE: KVNamespace;
  RATE_LIMIT: KVNamespace;
  
  // R2 Bucket
  MEDIA: R2Bucket;
  
  // Queues
  BADGE_QUEUE: Queue;
  NOTIFICATION_QUEUE: Queue;
  
  // Environment variables
  ENVIRONMENT: string;
  API_VERSION: string;
  MEDIA_BASE_URL: string;
  
  // Secrets (set via wrangler secret)
  JWT_SECRET: string;
  
  // OAuth Client IDs (set via wrangler secret)
  // Required for production, optional for development (dev bypass enabled)
  APPLE_CLIENT_ID?: string;   // Your iOS app Bundle ID (e.g., "com.plankchallenge.app")
  GOOGLE_CLIENT_ID?: string;  // Your Google OAuth Client ID

  // APNs secrets (set via wrangler secret put)
  APNS_KEY_ID: string;        // 10-char key ID from Apple Developer portal
  APNS_TEAM_ID: string;       // 10-char Apple Developer Team ID
  APNS_BUNDLE_ID: string;     // iOS app bundle ID (com.leo.PlankChallenge)
  APNS_PRIVATE_KEY: string;   // Full contents of the .p8 private key file
}

/**
 * Variables available in Hono context
 */
export interface Variables {
  userId?: string;
  requestId: string;
}
