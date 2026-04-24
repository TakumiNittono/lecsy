#!/usr/bin/env node
// sns-collect.mjs v2 — AI 最新情報 RSS 集約
//
// 毎朝 04:00 JST に走って top 10 AI items を _Vault/SNS/Daily/YYYY-MM-DD.md に集約。
// 情報源は _Vault/SNS/自動化_情報源.md に記載の RSS/Atom feed。
//
// 使い方:
//   node scripts/sns-collect.mjs                # 今日の snapshot
//   node scripts/sns-collect.mjs --date=YYYY-MM-DD
//   node scripts/sns-collect.mjs --dry          # 書き出さず stdout

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import dotenv from "dotenv";
dotenv.config({ path: fileURLToPath(new URL("../.env.local", import.meta.url)) });
dotenv.config();
import Parser from "rss-parser";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, "..");
const VAULT = path.resolve(ROOT, "../_Vault");
const DAILY_DIR = path.join(VAULT, "SNS/Daily");

const AI_KEYWORDS = [
  "AI", "GPT", "Claude", "Gemini", "LLM", "OpenAI", "Anthropic",
  "agent", "fine-tun", "benchmark", "RAG", "embedding", "token",
  "context window", "Llama", "Mistral", "xAI", "Grok",
  "reasoning model", "vision model", "multimodal",
  "AI SDK", "Cursor", "Copilot", "inference", "transformer",
];

const EXCLUDE_PATTERNS = [
  /machine learning course/i,
  /online course/i,
  /\bAI art\b/i,
  /\bAI generated image/i,
  /sponsored/i,
  // consumer-oriented Google/Gemini content (builder 向けじゃない)
  /tips for (organizing|cleaning|your space|travel|summer)/i,
  /\bspring cleaning\b/i,
  /\btravel smarter\b/i,
  /\bpersonal(ize|ized)\b.*\b(image|photo|video)\b/i,
  /\bsummer travel\b/i,
  /\bgift guide\b/i,
  /\bshopping\b/i,
  /\bads (advisor|campaign|safer)/i,
  /\bdata center\b/i, // インフラ投資のニュースは builder に直接関係少
];

const FEEDS = [
  // T0: 一次ソース (high priority) — builder 向け news が多い
  { name: "HN front page", url: "https://news.ycombinator.com/rss", weight: 1.5, filter: "ai-keyword" },
  { name: "Vercel AI SDK", url: "https://github.com/vercel/ai/releases.atom", weight: 1.4, filter: "none" },
  { name: "Google AI blog", url: "https://blog.google/technology/ai/rss/", weight: 0.9, filter: "none" },
  // T1: コミュニティ
  { name: "r/LocalLLaMA", url: "https://www.reddit.com/r/LocalLLaMA/.rss", weight: 1.0, filter: "none" },
  { name: "r/MachineLearning", url: "https://www.reddit.com/r/MachineLearning/.rss", weight: 0.8, filter: "ai-keyword" },
  { name: "arxiv cs.AI", url: "http://export.arxiv.org/rss/cs.AI", weight: 0.6, filter: "none" },
  { name: "arxiv cs.CL", url: "http://export.arxiv.org/rss/cs.CL", weight: 0.6, filter: "none" },
  // T2: ツール
  { name: "LangChain blog", url: "https://blog.langchain.dev/rss/", weight: 1.0, filter: "none" },
];

function parseArgs() {
  const args = { date: null, dry: false };
  for (const a of process.argv.slice(2)) {
    if (a.startsWith("--date=")) args.date = a.slice(7);
    else if (a === "--dry") args.dry = true;
  }
  if (!args.date) args.date = new Date().toISOString().slice(0, 10);
  return args;
}

function matchesAIKeyword(text) {
  if (!text) return false;
  // word-boundary match (e.g. "AI" matches but not "airport")
  return AI_KEYWORDS.some((k) => {
    const escaped = k.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
    const re = new RegExp(`\\b${escaped}\\b`, "i");
    return re.test(text);
  });
}

function excluded(text) {
  if (!text) return false;
  return EXCLUDE_PATTERNS.some((p) => p.test(text));
}

function cleanText(s, maxLen = 300) {
  if (!s) return "";
  let t = s
    .replace(/<[^>]+>/g, " ")
    .replace(/&[a-z]+;/gi, " ")
    .replace(/\s+/g, " ")
    .trim();
  if (t.length > maxLen) t = t.slice(0, maxLen).trim() + "…";
  return t;
}

async function fetchFeed(feed) {
  const parser = new Parser({
    timeout: 15000,
    headers: {
      "User-Agent": "takumi_global-news-collector/1.0 (+https://github.com/TakumiNittono/lecsy)",
    },
  });
  try {
    const parsed = await parser.parseURL(feed.url);
    const items = (parsed.items || []).slice(0, 20).map((it) => ({
      source: feed.name,
      weight: feed.weight,
      title: cleanText(it.title, 200),
      url: it.link || it.guid || "",
      published: it.isoDate || it.pubDate || "",
      summary: cleanText(it.contentSnippet || it.content || it.summary || "", 400),
    }));
    return items.filter((it) => {
      if (!it.title || !it.url) return false;
      if (excluded(it.title) || excluded(it.summary)) return false;
      if (feed.filter === "ai-keyword") {
        return matchesAIKeyword(it.title) || matchesAIKeyword(it.summary);
      }
      return true;
    });
  } catch (e) {
    console.error(`[${feed.name}] fetch failed: ${e.message}`);
    return [];
  }
}

function scoreItem(item) {
  let score = item.weight * 10;
  if (item.published) {
    const ageH = (Date.now() - new Date(item.published).getTime()) / 3600000;
    if (ageH >= 0 && ageH < 24) score += 5 - ageH / 5;
  }
  return score;
}

function dedupe(items) {
  const seen = new Set();
  const out = [];
  for (const it of items) {
    const key = it.url || it.title;
    if (seen.has(key)) continue;
    seen.add(key);
    out.push(it);
  }
  return out;
}

function buildSnapshot(date, items) {
  const top = items.slice(0, 10);
  const sections = top.map((it, i) => {
    return `### ${i + 1}. [${it.source}] ${it.title}
- URL: ${it.url}
- Published: ${it.published || "(unknown)"}
- Summary: ${it.summary || "(no summary)"}
`;
  }).join("\n");

  return `# Daily AI News — ${date}

> 自動生成: sns-collect.mjs @ ${new Date().toISOString()}
> Feeds attempted: ${FEEDS.length}, items kept: ${top.length}

## Top ${top.length} AI items

${sections}

---

## 投稿生成 (sns-run.mjs)

sns-run は上の items から **未投稿の最上位** を選んで 1 投稿を生成する。
Item の title + URL + summary が sourceContent として generator に渡る。

朝 08:00 (P1) / 昼 12:30 (P3) / 夜 21:00 (P5) でそれぞれ次の未投稿 item を消費。

## 手動操作

\`\`\`bash
# 強制再集約
cd sns-auto && npm run sns:collect

# 特定 date
node scripts/sns-collect.mjs --date=2026-04-25

# dry-run
node scripts/sns-collect.mjs --dry
\`\`\`
`;
}

async function main() {
  const args = parseArgs();
  console.log(`collecting ${FEEDS.length} feeds...`);

  const allItems = [];
  const results = await Promise.allSettled(FEEDS.map(fetchFeed));
  for (let i = 0; i < results.length; i++) {
    const r = results[i];
    const feedName = FEEDS[i].name;
    if (r.status === "fulfilled") {
      console.log(`  ✓ ${feedName}: ${r.value.length} items`);
      allItems.push(...r.value);
    } else {
      console.error(`  ✗ ${feedName}: ${r.reason?.message || r.reason}`);
    }
  }

  const scored = allItems.map((it) => ({ ...it, score: scoreItem(it) }));
  scored.sort((a, b) => b.score - a.score);
  const deduped = dedupe(scored);

  const snapshot = buildSnapshot(args.date, deduped);

  if (args.dry) {
    console.log(snapshot);
    return;
  }

  fs.mkdirSync(DAILY_DIR, { recursive: true });
  const outPath = path.join(DAILY_DIR, `${args.date}.md`);
  fs.writeFileSync(outPath, snapshot);
  console.log(`✓ written: ${outPath}`);
  console.log(`  top item: ${deduped[0]?.title?.slice(0, 80) || "(none)"}`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
