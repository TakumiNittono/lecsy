# Vercel環境変数設定ガイド

## 🔴 現在の問題

Vercelで「Application error: a server-side exception has occurred」エラーが発生しています。

これは、**環境変数が設定されていない**ことが原因です。

---

## ✅ 解決方法

### ステップ1: Vercel Dashboardで環境変数を設定

1. **Vercel Dashboardにアクセス**
   - https://vercel.com/dashboard
   - プロジェクト「lecsy」を選択

2. **Settings > Environment Variables**を開く

3. **以下の環境変数を追加**：

| 変数名 | 値 |
|--------|-----|
| `NEXT_PUBLIC_SUPABASE_URL` | `https://bjqilokchrqfxzimfnpm.supabase.co` |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | `sb_publishable_q6JRDcMOKDp8qPuptCLARg_-HqmJsNH` |
| `NEXT_PUBLIC_APP_URL` | `https://lecsy.vercel.app` |

4. **Environment**を選択：
   - ✅ Production
   - ✅ Preview
   - ✅ Development

5. **Save**をクリック

### ステップ2: 再デプロイ

環境変数を設定した後、以下のいずれかの方法で再デプロイ：

#### 方法1: 自動再デプロイ
- 新しいコミットをプッシュすると自動的に再デプロイされます

#### 方法2: 手動再デプロイ
1. Vercel Dashboard > **Deployments**タブ
2. 最新のデプロイメントの「**...**」メニューをクリック
3. **Redeploy**を選択

---

## 🔍 確認方法

環境変数が正しく設定されているか確認：

1. Vercel Dashboard > **Settings** > **Environment Variables**
2. 上記の3つの環境変数が表示されているか確認
3. 値が正しいか確認

---

## 📝 環境変数の説明

### NEXT_PUBLIC_SUPABASE_URL
- SupabaseプロジェクトのURL
- 値: `https://bjqilokchrqfxzimfnpm.supabase.co`

### NEXT_PUBLIC_SUPABASE_ANON_KEY
- SupabaseのAnon Key（公開可能）
- 値: `sb_publishable_q6JRDcMOKDp8qPuptCLARg_-HqmJsNH`

### NEXT_PUBLIC_APP_URL
- WebアプリのURL
- 値: `https://lecsy.vercel.app`

---

## 🐛 トラブルシューティング

### 問題1: 環境変数を設定してもエラーが続く

**解決方法**:
- 環境変数を設定した後、**必ず再デプロイ**してください
- ブラウザのキャッシュをクリアしてください

### 問題2: 環境変数の値が間違っている

**確認方法**:
- Supabase Dashboard > **Settings** > **API**で正しい値を確認
- 値に余分なスペースや改行が含まれていないか確認

### 問題3: 環境変数が反映されない

**解決方法**:
- Vercel Dashboard > **Deployments**で最新のデプロイメントのログを確認
- 環境変数が正しく読み込まれているか確認

---

## 📚 参考資料

- [Vercel Environment Variables Documentation](https://vercel.com/docs/concepts/projects/environment-variables)
- [Next.js Environment Variables](https://nextjs.org/docs/basic-features/environment-variables)

---

**最終更新**: 2026年1月27日
