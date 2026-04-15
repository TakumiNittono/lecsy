# OPERATIONS — lecsy 本番運用マニュアル

> 作成: 2026-04-14
> 対象: ローンチ後の日次/週次運用、障害対応、Live切替

---

## 🚨 1分でやる毎日チェック

```bash
# 1. Deepgram残高（critical < $50, warning < $150）
curl -X POST https://bjqilokchrqfxzimfnpm.supabase.co/functions/v1/deepgram-balance-check \
  -H "Authorization: Bearer <SERVICE_ROLE_KEY>"

# 2. 直近24hアラート
psql $SUPABASE_DB_URL -c "select level, source, message, created_at from system_alerts where created_at > now() - interval '24 hours' order by created_at desc;"

# 3. Stripe Webhook 失敗
stripe events list --limit 20 --types invoice.payment_failed,checkout.session.async_payment_failed
```

---

## 📊 監視ダッシュボード SQL

### Edge Function 利用状況（24時間）
```sql
-- Realtimeセッション数
select count(distinct user_id) as users,
       sum(minutes_today) as total_minutes
  from user_daily_realtime_usage
 where usage_date = current_date;

-- 月次cap到達ユーザー
select user_id, minutes_month
  from user_monthly_realtime_usage
 where usage_month = date_trunc('month', current_date)::date
   and minutes_month > 600
 order by minutes_month desc;
```

### 課金状況
```sql
-- アクティブ Pro/Student サブスク
select count(*) as active_subs
  from subscriptions
 where status = 'active'
   and provider = 'stripe';

-- 過去7日の新規課金
select date_trunc('day', created_at) as day, count(*)
  from subscriptions
 where status = 'active'
   and created_at > now() - interval '7 days'
 group by 1 order by 1;
```

### Feature Flag状態
```sql
select * from feature_flags;
```

---

## 🔔 Slack アラート設定（任意だが強く推奨）

`deepgram-balance-check` は残高 warning/critical 時に system_alerts 記録
に加え、`SLACK_WEBHOOK_URL` があれば Slack にプッシュ通知する。未設定なら
静かに no-op。

```bash
# 1. Slackで Incoming Webhook を作成 → URL をコピー
#    https://api.slack.com/messaging/webhooks

# 2. Supabase secret に登録
supabase secrets set SLACK_WEBHOOK_URL=https://hooks.slack.com/services/XXX/YYY/ZZZ

# 3. Edge Function を再デプロイして反映
supabase functions deploy deepgram-balance-check

# 4. 動作確認: CRITICAL_THRESHOLD を一時的に $99999 にして cron手動起動→Slack着信
```

---

## 🟢 Stripe Test → Live 切替手順（ローンチ日）

事前条件:
- LLC設立済、EIN取得済、銀行口座開設済
- Stripe Account 本人確認完了 (Activate account)

### Step 1: Live keys取得
1. Stripe Dashboard → 右上トグルを **Live mode** に切替
2. Developers → API keys → reveal `sk_live_...`

### Step 2: Live mode で Products + Prices 再作成
```bash
# Live keyに切替
export STRIPE_KEY=sk_live_xxx

# 同じスクリプトでLive側にも作成
stripe products create --api-key=$STRIPE_KEY --name="Lecsy Pro"
stripe products create --api-key=$STRIPE_KEY --name="Lecsy Student"
# (Price IDをメモ)

stripe prices create --api-key=$STRIPE_KEY \
  --product=prod_XXX --unit-amount=1299 --currency=usd \
  -d "recurring[interval]=month" --lookup-key=lecsy_pro_monthly
# (4つ作成)
```

### Step 3: Webhook endpoint 作成（Live）
```bash
curl -s https://api.stripe.com/v1/webhook_endpoints \
  -u sk_live_XXX: \
  -d "url=https://bjqilokchrqfxzimfnpm.supabase.co/functions/v1/stripe-webhook" \
  -d "enabled_events[]=checkout.session.completed" \
  -d "enabled_events[]=customer.subscription.created" \
  -d "enabled_events[]=customer.subscription.updated" \
  -d "enabled_events[]=customer.subscription.deleted" \
  -d "enabled_events[]=invoice.payment_succeeded" \
  -d "enabled_events[]=invoice.payment_failed"
# (idとsecretをメモ)
```

### Step 4: Supabase secrets 全部Liveに差し替え
```bash
supabase secrets set \
  STRIPE_SECRET_KEY=sk_live_XXX \
  STRIPE_WEBHOOK_SECRET=whsec_LIVE_XXX \
  STRIPE_PRICE_PRO_MONTHLY=price_LIVE_XXX \
  STRIPE_PRICE_PRO_YEARLY=price_LIVE_XXX \
  STRIPE_PRICE_STUDENT_MONTHLY=price_LIVE_XXX \
  STRIPE_PRICE_STUDENT_YEARLY=price_LIVE_XXX
```

### Step 5: Edge Functions 再デプロイ（secret反映）
```bash
supabase functions deploy stripe-webhook create-checkout-session create-portal-session
```

### Step 6: Smoke test (Live)
1. `/pricing` → "Start Pro" → 自分のリアルカードで$12.99課金（後で返金）
2. `subscriptions` テーブルで `status='active'` 確認
3. Stripe Dashboardで返金処理

---

## 🔴 障害対応プレイブック

### Deepgram 残高ゼロ
- **症状**: ユーザーから「字幕が出ない」、`feature_flags.realtime_captions_beta = false`
- **対応**:
  1. Deepgram Dashboard でクレジット追加
  2. `update feature_flags set enabled = true where name = 'realtime_captions_beta';`
  3. ユーザーへリリースノート/X投稿でアナウンス

### Edge Function エラー率上昇
- **確認**: Supabase Dashboard → Edge Functions → Logs
- **対応**: 該当関数を直前バージョンへロールバック → `git checkout <prev> -- supabase/functions/<name>/index.ts && supabase functions deploy <name>`

### Stripe Webhook 失敗
- **確認**: Stripe Dashboard → Developers → Webhooks → 該当endpoint の Recent deliveries
- **対応**: イベントを Resend → 復旧確認

### App Store クラッシュ報告
- **確認**: App Store Connect → TestFlight/Crashes
- **対応**: `git bisect` で原因特定 → hotfixバージョン提出

---

## 🔄 Cron設定（Supabase）

`pg_cron` + `pg_net` が必要（Dashboard → Database → Extensions で有効化）。

```sql
-- Deepgram残高 6時間ごと
select cron.schedule(
  'deepgram-balance-check-6h',
  '0 */6 * * *',
  $$
    select net.http_post(
      url := 'https://bjqilokchrqfxzimfnpm.supabase.co/functions/v1/deepgram-balance-check',
      headers := jsonb_build_object(
        'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key')
      )
    )
  $$
);

-- 古いalert削除（30日以上前）週次
select cron.schedule(
  'cleanup-old-alerts',
  '0 0 * * 0',
  $$ delete from system_alerts where created_at < now() - interval '30 days' $$
);
```

---

## 📞 緊急連絡先

| 種別 | 連絡先 |
|------|------|
| Deepgram support | support@deepgram.com |
| Supabase support | support@supabase.io (Pro plan) |
| Stripe support | Dashboard内 chat |
| Apple Developer | https://developer.apple.com/contact/ |
