# トラブルシューティングガイド

**作成日**: 2026年2月6日

---

## 🔧 よくある問題と解決策

### 1. Supabase Edge Functions のデプロイタイムアウト

**症状**: 
```
unexpected deploy status 400: {"message":"Bundle generation timed out"}
```

**原因**:
- 関数が大きすぎる
- 依存関係が多い
- ネットワークの問題
- 複数の関数を同時にデプロイしようとしている

**解決策**:

#### 方法1: 個別にデプロイする

```bash
# 1つずつデプロイ
supabase functions deploy stripe-webhook
supabase functions deploy summarize
supabase functions deploy save-transcript
supabase functions deploy delete-account
```

#### 方法2: デプロイを再試行する

タイムアウトは一時的な問題の可能性があります。数分待ってから再試行：

```bash
# 5分待ってから再試行
supabase functions deploy stripe-webhook
```

#### 方法3: Supabase ダッシュボードからデプロイ

1. [Supabase ダッシュボード](https://supabase.com/dashboard) にログイン
2. プロジェクトを選択
3. **Edge Functions** → **Deploy** をクリック
4. 関数をアップロード

#### 方法4: 関数のサイズを確認・最適化

```bash
# 関数のサイズを確認
du -sh supabase/functions/stripe-webhook
du -sh supabase/functions/summarize

# 大きすぎる場合は、不要なファイルを削除
# node_modules などが含まれていないか確認
```

---

### 2. Stripe CLI がインストールされていない

**症状**:
```
zsh: command not found: stripe
```

**解決策**:

#### macOS

```bash
brew install stripe/stripe-cli/stripe
```

#### その他のOS

- **Linux**: [Stripe CLI インストールガイド](https://stripe.com/docs/stripe-cli#install)
- **Windows**: [Stripe CLI インストールガイド](https://stripe.com/docs/stripe-cli#install)

#### インストール確認

```bash
stripe --version
# 出力例: stripe version 1.35.0
```

#### ログイン

```bash
stripe login
```

ブラウザが開いて認証画面が表示されます。認証後、ターミナルに戻ります。

---

### 3. Webhook Secret が取得できない

**症状**: `stripe listen` を実行しても `whsec_xxx` が表示されない

**解決策**:

1. **Stripe CLI にログインしているか確認**:
   ```bash
   stripe login
   ```

2. **Webhook を転送**:
   ```bash
   # ローカル開発用
   stripe listen --forward-to http://localhost:54321/functions/v1/stripe-webhook
   
   # または、Supabase の本番URL用
   stripe listen --forward-to https://<PROJECT_REF>.supabase.co/functions/v1/stripe-webhook
   ```

3. **出力を確認**:
   以下のような出力が表示されます：
   ```
   > Ready! Your webhook signing secret is whsec_xxxxxxxxxxxxx
   > (^C to quit)
   ```

4. **この `whsec_xxx` をコピー**して、Supabase の環境変数 `STRIPE_WEBHOOK_SECRET` に設定

---

### 4. Checkout Session 作成に失敗する

**症状**: "Failed to create checkout session" エラー

**原因と対策**:

| 原因 | 対策 |
|------|------|
| `STRIPE_SECRET_KEY` が未設定 | `.env.local` に設定されているか確認 |
| `STRIPE_PRICE_ID` が未設定 | `.env.local` に設定されているか確認 |
| 環境変数が読み込まれていない | Next.js サーバーを再起動 |
| Price ID が間違っている | Stripe ダッシュボードで確認 |

**確認手順**:

```bash
# 1. 環境変数を確認
cd web
cat .env.local | grep STRIPE

# 2. Next.js サーバーを再起動
npm run dev
```

---

### 5. Webhook が届かない

**症状**: 決済は成功するが、`subscriptions` テーブルが更新されない

**原因と対策**:

| 原因 | 対策 |
|------|------|
| `stripe listen` が実行されていない | 別のターミナルで実行 |
| Webhook URL が間違っている | 正しいURLを確認 |
| `STRIPE_WEBHOOK_SECRET` が間違っている | Stripe CLI で再取得 |
| Supabase Edge Function がデプロイされていない | デプロイを確認 |

**確認手順**:

```bash
# 1. Stripe CLI で Webhook を転送（別ターミナル）
stripe listen --forward-to http://localhost:54321/functions/v1/stripe-webhook

# 2. テストイベントを送信
stripe trigger checkout.session.completed

# 3. Supabase のログを確認
# Supabase ダッシュボード → Edge Functions → Logs
```

---

### 6. Pro 状態が反映されない

**症状**: 決済成功後も "Free" と表示される

**原因と対策**:

| 原因 | 対策 |
|------|------|
| ページがキャッシュされている | ハードリロード（Cmd+Shift+R） |
| Webhook が処理されていない | Webhook のログを確認 |
| `subscriptions` テーブルを直接確認 | Supabase ダッシュボードで確認 |

**確認手順**:

1. **Supabase ダッシュボード** → **Table Editor** → `subscriptions` テーブル
2. あなたの `user_id` で `status: "active"` のレコードがあるか確認
3. なければ、Webhook が正しく処理されていない可能性

---

### 7. 環境変数が読み込まれない

**症状**: 環境変数を設定したが、アプリで反映されない

**原因と対策**:

| 原因 | 対策 |
|------|------|
| `.env.local` の場所が間違っている | `web/.env.local` に配置 |
| Next.js サーバーを再起動していない | `npm run dev` を再実行 |
| 環境変数名が間違っている | `STRIPE_SECRET_KEY` など、正確な名前を確認 |

**確認手順**:

```bash
# 1. ファイルの場所を確認
cd web
ls -la .env.local

# 2. 内容を確認（機密情報は表示されないように注意）
cat .env.local

# 3. Next.js サーバーを再起動
npm run dev
```

---

## 📞 サポート

問題が解決しない場合：

1. **ログを確認**:
   - Next.js: ターミナルの出力
   - Supabase: ダッシュボード → Edge Functions → Logs
   - Stripe: ダッシュボード → Developers → Logs

2. **エラーメッセージをコピー**して、ドキュメントで検索

3. **Stripe サポート**: [Stripe Support](https://support.stripe.com/)

4. **Supabase サポート**: [Supabase Discord](https://discord.supabase.com/)

---

**最終更新**: 2026年2月6日
