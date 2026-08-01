import assert from "node:assert/strict";
import http, { type IncomingMessage } from "node:http";
import { spawn, type ChildProcess } from "node:child_process";
import { mkdtempSync, mkdirSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { chromium } from "playwright";

const SERVER_JS = new URL("../_build/js/release/build/server/server.js", import.meta.url).pathname;
const WORK_DIR = mkdtempSync(join(tmpdir(), "yunomi-review-comment-reanchor-"));
const REPORT = join(WORK_DIR, "REPORT.md");
const REVIEW_DIR = join(WORK_DIR, "reviews");
const LOCK_DIR = join(WORK_DIR, "locks");

function request(port: number, method: string, path: string, body = ""): Promise<{ status: number; body: string }> {
  return new Promise((resolve, reject) => {
    const req = http.request(`http://127.0.0.1:${port}${path}`, { method, headers: { "Content-Type": "application/json" } }, (res: IncomingMessage) => {
      let response = "";
      res.on("data", (chunk: string) => { response += chunk; });
      res.on("end", () => resolve({ status: res.statusCode || 0, body: response }));
    });
    req.on("error", reject);
    if (body) req.write(body);
    req.end();
  });
}

async function waitForServer(proc: ChildProcess): Promise<number> {
  let output = "";
  return new Promise((resolve, reject) => {
    const consume = (chunk: Buffer) => {
      output += String(chunk);
      const match = output.match(/http:\/\/127\.0\.0\.1:(\d+)/);
      if (match) resolve(Number(match[1]));
    };
    proc.stdout?.on("data", consume);
    proc.stderr?.on("data", consume);
    proc.once("exit", (code) => reject(new Error(`server exited before ready (${code})\n${output}`)));
    setTimeout(() => reject(new Error(`server startup timeout\n${output}`)), 10_000);
  });
}

async function waitForRound(port: number, round: number): Promise<any> {
  for (let i = 0; i < 80; i++) {
    const state = JSON.parse((await request(port, "GET", "/review-state")).body);
    if (state.review.rounds.at(-1)?.round === round) return state;
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  throw new Error(`round ${round} did not appear`);
}

const initial = [
  "# Reanchor", "", "before A", "", "TARGET", "RANGE END A", "", "after A", "", "before B", "TARGET", "after B", "",
  "before keep", "STAYS", "after keep", "", "before replace", "TARGET REPLACE", "after replace", "", "before deleted", "DELETE ME", "after deleted", "",
  "before ambiguous", "AMBIGUOUS", "after ambiguous", "", "| Left | Right |", "|---|---|", "| same | same |", "",
].join("\n");
const revised = [
  "# Reanchor", "", "inserted before every target", "", "before keep", "STAYS", "after keep", "",
  "before B", "TARGET", "after B", "", "| Left | Right |", "|---|---|", "| same | same |", "",
  "before A", "", "TARGET", "RANGE END A", "", "after A changed", "", "before ambiguous", "AMBIGUOUS", "after ambiguous", "",
  "before ambiguous", "AMBIGUOUS", "after ambiguous", "",
  "before replace", "REPLACED", "after replace", "",
].join("\n");

function rowOf(text: string, marker: string, occurrence = 0): number {
  let seen = 0;
  for (const [index, line] of text.split("\n").entries()) {
    if (line !== marker) continue;
    if (seen === occurrence) return index;
    seen++;
  }
  throw new Error(`missing ${marker} #${occurrence}`);
}

mkdirSync(REVIEW_DIR, { recursive: true });
mkdirSync(LOCK_DIR, { recursive: true });
writeFileSync(REPORT, initial);
writeFileSync(join(REVIEW_DIR, "review.json"), JSON.stringify({
  version: 1,
  branch: "reanchor",
  files: ["REPORT.md"],
  rounds: [{ round: 1, started_at: "2026-07-31T00:00:00.000Z", submitted_at: "2026-07-31T00:01:00.000Z", decision: "request_changes", summary: "" }],
  comments: [
    { id: "c-1-1", file: "REPORT.md", row: rowOf(initial, "TARGET"), col: 0, end_row: rowOf(initial, "TARGET"), end_col: 0, line: rowOf(initial, "TARGET") + 1, round: 1, text: "thread A", quote: "TARGET", status: "unresolved", replies: [], anchor: { snippet: "TARGET", context_before: "before A\n", context_after: "\nafter A" } },
    { id: "c-1-2", file: "REPORT.md", row: rowOf(initial, "TARGET", 1), col: 0, end_row: rowOf(initial, "TARGET", 1), end_col: 0, line: rowOf(initial, "TARGET", 1) + 1, round: 1, text: "thread B", quote: "TARGET", status: "unresolved", replies: [], anchor: { snippet: "TARGET", context_before: "before B", context_after: "after B" } },
    { id: "c-1-3", file: "REPORT.md", row: rowOf(initial, "| same | same |"), col: 1, end_row: rowOf(initial, "| same | same |"), end_col: 1, line: rowOf(initial, "| same | same |") + 1, round: 1, text: "left cell", quote: "| same | same |", value: "Markdown table cell R33 C1: same | source: | same | same |", status: "unresolved", replies: [], anchor: { snippet: "| same | same |", context_before: "|---|---|", context_after: "" } },
    { id: "c-1-4", file: "REPORT.md", row: rowOf(initial, "| same | same |"), col: 2, end_row: rowOf(initial, "| same | same |"), end_col: 2, line: rowOf(initial, "| same | same |") + 1, round: 1, text: "right cell", quote: "| same | same |", value: "Markdown table cell R33 C2: same | source: | same | same |", status: "unresolved", replies: [], anchor: { snippet: "| same | same |", context_before: "|---|---|", context_after: "" } },
    { id: "c-1-14", file: "REPORT.md", row: rowOf(initial, "| same | same |"), col: 3, end_row: rowOf(initial, "| same | same |"), end_col: 3, line: rowOf(initial, "| same | same |") + 1, round: 1, text: "removed third cell", quote: "| same | same |", value: "Markdown table cell R33 C3: removed | source: | same | same |", status: "unresolved", replies: [], anchor: { snippet: "| same | same |", context_before: "|---|---|", context_after: "" } },
    { id: "c-1-10", file: "REPORT.md", row: rowOf(initial, "TARGET"), col: 0, end_row: rowOf(initial, "TARGET"), end_col: 0, line: rowOf(initial, "TARGET") + 1, round: 1, text: "thread A tenth", quote: "TARGET", status: "unresolved", replies: [], anchor: { snippet: "TARGET", context_before: "before A\n", context_after: "\nafter A" } },
    { id: "c-1-5", file: "REPORT.md", row: rowOf(initial, "TARGET"), col: 0, end_row: rowOf(initial, "TARGET"), end_col: 0, line: rowOf(initial, "TARGET") + 1, round: 1, text: "thread A second", quote: "TARGET", status: "unresolved", replies: [], anchor: { snippet: "TARGET", context_before: "before A\n", context_after: "\nafter A" } },
    { id: "c-1-9", file: "REPORT.md", row: rowOf(initial, "TARGET"), col: 0, end_row: rowOf(initial, "TARGET") + 2, end_col: 0, line: rowOf(initial, "TARGET") + 1, round: 1, text: "thread A range", quote: "TARGET", status: "unresolved", replies: [], anchor: { snippet: "TARGET", context_before: "before A\n", context_after: "\nafter A" } },
    { id: "c-1-6", file: "REPORT.md", row: rowOf(initial, "STAYS"), col: 0, end_row: rowOf(initial, "STAYS"), end_col: 0, line: rowOf(initial, "STAYS") + 1, round: 1, text: "inserted before", quote: "STAYS", status: "unresolved", replies: [], anchor: { snippet: "STAYS", context_before: "before keep", context_after: "after keep" } },
    { id: "c-1-11", file: "REPORT.md", row: rowOf(initial, "STAYS"), col: 0, end_row: rowOf(initial, "STAYS"), end_col: 0, line: rowOf(initial, "STAYS") + 1, round: 1, text: "legacy source marker", status: "unresolved", replies: [], value: "legacy label | source: STAYS", element_text: "legacy label | source: STAYS", anchor: { snippet: "before keep\nSTAYS\nafter keep", context_before: "before keep", context_after: "after keep" } },
    { id: "c-1-7", file: "REPORT.md", row: rowOf(initial, "DELETE ME"), col: 0, end_row: rowOf(initial, "DELETE ME"), end_col: 0, line: rowOf(initial, "DELETE ME") + 1, round: 1, text: "deleted target", quote: "DELETE ME", status: "unresolved", replies: [], anchor: { snippet: "DELETE ME", context_before: "before deleted", context_after: "after deleted" } },
    { id: "c-1-8", file: "REPORT.md", row: rowOf(initial, "AMBIGUOUS"), col: 0, end_row: rowOf(initial, "AMBIGUOUS"), end_col: 0, line: rowOf(initial, "AMBIGUOUS") + 1, round: 1, text: "ambiguous target", quote: "AMBIGUOUS", status: "unresolved", replies: [], anchor: { snippet: "AMBIGUOUS", context_before: "before ambiguous", context_after: "after ambiguous" } },
    { id: "c-1-12", file: "REPORT.md", row: rowOf(initial, "TARGET", 1), col: 0, end_row: rowOf(initial, "TARGET", 1), end_col: 0, line: rowOf(initial, "TARGET", 1) + 1, round: 1, text: "continuous snippet", status: "unresolved", replies: [], anchor: { snippet: "before B\nTARGET\nafter B", context_before: "before B", context_after: "after B" } },
    { id: "c-1-13", file: "REPORT.md", row: rowOf(initial, "TARGET REPLACE"), col: 0, end_row: rowOf(initial, "TARGET REPLACE"), end_col: 0, line: rowOf(initial, "TARGET REPLACE") + 1, round: 1, text: "replaced target", quote: "TARGET REPLACE", status: "unresolved", replies: [], anchor: { snippet: "TARGET REPLACE", context_before: "before replace", context_after: "after replace" } },
  ],
}, null, 2));

let server: ChildProcess | null = null;
let browser: Awaited<ReturnType<typeof chromium.launch>> | null = null;
try {
  server = spawn(process.execPath, [SERVER_JS, "--no-open", "--loop", "--port", "0", REPORT], {
    cwd: WORK_DIR,
    env: { ...process.env, HERDR_PANE_ID: "", YUNOMI_NOTIFY_CMD: "", YUNOMI_REVIEW_DIR: REVIEW_DIR, YUNOMI_LOCK_DIR: LOCK_DIR },
    stdio: ["ignore", "pipe", "pipe"],
  });
  const port = await waitForServer(server);
  writeFileSync(REPORT, revised);
  assert.equal((await request(port, "POST", "/go")).status, 200, "next round signal is accepted");
  const state = await waitForRound(port, 2);
  const byId = new Map(state.review.comments.map((comment: { id: string }) => [comment.id, comment]));
  assert.deepEqual(
    [byId.get("c-1-1")?.line, byId.get("c-1-2")?.line, byId.get("c-1-3")?.line, byId.get("c-1-4")?.line, byId.get("c-1-6")?.line, byId.get("c-1-11")?.line, byId.get("c-1-12")?.line, byId.get("c-1-13")?.line],
    [rowOf(revised, "TARGET", 1) + 1, rowOf(revised, "TARGET") + 1, rowOf(revised, "| same | same |") + 1, rowOf(revised, "| same | same |") + 1, rowOf(revised, "STAYS") + 1, rowOf(revised, "STAYS") + 1, rowOf(revised, "TARGET") + 1, rowOf(revised, "REPLACED") + 1],
    "inserted, moved, and table targets reanchor by quote plus surrounding context",
  );
  assert.deepEqual(
    [byId.get("c-1-1")?.row, byId.get("c-1-2")?.row, byId.get("c-1-3")?.end_row, byId.get("c-1-4")?.end_row, byId.get("c-1-6")?.end_row, byId.get("c-1-9")?.end_row],
    [rowOf(revised, "TARGET", 1), rowOf(revised, "TARGET"), rowOf(revised, "| same | same |"), rowOf(revised, "| same | same |"), rowOf(revised, "STAYS"), rowOf(revised, "TARGET", 1) + 2],
    "row, line, and multi-line end_row stay synchronized with the resolved span",
  );
  assert.equal(byId.get("c-1-7")?.unanchored, true, "a deleted target fails closed instead of retaining its old row");
  assert.equal(byId.get("c-1-8")?.unanchored, true, "identical quote and context candidates fail closed instead of choosing one");
  assert.equal(byId.get("c-1-12")?.unanchored, false, "continuous legacy snippet resolves only at its matching target row");
  assert.equal(byId.get("c-1-13")?.unanchored, false, "a changed quote resolves when both preserved contexts uniquely identify its replacement row");

  browser = await chromium.launch({ headless: true });
  const page = await browser.newPage({ viewport: { width: 1280, height: 900 } });
  await page.goto(`http://127.0.0.1:${port}/`, { waitUntil: "domcontentloaded" });
  await page.waitForSelector(".review-loop-inline", { timeout: 10_000 });
  const readRendered = () => page.evaluate(() => Array.from(document.querySelectorAll<HTMLElement>(".review-loop-inline"), (inline) => {
    const cell = inline.closest<HTMLElement>("td,th");
    const preceding = inline.previousElementSibling as HTMLElement | null;
    return {
      id: inline.dataset.reviewCommentId || "",
      cell: cell?.getAttribute("data-col") || "",
      row: cell?.getAttribute("data-row") || preceding?.dataset.sourceLine || preceding?.dataset.sourceStartLine || "",
      sourceStart: cell?.dataset.sourceStartLine || preceding?.dataset.sourceStartLine || preceding?.dataset.sourceLine || "",
      sourceEnd: cell?.dataset.sourceEndLine || preceding?.dataset.sourceEndLine || preceding?.dataset.sourceLine || "",
    };
  }));
  const assertRendered = async () => {
    const rendered = await readRendered();
    assert.deepEqual(
      rendered.map((entry) => entry.id),
      ["c-1-6", "c-1-11", "c-1-2", "c-1-12", "c-1-3", "c-1-4", "c-1-1", "c-1-10", "c-1-5", "c-1-9", "c-1-13"],
      "document order is stable and comments sharing one target preserve review.json array order",
    );
    assert.equal(rendered.length, 11, "14 unresolved comments render 11 anchored inline threads");
    assert.equal(new Set(rendered.map((entry) => entry.id)).size, 11, "each anchored comment has exactly one inline thread");
    assert.deepEqual(
      rendered.filter((entry) => entry.id === "c-1-3" || entry.id === "c-1-4").map((entry) => entry.cell),
      ["1", "2"],
      "same-row same-text table comments render exactly once inside their own cells",
    );
    const duplicateRanges = rendered.filter((entry) => entry.id === "c-1-1" || entry.id === "c-1-2").map((entry) => ({
      ...entry,
      start: Number(entry.sourceStart),
      end: Number(entry.sourceEnd),
    }));
    assert.equal(duplicateRanges.length, 2, "both duplicate TARGET threads render once");
    assert.ok(duplicateRanges.every((entry) => entry.start <= rowOf(revised, "TARGET", entry.id === "c-1-1" ? 1 : 0) + 1 && rowOf(revised, "TARGET", entry.id === "c-1-1" ? 1 : 0) + 1 <= entry.end), "each duplicate thread's server-resolved source line is inside its rendered target range", duplicateRanges);
    assert.notEqual(duplicateRanges[0]?.sourceStart, duplicateRanges[1]?.sourceStart, "duplicate TARGET threads use separate context ranges rather than the first matching block");
    assert.equal(rendered.some((entry) => entry.id === "c-1-7" || entry.id === "c-1-8" || entry.id === "c-1-14"), false, "deleted, ambiguous, and missing-column comments never render at an old or arbitrary target");
    const unanchoredCards = page.locator("#review-loop-panel .review-loop-unanchored > .review-loop-list > .review-loop-comment");
    assert.equal(await unanchoredCards.count(), 3, "deleted, ambiguous, and missing-column comments remain visible as explicit unanchored cards");
    assert.deepEqual(await unanchoredCards.evaluateAll((cards) => cards.map(card => card.getAttribute("data-review-comment-id"))), ["c-1-14", "c-1-7", "c-1-8"], "unanchored sidebar cards identify only the comments that cannot be placed safely");
    assert.equal(await page.locator("#review-loop-panel .review-loop-unanchored .review-loop-reply-form").count(), 3, "unanchored cards retain reply actions");
    assert.equal(await page.locator("#review-loop-panel .review-loop-unanchored .review-loop-resolve").count(), 3, "unanchored cards retain resolve actions");
    assert.match(await page.locator("#review-loop-panel .review-loop-meta").textContent() || "", /14 open/, "unanchored comments remain in the unresolved count and gate");
  };
  await assertRendered();
  await page.reload({ waitUntil: "domcontentloaded" });
  await page.waitForSelector(".review-loop-inline", { timeout: 10_000 });
  await assertRendered();
} finally {
  await browser?.close();
  if (server?.exitCode === null) server.kill("SIGTERM");
  rmSync(WORK_DIR, { recursive: true, force: true });
}
