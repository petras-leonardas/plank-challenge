import { Context, Next } from 'hono';
import { errors } from '../utils/response';
import type { Env, Variables } from '../types/env';

/**
 * Global error handling middleware
 * Catches unhandled errors and returns appropriate responses
 * 
 * SECURITY: Error logging is sanitized to prevent sensitive data exposure
 * - Stack traces are only logged in development
 * - Error messages are truncated to prevent log bloat
 * - Request IDs are included for correlation
 */
export async function errorMiddleware(
  c: Context<{ Bindings: Env; Variables: Variables }>,
  next: Next
) {
  try {
    await next();
  } catch (err) {
    const requestId = c.get('requestId') || 'unknown';
    const isDevelopment = c.env.ENVIRONMENT === 'development';
    
    // SECURITY: Sanitize error logging to prevent sensitive data exposure
    if (err instanceof Error) {
      // Log sanitized error info
      const sanitizedLog = {
        requestId,
        errorName: err.name,
        // Truncate message to prevent log bloat from malicious input
        errorMessage: err.message.slice(0, 500),
        // Only include stack trace in development
        stack: isDevelopment ? err.stack : undefined,
        path: c.req.path,
        method: c.req.method,
      };
      console.error('[Error]', JSON.stringify(sanitizedLog));
      
      // Check for specific error types
      if (err.message.includes('not found') || err.message.includes('NOT_FOUND')) {
        return errors.notFound(c);
      }

      if (err.message.includes('unauthorized') || err.message.includes('UNAUTHORIZED')) {
        return errors.unauthorized(c);
      }

      if (err.message.includes('forbidden') || err.message.includes('FORBIDDEN')) {
        return errors.forbidden(c);
      }

      // Return detailed error in development only
      if (isDevelopment) {
        return errors.serverError(c, err.message);
      }
    } else {
      // Non-Error objects - log minimal info
      console.error('[Error]', JSON.stringify({
        requestId,
        errorType: typeof err,
        path: c.req.path,
        method: c.req.method,
      }));
    }

    // Generic server error for production
    return errors.serverError(c);
  }
}
