import { Context, Next } from 'hono';
import type { Env, Variables } from '../types/env';

/**
 * Request logging middleware
 * Generates request ID and logs request details
 */
export async function loggerMiddleware(
  c: Context<{ Bindings: Env; Variables: Variables }>,
  next: Next
) {
  const requestId = crypto.randomUUID();
  c.set('requestId', requestId);

  const start = Date.now();
  const method = c.req.method;
  const path = c.req.path;
  const userAgent = c.req.header('User-Agent') || 'unknown';

  console.log(`[${requestId}] --> ${method} ${path}`);

  await next();

  const duration = Date.now() - start;
  const status = c.res.status;

  console.log(`[${requestId}] <-- ${method} ${path} ${status} ${duration}ms`);
}
