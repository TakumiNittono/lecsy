# 「Verify JWT」設定の重要性

## 🚨 重要度: **最高レベル（必須）**

---

## なぜ重要か？

### 1. セキュリティの第一防衛線

**「Verify JWT」がOFFの場合**:
- ❌ **誰でもAPIにアクセス可能**になる
- ❌ **認証なしでデータを保存**できる
- ❌ **他人のデータにアクセス**できる可能性
- ❌ **無料でPro機能を使用**できる

**「Verify JWT」がONの場合**:
- ✅ **認証済みユーザーのみ**アクセス可能
- ✅ **ユーザーIDが自動的に取得**される
- ✅ **不正アクセスを防止**できる

---

## 具体的なリスク

### リスク1: 無認証でのデータ保存

**Verify JWT = OFF の場合**:
```bash
# 認証なしでデータを保存できてしまう
curl -X POST https://[project].supabase.co/functions/v1/save-transcript \
  -H "Content-Type: application/json" \
  -d '{"title":"Hacked","content":"Malicious content"}'
# → 成功してしまう（本来は401エラーになるべき）
```

**影響**:
- スパムデータの挿入
- データベースの汚染
- ストレージコストの増加

---

### リスク2: 他人のデータへのアクセス

**Verify JWT = OFF の場合**:
```bash
# 他人のtranscript_idで要約を取得できてしまう
curl -X POST https://[project].supabase.co/functions/v1/summarize \
  -H "Content-Type: application/json" \
  -d '{"transcript_id":"[other-user-id]","mode":"summary"}'
# → 他人のデータが取得できてしまう
```

**影響**:
- **プライバシー侵害**
- **個人情報漏洩**
- **GDPR違反の可能性**

---

### リスク3: Pro機能の無料利用

**Verify JWT = OFF の場合**:
```bash
# 認証なしでPro機能を使用できてしまう
curl -X POST https://[project].supabase.co/functions/v1/summarize \
  -H "Content-Type: application/json" \
  -d '{"transcript_id":"[any-id]","mode":"summary"}'
# → Proチェックをバイパスできる可能性
```

**影響**:
- **収益損失**
- **OpenAI APIコストの増加**
- **サービスの悪用**

---

## 現在の実装状況

### ✅ コードレベルでの保護

現在のEdge Functionコードでは、以下の保護が実装されています：

```typescript
// save-transcript/index.ts
const { data: { user }, error: authError } = await supabase.auth.getUser();
if (authError || !user) {
  return createErrorResponse(req, "Unauthorized", 401);
}
```

**しかし**:
- コードレベルの保護だけでは**不十分**な場合がある
- Supabaseの設定でJWT検証を無効にすると、**コードのバグや設定ミスでバイパスされる可能性**がある

---

## 二重防御の重要性

### レイヤー1: Supabase設定（「Verify JWT」）
- **インフラレベル**での保護
- **コードのバグに関係なく**動作
- **最初の防衛線**

### レイヤー2: コード内での検証
- **アプリケーションレベル**での保護
- **追加のセキュリティチェック**
- **二番目の防衛線**

**両方が必要**: どちらか一方だけでは不十分です。

---

## 実際の影響

### もし「Verify JWT」がOFFだったら...

#### シナリオ1: 悪意のあるユーザー
1. APIエンドポイントを発見
2. 認証なしでリクエストを送信
3. 大量のスパムデータを挿入
4. データベースが汚染される

#### シナリオ2: 競合他社
1. APIエンドポイントを分析
2. 認証なしでPro機能を使用
3. OpenAI APIコストが増加
4. サービスの収益が減少

#### シナリオ3: データ漏洩
1. 他人のtranscript_idを推測
2. 認証なしでデータを取得
3. 個人情報が漏洩
4. **GDPR違反で罰金**（最大2000万ユーロまたは年間売上の4%）

---

## 確認の重要性

### なぜ確認が必要か？

1. **デフォルト設定が不明**
   - ローカル開発では`config.toml`で設定
   - 本番環境では**手動で設定する必要がある場合がある**

2. **設定の変更リスク**
   - 誰かが誤って設定を変更する可能性
   - デプロイ時に設定がリセットされる可能性

3. **コンプライアンス要件**
   - App Store提出前にセキュリティ確認が必要
   - プライバシーポリシーとの整合性

---

## 確認方法（再掲）

### Supabase Dashboardでの確認

1. **ログイン**
   - https://supabase.com/dashboard
   - プロジェクトを選択

2. **Edge Functions設定**
   - 左メニュー: **Edge Functions**
   - `save-transcript`をクリック
   - **Settings**タブを開く
   - **「Verify JWT」がON**になっているか確認 ✅

3. **同様に`summarize`も確認**
   - `summarize`をクリック
   - **Settings**タブを開く
   - **「Verify JWT」がON**になっているか確認 ✅

---

## まとめ

### 重要性: ⭐⭐⭐⭐⭐（最高レベル）

**「Verify JWT」設定は**:
- ✅ **必須のセキュリティ設定**
- ✅ **データ保護の第一防衛線**
- ✅ **プライバシー保護の要**
- ✅ **コンプライアンス要件**

**確認にかかる時間**: 約2分

**確認しない場合のリスク**: 
- データ漏洩
- プライバシー侵害
- 法的責任
- サービス停止

**結論**: **必ず確認してください。** これはApp Store提出前に**必須**の確認項目です。

---

**最終更新**: 2026年1月28日
