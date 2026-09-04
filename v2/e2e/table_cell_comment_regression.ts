// Regression coverage for the Phase 2 "cell-level comment" fixes:
//   1. Table cells (td/th) never get a permanently-visible pencil button
//      (narrow columns must not have their text overwritten by an icon).
//   2. Non-cell commentable content (paragraphs, images, etc.) keeps a
//      pencil, but it is invisible until hover/focus (opacity 0 -> 1).
//   3. Clicking a table cell directly (no pencil needed) opens the inline
//      editor resolved to that specific cell (not the whole row).
//   4. Two different cells in the SAME source row get independent
//      `.has-comment` indicators anchored to their own <td>, not to a
//      single shared row-level element (the bug this phase fixes).
//   5. Image comment buttons inside two cells of the same Markdown row keep
//      independent drafts and display the selected row/column location.
import { spawn, type ChildProcess } from "node:child_process";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { mkdirSync, mkdtempSync, readFileSync } from "node:fs";
import { chromium, type Browser, type Page } from "playwright";

const BASE_PORT = 5368;
const SERVER_JS = new URL(
  "../_build/js/release/build/server/server.js",
  import.meta.url,
).pathname;
const FEATURES_MD = new URL("../../examples/test-features.md", import.meta.url).pathname;
const WORK_DIR = mkdtempSync(join(tmpdir(), "yunomi-table-cell-comment-"));
const LOCK_DIR = join(WORK_DIR, "locks");
const REVIEW_DIR = join(WORK_DIR, "reviews");

mkdirSync(LOCK_DIR, { recursive: true });
mkdirSync(REVIEW_DIR, { recursive: true });

let failed = 0;

function pass(msg: string, detail?: unknown): void {
  console.log(`PASS: ${msg}`);
  if (detail !== undefined) console.log(JSON.stringify(detail, null, 2));
}

function fail(msg: string, detail?: unknown): void {
  failed++;
  console.error(`FAIL: ${msg}`);
  if (detail !== undefined) console.error(JSON.stringify(detail, null, 2));
}

function assert(condition: boolean, msg: string, detail?: unknown): void {
  condition ? pass(msg, detail) : fail(msg, detail);
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

async function cardState(page: Page): Promise<{ visible: boolean; preview: string }> {
  return page.evaluate(() => {
    const card = document.querySelector<HTMLElement>(".yunomi-inline-comment-editor");
    return {
      visible: !!card && getComputedStyle(card).display !== "none",
      preview: document.querySelector("#cell-preview")?.textContent?.trim() || "",
    };
  });
}

async function closeCard(page: Page): Promise<void> {
  await page.keyboard.press("Escape");
  await page.waitForTimeout(100);
}

async function main(): Promise<void> {
  const proc = spawn(
    process.execPath,
    [SERVER_JS, "--no-open", "--port", String(BASE_PORT), FEATURES_MD],
    {
      cwd: new URL("..", import.meta.url).pathname,
      env: { ...process.env, HERDR_PANE_ID: "", YUNOMI_NOTIFY_CMD: "", YUNOMI_LOCK_DIR: LOCK_DIR, YUNOMI_REVIEW_DIR: REVIEW_DIR },
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

    browser = await chromium.launch();
    const page = await browser.newPage({ viewport: { width: 1280, height: 900 } });
    await page.addInitScript(() => {
      localStorage.clear();
      sessionStorage.clear();
    });
    await page.goto(`http://127.0.0.1:${port}`, { waitUntil: "domcontentloaded" });
    await page.waitForSelector("#md-preview .yunomi-comment-button", { timeout: 10000 });
    // The target table lives inside a <details> block that is collapsed by
    // default; expand every <details> so the cells are actually visible
    // (matches what a reviewer would do before clicking a cell).
    await page.evaluate(() => {
      document.querySelectorAll("details").forEach((d) => {
        d.open = true;
      });
    });
    await page.waitForSelector(
      '#md-preview table:not(.frontmatter-table) td[data-col="1"]',
      { timeout: 10000 },
    );

    // --- 1. No pencil button is ever created directly on a TEXT table cell.
    //        (Cells that contain only an image/video are a deliberate
    //        exception: images always keep a pencil per spec, and there is
    //        no cell text underneath for it to obscure.) ---
    const cellButtonInfo = await page.evaluate(() => {
      const buttons = Array.from(
        document.querySelectorAll(
          "#md-preview table:not(.frontmatter-table) td > .yunomi-comment-button, " +
            "#md-preview table:not(.frontmatter-table) th > .yunomi-comment-button",
        ),
      );
      const onTextCells = buttons.filter((btn) => {
        const cell = btn.parentElement;
        return !cell?.querySelector("img, video");
      });
      return { total: buttons.length, onTextCells: onTextCells.length };
    });
    assert(
      cellButtonInfo.onTextCells === 0,
      "文字だけのテーブルセル(td/th)には鉛筆ボタンが生成されない（画像セルは例外）",
      cellButtonInfo,
    );

    // --- 2. Image pencils are hover/focus-only (opacity 0 -> 1) ---
    const hostForHover = page
      .locator(
        "#md-preview .yunomi-media-comment-host:has(> img):has(> .yunomi-comment-button)",
      )
      .first();
    await hostForHover.scrollIntoViewIfNeeded();
    const hoveredHost = await hostForHover.elementHandle();
    if (!hoveredHost) throw new Error("commentable image host is missing");
    const paragraphButton = await hoveredHost.$(":scope > .yunomi-comment-button");
    if (!paragraphButton) throw new Error("commentable image button is missing");
    const paragraphOpacityBefore = await paragraphButton.evaluate(
      (button) => getComputedStyle(button).opacity,
    );
    assert(
      paragraphOpacityBefore === "0",
      "画像の鉛筆はデフォルトで非表示(opacity:0)",
      { paragraphOpacityBefore },
    );
    const hoverRulePresent = await page.evaluate(() =>
      Array.from(document.styleSheets).some((sheet) => {
        try {
          return Array.from(sheet.cssRules).some((rule) =>
            rule.cssText.includes(".yunomi-commentable:hover > .yunomi-comment-button"),
          );
        } catch {
          return false;
        }
      }),
    );
    assert(
      hoverRulePresent,
      "画像の鉛筆にはhoverで表示するCSS規則が配信される",
      { hoverRulePresent },
    );
    await paragraphButton.focus();
    // The opacity transition is 0.12s; wait past it before sampling.
    await page.waitForTimeout(300);
    const paragraphOpacityFocus = await paragraphButton.evaluate(
      (button) => getComputedStyle(button).opacity,
    );
    assert(
      paragraphOpacityFocus === "1",
      "画像の鉛筆はキーボードfocusでopacity:1になる",
      { paragraphOpacityFocus },
    );

    // --- 3 & 4. Two different cells in the same source row get independent
    //            per-cell comments and highlights, not a shared row highlight ---
    const cellsInfo = await page.evaluate(() => {
      const cells = Array.from(
        document.querySelectorAll<HTMLElement>(
          '#md-preview table:not(.frontmatter-table) td[data-col]',
        ),
      );
      const fileCell = cells.find((el) => (el.textContent || "").includes("login.e2e.ts"));
      const lineCell = cells.find(
        (el) =>
          fileCell &&
          el.getAttribute("data-row") === fileCell.getAttribute("data-row") &&
          el.getAttribute("data-col") !== fileCell.getAttribute("data-col") &&
          (el.textContent || "").trim() === "15",
      );
      return {
        fileRow: fileCell?.getAttribute("data-row") || null,
        fileCol: fileCell?.getAttribute("data-col") || null,
        lineRow: lineCell?.getAttribute("data-row") || null,
        lineCol: lineCell?.getAttribute("data-col") || null,
      };
    });
    assert(
      cellsInfo.fileRow !== null &&
        cellsInfo.fileRow === cellsInfo.lineRow &&
        cellsInfo.fileCol !== cellsInfo.lineCol,
      "同一行・別カラムの2セルを特定できる（テストの前提）",
      cellsInfo,
    );

    // Click cell 1 (file name column) directly — no pencil involved.
    await page.evaluate(() => {
      const cells = Array.from(
        document.querySelectorAll<HTMLElement>(
          '#md-preview table:not(.frontmatter-table) td[data-col]',
        ),
      );
      cells.find((el) => (el.textContent || "").includes("login.e2e.ts"))?.click();
    });
    await page.waitForSelector(".yunomi-inline-comment-editor", { state: "visible" });
    const cell1Card = await cardState(page);
    assert(
      cell1Card.visible && cell1Card.preview.includes("login.e2e.ts"),
      "セル1(login.e2e.ts)を直接クリックするとそのセルのインライン編集が開く",
      cell1Card,
    );
    const cell1EditorParent = await page.locator(".yunomi-inline-comment-editor").evaluate((editor) => {
      const cell = editor.closest("td,th");
      return { row: cell?.getAttribute("data-row"), col: cell?.getAttribute("data-col") };
    });
    assert(
      cell1EditorParent.row === cellsInfo.fileRow && cell1EditorParent.col === cellsInfo.fileCol,
      "セル1のコメントエディタはクリックしたセル自身の中に開く",
      cell1EditorParent,
    );
    await page.locator("#comment-input").fill("cell1 comment: file name");
    await page.locator("#save-comment").click();
    await page.waitForTimeout(150);

    // Click cell 2 (line number column, SAME row) directly.
    await page.evaluate(() => {
      const cells = Array.from(
        document.querySelectorAll<HTMLElement>(
          '#md-preview table:not(.frontmatter-table) td[data-col]',
        ),
      );
      cells
        .find((el) => (el.textContent || "").trim() === "15")
        ?.click();
    });
    await page.waitForSelector(".yunomi-inline-comment-editor", { state: "visible" });
    const cell2Card = await cardState(page);
    assert(
      cell2Card.visible &&
        cell2Card.preview.includes("15") &&
        !cell2Card.preview.includes("login.e2e.ts"),
      "セル2(行番号 15、同じ行の別カラム)を直接クリックするとそのセルのインライン編集が開く",
      cell2Card,
    );
    const cell2EditorParent = await page.locator(".yunomi-inline-comment-editor").evaluate((editor) => {
      const cell = editor.closest("td,th");
      return { row: cell?.getAttribute("data-row"), col: cell?.getAttribute("data-col") };
    });
    assert(
      cell2EditorParent.row === cellsInfo.lineRow && cell2EditorParent.col === cellsInfo.lineCol,
      "右側セルのコメントエディタは行の左端ではなくクリックした右側セル内に開く",
      cell2EditorParent,
    );
    await page.locator("#comment-input").fill("cell2 comment: line number");
    await page.locator("#save-comment").click();
    await page.waitForTimeout(150);

    // Both comments must now be visually anchored to their OWN cell.
    const indicatorState = await page.evaluate(() => {
      const marked = Array.from(
        document.querySelectorAll<HTMLElement>(
          '#md-preview table:not(.frontmatter-table) td.has-comment',
        ),
      );
      return {
        count: marked.length,
        rows: marked.map((el) => el.getAttribute("data-row")),
        cols: marked.map((el) => el.getAttribute("data-col")),
        texts: marked.map((el) => (el.textContent || "").trim()),
        quotes: marked.map((el) =>
          Array.from(el.querySelectorAll<HTMLElement>(".yunomi-inline-comment-context")).map(
            (quote) => (quote.textContent || "").trim(),
          ),
        ),
      };
    });
    assert(
      indicatorState.count === 2 &&
        indicatorState.rows[0] === indicatorState.rows[1] &&
        indicatorState.cols[0] !== indicatorState.cols[1] &&
        indicatorState.texts.some(text => text.includes("login.e2e.ts")) &&
        indicatorState.texts.some(text => text.includes("15")),
      "同じ行の別セル2つが、それぞれ独立した.has-commentとしてハイライトされる（行全体ではない）",
      indicatorState,
    );
    assert(
      indicatorState.texts.some((text) => text.includes("Markdown 29行目・1列目")) &&
        indicatorState.texts.some((text) => text.includes("Markdown 29行目・2列目")) &&
        indicatorState.quotes.some((quotes) => quotes.includes("login.e2e.ts")) &&
        indicatorState.quotes.some((quotes) => quotes.includes("15")),
      "画像以外の表コメントは自然な位置名と元の文字引用を分けて表示する",
      indicatorState,
    );
    const savedCommentParents = await page.evaluate(() =>
      Array.from(document.querySelectorAll<HTMLElement>("#md-preview .yunomi-inline-comment:not(.yunomi-inline-comment-editor)"))
        .map(comment => {
          const cell = comment.closest("td,th");
          return { row: cell?.getAttribute("data-row"), col: cell?.getAttribute("data-col") };
        }),
    );
    assert(
      savedCommentParents.some(cell => cell.row === cellsInfo.fileRow && cell.col === cellsInfo.fileCol) &&
        savedCommentParents.some(cell => cell.row === cellsInfo.lineRow && cell.col === cellsInfo.lineCol),
      "保存済みコメントもそれぞれクリックしたセル内に残る",
      savedCommentParents,
    );

    const imageCells = page.locator(
      '#md-preview table:not(.frontmatter-table):has(img[alt="Before"]):has(img[alt="After"]) td:has(img)',
    );
    assert(
      (await imageCells.count()) === 2,
      "同一Markdown行に画像セルが2つある（回帰テストの前提）",
      { count: await imageCells.count() },
    );

    const imageComments = [
      "left image cell comment",
      "right image cell comment",
    ];
    for (let index = 0; index < 2; index++) {
      const cell = imageCells.nth(index);
      await cell.scrollIntoViewIfNeeded();
      await cell.locator(":scope .yunomi-comment-button").click();
      await page.waitForSelector(".yunomi-inline-comment-editor", { state: "visible" });
      const editorValue = await page.locator("#comment-input").inputValue();
      const cellLocation = await cell.evaluate((element) => ({
        row: Number(element.getAttribute("data-row")) + 1,
        col: Number(element.getAttribute("data-col")),
      }));
      const editorLocation =
        (await page.locator(".yunomi-inline-comment-editor .yunomi-inline-comment-label").textContent()) || "";
      const editorHeadLayout = await page
        .locator(".yunomi-inline-comment-editor .review-loop-comment-head")
        .evaluate((head) => {
          const dot = head.querySelector<HTMLElement>(".review-loop-status-dot")?.getBoundingClientRect();
          const label = head.querySelector<HTMLElement>(".yunomi-inline-comment-label")?.getBoundingClientRect();
          return {
            dotWidth: dot?.width || 0,
            labelWidth: label?.width || 0,
            ordered: !!dot && !!label && dot.right <= label.left,
          };
        });
      assert(
        editorValue === "",
        `画像セル${index + 1}は別セルの既存コメントを引き継がない`,
        { editorValue },
      );
      assert(
        editorLocation ===
            `表の画像「${index === 0 ? "Before" : "After"}」（Markdown ${cellLocation.row}行目・${cellLocation.col}列目）` &&
          editorHeadLayout.dotWidth > 0 &&
          editorHeadLayout.labelWidth > 0 &&
          editorHeadLayout.ordered,
        `画像セル${index + 1}の青い状態点の隣に行・列ロケーションが表示される`,
        { editorLocation, cellLocation, editorHeadLayout },
      );
      await page.locator("#comment-input").fill(imageComments[index]);
      if (index === 0) {
        await page.locator("#save-comment").click();
        const pending = cell.locator(":scope .yunomi-inline-comment-view");
        await pending.waitFor({ state: "visible" });
        const pendingHeadLayout = await pending.locator(".review-loop-comment-head").evaluate((head) => {
          const dot = head.querySelector<HTMLElement>(".review-loop-status-dot")?.getBoundingClientRect();
          const label = head.querySelector<HTMLElement>(".yunomi-inline-comment-label")?.getBoundingClientRect();
          const badge = head.querySelector<HTMLElement>(".yunomi-inline-comment-pending")?.getBoundingClientRect();
          return {
            text: head.textContent?.trim() || "",
            widths: [dot?.width || 0, label?.width || 0, badge?.width || 0],
            ordered: !!dot && !!label && !!badge && dot.right <= label.left && label.right <= badge.left,
            contained:
              !!badge && badge.top >= head.getBoundingClientRect().top && badge.bottom <= head.getBoundingClientRect().bottom,
          };
        });
        assert(
          pendingHeadLayout.text.includes("表の画像「Before」（Markdown") &&
            pendingHeadLayout.text.endsWith("Pending") &&
            pendingHeadLayout.widths.every((width) => width > 0) &&
            pendingHeadLayout.ordered &&
            pendingHeadLayout.contained,
          "save後も青い状態点・画像ロケーション・Pendingが重ならず横並びで表示される",
          pendingHeadLayout,
        );
        await pending.click();
        await page.waitForSelector(".yunomi-inline-comment-editor", { state: "visible" });
      }
      if (index === 1) {
        await page.locator("#comment-input").press(
          process.platform === "darwin" ? "Meta+Enter" : "Control+Enter",
        );
      } else {
        await page.locator("#send-now-comment").click();
      }
      await page.waitForSelector(".yunomi-inline-comment-editor", { state: "detached" });
      await page.waitForFunction(
        ({ row, col }) =>
          !!document.querySelector(
            `#md-preview [data-row="${row}"][data-col="${col}"] .review-loop-inline`,
          ),
        { row: cellLocation.row - 1, col: cellLocation.col },
        { timeout: 5000 },
      );
    }

    const imageCommentState = await imageCells.evaluateAll((cells) =>
      cells.map((cell) => ({
        row: cell.getAttribute("data-row"),
        col: cell.getAttribute("data-col"),
        comments: Array.from(
          cell.querySelectorAll<HTMLElement>(":scope .review-loop-inline"),
        ).map((comment) => comment.textContent || ""),
      })),
    );
    assert(
      imageCommentState.length === 2 &&
        imageCommentState[0].row === imageCommentState[1].row &&
        imageCommentState[0].col !== imageCommentState[1].col &&
        imageCommentState[0].comments.some((text) =>
          text.includes("表の画像「Before」（Markdown 53行目・1列目）"),
        ) &&
        imageCommentState[1].comments.some((text) =>
          text.includes("表の画像「After」（Markdown 53行目・2列目）"),
        ) &&
        imageCommentState[0].comments.some((text) => text.includes(imageComments[0])) &&
        imageCommentState[1].comments.some((text) => text.includes(imageComments[1])),
      "send nowボタンとCmd/Ctrl+Enterの両方で画像名・Markdown行・列を表示して各セルへ独立して残る",
      imageCommentState,
    );
    const durableReview = JSON.parse(
      readFileSync(join(REVIEW_DIR, "review.json"), "utf8"),
    );
    const durableImageComments = durableReview.comments
      .filter((comment: { text?: string }) => imageComments.includes(comment.text || ""))
      .map((comment: { row?: number; col?: number; text?: string; target?: string }) => ({
        row: comment.row,
        col: comment.col,
        text: comment.text,
        target: comment.target,
      }));
    assert(
      durableImageComments.length === 2 &&
        durableImageComments[0].row === durableImageComments[1].row &&
        durableImageComments[0].col === 1 &&
        durableImageComments[1].col === 2 &&
        durableImageComments[0].target?.includes('image (alt="Before"') &&
        durableImageComments[1].target?.includes('image (alt="After"'),
      "send now後も画像名・行・列がAI向け構造化情報としてreview.jsonへ独立して永続化される",
      durableImageComments,
    );

    await closeCard(page);
    await page.locator("#send-and-exit").click();
    await page.waitForSelector("#submit-modal.visible", { timeout: 3000 });
    const exitPromise = waitForExit(proc);
    await page.locator("#modal-approve").click();
    const exitCode = await exitPromise;
    assert(exitCode === 0, "Submit後にサーバーが正常終了する", { exitCode });
    assert(
      serverOutput.includes("cell1 comment: file name") &&
        serverOutput.includes("cell2 comment: line number") &&
        serverOutput.includes("comments=2"),
      "提出YAMLには未提出の文字セルコメント2件だけが出力される",
      serverOutput,
    );
  } finally {
    if (browser) await browser.close();
    if (proc.exitCode === null) proc.kill("SIGTERM");
  }

  if (failed > 0) {
    process.exit(1);
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
