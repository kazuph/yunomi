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
    let timer: ReturnType<typeof setTimeout>;
    const settle = (fn: () => void) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      fn();
    };
    const check = () => {
      const match = output.match(/http:\/\/127\.0\.0\.1:(\d+)/);
      if (match) settle(() => resolve({ proc, output: () => output, port: Number(match[1]) }));
    };
    proc.stdout?.on("data", (chunk: Buffer) => { output += chunk.toString("utf8"); check(); });
    proc.stderr?.on("data", (chunk: Buffer) => { output += chunk.toString("utf8"); check(); });
    proc.on("exit", (code) => {
      settle(() => reject(new Error(`server exited early ${code}\n${output}`)));
    });
    if (stdin !== undefined) {
      proc.stdin?.end(stdin);
    }
    timer = setTimeout(() => {
      settle(() => reject(new Error(`server did not start\n${output}`)));
    }, 15000);
  });
}

async function stop(proc: ChildProcess): Promise<void> {
  await new Promise<void>((resolve) => {
    let timer: ReturnType<typeof setTimeout>;
    proc.once("exit", () => {
      clearTimeout(timer);
      resolve();
    });
    proc.kill("SIGINT");
    timer = setTimeout(() => {
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

const tallDiffFile = join(WORK_DIR, "tall.diff");
writeFileSync(tallDiffFile, [
  "diff --git a/tall.txt b/tall.txt",
  "index 1111111..2222222 100644",
  "--- a/tall.txt",
  "+++ b/tall.txt",
  "@@ -1,1 +1,1 @@",
  ...Array.from({ length: 450 }, (_, index) => `+line ${index + 1}`),
].join("\n"));

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
      assert(await page.locator(".diff-viewed-state").first().textContent() === "Unreviewed", "viewed control explains the initial unreviewed state");
      await firstBox.check();
      const viewedState = await page.evaluate(() => localStorage.getItem("yunomi:diff-viewed:changes.diff") || "");
      const viewedBlock = await page.locator(".diff-file-block").first().evaluate((el) => el.classList.contains("viewed"));
      assert(viewedState.includes("alpha.txt") && viewedBlock, "viewed checkbox persists and marks the file block", { viewedState, viewedBlock });
      assert(await page.locator(".diff-viewed-state").first().textContent() === "Reviewed", "viewed control shows the reviewed state after checking");
      await page.waitForFunction(async () => {
        const state = await fetch("/review-state").then((response) => response.json());
        return state?.review?.viewed_files?.["alpha.txt"] === true;
      });
      const reviewState = await page.evaluate(() => fetch("/review-state").then((response) => response.json()));
      assert(reviewState?.review?.viewed_files?.["alpha.txt"] === true, "viewed checkbox persists to review.json for later rounds", reviewState?.review?.viewed_files);

      await page.locator('.diff-line.addition[data-file="alpha.txt"]').first().click();
      await page.locator("#comment-input").fill("inline diff comment stays here");
      const beforeSave = await page.evaluate(() => ({
        filename: window.__YUNOMI_FILENAME__,
        inputCount: document.querySelectorAll("#comment-input").length,
        editorDisplay: getComputedStyle(document.querySelector(".yunomi-inline-comment-editor")!).display,
        inputValue: (document.querySelector("#comment-input") as HTMLTextAreaElement | null)?.value || "",
        allStorage: Object.fromEntries(Object.keys(localStorage).map(key => [key, localStorage.getItem(key)])),
        storedComments: localStorage.getItem(`yunomi:comments:${window.__YUNOMI_FILENAME__}`),
      }));
      assert(
        beforeSave.inputValue === "inline diff comment stays here" && Boolean(beforeSave.storedComments?.includes("inline diff comment stays here")),
        "diff comment input and draft stay populated before Save",
        beforeSave,
      );
      await page.locator("#save-comment").click();
      await page.waitForTimeout(150);
      const inlineState = await page.evaluate(() => ({
        inlineCount: document.querySelectorAll(".yunomi-inline-comment:not(.yunomi-inline-comment-editor)").length,
        storedComments: localStorage.getItem("yunomi-comments:changes.diff"),
        commentList: document.querySelector("#comment-list")?.textContent || "",
        activeClassCount: document.querySelectorAll(".diff-line.has-comment").length,
      }));
      assert(inlineState.inlineCount > 0, "saved diff comment creates an inline card", inlineState);
      const inline = page.locator(".yunomi-inline-comment:not(.yunomi-inline-comment-editor)").first();
      const inlineComment = await inline.textContent();
      const inlineBox = await inline.boundingBox();
      const blockBox = await page.locator('.diff-file-block[data-file="alpha.txt"]').boundingBox();
      const nestedInSplitColumn = await inline.evaluate((el) => Boolean(el.closest(".old-content,.new-content,.split-content")));
      const inlineLabel = await inline.locator(".yunomi-inline-comment-label").textContent();
      assert(
        inlineComment?.includes("inline diff comment stays here") === true && inlineBox && inlineBox.width > 0 && inlineBox.height > 0,
        "saved diff comment is visibly inline below the commented line",
        { inlineComment, inlineBox },
      );
      assert(
        Boolean(blockBox && inlineBox && inlineBox.width > blockBox.width * 0.6 && !nestedInSplitColumn),
        "split diff inline comment spans the row instead of one split column",
        { inlineBox, blockBox, nestedInSplitColumn },
      );
      assert(inlineLabel?.startsWith("Line") === true, "inline saved comments show their source location", { inlineLabel });

      await page.locator(".diff-file-link").nth(1).click();
      const betaVisible = await page.locator('.diff-file-block[data-file="beta.txt"]').isVisible();
      assert(betaVisible, "file tree link targets the matching diff block");
    });
  } finally {
    await stop(fileServer.proc);
  }

  const tallServer = await startYunomi([
    tallDiffFile,
    "--no-open",
    "--port",
    String(BASE_PORT + 2),
  ]);
  try {
    await withPage(tallServer.port, async (page) => {
      await page.waitForSelector(".diff-review-shell", { timeout: 10000 });
      const beforeScroll = await page.evaluate(() => {
        const shell = document.querySelector<HTMLElement>(".diff-review-shell");
        return shell ? { scrollHeight: shell.scrollHeight, clientHeight: shell.clientHeight, scrollTop: shell.scrollTop } : null;
      });
      assert(Boolean(beforeScroll && beforeScroll.scrollHeight > beforeScroll.clientHeight), "tall diff has a dedicated vertical scroll container", beforeScroll);
      await page.locator(".diff-review-shell").hover();
      await page.mouse.wheel(0, 1200);
      await page.waitForFunction(() => (document.querySelector<HTMLElement>(".diff-review-shell")?.scrollTop || 0) > 0);
      const afterScroll = await page.evaluate(() => {
        const shell = document.querySelector<HTMLElement>(".diff-review-shell");
        const tree = document.querySelector<HTMLElement>(".diff-file-tree");
        const toolbar = document.querySelector<HTMLElement>(".diff-toolbar");
        if (!shell || !tree || !toolbar) return null;
        return {
          scrollTop: shell.scrollTop,
          shellTop: shell.getBoundingClientRect().top,
          treeTop: tree.getBoundingClientRect().top,
          toolbarTop: toolbar.getBoundingClientRect().top,
        };
      });
      assert(Boolean(afterScroll && afterScroll.scrollTop > 0), "wheel scroll moves the diff scroll container", afterScroll);
      assert(
        Boolean(afterScroll && afterScroll.treeTop === afterScroll.shellTop && afterScroll.toolbarTop === afterScroll.shellTop),
        "file tree and toolbar stay sticky within the diff scroll container",
        afterScroll,
      );
    });
  } finally {
    await stop(tallServer.proc);
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
