import { spawn, type ChildProcess } from "node:child_process";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { chromium, type Browser, type Page } from "playwright";

const SERVER_JS = new URL("../_build/js/release/build/server/server.js", import.meta.url).pathname;
const WORK_DIR = mkdtempSync(join(tmpdir(), "yunomi-code-diff-"));
const LOCK_DIR = join(WORK_DIR, "locks");
const REVIEW_DIR = join(WORK_DIR, "reviews");
const BASE_PORT = 5863;

let passed = 0;
let failed = 0;

function assert(condition: boolean, message: string, detail?: unknown): void {
  if (condition) {
    passed++;
    console.log(`PASS: ${message}`);
  } else {
    failed++;
    console.error(`FAIL: ${message}`);
    if (detail !== undefined) console.error(JSON.stringify(detail, null, 2));
  }
}

function startYunomi(args: string[], stdin?: string): Promise<{ proc: ChildProcess; output: () => string; port: number }> {
  return new Promise((resolve, reject) => {
    const proc = spawn(process.execPath, [SERVER_JS, ...args], {
      stdio: [stdin === undefined ? "ignore" : "pipe", "pipe", "pipe"],
      env: {
        ...process.env,
        HERDR_PANE_ID: "",
        YUNOMI_NOTIFY_CMD: "",
        YUNOMI_LOCK_DIR: LOCK_DIR,
        YUNOMI_REVIEW_DIR: REVIEW_DIR,
      },
    });
    let output = "";
    let settled = false;
    const check = () => {
      const match = output.match(/http:\/\/127\.0\.0\.1:(\d+)/);
      if (!settled && match) {
        settled = true;
        resolve({ proc, output: () => output, port: Number(match[1]) });
      }
    };
    proc.stdout?.on("data", (chunk: Buffer) => { output += chunk.toString("utf8"); check(); });
    proc.stderr?.on("data", (chunk: Buffer) => { output += chunk.toString("utf8"); check(); });
    proc.on("exit", (code) => {
      if (!settled) reject(new Error(`server exited early ${code}\n${output}`));
    });
    if (stdin !== undefined) {
      proc.stdin?.end(stdin);
    }
    setTimeout(() => {
      if (!settled) reject(new Error(`server did not start\n${output}`));
    }, 15000);
  });
}

async function stop(proc: ChildProcess): Promise<void> {
  await new Promise<void>((resolve) => {
    proc.once("exit", () => resolve());
    proc.kill("SIGINT");
    setTimeout(() => {
      proc.kill("SIGKILL");
      resolve();
    }, 3000);
  });
}

async function withPage<T>(port: number, fn: (page: Page, browser: Browser) => Promise<T>): Promise<T> {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage({ viewport: { width: 1100, height: 800 } });
  try {
    await page.goto(`http://127.0.0.1:${port}`, { waitUntil: "domcontentloaded" });
    return await fn(page, browser);
  } finally {
    await browser.close();
  }
}

const diff = [
  "diff --git a/alpha.txt b/alpha.txt",
  "index 1111111..2222222 100644",
  "--- a/alpha.txt",
  "+++ b/alpha.txt",
  "@@ -1,2 +1,2 @@",
  " one",
  "-old alpha",
  "+new alpha",
  "diff --git a/beta.txt b/beta.txt",
  "new file mode 100644",
  "index 0000000..3333333",
  "--- /dev/null",
  "+++ b/beta.txt",
  "@@ -0,0 +1 @@",
  "+new beta",
].join("\n");

const diffFile = join(WORK_DIR, "changes.diff");
writeFileSync(diffFile, diff);

try {
  const fileServer = await startYunomi([
    diffFile,
    "--no-open",
    "--port",
    String(BASE_PORT),
  ]);
  try {
    await withPage(fileServer.port, async (page) => {
      await page.waitForSelector(".diff-review-shell", { timeout: 10000 });
      const treeItems = await page.locator(".diff-file-tree-item").count();
      assert(treeItems === 2, "diff file tree lists each changed file", { treeItems });
      assert(await page.locator("#diff-unified-toggle").isVisible(), "Unified toggle is visible");
      assert(await page.locator("#diff-split-toggle").isVisible(), "Split toggle is visible");
      assert(await page.locator(".old-content").count() > 0 && await page.locator(".new-content").count() > 0, "split panes have old/new content nodes");

      await page.locator("#diff-split-toggle").click();
      const splitClass = await page.evaluate(() => document.body.classList.contains("diff-split"));
      const storedMode = await page.evaluate(() => localStorage.getItem("yunomi:diff-view:changes.diff"));
      assert(splitClass && storedMode === "split", "Split toggle applies and persists to localStorage", { splitClass, storedMode });

      await page.reload({ waitUntil: "domcontentloaded" });
      const splitAfterReload = await page.evaluate(() => document.body.classList.contains("diff-split"));
      assert(splitAfterReload, "Split view is restored after reload");

      const firstBox = page.locator(".diff-viewed-checkbox").first();
      await firstBox.check();
      const viewedState = await page.evaluate(() => localStorage.getItem("yunomi:diff-viewed:changes.diff") || "");
      const viewedBlock = await page.locator(".diff-file-block").first().evaluate((el) => el.classList.contains("viewed"));
      assert(viewedState.includes("alpha.txt") && viewedBlock, "viewed checkbox persists and marks the file block", { viewedState, viewedBlock });

      await page.locator(".diff-file-link").nth(1).click();
      const betaVisible = await page.locator('.diff-file-block[data-file="beta.txt"]').isVisible();
      assert(betaVisible, "file tree link targets the matching diff block");
    });
  } finally {
    await stop(fileServer.proc);
  }

  const stdinServer = await startYunomi([
    "--no-open",
    "--port",
    String(BASE_PORT + 1),
  ], diff);
  try {
    await withPage(stdinServer.port, async (page) => {
      await page.waitForSelector(".diff-review-shell", { timeout: 10000 });
      assert(await page.locator(".diff-file-tree-item").count() === 2, "piped git diff also renders the file tree");
      assert(await page.locator("#diff-split-toggle").isVisible(), "piped git diff keeps the split/unified toolbar");
    });
  } finally {
    await stop(stdinServer.proc);
  }

  console.log(`Code diff enhance E2E: ${passed} passed, ${failed} failed`);
  if (failed > 0) process.exit(1);
} finally {
  rmSync(WORK_DIR, { recursive: true, force: true });
}
