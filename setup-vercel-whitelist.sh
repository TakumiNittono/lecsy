#!/bin/bash
# Vercel 環境変数設定用コマンド生成スクリプト

set -e

echo "======================================"
echo "🚀 Vercel 環境変数設定コマンド生成"
echo "======================================"
echo ""

read -p "ホワイトリストのメールアドレス (カンマ区切り): " EMAILS

if [ -z "$EMAILS" ]; then
    echo "❌ メールアドレスが入力されていません"
    exit 1
fi

echo ""
echo "以下のコマンドをコピーして実行してください:"
echo ""
echo "----------------------------------------"
echo "vercel env add WHITELIST_EMAILS production"
echo ""
echo "値を入力するプロンプトが表示されたら以下を入力:"
echo "$EMAILS"
echo "----------------------------------------"
echo ""
echo "または、Vercel Dashboard で設定:"
echo "1. https://vercel.com/dashboard にアクセス"
echo "2. プロジェクトを選択 → Settings → Environment Variables"
echo "3. Key: WHITELIST_EMAILS"
echo "4. Value: $EMAILS"
echo "5. Environment: Production, Preview, Development 全てにチェック"
echo ""
