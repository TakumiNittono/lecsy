# Apple Sign In Bundle ID設定修正ガイド

## 🔴 エラー内容

```
Unacceptable audience in id_token: [com.takumiNittono.word.lecsy]
```

このエラーは、Supabase側のApple設定で**Client IDs**に`com.takumiNittono.word.lecsy`が登録されていないことが原因です。

## ✅ 解決手順

### 1. Supabase DashboardでClient IDsを確認・追加

1. [Supabase Dashboard](https://supabase.com/dashboard) にアクセス
2. プロジェクトを選択
3. **「Authentication」** → **「Providers」** → **「Apple」** を開く
4. **「Client IDs」**フィールドを確認

**現在の設定**: `com.takumiNittono.lecsy.auth`（Services ID）

**追加が必要**: `com.takumiNittono.word.lecsy`（App ID / Bundle ID）

### 2. Client IDsにBundle IDを追加

**「Client IDs」フィールドに以下を設定**（カンマ区切り）:

```
com.takumiNittono.lecsy.auth,com.takumiNittono.word.lecsy
```

または、複数行で:

```
com.takumiNittono.lecsy.auth
com.takumiNittono.word.lecsy
```

### 3. 設定を保存

1. **「Save」**ボタンをクリック
2. 設定が保存されることを確認

### 4. 動作確認

1. アプリを再ビルド・実行
2. Apple Sign Inボタンをタップ
3. 認証が正常に完了することを確認

## 📝 重要なポイント

### Client IDsの役割

SupabaseのApple設定の「Client IDs」には、以下を設定します：

1. **Services ID**: `com.takumiNittono.lecsy.auth`（Web OAuth用）
2. **App ID / Bundle ID**: `com.takumiNittono.word.lecsy`（iOSネイティブサインイン用）

### なぜ両方必要か

- **Services ID**: Web側のOAuthフローで使用
- **Bundle ID**: iOS側のネイティブサインインで使用

iOSアプリからApple Sign Inを使用する場合、id_tokenのaudienceにBundle IDが含まれるため、Supabase側でもそのBundle IDを認識する必要があります。

## 🔍 GoogleとAppleで同じメールアドレスの場合

### Supabaseの動作

Supabaseは、**同じメールアドレス**でGoogleとAppleの両方でサインインした場合、**自動的に同じユーザーとして扱います**。

- Googleでサインイン → ユーザー作成
- 同じメールアドレスでAppleでサインイン → 既存のユーザーにリンク

これは正常な動作です。

### ユーザー体験

1. Googleでサインイン → アカウント作成
2. ログアウト
3. Appleでサインイン（同じメールアドレス） → 既存のアカウントにログイン

ユーザーは同じアカウントで、どちらの方法でもログインできます。

## 🔍 トラブルシューティング

### 問題1: まだエラーが表示される

**確認事項**:
1. Client IDsに`com.takumiNittono.word.lecsy`が追加されているか
2. カンマ区切りで正しく設定されているか
3. 設定を保存したか
4. アプリを再ビルドしたか

### 問題2: 別のユーザーとして認識される

**原因**: メールアドレスが異なる、またはSupabaseの設定が正しくない

**解決方法**:
1. Supabase Dashboard > Authentication > Users でユーザーを確認
2. 同じメールアドレスでサインインしているか確認

---

**最終更新**: 2026年1月27日
