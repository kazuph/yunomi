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
        es.addEventListener("reply", (event) => seen.push(`reply:${(event as MessageEvent).data}`));
        (window as unknown as { __sendNowSeen: string[]; __sendNowEs: EventSource }).__sendNowSeen = seen;
        (window as unknown as { __sendNowSeen: string[]; __sendNowEs: EventSource }).__sendNowEs = es;
      });

      await page.locator(".text-line[data-row='1']").click();
      await page.waitForSelector("#comment-card", { state: "visible" });
      assert(await page.locator("#send-now-comment").isVisible(), "Send now button is visible next to Save");
      await page.locator("#comment-input").fill("send-now review comment");
      await page.locator("#send-now-comment").click();

      await page.waitForFunction(() => {
        const seen = (window as unknown as { __sendNowSeen?: string[] }).__sendNowSeen || [];
        return seen.some((line) => line.startsWith("send-now:"));
      });
      const sendEvents = await page.evaluate(() => (window as unknown as { __sendNowSeen: string[] }).__sendNowSeen.filter((line) => line.startsWith("send-now:")));
      assert(sendEvents.length === 1 && sendEvents[0].includes("\"key\":\"1:0\""), "Send now emits a dedicated SSE event with the comment key", { sendEvents });

      const reviewPath = join(REVIEW_DIR, "review.json");
      const review = existsSync(reviewPath) ? JSON.parse(readFileSync(reviewPath, "utf8")) : {};
      const stored = Array.isArray(review.comments) ? review.comments.find((comment: { id?: string }) => comment.id === "1:0") : null;
      assert(stored?.text === "send-now review comment" && stored?.send_now === true, "Send now writes the pending comment to review.json");

      const replyResponse = await fetch(`http://127.0.0.1:${server.port}/reply-comment`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ id: "1:0", text: "agent reply arrived", author: "agent" }),
      });
      assert(replyResponse.ok, "/reply-comment accepts the agent reply");

      await page.waitForFunction(() => {
        const seen = (window as unknown as { __sendNowSeen?: string[] }).__sendNowSeen || [];
        return seen.some((line) => line.startsWith("reply:"));
      });
      const inlineReply = await page.locator(".comment-inline-replies").textContent({ timeout: 5000 });
      assert((inlineReply || "").includes("agent reply arrived"), "Agent reply renders inline under the matching comment list entry", { inlineReply });

      const afterReply = JSON.parse(readFileSync(reviewPath, "utf8"));
      const replied = afterReply.comments.find((comment: { id?: string }) => comment.id === "1:0");
      assert(replied?.replies?.[0]?.text === "agent reply arrived", "Agent reply is persisted in review.json history");

      await page.evaluate(() => (window as unknown as { __sendNowEs?: EventSource }).__sendNowEs?.close());
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
