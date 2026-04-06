# Supabase API Key 修正ガイド

## 🚨 問題: "Invalid API key" エラー

ログに以下のエラーが表示されている場合：
```
❌ AuthService: HTTPエラー - Status: 401, Message: {"message":"Invalid API key"}
```

これは、Supabase Dashboardから取得した最新のAnon Keyと、アプリに設定されているAnon Keyが一致していない可能性があります。

---

## 📋 修正手順

### Step 1: Supabase Dashboardで最新のAnon Keyを取得

1. [Supabase Dashboard](https://app.supabase.com) にログイン
2. プロジェクト `bjqilokchrqfxzimfnpm` を選択
3. **Settings** > **API** を開く
4. **Project API keys** セクションで **`anon` `public`** キーを確認
5. **「Reveal」** ボタンをクリックして、Anon Keyを表示
6. **Anon Key全体をコピー**（長いJWT形式の文字列）

---

### Step 2: 設定ファイルを更新

#### 2-1. Debug.xcconfig を更新

```bash
cd "/Users/takuminittono/Desktop/iPhone app/lecsy"
open lecsy/Config/Debug.xcconfig
```

以下の行を、Supabase Dashboardからコピーした最新のAnon Keyに置き換えてください：

```xcconfig
SUPABASE_ANON_KEY = [ここに最新のAnon Keyを貼り付け]
```

#### 2-2. Release.xcconfig を更新

```bash
open lecsy/Config/Release.xcconfig
```

同様に、最新のAnon Keyに置き換えてください：

```xcconfig
SUPABASE_ANON_KEY = [ここに最新のAnon Keyを貼り付け]
```

**重要**: DebugとReleaseで**同じAnon Key**を使用してください。

---

### Step 3: Xcodeでクリーンビルド

1. Xcodeを開く
2. **Product** > **Clean Build Folder** (Shift + Cmd + K)
3. **Product** > **Build** (Cmd + B)
4. アプリを再実行

---

## 🔍 確認方法

### Anon Keyの形式確認

正しいAnon Keyは以下の形式です：
- **JWT形式**: `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJqcWlsb2tjaHJxZnh6aW1mbnBtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzgwMDg2MTgsImV4cCI6MjA1MzU4NDYxOH0.7Ty6JmAJH5EWnPj0L_8xWUBrM4LrpZRqJfNxGt_zOL4`
- **3つの部分**がドット（`.`）で区切られている
- **長さ**: 約200文字以上

### 現在の設定を確認

Xcodeのコンソールで、アプリ起動時に以下のログが表示されます：

```
✅ Supabase Anon Key loaded (first 20 chars): eyJhbGciOiJIUzI1NiIs...
   - Anon Key length: 208
```

このログで、Anon Keyが正しく読み込まれているか確認できます。

---

## ⚠️ よくある問題

### 問題1: Anon Keyが古い

**症状**: 以前は動いていたが、突然動かなくなった

**原因**: Supabase DashboardでAnon Keyが再生成された可能性があります

**解決方法**: Step 1-3を実行して、最新のAnon Keyに更新してください

---

### 問題2: 設定ファイルが正しく読み込まれていない

**症状**: Anon Key lengthが0または短い

**確認方法**:
1. Xcode > **Product** > **Clean Build Folder**
2. プロジェクトを閉じて再度開く
3. **Build Settings** で `SUPABASE_ANON_KEY` が正しく設定されているか確認

---

### 問題3: プロジェクトが一時停止している

**症状**: すべてのAPIリクエストが401エラー

**確認方法**:
1. Supabase Dashboard > **Settings** > **General** を開く
2. プロジェクトの状態を確認
3. 一時停止している場合は、プロジェクトを再開してください

---

## 🧪 動作確認

### 1. アプリを起動

Xcodeでアプリを実行し、コンソールログを確認：

```
✅ Supabase Anon Key loaded (first 20 chars): eyJhbGciOiJIUzI1NiIs...
   - Anon Key length: 208
✅ AuthService: Supabase client initialization completed
```

### 2. Sign in with Appleを試す

1. ログイン画面で「Sign in with Apple」をタップ
2. Apple認証を完了
3. コンソールログを確認：

**成功の場合**:
```
✅ AuthService: Appleサインイン成功
```

**失敗の場合**:
```
❌ AuthService: HTTPエラー - Status: 401
```

→ まだAnon Keyが正しく設定されていない可能性があります

---

## 📝 チェックリスト

- [ ] Supabase Dashboard > Settings > API で最新のAnon Keyを取得
- [ ] Debug.xcconfig の `SUPABASE_ANON_KEY` を最新の値に更新
- [ ] Release.xcconfig の `SUPABASE_ANON_KEY` を最新の値に更新
- [ ] Xcodeで Clean Build Folder を実行
- [ ] アプリを再ビルド・再実行
- [ ] コンソールログでAnon Keyが正しく読み込まれているか確認
- [ ] Sign in with Appleが成功するか確認

---

## 🔗 参考リンク

- [Supabase Dashboard](https://app.supabase.com)
- [Supabase API Keys Documentation](https://supabase.com/docs/guides/api/api-keys)

---

**最終更新**: 2026年1月30日
