#!/bin/bash
# Supabase Edge Functions 環境変数セットアップ
# Usage: ./setup-secrets.sh

set -e

echo "======================================"
echo "🔧 Supabase 環境変数セットアップ"
echo "======================================"
echo ""

# プロジェクトディレクトリに移動
cd "$(dirname "$0")"

# 現在の設定を表示
echo "📋 現在の環境変数:"
supabase secrets list
echo ""

# ホワイトリストメールアドレス
echo "----------------------------------------"
echo "1️⃣  ホワイトリスト設定"
echo "----------------------------------------"
echo "課金なしでAI機能を使えるメールアドレスを設定します"
echo "（カンマ区切りで複数指定可能）"
echo ""
read -p "メールアドレス (例: admin@example.com,tester@example.com): " WHITELIST_EMAILS

if [ -n "$WHITELIST_EMAILS" ]; then
    echo "✅ ホワイトリスト: $WHITELIST_EMAILS"
    supabase secrets set WHITELIST_EMAILS="$WHITELIST_EMAILS"
else
    echo "⏭️  スキップしました"
fi

echo ""

# OpenAI API Key
echo "----------------------------------------"
echo "2️⃣  OpenAI API Key設定"
echo "----------------------------------------"
echo "AI要約機能に必要です"
echo ""
read -p "OpenAI API Key (sk-...): " OPENAI_API_KEY

if [ -n "$OPENAI_API_KEY" ]; then
    echo "✅ OpenAI API Key を設定しました"
    supabase secrets set OPENAI_API_KEY="$OPENAI_API_KEY"
else
    echo "⏭️  スキップしました"
fi

echo ""

# Stripe Secret Key
echo "----------------------------------------"
echo "3️⃣  Stripe Secret Key設定"
echo "----------------------------------------"
echo "課金機能に必要です（テスト環境: sk_test_... / 本番: sk_live_...）"
echo ""
read -p "Stripe Secret Key: " STRIPE_SECRET_KEY

if [ -n "$STRIPE_SECRET_KEY" ]; then
    echo "✅ Stripe Secret Key を設定しました"
    supabase secrets set STRIPE_SECRET_KEY="$STRIPE_SECRET_KEY"
else
    echo "⏭️  スキップしました"
fi

echo ""

# Stripe Webhook Secret
echo "----------------------------------------"
echo "4️⃣  Stripe Webhook Secret設定"
echo "----------------------------------------"
echo "Webhook処理に必要です（whsec_...）"
echo ""
read -p "Stripe Webhook Secret: " STRIPE_WEBHOOK_SECRET

if [ -n "$STRIPE_WEBHOOK_SECRET" ]; then
    echo "✅ Stripe Webhook Secret を設定しました"
    supabase secrets set STRIPE_WEBHOOK_SECRET="$STRIPE_WEBHOOK_SECRET"
else
    echo "⏭️  スキップしました"
fi

echo ""
echo "======================================"
echo "✅ セットアップ完了！"
echo "======================================"
echo ""

# 設定後の環境変数を表示
echo "📋 現在の環境変数:"
supabase secrets list
echo ""

echo "次のステップ:"
echo "1. Edge Functionを再デプロイ:"
echo "   supabase functions deploy summarize"
echo "   supabase functions deploy stripe-webhook"
echo ""
echo "2. ログインして動作確認"
echo ""
