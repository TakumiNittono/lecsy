# Lecsy — Briefing for Alex

Last updated: 2026-04-19
From: Takumi
For: Alex

Hey Alex — this doc is for you. It explains what Lecsy is, why it matters, what the plan is for FMCC in May and June, and where I'd love your help. Read it whenever you have time, and tell me anything that is unclear or that you think I'm missing.

---

## 1. What Lecsy is, in one paragraph

Lecsy is a mobile and web app that turns a live lecture into **real-time captions** and a **clean summary** they can study from later. It's designed for students who struggle to follow a class in English — international students, ESL learners, students with hearing or processing differences. They open the app, the professor starts talking, and the student reads along in English. After class, they get a searchable transcript and an AI-generated summary.

Think of it as **closed captions + an automatic notetaker**, built specifically for classrooms.

## 2. Why it matters

- International students in US community colleges and universities often understand only ~60–70% of a fast-spoken lecture. That gap is the single biggest reason they underperform compared to their actual ability.
- Existing solutions (Otter, manual notetakers, closed captions) are either too generic, too expensive for a school, or not built for the classroom. Lecsy is designed specifically for lectures and for students who are still learning English.
- The market isn't small. Every community college and language school in the US has this exact problem. Worldwide, hundreds of millions of students learn in a language that isn't their strongest.

## 3. Where it runs today

- **iOS app** — live on the App Store. This is the main product students use in class.
- **Web app (lecsy.app)** — students can review transcripts on their laptop, and schools can manage their organization, users, and usage there.
- **Backend** — Supabase for data + auth, Deepgram for real-time transcription, OpenAI for summaries, Stripe for billing.
- The app is already being used in production by individual students (B2C). The B2B / school-level features are what we are rolling out now.

## 4. What we're building right now (90-day plan, locked)

Ship-or-kill by June 8:
1. **School accounts (organizations)** — a school can enroll students in bulk, assign licenses, and see usage.
2. **FERPA consent flow** — before a student's audio is processed, they agree to a privacy notice that meets US education privacy law.
3. **Study streak / engagement** — to pull students back into the app after class and build a habit.
4. **Stripe billing on iOS** — schools pay via invoice, individuals pay via subscription.

Tech work beyond these is paused. Everything else is noise until June.

## 5. The FMCC pilot — the part I need your help with

**Big picture**: FMCC is our first real school. If we land them, it proves the model and opens doors to every other community college on the East Coast.

**Timeline**:
- **May 1 – May 6**: I fly out, stay near you, and we run a working pilot at FMCC. It's still informal — no contract yet, we're proving the product works in a real classroom.
- **May 7 – May 31**: Follow-up. Emails, meetings, legal review, pricing. Goal is a signed agreement (or at minimum a signed letter of intent) before the semester starts.
- **June 1**: Language Center (LC) semester begins. If everything goes right, Lecsy is live in real classes under a real contract.

**Key people on the FMCC side**:
- **Ryoko Sekiguchi** (extension **x8149**) — our warm intro inside FMCC. She's expecting us.
- **Beth Carpenter** — my former host family. She's local, knows people, and is our community anchor.

## 6. Where I'd love your help

You are not just a driver or an assistant — you are a **co-pilot** for the US side of this business. You are American, you speak English natively, and you're studying tax and law. That combination is exactly what I need in the room at FMCC. Specifically:

1. **In-person support at FMCC (May 1–6)**: come with me to meetings, help me read the room, jump in when my English isn't landing. Your house is 10 minutes from campus — you're the closest person to the target.
2. **Email and written communication**: review any important email I send to FMCC staff before it goes out. Catch awkward phrasing and cultural misses.
3. **Paperwork review**: when we get to contracts, consent forms, and pricing letters, I want you to read them with me before a lawyer finalizes anything. I trust your judgment on what "feels normal" in a US school context.
4. **Local follow-through (after May 6)**: if FMCC asks for a quick demo, a document drop-off, or a face-to-face meeting after I fly home, you can be there in 10 minutes. That alone is a huge advantage.
5. **Community knowledge**: through Beth and your own network, tell me which FMCC staff actually decides, not just who says yes in meetings.

I'll put our arrangement (hours, compensation, scope) in writing separately. This doc is about the work itself.

## 7. Why I'm telling YOU all of this

We've known each other for over a year and eight months. You've seen this project grow from zero. I trust you — fully — with the business side of what happens in New York. My plan to make Lecsy work in the US depends on having someone there who understands both the country and me. That's you.

## 8. Questions I'd like your take on

- What's the best way to approach FMCC's administration — bottom-up (teachers first) or top-down (dean first)?
- Are there tax implications for how I pay you (W-9, 1099, cash, hourly vs. project)?
- If we get a verbal "yes" in May, what's the cleanest way to convert it to a signed piece of paper before June 1?
- Anything you think I'm underestimating about doing business in the US as a non-citizen?

No rush — answer when it fits you. I'd rather you think carefully than reply fast.

Thanks, Alex. Let's make this one count.

— Takumi
