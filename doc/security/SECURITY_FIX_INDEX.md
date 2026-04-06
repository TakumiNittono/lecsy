# Lecsy セキュリティ修正ガイド - インデックス

**作成日**: 2026年1月28日  
**対象**: Lecsy プロジェクト全体

---

## 概要

このディレクトリには、セキュリティ評価で特定された問題の修正ガイドが含まれています。

---

## 修正ガイド一覧

### 緊急（Critical）- 即座に対応

| # | ファイル | 対象 | 推定時間 |
|---|----------|------|----------|
| 1 | [SECURITY_FIX_01_JWT_VERIFICATION.md](./SECURITY_FIX_01_JWT_VERIFICATION.md) | JWT検証の有効化 | 5分 |
| 2 | [SECURITY_FIX_02_OWNERSHIP_CHECK.md](./SECURITY_FIX_02_OWNERSHIP_CHECK.md) | 所有権チェックの追加 | 15分 |
| 3 | [SECURITY_FIX_03_HARDCODED_CREDENTIALS.md](./SECURITY_FIX_03_HARDCODED_CREDENTIALS.md) | ハードコーディング削除（iOS） | 30分 |
| 4 | [SECURITY_FIX_04_API_AUTH.md](./SECURITY_FIX_04_API_AUTH.md) | APIルートの認証強化 | 20分 |
| 5 | [SECURITY_FIX_05_STRIPE_WEBHOOK.md](./SECURITY_FIX_05_STRIPE_WEBHOOK.md) | Stripe Webhookエラーハンドリング | 20分 |

### 高（High）- 短期対応

| # | ファイル | 対象 | 推定時間 |
|---|----------|------|----------|
| 6 | [SECURITY_FIX_06_TOKEN_LOGGING.md](./SECURITY_FIX_06_TOKEN_LOGGING.md) | トークンログ出力無効化 | 15分 |
| 7 | [SECURITY_FIX_07_XSS_PROTECTION.md](./SECURITY_FIX_07_XSS_PROTECTION.md) | XSS対策の強化 | 20分 |
| 8 | [SECURITY_FIX_08_CSRF_PROTECTION.md](./SECURITY_FIX_08_CSRF_PROTECTION.md) | CSRF対策の実装 | 30分 |
| 10 | [SECURITY_FIX_10_RATE_LIMITING.md](./SECURITY_FIX_10_RATE_LIMITING.md) | レート制限の実装 | 45分 |

### 中（Medium）- 中期対応

| # | ファイル | 対象 | 推定時間 |
|---|----------|------|----------|
| 9 | [SECURITY_FIX_09_CORS_SETTINGS.md](./SECURITY_FIX_09_CORS_SETTINGS.md) | CORS設定の見直し | 15分 |

---

## 推奨実装順序

### Phase 1: 緊急対応（1-2日）

```
1. JWT検証の有効化          → SECURITY_FIX_01
2. 所有権チェック追加        → SECURITY_FIX_02
3. Stripe Webhook修正       → SECURITY_FIX_05
4. APIルート認証強化        → SECURITY_FIX_04
5. ハードコーディング削除    → SECURITY_FIX_03
```

**実装後の確認**:
- [ ] iOSアプリから文字起こし保存が動作する
- [ ] Webアプリで講義削除が動作する
- [ ] Pro機能（要約）が自分のデータのみで動作する
- [ ] Stripe決済フローが正常に動作する

### Phase 2: 高優先度対応（1週間）

```
6. トークンログ無効化        → SECURITY_FIX_06
7. XSS対策強化              → SECURITY_FIX_07
8. CSRF対策実装             → SECURITY_FIX_08
```

**実装後の確認**:
- [ ] Releaseビルドでトークンがログに出力されない
- [ ] XSS攻撃のテストが成功する（スクリプトが実行されない）
- [ ] CSRFトークンなしのリクエストが拒否される

### Phase 3: 中優先度対応（2週間）

```
9. CORS設定見直し           → SECURITY_FIX_09
10. レート制限実装          → SECURITY_FIX_10
```

**実装後の確認**:
- [ ] 許可されたオリジンのみからリクエストが成功する
- [ ] レート制限が適用され、過剰なリクエストが拒否される

---

## ファイル構成

```
lecsy/
├── SECURITY_ASSESSMENT.md           # セキュリティ評価レポート
├── SECURITY_FIX_INDEX.md            # このファイル（インデックス）
├── SECURITY_FIX_01_JWT_VERIFICATION.md
├── SECURITY_FIX_02_OWNERSHIP_CHECK.md
├── SECURITY_FIX_03_HARDCODED_CREDENTIALS.md
├── SECURITY_FIX_04_API_AUTH.md
├── SECURITY_FIX_05_STRIPE_WEBHOOK.md
├── SECURITY_FIX_06_TOKEN_LOGGING.md
├── SECURITY_FIX_07_XSS_PROTECTION.md
├── SECURITY_FIX_08_CSRF_PROTECTION.md
├── SECURITY_FIX_09_CORS_SETTINGS.md
└── SECURITY_FIX_10_RATE_LIMITING.md
```

---

## 新規作成が必要なファイル

### iOS アプリ

| ファイル | 修正ガイド |
|----------|-----------|
| `lecsy/Config/Debug.xcconfig` | #3 |
| `lecsy/Config/Release.xcconfig` | #3 |
| `lecsy/Config/Debug.xcconfig.example` | #3 |
| `lecsy/Utils/Logger.swift` | #6 |

### Web アプリ

| ファイル | 修正ガイド |
|----------|-----------|
| `web/utils/api/auth.ts` | #4 |
| `web/utils/sanitize.ts` | #7 |
| `web/utils/csrf.ts` | #8 |
| `web/utils/api/csrfMiddleware.ts` | #8 |
| `web/app/api/csrf/route.ts` | #8 |
| `web/hooks/useCSRF.ts` | #8 |
| `web/utils/rateLimit.ts` | #10 |

### Supabase Edge Functions

| ファイル | 修正ガイド |
|----------|-----------|
| `supabase/functions/_shared/cors.ts` | #9 |
| `supabase/functions/_shared/rateLimit.ts` | #10 |

---

## 必要なパッケージ

### Web アプリ（npm）

```bash
# XSS対策
npm install dompurify jsdom
npm install --save-dev @types/dompurify @types/jsdom

# レート制限
npm install @upstash/redis @upstash/ratelimit
```

### 環境変数

```env
# .env.local (Web)
CSRF_SECRET=<random-32-char-secret>
UPSTASH_REDIS_REST_URL=<your-upstash-url>
UPSTASH_REDIS_REST_TOKEN=<your-upstash-token>

# Supabase Edge Functions
ALLOWED_ORIGINS=https://lecsy.vercel.app,https://www.lecsy.app
```

---

## デプロイチェックリスト

### 本番デプロイ前の確認

- [ ] すべての緊急修正（#1-5）が完了
- [ ] ローカル環境でのテストが成功
- [ ] ステージング環境でのテストが成功
- [ ] 環境変数が正しく設定されている
- [ ] Git履歴から機密情報が削除されている（必要な場合）

### デプロイ手順

```bash
# 1. Edge Functions をデプロイ
cd supabase
supabase functions deploy save-transcript
supabase functions deploy summarize
supabase functions deploy stripe-webhook

# 2. 環境変数を設定
supabase secrets set ALLOWED_ORIGINS="..."

# 3. Web アプリをデプロイ
cd ../web
vercel --prod

# 4. iOS アプリをビルド
# Xcode で Release ビルドを作成
```

---

## セキュリティテストの実行

### 基本テスト

```bash
# 1. 認証なしでAPIアクセス（401を期待）
curl -X DELETE http://localhost:3000/api/transcripts/123

# 2. 不正なオリジンからアクセス（403を期待）
curl -X POST http://localhost:3000/api/transcripts/123/title \
  -H "Origin: https://evil.com"

# 3. レート制限テスト（429を期待）
for i in {1..100}; do curl http://localhost:3000/api/test; done
```

### XSS テスト

データベースに悪意のあるコンテンツを挿入し、レンダリング時にスクリプトが実行されないことを確認。

---

## 参考ドキュメント

- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [Supabase Security Best Practices](https://supabase.com/docs/guides/platform/going-into-prod)
- [Next.js Security](https://nextjs.org/docs/app/building-your-application/configuring/content-security-policy)
- [iOS App Security](https://developer.apple.com/documentation/security)

---

## サポート

問題が発生した場合は、各修正ガイドのトラブルシューティングセクションを参照してください。
