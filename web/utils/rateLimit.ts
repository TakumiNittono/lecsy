// Supabase-backed rate limiting for Vercel serverless
// In-memory rate limiting doesn't work on serverless platforms because
// each invocation gets a fresh process. This uses Supabase to persist
// rate limit state across invocations.

import type { SupabaseClient } from '@supabase/supabase-js'

/**
 * Check and enforce rate limits using Supabase
 * @param supabase - Authenticated Supabase client
 * @param userId - The authenticated user's ID
 * @param action - Action identifier (e.g., "checkout", "delete_transcript")
 * @param limit - Maximum number of requests allowed in the window
 * @param windowMs - Time window in milliseconds
 */
export async function checkRateLimit(
  supabase: SupabaseClient,
  userId: string,
  action: string,
  limit: number,
  windowMs: number
): Promise<{ allowed: boolean; remaining: number }> {
  const windowStart = new Date(Date.now() - windowMs).toISOString()

  try {
    // Clean up old entries for this user+action
    await supabase
      .from('rate_limit_logs')
      .delete()
      .eq('user_id', userId)
      .eq('action', action)
      .lt('created_at', windowStart)

    // Count requests in the current window
    const { count, error } = await supabase
      .from('rate_limit_logs')
      .select('*', { count: 'exact', head: true })
      .eq('user_id', userId)
      .eq('action', action)
      .gte('created_at', windowStart)

    if (error) {
      console.error('Rate limit check failed:', error.message)
      // Fail open: allow request if DB check fails
      return { allowed: true, remaining: limit }
    }

    const currentCount = count || 0
    if (currentCount >= limit) {
      return { allowed: false, remaining: 0 }
    }

    // Record this request
    await supabase
      .from('rate_limit_logs')
      .insert({ user_id: userId, action })

    return { allowed: true, remaining: limit - currentCount - 1 }
  } catch (error) {
    console.error('Rate limit error:', error instanceof Error ? error.message : 'Unknown')
    // Fail open
    return { allowed: true, remaining: limit }
  }
}

/**
 * Create a 429 Too Many Requests response
 */
export function createRateLimitResponse(): Response {
  return new Response(
    JSON.stringify({
      error: 'Too many requests',
      message: 'Please try again later',
    }),
    {
      status: 429,
      headers: {
        'Content-Type': 'application/json',
        'Retry-After': '60',
      },
    }
  )
}
