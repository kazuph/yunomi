import http, { type IncomingMessage } from "node:http";
import { spawn, type ChildProcess } from "node:child_process";
import { mkdirSync, mkdtempSync, readFileSync, writeFileSync, rmSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { chromium } from "playwright";

const SERVER_JS = new URL(
  "../_build/js/release/build/server/server.js",
  import.meta.url,
).pathname;

const PORT = 5862;
let passed = 0;
let failed = 0;

function assert(condition: boolean, message: string): void {
  if (condition) {
    passed++;
    console.log(`PASS: ${message}`);
  } else {
    failed++;
    console.error(`FAIL: ${message}`);
  }
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function httpGet(path: string): Promise<{ status: number; body: Buffer; headers: http.IncomingHttpHeaders }> {
  return new Promise((resolve, reject) => {
    http.get(`http://127.0.0.1:${PORT}${path}`, (res: IncomingMessage) => {
      const chunks: Buffer[] = [];
      res.on("data", (chunk: Buffer) => chunks.push(chunk));
      res.on("end", () => resolve({
        status: res.statusCode ?? 0,
        body: Buffer.concat(chunks),
        headers: res.headers,
      }));
    }).on("error", reject);
  });
}

async function waitForReady(): Promise<boolean> {
  for (let i = 0; i < 50; i++) {
    try {
      const res = await httpGet("/healthz");
      if (res.status === 200) return true;
    } catch (_err: unknown) {}
    await sleep(100);
  }
  return false;
}

function waitForExit(proc: ChildProcess, timeoutMs: number): Promise<number | "timeout"> {
  return new Promise((resolve) => {
    const timer = setTimeout(() => resolve("timeout"), timeoutMs);
    proc.once("exit", (code: number | null) => {
      clearTimeout(timer);
      resolve(code ?? 0);
    });
  });
}

function yamlCommentBlock(text: string): string {
  const start = text.indexOf("comments:\n");
  if (start < 0) return "";
  const after = text.slice(start + "comments:\n".length);
  const end = after.search(/\nsummary:/);
  return end >= 0 ? after.slice(0, end) : after;
}

const dir = mkdtempSync(join(tmpdir(), "yunomi-html-preview-"));
const reviewDir = join(dir, "reviews");
mkdirSync(reviewDir, { recursive: true });
const htmlFile = join(dir, "page.html");
const logoFile = join(dir, "logo.png");
const linkedFile = join(dir, "linked.html");
writeFileSync(logoFile, Buffer.from(
  "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=",
  "base64",
));
writeFileSync(htmlFile, [
  "<!doctype html>",
  "<html>",
  "<body>",
  "<main>",
  "<button id=\"cta\">Buy</button>",
  "<a id=\"docs-link\" href=\"./linked.html\" target=\"_self\" rel=\"opener\">Docs</a>",
  "<img src=\"./logo.png\" alt=\"logo\">",
  "</main>",
  "</body>",
  "</html>",
].join("\n"));
writeFileSync(linkedFile, "<!doctype html><title>Linked HTML target</title><h1>Linked HTML target</h1>");

const proc = spawn("node", [
  SERVER_JS,
  htmlFile,
  "--no-open",
  "--host",
  "127.0.0.1",
  "--port",
  String(PORT),
], {
  stdio: ["ignore", "pipe", "pipe"],
  env: { ...process.env, HERDR_PANE_ID: "", YUNOMI_NOTIFY_CMD: "", YUNOMI_REVIEW_DIR: reviewDir },
});

let output = "";
proc.stdout?.on("data", (chunk: Buffer) => { output += chunk.toString("utf8"); });
proc.stderr?.on("data", (chunk: Buffer) => { output += chunk.toString("utf8"); });

try {
  assert(await waitForReady(), "HTML preview server becomes ready");

  const shell = await httpGet("/");
  const shellText = shell.body.toString("utf8");
  assert(shell.status === 200, "HTML preview shell returns 200");
  assert(shellText.includes("<iframe"), "HTML preview shell renders an iframe");
  assert(shellText.includes("sandbox=\"allow-scripts allow-same-origin allow-popups\""), "iframe permits user-activated external tabs without relaxing its remaining sandbox");
  assert(shellText.includes("src=\"/__yunomi_html_target\""), "iframe points at the local HTML target");
  assert(shellText.includes("data-theme=\"light\""), "HTML preview shell uses the markdown light theme token");
  assert(shellText.includes("--bg:#ffffff") || shellText.includes("--bg: #ffffff"), "HTML preview shell uses Primer canvas tokens like markdown");
  assert(!shellText.includes("#f6faf0"), "HTML preview shell no longer uses the old green tea chrome");
  assert(shellText.includes("class=\"brand\""), "HTML preview shell reuses the markdown brand mark");

  const target = await httpGet("/__yunomi_html_target");
  const targetText = target.body.toString("utf8");
  assert(target.status === 200, "iframe target returns the reviewed HTML");
  assert(targetText.includes("id=\"cta\""), "iframe target preserves the reviewed button");
  assert(targetText.includes("data-yunomi-html"), "iframe target injects the html comment overlay");

  const logo = await httpGet("/logo.png");
  assert(logo.status === 200, "relative image asset is served");
  assert(String(logo.headers["content-type"]).includes("image/png"), "relative image asset keeps image/png content type");
  assert(logo.body.length > 0, "relative image asset has a body");

  const browser = await chromium.launch();
  try {
    const page = await browser.newPage({ viewport: { width: 1280, height: 900 } });
    await page.goto(`http://127.0.0.1:${PORT}/`, { waitUntil: "domcontentloaded" });
    const frame = page.frameLocator("#yunomi-html-frame");
    const docsLink = frame.locator("#docs-link");
    assert(await docsLink.getAttribute("target") === "_blank", "HTML preview forces links into an external tab");
    assert(await docsLink.getAttribute("rel") === "noopener noreferrer", "HTML preview strips opener and referrer access");
    const shellUrl = page.url();
    const popupPromise = page.context().waitForEvent("page");
    await docsLink.click();
    const popup = await popupPromise;
    assert(page.url() === shellUrl, "HTML link clicks keep the review shell in its original tab");
    assert(popup.url().endsWith("/linked.html"), "HTML link clicks open the target in a separate tab");
    assert(await popup.evaluate(() => window.opener) === null, "HTML external tabs cannot access the review through window.opener");
    await popup.close();
    const submitButton = frame.locator("#yunomi-html-submit");
    assert(await submitButton.isVisible(), "HTML preview always shows Submit & Exit");
    await frame.locator("#cta").click();
    await frame.locator("#yunomi-html-card textarea").fill("CTA wording is too terse");
    await frame.locator("#yunomi-html-card [data-yunomi-save]").click();
    const exitPromise = waitForExit(proc, 5000);
    await submitButton.click();
    await frame.locator("#yunomi-html-submit-card textarea").fill("HTML needs a clearer CTA");
    await frame.locator("#yunomi-html-submit-card input[value='request_changes']").check();
    await frame.locator("#yunomi-html-submit-card [data-yunomi-submit]").click();
    const exitCode = await exitPromise;
    assert(exitCode === 0, "HTML preview Submit & Exit finishes the review");
    await page.close();
  } finally {
    await browser.close();
  }

  assert(output.includes("CTA wording is too terse"), "HTML preview /exit accepts comment payload");
  assert(output.includes("summary: HTML needs a clearer CTA"), "HTML preview submit preserves summary text");
  assert(output.includes("decision: request_changes"), "HTML preview submit can request changes");
  assert(output.includes("mode: html"), "submitted YAML includes mode: html");
  const commentBlock = yamlCommentBlock(output);
  const requiredKeys = ["file", "row", "col", "end_row", "end_col", "text", "snippet", "context_before", "context_after", "selector", "bounds", "element_text", "attachments"];
  assert(requiredKeys.every((key) => new RegExp(`(^|\\n)\\s{2,}(-\\s+)?${key}:`).test(commentBlock)), "HTML preview YAML comment block includes every common schema key");
  assert(commentBlock.includes("file: page.html"), "HTML preview YAML uses basename when the file is outside the process cwd");
  assert(!commentBlock.includes(htmlFile) && !commentBlock.includes(dir), "HTML preview YAML common file field does not expose absolute temp paths");
  assert(commentBlock.includes("row: 0"), "HTML preview YAML includes row");
  assert(commentBlock.includes("col: 0"), "HTML preview YAML includes col");
  assert(commentBlock.includes("end_row: 0"), "HTML preview YAML includes end_row");
  assert(commentBlock.includes("end_col: 0"), "HTML preview YAML includes end_col");
  assert(commentBlock.includes("snippet: Buy"), "HTML preview YAML includes snippet");
  assert(commentBlock.includes("context_before:"), "HTML preview YAML includes context_before");
  assert(commentBlock.includes("context_after:"), "HTML preview YAML includes context_after");
  assert(output.includes("selector: '#cta'") || output.includes("selector: #cta"), "submitted YAML includes selector");
  assert(output.includes("value: Buy"), "submitted YAML includes element text");
  assert(output.includes("bounds:"), "submitted YAML includes bounds");
  assert(commentBlock.includes("element_text: Buy"), "HTML preview YAML includes element_text");
  assert(commentBlock.includes("attachments: []"), "HTML preview YAML includes attachments");
  const review = JSON.parse(readFileSync(join(reviewDir, "review.json"), "utf8"));
  const persisted = review.comments?.find((comment: any) => comment.text === "CTA wording is too terse");
  assert(requiredKeys.every((key) => Object.prototype.hasOwnProperty.call(persisted || {}, key)), "HTML preview /exit persists every common schema key to review.json");
  assert(persisted?.file === "page.html" && persisted?.selector === "#cta" && persisted?.element_text === "Buy", "HTML preview review.json preserves relative file and DOM context");
} catch (err: unknown) {
  failed++;
  console.error(`FAIL: ${(err as Error).message}`);
} finally {
  try { proc.kill("SIGKILL"); } catch (_err: unknown) {}
  rmSync(dir, { recursive: true, force: true });
}

console.log(`HTML preview E2E: ${passed} passed, ${failed} failed`);
if (failed > 0) process.exit(1);
