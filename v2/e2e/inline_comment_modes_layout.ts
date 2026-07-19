import { spawn, type ChildProcess } from "node:child_process";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { chromium, type Browser, type Page } from "playwright";

const SERVER_JS = new URL("../_build/js/release/build/server/server.js", import.meta.url).pathname;
const WORK_DIR = mkdtempSync(join(tmpdir(), "yunomi-mode-layout-"));
const BASE_PORT = 5898;
const fixtures = [
  { mode: "csv", file: join(WORK_DIR, "audit.csv"), content: "name,status,note\nalpha,ready,日本語の長い説明 🐈\nbeta,pending,review me\n", target: "tbody td[data-row][data-col]" },
  { mode: "tsv", file: join(WORK_DIR, "audit.tsv"), content: "name\tstatus\tnote\nalpha\tready\t日本語の長い説明 ☕\nbeta\tpending\treview me\n", target: "tbody td[data-row][data-col]" },
  { mode: "text", file: join(WORK_DIR, "audit.txt"), content: "first plain text line\n日本語の長い二行目 🐾\nthird line\n", target: ".text-line[data-row]" },
  { mode: "diff", file: join(WORK_DIR, "audit.diff"), content: "diff --git a/a.txt b/a.txt\nindex 1111111..2222222 100644\n--- a/a.txt\n+++ b/a.txt\n@@ -1,2 +1,2 @@\n-old line\n+new 日本語 line\n context\n", target: ".diff-line[data-row]" },
  { mode: "html", file: join(WORK_DIR, "audit.html"), content: "<!doctype html><html><head><meta charset=\"utf-8\"><style>body{font:16px system-ui;margin:40px;max-width:900px}button{padding:12px 20px}</style></head><body><h1>HTML preview</h1><p>日本語の長い説明と絵文字 🍵</p><button id=\"audit-target\">Review target</button></body></html>", target: "#audit-target" },
];
for (const fixture of fixtures) writeFileSync(fixture.file, fixture.content);

let passed = 0;
let failed = 0;
function assert(condition: boolean, message: string, detail?: unknown): void {
  if (condition) { passed++; console.log(`PASS: ${message}`); }
  else { failed++; console.error(`FAIL: ${message}`); if (detail !== undefined) console.error(JSON.stringify(detail, null, 2)); }
}

function startServer(): Promise<{ proc: ChildProcess; port: number; output: () => string }> {
  return new Promise((resolve, reject) => {
    const proc = spawn(process.execPath, [SERVER_JS, ...fixtures.map((item) => item.file), "--no-open", "--port", String(BASE_PORT)], {
      env: { ...process.env, HERDR_PANE_ID: "", YUNOMI_NOTIFY_CMD: "", YUNOMI_LOCK_DIR: join(WORK_DIR, "locks"), YUNOMI_REVIEW_DIR: join(WORK_DIR, "reviews") },
      stdio: ["ignore", "pipe", "pipe"],
    });
    let output = "";
    let settled = false;
    const consume = (chunk: Buffer) => {
      output += chunk.toString("utf8");
      const match = output.match(/http:\/\/127\.0\.0\.1:(\d+)/);
      if (!settled && match) { settled = true; resolve({ proc, port: Number(match[1]), output: () => output }); }
    };
    proc.stdout?.on("data", consume); proc.stderr?.on("data", consume);
    proc.on("exit", (code) => { if (!settled) reject(new Error(`server exited early ${code}\n${output}`)); });
    setTimeout(() => { if (!settled) reject(new Error(`server startup timeout\n${output}`)); }, 15_000);
  });
}

async function stopServer(proc: ChildProcess): Promise<void> {
  if (proc.exitCode !== null) return;
  await new Promise<void>((resolve) => { proc.once("exit", () => resolve()); proc.kill("SIGTERM"); setTimeout(resolve, 2_000); });
}

async function shellLayout(page: Page): Promise<Record<string, unknown>> {
  return page.evaluate(() => {
    const editor = document.querySelector<HTMLElement>(".yunomi-inline-comment-editor");
    const target = editor?.parentElement?.closest<HTMLElement>("tr,.text-line,.diff-line")?.previousElementSibling as HTMLElement | null;
    const editorRect = editor?.getBoundingClientRect();
    const targetRect = target?.getBoundingClientRect();
    const sidebar = document.querySelector<HTMLElement>(".media-sidebar:not(.hidden)");
    const comments = document.querySelector<HTMLElement>(".comment-list:not(.collapsed)");
    const sidebarRect = sidebar?.getBoundingClientRect();
    const commentsRect = comments?.getBoundingClientRect();
    return {
      viewportWidth: innerWidth,
      scrollWidth: document.documentElement.scrollWidth,
      editorCount: document.querySelectorAll(".yunomi-inline-comment-editor").length,
      inputIdCount: document.querySelectorAll("#comment-input").length,
      editorWithinViewport: !editorRect || (editorRect.left >= 0 && editorRect.right <= innerWidth),
      targetEditorOverlap: editorRect && targetRect
        ? Math.max(0, Math.min(editorRect.right, targetRect.right) - Math.max(editorRect.left, targetRect.left)) * Math.max(0, Math.min(editorRect.bottom, targetRect.bottom) - Math.max(editorRect.top, targetRect.top))
        : 0,
      commentsSidebarOverlap: commentsRect && sidebarRect
        ? Math.max(0, Math.min(commentsRect.right, sidebarRect.right) - Math.max(commentsRect.left, sidebarRect.left)) * Math.max(0, Math.min(commentsRect.bottom, sidebarRect.bottom) - Math.max(commentsRect.top, sidebarRect.top))
        : 0,
    };
  });
}

const server = await startServer();
let browser: Browser | null = null;
try {
  browser = await chromium.launch({ headless: true });
  for (let index = 0; index < fixtures.length; index++) {
    const fixture = fixtures[index];
    const page = await browser.newPage({ viewport: { width: 1280, height: 850 } });
    await page.goto(`http://127.0.0.1:${server.port + index}`, { waitUntil: "domcontentloaded" });
    if (fixture.mode === "html") {
      const frame = page.frameLocator("#yunomi-html-frame");
      await frame.locator(fixture.target).click();
      await frame.locator("#yunomi-html-card textarea").waitFor({ state: "visible" });
      const htmlLayout = await frame.locator("body").evaluate(() => {
        const card = document.querySelector<HTMLElement>("#yunomi-html-card");
        const rect = card?.getBoundingClientRect();
        return {
          cardCount: document.querySelectorAll("#yunomi-html-card").length,
          withinViewport: !!rect && rect.left >= 0 && rect.top >= 0 && rect.right <= innerWidth && rect.bottom <= innerHeight,
          horizontalOverflow: document.documentElement.scrollWidth > innerWidth,
        };
      });
      assert(htmlLayout.cardCount === 1 && htmlLayout.withinViewport && !htmlLayout.horizontalOverflow, "html preview comment UI stays within its iframe viewport", htmlLayout);
      await frame.locator("#yunomi-html-card [data-yunomi-cancel]").click();
    } else {
      await page.waitForSelector(fixture.target, { timeout: 10_000 });
      await page.locator(fixture.target).first().click();
      await page.waitForSelector(".yunomi-inline-comment-editor #comment-input", { state: "visible" });
      const layout = await shellLayout(page);
      assert(layout.editorCount === 1 && layout.inputIdCount === 1, `${fixture.mode} opens exactly one inline editor`, layout);
      assert(layout.editorWithinViewport === true && layout.targetEditorOverlap === 0 && layout.commentsSidebarOverlap === 0, `${fixture.mode} inline editor does not break layout`, layout);
      assert(Number(layout.scrollWidth) <= Number(layout.viewportWidth), `${fixture.mode} has no horizontal page overflow`, layout);
      await page.locator('.yunomi-inline-comment-editor [data-action="cancel"]').click();
    }
    await page.close();
  }
  assert(!server.output().includes("TypeError") && !server.output().includes("ReferenceError"), "all mode servers have no runtime errors", server.output());
} catch (error) {
  failed++;
  console.error(error instanceof Error ? error.stack || error.message : String(error));
} finally {
  if (browser) await browser.close();
  await stopServer(server.proc);
  rmSync(WORK_DIR, { recursive: true, force: true });
}

console.log(`Inline comment mode layout E2E: ${passed} passed, ${failed} failed`);
if (failed > 0) process.exit(1);
