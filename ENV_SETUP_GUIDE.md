# 環境変数設定ガイド - ALLOWED_ORIGINS

## 概要

`ALLOWED_ORIGINS` は、Supabase Edge Functions で CORS を制御するための環境変数です。

---

## 設定方法

### 方法1: Supabase ダッシュボードから設定（推奨）

1. **Supabase ダッシュボードにログイン**
   - https://supabase.com/dashboard にアクセス

2. **プロジェクトを選択**
   - Lecsy プロジェクトを選択

3. **Settings に移動**
   - 左側のメニューから **Settings** をクリック

4. **Edge Functions を選択**
   - Settings メニュー内の **Edge Functions** をクリック

5. **Environment Variables セクションを開く**
   - 下にスクロールして **Environment Variables** セクションを見つける

6. **新しい環境変数を追加**
   - **Add new variable** ボタンをクリック
   - **Name**: `ALLOWED_ORIGINS`
   - **Value**: `https://lecsy.vercel.app,https://www.lecsy.app`
   - **Save** をクリック

   **注意**: 複数のオリジンはカンマ区切りで指定します

---

### 方法2: Supabase CLI から設定

#### 前提条件
- Supabase CLI がインストールされていること
- プロジェクトにログインしていること

#### 手順

```bash
# プロジェクトのルートディレクトリに移動
cd "/Users/takuminittono/Desktop/iPhone app/lecsy"

# supabase ディレクトリに移動
cd supabase

# 環境変数を設定
supabase secrets set ALLOWED_ORIGINS="https://lecsy.vercel.app,https://www.lecsy.app"
```

#### 確認

```bash
# 設定された環境変数を確認（値は表示されません）
supabase secrets list
```

---

## 設定値の例

### 本番環境
```
ALLOWED_ORIGINS=https://lecsy.vercel.app,https://www.lecsy.app
```

### 開発環境（ローカル開発用）
```
ALLOWED_ORIGINS=http://localhost:3000,http://localhost:54323
```

### 本番 + 開発環境
```
ALLOWED_ORIGINS=https://lecsy.vercel.app,https://www.lecsy.app,http://localhost:3000
```

---

## 注意事項

1. **カンマ区切り**: 複数のオリジンはカンマ（`,`）で区切ります
2. **スペースなし**: カンマの前後にスペースを入れないでください
3. **プロトコルを含める**: `https://` または `http://` を含めてください
4. **末尾のスラッシュなし**: URLの末尾に `/` は付けないでください

**正しい例**:
```
https://lecsy.vercel.app,https://www.lecsy.app
```

**間違った例**:
```
https://lecsy.vercel.app, https://www.lecsy.app  # スペースが含まれている
lecsy.vercel.app  # プロトコルがない
https://lecsy.vercel.app/  # 末尾にスラッシュがある
```

---

## 設定後の確認

### 1. Edge Function を再デプロイ

環境変数を設定した後、Edge Functions を再デプロイする必要があります：

```bash
cd supabase

# 各関数を再デプロイ
supabase functions deploy save-transcript
supabase functions deploy summarize
```

### 2. 動作確認

ブラウザの開発者ツールで CORS ヘッダーを確認：

```bash
# 許可されたオリジンからのリクエスト
curl -X OPTIONS https://<your-project>.supabase.co/functions/v1/save-transcript \
  -H "Origin: https://lecsy.vercel.app" \
  -H "Access-Control-Request-Method: POST" \
  -v
```

期待される結果:
```
< HTTP/1.1 204 No Content
< Access-Control-Allow-Origin: https://lecsy.vercel.app
< Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS
```

---

## トラブルシューティング

### 環境変数が反映されない

1. **Edge Functions を再デプロイ**
   ```bash
   supabase functions deploy save-transcript
   ```

2. **環境変数の確認**
   ```bash
   supabase secrets list
   ```

3. **ダッシュボードで確認**
   - Settings > Edge Functions > Environment Variables で設定を確認

### CORS エラーが発生する

1. **オリジンが正しく設定されているか確認**
   - リクエストの `Origin` ヘッダーと設定値が完全に一致している必要があります

2. **開発環境の場合**
   - ローカル開発時は `http://localhost:3000` を追加してください

---

## 関連ファイル

- `supabase/functions/_shared/cors.ts` - CORS設定の実装
- `supabase/functions/save-transcript/index.ts` - save-transcript関数
- `supabase/functions/summarize/index.ts` - summarize関数

---

## 参考リンク

- [Supabase Edge Functions - Environment Variables](https://supabase.com/docs/guides/functions/secrets)
- [Supabase CLI - Secrets](https://supabase.com/docs/reference/cli/supabase-secrets)
