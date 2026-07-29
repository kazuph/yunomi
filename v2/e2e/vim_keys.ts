import { spawn, type ChildProcess } from "node:child_process";
import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { chromium, type Browser, type Page } from "playwright";

const SERVER_JS = new URL("../_build/js/release/build/server/server.js", import.meta.url).pathname;
const WORK_DIR = mkdtempSync(join(tmpdir(), "yunomi-vim-"));
const LOCK_DIR = join(WORK_DIR, "locks");
const REVIEW_DIR = join(WORK_DIR, "reviews");
const SAMPLE = join(WORK_DIR, "vim.txt");
const BASE_PORT = 5868;

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

function startYunomi(args: string[]): Promise<{ proc: ChildProcess; output: () => string; port: number }> {
  return new Promise((resolve, reject) => {
    const proc = spawn(process.execPath, [SERVER_JS, ...args], {
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
  const page = await browser.newPage({ viewport: { width: 1000, height: 760 } });
  const diagnostics: string[] = [];
  page.on("console", (message) => diagnostics.push(`console:${message.type()}:${message.text()}`));
  page.on("pageerror", (error) => diagnostics.push(`pageerror:${error.message}`));
  try {
    await page.goto(`http://127.0.0.1:${port}`, { waitUntil: "domcontentloaded" });
    return await fn(page, browser);
  } catch (error) {
    const body = await page.locator("body").textContent().catch(() => "");
    throw new Error(`${error instanceof Error ? error.message : String(error)}\nDiagnostics:\n${diagnostics.join("\n")}\nBody:\n${(body || "").slice(0, 500)}`);
  } finally {
    await browser.close();
  }
}

writeFileSync(SAMPLE, ["first vim line", "second vim line", "third vim line"].join("\n"));
mkdirSync(REVIEW_DIR, { recursive: true });
writeFileSync(join(REVIEW_DIR, "review.json"), JSON.stringify({
  version: 1,
  branch: "vim-test",
  files: ["vim.txt"],
  rounds: [{ round: 1, started_at: new Date().toISOString(), submitted_at: null, decision: null, summary: "" }],
  comments: [{
    id: "loop-1",
    file: "vim.txt",
    line: 2,
    round: 1,
    text: "resolve by keyboard",
    author: "human",
    status: "unresolved",
    replies: [],
    anchor: { snippet: "second vim line", context_before: "first vim line", context_after: "third vim line" },
  }],
}, null, 2));

try {
  const server = await startYunomi([SAMPLE, "--no-open", "--port", String(BASE_PORT)]);
  try {
    await withPage(server.port, async (page) => {
      await page.waitForSelector(".text-line[data-row='0']", { timeout: 10000 });
      await page.waitForFunction(() => (window as unknown as { __YUNOMI_VIM_KEYS_READY__?: boolean }).__YUNOMI_VIM_KEYS_READY__ === true, undefined, { timeout: 5000 });
      await page.keyboard.press("j");
      await page.waitForSelector(".text-line[data-row='0'].vim-key-selected", { timeout: 5000 }).catch(async (error) => {
        const state = await page.evaluate(() => ({
          ready: (window as unknown as { __YUNOMI_VIM_KEYS_READY__?: boolean }).__YUNOMI_VIM_KEYS_READY__,
          lastKey: (window as unknown as { __YUNOMI_VIM_LAST_KEY__?: string }).__YUNOMI_VIM_LAST_KEY__,
          handled: (window as unknown as { __YUNOMI_VIM_HANDLED__?: string }).__YUNOMI_VIM_HANDLED__,
          targetCount: (window as unknown as { __YUNOMI_VIM_TARGET_COUNT__?: number }).__YUNOMI_VIM_TARGET_COUNT__,
          selectedCount: document.querySelectorAll(".vim-key-selected").length,
        }));
        throw new Error(`${error instanceof Error ? error.message : String(error)}\nVim state: ${JSON.stringify(state)}`);
      });
      assert(true, "j selects the first review target");
      const selectedStyle = await page.locator(".text-line[data-row='0'].vim-key-selected").evaluate((element) => {
        const style = getComputedStyle(element);
        return { outlineStyle: style.outlineStyle, outlineWidth: style.outlineWidth, backgroundColor: style.backgroundColor };
      });
      assert(
        selectedStyle.outlineStyle === "none" && selectedStyle.outlineWidth === "0px",
        "keyboard selection uses no outline",
      );
      await page.waitForFunction(() => {
        const element = document.querySelector(".text-line[data-row='0'].vim-key-selected");
        if (!element) return false;
        const backgroundColor = getComputedStyle(element).backgroundColor;
        return backgroundColor !== "rgba(0, 0, 0, 0)" && backgroundColor !== "transparent";
      });
      const selectedBackground = await page.locator(".text-line[data-row='0'].vim-key-selected").evaluate((element) => (
        getComputedStyle(element).backgroundColor
      ));
      assert(
        selectedBackground !== "rgba(0, 0, 0, 0)" && selectedBackground !== "transparent",
        "keyboard selection remains visible through its background color",
        selectedBackground,
      );

      await page.keyboard.press("j");
      await page.waitForSelector(".text-line[data-row='1'].vim-key-selected");
      assert(true, "j moves to the next review target");

      await page.keyboard.press("k");
      await page.waitForSelector(".text-line[data-row='0'].vim-key-selected");
      assert(true, "k moves to the previous review target");

      await page.keyboard.press("c");
      await page.waitForSelector(".yunomi-inline-comment-editor", { state: "visible" });
      assert(await page.evaluate(() => document.activeElement?.id === "comment-input"), "c opens the inline editor for the selected target");

      await page.locator("#comment-input").fill("");
      await page.keyboard.type("?");
      assert(await page.locator("#comment-input").inputValue() === "?", "? is inserted into the comment input");
      assert(await page.locator(".vim-key-help:not(.hidden)").count() === 0, "? does not open keyboard help while typing");
      await page.locator("#comment-input").fill("keyboard comment");
      await page.keyboard.press(process.platform === "darwin" ? "Meta+Enter" : "Control+Enter");
      await page.waitForSelector(".yunomi-inline-comment-editor", { state: "detached" });
      assert(await page.locator("#comment-list li[data-key='0:0']").count() === 1, "Cmd/Ctrl+Enter saves an open keyboard comment");

      await page.keyboard.press("Escape");
      await page.waitForSelector(".yunomi-inline-comment-editor", { state: "detached" });
      await page.locator("#send-and-exit").focus();
      await page.keyboard.press("n");
      await page.waitForSelector(".yunomi-inline-comment-editor", { state: "visible" });
      const jumpedText = await page.locator("#comment-input").inputValue();
      const jumpedTitle = await page.locator(".yunomi-inline-comment-label").first().textContent().catch(() => "");
      const commentPanelText = await page.locator(".comment-list").textContent().catch(() => "");
      assert(jumpedText === "keyboard comment", "n jumps to the next saved comment", { jumpedText, jumpedTitle, commentPanelText });
      await page.keyboard.press("Escape");

      await page.locator("#send-and-exit").focus();
      await page.keyboard.press("?");
      await page.waitForSelector(".vim-key-help:not(.hidden)");
      assert(true, "? opens keyboard help outside text inputs");
      await page.locator("#send-and-exit").focus();
      await page.evaluate(() => document.dispatchEvent(new KeyboardEvent("keydown", { key: "？", bubbles: true, cancelable: true })));
      await page.waitForSelector(".vim-key-help:not(.hidden)");
      assert(true, "？ opens keyboard help outside text inputs");
      await page.mouse.click(5, 5);

      await page.waitForSelector(".review-loop-inline .review-loop-resolve", { timeout: 10000 });
      await page.keyboard.press("r");
      await page.waitForFunction(() => {
        const counts = document.querySelector(".review-loop-meta")?.textContent?.trim() || "";
        const status = (window as unknown as { __YUNOMI_REVIEW_LOOP_STATUS__?: string }).__YUNOMI_REVIEW_LOOP_STATUS__ || "";
        return !document.querySelector(".review-loop-inline .review-loop-resolve")
          && !document.querySelector("#review-loop-panel [data-review-comment-id='loop-1']")
          && counts.startsWith("0 open")
          && status.includes("All resolved");
      });
      const review = JSON.parse(readFileSync(join(REVIEW_DIR, "review.json"), "utf8"));
      assert(review.comments[0]?.status === "resolved", "r resolves the focused review-loop comment");

      await page.evaluate(() => (document.activeElement as HTMLElement | null)?.blur());
      await page.keyboard.press(process.platform === "darwin" ? "Meta+Enter" : "Control+Enter");
      assert(
        await page.locator("#submit-modal.visible").count() === 0,
        "Cmd/Ctrl+Enter outside a comment editor never opens Submit",
      );

      await page.keyboard.press("?");
      await page.waitForSelector(".vim-key-help:not(.hidden)");
      assert((await page.locator(".vim-key-help").textContent() || "").includes("Keyboard review"), "? opens keyboard help");
      await page.locator("[data-vim-toggle]").click();
      assert(await page.evaluate(() => localStorage.getItem("yunomi:vim-keys:vim.txt") === "off"), "keyboard help toggles Vim keys off in localStorage");
      await page.mouse.click(5, 5);
      await page.keyboard.press("j");
      assert(await page.locator(".text-line[data-row='1'].vim-key-selected").count() === 0, "localStorage off disables j/k navigation");
    });
  } finally {
    await stop(server.proc);
  }

  const disabled = await startYunomi([SAMPLE, "--no-open", "--no-vim", "--port", String(BASE_PORT + 1)]);
  try {
    await withPage(disabled.port, async (page) => {
      await page.waitForSelector(".text-line[data-row='0']", { timeout: 10000 });
      await page.keyboard.press("j");
      assert(await page.locator(".vim-key-selected").count() === 0, "--no-vim disables Vim keybindings at render time");
    });
  } finally {
    await stop(disabled.proc);
  }
} catch (error) {
  failed++;
  console.error(error instanceof Error ? error.stack || error.message : String(error));
} finally {
  rmSync(WORK_DIR, { recursive: true, force: true });
}

console.log(`Vim keys E2E: ${passed} passed, ${failed} failed`);
if (failed > 0) process.exit(1);
