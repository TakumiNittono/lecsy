# @takumi_global アカウント設計 v3 (2026-04-24)

> 親: [[MOC_SNS]]
> **v3: AI 最新情報発信者に pivot**。Lecsy は bio の 1 行のみ、本文では触れない。

## TL;DR

- **何**: AI 業界の最新発表を、一次ソースから **builder 視点**で解釈する account
- **誰に**: 個人開発者 / indie SaaS builder / エンジニア
- **誰**: Identity は最小、Voice (taste) は strong
- **形式**: 全投稿 `Q + A (3 点) + taste` 構造、日本語

## なぜこの概念か

- AI 業界の発表 velocity は毎日ある → ネタ枯渇しない
- 一次ソース (OpenAI / Anthropic / Google 等) から speed で勝負できる
- Reader applicability 100% (全 builder が AI 使う)
- 自分語り / 内部数字 trap を回避
- 差別化は Voice (煽り翻訳 + 実測比較) で作る

## 答える 5 問 (投稿はこの派生のみ)

| # | 問い | pillar |
|---|---|---|
| 1 | **新モデル / API、既存と何が違う？** (ベンチマーク + 価格 + 実装影響) | P1 |
| 2 | **新 AI ツール、どのユースケースに効く？** (使用レイヤー判定) | P2 |
| 3 | **API の価格・レート・機能、どう選ぶ？** (選定判断) | P3 |
| 4 | **論文/研究、個人開発者が使える部分は？** (抽出) | P4 |
| 5 | **業界の動き、builder はどう読む？** (メタ解釈) | P5 |

## 全投稿の必須形式

```
Q: [今日のニュースを 1 文で]

A:
• [一次ソース由来の数字 1 つ]
• [実装にどう使う / 使わないか判断]
• [既存ツール / 前モデルとの比較]

[taste 1 行: 煽り翻訳 / 断定 / NG 提示]

出典: [URL]
```

**必須要件:**
- 出典 URL を必ず含める (一次ソース直撃が voice の核)
- 数字は出典にあるものだけ (四捨五入・近似禁止)
- Q は **今日** のニュース or 発表から

## Voice (taste) 3 層

### 1. 一次ソース直撃
- 日本語二次翻訳より先に、OpenAI/Anthropic/Google の原文から直接拾う
- URL を貼る。二次情報記事を貼らない

### 2. 実測比較
- 「新モデル」の主張を数字で検証
- ベンチマーク / 価格 / レイテンシ / context window を前モデル・競合と比較
- 「体感」「たぶん」「おそらく」禁止

### 3. 煽り翻訳 (最強の差別化)
- "AGI に到達" "revolutionary" "業界初" "シームレス" などの marketing 煽りを実装レイヤーに翻訳
- "GPT-5 が推論できる" → "1 shot で 200 token / $0.003、誰も chain-of-thought 組まずに使える"
- 煽りを数字で分解する

## 情報源 (一次ソース優先)

| 源 | 取得方法 | 頻度 | pillar |
|---|---|---|---|
| **Hacker News front page** | RSS (https://news.ycombinator.com/rss) | 日次 | P1-P5 |
| **Google AI blog** | RSS (https://blog.google/technology/ai/rss/) | 日次 | P1, P2 |
| **OpenAI news** | 公式 site scrape (RSS なし) | 日次 | P1, P3 |
| **Anthropic news** | https://www.anthropic.com/news (scrape) | 日次 | P1, P3 |
| **Meta AI blog** | https://ai.meta.com/blog (scrape) | 週次 | P2 |
| **arxiv cs.AI new submissions** | RSS (https://arxiv.org/rss/cs.AI) | 日次 | P4 |
| **Vercel AI SDK releases** | GitHub atom (https://github.com/vercel/ai/releases.atom) | 日次 | P2, P3 |
| **r/LocalLLaMA top** | RSS (https://www.reddit.com/r/LocalLLaMA/.rss) | 日次 | P2, P5 |

→ `sns-collect.mjs` で RSS fetch して `_Vault/SNS/Daily/YYYY-MM-DD.md` に top 10 items。

## 投稿の source の扱い

- **Primary**: 今日の Daily.md 内のニュース item 1 つを sourceContent として generator に渡す
- **Secondary**: 在庫マップは使わない (将来削除検討)

## Identity (最小)

- **Allow**: Takumi / Florida / OPT 中 / Lecsy 作り中 **← ただし bio の 1 行のみ、本文で言及しない**
- **NG**: Nittono / 苗字 / 家族 / 学校名 / 市 / 年齢
- **NG**: 本文で Lecsy, lecsy.app, 講義 AI, 「自分のプロダクト」系を書く
  (bio と プロフィール URL の `lecsy.app` だけ例外)

## Bio (v3)

```
AI 業界の最新発表を builder 視点で。実測と比較、煽りぶった切り。
OpenAI / Anthropic / Google / HN / arxiv を一次ソースから。
日本語 / Florida / Lecsy 作り中
```

## Pinned tweet v3

→ [[SNS/ピン留めツイート_ドラフト]] (3 ツイ、問いベース、Lecsy 無言及)

## 語彙の完全禁止 (本文)

- Lecsy / lecsy / 講義 AI / iOS アプリ (自製品の宣伝)
- 本名 (Nittono / 新藤 / ニットノ)
- 肩書き claim (Founder / CEO / Founded)
- 完了形 overclaim (launched / sold / built / 達成した)
- 自分語り (今日 / 今週 / 俺が / 自分の進捗)
- @メンション / ハッシュタグ
- 煽り語彙 (業界初 / 最速 / 唯一無二 / 革新的 / シームレス / AI-powered)
- 一般化 (すべての / みんな / 全員が / 100%)
- 体感語彙 (たぶん / おそらく / 体感)

## KPI (main)

- DM 週 5 件 / コア読者 30 人 (Voice に fan がつく量)
- 平均 engagement rate 2%+
- 1 投稿あたり reader の「一次ソースに飛ぶ」率が計測指標化できたら追う

## 関連

- [[MOC_SNS]] / [[SNS/tone_sample]] / [[SNS/ピン留めツイート_ドラフト]]
- [[SNS/自動化_情報源]] (v3 - AI RSS に書き直し)
- [[SNS/自動化_運用手順]] / [[SNS/自動化_タイムテーブル]]
- memory: [[feedback_no_real_name]] [[feedback_no_founder_claim]] [[feedback_value_first]] [[feedback_voice_not_personal]] [[feedback_no_fabrication]]
