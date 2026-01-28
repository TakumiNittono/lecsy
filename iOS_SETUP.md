# iOS アプリ セットアップガイド

このガイドでは、lecsy iOSアプリのセットアップ手順を説明します。

## 📋 前提条件

- Xcode 15.0以上
- iOS 17.6以上をターゲット
- macOS 14.0以上

## 🚀 セットアップ手順

### 1. Xcodeプロジェクトを開く

```bash
open lecsy.xcodeproj
```

### 2. Bundle ID設定

1. Xcodeでプロジェクトを選択
2. **TARGETS** > **lecsy** を選択
3. **General** タブで以下を設定：
   - **Bundle Identifier**: `com.takumiNittono.lecsy`
   - **Display Name**: `lecsy`
   - **Deployment Target**: `iOS 17.6`

### 3. Swift Package Managerで依存関係を追加

#### WhisperKit を追加

1. Xcodeメニュー > **File** > **Add Package Dependencies...**
2. 以下のURLを入力：
   ```
   https://github.com/argmaxinc/WhisperKit.git
   ```
3. **Version**: `0.9.0` を選択
4. **Add to Target**: `lecsy` を選択
5. **Add Package** をクリック

#### Supabase Swift を追加

1. Xcodeメニュー > **File** > **Add Package Dependencies...**
2. 以下のURLを入力：
   ```
   https://github.com/supabase/supabase-swift.git
   ```
3. **Version**: `2.0.0` を選択
4. **Add to Target**: `lecsy` を選択
5. **Add Package** をクリック

### 4. Info.plist設定

プロジェクトに `Info.plist` が存在しない場合は、以下を追加：

1. **TARGETS** > **lecsy** > **Info** タブ
2. 以下のキーを追加：
   - **Privacy - Microphone Usage Description**: `lecsy needs microphone access to record your lectures.`
   - **UIBackgroundModes**: `audio` を追加

または、`lecsy/Info.plist` ファイルをプロジェクトに追加してください。

### 5. バックグラウンド録音設定

**TARGETS** > **lecsy** > **Signing & Capabilities** で以下を追加：

- **Background Modes** を追加
  - ✅ **Audio, AirPlay, and Picture in Picture** をチェック

### 6. 環境変数設定（オプション）

Supabase連携用の設定ファイルを作成：

1. `lecsy/Config.swift` を作成（オプション）
2. 以下の内容を設定：

```swift
enum Config {
    static let supabaseURL = "https://bjqilokchrqfxzimfnpm.supabase.co"
    static let supabaseAnonKey = "sb_publishable_q6JRDcMOKDp8qPuptCLARg_-HqmJsNH"
}
```

**注意**: 本番環境では、環境変数や設定ファイルから読み込むようにしてください。

### 7. ビルド確認

1. **Product** > **Build** (⌘B) でビルド
2. エラーがないことを確認

### 8. シミュレーターで実行

1. デバイス選択で **iPhone 15 Pro** などを選択
2. **Product** > **Run** (⌘R) で実行
3. マイク権限のリクエストが表示されることを確認

## ✅ 確認チェックリスト

- [ ] Bundle ID設定完了
- [ ] WhisperKit パッケージ追加完了
- [ ] Supabase Swift パッケージ追加完了
- [ ] Info.plist設定完了（マイク権限）
- [ ] バックグラウンド録音設定完了
- [ ] ビルド成功
- [ ] シミュレーターで実行確認

## 📝 次のステップ

セットアップが完了したら、以下を実装します：

1. **録音機能の動作確認**
   - RecordViewで録音開始/停止が動作するか確認

2. **文字起こし機能実装**
   - TranscriptionService実装
   - WhisperKitモデル読み込み

3. **データ管理実装**
   - LectureStore実装
   - ローカル保存

4. **認証 & Web保存実装**
   - AuthService実装
   - SyncService実装

## 🔗 参考リンク

- [WhisperKit GitHub](https://github.com/argmaxinc/WhisperKit)
- [Supabase Swift GitHub](https://github.com/supabase/supabase-swift)
- [Apple Developer Documentation](https://developer.apple.com/documentation/)
