/**
 * Close-auto-submit race regression.
 *
 * Background: pagehide/beforeunload -> POST /close arms a 5s server-side
 * timer (schedule_close_submit) that auto-submits whatever draft was
 * captured at the instant of pagehide, UNLESS the tab reconnects via
 * POST /session/open before the timer fires. If a reload (the browser's
 * own F5, or the app's own "the reviewed file changed" SSE-driven reload)
 * happens while the human is mid-typing, and the reconnect is slow for any
 * reason (slow JS boot, slow network, contention), the 5s timer used to
 * fire first: a STALE, PARTIAL snapshot (e.g. "エージェ" instead of the
 * intended "エージェントへの..." text) got silently finalized as the human's
 * real answer, and the server process exited — permanently, since there is
 * no server left to receive the late reconnect.
 *
 * Two structural fixes close this:
 *   (A) A reload triggered by the app's own SSE "reload" event (file
 *       changed) never reports a /close at all — see
 *       intentional_reload_in_progress in app.mbt. No close means no timer
 *       is ever armed, so there's no race to lose for this trigger.
 *   (B) For any OTHER reload (manual F5, or a close that arrives before
 *       fix A's flag could apply), the server correlates a nearby index-page
 *       GET / with the close signal (looks_like_reload_in_flight in
 *       main.mbt) and grants exactly one 5s extension before finalizing —
 *       giving a slow reconnect real room to land instead of confirming a
 *       mid-typing snapshot on a fixed clock.
 *   Independently, question answers, the summary textarea, and comments now
 *   all persist to the SAME localStorage draft (persist_draft in app.mbt,
 *   generalized from the comments-only persist_comments), so even a
 *   genuinely-lost tab's typing survives a reload via the existing
 *   Restore/Discard recovery modal.
 *
 * This test also re-confirms the safety net's OWN reason to exist still
 * works: a tab that is truly closed (never reconnects) must still
 * auto-submit so an AI agent waiting on the verdict is never stuck forever.
 *
 * Run: node --experimental-strip-types v2/e2e/close_race_regression.ts
 */
import { spawn, type ChildProcess } from "node:child_process";
import { mkdtempSync, writeFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { chromium, type Browser } from "playwright";

const SERVER_JS = new URL(
  "../_build/js/release/build/server/server.js",
  import.meta.url,
).pathname;

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

function fixtureContent(rev: number): string {
  return [
    "---",
    "yunomi:",
    "  questions:",
    "    - id: q-freetext",
    "      question: AIエージェントへのコメント機能について自由にご記入ください",
    "---",
    "",
    "# close race regression fixture",
    "",
    `rev ${rev}`,
    "",
  ].join("\n");
}

/**
 * Two-question variant used by Scenario 2. q-other is deliberately never
 * interacted with, so it stays unanswered through the whole scenario. That
 * matters for the HIGH-1 fix under test elsewhere in this file: after
 * app.mbt's hide_recovery_modal() applies stored draft answers on Restore,
 * it only re-opens the questions modal when count_unanswered_questions() >
 * 0 (see app.mbt:1059-1069) — any non-empty text, even a mid-word partial
 * like "エージェ", already counts as "answered" per that count, so a
 * single-question fixture would leave the modal closed after Restore and
 * the (now hidden, per .yunomi-questions-overlay's display:none) q-freetext
 * textarea would not be a reachable target for Playwright's .fill() to
 * continue typing. Keeping q-other permanently unanswered is what makes
 * the questions modal genuinely reopen after Restore here, matching what a
 * real reviewer would see and letting the test reach the textarea the same
 * way a human would.
 */
function fixtureContentTwoQuestions(rev: number): string {
  return [
    "---",
    "yunomi:",
    "  questions:",
    "    - id: q-freetext",
    "      question: AIエージェントへのコメント機能について自由にご記入ください",
    "    - id: q-other",
    "      question: 他に確認したい点はありますか（このシナリオでは意図的に未回答のまま）",
    "---",
    "",
    "# close race regression fixture (scenario 2: two questions)",
    "",
    `rev ${rev}`,
    "",
  ].join("\n");
}

function startServer(
  mdPath: string,
  requestedPort: number,
  lockDir: string,
): Promise<{ proc: ChildProcess; getOutput: () => string; port: number }> {
  return new Promise((resolve, reject) => {
    const proc = spawn(
      process.execPath,
      [SERVER_JS, mdPath, "--no-open", "--port", String(requestedPort)],
      {
        env: { ...process.env, HERDR_PANE_ID: "", YUNOMI_NOTIFY_CMD: "", YUNOMI_LOCK_DIR: lockDir, YUNOMI_REVIEW_DIR: join(lockDir, "../reviews-" + Date.now()) },
        stdio: ["ignore", "pipe", "pipe"],
      },
    );
    let out = "";
    let resolved = false;
    proc.stdout!.on("data", (d: Buffer) => {
      out += String(d);
      if (!resolved) {
        // Parse the actual bound port from stdout rather than assuming the
        // requested port was free — a stale process (or a parallel test
        // run) can hold it, and the server picks the next available port
        // instead of failing. Hardcoding the requested port here caused
        // flaky failures when that happened.
        const match = out.match(/http:\/\/127\.0\.0\.1:(\d+)/);
        if (match) {
          resolved = true;
          resolve({ proc, getOutput: () => out, port: parseInt(match[1], 10) });
        }
      }
    });
    proc.stderr!.on("data", (d: Buffer) => {
      out += String(d);
    });
    proc.on("exit", (code) => {
      if (!resolved) {
        resolved = true;
        reject(new Error(`server exited before ready (code=${code})\n${out}`));
      }
    });
    setTimeout(() => {
      if (!resolved) reject(new Error(`server did not start:\n${out}`));
    }, 10000);
  });
}

/**
 * Poll server stdout/stderr for a log substring instead of guessing a sleep
 * duration relative to a timer's nominal delay — the actual timer callback
 * (Node event loop, GC pauses, CI contention) can fire measurably later
 * than its nominal delay, so a fixed-sleep check with a thin margin above
 * that nominal delay is inherently flaky. Observing the server's own log
 * line for the state transition under test removes that guesswork.
 */
function waitForLogLine(
  getOutput: () => string,
  pattern: string,
  timeoutMs: number,
): Promise<boolean> {
  return new Promise((resolve) => {
    const start = Date.now();
    const check = () => {
      if (getOutput().includes(pattern)) {
        resolve(true);
        return;
      }
      if (Date.now() - start >= timeoutMs) {
        resolve(false);
        return;
      }
      setTimeout(check, 100);
    };
    check();
  });
}

/**
 * Like waitForLogLine, but waits for `pattern` to appear at least `minCount`
 * times. Used for log lines (like "open file=") that legitimately recur
 * across the scenario, where a single-occurrence check would false-positive
 * on an earlier, unrelated occurrence of the same substring.
 */
function waitForLogCount(
  getOutput: () => string,
  pattern: string,
  minCount: number,
  timeoutMs: number,
): Promise<boolean> {
  return new Promise((resolve) => {
    const start = Date.now();
    const check = () => {
      const count = getOutput().split(pattern).length - 1;
      if (count >= minCount) {
        resolve(true);
        return;
      }
      if (Date.now() - start >= timeoutMs) {
        resolve(false);
        return;
      }
      setTimeout(check, 100);
    };
    check();
  });
}

function waitForExit(proc: ChildProcess): Promise<number | null> {
  return new Promise((resolve) => {
    if (proc.exitCode !== null) {
      resolve(proc.exitCode);
      return;
    }
    proc.once("exit", (code) => resolve(code));
  });
}

function killIfAlive(proc: ChildProcess): void {
  if (proc.exitCode === null && !proc.killed) proc.kill("SIGKILL");
}

async function scenarioSelfTriggeredReloadNeverCloses(
  browser: Browser,
  workDir: string,
  requestedPort: number,
): Promise<void> {
  console.log("\n--- Scenario 1: SSE-triggered reload (file changed) never reports /close ---");
  const mdPath = join(workDir, "s1.md");
  writeFileSync(mdPath, fixtureContent(1));
  const { proc, getOutput, port } = await startServer(
    mdPath,
    requestedPort,
    join(workDir, "locks1"),
  );
  try {
    const page = await browser.newPage();
    let closeRequestSeen = false;
    page.on("request", (req) => {
      if (req.url().includes("/close")) closeRequestSeen = true;
    });

    await page.goto(`http://127.0.0.1:${port}/`, { waitUntil: "domcontentloaded" });
    await page.waitForSelector("#yunomi-questions-overlay.visible", { timeout: 5000 });

    const FULL_ANSWER =
      "AIエージェントへのコメント機能はとても重要です。長文でも壊れず🎉最後まで反映されること。";
    await page.locator('.question-card[data-qid="q-freetext"] .q-answer').fill(FULL_ANSWER);

    const loadPromise = page.waitForEvent("load", { timeout: 15000 });
    // Change the reviewed file on disk — same trigger as an AI agent
    // live-editing REPORT.md while the human is mid-review. watch_file's
    // default poll interval can take a few seconds to notice.
    writeFileSync(mdPath, fixtureContent(2));
    await loadPromise;

    assert(!closeRequestSeen, "SSEリロード中は /close が一度も送られない", { closeRequestSeen });

    // task #19: an SSE self-triggered reload (this one) must restore the
    // draft SEAMLESSLY — no recovery-modal confirmation click required.
    // Requiring a manual click after EVERY file-change reload meant a
    // second reload arriving before the human clicked Restore could wipe
    // the freshly-reloaded (unrestored) DOM state again, which is exactly
    // what a real review session hit: the questions dialog appeared to
    // "flash and vanish" repeatedly. See check_recovery()'s doc comment.
    const recoveryModalNeverAppears = await page
      .waitForFunction(() => {
        const modal = document.querySelector("#recovery-modal");
        return !!modal && modal.classList.contains("visible");
      }, undefined, { timeout: 2000 })
      .then(() => false)
      .catch(() => true);
    assert(
      recoveryModalNeverAppears,
      "自己トリガーのSSEリロードでは復元確認モーダルを経由せず自動復元される（手動クリック不要）",
    );
    const restoredValue = await page
      .locator('.question-card[data-qid="q-freetext"] .q-answer')
      .inputValue();
    assert(
      restoredValue === FULL_ANSWER,
      "復元された回答がリロード前の全文と完全一致する（欠落・切り詰めなし、自動復元）",
      { restoredValue, expected: FULL_ANSWER },
    );
    const questionsOverlayVisible = await page
      .locator("#yunomi-questions-overlay")
      .evaluate((el) => el.classList.contains("visible"));
    assert(
      questionsOverlayVisible,
      "自動復元後、質問ステッパーが前面表示されたまま維持される（表示直後に自動で閉じない）",
    );
    // The human reviews the prefilled answer and closes the dialog
    // themselves (still fully answered — not blocked from proceeding).
    const closeBtn = page.locator("#yunomi-questions-close");
    if (await closeBtn.isVisible().catch(() => false)) {
      await closeBtn.click();
    }

    // Now perform the real, intentional submit and confirm the full text
    // (not a stale partial) reaches the verdict YAML.
    await page.locator("#send-and-exit").click();
    await page.waitForSelector("#submit-modal.visible", { timeout: 5000 });
    const exitPromise = waitForExit(proc);
    await page.locator("#modal-request-changes").click();
    const exitCode = await exitPromise;
    assert(exitCode === 0, "本物のSubmit後にサーバーが正常終了する", { exitCode });

    const output = getOutput();
    // Safe as a single-line `/m` match because `answers` is a JSON string
    // (embedded newlines already encoded as literal `\n`) before
    // yaml_escape_string() quotes it — see questions_answers.ts for the
    // full explanation.
    const match = output.match(/^answers: '(.*)'$/m);
    const answersRaw = match ? match[1].replace(/''/g, "'") : "";
    let parsed: Record<string, string> = {};
    try {
      parsed = JSON.parse(answersRaw);
    } catch {
      /* assertion below will fail with detail */
    }
    assert(
      parsed["q-freetext"] === FULL_ANSWER,
      "verdict YAMLのanswersに全文が欠落なく出力される",
      { got: parsed["q-freetext"], expected: FULL_ANSWER },
    );

    await page.close();
  } finally {
    killIfAlive(proc);
  }
}

async function scenarioDelayedReconnectDoesNotLoseTypedAnswer(
  browser: Browser,
  workDir: string,
  requestedPort: number,
): Promise<void> {
  console.log(
    "\n--- Scenario 2: generic reload (not SSE-triggered) with a slow /session/open reconnect must not finalize the stale partial draft ---",
  );
  const mdPath = join(workDir, "s2.md");
  writeFileSync(mdPath, fixtureContentTwoQuestions(1));
  const { proc, getOutput, port } = await startServer(
    mdPath,
    requestedPort,
    join(workDir, "locks2"),
  );
  try {
    const page = await browser.newPage();

    let sessionOpenCount = 0;
    await page.route("**/session/open", async (route) => {
      sessionOpenCount++;
      if (sessionOpenCount === 1) {
        await route.continue();
        return;
      }
      // Simulate a slow reconnect: well past the base 5s window, but
      // within fix B's single 5s extension budget.
      await new Promise((r) => setTimeout(r, 6000));
      await route.continue().catch(() => {});
    });

    await page.goto(`http://127.0.0.1:${port}/`, { waitUntil: "domcontentloaded" });
    await page.waitForSelector("#yunomi-questions-overlay.visible", { timeout: 5000 });

    const PARTIAL = "エージェ";
    const REST = "ントへのコメント機能について、これは完成した回答です。";
    const FULL = PARTIAL + REST;
    const answerBox = page.locator('.question-card[data-qid="q-freetext"] .q-answer');
    await answerBox.fill(PARTIAL);

    await page.evaluate(() => location.reload());

    // Instead of sleeping a fixed duration timed relative to the base
    // 5000ms window (a thin, flaky margin under CI load), observe the
    // server's own "deferring close submit" log line — main.mbt logs this
    // exactly when the base timer fires AND looks_like_reload_in_flight()
    // grants the one-time extension. This directly proves the extension
    // fired, rather than inferring it from elapsed wall-clock time.
    const extended = await waitForLogLine(getOutput, "deferring close submit", 8000);
    assert(
      extended,
      "リロード検知によりcloseの確定が延長される（サーバーログ 'deferring close submit' を観測）",
      { outputTail: getOutput().slice(-1000) },
    );
    assert(
      proc.exitCode === null,
      "延長ログ観測の直後もサーバーはまだ生きている＝中途半端な下書きを確定していない",
      { exitCode: proc.exitCode },
    );
    assert(
      !getOutput().includes("auto submit after last tab close"),
      "この時点で自動Submitは発火していない",
    );

    // Let the delayed /session/open (6000ms route delay) land. Note:
    // handle_session_open (main.mbt) calls cancel_pending_close() — a
    // direct clearTimeout(), logging nothing — BEFORE the extended timer
    // ever gets a chance to fire and log "cancel close submit"; that log
    // line only fires from inside the timer callback itself, which is a
    // race this proactive cancel wins in practice. So the reliable signal
    // for "the delayed reconnect landed" is the SECOND "open file=" log
    // line (the first is the initial page load) rather than a log line
    // that in practice never gets a chance to appear on this path.
    const reconnected = await waitForLogCount(getOutput, "open file=", 2, 8000);
    assert(
      reconnected,
      "遅延reconnectが着地する（2回目の 'open file=' ログを観測＝cancel_pending_close()で延長タイマーが黙ってキャンセルされる）",
      { outputTail: getOutput().slice(-1000) },
    );
    assert(
      proc.exitCode === null,
      "遅延reconnect着地後もサーバーは生きている（自動Submitされていない）",
      { exitCode: proc.exitCode },
    );

    // The reloaded page should show the recovery modal with the PARTIAL
    // draft (persisted live while typing, independent of the close path).
    const recovered = await page
      .waitForFunction(() => {
        const modal = document.querySelector("#recovery-modal");
        return !!modal && modal.classList.contains("visible");
      }, undefined, { timeout: 5000 })
      .then(() => true)
      .catch(() => false);
    assert(recovered, "reconnect後、復元モーダルが表示される");
    if (recovered) {
      await page.locator("#recovery-restore").click();
      await page.waitForTimeout(200);
      const restoredValue = await page
        .locator('.question-card[data-qid="q-freetext"] .q-answer')
        .inputValue();
      assert(restoredValue === PARTIAL, "復元された下書きはリロード直前の部分入力と一致する", {
        restoredValue,
        expected: PARTIAL,
      });
      // The human continues typing the rest and does the REAL submit.
      await page.locator('.question-card[data-qid="q-freetext"] .q-answer').fill(FULL);
      // q-other is deliberately left unanswered (see
      // fixtureContentTwoQuestions), so the modal does not auto-close on
      // its own here — close it explicitly, same as a human clicking away
      // from a question they're intentionally skipping, so the overlay
      // stops intercepting clicks on the Submit button underneath.
      const closeBtn = page.locator("#yunomi-questions-close");
      if (await closeBtn.isVisible().catch(() => false)) {
        await closeBtn.click();
      }
    }

    await page.locator("#send-and-exit").click();
    await page.waitForSelector("#submit-modal.visible", { timeout: 5000 });
    const exitPromise = waitForExit(proc);
    await page.locator("#modal-approve").click();
    const exitCode = await exitPromise;
    assert(exitCode === 0, "本物のSubmit後にサーバーが正常終了する", { exitCode });

    const output = getOutput();
    // Safe as a single-line `/m` match because `answers` is a JSON string
    // (embedded newlines already encoded as literal `\n`) before
    // yaml_escape_string() quotes it — see questions_answers.ts for the
    // full explanation.
    const match = output.match(/^answers: '(.*)'$/m);
    const answersRaw = match ? match[1].replace(/''/g, "'") : "";
    let parsed: Record<string, string> = {};
    try {
      parsed = JSON.parse(answersRaw);
    } catch {
      /* assertion below fails with detail */
    }
    assert(
      parsed["q-freetext"] === FULL,
      "最終verdictには継続入力した完全な回答が反映される（途中経過の部分文字列ではない）",
      { got: parsed["q-freetext"], expected: FULL },
    );

    await page.close();
  } finally {
    killIfAlive(proc);
  }
}

async function scenarioGenuineAbandonmentStillAutoSubmits(
  browser: Browser,
  workDir: string,
  requestedPort: number,
): Promise<void> {
  console.log(
    "\n--- Scenario 3 (regression guard): a genuinely-abandoned tab (no reconnect ever) still auto-submits within the base window ---",
  );
  const mdPath = join(workDir, "s3.md");
  writeFileSync(mdPath, fixtureContent(1));
  const { proc, getOutput, port } = await startServer(
    mdPath,
    requestedPort,
    join(workDir, "locks3"),
  );
  try {
    const context = await browser.newContext();
    const page = await context.newPage();
    await page.goto(`http://127.0.0.1:${port}/`, { waitUntil: "domcontentloaded" });
    await page.waitForSelector("#yunomi-questions-overlay.visible", { timeout: 5000 });

    const ABANDONED_TEXT = "レビュー中に離脱した内容";
    await page
      .locator('.question-card[data-qid="q-freetext"] .q-answer')
      .fill(ABANDONED_TEXT);

    // A real user reviews for at least a few seconds before abandoning —
    // wait past the reload-correlation window so this close is NOT mistaken
    // for a reload-in-flight (which would legitimately grant one 5s
    // extension; that path is already covered by Scenario 2).
    await page.waitForTimeout(4000);

    const exitPromise = waitForExit(proc);
    // Headless Chromium's context.close()/page.close() tear the renderer
    // down WITHOUT running pagehide/beforeunload handlers (verified: no
    // /close request is ever observed that way), unlike a real browser tab
    // close. A real cross-origin navigation away DOES fire them reliably,
    // so use that as the faithful way to trigger the close beacon in this
    // headless test harness — the server-side code under test only cares
    // that pagehide/beforeunload fired, not why.
    await page.goto("about:blank").catch(() => {});

    const exitCode = await Promise.race([
      exitPromise,
      new Promise<null>((r) => setTimeout(() => r(null), 8000)),
    ]);
    assert(
      exitCode === 0,
      "本当に放棄されたタブは基本の待機窓（約5秒、延長なし）以内に自動Submitでサーバーが終了する",
      { exitCode },
    );
    const output = getOutput();
    assert(
      !output.includes("deferring close submit"),
      "リロードのシグナルが無いため延長ロジックは発火しない（放棄検知が遅くならない）",
    );
    // Safe as a single-line `/m` match because `answers` is a JSON string
    // (embedded newlines already encoded as literal `\n`) before
    // yaml_escape_string() quotes it — see questions_answers.ts for the
    // full explanation.
    const match = output.match(/^answers: '(.*)'$/m);
    const answersRaw = match ? match[1].replace(/''/g, "'") : "";
    let parsed: Record<string, string> = {};
    try {
      parsed = JSON.parse(answersRaw);
    } catch {
      /* assertion below fails with detail */
    }
    assert(
      parsed["q-freetext"] === ABANDONED_TEXT,
      "自動Submitされた内容は離脱直前のドラフトと一致する（安全網としての既存挙動維持）",
      { got: parsed["q-freetext"], expected: ABANDONED_TEXT },
    );
    await context.close().catch(() => {});
  } finally {
    killIfAlive(proc);
  }
}

async function scenarioRecoveryDiscardReopensQuestionsModal(
  browser: Browser,
  workDir: string,
  requestedPort: number,
): Promise<void> {
  console.log(
    "\n--- Scenario 4 (HIGH-1 regression guard): deciding Discard on the recovery modal after the 500ms auto-popup window still re-opens the questions modal ---",
  );
  const mdPath = join(workDir, "s4.md");
  writeFileSync(mdPath, fixtureContent(1));
  const { proc, getOutput, port } = await startServer(
    mdPath,
    requestedPort,
    join(workDir, "locks4"),
  );
  try {
    const context = await browser.newContext();
    const page = await context.newPage();
    await page.goto(`http://127.0.0.1:${port}/`, { waitUntil: "domcontentloaded" });
    await page.waitForSelector("#yunomi-questions-overlay.visible", { timeout: 5000 });

    // Type a partial answer (persist_draft fires on the "input" event via
    // setup_questions_ui's `.q-answer` listener) then close the questions
    // modal without submitting, leaving a draft in localStorage for the
    // next load to recover.
    await page
      .locator('.question-card[data-qid="q-freetext"] .q-answer')
      .fill("下書き途中の回答");
    const closeBtn = page.locator("#yunomi-questions-close");
    if (await closeBtn.isVisible().catch(() => false)) {
      await closeBtn.click();
    }
    await page.waitForTimeout(200);

    // A real cross-origin navigation (not context/page.close()) reliably
    // fires pagehide/beforeunload in headless Chromium — see Scenario 3's
    // comment for why this matters here.
    await page.goto("about:blank").catch(() => {});
    await page.waitForTimeout(200);

    // Fresh load: check_recovery() shows the recovery modal synchronously
    // (app.mbt:987-1002), and setup_questions_ui()'s auto-popup (500ms
    // after init) must see it still visible and skip opening the questions
    // modal underneath it. That is the exact setup for the HIGH-1
    // regression: without hide_recovery_modal() doing its own re-check
    // (app.mbt:1059-1069), the questions modal would never auto-open again
    // once the human takes longer than 500ms to decide Restore/Discard.
    await page.goto(`http://127.0.0.1:${port}/`, { waitUntil: "domcontentloaded" });
    const recoveryVisible = await page
      .waitForFunction(() => {
        const modal = document.querySelector("#recovery-modal");
        return !!modal && modal.classList.contains("visible");
      }, undefined, { timeout: 5000 })
      .then(() => true)
      .catch(() => false);
    assert(recoveryVisible, "再訪問時に復元モーダルが表示される");

    // Wait comfortably past the 500ms auto-popup window before deciding —
    // this is the exact human behavior that triggered the regression.
    await page.waitForTimeout(1000);
    const questionsVisibleBeforeDecision = await page
      .locator("#yunomi-questions-overlay")
      .evaluate((el) => el.classList.contains("visible"));
    assert(
      !questionsVisibleBeforeDecision,
      "1秒待った時点ではまだ質問モーダルは自動で開いていない（復元モーダルの後ろに隠れて二重表示されない）",
    );

    await page.locator("#recovery-discard").click();

    const questionsReopened = await page
      .waitForFunction(() => {
        const overlay = document.querySelector("#yunomi-questions-overlay");
        return !!overlay && overlay.classList.contains("visible");
      }, undefined, { timeout: 3000 })
      .then(() => true)
      .catch(() => false);
    assert(
      questionsReopened,
      "HIGH-1修正確認: Discard後、未回答の質問が残っているため質問モーダルが自動で再オープンする",
    );

    await page.close();
    await context.close().catch(() => {});
  } finally {
    killIfAlive(proc);
  }
}

async function main(): Promise<void> {
  const workDir = mkdtempSync(join(tmpdir(), "yunomi-close-race-regression-"));
  const browser = await chromium.launch();
  try {
    await scenarioSelfTriggeredReloadNeverCloses(browser, workDir, 5941);
    await scenarioDelayedReconnectDoesNotLoseTypedAnswer(browser, workDir, 5942);
    await scenarioGenuineAbandonmentStillAutoSubmits(browser, workDir, 5943);
    await scenarioRecoveryDiscardReopensQuestionsModal(browser, workDir, 5944);
  } finally {
    await browser.close();
    rmSync(workDir, { recursive: true, force: true });
  }

  console.log(`\nResults: ${failed === 0 ? "all passed" : failed + " failed"}`);
  if (failed > 0) process.exitCode = 1;
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});
