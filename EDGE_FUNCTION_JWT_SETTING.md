# Edge Function JWT検証設定ガイド

## 🔍 現在の問題

- `execution_id: null` → Edge Functionが実行されていない
- すべての呼び出しが401エラー
- SupabaseのAPI GatewayレベルでJWT検証が失敗している可能性

---

## 📋 JWT検証設定を変更する方法

### 方法1: Supabase Dashboardで設定を確認（推奨）

#### 手順

1. **Supabase Dashboardにアクセス**
   - URL: https://supabase.com/dashboard
   - プロジェクト: `bjqilokchrqfxzimfnpm` を選択

2. **Edge Functionsに移動**
   - 左サイドバーで「**Edge Functions**」をクリック

3. **save-transcript関数を選択**
   - 関数一覧から「**save-transcript**」をクリック

4. **Detailsタブを開く**
   - 「**Details**」タブをクリック
   - ここにJWT検証の設定がある可能性があります

5. **設定を確認**
   - 「**Verify JWT**」または「**JWT Verification**」の設定を確認
   - 有効/無効を切り替えられる場合は、無効に設定

**注意**: Supabase DashboardのUIでは、JWT検証設定を直接変更できない場合があります。その場合は、方法2を使用してください。

---

### 方法2: config.tomlファイルで設定（確実な方法）

#### 手順

1. **config.tomlファイルを作成**

`supabase/config.toml`ファイルを作成（または既存の`config.toml.bak`を`config.toml`にリネーム）：

```toml
[project]
name = "lecsy"

[functions.save-transcript]
verify_jwt = false
```

2. **設定をデプロイ**

```bash
cd "/Users/takuminittono/Desktop/iPhone app/lecsy"
supabase functions deploy save-transcript --project-ref bjqilokchrqfxzimfnpm
```

**注意**: `config.toml`ファイルの設定が本番環境に反映されるかどうかは、Supabase CLIのバージョンによって異なる場合があります。

---

### 方法3: Edge FunctionのコードでJWT検証をバイパス（推奨されない）

**注意**: セキュリティ上のリスクがあるため、推奨されません。

Edge Functionのコード内でJWT検証をスキップする方法もありますが、これは**推奨されません**。代わりに、Edge Function内で手動でJWT検証を行う方が安全です。

---

## ✅ 推奨される解決方法

### オプション1: Edge Function内でJWT検証を手動実装（推奨）

現在の実装では、Edge Function内でJWT検証を行っていますが、API GatewayレベルでJWT検証が失敗している可能性があります。

**対応**: Edge Functionの設定でJWT検証を無効にし、Edge Function内で手動でJWT検証を行う（現在の実装を維持）。

### オプション2: JWT検証を無効にする（開発環境のみ）

**注意**: 本番環境では推奨されません。

1. `config.toml`ファイルを作成：

```toml
[functions.save-transcript]
verify_jwt = false
```

2. Edge Functionを再デプロイ：

```bash
cd "/Users/takuminittono/Desktop/iPhone app/lecsy"
supabase functions deploy save-transcript --project-ref bjqilokchrqfxzimfnpm
```

---

## 🔧 実際の手順（方法2を推奨）

### ステップ1: config.tomlファイルを作成

```bash
cd "/Users/takuminittono/Desktop/iPhone app/lecsy/supabase"
cp config.toml.bak config.toml
```

### ステップ2: config.tomlファイルを編集

`config.toml`ファイルを開き、以下の設定を追加または確認：

```toml
[functions.save-transcript]
verify_jwt = false
```

### ステップ3: Edge Functionを再デプロイ

```bash
cd "/Users/takuminittono/Desktop/iPhone app/lecsy"
supabase functions deploy save-transcript --project-ref bjqilokchrqfxzimfnpm
```

### ステップ4: 動作確認

1. アプリを再実行
2. ファイルをアップロード
3. 401エラーが解消されているか確認

---

## 🐛 トラブルシューティング

### 問題1: config.tomlファイルが反映されない

**原因**: Supabase CLIのバージョンが古い、または設定ファイルの場所が間違っている

**解決方法**:
- Supabase CLIを最新版に更新: `supabase update`
- `config.toml`ファイルが`supabase/`ディレクトリに存在するか確認

### 問題2: デプロイ後に401エラーが続く

**原因**: 設定が反映されていない、または別の問題がある

**解決方法**:
- Edge FunctionのInvocationsタブで、リクエストヘッダーを確認
- Edge FunctionのLogsタブで、エラーメッセージを確認
- 必要に応じて、Edge Functionのコードを確認

### 問題3: JWT検証を無効にしたくない

**原因**: セキュリティ上の懸念

**解決方法**:
- Edge Function内で手動でJWT検証を行う（現在の実装を維持）
- トークンの有効期限を確認し、必要に応じてリフレッシュ
- アプリ側でトークンが正しく送信されているか確認

---

## 📚 参考資料

- [Supabase Edge Functions Documentation](https://supabase.com/docs/guides/functions)
- [Function Configuration](https://supabase.com/docs/guides/functions/function-configuration)
- [Securing Edge Functions](https://supabase.com/docs/guides/functions/auth)

---

**最終更新**: 2026年1月27日
