# 🗺 MOC — SNS (財産としての発信)

> Lecsy を畳んでも残る個人資産として、X / LinkedIn / Substack を積む。
> **本体は `_Vault/SNS/`。動線は `lecsy-video/scripts/sns-draft.mjs`。**

---

## 🎯 戦略と運用

- [[SNS/アカウント設計_@takumi_global]] — **Identity/Audience/Pillar/Voice/Profile** ★迷ったらここ★
- [[SNS/ピン留めツイート_ドラフト]] — 自己紹介スレッド (A案 5ツイ推奨)
- [[SNS/戦略_2026-04-24]] — 財産化の定義 / 個人8:製品2 / 3段階自動化
- [[SNS/運用ルール]] — プラットフォーム別カデンス / NG / CTA
- [[SNS/在庫_マップ]] — Vault ノート → 投稿ネタのマスタマップ

## 🤖 自動化 (@takumi_global 完全自動)

- [[SNS/自動化_決定ログ]] — 2026-04-24 リスク受諾の記録
- [[SNS/自動化_運用手順]] — 初期セットアップ / kill switch / 異常時
- [[SNS/自動化_タイムテーブル]] — cron の時刻設計 (JST 基準) と週次ルーティン
- [[SNS/自動化_情報源]] — Stripe/Supabase/Deepgram/GitHub/... 何をどこから取るか
- [[SNS/tone_sample]] — OpenAI に真似させる tone (ユーザー記入)

## 📥 日次ドラフト

- `_Vault/SNS/ドラフト/_TEMPLATE.md` — フォーマット
- `_Vault/SNS/ドラフト/YYYY-MM-DD.md` — 当日分 (sns-draft.mjs が生成)
- `_Vault/SNS/公開済/` — 投稿後にここへ移動 (効果測定の種)

## ⚙️ パイプライン

```bash
# 翌日分の下書きを3件作る
cd lecsy-video && node scripts/sns-draft.mjs --date=2026-04-25

# 状態ファイル (どれを出したか、次は何か)
# lecsy-video/content/sns-posts.json
```

## 📐 プラットフォーム配分 (Work in Public 戦略 に準拠)

| ch | 頻度 | 主ネタ | tone |
|---|---|---|---|
| **X (個人)** | 週3-5 | 技術/数字/ビルドログ | casual, thread可 |
| **LinkedIn (個人)** | 週1 | B2B学び/営業裏側 | Justin Welsh 3部構成 |
| **Substack** | 隔週 | 長文深掘り | essay |
| **YouTube** | 月1 | 10分深掘り | doc-style |
| **TikTok/IG Reels** | 週1-2 | 既存 `lecsy-video/` 動画転用 | visual |

## 🚫 混同しない

- **動画パイプライン** = `lecsy-video/` (HeyGen+Remotion)。SNS はその上流で、テキスト主・個人主。
- **製品アカウント (@lecsyapp)** は Launch 期の拡声器。**個人アカ (@nittonotakumi) が本命。**

## 📎 戻る: [[HOME]] / 関連: [[MOC_ASO_マーケ]] / [[学び/Work in Public 戦略]] / [[学び/Justin Welsh LinkedIn 3段階システム]]
