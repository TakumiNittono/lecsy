# PARA メソッド

> 出典: [[NotebookLM_学習/⑮ 生産性 個人運用]] / Tiago Forte (Forte Labs)

## 4つのフォルダ

情報を**4つのカテゴリ**に分類する Second Brain の整理法。

| フォルダ | 定義 | lecsy 例 |
|---|---|---|
| **Projects** | 明確な完了期限がある短期的な取り組み | 「v1.0 ローンチ」「FMCC パイロット商談」 |
| **Areas** | 継続的な責任（期限なし） | 「lecsy インフラ」「OPT 本業」「健康」「営業パイプライン」 |
| **Resources** | 将来役立つ興味関心 | 「Claude API ドキュメント」「UX 研究」「競合分析」 |
| **Archives** | 完了・保留した過去のもの | 「完了した機能実装」「過去商談の記録」 |

## 核心原則

### 「有用性」に基づいた分類
学問的な分類（「経済学」「プログラミング」）ではなく、
**「これを次にいつ、どのように使うか？」**という実用的な視点で配置。

## CODE ワークフロー

**C**apture → **O**rganize → **D**istill → **E**xpress

### Capture
ひらめいた知見を即、Inbox に放り込む（Obsidian の Daily Note）。

### Organize
定期的（週次）に PARA のどこに置くか決める。

### Distill
**「核心部分のみを太字にする」**ことで蒸留。
深夜の疲れた状態でも即座に実装（表現）に活用できる状態に。

### Express
実際の成果物（コード、ブログ記事、営業資料）に転用。

## lecsy Vault への適用

### 現状（整理前）
```
_Vault/
├── Deepgram/
├── NotebookLM_学習/
├── 学び/
├── HOME.md
├── （その他ランダム）
```

### PARA 適用案（2026-04 後半 移行）
```
_Vault/
├── 00_Inbox/       ← Capture の一時置き場
├── 10_Projects/    ← 期限あり
│   ├── v1.0-launch/
│   ├── FMCC-pilot/
│   └── O-1A-evidence/
├── 20_Areas/       ← 継続責任
│   ├── lecsy-infra/
│   ├── OPT-work/
│   ├── sales-pipeline/
│   └── health/
├── 30_Resources/   ← 参照用
│   ├── NotebookLM_学習/   ← 既存移動
│   ├── 学び/                ← 既存移動
│   ├── claude-docs/
│   └── edtech-research/
└── 90_Archive/     ← 完了・保留
```

### 移行手順
1. `00_Inbox` `10_Projects` `20_Areas` `30_Resources` `90_Archive` フォルダ作成
2. 既存 `_Vault/NotebookLM_学習/` を `30_Resources/` に移動
3. 既存 `_Vault/学び/` を `30_Resources/` に移動
4. アクティブプロジェクト（v1.0、FMCC等）を `10_Projects/` に切り出し
5. 全ドキュメントの内部リンク（[[...]]）を更新（Obsidian が自動）

## 関連

- [[Cal Newport Deep Work 2026]]
- [[Feel-Good Productivity 3原則]]
- [[Bootstrap Founder 日課5]]
