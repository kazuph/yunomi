/**
 * E2E regression for task #21 — a real re-review session answered all 3
 * questions in a REPORT.md, clicked "完了" on the last one, and the modal
 * just vanished with zero feedback:
 *
 *   "あれ、今全部回答できた？ 3つ目を回答した瞬間に消えたので、分からず。
 *    最悪のUX。"
 *
 * Root cause #1 (the actual UX gap): clicking "完了" on the last question
 * called close_questions_modal() directly — there was no confirmation step,
 * so a human had no way to see "yes, all 3 answers were recorded" before
 * the dialog disappeared.
 *
 * Root cause #2 (found by reproducing the fix with Playwright, not
 * guessed): update_questions_count() — wired to every option-click and
 * textarea "input" event — scheduled an unconditional close_questions_modal()
 * 500ms after the DOM state alone showed every question answered, with NO
 * awareness of the new summary screen. Filling in the last question's
 * answer (an "input" event, independent of ever clicking Next/完了) armed
 * this timer; ~500ms later it fired and force-closed the modal regardless
 * of whether the human had since navigated to the summary confirmation
 * screen or back to edit an earlier answer — completely defeating the
 * point of the new confirmation step. Fixed by removing the timer-based
 * auto-close entirely: closing the modal is now owned exclusively by the
 * explicit Next/完了/確定して閉じる button flow (advance_question_step())
 * and the X/Later/backdrop/ESC escape hatches — never by a side effect of
 * mere DOM mutation.
 *
 * The fix: clicking "完了" on the last question now opens an answer-summary
 * confirmation screen (question_step_index === card count, the stepper's
 * "virtual last step + 1") listing every question's current answer, with:
 *   - a "戻る" affordance (the Later button relabeled) and per-item click
 *     navigation back to that question for editing,
 *   - a "確定して閉じる" primary action that actually closes and briefly
 *     flashes the floating pill in a "done" state (check icon, N/N badge)
 *     as minimal, concrete feedback that the review was recorded.
 *
 * Run: node --experimental-strip-types e2e/questions_answer_summary_regression.ts
 */
import { spawn, type ChildProcess } from "node:child_process";
import { mkdirSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { chromium, type Browser } from "playwright";

const SERVER_JS = new URL(
  "../_build/js/release/build/server/server.js",
  import.meta.url,
).pathname;
const BASE_PORT = 5680;
const FIXTURE_MD = new URL("../../examples/questions-answers.md", import.meta.url).pathname;
const LOCK_DIR = join(tmpdir(), "yunomi-questions-answer-summary-locks");
mkdirSync(LOCK_DIR, { recursive: true });

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

type ServerHandle = { proc: ChildProcess; port: number };

function startServer(): Promise<ServerHandle> {
  return new Promise((resolve, reject) => {
    const proc = spawn(
      process.execPath,
      [SERVER_JS, FIXTURE_MD, "--no-open", "--port", String(BASE_PORT)],
      {
        cwd: new URL("..", import.meta.url).pathname,
        env: { ...process.env, HERDR_PANE_ID: "", YUNOMI_NOTIFY_CMD: "", YUNOMI_LOCK_DIR: LOCK_DIR, YUNOMI_REVIEW_DIR: join(tmpdir(), "yunomi-review-" + Date.now() + "-" + Math.random().toString(36).slice(2,6)) },
        stdio: ["ignore", "pipe", "pipe"],
      },
    );
    let out = "";
    let resolved = false;
    proc.stdout!.on("data", (d: Buffer) => {
      out += String(d);
      if (!resolved) {
        const m = out.match(/http:\/\/127\.0\.0\.1:(\d+)/);
        if (m) {
          resolved = true;
          resolve({ proc, port: parseInt(m[1], 10) });
        }
      }
    });
    proc.stderr!.on("data", (d: Buffer) => (out += String(d)));
    proc.on("exit", (code) => {
      if (!resolved) reject(new Error(`server exited before ready (${code})\n${out}`));
    });
  });
}

function killIfAlive(proc: ChildProcess): void {
  if (!proc.killed) proc.kill();
}

async function scenarioSummaryShownInsteadOfVanishing(browser: Browser): Promise<void> {
  console.log(
    "\n--- Scenario (a): completing the last question shows a summary confirmation, not a silent close ---",
  );
  const { proc, port } = await startServer();
  try {
    const page = await browser.newPage({ viewport: { width: 1280, height: 900 } });
    await page.goto(`http://127.0.0.1:${port}/`, { waitUntil: "domcontentloaded" });
    await page.waitForSelector("#yunomi-questions-overlay.visible", { timeout: 5000 });

    await page.locator('.question-card[data-qid="q1-option"] .q-option-btn').first().click();
    await page.locator("#yunomi-questions-next").click();

    await page.waitForSelector('.question-card[data-qid="q2-freetext"].step-active');
    const FREETEXT_ANSWER = "コメント機能はとても重要だと思います。";
    await page.locator('.question-card[data-qid="q2-freetext"] .q-answer').fill(FREETEXT_ANSWER);
    const nextLabelOnLast = await page.locator("#yunomi-questions-next").textContent();
    assertTrue(nextLabelOnLast === "完了", "最終問のNextボタンは「完了」ラベル", {
      nextLabelOnLast,
    });
    await page.locator("#yunomi-questions-next").click();

    // Give the (now-removed) 500ms auto-close timer time to have fired if
    // it still existed — the whole point of this wait is to prove it does
    // NOT silently close the summary screen.
    await page.waitForTimeout(800);

    const overlayVisible = await page
      .locator("#yunomi-questions-overlay")
      .evaluate((el) => el.classList.contains("visible"));
    assertTrue(overlayVisible, "「完了」クリック後もダイアログは消えず開いたままである", {
      overlayVisible,
    });
    const summaryActive = await page
      .locator("#yunomi-questions-body")
      .evaluate((el) => el.classList.contains("summary-active"));
    assertTrue(summaryActive, "回答サマリ確認画面に遷移している");
    const summaryTexts = await page.locator(".q-summary-item").allTextContents();
    assertTrue(summaryTexts.length === 2, "サマリに2問分の項目が表示される", { summaryTexts });
    assertTrue(
      summaryTexts.some((t) => t.includes(FREETEXT_ANSWER)),
      "サマリの自由記述項目に入力した全文がそのまま表示される（欠落なし）",
      { summaryTexts },
    );
    const nextLabel = await page.locator("#yunomi-questions-next").textContent();
    assertTrue(nextLabel === "確定して閉じる", "サマリ画面のNextボタンは「確定して閉じる」ラベル", {
      nextLabel,
    });
    const laterLabel = await page.locator("#yunomi-questions-later").textContent();
    assertTrue(laterLabel === "戻る", "サマリ画面のLaterボタンは「戻る」ラベルに切り替わる", {
      laterLabel,
    });

    await page.close();
  } finally {
    killIfAlive(proc);
  }
}

async function scenarioBackNavigationEditsAnAnswer(browser: Browser): Promise<void> {
  console.log(
    "\n--- Scenario (b): clicking a summary item jumps back to that question, preserving the edit ---",
  );
  const { proc, port } = await startServer();
  try {
    const page = await browser.newPage({ viewport: { width: 1280, height: 900 } });
    await page.goto(`http://127.0.0.1:${port}/`, { waitUntil: "domcontentloaded" });
    await page.waitForSelector("#yunomi-questions-overlay.visible", { timeout: 5000 });

    await page.locator('.question-card[data-qid="q1-option"] .q-option-btn').first().click();
    await page.locator("#yunomi-questions-next").click();
    await page.waitForSelector('.question-card[data-qid="q2-freetext"].step-active');
    await page.locator('.question-card[data-qid="q2-freetext"] .q-answer').fill("最初の回答");
    await page.locator("#yunomi-questions-next").click();
    await page.waitForSelector(".q-summary-item");

    // Jump back to question 2 (index 1) via the summary item.
    await page.locator('.q-summary-item[data-step="1"]').click();
    await page.waitForTimeout(150);
    const onQ2 = await page
      .locator('.question-card[data-qid="q2-freetext"]')
      .evaluate((el) => el.classList.contains("step-active"));
    assertTrue(onQ2, "サマリ項目クリックで該当の質問ステップに戻る");
    const summaryGoneWhileEditing = await page
      .locator("#yunomi-questions-body")
      .evaluate((el) => !el.classList.contains("summary-active"));
    assertTrue(summaryGoneWhileEditing, "編集中はサマリ画面が引っ込む（.summary-activeが外れる）");

    // Edit the answer, then re-advance to the summary and confirm the edit stuck.
    await page.locator('.question-card[data-qid="q2-freetext"] .q-answer').fill("修正後の回答");
    await page.locator("#yunomi-questions-next").click();
    await page.waitForSelector(".q-summary-item");
    const summaryTexts = await page.locator(".q-summary-item").allTextContents();
    assertTrue(
      summaryTexts.some((t) => t.includes("修正後の回答")) &&
        !summaryTexts.some((t) => t.includes("最初の回答")),
      "サマリ画面に戻った後の回答が編集後の内容に更新されている",
      { summaryTexts },
    );

    await page.close();
  } finally {
    killIfAlive(proc);
  }
}

async function scenarioConfirmClosesAndFlashesPill(browser: Browser): Promise<void> {
  console.log(
    "\n--- Scenario (c): 確定して閉じる actually closes the modal and briefly flashes the pill as done ---",
  );
  const { proc, port } = await startServer();
  try {
    const page = await browser.newPage({ viewport: { width: 1280, height: 900 } });
    await page.goto(`http://127.0.0.1:${port}/`, { waitUntil: "domcontentloaded" });
    await page.waitForSelector("#yunomi-questions-overlay.visible", { timeout: 5000 });

    await page.locator('.question-card[data-qid="q1-option"] .q-option-btn').first().click();
    await page.locator("#yunomi-questions-next").click();
    await page.waitForSelector('.question-card[data-qid="q2-freetext"].step-active');
    await page.locator('.question-card[data-qid="q2-freetext"] .q-answer').fill("回答2");
    await page.locator("#yunomi-questions-next").click();
    await page.waitForSelector(".q-summary-item");

    await page.locator("#yunomi-questions-next").click(); // 確定して閉じる
    await page.waitForTimeout(200);

    const overlayVisible = await page
      .locator("#yunomi-questions-overlay")
      .evaluate((el) => el.classList.contains("visible"));
    assertTrue(!overlayVisible, "確定して閉じるクリックでダイアログが実際に閉じる");
    const pillDone = await page
      .locator("#yunomi-questions-bar-open")
      .evaluate((el) => el.classList.contains("done") && el.classList.contains("visible"));
    assertTrue(pillDone, "確定直後、ピルが「回答済み」状態でフラッシュ表示される");
    const pillCount = await page.locator("#yunomi-questions-bar-count").textContent();
    assertTrue(pillCount === "2/2", "フラッシュ中のピルは「N/N」形式のバッジを表示する", {
      pillCount,
    });

    // Wait past the flash window — the pill should revert (nothing left
    // unanswered, so it hides again) instead of staying stuck in "done".
    await page.waitForTimeout(2700);
    const pillDoneAfter = await page
      .locator("#yunomi-questions-bar-open")
      .evaluate((el) => el.classList.contains("done"));
    const pillVisibleAfter = await page
      .locator("#yunomi-questions-bar-open")
      .evaluate((el) => el.classList.contains("visible"));
    assertTrue(!pillDoneAfter, "フラッシュ後、ピルの done 状態が解除される");
    assertTrue(!pillVisibleAfter, "全問回答済みのため、フラッシュ後ピルは再び隠れる");

    await page.close();
  } finally {
    killIfAlive(proc);
  }
}

async function scenarioLaterAbandonSkipsSummary(browser: Browser): Promise<void> {
  console.log(
    "\n--- Scenario (d): abandoning mid-way via 後で回答する never shows the summary, and reopening resumes correctly ---",
  );
  const { proc, port } = await startServer();
  try {
    const page = await browser.newPage({ viewport: { width: 1280, height: 900 } });
    await page.goto(`http://127.0.0.1:${port}/`, { waitUntil: "domcontentloaded" });
    await page.waitForSelector("#yunomi-questions-overlay.visible", { timeout: 5000 });

    await page.locator('.question-card[data-qid="q1-option"] .q-option-btn').first().click();
    await page.locator("#yunomi-questions-next").click();
    await page.waitForSelector('.question-card[data-qid="q2-freetext"].step-active');

    const laterLabel = await page.locator("#yunomi-questions-later").textContent();
    assertTrue(laterLabel === "後で回答する", "質問未完了の間はLaterボタンが「後で回答する」のまま", {
      laterLabel,
    });
    await page.locator("#yunomi-questions-later").click();
    await page.waitForTimeout(300);

    const overlayVisible = await page
      .locator("#yunomi-questions-overlay")
      .evaluate((el) => el.classList.contains("visible"));
    assertTrue(!overlayVisible, "後で回答するクリックで即座に閉じる（サマリを経由しない）");
    const pillDone = await page
      .locator("#yunomi-questions-bar-open")
      .evaluate((el) => el.classList.contains("done"));
    assertTrue(!pillDone, "途中終了のクローズでは「回答済み」フラッシュは出ない");

    await page.locator("#yunomi-questions-bar-open").click();
    await page.waitForTimeout(150);
    const resumedOnQ2 = await page
      .locator('.question-card[data-qid="q2-freetext"]')
      .evaluate((el) => el.classList.contains("step-active"));
    assertTrue(resumedOnQ2, "ピルから再度開くと未回答だった質問(2問目)から再開する（サマリではない）");
    const summaryActiveOnReopen = await page
      .locator("#yunomi-questions-body")
      .evaluate((el) => el.classList.contains("summary-active"));
    assertTrue(!summaryActiveOnReopen, "再開時にサマリ画面は表示されない");

    await page.close();
  } finally {
    killIfAlive(proc);
  }
}

async function main(): Promise<void> {
  const browser = await chromium.launch();
  try {
    await scenarioSummaryShownInsteadOfVanishing(browser);
    await scenarioBackNavigationEditsAnAnswer(browser);
    await scenarioConfirmClosesAndFlashesPill(browser);
    await scenarioLaterAbandonSkipsSummary(browser);
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
