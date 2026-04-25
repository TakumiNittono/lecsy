#!/usr/bin/env node
// sns-delete-x.mjs — 投稿済みツイートを削除する一発スクリプト
// Usage: node scripts/sns-delete-x.mjs <id1> <id2> ...

import { fileURLToPath } from "node:url";
import dotenv from "dotenv";
dotenv.config({ path: fileURLToPath(new URL("../.env.local", import.meta.url)) });
dotenv.config();
import { TwitterApi } from "twitter-api-v2";

const ids = process.argv.slice(2);
if (!ids.length) {
  console.error("Usage: node scripts/sns-delete-x.mjs <id1> <id2> ...");
  process.exit(1);
}

const c = new TwitterApi({
  appKey: process.env.X_API_KEY,
  appSecret: process.env.X_API_KEY_SECRET,
  accessToken: process.env.X_ACCESS_TOKEN,
  accessSecret: process.env.X_ACCESS_TOKEN_SECRET,
}).readWrite;

const results = [];
for (const id of ids) {
  try {
    const r = await c.v2.deleteTweet(id);
    console.log(`✓ deleted ${id}: ${JSON.stringify(r.data)}`);
    results.push({ id, ok: true, data: r.data });
  } catch (e) {
    console.error(`✗ failed ${id}: ${e.message}`);
    results.push({ id, ok: false, error: String(e.message || e) });
  }
}

const ok = results.filter((r) => r.ok).length;
console.log(`\n=== ${ok}/${ids.length} deleted ===`);
process.exit(ok === ids.length ? 0 : 1);
