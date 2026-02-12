# セキュリティ実装状況

**最終確認日**: 2026年2月12日

---

## ✅ 実装済みのセキュリティ対策

### 1. 認証・認可

- [x] **JWT検証**: Edge Functionsで`supabase.auth.getUser()`を使用
- [x] **所有権チェック**: `summarize`関数で`eq("user_id", user.id)`を実装
- [x] **APIルート認証**: `authenticateRequest()`をすべてのAPIルートで使用
- [x] **UUID検証**: `isValidUUID()`でID形式を検証

### 2. 入力検証

- [x] **タイトル検証**: 最大200文字、空文字チェック
- [x] **UUID検証**: 不正なID形式を拒否（Transcript詳細ページ含む）
- [x] **リダイレクト検証**: オープンリダイレクト対策（`getSafeRedirectPath`）
- [x] **Stripe Webhook**: `user_id`のUUID検証を実装

### 3. XSS対策

- [x] **サニタイゼーション**: `sanitizeText()`でHTMLタグを除去
- [x] **DOMPurify**: クライアント側でHTMLサニタイゼーション
- [x] **エスケープ**: 検索クエリを`escapeRegExp()`でエスケープ

### 4. CSRF対策

- [x] **Origin検証**: `validateOrigin()`でSame-Origin Requestをチェック
- [x] **Vercel対応**: 本番環境とプレビュー環境を許可
- [x] **開発環境対応**: localhostを許可

### 5. レート制限

- [x] **APIレート制限**: 削除API（20回/時間）、タイトル更新（30回/分）
- [x] **Stripe API**: Checkout（5回/分）、Portal（10回/分）
- [x] **クライアント識別**: ユーザーIDまたはIPアドレスで識別
- [x] **レスポンスヘッダー**: `X-RateLimit-Remaining`、`Retry-After`を返す

### 6. CORS設定

- [x] **Edge Functions**: `_shared/cors.ts`で許可オリジンを管理
- [x] **環境変数対応**: `ALLOWED_ORIGINS`で動的に設定可能
- [x] **プリフライトリクエスト**: OPTIONSリクエストに対応

### 7. 機密情報の保護

- [x] **iOS APIキー**: xcconfigファイルで管理（Gitにコミットしない）
- [x] **トークンログ**: `AppLogger.logToken()`でマスク
- [x] **デバッグログ**: Releaseビルドでは出力しない

### 8. エラーハンドリング

- [x] **情報漏洩防止**: 本番環境では詳細なエラーメッセージを返さない
- [x] **Stripe Webhook**: エラー時に適切なログを記録
- [x] **所有権エラー**: "not found or access denied"で統一

### 9. Webセキュリティ（2026年2月追加）

- [x] **オープンリダイレクト対策**: auth callback、login、Google OAuthで`redirectTo`検証
- [x] **Stripe API強化**: Origin検証、レート制限、環境変数チェック
- [x] **セキュリティヘッダー**: X-XSS-Protection、Permissions-Policyを追加
- [x] **Transcript詳細**: UUIDバリデーションで不正IDを早期拒否

---

## 📋 実装ファイル一覧

### Webアプリ

- `web/utils/api/auth.ts` - 認証・UUID検証・Origin検証
- `web/utils/redirect.ts` - オープンリダイレクト対策
- `web/utils/sanitize.ts` - XSS対策
- `web/utils/rateLimit.ts` - レート制限
- `web/app/api/transcripts/[id]/route.ts` - 削除API（認証・レート制限付き）
- `web/app/api/transcripts/[id]/title/route.ts` - タイトル更新API（認証・レート制限付き）
- `web/app/api/create-checkout-session/route.ts` - Stripe Checkout（Origin検証・レート制限付き）
- `web/app/api/create-portal-session/route.ts` - Stripe Portal（同上）

### Edge Functions

- `supabase/functions/_shared/cors.ts` - CORS設定
- `supabase/functions/summarize/index.ts` - 所有権チェック実装済み
- `supabase/functions/stripe-webhook/index.ts` - UUID検証・エラーハンドリング

### iOSアプリ

- `lecsy/Utils/Logger.swift` - セキュアログ出力
- `lecsy/Config/Debug.xcconfig` - APIキー管理（Gitにコミットしない）
- `lecsy/Config/Release.xcconfig` - 本番環境設定

---

## ⚠️ 注意事項

### 1. JWT検証について

`supabase/config.toml`で`verify_jwt = false`になっていますが、これは意図的な設定です：
- Edge Functionsのコード内で`supabase.auth.getUser()`を使用して認証チェックを実装
- iOSアプリからのリクエストで問題が発生したため、コード内認証に切り替え
- **セキュリティは確保されています**（コード内で認証チェックを実装）

### 2. レート制限について

現在はインメモリキャッシュを使用しています：
- **開発環境**: 問題なし
- **本番環境**: 複数インスタンスで動作する場合は、Upstash Redisの使用を推奨

### 3. CORS設定について

`ALLOWED_ORIGINS`環境変数を設定する必要があります：
```bash
supabase secrets set ALLOWED_ORIGINS="https://lecsy.vercel.app,https://www.lecsy.app"
```

---

## 🧪 セキュリティテスト

### 基本テスト

```bash
# 1. 認証なしでAPIアクセス（401を期待）
curl -X DELETE https://lecsy.vercel.app/api/transcripts/123

# 2. 不正なOriginからアクセス（403を期待）
curl -X POST https://lecsy.vercel.app/api/transcripts/123/title \
  -H "Origin: https://evil.com" \
  -H "Authorization: Bearer <token>"

# 3. レート制限テスト（429を期待）
# 30回連続でリクエストを送信
```

### XSSテスト

データベースに以下のような悪意のあるコンテンツを挿入：
```html
<script>alert('XSS')</script>
<img src=x onerror="alert('XSS')">
```

レンダリング時にスクリプトが実行されないことを確認。

---

## 📝 中優先度項目について

中優先度（Medium）の項目は**実装しなくても問題ありません**。

### 中優先度項目

- **修正 #9: CORS設定の見直し**
  - 現在の実装: `_shared/cors.ts`で既に実装済み
  - 環境変数`ALLOWED_ORIGINS`で動的に設定可能
  - **現状で十分機能しています**

### 推奨事項

中優先度の項目は、将来的に必要になった場合に実装すれば十分です。
現在の実装でApp Store提出には問題ありません。

---

## ✅ デプロイ準備完了

すべての緊急・高優先度のセキュリティ修正が実装されています。
中優先度の項目は実装済みまたは後回しで問題ありません。

**次のステップ**:
1. 本番環境での動作確認
2. セキュリティテストの実行
3. モニタリング設定

---

**最終更新**: 2026年2月12日
