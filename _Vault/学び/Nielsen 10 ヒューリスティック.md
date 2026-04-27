# Nielsen 10 ヒューリスティック

> 出典: [[NotebookLM_学習/⑭ UX UI デザイン]] / Jakob Nielsen (NN/g)

## 概要

**1994年から 30+ 年使われている UX 評価の世界標準**。
lecsy のUIレビュー時に使うチェックリスト。

## 10 ヒューリスティック

### 1. システム状態の視認性 (Visibility of System Status)
ユーザーに「今、何が起きているか」を常に伝える。
- lecsy 例: 録音中のインジケーター、同期中バッジ

### 2. 実世界とシステムの一致 (Match System and Real World)
ユーザーが使う言葉、概念、流れをそのまま使う。
- lecsy 例: 「出欠」「教材」「生徒」（技術用語を避ける）

### 3. ユーザーコントロールと自由 (User Control and Freedom)
誤操作への「出口（Exit）」を常に提供。
- lecsy 例: Undo ボタン、確認なしの削除禁止

### 4. 一貫性と標準 (Consistency and Standards)
iOS の標準パターンに従う。
- lecsy 例: Back ボタン位置、タブバー下部、SF Symbols 使用

### 5. エラーの防止 (Error Prevention)
エラーが発生する前に防ぐ設計。
- lecsy 例: 削除前に「本当に？」、入力前にフォーマット例示

### 6. 再生より再認 (Recognition rather than Recall)
記憶させず、選ばせる。
- lecsy 例: タグは選択式、教科書名はオートコンプリート

### 7. 柔軟性と効率性 (Flexibility and Efficiency)
初心者にはガイド、熟練者にはショートカット。
- lecsy 例: キーボードショートカット、3タップ機能を2タップに短縮

### 8. 美的で最小限のデザイン (Aesthetic and Minimalist)
関連性の低い情報は削ぎ落とす。
- lecsy 例: 録音中は録音に関係ないUI要素を非表示

### 9. エラーからの回復 (Error Recovery)
エラーメッセージは**技術コードではなく解決策を提示する平易な言葉**。
- 悪い例: "Error 500: Internal Server Error"
- 良い例: "接続に問題が発生しました。数秒後に再度お試しください。問題が続く場合は [サポート]"

### 10. ヘルプとドキュメント (Help and Documentation)
コンテキストに合わせたヘルプを即座に参照できるように。
- lecsy 例: 各画面の右上に「?」ボタン、該当機能のガイドに直接遷移

## lecsy UI レビュー手順

1. 各画面のスクリーンショットを撮る
2. 10項目を順にチェック → ✅ / ❌ / ⚠️ で評価
3. ❌ と ⚠️ をリスト化
4. 優先度付け（ユーザー影響度 × 修正コスト）
5. 上位5件を [[Design Sprint ソロ版]] で修正

## 関連

- [[Don Norman 設計原則]]
- [[Mobile-First 設計鉄則]]
- [[Design Sprint ソロ版]]
