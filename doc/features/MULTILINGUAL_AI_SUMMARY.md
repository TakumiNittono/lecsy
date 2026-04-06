# 多言語対応AIサマリー機能

## 📋 概要

AI Summary と Exam Prep 機能が、7つの言語でサマリーを生成できるようになりました。

## ✨ 機能

### 対応言語

1. 🇯🇵 **日本語** (Japanese) - デフォルト
2. 🇺🇸 **English** (英語)
3. 🇪🇸 **Español** (スペイン語)
4. 🇨🇳 **中文** (中国語)
5. 🇰🇷 **한국어** (韓国語)
6. 🇫🇷 **Français** (フランス語)
7. 🇩🇪 **Deutsch** (ドイツ語)

### 動作

- **入力**: 英語の講義文字起こし
- **出力**: 選択した言語でのAIサマリー/試験対策

## 🎨 UI説明

### 言語選択

ボタンをクリックする前に、希望の出力言語を選択できます：

```
┌─────────────────────────────────────┐
│ Summary Language / サマリーの言語    │
├─────────────────────────────────────┤
│ [日本語] [English] [Español] [中文] │
│ [한국어]  [Français] [Deutsch]       │
└─────────────────────────────────────┘
```

- 選択中の言語は青色（Summary）または紫色（Exam Prep）で強調表示
- 言語を変更して「Regenerate」すれば別の言語で再生成可能

## 🔧 実装詳細

### フロントエンド

#### AISummaryButton.tsx
- `selectedLanguage` state（デフォルト: `'ja'`）
- 言語選択UI（グリッドレイアウト）
- API呼び出し時に `output_language` パラメータを送信

#### ExamModeButton.tsx
- 同様の実装
- 紫/ピンクのカラースキーム

### バックエンド

#### supabase/functions/summarize/index.ts

**更新内容:**
```typescript
interface SummarizeRequest {
  transcript_id: string;
  mode: "summary" | "exam";
  output_language?: string;  // 追加
}
```

**プロンプト生成:**
```typescript
const languageInstruction = `You must respond ONLY in ${languageName}. All text in your response must be in ${languageName}.`;
```

- システムメッセージとユーザープロンプトの両方に言語指示を追加
- GPT-4 Turboが指定された言語で完全なレスポンスを生成

## 🧪 テスト方法

1. Webアプリにアクセス
2. 任意の講義を開く
3. 「AI Summary」または「Exam Prep」セクションで言語を選択
4. 「Generate」ボタンをクリック
5. 選択した言語でサマリーが生成されることを確認

## 🌍 使用例

### 日本語（デフォルト）
```json
{
  "summary": "この講義では、機械学習の基礎について説明しています...",
  "key_points": ["教師あり学習の概念", "分類と回帰の違い"]
}
```

### English
```json
{
  "summary": "This lecture covers the fundamentals of machine learning...",
  "key_points": ["Concept of supervised learning", "Difference between classification and regression"]
}
```

### Español
```json
{
  "summary": "Esta conferencia cubre los fundamentos del aprendizaje automático...",
  "key_points": ["Concepto de aprendizaje supervisado", "Diferencia entre clasificación y regresión"]
}
```

## 🚀 デプロイ済み

- ✅ フロントエンドコンポーネント更新
- ✅ Edge Function更新・デプロイ完了
- ✅ 本番環境で利用可能

## 📝 注意事項

- キャッシュは言語ごとには分けていません（同じtranscript_idなら最後に生成した言語のものが保存されます）
- 複数言語でサマリーを保存したい場合は、データベーススキーマの変更が必要です
- 現在は1つのtranscriptに対して1つのサマリーのみ保存

## 🔮 今後の拡張案

1. **言語ごとのキャッシュ**: `summaries`テーブルに`language`カラムを追加
2. **ブラウザ言語の自動検出**: `navigator.language`を使用してデフォルト言語を設定
3. **ユーザー設定**: プロフィールで優先言語を保存
4. **さらなる言語追加**: アラビア語、ロシア語、ポルトガル語など

---

**実装完了日**: 2026-02-07
**実装者**: AI Assistant
