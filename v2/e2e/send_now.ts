import { spawn, type ChildProcess } from "node:child_process";
import { existsSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { chromium, type Browser, type Page } from "playwright";

const SERVER_JS = new URL("../_build/js/release/build/server/server.js", import.meta.url).pathname;
const WORK_DIR = mkdtempSync(join(tmpdir(), "yunomi-send-now-"));
const LOCK_DIR = join(WORK_DIR, "locks");
const REVIEW_DIR = join(WORK_DIR, "reviews");
const BASE_PORT = 5865;

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
  try {
    await page.goto(`http://127.0.0.1:${port}`, { waitUntil: "domcontentloaded" });
    return await fn(page, browser);
  } finally {
    await browser.close();
  }
}

const sample = join(WORK_DIR, "send-now.txt");
writeFileSync(sample, ["first line", "second line", "third line"].join("\n"));

try {
  const server = await startYunomi([
    sample,
    "--no-open",
    "--port",
    String(BASE_PORT),
  ]);
  try {
    await withPage(server.port, async (page) => {
      await page.waitForSelector(".text-line[data-row='1']", { timeout: 10000 });
      await page.evaluate(() => {
        const seen: string[] = [];
        const es = new EventSource(`${location.origin}/sse`);
        es.addEventListener("send-now", (event) => seen.push(`send-now:${(event as MessageEvent).data}`));
        es.addEventListener("comment", (event) => seen.push(`comment:${(event as MessageEvent).data}`));
        es.addEventListener("reply", (event) => seen.push(`reply:${(event as MessageEvent).data}`));
        (window as unknown as { __sendNowSeen: string[]; __sendNowEs: EventSource }).__sendNowSeen = seen;
        (window as unknown as { __sendNowSeen: string[]; __sendNowEs: EventSource }).__sendNowEs = es;
      });

      await page.locator(".text-line[data-row='1']").click();
      await page.waitForSelector(".yunomi-inline-comment-editor", { state: "visible" });
      assert(await page.locator("#send-now-comment").textContent() === "Add single comment", "Immediate action uses GitHub's Add single comment label");
      assert(await page.locator("#save-comment").textContent() === "Start a review", "First pending action uses GitHub's Start a review label");
      await page.locator("#comment-input").fill("send-now review comment");
      await page.locator("#send-now-comment").click();

      await page.waitForFunction(() => {
        const seen = (window as unknown as { __sendNowSeen?: string[] }).__sendNowSeen || [];
        return seen.some((line) => line.startsWith("send-now:"));
      });
      const sendEvents = await page.evaluate(() => (window as unknown as { __sendNowSeen: string[] }).__sendNowSeen.filter((line) => line.startsWith("send-now:")));
      const storageScope = await page.evaluate(() => window.__YUNOMI_STORAGE_SCOPE__);
      const durableCommentId = `${storageScope}|1:0`;
      assert(sendEvents.length === 1 && sendEvents[0].includes(`\"key\":${JSON.stringify(durableCommentId)}`), "Add single comment emits a path-scoped SSE comment key", { sendEvents, durableCommentId });

      const reviewPath = join(REVIEW_DIR, "review.json");
      const review = existsSync(reviewPath) ? JSON.parse(readFileSync(reviewPath, "utf8")) : {};
      const stored = Array.isArray(review.comments) ? review.comments.find((comment: { id?: string }) => comment.id === durableCommentId) : null;
      assert(stored?.text === "send-now review comment" && stored?.send_now === true, "Add single comment writes a path-scoped durable ID to review.json");
      const sentDraft = await page.evaluate(() => localStorage.getItem(`yunomi:comments:${window.__YUNOMI_STORAGE_SCOPE__}`) || "");
      assert(sentDraft.includes('"pending":false') && sentDraft.includes('"sent":true'), "Immediate comments persist as sent, not pending", { sentDraft });

      // Sending a comment must not pop the drafts panel open from the top: it
      // interrupts the review and was never a request to read the draft list.
      assert(await page.locator(".comment-list:not(.collapsed)").count() === 0, "Add single comment leaves the drafts panel closed");
      // A sent comment is not a draft. It already lives in the document as an
      // inline thread, so counting it as unsubmitted work contradicts the pill.
      assert(await page.locator("#comment-count").textContent() === "0", "a sent comment is not counted as a draft");
      assert(await page.locator("#pill-comments").isVisible() === false, "the drafts pill stays hidden while nothing is unsubmitted");

      await page.locator(".text-line[data-row='2']").click();
      await page.locator("#comment-input").fill("pending review comment");
      await page.locator("#save-comment").click();
      await page.waitForTimeout(200);
      const pendingState = await page.evaluate(() => ({
        events: (window as unknown as { __sendNowSeen?: string[] }).__sendNowSeen || [],
        draft: localStorage.getItem(`yunomi:comments:${window.__YUNOMI_STORAGE_SCOPE__}`) || "",
        badges: Array.from(document.querySelectorAll(".yunomi-inline-comment-pending")).map((element) => element.textContent),
      }));
      assert(!pendingState.events.some((line) => line.startsWith("comment:") && line.includes("pending review comment")), "Start a review keeps the comment local until Submit review", pendingState);
      assert(pendingState.draft.includes('"pending":true') && pendingState.draft.includes('"sent":false') && pendingState.badges.includes("Pending"), "Pending state and badge persist locally", pendingState);
      // ...and an actually unsubmitted comment brings the pill back, counting
      // only itself rather than the comment that was already sent above.
      assert(await page.locator("#comment-count").textContent() === "1", "an unsubmitted comment counts as exactly one draft");
      assert(await page.locator("#pill-comments").isVisible() === true, "the drafts pill reappears once there is unsubmitted work");
      await page.locator(".text-line[data-row='0']").click();
      assert(await page.locator("#save-comment").textContent() === "Add review comment", "Later pending actions use GitHub's Add review comment label");
      await page.keyboard.press("Escape");

      const replyResponse = await fetch(`http://127.0.0.1:${server.port}/reply-comment`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ id: durableCommentId, text: "agent reply arrived", author: "agent" }),
      });
      assert(replyResponse.ok, "/reply-comment accepts the agent reply");

      await page.waitForFunction(() => {
        const seen = (window as unknown as { __sendNowSeen?: string[] }).__sendNowSeen || [];
        return seen.some((line) => line.startsWith("reply:"));
      });
      // A sent comment is not a draft, so it has no entry in the drafts list.
      // Once the durable conversation arrives, it becomes the only inline
      // surface for that comment instead of duplicating the local saved card.
      assert(await page.locator(`#comment-list li[data-key="${durableCommentId}"]`).count() === 0, "a sent comment keeps no entry in the drafts list");
      const durableInline = page.locator(`.review-loop-inline[data-review-comment-id="${durableCommentId}"]`);
      await durableInline.waitFor({ state: "visible", timeout: 5000 });
      assert(
        await durableInline.count() === 1
          && (await durableInline.textContent() || "").includes("agent reply arrived")
          && await page.locator(`.yunomi-inline-comment[data-comment-key="${durableCommentId}"]`).count() === 0,
        "the durable inline conversation replaces the local sent card without duplicating its content",
        { durableInline: await durableInline.allTextContents() },
      );

      await page.locator(".text-line[data-row='1']").click();
      assert(await page.locator(".yunomi-inline-comment-editor").count() === 0, "clicking the same unresolved location does not reopen a new comment editor");
      assert(
        await durableInline.locator("textarea:focus, button:focus, input:focus").count() === 1,
        "clicking the same unresolved location focuses its durable conversation",
      );

      const afterReply = JSON.parse(readFileSync(reviewPath, "utf8"));
      const replied = afterReply.comments.find((comment: { id?: string }) => comment.id === durableCommentId);
      assert(replied?.replies?.[0]?.text === "agent reply arrived", "Agent reply is persisted in review.json history");

      await page.evaluate(() => (window as unknown as { __sendNowEs?: EventSource }).__sendNowEs?.close());
      await page.reload({ waitUntil: "domcontentloaded" });
      const restore = page.locator("#recovery-restore");
      const restoreVisible = await restore.waitFor({ state: "visible", timeout: 3000 }).then(() => true).catch(() => false);
      if (restoreVisible) await restore.click();
      await page.waitForFunction((commentId) => {
        const durable = document.querySelector(`.review-loop-inline[data-review-comment-id="${CSS.escape(commentId)}"]`);
        const local = document.querySelector(`.yunomi-inline-comment[data-comment-key="${CSS.escape(commentId)}"]`);
        return Boolean(durable?.textContent?.includes("agent reply arrived")) && !local;
      }, durableCommentId, { timeout: 5000 });
      assert(
        await page.locator(`.review-loop-inline[data-review-comment-id="${durableCommentId}"]`).count() === 1
          && await page.locator(`.yunomi-inline-comment[data-comment-key="${durableCommentId}"]`).count() === 0,
        "reload restores exactly one durable inline conversation",
      );
    });
  } finally {
    await stop(server.proc);
  }
} catch (error) {
  failed++;
  console.error(error instanceof Error ? error.stack || error.message : String(error));
} finally {
  rmSync(WORK_DIR, { recursive: true, force: true });
}

console.log(`Send now E2E: ${passed} passed, ${failed} failed`);
if (failed > 0) process.exit(1);
