import { spawn, type ChildProcess } from "node:child_process";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { mkdirSync } from "node:fs";
import { chromium, type Browser, type Page } from "playwright";

const BASE_PORT = 5358;
const SERVER_JS = new URL(
  "../_build/js/release/build/server/server.js",
  import.meta.url,
).pathname;
const FEATURES_MD = new URL("../../examples/test-features.md", import.meta.url).pathname;
const LOCK_DIR = join(tmpdir(), "yunomi-comment-shortcuts-locks");

mkdirSync(LOCK_DIR, { recursive: true });

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

async function cardState(page: Page): Promise<{
  visible: boolean;
  preview: string;
}> {
  return page.evaluate(() => {
    const card = document.querySelector<HTMLElement>(".yunomi-inline-comment-editor");
    return {
      visible: !!card && getComputedStyle(card).display !== "none",
      preview: document.querySelector("#cell-preview")?.textContent?.trim() || "",
    };
  });
}

async function selectedState(page: Page): Promise<{
  previewText: string;
  previewBackgroundColor: string;
  previewOutlineStyle: string;
  previewOutlineWidth: string;
  previewBoxShadow: string;
  selectedRows: string[];
  selectedCols: string[];
  cardVisible: boolean;
  activeMediaIndex: number | null;
}> {
  return page.evaluate(() => {
    const selected = Array.from(document.querySelectorAll<HTMLElement>(".md-right td.selected"));
    const highlighted = document.querySelector<HTMLElement>(".md-preview .preview-highlight");
    const card = document.querySelector<HTMLElement>(".yunomi-inline-comment-editor");
    const activeMedia = document.querySelector<HTMLElement>(".media-sidebar-thumb.active");
    return {
      previewText: highlighted?.textContent?.trim() || highlighted?.getAttribute("title") || "",
      previewBackgroundColor: highlighted ? getComputedStyle(highlighted).backgroundColor : "",
      previewOutlineStyle: highlighted ? getComputedStyle(highlighted).outlineStyle : "",
      previewOutlineWidth: highlighted ? getComputedStyle(highlighted).outlineWidth : "",
      previewBoxShadow: highlighted ? getComputedStyle(highlighted).boxShadow : "",
      selectedRows: selected.map((el) => el.getAttribute("data-row") || ""),
      selectedCols: selected.map((el) => el.getAttribute("data-col") || ""),
      cardVisible: !!card && getComputedStyle(card).display !== "none",
      activeMediaIndex: activeMedia ? Number(activeMedia.getAttribute("data-media-index")) : null,
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
      env: { ...process.env, HERDR_PANE_ID: "", YUNOMI_NOTIFY_CMD: "", YUNOMI_LOCK_DIR: LOCK_DIR, YUNOMI_REVIEW_DIR: join(tmpdir(), "yunomi-review-" + Date.now() + "-" + Math.random().toString(36).slice(2,6)) },
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
    await page.evaluate(() => {
      const events: string[] = [];
      const stream = new EventSource(`${location.origin}/sse`);
      stream.addEventListener("send-now", (event) => events.push((event as MessageEvent).data));
      (window as unknown as { __imageCommentEvents: string[]; __imageCommentStream: EventSource }).__imageCommentEvents = events;
      (window as unknown as { __imageCommentEvents: string[]; __imageCommentStream: EventSource }).__imageCommentStream = stream;
    });

    const buttonSummary = await page.evaluate(() => {
      const buttons = Array.from(document.querySelectorAll<HTMLButtonElement>("#md-preview .yunomi-comment-button"));
      const normalHosts = buttons.filter((button) => {
        const host = button.parentElement;
        return !host?.matches(".yunomi-media-comment-host,.video-overlay-wrapper,.mermaid-container,.timeline-thumb-wrapper");
      });
      return {
        markdown: normalHosts.length > 0,
        normalHosts: normalHosts.map((button) => button.parentElement?.outerHTML.slice(0, 180) || ""),
        image: !!document.querySelector("#md-preview .yunomi-media-comment-host > img:not(.timeline-thumb)")?.parentElement?.querySelector(":scope > .yunomi-comment-button"),
        video: !!document.querySelector("#md-preview .video-overlay-wrapper > .yunomi-comment-button"),
        mermaid: !!document.querySelector("#md-preview .mermaid-container > .yunomi-comment-button"),
        mermaidFullscreenButtons: document.querySelectorAll("#md-preview .mermaid-fullscreen-btn").length,
        total: buttons.length,
      };
    });
    assert(
      !buttonSummary.markdown &&
        buttonSummary.image &&
        buttonSummary.video &&
        buttonSummary.mermaid &&
        buttonSummary.mermaidFullscreenButtons === 0 &&
        buttonSummary.total >= 4,
      "画像・動画・Mermaidだけにコメントアイコンがあり、通常Markdown要素には表示されない",
      buttonSummary,
    );

    const imageButton = page.locator("#md-preview .yunomi-media-comment-host > img:not(.timeline-thumb)").first().locator("..").locator(":scope > .yunomi-comment-button");
    await imageButton.hover();
    const imageAffordance = await imageButton.evaluate((button) => {
      return {
        ariaLabel: button.getAttribute("aria-label"),
        title: button.getAttribute("title"),
        captions: button.querySelectorAll(".yunomi-comment-button-label").length,
      };
    });
    assert(
      imageAffordance.ariaLabel === "Comment on image" &&
        imageAffordance.title === null &&
        imageAffordance.captions === 0,
      "画像コメントの対象名は支援技術だけに提供し、画面には重ねて表示しない",
      imageAffordance,
    );

    await page.locator("#md-preview img:not(.timeline-thumb)").first().evaluate((img) => {
      img.parentElement?.querySelector<HTMLButtonElement>(":scope > .yunomi-comment-button")?.click();
    });
    const imageCard = await cardState(page);
    assert(
      imageCard.visible && imageCard.preview === '画像「Before」',
      "画像右上のコメントカードは技術的なURLではなく画像名を引用表示する",
      imageCard,
    );
    const imageEditor = page.locator(".yunomi-inline-comment-editor:visible");
    const imageEditorInputLocator = imageEditor.locator("#comment-input");
    assert(
      await imageEditorInputLocator.evaluate((input) => document.activeElement === input),
      "画像コメントを開くと入力欄へ自動フォーカスする",
    );
    await imageEditorInputLocator.pressSequentially("keyboard image comment");
    const imageEditorInput = await page.evaluate(() => {
      const input = document.querySelector<HTMLTextAreaElement>(".yunomi-inline-comment-editor #comment-input");
      const editor = input?.closest<HTMLElement>(".yunomi-inline-comment-editor");
      const image = document.querySelector<HTMLElement>("#md-preview img[alt='Before']");
      const editorRect = editor?.getBoundingClientRect();
      const imageRect = image?.getBoundingClientRect();
      return {
        focus: document.activeElement?.id || "",
        value: input?.value || "",
        editorBelowImage: !!editorRect && !!imageRect && editorRect.top >= imageRect.bottom,
      };
    });
    assert(
      imageEditorInput.focus === "comment-input" &&
        imageEditorInput.value === "keyboard image comment" &&
        imageEditorInput.editorBelowImage,
      "画像コメントのエディタは画像直下でフォーカスを受け、実キーボード入力できる",
      imageEditorInput,
    );
    const imageButtonGeometry = await page.locator("#md-preview .yunomi-media-comment-host > img:not(.timeline-thumb)").first().evaluate((img) => {
      const button = img.parentElement?.querySelector<HTMLElement>(":scope > .yunomi-comment-button");
      const image = img.getBoundingClientRect();
      const host = img.parentElement?.getBoundingClientRect();
      const control = button?.getBoundingClientRect();
      return {
        inside: !!control && control.left >= image.left && control.top >= image.top && control.right <= image.right && control.bottom <= image.bottom,
        image: { left: image.left, top: image.top, right: image.right, bottom: image.bottom },
        host: host && { left: host.left, top: host.top, right: host.right, bottom: host.bottom },
        control: control && { left: control.left, top: control.top, right: control.right, bottom: control.bottom },
      };
    });
    assert(imageButtonGeometry.inside, "画像のコメントアイコンは画像本体の右上に収まり、親段落や表セルへは広がらない", imageButtonGeometry);
    await page.locator(".yunomi-inline-comment-editor #comment-input").fill("image payload check");
    await page.locator("#send-now-comment").click();
    await page.waitForFunction(() => ((window as unknown as { __imageCommentEvents?: string[] }).__imageCommentEvents || []).length > 0);
    const imagePayload = await page.evaluate(() => {
      const events = (window as unknown as { __imageCommentEvents: string[] }).__imageCommentEvents;
      return JSON.parse(events[events.length - 1]);
    });
    assert(
      imagePayload.target === 'image (alt="Before" src="./assets/screenshot-before.png")',
      "画像コメントの即時送信は画像種別・alt・URLをSSEへ含める",
      imagePayload,
    );
    if (await page.locator(".comment-list:not(.collapsed)").count() === 1) {
      await page.locator("#comment-list-minimize").click();
      await page.waitForSelector(".comment-list.collapsed");
    }

    await page.locator("#md-preview .mermaid-container > .yunomi-comment-button").first().click();
    const mermaidCard = await cardState(page);
    assert(
      mermaidCard.visible && mermaidCard.preview.includes("flowchart"),
      "Mermaid右上のコメントアイコンでコメントカードが開く",
      mermaidCard,
    );
    await closeCard(page);

    await page.locator("#md-preview .video-overlay-wrapper > .yunomi-comment-button").first().click();
    const videoCard = await cardState(page);
    assert(videoCard.visible && videoCard.preview.length > 0, "動画右上のコメントアイコンでコメントカードが開く", videoCard);
    await closeCard(page);

    await page.waitForFunction(() => {
      const wrapper = document.querySelector("#md-preview .video-overlay-wrapper");
      return !!wrapper && wrapper.querySelectorAll(".video-timeline .timeline-thumb-wrapper").length > 0;
    }, undefined, { timeout: 30000 });
    const timelineButton = await page.evaluate(() => {
      const thumb = document.querySelector<HTMLElement>("#md-preview .video-timeline .timeline-thumb-wrapper");
      const button = thumb?.querySelector<HTMLButtonElement>(":scope > .yunomi-comment-button");
      button?.click();
      return { hasThumb: !!thumb, hasButton: !!button };
    });
    const timelineCard = await cardState(page);
    assert(
      timelineButton.hasThumb && timelineButton.hasButton && timelineCard.visible && timelineCard.preview.length > 0,
      "動画サムネ右上のコメントアイコンでコメントカードが開く",
      { timelineButton, timelineCard },
    );
    await closeCard(page);

    const headingTarget = page.locator("#md-preview h1[data-source-line]");
    const headingCount = await headingTarget.count();
    assert(headingCount === 1, "枠線を検証するMarkdown見出しが一意に存在する", { headingCount });
    await headingTarget.click();
    await page.waitForTimeout(200);
    const headingSelection = await selectedState(page);
    assert(
      headingSelection.previewText.length > 0 &&
        headingSelection.previewBackgroundColor !== "rgba(0, 0, 0, 0)" &&
        headingSelection.previewBackgroundColor !== "transparent" &&
        headingSelection.previewOutlineStyle === "none" &&
        headingSelection.previewBoxShadow.includes("6px") &&
        !headingSelection.previewBoxShadow.includes("inset"),
      "選択中のMarkdown本文は枠線を付けず背景色だけを外側へ広げる",
      headingSelection,
    );
    await closeCard(page);

    await page.evaluate((row) => {
      document.querySelector<HTMLElement>(`.md-right td[data-row="${row}"][data-col="1"]`)?.click();
    }, 0);
    await page.waitForTimeout(100);
    const beforeShift = await selectedState(page);
    await closeCard(page);
    await page.keyboard.press("Shift+J");
    await page.keyboard.press("Shift+K");
    const afterShift = await selectedState(page);
    assert(
      JSON.stringify(beforeShift.selectedRows) === JSON.stringify(afterShift.selectedRows),
      "Shift+j/k のコメント対象移動は削除され、選択行を変更しない",
      { beforeShift, afterShift },
    );

    await page.locator(".media-sidebar-thumb[data-media-index='3']").click();
    await page.waitForTimeout(200);
    const mediaBeforeShift = await selectedState(page);
    await page.keyboard.press("Shift+J");
    await page.keyboard.press("Shift+K");
    const mediaAfterShift = await selectedState(page);
    assert(
      mediaBeforeShift.activeMediaIndex === 3 && mediaAfterShift.activeMediaIndex === 3,
      "Shift+j/k はメディアサイドバーにも二重発火しない",
      { mediaBeforeShift, mediaAfterShift },
    );

    await page.keyboard.press("j");
    const mediaAfterPlainJ = await selectedState(page);
    await page.keyboard.press("k");
    const mediaAfterPlainK = await selectedState(page);
    assert(
      mediaAfterPlainJ.activeMediaIndex === 4 && mediaAfterPlainK.activeMediaIndex === 3,
      "通常の hjkl メディア移動は残る",
      { mediaAfterPlainJ, mediaAfterPlainK },
    );

    await page.evaluate((row) => {
      document.querySelector<HTMLElement>(`.md-right td[data-row="${row}"][data-col="1"]`)?.click();
    }, 0);
    await closeCard(page);
    await page.keyboard.press("i");
    const iCard = await cardState(page);
    assert(iCard.visible && iCard.preview.length > 0, "i は選択中の対象のコメントカードを開く", iCard);
    await closeCard(page);

    await page.evaluate(() => {
      const cells = Array.from(document.querySelectorAll<HTMLElement>("#md-preview table:not(.frontmatter-table) td"));
      const cell = cells.find((el) => el.offsetParent !== null && el.getBoundingClientRect().width > 0);
      cell?.click();
    });
    await page.waitForTimeout(100);
    const tableStart = await selectedState(page);
    await closeCard(page);
    await page.keyboard.press("Shift+L");
    const tableRight = await selectedState(page);
    await page.keyboard.press("Enter");
    const enterCard = await cardState(page);
    assert(
      tableStart.selectedRows[0] === tableRight.selectedRows[0] &&
        tableStart.previewText !== tableRight.previewText &&
        enterCard.visible,
      "Shift+l は表セルを右へ移動し、Enter は選択セルのカードを開く",
      { tableStart, tableRight, enterCard },
    );
    await closeCard(page);
    await page.evaluate(() => {
      const cells = Array.from(document.querySelectorAll<HTMLElement>("#md-preview table:not(.frontmatter-table) td"));
      const codeCell = cells.find((el) =>
        (el.textContent || "").includes("page.goto('/')") &&
        !el.closest("details:not([open])") &&
        el.offsetParent !== null &&
        el.getBoundingClientRect().width > 0 &&
        el.getBoundingClientRect().height > 0
      );
      codeCell?.click();
    });
    try {
      await page.waitForSelector(".yunomi-inline-comment-editor", { state: "visible" });
    } catch (error: unknown) {
      const editorAncestors = await page.locator(".yunomi-inline-comment-editor").first().evaluate((editor) => {
        const result = [];
        for (let node: Element | null = editor; node; node = node.parentElement) {
          const element = node as HTMLElement;
          const style = getComputedStyle(element);
          result.push({
            tag: element.tagName,
            id: element.id,
            className: element.className,
            display: style.display,
            visibility: style.visibility,
            offsetParent: element.offsetParent?.tagName || null,
            open: element.matches("details") ? element.hasAttribute("open") : undefined,
          });
        }
        return result;
      });
      throw new Error(`${String(error)}\neditor ancestors: ${JSON.stringify(editorAncestors)}`);
    }
    const codeCellCard = await cardState(page);
    assert(codeCellCard.preview.includes("page.goto"), "提出値検証用にコード表セルのコメントカードが開く", codeCellCard);
    const tableEditor = page.locator(".yunomi-inline-comment-editor:visible");
    await tableEditor.locator("#comment-input").fill("table cell value check");
    await tableEditor.locator("#save-comment").click();
    await page.waitForFunction(() => Array.from(document.querySelectorAll(".yunomi-inline-comment-text")).some((node) => node.textContent === "table cell value check"));

    await page.evaluate(() => {
      const thumbs = Array.from(document.querySelectorAll<HTMLElement>("#md-preview .video-timeline .timeline-thumb-wrapper"));
      const thumb = thumbs.find((el) => el.offsetParent !== null && el.querySelector(":scope > .yunomi-comment-button"));
      thumb?.querySelector<HTMLButtonElement>(":scope > .yunomi-comment-button")?.click();
    });
    const valueTimelineCard = await cardState(page);
    assert(valueTimelineCard.visible, "提出値検証用に動画サムネコメントカードが開く", valueTimelineCard);
    const timelineEditor = page.locator(".yunomi-inline-comment-editor:visible");
    await timelineEditor.locator("#comment-input").fill("video timeline value check");
    await timelineEditor.locator("#save-comment").click();
    await page.waitForFunction(() => Array.from(document.querySelectorAll(".yunomi-inline-comment-text")).some((node) => node.textContent === "video timeline value check"));

    await page.locator("#send-and-exit").click();
    await page.waitForSelector("#submit-modal.visible", { timeout: 3000 });
    const beforeModalKeys = await selectedState(page);
    await page.keyboard.press("Shift+J");
    await page.keyboard.press("i");
    const afterModalKeys = await selectedState(page);
    const modalStillVisible = await page.locator("#submit-modal.visible").count();
    assert(
      modalStillVisible === 1 &&
        JSON.stringify(beforeModalKeys.selectedRows) === JSON.stringify(afterModalKeys.selectedRows),
      "送信ダイアログ表示中は Shift+hjkl と i/Enter が無効",
      { beforeModalKeys, afterModalKeys, modalStillVisible },
    );
    const exitPromise = waitForExit(proc);
    await page.locator("#modal-approve").click();
    const exitCode = await exitPromise;
    assert(exitCode === 0, "Submit後にサーバーが正常終了する", { exitCode });
    assert(
      serverOutput.includes("text: table cell value check") &&
        serverOutput.includes("Markdown table cell") &&
        serverOutput.includes("page.goto") &&
        serverOutput.includes("text: video timeline value check") &&
        serverOutput.includes("Video thumbnail") &&
        serverOutput.includes("src=./videos/"),
      "提出YAMLのvalueで表セルと動画サムネ時刻が復元できる",
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
