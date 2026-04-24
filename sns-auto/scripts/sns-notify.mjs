#!/usr/bin/env node
// sns-notify.mjs — Slack 通知レイヤー
//
// 呼出側は `await notify(...)` で使える。失敗しても絶対に throw しない。
// 既存の supabase/functions/_shared/alert.ts と同じ設計思想:
//   - 環境未設定でも本体処理を止めない
//   - 自身の失敗で呼出元を落とさない
//   - レベル別の emoji
//
// Env:
//   SLACK_WEBHOOK_URL       — https://hooks.slack.com/services/... (未設定ならノーオペ)
//   SLACK_NOTIFY=false      — 全通知を無効化 (デバッグ時)
//   SLACK_NOTIFY_SUCCESS=true — 成功通知も送る (デフォルトは送らない)

import { fileURLToPath } from "node:url";
import dotenv from "dotenv";
dotenv.config({ path: fileURLToPath(new URL("../.env.local", import.meta.url)) });
dotenv.config();

const EMOJI = {
  info: ":information_source:",
  success: ":white_check_mark:",
  warning: ":warning:",
  error: ":x:",
  critical: ":rotating_light:",
};

function classify(err) {
  const msg = String(err?.message || err || "");
  const code = err?.code || err?.status || err?.statusCode;
  const data = err?.data || err?.response?.data || {};

  if (msg.includes("API key") || code === 401 || data?.errors?.[0]?.code === 32) {
    return { kind: "auth", level: "critical" };
  }
  if (code === 429 || msg.toLowerCase().includes("rate limit")) {
    return { kind: "rate-limit", level: "warning" };
  }
  if (code === 402 || msg.includes("insufficient") || msg.toLowerCase().includes("quota") || msg.toLowerCase().includes("credit")) {
    return { kind: "credit", level: "critical" };
  }
  if (code === 403 && msg.toLowerCase().includes("duplicate")) {
    return { kind: "duplicate", level: "warning" };
  }
  if (code === 403) {
    return { kind: "forbidden", level: "error" };
  }
  return { kind: "error", level: "error" };
}

function summary(kind) {
  switch (kind) {
    case "auth": return "認証エラー — API キーが無効 / 失効 / 権限不足";
    case "rate-limit": return "レート制限に到達 — しばらく待って再試行";
    case "credit": return "クレジット/クォータ不足 — 課金追加が必要";
    case "duplicate": return "重複投稿検出 — 同じ文面を短時間で再投稿しようとした";
    case "forbidden": return "API から 403 — 権限設定を要確認";
    case "guardrail": return "ガードレールで投稿をブロック";
    case "success": return "投稿成功";
    case "digest": return "日次サマリー";
    case "disabled": return "SNS 自動化が kill switch で停止中";
    default: return "自動投稿パイプライン エラー";
  }
}

export async function notify({ kind = "error", level, title, text, fields = [], err = null }) {
  const url = process.env.SLACK_WEBHOOK_URL;
  if (!url || process.env.SLACK_NOTIFY === "false") return;
  if (kind === "success" && process.env.SLACK_NOTIFY_SUCCESS !== "true") return;

  const emoji = EMOJI[level] || EMOJI.error;
  const summaryText = title || summary(kind);

  const fieldBlocks = fields.map((f) => ({
    type: "mrkdwn",
    text: `*${f.label}*\n${f.value}`,
  }));

  const blocks = [
    {
      type: "header",
      text: { type: "plain_text", text: `${emoji} ${summaryText}` },
    },
  ];
  if (text) {
    blocks.push({ type: "section", text: { type: "mrkdwn", text } });
  }
  if (fieldBlocks.length) {
    for (let i = 0; i < fieldBlocks.length; i += 2) {
      blocks.push({ type: "section", fields: fieldBlocks.slice(i, i + 2) });
    }
  }
  if (err) {
    const errMsg = typeof err === "string" ? err : (err.stack || err.message || JSON.stringify(err));
    blocks.push({
      type: "section",
      text: { type: "mrkdwn", text: "```" + errMsg.slice(0, 1800) + "```" },
    });
  }
  blocks.push({
    type: "context",
    elements: [
      { type: "mrkdwn", text: `source: \`lecsy-video/scripts/sns-run.mjs\` | ${new Date().toISOString()}` },
    ],
  });

  try {
    const resp = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ blocks, text: summaryText }),
    });
    if (!resp.ok) {
      console.error(`[slack] ${resp.status} ${await resp.text().catch(() => "")}`);
    }
  } catch (e) {
    console.error(`[slack] notify failed: ${e.message}`);
  }
}

export function notifyFromError(err, { source, id = null } = {}) {
  const { kind, level } = classify(err);
  return notify({
    kind,
    level,
    title: `${summary(kind)}${id ? ` (${id})` : ""}`,
    text: source ? `source: \`${source}\`` : undefined,
    err,
  });
}

async function cli() {
  const mode = process.argv[2] || "test";
  if (mode === "test") {
    await notify({
      kind: "info",
      level: "info",
      title: "Slack 連携テスト",
      text: "これが届けば通知レイヤーは動いてます。",
      fields: [
        { label: "env", value: process.env.NODE_ENV || "local" },
        { label: "webhook", value: process.env.SLACK_WEBHOOK_URL ? "set" : "unset" },
      ],
    });
    console.log("✓ test sent (if SLACK_WEBHOOK_URL is set)");
  }
}

if (fileURLToPath(import.meta.url) === process.argv[1]) {
  cli().catch((e) => {
    console.error(e);
    process.exit(1);
  });
}
