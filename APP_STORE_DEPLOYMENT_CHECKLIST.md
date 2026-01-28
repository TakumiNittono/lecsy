# App Store提出前チェックリスト

## 📋 必須項目

### 1. アプリ情報の設定 ✅

- [x] Bundle ID: `com.takumiNittono.word.lecsy` ⚠️ **注意**: 実際のプロジェクトでは `com.takumiNittono.word.lecsy` が使用されています
- [ ] バージョン番号の設定（Xcodeプロジェクト設定で確認）
- [ ] ビルド番号の設定
- [ ] アプリ表示名（Display Name）の設定
- [ ] カテゴリの選択（教育/生産性など）

**確認方法**:
```bash
# Xcodeで以下を確認
# General > Identity
# - Display Name: lecsy
# - Bundle Identifier: com.takumiNittono.lecsy
# - Version: 1.0.0（例）
# - Build: 1（例）
```

---

### 2. アイコンとスクリーンショット 📱

#### アプリアイコン
- [ ] 1024x1024px のアイコン（必須）
- [ ] すべてのサイズが揃っているか確認

**必要なサイズ**:
- 1024x1024px（App Store用）
- その他のサイズはXcodeが自動生成

#### スクリーンショット
- [ ] iPhone 6.7インチ（iPhone 14 Pro Maxなど）: 1290x2796px
- [ ] iPhone 6.5インチ（iPhone 11 Pro Maxなど）: 1242x2688px
- [ ] iPhone 5.5インチ（iPhone 8 Plusなど）: 1242x2208px
- [ ] 最低3枚、最大10枚

**スクリーンショットに含めるべき画面**:
1. 録音画面（ホーム画面）
2. ライブラリ画面（講義一覧）
3. 講義詳細画面（文字起こし表示）
4. 設定画面（オプション）

---

### 3. App Store Connectの設定 🍎

#### アプリ情報
- [ ] App Store Connectでアプリを作成
- [ ] アプリ名（30文字以内）
- [ ] サブタイトル（30文字以内）
- [ ] アプリ説明（4000文字以内）
- [ ] キーワード（100文字以内、カンマ区切り）
- [ ] サポートURL（必須）
- [ ] マーケティングURL（オプション）
- [ ] プライバシーポリシーURL（必須）

#### プライバシーポリシー
- [ ] プライバシーポリシーページの作成
- [ ] 以下の情報を含める:
  - 収集するデータ（マイク音声、ユーザーID、メールアドレスなど）
  - データの使用方法
  - データの保存場所（Supabase）
  - データの共有（第三者サービス）
  - ユーザーの権利

**推奨**: Webアプリに `/privacy` ページを作成

---

### 4. 権限と説明文 🔐

#### Info.plistの確認
- [x] `NSMicrophoneUsageDescription` - マイク権限の説明
- [ ] `NSPhotoLibraryUsageDescription`（使用する場合）
- [ ] `NSCameraUsageDescription`（使用する場合）

**現在の設定**:
```xml
<key>NSMicrophoneUsageDescription</key>
<string>講義の音声を録音して文字起こしするためにマイクへのアクセスが必要です。</string>
```

#### App Store Connectでの権限説明
- [ ] マイク権限の使用理由を説明
- [ ] データの収集と使用について説明

---

### 5. 証明書とプロビジョニングプロファイル 🔑

- [ ] Apple Developer Programへの登録（年間$99）
- [ ] App IDの作成（Bundle IDと一致）
- [ ] Distribution証明書の作成
- [ ] App Store用プロビジョニングプロファイルの作成
- [ ] Xcodeで自動管理を有効化（推奨）

**確認方法**:
```
Xcode > Signing & Capabilities
- Automatically manage signing: ✅
- Team: あなたの開発チームを選択
- Provisioning Profile: Xcode Managed Profile
```

---

### 6. Capabilities（機能）の設定 ⚙️

- [x] Sign in with Apple（Apple Sign In）
- [x] Background Modes（Audio）
- [x] Live Activities
- [ ] Push Notifications（使用する場合）
- [ ] In-App Purchase（課金機能がある場合）

**確認方法**:
```
Xcode > Signing & Capabilities
- 必要なCapabilityが追加されているか確認
```

---

### 7. ビルドとアーカイブ 📦

- [ ] Release設定でビルド
- [ ] アーカイブの作成
- [ ] アーカイブの検証（Validate）
- [ ] アーカイブのアップロード（Upload）

**手順**:
```
1. Xcode > Product > Scheme > Edit Scheme
   - Build Configuration: Release
2. Product > Archive
3. Organizer > Distribute App
4. App Store Connect > Upload
```

---

### 8. TestFlightテスト 🧪

- [ ] TestFlightにビルドをアップロード
- [ ] 内部テストグループの作成
- [ ] テストユーザーの招待
- [ ] テスト期間: 最低1週間（推奨）

**テスト項目**:
- [ ] 録音機能
- [ ] 文字起こし機能
- [ ] Web同期機能
- [ ] 認証（Google/Apple Sign In）
- [ ] タイトル編集と同期
- [ ] バックグラウンド録音
- [ ] Live Activities

---

### 9. レビューガイドラインの確認 ✅

#### 必須要件
- [ ] アプリが完全に機能する
- [ ] クラッシュしない
- [ ] プライバシーポリシーが公開されている
- [ ] 権限の使用理由が明確
- [ ] テストアカウントを提供（認証が必要な場合）

#### 注意事項
- [ ] プレースホルダーコンテンツがない
- [ ] 未完成の機能がない
- [ ] デバッグコードが削除されている
- [ ] ハードコードされた認証情報がない

---

### 10. 課金設定（該当する場合）💰

- [ ] App Store ConnectでIn-App Purchaseを設定
- [ ] サブスクリプションの設定（Proプランなど）
- [ ] 価格設定
- [ ] サブスクリプショングループの作成
- [ ] サンドボックステストアカウントの作成

**参考**: `doc/06_課金設計書.md` を確認

---

### 11. リリースノート 📝

- [ ] 初回リリースの説明文を作成
- [ ] 主要機能の説明
- [ ] バグ修正（該当する場合）

**例**:
```
初回リリース

lecsyへようこそ！

主な機能:
- 講義の音声を録音して文字起こし
- オフラインで動作する文字起こしエンジン
- Webアプリと同期してどこからでもアクセス
- Live Activitiesで録音状態を確認

フィードバックをお待ちしています！
```

---

### 12. 年齢制限とコンテンツレーティング 🎯

- [ ] 年齢制限の設定（4+推奨）
- [ ] コンテンツレーティングの回答
  - 暴力: なし
  - 性的コンテンツ: なし
  - ギャンブル: なし
  - その他: なし

---

### 13. ローカライゼーション 🌍

- [ ] 日本語対応
- [ ] 英語対応（オプション）
- [ ] App Store Connectで言語を設定

---

### 14. 最終確認 ✅

- [ ] すべての機能が動作する
- [ ] クラッシュログがない
- [ ] パフォーマンスが良好
- [ ] バッテリー消費が適切
- [ ] メモリ使用量が適切
- [ ] ネットワークエラー時の処理
- [ ] オフライン時の動作

---

## 🚀 提出手順

1. **App Store Connectでアプリを作成**
   - https://appstoreconnect.apple.com
   - アプリ情報を入力
   - スクリーンショットをアップロード
   - プライバシーポリシーURLを設定

2. **Xcodeでアーカイブを作成**
   - Product > Archive
   - Validate App
   - Upload to App Store Connect

3. **TestFlightでテスト**
   - 内部テストグループに追加
   - テストユーザーを招待
   - フィードバックを収集

4. **レビュー提出**
   - App Store Connect > アプリ > バージョン
   - リリースノートを入力
   - レビュー提出

5. **レビュー待ち**
   - 通常1-3日
   - 必要に応じて修正

---

## 📚 参考リンク

- [App Store Connect](https://appstoreconnect.apple.com)
- [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)
- [TestFlight](https://developer.apple.com/testflight/)

---

## ⚠️ よくある問題と対処法

### 1. 証明書エラー
- **問題**: "No signing certificate found"
- **対処**: Xcode > Preferences > Accounts > チームを選択 > Download Manual Profiles

### 2. アップロードエラー
- **問題**: "Invalid Bundle"
- **対処**: Bundle IDがApp Store Connectと一致しているか確認

### 3. レビュー却下
- **問題**: "Missing Privacy Policy"
- **対処**: プライバシーポリシーURLを設定

### 4. TestFlightビルドが表示されない
- **問題**: ビルドが処理中
- **対処**: 通常30分-2時間かかります。待つか、メール通知を確認

---

## 📝 チェックリストの使い方

1. 各項目を順番に確認
2. 完了した項目にチェックを入れる
3. 問題があればメモを残す
4. すべて完了したら提出準備完了

---

**最終更新**: 2026年1月28日
