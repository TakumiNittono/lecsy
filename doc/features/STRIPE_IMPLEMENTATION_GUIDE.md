# Stripe 課金実装ガイド — lecsy Pro ($2.99/月)

**最終更新日**: 2026年2月6日

---

## 目次

1. [概要](#1-概要)
2. [提供内容 — Free vs Pro](#2-提供内容--free-vs-pro)
3. [アーキテクチャ全体図](#3-アーキテクチャ全体図)
4. [Stripe ダッシュボード設定](#4-stripe-ダッシュボード設定)
5. [環境変数の設定](#5-環境変数の設定)
6. [バックエンド実装（実装済み）](#6-バックエンド実装実装済み)
7. [フロントエンド実装（未実装・要対応）](#7-フロントエンド実装未実装要対応)
8. [Webhook 処理](#8-webhook-処理)
9. [サブスクリプション管理](#9-サブスクリプション管理)
10. [テスト手順](#10-テスト手順)
11. [デプロイチェックリスト](#11-デプロイチェックリスト)
12. [App Store 規約への配慮](#12-app-store-規約への配慮)
13. [トラブルシューティング](#13-トラブルシューティング)

---

## 1. 概要

### 課金モデル

| 項目 | 内容 |
|------|------|
| **プラン名** | lecsy Pro |
| **価格** | $2.99/月（サブスクリプション） |
| **決済手段** | クレジットカード（Stripe経由） |
| **課金プラットフォーム** | Webアプリのみ（iOS App Store外） |
| **フリートライアル** | なし（無料プランが十分充実しているため） |
| **解約** | いつでも可能（Stripe Customer Portal経由） |

### なぜ $2.99 なのか

- 学生向けアプリとして手頃な価格帯
- コーヒー1杯以下の価格で心理的ハードルが低い
- AI API コスト（OpenAI GPT-4 Turbo）をカバーしつつ利益を確保
- 目標：MAU 10,000人 × 5%コンバージョン = 500人 × $2.99 = **$1,495/月**

### 技術スタック

| 技術 | 用途 |
|------|------|
| **Stripe** | 決済処理・サブスクリプション管理 |
| **Next.js 14** | Webフロントエンド + API Routes |
| **Supabase** | 認証・DB（subscriptionsテーブル） |
| **Supabase Edge Functions** | Webhook処理・AI要約処理 |
| **Vercel** | Webアプリホスティング |

---

## 2. 提供内容 — Free vs Pro

### Free プラン（永久無料）

| 機能 | 詳細 |
|------|------|
| 録音 | **無制限** — ワンタップ録音、バックグラウンド録音、画面ロック中も動作 |
| 文字起こし | **無制限** — WhisperKit によるオフライン処理、日本語・英語対応 |
| Web閲覧 | テキストの閲覧・検索・コピー・印刷 |
| ライブラリ管理 | タイトル編集・削除 |
| プライバシー | 音声データは端末内に留まる（テキストのみ任意でクラウド同期） |

### Pro プラン（$2.99/月）

Free プランの全機能に加えて：

| 機能 | 詳細 |
|------|------|
| **AI 要約** | GPT-4 Turbo による講義内容の自動要約（200-300文字） |
| **セクション分割** | 講義をセクションごとに分割し、各セクションの1行要約を生成 |
| **重要ポイント抽出** | 講義から重要なキーポイントをリストアップ |
| **試験対策モード** | 重要用語の抽出・定義、Q&A形式の問題生成、出題予想 |
| **フェアリミット** | 1日20回 / 1ヶ月400回の要約生成 |

### Pro 機能の詳細

#### AI 要約モード (`mode: "summary"`)
```json
{
  "summary": "全体の要約（200-300文字）",
  "key_points": ["重要ポイント1", "重要ポイント2", "..."],
  "sections": [
    {"heading": "セクション名", "content": "1行要約"},
    "..."
  ]
}
```

#### 試験対策モード (`mode: "exam"`)
```json
{
  "key_terms": [
    {"term": "用語", "definition": "定義"},
    "..."
  ],
  "questions": [
    {"question": "問題", "answer": "解答"},
    "..."
  ],
  "predictions": ["出題予想1", "出題予想2", "..."]
}
```

---

## 3. アーキテクチャ全体図

```
┌──────────────────────────────────────────────────────────────────────┐
│                         lecsy 課金フロー                              │
├──────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌──────────┐     ┌──────────────────┐     ┌──────────────────┐     │
│  │ ユーザー  │────▶│  Next.js Web App  │────▶│  Stripe Checkout │     │
│  │ (ブラウザ)│     │  (Vercel)         │     │  Session         │     │
│  └──────────┘     └──────────────────┘     └────────┬─────────┘     │
│       ▲                                              │               │
│       │                                              ▼               │
│       │           ┌──────────────────┐     ┌──────────────────┐     │
│       │           │  Supabase DB     │◀────│  Stripe Webhook  │     │
│       │           │  (subscriptions) │     │  (Edge Function) │     │
│       │           └────────┬─────────┘     └──────────────────┘     │
│       │                    │                                         │
│       │                    ▼                                         │
│       │           ┌──────────────────┐     ┌──────────────────┐     │
│       └───────────│  Pro機能チェック  │────▶│  OpenAI GPT-4    │     │
│                   │  (summarize)     │     │  Turbo           │     │
│                   └──────────────────┘     └──────────────────┘     │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
```

### フロー概要

1. **ユーザーがWebアプリで「Upgrade to Pro」をクリック**
2. **Next.js API Route** が Stripe Checkout Session を作成
3. **Stripe Checkout ページ**にリダイレクト → カード情報入力
4. **決済成功** → Stripe が Webhook を送信
5. **Supabase Edge Function** が Webhook を受信 → `subscriptions` テーブルを更新
6. **Pro機能利用時** → `subscriptions` テーブルで `status: "active"` を確認
7. **AI要約を実行** → OpenAI GPT-4 Turbo で要約生成

---

## 4. Stripe ダッシュボード設定

### 4.1 Stripe アカウント作成

1. [https://dashboard.stripe.com/register](https://dashboard.stripe.com/register) でアカウント作成
2. ビジネス情報を入力（個人事業主でもOK）
3. 本番環境を有効化するために銀行口座を登録

### 4.2 商品（Product）の作成

1. Stripe ダッシュボード → **Products** → **Add Product**
2. 以下の情報を入力：

| 項目 | 値 |
|------|-----|
| **Product name** | lecsy Pro |
| **Description** | AI-powered lecture summaries, key points extraction, and exam prep mode for students. |
| **Pricing model** | Recurring |
| **Price** | $2.99 |
| **Billing period** | Monthly |
| **Currency** | USD |

3. 作成後、**Price ID** をコピー（`price_xxxxxxxxxxxxx` の形式）

### 4.3 Customer Portal の設定

1. Stripe ダッシュボード → **Settings** → **Billing** → **Customer Portal**
2. 以下を有効化：
   - **Customers can switch plans**: OFF（プランは1つのみ）
   - **Customers can update payment methods**: ON
   - **Customers can cancel subscriptions**: ON
   - **Cancellation flow**: Cancel at end of billing period
3. **Business information** にアプリ名と利用規約URLを入力
4. **Save** をクリック

### 4.4 Webhook の設定

1. Stripe ダッシュボード → **Developers** → **Webhooks**
2. **Add endpoint** をクリック
3. 以下を設定：

| 項目 | 値 |
|------|-----|
| **Endpoint URL** | `https://<SUPABASE_PROJECT_REF>.supabase.co/functions/v1/stripe-webhook` |
| **Events to listen** | `checkout.session.completed`, `customer.subscription.updated`, `customer.subscription.deleted`, `invoice.payment_failed` |

4. 作成後、**Signing secret** をコピー（`whsec_xxxxxxxxxxxxx` の形式）

---

## 5. 環境変数の設定

### 5.1 Vercel（Next.js Web アプリ）

Vercel ダッシュボード → プロジェクト → **Settings** → **Environment Variables** に以下を追加：

```env
# Stripe
STRIPE_SECRET_KEY=sk_live_xxxxxxxxxxxxx         # Stripe Secret Key（本番用）
STRIPE_PRICE_ID=price_xxxxxxxxxxxxx             # 商品のPrice ID
NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY=pk_live_xxxx # Stripe Publishable Key（フロント用）

# App URL（リダイレクト先）
NEXT_PUBLIC_APP_URL=https://lecsy.vercel.app     # 本番URL
```

> **テスト環境では** `sk_test_xxx` と `pk_test_xxx` を使用すること

### 5.2 Supabase Edge Functions

Supabase ダッシュボード → **Edge Functions** → **Secrets** に以下を追加：

```env
# Stripe
STRIPE_SECRET_KEY=sk_live_xxxxxxxxxxxxx
STRIPE_WEBHOOK_SECRET=whsec_xxxxxxxxxxxxx

# OpenAI（AI要約用）
OPENAI_API_KEY=sk-xxxxxxxxxxxxx
```

---

## 6. バックエンド実装（実装済み）

### 6.1 Checkout Session 作成 API

**ファイル**: `web/app/api/create-checkout-session/route.ts`
**状態**: ✅ 実装済み

```typescript
// 主要な処理フロー:
// 1. Supabase認証でユーザーを確認
// 2. 既存のStripe Customerを確認（なければ作成）
// 3. Stripe Checkout Sessionを作成（mode: "subscription"）
// 4. Checkout URLを返す
```

**エンドポイント**: `POST /api/create-checkout-session`
**認証**: 必須（Supabase Auth）
**レスポンス**: `{ url: "https://checkout.stripe.com/..." }`

### 6.2 Customer Portal API

**ファイル**: `web/app/api/create-portal-session/route.ts`
**状態**: ✅ 実装済み

```typescript
// 主要な処理フロー:
// 1. Supabase認証でユーザーを確認
// 2. subscriptionsテーブルからStripe Customer IDを取得
// 3. Stripe Customer Portal Sessionを作成
// 4. Portal URLを返す
```

**エンドポイント**: `POST /api/create-portal-session`
**認証**: 必須（Supabase Auth）
**レスポンス**: `{ url: "https://billing.stripe.com/..." }`

### 6.3 Stripe Webhook ハンドラー

**ファイル**: `supabase/functions/stripe-webhook/index.ts`
**状態**: ✅ 実装済み

処理するイベント：

| イベント | 処理内容 |
|---------|---------|
| `checkout.session.completed` | サブスクリプション作成 → `subscriptions` テーブルに `status: "active"` で UPSERT |
| `customer.subscription.updated` | サブスクリプション更新 → `status` と `current_period_end` を更新 |
| `customer.subscription.deleted` | サブスクリプション解約 → `status: "canceled"` に更新 |
| `invoice.payment_failed` | 支払い失敗 → `status: "past_due"` に更新 |

### 6.4 AI 要約 Edge Function

**ファイル**: `supabase/functions/summarize/index.ts`
**状態**: ✅ 実装済み

```typescript
// 主要な処理フロー:
// 1. 認証チェック
// 2. Pro状態チェック（subscriptions.status === "active"）
// 3. フェアリミットチェック（日次20回）
// 4. キャッシュチェック（既存の要約があれば返す）
// 5. OpenAI GPT-4 Turbo で要約/試験対策を生成
// 6. summariesテーブルに保存
// 7. usage_logsに記録
```

### 6.5 データベーススキーマ

#### `subscriptions` テーブル

```sql
CREATE TABLE subscriptions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,
  status TEXT NOT NULL DEFAULT 'free',  -- free, active, canceled, past_due
  provider TEXT DEFAULT 'stripe',
  stripe_customer_id TEXT,
  stripe_subscription_id TEXT,
  current_period_start TIMESTAMPTZ,
  current_period_end TIMESTAMPTZ,
  cancel_at_period_end BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- RLS ポリシー
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can read own subscription"
  ON subscriptions FOR SELECT USING (auth.uid() = user_id);
```

#### `usage_logs` テーブル

```sql
CREATE TABLE usage_logs (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  action TEXT NOT NULL,  -- 'summarize' | 'exam_mode'
  transcript_id UUID REFERENCES transcripts(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- RLS ポリシー
ALTER TABLE usage_logs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can read own usage"
  ON usage_logs FOR SELECT USING (auth.uid() = user_id);
```

#### `summaries` テーブル

```sql
CREATE TABLE summaries (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  transcript_id UUID REFERENCES transcripts(id) ON DELETE CASCADE UNIQUE,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  model TEXT DEFAULT 'gpt-4-turbo',
  summary TEXT,
  key_points JSONB,
  sections JSONB,
  exam_mode JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- RLS ポリシー
ALTER TABLE summaries ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can read own summaries"
  ON summaries FOR SELECT USING (auth.uid() = user_id);
```

---

## 7. フロントエンド実装（未実装・要対応）

### 7.1 課金ボタンコンポーネント（新規作成が必要）

**ファイル**: `web/components/UpgradeButton.tsx`

```tsx
'use client'

import { useState } from 'react'
import { createClient } from '@/utils/supabase/client'

export default function UpgradeButton() {
  const [loading, setLoading] = useState(false)

  const handleUpgrade = async () => {
    setLoading(true)
    try {
      const res = await fetch('/api/create-checkout-session', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
      })
      const data = await res.json()
      if (data.url) {
        window.location.href = data.url
      } else {
        alert('Error creating checkout session')
      }
    } catch (error) {
      console.error('Checkout error:', error)
      alert('Something went wrong. Please try again.')
    } finally {
      setLoading(false)
    }
  }

  return (
    <button
      onClick={handleUpgrade}
      disabled={loading}
      className="w-full px-6 py-4 bg-gradient-to-r from-blue-600 to-blue-500 
                 text-white rounded-xl font-semibold hover:from-blue-700 
                 hover:to-blue-600 transition-all shadow-lg hover:shadow-xl 
                 transform hover:scale-105 disabled:opacity-50 
                 disabled:cursor-not-allowed disabled:transform-none"
    >
      {loading ? 'Redirecting...' : 'Upgrade to Pro — $2.99/mo'}
    </button>
  )
}
```

### 7.2 サブスクリプション管理ボタン（新規作成が必要）

**ファイル**: `web/components/ManageSubscriptionButton.tsx`

```tsx
'use client'

import { useState } from 'react'

export default function ManageSubscriptionButton() {
  const [loading, setLoading] = useState(false)

  const handleManage = async () => {
    setLoading(true)
    try {
      const res = await fetch('/api/create-portal-session', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
      })
      const data = await res.json()
      if (data.url) {
        window.location.href = data.url
      }
    } catch (error) {
      console.error('Portal error:', error)
    } finally {
      setLoading(false)
    }
  }

  return (
    <button
      onClick={handleManage}
      disabled={loading}
      className="text-sm text-blue-600 hover:text-blue-800 underline 
                 disabled:opacity-50 disabled:cursor-not-allowed"
    >
      {loading ? 'Loading...' : 'Manage Subscription'}
    </button>
  )
}
```

### 7.3 ダッシュボードの Pro 状態表示（修正が必要）

**ファイル**: `web/app/app/page.tsx`

ダッシュボードのSubscriptionカードを更新して、Pro状態を動的に表示する必要がある：

```tsx
// subscriptions テーブルからユーザーのサブスク状態を取得
const { data: subscription } = await supabase
  .from('subscriptions')
  .select('status, current_period_end, cancel_at_period_end')
  .eq('user_id', user.id)
  .single()

const isPro = subscription?.status === 'active'
const willCancel = subscription?.cancel_at_period_end

// Subscription カードの表示例:
// isPro → "Pro" + 次回更新日 + 管理ボタン
// !isPro → "Free" + アップグレードボタン
```

### 7.4 ランディングページの更新（修正が必要）

**ファイル**: `web/app/page.tsx`

- 「Coming Soon」バッジを削除
- Pro カードに `UpgradeButton` コンポーネントを配置
- または「Start Free, Upgrade Later」のフローに変更

### 7.5 AI 要約表示ページ（新規作成が必要）

**ファイル**: `web/app/app/t/[id]/summary/page.tsx`

```tsx
// このページで必要な機能:
// 1. トランスクリプト詳細ページから「AI Summary」ボタンで遷移
// 2. summarize Edge Function を呼び出し
// 3. 要約結果を表示（サマリー / キーポイント / セクション分割）
// 4. 試験対策モードへの切り替えタブ
// 5. ローディング状態とエラーハンドリング
```

### 7.6 決済成功/キャンセル時のUI（新規作成が必要）

`/app?success=true` と `/app?canceled=true` のクエリパラメータに応じたトースト通知を実装：

```tsx
// web/app/app/page.tsx に追加
// URLパラメータをチェックしてトースト表示
// success=true → "Welcome to Pro! AI features are now available."
// canceled=true → "Checkout canceled. You can upgrade anytime."
```

---

## 8. Webhook 処理

### 8.1 処理フロー詳細

```
Stripe → Webhook POST → Supabase Edge Function → DB更新
```

#### checkout.session.completed（初回課金成功）

```
1. Stripe署名を検証（whsec_xxx）
2. session.metadata.user_id を取得
3. UUIDフォーマットを検証
4. stripe.subscriptions.retrieve() でサブスクリプション詳細を取得
5. subscriptions テーブルに UPSERT:
   - status: "active"
   - stripe_customer_id: session.customer
   - stripe_subscription_id: subscription.id
   - current_period_start / current_period_end
```

#### customer.subscription.updated（更新/変更）

```
1. subscription.status を確認
2. subscriptions テーブルを UPDATE:
   - status: active | past_due | etc.
   - current_period_end: 新しい期限
   - cancel_at_period_end: 解約予定フラグ
```

#### customer.subscription.deleted（完全解約）

```
1. subscriptions テーブルを UPDATE:
   - status: "canceled"
```

#### invoice.payment_failed（支払い失敗）

```
1. subscriptions テーブルを UPDATE:
   - status: "past_due"
```

### 8.2 セキュリティ対策（実装済み）

- ✅ Stripe 署名検証（`stripe.webhooks.constructEvent`）
- ✅ UUID フォーマット検証
- ✅ Service Role Key でDB操作（RLSバイパス）
- ✅ エラー詳細を外部に公開しない
- ✅ 各イベントでのエラーハンドリング

---

## 9. サブスクリプション管理

### 9.1 サブスクリプションのライフサイクル

```
Free → Checkout → Active → (解約要求) → Cancel at period end → Canceled
                     ↓
              (支払い失敗) → Past Due → (再試行成功) → Active
                                    → (再試行失敗) → Canceled
```

### 9.2 ステータス一覧

| ステータス | 意味 | Pro機能 |
|-----------|------|---------|
| `free` (デフォルト) | 無料プラン | 使用不可 |
| `active` | 有効なサブスクリプション | **使用可能** |
| `past_due` | 支払い失敗（Stripeが自動リトライ中） | 使用不可 |
| `canceled` | 解約済み | 使用不可 |

### 9.3 解約フロー

1. ユーザーが「Manage Subscription」をクリック
2. Stripe Customer Portal にリダイレクト
3. Portal で「Cancel subscription」を選択
4. **期間終了時に解約**（即時解約ではない）
5. Webhook `customer.subscription.updated` が `cancel_at_period_end: true` で送信
6. 期間終了時に `customer.subscription.deleted` が送信 → `status: "canceled"`

---

## 10. テスト手順

### 10.1 テスト環境の準備

1. Stripe ダッシュボードで **Test mode** を有効化
2. テスト用APIキー（`sk_test_xxx`, `pk_test_xxx`）を使用
3. Vercel の Preview 環境にテスト用環境変数を設定

### 10.2 テスト用カード番号

| カード番号 | 結果 |
|-----------|------|
| `4242 4242 4242 4242` | 成功 |
| `4000 0000 0000 3220` | 3Dセキュア認証が必要 |
| `4000 0000 0000 0002` | カード拒否 |
| `4000 0000 0000 9995` | 残高不足 |

**有効期限**: 未来の任意の日付（例: 12/34）
**CVC**: 任意の3桁（例: 123）

### 10.3 テスト手順チェックリスト

#### Checkout フロー

- [ ] ログイン状態で「Upgrade to Pro」をクリック
- [ ] Stripe Checkout ページが表示される
- [ ] テストカードで決済完了
- [ ] `/app?success=true` にリダイレクトされる
- [ ] `subscriptions` テーブルに `status: "active"` のレコードが作成される
- [ ] ダッシュボードのSubscriptionカードが「Pro」に変わる

#### Pro 機能

- [ ] Pro ユーザーとしてAI要約が利用できる
- [ ] フェアリミット（日次20回）が正しく動作する
- [ ] 非Pro ユーザーはAI要約が利用できない（403エラー）

#### 解約フロー

- [ ] 「Manage Subscription」から Customer Portal にアクセスできる
- [ ] Portal で解約操作ができる
- [ ] `cancel_at_period_end: true` が設定される
- [ ] 期間終了後に `status: "canceled"` になる

#### Webhook

- [ ] Stripe CLI でローカルテスト：`stripe listen --forward-to localhost:54321/functions/v1/stripe-webhook`
- [ ] 全イベントが正しく処理される
- [ ] 無効な署名は拒否される

### 10.4 Stripe CLI でのローカルテスト

```bash
# Stripe CLI インストール
brew install stripe/stripe-cli/stripe

# ログイン
stripe login

# Webhook をローカルに転送
stripe listen --forward-to http://localhost:54321/functions/v1/stripe-webhook

# テストイベントを送信
stripe trigger checkout.session.completed
stripe trigger customer.subscription.updated
stripe trigger customer.subscription.deleted
stripe trigger invoice.payment_failed
```

---

## 11. デプロイチェックリスト

### Phase 1: 準備

- [ ] Stripe 本番アカウントの有効化（銀行口座登録済み）
- [ ] 本番用 Product & Price の作成（$2.99/月）
- [ ] Customer Portal の設定完了
- [ ] Webhook エンドポイントの登録（本番URL）

### Phase 2: 環境変数

- [ ] Vercel に本番用 `STRIPE_SECRET_KEY` を設定
- [ ] Vercel に本番用 `STRIPE_PRICE_ID` を設定
- [ ] Vercel に本番用 `NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY` を設定
- [ ] Supabase に本番用 `STRIPE_SECRET_KEY` を設定
- [ ] Supabase に本番用 `STRIPE_WEBHOOK_SECRET` を設定
- [ ] Supabase に `OPENAI_API_KEY` を設定

### Phase 3: フロントエンド

- [ ] `UpgradeButton` コンポーネント作成
- [ ] `ManageSubscriptionButton` コンポーネント作成
- [ ] ダッシュボードのPro状態表示更新
- [ ] ランディングページの「Coming Soon」を削除
- [ ] 決済成功/キャンセルのトースト通知実装
- [ ] AI要約表示ページ作成

### Phase 4: テスト

- [ ] テスト環境で全フロー確認
- [ ] Webhook の動作確認
- [ ] 解約フローの確認
- [ ] エラーケースの確認

### Phase 5: 本番リリース

- [ ] 本番環境にデプロイ
- [ ] 本番 Webhook の動作確認
- [ ] 実際のカードでテスト購入 → 即解約
- [ ] ユーザーへの告知

---

## 12. App Store 規約への配慮

### 重要な注意点

| ルール | 対応 |
|--------|------|
| iOSアプリ内でStripe課金への**直接誘導は禁止** | ✅ iOSアプリ内に課金ボタンは設置しない |
| Webアプリへの一般的なリンクは許可 | ✅ 「Open on Web」ボタンで自然にWeb誘導 |
| 無料機能が完全に動作すること | ✅ 録音・文字起こし・Web閲覧は全て無料 |
| 外部課金のメリットをアプリ内で宣伝しない | ✅ iOSアプリ内でPro機能の詳細は表示しない |

### iOSアプリでの推奨対応

```
❌ NG: 「Pro にアップグレードして AI 要約を使おう！$2.99/月」
❌ NG: 「Stripe で購入」ボタン
✅ OK: 「Open on Web」ボタン（一般的なWeb誘導）
✅ OK: Web で追加機能が利用可能（詳細は Web で確認）
```

---

## 13. トラブルシューティング

### よくある問題と解決策

#### Checkout Session 作成に失敗する

```
原因: STRIPE_SECRET_KEY または STRIPE_PRICE_ID が未設定/無効
対策: Vercel の環境変数を確認。テスト/本番キーの混在に注意
```

#### Webhook が届かない

```
原因: Webhook URLの誤り、またはWebhook Secretの不一致
対策:
1. Stripe ダッシュボードで Webhook のログを確認
2. Endpoint URL が正しいか確認
3. STRIPE_WEBHOOK_SECRET が最新か確認
4. Supabase Edge Function がデプロイされているか確認
```

#### Pro 状態が反映されない

```
原因: Webhook処理は成功したがフロントが古いデータを表示
対策:
1. subscriptions テーブルを直接確認
2. ページをリロード（キャッシュ無効化）
3. Supabase のRLSポリシーを確認
```

#### 二重課金

```
原因: Checkout Session が重複作成された
対策:
1. 既存のStripe Customer IDを使い回す（実装済み）
2. Stripe ダッシュボードで確認・返金
3. Checkout Session にidempotencyキーを追加（推奨）
```

#### テスト環境と本番環境の混在

```
原因: テスト用キーと本番用キーが混在
対策:
1. Vercel の環境変数をプレビュー/本番で分ける
2. テスト用は必ず sk_test_ / pk_test_ を使用
3. 本番は sk_live_ / pk_live_ を使用
```

---

## まとめ

### 実装状況

| カテゴリ | 状態 | 詳細 |
|---------|------|------|
| Stripe バックエンド | ✅ 完了 | Checkout, Portal, Webhook |
| データベース | ✅ 完了 | subscriptions, usage_logs, summaries |
| AI 要約ロジック | ✅ 完了 | summarize Edge Function |
| フロントエンドUI | ⚠️ 未完了 | 課金ボタン、Pro表示、要約ページ |
| ランディングページ | ⚠️ 部分完了 | 「Coming Soon」→ 実際の課金ボタンに変更必要 |
| テスト | ⬜ 未実施 | 全フローのE2Eテスト必要 |

### 次のステップ（優先順位順）

1. **`UpgradeButton`** と **`ManageSubscriptionButton`** コンポーネントの作成
2. **ダッシュボード**のPro状態表示を動的に更新
3. **ランディングページ**の「Coming Soon」を削除し課金ボタン設置
4. **AI要約表示ページ**（`/app/t/[id]/summary`）の作成
5. **テスト環境**で全フローの動作確認
6. **本番リリース**

---

**作成日**: 2026年2月6日
