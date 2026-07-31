import { Hono } from 'hono';
import type { Env, Variables } from '../types/env';

const legal = new Hono<{ Bindings: Env; Variables: Variables }>();

// ============================================
// SHARED LAYOUT
// ============================================

function page(title: string, body: string): string {
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${title} — Plank Challenge</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      line-height: 1.7;
      color: #1a1a2e;
      background: #f8f9fa;
      padding: 24px 16px 64px;
      max-width: 680px;
      margin: 0 auto;
    }
    h1 { font-size: 28px; font-weight: 700; margin-bottom: 8px; }
    .updated { font-size: 14px; color: #666; margin-bottom: 32px; }
    h2 { font-size: 20px; font-weight: 600; margin: 32px 0 12px; }
    p, li { font-size: 16px; color: #333; margin-bottom: 12px; }
    ul { padding-left: 20px; margin-bottom: 16px; }
    a { color: #0066ff; text-decoration: none; }
    a:hover { text-decoration: underline; }
    .contact { background: #e9ecef; border-radius: 8px; padding: 16px; margin-top: 24px; }
  </style>
</head>
<body>
  ${body}
</body>
</html>`;
}

// ============================================
// PRIVACY POLICY
// ============================================

legal.get('/privacy', (c) => {
  const html = page('Privacy Policy', `
  <h1>Privacy Policy</h1>
  <p class="updated">Last updated: April 2026</p>

  <p>Plank Challenge ("the app", "we", "us") is a fitness application that helps you build a daily plank habit. This policy explains what information we collect, how we use it, and your rights regarding that information.</p>

  <h2>Information we collect</h2>
  <p>When you use Plank Challenge, we may collect the following:</p>
  <ul>
    <li><strong>Account information</strong> — your email address, display name, and profile photo. If you sign in with Apple or Google, we receive the basic profile information those services provide.</li>
    <li><strong>Activity data</strong> — your plank records, including duration, date, and type. This data powers your streaks, statistics, and leaderboard positions.</li>
    <li><strong>Device information</strong> — device model, operating system version, app version, and push notification tokens (if you enable reminders).</li>
    <li><strong>Usage preferences</strong> — your timezone, notification settings, and app preferences.</li>
  </ul>

  <h2>How we use your information</h2>
  <ul>
    <li>To provide and maintain the app's features, including streaks, badges, groups, and leaderboards.</li>
    <li>To send you daily plank reminders if you opt in.</li>
    <li>To authenticate your account and keep it secure.</li>
    <li>To improve the app based on general usage patterns.</li>
  </ul>
  <p>We do not sell your personal information. We do not use your data for advertising.</p>

  <h2>Third-party services</h2>
  <p>We rely on the following third-party services to operate the app:</p>
  <ul>
    <li><strong>Cloudflare</strong> — hosting, database, and file storage infrastructure.</li>
    <li><strong>Apple</strong> — authentication (Sign in with Apple) and push notifications (APNs).</li>
    <li><strong>Google</strong> — authentication (Google Sign-In).</li>
  </ul>
  <p>These services have their own privacy policies. We encourage you to review them.</p>

  <h2>Data storage and security</h2>
  <p>Your data is stored on Cloudflare's global infrastructure. We use encryption in transit (HTTPS/TLS) and follow industry-standard security practices to protect your information. However, no system is perfectly secure, and we cannot guarantee absolute security.</p>

  <h2>Data retention</h2>
  <p>We retain your data for as long as your account is active. If you delete your account, your personal data is permanently removed from our systems. Some anonymised, aggregated data may be retained for analytical purposes.</p>

  <h2>Your rights</h2>
  <p>You can:</p>
  <ul>
    <li><strong>Access</strong> your data through the app (your profile, plank history, and statistics).</li>
    <li><strong>Update</strong> your profile information at any time in the app's settings.</li>
    <li><strong>Delete</strong> your account and all associated data through the app's settings.</li>
  </ul>

  <h2>Children's privacy</h2>
  <p>Plank Challenge is not directed at children under 13. We do not knowingly collect personal information from children under 13. If you believe a child has provided us with personal information, contact us so we can remove it.</p>

  <h2>Changes to this policy</h2>
  <p>We may update this policy from time to time. When we do, we will update the "Last updated" date at the top. Continued use of the app after changes constitutes acceptance of the updated policy.</p>

  <div class="contact">
    <h2>Contact us</h2>
    <p>If you have questions about this policy or your data, contact us at <a href="mailto:petras.leonardas@gmail.com">petras.leonardas@gmail.com</a>.</p>
  </div>
  `);

  return c.html(html);
});

// ============================================
// TERMS OF SERVICE
// ============================================

legal.get('/terms', (c) => {
  const html = page('Terms of Service', `
  <h1>Terms of Service</h1>
  <p class="updated">Last updated: April 2026</p>

  <p>Welcome to Plank Challenge. By creating an account or using the app, you agree to these terms. If you do not agree, do not use the app.</p>

  <h2>Your account</h2>
  <ul>
    <li>You must provide accurate information when creating your account.</li>
    <li>You are responsible for maintaining the security of your account credentials.</li>
    <li>One account per person. Creating multiple accounts to manipulate streaks, leaderboards, or other features is not permitted.</li>
    <li>You must be at least 13 years old to use the app.</li>
  </ul>

  <h2>Acceptable use</h2>
  <p>When using Plank Challenge, you agree not to:</p>
  <ul>
    <li>Submit false or misleading plank data.</li>
    <li>Harass, abuse, or harm other users.</li>
    <li>Use offensive or inappropriate content in your profile, display name, or group names.</li>
    <li>Attempt to gain unauthorised access to other accounts or our systems.</li>
    <li>Use the app for any unlawful purpose.</li>
  </ul>

  <h2>Content and data</h2>
  <p>You retain ownership of any content you submit to the app (profile photos, display names, etc.). By submitting content, you grant us a limited licence to store, display, and distribute it as necessary to provide the service (for example, showing your profile photo to other users on a leaderboard).</p>
  <p>We reserve the right to remove content that violates these terms.</p>

  <h2>The service</h2>
  <ul>
    <li>Plank Challenge is provided "as is" without warranties of any kind.</li>
    <li>We may modify, suspend, or discontinue any part of the app at any time.</li>
    <li>We do not guarantee uninterrupted or error-free operation.</li>
    <li>Features may be added, changed, or removed as the app evolves.</li>
  </ul>

  <h2>Account termination</h2>
  <p>You may delete your account at any time through the app's settings. We may suspend or terminate accounts that violate these terms, without prior notice.</p>

  <h2>Limitation of liability</h2>
  <p>To the maximum extent permitted by law, Plank Challenge and its developer shall not be liable for any indirect, incidental, special, consequential, or punitive damages arising from your use of the app. Our total liability for any claim related to the app shall not exceed the amount you paid to use the app (which is currently nothing — the app is free).</p>

  <h2>Changes to these terms</h2>
  <p>We may update these terms from time to time. When we do, we will update the "Last updated" date at the top. Continued use of the app after changes constitutes acceptance of the updated terms.</p>

  <div class="contact">
    <h2>Contact us</h2>
    <p>If you have questions about these terms, contact us at <a href="mailto:petras.leonardas@gmail.com">petras.leonardas@gmail.com</a>.</p>
  </div>
  `);

  return c.html(html);
});

export default legal;
