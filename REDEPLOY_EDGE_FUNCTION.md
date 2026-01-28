# Edge Function再デプロイ手順

## 🔄 Edge Functionを再デプロイ

`save-transcript` Edge Functionを再デプロイして、改善されたエラーハンドリングを反映します。

### 手順

1. **ターミナルでSupabaseプロジェクトディレクトリに移動**:
   ```bash
   cd supabase
   ```

2. **Edge Functionを再デプロイ**:
   ```bash
   supabase functions deploy save-transcript
   ```

3. **デプロイが完了したら、アプリを再実行して「Webに保存」を試す**

4. **エラーメッセージを確認**:
   - コンソールログでエラーメッセージを確認
   - Supabase Dashboardの**Logs**タブでEdge Functionのログを確認

---

## 🔍 確認ポイント

### エラーメッセージの種類

1. **`{"code":401,"message":"Invalid JWT"}`**:
   - API GatewayまたはEdge Functionランタイムから返される
   - JWTトークンが無効と判断されている

2. **`{"error": "Unauthorized", "code": "AUTH_ERROR", "message": "..."}`**:
   - Edge Functionのコードから返される
   - `supabase.auth.getUser()`が失敗している

3. **`{"error": "Unauthorized", "code": "NO_USER", "message": "User not found"}`**:
   - Edge Functionのコードから返される
   - ユーザーが見つからない

---

## 🐛 トラブルシューティング

### JWTトークンが無効と判断される場合

1. **トークンの有効期限を確認**:
   - JWTトークンには`expires_at`フィールドがある
   - トークンが期限切れの場合は、再ログインが必要

2. **トークンの形式を確認**:
   - `Bearer <token>`形式になっているか確認
   - トークンが正しくエンコードされているか確認

3. **Supabaseの設定を確認**:
   - Edge Functionの設定でJWT検証が有効になっているか確認

---

**最終更新**: 2026年1月27日
