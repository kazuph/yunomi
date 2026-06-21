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
    const card = document.querySelector<HTMLElement>("#comment-card");
    return {
      visible: !!card && getComputedStyle(card).display !== "none",
      preview: document.querySelector("#cell-preview")?.textContent?.trim() || "",
    };
  });
}

async function selectedState(page: Page): Promise<{
  previewText: string;
  selectedRows: string[];
  selectedCols: string[];
  cardVisible: boolean;
  activeMediaIndex: number | null;
}> {
  return page.evaluate(() => {
    const selected = Array.from(document.querySelectorAll<HTMLElement>(".md-right td.selected"));
    const highlighted = document.querySelector<HTMLElement>(".md-preview .preview-highlight");
    const card = document.querySelector<HTMLElement>("#comment-card");
    const activeMedia = document.querySelector<HTMLElement>(".media-sidebar-thumb.active");
    return {
      previewText: highlighted?.textContent?.trim() || highlighted?.getAttribute("title") || "",
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
      env: { ...process.env, YUNOMI_LOCK_DIR: LOCK_DIR },
      stdio: ["ignore", "pipe", "pipe"],
    },
  );

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

    const buttonSummary = await page.evaluate(() => ({
      markdown: !!document.querySelector("#md-preview p > .yunomi-comment-button, #md-preview li > .yunomi-comment-button, #md-preview blockquote > .yunomi-comment-button"),
      image: !!document.querySelector("#md-preview img:not(.timeline-thumb)")?.parentElement?.querySelector(":scope > .yunomi-comment-button"),
      video: !!document.querySelector("#md-preview .video-overlay-wrapper > .yunomi-comment-button"),
      total: document.querySelectorAll("#md-preview .yunomi-comment-button").length,
    }));
    assert(
      buttonSummary.markdown && buttonSummary.image && buttonSummary.video && buttonSummary.total >= 3,
      "Markdown・画像・動画にコメントアイコンが常設される",
      buttonSummary,
    );

    await page.locator("#md-preview img:not(.timeline-thumb)").first().evaluate((img) => {
      img.parentElement?.querySelector<HTMLButtonElement>(":scope > .yunomi-comment-button")?.click();
    });
    const imageCard = await cardState(page);
    assert(imageCard.visible && imageCard.preview.length > 0, "画像右上のコメントアイコンでコメントカードが開く", imageCard);
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
  } finally {
    if (browser) await browser.close();
    proc.kill("SIGTERM");
  }

  if (failed > 0) {
    process.exit(1);
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
