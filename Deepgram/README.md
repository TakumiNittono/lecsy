# lecsy 2.0 完全パッケージ（Deepgram版）

> これは lecsy の **WhisperKit→Deepgram 大転換** に伴う、今後の全方針をまとめた完全パッケージ。
> 既存 `CURRENT_STATUS.md` の状態から、このパッケージの内容に全面切替する。
>
> 最終更新: 2026-04-14

---

## 📖 このフォルダとは

lecsy を「世界中の大学が使うアプリ」にするための**戦略・プロダクト・営業・技術・法務**のすべて。
lecsy プロジェクト（iOSコード・Web・Supabase）に**そのまま持ち込める**自己完結パッケージ。

### なぜ "Deepgram" 名か
WhisperKit（オンデバイスAI）から Deepgram Nova-3（クラウドSTT）への転換が**最大の意思決定**だったから。この選択が全ての方向性（価格・機能・営業・堀）を決めた。

---

## 🎯 この中身を5行で

1. **コンセプト**: "Your semester-long AI companion for English lectures" — 留学生向け学期OS
2. **技術**: Deepgram Nova-3 + GPT-4o Mini + Stripe + Supabase（WhisperKit完全削除）
3. **5キラー機能**: Bilingual Captions / Course Hierarchy / AI Study Guide / Vocabulary+Anki / Exam Prep Plan
4. **価格**: Pro $12.99 / Student $6.99 / ISSS $499-2,499 / Enterprise $25-75K/年
5. **営業**: B2C個人留学生 → 大学ISSS B2B → Enterprise全学、3段階

---

## 📁 フォルダ構造

```
Deepgram/                 ← このフォルダ (lecsy codebase に持って行く対象)
│
├── README.md             ← この文書（入口）
├── 00_INDEX.md           ← ナビゲーション
│
├── 01_ビジョンと勝ち筋.md      ← 戦略の核、毎週読む
├── 02_5キラー機能完全仕様.md   ← プロダクトの顔
├── 03_競合完全ガイド.md         ← 55社マップ
├── 04_営業完全戦術書.md         ← 毎日の営業バイブル
├── 05_90日アクションプラン.md   ← 4/14-7/13 週次計画
├── 06_技術スタック完全版.md     ← アーキ
├── 07_価格とユニットエコノミクス.md ← 数字
├── 08_法務コンプライアンス.md    ← FERPA/HECVAT/DPA
├── 09_リスクマップと対策.md     ← Top10リスク
├── 10_勝利のための鉄則.md       ← 毎朝読む
│
├── プロダクト/         ← アプリの詳細仕様
├── ビジネス/           ← 価格・競合・GTM・Stripe・財務
├── 技術/               ← Deepgram実装・移行・API仕様
├── 営業/               ← プレイブック・ターゲットリスト・HECVAT
├── ロードマップ/       ← 12ヶ月計画・1年バトルプラン
├── 法務OPT/            ← LLC・ビザ・リスク
└── 変更履歴/           ← WhisperKitからDeepgramへの変更点
```

---

## 🚀 lecsy プロジェクトで使う時

### Claude Code に渡す時
```bash
# lecsy プロジェクトのルートにこのフォルダをコピー or シンボリックリンク
cp -r /path/to/knowlege/Deepgram /path/to/lecsy/docs/

# もしくはリポジトリに直接 commit
cd /path/to/lecsy
cp -r /path/to/knowlege/Deepgram ./docs/
git add docs/Deepgram
git commit -m "Add Deepgram 2.0 strategy package"
```

### iOS/Web 開発で参照する順序
1. `01_ビジョンと勝ち筋.md` でゴールを掴む
2. `02_5キラー機能完全仕様.md` で何を作るか確認
3. `プロダクト/キラー5機能仕様.md` で詳細仕様
4. `06_技術スタック完全版.md` でアーキ理解
5. `技術/Deepgram-only設計_2026.md` で実装詳細
6. `05_90日アクションプラン.md` で今週やることを確認

### 営業先に行く前
1. `10_勝利のための鉄則.md` を読む
2. `04_営業完全戦術書.md` でトーク確認
3. `03_競合完全ガイド.md` で競合対応
4. `営業/HECVAT_Lite_回答テンプレ.md` を印刷

---

## ⚠️ 注意

### このパッケージと矛盾する古いノート
- `lecsy/プロダクト/プロダクト概要.md` の**旧版**（WhisperKit記述） → 無効、このフォルダが正
- B2C価格 $2.99-9.99 の記述 → 無効、$12.99/$6.99 が正
- 「完全オンデバイス」訴求 → 無効、「音声はlecsyサーバーに保存しない」が正

### 更新ルール
- 戦略変更があれば、**このフォルダを正**として扱う
- 四半期ごとに見直し
- 矛盾が出たら、このフォルダの更新日が後のものを採用

---

## 📜 変更履歴

- **2026-04-14** 初版作成。WhisperKit→Deepgram 転換に伴う完全パッケージ化。
  - 留学生特化ピボット確定
  - 5キラー機能決定
  - Stripe一本化、Apple IAP廃止
  - B2C→ISSS→Enterprise の3段階戦略確定
  - 全11ドキュメント + 既存26ファイル統合

詳細は `変更履歴/` フォルダ参照。

---

## 🔗 元のナレッジベース

このパッケージは下記から抽出・統合されている:

- `/Users/takuminittono/Desktop/knowlege/lecsy/` — 元のlecsy設計ノート群
- `/Users/takuminittono/Desktop/knowlege/営業/` — 営業関連
- `/Users/takuminittono/Desktop/knowlege/OPT/` — ビザ・LLC
- `/Users/takuminittono/Desktop/knowlege/brain/` — たくみ個人情報（含めず）

変更が必要な場合、このフォルダ内で行い、四半期末に元ナレッジへ反映する。

---

## 💡 最後に

このパッケージは**決定の集積**。迷った時はここに戻る。
新しい判断が必要な時も、まずここを読んで矛盾しないか確認する。

**"Otter は会議のため。Glean は障害者支援のため。StudyFetch は英語ネイティブ用。**
**lecsy は、英語講義に挑む留学生のための、唯一のiOS学期OS。"**
