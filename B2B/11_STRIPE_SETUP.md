# Stripe セットアップ手順 (有償化に必要)

> Lecsy B2B Pro プラン 1 本のシンプル課金。Stripe ダッシュボード操作 +
> Supabase Edge Function secrets 設定で約 15 分。

---

## 前提

- Stripe アカウント (https://dashboard.stripe.com)
- Supabase CLI が lecsy プロジェクトに linked 済 (`supabase status`)

---

## STEP 1 — Stripe で Pro Product を 1 つ作る

Stripe ダッシュボード → **Products → Add product**:

- **Name**: `Lecsy Pro (per seat)`
- **Pricing model**: Recurring
- **Billing period**: Monthly (Yearly も後で追加可)
- **Price**: $X / seat / month (営業価格に合わせる、例: $9〜$15/seat/月)
- **Usage type**: Licensed (per-unit、座席ベース)

作成後、price ID をメモ → `STRIPE_PRICE_PRO_MONTHLY`
(年額も作るなら `STRIPE_PRICE_PRO_YEARLY`)

> ⚠️ テストモードと本番モードで別々に作る。テストモードで通したあと本番に切り替え。

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

## STEP 3 — Supabase secrets を設定

```bash
cd /Users/takuminittono/Desktop/iPhone\ app/lecsy

supabase secrets set \
  STRIPE_PRICE_PRO_MONTHLY=price_xxx \
  STRIPE_PRICE_PRO_YEARLY=price_xxx \
  STRIPE_WEBHOOK_SECRET=whsec_xxx \
  --project-ref bjqilokchrqfxzimfnpm
```

(`STRIPE_SECRET_KEY` は既に設定済。確認: `supabase secrets list --project-ref bjqilokchrqfxzimfnpm`)

---

## STEP 4 — Edge Function をデプロイ

```bash
supabase functions deploy org-checkout --project-ref bjqilokchrqfxzimfnpm --no-verify-jwt
supabase functions deploy stripe-webhook --project-ref bjqilokchrqfxzimfnpm --no-verify-jwt
```

> `--no-verify-jwt` 必須。`stripe-webhook` は外部 (Stripe) からのリクエスト、
> `org-checkout` は ES256 access token を関数コードで verify するため。
> (どちらも `supabase/config.toml` でも `verify_jwt = false` 指定済)

---

## STEP 5 — `org-checkout` Edge Function のコード調整

現状の `supabase/functions/org-checkout/index.ts` は starter/growth/business の
3 ティアを参照しているはず。Pro 1 本に書き換える:

```ts
// before
const PRICES = {
  starter:  { monthly: ..., yearly: ... },
  growth:   { monthly: ..., yearly: ... },
  business: { monthly: ..., yearly: ... },
};

// after
const PRICES = {
  pro: {
    monthly: Deno.env.get('STRIPE_PRICE_PRO_MONTHLY'),
    yearly:  Deno.env.get('STRIPE_PRICE_PRO_YEARLY'),
  },
};
```

`stripe-webhook` 側の price → plan マッピングも同様に Pro 1 本に。

---

## STEP 6 — 通しテスト (テストモード)

1. Web 管理画面 `/org/{slug}/settings` → 「Upgrade」→ Pro
2. Stripe checkout に飛ぶ → テストカード `4242 4242 4242 4242`
3. 決済成功 → Lecsy にリダイレクト
4. 確認 SQL:
   ```sql
   SELECT id, name, plan, seats_purchased, stripe_subscription_id, stripe_subscription_status
   FROM organizations
   WHERE slug = 'your-test-org';
   ```
   - `plan = 'pro'`
   - `stripe_subscription_id` 入っている
   - `seats_purchased > 0`
   - `stripe_subscription_status = 'active'`

5. **座席追加テスト**: メンバーを `seats_purchased` を超えて追加 → `seat_limit_exceeded`

---

## STEP 7 — 本番モードへの切り替え

1. Stripe ダッシュ右上スイッチ → Live mode
2. 同じ Product/Webhook を本番で作成 (テストとは完全に別物扱い)
3. 本番の price ID と webhook secret で Supabase secrets を上書き
4. `STRIPE_SECRET_KEY` も `sk_live_...` に上書き

---

## チェックリスト

- [ ] テストモードで Pro Product 1 つ作成
- [ ] テストモードで Webhook endpoint + signing secret 取得
- [ ] Supabase secrets 4 個 set 済 (`STRIPE_PRICE_PRO_MONTHLY`, `STRIPE_PRICE_PRO_YEARLY`, `STRIPE_WEBHOOK_SECRET`, 既存 `STRIPE_SECRET_KEY`)
- [ ] `org-checkout` のコードを Pro 1 本に書き換え
- [ ] org-checkout / stripe-webhook デプロイ済
- [ ] テスト決済 1 回成功 (`4242` カード)
- [ ] 本番モードで同じことを繰り返し
