# Microsoft (Azure / Entra ID) SSO セットアップ手順

最終更新: 2026-04-19
オーナー: Takumi
理由: FMCC パイロット (5/1-6) で `student@*.edu` の Microsoft 365 ユーザーをワンタップでサインインさせるため。

コード側の実装は完了 (`signInWithMicrosoft()` を iOS / Web 両方に追加済み)。
**残りは Azure Portal と Supabase Dashboard の設定だけ**。下記をこの順番で実施してください。

---

## 0. 必要な情報 (コピペ用)

- **Supabase プロジェクト URL**: `https://bjqilokchrqfxzimfnpm.supabase.co`
- **Azure 用 Redirect URI** (これを Azure に登録する):
  `https://bjqilokchrqfxzimfnpm.supabase.co/auth/v1/callback`
- **iOS の OAuth コールバック scheme**: `lecsy://auth/callback` (既存。Info.plist に登録済)

---

## 1. Azure Portal で App registration (15-30 分)

### 1-1. ポータルにアクセス
1. https://portal.azure.com にサインイン (個人 Microsoft アカウントで OK)
2. 検索バーで「**Microsoft Entra ID**」(旧 Azure Active Directory) を開く
3. 左メニュー → **App registrations** → **New registration**

### 1-2. アプリ登録
- **Name**: `Lecsy` (任意)
- **Supported account types**: ★最重要★
  - ✅ **「Accounts in any organizational directory (Any Microsoft Entra ID tenant - Multitenant) and personal Microsoft accounts (e.g. Skype, Xbox)」** を選択
  - これで `@fmcc.edu`、`@outlook.com`、`@hotmail.com` 等すべて通る
  - ❌ 「Single tenant」を選ぶと FMCC 学生は弾かれる
- **Redirect URI**:
  - Platform: **Web**
  - URL: `https://bjqilokchrqfxzimfnpm.supabase.co/auth/v1/callback`
- **Register** をクリック

### 1-3. Application (client) ID をメモ
登録完了画面の **Application (client) ID** をコピー (例: `12345678-1234-1234-1234-123456789abc`)
→ これが後で Supabase に貼る **Azure Client ID**

### 1-4. Client Secret を発行
1. 左メニュー → **Certificates & secrets** → **New client secret**
2. Description: `Lecsy production secret`
3. Expires: **24 months** (2年)
4. **Add** クリック
5. 表示された **Value** 列の文字列を即コピー (もう二度と表示されない)
   → これが後で Supabase に貼る **Azure Client Secret**

### 1-5. API permissions の確認
1. 左メニュー → **API permissions**
2. デフォルトで `User.Read` (Microsoft Graph / Delegated) が入っているはず
3. 入っていなければ **Add a permission** → Microsoft Graph → Delegated → `User.Read` を追加
4. **Grant admin consent for ...** ボタンが見えたら押す (個人テナントなら不要)

---

## 2. Supabase Dashboard で Azure provider を有効化 (10 分)

1. https://supabase.com/dashboard/project/bjqilokchrqfxzimfnpm を開く
2. 左メニュー → **Authentication** → **Providers**
3. リストから **Azure (Microsoft)** を探して **Enabled** トグルを ON
4. 設定欄を埋める:
   - **Azure Client ID**: 1-3 でコピーした Application (client) ID
   - **Azure Secret**: 1-4 でコピーした Client Secret Value
   - **Azure Tenant URL** (任意): 空欄のまま OK
     - ※何か入れるなら `https://login.microsoftonline.com/common/v2.0` (multitenant + personal)
   - **Azure Tenant ID** (任意): 空欄のまま OK
5. **Save** をクリック

これで `https://bjqilokchrqfxzimfnpm.supabase.co/auth/v1/authorize?provider=azure` がライブになる。

---

## 3. iOS TestFlight ビルド配布 (30-60 分)

### 3-1. Xcode で Archive
1. Xcode で `lecsy.xcodeproj` を開く
2. 上部 device セレクタを **「Any iOS Device (arm64)」** に変更
3. メニュー: **Product → Archive**
4. ビルド完了後、**Organizer** ウィンドウが開く

### 3-2. App Store Connect にアップロード
1. Organizer で最新 archive を選択 → **Distribute App**
2. **App Store Connect** を選択 → **Next**
3. **Upload** を選択 → **Next**
4. すべてのチェックボックスを default で → **Next** → **Upload**
5. アップロード完了 (5-10 分)

### 3-3. TestFlight 配布設定
1. https://appstoreconnect.apple.com → My Apps → Lecsy → **TestFlight** タブ
2. 新しい build (#13 or higher) が **Processing** で出てくる → 30-60 分待つ
3. Processing 完了後、build をクリック → **Test Information** に簡単なメモ書く (「Microsoft SSO 追加版」)
4. **Internal Testing** グループに自分自身を追加 → 即座に届く
5. **External Testing** グループ (あるいは新規作成 `FMCC Pilot`) に Kim と FMCC 学生のメアドを追加
   - External の場合は Apple の Beta App Review (24h 程度) が必要、ただし**簡易レビューなので通常通る**
   - Internal なら即配布可

---

## 4. 動作確認チェックリスト (30 分)

### 4-1. Web で疎通確認 (最速の動作確認)
1. https://lecsy.app/login を開く
2. **Continue with Microsoft** ボタンが出ていることを確認
3. クリック → Microsoft の認証画面に飛ぶ → 自分のテストアカウントでサインイン
4. `lecsy.app/auth/callback` 経由で `/app` にリダイレクトされることを確認
5. Supabase Dashboard → **Authentication → Users** で新規ユーザーができ、**email 列が埋まっている**ことを確認
   - ★ ここが空だと iOS の pending-membership 自動参加が動かない

### 4-2. iOS TestFlight で実機確認
1. TestFlight アプリで Lecsy 最新 build をインストール
2. 起動 → サインイン画面で **Continue with Microsoft** が一番上にあることを確認
3. タップ → in-app Safari (ASWebAuthenticationSession) で Microsoft 認証画面
4. テストアカウントでサインイン → アプリに戻る → サインイン完了
5. Settings or Account chip で email が `@xxx.edu` (= Microsoft アカウントのメアド) になっていることを確認

### 4-3. Pending membership 自動参加 E2E 確認
1. Supabase SQL editor で:
   ```sql
   -- 1) fmcc-pilot org が無ければ作成
   INSERT INTO organizations (slug, name)
   VALUES ('fmcc-pilot', 'FMCC Pilot')
   ON CONFLICT (slug) DO NOTHING;

   -- 2) テスト用に自分の .edu メアドを pending member 登録
   INSERT INTO organization_members (org_id, email, role, status)
   SELECT id, 'YOUR_TEST_EDU_EMAIL@example.edu', 'student', 'pending'
   FROM organizations WHERE slug = 'fmcc-pilot';
   ```
   ※ `email` カラムが pending 用に存在するスキーマであることが前提。実際のスキーマは
   `supabase/migrations/` を確認のこと。
2. その `.edu` メアドの Microsoft アカウントで Lecsy にサインイン
3. サインイン直後、`PostLoginCoordinator.activatePendingMemberships()` が走り、
   `organization_members.status` が `'active'` に変わることを確認
4. アプリ内で org dashboard へのアクセスができる、recordings が org に紐付くことを確認

---

## 5. Kim 向け学生案内テンプレ (英語、5/2 配布用)

```
Welcome to Lecsy — quick install (3 minutes)

1. Open the App Store on your iPhone
2. Search "Lecsy" and download (free)
3. Open the app → tap "Continue with Microsoft"
4. Sign in with your @<school>.edu email and password
5. Allow microphone access — that's it

Your transcripts will appear automatically after each lecture.
Questions? Email Kim or support@lecsy.app
```

---

## トラブルシューティング

| 症状 | 原因と対応 |
|---|---|
| Microsoft 画面で「This app cannot be accessed at this time」 | App registration の Supported account types が Single tenant になっている → Multitenant + personal に変更 |
| サインイン後 Supabase の user に email が入らない | Supabase provider 設定で scope に `email` が含まれていない → コードで `scopes=openid email profile offline_access` を渡しているので通常 OK。Azure 側 API permissions の `User.Read` 確認 |
| iOS で「lecsy:// scheme not found」 | Info.plist の `CFBundleURLTypes` に `lecsy` が登録されているか確認 (既存の Google sign-in が動いているなら登録済) |
| `redirect_uri_mismatch` エラー | Azure の Redirect URI が Supabase の正確な URL (`https://bjqilokchrqfxzimfnpm.supabase.co/auth/v1/callback`) と完全一致していない |
| TestFlight ビルドが Processing から進まない | 通常 30-60 分。Apple の障害がないかは https://developer.apple.com/system-status/ 確認 |

---

## 推奨スケジュール (4/19 起点)

- **4/20 (日)**: §1 Azure 登録 + §2 Supabase 設定 + §4-1 Web 疎通確認 → ここまで 1.5h
- **4/21 (月)**: §3 TestFlight ビルド & アップロード → 1h
- **4/22 (火)**: §3-3 配布 + §4-2 実機確認 + §4-3 E2E確認 → 1h
- **4/23-25**: バッファ。問題が出たら fix & 再 archive
- **4/27 (日)**: Kim にテスト用招待リンク送付、1人の学生で動作確認依頼
- **4/29 (水)**: 最終 stable build を pin
- **5/1 (金)**: 出発、5/2 (土) 〜 教室パイロット
