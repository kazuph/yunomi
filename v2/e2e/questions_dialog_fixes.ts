/**
 * E2E regression for three bugs found in a real re-review of the
 * questions-stepper redesign (see task #18):
 *
 *   1. Clicking a decision in the Submit Review dialog (Approve / Request
 *      Changes) appeared to do nothing — the dialog never closed. Root
 *      cause: handle_submit() (main.mbt) called exit_process() ->
 *      process.exit() synchronously, before the /exit POST handler ever
 *      got to write the HTTP response, so the browser's fetch() saw
 *      net::ERR_EMPTY_RESPONSE / net::ERR_INCOMPLETE_CHUNKED_ENCODING and
 *      the client-side success callback (which hides the dialog and closes
 *      the tab) never ran. Fixed by deferring exit_process() until the
 *      response's "finish" event.
 *
 *   2. The floating unanswered-questions pill (top-right) visually and
 *      functionally overlapped the header's "Submit & Exit" button — a
 *      click meant for Submit & Exit could land on the pill instead,
 *      reopening the questions modal instead of opening Submit Review.
 *      Fixed by moving the pill to the bottom-left corner, away from every
 *      other fixed-position UI element.
 *
 *   3. "気がついたら回答する" (stumble on it eventually) was too weak a
 *      discovery path: if a prior round's draft already filled in every
 *      question, the modal never auto-opened on load at all — the human
 *      had zero visual indication a question even existed. Fixed by
 *      switching hide_recovery_modal()'s reopen decision from "is anything
 *      still blank" (dynamic) to "does an unresolved question exist at all"
 *      (static) — an unresolved question must always surface on load,
 *      prefilled or not.
 *
 * Run: node --experimental-strip-types e2e/questions_dialog_fixes.ts
 */
import { spawn, type ChildProcess } from "node:child_process";
import { mkdirSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { chromium, type Browser, type Page } from "playwright";

const SERVER_JS = new URL(
  "../_build/js/release/build/server/server.js",
  import.meta.url,
).pathname;
const FIXTURE_MD = new URL("../../examples/questions-answers.md", import.meta.url).pathname;
const LOCK_DIR = join(tmpdir(), "yunomi-questions-dialog-fixes-locks");
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

type ServerHandle = { proc: ChildProcess; getOutput: () => string; port: number };

function startServer(port: number): Promise<ServerHandle> {
  return new Promise((resolve, reject) => {
    const proc = spawn(
      process.execPath,
      [SERVER_JS, FIXTURE_MD, "--no-open", "--port", String(port)],
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

function waitForExit(proc: ChildProcess): Promise<number | null> {
  return new Promise((resolve) => {
    if (proc.exitCode !== null) {
      resolve(proc.exitCode);
      return;
    }
    proc.once("exit", (code) => resolve(code));
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

function rectsIntersect(a: DOMRectLike, b: DOMRectLike): boolean {
  return !(a.x + a.width <= b.x || b.x + b.width <= a.x || a.y + a.height <= b.y || b.y + b.height <= a.y);
}
type DOMRectLike = { x: number; y: number; width: number; height: number };

async function freshPage(browser: Browser, port: number): Promise<Page> {
  const page = await browser.newPage({ viewport: { width: 1280, height: 900 } });
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

/** Bug (a): Submit Review dialog must actually close and the server exit. */
async function scenarioSubmitDialogCloses(browser: Browser): Promise<void> {
  console.log("\n--- Scenario (a): Submit Review dialog closes after a decision, server exits cleanly ---");
  const { proc, port } = await startServer(5440);
  try {
    await waitHealth(port);
    const page = await freshPage(browser, port);
    await page.waitForSelector("#yunomi-questions-overlay.visible", { timeout: 5000 });

    const closeBtn = page.locator("#yunomi-questions-close");
    if (await closeBtn.isVisible().catch(() => false)) await closeBtn.click();

    await page.locator("#send-and-exit").click();
    await page.waitForSelector("#submit-modal.visible", { timeout: 5000 });

    // Watch the actual /exit network response so we can tell "server never
    // answered" (the original bug) apart from "answered, but UI didn't
    // react" (a different bug) if this ever regresses again.
    const exitResponsePromise = page
      .waitForResponse((res) => res.url().includes("/exit"), { timeout: 5000 })
      .then((res) => res.status())
      .catch((e) => `error: ${e}`);

    const exitPromise = waitForExit(proc);
    await page.locator("#modal-request-changes").click();

    const exitStatus = await exitResponsePromise;
    assertTrue(exitStatus === 200, "/exit POSTが正しく200レスポンスを返す（プロセスがレスポンス送信前に終了しない）", {
      exitStatus,
    });

    // The dialog must actually disappear — either because hide_submit_modal()
    // ran, or because the whole page navigated away (about:blank fallback).
    // Either is an acceptable "closed" outcome; staying visible forever is
    // the bug.
    const dialogGone = await page
      .waitForFunction(() => {
        const modal = document.querySelector("#submit-modal");
        const stillVisible = !!modal && modal.classList.contains("visible");
        return !stillVisible || location.href === "about:blank";
      }, undefined, { timeout: 3000 })
      .then(() => true)
      .catch(() => false);
    assertTrue(dialogGone, "Request Changesクリック後、Submit Reviewダイアログが実際に閉じる（またはページごと退避する）");

    const exitCode = await exitPromise;
    assertTrue(exitCode === 0, "サーバープロセスが正常終了する", { exitCode });

    await page.close();
  } finally {
    killIfAlive(proc);
  }
}

/** Bug (b): the pill must never intersect the header action buttons, at any viewport width. */
async function scenarioPillDoesNotOverlapHeader(browser: Browser): Promise<void> {
  console.log("\n--- Scenario (b): unanswered-questions pill never overlaps header buttons ---");
  const widths = [1280, 1024, 768, 480, 375];
  const { proc, port } = await startServer(5441);
  try {
    await waitHealth(port);
    for (const width of widths) {
      const page = await browser.newPage({ viewport: { width, height: 900 } });
      await page.addInitScript(() => {
        localStorage.clear();
        sessionStorage.clear();
      });
      await page.goto(`http://127.0.0.1:${port}`, { waitUntil: "domcontentloaded" });
      await page.waitForSelector("#yunomi-questions-overlay.visible", { timeout: 5000 });
      // Leave everything unanswered so the pill stays visible.
      await page.locator("#yunomi-questions-later").click();
      await page.waitForSelector("#yunomi-questions-bar-open.visible", { timeout: 5000 });

      const pillBox = await page.locator("#yunomi-questions-bar-open").boundingBox();
      assertTrue(!!pillBox, `width=${width}: ピルのバウンディングボックスが取得できる`);
      if (!pillBox) {
        await page.close();
        continue;
      }
      const headerButtonSelectors = [
        "#send-and-exit",
        "#pill-comments",
        "#media-sidebar-toggle",
        "#view-toggle",
        "#history-toggle",
        "#theme-toggle",
      ];
      for (const sel of headerButtonSelectors) {
        const btn = page.locator(sel);
        if (!(await btn.isVisible().catch(() => false))) continue; // e.g. view-toggle hides on narrow widths
        const box = await btn.boundingBox();
        if (!box) continue;
        const overlap = rectsIntersect(pillBox, box);
        assertTrue(
          !overlap,
          `width=${width}: ピルとヘッダーボタン${sel}が重ならない`,
          { pillBox, buttonBox: box },
        );
      }
      await page.close();
    }
  } finally {
    killIfAlive(proc);
  }
}

/** Bug (c): a fully-answered restored draft must still auto-open the stepper on load. */
async function scenarioAlwaysAutoOpensOnLoadEvenIfFullyAnswered(browser: Browser): Promise<void> {
  console.log(
    "\n--- Scenario (c): questions stepper auto-opens on page load even when the restored draft already answers everything ---",
  );
  const { proc, port } = await startServer(5442);
  try {
    await waitHealth(port);
    const page = await freshPage(browser, port);
    await page.waitForSelector("#yunomi-questions-overlay.visible", { timeout: 5000 });

    // Answer both questions completely via the real stepper flow.
    await page.locator(".question-card.step-active .q-option-btn").first().click();
    await page.locator("#yunomi-questions-next").click();
    await page.waitForSelector('.question-card[data-qid="q2-freetext"].step-active', { timeout: 5000 });
    await page.locator('.question-card[data-qid="q2-freetext"] .q-answer').fill("これで完了です。");
    await page
      .waitForFunction(() => {
        for (let i = 0; i < localStorage.length; i++) {
          const key = localStorage.key(i);
          if (!key?.startsWith("yunomi:comments:")) continue;
          try {
            const d = JSON.parse(localStorage.getItem(key) ?? "");
            if (d.answers?.["q2-freetext"]?.text === "これで完了です。") return true;
          } catch {}
        }
        return false;
      }, undefined, { timeout: 5000 })
      .catch(() => {});

    const closeBtn = page.locator("#yunomi-questions-close");
    if (await closeBtn.isVisible().catch(() => false)) await closeBtn.click();

    const unansweredBefore = await page.evaluate(() => {
      const cards = document.querySelectorAll(".question-card:not(.resolved)");
      let unanswered = 0;
      cards.forEach((card) => {
        const hasOption = !!card.querySelector(".q-option-btn.selected");
        const textarea = card.querySelector<HTMLTextAreaElement>(".q-answer");
        const hasText = !!textarea && textarea.value.length > 0;
        if (!hasOption && !hasText) unanswered++;
      });
      return unanswered;
    });
    assertTrue(unansweredBefore === 0, "リロード前: 両質問とも回答済み（unanswered=0）である前提が成立している", {
      unansweredBefore,
    });

    // Simulate "the next round": reload the page. The old (buggy) behavior
    // was to only re-open the modal via hide_recovery_modal()'s DYNAMIC
    // "anything still blank?" check — which is false here, so it silently
    // never opened. The fix makes this a STATIC "does an unresolved
    // question exist at all?" check, which must still be true.
    await page.reload({ waitUntil: "domcontentloaded" });

    const recoveryVisible = await page
      .waitForFunction(() => {
        const m = document.querySelector("#recovery-modal");
        return !!m && m.classList.contains("visible");
      }, undefined, { timeout: 5000 })
      .then(() => true)
      .catch(() => false);
    assertTrue(recoveryVisible, "リロード後、復元モーダルが表示される");

    if (recoveryVisible) {
      await page.locator("#recovery-restore").click();
    }

    const stepperReopened = await page
      .waitForFunction(() => {
        const overlay = document.querySelector("#yunomi-questions-overlay");
        return !!overlay && overlay.classList.contains("visible");
      }, undefined, { timeout: 3000 })
      .then(() => true)
      .catch(() => false);
    assertTrue(
      stepperReopened,
      "全問回答済みのdraftを復元した後でも、未解決の質問が存在する限り質問ステッパーが自動で前面表示される（「気がついたら回答する」に頼らない）",
    );

    if (stepperReopened) {
      // And it must show the PREFILLED answers, not blank fields — the
      // point is "confirm by stepping through", not "re-answer from
      // scratch".
      const q1Selected = await page
        .locator('.question-card[data-qid="q1-option"] .q-option-btn.selected')
        .count();
      assertTrue(q1Selected === 1, "再表示された1問目は既に選択済みの状態でプリフィルされている");
      const q2Value = await page
        .locator('.question-card[data-qid="q2-freetext"] .q-answer')
        .inputValue();
      assertTrue(
        q2Value === "これで完了です。",
        "再表示された2問目は既存の回答でプリフィルされている（空欄からの再入力を強いられない）",
        { q2Value },
      );
    }

    await page.close();
  } finally {
    killIfAlive(proc);
  }
}

async function main(): Promise<void> {
  const browser = await chromium.launch();
  try {
    await scenarioSubmitDialogCloses(browser);
    await scenarioPillDoesNotOverlapHeader(browser);
    await scenarioAlwaysAutoOpensOnLoadEvenIfFullyAnswered(browser);
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
