# セキュリティ修正 #9: CORS設定の見直し

**重要度**: 中  
**対象ファイル**: 
- `supabase/functions/save-transcript/index.ts`
- `supabase/functions/summarize/index.ts`
- `supabase/functions/stripe-webhook/index.ts`

**推定作業時間**: 15分

---

## 現状の問題

すべてのEdge Functionsで CORS が `*` に設定されており、任意のオリジンからのリクエストを許可しています。

```typescript
// 現在のコード
return new Response(null, {
  headers: {
    "Access-Control-Allow-Origin": "*",  // すべてのオリジンを許可
    "Access-Control-Allow-Methods": "POST",
    "Access-Control-Allow-Headers": "authorization, content-type",
  },
});
```

---

## 修正手順

### Step 1: CORS ユーティリティの作成

新規ファイル: `supabase/functions/_shared/cors.ts`

```typescript
// supabase/functions/_shared/cors.ts

// 許可するオリジンのリスト
const ALLOWED_ORIGINS = [
  // 本番環境
  'https://lecsy.vercel.app',
  'https://www.lecsy.app',
  // 開発環境
  'http://localhost:3000',
  'http://localhost:54323',  // Supabase Studio
];

// 追加のオリジン（環境変数から取得）
const EXTRA_ORIGINS = Deno.env.get('ALLOWED_ORIGINS')?.split(',') || [];
const ALL_ALLOWED_ORIGINS = [...ALLOWED_ORIGINS, ...EXTRA_ORIGINS];

/**
 * オリジンが許可されているかチェック
 */
export function isAllowedOrigin(origin: string | null): boolean {
  if (!origin) return false;
  return ALL_ALLOWED_ORIGINS.includes(origin);
}

/**
 * CORSレスポンスを取得
 */
export function getCorsOrigin(request: Request): string {
  const origin = request.headers.get('origin');
  
  // 許可されたオリジンの場合はそのオリジンを返す
  if (origin && isAllowedOrigin(origin)) {
    return origin;
  }
  
  // 許可されていない場合はデフォルトのオリジンを返す
  // （これによりCORSエラーが発生する）
  return ALL_ALLOWED_ORIGINS[0] || 'https://lecsy.vercel.app';
}

/**
 * CORSヘッダーを取得
 */
export function getCorsHeaders(request: Request): Record<string, string> {
  return {
    'Access-Control-Allow-Origin': getCorsOrigin(request),
    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'authorization, content-type, x-client-info',
    'Access-Control-Max-Age': '86400',  // 24時間キャッシュ
    'Access-Control-Allow-Credentials': 'true',
  };
}

/**
 * プリフライトリクエストのレスポンスを作成
 */
export function createPreflightResponse(request: Request): Response {
  return new Response(null, {
    status: 204,
    headers: getCorsHeaders(request),
  });
}

/**
 * CORSヘッダー付きのJSONレスポンスを作成
 */
export function createJsonResponse(
  request: Request,
  data: unknown,
  status: number = 200
): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      'Content-Type': 'application/json',
      ...getCorsHeaders(request),
    },
  });
}

/**
 * CORSヘッダー付きのエラーレスポンスを作成
 */
export function createErrorResponse(
  request: Request,
  error: string,
  status: number = 400
): Response {
  return createJsonResponse(request, { error }, status);
}
```

---

### Step 2: save-transcript/index.ts の修正

**変更前**:
```typescript
serve(async (req) => {
  // CORS
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST",
        "Access-Control-Allow-Headers": "authorization, content-type",
      },
    });
  }
  // ...
});
```

**変更後**:
```typescript
import {
  createPreflightResponse,
  createJsonResponse,
  createErrorResponse,
  getCorsHeaders,
} from '../_shared/cors.ts';

serve(async (req) => {
  // CORS プリフライト
  if (req.method === "OPTIONS") {
    return createPreflightResponse(req);
  }

  try {
    // ... 認証チェックなど ...

    // 成功レスポンス
    return createJsonResponse(req, data);

  } catch (error) {
    console.error("Error:", error);
    return createErrorResponse(req, "Internal server error", 500);
  }
});
```

---

### Step 3: summarize/index.ts の修正

**変更前**:
```typescript
if (req.method === "OPTIONS") {
  return new Response(null, {
    headers: {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "POST",
      "Access-Control-Allow-Headers": "authorization, content-type",
    },
  });
}
```

**変更後**:
```typescript
import {
  createPreflightResponse,
  createJsonResponse,
  createErrorResponse,
} from '../_shared/cors.ts';

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return createPreflightResponse(req);
  }

  try {
    // ... 処理 ...
    return createJsonResponse(req, savedSummary);
  } catch (error) {
    console.error("Error:", error);
    return createErrorResponse(req, "Internal server error", 500);
  }
});
```

---

### Step 4: stripe-webhook/index.ts について

**Stripe Webhook は CORS 不要**

Stripe からのリクエストはブラウザからではないため、CORS ヘッダーは不要です。むしろ、余分なヘッダーを削除した方が安全です。

```typescript
serve(async (req) => {
  // Webhookにはプリフライトリクエストがないため、OPTIONSハンドラは不要
  
  // ... 処理 ...
  
  return new Response(JSON.stringify({ received: true }), {
    headers: { "Content-Type": "application/json" },
    // CORSヘッダーは不要
  });
});
```

---

### Step 5: 環境変数の設定

Supabase ダッシュボードで環境変数を設定:

1. Project Settings > Edge Functions
2. Environment Variables に追加:

```
ALLOWED_ORIGINS=https://lecsy.vercel.app,https://www.lecsy.app
```

---

## iOSアプリからのリクエストについて

iOSアプリからのリクエストはブラウザ経由ではないため、CORS制限は適用されません。ただし、認証（JWT）によって保護されています。

```swift
// iOSからのリクエストはOriginヘッダーを送信しない
// → CORSチェックはスキップされ、JWT認証のみでアクセス制御
```

---

## 完全な修正後のコード例（save-transcript）

```typescript
// supabase/functions/save-transcript/index.ts

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  createPreflightResponse,
  createJsonResponse,
  createErrorResponse,
} from '../_shared/cors.ts';

interface SaveTranscriptRequest {
  title: string;
  content: string;
  created_at: string;
  duration?: number;
  language?: string;
  app_version?: string;
}

serve(async (req) => {
  // CORS プリフライト
  if (req.method === "OPTIONS") {
    return createPreflightResponse(req);
  }

  try {
    // 認証チェック
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return createErrorResponse(req, "Unauthorized", 401);
    }

    if (!authHeader.startsWith("Bearer ")) {
      return createErrorResponse(req, "Invalid auth format", 401);
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } }
    );

    const { data: { user }, error: authError } = await supabase.auth.getUser();
    
    if (authError || !user) {
      return createErrorResponse(req, "Unauthorized", 401);
    }

    // リクエストボディ
    const body: SaveTranscriptRequest = await req.json();

    // バリデーション
    if (!body.content || body.content.trim() === "") {
      return createErrorResponse(req, "Content is required", 400);
    }

    // word_count計算
    const wordCount = body.content.split(/\s+/).filter(Boolean).length;

    // 保存
    const { data, error } = await supabase
      .from("transcripts")
      .insert({
        user_id: user.id,
        title: body.title || `Recording ${new Date().toISOString()}`,
        content: body.content,
        created_at: body.created_at || new Date().toISOString(),
        duration: body.duration,
        language: body.language,
        word_count: wordCount,
        source: "ios",
      })
      .select("id, created_at")
      .single();

    if (error) {
      throw error;
    }

    return createJsonResponse(req, data);
  } catch (error) {
    console.error("Error:", error);
    return createErrorResponse(req, "Internal server error", 500);
  }
});
```

---

## デプロイ手順

```bash
# _shared ディレクトリを含めてデプロイ
cd supabase

# 各関数をデプロイ
supabase functions deploy save-transcript
supabase functions deploy summarize

# 環境変数を設定（ダッシュボードまたはCLI）
supabase secrets set ALLOWED_ORIGINS="https://lecsy.vercel.app,https://www.lecsy.app"
```

---

## 確認チェックリスト

- [ ] `_shared/cors.ts` を作成
- [ ] `save-transcript/index.ts` を修正
- [ ] `summarize/index.ts` を修正
- [ ] `stripe-webhook/index.ts` からCORSヘッダーを削除
- [ ] 環境変数 `ALLOWED_ORIGINS` を設定
- [ ] 許可されたオリジンからのリクエストが成功することを確認
- [ ] 許可されていないオリジンからのリクエストが拒否されることを確認
- [ ] iOSアプリからのリクエストが成功することを確認

---

## テスト方法

```bash
# 許可されたオリジン（200を期待）
curl -X OPTIONS https://<project>.supabase.co/functions/v1/save-transcript \
  -H "Origin: https://lecsy.vercel.app" \
  -H "Access-Control-Request-Method: POST" \
  -v

# 許可されていないオリジン（CORSエラーを期待）
curl -X OPTIONS https://<project>.supabase.co/functions/v1/save-transcript \
  -H "Origin: https://evil.com" \
  -H "Access-Control-Request-Method: POST" \
  -v
```

---

## 関連ドキュメント

- [MDN - CORS](https://developer.mozilla.org/en-US/docs/Web/HTTP/CORS)
- [Supabase Edge Functions - CORS](https://supabase.com/docs/guides/functions/cors)
