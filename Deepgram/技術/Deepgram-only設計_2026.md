# lecsy Deepgram-only アーキテクチャ設計（2026）

> 作成日: 2026-04-14
> 最終更新: 2026-04-14（グローバル版・Stripe一本化対応）
> ステータス: **これが今後の正式設計**。WhisperKit は全削除。
> ビジョン: **「世界中の大学が使うアプリ」**
> 関連: [[Deepgram実装_単体版]] / [[Deepgramセットアップ手順]] / [[価格体系]] / [[Stripe課金アーキテクチャ]] / [[HECVAT_Lite_回答テンプレ]]

---

## 0. この設計の一行サマリ

**Deepgram Nova-3 Multilingual で全世界の文字起こし + GPT-4o Mini でリアルタイム翻訳・Study Guide・Vocabulary生成 + pgvector でセマンティック検索。音声はクラウド0バイト。テキスト（JSON）だけ Supabase Postgres JSONB に保存。プラン別cap + 5層安全弁で原価暴走を防ぐ。決済はStripe一本、将来 multi-region で全世界対応。**

---

## 0.1 AI スタック（新・統合版）

```
Deepgram Nova-3 Multilingual
  ├─ Streaming WebSocket: リアルタイム字幕
  └─ Prerecorded HTTPS: オフライン後処理

GPT-4o Mini（OpenAI API）
  ├─ Streaming: リアルタイム翻訳（英→日/韓/中）
  ├─ Study Guide生成: Quick / Standard / Deep
  ├─ Vocabulary抽出: 専門用語・CEFR判定・定義
  ├─ Quiz生成: Multiple choice / Short answer
  ├─ Syllabus解析: PDF→コース階層JSON
  └─ Exam Prep Plan生成: Adaptive学習計画

text-embedding-3-small（OpenAI API）
  └─ Semantic Search: 全講義横断検索、類似用語、Professor's Style

pgvector（Supabase拡張）
  └─ Embeddings保存・コサイン類似度検索
```

### 原価目安（1ユーザー/月、中ヘビー使用想定）
| 項目 | 原価 |
|-----|-----|
| Deepgram Streaming 6h Multi | $3.31 |
| Deepgram Prerecorded 2h | $1.10 |
| GPT-4o Mini 翻訳 | $0.45 |
| GPT-4o Mini Study Guide x15 | $0.25 |
| GPT-4o Mini Vocabulary x200 | $0.06 |
| GPT-4o Mini Quiz x10 | $0.05 |
| Embeddings | $0.05 |
| Supabase | $0.30 |
| **合計** | **$5.57** |

→ Pro $12.99 で粗利 $6.74（57%）

---

## 1. なぜこの設計か（意思決定ログ）

### 1.1 WhisperKit を捨てる理由
- Deepgram Nova-3 の精度が WhisperKit tiny/small を明確に上回る（日英混在・アクセント・専門語彙）
- 中国圏ユーザーの「WhisperKit使えない」問題が構造的に解決
- アプリサイズ激減（モデルDL不要）、オンボーディングから「AIモデル準備」ページ削除
- コードベース単純化（WhisperKitLive / ModelLoader / 多言語キットDL機能すべて削除）

### 1.2 音声を保存しない理由
- ストレージ代はほぼ誤差（月20h/ユーザーで $0.007）だが、egress が効く（音声再生時 $0.09/GB）
- **プライバシー訴求**: 「音声は1秒も保存されません」と営業で言える
- **FERPA リスク軽減**: テキストもFERPA対象だが、音声保持は監査での追加リスク
- Deepgram Nova-3 精度なら「再文字起こし」需要は実質ゼロ → 音声保持の技術的価値も低い

### 1.3 テキストをクラウドに置く理由
- 端末またぐ閲覧（iPhone + iPad + Web）に必須
- B2B ダッシュボード / 検索 / 共有 / エクスポートすべてローカルでは困難
- ストレージ代はDeepgram本体代の1/1000以下、実質誤差
- Postgres JSONB なら word-level timestamp まで保持して全文検索もできる

### 1.4 構造変化の自覚
**Deepgram採用の瞬間、「完全オンデバイス」という lecsy 最大の差別化を捨てる**。今後は:
- HECVAT / DPA / SOC2 準備はローンチ前に不可避（逃げられない）
- 営業訴求は「オンデバイス」→ 「音声ゼロ保存 + FERPA準拠設計」にリフレーム
- Tactiq が先行した「プライバシー特化」ポジションを踏襲する

---

## 2. アーキテクチャ

```
┌──────────────── iOS アプリ ──────────────────┐
│                                              │
│  RecordView                                  │
│    ├─ オンライン → DeepgramStreamSession    │ ← Streaming WebSocket
│    └─ オフライン → ローカルバッファのみ       │ ← Opus 32kbps 一時保存
│                                              │
│  LibraryView の「保留」録音                  │
│    └─ 「文字起こしする」ボタン               │ ← Prerecorded API（オンライン復帰時）
│                                              │
│  完了後: 音声ファイルは端末内に残す          │
│           （ユーザー自身で削除可、7日で自動） │
└──────────────────────────────────────────────┘
          │                              ▲
          │ 1. 短寿命トークン要求        │ 4. 文字起こしJSON保存
          ▼                              │
┌── Supabase Edge Functions ──────────────┐
│                                          │
│  deepgram-token   (Streaming用)         │ ← 5層安全弁を全部ここで
│  deepgram-batch   (Prerecorded用)       │ ← 音声Upload → Deepgram → JSON保存
│  usage-tracker    (使用量更新)          │ ← 接続終了時にminutes加算
│                                          │
└──────────────────────────────────────────┘
          │                              ▲
          │ 2. WebSocket / HTTPS         │ 3. 結果返却
          ▼                              │
┌─ Deepgram API ───────────────────────────┐
│  wss://api.deepgram.com/v1/listen        │
│  https://api.deepgram.com/v1/listen      │
│  Zero Data Retention モード              │
│  Nova-3 Monolingual / Multilingual 切替  │
└──────────────────────────────────────────┘

┌─ Supabase Postgres ──────────────────────┐
│  transcripts (id, user_id, created_at,   │
│               language, duration_sec,    │
│               words JSONB,               │  ← word-level timestamp保持
│               text_search tsvector)      │
│  user_daily_realtime_usage               │  ← 日次cap用
│  user_monthly_usage                      │  ← 月次cap用
│  feature_flags                           │
│  organizations / org_members             │  ← B2B
└──────────────────────────────────────────┘
```

**原則:**
1. Deepgram管理者キーは**絶対にiOSバイナリに含めない**。Edge Function経由で短寿命トークン発行
2. 音声ファイルは**Supabase Storageに上げない**。必要ならPrerecorded用に一時Upload→処理後即削除
3. Deepgram は Zero Data Retention モードで契約（音声は処理後破棄を保証）

---

## 3. Deepgram 2モード活用

| モード | エンドポイント | 価格（Nova-3 Mono） | 用途 |
|-------|--------------|------------------|------|
| **Streaming** | WebSocket | $0.0077/分 | ライブ字幕（Pro/B2B） |
| **Prerecorded** | HTTPS POST | $0.0077/分 | オフライン保存→後送り（Free/Pro/B2B） |

**Multilingual（自動言語判定・多言語混在）をデフォに:**
- 価格 $0.0092/分（+20%）
- **Multilingual デフォ化の理由:**
  - 「世界中の大学」ビジョン → 言語切替の摩擦を消すことが最優先
  - ESL授業は英語＋学生母語の混在が前提
  - 多言語大学では先生もコードスイッチングする
  - +20%コストは粗利69%を守れるレンジ内
- **「英語のみクラス」モード**を上級設定としてオプション提供（原価-20%できる、パワーユーザー向け）
- デフォMultilingual・オプションMonolingualという設計で、ユーザー体験とコストの両立

**アドオン方針:**
- Smart Formatting: **常時ON**（無料）
- Diarization（話者分離）: **OFF**（講師1人の授業が大半、+26%の価値なし）
- Keyterm Prompting: 将来のB2Bオプション機能として保留（$+0.0013/分）
- Summarization: **使わない**（GPT-4o Mini で自前、方が安くて柔軟）
- Topic Detection / PII Redaction: 使わない

---

## 4. プラン別 機能・上限

### 4.1 B2C

| プラン | 月額 | Streaming（ライブ字幕） | Prerecorded | 1セッション | 月間合計 | 日次cap |
|------|------|---------------------|------------|----------|---------|---------|
| **Free** | $0 | ❌ なし | ✅ | 90分 | **300分/月** | 60分 |
| **Pro** | **$11.99** | ✅ | ✅ | 120分 | **15時間/月** | 3時間 |
| **Pro Student** (.edu) | **$5.99** | ✅ | ✅ | 120分 | **10時間/月** | 2時間 |

**設計意図:**
- Free 300分 = Otter と同ライン。「業界標準・良心的」認知
- Free **1セッション90分** は大学講義1コマ死守（Notta の 3分/録音は論外）
- Free 履歴は**無期限**（Granola の 30日は学期跨ぎで致命傷）
- Pro $11.99 は Otter Pro $16.99 の下、原価 $7 で粗利 42%
- Student 50%引きは Otter 20%引きを超える。.edu メール認証必須で乱用防止

### 4.2 B2B

| プラン | 月額 | 席数 | 1席月間時間 | 組織合計 | 1席原価 max | 1席 ARR |
|------|------|------|-----------|---------|-----------|--------|
| **Starter** | $349 | 50 | 8時間 | 400h/月 | $3.7 | $83.8 |
| **Growth** | $699 | 200 | 5時間 | 1,000h/月 | $2.3 | $42 |
| **Enterprise** | 要相談 | 無制限 | 契約次第 | 契約次第 | — | — |

**設計意図:**
- Glean $100/seat/year 水準と比べ Growth は $42 と**半額以下**、競争力強い
- 実稼働率は業界平均30-50% → 実原価は半分、**粗利 73-85%**
- 組織合計cap で1校が暴走しても Deepgram 予算が守られる
- Enterprise は SSO / SAML / Custom DPA / VPAT提出で $10-30k/年レンジ

---

## 5. 暴走防止：5層の安全弁

Edge Function `deepgram-token` / `deepgram-batch` に全部のせる。**全層通過しないとDeepgramへつながない。**

| 層 | チェック内容 | 発動時の挙動 | 実装場所 |
|---|------------|-----------|--------|
| **L1: 組織残高** | Deepgram残高 < $100 | 全ユーザー拒否 + Slack通知 | Edge + Deepgram API |
| **L2: 月次cap** | ユーザー/組織の monthly minutes 超過 | 新規セッション拒否 | Postgres |
| **L3: 日次cap** | 今日の minutes 超過 | 翌0時まで拒否 | Postgres |
| **L4: セッションcap** | 録音中に1セッション上限到達 | iOS側で自動切断 + 残り時間表示 | iOS |
| **L5: アイドル** | 無音120秒 or バックグラウンド5分 | WebSocket close | iOS |

**+ サイドレール:**
- **同時接続1セッション/ユーザー**（マルチ端末同時ストリームNG）
- **80%警告**: 月次capの80%で Push通知 + アプリ内バナー
- **Deepgramダッシュボード予算アラート**: 月予算の50/80/100%で Slack通知（プラットフォーム側）
- **新規ユーザー急増検知**: 1時間で50人以上の新規が同時接続 → Slack警告（abuse検知）

---

## 6. WhisperKit 削除計画

### 6.1 削除対象コード
```
lecsy/
├── WhisperKit/            ← 全削除
├── Services/
│   ├── WhisperKitLive.swift     ← 削除
│   ├── ModelLoader.swift        ← 削除
│   └── LanguageKitDownload.swift ← 削除
├── Views/
│   └── Onboarding/
│       └── AIModelPrepView.swift ← 削除
└── Info.plist
    └── WhisperKitモデルのBundle参照削除
```

### 6.2 置き換えコード
```
lecsy/
├── Services/
│   ├── DeepgramStreamSession.swift  ← 新規（Starscream使用）
│   ├── DeepgramBatchService.swift   ← 新規
│   └── TranscriptionCoordinator.swift ← リライト
├── Views/
│   └── LibraryView/
│       └── PendingRecordingsRow.swift ← 新規（オフライン保存分の再処理UI）
└── Package.swift
    └── Starscream 4.0.8+ 追加、WhisperKit依存削除
```

### 6.3 UX 変更点
- **オンボーディング**: 5ページ → 4ページ（AIモデル準備ページ削除）
- **オフライン時録音**: 「録音は可能、オンライン復帰後に自動文字起こし」を明示
- **Free 上限到達**: 「今月のAI文字起こしを使い切りました。Proで15時間まで」CTA
- **リアルタイム字幕ON/OFFトグル**: Pro でも節約したい時のため（Prerecordedへフォールバック）
- **言語選択**: 毎セッション確認（Monolingual/Multilingual 動的切替のため）

---

## 7. データモデル

### 7.1 Postgres スキーマ（新規/変更）

```sql
-- 文字起こし本体（音声は保存しない、テキストのみ）
create table public.transcripts (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references auth.users(id) on delete cascade,
  organization_id uuid references public.organizations(id),
  title          text,
  language       text not null,
  duration_sec   int not null,
  recorded_at    timestamptz not null,
  created_at     timestamptz not null default now(),
  words          jsonb not null,  -- Deepgram の words[] をそのまま
  text_plain     text generated always as (
    (select string_agg(w->>'word', ' ')
     from jsonb_array_elements(words) w)
  ) stored,
  text_search    tsvector generated always as (
    to_tsvector('simple', (select string_agg(w->>'word', ' ')
                           from jsonb_array_elements(words) w))
  ) stored
);
create index on public.transcripts using gin(text_search);
create index on public.transcripts (user_id, created_at desc);

-- 日次使用量
create table public.user_daily_realtime_usage (
  user_id       uuid references auth.users(id) on delete cascade,
  usage_date    date not null default current_date,
  minutes_today numeric(10,2) not null default 0,
  primary key (user_id, usage_date)
);

-- 月次使用量
create table public.user_monthly_usage (
  user_id        uuid references auth.users(id) on delete cascade,
  year_month     text not null,  -- 'YYYY-MM'
  minutes_total  numeric(10,2) not null default 0,
  primary key (user_id, year_month)
);

-- 組織月次使用量（B2B）
create table public.org_monthly_usage (
  organization_id uuid references public.organizations(id) on delete cascade,
  year_month      text not null,
  minutes_total   numeric(10,2) not null default 0,
  primary key (organization_id, year_month)
);

-- RLS: 本人と管理者のみ読める
alter table public.transcripts enable row level security;
create policy "users read own transcripts"
  on public.transcripts for select using (auth.uid() = user_id);
create policy "org admins read org transcripts"
  on public.transcripts for select using (
    organization_id in (
      select organization_id from public.org_members
      where user_id = auth.uid() and role in ('admin', 'owner')
    )
  );
```

### 7.2 サイズ試算
- word-level JSONB: 1時間 ≒ 200-300 KB
- 月20時間ユーザー: ≒ 6 MB/月
- 1,000ユーザー: 6 GB（Postgres $0.75/月）
- 10,000ユーザー: 60 GB（$7.5/月）
→ **ストレージ代は完全に誤差**。Deepgram本体代の1/1000。

---

## 7.5 Deepgram Zero Data Retention 契約（必須）

**世界中の大学に営業するなら ZDR は絶対条件**。Deepgramにはデフォ30日間のログ保持がある。営業の「音声ゼロ保存」訴求を真に成立させるには:

### 必要アクション
1. Deepgram営業に連絡: `enterprise@deepgram.com`
2. **Zero Data Retention (ZDR) Mode** を契約書で明示
3. Nova-3 ZDR対応を確認（Enterprise契約必須の可能性）
4. BAA / DPA も同時に取得

### 代替策（ZDR契約取れない場合）
- Prerecorded の場合、音声ファイルを**一切Upload前に終わらせる**設計 → 実装不可（Prerecordedの定義上）
- Streaming のみで運用し、Prerecordedは Free/Proのみ制限（コンプラ厳しい大学はStreaming専用）

→ **優先度最高タスク**: Deepgram営業に今週中にメール

---

## 8. グローバル対応（Phase別）

| 対応項目 | Phase 1 (〜2026) | Phase 2 (2027) | Phase 3 (2028) |
|--------|-------------|-------------|-------------|
| Deepgramリージョン | us-east-1 | **EU Private Cluster 追加** | APAC Private Cluster |
| Supabase region | us-east-1 | **eu-central-1 追加** | ap-northeast-1 |
| CDN | Cloudflare global | 同上 | 同上 |
| 多通貨 | USD/EUR/GBP/JPY | + CNY/KRW/BRL | + 地域別PPP |
| 多言語UI | EN/JA | + ES/PT/ZH/FR/DE | + AR/KO/HI |
| SSO（SAML/Shibboleth） | なし | **実装** | SCIM追加 |
| LTI 1.3 | なし | **実装** | Canvas/Moodle/Blackboard |
| VPAT監査 | 自己評価 | **第三者監査** | 継続 |
| コンプライアンス | FERPA/GDPR | + UK GDPR/LGPD | + APPI/PIPEDA |

### 多言語プライバシーポリシー対象
- 英（必須）
- 日（必須、創業者ネイティブ）
- 西（大規模市場）
- ポ（ブラジル）
- 中（簡体字）
- 仏
- 独
- 韓

---

## 9. プライバシーポリシー変更点

**必ず反映:**
1. サブプロセッサ開示: Deepgram, Inc. (米国) を明示
2. データフロー図: 音声は Deepgram へ送信 → 即破棄、テキストは Supabase (us-east) に保存
3. 削除権: ユーザー要請で30日以内にすべて削除
4. データ所在地: 米国（us-east-1）
5. 暗号化: 転送 TLS 1.2+、保存 AES-256
6. 保存期間: 文字起こしは無期限（ユーザーが削除するまで）、音声は保存しない

**営業用の1ライナー:**
> "Your audio never touches our servers. We send it to Deepgram for transcription, they process it in real-time and immediately discard it. We only store the resulting text — which you can delete anytime."

---

## 10. 実装フェーズ（〜6/1ローンチ）

| Phase | 期限 | 内容 | 完了基準 |
|------|-----|------|--------|
| **0** | 4/16 | Deepgram営業にZDR契約問い合わせ、Stripeビジネスアカウント準備 | 返信受取 |
| **1** | 4/23 | Edge Functions 2本 + DB migrations | ローカルで疎通確認 |
| **2** | 4/30 | iOS Deepgram Streaming 統合 | 英語ライブデモ動作 |
| **3** | 5/07 | Prerecorded フロー + オフライン対応 | オフライン保存→復帰で自動処理 |
| **4** | 5/14 | WhisperKit 完全削除 + オンボーディング更新 | クリーンビルド通過 |
| **5** | 5/21 | 5層安全弁 + capリミットUI | 全層の動作テスト |
| **6** | 5/25 | Stripe Checkout / Portal / Webhook 接続 | Web課金フロー動作 |
| **7** | 5/28 | プライバシーポリシー（多言語）/ DPA / HECVAT テンプレ最終化 | 書面整備完了 |
| **8** | 6/01 | **B2C Pro 課金ON + B2B 営業開始** | ローンチ |

---

## 11. コストモニタリング体制

### 10.1 毎日見る指標（Deepgramダッシュボード + Supabaseダッシュボード）
- 前日の Deepgram minutes 合計
- 前日の Deepgram コスト $
- 新規ユーザー数
- セッション平均時間
- 月次cap到達ユーザー数

### 10.2 アラート（Slack通知）
- Deepgram残高 < $500 → **即補充**
- 1日のminutes > 過去7日平均の150% → 異常検知
- 単一ユーザーが1日に cap の3倍リクエスト → abuse疑い
- Edge Function エラー率 > 5% → 調査

### 10.3 月次レビュー
- プラン別の実稼働時間 vs cap
- 粗利率（実収益 - Deepgramコスト）
- cap到達ユーザーの転換率（Free → Pro）
- 解約率

---

## 12. リスクと対策

| リスク | 発生確率 | 対策 |
|-------|--------|------|
| Deepgram値上げ・仕様変更 | 中 | Edge Function層で抽象化、将来 AssemblyAI / Google STT 切替可能に設計 |
| GPT-4o Realtime が無料で同等品出す | 中〜高 | IEP特化UX・FERPA書類整備・先行利益で堀 |
| 単一ユーザーの大量消費 | 中 | 5層安全弁、+ abuse検知Slack |
| Deepgramアウトテージ | 低 | エラー時は録音継続 → 復帰後 Prerecorded で後処理 |
| 中国圏ユーザーで接続不可 | 中 | 既知。営業対象外として割り切る |
| Supabase障害 | 低 | アプリ側でretry、重大時はユーザー通知 |

---

## 13. やらないことリスト（意思決定済み）

- ❌ WhisperKit 維持・フォールバック（完全削除）
- ❌ 音声ファイルのクラウド保存（プライバシーとコストで不要）
- ❌ **Apple IAP 採用**（30%手数料回避、Stripe一本化）
- ❌ Deepgram Voice Agent API（$0.08/分、lecsy用途に不要で高額）
- ❌ Deepgram Diarization（1講師前提、+26%の価値なし）
- ❌ Deepgram Summarization（GPT-4o Mini で自前）
- ❌ Free tier のライブ字幕提供（原価赤字、Proへの転換フック）
- ❌ 端末間同時接続（abuseリスク高）
- ❌ Android版（Phase 3以降まで着手しない）

---

## 14. 次のアクション

1. **Deepgram営業にZDR契約問い合わせメール**（今週中）
2. Stripe ビジネスアカウント準備（LLC設立後即）
3. [[Stripe課金アーキテクチャ]] に沿ってWeb課金フロー実装
4. 既存 `Deepgram実装_単体版.md` のコード例を実プロジェクトに適用開始
5. プライバシーポリシー多言語版ドラフト（英・日）

---

*関連: [Deepgram実装_単体版](./Deepgram実装_単体版.md) / [Deepgramリアルタイム字幕実装](./Deepgramリアルタイム字幕実装.md) / [価格体系](../ビジネス/価格体系.md) / [プロダクト概要](../プロダクト/プロダクト概要.md)*
