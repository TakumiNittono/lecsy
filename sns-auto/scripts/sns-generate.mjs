#!/usr/bin/env node
// sns-generate.mjs — 在庫候補から Claude API で投稿本文を生成する
//
// Usage (lib):
//   import { generatePost } from "./sns-generate.mjs";
//   const post = await generatePost({ id, ch, sourceNote, angle, lang });
//
// CLI (単体テスト用):
//   node scripts/sns-generate.mjs --id=SNS-001
//
// 契約:
//   - Claude は Vault 抜粋に書かれた事実のみを使う。推測・追加数字は禁止
//   - 出力は JSON: { mode: "single"|"thread", text: string, thread?: string[] }
//   - 失敗時は throw

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import dotenv from "dotenv";
dotenv.config({ path: fileURLToPath(new URL("../.env.local", import.meta.url)) });
dotenv.config();
import OpenAI from "openai";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, "..");
const VAULT = path.resolve(ROOT, "../_Vault");
const TONE_FILE = path.join(VAULT, "SNS/tone_sample.md");

const DEFAULT_TONE = `
- 話者: Florida で OPT 中の個人開発者 (Lecsy 作り中、B2B ESL 攻め中)
- 文体: タメ口中心、実測主義、数字ファースト
- 全投稿は Q + A (3 点) 構造、最後は taste 1 行で閉じる
- 絶対 NG: 本名 (Nittono/新藤)、肩書き (Founder/CEO)、完了形 (launched/sold/built)、自分語り、ハッシュタグ
- taste: 実測主義 / Apple 美学 / 誇大 (業界初/シームレス/革新的) を嫌う
`.trim();

function loadTone() {
  if (!fs.existsSync(TONE_FILE)) return DEFAULT_TONE;
  const content = fs.readFileSync(TONE_FILE, "utf8").trim();
  return content.length > 50 ? content : DEFAULT_TONE;
}

function resolveSource(sourceNote) {
  const wikilink = sourceNote.match(/\[\[([^\]]+)\]\]/);
  if (wikilink) {
    const rel = wikilink[1];
    const candidates = [path.join(VAULT, rel + ".md"), path.join(VAULT, rel)];
    for (const c of candidates) if (fs.existsSync(c)) return c;
    const name = rel.split("/").pop() + ".md";
    return findByName(VAULT, name);
  }
  const bt = sourceNote.match(/`([^`]+)`/);
  if (bt) {
    const rel = bt[1].split("#")[0];
    const abs = path.resolve(VAULT, "..", rel);
    if (fs.existsSync(abs)) return abs;
  }
  return null;
}

function findByName(dir, name) {
  const entries = fs.readdirSync(dir, { withFileTypes: true });
  for (const e of entries) {
    if (e.name.startsWith(".") || e.name === "node_modules") continue;
    const full = path.join(dir, e.name);
    if (e.isDirectory()) {
      const sub = findByName(full, name);
      if (sub) return sub;
    } else if (e.name === name) return full;
  }
  return null;
}

function buildSystemPrompt(tone, ch, lang) {
  const charBudget = ch === "LI"
    ? "2000-2500 字 (LinkedIn)"
    : `**日本語 1 字 = X の 2 unit**。URL は 23 unit 固定。上限 280 units。

単発 (mode: single): **本文 日本語 100 字以内** + URL 1 つ。これを超える内容は thread にする。

thread 推奨 (内容が重い時): 3 ツイ、各 90 字以内 日本語 + 最後のツイに URL。
- 1/3: Q + 背景 1 行
- 2/3: A (要点 + 数字)
- 3/3: 比較 + taste + URL`;
  const platformRule = ch === "LI"
    ? "LinkedIn: Q → A (3 点) → taste 閉じ → 出典 URL"
    : "X: 単発なら 140-280 字 1 ツイ。スレッドなら 3-5 ツイ、ツイ間は '---' で区切る";
  return `あなたは @takumi_global の代筆者です。この account は **「AI 業界の最新発表を builder 視点で読む」** account。fans は Voice (taste) にしか付かない。

# 答える 5 問 (この派生だけ書く)
1. 新モデル / API、既存と何が違う？ (ベンチマーク + 価格 + 実装影響)
2. 新 AI ツール、どのユースケースに効く？ (使用レイヤー判定)
3. API の価格・レート・機能、どう選ぶ？ (選定判断)
4. 論文/研究、個人開発者が使える部分は？ (抽出)
5. 業界の動き、builder はどう読む？ (メタ解釈)

# tone
${tone}

# 必須構造

## 単発 (日本語 100 字以内)
Q: [ニュース 1 文]
A:
• [数字 1 つ]
• [実装判断 or 比較]
[出典: URL]

## スレッド (3 ツイ、各 90 字以内日本語 + URL は最後のみ)
1/3: Q + 背景 1 行
2/3: A 要点 + 数字
3/3: taste 1 行 + 出典 URL

# プラットフォーム規則
${platformRule}
文字数: ${charBudget}
言語: ${lang === "en" ? "英語" : "日本語"}

# 絶対ルール (違反は即却下)
- sourceContent に書いてある事実 (数字・固有名詞・社名・人名・日付) 以外を使わない
- **数字は source と exact match**。四捨五入・近似・概算・桁変更禁止
- 出典 URL を必ず本文に含める (voice の核)
- 推測や一般論で数字を作らない。source に数字がなければ数字を書かない
- **自社製品 (Lecsy / lecsy / 講義AI) を本文で言及しない** (bio 例外)
- 本名 (Nittono/新藤/ニットノ) 禁止
- 肩書き (Founder/CEO/Founded) 禁止
- 完了形 overclaim (launched/sold to/built a company/達成した) 禁止
- 自分語り (「今日」「今週」「俺が」「自分の進捗」で始まらない)
- @メンション / ハッシュタグ 禁止
- 絵文字は最大 1 個
- 煽り加担禁止 (業界初/最速/唯一無二/シームレス/革新的/AGI/revolutionary/AI-powered)
- 一般化禁止 (すべての/みんな/全員が/100%)
- 体感禁止 (たぶん/おそらく/体感)
- 1 投稿 1 メッセージ

# 出力フォーマット (JSON のみ、前後に文章を付けない)
{
  "mode": "single" | "thread",
  "text": "...",          // single の時の本文 (スレッドの時は最初のツイ)
  "thread": ["...", ...], // thread の時のみ各ツイ (text と同じ内容を先頭に)
  "rationale": "なぜこの切り口にしたか (1-2 行、後で tone 調整に使う)"
}`;
}

function buildUserPrompt(cand, sourceContent) {
  if (cand.sourceUrl) {
    // AI news item mode (Daily.md から)
    return `# 今日の AI ニュース item で投稿を書いてください

- id: ${cand.id}
- source: ${cand.source || "(unknown)"}
- タイトル: ${cand.title || ""}
- 公開日: ${cand.published || "(unknown)"}
- 出典 URL: ${cand.sourceUrl}

# サマリ (source 由来、これ以外の事実は使わない)

\`\`\`
${sourceContent.slice(0, 4000)}
\`\`\`

# 要件
- Q+A 構造、出典 URL を必ず本文に
- 数字は上記サマリにある物のみ、無ければ数字を書かない
- builder (個人開発者) が「自分のプロジェクトに持ち帰れる」形で
- Lecsy / 自社製品に言及しない

JSON で出力してください。`;
  }
  return `# 依頼

次の候補で投稿を書いてください。

- id: ${cand.id}
- チャネル: ${cand.ch}
- angle: ${cand.angle || ""}
- 参照元 sourceNote: ${cand.sourceNote || ""}

# sourceNote 抜粋 (これ以外の事実は使わない)

\`\`\`
${sourceContent.slice(0, 6000)}
\`\`\`

上記 tone・規則に従って JSON で出力してください。`;
}

export async function generatePost(cand) {
  const apiKey = process.env.OPENAI_API_KEY;
  if (!apiKey) throw new Error("OPENAI_API_KEY not set");

  const tone = loadTone();
  let sourceContent = "";

  if (cand.sourceUrl) {
    // AI news item: sourceContent は title + summary
    sourceContent = `Title: ${cand.title || ""}\nSource: ${cand.source || ""}\nPublished: ${cand.published || ""}\nURL: ${cand.sourceUrl}\n\nSummary:\n${cand.summary || ""}`;
  } else if (cand.sourceNote) {
    const srcPath = resolveSource(cand.sourceNote);
    sourceContent = srcPath && fs.existsSync(srcPath)
      ? fs.readFileSync(srcPath, "utf8")
      : "";
  }
  if (!sourceContent) {
    throw new Error(`no source content for ${cand.id}`);
  }

  const client = new OpenAI({ apiKey });
  const model = process.env.OPENAI_MODEL || "gpt-4o";
  const isLI = cand.ch === "LI";
  const resp = await client.chat.completions.create({
    model,
    max_tokens: isLI ? 2048 : 500,
    response_format: { type: "json_object" },
    messages: [
      { role: "system", content: buildSystemPrompt(tone, cand.ch, cand.lang || "ja") },
      { role: "user", content: buildUserPrompt(cand, sourceContent) },
    ],
  });

  const text = resp.choices?.[0]?.message?.content?.trim() || "";
  if (!text) throw new Error(`OpenAI returned empty content`);

  let parsed;
  try {
    parsed = JSON.parse(text);
  } catch {
    const jsonMatch = text.match(/\{[\s\S]*\}/);
    if (!jsonMatch) throw new Error(`OpenAI did not return JSON:\n${text}`);
    parsed = JSON.parse(jsonMatch[0]);
  }
  if (!parsed.mode || !parsed.text) throw new Error(`Invalid shape: ${text}`);

  return {
    id: cand.id,
    ch: cand.ch,
    lang: cand.lang || "ja",
    model,
    mode: parsed.mode,
    text: parsed.text,
    thread: parsed.thread || null,
    rationale: parsed.rationale || "",
    sourceNote: cand.sourceNote || null,
    sourceUrl: cand.sourceUrl || null,
    generatedAt: new Date().toISOString(),
  };
}

async function cli() {
  const idArg = process.argv.find((a) => a.startsWith("--id="));
  if (!idArg) {
    console.error("Usage: node scripts/sns-generate.mjs --id=SNS-001");
    process.exit(1);
  }
  const id = idArg.slice(5);
  const inv = fs.readFileSync(path.join(VAULT, "SNS/在庫_マップ.md"), "utf8");
  const line = inv.split("\n").find((l) => l.startsWith(`| ${id} `));
  if (!line) {
    console.error(`id not found in inventory: ${id}`);
    process.exit(1);
  }
  const cells = line.split("|").map((c) => c.trim()).filter(Boolean);
  const cand = { id: cells[0], ch: cells[1], sourceNote: cells[2], angle: cells[3] };
  const post = await generatePost(cand);
  console.log(JSON.stringify(post, null, 2));
}

if (fileURLToPath(import.meta.url) === process.argv[1]) {
  cli().catch((e) => {
    console.error(e);
    process.exit(1);
  });
}
