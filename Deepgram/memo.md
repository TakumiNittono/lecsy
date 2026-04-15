# 🚀 Lecsy 戦略ロードマップ（Whisper → B2B Pro）

> 最終更新: 2026-04-15
> **このファイルは実行ベースの戦略正本**。コードと常に同期させる。

---

## 🎯 全体目的

初期段階は **コスト最小 × 体験を崩さない** で成立させ、
段階的に「他にない体験」を積み上げて B2B 高単価へ上げていく。

**売り先順序**:
1. 個人の留学生（B2C）= 信用装置
2. 米大学 ISSS / ESL（B2B）= 本命収益
3. Enterprise 全学契約 = 爆発

---

## 🟢 フェーズ1：初期プロダクト（現在、〜5月末）

### 技術スタック
- **文字起こし**: WhisperKit（iOS オンデバイス）
- **AI要約**: OpenAI `gpt-5-nano` 経由の既存 `summarize` Edge Function
- **同期**: Supabase Postgres (transcript text のみ、音声は端末残留)
- **認証**: Apple / Google / Magic link
- 💰 Deepgram / GPT-4o Mini 翻訳 **使わない**

### UX
- 録音 → 停止 → WhisperKit が端末上で文字起こし
- 要約・復習は既存の `LectureDetailView` で提供
- リアルタイム字幕は **表示しない**（= Pro 体験として封印）

### KPI
- 安定クラッシュ率 < 1%
- WhisperKit文字起こしの満足度（内部調査）
- 週次 Active 500人（既存DL）→ 維持

### 完了条件
- [ ] キャンペーンバナー（全員Pro無料）文言を撤去
- [ ] Free プランが default = WhisperKit 経路で動作
- [ ] Settings に "On-Device Transcription" 表示
- [ ] Beta org を作って俺自身を member に入れて動作確認

---

## 🧪 フェーズ2：パイロット運用（友人 Beta、5月末〜6月末）

### 対象
- 俺（たくみ）自身 + 留学生の友人 5〜15人
- 全員「Beta Tester」として `lecsy-beta` 組織に所属

### 位置づけ
- **"無料ユーザー" ではなく "Private Beta"**
- Pro機能（Deepgramリアルタイム字幕 + 翻訳）を個別にアンロック
- 使用時間・満足度を実データで計測

### 仕組み
- Web `/admin/beta` から、俺が email を追加すると Pro 化
- Beta Tester は実際 `organization_members.status='active'` として記録
- PlanService が org membership を読んで Pro 判定

### 実施内容
- 1日最低1講義の録音（真面目に使う）
- 週1の Slack / LINE ヒアリング
- エラー/要望/好感ポイントを Airtable or Notion に記録

### KPI
- Beta Tester の週次 recording 時間
- クラッシュ・翻訳レイテンシ実測値
- 「他人に勧めたいか」NPS

### 完了条件
- [ ] 5人以上が週1本以上録音
- [ ] Deepgram streaming 平均レイテンシ < 1秒を実測
- [ ] 翻訳品質に対する Go/NoGo 判断（母語ネイティブのスコア）

---

## 🔴 フェーズ3：B2B Pro 実装（6月〜8月）

### 必要な Pro 機能
| 機能 | 現状 | 必要作業 |
|------|-----|---------|
| Deepgram リアルタイム字幕 | ✅ 実装済 | Beta で実測、バグ取り |
| Bilingual Live Translation | ✅ 実装済 | 品質調整、UI改良 |
| AI Study Guide | ✅ 既存 | Quick/Standard/Deep 段階追加 |
| Vocabulary 抽出 | ❌ 未 | `extract-vocabulary` Edge Function + pgvector |
| Anki export | ❌ 未 | `.apkg` 生成、iOSから .eduライブラリへ送る |
| Exam Prep Plan | ❌ 未 | 試験日入力 → GPT で逆算プラン生成 |

### B2B 固有機能
- SAML SSO（Enterprise）
- FERPA DPA テンプレ
- HECVAT-Lite 即答
- per-seat usage dashboard
- 管理者向け月次レポート (CSV)

### KPI
- ベータ校 5-10校 にデモ実施
- Protocol Agreement 署名 2-3校
- UF ELI / Santa Fe のいずれかが Fall session で pilot 開始

---

## 🎯 フェーズ4：B2C 無料体験設計（6月1日以降）

### 無料ユーザーの流れ
```
1. DL → サインイン → 即 WhisperKit 経路 (コスト$0)
2. "Pro を 30分無料体験" ボタン（オンボーディング内）
3. Pro 体験中: Deepgram Live字幕 + 翻訳を見せる
4. 30分超過: 体験終了 → 継続するなら課金導線
5. 課金しない: WhisperKit 経路で永続利用可
```

### 無料体験（30分限定）の実装方針
- `subscriptions.trial_seconds_granted: 1800` で granted
- Deepgram cap は streaming minutes で減算
- UI: "あと ${残り}分 の Pro 体験" を LiveCaptionView 上に表示
- 体験中はフル機能（翻訳 + Study Guide + Anki）

### 目的
- 初回で「これすげえ」と言わせる
- 課金への明確な橋渡し
- でも無料ユーザーを切り捨てない（WhisperKitで永続利用OK）

### 完了条件
- [ ] 6/1 までにトライアル機構完成
- [ ] WhisperKit 経路が Trial 後も自然に動く
- [ ] コンバージョン率 3% 以上（Trial → paid）

---

## 💰 フェーズ5：マネタイズ展開（6月〜年末）

### B2C
| プラン | 月額 | 狙い |
|-------|-----|-----|
| Free | $0 | 導線、WhisperKit、永続利用 |
| Student $7.99 | .edu限定 | 学部生（典型ユーザー） |
| Pro $12.99 | - | 院生・非学生 |
| Power $24.99 | - | PhD・研究者・ヘビーユーザー |

### B2B（本命収益）
| プラン | 年額 | 席数 | 狙い |
|-------|-----|-----|-----|
| ISSS Starter | $5,989 | 100 | 小規模ESL / コミカレ |
| ISSS Growth | $14,990 | 500 | 中規模大学 ISSS |
| ISSS Premium | $39,990 | 2,000 | 大規模大学 |
| Enterprise | $25K-75K | 無制限 | SAML / VPAT / SOC2要 |

### 売り方
- B2C は SNS / クチコミ / ASO で獲得
- B2B は LinkedIn + 訪問 + ISSS Director個別営業
- UF ELI flagship → "Used at UF" ブランドで横展開

---

## 🔥 コア戦略原則

### 1. 段階的価値提供
```
Free WhisperKit → Pro Trial 30分 → 継続課金 → B2B個別営業
```
各層で「次に行きたくなる理由」を用意する。

### 2. コスト最適化
| 層 | 原価 | 戦略 |
|---|-----|-----|
| Free WhisperKit | ほぼ $0（端末側） | 全開放OK |
| Pro Trial | $0.55/h Deepgram + $0.75/h GPT | 時間制限で抑制 |
| Paid Pro | 同上 | 売上で十分カバー |
| B2B | per-seat 減価 | 実稼働率30%で見積もる |

### 3. B2C → B2B 導線
- 学生個人が「大学に導入してほしい」と言い出す仕組み
- ISSS に「既にうちの留学生10人使ってる」アプローチ
- 草の根 → 上からの決定 の両面作戦

---

## ⚠️ 絶対ルール

1. **無料でフル機能を開放しない**（= いまのキャンペーン解除）
2. **Trial には厳密なタイムリミット**（30分、秒単位で計測）
3. **友人は "Beta Tester" として扱い、ただの無料ではない**（フィードバック義務）
4. **Apple IAP 不採用、Stripe Web 一本**（30%回避）
5. **音声は lecsy 保存しない**（Deepgram は30日で削除）

---

## 💬 最重要マインド

> 無料で満足させるのではなく、
> 無料で「欲しくさせる」プロダクトを作る

Free は **信用装置**、B2B が **本丸**。
毎朝この memo を開いて、迷ったらこの原則に戻る。

---

## 🛠 実装ガードレール（コード真実）

| 判断 | コード場所 | 現状 | 目標 |
|------|----------|------|------|
| キャンペーン中 Pro 昇格 | `PlanService.isPaid`, `deepgram-token`, `isPro.ts` | ON | **OFF**（即） |
| Free 経路 | `RecordView.startTranscription` | Deepgram→WhisperKit fallback | Free = WhisperKit のみ |
| Beta Tester 管理 | `organization_members` (lecsy-beta org) | 未設定 | web `/admin/beta` で追加 |
| Pro Trial 30分 | 未実装 | — | フェーズ4で追加 |

---

## 🔗 関連ファイル

- `価格設計_現行.md` — 具体的なプラン cap と Stripe 設定
- `EXECUTION_PLAN.md` — W01-W08 実装タスクゲート
- `OPERATIONS.md` — Live切替手順、障害対応
- `10_勝利のための鉄則.md` — 毎朝読むマントラ
