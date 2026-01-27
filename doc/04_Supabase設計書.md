# lecsy Supabase設計書

## 📋 目次

1. [概要](#概要)
2. [プロジェクト設定](#プロジェクト設定)
3. [認証設定](#認証設定)
4. [データベース設計](#データベース設計)
5. [Row Level Security](#row-level-security)
6. [Edge Functions](#edge-functions)
7. [Stripe連携](#stripe連携)

---

## 概要

### Supabaseの役割

| 機能 | 用途 |
|------|------|
| Auth | Google/Apple OAuth認証 |
| Database | 文字起こしテキスト・要約の保存 |
| RLS | ユーザーデータの完全隔離 |
| Edge Functions | カスタムAPI（保存・要約・課金） |
| Storage | 将来のPDFエクスポート等 |

### 接続情報

```
Project URL: https://[project-ref].supabase.co
Anon Key: eyJ... (公開可能)
Service Role Key: eyJ... (サーバーサイドのみ)
```

---

## プロジェクト設定

### 基本設定

| 項目 | 設定値 |
|------|--------|
| リージョン | Northeast Asia (Tokyo) 推奨 |
| Plan | Free → Pro（本番前に移行） |
| Database Password | 強力なパスワードを生成 |

### API設定

```
REST API: https://[project-ref].supabase.co/rest/v1
Auth API: https://[project-ref].supabase.co/auth/v1
Functions: https://[project-ref].supabase.co/functions/v1
```

---

## 認証設定

### OAuth Providers

#### Google OAuth

```
Client ID: xxx.apps.googleusercontent.com
Client Secret: xxx
Authorized Redirect URIs:
  - https://[project-ref].supabase.co/auth/v1/callback
```

**Google Cloud Console設定:**
1. OAuth同意画面を設定
2. 認証情報でOAuth 2.0クライアントIDを作成
3. iOS バンドルIDを追加: `com.takumiNittono.lecsy`
4. Authorized redirect URIsにSupabaseのコールバックURLを追加

#### Apple Sign In

```
Services ID: com.takumiNittono.lecsy.auth
Team ID: xxx
Key ID: xxx
Private Key: -----BEGIN PRIVATE KEY-----...
Authorized Redirect URIs:
  - https://[project-ref].supabase.co/auth/v1/callback
```

**Apple Developer Console設定:**
1. Identifiers > Services IDs を作成
2. Sign In with Apple を有効化
3. Configure で Return URLを設定
4. Keys > Sign In with Apple 用のキーを作成

### JWT設定

```
JWT Secret: 自動生成（変更不要）
JWT Expiry: 3600 (1時間)
```

### URL設定

```
Site URL: https://lecsy.app（本番URL）
Redirect URLs:
  - lecsy://auth/callback (iOS)
  - https://lecsy.app/auth/callback (Web)
```

---

## データベース設計

### ERD（Entity Relationship Diagram）

```
┌─────────────────────────────────────────────────────────────┐
│                      auth.users                             │
│  (Supabase管理)                                             │
│  ─────────────────────────────────────────                  │
│  id: uuid [PK]                                              │
│  email: text                                                │
│  ...                                                        │
└─────────────────────────┬───────────────────────────────────┘
                          │
          ┌───────────────┼───────────────┐
          │               │               │
          ▼               ▼               ▼
┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
│   transcripts   │ │    summaries    │ │  subscriptions  │
│  ─────────────  │ │  ─────────────  │ │  ─────────────  │
│  id [PK]        │ │  id [PK]        │ │  user_id [PK]   │
│  user_id [FK]   │ │  transcript_id  │ │  status         │
│  title          │ │  [FK]           │ │  provider       │
│  content        │ │  user_id [FK]   │ │  current_period │
│  created_at     │ │  summary        │ │  _end           │
│  updated_at     │ │  key_points     │ │  updated_at     │
│  source         │ │  exam_mode      │ └─────────────────┘
│  word_count     │ │  model          │
│  language       │ │  created_at     │
└─────────────────┘ │  updated_at     │
                    └─────────────────┘
```

### テーブル定義

#### transcripts（文字起こしテキスト）

```sql
CREATE TABLE transcripts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    title TEXT,
    content TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    source TEXT DEFAULT 'ios',
    word_count INTEGER,
    language TEXT,
    duration INTEGER,  -- 秒単位
    
    CONSTRAINT content_not_empty CHECK (content <> '')
);

-- インデックス
CREATE INDEX idx_transcripts_user_id ON transcripts(user_id);
CREATE INDEX idx_transcripts_created_at ON transcripts(created_at DESC);
CREATE INDEX idx_transcripts_user_created ON transcripts(user_id, created_at DESC);

-- updated_at 自動更新トリガー
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_transcripts_updated_at
    BEFORE UPDATE ON transcripts
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
```

#### summaries（AI要約結果）

```sql
CREATE TABLE summaries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    transcript_id UUID NOT NULL REFERENCES transcripts(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    summary TEXT,
    key_points JSONB,        -- ["ポイント1", "ポイント2", ...]
    sections JSONB,          -- [{"heading": "...", "content": "..."}, ...]
    exam_mode JSONB,         -- {"key_terms": [...], "questions": [...], "predictions": [...]}
    model TEXT DEFAULT 'gpt-4-turbo',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT one_summary_per_transcript UNIQUE (transcript_id)
);

-- インデックス
CREATE INDEX idx_summaries_transcript_id ON summaries(transcript_id);
CREATE INDEX idx_summaries_user_id ON summaries(user_id);

-- updated_at 自動更新
CREATE TRIGGER update_summaries_updated_at
    BEFORE UPDATE ON summaries
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
```

#### subscriptions（サブスクリプション状態）

```sql
CREATE TABLE subscriptions (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'free',  -- 'free', 'active', 'canceled', 'past_due'
    provider TEXT,                        -- 'stripe', 'appstore'
    stripe_customer_id TEXT,
    stripe_subscription_id TEXT,
    current_period_start TIMESTAMPTZ,
    current_period_end TIMESTAMPTZ,
    cancel_at_period_end BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT valid_status CHECK (status IN ('free', 'active', 'canceled', 'past_due'))
);

-- インデックス
CREATE INDEX idx_subscriptions_status ON subscriptions(status);
CREATE INDEX idx_subscriptions_stripe_customer ON subscriptions(stripe_customer_id);

-- updated_at 自動更新
CREATE TRIGGER update_subscriptions_updated_at
    BEFORE UPDATE ON subscriptions
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
```

#### usage_logs（AI使用量ログ）

```sql
CREATE TABLE usage_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    action TEXT NOT NULL,        -- 'summarize', 'exam_mode'
    transcript_id UUID REFERENCES transcripts(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT valid_action CHECK (action IN ('summarize', 'exam_mode'))
);

-- インデックス
CREATE INDEX idx_usage_logs_user_created ON usage_logs(user_id, created_at DESC);
CREATE INDEX idx_usage_logs_user_action_created ON usage_logs(user_id, action, created_at DESC);
```

---

## Row Level Security

### RLS有効化

```sql
ALTER TABLE transcripts ENABLE ROW LEVEL SECURITY;
ALTER TABLE summaries ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE usage_logs ENABLE ROW LEVEL SECURITY;
```

### transcripts ポリシー

```sql
-- 自分の文字起こしのみ閲覧可能
CREATE POLICY "Users can view own transcripts"
    ON transcripts FOR SELECT
    USING (auth.uid() = user_id);

-- 自分の文字起こしのみ作成可能
CREATE POLICY "Users can insert own transcripts"
    ON transcripts FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- 自分の文字起こしのみ更新可能
CREATE POLICY "Users can update own transcripts"
    ON transcripts FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- 自分の文字起こしのみ削除可能
CREATE POLICY "Users can delete own transcripts"
    ON transcripts FOR DELETE
    USING (auth.uid() = user_id);
```

### summaries ポリシー

```sql
-- 自分の要約のみ閲覧可能
CREATE POLICY "Users can view own summaries"
    ON summaries FOR SELECT
    USING (auth.uid() = user_id);

-- 自分の要約のみ作成可能（Edge Function経由）
CREATE POLICY "Users can insert own summaries"
    ON summaries FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- 自分の要約のみ更新可能
CREATE POLICY "Users can update own summaries"
    ON summaries FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);
```

### subscriptions ポリシー

```sql
-- 自分のサブスクリプションのみ閲覧可能
CREATE POLICY "Users can view own subscription"
    ON subscriptions FOR SELECT
    USING (auth.uid() = user_id);

-- サブスクリプションの作成はサービスロールのみ（Edge Functionから）
-- INSERT/UPDATE/DELETE ポリシーは作成しない（サービスロール専用）
```

### usage_logs ポリシー

```sql
-- 自分の使用ログのみ閲覧可能
CREATE POLICY "Users can view own usage logs"
    ON usage_logs FOR SELECT
    USING (auth.uid() = user_id);

-- 使用ログの作成はサービスロールのみ
```

---

## Edge Functions

### ディレクトリ構造

```
supabase/
└── functions/
    ├── save-transcript/
    │   └── index.ts
    ├── summarize/
    │   └── index.ts
    ├── stripe-webhook/
    │   └── index.ts
    └── _shared/
        ├── supabase.ts
        ├── openai.ts
        └── utils.ts
```

### save-transcript

**Purpose**: iOSからの文字起こしテキスト保存

```typescript
// supabase/functions/save-transcript/index.ts

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

interface SaveTranscriptRequest {
  title: string;
  content: string;
  created_at: string;
  duration?: number;
  language?: string;
  app_version?: string;
}

serve(async (req) => {
  // CORS
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST",
        "Access-Control-Allow-Headers": "authorization, content-type",
      },
    });
  }

  try {
    // 認証チェック
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
      });
    }

    // Supabaseクライアント
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } }
    );

    // ユーザー取得
    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError || !user) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
      });
    }

    // リクエストボディ
    const body: SaveTranscriptRequest = await req.json();

    // バリデーション
    if (!body.content || body.content.trim() === "") {
      return new Response(
        JSON.stringify({ error: "Content is required", code: "VALIDATION_ERROR" }),
        { status: 400 }
      );
    }

    // word_count計算
    const wordCount = body.content.split(/\s+/).filter(Boolean).length;

    // 保存
    const { data, error } = await supabase
      .from("transcripts")
      .insert({
        user_id: user.id,
        title: body.title || `Recording ${new Date().toISOString()}`,
        content: body.content,
        created_at: body.created_at || new Date().toISOString(),
        duration: body.duration,
        language: body.language,
        word_count: wordCount,
        source: "ios",
      })
      .select("id, created_at")
      .single();

    if (error) {
      throw error;
    }

    return new Response(JSON.stringify(data), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("Error:", error);
    return new Response(
      JSON.stringify({ error: "Internal server error" }),
      { status: 500 }
    );
  }
});
```

### summarize

**Purpose**: AI要約生成（Pro専用）

```typescript
// supabase/functions/summarize/index.ts

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import OpenAI from "https://esm.sh/openai@4";

interface SummarizeRequest {
  transcript_id: string;
  mode: "summary" | "exam";
}

const DAILY_LIMIT = 20;
const MONTHLY_LIMIT = 400;

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST",
        "Access-Control-Allow-Headers": "authorization, content-type",
      },
    });
  }

  try {
    // 認証
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), { status: 401 });
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } }
    );

    const serviceClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    const { data: { user } } = await supabase.auth.getUser();
    if (!user) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), { status: 401 });
    }

    // Pro状態チェック
    const { data: subscription } = await supabase
      .from("subscriptions")
      .select("status")
      .eq("user_id", user.id)
      .single();

    if (!subscription || subscription.status !== "active") {
      return new Response(
        JSON.stringify({ error: "Pro subscription required", code: "PRO_REQUIRED" }),
        { status: 403 }
      );
    }

    // リクエスト
    const body: SummarizeRequest = await req.json();

    // フェアリミットチェック
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const { count: dailyCount } = await serviceClient
      .from("usage_logs")
      .select("*", { count: "exact", head: true })
      .eq("user_id", user.id)
      .gte("created_at", today.toISOString());

    if ((dailyCount || 0) >= DAILY_LIMIT) {
      return new Response(
        JSON.stringify({
          error: "Daily limit reached. Try again tomorrow.",
          code: "DAILY_LIMIT",
        }),
        { status: 429 }
      );
    }

    // transcript取得
    const { data: transcript, error: transcriptError } = await supabase
      .from("transcripts")
      .select("id, content, title")
      .eq("id", body.transcript_id)
      .single();

    if (transcriptError || !transcript) {
      return new Response(
        JSON.stringify({ error: "Transcript not found" }),
        { status: 404 }
      );
    }

    // キャッシュチェック
    const { data: existingSummary } = await supabase
      .from("summaries")
      .select("*")
      .eq("transcript_id", body.transcript_id)
      .single();

    if (existingSummary) {
      if (body.mode === "summary" && existingSummary.summary) {
        return new Response(JSON.stringify(existingSummary));
      }
      if (body.mode === "exam" && existingSummary.exam_mode) {
        return new Response(JSON.stringify(existingSummary));
      }
    }

    // OpenAI呼び出し
    const openai = new OpenAI({ apiKey: Deno.env.get("OPENAI_API_KEY") });

    let prompt: string;
    if (body.mode === "summary") {
      prompt = `以下の講義文字起こしを分析し、JSON形式で要約を生成してください。

講義内容:
${transcript.content}

出力形式:
{
  "summary": "全体の要約（200-300文字）",
  "key_points": ["重要ポイント1", "重要ポイント2", ...],
  "sections": [
    {"heading": "セクション名", "content": "1行要約"},
    ...
  ]
}`;
    } else {
      prompt = `以下の講義文字起こしを分析し、試験対策用のJSON形式で情報を生成してください。

講義内容:
${transcript.content}

出力形式:
{
  "key_terms": [
    {"term": "用語", "definition": "定義"},
    ...
  ],
  "questions": [
    {"question": "問題", "answer": "解答"},
    ...
  ],
  "predictions": ["出題予想1", "出題予想2", ...]
}`;
    }

    const completion = await openai.chat.completions.create({
      model: "gpt-4-turbo",
      messages: [
        { role: "system", content: "あなたは大学講義の要約と試験対策を行う専門家です。" },
        { role: "user", content: prompt },
      ],
      response_format: { type: "json_object" },
    });

    const result = JSON.parse(completion.choices[0].message.content || "{}");

    // 保存
    const summaryData = {
      transcript_id: body.transcript_id,
      user_id: user.id,
      model: "gpt-4-turbo",
      ...(body.mode === "summary"
        ? {
            summary: result.summary,
            key_points: result.key_points,
            sections: result.sections,
          }
        : { exam_mode: result }),
    };

    const { data: savedSummary, error: saveError } = await serviceClient
      .from("summaries")
      .upsert(summaryData, { onConflict: "transcript_id" })
      .select()
      .single();

    if (saveError) throw saveError;

    // 使用ログ記録
    await serviceClient.from("usage_logs").insert({
      user_id: user.id,
      action: body.mode === "summary" ? "summarize" : "exam_mode",
      transcript_id: body.transcript_id,
    });

    return new Response(JSON.stringify(savedSummary), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("Error:", error);
    return new Response(
      JSON.stringify({ error: "Internal server error" }),
      { status: 500 }
    );
  }
});
```

### stripe-webhook

**Purpose**: Stripeイベント処理

```typescript
// supabase/functions/stripe-webhook/index.ts

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import Stripe from "https://esm.sh/stripe@13";

const stripe = new Stripe(Deno.env.get("STRIPE_SECRET_KEY")!, {
  apiVersion: "2023-10-16",
});

const webhookSecret = Deno.env.get("STRIPE_WEBHOOK_SECRET")!;

serve(async (req) => {
  const signature = req.headers.get("stripe-signature");
  if (!signature) {
    return new Response("Missing signature", { status: 400 });
  }

  try {
    const body = await req.text();
    const event = stripe.webhooks.constructEvent(body, signature, webhookSecret);

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    switch (event.type) {
      case "checkout.session.completed": {
        const session = event.data.object as Stripe.Checkout.Session;
        const userId = session.metadata?.user_id;
        const subscriptionId = session.subscription as string;

        if (userId && subscriptionId) {
          const subscription = await stripe.subscriptions.retrieve(subscriptionId);

          await supabase.from("subscriptions").upsert({
            user_id: userId,
            status: "active",
            provider: "stripe",
            stripe_customer_id: session.customer as string,
            stripe_subscription_id: subscriptionId,
            current_period_start: new Date(subscription.current_period_start * 1000).toISOString(),
            current_period_end: new Date(subscription.current_period_end * 1000).toISOString(),
          });
        }
        break;
      }

      case "customer.subscription.updated": {
        const subscription = event.data.object as Stripe.Subscription;

        await supabase
          .from("subscriptions")
          .update({
            status: subscription.status === "active" ? "active" : subscription.status,
            current_period_end: new Date(subscription.current_period_end * 1000).toISOString(),
            cancel_at_period_end: subscription.cancel_at_period_end,
          })
          .eq("stripe_subscription_id", subscription.id);
        break;
      }

      case "customer.subscription.deleted": {
        const subscription = event.data.object as Stripe.Subscription;

        await supabase
          .from("subscriptions")
          .update({ status: "canceled" })
          .eq("stripe_subscription_id", subscription.id);
        break;
      }

      case "invoice.payment_failed": {
        const invoice = event.data.object as Stripe.Invoice;
        const subscriptionId = invoice.subscription as string;

        if (subscriptionId) {
          await supabase
            .from("subscriptions")
            .update({ status: "past_due" })
            .eq("stripe_subscription_id", subscriptionId);
        }
        break;
      }
    }

    return new Response(JSON.stringify({ received: true }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("Webhook error:", error);
    return new Response(`Webhook Error: ${error.message}`, { status: 400 });
  }
});
```

---

## Stripe連携

### 環境変数

```
STRIPE_SECRET_KEY=sk_live_xxx
STRIPE_WEBHOOK_SECRET=whsec_xxx
STRIPE_PRICE_ID=price_xxx  # Pro月額プラン
```

### Stripe Dashboard設定

1. **Product作成**: "lecsy Pro"
2. **Price作成**: $2.99/month (recurring)
3. **Webhook設定**:
   - Endpoint: `https://[project-ref].supabase.co/functions/v1/stripe-webhook`
   - Events:
     - `checkout.session.completed`
     - `customer.subscription.updated`
     - `customer.subscription.deleted`
     - `invoice.payment_failed`

### Checkout Session作成（Web側で使用）

```typescript
// Web側でStripe Checkout Sessionを作成
const response = await fetch("/api/create-checkout-session", {
  method: "POST",
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify({ priceId: "price_xxx" }),
});

const { url } = await response.json();
window.location.href = url;
```

---

**最終更新**: 2026年1月26日
