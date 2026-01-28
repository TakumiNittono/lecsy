# セキュリティ修正 #4: APIルートの認証チェック強化

**重要度**: 緊急  
**対象ファイル**: 
- `web/middleware.ts`
- `web/app/api/transcripts/[id]/route.ts`
- `web/app/api/transcripts/[id]/title/route.ts`

**推定作業時間**: 20分

---

## 現状の問題

### 問題 1: APIルートがミドルウェアをスキップ

```typescript
// web/middleware.ts (5-8行目)
export async function middleware(request: NextRequest) {
  // APIルートはミドルウェアをスキップ
  if (request.nextUrl.pathname.startsWith('/api/')) {
    return
  }
```

**リスク**: APIルートでセッションが更新されず、認証チェックの一貫性が失われます。

### 問題 2: 削除・更新の成功確認がない

```typescript
// web/app/api/transcripts/[id]/route.ts (20-25行目)
const { error } = await supabase
  .from("transcripts")
  .delete()
  .eq("id", id)
  .eq("user_id", user.id)
// 削除が実際に行われたかの確認がない
```

---

## 修正手順

### Step 1: middleware.ts の修正

**変更前**:
```typescript
import { type NextRequest } from 'next/server'
import { updateSession } from '@/utils/supabase/middleware'

export async function middleware(request: NextRequest) {
  // APIルートはミドルウェアをスキップ
  if (request.nextUrl.pathname.startsWith('/api/')) {
    return
  }
  
  return await updateSession(request)
}

export const config = {
  matcher: [
    '/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)',
  ],
}
```

**変更後**:
```typescript
import { type NextRequest, NextResponse } from 'next/server'
import { updateSession } from '@/utils/supabase/middleware'

export async function middleware(request: NextRequest) {
  // 公開APIルート（Webhookなど）はスキップ
  const publicApiPaths = [
    '/api/stripe-webhook',  // Stripeからのwebhook
  ]
  
  if (publicApiPaths.some(path => request.nextUrl.pathname.startsWith(path))) {
    return NextResponse.next()
  }
  
  // セッション更新はすべてのルートで実行
  return await updateSession(request)
}

export const config = {
  matcher: [
    '/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)',
  ],
}
```

---

### Step 2: API共通の認証ヘルパーを作成

新規ファイル: `web/utils/api/auth.ts`

```typescript
import { createClient } from '@/utils/supabase/server'
import { NextResponse } from 'next/server'

export interface AuthenticatedUser {
  id: string
  email?: string
}

export interface AuthResult {
  user: AuthenticatedUser | null
  error: NextResponse | null
}

/**
 * APIルートで認証チェックを行う
 * @returns user: 認証されたユーザー、error: エラーレスポンス
 */
export async function authenticateRequest(): Promise<AuthResult> {
  try {
    const supabase = createClient()
    const { data: { user }, error: authError } = await supabase.auth.getUser()

    if (authError) {
      console.error('Authentication error:', authError)
      return {
        user: null,
        error: NextResponse.json(
          { error: 'Authentication failed' },
          { status: 401 }
        )
      }
    }

    if (!user) {
      return {
        user: null,
        error: NextResponse.json(
          { error: 'Unauthorized' },
          { status: 401 }
        )
      }
    }

    return {
      user: {
        id: user.id,
        email: user.email
      },
      error: null
    }
  } catch (error) {
    console.error('Unexpected auth error:', error)
    return {
      user: null,
      error: NextResponse.json(
        { error: 'Internal server error' },
        { status: 500 }
      )
    }
  }
}

/**
 * UUIDの形式を検証
 */
export function isValidUUID(id: string): boolean {
  const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
  return uuidRegex.test(id)
}
```

---

### Step 3: transcripts/[id]/route.ts の修正

**変更前**:
```typescript
import { createClient } from "@/utils/supabase/server"
import { NextRequest, NextResponse } from "next/server"

export const dynamic = 'force-dynamic'

export async function DELETE(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params
    const supabase = createClient()
    const { data: { user }, error: authError } = await supabase.auth.getUser()

    if (authError || !user) {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 })
    }

    const { error } = await supabase
      .from("transcripts")
      .delete()
      .eq("id", id)
      .eq("user_id", user.id)

    if (error) {
      console.error("Error deleting transcript:", error)
      return NextResponse.json({ error: "Failed to delete transcript" }, { status: 500 })
    }

    return NextResponse.json({ success: true })
  } catch (error) {
    console.error("Error in DELETE /api/transcripts/[id]:", error)
    return NextResponse.json(
      { error: "Internal server error" },
      { status: 500 }
    )
  }
}
```

**変更後**:
```typescript
import { createClient } from "@/utils/supabase/server"
import { NextRequest, NextResponse } from "next/server"
import { authenticateRequest, isValidUUID } from "@/utils/api/auth"

export const dynamic = 'force-dynamic'

export async function DELETE(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params
    
    // ID形式のバリデーション
    if (!isValidUUID(id)) {
      return NextResponse.json(
        { error: "Invalid ID format" },
        { status: 400 }
      )
    }

    // 認証チェック
    const { user, error: authError } = await authenticateRequest()
    if (authError) return authError

    const supabase = createClient()

    // 削除を実行し、結果を確認
    const { data, error } = await supabase
      .from("transcripts")
      .delete()
      .eq("id", id)
      .eq("user_id", user!.id)
      .select('id')  // 削除されたレコードを返す
      .single()

    if (error) {
      // レコードが見つからない場合
      if (error.code === 'PGRST116') {
        return NextResponse.json(
          { error: "Transcript not found or access denied" },
          { status: 404 }
        )
      }
      console.error("Error deleting transcript:", error)
      return NextResponse.json(
        { error: "Failed to delete transcript" },
        { status: 500 }
      )
    }

    // 削除が成功したかを確認
    if (!data) {
      return NextResponse.json(
        { error: "Transcript not found or access denied" },
        { status: 404 }
      )
    }

    return NextResponse.json({ success: true, deletedId: data.id })
  } catch (error) {
    console.error("Error in DELETE /api/transcripts/[id]:", error)
    return NextResponse.json(
      { error: "Internal server error" },
      { status: 500 }
    )
  }
}
```

---

### Step 4: transcripts/[id]/title/route.ts の修正

**変更後**:
```typescript
import { createClient } from "@/utils/supabase/server"
import { NextRequest, NextResponse } from "next/server"
import { authenticateRequest, isValidUUID } from "@/utils/api/auth"

export const dynamic = 'force-dynamic'

// タイトルのバリデーション
const MAX_TITLE_LENGTH = 200
const validateTitle = (title: unknown): { valid: boolean; error?: string } => {
  if (typeof title !== 'string') {
    return { valid: false, error: 'Title must be a string' }
  }
  if (title.trim().length === 0) {
    return { valid: false, error: 'Title cannot be empty' }
  }
  if (title.length > MAX_TITLE_LENGTH) {
    return { valid: false, error: `Title cannot exceed ${MAX_TITLE_LENGTH} characters` }
  }
  return { valid: true }
}

export async function PATCH(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params
    
    // ID形式のバリデーション
    if (!isValidUUID(id)) {
      return NextResponse.json(
        { error: "Invalid ID format" },
        { status: 400 }
      )
    }

    // 認証チェック
    const { user, error: authError } = await authenticateRequest()
    if (authError) return authError

    // リクエストボディのパース
    let body: { title?: unknown }
    try {
      body = await request.json()
    } catch {
      return NextResponse.json(
        { error: "Invalid JSON body" },
        { status: 400 }
      )
    }

    // タイトルのバリデーション
    const titleValidation = validateTitle(body.title)
    if (!titleValidation.valid) {
      return NextResponse.json(
        { error: titleValidation.error },
        { status: 400 }
      )
    }

    const title = (body.title as string).trim()
    const supabase = createClient()

    // 更新を実行し、結果を確認
    const { data, error } = await supabase
      .from("transcripts")
      .update({ title, updated_at: new Date().toISOString() })
      .eq("id", id)
      .eq("user_id", user!.id)
      .select('id, title')
      .single()

    if (error) {
      if (error.code === 'PGRST116') {
        return NextResponse.json(
          { error: "Transcript not found or access denied" },
          { status: 404 }
        )
      }
      console.error("Error updating transcript title:", error)
      return NextResponse.json(
        { error: "Failed to update title" },
        { status: 500 }
      )
    }

    if (!data) {
      return NextResponse.json(
        { error: "Transcript not found or access denied" },
        { status: 404 }
      )
    }

    return NextResponse.json({ success: true, data })
  } catch (error) {
    console.error("Error in PATCH /api/transcripts/[id]/title:", error)
    return NextResponse.json(
      { error: "Internal server error" },
      { status: 500 }
    )
  }
}
```

---

## 確認チェックリスト

- [ ] `middleware.ts` を修正（公開APIパスのみスキップ）
- [ ] `utils/api/auth.ts` を作成
- [ ] `transcripts/[id]/route.ts` を修正
- [ ] `transcripts/[id]/title/route.ts` を修正
- [ ] UUID形式のバリデーションが機能することを確認
- [ ] 認証なしでAPIアクセスが拒否されることを確認
- [ ] 他ユーザーのデータにアクセスできないことを確認
- [ ] 削除・更新の成功確認が機能することを確認

---

## テスト方法

```bash
# 認証なしでアクセス（401を期待）
curl -X DELETE http://localhost:3000/api/transcripts/123e4567-e89b-12d3-a456-426614174000

# 不正なID形式（400を期待）
curl -X DELETE http://localhost:3000/api/transcripts/invalid-id \
  -H "Cookie: ..."

# 存在しないID（404を期待）
curl -X DELETE http://localhost:3000/api/transcripts/123e4567-e89b-12d3-a456-426614174000 \
  -H "Cookie: ..."
```

---

## 関連ドキュメント

- [Next.js Middleware](https://nextjs.org/docs/app/building-your-application/routing/middleware)
- [Supabase Auth Helpers](https://supabase.com/docs/guides/auth/auth-helpers/nextjs)
