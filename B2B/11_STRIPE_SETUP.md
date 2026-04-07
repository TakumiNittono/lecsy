# Stripe セットアップ手順 (有償化に必要)

> Lecsy B2B で課金導線を有効化するための **手動操作チェックリスト**。
> Stripe ダッシュボード上での操作 + Supabase Edge Function secrets の設定が必要。
> 約 20 分。

---

## 前提

- Stripe アカウント (https://dashboard.stripe.com) にログイン済
- Supabase CLI がローカルから lecsy プロジェクトに linked 済 (`supabase status`)

---

## STEP 1 — Stripe で Product を 3 つ作る

ダッシュボード → **Products → Add product** を 3 回繰り返す。

### Product A: Starter
- Name: `Lecsy Starter (per seat)`
- Pricing model: **Recurring**
- Monthly: $299/mo / billed monthly → Price ID をメモ → `STRIPE_PRICE_STARTER_MONTHLY`
- Yearly: $2,990/yr (= 2 ヶ月分割引) / billed yearly → `STRIPE_PRICE_STARTER_YEARLY`

### Product B: Growth
- Name: `Lecsy Growth (per seat)`
- Monthly: $599/mo → `STRIPE_PRICE_GROWTH_MONTHLY`
- Yearly: $5,990/yr → `STRIPE_PRICE_GROWTH_YEARLY`

### Product C: Business
- Name: `Lecsy Business (per seat)`
- Monthly: $1,199/mo (or custom) → `STRIPE_PRICE_BUSINESS_MONTHLY`
- Yearly: $11,990/yr → `STRIPE_PRICE_BUSINESS_YEARLY`

> ⚠️ **テストモードと本番モード両方で作る必要がある**。最初はテストモードで通しで動くことを確認してから本番に切り替え。

---

## STEP 2 — Webhook エンドポイントを登録

Stripe ダッシュボード → **Developers → Webhooks → Add endpoint**

- Endpoint URL: `https://bjqilokchrqfxzimfnpm.supabase.co/functions/v1/stripe-webhook`
- Events to send:
  - `customer.subscription.created`
  - `customer.subscription.updated`
  - `customer.subscription.deleted`
  - `invoice.payment_succeeded`
  - `invoice.payment_failed`
- 作成後、表示される **Signing secret** (`whsec_...`) をコピー → `STRIPE_WEBHOOK_SECRET`

---

## STEP 3 — Supabase Edge Function に secrets を設定

ターミナルで:

```bash
cd /Users/takuminittono/Desktop/iPhone\ app/lecsy

supabase secrets set \
  STRIPE_PRICE_STARTER_MONTHLY=price_xxx \
  STRIPE_PRICE_STARTER_YEARLY=price_xxx \
  STRIPE_PRICE_GROWTH_MONTHLY=price_xxx \
  STRIPE_PRICE_GROWTH_YEARLY=price_xxx \
  STRIPE_PRICE_BUSINESS_MONTHLY=price_xxx \
  STRIPE_PRICE_BUSINESS_YEARLY=price_xxx \
  STRIPE_WEBHOOK_SECRET=whsec_xxx \
  --project-ref bjqilokchrqfxzimfnpm
```

(`STRIPE_SECRET_KEY` は既に設定済み。確認: `supabase secrets list --project-ref bjqilokchrqfxzimfnpm`)

---

## STEP 4 — Edge Function をデプロイ

```bash
supabase functions deploy org-checkout --project-ref bjqilokchrqfxzimfnpm
supabase functions deploy stripe-webhook --project-ref bjqilokchrqfxzimfnpm --no-verify-jwt
```

> `stripe-webhook` は Stripe からの呼び出しなので `--no-verify-jwt` 必須。

---

## STEP 5 — 通しテスト (テストモード)

1. Web 管理画面 `/org/{slug}/settings` → 「Upgrade plan」→ Starter (monthly) を選択
2. Stripe checkout に飛ぶ → テストカード `4242 4242 4242 4242` (任意の future expiry, CVV)
3. 決済成功 → Lecsy にリダイレクト
4. Supabase で確認:
   ```sql
   SELECT id, name, plan, seats_purchased, stripe_customer_id, stripe_subscription_id, stripe_subscription_status
   FROM organizations
   WHERE slug = 'your-test-org';
   ```
   - `stripe_subscription_id` が入っているか
   - `seats_purchased` が `> 0` か (これがあると seat 上限の分母になる)
   - `stripe_subscription_status` が `active` か

5. **座席追加テスト**: メンバーを追加して `seats_purchased` を超えると `seat_limit_exceeded` エラーが出ること

---

## STEP 6 — 本番モードへの切り替え

1. Stripe ダッシュ右上のスイッチを **Live mode** に
2. 同じ Product/Webhook を本番モードでも作成 (完全に別物扱い)
3. 本番の Price ID と Webhook secret で Supabase secrets を上書き
4. `STRIPE_SECRET_KEY` も本番の `sk_live_...` に上書き

> ⚠️ 上書き前に **必ず Supabase secrets を export して退避**:
> `supabase secrets list --project-ref bjqilokchrqfxzimfnpm`

---

## チェックリスト

- [ ] テストモードで Product 3×2 = 6 個作成済
- [ ] テストモードで Webhook endpoint 作成済 + signing secret 取得済
- [ ] Supabase secrets 7 個 set 済
- [ ] org-checkout / stripe-webhook デプロイ済
- [ ] テスト決済 1 回成功 (`4242` カード)
- [ ] DB の `seats_purchased` が更新されることを確認
- [ ] 座席上限 enforcement 動作確認
- [ ] 本番モードで同じことを繰り返し
