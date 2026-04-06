# セキュリティ修正 #3: ハードコーディングされた認証情報の削除（iOS）

**重要度**: 緊急  
**対象ファイル**: 
- `lecsy/Config/SupabaseConfig.swift`
- `lecsy/Info.plist`
- Xcodeプロジェクト設定  

**推定作業時間**: 30分

---

## 現状の問題

Supabase URL と Anon Key がソースコードにハードコーディングされています。

### SupabaseConfig.swift (29-42行目)
```swift
// デフォルト値（.envファイルの値と一致）
self.supabaseURL = URL(string: "https://bjqilokchrqfxzimfnpm.supabase.co")!

// デフォルト値（.envファイルの値と一致）
self.supabaseAnonKey = "sb_publishable_q6JRDcMOKDp8qPuptCLARg_-HqmJsNH"
```

### Info.plist (9-12行目)
```xml
<key>SUPABASE_URL</key>
<string>https://bjqilokchrqfxzimfnpm.supabase.co</string>
<key>SUPABASE_ANON_KEY</key>
<string>sb_publishable_q6JRDcMOKDp8qPuptCLARg_-HqmJsNH</string>
```

**リスク**: 
- ソースコードがGitリポジトリにコミットされる
- Info.plistはアプリバンドルに含まれ、逆コンパイルで読み取り可能

---

## 修正手順

### Step 1: xcconfig ファイルの作成

#### 1.1 Debug用設定ファイルを作成

新規ファイル: `lecsy/Config/Debug.xcconfig`

```
// Debug.xcconfig
// 開発環境用の設定

SUPABASE_URL = https:/$()/bjqilokchrqfxzimfnpm.supabase.co
SUPABASE_ANON_KEY = sb_publishable_q6JRDcMOKDp8qPuptCLARg_-HqmJsNH

// 注意: $() は "/" のエスケープに必要
```

#### 1.2 Release用設定ファイルを作成

新規ファイル: `lecsy/Config/Release.xcconfig`

```
// Release.xcconfig
// 本番環境用の設定（CI/CDで値を注入）

SUPABASE_URL = $(SUPABASE_URL_RELEASE)
SUPABASE_ANON_KEY = $(SUPABASE_ANON_KEY_RELEASE)

// CI/CDで環境変数として設定する
```

---

### Step 2: Xcodeプロジェクトに xcconfig を設定

1. Xcodeでプロジェクトを開く
2. プロジェクトナビゲーターでプロジェクトファイル（青いアイコン）を選択
3. `PROJECT` の `lecsy` を選択
4. `Info` タブを選択
5. `Configurations` セクションで:
   - `Debug` の横の `None` をクリック → `Debug.xcconfig` を選択
   - `Release` の横の `None` をクリック → `Release.xcconfig` を選択

---

### Step 3: Info.plist の修正

**変更前**:
```xml
<key>SUPABASE_URL</key>
<string>https://bjqilokchrqfxzimfnpm.supabase.co</string>
<key>SUPABASE_ANON_KEY</key>
<string>sb_publishable_q6JRDcMOKDp8qPuptCLARg_-HqmJsNH</string>
```

**変更後**:
```xml
<key>SUPABASE_URL</key>
<string>$(SUPABASE_URL)</string>
<key>SUPABASE_ANON_KEY</key>
<string>$(SUPABASE_ANON_KEY)</string>
```

---

### Step 4: SupabaseConfig.swift の修正

**変更前**:
```swift
private init() {
    // 環境変数またはInfo.plistから読み込み
    // 優先順位: 環境変数 > Info.plist
    
    // Supabase URL
    // 優先順位: 環境変数 > Info.plist > デフォルト値
    if let urlString = ProcessInfo.processInfo.environment["SUPABASE_URL"] ?? 
                      Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
       let url = URL(string: urlString) {
        self.supabaseURL = url
        print("✅ Supabase URL loaded from environment/Info.plist: \(urlString)")
    } else {
        // デフォルト値（.envファイルの値と一致）
        self.supabaseURL = URL(string: "https://bjqilokchrqfxzimfnpm.supabase.co")!
        print("⚠️ Using default Supabase URL. Consider setting SUPABASE_URL in Info.plist")
    }
    
    // Supabase Anon Key
    // 優先順位: 環境変数 > Info.plist > デフォルト値
    if let key = ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"] ?? 
                 Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String {
        self.supabaseAnonKey = key
        print("✅ Supabase Anon Key loaded from environment/Info.plist")
    } else {
        // デフォルト値（.envファイルの値と一致）
        self.supabaseAnonKey = "sb_publishable_q6JRDcMOKDp8qPuptCLARg_-HqmJsNH"
        print("⚠️ Using default Supabase Anon Key. Consider setting SUPABASE_ANON_KEY in Info.plist")
    }
}
```

**変更後**:
```swift
private init() {
    // Info.plist から読み込み（xcconfig経由で設定される）
    guard let urlString = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
          !urlString.isEmpty,
          !urlString.hasPrefix("$("),  // 未展開の変数をチェック
          let url = URL(string: urlString) else {
        fatalError("❌ SUPABASE_URL is not configured. Please set it in xcconfig.")
    }
    self.supabaseURL = url
    
    guard let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
          !key.isEmpty,
          !key.hasPrefix("$(") else {  // 未展開の変数をチェック
        fatalError("❌ SUPABASE_ANON_KEY is not configured. Please set it in xcconfig.")
    }
    self.supabaseAnonKey = key
    
    #if DEBUG
    print("✅ Supabase URL loaded: \(urlString)")
    print("✅ Supabase Anon Key loaded (first 20 chars): \(key.prefix(20))...")
    #endif
}
```

---

### Step 5: .gitignore の更新

`.gitignore` に以下を追加:

```gitignore
# Xcconfig files with secrets
lecsy/Config/Debug.xcconfig
lecsy/Config/Release.xcconfig

# Keep example file
!lecsy/Config/*.xcconfig.example
```

---

### Step 6: Example ファイルの作成

新規ファイル: `lecsy/Config/Debug.xcconfig.example`

```
// Debug.xcconfig.example
// このファイルをコピーして Debug.xcconfig を作成してください
// cp Debug.xcconfig.example Debug.xcconfig

SUPABASE_URL = https:/$()/your-project.supabase.co
SUPABASE_ANON_KEY = your-anon-key-here

// 注意: $() は "/" のエスケープに必要
```

---

## CI/CD 設定（GitHub Actions の例）

```yaml
# .github/workflows/ios-build.yml
name: iOS Build

on:
  push:
    branches: [main]

jobs:
  build:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Create xcconfig
        run: |
          cat > lecsy/Config/Release.xcconfig << EOF
          SUPABASE_URL = https:/\$()/bjqilokchrqfxzimfnpm.supabase.co
          SUPABASE_ANON_KEY = ${{ secrets.SUPABASE_ANON_KEY }}
          EOF
      
      - name: Build
        run: |
          xcodebuild -project lecsy.xcodeproj \
            -scheme lecsy \
            -configuration Release \
            -destination 'generic/platform=iOS' \
            build
```

---

## 確認チェックリスト

- [ ] `Debug.xcconfig` ファイルを作成
- [ ] `Release.xcconfig` ファイルを作成
- [ ] Xcodeプロジェクトに xcconfig を設定
- [ ] `Info.plist` を変数参照に変更
- [ ] `SupabaseConfig.swift` からデフォルト値を削除
- [ ] `.gitignore` に xcconfig を追加
- [ ] `.xcconfig.example` ファイルを作成
- [ ] ビルドが成功することを確認
- [ ] アプリが正常に動作することを確認
- [ ] Git履歴から機密情報を削除（必要な場合）

---

## Git履歴からの機密情報削除（オプション）

すでにコミットされた機密情報を削除する場合:

```bash
# BFG Repo-Cleanerを使用
brew install bfg

# 機密情報を含むファイルを置換
bfg --replace-text passwords.txt

# または特定のファイルを削除
bfg --delete-files Debug.xcconfig

# 履歴を書き換え
git reflog expire --expire=now --all
git gc --prune=now --aggressive

# 強制プッシュ（注意: チームメンバーに通知が必要）
git push --force
```

---

## 関連ドキュメント

- [Apple - Configuration Settings File](https://developer.apple.com/documentation/xcode/adding-a-build-configuration-file-to-your-project)
- [Xcode Build Configuration Files](https://nshipster.com/xcconfig/)
- [OWASP - Sensitive Data Exposure](https://owasp.org/Top10/A02_2021-Cryptographic_Failures/)
