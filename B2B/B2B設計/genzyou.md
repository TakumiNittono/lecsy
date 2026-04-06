# lecsy 現状分析 & B2B/B2C分離計画

> 最終更新: 2026-04-03

---

## 1. 分離の方針

### 決定事項

| 項目 | B2B（現lecsy → 改修） | B2C（新規アプリ） |
|------|----------------------|------------------|
| 対象言語 | **英語専門** | 多言語（12言語） |
| プラットフォーム | iOS + Web管理画面 | iOSのみ（Webほぼ不要） |
| バックエンド | Supabase（org機能フル活用） | ローカル中心（Supabase最小限） |
| ターゲット | 米語学学校・大学IEP | 個人の学生（グローバル） |
| 課金 | 組織単位（per-seat） | 個人（Freemium） |

### なぜ分離するのか

1. **語学学校のオーナーがデモを見た時に「うちのためのツール」と即座に感じる必要がある** — 現状は「学生用アプリに管理機能がついてる」印象
2. **B2Cの多言語対応とB2Bの英語特化は相反する** — 1アプリに詰めるとどちらも中途半端
3. **App Storeで「lecsy for Business」として別に存在** → B2B顧客が検索で見つけやすい
4. **営業デモ時に管理者アプリだけ見せられる**（学生向けUIが邪魔にならない）

### なぜB2Bを英語専門にするのか

1. **営業メッセージがシャープになる** — 「アメリカの語学学校で英語を学ぶ留学生向け」と言い切れる
2. **OPTの営業先はアメリカの語学学校・大学IEP** → 学生は全員英語を学んでいる
3. **WhisperKitの英語モデルが最も精度が高い** → 品質保証しやすい
4. **12言語のメンテナンスコストがゼロになる** → UIも英語固定、ローカライズ不要
5. **Glossary・Cross-Summaryを英語学習に最適化できる**
6. **多言語はB2C側の差別化として活かせる** → 棲み分けが明確

---

## 2. 現状のアーキテクチャ（分離前）

### 2.1 全体構成

```
lecsy/
├── lecsy/              # iOS アプリ（Swift/SwiftUI）
│   ├── Models/         # 8ファイル, 566行
│   ├── Views/          # 15ファイル, 5,151行
│   ├── Services/       # 9ファイル, 4,206行
│   └── (計 ~9,900行)
├── web/                # Webアプリ（Next.js 14 / TypeScript）
│   ├── app/            # 21ページ, 4,807行
│   ├── components/     # 28コンポーネント, 3,435行
│   └── (計 ~9,850行)
├── supabase/
│   ├── migrations/     # 12ファイル, 910行
│   └── functions/      # 7 Edge Functions, 1,094行
└── B2B/                # 戦略ドキュメント, 2,774行
```

**合計: 127ファイル, 約26,500行**

### 2.2 iOS アプリ詳細

#### Models（8ファイル）

| ファイル | 行数 | 分類 | 分離先 |
|---------|------|------|--------|
| `User.swift` | 21 | 共通 | 両方 |
| `Organization.swift` | 132 | B2B | B2B |
| `Lecture.swift` | 171 | 共通 | 両方 |
| `TranscriptionLanguage.swift` | 133 | B2C（多言語） | B2C → B2Bは英語のみに簡略化 |
| `TranscriptionStatus.swift` | 32 | 共通 | 両方 |
| `TranscriptionResult.swift` | 27 | 共通 | 両方 |
| `LecsyWidgetAttributes.swift` | 49 | B2C | B2C |
| `AppLanguage.swift` | 22 | B2C（多言語） | B2Cのみ |

#### Views（15ファイル）

| ファイル | 行数 | 分類 | 分離先 |
|---------|------|------|--------|
| **Auth/** | | | |
| `LoginView.swift` | 273 | 共通 | 両方（B2Bはorg参加フロー追加） |
| **Home/** | | | |
| `RecordView.swift` | 665 | 共通 | 両方 |
| **Library/** | | | |
| `LibraryView.swift` | 587 | 共通 | 両方（B2Bはorg視点に改修） |
| `LectureDetailView.swift` | 829 | 共通 | 両方 |
| **Organization/** | | | |
| `CrossSummaryView.swift` | 215 | B2B | B2Bのみ |
| `OrgGlossaryView.swift` | 200 | B2B | B2Bのみ |
| **Onboarding/** | | | |
| `OnboardingView.swift` | 437 | B2C | B2C → B2Bは別オンボーディング |
| **Settings/** | | | |
| `SettingsView.swift` | 347 | 共通 | 両方 |
| **Components/** | | | |
| `AIConsentView.swift` | 87 | 共通 | 両方 |
| `AudioWaveformView.swift` | 51 | 共通 | 両方 |
| `CopyButton.swift` | 38 | 共通 | 両方 |
| `LanguagePickerSheet.swift` | 50 | B2C（多言語） | B2Cのみ |
| `ReportSheet.swift` | 136 | 共通 | 両方 |
| `SyncedTranscriptView.swift` | 115 | 共通 | 両方 |
| `TitleInputSheet.swift` | 139 | 共通 | 両方 |

#### Services（9ファイル）

| ファイル | 行数 | 分類 | 分離先 |
|---------|------|------|--------|
| `TranscriptionService.swift` | 1,070 | 共通 | 両方（B2Bは英語モデルのみ） |
| `RecordingService.swift` | 854 | 共通 | 両方 |
| `AuthService.swift` | 1,605 | 共通 | 両方（B2BはSAML/SSO追加） |
| `SyncService.swift` | 469 | 共通 | 両方（B2Bはorg紐付け強化） |
| `LectureStore.swift` | 217 | 共通 | 両方 |
| `OrganizationService.swift` | 422 | B2B | B2Bのみ |
| `AudioPlayerService.swift` | 160 | 共通 | 両方 |
| `ReportService.swift` | 127 | 共通 | 両方 |
| `StudyStreakService.swift` | 138 | B2C | B2Cのみ |
| `KeychainService.swift` | 72 | 共通 | 両方 |
| `AppLanguageService.swift` | 33 | B2C（多言語） | B2Cのみ |

### 2.3 Web アプリ詳細

#### ページ（21ページ）

**B2B管理画面（残す・強化）:**
| パス | 行数 | 用途 |
|-----|------|------|
| `/org/[slug]/page.tsx` | 382 | 組織ダッシュボード |
| `/org/[slug]/members/page.tsx` | 94 | メンバー管理 |
| `/org/[slug]/settings/page.tsx` | 36 | 組織設定 |
| `/org/[slug]/usage/page.tsx` | - | 利用統計 |
| `/org/[slug]/ai/page.tsx` | 113 | AI機能（Glossary, Cross-Summary） |
| `/org/new/page.tsx` | - | 組織作成 |
| `/admin/page.tsx` | 213 | スーパー管理者 |

**B2C個人向け（分離 or 削除）:**
| パス | 行数 | 判断 |
|-----|------|------|
| `/app/page.tsx` | 284 | B2Bでは不要 → 削除 |
| `/app/t/[id]/page.tsx` | 288 | B2Bではorg経由のみ → 改修 |
| `/app/reports/page.tsx` | 101 | 両方で使用 → 残す |

**マーケティング（B2B用に書き換え）:**
| パス | 行数 | 判断 |
|-----|------|------|
| ホームページ | 785 | B2B向けLPに全面改修 |
| SEOページ×4 | ~1,200 | B2B向けに書き換え or 削除 |
| `/login/page.tsx` | 260 | 残す |
| `/privacy/`, `/terms/` | 533 | B2B利用規約に更新 |

#### APIルート（14エンドポイント）

**B2B（残す・強化）: 9エンドポイント**
- `/api/org/` — 組織一覧
- `/api/org/activate-membership/` — メンバーシップ有効化
- `/api/org/[slug]/` — 組織CRUD
- `/api/org/[slug]/members/[id]/` — メンバー管理
- `/api/org/[slug]/invites/` — 招待管理
- `/api/org/[slug]/usage/` — 利用統計
- `/api/org/[slug]/ai/glossary/` — 組織用語集
- `/api/org/[slug]/ai/cross-summary/` — クロスサマリー
- `/api/reports/` — レポート

**B2C or 共通（判断必要）: 5エンドポイント**
| エンドポイント | 判断 |
|---------------|------|
| `/api/auth/google/` | 残す（B2Bでも使用） |
| `/api/transcripts/[id]/` | 残す（org経由アクセスに改修） |
| `/api/transcripts/[id]/title/` | 残す |
| `/api/create-checkout-session/` | B2B課金に改修（per-seat） |
| `/api/create-portal-session/` | 残す（org billing用） |

#### コンポーネント（28コンポーネント）

**B2B（残す）: 13コンポーネント**
- `OrgSidebar.tsx`, `OrgSwitcher.tsx`, `OrgSettings.tsx`
- `MembersList.tsx`, `BulkInviteUpload.tsx`, `NewOrgForm.tsx`
- `UsageStats.tsx`, `Toast.tsx`, `ToastProvider.tsx`
- `SearchBar.tsx`, `EditTitleButton.tsx`, `EditTitleForm.tsx`, `DeleteForm.tsx`

**B2C or 不要（削除候補）: 15コンポーネント**
| コンポーネント | 判断 |
|---------------|------|
| `TranscriptList.tsx` | 改修（org視点に） |
| `AISummaryButton.tsx` | 残す（B2Bでも使用） |
| `ExamModeButton.tsx` | B2C寄り → 検討 |
| `PrintButton.tsx` | 残す |
| `CopyButton.tsx` | 残す |
| `ProCardUpgradeButton.tsx` | 削除（B2Bは個人課金なし） |
| `UpgradeButton.tsx` | 削除 |
| `ProFeatureButton.tsx` | 削除 |
| `SubscriptionCard.tsx` | B2B課金に改修 |
| `ManageSubscriptionButton.tsx` | B2B billing用に改修 |
| `ComparisonTable.tsx` | B2B pricing用に改修 |
| `CTASection.tsx` | B2B向けに改修 |
| `FAQSection.tsx` | B2B向けに改修 |
| `SEOFooter.tsx` | 残す |
| `SEOPageLayout.tsx` | 残す |

### 2.4 Supabase バックエンド

#### テーブル構成

**共通テーブル（両方で使用）:**
| テーブル | 用途 |
|---------|------|
| `transcripts` | 文字起こしデータ |
| `summaries` | AI要約データ |
| `usage_logs` | 利用ログ |
| `rate_limits` | API制限 |
| `reports` | バグレポート |

**B2B専用テーブル:**
| テーブル | 用途 |
|---------|------|
| `organizations` | 組織マスタ（type, plan, max_seats） |
| `organization_members` | メンバー（role: owner/admin/teacher/student） |
| `organization_invites` | 招待トークン（7日有効期限） |
| `org_ai_features` | 組織AI機能（glossary, cross-summary） |
| `org_ai_usage_logs` | 組織別AI利用ログ |

**B2C専用テーブル:**
| テーブル | 用途 |
|---------|------|
| `subscriptions` | 個人サブスクリプション |

#### Edge Functions（7関数）

| 関数 | 行数 | 分類 |
|-----|------|------|
| `save-transcript` | 97 | 共通 |
| `summarize` | 267 | 共通（B2Bはorg quota適用） |
| `org-ai-assist` | 311 | B2B専用 |
| `stripe-webhook` | 176 | 共通（B2Bはorg billing追加） |
| `submit-report` | 97 | 共通 |
| `delete-account` | 56 | 共通 |
| `_shared/cors.ts` | 90 | 共通 |

### 2.5 多言語サポート（現状）

現在12言語に対応（B2Cで維持、B2Bでは英語のみに）:

| 言語 | コード | モデル | B2B | B2C |
|------|--------|--------|-----|-----|
| English | en | バンドル済 | ✅ | ✅ |
| Japanese | ja | DL必要 | ❌ | ✅ |
| Korean | ko | DL必要 | ❌ | ✅ |
| Chinese | zh | DL必要 | ❌ | ✅ |
| Spanish | es | DL必要 | ❌ | ✅ |
| French | fr | DL必要 | ❌ | ✅ |
| German | de | DL必要 | ❌ | ✅ |
| Portuguese | pt | DL必要 | ❌ | ✅ |
| Italian | it | DL必要 | ❌ | ✅ |
| Russian | ru | DL必要 | ❌ | ✅ |
| Arabic | ar | DL必要 | ❌ | ✅ |
| Hindi | hi | DL必要 | ❌ | ✅ |

### 2.6 録音→文字起こしパイプライン

```
1. 録音 (RecordingService)
   ├─ AVAudioRecorder (.wav形式)
   ├─ リアルタイム波形表示（30ポイント履歴）
   ├─ バックグラウンド対応
   ├─ 一時停止/再開（正確な再生時間計算）
   ├─ クラッシュリカバリー（UserDefaults永続化）
   └─ 最大100分

2. 文字起こし (TranscriptionService)
   ├─ WhisperKit（オンデバイス）
   ├─ チャンク戦略:
   │  ├─ < 3分: 全体一括処理
   │  └─ >= 3分: 2分チャンク + 3秒オーバーラップ
   ├─ チャンクごとにタイムアウト2分
   └─ セグメント結合 + タイムスタンプ生成

3. 同期 (SyncService)
   ├─ Supabase Edge Function経由
   ├─ オフラインキューイング + リトライ
   └─ Lecture.savedToWeb + webTranscriptId更新

4. AI処理 (Supabase Edge Functions)
   ├─ summarize: GPT-4 Turbo要約（Pro機能）
   ├─ org-ai-assist: Cross-Summary / Glossary（B2B機能）
   └─ レート制限: 20回/日, 400回/月
```

---

## 3. 分離後のアーキテクチャ

### 3.1 B2Bアプリ（現lecsy → 改修）

```
lecsy-business/
├── iOS App
│   ├── 英語専門（モデルDL不要、バンドル済のみ）
│   ├── org参加フロー付きオンボーディング
│   ├── 教師/管理者向けダッシュボード（新規）
│   ├── 学生の学習状況一覧（新規）
│   ├── Cross-Summary & Glossary（既存強化）
│   └── 録音→文字起こし→同期（既存流用）
│
├── Web管理画面
│   ├── /org/[slug]/ — 組織ダッシュボード
│   ├── /org/[slug]/members/ — メンバー管理
│   ├── /org/[slug]/usage/ — 利用統計
│   ├── /org/[slug]/ai/ — AI機能
│   ├── /org/[slug]/settings/ — 組織設定
│   ├── /admin/ — スーパー管理者
│   └── B2B向けランディングページ
│
└── Supabase（共有）
    ├── organizations, org_members, org_invites
    ├── transcripts（org_id紐付け追加）
    ├── org_ai_features
    └── org用Stripe billing
```

**B2Bで削除するもの:**
- `LanguagePickerSheet.swift` — 言語選択不要（英語固定）
- `AppLanguageService.swift` — アプリ言語切替不要
- `AppLanguage.swift` — 同上
- `LecsyWidgetAttributes.swift` — 個人向けウィジェット不要
- `StudyStreakService.swift` — 個人のストリーク不要
- `OnboardingView.swift` — B2B用に全面書き換え
- `ProCardUpgradeButton.tsx` — 個人課金UI
- `UpgradeButton.tsx` — 個人課金UI
- `ProFeatureButton.tsx` — 個人課金UI
- SEOランディングページ×4 — B2B用に書き換え
- 個人向けマーケティングコピー

**B2Bで追加するもの:**
- 教師ダッシュボード（学生一覧、進捗、出席）
- 管理者ダッシュボード（利用統計、請求、設定）
- org参加オンボーディング（招待トークン → 自動参加）
- SAML/SSO認証（Phase 3）
- LTI 1.3統合（Canvas/Blackboard、Phase 4）
- ADAコンプライアンスレポート（Phase 3）

### 3.2 B2Cアプリ（新規）

```
lecsy/
├── iOS App（新規、軽量）
│   ├── 多言語対応（12言語）
│   ├── 録音→文字起こし→保存（ローカル中心）
│   ├── AI要約（Pro課金）
│   ├── シンプルなUI（学生向け）
│   └── Web同期は最小限
│
├── Web（最小限）
│   ├── ランディングページ（1ページ）
│   ├── ログイン（Web版transcript閲覧用）
│   └── プライバシーポリシー / 利用規約
│
└── Supabase（共有 or 独立）
    ├── transcripts（個人のみ）
    ├── summaries
    ├── subscriptions（個人課金）
    └── usage_logs
```

**B2Cのコア機能:**
1. 録音（RecordingService流用）
2. オンデバイス文字起こし（TranscriptionService流用、全12言語）
3. ローカルライブラリ管理（LectureStore流用）
4. AI要約（個人Pro課金、Freemium）
5. 学習ストリーク（StudyStreakService流用）

**B2Cで不要なもの:**
- Organization関連の全機能
- メンバー管理、招待、ロール
- Cross-Summary、Glossary
- 管理者ダッシュボード
- 組織課金

---

## 4. リポジトリ構成案

```
# 案A: モノレポ（推奨）
lecsy/
├── apps/
│   ├── b2b-ios/          # B2B iOSアプリ（現lecsyベース）
│   ├── b2b-web/          # B2B Web管理画面（現webベース）
│   ├── b2c-ios/          # B2C iOSアプリ（新規）
│   └── b2c-web/          # B2C ランディングページ（最小限）
├── packages/
│   └── shared/           # 共有コード（録音、文字起こし、認証）
├── supabase/             # 共有バックエンド
└── B2B/                  # 戦略ドキュメント

# 案B: リポジトリ分離
lecsy-business/           # B2Bリポジトリ（iOS + Web + Supabase）
lecsy/                    # B2Cリポジトリ（iOS + 最小Web）
```

---

## 5. 実行優先順位

### Phase 0: 分離準備（1週間）
- [ ] リポジトリ構成決定（モノレポ or 分離）
- [ ] 共有コードの特定とモジュール化
- [ ] B2BアプリのBundle ID / App Store Connect設定

### Phase 1: B2Bアプリ英語専門化（1-2週間）
- [ ] 多言語コード削除（TranscriptionLanguage簡略化）
- [ ] LanguagePickerSheet削除
- [ ] WhisperKit英語モデルのみバンドル
- [ ] UI英語固定
- [ ] 個人向け課金UI削除
- [ ] B2B向けオンボーディング作成

### Phase 2: B2B管理機能強化（2-3週間）
- [ ] 教師ダッシュボード（iOS）
- [ ] 管理者ダッシュボード（iOS）
- [ ] org参加フロー改善
- [ ] Web管理画面のLP改修

### Phase 3: B2Cアプリ新規作成（2-3週間）
- [ ] Xcodeプロジェクト新規作成
- [ ] 共有コード（録音・文字起こし）の移植
- [ ] 多言語UI実装
- [ ] ローカルファースト設計
- [ ] App Store申請

### Phase 4: 営業開始と並行改善
- [ ] Florida語学学校への営業開始
- [ ] フィードバックに基づくB2B改善
- [ ] B2CのApp Store最適化（ASO）
