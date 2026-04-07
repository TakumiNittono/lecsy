# Lecsy ピッチ資料 — ESL プログラム / 大学 ISSO 向け

最終更新: 2026-04-07
ターゲット: 米国の Intensive English Program (IEP) / ESL Director / International Student Services Office (ISSO) Director
戦略マスタ: `doc/STRATEGIC_REVIEW_2026Q2.md`

旧版 (個人課金 / 一般 SaaS 文脈) は git history `B2B/06_PITCH_MATERIALS.md@bb9d006` 参照。

---

## 1. 30 秒ピッチ (口頭で言う版)

> Lecsy は、留学生のための iPhone ネイティブの講義ノートアプリです。
> 学生が iPhone で講義を録音すると、デバイス上で文字起こしされ、AI が学生の母語 (日本語、韓国語、中国語、スペイン語、フランス語、ドイツ語、英語の 7 言語) で要約を作ります。
> 英語と母語の bilingual ノートが並列表示されるので、学生は単語を学びながら内容を理解できます。
>
> 音声ファイルは絶対にサーバーに送信しません。テキストだけです。
> Otter.ai が現在 集団訴訟を抱えてる "勝手に学習データに使われる" 問題、私たちは構造的に存在しません。
>
> 御校の学生が今あるアプリ (Otter, Notta) で困ってるのは、英語のままの要約しか出ないこと、そして学校管理者が活動を把握できないこと。Lecsy はその両方を解決します。

---

## 2. 1 ページピッチ (PDF / メール添付用)

### What is Lecsy?

**An iOS-native lecture companion built specifically for international students who study in English.**

- Records lectures directly on the student's iPhone
- Transcribes on-device using Whisper (no cloud round-trip for audio)
- Generates AI summaries in 7 languages: 日本語 / English / 中文 / 한국어 / Español / Français / Deutsch
- **Bilingual mode**: shows the summary side-by-side in the student's native language and English, so they learn vocabulary while understanding content
- Web dashboard for ESL Directors / ISSO staff to see student activity, search transcripts, and export CSV reports

### Why it matters for your program

| Pain | Lecsy solution |
|---|---|
| International students fall behind in fast-paced lectures | AI summary in their native language, available within 30 seconds of class ending |
| TOEFL passed, but academic English still hard | Bilingual notes — read the same content in both languages |
| Otter / Notta only summarize in English | 7 languages, optimized for academic terminology |
| Privacy concerns about classroom recording | Audio NEVER leaves the iPhone. Only transcript text is stored. We do not train AI on student data |
| You cannot see how your students are doing | Web dashboard: per-student activity, search across all transcripts, weekly CSV exports |
| You don't have IT bandwidth for SOC2 procurement | Free pilot — no SOC2 box-check required for the pilot program |

### What you get

- iOS app, free for all your students for the duration of the pilot
- Web admin dashboard at `lecsy.app/org/your-school`
- Per-student activity reports
- Full transcript search
- Weekly CSV export of all activity
- Direct line to the founder (me) for feedback and feature requests

### What we ask in return (pilot)

- Use it for one semester (~14 weeks)
- A 30-minute end-of-semester debrief call with your team
- Permission to use your school's logo on our website (optional, can be anonymous)

### Pricing after pilot

- **ESL / IEP programs**: $5 per seat per month, annual contract, minimum 50 seats
  - 50 seats × $5 × 12 = **$3,000 / year**
  - Most ESL programs of 100-300 students fit comfortably
- **University ISSO**: $10 per seat per month, annual contract, minimum 100 seats
  - 100 seats × $10 × 12 = **$12,000 / year**
- **Enterprise (full university)**: custom + SOC2 — available 2026 Q3 onwards

### Otter.ai vs Lecsy

| | Otter Business | Lecsy ESL |
|---|---|---|
| Per seat / month | $20 | **$5** |
| Native iOS app | ❌ Web/Android-first | ✅ iOS native |
| Multi-language summary | ❌ English only | ✅ 7 languages |
| Bilingual side-by-side notes | ❌ | ✅ |
| Audio storage | ☁️ Cloud | 📱 Device only |
| AI training on your data | ⚠️ Yes (basis of 2025-08 class action lawsuit) | ❌ Never |
| Built for international students | ❌ Built for meetings | ✅ Built for lectures |

---

## 3. 5 分プレゼン (Loom 録画用台本)

### Slide 1 — Hook (10 秒)

> "30% of your international students will tell you privately that they can't follow English lectures at full speed. They passed TOEFL. They're not slow learners. The vocabulary just hits faster than they can process. I built Lecsy because that was me."

### Slide 2 — Demo: record (30 秒)

> "Here's what they do. Open Lecsy on their iPhone. Tap record. Set the language they want notes in — let's say Japanese. Sit through class normally."
>
> [Show iPhone screen recording]

### Slide 3 — Demo: bilingual summary (60 秒)

> "Class ends. Tap stop. The transcription is already on their phone — it ran on-device while the lecture was happening. They tap 'Generate Summary'. Within 30 seconds they have this:"
>
> [Show side-by-side bilingual notes]
>
> "Left side: full summary in Japanese. Right side: same summary in English. Key points, sections, exam-prep questions. They read the Japanese to understand. They read the English to learn vocabulary. Same lecture, two languages, no extra study time."

### Slide 4 — Demo: web admin (60 秒)

> "Now let me show you what YOU see. This is the web dashboard for an ESL Director. You see your total students, how many recordings they made this week, total recorded minutes, language breakdown."
>
> [Show /org/[slug] dashboard]
>
> "Click any student to see their individual activity timeline. Search across all your students' transcripts. Export the whole thing to CSV for your weekly report."
>
> [Show /org/[slug]/students/[id]]

### Slide 5 — Privacy (45 秒)

> "Three privacy points your IT department will ask about:
>
> 1. We never upload audio. Period. The recording stays on the student's iPhone. We only get the text transcription.
> 2. We never train AI on your students' content. If you compare us to Otter — they're currently in a class action lawsuit on exactly this issue, filed August 2025.
> 3. FERPA-aligned. We have a DPA template ready. No student PII in URLs, no data sharing with third parties beyond the OpenAI API call for summaries.
>
> If your IT requires SOC2 — we don't have it yet. We're launching pilots first, then pursuing SOC2 in late 2026. For the pilot semester, no SOC2 is required because we treat it as a research instrument, not a system of record."

### Slide 6 — Ask (30 秒)

> "Here's what I want from you. Free pilot for one semester. I onboard your team in 30 minutes. Your students download the app. At the end of the semester, you give me 30 minutes of feedback. That's it.
>
> If it works for your students, we talk pricing in the spring. If it doesn't, you owe me nothing.
>
> I'm a solo founder, currently on OPT in the US. I built this because I needed it. I'm looking for 4 partner programs to validate it before scaling.
>
> Are you in?"

---

## 4. FAQ (商談で聞かれたら答える用)

### Q: How is this different from Otter / Notta?
A: Three things. (1) iOS native, not browser-first. (2) Native-language summaries in 7 languages, not just English. (3) Audio never leaves the device. Otter and Notta both store full audio in the cloud and use it for AI training — that's the basis of the 2025 class action.

### Q: What if a student doesn't have an iPhone?
A: Honest answer: we don't support Android yet. International students from Asia (China, Korea, Japan, Taiwan, Hong Kong) are 70%+ iPhone — that's our beachhead. Android is a 2026 Q4 plan.

### Q: How accurate is the transcription?
A: Whisper-medium model on-device. ~92% on clean classroom audio with a single English-speaking professor. Accuracy degrades with thick accents (true of all transcription tools). We recommend students sit in the front 1/3 of the lecture hall.

### Q: What about copyright? Recording professors without permission?
A: The student is responsible for getting professor permission, just like with any recording app. We show a one-time consent modal in the app on first launch reminding them. Most US universities allow personal lecture recording for accessibility / second-language reasons, but the student should always check.

### Q: Do you integrate with our LMS (Canvas, Blackboard, Moodle)?
A: Not yet. On the roadmap for Q4 2026 if the pilot proves the core value.

### Q: Can professors opt students out?
A: Yes — and it's easy. We can add a "do not record this class" registration to a student's profile. Or the professor can simply tell students at the start of class. We'll honor any request.

### Q: What happens to my students' data when the pilot ends?
A: If you don't continue, every student gets a one-time export of their notes (CSV + JSON), and we delete all transcripts within 30 days of contract end. Standard SaaS exit.

### Q: What's the minimum commitment?
A: Pilot = 14 weeks (one semester). After that, annual contract, minimum 50 seats. We don't do month-to-month for B2B because it's not how schools budget anyway.

### Q: Why are you so cheap compared to Otter ($5 vs $20)?
A: Three reasons. (1) Solo founder, near-zero overhead. (2) International students segment is underserved — we'd rather get you to "yes" at $5 than miss the wedge at $20. (3) We're early. The price will go up after we have 10 paying schools and SOC2.

---

## 5. ピッチ資料の使い分け

| シーン | 使うもの |
|---|---|
| 最初のコールドメール | §1 (30 秒) を本文に + §2 (1 ページ) を PDF 添付 |
| デモ商談 (30 分) | §3 (5 分プレゼン) で 5 分話して残り 25 分は対話 |
| 商談中の質問対応 | §4 FAQ |
| クロージング後の正式提案書 | §2 (1 ページ) を整形した PDF |
