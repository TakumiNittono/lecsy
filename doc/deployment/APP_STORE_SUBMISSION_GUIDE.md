# App Store 申請完全ガイド

> 明日のApp Store申請に向けて、このガイドに従って準備を完了してください。

---

## ✅ 完了済みの修正

| 項目 | 状態 | 説明 |
|------|------|------|
| プライバシーポリシー | ✅ | `/privacy` ページを作成 |
| 利用規約 | ✅ | `/terms` ページを作成 |
| Release.xcconfig | ✅ | 本番用Supabase設定を追加 |
| Widget名 | ✅ | `LecsyWidget` に修正 |
| Widget Bundle ID | ✅ | `com.takumiNittono.word.lecsy.LecsyWidget` に修正 |
| JWT検証 | ✅ | `verify_jwt = true` に設定 |
| アプリアイコン | ✅ | ダークモード・Tinted版を設定 |
| メタデータ | ✅ | `APP_STORE_METADATA.md` に準備 |

---

## 📋 申請前の必須チェックリスト

### 1. Supabase Edge Functions のデプロイ

```bash
# Supabase CLIにログイン
supabase login

# Edge Functionsをデプロイ
cd "/Users/takuminittono/Desktop/iPhone app/lecsy/supabase"
supabase functions deploy save-transcript --project-ref bjqilokchrqfxzimfnpm
supabase functions deploy summarize --project-ref bjqilokchrqfxzimfnpm
supabase functions deploy stripe-webhook --project-ref bjqilokchrqfxzimfnpm
```

### 2. Webアプリのデプロイ

```bash
# Vercelにデプロイ（プライバシーポリシーページを含む）
cd "/Users/takuminittono/Desktop/iPhone app/lecsy/web"
vercel --prod
```

**重要**: デプロイ後、以下のURLが動作することを確認
- `https://your-domain.vercel.app/privacy`
- `https://your-domain.vercel.app/terms`

### 3. Xcodeでの確認

1. **プロジェクトを開く**
   ```bash
   open "/Users/takuminittono/Desktop/iPhone app/lecsy/lecsy.xcodeproj"
   ```

2. **Build Configuration を確認**
   - `Product` > `Scheme` > `Edit Scheme`
   - `Run` > `Build Configuration` を `Release` に設定

3. **Signing & Capabilities を確認**
   - `Signing & Capabilities` タブを開く
   - `Team` が正しく設定されているか確認
   - `Automatically manage signing` が有効か確認

4. **Capabilities の確認**
   - ✅ Sign in with Apple
   - ✅ Background Modes (Audio)
   - ✅ Live Activities（WidgetKit）

5. **Info.plist の確認**
   - ✅ `NSMicrophoneUsageDescription`（マイク権限の説明）
   - ✅ `UIBackgroundModes`（audio）
   - ✅ `NSSupportsLiveActivities`

### 4. アーカイブとアップロード

1. **デバイスを選択**
   - `Product` > `Destination` > `Any iOS Device (arm64)`

2. **アーカイブを作成**
   - `Product` > `Archive`
   - ビルドが完了するまで待機

3. **アーカイブを検証**
   - Organizer が開いたら、`Validate App` をクリック
   - すべてのチェックに合格するか確認

4. **App Store Connect にアップロード**
   - `Distribute App` をクリック
   - `App Store Connect` を選択
   - アップロード完了まで待機

---

## 📱 App Store Connect での設定

### 1. アプリ情報の入力

**基本情報**
| フィールド | 値 |
|-----------|-----|
| アプリ名 | lecsy |
| サブタイトル | 講義録音 × 文字起こし × AI |
| カテゴリ | Education |
| Bundle ID | com.takumiNittono.word.lecsy |

**説明文**
- `APP_STORE_METADATA.md` からコピー

**キーワード**
```
講義,録音,文字起こし,音声認識,学習,大学,試験,ノート,要約,AI,オフライン,英語,勉強,復習
```

### 2. プライバシーポリシーURL

```
https://your-domain.vercel.app/privacy
```

**⚠️ 重要**: 実際のVercelドメインに置き換えてください

### 3. サポートURL

```
https://your-domain.vercel.app
```

### 4. スクリーンショット

最低3枚必要（iPhone 6.7インチ: 1290 x 2796 px）

1. 録音画面
2. ライブラリ画面
3. 講義詳細画面

### 5. 年齢レーティング

すべて「なし」を選択 → **4+**

### 6. App Review 情報

**テストアカウント**
- 新規ユーザーとして Apple Sign In でログイン可能
- または、テストアカウントを作成して認証情報を提供

**デモ手順**（メモ欄に記入）
```
1. アプリを起動
2. 「録音」ボタンをタップして録音開始
3. 数秒録音して停止ボタンをタップ
4. 文字起こしが完了するまで待機（約30秒）
5. 講義詳細画面で文字起こし結果を確認
6. Apple Sign In でログイン
7. 「Save to Web」をタップしてWebに保存
```

---

## ⚠️ よくある却下理由と対策

### 1. "Guideline 5.1.1 - Data Collection and Storage"
**原因**: プライバシーポリシーが不十分
**対策**: `/privacy` ページを作成済み ✅

### 2. "Guideline 4.0 - Design"
**原因**: 未完成の機能、プレースホルダーコンテンツ
**対策**: すべての画面が完成していることを確認

### 3. "Guideline 2.1 - Performance: App Completeness"
**原因**: アプリがクラッシュする
**対策**: 実機でテストを完了

### 4. "Guideline 4.2 - Design: Minimum Functionality"
**原因**: 機能が少なすぎる
**対策**: 録音・文字起こし・Web同期の主要機能あり ✅

### 5. "Guideline 5.1.2 - Legal: Privacy - Data Use and Sharing"
**原因**: マイク権限の説明が不十分
**対策**: `NSMicrophoneUsageDescription` を設定済み ✅

---

## 📝 最終確認チェックリスト

### コード/設定
- [ ] Release.xcconfig に本番Supabase値が設定されている
- [ ] JWT検証が有効化されている（verify_jwt = true）
- [ ] アプリアイコンが設定されている
- [ ] Info.plist のマイク権限説明が適切

### デプロイ
- [ ] Edge Functions がデプロイされている
- [ ] Webアプリがデプロイされている
- [ ] プライバシーポリシーページにアクセスできる

### Xcode
- [ ] Release ビルドでテスト完了
- [ ] アーカイブが正常に作成できる
- [ ] Validate App が成功する

### App Store Connect
- [ ] アプリ情報がすべて入力されている
- [ ] スクリーンショットがアップロードされている
- [ ] プライバシーポリシーURLが設定されている
- [ ] 年齢レーティングが設定されている

### 動作確認
- [ ] 録音が正常に動作する
- [ ] 文字起こしが正常に完了する
- [ ] Apple Sign In が動作する
- [ ] Web保存が成功する
- [ ] バックグラウンド録音が動作する

---

## 🚀 申請後

1. **ステータス確認**
   - App Store Connect で「審査待ち」→「審査中」→「承認」

2. **審査時間**
   - 通常 24-48 時間（初回は少し長い場合あり）

3. **却下された場合**
   - 却下理由を確認
   - 修正して再提出
   - Resolution Center で質問可能

---

**作成日**: 2026年1月28日
**最終確認**: 申請前に必ずこのガイドをすべて確認してください
