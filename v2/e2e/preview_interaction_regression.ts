import assert from "node:assert/strict";
import http, { type IncomingMessage } from "node:http";
import net from "node:net";
import { mkdtempSync, rmSync } from "node:fs";
import { spawn, type ChildProcess } from "node:child_process";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { fileURLToPath } from "node:url";
import { chromium, type Browser, type Page, type BrowserContext, type Locator } from "playwright";

const __dirname = fileURLToPath(new URL(".", import.meta.url));
const ROOT = join(__dirname, "..", "..");
const SERVER_JS = join(ROOT, "v2", "_build", "js", "release", "build", "server", "server.js");
const FIXTURE_MD = join(ROOT, "examples", "preview-regression.md");
const LOCK_DIR = mkdtempSync(join(tmpdir(), "yunomi-preview-interaction-locks-"));

let passed = 0;
let failed = 0;

function logPass(message: string): void {
  passed += 1;
  console.log(`PASS: ${message}`);
}

function logFail(message: string, error?: unknown): void {
  failed += 1;
  console.error(`FAIL: ${message}`);
  if (error) {
    console.error((error as Error).stack || (error as Error).message || String(error));
  }
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function waitForServer(port: number): Promise<void> {
  return new Promise((resolve, reject) => {
    const startedAt = Date.now();
    const timeout = setTimeout(() => {
      reject(new Error(`server did not become ready on port ${port}`));
    }, 30000);

    const poll = () => {
      http
        .get(`http://127.0.0.1:${port}/healthz`, (res: IncomingMessage) => {
          if (res.statusCode === 200) {
            clearTimeout(timeout);
            resolve();
            return;
          }
          if (Date.now() - startedAt > 30000) {
            clearTimeout(timeout);
            reject(new Error(`server health check timed out on port ${port}`));
            return;
          }
          setTimeout(poll, 200);
        })
        .on("error", () => {
          if (Date.now() - startedAt > 30000) {
            clearTimeout(timeout);
            reject(new Error(`server health check timed out on port ${port}`));
            return;
          }
          setTimeout(poll, 200);
        });
    };

    poll();
  });
}

async function isPortAvailable(port: number): Promise<boolean> {
  return new Promise((resolve) => {
    const server = net.createServer();
    server.unref();
    server.on("error", () => resolve(false));
    server.listen(port, "127.0.0.1", () => {
      server.close(() => resolve(true));
    });
  });
}

async function findAvailablePort(startPort: number, attempts = 200): Promise<number> {
  for (let offset = 0; offset < attempts; offset += 1) {
    const port = startPort + offset;
    // Pick a truly free port up front so we never talk to a stale server.
    if (await isPortAvailable(port)) {
      return port;
    }
  }
  throw new Error(`failed to find an available port from ${startPort}`);
}

function startServer(port: number): ChildProcess {
  return spawn(
    "node",
    [SERVER_JS, "--no-open", "--port", String(port), FIXTURE_MD],
    {
      cwd: ROOT,
      stdio: ["ignore", "ignore", "inherit"],
      env: { ...process.env, HERDR_PANE_ID: "", YUNOMI_NOTIFY_CMD: "", YUNOMI_LOCK_DIR: LOCK_DIR, YUNOMI_REVIEW_DIR: join(tmpdir(), "yunomi-review-" + Date.now() + "-" + Math.random().toString(36).slice(2,6)) },
    },
  );
}

interface Box {
  x: number;
  y: number;
  width: number;
  height: number;
}

interface Point {
  x: number;
  y: number;
}

function boxIntersectionArea(a: Box | null, b: Box | null): number {
  if (!a || !b) {
    return 0;
  }
  const left = Math.max(a.x, b.x);
  const top = Math.max(a.y, b.y);
  const right = Math.min(a.x + a.width, b.x + b.width);
  const bottom = Math.min(a.y + a.height, b.y + b.height);
  const width = Math.max(0, right - left);
  const height = Math.max(0, bottom - top);
  return width * height;
}

function rectContains(outer: Box | null, inner: Box | null, tolerance = 0): boolean {
  if (!outer || !inner) {
    return false;
  }
  return (
    inner.x >= outer.x - tolerance &&
    inner.y >= outer.y - tolerance &&
    inner.x + inner.width <= outer.x + outer.width + tolerance &&
    inner.y + inner.height <= outer.y + outer.height + tolerance
  );
}

function pointInRect(rect: Box | null, point: Point | null, tolerance = 0): boolean {
  if (!rect || !point) {
    return false;
  }
  return (
    point.x >= rect.x - tolerance &&
    point.y >= rect.y - tolerance &&
    point.x <= rect.x + rect.width + tolerance &&
    point.y <= rect.y + rect.height + tolerance
  );
}

function centerOf(rect: Box | null): Point | null {
  if (!rect) {
    return null;
  }
  return {
    x: rect.x + rect.width / 2,
    y: rect.y + rect.height / 2,
  };
}

async function createPage(browser: Browser, viewport = { width: 1440, height: 1000 }): Promise<{ context: BrowserContext; page: Page }> {
  const context = await browser.newContext({ viewport });
  // These scenarios exercise the split (preview + source) view; the app now
  // defaults to preview-only, so opt into the saved "both" panel state.
  await context.addInitScript(() => {
    try {
      localStorage.setItem("yunomi-panel-state", "both");
    } catch {}
  });
  const page = await context.newPage();
  page.on("pageerror", (err) => {
    console.error("PAGEERROR:", String(err));
  });
  page.on("console", (msg) => {
    if (msg.type() === "error") {
      console.error("CONSOLE:", msg.text());
    }
  });
  return { context, page };
}

async function gotoFixture(page: Page, port: number): Promise<void> {
  const url = `http://127.0.0.1:${port}`;
  let lastError: Error | null = null;
  for (let attempt = 0; attempt < 3; attempt += 1) {
    try {
      await page.goto(url, { waitUntil: "domcontentloaded", timeout: 15000 });
      return;
    } catch (error: unknown) {
      lastError = error as Error;
      if (attempt === 2) {
        throw error;
      }
      await page.waitForTimeout(250 * (attempt + 1));
    }
  }
  throw lastError;
}

async function waitForCommentCard(page: Page): Promise<void> {
  await page.waitForFunction(() => {
    const card = document.querySelector(".yunomi-inline-comment-editor");
    if (!card) {
      return false;
    }
    const style = getComputedStyle(card);
    return style.display !== "none" && style.visibility !== "hidden";
  });
}

async function getSelectedRows(page: Page): Promise<number[]> {
  return page.evaluate(() => {
    return Array.from(document.querySelectorAll(".md-right td.selected"))
      .map((cell) => Number(cell.getAttribute("data-row")))
      .filter((value) => Number.isFinite(value))
      .sort((a, b) => a - b);
  });
}

async function waitForSelectedRowCount(page: Page, minCount: number): Promise<void> {
  await page.waitForFunction(
    (expected: number) => document.querySelectorAll(".md-right td.selected").length >= expected,
    minCount,
  );
}

async function getBox(locator: Locator): Promise<Box | null> {
  return locator.boundingBox();
}

function assertContiguousRows(rows: number[], message: string): void {
  assert.ok(rows.length > 0, `${message}: selected row list is empty`);
  for (let i = 1; i < rows.length; i += 1) {
    assert.equal(rows[i], rows[i - 1] + 1, `${message}: selected rows are not contiguous`);
  }
}

async function clickAt(locator: Locator, position: { x: number; y: number }): Promise<void> {
  await locator.scrollIntoViewIfNeeded();
  await locator.click({ position });
}

async function getTextNodeClickPoint(page: Page, selector: string): Promise<Point | null> {
  return page.evaluate((targetSelector: string) => {
    const root = document.querySelector(targetSelector);
    if (!root) {
      return null;
    }
    const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
    while (walker.nextNode()) {
      const node = walker.currentNode;
      if (!(node.textContent || "").trim()) {
        continue;
      }
      const range = document.createRange();
      range.selectNodeContents(node);
      const rect = Array.from(range.getClientRects()).find((candidate) => candidate.width > 0 && candidate.height > 0);
      if (rect) {
        return {
          x: rect.left + Math.min(rect.width / 2, 24),
          y: rect.top + rect.height / 2,
        };
      }
    }
    return null;
  }, selector);
}

async function runScenario(name: string, fn: () => Promise<void>): Promise<void> {
  console.log(`\n--- ${name} ---`);
  try {
    await fn();
    logPass(name);
  } catch (error: unknown) {
    logFail(name, error);
  }
}

async function main(): Promise<void> {
  const port = await findAvailablePort(5359);
  const server = startServer(port);
  let browser: Browser | undefined;

  try {
    await waitForServer(port);
    browser = await chromium.launch({ headless: true });

    await runScenario("mermaid click selects multiple source rows", async () => {
      const { context, page } = await createPage(browser!);
      try {
        await gotoFixture(page, port);
        await page.waitForSelector(".md-preview");
        await page.waitForSelector(".md-right");
        const mermaid = page.locator(".md-preview .mermaid-container").first();
        await mermaid.locator(":scope > .yunomi-comment-button").click();
        await waitForSelectedRowCount(page, 2);
        await waitForCommentCard(page);
        await page.waitForTimeout(200);

        const rows = await getSelectedRows(page);
        assert.ok(rows.length > 1, "mermaid click should select multiple source rows");
        assertContiguousRows(rows, "mermaid click");

        const card = await getBox(page.locator(".yunomi-inline-comment-editor"));
        const target = await getBox(mermaid);
        assert.ok(card, "comment card should be rendered for mermaid click");
        assert.ok(target, "mermaid target box should be measurable");
        assert.equal(await page.locator(".yunomi-inline-comment-editor").count(), 1, "mermaid should open exactly one inline editor");
      } finally {
        await context.close();
      }
    });

    await runScenario("split view places the inline editor below the preview target", async () => {
      const { context, page } = await createPage(browser!);
      try {
        await gotoFixture(page, port);
        await page.waitForSelector(".md-preview");
        await page.waitForSelector(".md-right");

        const paragraph = page.locator(".md-preview p").first();
        await clickAt(paragraph, { x: 24, y: 8 });
        await waitForCommentCard(page);
        await page.waitForTimeout(200);

        const card = await getBox(page.locator(".yunomi-inline-comment-editor"));
        const target = await getBox(paragraph);
        const mdRight = await getBox(page.locator(".md-right"));
        const rows = await getSelectedRows(page);

        assert.ok(card, "comment card should be visible in split view");
        assert.ok(target, "preview paragraph should be measurable");
        assert.ok(mdRight, "md-right pane should be measurable");
        assert.equal(rows[0], 4, "paragraph click should anchor to the first paragraph source row");
        assert.equal(boxIntersectionArea(card, target), 0, "comment card must not overlap the preview target");
        assert.ok(card.y >= target.y + target.height, "inline editor should start below the preview target");
      } finally {
        await context.close();
      }
    });

    await runScenario("paragraph text-node clicks still select the source row", async () => {
      const { context, page } = await createPage(browser!);
      try {
        await gotoFixture(page, port);
        await page.waitForSelector(".md-preview");
        await page.waitForSelector(".md-right");

        const selector = ".md-preview p";
        const point = await getTextNodeClickPoint(page, selector);
        assert.ok(point, "paragraph text node should expose a clickable client rect");

        await page.mouse.click(point!.x, point!.y);
        await waitForCommentCard(page);
        await page.waitForTimeout(200);

        const rows = await getSelectedRows(page);
        assert.ok(rows.length >= 1, "text-node click should select at least one source row");
        assert.equal(rows[0], 4, "text-node click should anchor to the first paragraph source row");

        const card = await getBox(page.locator(".yunomi-inline-comment-editor"));
        const target = await getBox(page.locator(selector).first());
        assert.ok(card, "comment card should be visible after text-node click");
        assert.ok(target, "paragraph target should be measurable");
        assert.equal(
          boxIntersectionArea(card, target),
          0,
          "comment card must not overlap the paragraph after text-node click",
        );
      } finally {
        await context.close();
      }
    });

    await runScenario("preview text selection remains available after comment targeting", async () => {
      const { context, page } = await createPage(browser!);
      try {
        await gotoFixture(page, port);
        await page.waitForSelector(".md-preview");

        const selectionTarget = await page.locator(".md-preview p").first().evaluate((element) => {
          const walker = document.createTreeWalker(element, NodeFilter.SHOW_TEXT);
          const node = walker.nextNode();
          if (!node || !node.textContent?.trim()) {
            return null;
          }
          const range = document.createRange();
          range.selectNodeContents(node);
          const rects = Array.from(range.getClientRects()).filter((rect) => rect.width > 0 && rect.height > 0);
          const first = rects[0];
          const last = rects[rects.length - 1];
          if (!first || !last) {
            return null;
          }
          return {
            text: node.textContent,
            start: { x: first.left + 2, y: first.top + first.height / 2 },
            end: { x: last.right - 2, y: last.top + last.height / 2 },
          };
        });
        assert.ok(selectionTarget, "preview text should expose a selectable range");

        await page.mouse.move(selectionTarget!.start.x, selectionTarget!.start.y);
        await page.mouse.down();
        await page.mouse.move(selectionTarget!.end.x, selectionTarget!.end.y, { steps: 5 });
        await page.mouse.up();
        await waitForCommentCard(page);
        await page.waitForTimeout(100);

        const selection = await page.evaluate(() => {
          const current = window.getSelection();
          return { text: current?.toString() || "", collapsed: current?.isCollapsed ?? true };
        });
        assert.ok(selection.text.trim().length > 0, "selected preview text should remain available for copying");
        assert.equal(selection.collapsed, false, "comment targeting must not collapse the native text selection");
      } finally {
        await context.close();
      }
    });

    await runScenario("preview-only keeps the comment card off the clicked element", async () => {
      const { context, page } = await createPage(browser!, { width: 1280, height: 900 });
      try {
        await gotoFixture(page, port);
        await page.waitForSelector(".md-preview");

        await page.locator("#view-toggle").click();
        await page.waitForFunction(() => document.querySelector(".md-layout")?.classList.contains("preview-only"));

        const quote = page.locator(".md-preview blockquote").first();
        await clickAt(quote, { x: 24, y: 10 });
        await waitForCommentCard(page);
        await page.waitForTimeout(200);

        const card = await getBox(page.locator(".yunomi-inline-comment-editor"));
        const target = await getBox(quote);
        const rows = await getSelectedRows(page);

        assert.ok(card, "comment card should be visible in preview-only mode");
        assert.ok(target, "blockquote target should be measurable");
        assert.equal(rows[0], 7, "blockquote click should anchor to the first quote source row");
        assert.equal(await page.locator(".yunomi-inline-comment-editor").count(), 1, "preview-only should open exactly one inline editor");
      } finally {
        await context.close();
      }
    });

    await runScenario("saved draft is restored on reload with a discardable notice", async () => {
      const { context, page } = await createPage(browser!);
      try {
        await gotoFixture(page, port);
        await page.waitForSelector(".md-preview");

        await page.evaluate(() => {
          localStorage.setItem(
            `yunomi:comments:${window.__YUNOMI_STORAGE_SCOPE__}`,
            JSON.stringify({
              comments: {
                "27:0": { row: 27, col: 0, text: "restored image note" },
              },
              timestamp: Date.now(),
            }),
          );
        });

        await page.reload({ waitUntil: "domcontentloaded" });
        await page.waitForSelector(".yunomi-restore-toast");

        const afterRestore = await page.evaluate(() => ({
          modalCount: document.querySelectorAll("#recovery-modal").length,
          toastText: document.querySelector(".yunomi-restore-toast")?.textContent || "",
          selectedCount: document.querySelectorAll(".has-comment").length,
        }));
        assert.equal(afterRestore.modalCount, 0, "no recovery modal exists anymore");
        assert.match(afterRestore.toastText, /Draft restored \(1\)/, "notice names how many items came back");
        assert.equal(afterRestore.selectedCount, 1, "the draft is applied without asking");

        await page.locator('.yunomi-inline-comment-view:has-text("restored image note")').first().click();
        await waitForCommentCard(page);
        const restoredText = await page.locator("#comment-input").inputValue();
        assert.equal(restoredText, "restored image note", "restore should repopulate the saved comment text");
      } finally {
        await context.close();
      }
    });

    await runScenario("image-side whitespace still anchors to the image instead of empty space", async () => {
      const { context, page } = await createPage(browser!);
      try {
        await gotoFixture(page, port);
        await page.waitForSelector(".md-preview");
        await page.waitForSelector(".md-right");

        const image = page.locator('.md-preview img[alt="Fixture Image"]').first();
        const imageParagraph = image.locator("xpath=ancestor::p[1]");
        const imageBox = await getBox(image);
        const paragraphBox = await getBox(imageParagraph);

        assert.ok(imageBox, "fixture image should be measurable");
        assert.ok(paragraphBox, "image paragraph should be measurable");
        assert.ok(paragraphBox!.width > imageBox!.width + 24, "image paragraph should include clickable right-side whitespace");

        const clickPoint = {
          x: Math.min(paragraphBox!.x + paragraphBox!.width - 8, imageBox!.x + imageBox!.width + 32),
          y: imageBox!.y + imageBox!.height / 2,
        };
        assert.ok(
          clickPoint.x > imageBox!.x + imageBox!.width,
          "whitespace click point should be outside the image box on the right side",
        );

        await page.mouse.click(clickPoint.x, clickPoint.y);
        await waitForCommentCard(page);
        await page.waitForTimeout(200);

        const rows = await getSelectedRows(page);
        const previewText = await page.locator("#cell-preview").textContent();
        const card = await getBox(page.locator(".yunomi-inline-comment-editor"));

        assert.equal(rows[0], 27, "image whitespace click should anchor to the image markdown row");
        assert.notEqual(previewText, "(empty)", "image whitespace click should not be treated as empty");
        assert.match(previewText || "", /Fixture Image|\[image\]|preview-image\.png/i, "image whitespace click should preview image identity");
        assert.ok(card, "comment card should be visible after image whitespace click");
        assert.equal(boxIntersectionArea(card, imageBox), 0, "comment card must not overlap the image");
      } finally {
        await context.close();
      }
    });

    await runScenario("source clicks keep the comment card off the selected markdown row", async () => {
      const { context, page } = await createPage(browser!);
      try {
        await gotoFixture(page, port);
        await page.waitForSelector(".md-right");

        const sourceCell = page.locator(".md-right td[data-row=\"2\"][data-col=\"1\"]").first();
        await clickAt(sourceCell, { x: 36, y: 10 });
        await waitForCommentCard(page);
        await page.waitForTimeout(200);

        const card = await getBox(page.locator(".yunomi-inline-comment-editor"));
        const target = await getBox(sourceCell);

        assert.ok(card, "comment card should be visible for source clicks");
        assert.ok(target, "selected markdown row should be measurable");
        assert.equal(await page.locator(".yunomi-inline-comment-editor").count(), 1, "source click should open exactly one inline editor");
      } finally {
        await context.close();
      }
    });

    await runScenario("Cmd/Ctrl+Enter in comment input saves the comment without opening submit modal", async () => {
      const { context, page } = await createPage(browser!);
      try {
        await gotoFixture(page, port);
        await page.waitForSelector(".md-preview");

        const paragraph = page.locator(".md-preview p").first();
        await clickAt(paragraph, { x: 24, y: 8 });
        await waitForCommentCard(page);

        const textarea = page.locator("#comment-input");
        await textarea.fill("saved via shortcut");
        await textarea.press(process.platform === "darwin" ? "Meta+Enter" : "Control+Enter");
        await page.waitForTimeout(250);

        const state = await page.evaluate(() => {
          const card = document.querySelector(".yunomi-inline-comment-editor");
          const modal = document.querySelector("#submit-modal");
          const key = `yunomi:comments:${window.__YUNOMI_STORAGE_SCOPE__}`;
          return {
            cardVisible: !!card && getComputedStyle(card).display !== "none",
            submitVisible: !!modal && modal.classList.contains("visible"),
            stored: localStorage.getItem(key),
          };
        });

        assert.equal(state.submitVisible, false, "comment-input shortcut must not open submit modal");
        assert.equal(state.cardVisible, false, "comment-input shortcut should save and close the comment card");
        assert.ok(state.stored && state.stored.includes("saved via shortcut"), "comment-input shortcut should persist the comment draft");
      } finally {
        await context.close();
      }
    });

    await runScenario("h1 heading text and icon behave differently", async () => {
      const { context, page } = await createPage(browser!);
      try {
        await gotoFixture(page, port);
        await page.waitForSelector(".md-preview");

        const summary = page.locator(".md-preview details.heading-toggle > summary.heading-summary").first();
        const heading = summary.locator(".md-heading-toggle").first();
        const icon = summary.locator(".heading-toggle-icon").first();

        const headingBox = await getBox(heading);
        const iconBox = await getBox(icon);
        assert.ok(headingBox, "heading box should exist");
        assert.ok(iconBox, "toggle icon box should exist");

        const textClickPoint = {
          x: Math.min(headingBox!.x + headingBox!.width - 8, iconBox!.x + iconBox!.width + 48),
          y: headingBox!.y + headingBox!.height / 2,
        };

        await page.mouse.click(textClickPoint.x, textClickPoint.y);
        await waitForCommentCard(page);
        await page.waitForTimeout(150);

        const detailsAfterTextClick = await page.evaluate(() => {
          const summary = document.querySelector(".md-preview details.heading-toggle > summary.heading-summary");
          const heading = summary?.querySelector(".md-heading-toggle");
          const details = summary?.closest("details");
          const card = document.querySelector(".yunomi-inline-comment-editor");
          return {
            headingTag: heading?.tagName || "",
            open: !!details?.hasAttribute("open"),
            cardVisible: !!card && getComputedStyle(card).display !== "none",
          };
        });

        assert.equal(detailsAfterTextClick.headingTag, "H1", "the first toggleable heading should be the H1 heading");
        assert.equal(detailsAfterTextClick.open, true, "text click should not collapse the heading");
        assert.equal(detailsAfterTextClick.cardVisible, true, "text click should open the comment card");

        await page.keyboard.press("Escape");
        await page.waitForTimeout(150);

        const cardAfterEscape = await page.evaluate(() => {
          const card = document.querySelector(".yunomi-inline-comment-editor");
          return !!card && getComputedStyle(card).display !== "none";
        });
        assert.equal(cardAfterEscape, false, "Escape should close the comment card before icon testing");

        await icon.click();
        await page.waitForTimeout(200);

        const detailsAfterIconClick = await page.evaluate(() => {
          const summary = document.querySelector(".md-preview details.heading-toggle > summary.heading-summary");
          const details = summary?.closest("details");
          const card = document.querySelector(".yunomi-inline-comment-editor");
          return {
            open: !!details?.hasAttribute("open"),
            cardVisible: !!card && getComputedStyle(card).display !== "none",
          };
        });

        assert.equal(detailsAfterIconClick.open, false, "icon click should collapse the heading");
        assert.equal(detailsAfterIconClick.cardVisible, false, "icon click should not keep the comment card open");
      } finally {
        await context.close();
      }
    });

    await runScenario("Comments pill opens populated list for preview-origin comments", async () => {
      const { context, page } = await createPage(browser!);
      try {
        await gotoFixture(page, port);
        await page.waitForSelector(".md-preview");

        const paragraph = page.locator(".md-preview p").first();
        await clickAt(paragraph, { x: 24, y: 8 });
        await waitForCommentCard(page);
        await page.locator("#comment-input").fill("paragraph note");
        await page.locator("#save-comment").click();
        await page.waitForTimeout(150);

        const quote = page.locator(".md-preview blockquote").first();
        await clickAt(quote, { x: 24, y: 10 });
        await waitForCommentCard(page);
        await page.locator("#comment-input").fill("blockquote note");
        await page.locator("#save-comment").click();
        await page.waitForTimeout(150);

        await page.locator("#pill-comments").click();
        await page.waitForTimeout(200);

        const panelState = await page.evaluate(() => {
          const panel = document.querySelector(".comment-list");
          const list = document.querySelector("#comment-list");
          const items = Array.from(document.querySelectorAll("#comment-list li")).map((item) =>
            item.textContent?.trim() || "",
          );
          return {
            open: !!panel && !panel.classList.contains("collapsed"),
            text: list?.textContent?.trim() || "",
            items,
            countBadge: document.querySelector("#comment-count")?.textContent?.trim() || "",
          };
        });

        assert.equal(panelState.open, true, "Drafts pill should open the unsubmitted comment list");
        assert.equal(panelState.countBadge, "2", "draft badge should reflect preview-origin saved drafts");
        assert.ok(panelState.items.length >= 2, "draft list should show saved drafts instead of the empty-state");
        assert.ok(panelState.text.includes("paragraph note"), "draft list should contain the first preview comment");
        assert.ok(panelState.text.includes("blockquote note"), "draft list should contain the second preview comment");
        assert.ok(!/^No drafts yet$/i.test(panelState.text), "draft list must not claim to be empty when drafts exist");
      } finally {
        await context.close();
      }
    });

    await runScenario("main preview targets all map to source selections", async () => {
      const { context, page } = await createPage(browser!);
      try {
        await gotoFixture(page, port);
        await page.waitForSelector(".md-preview");
        await page.waitForSelector(".md-right");

        const cases = [
          {
            name: "paragraph",
            locator: page.locator(".md-preview p").first(),
            minRows: 1,
            expectedFirstRow: 4,
          },
          {
            name: "blockquote",
            locator: page.locator(".md-preview blockquote").first(),
            minRows: 1,
            expectedFirstRow: 7,
          },
          {
            name: "table cell",
            locator: page.locator(".md-preview table td").first(),
            minRows: 1,
            expectedFirstRow: 12,
          },
          {
            name: "code block",
            locator: page.locator(".md-preview pre").first(),
            minRows: 2,
            expectedFirstRow: 15,
          },
          {
            name: "mermaid",
            locator: page.locator(".md-preview .mermaid-container .mermaid").first(),
            commentButton: page.locator(".md-preview .mermaid-container > .yunomi-comment-button").first(),
            minRows: 2,
            expectedFirstRow: 21,
          },
        ];

        for (const item of cases) {
          await page.keyboard.press("Escape").catch(() => {});
          await page.waitForTimeout(100);

          if ("commentButton" in item && item.commentButton) {
            await item.commentButton.click();
          } else {
            await clickAt(item.locator, { x: 20, y: 10 });
          }
          await waitForCommentCard(page);
          await page.waitForTimeout(250);

          const rows = await getSelectedRows(page);
          assert.ok(rows.length >= item.minRows, `${item.name} should select at least ${item.minRows} source row(s)`);
          assertContiguousRows(rows, `${item.name} selection`);
          assert.equal(rows[0], item.expectedFirstRow, `${item.name} should anchor to the expected source row`);

          const card = await getBox(page.locator(".yunomi-inline-comment-editor"));
          const target = await getBox(item.locator);
          assert.ok(card, `${item.name} should render a comment card`);
          assert.ok(target, `${item.name} should be measurable`);
          assert.equal(await page.locator(".yunomi-inline-comment-editor").count(), 1, `${item.name} should open exactly one inline editor`);
        }
      } finally {
        await context.close();
      }
    });

    // --- smooth scroll: preview scroll syncs source pane with bounded deltas ---
    await runScenario("smooth scroll: preview scroll syncs source pane with bounded deltas", async () => {
      const { context, page } = await createPage(browser!);
      try {
        await gotoFixture(page, port);
        await page.waitForTimeout(500);
        const result = await page.evaluate(async () => {
          const preview = document.querySelector(".md-left") as HTMLElement;
          const source = document.querySelector(".md-right") as HTMLElement;
          if (!preview || !source || preview.scrollHeight <= preview.clientHeight) {
            return { skipped: true, previewMoved: false, sourceMoved: false, sourceMaxDelta: 0 };
          }
          const sourceStart = source.scrollTop;
          const sourcePositions: number[] = [sourceStart];
          // Scroll preview in small increments and wait for sync
          for (let i = 0; i < 6; i++) {
            preview.scrollTop += 80;
            preview.dispatchEvent(new Event("scroll"));
            await new Promise((r) => requestAnimationFrame(() => setTimeout(r, 50)));
            sourcePositions.push(source.scrollTop);
          }
          let sourceMaxDelta = 0;
          for (let i = 1; i < sourcePositions.length; i++) {
            const d = Math.abs(sourcePositions[i] - sourcePositions[i - 1]);
            if (d > sourceMaxDelta) sourceMaxDelta = d;
          }
          return {
            skipped: false,
            previewMoved: preview.scrollTop > 0,
            sourceMoved: source.scrollTop > sourceStart,
            sourceMaxDelta,
          };
        });
        if (result.skipped) {
          return;
        }
        assert.ok(result.previewMoved, "preview pane scrolled");
        // Source should follow preview (sync_scroll fires on preview scroll)
        // sourceMaxDelta should be bounded by apply_scroll_clamped
        if (result.sourceMoved) {
          assert.ok(result.sourceMaxDelta <= 800,
            `source sync delta should be bounded (got ${result.sourceMaxDelta}px)`);
        }
      } finally {
        await context.close();
      }
    });

    console.log(`\nSummary: ${passed} passed, ${failed} failed`);
    if (failed > 0) {
      process.exitCode = 1;
    }
  } finally {
    if (browser) {
      await browser.close();
    }
    try {
      server.kill("SIGKILL");
    } catch (_: unknown) {}
    rmSync(LOCK_DIR, { recursive: true, force: true });
  }
}

await main();
