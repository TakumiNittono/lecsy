#!/bin/bash

# Supabase 設定確認スクリプト
# 使用方法: ./verify_setup.sh

echo "🔍 lecsy Supabase 設定確認"
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

# 1. .env ファイル確認
check_env_file() {
    checks_total=$((checks_total + 1))
    if [ -f "supabase/.env" ]; then
        echo -e "${GREEN}✓${NC} .env ファイルが存在します"
        checks_passed=$((checks_passed + 1))
        
        # 必須環境変数の確認
        source supabase/.env
        required_vars=("SUPABASE_URL" "SUPABASE_ANON_KEY" "SUPABASE_SERVICE_ROLE_KEY")
        for var in "${required_vars[@]}"; do
            if [ -z "${!var}" ]; then
                echo -e "  ${RED}✗${NC} ${var} が設定されていません"
            else
                echo -e "  ${GREEN}✓${NC} ${var} が設定されています"
            fi
        done
    else
        echo -e "${YELLOW}⚠${NC} .env ファイルが存在しません（.env.example をコピーして作成してください）"
    fi
}

# 2. マイグレーションファイル確認
check_migrations() {
    checks_total=$((checks_total + 1))
    if [ -f "supabase/migrations/001_initial_schema.sql" ]; then
        echo -e "${GREEN}✓${NC} 初期スキーママイグレーションファイルが存在します"
        checks_passed=$((checks_passed + 1))
    else
        echo -e "${RED}✗${NC} 初期スキーママイグレーションファイルが見つかりません"
    fi
}

# 3. Edge Functions 確認
check_functions() {
    functions=("save-transcript" "summarize" "stripe-webhook")
    for func in "${functions[@]}"; do
        checks_total=$((checks_total + 1))
        if [ -f "supabase/functions/${func}/index.ts" ]; then
            echo -e "${GREEN}✓${NC} ${func} Edge Function が存在します"
            checks_passed=$((checks_passed + 1))
        else
            echo -e "${RED}✗${NC} ${func} Edge Function が見つかりません"
        fi
    done
}

# 4. Supabase CLI 確認
check_cli() {
    checks_total=$((checks_total + 1))
    if command -v supabase &> /dev/null; then
        echo -e "${GREEN}✓${NC} Supabase CLI がインストールされています"
        checks_passed=$((checks_passed + 1))
        
        # ログイン状態確認
        if supabase projects list &> /dev/null; then
            echo -e "  ${GREEN}✓${NC} Supabase CLI にログインしています"
        else
            echo -e "  ${YELLOW}⚠${NC} Supabase CLI にログインしていません（supabase login を実行してください）"
        fi
    else
        echo -e "${YELLOW}⚠${NC} Supabase CLI がインストールされていません"
        echo "  インストール方法: brew install supabase/tap/supabase"
    fi
}

# 実行
echo "1. 環境変数ファイル確認"
check_env_file
echo ""

echo "2. マイグレーションファイル確認"
check_migrations
echo ""

echo "3. Edge Functions 確認"
check_functions
echo ""

echo "4. Supabase CLI 確認"
check_cli
echo ""

# 結果表示
echo "================================"
echo "確認結果: ${checks_passed}/${checks_total} 項目が完了"
echo ""

if [ $checks_passed -eq $checks_total ]; then
    echo -e "${GREEN}✓ すべてのチェックが完了しました！${NC}"
    echo ""
    echo "次のステップ:"
    echo "1. Supabase Dashboard でデータベーススキーマを適用"
    echo "2. 認証プロバイダー（Google/Apple）を設定"
    echo "3. Edge Functions をデプロイ"
    echo ""
    echo "詳細は supabase/CHECK_SETUP.md を参照してください"
else
    echo -e "${YELLOW}⚠ いくつかの項目が未完了です${NC}"
    echo ""
    echo "確認が必要な項目:"
    echo "- supabase/README.md の手順に従って設定を完了してください"
    echo "- supabase/CHECK_SETUP.md で詳細な確認を行ってください"
fi
