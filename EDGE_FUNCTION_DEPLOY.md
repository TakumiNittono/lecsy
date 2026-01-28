# Edge Function デプロイガイド

## 🔴 現在の問題

ネットワーク接続エラーが発生しています：
```
The network connection was lost.
URL Error Code: -1005
```

これは、Edge Functionがデプロイされていない可能性があります。

---

## ✅ Edge Functionのデプロイ確認

### 1. Supabase CLIのインストール確認

```bash
# macOS
brew install supabase/tap/supabase

# または npm
npm install -g supabase
```

### 2. Supabaseにログイン

```bash
supabase login
```

### 3. プロジェクトをリンク

```bash
# プロジェクト参照IDを取得（Supabase Dashboard > Settings > General）
supabase link --project-ref bjqilokchrqfxzimfnpm
```

### 4. Edge Functionをデプロイ

```bash
# save-transcript関数をデプロイ
cd /Users/takuminittono/Desktop/iPhone\ app/lecsy/supabase
supabase functions deploy save-transcript --project-ref bjqilokchrqfxzimfnpm
```

### 5. デプロイ確認

Supabase Dashboardで確認：
1. Supabase Dashboardにログイン
2. **Edge Functions** > **save-transcript** を開く
3. 関数がデプロイされていることを確認

---

## 🧪 デプロイ後のテスト

### 1. アプリで再試行

1. アプリを再起動
2. 講義詳細画面で「Save to Web」をタップ
3. 保存が成功することを確認

### 2. ログの確認

以下のログが表示されることを確認：

```
🌐 SyncService: Edge Function呼び出し中...
   - URL: https://bjqilokchrqfxzimfnpm.supabase.co/functions/v1/save-transcript
✅ SyncService: Web保存成功 - Web ID: ...
```

---

## 🔧 トラブルシューティング

### 問題1: デプロイに失敗する

**原因**: 認証情報が正しくない

**解決方法**:
```bash
# 再ログイン
supabase login

# プロジェクトを再リンク
supabase link --project-ref bjqilokchrqfxzimfnpm
```

### 問題2: 関数が見つからない

**原因**: 関数名が間違っている

**解決方法**:
```bash
# 関数一覧を確認
supabase functions list --project-ref bjqilokchrqfxzimfnpm

# 正しい関数名でデプロイ
supabase functions deploy save-transcript --project-ref bjqilokchrqfxzimfnpm
```

### 問題3: ネットワークエラーが続く

**確認事項**:
1. Edge Functionがデプロイされているか
2. ネットワーク接続が正常か
3. Supabaseプロジェクトがアクティブか

**解決方法**:
- Supabase DashboardでEdge Functionのログを確認
- ネットワーク接続を確認
- リトライ機能が動作することを確認（最大3回）

---

## 📚 参考資料

- [Supabase Edge Functions Documentation](https://supabase.com/docs/guides/functions)
- [Supabase CLI Documentation](https://supabase.com/docs/reference/cli/introduction)

---

**最終更新**: 2026年1月27日
