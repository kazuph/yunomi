/**
 * Closing, navigating, and reloading must never finalize a review.
 * Drafts stay in localStorage and the server exits only after an explicit
 * action in the Submit Review dialog reaches POST /exit.
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
const SERVER_START_TIMEOUT_MS = 10_000;
const SLOW_RECONNECT_DELAY_MS = 6_000;

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
    }, SERVER_START_TIMEOUT_MS);
  });
}

/**
 * Wait for a recurring server log without a fixed client-boot delay.
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

    // Change the reviewed file on disk — same trigger as an AI agent
    // live-editing REPORT.md while the human is mid-review. watch_file's
    // default poll interval can take a few seconds to notice. The preview is
    // patched in place; no navigation happens.
    let loads = 0;
    page.on("load", () => (loads += 1));
    writeFileSync(mdPath, fixtureContent(2));
    await page.waitForFunction(() => (window as any).__YUNOMI_QUIET_REFRESH_COUNT__ === 1, undefined, { timeout: 15000 });
    assert(loads === 0, "ファイル更新はその場のプレビュー差し替えで処理され、ページ遷移しない", { loads });

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
    "\n--- Scenario 2: generic reload with a slow /session/open reconnect keeps the draft local and the server alive ---",
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
      // Simulate a slow client boot. Closing never starts a submit deadline,
      // so the reconnect may take arbitrarily longer than the former 5s timer.
      await new Promise((r) => setTimeout(r, SLOW_RECONNECT_DELAY_MS));
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

    // Let the delayed /session/open land. The second open log is the direct
    // signal that the reloaded client finished booting.
    const reconnected = await waitForLogCount(
      getOutput,
      "open file=",
      2,
      SLOW_RECONNECT_DELAY_MS + SERVER_START_TIMEOUT_MS,
    );
    assert(
      reconnected,
      "6秒遅延したreconnectが着地する（2回目の 'open file=' ログを観測）",
      { outputTail: getOutput().slice(-1000) },
    );
    assert(
      proc.exitCode === null,
      "遅延reconnect着地後もサーバーは生きている",
      { exitCode: proc.exitCode },
    );
    assert(!/^action:/m.test(getOutput()), "リロードではverdictも通知も生成されない");

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

async function scenarioTabCloseWaitsForExplicitSubmit(
  browser: Browser,
  workDir: string,
  requestedPort: number,
): Promise<void> {
  console.log(
    "\n--- Scenario 3: closing the last tab preserves the draft and waits for explicit Submit Review ---",
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

    // Headless Chromium's context.close()/page.close() tear the renderer
    // down WITHOUT running pagehide/beforeunload handlers (verified: no
    // /close request is ever observed that way), unlike a real browser tab
    // close. A real cross-origin navigation away DOES fire them reliably,
    // so use that as the faithful way to trigger the close beacon in this
    // headless test harness — the server-side code under test only cares
    // that pagehide/beforeunload fired, not why.
    await page.goto("about:blank").catch(() => {});

    await new Promise((resolve) => setTimeout(resolve, 5500));
    const health = await fetch(`http://127.0.0.1:${port}/healthz`);
    assert(
      proc.exitCode === null && health.status === 200,
      "最後のタブを閉じて旧5秒タイマーを越えてもサーバーは待機を続ける",
      { exitCode: proc.exitCode, health: health.status },
    );
    const output = getOutput();
    assert(!/^action:/m.test(output), "タブcloseだけではverdictも通知も生成されない");

    await page.goto(`http://127.0.0.1:${port}/`, { waitUntil: "domcontentloaded" });
    await page.waitForSelector("#recovery-modal.visible", { timeout: 5000 });
    await page.locator("#recovery-restore").click();
    const restored = await page.locator('.question-card[data-qid="q-freetext"] .q-answer').inputValue();
    assert(restored === ABANDONED_TEXT, "close前の下書きは再訪時に復元できる", { restored });
    // The questions overlay intercepts pointer events while it is visible;
    // dismiss it and wait for it to actually hide before pressing Submit.
    const overlay = page.locator("#yunomi-questions-overlay");
    if (await overlay.evaluate((el) => el.classList.contains("visible")).catch(() => false)) {
      await page.locator("#yunomi-questions-close").click();
      await page.waitForSelector("#yunomi-questions-overlay.visible", { state: "hidden", timeout: 5000 });
    }
    await page.locator("#send-and-exit").click();
    await page.waitForSelector("#submit-modal.visible", { timeout: 5000 });
    const exitPromise = waitForExit(proc);
    await page.locator("#modal-request-changes").click();
    const exitCode = await exitPromise;
    assert(exitCode === 0, "明示Submit Review操作でのみサーバーが終了する", { exitCode });
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
    await scenarioTabCloseWaitsForExplicitSubmit(browser, workDir, 5943);
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
