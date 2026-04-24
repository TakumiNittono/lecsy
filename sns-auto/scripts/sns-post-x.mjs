#!/usr/bin/env node
// sns-post-x.mjs — X API v2 で投稿する最小クライアント
//
// Usage (lib):
//   import { postToX } from "./sns-post-x.mjs";
//   const result = await postToX(post, { dryRun: true });
//
// 対応:
//   - 単発テキスト投稿 (v2 POST /2/tweets)
//   - スレッド (reply_to_tweet_id で連結)
//   - 画像/動画は後で追加 (v1.1 media/upload が必要)
//
// 認証: OAuth 1.0a user context (Consumer + Access 4 キー)
//
// 契約:
//   - dryRun: true なら API を叩かず { dryRun: true, would: {...} } を返す
//   - 投稿成功で { tweetId, url, postedAt } を返す
//   - 失敗は throw

import { fileURLToPath } from "node:url";
import dotenv from "dotenv";
dotenv.config({ path: fileURLToPath(new URL("../.env.local", import.meta.url)) });
dotenv.config();
import { TwitterApi } from "twitter-api-v2";

function requireEnv(key) {
  const v = process.env[key];
  if (!v) throw new Error(`${key} not set in env`);
  return v;
}

function client() {
  return new TwitterApi({
    appKey: requireEnv("X_API_KEY"),
    appSecret: requireEnv("X_API_KEY_SECRET"),
    accessToken: requireEnv("X_ACCESS_TOKEN"),
    accessSecret: requireEnv("X_ACCESS_TOKEN_SECRET"),
  }).readWrite;
}

export async function postToX(post, { dryRun = true } = {}) {
  if (post.ch !== "X") {
    throw new Error(`sns-post-x only handles ch=X, got ${post.ch}`);
  }

  if (dryRun) {
    return {
      dryRun: true,
      would: {
        mode: post.mode,
        text: post.text,
        thread: post.thread,
      },
    };
  }

  const c = client();

  if (post.mode === "single") {
    const r = await c.v2.tweet(post.text);
    return {
      dryRun: false,
      tweetId: r.data.id,
      url: `https://x.com/${process.env.X_HANDLE || "i"}/status/${r.data.id}`,
      postedAt: new Date().toISOString(),
    };
  }

  if (post.mode === "thread") {
    const thread = post.thread || [post.text];
    const ids = [];
    let parent = null;
    for (const t of thread) {
      const payload = parent ? { reply: { in_reply_to_tweet_id: parent } } : {};
      const r = await c.v2.tweet(t, payload);
      ids.push(r.data.id);
      parent = r.data.id;
    }
    return {
      dryRun: false,
      tweetId: ids[0],
      threadIds: ids,
      url: `https://x.com/${process.env.X_HANDLE || "i"}/status/${ids[0]}`,
      postedAt: new Date().toISOString(),
    };
  }

  throw new Error(`unknown mode: ${post.mode}`);
}

async function cli() {
  const fs = await import("node:fs");
  const pathArg = process.argv[2];
  const live = process.argv.includes("--live");
  if (!pathArg || !fs.existsSync(pathArg)) {
    console.error("Usage: node scripts/sns-post-x.mjs <post.json> [--live]");
    process.exit(1);
  }
  const post = JSON.parse(fs.readFileSync(pathArg, "utf8"));
  const result = await postToX(post, { dryRun: !live });
  console.log(JSON.stringify(result, null, 2));
}

if (fileURLToPath(import.meta.url) === process.argv[1]) {
  cli().catch((e) => {
    console.error(e);
    process.exit(1);
  });
}
