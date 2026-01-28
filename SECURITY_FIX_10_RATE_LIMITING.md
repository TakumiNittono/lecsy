# セキュリティ修正 #10: レート制限の実装

**重要度**: 高  
**対象ファイル**: 
- `web/middleware.ts`
- `supabase/functions/` 配下のEdge Functions

**推定作業時間**: 45分

---

## 現状の問題

APIルートやEdge Functionsにレート制限が実装されておらず、ブルートフォース攻撃やDoS攻撃に対する防御がありません。

---

## 修正手順（Web アプリ）

### Step 1: Upstash Redis のセットアップ

Vercel Edge でレート制限を実装するには Upstash Redis を使用します。

1. [Upstash](https://upstash.com/) でアカウント作成
2. 新しい Redis データベースを作成
3. 接続情報を取得

```bash
# 環境変数を設定
UPSTASH_REDIS_REST_URL=https://xxx.upstash.io
UPSTASH_REDIS_REST_TOKEN=xxx
```

---

### Step 2: パッケージのインストール

```bash
cd web
npm install @upstash/redis @upstash/ratelimit
```

---

### Step 3: レート制限ユーティリティの作成

新規ファイル: `web/utils/rateLimit.ts`

```typescript
import { Ratelimit } from '@upstash/ratelimit';
import { Redis } from '@upstash/redis';

// Redisクライアントの初期化
const redis = new Redis({
  url: process.env.UPSTASH_REDIS_REST_URL!,
  token: process.env.UPSTASH_REDIS_REST_TOKEN!,
});

/**
 * API レート制限
 * - 1分間に30リクエストまで
 */
export const apiRateLimiter = new Ratelimit({
  redis,
  limiter: Ratelimit.slidingWindow(30, '1 m'),
  analytics: true,
  prefix: 'ratelimit:api',
});

/**
 * 認証 レート制限（ログイン試行など）
 * - 5分間に10リクエストまで
 */
export const authRateLimiter = new Ratelimit({
  redis,
  limiter: Ratelimit.slidingWindow(10, '5 m'),
  analytics: true,
  prefix: 'ratelimit:auth',
});

/**
 * 厳格なレート制限（削除操作など）
 * - 1時間に20リクエストまで
 */
export const strictRateLimiter = new Ratelimit({
  redis,
  limiter: Ratelimit.slidingWindow(20, '1 h'),
  analytics: true,
  prefix: 'ratelimit:strict',
});

/**
 * AI要約のレート制限
 * - 1日20回まで
 */
export const aiRateLimiter = new Ratelimit({
  redis,
  limiter: Ratelimit.fixedWindow(20, '1 d'),
  analytics: true,
  prefix: 'ratelimit:ai',
});

/**
 * クライアントの識別子を取得
 */
export function getClientIdentifier(request: Request, userId?: string): string {
  // 認証済みユーザーはユーザーIDを使用
  if (userId) {
    return `user:${userId}`;
  }
  
  // 未認証ユーザーはIPアドレスを使用
  const forwarded = request.headers.get('x-forwarded-for');
  const ip = forwarded?.split(',')[0].trim() || 
             request.headers.get('x-real-ip') || 
             'unknown';
  
  return `ip:${ip}`;
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
  );
}
```

---

### Step 4: middleware.ts の修正

```typescript
import { type NextRequest, NextResponse } from 'next/server'
import { updateSession } from '@/utils/supabase/middleware'
import { apiRateLimiter, getClientIdentifier, createRateLimitResponse } from '@/utils/rateLimit'

// レート制限をスキップするパス
const RATE_LIMIT_EXEMPT = [
  '/_next',
  '/favicon.ico',
  '/api/stripe-webhook',  // Stripe Webhookは独自のレート制限を持つ
];

export async function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl;
  
  // 静的ファイルなどはスキップ
  if (RATE_LIMIT_EXEMPT.some(path => pathname.startsWith(path))) {
    return NextResponse.next();
  }
  
  // APIルートにはレート制限を適用
  if (pathname.startsWith('/api/')) {
    const identifier = getClientIdentifier(request);
    const { success, remaining, reset } = await apiRateLimiter.limit(identifier);
    
    if (!success) {
      return createRateLimitResponse(remaining, reset);
    }
    
    // レート制限情報をヘッダーに追加
    const response = NextResponse.next();
    response.headers.set('X-RateLimit-Remaining', String(remaining));
    response.headers.set('X-RateLimit-Reset', String(reset));
    return response;
  }
  
  return await updateSession(request);
}

export const config = {
  matcher: [
    '/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)',
  ],
}
```

---

### Step 5: 削除APIに厳格なレート制限を追加

`web/app/api/transcripts/[id]/route.ts`:

```typescript
import { strictRateLimiter, getClientIdentifier } from '@/utils/rateLimit'

export async function DELETE(request: NextRequest, ...) {
  // 認証チェック
  const { user, error: authError } = await authenticateRequest();
  if (authError) return authError;

  // 厳格なレート制限
  const identifier = getClientIdentifier(request, user!.id);
  const { success, remaining, reset } = await strictRateLimiter.limit(identifier);
  
  if (!success) {
    return new NextResponse(
      JSON.stringify({
        error: 'Rate limit exceeded',
        message: 'You have reached the maximum number of delete operations. Please try again later.',
        retryAfter: Math.ceil((reset - Date.now()) / 1000),
      }),
      {
        status: 429,
        headers: {
          'Content-Type': 'application/json',
          'Retry-After': String(Math.ceil((reset - Date.now()) / 1000)),
        },
      }
    );
  }

  // ... 削除処理
}
```

---

## 修正手順（Edge Functions）

### Step 1: Supabase Edge Functions 用のレート制限

新規ファイル: `supabase/functions/_shared/rateLimit.ts`

```typescript
// supabase/functions/_shared/rateLimit.ts

interface RateLimitEntry {
  count: number;
  resetAt: number;
}

// インメモリキャッシュ（Edge Functionインスタンス内）
const cache = new Map<string, RateLimitEntry>();

/**
 * シンプルなインメモリレート制限
 * 注意: Edge Functionはステートレスなため、分散環境では完全ではありません
 * 本番環境ではRedisなどの外部ストレージを使用することを推奨
 */
export function checkRateLimit(
  key: string,
  limit: number,
  windowMs: number
): { allowed: boolean; remaining: number; resetAt: number } {
  const now = Date.now();
  const entry = cache.get(key);
  
  // エントリがない、または期限切れの場合
  if (!entry || entry.resetAt < now) {
    const resetAt = now + windowMs;
    cache.set(key, { count: 1, resetAt });
    return { allowed: true, remaining: limit - 1, resetAt };
  }
  
  // 制限内の場合
  if (entry.count < limit) {
    entry.count++;
    return { allowed: true, remaining: limit - entry.count, resetAt: entry.resetAt };
  }
  
  // 制限超過
  return { allowed: false, remaining: 0, resetAt: entry.resetAt };
}

/**
 * ユーザーIDベースのレート制限
 */
export function userRateLimit(
  userId: string,
  limit: number = 60,
  windowMs: number = 60000  // 1分
): { allowed: boolean; remaining: number; resetAt: number } {
  return checkRateLimit(`user:${userId}`, limit, windowMs);
}

/**
 * IPベースのレート制限
 */
export function ipRateLimit(
  request: Request,
  limit: number = 30,
  windowMs: number = 60000
): { allowed: boolean; remaining: number; resetAt: number } {
  const ip = request.headers.get('x-forwarded-for')?.split(',')[0].trim() || 'unknown';
  return checkRateLimit(`ip:${ip}`, limit, windowMs);
}

/**
 * キャッシュのクリーンアップ（定期的に呼び出す）
 */
export function cleanupCache(): void {
  const now = Date.now();
  for (const [key, entry] of cache.entries()) {
    if (entry.resetAt < now) {
      cache.delete(key);
    }
  }
}
```

---

### Step 2: summarize/index.ts にレート制限を追加

```typescript
import { userRateLimit } from '../_shared/rateLimit.ts';
import { createErrorResponse } from '../_shared/cors.ts';

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return createPreflightResponse(req);
  }

  try {
    // ... 認証チェック ...

    // レート制限チェック
    const { allowed, remaining, resetAt } = userRateLimit(user.id, 20, 86400000); // 1日20回
    
    if (!allowed) {
      const retryAfter = Math.ceil((resetAt - Date.now()) / 1000);
      return new Response(
        JSON.stringify({
          error: "Rate limit exceeded",
          code: "RATE_LIMIT",
          retryAfter,
        }),
        {
          status: 429,
          headers: {
            "Content-Type": "application/json",
            "Retry-After": String(retryAfter),
            "X-RateLimit-Remaining": String(remaining),
          },
        }
      );
    }

    // ... 処理続行 ...
  } catch (error) {
    // ...
  }
});
```

---

### Step 3: Supabase + Upstash Redis の統合（推奨）

より堅牢なレート制限が必要な場合:

```typescript
// supabase/functions/_shared/rateLimitRedis.ts

import { Redis } from 'https://esm.sh/@upstash/redis';
import { Ratelimit } from 'https://esm.sh/@upstash/ratelimit';

const redis = new Redis({
  url: Deno.env.get('UPSTASH_REDIS_REST_URL')!,
  token: Deno.env.get('UPSTASH_REDIS_REST_TOKEN')!,
});

export const apiRateLimiter = new Ratelimit({
  redis,
  limiter: Ratelimit.slidingWindow(30, '1 m'),
  prefix: 'ratelimit:edge',
});

export async function checkEdgeRateLimit(
  identifier: string
): Promise<{ allowed: boolean; remaining: number; reset: number }> {
  const result = await apiRateLimiter.limit(identifier);
  return {
    allowed: result.success,
    remaining: result.remaining,
    reset: result.reset,
  };
}
```

---

## 確認チェックリスト

- [ ] Upstash Redis をセットアップ
- [ ] `@upstash/redis` と `@upstash/ratelimit` をインストール
- [ ] `utils/rateLimit.ts` を作成
- [ ] `middleware.ts` にレート制限を追加
- [ ] 削除APIに厳格なレート制限を追加
- [ ] Edge Functions 用のレート制限を作成
- [ ] `summarize` 関数にレート制限を追加
- [ ] レート制限が機能することをテスト
- [ ] 429レスポンスが正しく返されることを確認

---

## テスト方法

```bash
# 連続リクエストでレート制限をテスト
for i in {1..50}; do
  curl -s -o /dev/null -w "%{http_code}\n" http://localhost:3000/api/transcripts
done

# 429が返されることを確認
```

---

## 関連ドキュメント

- [Upstash Rate Limiting](https://upstash.com/docs/oss/sdks/ts/ratelimit/overview)
- [Vercel Edge Middleware](https://vercel.com/docs/functions/edge-middleware)
- [OWASP Rate Limiting](https://owasp.org/www-community/controls/Blocking_Brute_Force_Attacks)
