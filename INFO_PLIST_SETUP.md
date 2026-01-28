# Info.plist設定ガイド

## ⚠️ 現在の警告

アプリ実行時に以下の警告が表示されています：
```
⚠️ Using default Supabase URL. Consider setting SUPABASE_URL in Info.plist
⚠️ Using default Supabase Anon Key. Consider setting SUPABASE_ANON_KEY in Info.plist
```

これらの警告は、Info.plistにSupabase設定が追加されていないことを示しています。

---

## 📝 Info.plistへの設定追加方法

### 方法1: XcodeのGUIから設定（推奨）

1. **Xcodeでプロジェクトを開く**
   ```bash
   open lecsy.xcodeproj
   ```

2. **プロジェクトナビゲーターでプロジェクトを選択**
   - 左側のナビゲーターで `lecsy` プロジェクト（青いアイコン）をクリック

3. **Targetを選択**
   - 中央のエディタで `lecsy` Targetを選択

4. **Infoタブを開く**
   - 上部のタブから「Info」を選択

5. **Custom iOS Target Propertiesセクションを確認**
   - 既存のキーが表示されているセクション

6. **新しいキーを追加**
   - 「+」ボタンをクリック
   - キー名: `SUPABASE_URL`
   - タイプ: `String`
   - 値: `https://bjqilokchrqfxzimfnpm.supabase.co`

7. **2つ目のキーを追加**
   - 「+」ボタンをクリック
   - キー名: `SUPABASE_ANON_KEY`
   - タイプ: `String`
   - 値: `sb_publishable_q6JRDcMOKDp8qPuptCLARg_-HqmJsNH`

8. **保存**
   - `Cmd + S` で保存

### 方法2: Info.plistファイルを直接編集

1. **Info.plistファイルを見つける**
   - Xcodeのプロジェクトナビゲーターで `Info.plist` を探す
   - または、プロジェクト設定の「Info」タブで「Open As」>「Source Code」を選択

2. **XMLを編集**
   ```xml
   <key>SUPABASE_URL</key>
   <string>https://bjqilokchrqfxzimfnpm.supabase.co</string>
   <key>SUPABASE_ANON_KEY</key>
   <string>sb_publishable_q6JRDcMOKDp8qPuptCLARg_-HqmJsNH</string>
   ```

3. **保存**

### 方法3: プロジェクト設定のBuild Settingsから（非推奨）

この方法は複雑なため、方法1または方法2を推奨します。

---

## ✅ 設定確認方法

### 1. ビルド後のログ確認

アプリを実行し、Xcodeのコンソールで以下のログを確認：

**設定が正しく読み込まれた場合:**
```
✅ Supabase URL loaded from environment/Info.plist: https://bjqilokchrqfxzimfnpm.supabase.co
✅ Supabase Anon Key loaded from environment/Info.plist
```

**設定が読み込まれていない場合（現在の状態）:**
```
⚠️ Using default Supabase URL. Consider setting SUPABASE_URL in Info.plist
⚠️ Using default Supabase Anon Key. Consider setting SUPABASE_ANON_KEY in Info.plist
```

### 2. コードで確認

`SupabaseConfig.swift`の`init()`メソッドで、設定値が正しく読み込まれているか確認できます。

---

## 🔒 セキュリティに関する注意

### 現在の実装

- **Anon Keyは公開可能**: SupabaseのAnon Keyは公開しても問題ありません（RLSで保護されているため）
- **デフォルト値**: 現在、コード内にデフォルト値が設定されています

### 本番環境での推奨事項

1. **環境変数を使用**: CI/CDパイプラインで環境変数を設定
2. **Info.plistから削除**: 本番ビルドでは、Info.plistから値を削除し、環境変数のみを使用
3. **設定ファイルの分離**: 開発用と本番用で異なる設定ファイルを使用

---

## 🐛 トラブルシューティング

### 問題1: 設定が反映されない

**原因**: Xcodeのキャッシュ

**解決方法**:
1. Xcodeで `Product` > `Clean Build Folder` (`Shift + Cmd + K`)
2. アプリを再ビルド・実行

### 問題2: キーが追加できない

**原因**: Info.plistの形式が正しくない

**解決方法**:
1. プロジェクト設定の「Info」タブで「Open As」>「Source Code」を選択
2. XML形式で直接編集

### 問題3: 値が正しく読み込まれない

**確認事項**:
1. キー名が正確か（大文字小文字を含む）
2. 値に余分なスペースがないか
3. プロジェクトをクリーンビルドしたか

---

## 📚 参考資料

- [Apple Developer: Info.plist Key Reference](https://developer.apple.com/library/archive/documentation/General/Reference/InfoPlistKeyReference/Introduction/Introduction.html)
- [Supabase Swift Client Documentation](https://supabase.com/docs/reference/swift)

---

**最終更新**: 2026年1月27日
