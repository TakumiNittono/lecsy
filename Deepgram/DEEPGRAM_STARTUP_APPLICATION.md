# Deepgram Startup Program Application

Lecsy / 2026-04-15 提出用ドラフト

---

## Company website URL

```
https://www.lecsy.app/
```

---

## In 50 characters or less, what does your company do?

```
Lecture captions & translation for intl students.
```

(49 characters)

---

## What are you going to make?

### English (提出用)

```
Lecsy (https://www.lecsy.app/) is an iOS app that helps international students survive English-language lectures. Students record a class, and Lecsy transcribes it, translates it into their native language, and generates a structured summary, vocabulary list, and searchable transcript they can review before the exam. We are also building a B2B version for U.S. language schools, community colleges, and universities, so instructors can roll Lecsy out to an entire cohort and see which students are falling behind on comprehension.
```

### 日本語訳 (確認用)

Lecsy（https://www.lecsy.app/）は、留学生が英語の授業を乗り切るのを助けるiOSアプリです。学生が授業を録音すると、Lecsyがそれを文字起こしし、母国語に翻訳し、試験前に復習できる構造化されたサマリー・単語リスト・検索可能な文字起こしを生成します。さらに、米国の語学学校・コミュニティカレッジ・大学向けのB2B版も開発中で、講師がクラス単位でLecsyを導入し、どの学生が理解についていけていないかを把握できるようにします。

---

## What's new about what you're making?

### English (提出用)

```
Generic transcription tools are built for meetings and podcasts. They are not built for a 90-minute lecture packed with technical jargon, heavy accents, and code-switching — which is exactly the environment where international students are drowning. Lecsy is purpose-built for the classroom: translation and vocabulary extraction are first-class features, not afterthoughts, and the B2B layer is designed around how schools actually operate (cohort onboarding, per-class access, learning analytics). We are starting with U.S. language schools and community colleges — a segment every mainstream transcription product ignores — and expanding into 4-year universities from there.
```

### 日本語訳 (確認用)

一般的な文字起こしツールは会議やポッドキャスト向けに作られていて、専門用語・強いアクセント・コードスイッチングが飛び交う90分の授業用ではありません。まさにそこが留学生が溺れている環境です。Lecsyは教室に特化して設計されていて、翻訳と単語抽出を「おまけ」ではなく中心機能として扱い、B2B側も学校の実運用（コホート単位の導入、クラス別アクセス、学習分析）に合わせて設計しています。私たちはまず、主要な文字起こしプロダクトが誰も見向きもしない米国の語学学校とコミュニティカレッジから始めて、そこから4年制大学へ広げていきます。

---

## How will you use Deepgram in your product?

### English (提出用)

```
Today Lecsy's App Store version runs on Whisper, and it works — but Whisper's limits are exactly where our users struggle most: real-time streaming is weak, accuracy on heavily accented English drops, and long-form technical vocabulary is inconsistent. As we evaluated alternatives, Deepgram's Nova streaming model stood out on every one of those dimensions, which is why we want to move our core transcription pipeline onto Deepgram.

Specifically, we plan to use:
- Deepgram streaming (Nova) to add real-time live captions during lectures, which Whisper cannot reliably do on-device.
- Word-level timestamps and diarization to power our review features — searchable transcripts, auto-generated vocabulary cards, and separating lecturer speech from student questions.
- Multilingual / language-detection models to handle the code-switching that is common in ESL classrooms.

For an international student sitting in a lecture they can only half-understand, the gap between "captions that kind of work" and "captions they can rely on" is the difference between passing and failing a class. Deepgram is what lets us close that gap at scale — thousands of students across U.S. language schools and community colleges, and eventually 4-year universities.
```

### 日本語訳 (確認用)

現在、App Store版のLecsyはWhisperで動いていて、機能はしています。ただWhisperの弱点が、まさに私たちのユーザーが苦しんでいるポイントそのものです：リアルタイムストリーミングが弱い、強いアクセントへの精度が落ちる、長尺の専門用語が安定しない。代替を検討する中で、DeepgramのNovaストリーミングモデルがこのすべての面で群を抜いていたため、中核の文字起こしパイプラインをDeepgramに移行したいと考えています。

具体的な用途：
- Deepgramストリーミング(Nova)を使って、授業中のリアルタイムライブキャプションを実現する（Whisperではオンデバイスで安定して実現できない領域）
- 単語単位のタイムスタンプと話者分離で、復習機能を強化する（検索可能な文字起こし、自動単語カード生成、講師と学生の発話分離）
- 多言語／言語検出モデルで、ESL教室で頻発するコードスイッチングに対応する

英語の授業を半分しか理解できずに座っている留学生にとって、「なんとなく動くキャプション」と「信頼できるキャプション」の差は、単位を取れるか落とすかの差です。Deepgramは、このギャップをスケールして埋めるための鍵です。米国の語学学校・コミュニティカレッジの何千人もの学生、そして将来的には4年制大学へ。

---

## Is your company incorporated yet?

- [ ] Yes
- [ ] No

*(現状に合わせてチェック)*
