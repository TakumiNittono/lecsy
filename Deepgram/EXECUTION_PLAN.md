# EXECUTION PLAN — MVP of the Vision

> 作成: 2026-04-14 / 期間: 2026-04-14 〜 2026-07-13（13週）
> **このドキュメントが実行の単一真実**。戦略は`01`〜`10`、実装詳細は`技術/`、実行タスクはここ。
>
> **レーン分担**: 営業/メール/LLC/保険/コミュニティ発信 = 人間 (たくみ) / 実装・インフラ = AI (Claude)。
> このファイルは**実装タスクのみ**記載する。営業進捗は別管理。

---

## 🔒 スコープ凍結（触らない）

90日の実装スコープはこの5本のみ。追加する時は**ここを更新してから**コードを書く。

| # | スコープ | 何をしない | 凍結理由 |
|---|---------|----------|---------|
| 1 | Deepgram Nova-3 Streaming（JA+ENのみ） | 他言語、オフラインPrerecorded高度機能 | 差別化の中核、外すと存在価値消滅 |
| 2 | Bilingual Captions（JA+EN並列） | 3言語並列、話者別色分け、字幕編集UI | "唯一無二"の訴求点 |
| 3 | AI Study Guide **Quickのみ** | Standard/Deep、Quiz、Vocabulary、Anki、Exam Prep | GPT呼び出し1本化でコスト管理 |
| 4 | Stripe Web Checkout + 安全弁L1-L3 | L4/L5（iOS側フォアグラウンド/無音検知）、多通貨 | 課金導線の最低限 |
| 5 | UF ELI + Santa Fe 2校集中 | Orlando/Tampaツアー、10校営業 | Flagship戦略、広げると薄まる |

**追加禁止**: Course Hierarchy 4階層、pgvector、Vocabulary自動抽出、Anki export、Exam Prep、Syllabus OCR、Push通知、Live Activities、Android。

**例外条項の1本 (2026-04-21確定)**: ローンチ後 W09 以降、上位5本が完全動作したら、最初の追加機能は **Deepgramお試し枠** (Free ユーザーに Live字幕を初回30分 or 最初の1講義だけ解放、one-time)。Pro 転換率を上げる Free → Pro の導線。これ以外の機能追加は禁止。

---

## 🎯 ローンチ日: 2026-06-08（W08月曜）

90日プランの6/1から1週ずらす。根拠: 鉄則「遅延は最大2週間」許容 / W07 LLC設立とApp Store Reviewの並行を避ける。

---

## ✅ Week-by-Week Gate（各週末に全✅でないと翌週進まない）

### W01: 4/14-4/20 — 足場作り ✅ **完了 (2026-04-14)**
- [x] `Deepgram/EXECUTION_PLAN.md` 作成
- [x] Supabase migration 適用（`20260414000000_deepgram_realtime_usage.sql`）
- [x] Edge Function `deepgram-token` デプロイ、Gateway 401応答確認
- [x] iOS `DeepgramStreamSession.swift` / `DeepgramTokenProvider.swift` / `DeepgramAudioCapture.swift` 配置
- [x] 依存: URLSessionWebSocketTask（SPM追加不要）
- [x] Xcode: objectVersion 77 `FileSystemSynchronizedRootGroup` により自動ターゲット所属
- [x] Deepgram secrets（`DEEPGRAM_ADMIN_KEY`, `DEEPGRAM_PROJECT_ID`）は事前設定済み
- **Gate ✅**: curl疎通でGateway認証→functionへルーティング確認

### W02: 4/21-4/27 — iOS疎通 ✅ **前倒し実装完了 (2026-04-14)**
- [x] `lecsy/Services/TranscriptionCoordinator.swift` 新規（RecordingService観察、NWPathMonitor、Deepgram起動）
- [x] `lecsy/Views/Components/LiveCaptionView.swift` 新規（finalized/interim、BETA badge、auto-scroll）
- [x] `lecsy/Views/Home/RecordView.swift` に `LiveCaptionView` 統合（録音中のみ表示）
- [ ] **人間側E2E**: Xcodeで実機ビルド → 英語発話で字幕確認
- **Gate**: 実機で字幕表示、遅延<1秒

### W03: 4/28-5/04 — Bilingual プロトタイプ ✅ **前倒し完了 (2026-04-14)**
- [x] Edge Function `translate-realtime` デプロイ（GPT-4o Mini）
- [x] `lecsy/Services/TranslationStream.swift` 新規（per-segment翻訳キュー）
- [x] `lecsy/Views/Components/BilingualCaptionView.swift` 新規（左右並列ScrollViewReader同期）
- [x] `RecordView.swift` で `LiveCaptionView` → `BilingualCaptionView` に切替
- **Gate**: 実機で英語<500ms / 和訳<2秒（人間側で計測）

### W04: 5/05-5/11 — Study Guide Quick ✅ **既存実装で機能完結**
- [x] 既存 `summarize` / `summarize-stream` Edge Function が `gpt-5-nano` で稼働中
- [x] 既存 `SummaryService` (311行) + `LectureDetailView` (1153行) が summary/key_points/sections を表示
- [x] cachedSummary 機構あり、language別キャッシュ対応済み
- [x] camp期間中レート上限緩和 (50/day, 1500/month) も実装済み
- **note**: 「Study Guide Quick」専用UI追加は不要。既存サマリー導線がそのまま該当
- **Gate**: 既存`summarize`が10秒以内応答（人間側で計測）

### W05: 5/12-5/18 — WhisperKit fallback化 → 恒久配置化
**Phase 1 (2026-04-14 完了): Deepgram優先 + WhisperKit fallback**
- [x] `TranscriptionCoordinator.consumeFinalizedTranscript()` 追加
- [x] `RecordView.saveLecture()` 改修: liveResultあり→そのまま採用、なし→WhisperKit
- [x] 安全弁L1 (残高) / L3 (日次120分) は `deepgram-token` Edge Functionに実装済み
- [x] 安全弁L2 (月次600分) も同関数に実装済み

**Phase 2 (方針変更 2026-04-21): WhisperKit 恒久配置**
- 【撤回】WhisperKit 完全削除タスクは**実行しない**。理由: (1) Free ユーザー文字起こしコスト$0、(2) 鉄則4「音声を lecsy サーバーに保存しない」との整合、(3) Deepgram単一依存リスク回避、(4) オフライン対応（飛行機・地下・寮Wi-Fi不安定）。
- [ ] `TranscriptionService.swift` を `TranscriptionProvider` プロトコルで抽象化、Deepgram(Live+Batch) と WhisperKit パスを分離（1924行 → 700-800行目安）。**削除ではなく整理**。
- [x] `Info.plist` マイク用途文言書き換え (2026-04-14 完了)
- [x] `PrivacyInfo.xcprivacy` DataType更新 (2026-04-14 完了)
- [ ] `Info.plist` 文言を "processed via Deepgram (Pro) or on-device (Free)" の両対応文言に再修正

**Gate**: Phase 1 ✅ / Phase 2 はコード整理のみ、6/1 までに完了

### W06: 5/19-5/25 — Stripe Test mode 完全構築 ✅ **前倒し完了 (2026-04-14)**
**Edge Functions (deployed)**
- [x] `supabase/functions/create-checkout-session/index.ts`
- [x] `supabase/functions/create-portal-session/index.ts`
- [x] 既存 `stripe-webhook` は B2C(user_id) / B2B(org_id) 両対応のまま再デプロイ

**Web**
- [x] `web/app/pricing/page.tsx` — 月/年トグル、キャンペーンバナー、Pro/Student 2カラム
- [x] `web/app/api/stripe/checkout/route.ts` — Edge Functionプロキシ
- [x] `web/app/api/stripe/portal/route.ts` — Edge Functionプロキシ

**iOS**
- [x] `lecsy/Services/BillingService.swift` (2026-04-15) — `openPricing()` で Safari に `/pricing`、`openPortal()` で Stripe Customer Portal を開く。コード保有、UI は feature flag で gate。
- [x] `lecsy/Services/PlanService.swift` (2026-04-15) — Pro 判定を B2B (organization_members) と B2C (subscriptions.status='active' + provider='stripe') の 2 系統並行に拡張。`ProSource` enum で UI 分岐。`b2cCheckoutEnabled` flag も同時フェッチ。
- [x] Settings `PlanSection` (2026-04-15) — Pro via org は常に表示。Stripe 経路と "View Plans" は `feature_flags.b2c_stripe_checkout` が true の時のみ表示。
  **方針 (2026-04-15 再確認)**: 6/1 ローンチ時点は B2B のみ Deepgram Pro。B2C は WhisperKit Free のみで課金UI非表示。ローンチ後に個人プラン解放するときは `update public.feature_flags set enabled=true where name='b2c_stripe_checkout'` で remote 解放。

**Stripe Test mode infra**
- [x] Products作成: `Lecsy Pro` / `Lecsy Student`
- [x] 4 Prices作成 (Pro $12.99/$109yr、Student $6.99/$59yr)
- [x] Supabase secrets登録: `STRIPE_PRICE_PRO_MONTHLY/_YEARLY`、`STRIPE_PRICE_STUDENT_MONTHLY/_YEARLY`
- [x] Webhook endpoint作成 → `STRIPE_WEBHOOK_SECRET` 登録
- [x] `stripe trigger checkout.session.completed` 疎通確認

**Lookup keys** (将来Liveへの切替時に便利)
- `lecsy_pro_monthly` / `lecsy_pro_yearly` / `lecsy_student_monthly` / `lecsy_student_yearly`

**Gate ✅**: 全コード+infra完成。実動作テストは web/iOS UI から

### W07: 5/26-5/31 — プライバシー更新 ✅ **AI担当分完了 (2026-04-14)**
- [x] `lecsy/Info.plist` `NSMicrophoneUsageDescription` をDeepgram実態に書き換え
- [x] `web/app/privacy/page.tsx` 全面rewrite（Deepgram subprocessor明示、30日削除、ZDR言及、FERPA追加）
- [x] `web/app/terms/page.tsx` 更新（Pro/Student価格、Deepgram経路、B2B/教育機関セクション追加）
- **人間側スキップ (ユーザー指示)**: LLC, EIN, 銀行口座, 保険, App Store審査申請

### W08: 6/01-6/07 — 全開ローンチ（収益レバー3本同日起動）

**6/1 当日に解放するもの (方針確定 2026-04-21):**
1. **Stripe Test → Live 切替** (Products/Prices/Webhook Secret)
2. **B2C Pro $12.99/月 解放** — `update public.feature_flags set enabled=true where name='b2c_stripe_checkout'` で iOS Settings "View Plans"/"Manage Subscription" が即露出
3. **AI翻訳サブスク $5/月 同時ローンチ** — B2C Pro より軽い中間プラン、翻訳機能のみ解放
4. B2B Pro (Deepgram) は既に稼働中 → 合計 3本の収益レバーが同日ON

**前提実装（済）**
- [x] `supabase/functions/deepgram-balance-check/index.ts` deployed (auto-disable on低残高)
- [x] `supabase/migrations/20260414100000_system_alerts.sql` applied
- [x] `Deepgram/OPERATIONS.md` 運用マニュアル作成（Stripe Live切替手順、監視SQL、障害対応、cron設定）
- [x] `lecsy/Services/Deepgram/DeepgramBatchService.swift` 新規（Prerecorded API、WhisperKit fallback前段）
- [x] `RecordView.startTranscription` 改修: Deepgram batch primary、WhisperKit fallback
- [x] `lecsy/Services/BillingService.swift` をSettings画面に統合（"View Plans" / "Manage Subscription"）
- [x] **www.lecsy.app に本番デプロイ** — privacy/terms/sitemap/landing/pricing 全部Deepgram実態に整合
- [x] middleware に `/pricing` + SEOページ群を public で追加

**6/1 までに追加で必要なAIレーン作業**
- [ ] AI翻訳サブスク用 Stripe Product/Price 作成（`lecsy_translate_monthly`, $5/月）
- [ ] `supabase/functions/stripe-webhook/index.ts` で AI翻訳サブスクの price_id 分岐追加
- [ ] iOS `PlanService` に `ProTier` enum (`.pro` / `.translateOnly` / `.orgPro`) 拡張
- [ ] Web `/pricing` のバナー文言を "🚀 coming soon" → 本番文言に書き換え

**人間側 (6/1 当日)**
- Stripe Live切替実行、ユーザー通知配信、SNS投稿（日/韓/中コミュニティ）
- `b2c_stripe_checkout` feature_flag を true に
- Slack Webhook URL 発行 → `supabase secrets set SLACK_WEBHOOK_URL=...`

**Gate**: 24時間無事故、B2C Pro課金1号 or AI翻訳サブスク課金1号 獲得

### W09-W12: 6/08-7/06 — Summer pilot運用 + Deepgramお試し枠投入
- UF ELI Summer pilot 開始、週次フィードバック会議
- Santa Fe pilot 開始
- **営業は2校 + FMCC**。Tampa/Orlandoツアーはやらない（凍結スコープ）
- **W10 (6/15-6/21): Deepgramお試し枠を実装** — Free ユーザーが初回30分 or 最初の1講義だけ Live字幕を使える one-time 枠。`user_trial_realtime_usage` テーブル追加、`deepgram-token` Edge Function にトライアル判定、iOS で「お試し残り○分」バッジ表示、使い切り時の Pro誘導モーダル。これが**例外条項の1本**（残り追加禁止）
- その他の技術はバグ修正のみ
- **Gate (W12末)**: 2校パイロット稼働中、MRR $500以上、クラッシュ率<1%、お試し枠→Pro 転換率計測開始

### W13: 7/07-7/13 — 日本帰国準備
- パイロット運用引き継ぎ資料作成
- リモート監視体制（Slackアラート確認）
- 日本の留学エージェント2-3社にアポメール

---

## 🗂 コード変更マップ（完全再現用）

### 新規作成ファイル

```
supabase/migrations/20260414000000_deepgram_realtime_usage.sql    [W01]
supabase/migrations/20260420000000_feature_flags.sql              [W01]
supabase/functions/deepgram-token/index.ts                        [W01]
supabase/functions/deepgram-balance-check/index.ts                [W01]
supabase/functions/translate-realtime/index.ts                    [W03]
supabase/functions/generate-study-guide/index.ts                  [W04]
supabase/functions/create-checkout-session/index.ts               [W06]
supabase/functions/create-portal-session/index.ts                 [W06]

lecsy/Services/Deepgram/DeepgramStreamSession.swift               [W01✅ URLSessionWebSocketTask]
lecsy/Services/Deepgram/DeepgramTokenProvider.swift               [W01✅ LecsyAPIClient統合]
lecsy/Services/Deepgram/DeepgramAudioCapture.swift                [W01✅ 16kHz linear16]
lecsy/Services/TranscriptionCoordinator.swift                     [W02✅ NWPathMonitor + Deepgram起動]
lecsy/Views/Components/LiveCaptionView.swift                      [W02✅ BETA badge付き]
lecsy/Services/TranslationStream.swift                            [W03]
lecsy/Views/Home/BilingualCaptionView.swift                       [W03]
lecsy/Views/Library/StudyGuideView.swift                          [W04]

web/app/pricing/page.tsx                                          [W06]
web/app/api/stripe/checkout/route.ts                              [W06]
web/app/api/stripe/portal/route.ts                                [W06]
```

### 大改修ファイル

```
lecsy/Services/TranscriptionService.swift  [W05] 1924行 → ~400行に縮小、WhisperKit削除
lecsy/Services/RecordingService.swift       [W02,W05] Deepgram出力経路追加
lecsy/Models/Lecture.swift                  [W03] translatedSentences追加
lecsy/Info.plist                            [W05] マイク用途文言
lecsy/PrivacyInfo.xcprivacy                 [W05] DataType更新
supabase/functions/stripe-webhook/index.ts   [W06] 新Price ID対応
```

### 削除

```
lecsy/WhisperKitModels/                     [W05] フォルダごと
```

---

## 🚨 遅延時プロトコル

| 遅れる対象 | 2日以内 | 1週間以上 |
|---------|--------|---------|
| Deepgram疎通（W01-W02） | 続行 | **致命的**。Deepgram側のissueならAssemblyAIへ切替検討 |
| Bilingual UI（W03） | 続行 | 英語字幕のみでW03デモ、和訳はW04に |
| WhisperKit撤去（W05） | 続行 | フラグで新旧切替、W07までに完了すればOK |
| Stripe（W06） | 続行 | 既存Apple IAP維持してローンチ、W09にStripe切替 |
| LLC（W07） | 続行 | 6/15まで延長、営業は「Business entity in formation」で継続 |
| App Store Review（W07-W08） | 続行 | Reader App申請 or メタデータ修正で48時間以内再申請 |

---

## 📊 KPI（毎週日曜チェック）

| 指標 | W04 | W08 | W12 |
|-----|-----|-----|-----|
| Deepgram疎通 | ✅ | ✅ | ✅ |
| Bilingual字幕動作 | ✅ | ✅ | ✅ |
| Pro paying users | 0 | 1+ | 20+ |
| MRR | $0 | $20 | $500 |
| B2B パイロット校 | 0 | 0-1 | 2 |
| クラッシュ率 | - | <1% | <0.5% |
| Deepgram残高 | >$150 | >$150 | >$150 |

---

## 🔄 毎朝ルーティン

1. この EXECUTION_PLAN を開く、今週のGateを確認
2. `10_勝利のための鉄則.md` を1セクション読む
3. Slack/メール返信 15分
4. 今週の未完✅を1つ潰す

## 🔄 毎週日曜

1. 当週のGate ✅ 埋める
2. 翌週のタスクを頭に入れる
3. KPI数値記録
4. 鉄則違反がないかセルフチェック（「機能足した？」「英語ネイティブに寄った？」）

---

## 📌 本計画のバージョン管理

- このファイルを変更したら `変更履歴/重要な意思決定ログ.md` に追記
- スコープ凍結を解く場合、理由を明記してから書き換え
- W01ごとに「進捗サマリ」コメント追記（日付、状態、ブロッカー）
