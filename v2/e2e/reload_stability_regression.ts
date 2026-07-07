/**
 * E2E regression for task #19 — a real re-review session hit three
 * compounding symptoms while answering a 3-question REPORT.md:
 *
 *   "3つめの質問回答中に落ちました。最悪。何が起こってるんだろうそして
 *    今現時点で未回答の回答があるはずなのに回答。質問ダイアログがリロー
 *    ド直後にすぐ消えます。最悪"
 *
 * Server log evidence showed TWO back-to-back close→open cycles (a file
 * being edited twice in quick succession by a concurrent agent — a
 * realistic scenario in a busy multi-agent session) followed by a submit
 * with a clearly mid-typing answer ("今な").
 *
 * Root causes found by actually reproducing this with Playwright (not
 * guessed):
 *
 *   1. check_recovery() required a fresh MANUAL "Restore" click after
 *      EVERY SSE self-triggered reload. If a second reload arrived before
 *      the human could click Restore on the first one, the freshly
 *      reloaded (still unrestored) page just got reloaded again — from the
 *      human's side, "the dialog flashes and vanishes". Fixed: an SSE
 *      self-triggered reload (flagged via a localStorage marker set right
 *      before location.reload(), since in-memory state doesn't survive a
 *      navigation) now auto-restores with zero clicks.
 *
 *   2. update_questions_count()'s "auto-close if everything's answered"
 *      500ms timer was ALSO firing off the back of that auto-restore when
 *      the restored draft happened to already be fully answered — closing
 *      the dialog task #18 had just forced open, with no human interaction
 *      in between. Fixed: restore uses update_questions_badge() (count
 *      display only), not update_questions_count() (which also schedules
 *      the auto-close) — auto-close now only fires from genuine option
 *      clicks / textarea input, never from a programmatic restore.
 *
 *   3. arm_close_timer's reload-correlation grace period remains a
 *      ONE-SHOT extension (already_extended: Bool) — UNCHANGED from before
 *      this task. Root cause #1's fix (an SSE self-triggered reload never
 *      sends /close in the first place) is what actually protects a
 *      second back-to-back reload; schedule_close_submit() also resets the
 *      extension to a fresh state on every genuinely new /close signal, so
 *      the timer never needed more than one extension. A bounded
 *      max_close_extensions (5) variant was tried and reverted after it
 *      regressed smoke.ts's "Browser Close: closing the page exits the
 *      server" — looks_like_reload_in_flight() compares fixed timestamps
 *      that stay true across retries, so raising the cap just stretched
 *      the worst-case abandonment wait (up to ~30s) without fixing
 *      anything root causes #1/#2 didn't already fix.
 *
 * Run: node --experimental-strip-types e2e/reload_stability_regression.ts
 */
import { spawn, type ChildProcess } from "node:child_process";
import { mkdtempSync, writeFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { chromium, type Browser, type Page } from "playwright";

const SERVER_JS = new URL(
  "../_build/js/release/build/server/server.js",
  import.meta.url,
).pathname;

let failed = 0;
function pass(msg: string): void {
  console.log(`PASS: ${msg}`);
}
function fail(msg: string, detail?: unknown): void {
  failed++;
  console.error(`FAIL: ${msg}`);
  if (detail !== undefined) console.error(JSON.stringify(detail, null, 2));
}
function assertTrue(condition: boolean, msg: string, detail?: unknown): void {
  condition ? pass(msg) : fail(msg, detail);
}

function threeQuestionFixture(rev: number): string {
  return [
    "---",
    "yunomi:",
    "  questions:",
    "    - id: q-signoff-failopen",
    "      question: hookのfail-open設計をサインオフする？",
    "      options:",
    "        - OK",
    "        - fail-closedに変えて",
    "    - id: q-experience-hook",
    "      question: plan-review-hook試作、体験してみる？",
    "      options:",
    "        - あとで体験する",
    "        - 今回は見送り",
    "    - id: q-emoji-bar",
    "      question: 質問バーの絵文字文言は別タスクで直す？",
    "---",
    "",
    "# reload stability regression fixture",
    "",
    `rev ${rev}`,
    "",
  ].join("\n");
}

type ServerHandle = { proc: ChildProcess; getOutput: () => string; port: number };

function startServer(mdPath: string, port: number, lockDir: string): Promise<ServerHandle> {
  return new Promise((resolve, reject) => {
    const proc = spawn(process.execPath, [SERVER_JS, mdPath, "--no-open", "--port", String(port)], {
      env: { ...process.env, HERDR_PANE_ID: "", YUNOMI_NOTIFY_CMD: "", YUNOMI_LOCK_DIR: lockDir, YUNOMI_REVIEW_DIR: join(lockDir, "../reviews-" + Date.now()) },
      stdio: ["ignore", "pipe", "pipe"],
    });
    let out = "";
    let resolved = false;
    proc.stdout!.on("data", (d: Buffer) => {
      out += String(d);
      if (!resolved) {
        const m = out.match(/http:\/\/127\.0\.0\.1:(\d+)/);
        if (m) {
          resolved = true;
          resolve({ proc, getOutput: () => out, port: parseInt(m[1], 10) });
        }
      }
    });
    proc.stderr!.on("data", (d: Buffer) => (out += String(d)));
    proc.on("exit", (code) => {
      if (!resolved) reject(new Error(`server exited before ready (${code})\n${out}`));
    });
    setTimeout(() => {
      if (!resolved) reject(new Error(`startup timeout\n${out}`));
    }, 10000);
  });
}

async function waitHealth(port: number): Promise<void> {
  for (let i = 0; i < 50; i++) {
    try {
      const r = await fetch(`http://127.0.0.1:${port}/healthz`);
      if (r.ok) return;
    } catch {}
    await new Promise((r) => setTimeout(r, 100));
  }
  throw new Error(`healthz timeout on ${port}`);
}

function killIfAlive(proc: ChildProcess): void {
  if (proc.exitCode === null && !proc.killed) proc.kill("SIGKILL");
}

async function freshPage(browser: Browser, port: number): Promise<Page> {
  const page = await browser.newPage({ viewport: { width: 1280, height: 900 } });
  // Clear storage only on the tab's very first load. addInitScript reruns
  // on EVERY navigation, including the file-watch reloads these scenarios
  // deliberately trigger — an unconditional clear here would wipe the
  // draft out from under every single one of them (a test-harness bug
  // that looks identical to a real localStorage-loss bug if unguarded;
  // see questions_answers.ts for the same fix applied earlier).
  await page.addInitScript(() => {
    const marker = "__yunomi_e2e_boot__";
    if (!sessionStorage.getItem(marker)) {
      localStorage.clear();
      sessionStorage.clear();
      sessionStorage.setItem(marker, "1");
    }
  });
  await page.goto(`http://127.0.0.1:${port}`, { waitUntil: "domcontentloaded" });
  return page;
}

async function reachThirdQuestion(page: Page): Promise<void> {
  await page.waitForSelector("#yunomi-questions-overlay.visible", { timeout: 5000 });
  await page.locator(".question-card.step-active .q-option-btn").first().click();
  await page.locator("#yunomi-questions-next").click();
  await page.waitForTimeout(150);
  await page.locator(".question-card.step-active .q-option-btn").first().click();
  await page.locator("#yunomi-questions-next").click();
  await page.waitForTimeout(150);
}

/** (a): no spurious reload fires while idle/typing, absent any real file change. */
async function scenarioNoSpuriousReloadWhileIdle(browser: Browser): Promise<void> {
  console.log("\n--- Scenario (a): no reload fires while typing Q3, absent a real file change ---");
  const workDir = mkdtempSync(join(tmpdir(), "yunomi-reload-stability-a-"));
  const mdPath = join(workDir, "fixture.md");
  writeFileSync(mdPath, threeQuestionFixture(1));
  const { proc, port } = await startServer(mdPath, 5470, join(workDir, "locks"));
  try {
    await waitHealth(port);
    const page = await freshPage(browser, port);
    let navigations = 0;
    page.on("framenavigated", (frame) => {
      if (frame === page.mainFrame()) navigations++;
    });
    await reachThirdQuestion(page);
    navigations = 0; // only count navigations from here on
    const answerBox = page.locator(".question-card.step-active .q-answer");
    await answerBox.fill("途中経過のテキスト");
    // Non-empty text on the last remaining question makes
    // count_unanswered_questions() hit 0, which — correctly, and
    // unrelated to task #19 — schedules the existing "auto-close once
    // everything's answered" 500ms timer (see update_questions_count()).
    // That's a genuine-interaction affordance, not a bug: don't assert the
    // dialog stays open here, just that the underlying draft survives and
    // that nothing NAVIGATES (which is what task #19 is actually about).
    await page
      .waitForFunction(
        (expected) => {
          for (let i = 0; i < localStorage.length; i++) {
            const key = localStorage.key(i);
            if (!key?.startsWith("yunomi:comments:")) continue;
            try {
              const d = JSON.parse(localStorage.getItem(key) ?? "");
              if (d.answers?.["q-emoji-bar"]?.text === expected) return true;
            } catch {}
          }
          return false;
        },
        "途中経過のテキスト",
        { timeout: 3000 },
      )
      .catch(() => {});
    // fs.watchFile's default poll interval is ~5s — wait comfortably past
    // two full polling cycles with the file untouched.
    await page.waitForTimeout(6500);
    assertTrue(navigations === 0, "ファイルを一切変更していない間、リロード（ナビゲーション）は一度も発生しない", {
      navigations,
    });
    const draftStillIntact = await page.evaluate(() => {
      for (let i = 0; i < localStorage.length; i++) {
        const key = localStorage.key(i)!;
        if (!key.startsWith("yunomi:comments:")) continue;
        try {
          const d = JSON.parse(localStorage.getItem(key) ?? "");
          return d.answers?.["q-emoji-bar"]?.text ?? "";
        } catch {
          return "<parse error>";
        }
      }
      return "<no draft>";
    });
    assertTrue(
      draftStillIntact === "途中経過のテキスト",
      "リロードが起きないので下書きの内容も勝手に消えたりリセットされたりしない",
      { draftStillIntact },
    );
    await page.close();
  } finally {
    killIfAlive(proc);
    rmSync(workDir, { recursive: true, force: true });
  }
}

/** (b): the immediate answer live-delivery (task #18) must not itself trigger an SSE reload. */
async function scenarioAnswerLiveDeliveryDoesNotTriggerReload(browser: Browser): Promise<void> {
  console.log("\n--- Scenario (b): posting an answer live-event does not trigger an SSE reload ---");
  const workDir = mkdtempSync(join(tmpdir(), "yunomi-reload-stability-b-"));
  const mdPath = join(workDir, "fixture.md");
  writeFileSync(mdPath, threeQuestionFixture(1));
  const { proc, port } = await startServer(mdPath, 5471, join(workDir, "locks"));
  try {
    await waitHealth(port);
    const page = await freshPage(browser, port);
    await page.waitForSelector("#yunomi-questions-overlay.visible", { timeout: 5000 });

    let navigations = 0;
    page.on("framenavigated", (frame) => {
      if (frame === page.mainFrame()) navigations++;
    });
    let sawReloadSseEvent = false;
    await page.exposeFunction("__testSawReload", () => {
      sawReloadSseEvent = true;
    });
    await page.evaluate(() => {
      // Tap into a fresh EventSource the same way the app does, purely to
      // observe whether a "reload" event ever arrives — independent of the
      // app's own handler, so this can't be fooled by app-side logic.
      const es = new EventSource(location.origin + "/sse");
      es.addEventListener("reload", () => {
        (window as unknown as { __testSawReload: () => void }).__testSawReload();
      });
      (window as unknown as { __probeEs: EventSource }).__probeEs = es;
    });
    await page.waitForTimeout(300);

    // Answer Q1 (option) and advance — this fires send_answer_event_to_server
    // -> POST /comment type:"answer" -> handle_answer_event's SSE "answer"
    // broadcast (main.mbt).
    const responsePromise = page.waitForResponse((res) => res.url().includes("/comment"), {
      timeout: 5000,
    });
    await page.locator(".question-card.step-active .q-option-btn").first().click();
    await page.locator("#yunomi-questions-next").click();
    const commentResponse = await responsePromise;
    assertTrue(commentResponse.status() === 200, "answer即時配信のPOST /commentが200を返す", {
      status: commentResponse.status(),
    });

    await page.waitForTimeout(1000);
    assertTrue(navigations === 0, "answer即時配信の直後もページのナビゲーション（リロード）は発生しない", {
      navigations,
    });
    assertTrue(
      !sawReloadSseEvent,
      "answer即時配信はSSE 'reload' イベントを一切発火させない（'answer'イベントのみ、別チャンネルとして分離されている）",
    );

    await page.close();
  } finally {
    killIfAlive(proc);
    rmSync(workDir, { recursive: true, force: true });
  }
}

/**
 * (c): even when the file genuinely changes TWICE in quick succession
 * (matching the real incident's server-log evidence) while the human is
 * mid-typing the 3rd question, the dialog auto-restores every time and the
 * in-progress answer is never silently finalized/submitted.
 */
async function scenarioReloadRestoresWithoutFinalizing(browser: Browser): Promise<void> {
  console.log(
    "\n--- Scenario (c): two back-to-back file-change reloads while typing Q3 — dialog restores, nothing gets finalized early ---",
  );
  const workDir = mkdtempSync(join(tmpdir(), "yunomi-reload-stability-c-"));
  const mdPath = join(workDir, "fixture.md");
  writeFileSync(mdPath, threeQuestionFixture(1));
  const { proc, getOutput, port } = await startServer(mdPath, 5472, join(workDir, "locks"));
  try {
    await waitHealth(port);
    const page = await freshPage(browser, port);
    let closeRequestSeen = false;
    let exitRequestSeen = false;
    page.on("request", (req) => {
      if (req.url().includes("/close")) closeRequestSeen = true;
      if (req.url().includes("/exit")) exitRequestSeen = true;
    });

    await reachThirdQuestion(page);
    const answerBox = page.locator(".question-card.step-active .q-answer");
    const PARTIAL = "今な";
    await answerBox.fill(PARTIAL);
    await page
      .waitForFunction(
        (expected) => {
          for (let i = 0; i < localStorage.length; i++) {
            const key = localStorage.key(i);
            if (!key?.startsWith("yunomi:comments:")) continue;
            try {
              const d = JSON.parse(localStorage.getItem(key) ?? "");
              if (d.answers?.["q-emoji-bar"]?.text === expected) return true;
            } catch {}
          }
          return false;
        },
        PARTIAL,
        { timeout: 3000 },
      )
      .catch(() => {});

    // Two edits in a row, like the real incident's log evidence.
    await page.waitForTimeout(500);
    writeFileSync(mdPath, threeQuestionFixture(2));
    const nav1 = page.waitForEvent("load", { timeout: 15000 });
    await nav1;
    await page.waitForTimeout(1500);
    writeFileSync(mdPath, threeQuestionFixture(3));
    const nav2 = page.waitForEvent("load", { timeout: 15000 });
    await nav2;

    assertTrue(!closeRequestSeen, "2回連続のリロードでも /close は一度も送られない（意図的リロードとして扱われる）", {
      closeRequestSeen,
    });
    assertTrue(
      !exitRequestSeen,
      "2回連続のリロードでも /exit（確定提出）は一切発生しない＝途中経過が勝手に確定されない",
      { exitRequestSeen },
    );

    const overlayVisible = await page
      .locator("#yunomi-questions-overlay")
      .evaluate((el) => el.classList.contains("visible"));
    assertTrue(overlayVisible, "2回連続リロード後も質問ステッパーが前面表示されている（消えたままにならない）");

    const restoredValue = await page
      .locator('.question-card[data-qid="q-emoji-bar"] .q-answer')
      .inputValue();
    assertTrue(
      restoredValue === PARTIAL,
      "2回連続リロード後も3問目の入力途中の回答が一文字も欠けず復元されている",
      { restoredValue, expected: PARTIAL },
    );
    const isStepActive = await page
      .locator('.question-card[data-qid="q-emoji-bar"]')
      .evaluate((el) => el.classList.contains("step-active"));
    assertTrue(isStepActive, "2回連続リロード後もステッパーの位置は3問目のまま（1問目に戻らない）");

    // Finish for real, and confirm the FULL (not truncated) answer reaches
    // the verdict YAML — proving the earlier partial never got finalized.
    const FULL = PARTIAL + "らこれで完成です。";
    await page
      .locator('.question-card[data-qid="q-emoji-bar"] .q-answer')
      .evaluate((el, value) => {
        const ta = el as HTMLTextAreaElement;
        ta.value = value;
        ta.dispatchEvent(new Event("input", { bubbles: true }));
      }, FULL);
    const closeBtn = page.locator("#yunomi-questions-close");
    if (await closeBtn.isVisible().catch(() => false)) {
      await closeBtn.click();
    }
    await page.locator("#send-and-exit").click();
    await page.waitForSelector("#submit-modal.visible", { timeout: 5000 });
    const exitPromise = new Promise<number | null>((resolve) => {
      if (proc.exitCode !== null) {
        resolve(proc.exitCode);
        return;
      }
      proc.once("exit", (code) => resolve(code));
    });
    await page.locator("#modal-request-changes").click();
    const exitCode = await exitPromise;
    assertTrue(exitCode === 0, "最終Submit後にサーバーが正常終了する", { exitCode });

    const output = getOutput();
    const match = output.match(/^answers: '(.*)'$/m);
    const answersRaw = match ? match[1].replace(/''/g, "'") : "";
    let parsed: Record<string, string> = {};
    try {
      parsed = JSON.parse(answersRaw);
    } catch {}
    assertTrue(
      parsed["q-emoji-bar"] === FULL,
      "最終verdict YAMLには完成した全文が反映される（2回のリロードを経ても部分文字列で確定されていない）",
      { got: parsed["q-emoji-bar"], expected: FULL },
    );

    await page.close();
  } finally {
    killIfAlive(proc);
    rmSync(workDir, { recursive: true, force: true });
  }
}

async function main(): Promise<void> {
  const browser = await chromium.launch();
  try {
    await scenarioNoSpuriousReloadWhileIdle(browser);
    await scenarioAnswerLiveDeliveryDoesNotTriggerReload(browser);
    await scenarioReloadRestoresWithoutFinalizing(browser);
  } finally {
    await browser.close();
  }
  console.log(`\nSummary: ${failed === 0 ? "all passed" : `${failed} failed`}`);
  if (failed > 0) process.exit(1);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
