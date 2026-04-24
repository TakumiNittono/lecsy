#!/usr/bin/env node
// sns-guardrail.mjs — 生成済み投稿の事前フィルタ
//
// Usage (lib):
//   import { checkPost } from "./sns-guardrail.mjs";
//   const result = checkPost(post, sourceContent);
//   if (!result.pass) { skip & notify; }
//
// 返り値: { pass: boolean, reasons: string[] }
//
// 目的: Claude のハルシネーション・tone 違反・事故投稿を投稿前に遮断。
//       ここで弾かれた投稿は人間レビューキューに入るだけ、即投稿はしない。

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const VAULT = path.resolve(__dirname, "../../lecsy/_Vault");

const NG_KEYWORDS = [
  // 競合攻撃 (Otter を叩くのは長期的に負け)
  "Otter は", "Notta は", "CLOVA は",
  // 政治
  "Trump", "Biden", "自民党", "立憲",
  // 炎上系 fire take
  "クソ", "ゴミ", "バカ", "アホ", "死ね", "殺", "終わってる",
  // 誇大表現 (Lecsy 仕様に反する)
  "業界No.1", "業界最安", "最速の", "唯一無二",
  // 未確認誇張
  "すべての学生が", "全員が", "100%",
];

const NG_CLAIMS = [
  // 対応言語の真実: 9言語のみ (memory 参照)
  /(100\s*\+?\s*(言語|languages))/i,
  /12\s*(言語|languages)/i,
  // 翻訳は Pro 限定
  /(free|無料)[\s\S]{0,20}翻訳/,
];

const FACT_PATTERNS = [
  // 数字系クレーム (単位付き) — sourceContent に含まれていなければ flag
  /\d+\s*%/g,
  /\$\s?\d+/g,
  /\d+\s*(倍|時間|分|秒|日|ヶ月|月|年|件|人|校|社|DL|MRR|ARR)/g,
];

const MAX_X_SINGLE = 280;
const MAX_X_THREAD_TWEET = 280;
const MAX_THREAD_LEN = 8;
const MAX_LI_LEN = 3000;
const MAX_HASHTAGS = 0; // 運用ルールでハッシュタグ禁止
const MAX_MENTIONS = 0; // @メンション禁止
const MAX_URLS = 2;

function countEach(text, pattern) {
  const m = text.match(pattern);
  return m ? m.length : 0;
}

function checkOneText(text, { platform, sourceContent }) {
  const reasons = [];
  if (!text || text.trim().length === 0) {
    reasons.push("empty text");
    return reasons;
  }

  const len = [...text].length;
  const maxLen = platform === "LI" ? MAX_LI_LEN : MAX_X_SINGLE;
  if (len > maxLen) reasons.push(`length ${len} > ${maxLen}`);
  if (len < 20) reasons.push(`length ${len} < 20 (too short)`);

  for (const kw of NG_KEYWORDS) {
    if (text.includes(kw)) reasons.push(`NG keyword: "${kw}"`);
  }
  for (const re of NG_CLAIMS) {
    if (re.test(text)) reasons.push(`NG claim matched: ${re}`);
  }

  const mentions = countEach(text, /(^|\s)@[\w_]+/g);
  if (mentions > MAX_MENTIONS) reasons.push(`@mentions: ${mentions} > ${MAX_MENTIONS}`);

  const hashtags = countEach(text, /(^|\s)#[^\s#]+/g);
  if (hashtags > MAX_HASHTAGS) reasons.push(`hashtags: ${hashtags} > ${MAX_HASHTAGS}`);

  const urls = countEach(text, /https?:\/\/[^\s]+/g);
  if (urls > MAX_URLS) reasons.push(`urls: ${urls} > ${MAX_URLS}`);

  // ファクトチェック: 数字クレームが sourceContent に存在するか
  if (sourceContent) {
    const claims = [];
    for (const p of FACT_PATTERNS) {
      const matches = text.match(p) || [];
      claims.push(...matches);
    }
    for (const claim of claims) {
      const normalized = claim.replace(/\s/g, "");
      const srcNormalized = sourceContent.replace(/\s/g, "");
      if (!srcNormalized.includes(normalized)) {
        reasons.push(`unverified claim: "${claim}" not in sourceNote`);
      }
    }
  }

  return reasons;
}

export function checkPost(post, sourceContent = "") {
  const reasons = [];

  if (post.mode === "single") {
    reasons.push(
      ...checkOneText(post.text, { platform: post.ch, sourceContent })
    );
  } else if (post.mode === "thread") {
    const thread = post.thread || [];
    if (thread.length < 2) reasons.push(`thread with ${thread.length} tweets`);
    if (thread.length > MAX_THREAD_LEN)
      reasons.push(`thread too long: ${thread.length} > ${MAX_THREAD_LEN}`);
    thread.forEach((t, i) => {
      const r = checkOneText(t, { platform: post.ch, sourceContent });
      r.forEach((reason) => reasons.push(`tweet ${i + 1}: ${reason}`));
    });
  } else {
    reasons.push(`unknown mode: ${post.mode}`);
  }

  return { pass: reasons.length === 0, reasons };
}

async function cli() {
  const path = process.argv[2];
  if (!path || !fs.existsSync(path)) {
    console.error("Usage: node scripts/sns-guardrail.mjs <generated-post.json>");
    process.exit(1);
  }
  const post = JSON.parse(fs.readFileSync(path, "utf8"));
  const result = checkPost(post);
  console.log(JSON.stringify(result, null, 2));
  process.exit(result.pass ? 0 : 1);
}

import { fileURLToPath as _fu } from "node:url";
if (_fu(import.meta.url) === process.argv[1]) {
  cli().catch((e) => {
    console.error(e);
    process.exit(1);
  });
}
