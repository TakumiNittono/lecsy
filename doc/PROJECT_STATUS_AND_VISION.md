# Lecsy — プロジェクト現状・設計・将来ビジョン総合ドキュメント

最終更新: 2026-04-04

---

## 1. プロダクト概要

**Lecsy**は、大学の講義音声をオンデバイスAI（WhisperKit）で文字起こしするiOSアプリ。

| 項目 | 内容 |
|------|------|
| プラットフォーム | iOS (SwiftUI) |
| コア技術 | WhisperKit (オンデバイスWhisper) |
| バックエンド | Supabase (Auth, DB, Edge Functions) |
| 収益モデル | B2C無料 → Pro課金（AI要約）/ B2B（将来） |
| 対応言語 | 12言語（英語 + 11言語の多言語キット） |
| 価格 | 録音・文字起こしは完全無料 |

### コアバリュー
- **完全無料**: 録音・文字起こしに課金なし
- **完全ローカル**: 音声データはデバイス外に出ない
- **オフライン動作**: ネットワーク不要
- **プライバシーファースト**: アカウント登録不要で即使用可能

---

## 2. 現状のアーキテクチャ

### 2.1 アプリ構成

```
lecsyApp (エントリーポイント)
  ├─ OnboardingView (初回起動・5ページ)
  │   ├─ プライバシー同意
  │   ├─ 使い方説明
  │   ├─ 機能紹介
  │   ├─ 言語選択
  │   └─ AIモデル準備
  │
  └─ ContentView (タブナビゲーション)
      ├─ RecordView    — 録音・一時停止・ブックマーク
      ├─ LibraryView   — 検索・ソート・コース分類
      └─ SettingsView  — 言語設定・多言語キットDL
```

### 2.2 サービスレイヤー

| サービス | 役割 | パターン |
|---------|------|---------|
| `RecordingService` | 録音・Live Activity・クラッシュリカバリ | Singleton / ObservableObject |
| `TranscriptionService` | WhisperKitによる文字起こし | Singleton / ObservableObject |
| `AudioPlayerService` | 再生・可変速度・シーク | Singleton / ObservableObject |
| `LectureStore` | 講義データCRUD・JSON永続化 | Singleton / ObservableObject |
| `StudyStreakService` | 学習ストリーク・週間統計 | Singleton / ObservableObject |
| `ReportService` | バグレポート（メール） | Singleton |
| `AppLanguageService` | UI言語（英語のみ） | Singleton |

### 2.3 データモデル

```
Lecture
├── id: UUID
├── title: String
├── createdAt: Date
├── duration: TimeInterval
├── audioFileName: String?
├── transcriptText: String?
├── transcriptSegments: [TranscriptionSegment]?
├── transcriptStatus: TranscriptionStatus
├── language: TranscriptionLanguage
├── bookmarks: [LectureBookmark]
├── courseName: String?
└── lastPlaybackPosition: TimeInterval?
```

### 2.4 データフロー

```
録音開始 → RecordingService（AVAudioRecorder + Live Activity）
  → 停止 → TitleInputSheet
  → LectureStore.addLecture()
  → TranscriptionService.transcribe()（チャンク分割・部分更新）
  → LectureStore.updateLecture()
  → Notification → LibraryView自動遷移
```

### 2.5 ストレージ

| 種類 | 方式 | 場所 |
|------|------|------|
| 講義メタデータ | JSON (lectures.json) | Documents/ |
| バックアップ | JSON (lectures_backup.json) | Documents/ |
| 音声ファイル | M4A (AAC 64kbps) | Documents/ |
| ユーザー設定 | UserDefaults | 標準 |
| AIモデル | CoreML (.mlmodelc) | Bundle / Cache |

書き込みはアトミック（temp → rename）。プライマリ破損時はバックアップから自動復旧。

---

## 3. 機能一覧と完成度

### 3.1 実装済み機能

| 機能 | 完成度 | 詳細 |
|------|--------|------|
| 音声録音 | 100% | 一時停止/再開、バックグラウンド録音、最大100分 |
| Live Activity | 100% | ロック画面での録音状態表示（iOS 17+） |
| AI文字起こし | 95% | 12言語、2分チャンク + 3秒オーバーラップ、部分更新 |
| ライブラリ管理 | 95% | 検索（デバウンス付き）、5種ソート、コース分類、時系列グループ |
| 音声再生 | 90% | 0.75x〜2.0x可変速度、シーク、再生位置記憶 |
| ブックマーク | 95% | 録音中追加、ラベル編集、タップでジャンプ、コンテキストメニュー |
| 同期トランスクリプト | 95% | 時間同期表示、アクティブセグメントハイライト、バイナリサーチ |
| エクスポート | 95% | テキスト/Markdown/PDF（タイムスタンプ付き） |
| オンボーディング | 90% | 5ページ、プログレスバー、AIモデルプリロード |
| クラッシュリカバリ | 95% | 録音状態のUserDefaults永続化、孤立ファイル回収 |
| 低音量警告 | 100% | 5秒以上の低レベル検知 |
| ディスク容量チェック | 100% | 開始時100MB + 録音中30秒毎10MB |
| メモリ警告対応 | 100% | メータリング停止で録音継続 |
| レビュー依頼 | 100% | 5回録音完了後にSKStoreReviewController |
| バグレポート | 100% | カテゴリ別メール送信（デバイス情報付き） |

### 3.2 未実装 / 削除済み機能

| 機能 | 状態 | 備考 |
|------|------|------|
| ユーザー認証（Apple Sign-In） | 削除済み | AuthService, KeychainService削除 |
| クラウド同期 | 削除済み | SyncService削除 |
| B2B組織機能（iOS側） | 削除済み | Organization, OrgGlossary等のView削除 |
| Pro課金（iOS側） | 未接続 | Supabase側にStripe連携あるがiOS未実装 |
| AI要約 | バックエンドのみ | Edge Function実装済み、iOS未接続 |

---

## 4. 品質評価

### 4.1 総合スコア: 82/100

| 観点 | スコア | 評価 |
|------|--------|------|
| 機能完成度 | 90/100 | B2Cとして必要十分 |
| コード品質 | 78/100 | 堅牢だがViewModelレイヤー欠如 |
| UI/UX | 85/100 | 一貫したデザイン、適切なアニメーション |
| 堅牢性 | 85/100 | クラッシュリカバリ・防御的コーディングが優秀 |
| テスト | 70/100 | 119ユニットテスト実装済み（モデル・ストア・ユーティリティ） |
| セキュリティ | 85/100 | バックエンドRLS徹底、ログマスキング |

### 4.2 テストカバレッジ

| テストファイル | テスト数 | 対象 |
|---------------|---------|------|
| LectureTests.swift | 21 | Lecture, LectureBookmark |
| TranscriptionResultTests.swift | 13 | TranscriptionSegment, token stripping |
| TranscriptionLanguageTests.swift | 13 | 12言語の全プロパティ |
| TranscriptionStatusTests.swift | 5 | ステータスenum |
| LectureStoreTests.swift | 21 | CRUD, 検索, 永続化, バックアップ復旧 |
| ErrorMessagesTests.swift | 12 | エラーメッセージ変換 |
| AppLoggerTests.swift | 15 | maskSensitive, LogCategory |
| MiscModelTests.swift | 11 | ReportCategory, AppLanguage |
| LecsyWidgetAttributesTests.swift | 8 | Widget ContentState |
| **合計** | **119** | **全パス** |

### 4.3 既知の技術的課題

| 課題 | 優先度 | 詳細 |
|------|--------|------|
| `saveLectures()`の重複 | 低 | `saveLectures()`と`saveLecturesReturningSuccess()`がほぼ同一コード |
| `formatDuration`の重複 | 低 | RecordView, RecoverySheet, Lectureに3つの独自実装 |
| RecordViewの肥大化 | 中 | 783行。UIとビジネスロジックが混在 |
| JSONストレージのスケーラビリティ | 低 | 100件超で要検討。現状は問題なし |
| `try?`でのエラー握りつぶし | 低 | 音声ファイル削除時。ストレージリークの可能性は低い |

---

## 5. バックエンド（Supabase）

### 5.1 データベーススキーマ

**個人ユーザー向け**:
- `transcripts` — ユーザーの文字起こしデータ
- `summaries` — AI要約（Pro機能）
- `subscriptions` — 課金ステータス
- `usage_logs` — AI使用量追跡
- `rate_limits` — API レート制限
- `reports` — バグレポート

**B2B向け**:
- `organizations` — 組織管理（language_school/university_iep/college/corporate）
- `organization_members` — メンバー（owner/admin/teacher/student）
- `organization_invites` — 招待管理
- `org_glossaries` — 組織カスタム用語集
- `org_ai_usage_logs` — B2B AI使用量

### 5.2 Edge Functions

| 関数 | 用途 | 状態 |
|------|------|------|
| `save-transcript` | iOS→Supabaseの文字起こし保存 | 実装済み |
| `summarize` | AI要約生成（OpenAI） | 実装済み |
| `org-ai-assist` | B2B向けAI（多言語要約・用語集生成） | 実装済み |
| `submit-report` | バグレポート保存 | 実装済み |
| `stripe-webhook` | Stripe決済イベント処理 | 実装済み |
| `delete-account` | アカウント削除（GDPR） | 実装済み |

### 5.3 iOS連携の現状

**接続されている**: なし（Auth/Sync削除済み）
**バックエンドだけ存在**: 全Edge Functions、全DBスキーマ

→ 現在のiOSアプリは**完全にローカルで完結するB2Cアプリ**。クラウド機能は一切使用していない。

---

## 6. ビジネス現状

### 6.1 数値

| 指標 | 値 |
|------|-----|
| ダウンロード数 | 約200 |
| 目標 | 1,000+ DL（OPT開始前） |
| 広告予算 | 月3万円（$200-300） |
| 有料版ローンチ予定 | 2026年7月（OPT開始後） |
| 競合との差別化 | 完全無料 + オンデバイスAI + プライバシー |

### 6.2 マーケティング戦略

**ASO（App Store最適化）**:
- キーワード: lecture, transcription, AI, whisper, record, notes, study
- スクリーンショット最適化（録音→文字起こし→ライブラリのストーリー）
- App Preview動画
- 目標: 4.5星以上

**広告配分**:
| チャネル | 月額 | 期待効果 |
|---------|------|---------|
| Apple Search Ads | $150 | CPI $2-3で月50-75DL |
| TikTok Spark Ads | $75 | StudyTok認知拡大 |
| マイクロインフルエンサー | $75 | 小規模クリエイターコラボ |

---

## 7. 将来ビジョン

### 7.1 短期（2026年4月〜6月）— OPT開始前

**目標**: B2Cアプリの完成度を最大化し、1,000DL達成

| アクション | 詳細 |
|-----------|------|
| 検索強化 | セグメント単位検索（キーワード箇所にジャンプ） |
| 15秒スキップボタン | 講義アプリの必須UX |
| ASO最適化 | キーワード・スクリーンショット・App Preview動画 |
| レビュー促進 | App Storeの星4.5+維持 |
| バグ修正・安定化 | テスト追加、エッジケース対応 |

### 7.2 中期（2026年6月〜12月）— OPT + LLC設立

**目標**: LLC設立、Pro課金開始、B2B営業開始

| マイルストーン | 時期 | 内容 |
|-------------|------|------|
| LLC設立 | 6月 | フロリダ州でLecsy LLC設立 |
| Pro課金ローンチ | 7月 | AI要約・Exam Mode（月$4.99 or $9.99） |
| クラウド同期復活 | 7-8月 | Apple Sign-In + iCloud or Supabase同期 |
| B2B営業開始 | 8月〜 | フロリダの語学学校を中心にアプローチ |
| Web管理画面 | 9-10月 | B2B組織管理ダッシュボード |

### 7.3 B2B戦略

**ターゲット**:
- 語学学校（ESL/EFL）
- 大学のIEP（Intensive English Program）
- 企業研修プログラム

**プラン設計**:

| プラン | 月額 | 席数 | AI制限 |
|--------|------|------|--------|
| Starter | $49/月 | 25席 | 10回/日 |
| Growth | $149/月 | 100席 | 50回/日 |
| Enterprise | カスタム | 無制限 | 200回/日 |

**B2B固有機能**（バックエンド実装済み）:
- 組織管理（role: owner/admin/teacher/student）
- 多言語クロスサマリー（日→英、英→日など）
- 組織カスタム用語集
- 使用量アナリティクス

**営業拠点**: フロリダ州オカラ（車あり、州内どこでも訪問可能）

### 7.4 長期（2027年〜）

| 方向性 | 内容 |
|--------|------|
| Apple Watch対応 | 録音の開始/停止をWatchから |
| オンデバイスAI要約 | Apple Intelligence / CoreML活用で無料要約 |
| Android版 | Flutter or KMPで展開 |
| LMS連携 | Canvas, Moodle等との統合 |
| 大学パートナーシップ | 学校単位の一括導入 |

---

## 8. 技術的改善ロードマップ

### Phase 1: コード品質向上（現在進行中）

- [x] ユニットテスト119件実装
- [ ] `saveLectures()`の重複解消
- [ ] `formatDuration`の共通化
- [ ] RecordViewからビジネスロジックを分離（ViewModel導入）

### Phase 2: ユーザー体験向上

- [ ] セグメント単位の検索（キーワード箇所にジャンプ）
- [ ] 15秒戻る/進むボタン
- [ ] タグ/フォルダ機能（courseNameの拡張）
- [ ] Undo削除のタイマーを10-15秒に延長

### Phase 3: クラウド連携復活（Pro課金に必要）

- [ ] 認証方針の決定（Apple Sign-In vs パスワードレス）
- [ ] テキストのみのクラウド同期（音声はローカル維持）
- [ ] Pro課金（StoreKit 2）
- [ ] AI要約のiOS UI

### Phase 4: B2Bフロントエンド

- [ ] iOS組織機能の再実装
- [ ] Web管理画面（Next.js）
- [ ] 管理者ダッシュボード
- [ ] 招待・メンバー管理UI

---

## 9. ディレクトリ構成

```
lecsy/
├── lecsy/                          # メインiOSアプリ
│   ├── lecsyApp.swift             # エントリーポイント
│   ├── ContentView.swift          # タブナビゲーション
│   ├── Info.plist                 # アプリ設定
│   ├── Models/                    # データモデル (6ファイル)
│   ├── Services/                  # ビジネスロジック (7ファイル)
│   ├── Views/                     # SwiftUI View
│   │   ├── Home/                  # RecordView
│   │   ├── Library/               # LibraryView, LectureDetailView
│   │   ├── Settings/              # SettingsView
│   │   ├── Onboarding/            # OnboardingView
│   │   └── Components/            # 再利用コンポーネント
│   ├── Utils/                     # Logger, ErrorMessages
│   └── Assets.xcassets/           # アイコン・画像
│
├── lecsyTests/                    # ユニットテスト (9ファイル, 119テスト)
├── lecsyUITests/                  # UIテスト
├── LecsyWidgetExtension/          # Live Activity Widget
│
├── supabase/                      # バックエンド
│   ├── migrations/                # DBマイグレーション (12ファイル)
│   ├── functions/                 # Edge Functions (6関数)
│   └── seed.sql                   # テストデータ
│
├── doc/                           # 設計ドキュメント
│   ├── 00_README.md               # プロジェクト概要
│   ├── 01_要件定義書.md            # 要件定義
│   ├── 02_技術仕様書.md            # 技術仕様
│   ├── 03_iOS設計書.md            # iOS設計
│   ├── 04_Supabase設計書.md       # バックエンド設計
│   ├── 05_Web設計書.md            # Web設計
│   ├── 06_課金設計書.md            # 課金設計
│   ├── 07_実装ロードマップ.md      # 実装計画
│   └── 08_LPコピー.md             # ランディングページ
│
├── B2B/                           # B2B戦略・営業資料
│   ├── 01_MARKET_RESEARCH.md
│   ├── 02_SALES_STRATEGY.md
│   ├── 03_PROSPECT_LIST.md
│   ├── 04_FINANCIAL_MODEL.md
│   ├── 05_FEATURE_ROADMAP.md
│   ├── 06_PITCH_MATERIALS.md
│   ├── 07_ACTION_PLAN.md
│   └── B2B設計/                   # B2B技術設計
│
└── GROWTH_STRATEGY.md             # B2C成長戦略
```

---

## 10. 重要な設計判断の記録

| 判断 | 理由 | 日付 |
|------|------|------|
| オンデバイスAI（WhisperKit）採用 | プライバシーファースト、オフライン対応、差別化 | 2026-01 |
| JSON永続化を選択 | MVP速度優先、50件程度なら十分な性能 | 2026-01 |
| Auth/Sync機能の削除 | B2Cの核心機能に集中、クラウド不要 | 2026-03 |
| 多言語小モデルをバンドル | 初回ダウンロード不要で即使用可能 | 2026-02 |
| B2B iOS UIの削除 | バックエンドのみ先行、フロント実装は営業確定後 | 2026-04 |
| Swift Testing採用 | Xcode 16ネイティブ、XCTestより簡潔 | 2026-04 |
| ローカルファーストの方針確定 | クラウドは差別化にならない。ローカル完結がlecsyの強み | 2026-04 |

---

## 11. 競合分析

| アプリ | 価格 | AI | オフライン | 差別化ポイント |
|--------|------|-----|----------|--------------|
| **Lecsy** | 無料 | オンデバイス | 完全対応 | 無料 + プライバシー |
| Otter.ai | $16.99/月 | クラウド | 不可 | リアルタイム文字起こし |
| Notta | $14.99/月 | クラウド | 不可 | 多言語翻訳 |
| AudioPen | $9.99/月 | クラウド | 不可 | AI要約特化 |
| Rev | 従量課金 | クラウド | 不可 | プロ品質 |

**Lecsyの最大の武器**: 競合が全て月額課金の中で、完全無料 + オフライン + プライバシー。学生にとって最もアクセスしやすい選択肢。

---

*このドキュメントは、プロジェクトの全体像を1ファイルで把握するための統合リファレンスです。*
*個別の詳細は doc/ および B2B/ 配下の各ドキュメントを参照してください。*
