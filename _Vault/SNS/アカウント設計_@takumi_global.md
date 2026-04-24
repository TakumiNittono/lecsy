# @takumi_global アカウント設計 v2 (2026-04-24)

> 親: [[MOC_SNS]]
> **前版 (v1) は self-identity 過剰で捨てた。v2 は「問いに答える account」フレーム**

## TL;DR

- **誰** は minimum (Bio の 1 行のみ、本文では名乗らない)
- **Voice (taste)** は strong (実測主義 / Apple 美学 / 誇大嫌い)
- **何** を central (5 つの問いに答え続ける account)
- **形式** = 全投稿が `Q + A (3 点)` 構造、自分語り禁止

## Goal: 影響力 / fans を持つ、でも personal は出さない

「fans は Identity じゃなく Voice にしかつかない」が大前提。本名・家族・出自を出さずに fan を作るには:

1. **Voice (taste)** を尖らせる — 美学・批判の方向・ユーモアの癖で覚えさせる
2. **Signature format** を固定 — 毎回 Q+A 3点 → "あ、takumi_global だ" の即時認識
3. **Daily drumbeat** — 朝 08:00 / 昼 12:30 / 夜 21:00 JST の定時性
4. **Memorable NG** — 「こういうのは書かない」が明確だと信頼が積み上がる
5. **問いへの回答 reply** — DM・リプは返す (ただし personal な雑談はしない、問いには答える)

## Voice (taste) — 3 層

### 1. 実測主義
- 「体感」「たぶん」「おそらく」禁止
- 最後は必ず断定か選択肢提示で閉じる
- 数字のない主張を書かない

### 2. Apple 美学派 ([[feedback_lp_apple_aesthetic]] と整合)
- モノクロ基調の美学
- グラデ・パルスドット・ダサい多色 UI を言語化して嫌う
- minimalism 寄りの判断 (「要らない」を積極的に書く)

### 3. 誇大表現を嫌う
- "業界初" "最速" "革新的" "シームレス" "AI-powered" を使わず、使われると皮肉る
- AI slop / marketing 言語を翻訳して出す型 (「"シームレスな体験" = 説明できないから逃げてる」)

## Voice を投稿に染み込ませる 3 型

### A. 断定で閉じる型
```
Q: X は Y と Z どっち？

A:
• 数字 1
• 数字 2
• 条件分岐

[結論 1 行] → Y 一択。迷うな。
```

### B. NG 提示で閉じる型
```
Q: X を設計するなら何に気をつける？

A:
• 選ぶべき (1-2 行)
• 避けるべき (1-2 行)
• 罠 (1-2 行)

[avoid 1 行] → これをやったら UX が死ぬ。
```

### C. AI slop 翻訳型 (たまに)
```
"シームレスな AI 体験" を翻訳すると:
• 実装の詳細を説明したくない
• 遅延が隠せないから presentation で誤魔化す
• 数字で比較されたくない

実測 TTFB 300 ms と書けば済む話。
```

## 答える 5 問

この account に来た読者が `Q: ... の答えをください` で受け取れる 5 つ。**他の Q は捨てる**。

| # | 問い | pillar |
|---|---|---|
| 1 | **Deepgram と WhisperKit、どう使い分ける？** | P3 技術 |
| 2 | **iOS でリアルタイム音声処理、どこで落とす？** | P3 技術 |
| 3 | **AI × 教育プロダクトのユニットエコノミクスは？** | P1 数字 |
| 4 | **米国の語学学校にどう売り込む？** | P2 GTM |
| 5 | **OPT 1 年で技術者が LLC 立てるなら何をいつやる？** | P2 法務 |

→ **投稿は全部この 5 問の派生形**。他は書かない。

## 全投稿の必須形式

```
Q: [問いを短く]

A:
• [要点 1 + 実測数字]
• [要点 2 + 選択肢 / 代替案]
• [要点 3 + 具体手順 or 次アクション]

[必要なら出典 / Vault link / CTA]
```

- **Q は必ず書く** (内部的でも OK、見出し or ツイ冒頭)
- **A の 3 点は必ず分ける** (まとめ読みを助ける)
- **数字なしの A は書かない** (抽象論禁止)
- **出典は Vault にあるものだけ**

## flagship: 毎週金曜 17:00 JST「今週解けた問題」

週 1 の大玉スレッド。3-5 ツイで 1 つの Q を深掘り:
1. 問いの背景 (なぜこれが問題か)
2. 試した選択肢 + 結果 (数字)
3. 最適解 (条件付き)
4. 失敗パターン (避けるべき罠)
5. CTA (DM / Substack)

→ これが後の Substack 化・書籍化の素材になる。

## 語り手の設定 (minimal、本文では基本出さない)

- **Allow**: Takumi (下の名前のみ) / Florida / OPT 中 / AA 取得 / Lecsy 作ってる
- **NG**: Nittono / 苗字 / 家族 / 学校名 / 市 / 年齢 / Founder / 〜した (完了形)
- **動詞ルール**: 「作ってる / Building / 攻めてる / 営業中」のみ。「Founder / Built / Sold / Launched」は **2026-06-01 ローンチ後**に段階的解禁

## bio (v2)

```
iOS 音声 AI と米国 B2B 教育、AI × 教育のコスト構造について書いてる
Florida / OPT / Lecsy 作ってる
lecsy.app
```

→ 4 行。自己定義よりトピック定義。

## Display name (v2)

**推奨: `Lecsy / Building` or `Takumi (Lecsy)`**
- "Nittono" 系は出さない
- Founder 系の肩書きも書かない
- `takumi_global` のままでも良い

## 書かないことリスト（確定）

- 「今日 X した」系の日報
- 「今週の進捗」系の自分語り
- マインド系 / 朝活 / ルーティン / 精神論
- 他社名指し批判 (Otter は / Notta は)
- 捏造エピソード (体験年数・回数・感情)
- Founder / 完了形 / 達成 claim
- 本名 / 家族 / 学校名 / 市
- Vault に無い数字

## NG ワード（guardrail で自動ブロック）

- 本名系: `Nittono`, `新藤`, `ニットノ`
- 肩書き claim: `Founder`, `Founded`, `CEO`
- 完了形 overclaim: `launched`, `sold to`, `built a company`
- 競合: `Otter は`, `Notta は`, `CLOVA は`
- 誇大: `業界No.1`, `業界最安`, `唯一無二`
- 誇張: `すべての`, `全員が`, `みんな`
- 言語の嘘: `100+ languages`, `12 言語`

## KPI (main = b + d)

- **DM が週 5 件、コア読者 30 人** (quality)
- **B2B 商談 1 件がここ経由で発生** (distribution)
- フォロワー数は副次指標

## 関連

- [[MOC_SNS]] / [[SNS/tone_sample]] / [[SNS/在庫_マップ]]
- [[SNS/ピン留めツイート_ドラフト]]
- [[SNS/戦略_2026-04-24]] (上位戦略)
- memory: [[feedback_no_real_name]] [[feedback_value_first]] [[feedback_no_fabrication]] [[feedback_no_founder_claim]]
