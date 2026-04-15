# lecsy Stripe 課金アーキテクチャ

> 作成日: 2026-04-14
> 目的: Apple IAP 30%手数料回避、iOS-Web分離パターンで全粗利確保
> 関連: [[Deepgram-only設計_2026]] / [[価格体系]] / [[プロダクト概要]]

---

## 0. 設計の一行サマリ

**iOS アプリ内で課金しない。価格表示もしない。ユーザーは lecsy.app（Web）で Stripe Checkout → サブスク状態を API 経由で iOS に反映。Netflix / Notion / Spotify と同じモデル。**

---

## 1. なぜ Stripe 一本か

### 1.1 Apple IAP 30% の致命性

| プラン | 売上 | Apple 30% | Deepgram原価 | **Apple経由の粗利率** |
|------|-----|---------|----------|-----------|
| Pro $11.99 | $11.99 | -$3.60 | -$2.80 | **44%** |
| Student $5.99 | $5.99 | -$1.80 | -$2.30 | **27%** |

**Student プランは赤字寸前**。グローバル展開するには致命的。

### 1.2 Stripe の粗利改善

| プラン | 売上 | Stripe 2.9%+$0.30 | Deepgram原価 | **Stripe粗利率** |
|------|-----|----------------|----------|-----------|
| Pro $11.99 | $11.99 | -$0.65 | -$2.80 | **69%** |
| Student $5.99 | $5.99 | -$0.47 | -$2.30 | **49%** |

**B2C Pro で +25pt の粗利改善**。グローバル展開が経済的に成立する。

### 1.3 Apple Small Business Program は不十分
- 最初の$1M売上は15%手数料に軽減される制度
- ただし**$1M超えた瞬間に30%**に戻る
- グローバル展開なら当然$1M超えるので、将来的な負債になる
- Stripe一本なら永遠に2.9%で安定

### 1.4 その他の理由
- **B2B契約**: Apple IAPは個人課金のみ、per-seat契約不可
- **Invoice・ACH**: 大学はクレカ払いを嫌う、銀行振込が主流 → Stripe Invoice必須
- **多通貨**: Stripeは170+通貨自動対応、Appleは為替レート悪い
- **Enterprise契約**: 数千ドルの手動請求はAppleではできない

---

## 2. iOS-Web 分離の具体パターン

### 2.1 iOS アプリ側
```swift
// OK なもの
✅ アカウント作成・ログイン
✅ 全機能の無料利用（Free tier）
✅ Pro機能タップ時に「Pro でご利用いただけます」と表示
✅ 「lecsy.app で管理」というテキストリンク（決済ボタンではない一般Webリンク）
✅ サブスク状態のAPI取得（Stripeから来た情報をSupabase経由で）

// NG なもの
❌ アプリ内で価格を表示（"$11.99/月" など）
❌ アプリ内に「Proにアップグレード」ボタン（Apple審査で弾かれる）
❌ 決済ページへの直接リンク（/billing ではなく / ならOK）
❌ アプリ内でクレカ情報入力
```

### 2.2 ユーザー体験フロー

```
1. App Store から lecsy DL
2. iOS で Sign in with Apple / Email でアカウント作成
3. Free tier を使う（300分/月、Prerecordedのみ）
4. Pro機能（Streaming）をタップ
   → 「この機能は Pro で使えます。lecsy.app で詳細をご覧ください」
5. ユーザー自身が lecsy.app にアクセス
6. /pricing でプラン比較
7. /billing で Stripe Checkout → 課金
8. iOS アプリを再起動 or 「プランを更新」タップ
9. API から Pro 状態取得 → Streaming 解放
```

### 2.3 Apple 審査通過のポイント（実績ベース）

| リスク | 対応 |
|-----|-----|
| アプリ内価格表示 | 一切しない |
| 「Upgrade」ボタン | 「詳細はlecsy.app」テキストのみ |
| Web誘導の明確性 | ユーザーが能動的に移動する設計 |
| クレカ入力画面 | iOS 内に一切置かない |
| エラーメッセージ | 「Proが必要です」程度、課金促進表現は避ける |
| App Store Connect審査 | アプリ説明に「一部機能はWebでサブスク」と明記 |

**過去の実例:** Netflix, Spotify, Notion, Linear, Figma, Amazon Kindle は長年このパターン。Apple は明示的に許可している。

---

## 3. 技術実装

### 3.1 Stripe 商品構成

```
Products:
├─ lecsy Pro
│   └─ Prices:
│       ├─ $11.99/month (USD)
│       ├─ $89/year (USD)
│       ├─ €11.99/month (EUR)
│       ├─ £10.99/month (GBP)
│       └─ ¥1,890/month (JPY)
│
├─ lecsy Pro Student
│   └─ Prices:
│       ├─ $5.99/month (USD)
│       ├─ $49/year (USD)
│       └─ (各通貨対応)
│
├─ lecsy Business Starter
│   └─ Prices:
│       └─ $349/month (USD)
│
├─ lecsy Business Growth
│   └─ Prices:
│       └─ $699/month (USD)
│
└─ lecsy Business Enterprise
    └─ (カスタム、Invoice経由)
```

### 3.2 課金フロー実装

```
Web (lecsy.app)
  /pricing
    └─ ユーザー選択 → /billing/checkout?plan=pro_monthly
  /billing
    └─ Stripe Checkout Session 生成
        └─ Supabase Edge Function: create-checkout-session
            └─ stripe.checkout.sessions.create({
                mode: 'subscription',
                line_items: [{ price: 'price_xxx', quantity: 1 }],
                customer_email: user.email,
                success_url: 'https://lecsy.app/billing/success',
                cancel_url: 'https://lecsy.app/pricing',
                metadata: { user_id, plan }
              })
  /billing/success
    └─ "Thank you!" + "Open lecsy app to start using Pro"

Stripe Webhook: /api/stripe/webhook
  ├─ customer.subscription.created → Supabase `profiles.plan = 'pro'`
  ├─ customer.subscription.updated → 同上
  ├─ customer.subscription.deleted → Free に戻す
  ├─ invoice.paid → 継続
  └─ invoice.payment_failed → リトライ対応

iOS App
  └─ ログイン時 / Pull-to-refresh 時
      └─ Supabase API で profiles.plan を取得
          └─ UI State 更新（Streaming UI 解放 etc）
```

### 3.3 Supabase スキーマ

```sql
-- ユーザーのプラン状態
alter table public.profiles
  add column plan text not null default 'free',  -- 'free' | 'pro' | 'student' | 'business'
  add column stripe_customer_id text,
  add column subscription_id text,
  add column plan_expires_at timestamptz,
  add column edu_domain_verified boolean default false;

-- Stripe Webhook ログ
create table public.stripe_events (
  id text primary key,  -- Stripe event ID
  type text not null,
  data jsonb not null,
  processed_at timestamptz not null default now()
);

-- 組織のプラン（B2B）
alter table public.organizations
  add column plan text not null default 'starter',
  add column stripe_subscription_id text,
  add column seats int not null default 50,
  add column billing_email text;
```

### 3.4 Edge Functions 必要なもの

```
supabase/functions/
├─ create-checkout-session/   ← Stripe Checkout URL 発行
├─ create-portal-session/     ← サブスク管理ポータルURL発行
├─ stripe-webhook/            ← Stripe イベント受信
├─ verify-edu-domain/         ← 学生割引 .edu/.ac.* 認証
└─ grant-access/              ← Manual grant（Enterprise用、Invoice支払い後）
```

### 3.5 教育ドメイン認証（Student plan）

```typescript
// Edge Function: verify-edu-domain
const EDU_DOMAINS = [
  /\.edu$/,
  /\.ac\.uk$/,
  /\.ac\.jp$/,
  /\.ac\.kr$/,
  /\.edu\.au$/,
  /\.edu\.cn$/,
  /\.uni-.*\.de$/,
  /^.*\.fr$/,  // 仏は大学ドメインが多様、個別判定
  // 追加予定
];

function isEducationDomain(email: string): boolean {
  const domain = email.split('@')[1].toLowerCase();
  return EDU_DOMAINS.some(regex => regex.test(domain));
}
```

### 3.6 B2B Enterprise フロー

```
1. /enterprise/contact で商談フォーム送信
2. たくみ が email で返信、Zoom / 対面ミーティング
3. カスタム見積もり作成
4. DPA / FERPA Addendum / MSA 署名
5. Stripe Invoice （Net 30/60）発行
6. 大学 ACH / 銀行振込
7. 支払い確認後、grant-access Edge Function で組織作成・SSO設定
```

---

## 4. 多通貨・多地域対応

### 4.1 通貨自動切替
- Stripe Price で各通貨の Price object 作成
- ユーザーのブラウザ言語 or 選択から判定
- ログイン済みユーザーは profile に preferred_currency を保存

### 4.2 税金対応（Stripe Tax）
- Stripe Tax で各国付加価値税を自動計算
- **EU VAT**: B2B は VAT ID 入力で reverse charge
- **米国 sales tax**: 州ごと異なる、Stripe Tax で自動化
- **日本消費税**: 10% 自動加算
- **UK VAT**: 20% 自動加算

### 4.3 地域別価格（PPP、Phase 4で）
- Stripe Geographical pricing で同一商品を地域別単価に
- 中国・南米・東南アジア向けは30-50%ディスカウント版

---

## 5. Apple審査対応

### 5.1 App Store Connect の記載内容

**App Description に明記:**
```
lecsy is free to download and use. Some advanced features
(real-time captioning, extended monthly limits) are available
through a Pro subscription, managed at lecsy.app.
```

**Privacy Policy に明記:**
- Stripe使用、subprocessors リスト
- 課金はWebで完結、iOS内で決済なし

**Pricing Tier**: **Free のみ**（Apple IAPを一切登録しない）

### 5.2 App Review 質問への回答テンプレ

Q: なぜ Pro機能にアプリ内課金がないのか？
A: lecsy Pro is a web-based subscription service, similar to Netflix or Spotify. Users subscribe and manage their account on lecsy.app. The iOS app then grants access to Pro features based on their subscription status retrieved from our API.

Q: アプリ内で価格が表示されない理由は？
A: Per App Store Review Guidelines 3.1.3(b), reader/external subscription apps do not display pricing in-app. All pricing and subscription management occurs on lecsy.app.

### 5.3 Reader App Declaration（必要に応じて）
- App Store Connect で "Reader App" として申請可能
- lecsy は "Digital content and services" カテゴリに該当する可能性
- 申請すれば明示的に外部課金が許可される
- ただし現時点では申請せず運用、問題出たら申請

---

## 6. B2B （Invoice）フロー詳細

### 6.1 Starter / Growth（セルフサーブ）
```
Web /pricing/business
  → /business/signup （組織名・席数）
  → Stripe Checkout （月額 or 年額）
  → 課金成功後、組織作成 + 管理者招待リンク送付
```

### 6.2 Enterprise（商談）
```
Web /enterprise/contact
  → たくみ email / Zoom
  → 見積もり（DocuSign or PDF）
  → DPA / FERPA Addendum 署名（Dropbox Sign 等）
  → Stripe Invoice 送信（Net 30/60、ACH対応）
  → 支払い受領後、Supabase で組織作成・SSO設定
```

### 6.3 Invoice支払い方法
- **ACH**: 米国銀行振込（低手数料 0.8%、上限$5）
- **Wire Transfer**: 国際送金（高速、$25-50の送金手数料別途）
- **Check**: 米国大学で稀にあり、住所記載
- **PO (Purchase Order)**: 大学発注書 → Net 30 で Invoice払い

---

## 7. セキュリティ

### 7.1 Secrets管理
```
Supabase Secrets:
  STRIPE_SECRET_KEY = sk_live_xxx
  STRIPE_WEBHOOK_SECRET = whsec_xxx
  STRIPE_PUBLIC_KEY = pk_live_xxx (client-side使用)

環境:
  Production: sk_live / pk_live
  Development: sk_test / pk_test
```

### 7.2 Webhook署名検証
```typescript
// 必ず署名検証
const event = stripe.webhooks.constructEvent(
  body,
  signature,
  process.env.STRIPE_WEBHOOK_SECRET
);
```

### 7.3 IdempotencyKey
- 全重要APIコールで idempotency_key を付与
- 二重課金・二重更新を防止

---

## 8. リスクと対策

| リスク | 対策 |
|------|-----|
| Apple審査で弾かれる | 過去実例多数、Reader App申請可能 |
| Stripe Webhook取りこぼし | Event テーブルに全記録、1日1回 reconcile |
| ユーザーが支払ったのに反映されない | Webhook処理に retry、1時間内reconcile |
| チャージバック | Stripe Radar で検知、Enterprise は NDA で protection |
| 通貨レート変動 | 年1回 Price 見直し |
| EU VAT 誤算 | Stripe Tax にほぼ全任せ |
| Student割引詐称 | 教育ドメイン認証必須、VPN検知、怪しければ手動レビュー |

---

## 9. 実装チェックリスト（6/1 ローンチまで）

### Stripe 側
- [ ] Stripe Business アカウント作成（LLC設立後）
- [ ] Tax ID・事業情報登録
- [ ] 商品・価格設定（B2C Pro/Student、B2B Starter/Growth）
- [ ] Stripe Tax 有効化
- [ ] Webhook endpoint 登録
- [ ] Test mode で全フロー確認
- [ ] Live mode 切替

### Supabase 側
- [ ] DB スキーマ更新（plan, stripe_customer_id 等）
- [ ] Edge Functions 5本実装
- [ ] Webhook 署名検証
- [ ] RLS ポリシー更新

### Web 側
- [ ] /pricing LP
- [ ] /billing ページ（Checkout リンク）
- [ ] /billing/portal ページ（Stripe Customer Portal）
- [ ] /enterprise/contact フォーム
- [ ] /business/signup フロー

### iOS 側
- [ ] 価格表示・IAP UI の完全削除
- [ ] プラン状態 API フェッチ
- [ ] Pro gated 機能の UI 分岐
- [ ] 「lecsy.app で管理」リンク（SFSafariViewController）
- [ ] App Store Connect メタデータ更新

### コンプライアンス
- [ ] Privacy Policy に Stripe 記載
- [ ] Subprocessor 一覧更新
- [ ] Terms of Service 改訂

---

## 10. 参考リソース

- Stripe Docs: https://stripe.com/docs
- App Store Review Guidelines 3.1.3(b): https://developer.apple.com/app-store/review/guidelines/
- Notion の IAPなしサブスク事例
- Netflix の Reader App 運用
- Digital Markets Act (EU) 外部決済ガイダンス

---

*関連: [Deepgram-only設計_2026](../技術/Deepgram-only設計_2026.md) / [価格体系](./価格体系.md) / [プロダクト概要](../プロダクト/プロダクト概要.md)*
