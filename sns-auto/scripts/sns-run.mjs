#!/usr/bin/env node
// sns-run.mjs — SNS 自動投稿のメインランナー
//
// フロー: inventory → generate (Claude) → guardrail → post (X) → archive
//
// Usage:
//   node scripts/sns-run.mjs                 # dry-run, 翌日分3件, 出さずにドラフトのみ
//   node scripts/sns-run.mjs --live          # 実投稿モード
//   node scripts/sns-run.mjs --count=5       # 件数
//   node scripts/sns-run.mjs --lang=ja       # 言語フィルタ (未指定は全部)
//   node scripts/sns-run.mjs --id=SNS-001    # 特定IDだけ (テスト用)
//
// 異常時: guardrail で弾かれた場合は sourceNote ローテーション + 次候補を試行。
//         X API 失敗は即 throw してプロセス終了 (cron の失敗通知に任せる)。
//
// Kill switch:
//   SNS_AUTO_DISABLED=true を env に入れれば即終了 (何も投稿しない)

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { createHash } from "node:crypto";
import dotenv from "dotenv";
dotenv.config({ path: fileURLToPath(new URL("../.env.local", import.meta.url)) });
dotenv.config();
import { generatePost } from "./sns-generate.mjs";
import { checkPost } from "./sns-guardrail.mjs";
import { postToX } from "./sns-post-x.mjs";
import { notify, notifyFromError } from "./sns-notify.mjs";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, "..");
const VAULT = path.resolve(ROOT, "../_Vault");
const INVENTORY = path.join(VAULT, "SNS/在庫_マップ.md");
const STATE = path.join(ROOT, "content/sns-posts.json");
const LOG_DIR = path.join(VAULT, "SNS/ログ");
const ARCHIVE_DIR = path.join(VAULT, "SNS/公開済");

function parseArgs() {
  const args = { live: false, count: 3, lang: null, id: null, pillar: null, ch: null };
  for (const a of process.argv.slice(2)) {
    if (a === "--live") args.live = true;
    else if (a.startsWith("--count=")) args.count = parseInt(a.slice(8), 10);
    else if (a.startsWith("--lang=")) args.lang = a.slice(7);
    else if (a.startsWith("--id=")) args.id = a.slice(5);
    else if (a.startsWith("--pillar=")) args.pillar = a.slice(9);
    else if (a.startsWith("--ch=")) args.ch = a.slice(5);
  }
  return args;
}

function parseInventory() {
  const md = fs.readFileSync(INVENTORY, "utf8");
  const rows = [];
  for (const line of md.split("\n")) {
    if (!line.startsWith("| SNS-")) continue;
    const cells = line.split("|").map((c) => c.trim()).filter(Boolean);
    if (cells.length < 5) continue;
    const [id, ch, pillar, sourceNote, angle, lastPosted] = cells;
    rows.push({
      id, ch, pillar, sourceNote, angle,
      lastPosted: lastPosted || "", lang: "ja",
    });
  }
  return rows;
}

function parseDaily(date) {
  const dailyPath = path.join(VAULT, "SNS/Daily", `${date}.md`);
  if (!fs.existsSync(dailyPath)) return [];
  const md = fs.readFileSync(dailyPath, "utf8");
  const items = [];
  const lines = md.split("\n");
  let current = null;
  for (const line of lines) {
    const header = line.match(/^### (\d+)\.\s*\[([^\]]+)\]\s*(.+)$/);
    if (header) {
      if (current) items.push(current);
      current = {
        index: parseInt(header[1], 10),
        source: header[2].trim(),
        title: header[3].trim(),
        sourceUrl: "",
        published: "",
        summary: "",
      };
      continue;
    }
    if (!current) continue;
    const urlM = line.match(/^-\s*URL:\s*(.+)$/);
    if (urlM) current.sourceUrl = urlM[1].trim();
    const pubM = line.match(/^-\s*Published:\s*(.+)$/);
    if (pubM) current.published = pubM[1].trim();
    const sumM = line.match(/^-\s*Summary:\s*(.+)$/);
    if (sumM) current.summary = sumM[1].trim();
  }
  if (current) items.push(current);
  return items
    .filter((it) => it.sourceUrl && it.title)
    .map((it) => ({
      id: "AI-" + createHash("sha1").update(it.sourceUrl).digest("hex").slice(0, 8),
      ch: "X",
      pillar: "AI",
      lang: "ja",
      lastPosted: "",
      ...it,
    }));
}

function loadState() {
  if (!fs.existsSync(STATE)) return { meta: {}, posts: [] };
  return JSON.parse(fs.readFileSync(STATE, "utf8"));
}

function saveState(state) {
  fs.writeFileSync(STATE, JSON.stringify(state, null, 2) + "\n");
}

function alreadyPosted(state, id, windowDays = 30) {
  const cutoff = Date.now() - windowDays * 86400000;
  return state.posts.some(
    (p) => p.id === id && p.status === "posted" && Date.parse(p.postedAt) > cutoff
  );
}

function recentlyBlocked(state, id, windowH = 6) {
  const cutoff = Date.now() - windowH * 3600000;
  return state.posts.some(
    (p) => p.id === id && p.status === "blocked" && Date.parse(p.blockedAt) > cutoff
  );
}

function pickCandidates(inv, state, { count, lang, id, pillar, ch }) {
  if (id) return inv.filter((r) => r.id === id);
  // ベース pool: 投稿済 30日 + 直近6時間に blocked のものを除外
  let pool = inv.filter(
    (r) => !alreadyPosted(state, r.id) && !recentlyBlocked(state, r.id)
  );
  if (ch) pool = pool.filter((r) => r.ch === ch); // LI 行を X cron から除外
  if (lang) pool = pool.filter((r) => r.lang === lang);

  const scoreOf = (r) => (r.lastPosted ? Date.parse(r.lastPosted) || 0 : -1);
  const sorted = (arr) => [...arr].sort((a, b) => scoreOf(a) - scoreOf(b));

  // Tier 1: pillar 完全一致 (cron が --pillar=P1/P2/P3 で指定する想定)
  const tier1 = pillar ? sorted(pool.filter((r) => r.pillar === pillar)) : sorted(pool);

  // Tier 2: pillar フィルタを外した全候補 (Inventory 枯渇 → AI Daily 含む)
  const tier2 = pillar
    ? sorted(pool.filter((r) => r.pillar !== pillar))
    : [];

  // 最低 8 件キープして retry 余力を確保 (1 件目が error/blocked でも次へ)
  const merged = [...tier1, ...tier2];
  const minPick = Math.max(count * 5, 8);
  return merged.slice(0, minPick);
}

function openLog() {
  fs.mkdirSync(LOG_DIR, { recursive: true });
  const date = new Date().toISOString().slice(0, 10);
  const logPath = path.join(LOG_DIR, `${date}.log`);
  const stream = fs.createWriteStream(logPath, { flags: "a" });
  const log = (msg) => {
    const line = `[${new Date().toISOString()}] ${msg}`;
    console.log(line);
    stream.write(line + "\n");
  };
  return { log, close: () => stream.end() };
}

function appendArchive(post, result) {
  fs.mkdirSync(ARCHIVE_DIR, { recursive: true });
  const date = new Date().toISOString().slice(0, 10);
  const archPath = path.join(ARCHIVE_DIR, `${date}.md`);
  const entry = `\n## ${post.id} (${post.ch}) — ${new Date().toISOString()}

**sourceNote:** ${post.sourceNote}
**mode:** ${post.mode}
**url:** ${result.url || "(dry-run)"}
**rationale:** ${post.rationale}

\`\`\`
${post.mode === "thread" ? (post.thread || []).join("\n---\n") : post.text}
\`\`\`

---
`;
  fs.appendFileSync(archPath, entry);
}

function markPosted(state, post, result) {
  state.posts.push({
    id: post.id,
    ch: post.ch,
    lang: post.lang,
    status: result.dryRun ? "dry-run" : "posted",
    tweetId: result.tweetId || null,
    url: result.url || null,
    postedAt: result.postedAt || new Date().toISOString(),
    generatedAt: post.generatedAt,
  });
}

async function main() {
  const args = parseArgs();
  const { log, close } = openLog();

  log(`=== sns-run start args=${JSON.stringify(args)} ===`);

  if (process.env.SNS_AUTO_DISABLED === "true") {
    log("SNS_AUTO_DISABLED=true → abort");
    await notify({
      kind: "disabled",
      level: "warning",
      title: "SNS 自動化が停止中",
      text: "kill switch (`SNS_AUTO_DISABLED=true`) で停止。再開するには env を false に。",
    });
    close();
    return;
  }

  const today = (() => {
    // JST date — matches sns-collect.mjs Daily file naming.
    const ms = Date.now() + 9 * 3600 * 1000;
    return new Date(ms).toISOString().slice(0, 10);
  })();
  const daily = parseDaily(today);
  const inv = parseInventory();
  // Daily と Inventory を merge: pillar=P1/P2/P3 cron は Inventory から、pillar=AI cron は Daily から拾える
  const allItems = [...daily, ...inv];
  log(`source: Daily.md (${daily.length} items) + Inventory (${inv.length} items) = ${allItems.length}`);
  const state = loadState();
  const cands = pickCandidates(allItems, state, args);

  if (!cands.length) {
    log("no candidates — Daily.md empty or inventory exhausted");
    await notify({
      kind: "warning",
      level: "warning",
      title: "SNS 候補なし",
      text: `今日 (${today}) の Daily.md が空、または全候補が投稿済。sns-collect.mjs を再実行するか、在庫マップを補充してください。`,
    });
    close();
    return;
  }

  let successCount = 0;
  let errorCount = 0;
  const blocked = [];

  log(`picked ${cands.length}: ${cands.map((c) => c.id).join(", ")}`);

  for (const cand of cands) {
    try {
      const sourceContent = (() => {
        try {
          if (cand.sourceUrl) {
            return `${cand.title || ""}\n\n${cand.summary || ""}\n\nURL: ${cand.sourceUrl}`;
          }
          const p = resolveForCheck(cand.sourceNote);
          return p ? fs.readFileSync(p, "utf8") : "";
        } catch {
          return "";
        }
      })();

      let post = null;
      let gr = null;
      let prevReasons = null;
      const MAX_ATTEMPTS = 3;
      for (let attempt = 1; attempt <= MAX_ATTEMPTS; attempt++) {
        log(`-- ${cand.id}: generate (attempt ${attempt}/${MAX_ATTEMPTS})`);
        post = await generatePost(cand, { prevReasons });
        log(`-- ${cand.id}: mode=${post.mode} textLen=${post.text.length}`);
        gr = checkPost(post, sourceContent);
        if (gr.pass) break;
        log(`-- ${cand.id}: attempt ${attempt} blocked: ${gr.reasons.join("; ")}`);
        prevReasons = gr.reasons;
      }

      if (!gr.pass) {
        log(`-- ${cand.id}: GUARDRAIL BLOCKED (after ${MAX_ATTEMPTS}): ${gr.reasons.join("; ")}`);
        blocked.push({ id: cand.id, reasons: gr.reasons });
        await notify({
          kind: "guardrail",
          level: "warning",
          title: `Guardrail block: ${cand.id}`,
          text: "Claude/GPT が tone/事実チェックに失敗。投稿スキップ。",
          fields: [
            { label: "id", value: cand.id },
            { label: "reasons", value: gr.reasons.map((r) => `• ${r}`).join("\n") },
          ],
        });
        state.posts.push({
          id: post.id,
          ch: post.ch,
          status: "blocked",
          reasons: gr.reasons,
          generatedAt: post.generatedAt,
          blockedAt: new Date().toISOString(),
        });
        saveState(state);
        continue;
      }

      log(`-- ${cand.id}: guardrail PASS`);

      const result = await postToX(post, { dryRun: !args.live });
      log(
        `-- ${cand.id}: ${result.dryRun ? "DRY-RUN" : "POSTED"} ${
          result.url || ""
        }`
      );

      appendArchive(post, result);
      markPosted(state, post, result);
      saveState(state);
      if (!result.dryRun) {
        successCount++;
        await notify({
          kind: "success",
          level: "success",
          title: `投稿成功: ${cand.id}`,
          text: `<${result.url}|X で開く>`,
          fields: [
            { label: "id", value: cand.id },
            { label: "mode", value: post.mode },
            { label: "length", value: String(post.text.length) },
          ],
        });
      }
      // count 達成したら以降の候補を消費しない (fail-safe で多めに pick してるため)
      if (successCount >= args.count) {
        log(`-- reached target count=${args.count}, stop iterating`);
        break;
      }
    } catch (err) {
      errorCount++;
      log(`-- ${cand.id}: ERROR ${err.message}`);
      await notifyFromError(err, { source: "sns-run.mjs", id: cand.id });
      state.posts.push({
        id: cand.id,
        ch: cand.ch,
        status: "error",
        error: String(err.message || err),
        erroredAt: new Date().toISOString(),
      });
      saveState(state);
    }
  }

  log(`=== sns-run end success=${successCount} errors=${errorCount} blocked=${blocked.length} ===`);

  if (errorCount > 0 || blocked.length >= 2) {
    await notify({
      kind: "digest",
      level: errorCount > 0 ? "error" : "warning",
      title: "SNS ラン完了 (要確認)",
      fields: [
        { label: "success", value: String(successCount) },
        { label: "errors", value: String(errorCount) },
        { label: "blocked", value: String(blocked.length) },
        { label: "live", value: String(args.live) },
      ],
    });
  }

  close();
}

function resolveForCheck(sourceNote) {
  const wikilink = sourceNote.match(/\[\[([^\]]+)\]\]/);
  if (wikilink) {
    const rel = wikilink[1];
    const candidates = [path.join(VAULT, rel + ".md"), path.join(VAULT, rel)];
    for (const c of candidates) if (fs.existsSync(c)) return c;
    return findByName(VAULT, rel.split("/").pop() + ".md");
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

main().catch(async (e) => {
  console.error(e);
  await notifyFromError(e, { source: "sns-run.mjs (top-level)" });
  process.exit(1);
});
