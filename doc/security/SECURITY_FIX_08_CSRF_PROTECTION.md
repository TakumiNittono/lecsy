# セキュリティ修正 #8: CSRF対策の実装

**重要度**: 高  
**対象ファイル**: 
- `web/utils/supabase/middleware.ts`
- `web/app/api/` 配下のAPIルート
- 新規作成ファイル

**推定作業時間**: 30分

---

## 現状の問題

CSRFトークンの検証が実装されていません。認証済みセッションを悪用したCSRF攻撃のリスクがあります。

---

## 修正手順

### Step 1: CSRFユーティリティの作成

新規ファイル: `web/utils/csrf.ts`

```typescript
import { cookies } from 'next/headers';
import { randomBytes, createHmac } from 'crypto';

const CSRF_SECRET = process.env.CSRF_SECRET || 'your-csrf-secret-key-change-in-production';
const CSRF_COOKIE_NAME = '__Host-csrf';
const CSRF_HEADER_NAME = 'x-csrf-token';
const TOKEN_EXPIRY_MS = 60 * 60 * 1000; // 1時間

interface CSRFToken {
  value: string;
  timestamp: number;
}

/**
 * CSRFトークンを生成
 */
export function generateCSRFToken(): string {
  const timestamp = Date.now();
  const randomValue = randomBytes(32).toString('hex');
  const data = `${randomValue}:${timestamp}`;
  const signature = createHmac('sha256', CSRF_SECRET)
    .update(data)
    .digest('hex');
  
  return `${data}:${signature}`;
}

/**
 * CSRFトークンを検証
 */
export function validateCSRFToken(token: string | null): boolean {
  if (!token) return false;
  
  const parts = token.split(':');
  if (parts.length !== 3) return false;
  
  const [randomValue, timestampStr, signature] = parts;
  const timestamp = parseInt(timestampStr, 10);
  
  // タイムスタンプの検証
  if (isNaN(timestamp)) return false;
  if (Date.now() - timestamp > TOKEN_EXPIRY_MS) return false;
  
  // 署名の検証
  const data = `${randomValue}:${timestamp}`;
  const expectedSignature = createHmac('sha256', CSRF_SECRET)
    .update(data)
    .digest('hex');
  
  // タイミング攻撃を防ぐための比較
  return timingSafeEqual(signature, expectedSignature);
}

/**
 * タイミングセーフな文字列比較
 */
function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  
  let result = 0;
  for (let i = 0; i < a.length; i++) {
    result |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return result === 0;
}

/**
 * CSRFトークンをCookieに設定
 */
export async function setCSRFCookie(): Promise<string> {
  const token = generateCSRFToken();
  const cookieStore = await cookies();
  
  cookieStore.set(CSRF_COOKIE_NAME, token, {
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'strict',
    path: '/',
    maxAge: TOKEN_EXPIRY_MS / 1000,
  });
  
  return token;
}

/**
 * リクエストからCSRFトークンを取得して検証
 */
export async function verifyCSRFFromRequest(request: Request): Promise<boolean> {
  const cookieStore = await cookies();
  const cookieToken = cookieStore.get(CSRF_COOKIE_NAME)?.value;
  const headerToken = request.headers.get(CSRF_HEADER_NAME);
  
  // Cookieとヘッダーの両方が必要
  if (!cookieToken || !headerToken) return false;
  
  // 両方が一致し、有効であることを確認
  if (cookieToken !== headerToken) return false;
  
  return validateCSRFToken(cookieToken);
}

/**
 * OriginとRefererを検証
 */
export function verifyOrigin(request: Request): boolean {
  const origin = request.headers.get('origin');
  const referer = request.headers.get('referer');
  
  // 許可するオリジン
  const allowedOrigins = [
    process.env.NEXT_PUBLIC_SITE_URL,
    'http://localhost:3000',
    'https://localhost:3000',
  ].filter(Boolean);
  
  // Originヘッダーの検証
  if (origin) {
    return allowedOrigins.some(allowed => origin === allowed);
  }
  
  // Refererヘッダーの検証（Originがない場合）
  if (referer) {
    try {
      const refererUrl = new URL(referer);
      const refererOrigin = `${refererUrl.protocol}//${refererUrl.host}`;
      return allowedOrigins.some(allowed => refererOrigin === allowed);
    } catch {
      return false;
    }
  }
  
  return false;
}
```

---

### Step 2: 環境変数の追加

`.env.local` に追加:

```env
# CSRF保護用のシークレット（本番環境では強力なランダム値を使用）
CSRF_SECRET=your-random-32-character-secret-key
```

生成方法:
```bash
node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
```

---

### Step 3: CSRFミドルウェアの作成

新規ファイル: `web/utils/api/csrfMiddleware.ts`

```typescript
import { NextRequest, NextResponse } from 'next/server';
import { verifyCSRFFromRequest, verifyOrigin } from '@/utils/csrf';

// CSRF保護が必要なHTTPメソッド
const PROTECTED_METHODS = ['POST', 'PUT', 'PATCH', 'DELETE'];

// CSRF保護をスキップするパス（Webhookなど）
const CSRF_EXEMPT_PATHS = [
  '/api/stripe-webhook',
];

/**
 * CSRF保護ミドルウェア
 */
export async function csrfProtection(
  request: NextRequest,
  handler: () => Promise<NextResponse>
): Promise<NextResponse> {
  const { pathname } = request.nextUrl;
  const method = request.method;
  
  // スキップ対象のパスをチェック
  if (CSRF_EXEMPT_PATHS.some(path => pathname.startsWith(path))) {
    return handler();
  }
  
  // 保護対象のメソッドのみチェック
  if (!PROTECTED_METHODS.includes(method)) {
    return handler();
  }
  
  // Origin/Refererの検証
  if (!verifyOrigin(request)) {
    console.warn(`CSRF: Invalid origin for ${method} ${pathname}`);
    return NextResponse.json(
      { error: 'Invalid request origin' },
      { status: 403 }
    );
  }
  
  // CSRFトークンの検証
  const isValidCSRF = await verifyCSRFFromRequest(request);
  if (!isValidCSRF) {
    console.warn(`CSRF: Invalid token for ${method} ${pathname}`);
    return NextResponse.json(
      { error: 'Invalid CSRF token' },
      { status: 403 }
    );
  }
  
  return handler();
}
```

---

### Step 4: CSRFトークンを提供するAPIエンドポイント

新規ファイル: `web/app/api/csrf/route.ts`

```typescript
import { NextResponse } from 'next/server';
import { setCSRFCookie } from '@/utils/csrf';

export const dynamic = 'force-dynamic';

export async function GET() {
  try {
    const token = await setCSRFCookie();
    
    return NextResponse.json({ 
      token,
      expiresIn: 3600 // 1時間（秒単位）
    });
  } catch (error) {
    console.error('CSRF token generation error:', error);
    return NextResponse.json(
      { error: 'Failed to generate token' },
      { status: 500 }
    );
  }
}
```

---

### Step 5: クライアントサイドのCSRFフック

新規ファイル: `web/hooks/useCSRF.ts`

```typescript
'use client';

import { useState, useEffect, useCallback } from 'react';

interface CSRFState {
  token: string | null;
  loading: boolean;
  error: string | null;
}

export function useCSRF() {
  const [state, setState] = useState<CSRFState>({
    token: null,
    loading: true,
    error: null,
  });

  const fetchToken = useCallback(async () => {
    try {
      setState(prev => ({ ...prev, loading: true, error: null }));
      
      const response = await fetch('/api/csrf');
      if (!response.ok) {
        throw new Error('Failed to fetch CSRF token');
      }
      
      const data = await response.json();
      setState({
        token: data.token,
        loading: false,
        error: null,
      });
      
      // トークンの有効期限前に更新
      const refreshTime = (data.expiresIn - 60) * 1000; // 1分前に更新
      setTimeout(fetchToken, refreshTime);
      
    } catch (error) {
      setState({
        token: null,
        loading: false,
        error: error instanceof Error ? error.message : 'Unknown error',
      });
    }
  }, []);

  useEffect(() => {
    fetchToken();
  }, [fetchToken]);

  /**
   * CSRF保護付きのfetch
   */
  const csrfFetch = useCallback(async (
    url: string,
    options: RequestInit = {}
  ): Promise<Response> => {
    if (!state.token) {
      throw new Error('CSRF token not available');
    }
    
    const headers = new Headers(options.headers);
    headers.set('x-csrf-token', state.token);
    
    return fetch(url, {
      ...options,
      headers,
      credentials: 'include', // Cookieを含める
    });
  }, [state.token]);

  return {
    ...state,
    csrfFetch,
    refreshToken: fetchToken,
  };
}
```

---

### Step 6: コンポーネントでの使用例

**DeleteForm.tsx の修正**:

```tsx
'use client';

import { useCSRF } from '@/hooks/useCSRF';
import { useRouter } from 'next/navigation';
import { useState } from 'react';

interface DeleteFormProps {
  transcriptId: string;
}

export default function DeleteForm({ transcriptId }: DeleteFormProps) {
  const router = useRouter();
  const { csrfFetch, loading: csrfLoading } = useCSRF();
  const [isDeleting, setIsDeleting] = useState(false);

  const handleDelete = async () => {
    if (!confirm('Are you sure you want to delete this transcript?')) {
      return;
    }

    setIsDeleting(true);
    
    try {
      const response = await csrfFetch(`/api/transcripts/${transcriptId}`, {
        method: 'DELETE',
      });

      if (!response.ok) {
        const data = await response.json();
        throw new Error(data.error || 'Failed to delete');
      }

      router.push('/app');
      router.refresh();
    } catch (error) {
      console.error('Delete error:', error);
      alert('Failed to delete transcript');
    } finally {
      setIsDeleting(false);
    }
  };

  return (
    <button
      onClick={handleDelete}
      disabled={isDeleting || csrfLoading}
      className="px-4 py-2 text-red-600 hover:text-red-700 ..."
    >
      {isDeleting ? 'Deleting...' : 'Delete'}
    </button>
  );
}
```

---

### Step 7: SameSite Cookie の確認

`web/utils/supabase/middleware.ts` で SameSite 設定を確認:

```typescript
// supabase/middleware.ts に追加または確認

// Cookieのオプションを設定
const cookieOptions = {
  sameSite: 'lax' as const,  // または 'strict'
  secure: process.env.NODE_ENV === 'production',
  httpOnly: true,
};
```

---

## 簡易版: Origin/Referer 検証のみ

フル実装が難しい場合、最低限 Origin/Referer 検証を追加:

```typescript
// web/utils/api/auth.ts に追加

export function validateOrigin(request: Request): boolean {
  const origin = request.headers.get('origin');
  const referer = request.headers.get('referer');
  
  const allowedOrigins = [
    process.env.NEXT_PUBLIC_SITE_URL,
    'http://localhost:3000',
  ].filter(Boolean);
  
  if (origin && !allowedOrigins.includes(origin)) {
    return false;
  }
  
  if (referer) {
    try {
      const url = new URL(referer);
      const refOrigin = `${url.protocol}//${url.host}`;
      if (!allowedOrigins.includes(refOrigin)) {
        return false;
      }
    } catch {
      return false;
    }
  }
  
  return true;
}

// APIルートで使用
export async function DELETE(request: NextRequest, ...) {
  if (!validateOrigin(request)) {
    return NextResponse.json({ error: 'Forbidden' }, { status: 403 });
  }
  // ...
}
```

---

## 確認チェックリスト

- [ ] `utils/csrf.ts` を作成
- [ ] `utils/api/csrfMiddleware.ts` を作成
- [ ] `/api/csrf` エンドポイントを作成
- [ ] `hooks/useCSRF.ts` を作成
- [ ] 環境変数 `CSRF_SECRET` を設定
- [ ] 各コンポーネントで `csrfFetch` を使用
- [ ] SameSite Cookie の設定を確認
- [ ] Origin/Referer 検証が機能することを確認

---

## テスト方法

```bash
# CSRFトークンなしでPOSTリクエスト（403を期待）
curl -X POST http://localhost:3000/api/transcripts/123/title \
  -H "Content-Type: application/json" \
  -d '{"title":"Test"}'

# 不正なOriginでリクエスト（403を期待）
curl -X POST http://localhost:3000/api/transcripts/123/title \
  -H "Content-Type: application/json" \
  -H "Origin: https://evil.com" \
  -d '{"title":"Test"}'
```

---

## 関連ドキュメント

- [OWASP CSRF Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Cross-Site_Request_Forgery_Prevention_Cheat_Sheet.html)
- [SameSite Cookies](https://web.dev/samesite-cookies-explained/)
