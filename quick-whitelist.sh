#!/bin/bash
# ホワイトリストだけを設定するクイックスクリプト

set -e

echo "🔧 ホワイトリスト設定"
echo ""

read -p "メールアドレス (カンマ区切り): " EMAILS

if [ -z "$EMAILS" ]; then
    echo "❌ メールアドレスが入力されていません"
    exit 1
fi

cd "$(dirname "$0")"
supabase secrets set WHITELIST_EMAILS="$EMAILS"

echo ""
echo "✅ 設定完了！"
echo ""
echo "次のコマンドで反映してください:"
echo "supabase functions deploy summarize"
