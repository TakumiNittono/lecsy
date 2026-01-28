# セキュリティ修正デプロイチェックリスト

**作成日**: 2026年1月28日

---

## デプロイ前の確認

### ✅ 完了した修正

- [x] 修正 #1: JWT検証の有効化
- [x] 修正 #2: 所有権チェックの追加
- [x] 修正 #3: APIキーのハードコーディング削除（iOS）
- [x] 修正 #4: APIルートの認証強化
- [x] 修正 #5: Stripe Webhookエラーハンドリング
- [x] 修正 #6: トークンログ出力無効化
- [x] 修正 #7: XSS対策の強化
- [x] 修正 #8: CSRF対策の実装
- [x] 修正 #9: CORS設定の見直し
- [x] 修正 #10: レート制限の実装

### ✅ 環境変数の設定

- [x] `ALLOWED_ORIGINS` を設定済み

---

## デプロイ手順

### Step 1: Edge Functions のデプロイ

```bash
cd "/Users/takuminittono/Desktop/iPhone app/lecsy/supabase"

# 各関数をデプロイ
supabase functions deploy save-transcript
supabase functions deploy summarize
supabase functions deploy stripe-webhook
```

### Step 2: 環境変数の確認

```bash
# 設定された環境変数を確認
supabase secrets list
```

### Step 3: Webアプリのデプロイ

```bash
cd "/Users/takuminittono/Desktop/iPhone app/lecsy/web"

# Vercelにデプロイ
vercel --prod

# または、GitHub経由で自動デプロイされている場合は
# コミット＆プッシュ
git add .
git commit -m "feat: セキュリティ修正を実装"
git push origin main
```

---

## デプロイ後の確認

### Edge Functions の動作確認

1. **save-transcript 関数**
   ```bash
   # iOSアプリから文字起こし保存が正常に動作することを確認
   ```

2. **summarize 関数**
   ```bash
   # Webアプリから要約生成が正常に動作することを確認
   # 他ユーザーのデータにアクセスできないことを確認
   ```

3. **stripe-webhook 関数**
   ```bash
   # Stripe決済フローが正常に動作することを確認
   ```

### Webアプリの動作確認

1. **ログイン機能**
   - [ ] Googleログインが正常に動作する
   - [ ] Appleログインが正常に動作する

2. **講義管理機能**
   - [ ] 講義一覧が表示される
   - [ ] 講義の詳細が表示される
   - [ ] 講義の削除が正常に動作する
   - [ ] タイトルの更新が正常に動作する

3. **セキュリティ確認**
   - [ ] XSS攻撃のテスト（悪意のあるスクリプトが実行されない）
   - [ ] CSRF対策（不正なOriginからのリクエストが拒否される）
   - [ ] レート制限（過剰なリクエストが429エラーになる）

### iOSアプリの動作確認

1. **ビルド**
   - [ ] Debugビルドが成功する
   - [ ] Releaseビルドが成功する

2. **機能確認**
   - [ ] ログインが正常に動作する
   - [ ] 文字起こし保存が正常に動作する
   - [ ] Releaseビルドでトークンがログに出力されない

---

## トラブルシューティング

### Edge Functions のデプロイエラー

```bash
# ログを確認
supabase functions logs save-transcript

# ローカルでテスト
supabase functions serve save-transcript
```

### 環境変数が反映されない

```bash
# 環境変数を再設定
supabase secrets set ALLOWED_ORIGINS="https://lecsy.vercel.app,https://www.lecsy.app"

# 関数を再デプロイ
supabase functions deploy save-transcript
```

### CORS エラーが発生する

1. `ALLOWED_ORIGINS` に正しいオリジンが設定されているか確認
2. Edge Functions を再デプロイ
3. ブラウザのキャッシュをクリア

---

## 次のステップ

デプロイが完了したら：

1. **モニタリング**
   - エラーログを定期的に確認
   - パフォーマンスを監視

2. **セキュリティ監査**
   - 定期的なセキュリティレビュー
   - 依存ライブラリの脆弱性チェック

3. **ドキュメント更新**
   - セキュリティポリシーの更新
   - チームメンバーへの共有
