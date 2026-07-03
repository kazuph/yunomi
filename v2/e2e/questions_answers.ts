/**
 * E2E regression for the frontmatter `yunomi: questions:` stepper UI.
 *
 * Background: the previous "show every question in one tall scrolling
 * stack" modal drew three complaints from an actual review session:
 *   1. Carefully-written judgment material (why the AI is asking) never
 *      appeared anywhere in the dialog.
 *   2. The card heading showed the internal frontmatter `id`
 *      (e.g. "q-signoff-failopen") as if it were meaningful to a human.
 *   3. All questions stacked at once made the modal tall — the user wanted
 *      an AskUserQuestion-style "answer one, screen switches to the next"
 *      flow instead.
 *   4. Answers typed mid-review vanished with no way to tell the AI what
 *      had already been decided; the only escape hatch was "answer later".
 *
 * This test drives the real browser UI (not a direct POST to /exit) through
 * the redesigned stepper and checks all four fixes:
 *   (a) clicking "次へ" on the first question appends an `answer` event to
 *       the live JSONL log immediately — not at the end of the review.
 *   (b) closing the modal mid-typing on the second question and reopening
 *       it (via a full reload + Restore, proving the localStorage round
 *       trip, not just in-memory DOM state) restores both the stepper
 *       position and the partially-typed text.
 *   (c) the final Submit still produces the same verdict YAML `answers:`
 *       shape as before (id-keyed JSON, full text preserved).
 *   (d) no internal question id ever renders as visible text in the modal.
 *   (e) no emoji renders anywhere in the modal or the unanswered-count
 *       pill.
 *
 * Run: node --experimental-strip-types e2e/questions_answers.ts
 */
import assert from "node:assert/strict";
import { spawn, type ChildProcess } from "node:child_process";
import { existsSync, mkdirSync, readFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { chromium, type Browser, type Locator } from "playwright";

const BASE_PORT = 5410;
const SERVER_JS = new URL(
  "../_build/js/release/build/server/server.js",
  import.meta.url,
).pathname;
const FIXTURE_MD = new URL(
  "../../examples/questions-answers.md",
  import.meta.url,
).pathname;
const LOCK_DIR = join(tmpdir(), "yunomi-questions-answers-locks");

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

function waitForServerOutput(proc: ChildProcess): Promise<number> {
  let stdout = "";
  let resolved = false;
  return new Promise((resolve, reject) => {
    proc.stdout!.on("data", (chunk: Buffer) => {
      stdout += String(chunk);
      if (resolved) return;
      const match = stdout.match(/http:\/\/127\.0\.0\.1:(\d+)/);
      if (match) {
        resolved = true;
        resolve(parseInt(match[1], 10));
      }
    });
    proc.stderr!.on("data", (chunk: Buffer) => {
      stdout += String(chunk);
    });
    proc.on("exit", (code: number | null) => {
      if (!resolved) {
        resolved = true;
        reject(new Error(`server exited before ready (code=${code})\n${stdout}`));
      }
    });
    setTimeout(() => {
      if (!resolved) {
        resolved = true;
        reject(new Error(`server startup timeout\n${stdout}`));
      }
    }, 10000);
  });
}

function waitForExit(proc: ChildProcess): Promise<number | null> {
  return new Promise((resolve) => {
    proc.once("exit", (code) => resolve(code));
  });
}

async function waitForHealth(port: number): Promise<void> {
  for (let i = 0; i < 50; i++) {
    try {
      const res = await fetch(`http://127.0.0.1:${port}/healthz`);
      if (res.ok) return;
    } catch (_: unknown) {}
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  throw new Error(`healthz timeout on ${port}`);
}

/**
 * Undo YAML single-quote scalar doubling ('' -> ') on the inner content of
 * a `key: '...'` line (outer quotes already stripped).
 */
function undoubleSingleQuotes(inner: string): string {
  return inner.replace(/''/g, "'");
}

/** Poll a predicate until it's true or the timeout elapses. */
async function waitUntil(
  predicate: () => boolean | Promise<boolean>,
  timeoutMs: number,
  intervalMs = 100,
): Promise<boolean> {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    if (await predicate()) return true;
    await new Promise((r) => setTimeout(r, intervalMs));
  }
  return await predicate();
}

// A visible-emoji detector: the pictographic ranges the old modal used
// (📋 U+1F4CB, ⏳ U+23F3, ✅ U+2705, 🗂️ U+1F5C2+U+FE0F) all fall inside
// these blocks. Plain typographic symbols already used elsewhere in the app
// (×, ▸, arrows) intentionally fall OUTSIDE these ranges.
const EMOJI_PATTERN = /[\u{1F300}-\u{1FAFF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]/u;

// 280+ Japanese characters (well over the "200文字超" bar), including an
// emoji, embedded full-width punctuation, and a couple of ASCII/ digits to
// mimic a realistic free-text review comment.
const LONG_ANSWER =
  "AIエージェントへのコメント機能は非常に重要な体験改善だと思います。" +
  "特に長文の日本語フィードバックが行末で切れずにそのまま反映されることを必ず確認したいです。" +
  "たとえば「これって何の意味ある？」のような率直な指摘や、句読点、感嘆符！、絵文字🎉、" +
  "半角記号(a-z0-9)が混在していても壊れないこと、複数行にまたがる説明であっても、" +
  "最後の一文字まで欠けずにverdict YAMLへ反映されることを2026年時点であらためて確認する。" +
  "これはregressionテストの本文です。".repeat(1);

const PARTIAL_ANSWER = "エージェントへのコメント機能は";

async function main(): Promise<void> {
  assertTrue(LONG_ANSWER.length > 200, "test fixture answer exceeds 200 chars", {
    length: LONG_ANSWER.length,
  });

  const proc = spawn(
    process.execPath,
    [SERVER_JS, "--no-open", "--port", String(BASE_PORT), FIXTURE_MD],
    {
      cwd: new URL("..", import.meta.url).pathname,
      env: { ...process.env, YUNOMI_LOCK_DIR: LOCK_DIR },
      stdio: ["ignore", "pipe", "pipe"],
    },
  );

  let serverOutput = "";
  proc.stdout!.on("data", (chunk: Buffer) => {
    serverOutput += String(chunk);
  });
  proc.stderr!.on("data", (chunk: Buffer) => {
    serverOutput += String(chunk);
  });

  let browser: Browser | null = null;
  try {
    const port = await waitForServerOutput(proc);
    await waitForHealth(port);

    // The live log path is announced once at boot (init_live_log, well
    // before the "http://..." ready line), so it's already captured here.
    const liveLogMatch = serverOutput.match(/\[YUNOMI_LIVE\] (.+)/);
    assertTrue(!!liveLogMatch, "サーバーがlive logのパスを起動時に announce する", {
      serverOutputTail: serverOutput.slice(-500),
    });
    const liveLogPath = liveLogMatch ? liveLogMatch[1].trim() : "";

    browser = await chromium.launch();
    const page = await browser.newPage({ viewport: { width: 1280, height: 900 } });
    // Clear storage only on the tab's very first load. addInitScript reruns
    // on every navigation, including the deliberate page.reload() this test
    // does further down to prove the draft survives a real reload+Restore —
    // an unconditional clear here would wipe that draft out from under the
    // reload before check_recovery() ever got a chance to see it.
    // sessionStorage (unlike localStorage) survives a same-tab reload, so it
    // doubles as the "have we already cleared once" marker.
    await page.addInitScript(() => {
      const marker = "__yunomi_e2e_boot__";
      if (!sessionStorage.getItem(marker)) {
        localStorage.clear();
        sessionStorage.clear();
        sessionStorage.setItem(marker, "1");
      }
    });
    await page.goto(`http://127.0.0.1:${port}`, { waitUntil: "domcontentloaded" });

    // The questions modal auto-opens ~500ms after load when there are
    // unanswered questions (setup_questions_ui).
    await page.waitForSelector("#yunomi-questions-overlay.visible", { timeout: 5000 });

    const cardCount = await page.locator(".question-card").count();
    assertTrue(cardCount === 2, "両方の質問カードがDOMに存在する（非表示でも保持される）", {
      cardCount,
    });

    const q1Card = page.locator('.question-card[data-qid="q1-option"]');
    const q2Card = page.locator('.question-card[data-qid="q2-freetext"]');

    // --- Stepper: only the first question is on screen ---
    await assertVisibleStep(q1Card, q2Card, "1/2", "次へ");

    // --- (d)/(e): no internal id, no emoji, anywhere in the visible modal ---
    const overlayText = (await page.locator("#yunomi-questions-overlay").innerText()) ?? "";
    assertTrue(
      !overlayText.includes("q1-option") && !overlayText.includes("q2-freetext"),
      "内部ID(q1-option/q2-freetext)が質問モーダルの表示テキストに一切出現しない",
      { overlayText },
    );
    assertTrue(
      !/\bq-[a-z0-9-]/i.test(overlayText),
      "汎用の 'q-' プレフィックス付きIDらしき文字列も表示テキストに出現しない",
      { overlayText },
    );
    assertTrue(
      !EMOJI_PATTERN.test(overlayText),
      "質問モーダルの表示テキストに絵文字が含まれない",
      { overlayText },
    );
    const barText = (await page.locator("#yunomi-questions-bar-open").innerText().catch(() => "")) ?? "";
    assertTrue(!EMOJI_PATTERN.test(barText), "未回答質問バッジ(ピル)にも絵文字が含まれない", {
      barText,
    });
    // The judgment material (frontmatter `context:`) the AI wrote must
    // actually render — this is complaint #1 from the real review session.
    assertTrue(
      overlayText.includes("現行の質問ダイアログはユーザーの実体験フィードバックにより全面再設計した"),
      "frontmatterのcontext:（判断材料）が質問カードに表示される",
      { overlayText },
    );

    // --- Q1: answer purely by selecting an option button (no free text) ---
    const optionButtons = q1Card.locator(".q-option-btn");
    const optionCount = await optionButtons.count();
    assertTrue(optionCount === 2, "選択肢ボタンが2つ描画される", { optionCount });
    const firstOptionText = (await optionButtons.first().textContent())?.trim() ?? "";
    await optionButtons.first().click();
    const selectedNow = await q1Card.locator(".q-option-btn.selected").count();
    assertTrue(selectedNow === 1, "選択肢クリックでselectedクラスが付与される", { selectedNow });

    // --- (a): clicking "次へ" flushes the answer to the live log immediately ---
    await page.locator("#yunomi-questions-next").click();
    const liveLogHasAnswer =
      liveLogPath.length > 0 &&
      (await waitUntil(() => {
        if (!existsSync(liveLogPath)) return false;
        const content = readFileSync(liveLogPath, "utf-8");
        return content
          .split("\n")
          .filter((l) => l.trim().length > 0)
          .some((line) => {
            try {
              const evt = JSON.parse(line);
              return (
                evt.type === "answer" && evt.id === "q1-option" && evt.answer === firstOptionText
              );
            } catch {
              return false;
            }
          });
      }, 5000));
    assertTrue(
      liveLogHasAnswer,
      "「次へ」クリック直後、live log(JSONL)にtype:answerイベントが即時追記される",
      { liveLogPath },
    );

    // --- Stepper advanced to the second (and last) question ---
    await assertVisibleStep(q2Card, q1Card, "2/2", "完了");

    // --- (b): close mid-typing on Q2, reload, Restore -> position + text survive ---
    await q2Card.locator(".q-answer").fill(PARTIAL_ANSWER);
    const persistedPartial = await page
      .waitForFunction(
        (expected) => {
          for (let i = 0; i < localStorage.length; i++) {
            const key = localStorage.key(i);
            if (!key || !key.startsWith("yunomi:comments:")) continue;
            try {
              const draft = JSON.parse(localStorage.getItem(key) ?? "");
              const answers = draft.answers ?? {};
              if (answers["q2-freetext"]?.text === expected.text && draft.step === expected.step) {
                return true;
              }
            } catch {
              // draft still mid-write / not JSON yet — keep polling
            }
          }
          return false;
        },
        { text: PARTIAL_ANSWER, step: 1 },
        { timeout: 5000 },
      )
      .then(() => true)
      .catch(() => false);
    assertTrue(
      persistedPartial,
      "2問目の部分入力とステップ位置(step=1)がlocalStorageのdraftへ永続化される",
    );

    const closeBtn = page.locator("#yunomi-questions-close");
    if (await closeBtn.isVisible().catch(() => false)) {
      await closeBtn.click();
    }
    await page.reload({ waitUntil: "domcontentloaded" });

    const recoveryVisible = await page
      .waitForFunction(() => {
        const modal = document.querySelector("#recovery-modal");
        return !!modal && modal.classList.contains("visible");
      }, undefined, { timeout: 5000 })
      .then(() => true)
      .catch(() => false);
    assertTrue(recoveryVisible, "リロード後に復元モーダルが表示される");
    if (recoveryVisible) {
      await page.locator("#recovery-restore").click();
      await page.waitForTimeout(200);

      const q2Restored = page.locator('.question-card[data-qid="q2-freetext"]');
      const isStepActive = await q2Restored.evaluate((el) => el.classList.contains("step-active"));
      assertTrue(isStepActive, "復元後、ステッパーの位置が2問目のまま復元される（1問目に戻らない）");
      const restoredValue = await q2Restored.locator(".q-answer").inputValue();
      assertTrue(
        restoredValue === PARTIAL_ANSWER,
        "復元された2問目の回答がクローズ直前の部分入力と完全一致する",
        { restoredValue, expected: PARTIAL_ANSWER },
      );
      const q1Restored = page.locator('.question-card[data-qid="q1-option"]');
      const q1SelectedRestored = await q1Restored.locator(".q-option-btn.selected").count();
      assertTrue(
        q1SelectedRestored === 1,
        "復元後も1問目の選択済み回答が失われていない（stepper全体のdraftが復元される）",
      );

      // Finish the review for real: overwrite the partial with the full,
      // multi-hundred-character answer. Both questions already count as
      // "answered" (Q1's option + Q2's non-empty partial text), so
      // update_questions_count() has already auto-closed the modal by now.
      // Locator.fill({force:true}) still tries to focus() the element
      // first, which real browsers silently refuse for a display:none
      // node — so it's a no-op here. Set the value + dispatch "input"
      // directly instead; that's the same DOM node and the same event
      // app.mbt's listener reacts to, collect_yunomi_answers() reads from
      // at Submit time regardless of the modal's visibility.
      await q2Restored.locator(".q-answer").evaluate((el, value) => {
        const textarea = el as HTMLTextAreaElement;
        textarea.value = value;
        textarea.dispatchEvent(new Event("input", { bubbles: true }));
      }, LONG_ANSWER);
      const domValueAfterFill = await q2Restored.locator(".q-answer").inputValue();
      assertTrue(
        domValueAfterFill === LONG_ANSWER,
        "非表示のテキストエリアに直接セットした完全な回答がDOM値に反映される",
        { length: domValueAfterFill.length },
      );
      const persistedFull = await page
        .waitForFunction(
          (expected) => {
            for (let i = 0; i < localStorage.length; i++) {
              const key = localStorage.key(i);
              if (!key || !key.startsWith("yunomi:comments:")) continue;
              try {
                const draft = JSON.parse(localStorage.getItem(key) ?? "");
                if (draft.answers?.["q2-freetext"]?.text === expected) return true;
              } catch {
                /* keep polling */
              }
            }
            return false;
          },
          LONG_ANSWER,
          { timeout: 5000 },
        )
        .then(() => true)
        .catch(() => false);
      assertTrue(persistedFull, "上書き後の全文回答がlocalStorageのdraftへ再永続化される");

      // update_questions_count()'s 500ms auto-close may already have fired
      // now that both questions are answered — click through explicitly if
      // the modal (and its "完了" button) is still open.
      const nextBtn = page.locator("#yunomi-questions-next");
      if (await nextBtn.isVisible().catch(() => false)) {
        await nextBtn.click();
      }
      const closeBtn2 = page.locator("#yunomi-questions-close");
      if (await closeBtn2.isVisible().catch(() => false)) {
        await closeBtn2.click();
      }
    }

    await page.locator("#send-and-exit").click();
    await page.waitForSelector("#submit-modal.visible", { timeout: 5000 });

    const exitPromise = waitForExit(proc);
    await page.locator("#modal-request-changes").click();
    const exitCode = await exitPromise;
    assertTrue(exitCode === 0, "Submit後にサーバーが正常終了する", { exitCode });

    // --- (c): the verdict YAML's `answers:` field keeps the old shape ---
    // Safe as a single-line `/m` match because `answers` is a JSON string
    // (embedded newlines already encoded as literal `\n`) before
    // yaml_escape_string() wraps it in single quotes.
    const match = serverOutput.match(/^answers: '(.*)'$/m);
    assertTrue(!!match, "verdict YAMLにanswersフィールドが出力される", {
      serverOutputTail: serverOutput.slice(-2000),
    });

    if (match) {
      const rawJsonText = undoubleSingleQuotes(match[1]);
      let parsed: Record<string, string> | null = null;
      let parseError: string | null = null;
      try {
        parsed = JSON.parse(rawJsonText);
      } catch (e: unknown) {
        parseError = (e as Error).message;
      }
      assertTrue(parsed !== null, "answersは正しいJSONとしてパースできる (node JSON.parse)", {
        parseError,
        rawJsonText,
      });

      if (parsed) {
        assertTrue(
          parsed["q1-option"] === firstOptionText,
          "選択肢回答(q1-option)がanswersに完全な形で出力される（ステッパー経由でも従来形式）",
          { expected: firstOptionText, actual: parsed["q1-option"] },
        );
        assertTrue(
          parsed["q2-freetext"] === LONG_ANSWER,
          "200文字超の日本語自由回答(q2-freetext)が一文字も欠けず出力される",
          {
            expectedLength: LONG_ANSWER.length,
            actualLength: parsed["q2-freetext"]?.length ?? -1,
            expectedTail: LONG_ANSWER.slice(-30),
            actualTail: parsed["q2-freetext"]?.slice(-30) ?? "<missing>",
          },
        );
      }
    }

    assertTrue(
      serverOutput.includes("decision: request_changes"),
      "Request Changes決定がverdict YAMLに反映される",
    );
  } finally {
    if (browser) await browser.close();
    if (proc.exitCode === null) proc.kill("SIGTERM");
  }

  console.log(`\nSummary: ${failed === 0 ? "all passed" : `${failed} failed`}`);
  if (failed > 0) {
    process.exit(1);
  }
}

/**
 * Assert the one-question-per-screen invariant: `activeCard` is on screen
 * (has .step-active and is actually visible) while `inactiveCard` is not,
 * and the header/footer chrome (progress counter, Next-vs-Complete label)
 * matches.
 */
async function assertVisibleStep(
  activeCard: Locator,
  inactiveCard: Locator,
  expectedProgress: string,
  expectedButtonLabel: string,
): Promise<void> {
  await activeCard.waitFor({ state: "visible", timeout: 5000 });
  const inactiveVisible = await inactiveCard.isVisible().catch(() => false);
  assertTrue(!inactiveVisible, "非アクティブな質問カードは画面に表示されない（1問1画面）", {
    expectedProgress,
  });
  const progressText = (await page_progress()) ?? "";
  assertTrue(
    progressText === expectedProgress,
    `進捗表示が「${expectedProgress}」を示す（説明文言なしの数字のみ）`,
    { progressText },
  );
  const buttonLabel = (await activeCard.page().locator("#yunomi-questions-next").innerText()) ?? "";
  assertTrue(
    buttonLabel.trim() === expectedButtonLabel,
    `フッターの主ボタンが「${expectedButtonLabel}」を示す`,
    { buttonLabel },
  );

  async function page_progress(): Promise<string> {
    return (await activeCard.page().locator("#yunomi-questions-progress").innerText()) ?? "";
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
