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
  "agent", "agents", "agentic", "fine-tun", "benchmark", "RAG", "embedding", "token", "tokens",
  "context window", "Llama", "Mistral", "xAI", "Grok", "DeepSeek", "Qwen",
  "reasoning model", "vision model", "multimodal", "diffusion",
  "AI SDK", "Cursor", "Copilot", "inference", "transformer",
  "Hugging Face", "HuggingFace", "Devin", "Cognition", "Replicate",
  "MCP", "tool use", "tool-use", "function calling",
  "prompt", "prompt engineering", "chain of thought", "CoT",
  "GPU", "H100", "B200", "TPU",
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
  // T0: 一次ソース — AI labs / model providers (highest weight)
  { name: "HN front page", url: "https://news.ycombinator.com/rss", weight: 1.6, filter: "ai-keyword" },
  { name: "HN best", url: "https://hnrss.org/best", weight: 1.4, filter: "ai-keyword" },
  { name: "HN AI keyword", url: "https://hnrss.org/newest.rss?q=AI+OR+LLM+OR+GPT+OR+Claude+OR+Gemini+OR+Anthropic+OR+OpenAI", weight: 1.3, filter: "none" },
  { name: "Google AI blog", url: "https://blog.google/technology/ai/rss/", weight: 1.2, filter: "none" },
  { name: "Google DeepMind blog", url: "https://deepmind.google/blog/rss.xml", weight: 1.3, filter: "none" },
  { name: "NVIDIA blog", url: "https://blogs.nvidia.com/feed/", weight: 0.9, filter: "ai-keyword" },
  { name: "AWS ML blog", url: "https://aws.amazon.com/blogs/machine-learning/feed/", weight: 0.9, filter: "none" },
  { name: "HuggingFace blog", url: "https://huggingface.co/blog/feed.xml", weight: 1.3, filter: "none" },

  // T1: Builder ecosystem / SDKs / dev tools
  { name: "Vercel AI SDK", url: "https://github.com/vercel/ai/releases.atom", weight: 1.0, filter: "none" },
  { name: "Anthropic releases (GH)", url: "https://github.com/anthropics/anthropic-sdk-typescript/releases.atom", weight: 1.1, filter: "none" },
  { name: "OpenAI SDK releases (GH)", url: "https://github.com/openai/openai-node/releases.atom", weight: 1.1, filter: "none" },
  { name: "llama.cpp releases (GH)", url: "https://github.com/ggerganov/llama.cpp/releases.atom", weight: 0.9, filter: "none" },
  { name: "vLLM releases (GH)", url: "https://github.com/vllm-project/vllm/releases.atom", weight: 0.9, filter: "none" },

  // T2: Research / Papers (atom is more reliable than rss for arxiv)
  { name: "arxiv cs.AI (atom)", url: "https://rss.arxiv.org/atom/cs.AI", weight: 0.7, filter: "none" },
  { name: "arxiv cs.CL (atom)", url: "https://rss.arxiv.org/atom/cs.CL", weight: 0.7, filter: "none" },
  { name: "arxiv cs.LG (atom)", url: "https://rss.arxiv.org/atom/cs.LG", weight: 0.6, filter: "none" },

  // T3: Community (Reddit needs Mozilla UA — handled in fetchFeed)
  { name: "r/LocalLLaMA", url: "https://www.reddit.com/r/LocalLLaMA/.rss", weight: 1.0, filter: "none" },
  { name: "r/MachineLearning", url: "https://www.reddit.com/r/MachineLearning/.rss", weight: 0.9, filter: "ai-keyword" },
  { name: "r/singularity", url: "https://www.reddit.com/r/singularity/.rss", weight: 0.7, filter: "ai-keyword" },
  { name: "r/OpenAI", url: "https://www.reddit.com/r/OpenAI/.rss", weight: 0.8, filter: "none" },
  { name: "r/ClaudeAI", url: "https://www.reddit.com/r/ClaudeAI/.rss", weight: 0.8, filter: "none" },

  // T4: Builder voices (newsletters / personal blogs)
  { name: "Simon Willison", url: "https://simonwillison.net/atom/everything/", weight: 1.3, filter: "none" },
  { name: "Latent Space", url: "https://www.latent.space/feed", weight: 1.2, filter: "none" },
  { name: "Sebastian Raschka", url: "https://magazine.sebastianraschka.com/feed", weight: 1.1, filter: "none" },
  { name: "Ethan Mollick", url: "https://www.oneusefulthing.org/feed", weight: 1.0, filter: "none" },
  { name: "Import AI", url: "https://importai.substack.com/feed", weight: 1.0, filter: "none" },
  { name: "Andrej Karpathy (HN)", url: "https://hnrss.org/newest?q=karpathy", weight: 1.1, filter: "none" },

  // T5: Tech press AI verticals
  { name: "TechCrunch AI", url: "https://techcrunch.com/category/artificial-intelligence/feed/", weight: 0.7, filter: "none" },
  { name: "The Decoder", url: "https://the-decoder.com/feed/", weight: 0.8, filter: "none" },
  { name: "VentureBeat AI", url: "https://venturebeat.com/category/ai/feed/", weight: 0.7, filter: "none" },
  { name: "Ars Technica AI", url: "https://arstechnica.com/ai/feed/", weight: 0.8, filter: "none" },
  { name: "MIT Tech Review", url: "https://www.technologyreview.com/feed/", weight: 0.7, filter: "ai-keyword" },
];

function todayJst() {
  // JST date regardless of host TZ — cron design assumes JST day boundaries.
  const ms = Date.now() + 9 * 3600 * 1000;
  return new Date(ms).toISOString().slice(0, 10);
}

function parseArgs() {
  const args = { date: null, dry: false };
  for (const a of process.argv.slice(2)) {
    if (a.startsWith("--date=")) args.date = a.slice(7);
    else if (a === "--dry") args.dry = true;
  }
  if (!args.date) args.date = todayJst();
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
  const isReddit = /reddit\.com/i.test(feed.url);
  const ua = isReddit
    ? "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
    : "takumi_global-news-collector/1.0 (+https://github.com/TakumiNittono/lecsy)";
  const parser = new Parser({
    timeout: 15000,
    headers: {
      "User-Agent": ua,
      "Accept": "application/rss+xml, application/atom+xml, application/xml;q=0.9, */*;q=0.8",
    },
  });
  try {
    const parsed = await parser.parseURL(feed.url);
    const items = (parsed.items || []).slice(0, 40).map((it) => ({
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
  const top = items.slice(0, 30);
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
