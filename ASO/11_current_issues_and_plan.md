# 11. 現状の問題棚卸し & 今後のプラン

日付:2026-04-08
方針:B2B 棚上げ、**B2C 完全無料(〜6/1 まで広告なし・課金なし)**で 12 週 10,000 DL を狙う
更新:**広告 SDK 導入は中止**。6/1 まで純粋な無料運用。それ以降の収益化は別途判断。

---

## TL;DR(結論)

### ✅ 2026-04-08 一括修正済み
1. ~~広告クレームと SDK の矛盾~~ → **広告を完全削除**、"Free Until June 1" 訴求に統一
2. ~~"Upgrade to Pro $2.99/mo" ゾンビ UI~~ → **Web 全コンポーネント撤去**
3. ~~PrivacyInfo.xcprivacy 宣言不足~~ → **正しく書き直し**(AudioData削除、Email/UserID/UserContent/Diagnostics 追加)
4. ~~B2B(組織)タブ iOS に露出~~ → **`kB2BEnabled = false` で非表示**(コードは残置、LLC後に戻せる)
5. ~~PRIVACY_POLICY.md に OpenAI 送信記述なし~~ → **追記済み**

### 🟧 残課題(提出前に必須)
- [ ] **WhisperKit ベース英語モデル(~150MB)を IPA に事前同梱** — 初回 DL 体験の最大の敵
- [ ] **スクショ10枚 + App Preview 動画** を `ASO/05` 準拠で制作(最重要スロット:「Free Until June 1」)
- [ ] **App Store Connect メタデータ入力**(`ASO/04` からコピペ)
- [ ] **en-GB / en-AU ロケール追加**(en-US コピペで即追加)
- [ ] **TestFlight で完全フロー確認**:新規アカウント作成 → 録音 → 文字起こし → 要約 → 試験モード
- [ ] **Supabase Edge Function デプロイ**:`supabase functions deploy summarize`
- [ ] **Cloud Sync OFF トグルの動作確認**(Settings → Privacy)
- [ ] **OpenAI コスト試算**:DAU 100 の場合 / 1000 の場合 / 10000 の場合 の月額を概算し、6/1 までの持ち出し予算を確定

---

## 🔴 Phase 0:提出ブロッカー(ほぼ完了)

### P0-1. ✅ 広告クレーム削除(方針確定:6/1まで広告なし)
**確定方針**:6/1 まで広告 SDK は導入しない。純粋な完全無料運用。
- [x] `ASO/04_metadata_master.md` から広告記述を全削除 ✅
- [x] "Free Until June 1 — No Ads, No Subscription" をサブタイトルに昇格 ✅
- [x] `01_current_state.md` / `05_screenshots_creative.md` / `08_launch_growth_playbook.md` を広告なし前提に更新 ✅
- [ ] 6/1 直前(5月中旬)に再判断:継続無料 / 広告導入 / Pro 導入(LLC 次第)
- [ ] それまでの OpenAI 代は個人の持ち出し。フェアリミット(日次20/月400)で上限キャップ済

### P0-2. ✅ ゾンビ "Upgrade to Pro" UI の除去 完了
全部修正済(2026-04-08):
- [x] `web/components/UpgradeButton.tsx` → `return null` の no-op 化
- [x] `web/components/ProCardUpgradeButton.tsx` → "Get Started — 100% Free" / "Open Your Library" に
- [x] `web/components/ProFeatureButton.tsx` → `!isPro` ブロック削除
- [x] `web/components/SubscriptionCard.tsx` → "Free — Everything Unlocked / Free for every user until June 1, 2026" カードに
- [x] `web/components/AISummaryButton.tsx` → `!isPro` ブロック削除、isPro prop は互換のため残置
- [x] `web/components/ExamModeButton.tsx` → 同上
- [x] `web/app/page.tsx` FAQ を「100% 無料」に書き換え
- [x] `web/app/otter-alternative-for-lectures/page.tsx` / `ai-note-taking-for-international-students/page.tsx` / `ai-transcription-for-students/page.tsx` の `$2.99` / `Pro features` を全削除
- [ ] **残**:Stripe / org-checkout Edge Function は無効化したがデプロイ外しは未対応(害無し、後回しでOK)

### P0-3. ✅ PrivacyInfo.xcprivacy 修正完了
`lecsy/PrivacyInfo.xcprivacy` を実装に即して書き直し:
- [x] **AudioData 宣言を削除**(実際に送っていない = 過剰宣言もNG)
- [x] Email / Name / UserID / OtherUserContent / ProductInteraction / CrashData / PerformanceData を宣言
- [x] 全て `Tracking = false`
- [x] IDFA 宣言なし(広告SDK 未導入のため)
- [x] `NSPrivacyTracking = false` 維持

### P0-4. ✅ iOS から B2B(Organization)UI を隠す 完了
- [x] `lecsy/ContentView.swift` に `private let kB2BEnabled = false` を追加
- [x] Org タブ表示条件を `showOrgTab = kB2BEnabled && orgService.isInOrganization` に変更
- [x] Joined toast も同フラグでガード
- [x] コード本体は残置 → LLC 設立後は `kB2BEnabled = true` に戻すだけで復活
- [ ] **残**:organization-invite ディープリンクを黙って無視する処理(優先度低、レビュー通過後で OK)

### P0-5. デプロイ & 動作確認
- [ ] `supabase functions deploy summarize`(前回修正したやつ)
- [ ] 新規アカウント作成 → 録音 → AI要約が iOS/Web 両方で動く
- [ ] Cloud Sync OFF トグルが Settings → Privacy に見えることを確認(コードには存在済:`SettingsView.swift:160-163`)
- [ ] `PRIVACY_POLICY.md` に「AI要約時は transcript テキストが OpenAI GPT-4o-mini に送信される」を追記

---

## 🟧 Phase 1:差別化の強化(Week 2-3)

### P1-1. WhisperKit モデルの事前同梱
**問題**:多言語モデル 460MB、ベースでも 150MB の初回 DL。
ネット遅いと離脱。留学生向けのアプリでこれは致命的。

- [ ] **英語ベースモデル(~150MB)を IPA に同梱**(Xcode Copy Bundle Resources)
- [ ] 多言語モデルは初回録音後のオプションDL継続で OK
- [ ] 「モデル DL 中...」画面に進捗バーと時間目安
- [ ] オフライン時に DL 失敗した場合のフォールバック表示

### P1-2. AI 要約の利用状況表示
**問題**:1日20件 / 月400件の制限があるのに UI に残数表示なし → 18件目で突然失敗で★1。

- [ ] ライブラリ画面に "Today: 3/20 summaries" を表示
- [ ] 制限近付いた時(18/20)に黄色警告
- [ ] `usage_logs` を Swift から read する API or Supabase 直読

### P1-3. オンボーディング最適化
**現状**:既にサインイン必須ではない(`OnboardingView.swift`)→ ✅ 良い
**追加**:
- [ ] 初回起動時に「まず1件録音してみる」CTA を誘導
- [ ] 初回録音完了時に ATT ダイアログ(広告導入と連動)
- [ ] 要約を試すタイミングで「サインインで AI要約が使える」の緩い誘導(強制しない)

### P1-4. 不要 Edge Function の整理
B2B 棚上げで不要になった Edge Functions:
- `org-checkout` — 削除 or アーカイブ
- `stripe-webhook` — 無効化(関数は残して内部で 503)
- `org-create` / `org-csv-import` / `org-grant-ownership` / `org-ai-assist` / `send-org-invite` — 未デプロイ化
- `save-transcript` の `organization_id` / `visibility` / `class_id` フィールドは受け取るが無視する状態にする(iOS 側は送らなくなるが、後方互換)

削除ではなくデプロイ外すだけ。LLC後に復活可能。

---

## 🟧 Phase 2:提出 & ローンチ(Week 3-4)

### P2-1. App Store Connect 準備
- [ ] `ASO/04_metadata_master.md` の JP/EN をコピペ入力
- [ ] en-GB / en-AU ロケール追加(コピペ)
- [ ] カテゴリ Education (Primary) / Productivity (Secondary)
- [ ] 年齢 4+
- [ ] App Privacy 栄養ラベル:`ASO/10_data_flow_truth.md` 通りに宣言
- [ ] Promotional Text に「完全無料キャンペーン」文言

### P2-2. クリエイティブ(提出ブロッカー)
- [ ] スクショ 10 枚作成(`ASO/05_screenshots_creative.md` 準拠)
- [ ] **枚2「AI要約まで全部無料」**(最重要スロット)
- [ ] **枚3「音声は iPhone から出ません」**(事実ベース差別化)
- [ ] App Preview 動画 15-30秒
- [ ] App Icon を最終化(現状確認必要)

### P2-3. TestFlight で最終検証
- [ ] 新規 Apple ID で DL → オンボーディング → 録音 → 文字起こし → 要約 → 広告表示の完全フロー
- [ ] レート制限に達するまで要約を連打してエラー UX 確認
- [ ] 機内モードで録音・文字起こしが動くこと確認
- [ ] サインアウト状態で録音ができることを確認

### P2-4. 提出
- [ ] App Review Information 入力(demo account、reviewer 向け注記)
- [ ] 提出 → 通過したら Phase 3 へ

---

## 🟦 Phase 3:500→10K DL 成長ループ(Week 5-12)

`ASO/08_launch_growth_playbook.md` に詳細あり。ここでは優先順位だけ再掲:

### Week 5-6:指名検索の刈取り
- [ ] ブログ3本投入:
  - "Otter.ai Alternatives — The Free AI Summary One (2026)"
  - "Free Offline Lecture Recorder Comparison"
  - "100% Free Transcription App for International Students"
- [ ] Reddit /r/GetStudying, /r/InternationalStudents, /r/StudyTips に投稿
- [ ] Product Hunt ローンチ(水曜 朝6時 PST)
- [ ] Hacker News Show HN

### Week 7-8:ショート動画爆発点
- [ ] TikTok / YouTube Shorts 10本(留学生向けハック形式)
- [ ] 留学生系インフルエンサー5人にギフト(といっても無料だから「紹介して」だけ)
- [ ] X で "otter alternative" 検索リプライ営業

### Week 9-10:ロケール展開
- [ ] 韓国語 / スペイン語(メキシコ)/ 簡体中文 ロケール追加
- [ ] 各ロケールの Keywords / Subtitle / スクショ文言(構図は共通)

### Week 11-12:最終加速
- [ ] Apple "Today" エディトリアル申請
- [ ] 学生アンバサダー制度(無料なのでインセンティブは知名度だけ)
- [ ] 平均★4.5 維持 + 100レビュー突破確認

### 途中の判断ゲート
| 週 | Go 判定 | 未達時 |
|---|---|---|
| Week 4 | 審査通過 | 差戻し対応 |
| Week 6 | DL 1000、CVR 5% | スクショ差替 |
| Week 8 | DL 3000、★4.5 | 動画戦略転換 |
| Week 10 | DL 6000 | ロケール追加前倒し |
| Week 12 | **DL 10000** | フェーズ延長 |

---

## 🟪 Phase 4:LLC 設立と Pro 導入(2026 Q3 想定)

B2C 10K DL を達成したら、**それを信用装置として** LLC 設立 + Pro 導入。
- [ ] LLC 設立(Delaware / Wyoming)
- [ ] Apple Developer Organization に移行
- [ ] Stripe / Apple IAP セットアップ
- [ ] Pro 価値提案確定(案 A-D は `ASO/04` 末尾)
- [ ] `web/utils/isPro.ts` を元ロジックに戻す(git revert 1 コマンド)
- [ ] `summarize/index.ts` にレート制限の差別化(無料は 5/day、Pro は 100/day 等)
- [ ] ASO メタデータを Pro 訴求に書き換え
- [ ] B2B 復活:`#if B2B_ENABLED` を再度有効化、語学学校アプローチ再開

---

## 付録 A:ファイル別変更サマリ(P0 だけ)

| ファイル | 変更 |
|---|---|
| `lecsy/Info.plist` | GADApplicationIdentifier / SKAdNetworkItems / NSUserTrackingUsageDescription 追加 |
| `lecsy/PrivacyInfo.xcprivacy` | AudioData 削除、Email/UserID/OtherUserContent/IDFA 追加 |
| `lecsy/lecsyApp.swift` | AdMob 初期化 |
| `lecsy/Services/AdService.swift`(新規) | インタースティシャル管理 |
| `lecsy/Views/Library/LectureDetailView.swift` | AI要約完了後に広告表示フック |
| `lecsy/ContentView.swift` | Organization タブを `#if B2B_ENABLED` で囲む |
| `lecsy/Views/Organization/*` | 同上 |
| `web/components/UpgradeButton.tsx` | 削除 or 非表示化 |
| `web/components/AISummaryButton.tsx` | `if (!isPro)` ブロック削除 |
| `web/components/ExamModeButton.tsx` | 同上 |
| `web/components/SubscriptionCard.tsx` | "Pro" バッジ → "All features free" |
| `web/app/app/page.tsx` | `/app#subscription` 導線削除 |
| `PRIVACY_POLICY.md` | OpenAI 転写テキスト送信を追記 |

---

## 付録 B:やらないこと(明示的に捨てる)

B2C 集中のために**今はやらない**:
- ❌ B2B 営業(LLC 必要、現状追えない)
- ❌ Stripe 個人サブスク(LLC 必要)
- ❌ 有料広告配信(ASA 含む)— CVR 6%超えるまでは溶かすだけ
- ❌ Android 版 — iOS で 10K 達成してから
- ❌ Apple Watch / Mac Catalyst 対応 — コア検証が先
- ❌ 追加言語(ヒンディー / アラビア / ロシア) — Tier 1 終わってから
- ❌ Firebase / Amplitude 導入 — Supabase usage_logs で十分な間は

---

## 付録 C:日次ダッシュボード(Phase 3 以降)

毎朝 10 分でチェック:
1. App Store Connect → Analytics → Impressions / Product Page Views / Units / CVR
2. App Store Connect → Search Terms の新規上位3語
3. Supabase → transcripts テーブルの日次新規行数(=アクティブ度)
4. Supabase → usage_logs の summarize 件数(= AI 使用率)
5. 平均★(週次でOK)

数字が動かなくなったら ASO テスト(Product Page Optimization)を1枠回す。
