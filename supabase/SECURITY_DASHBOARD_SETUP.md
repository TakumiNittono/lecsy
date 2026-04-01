# Supabase セキュリティ設定（ダッシュボードで実行）

マイグレーションでは対応できない設定です。**Supabase ダッシュボードで手動で有効化してください。**

## Leaked Password Protection（流出パスワード保護）

**重要**: 過去に漏洩したパスワードの再利用を防ぎます。

### 設定手順

1. [Supabase ダッシュボード](https://supabase.com/dashboard) を開く
2. プロジェクトを選択
3. **Authentication** → **Providers** → **Email**
4. **Security** セクションで **Leaked password protection** をオンにする

> **注意**: Leaked Password Protection は **Pro Plan 以上** でのみ利用可能です。  
> Free Plan の場合はこの機能は使えません。現状のままでも他2件（Function Search Path・RLS Initplan）のマイグレーション修正で、DBアドバイザーの警告はかなり減ります。

### 効果

- ユーザーがサインアップ・パスワード変更時に、流出済みパスワードを使うと拒否される
- HaveIBeenPwned.org のデータベースと照合
