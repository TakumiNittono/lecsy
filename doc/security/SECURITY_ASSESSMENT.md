# Lecsy セキュリティ評価レポート

**評価日**: 2026年1月28日  
**対象**: Lecsy プロジェクト全体（iOS アプリ / Web アプリ / Supabase Edge Functions）  
**目的**: SaaS / Web 公開に向けたセキュリティ評価

---

## 概要

本レポートは、Lecsy プロジェクトのセキュリティ上の問題点を特定し、改善点をまとめたものです。

### 評価結果サマリー

| カテゴリ | 緊急 | 高 | 中 | 低 |
|---------|------|-----|-----|-----|
| 認証・認可 | 2 | 2 | 3 | 1 |
| 機密情報の管理 | 2 | 1 | 2 | - |
| データ保護 | - | 1 | 2 | 1 |
| API セキュリティ | 1 | 2 | 3 | 2 |
| ネットワーク | - | - | 2 | 1 |
| **合計** | **5** | **6** | **12** | **5** |

---

## 1. 緊急対応が必要な問題（Critical）

### 1.1 Edge Function の JWT 検証無効化

**ファイル**: `supabase/config.toml`

```toml
[functions.save-transcript]
verify_jwt = false
```

**リスク**: JWT 検証がバイパスされ、認証なしで API にアクセスされる可能性があります。

**推奨対応**:
```toml
[functions.save-transcript]
verify_jwt = true
```

---

### 1.2 summarize 関数での所有権チェック不足

**ファイル**: `supabase/functions/summarize/index.ts`

**問題**: `transcript_id` で transcript を取得していますが、そのデータがリクエストユーザーのものか確認していません。

**リスク**: 他のユーザーの transcript_id を指定して要約を取得できる可能性があります。

**推奨対応**:
```typescript
// 現在のコード
const { data: transcript } = await supabase
  .from('transcripts')
  .select('*')
  .eq('id', transcript_id)
  .single();

// 修正後
const { data: transcript } = await supabase
  .from('transcripts')
  .select('*')
  .eq('id', transcript_id)
  .eq('user_id', user.id)  // 所有権チェックを追加
  .single();
```

---

### 1.3 API キーのハードコーディング（iOS）

**ファイル**: `lecsy/Config/SupabaseConfig.swift`, `lecsy/Info.plist`

```swift
// SupabaseConfig.swift
self.supabaseURL = URL(string: "https://bjqilokchrqfxzimfnpm.supabase.co")!
self.supabaseAnonKey = "sb_publishable_q6JRDcMOKDp8qPuptCLARg_-HqmJsNH"
```

**リスク**: ソースコードに機密情報が含まれ、Git リポジトリにコミットされます。

**推奨対応**:
- デフォルト値を削除
- xcconfig ファイルまたはビルド設定から環境別に注入
- `.gitignore` に設定ファイルを追加

---

### 1.4 API ルートの認証チェック不足（Web）

**ファイル**: `web/app/middleware.ts`

```typescript
// 6行目: /api/ 配下のリクエストがミドルウェアをスキップ
```

**リスク**: API ルートが認証なしでアクセス可能になる可能性があります。

**推奨対応**:
```typescript
// middleware.ts で API ルートも認証チェックを実施
export const config = {
  matcher: [
    '/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)',
  ],
}
```

---

### 1.5 Stripe Webhook のエラーハンドリング不足

**ファイル**: `supabase/functions/stripe-webhook/index.ts`

**問題**: 
- データベース操作（`upsert`, `update`）のエラーチェックがない
- シグネチャ検証エラー時にエラーメッセージがそのまま返される

**推奨対応**:
```typescript
const { error } = await supabase
  .from('subscriptions')
  .upsert({ ... });

if (error) {
  console.error('Database error:', error);
  return new Response('Internal error', { status: 500 });
}
```

---

## 2. 高リスクの問題（High）

### 2.1 トークン情報のログ出力

**ファイル**: 
- `lecsy/Services/AuthService.swift` (227-228行目)
- `lecsy/Services/SyncService.swift` (107-108行目)
- `supabase/functions/save-transcript/index.ts` (56行目)

**問題**: アクセストークンやリフレッシュトークンの一部がログに出力されています。

**推奨対応**:
```swift
#if DEBUG
print("   - Access Token: \(accessToken.prefix(20))...")
#endif
```

---

### 2.2 ユーザー入力のサニタイズ不足（XSS）

**ファイル**: `web/app/app/t/[id]/page.tsx` (212行目)

**問題**: `transcript.content` を直接レンダリングしています。

**リスク**: データベースに悪意のあるスクリプトが保存されている場合、XSS 攻撃の可能性があります。

**推奨対応**:
```typescript
import DOMPurify from 'dompurify';

// サニタイズしてからレンダリング
<div dangerouslySetInnerHTML={{ __html: DOMPurify.sanitize(transcript.content) }} />
```

---

### 2.3 CSRF 対策の不足

**ファイル**: すべての API ルート

**問題**: CSRF トークンの検証が実装されていません。

**推奨対応**:
- SameSite Cookie の設定を確認（`Strict` を推奨）
- 重要な操作には CSRF トークンを実装
- Origin/Referer ヘッダーの検証を追加

---

### 2.4 入力検証の不足

**ファイル**: 
- `web/app/api/transcripts/[id]/title/route.ts`
- `web/app/api/transcripts/[id]/route.ts`

**問題**: 
- タイトルの最大長・文字種の検証がない
- ID パラメータの UUID 形式検証がない

**推奨対応**:
```typescript
// UUID形式の検証
const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
if (!uuidRegex.test(params.id)) {
  return NextResponse.json({ error: 'Invalid ID format' }, { status: 400 });
}

// タイトルの検証
if (title.length > 200) {
  return NextResponse.json({ error: 'Title too long' }, { status: 400 });
}
```

---

### 2.5 レート制限の未実装

**ファイル**: すべての API ルート・Edge Functions

**リスク**: ブルートフォース攻撃や DoS 攻撃に対する防御がありません。

**推奨対応**:
- Vercel Edge Middleware でレート制限を実装
- Supabase Edge Functions にレート制限を追加

```typescript
// Edge Functionsでの実装例
const rateLimitKey = `rate_limit:${user.id}`;
const current = await redis.incr(rateLimitKey);
if (current === 1) {
  await redis.expire(rateLimitKey, 60);
}
if (current > 10) {
  return new Response('Too many requests', { status: 429 });
}
```

---

### 2.6 データ暗号化の不足（iOS）

**ファイル**: `lecsy/Services/LectureStore.swift`

**問題**: 講義データが JSON ファイルとして平文保存されています。

**推奨対応**:
- iOS Data Protection API を使用
- または Core Data の暗号化機能を利用

```swift
// Data Protection APIの使用
try data.write(to: storageURL, options: .completeFileProtection)
```

---

## 3. 中リスクの問題（Medium）

### 3.1 CORS 設定が広すぎる

**ファイル**: Edge Functions 全般

```typescript
'Access-Control-Allow-Origin': '*'
```

**推奨対応**:
```typescript
const allowedOrigins = ['https://your-domain.com', 'https://app.your-domain.com'];
const origin = req.headers.get('origin');
const corsOrigin = allowedOrigins.includes(origin) ? origin : allowedOrigins[0];

return new Response(data, {
  headers: {
    'Access-Control-Allow-Origin': corsOrigin,
    ...
  }
});
```

---

### 3.2 月次制限の未実装

**ファイル**: `supabase/functions/summarize/index.ts`

**問題**: `MONTHLY_LIMIT` が定義されていますが、実際のチェックが未実装です。

---

### 3.3 認可チェックの不十分

**ファイル**: 
- `web/app/api/transcripts/[id]/route.ts`
- `web/app/api/transcripts/[id]/title/route.ts`

**問題**: 削除・更新の成功確認がありません。

**推奨対応**:
```typescript
const { data, error, count } = await supabase
  .from('transcripts')
  .delete()
  .eq('id', params.id)
  .eq('user_id', user.id)
  .select();

if (!data || data.length === 0) {
  return NextResponse.json({ error: 'Not found or unauthorized' }, { status: 404 });
}
```

---

### 3.4 エラーメッセージの詳細情報露出

**ファイル**: 
- `web/app/api/create-checkout-session/route.ts`
- `web/app/api/create-portal-session/route.ts`

**推奨対応**:
```typescript
// 本番環境では詳細エラーを返さない
const errorMessage = process.env.NODE_ENV === 'production' 
  ? 'An error occurred' 
  : error.message;
```

---

### 3.5 subscriptions テーブルの RLS ポリシー不足

**ファイル**: `supabase/migrations/001_initial_schema.sql`

**問題**: INSERT/UPDATE/DELETE ポリシーがありません。

**推奨対応**:
```sql
-- サービスロール用のポリシーを明示的に追加（ドキュメント目的）
-- または、サービスロールが RLS をバイパスすることを確認
```

---

### 3.6 証明書ピニング未実装（iOS）

**ファイル**: `lecsy/Services/SyncService.swift`

**リスク**: 中間者攻撃（MITM）のリスクがあります。

**推奨対応**:
- URLSession での証明書ピニング実装
- または、Alamofire などのライブラリを使用

---

### 3.7 録音ファイルの平文保存

**ファイル**: `lecsy/Services/RecordingService.swift`

**推奨対応**:
```swift
// ファイル保護を有効化
try FileManager.default.setAttributes(
    [.protectionKey: FileProtectionType.complete],
    ofItemAtPath: recordingURL.path
)
```

---

## 4. 低リスクの問題（Low）

### 4.1 URL パラメータの未検証

**ファイル**: `web/app/login/page.tsx`

`decodeURIComponent(errorParam)` を直接使用しています。

---

### 4.2 デバッグログの残存

**ファイル**: 各種ファイル

本番環境でも `console.log` / `print` が出力される可能性があります。

---

### 4.3 セッションタイムアウトの不明確

**ファイル**: `web/utils/supabase/middleware.ts`

セッションリフレッシュは実装されていますが、タイムアウト処理が不明確です。

---

### 4.4 JSON 解析のエラーハンドリング不足

**ファイル**: `supabase/functions/summarize/index.ts`

`JSON.parse()` でパースエラーが発生する可能性があります。

---

### 4.5 認証コールバックの検証不足

**ファイル**: `web/app/auth/callback/route.ts`

`code` パラメータの形式・長さの検証が不十分です。

---

## 5. 推奨アクションプラン

### Phase 1: 即座に対応（1-2日）

| # | 対応項目 | ファイル | 重要度 |
|---|---------|----------|--------|
| 1 | JWT 検証を有効化 | `supabase/config.toml` | 緊急 |
| 2 | 所有権チェックを追加 | `supabase/functions/summarize/index.ts` | 緊急 |
| 3 | API キーのハードコーディング削除 | `SupabaseConfig.swift`, `Info.plist` | 緊急 |
| 4 | Stripe Webhook のエラーハンドリング | `stripe-webhook/index.ts` | 緊急 |
| 5 | API ルートの認証チェック | `web/app/middleware.ts` | 緊急 |

### Phase 2: 短期対応（1週間）

| # | 対応項目 | ファイル | 重要度 |
|---|---------|----------|--------|
| 6 | トークンログの無効化 | 各 Service ファイル | 高 |
| 7 | XSS 対策の強化 | `t/[id]/page.tsx` | 高 |
| 8 | 入力検証の追加 | API ルート全般 | 高 |
| 9 | CSRF 対策の実装 | API ルート全般 | 高 |
| 10 | CORS 設定の見直し | Edge Functions | 中 |

### Phase 3: 中期対応（1ヶ月）

| # | 対応項目 | ファイル | 重要度 |
|---|---------|----------|--------|
| 11 | レート制限の実装 | API ルート、Edge Functions | 高 |
| 12 | データ暗号化 | `LectureStore.swift` | 高 |
| 13 | 月次制限の実装 | `summarize/index.ts` | 中 |
| 14 | RLS ポリシーの見直し | migrations | 中 |
| 15 | 証明書ピニング | `SyncService.swift` | 中 |

### Phase 4: 長期対応（継続）

- セキュリティ監査の定期実施
- 依存ライブラリの脆弱性スキャン
- ペネトレーションテストの実施
- セキュリティログの監視体制構築

---

## 6. チェックリスト

### デプロイ前の必須確認事項

- [ ] JWT 検証が有効化されているか
- [ ] API キーがソースコードにハードコーディングされていないか
- [ ] 所有権チェックが実装されているか
- [ ] CORS が適切に設定されているか
- [ ] トークン情報がログに出力されていないか
- [ ] 入力値のバリデーションが実装されているか
- [ ] エラーメッセージに機密情報が含まれていないか
- [ ] RLS ポリシーが適切に設定されているか

### 定期的なセキュリティレビュー

- [ ] 依存ライブラリの脆弱性チェック（週次）
- [ ] アクセスログの異常検知（日次）
- [ ] 認証失敗のモニタリング（日次）
- [ ] セキュリティパッチの適用（随時）

---

## 7. 参考リソース

- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [Supabase Security Best Practices](https://supabase.com/docs/guides/platform/going-into-prod)
- [Next.js Security](https://nextjs.org/docs/app/building-your-application/configuring/content-security-policy)
- [iOS App Security Best Practices](https://developer.apple.com/documentation/security)

---

**作成者**: AI Security Assessment  
**最終更新**: 2026年1月28日
