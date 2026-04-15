# lecsy 2.0 本番化 完全要件定義書（Deepgram + 留学生特化）

作成日: 2026-04-14
最終更新: 2026-04-14（留学生特化ピボット + 5キラー機能 + Stripe一本化 を統合）
対象: lecsy iOS / Web / Supabase アプリの 2026-06-01 本番ローンチ
採用エンジン: Deepgram Nova-3 streaming (WebSocket) + Prerecorded HTTPS
AI生成: GPT-4o Mini（翻訳・Study Guide・Vocabulary・Quiz）
決済: Stripe 一本（Apple IAP 廃止）
フォールバック: WhisperKit（端末内オフライン・FERPA strict時のみ安全網）

---

## 0. ビジョン・一行サマリ

> **"Your semester-long AI companion for English lectures."**
> lecsy は、米国大学に通う英語非ネイティブ留学生（80万人市場）が、英語講義を学期まるごと攻略する唯一の iOS 学期OS。

本書は、このビジョンを **2026-06-01 ローンチで実現する完全要件**を定義する。現状のDeepgram基盤（実装済）+ 新戦略（5キラー機能 + 留学生特化 + Stripe一本化）の統合版。

### 戦略コア（`Deepgram/01_ビジョンと勝ち筋.md` 詳細）
- **ターゲット**: 米国大学の英語非ネイティブ留学生
- **展開**: B2C個人 → 大学ISSS B2B → Enterprise の3段階
- **言語優先**: 日本語→韓国語→中国語→ベトナム→スペイン/ポルトガル
- **5キラー機能**: Bilingual Captions / Course Hierarchy / AI Study Guide / Vocabulary Intelligence / Exam Prep Plan
- **価格**: Free / Pro $12.99 / Student $6.99 / ISSS $499-2,499/月 / Enterprise $25-75K/年

---

## 1. アーキテクチャと採用済みコンポーネント

### iOS（既実装・本番級）
| コンポーネント | 役割 | ファイル |
|---|---|---|
| `DeepgramLiveService` | WS接続 / 音声変換 / セグメント管理 / 再接続 / 割込復帰 / 使用量報告 | `lecsy/Services/DeepgramLiveService.swift` |
| `DeepgramTokenProvider` | Edge Function 経由短寿命トークン取得 | `lecsy/Services/DeepgramTokenProvider.swift` |
| `DeepgramUsageReporter` | セッション終了時の利用分数 POST | 同上 |
| `TranscriptionCoordinator` | ネットワーク状態 / FERPA / フラグで Deepgram ↔ WhisperKit 選択 | `lecsy/Services/TranscriptionCoordinator.swift` |
| `RecordingLiveCaptionPanel` / `LiveCaptionView` | 録音中UI（接続状態、interim/final） | `lecsy/Views/Components/` |
| `DeepgramMessage` / `LiveCaptionSegment` | ドメインモデル | `lecsy/Models/` |

### iOS（新規実装）
| コンポーネント | 役割 | 見積 |
|---|---|---|
| `BilingualCaptionView` | 英+母語並列字幕UI（左右分割、同期スクロール） | 3d |
| `TranslationStreamClient` | GPT-4o Mini翻訳SSE受信 | 1d |
| `CoursesView` / `CourseHierarchyNavigator` | 学期→コース→週→回の階層UI | 2d |
| `StudyGuideView` | AI生成サマリ・Quiz表示 | 2d |
| `VocabularyView` / `AnkiExporter` | 専門用語抽出表示 + .apkg生成 | 2d |
| `ExamPlanView` | 試験カウントダウン学習計画UI（Phase 2） | 3d |
| `StripePortalLink` | Web課金導線（iOS内決済UIゼロ） | 0.5d |

### Supabase（既実装・本番級）
| Edge Function | 役割 | 状態 |
|---|---|---|
| `deepgram-token` | 認証 → feature flag → 残高 → 日次上限 → 短寿命キー発行 | ✅ |
| `deepgram-balance-check` | 日次cron、$150/$100閾値でアラート・自動OFF | ✅ |
| `deepgram-usage-add` | 利用分数を原子的に加算 | ✅ |

### Supabase（新規実装）
| Edge Function | 役割 | 見積 |
|---|---|---|
| `translate-realtime` | GPT-4o Mini streaming翻訳 | 2d |
| `generate-study-guide` | Quick/Standard/Deep の3モード生成 | 3d |
| `extract-vocabulary` | 専門用語抽出 + embedding + pgvector類似検索 | 2d |
| `parse-syllabus` | シラバスPDF→コース階層JSON（Phase 2） | 2d |
| `exam-plan-generator` | 試験学習計画自動生成（Phase 2） | 2d |
| `semantic-search` | 講義横断のpgvectorベース検索 | 1d |
| `stripe-webhook` | `customer.subscription.*`, `invoice.*` → `profiles.plan` 更新 | 2d |
| `create-checkout-session` | Stripe Checkout Session発行 | 0.5d |
| `create-portal-session` | Stripe Customer Portal URL発行 | 0.5d |
| `verify-edu-domain` | .edu/.ac.*/等 教育ドメイン認証 | 0.5d |

### Supabase Tables（既実装）
- `user_daily_realtime_usage` — PK (user_id, usage_date), RLS有
- `feature_flags` — `realtime_captions_beta`, `bilingual_captions_enabled`等
- RPC `increment_realtime_usage` — service_role only

### Supabase Tables（新規実装）
```sql
-- Course Hierarchy（4階層）
create table public.semesters (
  id uuid primary key, user_id uuid, name text, start_date date, end_date date
);
create table public.courses (
  id uuid primary key, semester_id uuid, user_id uuid,
  code text, title text, instructor text,
  syllabus_pdf_url text, syllabus_parsed jsonb,
  meeting_days text[], meeting_time text,
  midterm_dates date[], final_exam_date date,
  color text, organization_id uuid
);
create table public.weeks (
  id uuid primary key, course_id uuid, week_number int,
  start_date date, topic text, learning_goals text[],
  assignments jsonb
);
create table public.lectures (
  id uuid primary key, week_id uuid, course_id uuid,
  user_id uuid, transcript_id uuid,
  title text, recorded_at timestamptz, duration_sec int,
  auto_linked boolean default false
);

-- Transcript（word-level JSONB + pgvector）
alter table public.transcripts
  add column words jsonb,
  add column translated_sentences jsonb,
  add column embedding vector(1536),
  add column language text,
  add column origin text default 'cloud';

-- Study Guide
create table public.study_guides (
  id uuid primary key, lecture_id uuid, user_id uuid,
  depth text, -- 'quick' | 'standard' | 'deep'
  content jsonb, native_language text,
  generated_at timestamptz default now()
);

-- Vocabulary
create table public.personal_vocabulary (
  id uuid primary key, user_id uuid,
  term text, definition_en text, definition_native text,
  cefr_level text, domain text,
  embedding vector(1536),
  first_encountered_lecture_id uuid,
  encounter_count int default 1,
  next_review_at timestamptz,
  mastered boolean default false
);
create index on public.personal_vocabulary using ivfflat (embedding vector_cosine_ops);

-- Exam Plan（Phase 2）
create table public.study_plans (
  id uuid primary key, user_id uuid, course_id uuid,
  exam_date date, daily_tasks jsonb,
  created_at timestamptz default now()
);

-- Monthly usage（Gap 3）
create table public.user_monthly_realtime_usage (
  user_id uuid, year_month text, minutes_total numeric(10,2) default 0,
  primary key (user_id, year_month)
);
create table public.org_monthly_realtime_usage (
  organization_id uuid, year_month text, minutes_total numeric(10,2) default 0,
  primary key (organization_id, year_month)
);

-- Stripe
alter table public.profiles
  add column plan text default 'free',       -- 'free'|'pro'|'student'|'business'
  add column stripe_customer_id text,
  add column subscription_id text,
  add column plan_expires_at timestamptz,
  add column edu_domain_verified boolean default false;

-- Observability（Gap 9）
create table public.deepgram_token_metrics_daily (
  date date, total int, success int,
  unauthorized int, budget_exceeded int, daily_cap int,
  feature_disabled int, server_error int,
  primary key (date)
);
```

---

## 2. 機能要件（FR）

### FR-1 開始フロー（既存、維持）
1. ユーザー録音開始 → `TranscriptionCoordinator.chooseMode()` が以下を満たすなら Deepgram:
   - `liveCaptionsEnabled=true`
   - `ferpaStrictMode=false`
   - `NWPathMonitor` オンライン
   - `DEEPGRAM_TOKEN_ENDPOINT` 設定済
   - Supabase有効セッション
2. 上記1つでも欠ける → WhisperKit（オフライン安全網として維持）
3. Deepgram選択時、短寿命トークン取得 → WSS接続

### FR-2 ストリーミング仕様
既存（セクション2のdoc参照）に加え、**language動的選択（Gap #1）**:
```
?model=nova-3
&language={ja|en|multi}  ← ユーザー言語 / 録音言語に応じて
&encoding=linear16&sample_rate=16000&channels=1
&interim_results=true&smart_format=true&punctuate=true
&diarize=false&endpointing=300&utterance_end_ms=1000
&vad_events=true&filler_words=false
```

### FR-3 **NEW: Bilingual Captions（キラー機能①）**
- Deepgram Streaming で英語原文取得
- 各 final センテンスを `translate-realtime` Edge Function に投げる
- GPT-4o Mini で母語訳をSSEストリーム
- iOS `BilingualCaptionView` で左右並列表示
- 遅延目標: 英語 <500ms + 翻訳追加 <500ms（合計 <1000ms）
- UI: HStack、同期スクロール、タップ単語→母語定義ポップアップ
- Free プラン: 無効（Prerecordedのみ、Proへの転換フック）

### FR-4 **NEW: Course Hierarchy（キラー機能②）**
- 学期 → コース → 週 → 回の4階層
- 初期は手動入力（6/1）、シラバスPDF自動解析は Phase 2（Gap #20）
- 録音保存時に `week_id` / `course_id` 自動紐付け（ユーザー選択）
- Canvas LTI 1.3 は Phase 3（2027 Q2以降）

### FR-5 **NEW: AI Study Guide（キラー機能③）**
- 講義終了後、`generate-study-guide` Edge Function 呼び出し
- 3階層の深度:
  - **Quick** (5秒): 3行サマリ + 5キーターム + 母語訳
  - **Standard** (15秒): 完全要約 + 概念マップ + Q&A 10問
  - **Deep** (45秒): 練習問題20 + Flash Card 50 + 弱点分析
- GPT-4o Mini streaming でプログレッシブ表示
- Free: Quick 3回/月、Pro: 全モード無制限

### FR-6 **NEW: Vocabulary Intelligence（キラー機能④）**
- Transcript保存時、`extract-vocabulary` で専門用語抽出
- 各用語を text-embedding-3-small でembedding化
- pgvector で過去辞書との類似検索、既出/新規判定
- CEFR レベル + 母語訳 + 例文 + 発音
- Anki .apkg export（1タップ）
- アプリ内 Spaced Repetition（SM-2アルゴリズム）

### FR-7 **NEW: Exam Prep Plan（キラー機能⑤、Phase 2）**
- 試験日入力 → `exam-plan-generator` 呼び出し
- 2週間のDaily Task自動生成
- Professor's Style 検出（過去講義分析）
- Daily Push通知
- **6/1ローンチには含まず、8月追加予定**

### FR-8 終了フロー（既存、維持 + 追加）
既存:
1. `DeepgramLiveService.stop()` → `deepgram-usage-add` POST
2. 確定セグメントを保存

追加:
3. **Vocabulary自動抽出キック**（バックグラウンド）
4. **Course/Week自動紐付け**（ユーザー確認UI）

### FR-9 エラー / 再接続（既存、維持）
| 発生 | 挙動 |
|---|---|
| Edge Function 401 | unauthorized + ログイン導線 |
| 402 budget_exceeded | WhisperKit fallback |
| 429 daily_cap / monthly_cap（Gap #3） | fallback |
| 503 feature_disabled | fallback |
| WSS close ≠ 1000 | 2s→4s→8s リトライ×3 |
| 3回全失敗 | WhisperKit fallback |
| AVAudioSession中断 | 復帰通知で再開 |
| route change | エンジン再作成 |

### FR-10 **NEW: Stripe課金フロー**
**iOS内で課金UIゼロ（Apple IAP 廃止）**:
- 「プランをアップグレード」タップ → SFSafariViewController で `lecsy.app/billing`
- Web で Stripe Checkout → 成功 → iOS に戻る
- iOS起動時 / Pull-to-Refresh で `profiles.plan` 取得 → UI解放
- iOS 課金UIは一切表示しない（Apple審査対策）

**Apple審査対策 App Store メタデータ**:
```
"lecsy is free to download and use. Some advanced features are 
available through a Pro subscription, managed at lecsy.app."
```

### FR-11 **NEW: 既存500ユーザー移行**
- App Update → 初回起動時「クラウド同期を有効化？」ダイアログ
- オプトインで、ローカル録音メタデータ + 文字起こしテキストのみアップロード
- **音声ファイルはアップロードしない**（プライバシー維持）
- バックグラウンドURLSession、WiFi+充電時のみ
- 詳細: `Deepgram/技術/ローカルtoクラウド移行設計.md`

---

## 3. 非機能要件（NFR）

### NFR-1 性能
| 指標 | 目標（GA） |
|---|---|
| Deepgram interim 初回遅延 | p50 ≤ 400ms / p95 ≤ 800ms |
| 翻訳ストリーム追加遅延 | p95 ≤ 500ms |
| Bilingual 合計遅延 | p95 ≤ 1500ms |
| final化遅延 | p95 ≤ 1500ms |
| Study Guide Quick生成 | ≤ 5秒 |
| Study Guide Standard生成 | ≤ 15秒 |
| Vocabulary抽出（10用語） | ≤ 10秒 |
| 初回接続成功率 | ≥ 99.0% |
| 10分連続切断率 | ≤ 1% |

### NFR-2 信頼性
- 再接続時の字幕欠損 ≤ 2秒（RingBuffer対応、Gap #4）
- WhisperKit fallback時、表示済みDeepgramセグメントは破棄せず継続

### NFR-3 可用性
- Deepgram障害時 → Edge Function 5sタイムアウト → WhisperKit fallback
- Feature Flag で **30秒以内の全停止** 可能

### NFR-4 セキュリティ
- Deepgram管理者キー: Supabase Secrets のみ、バイナリ非含有
- 短寿命キー: TTL 15min, `usage:write` only
- Authorization: `Token <key>`（Bearer ではない）
- 管理者キー: 四半期ローテーション（Gap #8）
- `admin-for-edge` 権限: `keys:write + usage:read + billing:read`
- Deepgram Project 分離: `lecsy-dev` / `lecsy-prod`
- **Stripe Secrets**: `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET` → Supabase Secrets
- **OpenAI API Key**: 同上
- **GPT-4o Mini 呼び出しは Edge Function 経由のみ**（iOS から直接 OpenAI 叩かない）

### NFR-5 プライバシー / コンプライアンス
- **音声データ**: Deepgram に送信、**lecsy サーバー保存ゼロ**
- **Deepgram Zero Data Retention**: 将来交渉（MRR $10K以降）。現状は30日保持を Privacy Policy に明記
- **FERPA strict B2B 教室**: `ferpaStrictMode=true` で WhisperKit 固定
- **文字起こしテキスト**: Supabase `transcripts` に暗号化保存（AES-256）
- **翻訳テキスト**: OpenAI に送信、OpenAI は学習利用しない契約（API Usage Policy）
- **削除SLA**: ユーザー要請30日以内、契約終了後30日purge、90日backup retention
- **プライバシー訴求**（営業・Privacy Policy）:
  ```
  Audio Processing:
  • Your audio is streamed securely (TLS 1.3) to Deepgram, Inc.
    (SOC 2 Type II certified).
  • Deepgram retains audio up to 30 days for service quality
    then auto-deletes.
  • Lecsy servers NEVER store your audio at any time.
  • Only text transcripts are retained on Lecsy, deletable anytime.
  ```

### NFR-6 コスト
| 項目 | 原価 |
|---|---|
| Deepgram Nova-3 Multilingual | $0.0092/min = $0.552/h |
| Deepgram Nova-3 Monolingual（英語onlyオプション） | $0.0077/min = $0.462/h |
| GPT-4o Mini | $0.15/M input + $0.60/M output tokens |
| text-embedding-3-small | $0.02/M tokens |
| Stripe | 2.9% + $0.30/取引 |

**1ユーザー原価（Pro $12.99、中ヘビー想定）**:
- Deepgram 6h Multi + 2h Prerec ≈ $4.4
- GPT-4o Mini（翻訳+Study Guide+Vocab+Quiz） ≈ $0.80
- Embeddings ≈ $0.05
- Supabase配分 ≈ $0.30
- Stripe手数料 ≈ $0.68
- **合計 ≈ $6.25 → 粗利 $6.74（52%）**

**プラン別月次cap（Gap #3で実装）**:
| プラン | 月次 | 日次 |
|---|---|---|
| Free | 300分 Prerecorded only | 60分 |
| Pro | 15時間 | 3時間 |
| Pro Student | 10時間 | 2時間 |
| ISSS Starter（1席） | 8時間 | - |
| ISSS Growth（1席） | 5時間 | - |
| Enterprise | 契約次第 | - |

- 残高ハード閾値: $100未満で feature flag 自動OFF
- 警告閾値: $150

### NFR-7 オブザーバビリティ（Gap #9）
- Edge Function logs → Supabase Logs
- `deepgram-token` カウンタ → `deepgram_token_metrics_daily`
- クライアント匿名メトリクス → `realtime-metrics` Edge Function
- Deepgram Console Usage 日次チェック

### NFR-8 アクセシビリティ（Gap #6）
- Dynamic Type 最大 XXXL: `@ScaledMetric` で実装
- VoiceOver: final セグメントのみ読み上げ、interim は hidden
- コントラスト AA+（secondary 70%以上）
- Bilingual View も VoiceOver 両言語読み上げ対応

---

## 4. API 契約（固定）

### POST /functions/v1/deepgram-token（既存、拡張）
Request: Header `Authorization: Bearer <supabase_token>`, `apikey: <anon_key>`
Response 200:
```json
{
  "token": "dg_short_lived_...",
  "expires_in": 900,
  "minutes_today": 42.5,
  "daily_cap_minutes": 120,
  "minutes_this_month": 850,    // 追加
  "monthly_cap_minutes": 3000,  // 追加
  "preferred_language": "ja",    // 追加（language動的）
  "plan": "pro"                  // 追加
}
```
Error: 401 / 402 / 429 / 503 / 502 / 500（既存）
**追加**: 429 `monthly_cap` も返す

### POST /functions/v1/deepgram-usage-add（既存、維持）
### POST /functions/v1/translate-realtime（新規）
Request:
```json
{
  "text": "The Fourier transform is a mathematical...",
  "source_language": "en",
  "target_language": "ja",
  "lecture_id": "uuid"
}
```
Response: Server-Sent Events（streaming）
```
event: translation
data: {"text": "フーリエ変換は数学的", "complete": false}

event: translation
data: {"text": "フーリエ変換は数学的変換です", "complete": true}
```

### POST /functions/v1/generate-study-guide（新規）
Request:
```json
{
  "lecture_id": "uuid",
  "depth": "quick" | "standard" | "deep",
  "native_language": "ja"
}
```
Response: Server-Sent Events（streaming JSON）

### POST /functions/v1/extract-vocabulary（新規）
Request:
```json
{
  "lecture_id": "uuid",
  "native_language": "ja",
  "domain": "stem" | "humanities" | ...
}
```
Response:
```json
{
  "terms": [
    {
      "term": "Fourier transform",
      "definition_en": "...",
      "definition_native": "...",
      "cefr_level": "C1",
      "timestamp_sec": 754.2,
      "existing": false
    }
  ]
}
```

### POST /functions/v1/create-checkout-session（新規）
Request:
```json
{
  "plan": "pro_monthly" | "pro_yearly" | "student_monthly" | ...,
  "success_url": "https://lecsy.app/billing/success",
  "cancel_url": "https://lecsy.app/pricing"
}
```
Response:
```json
{ "url": "https://checkout.stripe.com/..." }
```

### POST /functions/v1/create-portal-session（新規）
Response:
```json
{ "url": "https://billing.stripe.com/..." }
```

### POST /functions/v1/stripe-webhook（新規）
受信イベント:
- `customer.subscription.created` / `updated` → `profiles.plan` 更新
- `customer.subscription.deleted` → Free に戻す
- `invoice.paid` → 継続
- `invoice.payment_failed` → リトライ対応

Webhook署名検証必須。

---

## 5. テスト要件

### 単体テスト（既存維持 + 追加）
既存:
- `DeepgramMessageTests` / `DeepgramLiveServiceHelpersTests`
- トークンプロバイダのステータスマッピング
- `attemptReconnect` 指数バックオフ
- `reportSessionUsage` delta計算
- `TranscriptionCoordinator.chooseMode` 真理値表

**追加**:
- `TranslationStreamClient` のSSE受信・エラー処理
- `StudyGuideService.generate(depth:)` の3モード
- `VocabularyExtractor` のpgvector類似判定
- `AnkiExporter` の .apkg 生成
- `StripePortalLink` の URL組立

### 結合テスト（GA前必須）
- `deepgram-token` staging curl: 5ステータス
- `deepgram-usage-add`: 境界値
- **新規**: `translate-realtime` のSSE streaming疎通
- **新規**: `generate-study-guide` の3 depth 生成
- **新規**: `stripe-webhook` の署名検証 + subscription.created

### 実機テスト（GA判定ゲート）
既存:
| シナリオ | 合格基準 |
|---|---|
| 5分連続 | 切断0 |
| 60分連続（**必須**） | 切断 ≤ 2、全自動再接続 |
| 10時間ソーク（**必須**） | crash=0, peak<350MB, disconnection auto-recovered |
| 30分沈黙→発話 | KeepAlive接続維持 |
| 画面ロック中 | 字幕継続 |
| 着信割込→復帰 | 自動再開 |
| AirPods外す | route change対応 |
| 機内モード | WhisperKit切替 |
| Wi-Fi→LTE | 3秒以内復帰 |
| 教室Wi-Fi 500kbps | p95 latency ≤ 1500ms |

**追加（新機能テスト）**:
| シナリオ | 合格基準 |
|---|---|
| Bilingual 15分連続 | 翻訳遅延 p95 ≤ 1500ms, 誤訳率 ≤ 10% |
| Study Guide Quick 20回生成 | 全て5秒以内、一貫性あり |
| Vocabulary抽出（1h講義） | 10-20用語抽出、CEFR判定 > 90%正確 |
| Anki export（50枚） | 完全な.apkg生成、import可 |
| Stripe Checkout完走 | 成功後1分以内にiOSで Pro解放 |
| 既存500ユーザーの移行 | 80%+が opt-in、0データ欠損 |

### ローカライゼーション
- 日本語講義（language=ja）: WER ≤ 18%
- 英語講義（language=en）: WER ≤ 12%
- 日英混在（language=multi）: WER ≤ 22%
- **追加**: 翻訳品質（GPT-4o Mini） BLEU ≥ 0.65

---

## 6. 運用要件

### 監視
- 日次cron `deepgram-balance-check`:
  - $150未満 → warning
  - $100未満 → critical + 自動OFF
- **追加**: OpenAI API usage 日次サマリ（Slack通知、月$100超で警告）
- **追加**: Stripe 日次売上 サマリ
- **追加**: `deepgram-token` 1h 402/429/503 発生数 Supabaseダッシュボード

### インシデント対応ランブック（`doc/INCIDENT_REALTIME.md`）
1. 「字幕が出ない」報告
   - `SELECT * FROM feature_flags WHERE name='realtime_captions_beta'`
   - Deepgram Console Balance確認
2. 残高急減（通常5倍以上）
   - 上位ユーザー抽出、bot疑い → 日次上限を0分に固定
3. Deepgram障害
   - `feature_flags.realtime_captions_beta=false` → 全員WhisperKit
4. **新規**: OpenAI API障害
   - 翻訳・Study Guide一時無効化、基本文字起こしのみ継続
5. **新規**: Stripe障害
   - 既存ユーザーはそのまま継続、新規課金のみ一時停止

### キーローテーション（四半期、Gap #8）
- Deepgram `admin-for-edge` 新規発行 → Secrets更新 → 旧キー失効
- OpenAI API Key 年次ローテーション
- Stripe rolling key ローテーション（月次推奨）
- 手順書: `doc/deployment/DEEPGRAM_KEY_ROTATION.md`

### 緊急停止
| 停止単位 | 手段 | 反映時間 |
|---|---|---|
| 全ユーザー（全機能） | `feature_flags` 複数OFF | 次回token取得時（<15min） |
| 特定ユーザー | `user_daily_realtime_usage` 999分挿入 | 即時 |
| 特定組織（Gap #5） | `org_monthly_realtime_usage` cap超過挿入 | 即時 |
| 翻訳機能のみ | `feature_flags.bilingual_captions=false` | <15min |
| Study Guide のみ | `feature_flags.ai_study_guide=false` | <15min |

---

## 7. ロールアウト計画

### フェーズ
| フェーズ | 期間 | 対象 | 条件 |
|---|---|---|---|
| BETA内部 | 2026-04 | 社内5名 | 現状達成 |
| BETA Limited | 2026-05 | TestFlight 100名 | 60分ソーク合格、staging 5ケーステスト合格 |
| BETA Public | 2026-05末 | 全ユーザー、BETAバッジ | 10h ソーク合格、新機能（Bilingual + Study Guide）動作 |
| **GA** | **2026-06-01** | **全ユーザー、BETA撤去、Stripe課金ON** | **Gap #1-12 + #13-23 完了** |
| Post-GA | 2026-07 | Exam Prep Plan追加 | Summer pilot実施校のフィードバック反映 |

### Kill switch（最強の保険）
- 各feature_flag を独立OFF可能
- iOSアプリ改修不要、DB 1行UPDATEで全端末反映
- Stripe Webhookを停止すれば課金も一時停止可

---

## 8. UI/表記の本番化

GA時（2026-06-01）に切替:
- `BETA`バッジ → 撤去
- 初回ダイアログ → 「New in lecsy 2.0」に差替
- 設定ラベル: 「リアルタイム字幕（実験機能）」→「リアルタイム字幕」
- App Store メタデータ:
  - Title: **"lecsy — AI Lecture OS for International Students"**
  - Subtitle: **"Real-time bilingual captions · Study guides · Vocab"**
  - Description: 留学生訴求に全面改訂、Stripe誘導を明記
- Privacy Policy: Deepgram音声送信 + GPT-4o Mini + Stripe 明記

---

## 9. Gap リスト（6/1 GAまでに完了必須）

### 既存 Gap（本番化のベース、P1=Must / P2=Should）

| # | Gap | 優先度 | 見積 | 状態 |
|---|---|---|---|---|
| 1 | language動的選択（ja/en/multi） | P1 | 0.5d | 未着手 |
| 2 | トークンTTL予防的プリフェッチ | P1 | 1.5d | 未着手 |
| 3 | 月次上限（user_monthly_realtime_usage） | P1 | 1d | 未着手 |
| 4 | 再接続時字幕欠損最小化（RingBuffer） | P2 | 2d | 未着手 |
| 5 | 組織単位月次上限（B2B） | P2 | 1.5d | 未着手 |
| 6 | Dynamic Type対応 | P1 | 0.5d | 未着手 |
| 7 | Deepgram zero-retention（無理なら Privacy記述） | P1 | 0.5d | **ZDR無し方針、Privacy明記のみ** |
| 8 | 管理者キーローテーション手順書 | P1 | 0.5d | 未着手 |
| 9 | オブザーバビリティ（`realtime-metrics` + `deepgram_token_metrics_daily`） | P2 | 1.5d | 未着手 |
| 10 | Plus/Free差別化（月次cap/言語multi可否） | P2 | 1d | 未着手 |
| 11 | 10時間ソークテスト自動化 | P1 | 1d | 未着手 |
| 12 | App Store ASO Beta→GA差替 | P1 | 0.5d | 未着手 |

### 🆕 新戦略 Gap（留学生特化 + 5キラー機能 + Stripe一本化）

| # | Gap | 優先度 | 見積 | 状態 |
|---|---|---|---|---|
| 13 | **Bilingual Captions UI**（左右分割、同期スクロール、タップ辞書） | **P0** | 3d | 未着手 |
| 14 | **GPT-4o Mini 翻訳ストリーム** Edge Function | **P0** | 2d | 未着手 |
| 15 | **Course Hierarchy** データモデル + UI（学期→科目→週→回） | **P0** | 4d | 未着手 |
| 16 | **AI Study Guide** Edge Function（Quick + Standard） | **P1** | 3d | 未着手 |
| 17 | **Vocabulary抽出** Edge Function（GPT-4o Mini + pgvector） | **P1** | 2d | 未着手 |
| 18 | **Anki .apkg export**（基本版） | **P1** | 1d | 未着手 |
| 19 | **Stripe Checkout / Portal / Webhook**（Apple IAP 完全廃止） | **P0** | 3d | 未着手 |
| 20 | **シラバスPDF自動解析**（Phase 2、7月Summer中） | **P2** | 2d | 7月対応 |
| 21 | **B2C価格プラン切替**（Pro $12.99 / Student $6.99） | **P0** | 1d | 未着手 |
| 22 | **App Store メタデータ**（留学生訴求 + Stripe誘導） | **P0** | 0.5d | 未着手 |
| 23 | **Exam Prep Plan**（Phase 2、8月Fall前） | **P2** | 5d | 8月対応 |
| 24 | **既存500ユーザー移行機能**（オプトイン同期） | **P0** | 3d | 未着手 |
| 25 | **iOS価格UI完全削除**（Apple審査対策） | **P0** | 0.5d | 未着手 |
| 26 | **AI Study Guide Deep mode**（Phase 2、7月） | **P2** | 2d | 7月対応 |

**6/1 GA必達（P0 + P1）合計**: 約 **29-33人日**
**6/1以降（P2 + Phase 2）合計**: 約 11-13人日

---

## 10. 実装タイムライン（7週間）

### Week 1 (4/14-4/20)
- Gap #1 language動的選択（0.5d）
- Gap #7 Privacy Policy整合（0.5d、ZDR無し明記）
- Gap #2 予防的プリフェッチ（1.5d、着手）
- Gap #25 iOS価格UI削除（0.5d）
- Gap #19 Stripe Checkout 着手（3d、開始）
- 並行: Gap #13 Bilingual UI プロトタイプ（3d、開始）

### Week 2 (4/21-4/27)
- Gap #2 完成
- Gap #19 完成
- Gap #13 完成
- Gap #14 GPT-4o Mini 翻訳Edge Function（2d）
- Gap #21 価格プラン切替（1d）
- Gap #3 月次上限（1d、着手）

### Week 3 (4/28-5/04)
- Gap #15 Course Hierarchy（4d、開始）
- Gap #3 完成
- Gap #24 既存ユーザー移行 Phase A-B（3d、着手）

### Week 4 (5/05-5/11)
- Gap #15 完成
- Gap #16 AI Study Guide Edge Function（3d）
- Gap #24 完成
- Gap #17 Vocabulary抽出（2d、着手）

### Week 5 (5/12-5/18)
- Gap #17 完成
- Gap #18 Anki export（1d）
- Gap #5 組織単位月次上限（1.5d）
- Gap #6 Dynamic Type（0.5d）
- Gap #11 10時間ソーク開始

### Week 6 (5/19-5/25)
- Gap #11 完成
- Gap #4 RingBuffer（2d）
- Gap #9 オブザーバビリティ（1.5d）
- Gap #8 キーローテーション手順書（0.5d）
- Gap #22 App Store メタデータ（0.5d）
- Gap #12 ASO差替（0.5d）

### Week 7 (5/26-5/31)
- **LLC設立 + EIN + Business銀行口座**
- Gap #10 Plus/Free差別化（1d）
- App Store Review申請
- Stripe Live mode切替準備
- 既存500ユーザー移行通知配信
- 最終QA

### Week 8: **2026-06-01 ローンチ** 🚀
- OPT開始、ISS報告
- Stripe Live mode切替
- Pro課金ON
- App Store リリース
- 既存500ユーザーへ移行通知メール
- パイロット校への正式版連絡

### Post-GA（6月以降、Summer pilot中）
- Gap #20 シラバスPDF自動解析（6月中旬）
- Gap #26 AI Study Guide Deep mode（6月末）
- Gap #23 Exam Prep Plan（8月Fall前）
- **韓国語UI追加**（7月）
- **中国語UI追加**（9月）

---

## 11. 受入基準（Go/No-Go）

GAリリース承認は以下**全て true**のとき:

1. ✅ Gap 既存P1項目（#1, #2, #3, #6, #7, #8, #11, #12）完了・マージ済
2. ✅ Gap 新規P0項目（#13, #14, #15, #19, #21, #22, #24, #25）完了・マージ済
3. ✅ 60分連続録音テスト: iPhone 15 Pro / iPhone SE3 の2端末で合格
4. ✅ 10時間ソークテスト: `crashed=0` / `peak_memory<350MB` / `disconnections_auto_recovered=all`
5. ✅ staging環境で `deepgram-token` の5ステータス系列テスト全パス
6. ✅ **新規**: Bilingual Captions 15分連続テスト合格（翻訳遅延 p95 ≤ 1500ms）
7. ✅ **新規**: Study Guide Quick/Standard 生成テスト合格（5秒/15秒以内）
8. ✅ **新規**: Stripe Checkout 完走テスト合格（購入→iOS反映 <1分）
9. ✅ **新規**: 既存ユーザー移行テスト合格（opt-in後の同期データ欠損 0%）
10. ✅ 直近2週間BETA Publicで初回接続成功率 ≥ 99.0%
11. ✅ Privacy Policy: Deepgram音声送信 + GPT-4o Mini + Stripe 明記
12. ✅ App Store メタデータ: 留学生訴求 + Stripe誘導（IAP 未設定）
13. ✅ 管理者キーローテーション手順書あり
14. ✅ 緊急停止（feature flag OFF）が30秒以内に全端末で効くことを検証
15. ✅ B2B組織アカウントで FERPA strict mode が Deepgram を発動させないことを検証
16. ✅ **LLC 設立完了 + EIN + Business銀行口座**
17. ✅ **Stripe Business アカウント認証完了、Live mode切替可能**

以上を満たさない場合はBETA Public継続、原因分析→修正→再評価。

---

## 12. 本書外（明示的スコープ外）

- Phase 3 シームレス online↔offline切替（完全シームレス）
- Phase 3 話者分離（diarize=true）本格運用
- macOS / watchOS / Android 対応
- 自前ASRモデル
- Canvas LTI 1.3（Phase 3、2027 Q2以降）
- SAML 2.0 / Shibboleth SSO（Phase 3）
- SCIM ユーザー同期（Phase 3）
- SOC 2 Type II 監査（Phase 3、2027）

これらは別プロポーザルで扱う。本書は **2026-06-01 GA** に限定。

---

## 13. 参照資料

### 戦略パッケージ（`Deepgram/` フォルダ）
- `README.md` — 入口
- `00_INDEX.md` — ナビゲーション
- `01_ビジョンと勝ち筋.md` — コア戦略
- `02_5キラー機能完全仕様.md` — 機能要点
- `03_競合完全ガイド.md` — 55社マップ
- `04_営業完全戦術書.md` — 営業バイブル
- `05_90日アクションプラン.md` — 週次計画
- `06_技術スタック完全版.md` — アーキ全体像
- `07_価格とユニットエコノミクス.md` — 数字
- `08_法務コンプライアンス.md` — FERPA/HECVAT/VPAT/App Store
- `09_リスクマップと対策.md` — リスク管理
- `10_勝利のための鉄則.md` — 原則

### 詳細設計
- `Deepgram/プロダクト/キラー5機能仕様.md`
- `Deepgram/技術/Deepgram-only設計_2026.md`
- `Deepgram/技術/ローカルtoクラウド移行設計.md`
- `Deepgram/ビジネス/Stripe課金アーキテクチャ.md`
- `Deepgram/ビジネス/価格体系.md`

### 実装ガイド
- `Deepgram/技術/Deepgram実装_単体版.md` — iOSコード
- `Deepgram/技術/Deepgramセットアップ手順.md` — アカウント・契約
- `Deepgram/技術/Deepgramリアルタイム字幕実装.md` — Streaming実装

### 営業・法務
- `Deepgram/営業/04_営業完全戦術書.md`
- `Deepgram/営業/HECVAT_Lite_回答テンプレ.md`
- `Deepgram/営業/F-1中の無料パイロット運用.md`
- `Deepgram/営業/uf_eli.md`

### 変更履歴
- `Deepgram/変更履歴/WhisperKitからDeepgramへ_完全変更点.md`
- `Deepgram/変更履歴/重要な意思決定ログ.md`

### 外部資料
- Deepgram Live Streaming: https://developers.deepgram.com/docs/live-streaming-audio
- Deepgram WebSocket: https://developers.deepgram.com/docs/lower-level-websockets
- OpenAI API Reference: https://platform.openai.com/docs/api-reference
- Stripe Checkout: https://stripe.com/docs/payments/checkout
- Apple App Review Guidelines 3.1.3(b): https://developer.apple.com/app-store/review/guidelines/
- Starscream: https://github.com/daltoniam/Starscream

---

## 14. 変更履歴

### 2026-04-14 統合アップデート
- **既存BETA→GA要件を維持**（Gap #1-#12）
- **新戦略を統合**（Gap #13-#26）:
  - 留学生特化ピボット
  - 5キラー機能追加（Bilingual Captions / Course Hierarchy / AI Study Guide / Vocabulary / Exam Prep Plan）
  - Stripe一本化、Apple IAP 廃止
  - B2C価格変更（Pro $12.99 / Student $6.99）
  - 既存500ユーザー移行フロー追加
- **GA タイミング**: 2026-07 → **2026-06-01** に前倒し
- **WhisperKit フォールバック**: 維持（オフライン・FERPA strict用、Phase 3で削除検討）
- **Zero Data Retention**: 追わない方針、Privacy Policyに30日保持を正直記述

### 2026-04-14 初版（本書の元）
- Deepgram BETA → GA の基本要件
- Gap #1-#12 定義

---

## 15. 本書の位置付け

**この1ファイルだけ持って行けば、6/1 ローンチに必要な技術・運用・営業・法務のすべてが分かる。**

lecsy プロジェクト（iOS / Web / Supabase codebase）にこのフォルダごと持ち込んで、Claude Code で開発する。

迷った時:
- 技術判断 → 本書 セクション1-6
- 運用判断 → 本書 セクション7-10
- ローンチ判断 → 本書 セクション11
- 戦略判断 → `Deepgram/01-10` の戦略ドキュメント
- 営業判断 → `Deepgram/04_営業完全戦術書.md`
- 緊急時 → `Deepgram/09_リスクマップと対策.md`

---

**これが lecsy 2.0 のすべて。実装を開始する準備は整った。**
