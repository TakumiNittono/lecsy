# 🚨 Vercel 本番環境エラー修正ガイド

## 現在の問題

Vercelの本番環境で「Error Loading Lecture」が発生しています。

### エラーログの内容
```
Transcript detail page error: Error: An error occurred in the Server Components render
```

## 🔍 考えられる原因

1. **環境変数が設定されていない**
   - `WHITELIST_EMAILS`
   - `NEXT_PUBLIC_SUPABASE_URL`
   - `NEXT_PUBLIC_SUPABASE_ANON_KEY`
   - `STRIPE_SECRET_KEY`
   - `STRIPE_PRICE_ID`

2. **Supabaseの接続エラー**
   - 認証トークンの問題
   - データベースクエリの失敗

3. **型エラーまたはランタイムエラー**

## ✅ 修正手順

### 1. Vercel環境変数を確認・設定

#### 方法A: Vercel Dashboard（推奨）

1. **[Vercel Dashboard](https://vercel.com/dashboard)** にアクセス
2. プロジェクト `lecsy` を選択
3. **Settings** タブ → **Environment Variables** をクリック
4. 以下の環境変数が設定されているか確認：

#### 必須の環境変数

| Key | Value | Environment |
|-----|-------|-------------|
| `NEXT_PUBLIC_SUPABASE_URL` | `https://bjqilokchrqfxzimfnpm.supabase.co` | ✅ Production, ✅ Preview, ✅ Development |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | `sb_publishable_q6JRDcMOKDp8qPuptCLARg_-HqmJsNH` | ✅ Production, ✅ Preview, ✅ Development |
| `STRIPE_SECRET_KEY` | `sk_test_51SxzisB48pmS725M...` | ✅ Production, ✅ Preview, ✅ Development |
| `STRIPE_PRICE_ID` | `price_1SxzmuB48pmS725MQMFQiUZn` | ✅ Production, ✅ Preview, ✅ Development |
| `WHITELIST_EMAILS` | `nittonotakumi@gmail.com` | ✅ Production, ✅ Preview, ✅ Development |
| `NEXT_PUBLIC_APP_URL` | `https://your-app.vercel.app` | ✅ Production, ✅ Preview, ✅ Development |

#### 設定手順

1. **Add New** ボタンをクリック
2. **Key** を入力（例: `WHITELIST_EMAILS`）
3. **Value** を入力（例: `nittonotakumi@gmail.com`）
4. **Environment** で Production, Preview, Development 全てにチェック
5. **Save** をクリック
6. すべての環境変数について繰り返し

### 2. 再デプロイ

環境変数を追加・変更した後は、再デプロイが必要です：

#### 方法A: 自動再デプロイ（環境変数追加時）
環境変数を保存すると自動的に再デプロイされます。

#### 方法B: 手動再デプロイ
1. **Deployments** タブをクリック
2. 最新のデプロイの右側にある「**...**」メニューをクリック
3. **Redeploy** を選択

### 3. ログを確認

再デプロイ後、ログを確認してエラーが解消されたか確認します：

1. **Deployments** タブで最新のデプロイをクリック
2. **Functions** タブを選択
3. エラーログを確認

## 🔧 追加の修正内容

今回のコミットで以下を改善しました：

### エラーページの追加
- `web/app/app/t/[id]/error.tsx` を作成
- ユーザーフレンドリーなエラー表示
- 開発環境では詳細なエラーメッセージを表示

### ログの改善
- 詳細なエラー情報をコンソールに出力
- タイムスタンプ、スタックトレース、環境変数の存在チェックを追加

## 🐛 デバッグ方法

### Vercelのログを確認

```bash
# Vercel CLIをインストール（まだの場合）
npm install -g vercel

# ログインしてプロジェクトをリンク
vercel login
vercel link

# リアルタイムでログを確認
vercel logs
```

### ローカルで本番ビルドをテスト

```bash
cd "/Users/takuminittono/Desktop/iPhone app/lecsy/web"
npm run build
npm start
```

ブラウザで `http://localhost:3000` を開いてテスト。

## 📊 エラーパターンと対策

### パターン1: 環境変数が未設定

**症状**: `undefined` や `null` エラー

**対策**: Vercel Dashboard で環境変数を設定

### パターン2: Supabase接続エラー

**症状**: `Failed to fetch`, `Network error`

**対策**:
1. Supabase URLとANON KEYが正しいか確認
2. Supabaseプロジェクトが稼働しているか確認

### パターン3: 認証エラー

**症状**: `Unauthorized`, `401`

**対策**:
1. ログアウト → 再ログイン
2. ブラウザのキャッシュをクリア

### パターン4: データベースクエリエラー

**症状**: `PGRST116`, `Row not found`

**対策**:
1. データが存在するか確認
2. RLSポリシーが正しく設定されているか確認

## ✅ チェックリスト

デプロイ前に以下を確認してください：

- [ ] すべての環境変数がVercelに設定されている
- [ ] ローカルで `npm run build` が成功する
- [ ] ローカルで `npm start` でアプリが起動する
- [ ] ログインできる
- [ ] ダッシュボードが表示される
- [ ] 講義詳細ページが表示される
- [ ] エラーログにエラーが出ていない

## 🆘 それでもエラーが解消しない場合

### ステップ1: Vercelのログを確認

1. Vercel Dashboard → Deployments → 最新のデプロイ
2. **Functions** タブを開く
3. エラーメッセージの全文をコピー

### ステップ2: ローカル環境で再現

1. `.env.local` に本番環境と同じ環境変数を設定
2. `npm run build && npm start` で実行
3. エラーが再現するか確認

### ステップ3: エラーメッセージを分析

エラーメッセージから以下を確認：
- どのファイルでエラーが発生しているか
- どの行でエラーが発生しているか
- エラーの種類（型エラー、ランタイムエラー、ネットワークエラーなど）

## 📞 サポート

問題が解決しない場合は、以下の情報を含めて報告してください：

1. Vercelのエラーログ（スクリーンショット）
2. ブラウザのコンソールログ
3. 再現手順
4. 期待される動作と実際の動作

---

**作成日**: 2026年2月6日
**最終更新**: 2026年2月6日
