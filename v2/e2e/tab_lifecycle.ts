/**
 * Tab Lifecycle E2E Test (the "duplicate tab" bug)
 *
 * 1. A lingering tab whose server died must retire itself when a NEW
 *    server reuses the same port (SSE "hello" instance-id change),
 *    so it never joins the new session as a stale tab.
 * 2. After Submit & Exit, a tab the browser refuses to close must park
 *    itself on about:blank so it no longer poses as a live review.
 *
 * Run: node --experimental-strip-types v2/e2e/tab_lifecycle.ts
 */
import { spawn, type ChildProcess } from "node:child_process";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { mkdtempSync, readFileSync, writeFileSync, rmSync } from "node:fs";
import { chromium } from "playwright";

const PORT = 5923;
const SERVER_JS = new URL(
  "../_build/js/release/build/server/server.js",
  import.meta.url,
).pathname;
const WORK_DIR = mkdtempSync(join(tmpdir(), "yunomi-tab-lifecycle-"));
const NOTIFY_LOG = join(WORK_DIR, "notify.log");
const NOTIFY_SCRIPT = join(WORK_DIR, "notify-capture.mjs");

let failed = 0;

function assert(condition: boolean, msg: string, detail?: unknown): void {
  if (condition) {
    console.log(`PASS: ${msg}`);
  } else {
    failed++;
    console.error(`FAIL: ${msg}`);
    if (detail !== undefined) console.error(JSON.stringify(detail, null, 2));
  }
}

function startServer(file: string, loop = false): Promise<ChildProcess> {
  return new Promise((resolve, reject) => {
    const args = [SERVER_JS, file, "--no-open", "--port", String(PORT)];
    if (loop) args.push("--loop", "--notify-pane", "p_test");
    const proc = spawn("node", args, {
      stdio: ["ignore", "pipe", "pipe"],
      env: {
        ...process.env,
        HERDR_PANE_ID: "",
        YUNOMI_NOTIFY_CMD: loop ? `${process.execPath} ${NOTIFY_SCRIPT} {msg}` : "",
        NOTIFY_LOG,
        YUNOMI_LOCK_DIR: join(WORK_DIR, "locks"),
        YUNOMI_REVIEW_DIR: join(WORK_DIR, "reviews-" + Date.now()),
      },
    });
    let out = "";
    const onData = (d: Buffer) => {
      out += String(d);
      if (out.includes(`http://127.0.0.1:${PORT}`)) resolve(proc);
    };
    proc.stdout.on("data", onData);
    proc.stderr.on("data", onData);
    setTimeout(() => reject(new Error(`server did not start:\n${out}`)), 10000);
  });
}

async function waitForNotification(pattern: RegExp): Promise<string> {
  const deadline = Date.now() + 5000;
  while (Date.now() < deadline) {
    const notifications = readFileSync(NOTIFY_LOG, "utf8");
    if (pattern.test(notifications)) return notifications;
    await new Promise((resolve) => setTimeout(resolve, 50));
  }
  throw new Error(`notification timeout: ${pattern}\n${readFileSync(NOTIFY_LOG, "utf8")}`);
}

function stop(proc: ChildProcess): Promise<void> {
  return new Promise((resolve) => {
    proc.on("exit", () => resolve());
    proc.kill("SIGINT");
    setTimeout(() => { proc.kill("SIGKILL"); resolve(); }, 3000);
  });
}

const docA = join(WORK_DIR, "a.md");
const docB = join(WORK_DIR, "b.md");
writeFileSync(docA, "# Session Alpha\n\nfirst body\n");
writeFileSync(docB, "# Session Beta\n\nsecond body\n");
writeFileSync(
  NOTIFY_SCRIPT,
  "import { appendFileSync } from 'node:fs'; appendFileSync(process.env.NOTIFY_LOG, process.argv[2] + '\\n');\n",
);
writeFileSync(NOTIFY_LOG, "");

const browser = await chromium.launch();
try {
  const page = await browser.newPage();

  // --- 1. zombie tab retires on server restart (port reuse) ---
  const a = await startServer(docA);
  await page.goto(`http://127.0.0.1:${PORT}/`, { waitUntil: "domcontentloaded" });
  const titleA = await page.evaluate(() => document.body.innerText.includes("Session Alpha"));
  assert(titleA, "セッションAの内容が表示される");
  await stop(a);
  await page.waitForTimeout(500);

  const b = await startServer(docB);
  // EventSource reconnects on its own schedule; the new hello id must retire the stale page.
  const retired = await page
    .waitForFunction(() => location.href === "about:blank", undefined, { timeout: 15000 })
    .then(() => true)
    .catch(() => false);
  const closedAfterRestart = page.isClosed();
  const showsBeta = closedAfterRestart
    ? false
    : await page.evaluate(() => document.body.innerText.includes("Session Beta")).catch(() => false);
  assert(retired || closedAfterRestart, "ポート再利用の新サーバ起動で残骸タブは閉じるか about:blank に退避する", {
    retired,
    closed: closedAfterRestart,
    url: closedAfterRestart ? "(closed)" : page.url(),
  });
  assert(!showsBeta, "残骸タブは新セッションの内容を表示しない", { showsBeta });

  // --- 2. submit parks the tab on about:blank when close is refused ---
  const fresh = await browser.newPage();
  await fresh.goto(`http://127.0.0.1:${PORT}/`, { waitUntil: "domcontentloaded" });
  await fresh.locator("#send-and-exit").click();
  const modal = await fresh.waitForSelector("#submit-modal", { timeout: 3000 }).catch(() => null);
  assert(modal !== null, "Submit & Exit でSubmitモーダルが開く");
  if (modal) {
    await fresh.locator("#modal-approve").click();
    const parked = await fresh
      .waitForFunction(() => location.href === "about:blank", undefined, { timeout: 8000 })
      .then(() => true)
      .catch(() => false);
    const closed = fresh.isClosed();
    assert(parked || closed, "Submit後、タブはcloseされるか about:blank に退避する", {
      parked,
      closed,
      url: closed ? "(closed)" : fresh.url(),
    });
  }
  await stop(b);

  // --- 3. request_changes retires the tab and emits one close notification ---
  writeFileSync(NOTIFY_LOG, "");
  const loop = await startServer(docB, true);
  const requestChanges = await browser.newPage();
  await requestChanges.goto(`http://127.0.0.1:${PORT}/`, { waitUntil: "domcontentloaded" });
  await requestChanges.waitForTimeout(100);
  await requestChanges.locator("#send-and-exit").click();
  await requestChanges.waitForSelector("#submit-modal.visible");
  const composing = await requestChanges.locator("#global-comment").evaluate((input) => {
    const event = new KeyboardEvent("keydown", {
      key: "Enter",
      ctrlKey: true,
      bubbles: true,
      cancelable: true,
      isComposing: true,
    });
    input.dispatchEvent(event);
    return {
      prevented: event.defaultPrevented,
      modalVisible: document.querySelector("#submit-modal")?.classList.contains("visible") || false,
    };
  });
  assert(
    !composing.prevented && composing.modalVisible,
    "IME変換中のCtrl+EnterはRequest Changesを送らずSubmitモーダルを維持する",
    composing,
  );
  await requestChanges
    .locator("#global-comment")
    .press(process.platform === "darwin" ? "Meta+Enter" : "Control+Enter");
  await waitForNotification(/\[yunomi\] verdict b\.md decision=request_changes/);
  const retiredAfterRequestChanges = await requestChanges
    .waitForFunction(() => location.href === "about:blank", undefined, { timeout: 5000 })
    .then(() => true)
    .catch(() => false);
  const notifications = await waitForNotification(/\[yunomi\] tab closed b\.md tab=.* active=0/);
  const closeCount = (notifications.match(/\[yunomi\] tab closed b\.md/g) || []).length;
  assert(
    retiredAfterRequestChanges && closeCount === 1,
    "Request Changes後に退役した実タブは閉じる通知を1回だけ送る",
    { retiredAfterRequestChanges, closeCount },
  );
  await stop(loop);
} finally {
  await browser.close();
  rmSync(WORK_DIR, { recursive: true, force: true });
}

console.log(`\nResults: ${failed === 0 ? "all passed" : failed + " failed"}`);
if (failed > 0) process.exitCode = 1;
