# 修正 #3: Xcodeプロジェクト設定ガイド

このファイルは、Xcodeプロジェクトにxcconfigファイルを設定する手順を説明します。

---

## Xcodeでの設定手順（スクリーンショット付き説明）

### Step 1: Xcodeプロジェクトを開く

1. Xcodeで `lecsy.xcodeproj` を開きます

### Step 2: プロジェクトナビゲーターでプロジェクトファイルを選択

1. 左側のプロジェクトナビゲーターで、**青いアイコン**（プロジェクトファイル）をクリック
   - 通常は一番上に表示されます
   - 名前は `lecsy` です

### Step 3: プロジェクト設定を開く

1. 中央のエディタエリアで、**PROJECT** セクションの **lecsy** を選択
   - 注意: TARGETS ではなく PROJECT を選択してください

### Step 4: Info タブを選択

1. 上部のタブから **Info** タブをクリック

### Step 5: Configurations セクションを確認

1. 下にスクロールして **Configurations** セクションを見つけます
2. 以下の2つの設定があります:
   - **Debug**
   - **Release**

### Step 6: Debug 設定に xcconfig を設定

1. **Debug** の行を見つけます
2. 右側の **None** をクリック
3. ドロップダウンメニューから **Debug.xcconfig** を選択
   - もし表示されない場合は、**Add File to "lecsy"...** を選択して `lecsy/Config/Debug.xcconfig` を追加

### Step 7: Release 設定に xcconfig を設定

1. **Release** の行を見つけます
2. 右側の **None** をクリック
3. ドロップダウンメニューから **Release.xcconfig** を選択
   - もし表示されない場合は、**Add File to "lecsy"...** を選択して `lecsy/Config/Release.xcconfig` を追加

### Step 8: 設定の確認

設定後、以下のようになっているはずです:

```
Configurations:
  Debug: Debug.xcconfig
  Release: Release.xcconfig
```

---

## トラブルシューティング

### xcconfigファイルが表示されない場合

1. **File > Add Files to "lecsy"...** を選択
2. `lecsy/Config/Debug.xcconfig` と `lecsy/Config/Release.xcconfig` を選択
3. **Options** で以下を確認:
   - ✅ **Copy items if needed** は**チェックしない**（ファイルは既にプロジェクト内にあるため）
   - ✅ **Create groups** を選択
   - ✅ **Add to targets: lecsy** にチェック
4. **Add** をクリック
5. 再度 Step 6-7 を実行

### ビルドエラーが発生する場合

エラーメッセージ: `❌ SUPABASE_URL is not configured`

**原因**: xcconfigファイルが正しく読み込まれていません

**解決方法**:
1. Xcodeでプロジェクトをクリーン: **Product > Clean Build Folder** (Shift + Cmd + K)
2. プロジェクトを閉じて再度開く
3. xcconfigファイルの設定を再確認
4. ビルドを再実行

### URLのエスケープについて

xcconfigファイルでは、URLの `/` を `$()` でエスケープする必要があります:

```
✅ 正しい: SUPABASE_URL = https:/$()/example.com
❌ 間違い: SUPABASE_URL = https://example.com
```

---

## 確認方法

### 1. ビルドが成功することを確認

1. Xcodeで **Product > Build** (Cmd + B) を実行
2. エラーが発生しないことを確認

### 2. アプリが正常に動作することを確認

1. シミュレーターまたは実機でアプリを実行
2. ログイン機能が動作することを確認
3. Supabaseへの接続が成功することを確認

### 3. Debugビルドでログを確認

Xcodeのコンソールに以下のようなログが表示されるはずです:

```
✅ Supabase URL loaded: https://bjqilokchrqfxzimfnpm.supabase.co
✅ Supabase Anon Key loaded (first 20 chars): sb_publishable_q6JRDc...
```

---

## 次のステップ

設定が完了したら:

1. ✅ ビルドが成功することを確認
2. ✅ アプリが正常に動作することを確認
3. ✅ Gitにコミット（xcconfigファイルは除外される）
4. ✅ チームメンバーに `Debug.xcconfig.example` をコピーして設定するよう案内

---

## 参考リンク

- [Apple公式ドキュメント: Configuration Settings File](https://developer.apple.com/documentation/xcode/adding-a-build-configuration-file-to-your-project)
- [NSHipster: xcconfig](https://nshipster.com/xcconfig/)
