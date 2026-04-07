# Lecsy 戦略レビュー — 競合分析と勝ち筋

作成: 2026-04-07
対象: Lecsy のクラウド化判断 + B2B ポジショニング
状況: 「ローカル主義 vs クラウド化」「Otter/Notta に勝てるのか」の経営判断

---

## TL;DR (1 ページ)

### 結論

1. **"プライバシー特化" は勝ち筋ではない**。Signal/Proton 型の差別化は B2C メッセや法人セキュリティでは効くが、学生向けノートでは購買要因にならない。Otter 訴訟 (2025-08) でプライバシー関心は上がったが、ユーザーは依然 Otter を使っている。
2. **しかし "Otter とクラウド機能で正面衝突" も勝てない**。Otter は 8〜9 桁の資金調達済、Notta も Youdao (NetEase) も同様。同じ土俵で戦うと負ける。
3. **本当の勝ち筋は「国際留学生向け B2B」**。市場 = ELL (English Language Learning) $10.7B → $75B (CAGR 21.5%)。米国の国際留学生 100 万人超。**B2C アプリは何個もあるが (LectMate / Transync / Soniox / JotMe)、B2B で語学学校・大学 ISSO (International Student Services Office) に売っているプレイヤーは事実上存在しない**。
4. **データ設計の答え**: フル "案 C" (テキストはクラウド、音声はローカル)。理由は競合分析から自明 — Otter / LectMate / Transync 全部クラウドで、ローカル主義のところは存在感ゼロ。
5. **ただし差別化は「学校管理画面」と「多言語要約」と「iOS ネイティブ品質」**で取る。クラウドストレージそのものでは差別化しない。

### 4 週間アクション (詳細は §7)

| 週 | やること |
|---|---|
| W1 | 録音→テキスト自動アップロード化 (`organization_id` 付き、音声は上げない) |
| W2 | 学校管理画面に「全文検索」「学生別アクティビティ」を追加 |
| W3 | 米国 4 校の ISSO / ESL ディレクターにコールドアウトリーチ (パイロット無償提案) |
| W4 | 多言語要約 UI を全前面に出した LP/ASO 改修 + Otter 訴訟を踏まえたプライバシーポリシー |

---

## 1. 競合マトリックス (硬数値ベース)

### 1.1 一般 AI 文字起こし市場

| プロダクト | 個人 | ビジネス | 学割 | データ | SOC2 | 国際生対応 | 主な弱点 |
|---|---|---|---|---|---|---|---|
| **Otter.ai** | $16.99/mo (年契約 $8.33) | $30/mo (年契約 $20) | 20% off (.edu) | 全クラウド | Enterprise のみ | △ (英語中心) | 85% 精度、訛り弱、**2025-08 集団訴訟** (盗聴疑い) |
| **Notta** | $13.99/mo (年契約 $8.25) | $59/mo (2 seats〜) | 50% off | 全クラウド | あり | ◎ 58 言語 | UI/UX が中華系臭く米英で弱い |
| **Fireflies** | $0 (800 min) | $19-29/seat | なし | 全クラウド | あり | △ | クレジット制で「すぐ枯れる」苦情 |
| **Granola** | — | $18/seat (推定) | なし | 全クラウド | — | △ | 会議特化、講義は不向き、**$250M valuation** |
| **Plaud (HW)** | $99/yr (1200min) | $239/yr (無制限) | なし | クラウド+デバイス | — | △ | ハードウェア $159 がハードル |
| **tldv / Read.ai / Krisp** | $0〜$25 | $20〜$30 | なし | 全クラウド | あり | △ | 全部「Zoom 会議」前提 |

### 1.2 国際留学生向け **直接競合** (これが見落とされていた)

| プロダクト | 価格 | 言語数 | フォーカス | 強み | 弱み | Lecsy が勝てる理由 |
|---|---|---|---|---|---|---|
| **LectMate (有道留学听课宝)** | ¥0.27/hr (≈$0.04/hr) VIP | 71 | 中国人留学生 (`Youdao/NetEase`) | 4.84★ / 490 reviews / 親会社 NetEase | **Chinese students only**、ブランドが完全に中国向け、米英 ESL 校にリーチ無し | 多言語/多国籍展開、B2B 売り、米国法務 |
| **Transync AI** | $8.99/mo or $7.99/10hr | 60 | 一般翻訳 (会議 + 講義) | リアルタイム 0.5s 字幕、AI 要約 | 講義特化していない、B2C のみ、ブランド弱 | 学校文脈、講義 UX (時間軸ジャンプ等) |
| **Soniox App** | $19.99/mo | 60+ | 開発者向け API + B2C | mid-sentence 言語切替 | 学生 UX が貧弱、B2C のみ | 学生フォーカス UI、要約品質、B2B |
| **JotMe** | $? | 107 | デスクトップ翻訳 + Chrome ext | 言語数 | iOS 弱、講義 UX 無し | iOS ネイティブ + 学校管理 |

**インサイト**: 国際留学生向けはすでに 4 つの競合がいる。**Lecsy = 知名度ゼロの 5 番目**。これは厳しい現実。

しかし — **どれも B2C しかやっていない**。LectMate は中国人個人、Transync は個人サブスク、Soniox は開発者 API、JotMe はリモート会議。**「米国の語学学校 / 大学 ISSO に組織契約で売る」をやっているプレイヤーが事実上ゼロ**。これが空白地帯。

### 1.3 Otter 訴訟の意味

2025-08 米北加で集団訴訟。要点:

- Otter Notetaker が会議参加者の同意なく録音
- 録音データを AI 訓練に「無期限保持」
- ECPA / CFAA / CIPA 違反
- Ohio State 等の大学が公式に「Otter 使用に注意」を発信

**示唆**: プライバシーは購買決定要因ではないが、**学校 IT/法務にとってリスクファクターになった**。これは Lecsy が「Otter は訴訟されてるけど、うちは音声を保存しません」と営業材料にできる。**訴訟そのものを売り文句にする** (Otter 名指しはしない)。

---

## 2. 市場サイズと「国際留学生」セグメント

### 2.1 マクロ

- **English Language Learning 市場**: 2025 = $10.7B → 2035 = $75B (CAGR 21.5%)
- **IELTS prep alone**: 2025 = $1.5B
- **TOEFL/IELTS 受験者**: 年間 400 万人超、APAC で 60%
- **米国留学生**: 2023-24 に **100 万人超**、ただし 2025 大学院は前年比 -10K (政治情勢)
- **デジタル化率**: ELL の 65% がモバイル、37% が AI ツール採用

→ **TAM 巨大**。仮に Lecsy が「米国の ESL 校 + 大学 ISSO」だけ取れても、対象は数千校 × 数百〜数千 seat = **理論上 $50M+ ARR が射程**。

### 2.2 米国 ESL 校 / 語学学校

- 米国の認定 ESL プログラム: **約 500〜700 校** (Intensive English Programs / IEP)
- 平均規模: 50〜500 学生
- 平均テック予算: 学生 1 人あたり年 $50〜$200
- 購買主体: ESL Director / Academic Director (≠ 大学 IT)
- 購買サイクル: **3〜6 週間** (大学全体購買の半年〜1 年より遥かに短い)
- SOC2 必須? → **No** (大学は yes、語学学校は基本 no)

→ **これが今すぐ刺さるエントリー**。SOC2 取得前でも売れる。

### 2.3 大学 ISSO (International Student Services Office)

- 米国大学約 4000 校のうち、国際生 100 人以上抱える大学 = 約 800 校
- ISSO は学生支援目的の「ソフトな」予算を持つ (≠ IT procurement)
- ISSO 経由は「大学全体ライセンス」より敷居が低い ($5-15K/年で買える)
- 購買サイクル: **6〜12 週間**

→ **中期エントリー**。SOC2 が無くても "ISSO 内部使用" として売れるケース多い。

### 2.4 B2C 補強 (国際生個人)

- ASO で「IELTS lecture」「international student note taker」狙い撃ち
- 多言語要約 (現状すでに 7 言語) は売り文句になる
- LectMate との競合は「中国人以外の留学生」を取る

---

## 3. 3 つの戦略オプション

### Play 1: Otter 正面衝突 (米英ネイティブ生向けクラウド SaaS)

**やること**: 月 $10〜15 で全機能、米国大学生 (ネイティブ) 向け、Slack 連携、Web ダッシュボード、全部入り。

**勝ち目**: 🔴 ほぼゼロ。Otter は資金 / ブランド / インテグレーション全部上。Granola ですら $250M valuation で会議市場に張り付き、講義に降りてきていない理由は「LTV が低い」から。

**結論**: ❌ やめる。

### Play 2: プライバシー特化 (Signal / Proton モデル)

**やること**: "あなたの講義は端末から出ない" を全面に。月 $5 安く設定、Aiko / Whisper オフライン押し。

**勝ち目**: 🟡 ニッチに留まる。

- Signal が WhatsApp に勝てていない事実が答え
- 学生は「便利 > プライバシー」で意思決定する
- Otter 訴訟があっても Otter MAU は減っていない
- "ローカル主義" を理由に **buy する** 学校は存在しない (理由になるのは "違反していない" であって "プライバシーが売り" ではない)

**結論**: ❌ メイン戦略にはしない。**ただしサブ価値として残す** (音声はローカル、文字だけクラウド)。

### Play 3: 国際留学生 × B2B 学校契約 ★ 推奨

**やること**:

1. **iOS ネイティブ + 多言語要約** をコア
2. **米国 ESL 校 / 大学 ISSO に組織契約** で売る (B2C は補助線)
3. **学校管理画面** = 「うちの留学生が今週どれだけ授業についていけているか」のダッシュボード
4. **音声はローカル、文字は組織クラウド** ハイブリッド (Otter 訴訟回避 + 機能性両立)
5. **価格**: ESL 校 = $5/seat/month (年契約)、大学 ISSO = $10/seat/month、最小 50 seats

**勝ち目**: 🟢 高い。理由:

- B2B の同セグメントに競合が事実上いない (LectMate ですら個人売り)
- ESL 校購買サイクルが短い (3-6 週)
- SOC2 不要でスタート可能
- 既存 B2C アプリで実績 = ASO 経由で先生に発見されている可能性
- 個人開発者の OPT 期間でも回せる規模感
- LectMate (中国人) との棲み分けが自然 = "non-Chinese international students"

**結論**: ✅ **これで行く**。

---

## 4. データ設計の最終回答

| 項目 | 保存場所 | 理由 |
|---|---|---|
| 音声ファイル (.m4a) | **端末ローカルのみ** | Otter 訴訟回避、ストレージコスト圧縮、肖像権/声の権利議論を回避、教授の許可問題を学生個人責任に転嫁可能 |
| 文字起こしテキスト | **Supabase** (組織所属者は `organization_id` 付き) | 学校管理画面成立、端末紛失時のデータロスト回避、検索可能、要約再生成可能 |
| 要約 (summary / exam) | **Supabase** | 既存通り |
| メタデータ (タイトル、時間、長さ、言語) | **Supabase** | 学校管理画面成立 |
| 学生のオプトアウト | あり (個別講義単位 + アカウント全体) | プライバシー懸念学生を取りこぼさない、訴訟リスク低減 |

これが「**音声は出ない、テキストは出る、ユーザーが切れる**」モデル。

### 設計原則

1. **デフォルト ON でクラウド同期** (デフォルト OFF だと誰もオンにしない)
2. 組織所属者は `visibility=org_wide` がデフォルト、個人は `private` がデフォルト
3. 「組織に共有しない」トグルは 1 タップで切替可能
4. プライバシーポリシーに **明示**: 「文字起こしテキストは Lecsy サーバーに保存されます。音声ファイルは端末から送信されません。」
5. アカウント削除時に Supabase 側のテキストも 30 日以内に削除 (既存 `delete-account` Edge Function を拡張)

### 既存コードからの差分

- `lecsy/Services/RecordingService.swift` — 文字起こし完了時に `save-transcript` Edge Function を自動呼び出し (現状は要約押した時だけ)
- `lecsy/Services/OrganizationContext.swift` — 既にある。`activeOrganization` を `save-transcript` payload に渡す
- `supabase/functions/save-transcript/index.ts` — `organization_id` / `visibility` パラメータを受ける
- `web/app/org/[slug]/page.tsx` — 全文検索 UI 追加 (Postgres `tsvector` で十分、Algolia 不要)
- `lecsy/Views/Settings/PrivacySettingsView.swift` (新規) — クラウド同期 ON/OFF + 「過去全て削除」ボタン

工数: **5〜8 日**。

---

## 5. プロダクト差別化 (なぜ Lecsy を買うか)

学校が Otter ではなく Lecsy を選ぶ理由は 5 つ。**全部すでに優位を持っているか、4 週間で取れる**:

| # | 差別化 | 現状 | 4 週で完成? |
|---|---|---|---|
| 1 | **iOS ネイティブの録音品質** | ✅ Whisper オンデバイス、Tier 1 高速化済 | ✅ 完了 |
| 2 | **多言語要約 (7 言語)** | ✅ ja/en/es/zh/ko/fr/de | ✅ 完了 |
| 3 | **音声を保存しないプライバシー** | ✅ 設計通り | ✅ ポリシー文言だけ |
| 4 | **学校管理画面 (誰が何を撮ったか + 検索)** | ⚠️ 半分 | ✅ W2 で完了 |
| 5 | **国際留学生 UI/UX** (英語+母語の bilingual notes) | ❌ まだない | ✅ W3 で MVP |

**Otter にはどれもない**。LectMate には #2 しかない (中国語のみ)。Transync には #1, #4, #5 がない。

→ **「iOS ネイティブで多言語要約ができ、音声を保存せず、学校が管理できる、国際留学生向け唯一のソリューション」**がポジショニング文。

---

## 6. 価格設計

### 案 A (推奨)

| プラン | 価格 | 対象 |
|---|---|---|
| Free | 月 5 講義要約まで | B2C 試用 |
| Pro (個人) | $7.99/mo or $59/yr | B2C メイン (Otter $16.99 の半額) |
| Pro (.edu 個人) | $4.99/mo or $39/yr | 学生個人 |
| **ESL School** | **$5/seat/month, min 50 seats, 年契約 = $3,000/年〜** | 語学学校 |
| **University ISSO** | **$10/seat/month, min 100 seats, 年契約 = $12,000/年〜** | 大学 ISSO |
| Enterprise | カスタム + SOC2 後 | 大学全学契約 |

ESL 校 50 seats 売れれば年 $3K、10 校で $30K = OPT 期間中の現実的目標。

### Stripe 設定変更

- `STRIPE_PRICE_ESL_SCHOOL_MONTHLY/YEARLY`
- `STRIPE_PRICE_UNIVERSITY_ISSO_MONTHLY/YEARLY`
- `metadata.org_type = 'esl_school' | 'university_isso'`

既存 `stripe-webhook` の B2B 分岐を流用可能。

---

## 7. 4 週間アクションプラン (具体)

### Week 1 (4/7-4/13): データアーキテクチャを Play 3 に倒す

- [ ] `RecordingService.swift` — 文字起こし完了で `save-transcript` 自動呼び出し
- [ ] `save-transcript/index.ts` — `organization_id` / `visibility` 受け取り
- [ ] `OrganizationContext` — `activeOrganization` を `RecorderViewModel` に注入
- [ ] `PrivacySettingsView` 新規 + 「クラウド同期 ON/OFF」トグル
- [ ] プライバシーポリシー更新 + App Store 説明文修正
- [ ] 既存 transcripts に `organization_id` を後埋めするマイグレーション (NULL 許容)

**Done = 「録音 → 自動でテキストが学校管理画面に出る」が動く**。

### Week 2 (4/14-4/20): 学校管理画面を "売れる" 状態にする

- [ ] `/org/[slug]` トップ — 「今週のアクティビティ」ダッシュボード (学生別、講義数、要約数)
- [ ] `/org/[slug]/transcripts` — 全文検索 (Postgres `tsvector`)
- [ ] `/org/[slug]/students/[id]` — 個別学生の活動詳細
- [ ] CSV エクスポート (週次レポート用)
- [ ] スクリーンショット 5 枚を Notion / pitch deck 用に撮る

**Done = ESL Director にデモ見せられる**。

### Week 3 (4/21-4/27): 営業 + bilingual notes MVP

- [ ] 米国 ESL 校トップ 50 のリストを `B2B/03_PROSPECT_LIST.md` から再選定
- [ ] 4 校の Academic Director にコールドメール (Loom デモ動画 + パイロット 1 ヶ月無償)
- [ ] iOS — 要約画面に「英語 + 母語並列表示」モード追加 (既存 multi-language summary を 2 並べるだけ)
- [ ] LP に「For International Students」セクション追加

**Done = 商談 1 件以上 + bilingual notes リリース**。

### Week 4 (4/28-5/4): 反応を見て倒す方向を決める

- [ ] W3 の商談結果を踏まえて価格 / 機能を調整
- [ ] パイロット契約 1 件以上クローズ
- [ ] App Store ASO を「international student lecture notes multilingual」最適化
- [ ] 次の 4 週の優先順位を決め直す (この時点で必ず再評価)

**Done = 有償 LOI 1 件 or 無償パイロット 2 件**。

---

## 8. 監視すべきリスク (top 5)

| # | リスク | 早期警戒シグナル | 対処 |
|---|---|---|---|
| 1 | **LectMate / Notta が B2B 学校売りを始める** | LinkedIn で営業 hire / 学校事例ブログ | スピード勝負、米国セグメントを早く取る |
| 2 | **Otter 訴訟で全 AI トランスクリプト規制が来る** | FTC 動向、CIPA 解釈拡大 | 音声非保存ポジションを早く確立、訴訟リスクを Otter に押し付ける |
| 3 | **米国の留学生数減 (政治情勢)** | OPT/STEM extension 改訂、ビザ統計 | 英国/カナダ/豪州語学学校に展開 |
| 4 | **OpenAI コスト爆発** | `org_ai_usage_logs` 月次グラフ | 組織月次上限 (H3) を必ず先に enforce |
| 5 | **個人開発者の限界** (営業 + 開発両立) | 商談取れたのにコード追いつかない | 月 1 商談取れた段階で契約デザイナー or contracted dev 検討 |

---

## 9. なぜ前回の "プライバシー特化案 A" を撤回するか — 自分の判断ミスの記録

前回 (この会話の 3 ターン前) 俺は「案 A (ローカル主義維持) でいくべき」と書いた。これは**間違いだった**。理由:

1. **個人開発者の法務コストを過大評価していた** — 実際は Supabase デフォルト暗号化 + 既存 `legal/` 雛形でほぼ足りる。半年溶けない、1〜2 週で済む。
2. **"プライバシー = 売れる" は B2C メッセでは効くが学生ノートでは効かない** — Signal が WhatsApp に勝てていない事実が答えだった。
3. **学校管理画面が成立しない設計を選んだら B2B が消える** — Lecsy の 10 倍成長は B2B でしか取れない (B2C 単体で 10K DL は届くが、ARR 100M は届かない)。
4. **データロストで学生が解約する事実を無視していた** — 期末前に iPhone 壊れたら 1 学期分消える設計は、学生が一番嫌うパターン。
5. **競合分析をせずに判断していた** — 今回ちゃんと調べたら、ローカル主義のプロダクト (Aiko, On Device AI など) は全部ニッチで終わっている。

ユーザーの「Otter とかノッタに勝てるわけなくね」は **正しい疑問**だった。あれが無かったらこの戦略レビューは生まれていない。

---

## 10. ソース

### Otter
- [Otter.ai Pricing 2026](https://www.claap.io/blog/otter-pricing)
- [Otter Student Discount](https://www.studentbeans.com/student-discount/us/otter-ai)
- [Otter.ai Class Action Lawsuit, NPR](https://www.npr.org/2025/08/15/g-s1-83087/otter-ai-transcription-class-action-lawsuit)
- [Ohio State IT Office on Otter Privacy](https://it.osu.edu/news/2025/08/22/otterai-and-your-privacy)
- [Workplace Privacy Report on Otter Suit](https://www.workplaceprivacyreport.com/2025/08/articles/artificial-intelligence/ai-notetaking-tools-under-fire-lessons-from-the-otter-ai-class-action-complaint/)

### Notta / Fireflies / Plaud / Granola
- [Notta Pricing](https://www.notta.ai/en/pricing)
- [Notta Education Discount](https://support.notta.ai/hc/en-us/articles/17418832708251)
- [Plaud NotePin Review, tldv](https://tldv.io/blog/plaud-notepin-review/)
- [Plaud TechCrunch 2026-01](https://techcrunch.com/2026/01/04/plaud-launches-a-new-ai-pin-and-a-desktop-meeting-notetaker/)

### 国際留学生向け直接競合
- [LectMate (有道留学听课宝) App Store](https://apps.apple.com/us/app/lectmate-%E6%9C%89%E9%81%93%E7%95%99%E5%AD%A6%E5%90%AC%E8%AF%BE%E5%AE%9D/id6459829488)
- [Transync AI Pricing](https://www.transyncai.com/pricing/)
- [Soniox Lecture App](https://soniox.com/soniox-app/use-cases/lecture-transcription)
- [JotMe Live Translator](https://www.jotme.io/)

### 市場サイズ
- [English Language Learning Market $10.7B → $75B](https://www.globalgrowthinsights.com/market-reports/english-language-learning-market-102194)
- [IELTS Learning Platform $1.5B by 2025](https://www.htfmarketintelligence.com/report/global-online-academic-ielts-learning-platform-market)
- [International Enrollment Higher Ed Dive](https://www.highereddive.com/news/international-enrollment-under-pressure-what-colleges-can-do/812258/)
- [International Student Challenges, FAU](https://www.fau.edu/thrive/students/thrive-thursdays/internationalstudentexperience/)

### EdTech コンプライアンス
- [FERPA / SOC2 for EdTech, Hireplicity](https://www.hireplicity.com/blog/ferpa-coppa-soc2-edtech-compliance-guide)
- [SOC2 for Education, PoliWriter](https://poliwriter.com/for/soc2-for-education)

### プライバシー特化プロダクト
- [Aiko (Sindre Sorhus)](https://sindresorhus.com/aiko)
- [Google AI Edge Eloquent (offline)](https://news.quantosei.com/2026/04/07/google-quietly-launched-an-ai-dictation-app-that-works-offline/)
