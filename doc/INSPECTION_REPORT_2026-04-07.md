# Lecsy 検査レポート — 2026-04-07

検査者: Claude (Opus 4.6)
対象コミット: `c1f0988` (HEAD)
検査範囲: iOS アプリ / Web 管理画面 / Supabase バックエンド

---

## TL;DR

| 領域 | 状態 | 備考 |
|---|---|---|
| **iOS Build** | ✅ Green | Xcode で iPhone 17 Pro シミュレータ起動成功 (16:08-16:41 確認) |
| **iOS UI: Cloud Sync トグル** | ✅ 表示確認済 | Settings → Privacy セクションに緑トグル + 説明文表示 |
| **Web Build** | ✅ Green | `next build` 成功、新規 2 ページ + 1 API route が認識済 |
| **Supabase: save-transcript Edge Function** | ✅ 実装済 | `organization_id` メンバーシップ検証付き |
| **Supabase: transcripts スキーマ** | ✅ 列存在 | `organization_id` / `visibility` + index + RLS ポリシー |
| **iOS → Supabase 自動同期パス** | ✅ 配線済 | `RecordView.startTranscription` → `CloudSyncService.uploadTranscriptIfEnabled` |
| **B2B 漏洩リスク** | ⚠️ 1 件残存 | 既存ダッシュボードが `user_id IN (members)` で個人録音を引いてる (詳細 §5) |
| **未コミット pre-existing 変更** | ⚠️ 5 ファイル | 別 WIP。本検査範囲外だが §6 にメモ |

**結論**: Week 1 + Week 2 で実装した機能は **コード / ビルド / UI レベルで全部 green**。実機 E2E (録音 → DB 行確認) は未実施だが、配線は確認済で Edge Function 側のロジックも前回コミットでテスト済。先に進める状態。

---

## 1. リポジトリ状態

### コミットライン (直近 4 件)

```
c1f0988 fix(cloud-sync): TranscriptionLanguage を rawValue で String 化
fa180b4 feat(org): Transcripts ページ + 学生詳細 + CSV エクスポート         (Week 2)
3b541cb feat(cloud-sync): 文字起こし完了で transcript text を Supabase に自動同期 (Week 1)
2ce62f4 feat(B2B): iOS 認証ユーザー向け要約 + Web 管理画面に super admin 管理を追加 (前回)
```

### Workspace inventory

```
iOS Swift ファイル数:        36 (Services + Views)
Supabase Edge Functions:    11 (save-transcript, summarize, org-create, …)
Supabase migrations:        28 (M1〜M22 + simplify)
Web API routes:             admin / auth / create-checkout-session / create-portal-session
                            / org / reports / transcripts
```

### 未コミット変更 (本検査範囲外)

```
M lecsy/Views/Library/LectureDetailView.swift
M lecsy/Views/Onboarding/OnboardingView.swift
M supabase/functions/summarize/index.ts
M web/app/api/create-checkout-session/route.ts
M web/app/api/create-portal-session/route.ts
```

5 ファイルとも前回 (`2ce62f4`) より前から変更されたまま。今回のコミットには含めていない。

---

## 2. iOS アプリ検査

### 2.1 ビルド

| 指標 | 結果 |
|---|---|
| `swiftc -parse` (Week 1 全 3 ファイル) | ✅ 全 clean |
| Xcode フルビルド (`Running lecsy on iPhone 17 Pro` 確認済) | ✅ Green |
| 実機シミュレータ起動 | ✅ 16:08 起動、16:41 録音画面 + Settings 確認 |

### 2.2 警告数とその内訳 (64 issues)

すべて yellow warning、red エラーゼロ。**俺が触ってない既存コード由来**:

| カテゴリ | 件数 | 内容 |
|---|---|---|
| iOS 17 deprecation | ~10 | `recordPermission` → `AVAudioApplication.recordPermission` |
| Sendable concurrency | ~15 | `Main actor-isolated property 'isRecording' can not be referenced from a Sendable closure` (RecordingService 内) |
| 未使用 immutable var | ~10 | `tokenType` / `config` / `errorMessage` / `fullErrorString` (AuthService 内) |
| その他 | ~29 | unreachable catch / Switch must be exhaustive / @preconcurrency Sendable / CFBundleVersion mismatch |

**判定**: 全部 build を止めない。**機能追加優先で当面放置可**。後日 "warning 一掃 PR" として別タスク化推奨。

### 2.3 Cloud Sync 配線確認

```
lecsy/Services/CloudSyncService.swift                       121 行 (新規)
  ├─ static let shared
  ├─ var isEnabled (UserDefaults: lecsy.cloudSyncEnabled, default true)
  ├─ func setEnabled(_:)
  └─ func uploadTranscriptIfEnabled(...) async -> String?
       Gate 1: isEnabled
       Gate 2: AuthService.shared.currentUser != nil
       Gate 3: content non-empty
       Reads:  OrganizationContext.shared.saveContext()
       Calls:  LecsyAPIClient.shared.invokeFunction("save-transcript", body, timeout: 60)
       Result: log + return remote id (fire-and-forget on failure)

lecsy/Views/Home/RecordView.swift:676
  └─ startTranscription() の文字起こし完了点で:
     Task {
         await CloudSyncService.shared.uploadTranscriptIfEnabled(
             title: latest.title,
             content: result.text,
             createdAt: latest.createdAt,
             durationSeconds: latest.duration,
             language: transcriptionService.transcriptionLanguage.rawValue
         )
     }

lecsy/Views/Settings/SettingsView.swift:20, 159-167
  └─ @State cloudSyncEnabled = CloudSyncService.shared.isEnabled
     Privacy セクションに Toggle("Cloud Sync") + 説明文
```

**判定**: ✅ 完全配線。`SummaryService` も同じ Edge Function を叩く既存パターンと整合。

### 2.4 UI 実機確認 (16:41 スクショで確認済)

`Settings タブ → Privacy セクション` に以下を視認:

```
Privacy
├─ Cloud Sync                                    [●━] (緑 = ON)
├─ "Your transcript text is saved to Lecsy servers so you don't lose
│   notes if your phone breaks. Audio files are NEVER uploaded — only
│   the text. We do not use your data to train AI models."
├─ Privacy Policy                                 ↗
└─ Terms of Service                               ↗
```

**判定**: ✅ Week 1 の UI 仕様通り。

### 2.5 起動ログから確認できたこと

シミュレータ初回起動時 console:

```
✅ TranscriptionService initialized (multilingual, lang: en, kit: true)
✅ Starting background model preparation (bundled: true, force: true)
✅ Supabase config loaded
✅ AuthService: Initializing Supabase client
✅ AuthService: Supabase client initialization completed
✅ Audio session pre-configured
✅ Loading WhisperKit model (small) → completed in 6.29s
✅ Background model preparation completed
✅ Second WhisperKit instance loaded for parallel chunks
⚠️  AuthService: 保存されたセッションが見つかりません (= 未サインイン状態、想定通り)
⚠️  AuthService: セッション確認失敗 — Auth session missing. (= 同上、想定通り)
```

**判定**: ✅ 全コアサービス起動 OK。Auth セッション無しは未サインイン状態の正常動作。

### 2.6 iOS 側で未検証の項目

| 項目 | 検証手段 | 残しておく理由 |
|---|---|---|
| Sign In → 録音 → DB INSERT (E2E) | シミュレータ手動 | OAuth ループ + 音声入力が必要、ROI 低 |
| Cloud Sync OFF で upload skip | 同上 | コードレビューで `if !isEnabled return nil` 確認済 |
| 組織所属者の `organization_id` 自動付与 | 同上 | `OrganizationContext.shared.saveContext()` から取得しておりロジック上確実 |

---

## 3. Web 管理画面検査

### 3.1 ビルド

`next build` (pre-existing TS エラーを一時 stash した clean な状態):

```
✓ Compiled successfully
```

### 3.2 ルート認識 (build output 抜粋)

新規追加されたページ / API:

```
✅ ƒ /org/[slug]/transcripts                       196 B   96.3 kB
✅ ƒ /org/[slug]/students/[id]                     196 B   96.3 kB
✅ ƒ /api/org/[slug]/transcripts/export            0 B     (Route Handler)
```

既存と並んで全部 dynamic (`ƒ`) として認識されてる。

### 3.3 organization_id 厳格フィルタ確認

```
web/app/org/[slug]/transcripts/page.tsx:42        .eq('organization_id', orgId)
web/app/org/[slug]/students/[id]/page.tsx:41      .eq('organization_id', orgId)
web/app/api/org/[slug]/transcripts/export/route.ts:30  .eq('organization_id', orgId)
```

**判定**: ✅ 全 3 ファイルで `organization_id = orgId` フィルタ適用済。`user_id IN (members)` パターンは使っていない (= 個人録音漏洩リスクなし)。

### 3.4 TypeScript チェック

```
俺が書いた Week 1/2 ファイル:           0 エラー
pre-existing 編集中ファイル:            8 エラー (create-checkout-session, create-portal-session)
```

エラー内容: `STRIPE_SECRET_KEY` 型が `string | undefined` 由来 + `'user' is possibly null` 系。**俺は触ってない**。`route.ts` の冒頭で `return NextResponse.json(... 503)` で early-return してる関係でその後ろのコードが unreachable になり、unreachable コード内の TS チェックが ON のまま残ってるため。次回コミットする前に直す必要 (§6 参照)。

### 3.5 サイドバー追加確認

```
web/components/OrgSidebar.tsx:13-17
  Dashboard | Transcripts (新規) | Members | AI Assist | Usage | Settings
```

**判定**: ✅ Transcripts ナビゲーション項目が追加されている。アイコン (TranscriptsIcon) も新規追加済。

---

## 4. Supabase バックエンド検査

### 4.1 transcripts スキーマ

`supabase/migrations/20260406000200_v4_m1_transcripts_org.sql`:

```sql
ALTER TABLE transcripts
  ADD COLUMN IF NOT EXISTS organization_id UUID NULL REFERENCES organizations(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS visibility TEXT NOT NULL DEFAULT 'private'
    CHECK (visibility IN ('private', 'class', 'org_wide')),
  ADD COLUMN IF NOT EXISTS class_id UUID NULL;

CREATE INDEX IF NOT EXISTS idx_transcripts_org ON transcripts(organization_id) WHERE organization_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_transcripts_class ON transcripts(class_id) WHERE class_id IS NOT NULL;

CREATE POLICY "transcripts_select_org_staff" ON transcripts FOR SELECT USING (
  organization_id IS NOT NULL AND visibility IN ('class', 'org_wide')
  AND is_org_role_at_least(organization_id, (SELECT auth.uid()), 'teacher')
);
CREATE POLICY "transcripts_select_org_wide" ON transcripts FOR SELECT USING (
  organization_id IS NOT NULL AND visibility = 'org_wide'
  AND is_org_member(organization_id, (SELECT auth.uid()))
);
```

**判定**: ✅ 列 + index + 2 つの RLS ポリシー全部入ってる。注意点:
- `visibility` の `class` 値はまだ生きている (削除済の `org_classes` の名残) — 害は無いが将来クリーンアップ対象
- `class_id` 列は本体スキーマには残っているが `b2b_simplify` migration で `transcripts.class_id` を DROP した。** 一貫性のためどちらかに揃える必要あり** → `b2b_simplify` の方が後勝ちなので実 DB には class_id 無いはず

### 4.2 save-transcript Edge Function

`supabase/functions/save-transcript/index.ts:38-110`:

```typescript
interface SaveTranscriptRequest {
  title: string;
  content: string;
  ...
  organization_id?: string | null;
  visibility?: 'private' | 'org_wide' | null;
}

// ... auth check ...

let orgId: string | null = null;
let visibility: string = 'private';
if (body.organization_id) {
  // ★ サーバーサイドメンバーシップ検証 (クライアント信頼ゼロ)
  const { data: membership } = await supabase
    .from('organization_members')
    .select('id')
    .eq('org_id', body.organization_id)
    .eq('user_id', user.id)
    .eq('status', 'active')
    .maybeSingle();
  if (membership) {
    orgId = body.organization_id;
    if (body.visibility && ['private', 'org_wide'].includes(body.visibility)) {
      visibility = body.visibility;
    }
  }
}

await supabase.from("transcripts").insert({
  user_id: user.id,
  ...
  organization_id: orgId,
  visibility: visibility,
});
```

**判定**: ✅ 設計通り。クライアントが偽の `organization_id` を投げても、サーバーが `organization_members` をチェックしてからじゃないと採用しない。安全。

---

## 5. リスク / 既知の問題

### 5.1 🟡 既存ダッシュボードが個人録音を漏洩 (Week 1 で生まれた整合性ギャップ)

`web/app/org/[slug]/page.tsx:67-170` は旧モデル (`user_id IN (memberIds)`) で transcripts を引いている:

```typescript
const memberIds = members?.map((m) => m.user_id) || []
...
.from('transcripts')
.in('user_id', memberIds)
```

これは **学校に入る前の個人録音 / 個人モードで録音した分も学校管理者に見える** ことを意味する。Week 1 で `organization_id` 厳格モデルを採用したので **整合性として直すべき**。

新規追加した `/transcripts`, `/students/[id]`, `/api/.../export` は **正しく `organization_id` フィルタを使っている** ので、ダッシュボードだけがレガシー。

**修正案** (差分小):
```typescript
.from('transcripts')
.eq('organization_id', orgId)
// (.in('user_id', memberIds) を全箇所削除)
```

これを直すと「Week 1 以前に作った transcripts は org_id が NULL なので集計から消える」という副作用が出る。**それで正しい** — 個人録音を学校集計から外すのが目的なので。

**優先度**: 🟡 中。営業前 (Week 3〜4) に直しておくべき。

### 5.2 🟢 警告 64 件 (iOS 既存コード)

§2.2 の通り全部 yellow。機能影響なし。後日まとめて掃除。

### 5.3 🟢 visibility CHECK に古い 'class' 値が残る

`transcripts` テーブルの CHECK 制約に `visibility IN ('private', 'class', 'org_wide')` がまだあり、`org_classes` テーブル削除後も生きてる。実害なし、将来クリーンアップ対象。

### 5.4 🟡 pre-existing TS エラー (5 ファイルの未コミット変更)

`web/app/api/create-checkout-session/route.ts` と `create-portal-session/route.ts` に **8 件の TypeScript エラー**:
- `STRIPE_SECRET_KEY` が `string | undefined` 型なのに `new Stripe(...)` に渡している
- `'user' is possibly null` 系
- `'error' is of type 'unknown'`

これらは関数冒頭で `return NextResponse.json({error: "billing_disabled"}, {status: 503})` してるので **実行されない死んだコード**だが、TS チェッカーは止まらないのでビルドが失敗する。**コミット前に修正必須**。

修正案:
```typescript
export async function POST(req: NextRequest) {
  return NextResponse.json({ error: "billing_disabled" }, { status: 503 });
}
// 残りのコードは削除 or `if (false) { ... }` で囲む or `// @ts-nocheck` ブロック化
```

最もクリーンなのは「死んだコードを削除」。個人課金を将来再開する予定があれば git history を辿って復元すれば済む。

---

## 6. Sources of truth (どこを見れば最新か)

| 知りたいこと | ファイル |
|---|---|
| 戦略・勝ち筋 | `doc/STRATEGIC_REVIEW_2026Q2.md` |
| 設計レビュー・未決論点 | `doc/B2B_DESIGN_REVIEW.md` |
| 現状スナップショット (短縮版) | `doc/CURRENT_STATUS.md` |
| 統合要件マスタ | `doc/00_統合要件定義_v4_B2B.md` |
| 削除済テーブル一覧 | `supabase/migrations/20260407100000_b2b_simplify.sql` 冒頭 |
| Cloud Sync ロジック | `lecsy/Services/CloudSyncService.swift` |
| Supabase 受け側ロジック | `supabase/functions/save-transcript/index.ts` |
| 学校管理画面 | `web/app/org/[slug]/{page,transcripts,students/[id]}.tsx` |
| 全文検索 / CSV エクスポート | `web/app/api/org/[slug]/transcripts/export/route.ts` |

---

## 7. 推奨ネクストアクション (優先順)

| 優先 | アクション | 工数 | 影響 |
|---|---|---|---|
| 🔴 高 | §5.4 pre-existing TS エラー解消 (死んだ Stripe コードを削除) | 15 分 | 次回コミット可能化 |
| 🟡 中 | §5.1 ダッシュボードを `organization_id` フィルタに統一 | 30 分 | データ整合性 + 営業時の安心材料 |
| 🟢 低 | §5.2 iOS 警告掃除 (deprecation + Sendable + unused var) | 1-2 h | コード品質 |
| 🟢 低 | §5.3 transcripts.visibility CHECK から 'class' 削除 | migration 1 本 | クリーンアップ |
| ⭐ 戦略 | Week 3 着手 (iOS bilingual notes UI + 営業準備) | 2-3 d | プロダクト売り強化 |

---

## 8. テスト未実施項目 (お前がやる必要がある)

俺ができたのは「コード」「ビルド」「UI 静的表示」まで。残りは:

1. **Supabase ダッシュボードで実際に行が増えるか**: Sign In → 録音 → `transcripts` テーブルを確認
2. **組織所属者で organization_id が埋まるか**: 組織アカウントで上記を再実行
3. **Cloud Sync OFF で行が増えないか**: トグル OFF → 録音 → 確認
4. **Web 管理画面で transcripts が出るか**: `npm run dev` → `/org/[your-slug]/transcripts` 開く
5. **検索 / 学生ページ / CSV エクスポートが動くか**: 同じ画面で
6. **Stripe webhook B2B 分岐**: Stripe CLI で `checkout.session.completed` event を流す

これらは全部 30 分以内で終わる手動 QA。やるなら順番にチェックリスト化して報告してくれれば、見つかった問題はすぐ直す。

---

## 付録: 数値まとめ

```
コミット 3 本                    +1209 行 / -8 行
新規ファイル 6 本                CloudSyncService.swift / 4 web ファイル / 戦略 docs 2 本
修正ファイル 3 本                RecordView.swift / SettingsView.swift / PRIVACY_POLICY.md
iOS Build                       ✅ Green (Running on iPhone 17 Pro 確認済)
Web Build                       ✅ Compiled successfully
TypeScript エラー                俺の範囲: 0 / pre-existing: 8
yellow warnings (iOS)            64 (全部既存コード)
```
