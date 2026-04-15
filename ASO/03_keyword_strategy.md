# 03. キーワード戦略

## 原則(Apple ASO 2026)
1. **App Name (30字)** = 最強シグナル。ブランド+主要 KW 1つ。
2. **Subtitle (30字)** = 2番目に強い。別軸の KW。
3. **Keyword Field (100字)** = カンマ区切り、スペース入れない、重複禁止、**App Name/Subtitle の語は書かない**(二重登録の無駄)。
4. **競合アプリ名**は Keyword フィールドに入れて OK(Apple は許容)。
5. **カテゴリ・開発者名・アプリ内購入名**も検索対象。

---

## 🇯🇵 日本語ロケール

### App Name(30字)
```
Lecsy: 講義録音&文字起こしAI
```
→ 「講義録音」「文字起こし」「AI」を App Name に載せ最強シグナル化。

### Subtitle(30字)
```

```
→ 「オフライン」「議事録」という別軸ビッグワードを獲得。

### Keywords(100字、スペース無し、カンマ区切り)
```
音声認識,書き起こし,ノート,勉強,試験,要約,大学生,留学,英語,オトター,ノッタ,レコーダー,ボイスメモ,対訳,速記
```
理由:
- Name/Subtitle に無い語のみ
- 「オトター/ノッタ」= 競合指名検索奪取
- 「留学/対訳」= 独自ポジション
- 「ボイスメモ/レコーダー」= 汎用流入
- 「試験/要約/勉強」= Pro 機能

---

## 🇺🇸 英語ロケール(US/グローバル) — **Primary Locale**

> ターゲット:英語圏の大学生。検索 intent は「lecture notes app」「transcribe lecture」「free otter alternative」「study from recorded lectures」。
> `04_metadata_master.md` の英語版とこの戦略は**必ず同期**していること。

### App Name(30字)
```
Lecsy: AI Lecture Notes
```
23字。`AI` + `Lecture` + `Notes` を1枚に束ねる。
"Recorder" は卒業:"lecture notes app" の方が月間検索の学生 intent が高く、"notes" は学生の mental model の中心。録音機能は Subtitle で回収する。

### Subtitle(30字)
```
Offline Record & AI Summaries
```
29字。Name で掴めなかった別軸 3 語 `Offline` `Record` `Summaries`(複数形はステマー indexing で単数も拾う)。

### Keywords(100字)
```
otter,notta,transcribe,study,exam,class,student,voice,memo,meeting,minutes,dictation,toefl,speech,college
```
98字。
- `otter,notta` = 競合指名(**最重要**、Apple ガイドライン OK)
- `transcribe,dictation,speech` = transcription intent
- `student,college,class,exam,study,toefl` = **大学生ポジションの鎖**。`college` で米国を掴み、`toefl` で留学生・語学学校ルートを掴む(B2B の種)
- `voice,memo` = Voice Memos 移行層
- `meeting,minutes` = Otter のプロユーザー流入(副次)

**Name/Subtitle と重複しないよう意図的に除外した語**(重複登録は無駄):`lecture` `notes` `ai` `offline` `record` `summary` `free`。

---

## 🇰🇷 韓国語(将来)
- App Name: `Lecsy: 강의 녹음 AI`
- Subtitle: `오프라인 받아쓰기와 요약`
- Keywords: `녹취,받아쓰기,노트,시험,유학,영어,회의록,오터`

## 🇪🇸 スペイン語(将来 — 米国ヒスパニック + ラテン)
- App Name: `Lecsy: Grabadora de Clases AI`
- Subtitle: `Transcribe sin conexión`
- Keywords: `transcribir,dictado,notas,examen,universidad,reunión,voz,otter`

## 🇨🇳 中文簡体(将来)
- App Name: `Lecsy: 讲课录音转文字AI`
- Subtitle: `离线转写与AI总结`
- Keywords: `录音,转写,笔记,考试,留学,会议,语音,讯飞,otter`

---

## 禁止事項(リジェクト/順位下落リスク)
- ❌ 競合名を App Name / Subtitle / Description に入れる(Keyword フィールドは OK)
- ❌ "#1" "Best" 等の優越的表現を名前に入れる
- ❌ Keyword フィールドに単数/複数両方(`note,notes`)→ 片方で十分
- ❌ スペース入り(`ai note` ではなく `ai,note`)

## 更新運用
- **4週間ごと**に App Store Connect → App Analytics → "Search Terms" を確認
- 流入の多い語を App Name / Subtitle に昇格、弱い語を Keyword から外す
- リリースのたびに A/B テスト(Product Page Optimization)を1枠回す
