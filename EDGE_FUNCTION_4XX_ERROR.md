# Edge Function 4xxエラー トラブルシューティング

## 🔴 現在の問題

Supabase Dashboardで`save-transcript` Edge Functionに**4xxエラー**が発生しています。

### エラー情報
- **エラーコード**: 4xx（クライアントエラー）
- **発生時刻**: 2026年1月27日 14:10頃
- **呼び出し回数**: 3回（うち1回が4xxエラー）

### 4xxエラーの可能性

1. **401 Unauthorized** - 認証トークンが無効または欠落
2. **400 Bad Request** - リクエストボディのバリデーションエラー
3. **403 Forbidden** - 権限不足

---

## 🔍 原因の特定

### 1. Supabase Dashboardでログを確認

1. Supabase Dashboard > **Edge Functions** > **save-transcript** を開く
2. **Logs**タブを開く
3. エラーが発生した時刻のログを確認
4. エラーメッセージを確認

### 2. よくある原因

#### 原因1: 認証トークンが正しく送信されていない

**確認方法**:
- アプリのログで「アクセストークン取得」のメッセージを確認
- Edge Functionのログで`Authorization`ヘッダーを確認

**解決方法**:
- `AuthService`でセッションが正しく設定されているか確認
- `accessToken`が正しく取得できているか確認

#### 原因2: リクエストボディの形式が正しくない

**確認方法**:
- Edge Functionのログでリクエストボディを確認
- `created_at`の形式が正しいか確認（ISO 8601形式）

**解決方法**:
- `SaveTranscriptRequest`の`created_at`をISO 8601形式に変換

#### 原因3: バリデーションエラー

**確認方法**:
- Edge Functionのログでバリデーションエラーを確認
- `content`が空でないか確認

**解決方法**:
- リクエストボディのバリデーションを確認

---

## ✅ 修正方法

### 1. リクエストボディの形式を確認

`created_at`が正しい形式（ISO 8601）になっているか確認：

```swift
// SyncService.swift
let request = SaveTranscriptRequest(
    title: lecture.displayTitle,
    content: transcriptText,
    created_at: lecture.createdAt, // Date型をISO 8601文字列に変換する必要がある可能性
    duration: lecture.duration,
    language: lecture.language.rawValue,
    app_version: Bundle.main.appVersion ?? "1.0.0"
)
```

### 2. アクセストークンの確認

`AuthService`でアクセストークンが正しく取得できているか確認：

```swift
// デバッグログを追加済み
if let token = await authService.accessToken {
    print("🌐 SyncService: アクセストークン取得 - \(token.prefix(20))...")
}
```

### 3. Edge Functionのログを確認

Supabase Dashboardで具体的なエラーメッセージを確認してください。

---

## 🧪 テスト手順

### 1. ログを確認

アプリを実行して「Save to Web」をタップし、以下のログを確認：

```
🌐 SyncService: アクセストークン取得 - ...
🌐 SyncService: Edge Function呼び出し中...
```

### 2. Edge Functionのログを確認

Supabase Dashboard > **Edge Functions** > **save-transcript** > **Logs**で：
- エラーメッセージを確認
- リクエストボディを確認
- `Authorization`ヘッダーを確認

### 3. エラーメッセージに基づいて修正

エラーメッセージに基づいて、適切な修正を行ってください。

---

## 📝 よくあるエラーと解決方法

### エラー1: "Unauthorized"

**原因**: 認証トークンが無効または欠落

**解決方法**:
1. アプリで再ログイン
2. セッションが正しく設定されているか確認
3. `accessToken`が正しく取得できているか確認

### エラー2: "Content is required"

**原因**: `content`が空または`null`

**解決方法**:
1. 文字起こしテキストが正しく保存されているか確認
2. `lecture.transcriptText`が空でないか確認

### エラー3: "Invalid date format"

**原因**: `created_at`の形式が正しくない

**解決方法**:
1. `Date`型をISO 8601文字列に変換
2. タイムゾーンを考慮

---

## 🔄 次のステップ

1. **Supabase Dashboardでログを確認**
   - **Logs**タブでエラーメッセージを確認
   - 具体的なエラーコード（401, 400, 403など）を確認

2. **エラーメッセージに基づいて修正**
   - エラーメッセージを共有してください
   - 適切な修正方法を提案します

3. **再テスト**
   - 修正後、再度「Save to Web」を試してください

---

**最終更新**: 2026年1月27日
