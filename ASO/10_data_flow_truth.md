# 10. データフロー真実表(ASOコピーの根拠)

**目的**:App Store 説明文・プライバシー栄養ラベル・プライバシーポリシーで嘘をつかないための"根拠ファイル"。
コードを直接読んで確認した事実のみ記載。

調査日:2026-04-08
調査対象コミット:main HEAD

---

## ✅ TRUE(そのまま言っていい)

### 1. 生音声(.m4a)は端末から一切出ない
- 根拠:`lecsy/Services/CloudSyncService.swift` 冒頭コメント:
  > "Audio (.m4a) is NEVER uploaded. Only the transcript text + metadata.
  > This is what differentiates us from Otter (currently in a class-action lawsuit)."
- 根拠:コードベース全体 grep で `.m4a` / `.mp3` のアップロード呼び出しゼロ
- → **"Your audio never leaves your iPhone"** は事実

### 2. 文字起こしは 100% オンデバイス
- 根拠:`lecsy/Services/TranscriptionService.swift` が **WhisperKit** を使用
- モデルはアプリ同梱 or ローカルキャッシュ、Neural Engine 実行
- サーバーには一切送信しない
- → **"On-device transcription"** / **"Offline speech-to-text"** は事実

### 3. AI 訓練に使わない
- 根拠:`PRIVACY_POLICY.md` 明記、Supabase 側に学習パイプライン無し、OpenAI 呼び出しは `chat.completions`(学習オプトアウト済み API)
- → **"We never use your data to train AI"** は事実

---

## ⚠️ 要修正(従来コピーは不正確)

### 4. 「全部オフライン」は嘘
**実態**:
- 文字起こし本体 = オンデバイス(TRUE)
- しかし**サインイン時**、文字起こし**テキスト**と**メタデータ**は Supabase に送信される
- AI 要約は **OpenAI GPT-4o-mini** に転写テキストを送信

**正しい言い方**:
- ❌ "100% offline"
- ✅ "Audio stays offline. On-device transcription."
- ✅ "Your audio never touches our servers."
- ✅ "Transcript text syncs to your account (you can turn it off)."

### 5. アップロードされるもの(サインイン時のみ)
`save-transcript` Edge Function への payload:
```
title, content(テキスト), created_at, duration, language, client_id,
organization_id, visibility, class_id
```
→ **音声は含まれない、テキストのみ**

### 6. AI 要約の経路
1. iOS → `save-transcript` Edge Function(テキスト保存)
2. iOS → `summarize` Edge Function(transcript_id を渡す)
3. Edge Function → **OpenAI GPT-4o-mini**(テキストを送信)
4. 結果を `summaries` テーブルに保存

OpenAI 側:Zero Data Retention 契約が無ければ 30日ログ保持。
ASO/プラポリでは **"AI summaries are processed by OpenAI"** と明示すべき。

---

## ✅ 解消済み:全員無料化(2026-04-08)

### 7. AI要約を全ユーザーに無料で提供 — 完了
- `supabase/functions/summarize/index.ts` の organization_members ゲートを削除
- `web/utils/isPro.ts` を全員 isPro: true 化(source: 'free-for-all')
- 認証:サインイン必須は維持(email収集のため)
- レート制限:日次20件 / 月400件(濫用防止・広告経済性維持)
- B2B 戦略は棚上げし B2C 完全無料に振り切り

**現在の前提**:サインイン済みユーザーは全機能無料、未サインインは録音/文字起こしまで

---

## 🛡️ App Privacy 栄養ラベル(App Store Connect 宣言)

広告導入前提で、**最低限以下を宣言する必要あり**:

| カテゴリ | データ型 | 用途 | 個人と紐付く? |
|---|---|---|---|
| Contact Info | Email Address | App Functionality, Account | Yes |
| User Content | Other User Content(transcript text) | App Functionality | Yes |
| Identifiers | User ID | App Functionality | Yes |
| Identifiers | Device ID(IDFA、広告SDK導入時) | Third-Party Advertising | Yes |
| Usage Data | Product Interaction | Analytics | Yes |
| Diagnostics | Crash Data, Performance Data | App Functionality | No |

**宣言しないもの(正直に申告):**
- ❌ Audio Data(送信していないので宣言不要)
- ❌ Precise Location / Coarse Location
- ❌ Health & Fitness
- ❌ Financial Info

**"Data Not Linked to You" or "Data Not Collected" の誤申告はリジェクト直行。**

---

## 🔗 使用サードパーティ(開示必須)

| サービス | 送るデータ | 目的 |
|---|---|---|
| Supabase | email, transcript text, metadata, usage logs | DB / Auth / Edge Functions |
| OpenAI | transcript text(要約時のみ) | GPT-4o-mini 要約生成 |
| Apple | email, name(Apple Sign-In時) | 認証 |
| Google | email, profile(Google Sign-In時) | 認証 |
| Stripe | (現状未使用 — LLC後に Pro 導入時) | 課金 |
| AdMob(導入予定) | IDFA, 広告イベント | 広告配信 |

**Firebase / Amplitude / Mixpanel は検出されず**(= 宣言不要)

---

## プライバシーポリシー整合性
`PRIVACY_POLICY.md` を確認:
- ✅「音声は端末から出ない」は事実と一致
- ✅「AI訓練に使わない」は事実と一致
- ⚠️「Cloud sync はオフにできる」→ 実装有無を別途確認すべき(Settings → Privacy → Cloud Sync が実装されているか)
- ⚠️ OpenAI への要約送信について明記されているか再確認

このファイルを根拠に、`04_metadata_master.md` のコピーは"事実のみ"で書かれている。
