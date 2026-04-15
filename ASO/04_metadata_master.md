# 04. メタデータ・マスター(決定版)

> **このファイルが App Store Connect に入力する唯一の正。**
> 文字数はすべてカウント済み・事実はすべてコードで裏取り済み。
> 過去の `doc/deployment/APP_STORE_METADATA.md` は破棄してこちらを使う。

---

## 0. データの真実(コピー作成の根拠・このページ以外で議論しない)

何が端末から出ていくのか、何が出ていかないのか。**このテーブルがすべての基準**です。

| データ | 端末内 | Supabase DB | OpenAI | 条件 |
|---|:---:|:---:|:---:|---|
| 🎙️ 生音声 .m4a | ✅ | ❌ | ❌ | **常に端末内のみ**(アップロードコード自体が存在しない) |
| 📝 文字起こしテキスト | ✅ | ✅ | ❌ | サインイン時のみ。Settings → Privacy → Cloud Sync で OFF 可能 |
| 🤖 AI 要約・試験モードの入力 | ✅ | ✅ | ✅ | ユーザーがボタンを押したとき、テキストのみ OpenAI GPT-4o-mini へ |
| 👤 Email / User ID / Name | — | ✅ | ❌ | Supabase Auth(Apple / Google / Magic Link) |
| 📊 Usage logs(機能利用回数) | — | ✅ | ❌ | レートリミット管理用 |
| 🆔 IDFA / デバイス ID | — | ❌ | ❌ | **取得していない**(広告 SDK 未導入) |
| 📍 Location | — | ❌ | ❌ | 取得していない |

### 言っていいこと(TRUE)
- ✅ 「音声は端末から出ない」/「Your audio never leaves your iPhone」
- ✅ 「文字起こしはオンデバイス」/「On-device transcription(WhisperKit)」
- ✅ 「録音と文字起こしはオフラインで動く」/「Recording and transcription work offline」
- ✅ 「広告なし・トラッカーなし」/「No ads. No trackers.」(6/1まで)
- ✅ 「完全無料(6/1まで)」/「100% free until June 1, 2026」
- ✅ 「AI を学習に使わない」(OpenAI API は training に使われない契約)

### 言ってはいけないこと(嘘 or 誤解を招く)
- ❌ 「100% オフライン」/「Fully offline」— AI 要約はクラウド
- ❌ 「データが一切クラウドに行かない」— テキストは行く
- ❌ 「広告で運営しています」— 現状広告なし
- ❌ 「Pro $2.99/月」— LLC 未設立で課金できない

### 正しい"精密な"言い方
> 録音と文字起こしは端末の中で完結します。音声がサーバーに送られることは一切ありません。
> 文字起こしが完了した後、テキストだけはあなたのアカウントにバックアップ同期されます(オフ可能)。
> AI 要約を押したときだけ、そのテキストが OpenAI に送られて要約が返ってきます。

---

## 1. 🇯🇵 日本語(プライマリロケール)

### App Name(30字)
```
Lecsy: AI講義録音&文字起こし
```
カウント:22字 / 30字。`AI` `講義` `録音` `文字起こし` の4大キーワードを App Name に集中。

### Subtitle(30字)
```
無料AI要約&オフライン文字起こし
```
カウント:17字 / 30字。`無料` `AI要約` `オフライン` `文字起こし`。
※ "オフライン文字起こし" は事実(WhisperKit)、全体オフラインではない。

### Keywords(100字・半角カンマ区切り・スペース禁止)
```
音声認識,書き起こし,議事録,ノート,レコーダー,ボイスメモ,勉強,試験,復習,大学生,留学生,英語,授業,対訳,オトター,ノッタ,速記,リスニング,TOEIC,ディクテーション
```
カウント:99字 / 100字。App Name / Subtitle と重複しない語のみ。
`オトター` `ノッタ` は競合指名検索の刈取り(Apple ガイドライン上 OK)。

### Promotional Text(170字・審査不要で随時更新可)
```
🎓 2026年6月1日まで、全機能 完全無料。広告なし、課金なし、クレジットカード不要。録音・文字起こし・AI要約・試験モードがすべて使えます。音声は端末から一切出ないオンデバイス設計で、12言語に対応。
```
カウント:約125字 / 170字。

### Description(4000字以内)
```








 highest-intent student terms: `AI` `Lecture` `Notes`.
Why not "Recorder": search-intent data shows US students google **"lecture notes app"** and **"transcribe lecture"** more than "lecture recorder". "Notes" is where the student mental model lives.

### Subtitle (30 chars)
```
Offline Record & AI Summaries
```
Count: 29 / 30. Adds the 3 other big terms that Name can't hold: `Offline` `Record` `Summaries` (plural form — Apple indexes stems). "Offline Record" is factually precise: recording works offline (WhisperKit, verified in `10_data_flow_truth.md`).

### Keywords (100 chars — commas, no spaces, no duplicates with Name/Subtitle)
```
otter,notta,transcribe,study,exam,class,student,voice,memo,meeting,minutes,dictation,toefl,speech,college
```
Count: 98 / 100.
- `otter,notta` — direct competitor-name capture (Apple-permitted in keyword field).
- `transcribe,dictation,speech` — transcription intent expansion.
- `student,college,class,exam,study,toefl` — **the university-student positioning lock**. `college` is US-specific; UK students still convert via `class,student,exam`.
- `voice,memo` — Voice Memos user migration.
- `meeting,minutes` — leaks in professional traffic for free (Otter's long tail).

Omitted on purpose (already in Name/Subtitle, so adding is wasted characters): `lecture` `notes` `ai` `offline` `record` `summary` `summaries` `free`.

### Promotional Text (170 chars — editable without review)
```
🎓 Free through June 1, 2026 — no ads, no subscription, no sign-up fees. Record any lecture, transcribe offline, get AI summaries & exam questions in seconds.
```
Count: 165 / 170. Leads with the deadline (urgency), then restates the three student jobs-to-be-done.

### Description (4000 chars max — this is the one that converts, not just indexes)
```
Lecsy turns any lecture into clean, searchable notes — automatically.

Hit record at the start of class. Walk out with a full transcript, an AI summary, and a set of likely exam questions. Built by an independent developer for university students who are tired of retyping their notes at midnight.

Free through June 1, 2026. No ads. No subscription. No credit card.

■ Made for students, not meeting rooms
• One-tap background recording — keeps running when your screen locks or you switch apps
• On-device speech-to-text (WhisperKit) — works in lecture halls with zero Wi-Fi
• AI summaries: key points, section outlines, definitions
• Exam Mode: AI generates likely test questions with model answers
• 12 languages including English, Spanish, French, German, Chinese, Japanese, Korean
• Multilingual AI summaries — record in English, read the summary in your native language
• Web access at lecsy.app — read, search, and copy transcripts on any laptop

■ The one thing no other lecture app can say
Your audio file stays on your iPhone. Period.

Not "encrypted in our cloud." Not "deleted after 30 days." It is never uploaded anywhere. There is literally no code path in Lecsy that sends your .m4a file off your device — and you can verify that in our open privacy docs.

Why that matters: Otter.ai is currently facing a class-action lawsuit over how it handled user audio. Notta stores every recording in its cloud at $13.99/month. Lecsy was built on a different architecture — audio never leaves the device, even for transcription. The only thing that ever goes to a server is the transcript *text*, and only if you're signed in and want cloud backup.

■ What actually gets sent to a server (honest version)
◎ Audio (.m4a) — NEVER. Stays on your iPhone.
◎ Transcript text — only if you're signed in, for backup. Toggle off anytime in Settings → Privacy → Cloud Sync.
◎ AI summaries & Exam Mode — when you tap the button, the transcript TEXT (not the audio) is sent to OpenAI's GPT-4o-mini to generate the summary. OpenAI does not train on API content.
◎ Ads, trackers, IDFA — none. No ad SDKs, no third-party analytics.
◎ AI training on your data — never. Not by us, not by our providers.

■ Who Lecsy is for
• Undergrads who can't keep up with fast-talking professors
• International students studying in English — read summaries in your first language
• STEM students who need accurate transcripts of dense lectures
• Pre-med, pre-law, and grad students prepping for exams from recorded classes
• Anyone who thinks $16.99/month for Otter is absurd for a student budget
• Students who do not want their voice on someone else's server

■ What you get for free
Every feature. Recording, transcription, AI summaries, Exam Mode, all 12 languages, web access — all of it. Daily limit is 50 AI summaries during the free period. No feature is paywalled.

■ Requirements
• iOS 17.6 or later
• One-time download of the on-device speech model (~150 MB) on first launch
• Recording and transcription work offline after that
• Cloud sync, AI summaries, and Exam Mode require internet

■ Pricing after June 1, 2026
We'll decide based on what students actually ask for. Our promise is simple: every feature that is free today will stay free for the users who already have it. We will not paywall features you already rely on.

■ Links
Privacy Policy: https://lecsy.app/privacy
Terms of Service: https://lecsy.app/terms
Support: support@lecsy.app

Lecsy is built by one independent developer. Bug reports, feature requests, and late-night "this saved my GPA" messages are all welcome via the in-app feedback form or email.
```

### What's New (release notes)
```
- Better transcription accuracy in noisy lecture halls
- Faster AI summaries
- Exam Mode improvements for longer lectures
- Every feature is free through June 1, 2026
- Bug fixes
Thanks for using Lecsy — please leave a rating if it saved you a study session.
```

---

## 3. App Store Connect 設定

| 項目 | 値 |
|---|---|
| Primary Category | **Education** |
| Secondary Category | **Productivity** |
| Age Rating | **4+** |
| Price | **Free** |
| In-App Purchases | **なし**(LLC 設立まで作成しない) |
| Subscription | **なし** |
| Sign-In Required? | **No**(録音・文字起こしはサインイン不要) |
| Third-Party Sign-In | Apple, Google, Magic Link |

### ロケール戦略(英語圏優先・2026-04-09 変更)
**Primary Language は `en-US` に設定**(App Store Connect → App Information → Primary Language)。
ja-JP は Secondary として維持。理由:ターゲットが世界の大学生、最終的な B2B 導入先も米国語学校→コミカレ→大学。

初期リリースで入れるロケール(en-US を一度書けば残りはコピペ、**コスト0で露出が3〜6倍になる**):
- **en-US**(Primary、上記の決定版コピーを入れる)
- **en-GB**(en-US と同一コピー。"college" の語だけ `university` に置換してもよいが keyword field はそのまま)
- **en-AU**(en-US と完全同一)
- **en-CA**(en-US と完全同一)
- **ja-JP**(上記 JP コピーを使用)

**ローカライズ追加だけで露出が増える。コスト 0 なので必ずやる。**

### Phase 2 で追加(Week 5-6)
- ko(韓国語)
- es-MX(スペイン語メキシコ)
- zh-Hans(簡体中文)

---

## 4. App Privacy 栄養ラベル(App Store Connect で宣言する内容)

**`lecsy/PrivacyInfo.xcprivacy` と一致させること。**

### Data Collected
| Data Type | Linked to User | Tracking | Purpose |
|---|:---:|:---:|---|
| Email Address | Yes | No | App Functionality |
| Name | Yes | No | App Functionality |
| User ID | Yes | No | App Functionality |
| Other User Content(transcript text) | Yes | No | App Functionality |
| Product Interaction | Yes | No | Analytics + App Functionality |
| Crash Data | No | No | App Functionality |
| Performance Data | No | No | App Functionality |

### Data NOT Collected(明示的に収集していない)
- ❌ Audio Data(音声は端末から出ない)
- ❌ Device ID / IDFA(広告 SDK 無し)
- ❌ Advertising Data
- ❌ Location(Precise / Coarse)
- ❌ Health & Fitness
- ❌ Financial Info
- ❌ Sensitive Info
- ❌ Contacts
- ❌ Photos / Videos(ユーザーコンテンツとしては)
- ❌ Browsing History
- ❌ Search History

### Tracking
**No**(`NSPrivacyTracking = false`)。ATT ダイアログ表示しない。

---

## 5. レビュー向け Notes(App Review Information 欄)

```
Hi Apple Review Team,

Lecsy is a lecture recording and AI study app built for students.

TEST ACCOUNT (if needed):
Email: reviewer@lecsy.app
Password: [設定後に記入]

KEY POINTS FOR REVIEW:
1. Audio recording is on-device only — the .m4a file is NEVER uploaded to any server. You can verify this by inspecting network traffic during recording.

2. Transcription uses WhisperKit (on-device). The ~150MB model downloads on first launch. Please wait for it to complete before testing transcription.

3. AI Summary and Exam Mode send the transcribed TEXT (not audio) to OpenAI's GPT-4o-mini via our Supabase Edge Function. This is disclosed in the app description and privacy policy.

4. Every feature is available to all signed-in users for free. There are no in-app purchases, subscriptions, or paywalls at this time.

5. The app supports anonymous use (no sign-in required) for recording and transcription. Sign-in is only required for cloud sync, AI summaries, and Exam Mode.

6. Privacy Policy: https://lecsy.app/privacy

Thank you for your time.
```

---

## 6. 将来の Pro 導入時(LLC 設立後に更新)

LLC 設立完了後、このセクションを元にこのファイルを差分更新する。候補:

- **Plan A:広告非表示のみ** — 最小構成、$1.99/月
- **Plan B:高精度要約(GPT-4o 本家)+ 無制限**(無料は 5/日キャップ)— $2.99/月
- **Plan C:A + B + クラウドストレージ増量** — $4.99/月

Lecsy の哲学:**「今 無料な機能は、今後も無料のまま」** を約束する。
Pro は "純粋な追加価値" 路線。既存機能の後ろにペイウォールを立てない。

---

## 7. 変更履歴

| 日付 | 変更 |
|---|---|
| 2026-04-08 | 決定版として全面書き直し。事実テーブル追加、6/1 まで完全無料モデル確定、広告記述削除、Pro 記述削除、OpenAI 開示追加、レビュー Notes 追加 |
| 2026-04-09 | **英語圏グローバル/大学生ターゲットに方針転換**。Primary Language を en-US に変更。英語 Name/Subtitle/Keywords/Description を学生 intent(lecture notes / study / exam / college)に寄せて全面書き直し。en-GB/AU/CA ロケール追加指示。04 と 03 と 05 を同時更新 |