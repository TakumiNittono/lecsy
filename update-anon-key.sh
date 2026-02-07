#!/bin/bash

# Supabase Anon Key 更新スクリプト
# 
# このスクリプトは、Supabase Dashboardから取得した最新のAnon Keyを
# Debug.xcconfig と Release.xcconfig に設定します。
#
# 使用方法:
#   ./update-anon-key.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEBUG_CONFIG="$SCRIPT_DIR/lecsy/Config/Debug.xcconfig"
RELEASE_CONFIG="$SCRIPT_DIR/lecsy/Config/Release.xcconfig"

echo "🔑 Supabase Anon Key 更新ツール"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "このスクリプトは、Supabase Dashboardから取得した最新のAnon Keyを"
echo "設定ファイルに更新します。"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ファイルの存在確認
if [ ! -f "$DEBUG_CONFIG" ]; then
    echo "❌ エラー: $DEBUG_CONFIG が見つかりません"
    exit 1
fi

if [ ! -f "$RELEASE_CONFIG" ]; then
    echo "❌ エラー: $RELEASE_CONFIG が見つかりません"
    exit 1
fi

# Anon Keyの入力
echo "📋 手順:"
echo "1. Supabase Dashboard (https://app.supabase.com) にアクセス"
echo "2. プロジェクト「bjqilokchrqfxzimfnpm」を選択"
echo "3. Settings > API を開く"
echo "4. Project API keys セクションで「anon」「public」キーの「Reveal」をクリック"
echo "5. Anon Key全体をコピー"
echo ""
read -p "最新のAnon Keyを貼り付けてください: " ANON_KEY

# 入力値の検証
if [ -z "$ANON_KEY" ]; then
    echo "❌ エラー: Anon Keyが入力されていません"
    exit 1
fi

# JWT形式の検証（基本的なチェック）
if [[ ! "$ANON_KEY" =~ ^eyJ[A-Za-z0-9_-]+\.eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$ ]]; then
    echo "⚠️  警告: Anon Keyの形式が正しくない可能性があります"
    echo "   JWT形式（3つの部分がドットで区切られている）である必要があります"
    read -p "続行しますか？ (y/n): " CONTINUE
    if [ "$CONTINUE" != "y" ]; then
        echo "❌ キャンセルされました"
        exit 1
    fi
fi

# バックアップの作成
echo ""
echo "📦 バックアップを作成中..."
cp "$DEBUG_CONFIG" "$DEBUG_CONFIG.backup"
cp "$RELEASE_CONFIG" "$RELEASE_CONFIG.backup"
echo "✅ バックアップ完了:"
echo "   - $DEBUG_CONFIG.backup"
echo "   - $RELEASE_CONFIG.backup"

# Debug.xcconfig を更新
echo ""
echo "📝 Debug.xcconfig を更新中..."
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    sed -i '' "s|^SUPABASE_ANON_KEY = .*|SUPABASE_ANON_KEY = $ANON_KEY|" "$DEBUG_CONFIG"
else
    # Linux
    sed -i "s|^SUPABASE_ANON_KEY = .*|SUPABASE_ANON_KEY = $ANON_KEY|" "$DEBUG_CONFIG"
fi
echo "✅ Debug.xcconfig 更新完了"

# Release.xcconfig を更新
echo "📝 Release.xcconfig を更新中..."
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    sed -i '' "s|^SUPABASE_ANON_KEY = .*|SUPABASE_ANON_KEY = $ANON_KEY|" "$RELEASE_CONFIG"
else
    # Linux
    sed -i "s|^SUPABASE_ANON_KEY = .*|SUPABASE_ANON_KEY = $ANON_KEY|" "$RELEASE_CONFIG"
fi
echo "✅ Release.xcconfig 更新完了"

# 確認表示
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ 更新完了！"
echo ""
echo "📋 次のステップ:"
echo "1. Xcodeで Product > Clean Build Folder (Shift + Cmd + K)"
echo "2. Product > Build (Cmd + B)"
echo "3. アプリを再実行して動作確認"
echo ""
echo "🔍 確認方法:"
echo "   Xcodeのコンソールで以下のログが表示されることを確認:"
echo "   ✅ Supabase Anon Key loaded (first 20 chars): eyJhbGciOiJIUzI1NiIs..."
echo "      - Anon Key length: [200文字以上]"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
