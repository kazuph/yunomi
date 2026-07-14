import http from "node:http";
import { spawn, type ChildProcess } from "node:child_process";
import { mkdirSync, mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { chromium, type Page } from "playwright";

const SERVER_JS = new URL("../_build/js/release/build/server/server.js", import.meta.url).pathname;
const OUT = new URL("../../.artifacts/v3-plan/images/", import.meta.url).pathname;
const WORK_DIR = mkdtempSync(join(tmpdir(), "e-"));
const LOCK_DIR = join(WORK_DIR, "locks");
const REVIEW_DIR = join(WORK_DIR, "reviews", "evidence");
mkdirSync(LOCK_DIR, { recursive: true });
mkdirSync(REVIEW_DIR, { recursive: true });
mkdirSync(OUT, { recursive: true });

function assert(condition: boolean, message: string): void {
  if (!condition) throw new Error(message);
}

function start(file: string): Promise<{ proc: ChildProcess; port: number }> {
  const proc = spawn(process.execPath, [SERVER_JS, file, "--no-open"], {
    cwd: WORK_DIR,
    stdio: ["ignore", "pipe", "pipe"],
    env: { ...process.env, HERDR_PANE_ID: "", YUNOMI_NOTIFY_CMD: "", YUNOMI_LOCK_DIR: LOCK_DIR, YUNOMI_REVIEW_DIR: REVIEW_DIR },
  });
  let output = "";
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error(`server start timeout\n${output}`)), 10000);
    const collect = (chunk: Buffer) => {
      output += String(chunk);
      const match = output.match(/http:\/\/127\.0\.0\.1:(\d+)/);
      if (match) {
        clearTimeout(timer);
        resolve({ proc, port: Number(match[1]) });
      }
    };
    proc.stdout?.on("data", collect);
    proc.stderr?.on("data", collect);
    proc.once("exit", (code) => reject(new Error(`server exited before ready: ${code}\n${output}`)));
  });
}

async function assertBrand(page: Page): Promise<void> {
  const brand = await page.locator("header .brand").evaluate((element) => {
    const word = element.querySelector<HTMLElement>(".brand-word");
    return {
      text: element.textContent || "",
      wordDisplay: word ? getComputedStyle(word).display : "missing",
      wordBox: word?.getBoundingClientRect().toJSON() || null,
    };
  });
  assert(brand.text.includes("yunomi"), `missing yunomi wordmark: ${JSON.stringify(brand)}`);
  assert(brand.text.includes("🍵"), `missing tea mark: ${JSON.stringify(brand)}`);
  assert(brand.wordDisplay !== "none" && Boolean(brand.wordBox?.width), `hidden yunomi wordmark: ${JSON.stringify(brand)}`);
}

async function stop(proc: ChildProcess): Promise<void> {
  if (proc.exitCode !== null) return;
  const exited = new Promise<void>((resolve) => proc.once("exit", () => resolve()));
  proc.kill("SIGINT");
  await exited;
}

const markdown = join(WORK_DIR, "EVIDENCE.md");
writeFileSync(markdown, "# Evidence\n\nAfter line\n");
writeFileSync(join(REVIEW_DIR, "review.json"), JSON.stringify({
  version: 1,
  branch: "evidence",
  files: [markdown],
  rounds: [
    { round: 1, started_at: "2026-07-10T00:00:00.000Z", submitted_at: "2026-07-10T00:01:00.000Z", decision: "request_changes", summary: "Please update the evidence line" },
    { round: 2, started_at: "2026-07-10T00:02:00.000Z", submitted_at: null, decision: null, summary: "" },
  ],
  comments: [{
    id: "c-1-1",
    file: "EVIDENCE.md",
    line: 3,
    round: 1,
    text: "Please update this line",
    author: "human",
    status: "unresolved",
    replies: [{ author: "agent", round: 2, text: "Updated the evidence line" }],
    anchor: { snippet: "After line", context_before: "# Evidence", context_after: "" },
  }],
}, null, 2));

const diff = join(WORK_DIR, "evidence.diff");
writeFileSync(diff, [
  "diff --git a/alpha.txt b/alpha.txt",
  "index 1111111..2222222 100644",
  "--- a/alpha.txt",
  "+++ b/alpha.txt",
  "@@ -1,2 +1,2 @@",
  " one",
  "-old alpha",
  "+new alpha",
].join("\n"));

const browser = await chromium.launch({ headless: true });
let markdownServer: ChildProcess | null = null;
let diffServer: ChildProcess | null = null;
try {
  const markdownRun = await start(markdown);
  markdownServer = markdownRun.proc;
  const page = await browser.newPage({ viewport: { width: 1280, height: 900 }, locale: "en-US" });
  await page.goto(`http://127.0.0.1:${markdownRun.port}`, { waitUntil: "domcontentloaded" });
  await page.waitForSelector("#review-loop-panel .review-loop-comment", { timeout: 10000 });
  await page.evaluate(() => document.fonts.ready);
  await page.evaluate(() => new Promise<void>((resolve) => requestAnimationFrame(() => requestAnimationFrame(() => resolve()))));
  await assertBrand(page);
  await page.screenshot({ path: join(OUT, "20260710-review-loop-panel.png") });

  await page.locator("#send-and-exit").click();
  await page.waitForSelector("#submit-modal.visible", { timeout: 5000 });
  await assertBrand(page);
  await page.screenshot({ path: join(OUT, "20260710-sample-review-submit.png") });

  const mobile = await browser.newPage({ viewport: { width: 390, height: 844 }, locale: "en-US" });
  await mobile.goto(`http://127.0.0.1:${markdownRun.port}`, { waitUntil: "domcontentloaded" });
  await mobile.waitForSelector("#md-preview", { timeout: 10000 });
  await mobile.evaluate(() => document.fonts.ready);
  await assertBrand(mobile);
  await mobile.screenshot({ path: join(OUT, "20260710-header-mobile.png") });
  await mobile.close();
  await page.close();

  const diffRun = await start(diff);
  diffServer = diffRun.proc;
  const diffPage = await browser.newPage({ viewport: { width: 1280, height: 900 }, locale: "en-US" });
  await diffPage.goto(`http://127.0.0.1:${diffRun.port}`, { waitUntil: "domcontentloaded" });
  await diffPage.waitForSelector(".diff-review-shell", { timeout: 10000 });
  await diffPage.evaluate(() => document.fonts.ready);
  await diffPage.locator("#diff-split-toggle").click();
  await diffPage.locator(".diff-line.addition[data-file]").click();
  await diffPage.locator("#comment-input").fill("inline diff comment stays here");
  await diffPage.locator("#save-comment").click();
  await diffPage.waitForSelector(".review-comment-inline", { timeout: 5000 });
  await assertBrand(diffPage);
  assert(await diffPage.locator(".review-comment-inline-label").textContent() === "Comment", "diff evidence must use English Comment label");
  assert(await diffPage.locator(".diff-viewed-state").textContent() === "Unreviewed", "diff evidence must use English Unreviewed label");
  await diffPage.screenshot({ path: join(OUT, "20260710-diff-inline-comment.png") });
  await diffPage.close();
  console.log("PASS: captured four current v3 review evidence screenshots");
} finally {
  await browser.close();
  if (diffServer) await stop(diffServer);
  if (markdownServer) await stop(markdownServer);
}
