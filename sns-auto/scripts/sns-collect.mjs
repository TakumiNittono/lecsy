#!/usr/bin/env node
// sns-collect.mjs — 日次スナップショット生成
//
// 毎朝 04:00 JST (GHA cron) に走って
// _Vault/SNS/Daily/YYYY-MM-DD.md に「今日 sns-run で使える素材」を吐き出す。
//
// Phase 1 (今日): GitHub commits + Vault diff の 2 ソース
// Phase 2 (後で): Stripe / Supabase / Deepgram / App Store / Sentry
//
// 使い方:
//   node scripts/sns-collect.mjs                # 今日の Daily.md 生成
//   node scripts/sns-collect.mjs --date=YYYY-MM-DD
//   node scripts/sns-collect.mjs --dry          # 書き出さず stdout

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { execSync } from "node:child_process";
import dotenv from "dotenv";
dotenv.config({ path: fileURLToPath(new URL("../.env.local", import.meta.url)) });
dotenv.config();

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, "..");
const VAULT = path.resolve(ROOT, "../_Vault");
const VAULT_ROOT = path.resolve(VAULT, "..");
const DAILY_DIR = path.join(VAULT, "SNS/Daily");

function parseArgs() {
  const args = { date: null, dry: false };
  for (const a of process.argv.slice(2)) {
    if (a.startsWith("--date=")) args.date = a.slice(7);
    else if (a === "--dry") args.dry = true;
  }
  if (!args.date) args.date = new Date().toISOString().slice(0, 10);
  return args;
}

function sh(cmd, cwd = VAULT_ROOT) {
  try {
    return execSync(cmd, { cwd, encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] });
  } catch (e) {
    return `(error running: ${cmd})\n${e.message?.slice(0, 200) || ""}`;
  }
}

function collectGithubCommits(date) {
  // 自分が昨日 (date の前日) push したコミット
  const since = new Date(date);
  since.setDate(since.getDate() - 1);
  const sinceIso = since.toISOString().slice(0, 10);
  const until = date;
  const log = sh(`git log --author="${process.env.GIT_AUTHOR_NAME || "TakumiNittono"}" --since="${sinceIso}" --until="${until}" --pretty=format:'- %h %s (%cr)' --no-merges`);
  const lines = log.trim().split("\n").filter(Boolean).slice(0, 20);
  return lines.length ? lines.join("\n") : "(no commits yesterday)";
}

function collectVaultDiff(date) {
  // 昨日 Vault 内で変更された MD ファイル (タイトルのみ)
  const since = new Date(date);
  since.setDate(since.getDate() - 1);
  const sinceIso = since.toISOString().slice(0, 10);
  const log = sh(`git log --since="${sinceIso}" --name-only --pretty=format: -- '_Vault/**/*.md' | sort -u | grep -v '^$' | head -20`);
  const lines = log.trim().split("\n").filter(Boolean);
  return lines.length ? lines.map((l) => `- ${l}`).join("\n") : "(no vault changes)";
}

function collectDeepgramLocalHint() {
  // Deepgram 残高/使用量 は supabase/functions/deepgram-balance-check 経由で取るのが理想
  // Phase 1 は手動セットの env or "未取得" 表示
  const last = process.env.DEEPGRAM_LAST_BALANCE_USD;
  return last ? `Deepgram 残高 (最終取得): $${last}` : "Deepgram 残高: (Phase 2 で自動化)";
}

function buildSnapshot(date) {
  const commits = collectGithubCommits(date);
  const vaultDiff = collectVaultDiff(date);
  const deepgram = collectDeepgramLocalHint();
  return `# Daily Snapshot — ${date}

> 自動生成: ${new Date().toISOString()}
> 情報源: GitHub commits + Vault diff (+ Deepgram hint)
> このファイルは sns-run.mjs に sourceNote 候補として参照可能。

## T0 Lecsy 数字

- ${deepgram}
- Stripe MRR: (Phase 2 で自動化)
- Supabase DAU: (Phase 2 で自動化)
- App Store DL: (Phase 2 で自動化)
- Sentry: (Phase 2 で自動化)

## T1 開発活動

### 昨日の commits (自分のみ)

${commits}

### 昨日更新した Vault ファイル

${vaultDiff}

## T2 B2B 営業

(Phase 2 — Gmail filter 実装後)

## T3 市場

(Phase 3 — RSS モニタリング実装後)

## T4 OPT / 法務

(Phase 3 — USCIS RSS 実装後)

---

## 💡 今日の投稿候補 (人間 or gpt-4o がここから選ぶ)

- 朝 08:00 候補 (P1 数字): 上の commits や Vault diff から 1 本選ぶ
- 昼 12:30 候補 (P3 技術): 昨日 touch した技術ファイルから 1 本
- 夜 21:00 候補 (P2 OPT): 上の Vault diff で OPT 関連更新があれば

手動で使うなら: \`node scripts/sns-run.mjs --pillar=P1 --count=1 --live\`
`;
}

function main() {
  const args = parseArgs();
  const snapshot = buildSnapshot(args.date);

  if (args.dry) {
    console.log(snapshot);
    return;
  }

  fs.mkdirSync(DAILY_DIR, { recursive: true });
  const outPath = path.join(DAILY_DIR, `${args.date}.md`);
  fs.writeFileSync(outPath, snapshot);
  console.log(`✓ snapshot written: ${outPath}`);
}

main();
