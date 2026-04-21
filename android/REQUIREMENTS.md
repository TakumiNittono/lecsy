# Lecsy Android — 要件定義書

最終更新: 2026-04-20

---

## 0. これは何

**B2B パイロット契約校 (FMCC, UF ELI, Santa Fe 等) の Android 学生向け Lecsy。**
配信は Web (`web/` の Next.js) を **PWA (Progressive Web App)** として提供する。
ネイティブ Android アプリは作らない。Kotlin / React Native / Flutter は不採用。

将来 7月以降に **Capacitor** でこの PWA を Play Store にラップする可能性はあるが、
本書のスコープ外 (Phase 7 として末尾に記載のみ)。

---

## 1. なぜ PWA か

### 1.1 Android では PWA がほぼネイティブと同等

| 機能 | Android PWA | iOS PWA | ネイティブ Android |
|---|---|---|---|
| ホーム画面アイコン | ✅ A2HS | ✅ (制約あり) | ✅ |
| フルスクリーン起動 (display:standalone) | ✅ | ✅ | ✅ |
| マイク (MediaRecorder API) | ✅ | ✅ | ✅ |
| Web Push 通知 | ✅ | △ (16.4+のみ) | ✅ |
| バックグラウンド継続 | △ (Wake Lock で延命) | ❌ | ✅ |
| Service Worker オフライン | ✅ | ✅ | n/a |
| インストール促進バナー | ✅ (beforeinstallprompt) | ❌ | n/a |
| Play Store 配布 | ❌ (TWA で可) | n/a | ✅ |

**結論: Android では PWA で十分。WhisperKit (オンデバイス Whisper) が使えない以外は機能差なし。**

### 1.2 既存資産の流用

- `web/` (Next.js 14, App Router) — そのまま使える
- Supabase バックエンド — 共通
- Deepgram WebSocket トークン発行 (`supabase/functions/deepgram-token`) — 共通
- 招待コード基盤 (`20260420000000_invite_codes.sql`) — 共通
- FERPA consent (`20260418000000_ferpa_consent.sql`) — 共通

新規開発は **Android 専用ルート + 録音 UI + PWA 化** のみ。

---

## 2. アクセス制御 (要件の核)

### 2.1 ルール

> **招待コード入力に成功した anonymous Supabase ユーザーのみ Android 版を使える。**
> メール・OAuth (Google / Microsoft) ・電話番号認証は **一切提供しない**。

### 2.2 認証フロー (既存 RPC の流用)

```
[Android Chrome で開く]
   ↓
[/android (PWA エントリ)]
   ↓
[招待コード入力欄] ← QR からは ?code=XXXXXX で自動入力
   ↓
[supabase.auth.signInAnonymously()]   ← Supabase が anon JWT を発行
   ↓
[supabase.rpc('redeem_invite_code', { p_code })]  ← 既存 RPC
   ↓ ok: true
[organization_members に active 行が入る]
   ↓
[/android/app へリダイレクト]
   ↓
[以降、ローカルに JWT が persist されている限り再入力不要]
```

**重要**: `redeem_invite_code` は既に `GRANT EXECUTE ... TO anon` 済み。
RPC が `auth.uid()` を取れる (= anon でも JWT を持っている) ことを前提に書かれている。

### 2.3 招待コード未入力 / 失敗時の挙動

- コードなしで `/android/app/*` を開いた → middleware で `/android` にリダイレクト
- コードが `code_not_found` / `code_already_used` / `code_expired` → エラーメッセージ表示
- ネットワーク失敗 → リトライボタン (signInAnonymously と redeem は分離)

### 2.4 デバイス紛失 / 機種変更時

匿名ユーザーは email を持たないので、JWT を失うとアカウントは復旧不能。
- 教員は「コードをもう1枚渡す」だけで済む (1回1コードだが追加発行は admin で可)
- パイロット契約校には事前にこの仕様を共有 (support doc に記載)

---

## 3. 機能スコープ

### 3.1 含むもの (Phase 1-6)

| # | 機能 | 実装場所 |
|---|---|---|
| F1 | 招待コード redeem (PWA エントリ) | `web/app/android/page.tsx` |
| F2 | リアルタイム録音 + 字幕 | `web/app/android/record/page.tsx` |
| F3 | トランスクリプト一覧 | `web/app/android/library/page.tsx` |
| F4 | トランスクリプト詳細 (read-only) | `web/app/android/t/[id]/page.tsx` |
| F5 | FERPA 同意モーダル (初回録音前) | 既存 component 流用 |
| F6 | PWA インストール促進 | manifest + beforeinstallprompt |
| F7 | オフライン shell (Service Worker) | `web/public/sw.js` |
| F8 | Wake Lock (録音中スリープ防止) | `screen.wakeLock.request('screen')` |

### 3.2 含まないもの (明示的にスコープ外)

- ❌ メール / OAuth / 電話番号 サインイン
- ❌ Stripe チェックアウト (B2C 課金は iOS only、B2B は org 側で精算)
- ❌ B2C サブスク / AI 翻訳サブスク (iOS only)
- ❌ WhisperKit オンデバイス推論 (技術的に不可、全文字起こし Deepgram)
- ❌ バックグラウンド録音 (PWA の制約。Wake Lock + 画面 ON 維持で代替)
- ❌ ネイティブ通知 (Web Push は将来 Phase 7 で検討)
- ❌ 動画録画 / 画面共有
- ❌ Play Store 配布 (Phase 7)

---

## 4. アーキテクチャ

### 4.1 配置

```
web/
├── app/
│   ├── android/                    ← 新規。Android 版の全画面
│   │   ├── page.tsx                ← 招待コード入力
│   │   ├── layout.tsx              ← Android 専用シェル (BottomNav 等)
│   │   ├── app/page.tsx            ← ホーム (録音ボタン)
│   │   ├── record/page.tsx         ← 録音中 UI
│   │   ├── library/page.tsx        ← トランスクリプト一覧
│   │   └── t/[id]/page.tsx         ← トランスクリプト詳細
│   ├── api/
│   │   └── android/
│   │       └── deepgram-token/route.ts  ← anon JWT で叩ける Deepgram トークン発行
│   └── layout.tsx                  ← manifest/theme-color の <link> 追加
├── components/
│   ├── android/                    ← 新規
│   │   ├── InviteCodeForm.tsx
│   │   ├── Recorder.tsx            ← MediaRecorder + Deepgram WS
│   │   ├── LiveCaption.tsx
│   │   ├── InstallPrompt.tsx       ← beforeinstallprompt 制御
│   │   └── BottomNav.tsx
├── lib/
│   ├── android/
│   │   ├── deepgram-stream.ts      ← WS クライアント
│   │   ├── recorder.ts             ← MediaRecorder ラッパ
│   │   └── ua.ts                   ← Android UA 判定
├── public/
│   ├── manifest.webmanifest        ← 新規
│   ├── sw.js                       ← 新規 (Service Worker)
│   └── icons/                      ← 新規
│       ├── icon-192.png
│       ├── icon-512.png
│       ├── icon-maskable-512.png
│       └── apple-touch-icon.png
└── middleware.ts                   ← UA gate を追加

android/                            ← 本ドキュメント置き場 (実装コードは無い)
├── REQUIREMENTS.md                 ← この文書
├── ASSETS_SPEC.md                  ← (後で) アイコン・スクショ仕様
└── TEST_PLAN.md                    ← (後で) 実機テスト手順
```

### 4.2 ルーティング

| パス | 役割 | 認証要件 |
|---|---|---|
| `/android` | 招待コード入力 + PWA インストール導線 | 不要 |
| `/android/app` | ホーム (Android 版) | anon + org_member.active 必須 |
| `/android/record` | 録音 + ライブ字幕 | 同上 |
| `/android/library` | トランスクリプト一覧 | 同上 |
| `/android/t/[id]` | トランスクリプト詳細 | 同上 |

### 4.3 既存ルートとの関係

- 既存 `/app/*` (Web 版本体) は **そのまま放置**。教員 / admin のダッシュボード用途。
- 既存 `/join/[slug]?code=XXX` は **iOS 用の deep-link カードのまま**。
  - 追加で「Android はこちら」ボタンを差し込み、`/android?code=XXX` に飛ばす。
- middleware で Android UA を検知して、未認証アクセスを `/android` に強制リダイレクト。

### 4.4 middleware.ts の追加ロジック

```typescript
// 疑似コード
if (isAndroidUserAgent(request) && !hasValidSession(request)) {
  if (!request.nextUrl.pathname.startsWith('/android')
      && !request.nextUrl.pathname.startsWith('/api')
      && !isPublicPath(request.nextUrl.pathname)) {
    return NextResponse.redirect(new URL('/android', request.url))
  }
}
```

注意: マーケ LP (`/`, `/pricing`, `/schools` 等) は Android UA でも見られるべき。
リダイレクト対象は `/app/*` などのアプリルートのみに絞る。

---

## 5. 録音 / 文字起こし設計

### 5.1 技術スタック

| レイヤ | 採用 |
|---|---|
| マイク取得 | `navigator.mediaDevices.getUserMedia({ audio: true })` |
| 録音 | `MediaRecorder` (mimeType: `audio/webm;codecs=opus`) |
| ストリーミング | WebSocket → Deepgram Live API |
| トークン発行 | `supabase.functions.invoke('deepgram-token')` (既存) |
| 表示 | React state で interim / final transcript を分けて描画 |
| 永続化 | 録音終了時に `supabase.functions.invoke('save-transcript')` (既存) |
| スリープ防止 | `navigator.wakeLock.request('screen')` |

### 5.2 オーディオフォーマット

- ブラウザ録音: `audio/webm;codecs=opus` (16kHz mono が理想だが MediaRecorder は強制不可)
- Deepgram Live API: `encoding=opus, sample_rate=48000, channels=1` を指定
- 検証必須: Pixel / Galaxy 双方で実機確認

### 5.3 バックグラウンド対応

- Wake Lock API でスクリーン ON 維持
- visibilitychange で画面が非表示になっても WebSocket は継続 (Chrome は許容)
- ただし完全なバックグラウンド (画面ロック) は PWA では限定的
  → UI 上で「録音中は画面を消さないでください」と明示

### 5.4 コスト管理

- 既存の `deepgram-realtime-usage` テーブル (`20260414000000_*.sql`) で課金カウント
- Android 経由の録音は WhisperKit fallback できないので 100% Deepgram
- 1コードあたりの月間最大分数 (例: 30h/月) を `redeem_invite_code` の戻り値で
  制限すべきか後日検討 → **Phase 1 では制限なし、Phase 6 で監視ダッシュボード追加**

---

## 6. PWA 化の具体仕様

### 6.1 `web/public/manifest.webmanifest`

```json
{
  "name": "Lecsy",
  "short_name": "Lecsy",
  "description": "Live captions and transcripts for your classroom.",
  "start_url": "/android?source=pwa",
  "scope": "/android",
  "display": "standalone",
  "orientation": "portrait",
  "background_color": "#ffffff",
  "theme_color": "#2563eb",
  "icons": [
    { "src": "/icons/icon-192.png", "sizes": "192x192", "type": "image/png" },
    { "src": "/icons/icon-512.png", "sizes": "512x512", "type": "image/png" },
    { "src": "/icons/icon-maskable-512.png", "sizes": "512x512", "type": "image/png", "purpose": "maskable" }
  ],
  "categories": ["education", "productivity"],
  "lang": "en"
}
```

### 6.2 `<head>` 追加 (`web/app/layout.tsx`)

```html
<link rel="manifest" href="/manifest.webmanifest" />
<meta name="theme-color" content="#2563eb" />
<meta name="mobile-web-app-capable" content="yes" />
```

### 6.3 Service Worker (`web/public/sw.js`)

- 戦略: app-shell キャッシュ (HTML / CSS / JS) + ネットワーク優先 (API)
- **音声データはキャッシュしない** (容量 + プライバシー)
- 登録は `web/app/android/layout.tsx` の `useEffect` 内で行う
- 実装は手書き or `next-pwa` パッケージ (依存追加が許容ならこちらが楽)

### 6.4 アイコン

- 192x192, 512x512, maskable 512x512 (safe zone 80%)
- 既存の `web/app/icon.png` (Next.js default) ベースで作る
- 仕様詳細は `android/ASSETS_SPEC.md` (後で作成) に分離

### 6.5 インストール促進 UX

- 初回訪問: 招待コード入力後、「ホーム画面に追加しよう」ガイドを表示
- `beforeinstallprompt` イベントを保持して、ユーザー操作後に `prompt()` を呼ぶ
- iOS 訪問者には別メッセージ (「iOS の方は App Store からどうぞ」)

---

## 7. UI / UX 仕様

### 7.1 デザイン原則

- iOS 版とビジュアル一貫性を保つ (色・タイポ)
- Android Material 3 ガイドラインは深追いしない (PWA としての一貫感優先)
- Tailwind の既存テーマ (`web/tailwind.config.ts`) を流用

### 7.2 画面リスト

1. **`/android` 招待コード入力**
   - Lecsy ロゴ + "Welcome" ヘッダ
   - 6文字入力欄 (オートフォーカス、英数字のみ、自動大文字化)
   - 「コード持ってない？」リンク → `mailto:` or pilot org 案内
2. **`/android/app` ホーム**
   - 大きな丸い「録音開始」ボタン (赤)
   - 「最近の文字起こし」3件
   - 下部 BottomNav (ホーム / ライブラリ / 設定)
3. **`/android/record` 録音中**
   - 巨大なタイマー
   - ライブ字幕 (interim 薄字 → final 濃字)
   - 「停止」ボタン
   - 「録音中は画面を消さないでください」注記
4. **`/android/library` 一覧**
   - 日付降順、タイトル + 長さ + 一部本文プレビュー
5. **`/android/t/[id]` 詳細**
   - 既存 `/app/t/[id]` と同じデータ構造、Android 用に再レイアウト
   - コピー / 共有 / 削除

### 7.3 アクセシビリティ

- 字幕フォントサイズは設定で 18 / 22 / 28 / 36px から選択可
- ハイコントラストモード (黒背景 + 黄字)
- すべてのボタンに aria-label

---

## 8. データモデル / DB

### 8.1 既存スキーマで足りる

- `organization_invite_codes` ✅
- `organization_members` ✅
- `transcripts` (`org_id` カラム済み) ✅
- `auth.users` (anonymous user 行が入る) ✅

### 8.2 追加が必要なもの

なし (Phase 1-6 では追加マイグレーション不要)。

将来 Phase 7 (監視) で `android_session_events` テーブル等を追加検討。

---

## 9. セキュリティ / プライバシー

| 項目 | 対応 |
|---|---|
| 招待コード総当たり攻撃 | 既存 `rate_limit` テーブル (`20260214100000`) を redeem RPC にも適用 (要追加) |
| FERPA 同意 | 既存フロー流用 (`20260418000000_ferpa_consent.sql`) |
| 音声データ保存 | 行わない (Deepgram に直接ストリーム、トランスクリプトのみ Supabase) |
| Service Worker のスコープ | `/android` 配下のみ (他ルートをキャッシュしない) |
| anon JWT 流出 | `localStorage` に persist。Service Worker で取り扱わない |
| マイク権限拒否 | 「設定からマイクを許可してください」案内 + リトライ |

---

## 10. 実装フェーズ (推定工数)

| Phase | 内容 | 工数 (ソロ) |
|---|---|---|
| **0. PWA 骨格** | manifest, icons, layout.tsx の link 追加 | 0.5 日 |
| **1. 招待コードゲート** | `/android` route, `InviteCodeForm`, signInAnonymously, redeem RPC | 1 日 |
| **2. UA gate middleware** | Android 検知 → `/android` リダイレクト | 0.5 日 |
| **3. 録音 + Deepgram** | `Recorder`, MediaRecorder, WebSocket, LiveCaption | 2 日 |
| **4. 保存 + ライブラリ + 詳細** | `library`, `t/[id]`, save-transcript 呼び出し | 1 日 |
| **5. Service Worker + offline** | sw.js, install promo | 0.5 日 |
| **6. 実機テスト + 修正** | Pixel + Galaxy で QA、bug fix | 1 日 |
| **小計** | | **~6.5 日** |
| **7. (後日) Capacitor + Play Store** | TWA or Capacitor wrap, store 申請 | 別途 2-3 週 |

**6/1 ローンチに乗せるなら 5/15 までに Phase 6 完了がデッドライン。**
MVP 凍結 5本との優先順位は別途相談。Phase 0-2 だけで「Android 招待制対応済み」と
営業で言えるので、最低限の差し込みは Phase 2 まで。

---

## 11. テスト計画 (概要、詳細は `TEST_PLAN.md`)

### 必須デバイス
- Pixel 7 以降 (Chrome)
- Galaxy S22 以降 (Samsung Internet, Chrome)
- 古めの Android (Pixel 4a 程度) — メモリ・パフォーマンス確認

### テスト項目
1. 招待コード redeem 成功 / 失敗 / 既使用
2. PWA インストール (A2HS) → standalone 起動 → セッション維持
3. マイク許可 → 録音開始 → ライブ字幕 → 停止 → 保存
4. 画面ロックでの挙動 (Wake Lock 効くか)
5. オフライン時のシェル表示
6. 既存 iOS ユーザーが PC ブラウザから `/android` を開いたときの挙動

### Chrome DevTools リモートデバッグ
- USB 接続 + `chrome://inspect` で実機 console 取得
- Lighthouse PWA audit を 90 点以上に

---

## 12. ローンチ準備

### 12.1 営業トーク更新
- 「Android あります、招待コード制でパイロット契約校限定」
- QR カード裏面に「Android: open camera, scan QR」と追記
- `/join/[slug]?code=XXX` ページに「Android はこちら」ボタン追加

### 12.2 ドキュメント
- `web/app/support/page.tsx` に Android セクション追加
- 教員向け配布資料 (PDF) に Android インストール手順を追加

### 12.3 監視
- Supabase で `organization_members` の `joined_at` を Android セッションと突き合わせ
- Deepgram の Android 経由分課金を週次レポート

---

## 13. 公開する / しないの判断基準

将来 Android を一般公開 (招待制を解除) するかは以下が満たされてから:
- B2B 契約校が 5校以上
- 1コードあたりの月間 Deepgram コストが 1ドル以下に最適化済み
- B2B 単価が黒字を担保している
- B2C 戦略上、Android で薄める意味がある (例: Play Store ランキング戦略開始)

それまでは **招待コードゲートを絶対に外さない**。

---

## 14. 関連ドキュメント / コード

- `Deepgram/EXECUTION_PLAN.md` — MVP スコープ凍結 (Android はその外)
- `supabase/migrations/20260420000000_invite_codes.sql` — 招待コード基盤
- `supabase/migrations/20260418000000_ferpa_consent.sql` — FERPA 同意
- `supabase/functions/deepgram-token/` — Deepgram WebSocket トークン発行
- `supabase/functions/save-transcript/` — トランスクリプト永続化
- `web/app/join/[slug]/page.tsx` — QR ランディング (Android 案内追加対象)
- `web/middleware.ts` — UA gate 追加対象
- `lecsy/Services/` (iOS 側) — 既存 deep-link / invite redeem 実装の参考
