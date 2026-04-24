#!/usr/bin/env node
// SNS ドラフト生成: 在庫_マップ.md → _Vault/SNS/ドラフト/YYYY-MM-DD.md
//
// 使い方:
//   node scripts/sns-draft.mjs                      # 翌日分3本
//   node scripts/sns-draft.mjs --date=2026-04-25    # 指定日
//   node scripts/sns-draft.mjs --count=5            # 5本
//   node scripts/sns-draft.mjs --dry                # 書き出さず stdout に表示
//
// 動作:
//   1. 在庫_マップ.md の全テーブル行をパース
//   2. 「最終投稿日」が古い / 空のものから N 件ピック
//   3. 各候補について sourceNote の冒頭を抜粋
//   4. _TEMPLATE.md の構造に沿って ドラフト/YYYY-MM-DD.md を生成
//   5. sns-posts.json の posts[] に draft エントリを追加
//
// 出力後の運用:
//   - 人間が 5 分でレビュー → Buffer に貼る
//   - 投稿したら 在庫_マップ.md の「最終投稿日」を手で埋める
//   - ドラフトは _Vault/SNS/公開済/ に move

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, "..");
const VAULT = path.resolve(ROOT, "../_Vault");
const INVENTORY = path.join(VAULT, "SNS/在庫_マップ.md");
const DRAFTS_DIR = path.join(VAULT, "SNS/ドラフト");
const STATE_FILE = path.join(ROOT, "content/sns-posts.json");

function parseArgs(argv) {
  const args = { date: null, count: 3, dry: false };
  for (const a of argv.slice(2)) {
    if (a.startsWith("--date=")) args.date = a.slice(7);
    else if (a.startsWith("--count=")) args.count = parseInt(a.slice(8), 10);
    else if (a === "--dry") args.dry = true;
  }
  if (!args.date) {
    const d = new Date();
    d.setDate(d.getDate() + 1);
    args.date = d.toISOString().slice(0, 10);
  }
  return args;
}

function parseInventory(md) {
  // 各テーブル行: | id | ch | sourceNote | angle | 最終投稿日 |
  const rows = [];
  const lines = md.split("\n");
  for (const line of lines) {
    if (!line.startsWith("| SNS-")) continue;
    const cells = line.split("|").map((c) => c.trim()).filter(Boolean);
    if (cells.length < 4) continue;
    const [id, ch, sourceNote, angle, lastPosted] = cells;
    rows.push({
      id,
      ch,
      sourceNote,
      angle,
      lastPosted: lastPosted || "",
    });
  }
  return rows;
}

function resolveWikilink(sourceNote) {
  // "[[学び/Foo]]" → "_Vault/学び/Foo.md"
  // "`Deepgram/xxx.md`" → "Deepgram/xxx.md" (Vault 親ディレクトリ)
  const wikilink = sourceNote.match(/\[\[([^\]]+)\]\]/);
  if (wikilink) {
    const rel = wikilink[1];
    const candidates = [
      path.join(VAULT, rel + ".md"),
      path.join(VAULT, rel),
    ];
    for (const c of candidates) {
      if (fs.existsSync(c)) return c;
    }
    // Vault 直下で名前一致を探す (wikilink は autoresolve)
    const name = rel.split("/").pop() + ".md";
    try {
      const found = findByName(VAULT, name);
      if (found) return found;
    } catch {}
    return null;
  }
  const backtick = sourceNote.match(/`([^`]+)`/);
  if (backtick) {
    const rel = backtick[1].split("#")[0];
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
    } else if (e.name === name) {
      return full;
    }
  }
  return null;
}

function excerpt(filePath, maxLines = 30) {
  if (!filePath || !fs.existsSync(filePath)) return "(sourceNote が見つかりませんでした)";
  const content = fs.readFileSync(filePath, "utf8");
  return content.split("\n").slice(0, maxLines).join("\n");
}

function pickCandidates(rows, count) {
  // 1) 最終投稿日が空のものを優先
  // 2) 日付が古い順
  const scored = rows.map((r) => ({
    ...r,
    score: r.lastPosted ? Date.parse(r.lastPosted) || 0 : -1,
  }));
  scored.sort((a, b) => a.score - b.score);
  return scored.slice(0, count);
}

function buildDraftSection(cand) {
  const srcPath = resolveWikilink(cand.sourceNote);
  const ex = excerpt(srcPath, 25);
  const header = cand.ch === "LI" ? "💼 LinkedIn" : "🐦 X";
  return `## ${header} — ${cand.id} (${cand.ch})

**sourceNote:** ${cand.sourceNote}
**angle:** ${cand.angle}

<details><summary>sourceNote 冒頭 (編集時に参照)</summary>

\`\`\`
${ex}
\`\`\`

</details>

### 投稿本文 (書き換える)

\`\`\`
${cand.angle}

(ここに本文。X なら 140字/ツイ、スレッドは --- で区切る。LinkedIn は 予告→中身→CTA の3部構成)
\`\`\`

**予約時刻:** ${cand.ch === "LI" ? "09:00 ET" : "08:00 JST / 19:00 ET"}
**CTA:** (ニュースレター / DM / App Store)

---
`;
}

function buildDraftFile(date, candidates) {
  const header = `# SNS ドラフト — ${date}

> 自動生成: ${new Date().toISOString()}
> 候補数: ${candidates.length}
> **5分レビュー → Buffer 投入 → 在庫_マップ.md の「最終投稿日」を埋める**

---

`;
  const sections = candidates.map(buildDraftSection).join("\n");
  const footer = `
## 投稿後チェックリスト

- [ ] Buffer で予約した
- [ ] \`_Vault/SNS/在庫_マップ.md\` の「最終投稿日」を ${date} で更新
- [ ] このファイルを \`_Vault/SNS/公開済/${date}.md\` に移動
- [ ] engagement メモ (いいね / リプ / 保存)
`;
  return header + sections + footer;
}

function updateState(stateFile, date, candidates) {
  const state = fs.existsSync(stateFile)
    ? JSON.parse(fs.readFileSync(stateFile, "utf8"))
    : { meta: {}, posts: [] };
  for (const c of candidates) {
    state.posts.push({
      id: c.id,
      ch: c.ch,
      draftDate: date,
      status: "draft",
      createdAt: new Date().toISOString(),
    });
  }
  fs.writeFileSync(stateFile, JSON.stringify(state, null, 2) + "\n");
}

function main() {
  const args = parseArgs(process.argv);
  if (!fs.existsSync(INVENTORY)) {
    console.error(`✗ inventory not found: ${INVENTORY}`);
    process.exit(1);
  }
  const inventory = parseInventory(fs.readFileSync(INVENTORY, "utf8"));
  if (!inventory.length) {
    console.error("✗ inventory is empty — 在庫_マップ.md のテーブルを確認してください");
    process.exit(1);
  }
  const candidates = pickCandidates(inventory, args.count);
  const draft = buildDraftFile(args.date, candidates);

  if (args.dry) {
    console.log(draft);
    return;
  }

  fs.mkdirSync(DRAFTS_DIR, { recursive: true });
  const outPath = path.join(DRAFTS_DIR, `${args.date}.md`);
  fs.writeFileSync(outPath, draft);
  updateState(STATE_FILE, args.date, candidates);

  console.log(`✓ draft written: ${outPath}`);
  console.log(`  picks: ${candidates.map((c) => c.id).join(", ")}`);
  console.log(`✓ state updated: ${STATE_FILE}`);
}

main();
