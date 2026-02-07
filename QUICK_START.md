# クイックスタートガイド — Stripe 課金テスト

**作成日**: 2026年2月6日

---

## ✅ 完了したステップ

- [x] Stripe CLI インストール
- [x] Stripe CLI ログイン
- [x] Supabase Edge Functions デプロイ（stripe-webhook, summarize）

---

## 🚀 次のステップ

### Step 1: Webhook Secret を取得

ターミナルで以下のコマンドを実行：

```bash
stripe listen --forward-to http://localhost:54321/functions/v1/stripe-webhook
```

**重要**: このコマンドを実行すると、以下のような出力が表示されます：

```
> Ready! Your webhook signing secret is whsec_xxxxxxxxxxxxx
> (^C to quit)
```

この `whsec_xxxxxxxxxxxxx` をコピーしてください。

### Step 2: Supabase に Webhook Secret を設定

1. [Supabase ダッシュボード](https://supabase.com/dashboard) にログイン
2. プロジェクトを選択
3. **Edge Functions** → **Secrets** をクリック
4. 以下の環境変数を追加：

| キー | 値 |
|------|-----|
| `STRIPE_SECRET_KEY` | `sk_test_xxxxxxxxxxxxx` （Stripe ダッシュボードから取得） |
| `STRIPE_WEBHOOK_SECRET` | `whsec_xxxxxxxxxxxxx` （Step 1で取得した値） |
| `OPENAI_API_KEY` | `sk-xxxxxxxxxxxxx` （AI要約機能用、オプション） |

### Step 3: Next.js サーバーを起動

**別のターミナル**で：

```bash
cd web
npm run dev
```

サーバーが `http://localhost:3020` で起動します。

### Step 4: テストフローを実行

1. **ブラウザで** `http://localhost:3020` にアクセス
2. **ログイン** → `/login` でGoogle/Apple Sign In
3. **ダッシュボード** (`/app`) に移動
4. **"Upgrade to Pro — $2.99/mo"** ボタンをクリック
5. **Stripe Checkout ページ**が開く
6. **テストカード**を入力：
   - カード番号: `4242 4242 4242 4242`
   - 有効期限: `12/34`
   - CVC: `123`
   - 郵便番号: `12345`
7. **"Subscribe"** をクリック
8. **成功** → `/app?success=true` にリダイレクト
9. **トースト通知**が表示される
10. **Subscription カード**が "Pro" に変わる

---

## 📋 チェックリスト

テスト前に確認：

- [ ] Webhook Secret を取得した（`whsec_xxx`）
- [ ] Supabase の環境変数に `STRIPE_WEBHOOK_SECRET` を設定した
- [ ] `stripe listen` が実行されている（別ターミナル）
- [ ] Next.js サーバーが起動している（`http://localhost:3020`）
- [ ] ログイン済み

---

## 🔍 トラブルシューティング

### Webhook が届かない

- `stripe listen` が実行されているか確認
- Supabase の環境変数 `STRIPE_WEBHOOK_SECRET` が正しいか確認
- Supabase ダッシュボード → Edge Functions → Logs でエラーを確認

### Pro 状態が反映されない

- ページをリロード（Cmd+Shift+R）
- Supabase ダッシュボード → Table Editor → `subscriptions` テーブルを確認
- `status: "active"` のレコードがあるか確認

詳細は `TROUBLESHOOTING.md` を参照してください。

---

**最終更新**: 2026年2月6日
