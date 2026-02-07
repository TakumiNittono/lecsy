#!/bin/bash
# ホワイトリスト設定スクリプト
# Usage: ./setup-whitelist.sh

set -e

echo "======================================"
echo "🔧 Supabase ホワイトリスト設定"
echo "======================================"
echo ""

# プロジェクトディレクトリに移動
cd "$(dirname "$0")"

# メールアドレスの入力
echo "課金なしでAI機能を使えるメールアドレスを入力してください"
echo "（カンマ区切りで複数指定可能）"
echo ""
read -p "メールアドレス: " EMAILS

if [ -z "$EMAILS" ]; then
    echo "❌ メールアドレスが入力されていません"
    exit 1
fi

echo ""
echo "設定するメールアドレス: $EMAILS"
echo ""
read -p "この内容で設定しますか？ (y/n): " CONFIRM

if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
    echo "キャンセルしました"
    exit 0
fi

echo ""
echo "📝 環境変数を設定中..."

# Supabase CLIで環境変数を設定
supabase secrets set WHITELIST_EMAILS="$EMAILS"

echo ""
echo "✅ ホワイトリストの設定が完了しました！"
echo ""
echo "次のステップ:"
echo "1. Edge Functionを再デプロイ: supabase functions deploy summarize"
echo "2. ログインして動作確認"
echo ""
