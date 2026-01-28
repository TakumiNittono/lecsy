// 簡易レート制限（インメモリ）
// 本番環境では Upstash Redis を使用することを推奨

interface RateLimitEntry {
  count: number
  resetAt: number
}

const cache = new Map<string, RateLimitEntry>()

// キャッシュのクリーンアップ（定期的に実行）
function cleanupCache(): void {
  const now = Date.now()
  for (const [key, entry] of cache.entries()) {
    if (entry.resetAt < now) {
      cache.delete(key)
    }
  }
}

// 5分ごとにクリーンアップ
if (typeof setInterval !== 'undefined') {
  setInterval(cleanupCache, 5 * 60 * 1000)
}

/**
 * レート制限をチェック
 */
export function checkRateLimit(
  key: string,
  limit: number,
  windowMs: number
): { allowed: boolean; remaining: number; resetAt: number } {
  const now = Date.now()
  const entry = cache.get(key)
  
  // エントリがない、または期限切れの場合
  if (!entry || entry.resetAt < now) {
    const resetAt = now + windowMs
    cache.set(key, { count: 1, resetAt })
    return { allowed: true, remaining: limit - 1, resetAt }
  }
  
  // 制限内の場合
  if (entry.count < limit) {
    entry.count++
    return { allowed: true, remaining: limit - entry.count, resetAt: entry.resetAt }
  }
  
  // 制限超過
  return { allowed: false, remaining: 0, resetAt: entry.resetAt }
}

/**
 * クライアントの識別子を取得
 */
export function getClientIdentifier(request: Request, userId?: string): string {
  // 認証済みユーザーはユーザーIDを使用
  if (userId) {
    return `user:${userId}`
  }
  
  // 未認証ユーザーはIPアドレスを使用
  const forwarded = request.headers.get('x-forwarded-for')
  const ip = forwarded?.split(',')[0].trim() || 
             request.headers.get('x-real-ip') || 
             'unknown'
  
  return `ip:${ip}`
}

/**
 * レート制限のレスポンスを作成
 */
export function createRateLimitResponse(remaining: number, reset: number) {
  return new Response(
    JSON.stringify({
      error: 'Too many requests',
      message: 'Please try again later',
      retryAfter: Math.ceil((reset - Date.now()) / 1000),
    }),
    {
      status: 429,
      headers: {
        'Content-Type': 'application/json',
        'X-RateLimit-Remaining': String(remaining),
        'X-RateLimit-Reset': String(reset),
        'Retry-After': String(Math.ceil((reset - Date.now()) / 1000)),
      },
    }
  )
}
