# @takumi_global アカウント設計 (2026-04-24)

> 親: [[MOC_SNS]] / [[SNS/戦略_2026-04-24]]
> この文書が sns-generate.mjs の tone / pillar / NG を決める。**迷ったらここに戻る。**

## TL;DR

- **誰**: Florida で米国 B2B SaaS を作る個人開発者 (OPT 日本人)
- **誰に**: 日本の indie 起業家 / OPT 日本人エンジニア / 米国挑戦予備軍
- **何を**: Build in Public (40%) + OPT/米国起業 一次情報 (30%) + 技術 deep dive (30%)
- **何語で**: 日本語 (2026-06 まで) → 英語を徐々に混ぜる (クロスオーバー表は [[SNS/戦略_2026-04-24]])

---

## 1. Identity

**一文で:** Florida で米国 B2B SaaS を作ってる個人開発者 / OPT 日本人

- **Founder of Lecsy** ではなく **個人開発者** を主語に。Lecsy は畳めるが nittono は残る = 財産性
- 「日本人 × OPT × 米国起業」が Unique Knowledge (Justin Welsh の執着)
- "エンジニア" より "個人開発者" のほうが indie / B2B 両方に刺さる

## 2. Audience (優先順位つき)

| # | 層 | なぜ | 直近のリターン |
|---|---|---|---|
| 1 | **日本 indie 起業家 / 個人開発者** | 応援・引用 RT・コラボ | フォロワー初期加速 |
| 2 | **OPT / 留学中 日本人エンジニア** | 共感・DM 相談 | 将来のベータユーザー・採用 |
| 3 | **日本→米国挑戦の予備軍** | 共感の広がり | 長期 distribution |
| 4 | **米国 edtech 投資家 / B2B 担当** (後) | Lecsy の資金 / 提携 | 英語化後 |

→ 最初の 3 ヶ月は **1 + 2** に絞る。米国 B2B は Lecsy の英語 LinkedIn が拾う。

## 3. Content Pillars (3 本の軸)

### P1 — Build in Public (40%)
**何を:** Lecsy の数字・決定・失敗
**例:**
- 週次 MRR 公開
- Deepgram コスト実測 ($0.003/min を 90 分授業で回したら)
- FMCC パイロット進捗 (許可された範囲で)
- pivot ログ (なぜ Web を B2B only に封印したか)
- 失注の理由

### P2 — OPT / 米国起業 一次情報 (30%)
**何を:** 日本人が OPT 1 年で米国 B2B SaaS を立ち上げる現場感
**例:**
- LLC 設立直後 10 タスク ([[学び/LLC 設立直後10項目]] 素材)
- Form 5472 の落とし穴
- O-1A 実績構築 (OPT 中にやる)
- コミカレ ESL 部門長への warm intro の取り方
- ESL 営業の断られ方 5 パターン

### P3 — 技術 deep dive (30%)
**何を:** Deepgram × iOS × Supabase × AI のリアル
**例:**
- Deepgram nova-3 WebSocket 最小構成
- WhisperKit vs Deepgram の使い分け (Free/Pro 境界設計)
- Swift async/await 落とし穴 3 つ
- Supabase Edge Function で credential rotation
- Cursor/Claude Code 実使用ログ

### 意識的に **入れない**
- 一般マインド系 (Founder Mode / 時間管理 / 朝活 / 意識高い) — 差別化度ゼロ、AI slop と見分けつかない
- 他社批判 (Otter / Notta / CLOVA 名指し)
- 他人の記事/ツイートの論評だけの投稿 (一次情報なし)
- 「今日の学び」系テンプレ

## 4. Voice

| 項目 | ルール |
|---|---|
| 一人称 | **「俺」** が基本 / ですます混ぜる時だけ「私」 |
| 文体 | タメ口 7 : ですます 3 |
| 断定 | 数字の裏付けがあれば断定 (「Deepgram は 1 分 \$0.003」) |
| 絵文字 | 最大 1 個/投稿 |
| ハッシュタグ | **禁止** (日本語 X では逆効果) |
| 長さ | 単発 140 字 or スレッド 3-5 ツイ |
| 構成 | 断定 → 数字/経験 → 問い or CTA |
| CTA | DM / ニュースレター / (たまに) App Store |

### 構造テンプレ (3 パターン)

**A. 数字単発:**
> [断定一行]
> [数字の根拠 1-2行]
> [自分なりの解釈 or 問い]

**B. スレッド 3 ツイ:**
> 1/3 問題提起 (俺は〜で困った)
> 2/3 解決策 + 数字
> 3/3 示唆 + DM 開放

**C. 失敗告白:**
> [何をやらかしたか]
> [なぜそれが起きたか]
> [今後どうするか / 学び]

## 5. Profile 設定 (@takumi_global)

### Handle (URL)
**推奨変更: `@Ww83vjNwSLXhV6B` → `@takumi_global`**
- x.com/settings/account/username で変更可 (空いてれば)
- フォロワー少ない今が痛手最小
- プロフィール URL が覚えやすい (名刺代わり)

⚠️ 変更したら `.env.local` の `X_HANDLE=takumi_global` に更新必須。

### Display Name
**推奨: `Takumi Nittono / Lecsy`**
- 名前 + 製品を 1 行で名刺化
- indie 起業家界隈で「あ、Lecsy の人ね」と即認識される

### Bio (120 字)
```
Florida で米国 B2B SaaS を作る個人開発者
米国語学学校向け講義AI『Lecsy』 @lecsyapp
Deepgram × Claude × iOS × Supabase
OPT 1年、失敗含めて公開で作る
```

### Bio (英語版 LinkedIn 用)
```
Building a lecture AI for U.S. language schools.
Solo dev, OPT, Florida. Swift + Deepgram + Claude.
Japanese immigrant founder building in public.
```

### Header Image (提案 3 案)

**案1 (テキストのみ・Apple 寄せ):**
```
[白背景]
Building in public from Florida
—
Japanese solo dev → U.S. B2B SaaS
@lecsyapp
```

**案2 (製品 + 実績):**
Lecsy アプリのスクショ + "90 min lecture → AI summary in 3 sec"

**案3 (顔 + タイムライン):**
顔写真 + "OPT 2026-06 → LLC → STEM OPT → H-1B" のビジュアルライン

→ **案1 推奨** (Apple 寄せ tone と揃う、長期的にブレない)

### Pinned Tweet
→ 別ファイル: [[SNS/ピン留めツイート_ドラフト]]
5 ツイの自己紹介スレッド。投稿 → pin → プロフィール完成

## 6. NG (絶対やらない)

- 他アプリ名指し批判 (Otter / Notta / CLOVA)
- 政治 / 宗教 / ジェンダー論
- 「すべての〜」「みんな〜」「世の中〜」の一般化
- Vault に無い数字を書く (guardrail が弾くが、ここでも禁止明記)
- @メンションで他人に話しかける (誤爆事故)
- 深夜 0-5 時の感情投稿 (翌朝まで寝かせる)
- "今日の学び" / "朝のルーティン" / "モーニングページ" 系テンプレ
- 未発表機能の予告 (WWDC 前は特に警戒)

## 7. 測定指標 (月次で見る)

- **フォロワー数**: 6/1 までに 500、9/1 までに 1500
- **engagement rate**: 平均 2%+ (いいね+リプ+RT / インプ)
- **DM 数/月**: 10+ (返信できる人のリストが本当の財産)
- **Substack 登録数** (始めたら): X フォロワーの 5%+ がコンバート
- **失敗投稿 (削除 or guardrail block)**: 月 3 件以内

## 8. このドキュメントの運用

- **変更の主導権はあなた**。AI が勝手に書き換えない
- 月初に 5 分で見直し: audience / pillar / voice が古くなってないか
- pillar 配分 (40/30/30) は 3 ヶ月ごとに再チューニング

## 関連

- [[MOC_SNS]] / [[SNS/戦略_2026-04-24]] / [[SNS/運用ルール]]
- [[SNS/tone_sample]] (このドキュメントの tone を具現化した例)
- [[SNS/ピン留めツイート_ドラフト]]
- [[SNS/在庫_マップ]] (pillar に沿った候補 31 本)
- [[学び/Justin Welsh LinkedIn 3段階システム]] (Unique Knowledge 理論)
- [[学び/Work in Public 戦略]]
