/**
 * Conversation UX regression:
 *   1. Clicking the reply form of a thread mounted inside a Mermaid block
 *      must not open the diagram fullscreen (only the diagram itself does).
 *   2. Agent replies surface as unread cues: header counter for inline
 *      threads, red dot on the bottom-right chat, tab-title prefix, bell.
 *   3. Thumbnail numbering is gone (header total + per-thumb index).
 *   4. A file change patches the preview in place: no navigation, the caret
 *      and text in an open reply form survive, unchanged Mermaid SVG nodes
 *      are kept, and a new round does not navigate either.
 *
 * Run: node --experimental-strip-types e2e/conversation_ux.ts
 */
import assert from "node:assert/strict";
import http, { type IncomingMessage } from "node:http";
import { spawn, type ChildProcess } from "node:child_process";
import { mkdirSync, rmSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { chromium } from "playwright";

const SERVER_JS = new URL("../_build/js/release/build/server/server.js", import.meta.url).pathname;
const TMP_DIR = join(tmpdir(), `yunomi-conversation-ux-${Date.now()}`);
const LOCK_DIR = join(TMP_DIR, "locks");
const REVIEW_DIR = join(TMP_DIR, ".yunomi", "reviews", "no-branch");
const REPORT = join(TMP_DIR, "REPORT.md");
const PORT = 5491;

function fixture(rev: number, opts: { shift?: boolean } = {}): string {
  const filler = Array.from({ length: 60 }, (_, i) => `Filler paragraph ${i + 1} keeps the preview scrollable.`);
  return [
    "# Conversation UX",
    ...(opts.shift ? ["", "Inserted line at the top shifts everything below."] : []),
    "",
    "Intro paragraph is the first review target.",
    "",
    "```mermaid",
    "graph TD; A-->B;",
    "```",
    "",
    `Second paragraph revision ${rev}.`,
    "",
    "## Section",
    "",
    ...filler.flatMap((line) => [line, ""]),
  ].join("\n");
}

function request(port: number, method: string, path: string, body = ""): Promise<{ status: number; body: string }> {
  return new Promise((resolve, reject) => {
    const req = http.request(
      `http://127.0.0.1:${port}${path}`,
      { method, headers: { "Content-Type": "application/json" } },
      (res: IncomingMessage) => {
        let data = "";
        res.on("data", (chunk: string) => (data += chunk));
        res.on("end", () => resolve({ status: res.statusCode || 0, body: data }));
      },
    );
    req.on("error", reject);
    if (body.length > 0) req.write(body);
    req.end();
  });
}

function waitForServerOutput(proc: ChildProcess): Promise<number> {
  let output = "";
  return new Promise((resolve, reject) => {
    const onData = (chunk: Buffer) => {
      output += String(chunk);
      const match = output.match(/http:\/\/127\.0\.0\.1:(\d+)/);
      if (match) resolve(Number(match[1]));
    };
    proc.stdout?.on("data", onData);
    proc.stderr?.on("data", onData);
    proc.on("exit", (code) => reject(new Error(`server exited early code=${code}\n${output}`)));
    setTimeout(() => reject(new Error(`server startup timeout\n${output}`)), 10000);
  });
}

async function waitForHealth(port: number): Promise<void> {
  for (let i = 0; i < 80; i++) {
    try {
      if ((await request(port, "GET", "/healthz")).status === 200) return;
    } catch (_) {}
    await new Promise((r) => setTimeout(r, 100));
  }
  throw new Error("healthz timeout");
}

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

async function main(): Promise<void> {
  mkdirSync(REVIEW_DIR, { recursive: true });
  mkdirSync(LOCK_DIR, { recursive: true });
  writeFileSync(REPORT, fixture(1));
  const server = spawn(process.execPath, [SERVER_JS, "--no-open", "--loop", "--port", String(PORT), REPORT], {
    cwd: TMP_DIR,
    env: { ...process.env, HERDR_PANE_ID: "", YUNOMI_NOTIFY_CMD: "", YUNOMI_LOCK_DIR: LOCK_DIR, YUNOMI_REVIEW_DIR: REVIEW_DIR },
    stdio: ["ignore", "pipe", "pipe"],
  });
  const browser = await chromium.launch({ headless: true });
  try {
    const port = await waitForServerOutput(server);
    await waitForHealth(port);

    const html = await request(port, "GET", "/");
    assert.doesNotMatch(html.body, /media-toggle-count/, "header no longer renders a media total counter");
    assert.match(html.body, /id="conversation-unread"/, "header renders the unread-replies counter");

    const page = await browser.newPage({ viewport: { width: 1280, height: 900 } });
    let loads = 0;
    let navigations = 0;
    page.on("load", () => (loads += 1));
    page.on("framenavigated", (frame) => {
      if (frame === page.mainFrame()) navigations += 1;
    });
    await page.goto(`http://127.0.0.1:${port}/`, { waitUntil: "load" });
    await page.waitForSelector(".mermaid-container .mermaid svg", { timeout: 15000 });
    await page.waitForSelector("#review-loop-panel .review-loop-reply-form", { timeout: 10000 });

    // --- 3. numbering gone -------------------------------------------------
    await page.waitForSelector("#media-sidebar-thumbs .media-sidebar-thumb", { timeout: 10000 });
    assert.equal(await page.locator("#media-toggle-count").count(), 0, "no media total counter in the header");
    assert.equal(await page.locator(".media-sidebar-thumb-index").count(), 0, "thumbnails carry no index number");

    // --- seed durable comments (round 1 request_changes) --------------------
    const submit = await request(
      port,
      "POST",
      "/exit",
      JSON.stringify({
        summary: "Round 1 overall",
        decision: "request_changes",
        action: "final_request_changes",
        comments: [
          { row: 4, col: 1, text: "Diagram thread", value: "```mermaid" },
          { row: 2, col: 1, text: "Intro thread", value: "Intro paragraph is the first review target." },
        ],
      }),
    );
    assert.equal(submit.status, 200);
    // A final submit retires the review tab; the next round opens it again.
    await sleep(800);
    await page.goto(`http://127.0.0.1:${port}/`, { waitUntil: "load" });
    await page.waitForSelector(".mermaid-container .mermaid svg", { timeout: 15000 });
    await page.waitForSelector('.mermaid-container .review-loop-inline[data-review-comment-id="c-1-1"] textarea', { timeout: 10000 });
    await page.waitForSelector('.review-loop-inline[data-review-comment-id="c-1-2"] textarea', { timeout: 10000 });
    await page.waitForFunction(() => (window as any).__YUNOMI_UNREAD__ !== undefined, undefined, { timeout: 5000 });

    // --- 1. reply form inside a Mermaid block does not maximize ------------
    const diagramTextarea = page.locator('.mermaid-container .review-loop-inline[data-review-comment-id="c-1-1"] textarea');
    await diagramTextarea.click();
    await sleep(300);
    assert.equal(
      await page.locator("#mermaid-fullscreen.visible").count(),
      0,
      "clicking the thread form inside the diagram block does not open fullscreen",
    );
    assert.equal(
      await page.evaluate(() => document.activeElement?.closest?.('.review-loop-inline[data-review-comment-id="c-1-1"]') !== null),
      true,
      "the reply textarea keeps focus after the click",
    );
    await page.locator('.mermaid-container .review-loop-inline[data-review-comment-id="c-1-1"] button[type="submit"]').click({ trial: false }).catch(() => {});
    await sleep(200);
    assert.equal(await page.locator("#mermaid-fullscreen.visible").count(), 0, "clicking the thread's submit button does not open fullscreen either");
    await page.locator(".mermaid-container .mermaid svg").click({ position: { x: 20, y: 20 } });
    await page.waitForSelector("#mermaid-fullscreen.visible", { timeout: 5000 });
    await page.keyboard.press("Escape");
    await page.waitForFunction(() => !document.querySelector("#mermaid-fullscreen")?.classList.contains("visible"), undefined, { timeout: 5000 });

    // --- 2. unread cues for an inline agent reply --------------------------
    await page.evaluate(() => {
      const pane = document.querySelector<HTMLElement>(".md-left")!;
      pane.scrollTop = pane.scrollHeight;
    });
    await sleep(1500);
    const before = await page.evaluate(() => (window as any).__YUNOMI_UNREAD__);
    assert.equal(before.total, 0, "nothing is unread before the agent replies");
    const reply1 = await request(port, "POST", "/reply-comment", JSON.stringify({ id: "c-1-2", text: "Agent answer on the intro", author: "agent" }));
    assert.equal(reply1.status, 200);
    await page.waitForFunction(() => (window as any).__YUNOMI_UNREAD__?.inline === 1, undefined, { timeout: 5000 });
    assert.equal(await page.locator("#conversation-unread:not([hidden])").textContent(), "1", "header counter shows one unread inline reply");
    assert.match(await page.title(), /^\(1\) /, "tab title carries the unread count");
    assert.equal(await page.locator('.review-loop-inline[data-review-comment-id="c-1-2"] .review-loop-thread-line.is-agent.is-unread').count(), 1, "the new agent line is marked unread");
    assert.equal(typeof (await page.evaluate(() => (window as any).__YUNOMI_LAST_BELL_AT__)), "number", "a bell was requested for the new reply");
    // Two more replies: the counter must go 3 → 2 → 1 → 0, one per click,
    // and scrolling the thread into view must not consume anything.
    for (const text of ["Second agent answer", "Third agent answer"]) {
      assert.equal((await request(port, "POST", "/reply-comment", JSON.stringify({ id: "c-1-2", text, author: "agent" }))).status, 200);
    }
    await page.waitForFunction(() => (window as any).__YUNOMI_UNREAD__?.inline === 3, undefined, { timeout: 5000 });
    await page.evaluate(() => document.querySelector('.review-loop-inline[data-review-comment-id="c-1-2"]')!.scrollIntoView({ block: "center" }));
    await sleep(2000);
    assert.equal(await page.evaluate(() => (window as any).__YUNOMI_UNREAD__?.inline), 3, "scrolling a thread into view does not mark its replies read");
    for (const expected of [2, 1, 0]) {
      await page.locator("#conversation-unread").click();
      await page.waitForFunction((n) => (window as any).__YUNOMI_UNREAD__?.inline === n, expected, { timeout: 5000 });
    }
    assert.equal(await page.locator("#conversation-unread[hidden]").count(), 1, "counter hides once every reply has been consumed");
    assert.doesNotMatch(await page.title(), /^\(\d+\) /, "tab title prefix clears");

    // --- 2b. red dot on the collapsed global chat ---------------------------
    await page.locator("#review-loop-panel .review-loop-sidebar-toggle").click();
    await page.waitForSelector("#review-loop-panel.review-loop-sidebar-collapsed", { timeout: 5000 });
    const reply2 = await request(port, "POST", "/reply-comment", JSON.stringify({ id: "r-1", text: "Agent global reply", author: "agent" }));
    assert.equal(reply2.status, 200);
    await page.waitForFunction(() => (window as any).__YUNOMI_UNREAD__?.global === 1, undefined, { timeout: 5000 });
    assert.equal(await page.locator("#review-loop-panel .review-loop-unread-dot:not([hidden])").count(), 1, "collapsed chat shows the red dot");
    assert.equal(await page.locator("#conversation-unread:not([hidden])").textContent(), "1", "header counter also counts the chat reply");
    // Clicking the header counter while the next unread lives in the chat
    // opens the chat, flashes that message and reads it.
    await page.locator("#conversation-unread").click();
    await page.waitForFunction(() => !document.querySelector("#review-loop-panel")?.classList.contains("review-loop-sidebar-collapsed"), undefined, { timeout: 5000 });
    assert.equal(await page.locator("#review-loop-panel .review-loop-conversation-message.is-flash").count(), 1, "the chat message that was jumped to flashes");
    await page.waitForFunction(() => (window as any).__YUNOMI_UNREAD__?.global === 0, undefined, { timeout: 6000 });
    assert.equal(await page.locator("#review-loop-panel .review-loop-unread-dot[hidden]").count(), 1, "the dot clears once the chat reply is read");
    assert.equal(await page.locator("#conversation-unread[hidden]").count(), 1, "header counter clears too");
    // A reply while the chat is open is read on its own after a moment.
    await page.locator("#review-loop-panel .review-loop-sidebar-toggle").click();
    await page.waitForSelector("#review-loop-panel.review-loop-sidebar-collapsed", { timeout: 5000 });
    await page.locator("#review-loop-panel .review-loop-sidebar-toggle").click();
    await page.waitForFunction(() => !document.querySelector("#review-loop-panel")?.classList.contains("review-loop-sidebar-collapsed"), undefined, { timeout: 5000 });

    // --- 4. quiet in-place refresh -----------------------------------------
    await page.evaluate(() => {
      const pane = document.querySelector<HTMLElement>(".md-left")!;
      pane.scrollTop = 0;
      (document.querySelector(".mermaid-container .mermaid svg") as any).__keep = "yes";
    });
    const introTextarea = page.locator('.review-loop-inline[data-review-comment-id="c-1-2"] textarea');
    await introTextarea.click();
    await introTextarea.type("typing while the agent edits");
    await page.keyboard.press("ArrowLeft");
    await page.keyboard.press("ArrowLeft");
    const caretBefore = await page.evaluate(() => (document.activeElement as HTMLTextAreaElement).selectionStart);
    const loadsBefore = loads;
    const navBefore = navigations;
    writeFileSync(REPORT, fixture(2));
    await page.waitForFunction(() => (window as any).__YUNOMI_QUIET_REFRESH_COUNT__ === 1, undefined, { timeout: 20000 });
    await page.waitForFunction(() => document.querySelector("#md-preview")?.textContent?.includes("Second paragraph revision 2."), undefined, { timeout: 5000 });
    assert.equal(loads, loadsBefore, "a file change no longer reloads the page");
    assert.equal(navigations, navBefore, "a file change no longer navigates");
    assert.equal(await page.evaluate(() => (document.querySelector(".mermaid-container .mermaid svg") as any)?.__keep), "yes", "unchanged Mermaid SVG node is kept");
    const after = await page.evaluate(() => {
      const el = document.activeElement as HTMLTextAreaElement | null;
      return { inForm: !!el?.closest('.review-loop-inline[data-review-comment-id="c-1-2"]'), value: el?.value, caret: el?.selectionStart };
    });
    assert.equal(after.inForm, true, "focus stays in the reply form being typed in");
    assert.equal(after.value, "typing while the agent edits", "typed text survives the refresh");
    assert.equal(after.caret, caretBefore, "caret position survives the refresh");
    assert.equal(await page.locator('.mermaid-container .review-loop-inline[data-review-comment-id="c-1-1"]').count(), 1, "diagram thread stays mounted");
    assert.equal(await page.locator("#tbody tr").count() > 60, true, "source pane is refreshed too");
    assert.match(await page.locator("#tbody").textContent() || "", /Second paragraph revision 2\./, "source pane shows the new text");

    // Inserting a line near the top shifts every block below; kept blocks
    // must get the new line numbers so comment anchors keep working.
    writeFileSync(REPORT, fixture(3, { shift: true }));
    await page.waitForFunction(() => (window as any).__YUNOMI_QUIET_REFRESH_COUNT__ === 2, undefined, { timeout: 20000 });
    await page.waitForFunction(() => document.querySelector("#md-preview")?.textContent?.includes("Second paragraph revision 3."), undefined, { timeout: 5000 });
    assert.equal(loads, loadsBefore, "a shifting edit does not reload either");
    const mermaidLine = await page.locator(".mermaid-container .mermaid").getAttribute("data-source-line");
    assert.equal(mermaidLine, "7", "kept Mermaid block carries the shifted source line");
    await page.waitForFunction(() => document.querySelectorAll(".review-loop-inline").length === 2, undefined, { timeout: 5000 }).catch(() => {});
    assert.equal(await page.locator(".review-loop-inline").count(), 2, "both inline threads are still on the page after the shift");
    // The thread re-render after a refresh fetches /review-state; give it a moment.
    await page.waitForSelector('.mermaid-container .review-loop-inline[data-review-comment-id="c-1-1"]', { timeout: 5000 }).catch(() => {});
    if (await page.locator('.mermaid-container .review-loop-inline[data-review-comment-id="c-1-1"]').count() !== 1) {
      console.log("DEBUG c-1-1 placement:", await page.evaluate(() => Array.from(document.querySelectorAll(".review-loop-inline")).map((e) => ({ id: (e as HTMLElement).dataset.reviewCommentId, parent: e.parentElement?.className || e.parentElement?.tagName, prev: e.previousElementSibling?.className || e.previousElementSibling?.tagName }))));
      console.log("DEBUG state:", (await request(port, "GET", "/review-state")).body.slice(0, 1500));
    }
    assert.equal(await page.locator('.mermaid-container .review-loop-inline[data-review-comment-id="c-1-1"]').count(), 1, "diagram thread follows the shifted diagram");

    // A new round patches the page too instead of navigating.
    const go = await request(port, "POST", "/go");
    assert.equal(go.status, 200);
    await page.waitForFunction(() => /Round 2/.test((window as any).__YUNOMI_REVIEW_LOOP_STATUS__ || ""), undefined, { timeout: 10000 });
    await sleep(1500);
    assert.equal(navigations, navBefore, "a new round does not navigate the tab");

    await page.close();
    console.log("conversation_ux: all assertions passed");
  } finally {
    await browser.close().catch(() => {});
    server.kill("SIGTERM");
    rmSync(TMP_DIR, { recursive: true, force: true });
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
