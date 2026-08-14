import assert from "node:assert/strict";
import { spawn, spawnSync } from "node:child_process";
import { mkdtempSync, writeFileSync, mkdirSync, rmSync, readFileSync, existsSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { chromium } from "playwright";

const REPO = "/Users/kazuph/src/github.com/kazuph/yunomi";
const SERVER_JS = join(REPO, "v2/_build/js/release/build/server/server.js");

function run(cmd, args, cwd) {
  const r = spawnSync(cmd, args, { cwd, encoding: "utf8" });
  if (r.status !== 0) throw new Error(`${cmd} ${args.join(" ")}\n${r.stdout}\n${r.stderr}`);
  return r;
}

async function request(port, path, body) {
  const res = await fetch(`http://127.0.0.1:${port}${path}`, {
    method: body ? "POST" : "GET",
    headers: body ? { "content-type": "application/json" } : undefined,
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  return { status: res.status, text, json: () => { try { return JSON.parse(text); } catch { return null; } } };
}

const root = mkdtempSync(join(tmpdir(), "yunomi-mux-chrome-dogfood-"));
run("git", ["init", "-b", "main"], root);
run("git", ["config", "user.email", "yunomi@example.test"], root);
run("git", ["config", "user.name", "yunomi"], root);
mkdirSync(join(root, "first"), { recursive: true });
mkdirSync(join(root, "second"), { recursive: true });
writeFileSync(join(root, "first/report.md"), "# First base\n");
writeFileSync(join(root, "second/report.md"), "# Second base\n");
run("git", ["add", "."], root);
run("git", ["commit", "-m", "base"], root);
run("git", ["checkout", "-b", "feature/mux-chrome-dogfood"], root);
writeFileSync(join(root, "first/report.md"), "# First changed\n");
writeFileSync(join(root, "second/report.md"), "# Second changed\n");
run("git", ["add", "."], root);
run("git", ["commit", "-m", "changed"], root);

const reviewDir = join(root, "reviews");
const lockDir = join(root, "locks");
mkdirSync(reviewDir, { recursive: true });
mkdirSync(lockDir, { recursive: true });
writeFileSync(join(reviewDir, "review.json"), JSON.stringify({
  version: 1,
  mux: true,
  branch: "feature/mux-chrome-dogfood",
  files: ["first/report.md", "second/report.md"],
  rounds: [
    { round: 1, started_at: "2026-08-13T00:00:00.000Z", submitted_at: "2026-08-13T00:01:00.000Z", decision: "request_changes", summary: "prior", results: {} },
    { round: 2, started_at: "2026-08-13T00:02:00.000Z", submitted_at: null, decision: null, summary: "", results: {} },
  ],
  comments: [
    {
      id: "dogfood-file",
      file: "first/report.md",
      line: 1,
      row: 0,
      col: 0,
      round: 1,
      text: "file anchored open",
      author: "dogfood",
      status: "unresolved",
      scope: "file",
      unanchored: false,
      quote: "# First changed",
      value: "# First changed",
      replies: [],
      anchor: { snippet: "# First changed", context_before: "", context_after: "" },
    },
  ],
}, null, 2));

const proc = spawn(process.execPath, [
  SERVER_JS, "review", "main", "--no-open", "--port", "0", "--loop",
], {
  cwd: root,
  env: {
    ...process.env,
    HERDR_PANE_ID: "",
    YUNOMI_NOTIFY_CMD: "true",
    YUNOMI_REVIEW_DIR: reviewDir,
    YUNOMI_LOCK_DIR: lockDir,
  },
  stdio: ["ignore", "pipe", "pipe"],
});

let port = 0;
await new Promise((resolve, reject) => {
  const timer = setTimeout(() => reject(new Error("server start timeout")), 20000);
  let buf = "";
  const observe = (chunk) => {
    buf += chunk.toString();
    const m = buf.match(/http:\/\/127\.0\.0\.1:(\d+)/);
    if (m) {
      port = Number(m[1]);
      clearTimeout(timer);
      resolve();
    }
  };
  proc.stdout.on("data", observe);
  proc.stderr.on("data", observe);
  proc.on("exit", (code) => reject(new Error(`server exited early ${code}: ${buf}`)));
});
console.log(`server port=${port}`);

const healthz = await request(port, "/healthz");
assert.equal(healthz.status, 200, "healthz must be 200");
console.log(`healthz=${healthz.status}`);

const profileDir = mkdtempSync(join(tmpdir(), "yunomi-mux-chrome-profile-"));
const context = await chromium.launchPersistentContext(profileDir, {
  channel: "chrome",
  headless: false,
  viewport: { width: 1280, height: 900 },
  args: ["--no-first-run", "--no-default-browser-check"],
});
const pageErrors = [];
const page = context.pages()[0] || await context.newPage();
page.on("pageerror", (error) => pageErrors.push(error.message));
await page.addInitScript("globalThis.__name=globalThis.__name||((f)=>f);");

async function dismissRecovery(target) {
  const overlay = target.locator("#recovery-modal.visible");
  if (await overlay.count() && await overlay.isVisible()) {
    await target.locator("#recovery-discard").click();
    await target.waitForSelector("#recovery-modal.visible", { state: "hidden", timeout: 5000 }).catch(() => {});
  }
}

async function openSubmitModal(target) {
  await dismissRecovery(target);
  await target.waitForSelector("#send-and-exit", { timeout: 15000 });
  await target.locator("#send-and-exit").click({ timeout: 10000 });
  await target.waitForSelector("#submit-modal.visible", { timeout: 8000 });
}

async function closeSubmitModal(target) {
  await target.keyboard.press("Escape").catch(() => {});
  await target.waitForSelector("#submit-modal.visible", { state: "hidden", timeout: 5000 }).catch(() => {});
}

const receipt = { port, healthz: healthz.status, browser: "channel=chrome isolated-profile headed", pageErrors };

try {
  await page.goto(`http://127.0.0.1:${port}/?f=0`, { waitUntil: "domcontentloaded" });
  await page.waitForSelector("#review-loop-panel, .review-actions, #send-and-exit", { timeout: 15000 });
  await dismissRecovery(page);
  receipt.html_generation = await page.evaluate(() => Number(window.__YUNOMI_REVIEW_GENERATION__ || 0));
  console.log(`html generation=${receipt.html_generation}`);

  const state0 = (await request(port, "/review-state?f=0")).json();
  receipt.gate_with_prior_file_open = state0.gate_unresolved_count;
  receipt.review_files = state0.review?.files || [];
  receipt.review_rounds = (state0.review?.rounds || []).map((r) => r.round);
  receipt.comment_ids = (state0.review?.comments || []).map((c) => ({ id: c.id, file: c.file, scope: c.scope, round: c.round, unanchored: c.unanchored, status: c.status }));
  const fileComment = (state0.review?.comments || []).find((c) => c.id === "dogfood-file");
  receipt.file_unanchored = fileComment?.unanchored ?? null;
  console.log(`gate_unresolved with prior file open=${state0.gate_unresolved_count} comments=${JSON.stringify(receipt.comment_ids)}`);
  assert.ok(fileComment, "seeded prior-round file thread is visible on f=0");
  assert.notEqual(fileComment.unanchored, true, "seeded file thread must remain anchored");
  assert.ok(state0.gate_unresolved_count > 0, "prior-round anchored file thread raises the approve gate");

  const roundCreate = await request(port, "/create-global-comment?f=0", { text: "round open thread" });
  receipt.round_comment_status = roundCreate.status;
  receipt.round_comment_body = roundCreate.text.slice(0, 200);
  console.log(`round comment status=${roundCreate.status} body=${roundCreate.text.slice(0, 200)}`);
  assert.equal(roundCreate.status, 200, "round open thread create accepted");

  const afterRound = (await request(port, "/review-state?f=0")).json();
  receipt.gate_after_round_open = afterRound.gate_unresolved_count;
  console.log(`gate_unresolved after round open=${afterRound.gate_unresolved_count}`);
  assert.equal(afterRound.gate_unresolved_count, state0.gate_unresolved_count, "round open thread must not increase approve gate");

  await page.waitForFunction((expected) => Number(window.__YUNOMI_REVIEW_LOOP_GATE__ || 0) === expected, state0.gate_unresolved_count, { timeout: 10000 }).catch(() => {});
  await openSubmitModal(page);
  const approveEnabledWithFile = await page.locator("#modal-approve").isEnabled();
  receipt.approve_enabled_with_file_and_round_open = approveEnabledWithFile;
  console.log(`approve enabled with file+round open=${approveEnabledWithFile}`);
  assert.equal(approveEnabledWithFile, false, "Approve is disabled while a prior-round anchored file thread is open");
  await closeSubmitModal(page);

  const blocked = await request(port, "/exit?f=0", {
    decision: "approve", comment: "should block",
  });
  receipt.approve_while_file_open_status = blocked.status;
  console.log(`approve while file open status=${blocked.status} body=${blocked.text.slice(0, 180)}`);
  assert.equal(blocked.status, 409, "Approve is rejected while an anchored file thread is open");

  const resolved = await request(port, `/resolve-comment?f=0`, { id: "dogfood-file" });
  receipt.resolve_file_status = resolved.status;
  console.log(`resolve file status=${resolved.status}`);
  assert.equal(resolved.status, 200, "file thread resolve accepted");

  const afterResolve = (await request(port, "/review-state?f=0")).json();
  receipt.gate_after_file_resolve = afterResolve.gate_unresolved_count;
  const roundStill = (afterResolve.review?.comments || [])
    .find((c) => c.text === "round open thread" || c.scope === "round");
  receipt.round_thread_status_after_file_resolve = roundStill?.status || null;
  console.log(`gate after file resolve=${afterResolve.gate_unresolved_count} round=${roundStill?.status}`);
  assert.equal(afterResolve.gate_unresolved_count, 0, "gate returns to non-blocking after file resolve");
  assert.ok(roundStill && roundStill.status !== "resolved", "round open thread remains stored and open");

  await page.waitForFunction(() => Number(window.__YUNOMI_REVIEW_LOOP_GATE__ || 0) === 0, { timeout: 10000 }).catch(() => {});
  await openSubmitModal(page);
  const approveEnabledAfter = await page.locator("#modal-approve").isEnabled();
  receipt.approve_enabled_after_file_resolve_with_round_open = approveEnabledAfter;
  console.log(`approve enabled after file resolve with round still open=${approveEnabledAfter}`);
  assert.equal(approveEnabledAfter, true, "Approve is enabled after file resolve even if round thread stays open");

  const exitResponse = page.waitForResponse((response) => response.url().includes("/exit"), { timeout: 10000 });
  await page.locator("#modal-approve").click();
  const clicked = await exitResponse;
  receipt.approve_click_status = clicked.status();
  receipt.approve_click_body = (await clicked.text()).slice(0, 180);
  console.log(`approve click status=${receipt.approve_click_status} body=${receipt.approve_click_body}`);
  assert.equal(receipt.approve_click_status, 200, "clicking Approve succeeds while only a round open thread remains");

  receipt.pageErrors = pageErrors;
  assert.deepEqual(pageErrors, [], "no page errors");
  receipt.result = "PASS";
  console.log("DOGFOOD_CHROME_MUX_GATE: PASS");
  console.log(JSON.stringify(receipt, null, 2));
} finally {
  await context.close().catch(() => {});
  proc.kill("SIGTERM");
  try { rmSync(root, { recursive: true, force: true }); } catch {}
  try { rmSync(profileDir, { recursive: true, force: true }); } catch {}
}
