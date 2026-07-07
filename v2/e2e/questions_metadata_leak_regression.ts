/**
 * E2E regression for task #17 — the Document Metadata table (rendered from
 * generic YAML frontmatter) had no indentation/nesting awareness, so it
 * read "id:", "question:", "context:", "resolved:" etc. straight out of
 * the nested `yunomi: questions:` block as if they were flat top-level
 * frontmatter keys. Since the SAME nested key repeats once per question,
 * each question's value silently overwrote the previous one — a real
 * REPORT.md with 3 questions showed only the LAST question's id/context in
 * Document Metadata, duplicating (and mangling) content the questions
 * modal already owns and renders correctly.
 *
 * Root cause + fix live in parse_markdown() (markdown.mbt): the frontmatter
 * scanner now tracks whether it's inside the `yunomi:` block by
 * indentation and skips every line inside it (the `yunomi:` key itself,
 * and everything nested under it), while still parsing real sibling
 * top-level keys (title, author, ...) normally. See the unit test "parse
 * markdown frontmatter excludes nested yunomi keys" in markdown_test.mbt
 * for the parser-level proof; this file proves it end-to-end in the
 * rendered page.
 *
 * The task also covered the pill's old "🗂️ 未回答の質問が…件あります"
 * emoji + explanatory-copy text — that was already replaced with a
 * minimal icon+badge pill during task #16's redesign (see html.mbt's
 * build_questions_modal()); this file re-confirms no emoji renders there
 * so a future change can't silently regress it back.
 *
 * Run: node --experimental-strip-types e2e/questions_metadata_leak_regression.ts
 */
import { spawn, type ChildProcess } from "node:child_process";
import { mkdtempSync, writeFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { chromium } from "playwright";

const SERVER_JS = new URL(
  "../_build/js/release/build/server/server.js",
  import.meta.url,
).pathname;
const LOCK_DIR = join(tmpdir(), "yunomi-questions-metadata-leak-locks");

let failed = 0;
function pass(msg: string): void {
  console.log(`PASS: ${msg}`);
}
function fail(msg: string, detail?: unknown): void {
  failed++;
  console.error(`FAIL: ${msg}`);
  if (detail !== undefined) console.error(JSON.stringify(detail, null, 2));
}
function assertTrue(condition: boolean, msg: string, detail?: unknown): void {
  condition ? pass(msg) : fail(msg, detail);
}

// 3 questions sharing the same nested keys (id/question/context/resolved),
// same shape as the real REPORT.md that exposed the bug, PLUS two real
// top-level sibling frontmatter keys (title/author) that must still render
// normally in Document Metadata.
const FIXTURE = `---
title: Wave 0 Report
author: Alice
yunomi:
  questions:
    - id: q-first
      question: First question, should not leak into Metadata?
      context: |
        Judgment material for the first question.
      resolved: false
    - id: q-second
      question: Second question, should not leak into Metadata?
      resolved: false
    - id: q-third
      question: Third (last) question — this id/context used to be the
        ONLY one visible in the buggy Metadata table
      context: |
        Judgment material for the third question.
      resolved: false
---

# Metadata Leak Regression Fixture
`;

type ServerHandle = { proc: ChildProcess; port: number };

function startServer(mdPath: string): Promise<ServerHandle> {
  return new Promise((resolve, reject) => {
    const proc = spawn(
      process.execPath,
      [SERVER_JS, mdPath, "--no-open", "--port", "0"],
      {
        cwd: new URL("..", import.meta.url).pathname,
        env: { ...process.env, YUNOMI_LOCK_DIR: LOCK_DIR, YUNOMI_REVIEW_DIR: join(tmpdir(), "yunomi-review-" + Date.now() + "-" + Math.random().toString(36).slice(2,6)) },
        stdio: ["ignore", "pipe", "pipe"],
      },
    );
    let out = "";
    let resolved = false;
    proc.stdout!.on("data", (d: Buffer) => {
      out += String(d);
      if (!resolved) {
        const m = out.match(/http:\/\/127\.0\.0\.1:(\d+)/);
        if (m) {
          resolved = true;
          resolve({ proc, port: parseInt(m[1], 10) });
        }
      }
    });
    proc.stderr!.on("data", (d: Buffer) => (out += String(d)));
    proc.on("exit", (code) => {
      if (!resolved) reject(new Error(`server exited before ready (${code})\n${out}`));
    });
  });
}

async function main(): Promise<void> {
  const workDir = mkdtempSync(join(tmpdir(), "yunomi-metadata-leak-"));
  const mdPath = join(workDir, "report.md");
  writeFileSync(mdPath, FIXTURE);

  const browser = await chromium.launch();
  const { proc, port } = await startServer(mdPath);
  try {
    const page = await browser.newPage({ viewport: { width: 1280, height: 900 } });
    await page.goto(`http://127.0.0.1:${port}/`, { waitUntil: "domcontentloaded" });
    await page.waitForSelector("#yunomi-questions-overlay.visible", { timeout: 5000 });
    // Close the questions modal to inspect the Metadata table underneath.
    await page.locator("#yunomi-questions-close").click();
    await page.waitForTimeout(150);

    const metaRows = await page.evaluate(() => {
      const table = document.querySelector(".frontmatter-table");
      if (!table) return null;
      return Array.from(table.querySelectorAll("tr")).map((tr) => tr.textContent?.trim() ?? "");
    });
    assertTrue(metaRows !== null, "Document Metadataテーブルが描画される（実キーがあるため）", {
      metaRows,
    });
    const joined = (metaRows ?? []).join(" | ");
    assertTrue(joined.includes("Wave 0 Report"), "実在するtitleキーはMetadataテーブルに表示される", {
      joined,
    });
    assertTrue(joined.includes("Alice"), "実在するauthorキーはMetadataテーブルに表示される", {
      joined,
    });
    assertTrue(
      !joined.includes("q-first") &&
        !joined.includes("q-second") &&
        !joined.includes("q-third"),
      "questions配下のネストしたidの値がMetadataテーブルに一切表示されない（どの質問の値も、最後の質問の値さえも）",
      { joined },
    );
    assertTrue(
      !joined.includes("Judgment material"),
      "questions配下のネストしたcontextの値がMetadataテーブルに表示されない",
      { joined },
    );
    // parse_markdown() deliberately still emits ONE harmless summary row —
    // "yunomi questions: N question(s)" — built from md.questions.length(),
    // not from the raw frontmatter map. That's a count, not a leak of any
    // question's id/context/etc., so it's expected and fine; what must NOT
    // appear is the raw `yunomi` frontmatter KEY (an empty/block-mapping
    // value with no useful info) as its own row.
    assertTrue(
      !(metaRows ?? []).some((r) => /^yunomi[✎\s]*$/.test(r) || /^yunomi[✎\s]+(?!questions)/.test(r)),
      "yunomiキー自体（生のfrontmatter値）はMetadataテーブルの行として表示されない",
      { metaRows },
    );
    assertTrue(
      (metaRows ?? []).some((r) => r.includes("yunomi questions") && r.includes("3 question")),
      "代わりに件数のみのサマリ行（yunomi questions: 3 question(s)）が表示される（質問内容そのものの二重表示ではない）",
      { metaRows },
    );

    // Re-confirm the pill has no emoji (task #16 already fixed this; task
    // #17 asked for re-verification so a future change can't regress it).
    const pillHTML = await page.locator("#yunomi-questions-bar-open").innerHTML();
    const EMOJI_PATTERN = /[\u{1F300}-\u{1FAFF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]/u;
    assertTrue(!EMOJI_PATTERN.test(pillHTML), "未回答質問ピルに絵文字が一切含まれない", {
      pillHTML,
    });

    await page.screenshot({
      path: new URL(
        "../../.artifacts/crit-adoption/questions-redesign/10-metadata-clean.png",
        import.meta.url,
      ).pathname,
    });

    await page.close();
  } finally {
    if (!proc.killed) proc.kill();
    await browser.close();
    rmSync(workDir, { recursive: true, force: true });
  }

  console.log(`\nSummary: ${failed === 0 ? "all passed" : `${failed} failed`}`);
  if (failed > 0) process.exit(1);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
