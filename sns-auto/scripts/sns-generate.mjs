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
- 話者: 日本の OPT 中の個人開発者 (米国B2B SaaS 立上げ中)
- 文体: タメ口寄り、時々ですます。一次情報・数字ファーストで語る
- 禁止: AI slop、教科書的一般論、絵文字乱用、ハッシュタグ
- 好み: 短文で断定 → 理由1つ。スレッドは 3-5 ツイ、最後は問いか CTA
- 温度: 熱いけど冷静。感情を数字で裏付ける
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
  const charBudget = ch === "LI" ? "2000-2500 字 (LinkedIn)" : "140-280 字 x 1-5 投稿 (X)";
  const platformRule = ch === "LI"
    ? "LinkedIn: 予告300字 → 中身 → CTA の Justin Welsh 3部構成"
    : "X: 単発なら 140 字前後。スレッドなら 3-5 ツイ、ツイ間は '---' で区切る";
  return `あなたは @takumi_global の代筆者です。以下の tone を厳守して日本語の SNS 投稿を書きます。

# tone
${tone}

# プラットフォーム規則
${platformRule}
文字数: ${charBudget}
言語: ${lang === "en" ? "英語" : "日本語"}

# 絶対ルール
- sourceNote 抜粋に書いてある事実 (数字・固有名詞・社名・人名・日付) 以外を使わない
- 推測や一般論で数字を作らない (例: "95% のユーザーが" などは sourceNote に書いて無ければ禁止)
- @メンション禁止 (他人に不意に飛ばすため)
- ハッシュタグ禁止
- 自慢・営業臭を 5% 以下に抑える (Work in Public 原則)
- 1 投稿 1 メッセージ。詰め込まない

# 出力フォーマット (JSON のみ、前後に文章を付けない)
{
  "mode": "single" | "thread",
  "text": "...",          // single の時の本文 (スレッドの時は最初のツイ)
  "thread": ["...", ...], // thread の時のみ各ツイ (text と同じ内容を先頭に)
  "rationale": "なぜこの切り口にしたか (1-2 行、後で tone 調整に使う)"
}`;
}

function buildUserPrompt(cand, sourceContent) {
  return `# 依頼

次の候補で投稿を書いてください。

- id: ${cand.id}
- チャネル: ${cand.ch}
- angle: ${cand.angle}
- 参照元 sourceNote: ${cand.sourceNote}

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
  const srcPath = resolveSource(cand.sourceNote);
  const sourceContent = srcPath && fs.existsSync(srcPath)
    ? fs.readFileSync(srcPath, "utf8")
    : "";
  if (!sourceContent) {
    throw new Error(`sourceNote not found for ${cand.id}: ${cand.sourceNote}`);
  }

  const client = new OpenAI({ apiKey });
  const model = process.env.OPENAI_MODEL || "gpt-4o";
  const resp = await client.chat.completions.create({
    model,
    max_tokens: 2048,
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
    sourceNote: cand.sourceNote,
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
