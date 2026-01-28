# lecsy セットアップガイド

## 📋 目次

1. [Supabase設定](#supabase設定)
2. [iOSアプリ設定](#iosアプリ設定)
3. [動作確認](#動作確認)
4. [トラブルシューティング](#トラブルシューティング)

---

## Supabase設定

### 1. Supabaseプロジェクトの確認

現在の設定値（`.env`ファイルから）:
- **URL**: `https://bjqilokchrqfxzimfnpm.supabase.co`
- **Anon Key**: `sb_publishable_q6JRDcMOKDp8qPuptCLARg_-HqmJsNH`

### 2. データベーススキーマの確認

マイグレーションファイルが適用されているか確認:
```bash
cd supabase
# マイグレーションを確認
cat migrations/001_initial_schema.sql
```

必要なテーブル:
- `transcripts` - 文字起こしテキスト
- `summaries` - AI要約（Phase 2）
- `subscriptions` - サブスクリプション（Phase 2）
- `usage_logs` - 使用ログ（Phase 2）

### 3. Edge Functionsのデプロイ確認

```bash
# save-transcript関数がデプロイされているか確認
supabase functions list --project-ref bjqilokchrqfxzimfnpm
```

必要な関数:
- `save-transcript` - iOSからの文字起こしテキスト保存

### 4. 認証設定の確認

Supabase Dashboard > Authentication > Providers で以下を確認:

#### Google OAuth
- [ ] Client IDが設定されている
- [ ] Client Secretが設定されている
- [ ] Redirect URLが正しく設定されている

#### Apple Sign In
- [ ] Services IDが設定されている
- [ ] Key IDが設定されている
- [ ] Private Keyが設定されている
- [ ] Redirect URLが正しく設定されている

#### Redirect URLs
以下のURLが設定されていることを確認:
- `lecsy://auth/callback` (iOS)
- `https://lecsy.app/auth/callback` (Web)

---

## iOSアプリ設定

### 1. Supabase設定の確認

現在、`SupabaseConfig.swift`は以下の優先順位で設定を読み込みます:

1. **環境変数** (`SUPABASE_URL`, `SUPABASE_ANON_KEY`)
2. **Info.plist** (`SUPABASE_URL`, `SUPABASE_ANON_KEY`)
3. **デフォルト値** (現在のプロジェクト値)

### 2. Info.plistに設定を追加（推奨）

Xcodeでプロジェクトを開き、`Info.plist`に以下を追加:

```xml
<key>SUPABASE_URL</key>
<string>https://bjqilokchrqfxzimfnpm.supabase.co</string>
<key>SUPABASE_ANON_KEY</key>
<string>sb_publishable_q6JRDcMOKDp8qPuptCLARg_-HqmJsNH</string>
```

**注意**: Info.plistは通常、Xcodeのプロジェクト設定に統合されています。
設定を追加するには:
1. Xcodeでプロジェクトを選択
2. Target > Info タブを開く
3. 「+」ボタンで新しいキーを追加
4. キー名: `SUPABASE_URL`, 値: `https://bjqilokchrqfxzimfnpm.supabase.co`
5. 同様に `SUPABASE_ANON_KEY` も追加

### 3. URL Schemeの確認

`Info.plist`に以下のURL Schemeが設定されていることを確認:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>lecsy</string>
        </array>
        <key>CFBundleURLName</key>
        <string>com.takumiNittono.lecsy</string>
    </dict>
</array>
```

### 4. マイク権限の確認

`Info.plist`に以下の権限説明が設定されていることを確認:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>講義の音声を録音して文字起こしするためにマイクへのアクセスが必要です。</string>
```

### 5. バックグラウンドモードの確認

`Info.plist`に以下の設定が含まれていることを確認:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
</array>
```

### 6. Live Activitiesの確認

`Info.plist`に以下の設定が含まれていることを確認:

```xml
<key>NSSupportsLiveActivities</key>
<true/>
```

---

## 動作確認

### 1. アプリのビルド

```bash
# Xcodeでプロジェクトを開く
open lecsy.xcodeproj

# またはコマンドラインからビルド
xcodebuild -project lecsy.xcodeproj -scheme lecsy -sdk iphonesimulator
```

### 2. 基本動作テスト

`TESTING_CHECKLIST.md`を参照して、以下の順序でテスト:

1. **録音機能**
   - マイク権限リクエスト
   - 録音開始・停止
   - Live Activities表示

2. **文字起こし機能**
   - モデルダウンロード
   - 文字起こし実行
   - 結果表示

3. **データ管理**
   - 講義一覧表示
   - 検索機能
   - 講義詳細表示

4. **認証機能**
   - Google/Apple ログイン
   - セッション管理

5. **Web同期機能**
   - Save to Web
   - エラーハンドリング

### 3. 統合テスト

`TESTING_CHECKLIST.md`の「統合テスト」セクションを参照:

- [ ] 録音→文字起こし→Web保存の正常フロー
- [ ] エラーハンドリング
- [ ] バックグラウンド動作

---

## トラブルシューティング

### 問題1: Supabase接続エラー

**症状**: `SyncService`でエラーが発生する

**確認事項**:
1. `SupabaseConfig.swift`の設定値が正しいか
2. ネットワーク接続が正常か
3. Supabaseプロジェクトがアクティブか

**解決方法**:
```swift
// デバッグログを確認
// Xcodeのコンソールで以下を確認:
// ✅ Supabase URL loaded from...
// ✅ Supabase Anon Key loaded from...
```

### 問題2: 認証エラー

**症状**: Google/Apple ログインが失敗する

**確認事項**:
1. Supabase Dashboard > Authentication > Providers で設定が正しいか
2. Redirect URLが正しく設定されているか
3. URL Scheme (`lecsy://`) が正しく設定されているか

**解決方法**:
- Supabase DashboardでRedirect URLを確認
- XcodeでURL Schemeを確認

### 問題3: 文字起こしが開始されない

**症状**: 録音停止後、文字起こしが開始されない

**確認事項**:
1. WhisperKitモデルがダウンロードされているか
2. 音声ファイルが正しく保存されているか
3. エラーログを確認

**解決方法**:
```swift
// デバッグログを確認
// Xcodeのコンソールで以下を確認:
// 🔵 WhisperKitモデルを読み込みます...
// 🔵 文字起こし開始...
```

### 問題4: Live Activitiesが表示されない

**症状**: 録音中にLive Activityが表示されない

**確認事項**:
1. iOS 16.2以上を使用しているか
2. `Info.plist`に`NSSupportsLiveActivities`が設定されているか
3. 設定 > lecsy > Live Activitiesが有効か

**解決方法**:
- 設定アプリでLive Activitiesを有効化
- `Info.plist`の設定を確認

### 問題5: Web保存が失敗する

**症状**: 「Save to Web」をタップしてもエラーになる

**確認事項**:
1. ログインしているか
2. Edge Function (`save-transcript`) がデプロイされているか
3. ネットワーク接続が正常か

**解決方法**:
```swift
// デバッグログを確認
// Xcodeのコンソールで以下を確認:
// 🌐 SyncService: saveToWeb開始...
// 🌐 SyncService: Edge Function呼び出し中...
// ✅ SyncService: Web保存成功...
```

---

## 次のステップ

動作テストが完了したら:

1. **Phase 2: 収益化**に進む
   - Stripe連携
   - AI要約機能
   - Pro状態管理

2. **バグ修正**
   - テストで発見した問題を修正

3. **UI/UX改善**
   - ユーザーフィードバックに基づく改善

---

**最終更新**: 2026年1月27日
