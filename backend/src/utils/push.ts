/**
 * APNs Silent Push Utility
 *
 * Sends a content-available silent push to all registered devices for a user.
 * Silent pushes (no alert, no sound, content-available: 1) wake the app in the
 * background so it can fetch fresh data and update the UI without the user
 * having to pull-to-refresh.
 *
 * Payload shape:
 *   { aps: { "content-available": 1 }, refreshType: ["notifications", "groups", ...] }
 *
 * The `refreshType` array tells the iOS app which data to re-fetch. Multiple
 * types can be combined in a single push to avoid redundant wakeups. Supported
 * values (iOS reads these in AppDelegate):
 *   "notifications" — re-fetch unread count + notification list
 *   "groups"        — re-fetch the user's group list
 *   "leaderboard"   — re-fetch the global leaderboard
 *   "badges"        — re-fetch earned badges
 *   "planks"        — re-fetch today's plank state
 *
 * Auth uses a JWT signed with ES256 (provider token auth — no per-device cert needed).
 * The jose library handles JWT signing; it's already a project dependency.
 *
 * APNs HTTP/2 endpoint:
 *   Production:  https://api.push.apple.com/3/device/:token
 *   Development: https://api.sandbox.push.apple.com/3/device/:token
 *
 * We use the production endpoint because the key was created as
 * "Production and Sandbox" and iOS routes correctly based on the app build.
 * For Debug builds (installed via Xcode/devicectl), APNs automatically uses
 * the sandbox — so we must call the sandbox endpoint for dev builds.
 * We detect this via the ENVIRONMENT variable.
 */

import { SignJWT, importPKCS8 } from 'jose';
import type { Env } from '../types/env';

/**
 * Promise-based JWT cache — prevents concurrent callers within the same isolate
 * from all signing a new JWT simultaneously (cache stampede). Any caller that
 * arrives while signing is in progress will await the same Promise rather than
 * starting a second signing operation.
 *
 * Note: Cloudflare Workers run in isolates, so this cache is per-isolate, not
 * shared across all Workers instances. Each cold-start will re-sign once, which
 * is fine — the cost is negligible and the cache helps for warm requests.
 */
let jwtPromise: Promise<string> | null = null;
let jwtExpiry: number = 0;

async function getApnsJwt(env: Env): Promise<string> {
  const now = Date.now();
  // Reuse the cached Promise if it hasn't expired
  if (jwtPromise && now < jwtExpiry) {
    return jwtPromise;
  }

  // Set the expiry immediately so concurrent callers reuse this Promise
  // rather than each starting their own signing operation
  jwtExpiry = now + 45 * 60 * 1000; // 45 min (APNs JWTs valid for 60 min)

  jwtPromise = (async () => {
    const privateKey = await importPKCS8(env.APNS_PRIVATE_KEY, 'ES256');
    return new SignJWT({})
      .setProtectedHeader({ alg: 'ES256', kid: env.APNS_KEY_ID })
      .setIssuer(env.APNS_TEAM_ID)
      .setIssuedAt()
      .sign(privateKey);
  })();

  return jwtPromise;
}

/**
 * Sends a typed silent push notification to all registered devices for a user.
 * Fires and forgets — errors are logged but never thrown.
 *
 * @param env          Worker environment (needs APNS_* secrets + DB)
 * @param userId       The recipient's user ID
 * @param refreshTypes Which data the iOS app should re-fetch on receipt.
 *                     Defaults to ["notifications"] for backwards compatibility.
 */
export async function sendSilentPush(
  env: Env,
  userId: string,
  refreshTypes: string[] = ['notifications'],
): Promise<void> {
  try {
    // Fetch all device tokens for this user
    const result = await env.DB
      .prepare('SELECT id, device_token FROM devices WHERE user_id = ? ORDER BY last_active_at DESC')
      .bind(userId)
      .all<{ id: string; device_token: string }>();

    const devices = result.results || [];
    if (devices.length === 0) return;

    const jwt = await getApnsJwt(env);

    // Use sandbox for development builds, production for everything else
    const apnsHost = env.ENVIRONMENT === 'development'
      ? 'api.sandbox.push.apple.com'
      : 'api.push.apple.com';

    const payload = JSON.stringify({
      aps: {
        'content-available': 1,
      },
      refreshType: refreshTypes,
    });

    // Send to all devices concurrently
    await Promise.allSettled(devices.map(async (device) => {
      const url = `https://${apnsHost}/3/device/${device.device_token}`;

      const response = await fetch(url, {
        method: 'POST',
        headers: {
          'authorization': `bearer ${jwt}`,
          'apns-topic': env.APNS_BUNDLE_ID,
          'apns-push-type': 'background',
          'apns-priority': '5',  // 5 = normal priority for background/silent pushes
          'content-type': 'application/json',
        },
        body: payload,
      });

      if (response.status === 410) {
        // Token is no longer valid — remove from DB to keep the table clean
        await env.DB
          .prepare('DELETE FROM devices WHERE id = ?')
          .bind(device.id)
          .run();
        console.log(`[APNs] Removed stale device token for user ${userId}`);
      } else if (!response.ok) {
        const body = await response.text().catch(() => '');
        console.error(`[APNs] Push failed for device ${device.id}: ${response.status} ${body}`);
      }
    }));
  } catch (err) {
    // Never let push failures affect the main request flow
    console.error('[APNs] sendSilentPush error:', err);
  }
}
