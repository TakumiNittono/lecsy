# 🔍 ログ確認ガイド

## Supabase Edge Function のログを確認する方法

### 方法1: Supabase ダッシュボード（推奨）

1. **ダッシュボードを開く**
   ```bash
   open https://supabase.com/dashboard/project/bjqilokchrqfxzimfnpm/functions
   ```

2. **`summarize` 関数をクリック**

3. **「Logs」タブを選択**
   - リアルタイムでログが表示されます
   - フィルタリングやエクスポートも可能

### 方法2: ブラウザで直接アクセス

以下のURLにアクセス：

**Functions ページ**:
https://supabase.com/dashboard/project/bjqilokchrqfxzimfnpm/functions

**summarize 関数の詳細**:
https://supabase.com/dashboard/project/bjqilokchrqfxzimfnpm/functions/summarize/details

### ログで確認すべき内容

#### ✅ ホワイトリストユーザーの成功ログ

AI要約を実行すると、以下のログが表示されます：

```
[Whitelisted user] nittonotakumi@gmail.com - skipping Pro check
```

このメッセージが表示されれば、ホワイトリストが正常に動作しています！

#### ❌ 非ホワイトリストユーザーのエラー

課金していないユーザーが使おうとすると：

```
Pro subscription required
```

これは正常な動作です。

### 📊 ログの種類

| ログレベル | 説明 |
|----------|------|
| **INFO** | 正常な処理 |
| **WARN** | 警告（処理は継続） |
| **ERROR** | エラー（処理が失敗） |

### 🐛 デバッグ時に確認すること

1. **認証エラー（401）**
   - ユーザーがログインしていない
   - トークンが無効

2. **権限エラー（403）**
   - ホワイトリストに登録されていない
   - Pro課金していない

3. **サーバーエラー（500）**
   - OpenAI API Keyが無効
   - その他の予期しないエラー

### 💡 Tips

- ログは最新のものが上に表示されます
- `Ctrl + F` でログ内を検索できます
- エラーが出た場合は、タイムスタンプをメモして問題を追跡しましょう

---

**プロジェクト**: lecsy (bjqilokchrqfxzimfnpm)
**作成日**: 2026年2月6日
