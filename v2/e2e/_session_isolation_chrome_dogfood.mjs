import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { mkdirSync, mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { chromium } from "playwright";

const REPO = "/Users/kazuph/src/github.com/kazuph/yunomi";
const SERVER_JS = join(REPO, "v2/_build/js/release/build/server/server.js");
const TARGET = join(REPO, "formal/review-mux/REPORT.md");
const EVIDENCE_DIR = join(REPO, "formal/review-mux");
const EMPTY_PNG = join(EVIDENCE_DIR, "session-isolation-empty-chat.png");
const TIMELINE_PNG = join(EVIDENCE_DIR, "session-isolation-timeline.png");
const APPROVE_PNG = join(EVIDENCE_DIR, "session-isolation-approve-gate.png");
const FULL_PNG = join(EVIDENCE_DIR, "session-isolation-full-ui.png");
const FOREIGN = [
  "quote-ui-checkbox",
  "YUNOMI_REPLY_REVIEW",
  "complex-markdown-showcase",
  "r-27",
];

async function request(port, path, body) {
  const res = await fetch(`http://127.0.0.1:${port}${path}`, {
    method: body ? "POST" : "GET",
    headers: body ? { "content-type": "application/json" } : undefined,
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  let json = null;
  try {
    json = JSON.parse(text);
  } catch {
    json = null;
  }
  return { status: res.status, text, json };
}

const lockDir = mkdtempSync(join(tmpdir(), "yunomi-session-iso-locks-"));
const reviewDir = mkdtempSync(join(tmpdir(), "yunomi-session-iso-reviews-"));
const profileDir = mkdtempSync(join(tmpdir(), "yunomi-session-iso-chrome-"));
mkdirSync(lockDir, { recursive: true });
mkdirSync(reviewDir, { recursive: true });

const env = { ...process.env, HERDR_PANE_ID: "", YUNOMI_NOTIFY_CMD: "true", YUNOMI_LOCK_DIR: lockDir, YUNOMI_REVIEW_DIR: reviewDir };

const proc = spawn(process.execPath, [SERVER_JS, TARGET, "--no-open", "--port", "0", "--loop"], {
  cwd: REPO,
  env,
  stdio: ["ignore", "pipe", "pipe"],
});

let port = 0;
let output = "";
await new Promise((resolve, reject) => {
  const timer = setTimeout(() => reject(new Error(`server start timeout\n${output}`)), 20000);
  const observe = (chunk) => {
    output += chunk.toString();
    const match = output.match(/http:\/\/127\.0\.0\.1:(\d+)/);
    if (match) {
      port = Number(match[1]);
      clearTimeout(timer);
      resolve();
    }
  };
  proc.stdout.on("data", observe);
  proc.stderr.on("data", observe);
  proc.on("exit", (code) => reject(new Error(`server exited early ${code}: ${output}`)));
});

const receipt = { port, target: "formal/review-mux/REPORT.md", lockDir, screenshots: { empty: EMPTY_PNG, timeline: TIMELINE_PNG, approve: APPROVE_PNG, full: FULL_PNG } };

try {
  const healthz = await request(port, "/healthz");
  assert.equal(healthz.status, 200, "healthz must be 200");
  receipt.healthz = healthz.status;

  const state = (await request(port, "/review-state")).json;
  const comments = state.review?.comments || [];
  receipt.files = state.review?.files || [];
  receipt.comment_count = comments.length;
  receipt.comment_ids = comments.map((c) => ({ id: c.id, file: c.file, scope: c.scope, text: String(c.text || "").slice(0, 80) }));
  receipt.gate_unresolved_count = state.gate_unresolved_count;
  const commentBlob = JSON.stringify(comments);
  receipt.foreign_hits = FOREIGN.filter((marker) => commentBlob.includes(marker));
  assert.deepEqual(receipt.files, ["formal/review-mux/REPORT.md"], "new session serves only this report");
  assert.equal(receipt.comment_count, 0, "new session must not show past conversations");
  assert.deepEqual(receipt.foreign_hits, [], "legacy mixed-branch conversations must not appear in API comments");
  assert.equal(state.gate_unresolved_count, 0, "empty new session has no approve-gate blockers");

  const context = await chromium.launchPersistentContext(profileDir, {
    channel: "chrome",
    headless: false,
    viewport: { width: 1440, height: 900 },
    args: ["--no-first-run", "--no-default-browser-check"],
  });
  const pageErrors = [];
  const page = context.pages()[0] || await context.newPage();
  page.on("pageerror", (error) => pageErrors.push(error.message));
  await page.addInitScript("globalThis.__name=globalThis.__name||((f)=>f);");
  await page.goto(`http://127.0.0.1:${port}/`, { waitUntil: "domcontentloaded" });
  await page.waitForSelector(".review-loop-header, .review-loop-conversation, #send-and-exit", { timeout: 15000 });
  const overlay = page.locator("#recovery-modal.visible");
  if (await overlay.count() && await overlay.isVisible()) {
    await page.locator("#recovery-discard").click();
    await page.waitForSelector("#recovery-modal.visible", { state: "hidden", timeout: 5000 }).catch(() => {});
  }
  await page.waitForSelector("#review-loop-panel.review-loop-sidebar .review-loop-header", { timeout: 15000 });
  const chat = await page.locator("#review-loop-panel").innerText();
  receipt.ui_has_chat = chat.includes("Chat") || (await page.locator("#review-loop-panel .review-loop-conversation").count()) > 0;
  receipt.ui_has_new_conversation = chat.includes("New conversation");
  receipt.ui_has_past_conversations = chat.includes("Past conversations");
  receipt.ui_has_resolve_conversation = /\bResolve conversation\b/.test(chat);
  receipt.ui_foreign_hits = FOREIGN.filter((marker) => chat.includes(marker));
  receipt.ui_has_past_marker_text = /\br-27\b/.test(chat) || chat.includes("quote-ui-checkbox");
  assert.equal(receipt.ui_has_past_marker_text, false, "chat must not show the mixed-branch r-27 / quote-ui conversation");
  assert.deepEqual(receipt.ui_foreign_hits, [], "chat must not contain foreign review identities");
  assert.equal(receipt.ui_has_chat, true, "empty session still renders the review chat chrome");
  assert.equal(receipt.ui_has_new_conversation, false, "empty session does not show New conversation");
  assert.equal(receipt.ui_has_past_conversations, false, "empty session does not show Past conversations");
  assert.equal(receipt.ui_has_resolve_conversation, false, "empty session does not show Resolve conversation");

  await page.locator("#review-loop-panel").screenshot({ path: EMPTY_PNG });
  const created = await request(port, "/create-global-comment", { text: "Oldest timeline message" });
  assert.equal(created.status, 200, "timeline seed create must succeed");
  const threadId = created.json?.id;
  assert.ok(threadId, "create-global-comment returns a thread id");
  const replied = await request(port, "/reply-comment", { id: threadId, text: "Latest timeline message", author: "human" });
  assert.equal(replied.status, 200, "timeline seed reply must succeed");
  await page.waitForFunction(() => document.querySelector("#review-loop-panel")?.textContent?.includes("Latest timeline message"), undefined, { timeout: 5000 });
  receipt.timeline_message_count = await page.locator("#review-loop-panel .review-loop-conversation-message").count();
  receipt.timeline_has_lifecycle = /New conversation|Past conversations|Resolve conversation/.test(await page.locator("#review-loop-panel").innerText());
  assert.ok(receipt.timeline_message_count >= 2, "timeline shows oldest and latest in one stream");
  assert.equal(receipt.timeline_has_lifecycle, false, "populated timeline still hides thread-lifecycle chrome");
  await page.locator("#review-loop-panel").screenshot({ path: TIMELINE_PNG });
  await page.screenshot({ path: join(EVIDENCE_DIR, "session-isolation-full-ui.png"), fullPage: true });
  await page.locator("#send-and-exit").click({ timeout: 10000 });
  await page.waitForSelector("#submit-modal.visible", { timeout: 8000 });
  const approveEnabled = await page.locator("#modal-approve").isEnabled();
  receipt.approve_enabled = approveEnabled;
  assert.equal(approveEnabled, true, "Approve is enabled on a clean new session");
  await page.locator("#submit-modal").screenshot({ path: APPROVE_PNG });
  await context.close().catch(() => {});

  receipt.pageErrors = pageErrors;
  assert.deepEqual(pageErrors, [], "no page errors");
  receipt.result = "PASS";
  writeFileSync(join(EVIDENCE_DIR, "session-isolation-chrome-evidence.json"), JSON.stringify(receipt, null, 2));
  console.log("DOGFOOD_CHROME_SESSION_ISOLATION: PASS");
  console.log(JSON.stringify(receipt, null, 2));
} finally {
  proc.kill("SIGTERM");
}
