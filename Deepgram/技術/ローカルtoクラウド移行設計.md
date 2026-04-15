# ローカル → クラウド 自動同期 移行設計

> 作成日: 2026-04-14
> 目的: 現状500ユーザーのローカルデータを失わず、自動でクラウド同期する仕組みへ移行
> 関連: [[Deepgram-only設計_2026]] / [[プロダクト概要]]

---

## 0. この設計の一行サマリ

**既存500ユーザーの録音・文字起こしデータ（テキストのみ、音声は除外）を、明示オプトインを経てバックグラウンドで自動Supabase同期。以降は全新規データが自動クラウド同期される。ユーザー体験はシームレス、プライバシーは明示的。**

---

## 1. 現状の棚卸し

### 1.1 既存アプリのデータ構造（推定）
```
端末内ストレージ:
├─ Documents/
│   ├─ recordings/
│   │   ├─ {uuid}.m4a          ← 音声ファイル
│   │   └─ {uuid}.transcript.json  ← WhisperKit文字起こし結果
│   └─ bookmarks.plist
│
├─ UserDefaults/
│   ├─ preferred_language
│   ├─ onboarding_complete
│   └─ ... 
│
└─ CoreData or SwiftData:
    ├─ Recording entity (title, duration, createdAt, ...)
    ├─ Segment entity (text, startTime, endTime, ...)
    └─ Bookmark entity (label, timeOffset, ...)
```

### 1.2 既存500ユーザーの特徴
- 全員 WhisperKit でローカル処理してきた
- 音声ファイルとテキストが端末内に蓄積
- アカウント登録なし（ローカル完結UX）
- 現状データの想定: 平均10-50録音/ユーザー、平均5-20時間の講義音声

### 1.3 懸念点
- **音声ファイルが大きい**: 5-20時間×30MB/h ≒ 150-600MB/ユーザー。クラウドへ送ると帯域とコストが問題
- **アカウントなしで運用してきた**: 急に「アカウント作って」は離脱リスク
- **プライバシー訴求が従来の売り**: 「音声はデバイスから出ない」が破られる不安

---

## 2. 設計方針

### 2.1 何をクラウドに送るか（何を送らないか）

| データ | クラウド送信 | 理由 |
|------|-----------|-----|
| 文字起こしテキスト（JSON, word-level） | ✅ **送信** | 端末またぐ閲覧・B2B管理・検索に必要 |
| 録音メタデータ（title, duration, createdAt, language, ブックマーク） | ✅ **送信** | ライブラリ管理に必要 |
| 音声ファイル（m4a/Opus） | ❌ **送信しない** | プライバシー訴求、帯域コスト、Deepgram再処理不要 |
| ユーザー設定（preferred_language等） | ✅ **送信** | 端末間で同期 |
| 検索履歴・UI状態 | ❌ 送信しない | プライバシー、価値なし |

→ **「音声ゼロ保存」ポジションは維持**。既存ユーザーの「音声は外に出ない」期待値を守る。

### 2.2 3つの原則

1. **明示オプトイン**: ユーザーが能動的に「有効化」を押した時のみ同期開始
2. **オフライン動作維持**: クラウド未同期でも全機能フル動作
3. **双方向同期**: Last-Write-Wins による conflict resolution、多端末対応

---

## 3. UXフロー

### 3.1 既存ユーザーの初回体験（アップデート後初回起動）

```
[App更新後、初回起動]
  ↓
[ようこそ画面]
  「lecsyがグローバル版にアップデートされました」
  「新機能: クラウド同期で端末間アクセス可能に」
  ↓
[アカウント作成]
  Sign in with Apple / Email
  「アカウント作成は必須ですが、ローカルデータは保持されます」
  ↓
[クラウド同期の説明画面]
  ✅ 文字起こしテキスト・メタデータをクラウド同期
  ❌ 音声ファイルはクラウドに送られません（従来通り端末内）
  ↓
[同意ボタン]
  「有効化する」 / 「今はやめる（ローカルのみ運用）」
  ↓
[バックグラウンド同期開始]
  プログレスバー: 「42/127 録音を同期中...」
  WiFi接続時のみ、アプリ閉じても継続
  ↓
[完了通知]
  「50 録音の同期が完了しました」
  「端末を追加するとデータ共有できます」
```

### 3.2 新規ユーザーの体験（6/1以降）

```
[初回起動]
  ↓
[オンボーディング 4ページ]
  1. プライバシー同意（「音声はクラウドに保存されません」明示）
  2. 使い方説明
  3. 言語選択
  4. アカウント作成（クラウド同期 自動ON、明示記載）
  ↓
[録音画面]
  記録すると即時バックグラウンド同期
```

### 3.3 「今はやめる」を選んだユーザー

- ローカルのみ運用に留まる
- 設定 > クラウド同期 から後でいつでも有効化可能
- Pro機能（Streaming）はオンライン必須、その場合のみアカウント要求
- アカウントなしでは Free + Prerecorded のみ利用可

---

## 4. 技術実装

### 4.1 同期アーキテクチャ

```
iOS App
  ├─ LocalStore (CoreData/SwiftData) ← Source of Truth（ローカル）
  │
  ├─ SyncEngine
  │   ├─ ChangeTracker — ローカル変更を記録
  │   ├─ UploadQueue — バックグラウンドアップロード
  │   ├─ DownloadQueue — 他端末からの変更取得
  │   └─ ConflictResolver — LWW (Last-Write-Wins)
  │
  └─ SupabaseClient
       ├─ REST API — CRUD操作
       └─ Realtime subscription — 他端末の変更を即時受信

Supabase
  ├─ Postgres: transcripts, user_settings, bookmarks
  ├─ RLS: 本人データのみアクセス可
  └─ Realtime: 変更通知
```

### 4.2 Postgres スキーマ

```sql
-- 既存の transcripts テーブル（Deepgram-only設計_2026.md 参照）を拡張

alter table public.transcripts
  add column client_id text,  -- iOS側で生成するUUID（競合解決用）
  add column synced_at timestamptz,
  add column version int not null default 1,  -- LWW用
  add column origin text not null default 'cloud',  -- 'cloud' | 'local_migrated' | 'new'
  add column deleted_at timestamptz;  -- ソフトデリート

create index on public.transcripts (user_id, synced_at desc);

-- ユーザー設定の同期
create table public.user_settings (
  user_id uuid primary key references auth.users(id) on delete cascade,
  preferred_language text,
  onboarding_complete boolean default false,
  cloud_sync_enabled boolean default true,
  migration_completed boolean default false,
  migration_completed_at timestamptz,
  settings jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);
alter table public.user_settings enable row level security;
create policy "users manage own settings"
  on public.user_settings for all using (auth.uid() = user_id);

-- ブックマーク
create table public.bookmarks (
  id uuid primary key default gen_random_uuid(),
  transcript_id uuid not null references public.transcripts(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  label text,
  time_offset numeric(10, 3) not null,
  client_id text,
  version int not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.bookmarks enable row level security;
create policy "users manage own bookmarks"
  on public.bookmarks for all using (auth.uid() = user_id);
```

### 4.3 iOS側のSwift実装方針

```swift
// 概念設計（詳細実装はコード化フェーズで）

protocol SyncEngine {
    func enableCloudSync() async throws
    func disableCloudSync() async throws
    func syncNow() async throws -> SyncResult
    func startBackgroundSync()
    func stopBackgroundSync()
}

class LecsySync: SyncEngine {
    // 初回移行：既存ローカルデータをアップロード
    func migrateExistingData() async throws {
        let localRecordings = try LocalStore.fetchAllRecordings()
        for recording in localRecordings {
            // 文字起こしJSONのみ送信、音声ファイルは送らない
            let payload = TranscriptPayload(
                clientId: recording.localUUID,
                title: recording.title,
                language: recording.language,
                words: recording.transcriptionJSON,
                recordedAt: recording.createdAt,
                origin: .localMigrated
            )
            try await SupabaseAPI.uploadTranscript(payload)
            try LocalStore.markSynced(recording)
        }
        try await markMigrationComplete()
    }

    // バックグラウンド同期
    func startBackgroundSync() {
        URLSessionBackgroundTask.schedule()
        // WiFi接続時にのみ起動
        // 15分ごとに未同期データをチェック
    }

    // Realtime subscription で他端末からの変更を受信
    func subscribeToRemoteChanges() {
        supabase.realtime
            .channel("transcripts:user_id=eq.\(userId)")
            .on("*", callback: handleRemoteChange)
            .subscribe()
    }

    // 競合解決（Last-Write-Wins）
    func resolveConflict(local: Transcript, remote: Transcript) -> Transcript {
        local.version > remote.version ? local : remote
    }
}
```

### 4.4 バックグラウンドアップロードの制約
- **iOS URLSession Background Configuration** 使用
- WiFi接続のみ（モバイルデータを消費しない）
- アプリ閉じても継続
- バッテリー低下時は一時停止
- 進捗を UserNotifications で通知（必要なら）

### 4.5 音声ファイルの扱い
- **クラウドにアップロードしない**
- 端末内で保持（従来通り）
- ユーザー側で手動削除 or 7日自動削除オプション
- 他端末で同じ録音を見たい場合、テキストは共有されるが音声は元端末のみ

---

## 5. 段階ロールアウト計画

### Phase A: 準備（W02 4/21-4/27）
- [ ] Supabase スキーマ拡張（transcripts, user_settings, bookmarks）
- [ ] Edge Functions: `upload-transcript`, `download-transcripts`, `sync-status`
- [ ] iOS SyncEngine 骨格実装

### Phase B: 移行機能実装（W03-W04 4/28-5/11）
- [ ] ローカルデータの棚卸しAPI（既存Recordingを一覧化）
- [ ] アップロードロジック（バッチ処理、リトライ）
- [ ] 進捗UI（プログレスバー・通知）
- [ ] オプトイン画面実装

### Phase C: オプトインUI + バックグラウンド同期（W05-W06 5/12-5/25）
- [ ] ようこそ画面（アップデート後初回）
- [ ] 同意フロー
- [ ] Background URLSession 設定
- [ ] Realtime subscription 実装
- [ ] 競合解決ロジック

### Phase D: 段階ロールアウト（W07-W09 5/26-6/14）
- [ ] TestFlight ベータで社内テスト（Week 07）
- [ ] App Store Review 申請（Week 07）
- [ ] 10%のユーザーへロールアウト（6/01）
- [ ] 50%へロールアウト（6/08）
- [ ] 100%ロールアウト（6/14）
- [ ] 監視: クラッシュ率、同期成功率、オプトイン率

### Phase E: 完了判定（W10 6/15-6/21）
- [ ] 移行率 >80% を確認
- [ ] エラー率 <2% を確認
- [ ] ユーザーからのフィードバック収集

---

## 6. 成功指標

| 指標 | 目標 | 測定方法 |
|------|------|--------|
| オプトイン率（既存500人） | **>70%** | user_settings.cloud_sync_enabled |
| 移行完了率 | >80% | user_settings.migration_completed |
| 移行中のクラッシュ率 | <1% | Crashlytics |
| アップロード失敗率 | <2% | Edge Function ログ |
| 平均移行時間（1ユーザー） | <10分 | sync_status テーブル |
| データ欠損率 | **0%** | 移行前後のレコード数比較 |

---

## 7. リスクと対策

| リスク | 影響 | 対策 |
|------|-----|-----|
| 既存ユーザーがオプトインを拒否 | 移行率低下 | オフラインのみで継続可能な状態を維持、後日再促し |
| ネットワーク不安定で移行失敗 | データ欠損 | 再試行ロジック、チェックポイント化、冪等なUpload |
| 文字起こしJSONサイズが想定超え | DBコスト増 | 1録音あたり最大5MBでトリミング、word単位圧縮 |
| 複数端末で同時編集 | 競合 | Last-Write-Wins、version番号で検知 |
| ユーザーがアカウント作成でつまずく | 離脱 | Sign in with Apple（1タップ）を推奨 |
| プライバシー不安で離れる | DL減 | 「音声は送信されません」を各画面で明示 |
| 移行時のバッテリー消費 | 不満 | WiFi+充電中のみ自動実行 |
| 5日で500ユーザー全員が終わらない | 体感遅い | 10%→50%→100%の段階ロールアウト |

---

## 8. 設計判断ログ

### Q: なぜ音声ファイルをクラウドに送らないか？
A: 
1. プライバシー訴求の維持（「音声ゼロ保存」）
2. コスト（500ユーザー × 300MB = 150GB、帯域+ストレージで月$20-50）
3. 再文字起こし不要（Nova-3精度で十分）
4. Deepgram ZDR契約と整合

### Q: なぜ双方向同期か？一方向（ローカル→クラウド）でよくないか？
A: 将来 iPad / Web / Android で同じデータを見せたい。Phase 3 でマルチデバイス対応する際、双方向sync が前提になる。今から作り込んでおく。

### Q: なぜ CloudKit ではなく Supabase か？
A: 
- B2B 管理ダッシュボード（Web）からもアクセスする必要がある
- CloudKit は iOS/macOS のみ、他プラットフォーム非対応
- Supabase で一元化すればコード資産が活きる

### Q: なぜ LWW (Last-Write-Wins) か？ CRDT ではないのか？
A: lecsy の文字起こしテキストは「多端末で同時編集する」シーンが稀。単純なLWWで実用上十分。将来editが頻繁になれば CRDT 検討。

### Q: Realtime subscription を最初から入れるか？
A: Phase D まではPull型（起動時 + 15分おき）で十分。Realtime は Phase E 以降で追加。

---

## 9. 今後のロードマップ

### 近期（Phase 1 実装、5月中）
- 基本移行完了、500ユーザー80%超同期
- オプトアウト選択肢も提供

### 中期（Phase 2-3、2026 Q4 - 2027 Q1）
- iPad/Webでのデータ閲覧
- 複数端末同時編集の改善
- Realtime subscription の有効化

### 長期（Phase 4-5、2027以降）
- End-to-End 暗号化オプション（Enterprise向け）
- Multi-region レプリケーション
- Selective Sync（大量データユーザー向け）

---

## 10. 既存ユーザーへの移行連絡（メールテンプレ）

**配信日: 2026-05-30（ローンチ2日前）**

```
Subject: lecsy is evolving — better performance, cloud sync, and our
         commitment to your privacy remains.

Hi [Name],

I'm Takumi, the founder of lecsy. Thanks for being one of our first
500 users.

I'm writing to share a big update coming June 1st:

🎯 What's new:
- Deepgram Nova-3 transcription (faster, more accurate, 12+ languages)
- Cloud sync across your devices (optional, opt-in)
- Real-time live captions (in Pro)

🔒 What hasn't changed:
- Your audio never leaves your device. Really.
- We only sync text transcripts (if you opt in).
- Your existing recordings stay safe on your device.

💰 What's new about pricing:
- Free tier stays free (300 min/month, 90-min sessions)
- New Pro plan ($11.99/mo) unlocks real-time captions
- Student plan ($5.99/mo) with .edu/.ac.uk/.ac.jp verification

What you need to do: just update the app on June 1st. On first open,
you'll see a friendly setup to enable cloud sync (or skip it).

Questions? Reply to this email.

— Takumi Nittono
Founder, Lecsy LLC
```

---

*関連: [Deepgram-only設計_2026](./Deepgram-only設計_2026.md) / [プロダクト概要](../プロダクト/プロダクト概要.md) / [実行タイムライン_2026](../ロードマップ/実行タイムライン_2026.md)*
