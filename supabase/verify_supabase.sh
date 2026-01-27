#!/bin/bash

# Supabase 設定確認スクリプト
# 使用方法: ./verify_supabase.sh

echo "🔍 Supabase 設定確認"
echo "================================"
echo ""

# 色の定義
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# チェック項目
checks_passed=0
checks_total=0

# 1. Supabase CLI 確認
check_cli() {
    checks_total=$((checks_total + 1))
    if command -v supabase &> /dev/null; then
        echo -e "${GREEN}✓${NC} Supabase CLI がインストールされています"
        checks_passed=$((checks_passed + 1))
        
        # ログイン状態確認
        if supabase projects list &> /dev/null; then
            echo -e "  ${GREEN}✓${NC} Supabase CLI にログインしています"
            
            # プロジェクトリンク確認
            if [ -f "supabase/.temp/project-ref" ] || supabase projects list | grep -q "bjqilokchrqfxzimfnpm"; then
                echo -e "  ${GREEN}✓${NC} プロジェクトがリンクされている可能性があります"
            else
                echo -e "  ${YELLOW}⚠${NC} プロジェクトがリンクされていない可能性があります"
                echo "    実行: supabase link --project-ref bjqilokchrqfxzimfnpm"
            fi
        else
            echo -e "  ${YELLOW}⚠${NC} Supabase CLI にログインしていません（supabase login を実行してください）"
        fi
    else
        echo -e "${YELLOW}⚠${NC} Supabase CLI がインストールされていません"
        echo "  インストール方法: brew install supabase/tap/supabase"
    fi
}

# 2. Edge Functions 確認
check_functions() {
    functions=("save-transcript" "summarize")
    for func in "${functions[@]}"; do
        checks_total=$((checks_total + 1))
        if [ -f "supabase/functions/${func}/index.ts" ]; then
            echo -e "${GREEN}✓${NC} ${func} Edge Function のコードが存在します"
            checks_passed=$((checks_passed + 1))
        else
            echo -e "${RED}✗${NC} ${func} Edge Function のコードが見つかりません"
        fi
    done
}

# 3. マイグレーションファイル確認
check_migrations() {
    checks_total=$((checks_total + 1))
    if [ -f "supabase/migrations/001_initial_schema.sql" ]; then
        echo -e "${GREEN}✓${NC} 初期スキーママイグレーションファイルが存在します"
        checks_passed=$((checks_passed + 1))
    else
        echo -e "${RED}✗${NC} 初期スキーママイグレーションファイルが見つかりません"
    fi
}

# 4. 環境変数確認
check_env() {
    checks_total=$((checks_total + 1))
    if [ -f "supabase/.env" ]; then
        echo -e "${GREEN}✓${NC} .env ファイルが存在します"
        checks_passed=$((checks_passed + 1))
        
        source supabase/.env
        if [ -n "$SUPABASE_URL" ] && [ -n "$SUPABASE_ANON_KEY" ]; then
            echo -e "  ${GREEN}✓${NC} Supabase URL/Key が設定されています"
        else
            echo -e "  ${YELLOW}⚠${NC} Supabase URL/Key が設定されていません"
        fi
        
        if [ -n "$OPENAI_API_KEY" ]; then
            echo -e "  ${GREEN}✓${NC} OpenAI API Key が設定されています"
        else
            echo -e "  ${YELLOW}⚠${NC} OpenAI API Key が設定されていません"
        fi
    else
        echo -e "${YELLOW}⚠${NC} .env ファイルが存在しません"
    fi
}

# 実行
echo "1. Supabase CLI 確認"
check_cli
echo ""

echo "2. Edge Functions 確認"
check_functions
echo ""

echo "3. マイグレーションファイル確認"
check_migrations
echo ""

echo "4. 環境変数確認"
check_env
echo ""

# 結果表示
echo "================================"
echo "確認結果: ${checks_passed}/${checks_total} 項目が完了"
echo ""

if [ $checks_passed -eq $checks_total ]; then
    echo -e "${GREEN}✓ すべてのチェックが完了しました！${NC}"
    echo ""
    echo "次のステップ:"
    echo "1. Supabase Dashboard でデータベーススキーマが適用されているか確認"
    echo "2. Supabase Dashboard > Edge Functions で関数がデプロイされているか確認"
    echo "3. Phase 1 の実装に進む"
else
    echo -e "${YELLOW}⚠ いくつかの項目が未完了です${NC}"
    echo ""
    echo "確認が必要な項目:"
    echo "- supabase/SUPABASE_SETUP.md の手順に従って設定を完了してください"
fi

echo ""
echo "📝 Supabase Dashboard での確認:"
echo "1. https://app.supabase.com にアクセス"
echo "2. Table Editor で transcripts, summaries, subscriptions, usage_logs が存在するか確認"
echo "3. Edge Functions で save-transcript, summarize がデプロイされているか確認"
