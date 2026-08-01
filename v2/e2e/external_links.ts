import assert from "node:assert/strict";
import { spawn, type ChildProcess } from "node:child_process";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { chromium } from "playwright";

const SERVER_JS = new URL("../_build/js/release/build/server/server.js", import.meta.url).pathname;
const WORK_DIR = mkdtempSync(join(tmpdir(), "yunomi-external-links-"));
const REVIEW_DIR = join(WORK_DIR, "reviews");
const LOCK_DIR = join(WORK_DIR, "locks");
const REPORT = join(WORK_DIR, "REPORT.md");
const LINKED = join(WORK_DIR, "linked.html");
const PORT = 5874;

mkdirSync(REVIEW_DIR, { recursive: true });
mkdirSync(LOCK_DIR, { recursive: true });
writeFileSync(REPORT, [
  "# External links",
  "",
  `[Inline](http://127.0.0.1:${PORT}/linked.html)`,
  "",
  "[Reference][docs]",
  "",
  `<http://127.0.0.1:${PORT}/linked.html?source=autolink>`,
  "",
  '<a id="raw-link" href="./linked.html?source=raw" target="_self" rel="opener">Raw HTML</a>',
  "",
  "A note[^note].",
  "",
  "[^note]: Footnote body",
  "",
  "[docs]: ./linked.html?source=reference",
].join("\n"));
writeFileSync(LINKED, "<!doctype html><title>Linked target</title><h1>Linked target</h1>");

function waitForServer(proc: ChildProcess): Promise<number> {
  let output = "";
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error(`server start timeout\n${output}`)), 10_000);
    proc.stdout?.on("data", (chunk: Buffer) => {
      output += String(chunk);
      const match = output.match(/http:\/\/127\.0\.0\.1:(\d+)/);
      if (match) {
        clearTimeout(timer);
        resolve(Number(match[1]));
      }
    });
    proc.stderr?.on("data", (chunk: Buffer) => { output += String(chunk); });
    proc.once("exit", (code) => reject(new Error(`server exited before ready: ${code}\n${output}`)));
  });
}

const proc = spawn(process.execPath, [SERVER_JS, "--no-open", "--port", String(PORT), REPORT], {
  cwd: WORK_DIR,
  stdio: ["ignore", "pipe", "pipe"],
  env: {
    ...process.env,
    HERDR_PANE_ID: "",
    YUNOMI_NOTIFY_CMD: "",
    YUNOMI_LOCK_DIR: LOCK_DIR,
    YUNOMI_REVIEW_DIR: REVIEW_DIR,
  },
});

let browser;
try {
  const port = await waitForServer(proc);
  browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1280, height: 900 } });
  await page.goto(`http://127.0.0.1:${port}/`, { waitUntil: "domcontentloaded" });

  const links = page.locator("#md-preview a[href]");
  const linkState = await links.evaluateAll((nodes) => nodes.map((node) => {
    const link = node as HTMLAnchorElement;
    return { href: link.getAttribute("href"), target: link.target, rel: link.rel };
  }));
  assert.ok(linkState.length >= 6, "fixture renders inline, reference, autolink, raw HTML, and footnote links");
  assert.ok(linkState.every((link) => link.target === "_blank"), "every rendered document link targets a new tab");
  assert.ok(linkState.every((link) => link.rel.split(/\s+/).includes("noopener") && link.rel.split(/\s+/).includes("noreferrer")), "every rendered document link severs opener and referrer access");
  assert.deepEqual(
    linkState.find((link) => link.href?.includes("source=raw")),
    { href: "./linked.html?source=raw", target: "_blank", rel: "noopener noreferrer" },
    "raw HTML cannot override yunomi's external-tab contract",
  );

  const targetUrl = `http://127.0.0.1:${PORT}/linked.html`;
  const inlineLink = page.locator(`#md-preview a[href="${targetUrl}"]`);
  assert.equal(await inlineLink.evaluate((link: HTMLAnchorElement) => link.href), targetUrl, "the browser resolves the document link to its intended URL");
  const originalUrl = page.url();
  const context = page.context();
  const pageCount = context.pages().length;
  const popupPromise = context.waitForEvent("page");
  const requestPromise = context.waitForEvent("request", (request) => request.isNavigationRequest() && request.url() === targetUrl);
  await inlineLink.click();
  const popup = await popupPromise;
  const request = await requestPromise;
  assert.equal(page.url(), originalUrl, "clicking a document link keeps the review in its original tab");
  assert.equal(context.pages().length, pageCount + 1, "clicking a document link creates exactly one separate tab");
  assert.equal(request.frame().page(), popup, "the separate tab navigates to the document link target");
  await popup.close();
  await page.close();
  console.log("PASS: markdown document links always open in an external tab");
} finally {
  await browser?.close().catch(() => {});
  if (proc.exitCode === null) proc.kill("SIGTERM");
  rmSync(WORK_DIR, { recursive: true, force: true });
}
