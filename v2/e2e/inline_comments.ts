import { spawn, type ChildProcess } from "node:child_process";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { chromium, type Browser, type Page } from "playwright";

const SERVER_JS = new URL("../_build/js/release/build/server/server.js", import.meta.url).pathname;
const WORK_DIR = mkdtempSync(join(tmpdir(), "yunomi-inline-comments-"));
const LOCK_DIR = join(WORK_DIR, "locks");
const REVIEW_DIR = join(WORK_DIR, "reviews");
const SAMPLE = join(WORK_DIR, "project-alpha", "docs", "inline-comments.md");
const BASE_PORT = 5887;
const EVIDENCE_DIR = process.env.YUNOMI_INLINE_EVIDENCE_DIR || "";

mkdirSync(LOCK_DIR, { recursive: true });
mkdirSync(REVIEW_DIR, { recursive: true });
mkdirSync(join(WORK_DIR, "project-alpha", "docs"), { recursive: true });
mkdirSync(join(WORK_DIR, "project-alpha", ".git"), { recursive: true });
if (EVIDENCE_DIR) mkdirSync(EVIDENCE_DIR, { recursive: true });
writeFileSync(SAMPLE, [
  "# Heading", "", "Paragraph with ![image](cat.png) and ![video](clip.mp4).", "",
  "- list item", "  - nested item", "", "1. ordered item", "", "> quoted block", "", "---", "",
  "```ts", "const answer = 42;", "```", "", "| Name | Value |", "|---|---|", "| alpha | **one** |", "",
  "```mermaid", "flowchart LR", "  A --> B", "```", "", "<details>", "<summary>More</summary>", "",
  "Inside details", "</details>", "", '<div class="raw-note">Raw HTML</div>',
].join("\n"));

let failures = 0;
function assert(condition: boolean, message: string, detail?: unknown): void {
  if (condition) console.log(`PASS: ${message}`);
  else { failures++; console.error(`FAIL: ${message}`); if (detail !== undefined) console.error(JSON.stringify(detail, null, 2)); }
}

function startServer(): Promise<{ proc: ChildProcess; port: number; output: () => string }> {
  return new Promise((resolve, reject) => {
    const proc = spawn(process.execPath, [SERVER_JS, "--no-open", "--port", String(BASE_PORT), SAMPLE], {
      cwd: new URL("..", import.meta.url).pathname,
      env: { ...process.env, HERDR_PANE_ID: "", YUNOMI_NOTIFY_CMD: "", YUNOMI_LOCK_DIR: LOCK_DIR, YUNOMI_REVIEW_DIR: REVIEW_DIR },
      stdio: ["ignore", "pipe", "pipe"],
    });
    let output = "";
    let settled = false;
    const consume = (chunk: Buffer) => {
      output += chunk.toString("utf8");
      const match = output.match(/http:\/\/127\.0\.0\.1:(\d+)/);
      if (!settled && match) { settled = true; resolve({ proc, port: Number(match[1]), output: () => output }); }
    };
    proc.stdout?.on("data", consume); proc.stderr?.on("data", consume);
    proc.on("exit", (code) => { if (!settled) reject(new Error(`server exited before ready (${code})\n${output}`)); });
    setTimeout(() => { if (!settled) reject(new Error(`server startup timeout\n${output}`)); }, 15_000);
  });
}

async function stopServer(proc: ChildProcess): Promise<void> {
  if (proc.exitCode !== null) return;
  await new Promise<void>((resolve) => { proc.once("exit", () => resolve()); proc.kill("SIGTERM"); setTimeout(resolve, 2_000); });
}

async function clickElement(page: Page, selector: string): Promise<void> {
  await page.locator(selector).first().evaluate((element) => {
    const media = element.matches("img:not(.timeline-thumb),video.video-preview,.mermaid-container");
    const host = element.matches("video.video-preview")
      ? element.closest(".video-overlay-wrapper")
      : element.matches("img:not(.timeline-thumb)")
        ? element.parentElement
        : element;
    const sourceHost = element.closest("[data-source-line],[data-source-start-line]");
    const button = media
      ? host?.querySelector(":scope > .yunomi-comment-button")
        || sourceHost?.querySelector(":scope > .yunomi-comment-button")
      : null;
    const clickable = button || element;
    (clickable as HTMLElement).click();
  });
  await page.waitForSelector(".yunomi-inline-comment-editor #comment-input", { state: "visible" });
}

async function layoutOverlaps(page: Page): Promise<Array<{ first: string; second: string; area: number }>> {
  return page.evaluate(() => {
    const selector = [
      "#md-preview h1", "#md-preview h2", "#md-preview h3", "#md-preview h4", "#md-preview h5", "#md-preview h6",
      "#md-preview p", "#md-preview li", "#md-preview ol", "#md-preview ul", "#md-preview td", "#md-preview th",
      "#md-preview pre", "#md-preview blockquote", "#md-preview hr", "#md-preview img:not(.timeline-thumb)",
      "#md-preview video.video-preview", "#md-preview .mermaid-container", "#md-preview details",
      "#md-preview .markdown-html-block", "#md-preview .yunomi-inline-comment-editor",
    ].join(",");
    const elements = Array.from(new Set(document.querySelectorAll<HTMLElement>(selector))).filter((element) => {
      const rect = element.getBoundingClientRect();
      const style = getComputedStyle(element);
      return style.display !== "none" && style.visibility !== "hidden" && rect.width > 0 && rect.height > 0;
    });
    const overlaps: Array<{ first: string; second: string; area: number }> = [];
    for (let firstIndex = 0; firstIndex < elements.length; firstIndex++) {
      for (let secondIndex = firstIndex + 1; secondIndex < elements.length; secondIndex++) {
        const first = elements[firstIndex];
        const second = elements[secondIndex];
        if (first.contains(second) || second.contains(first)) continue;
        const a = first.getBoundingClientRect();
        const b = second.getBoundingClientRect();
        const width = Math.max(0, Math.min(a.right, b.right) - Math.max(a.left, b.left));
        const height = Math.max(0, Math.min(a.bottom, b.bottom) - Math.max(a.top, b.top));
        if (width * height > 0) overlaps.push({
          first: `${first.tagName.toLowerCase()}.${first.className}`,
          second: `${second.tagName.toLowerCase()}.${second.className}`,
          area: width * height,
        });
      }
    }
    return overlaps;
  });
}

async function exerciseType(page: Page, name: string, selector: string): Promise<void> {
  await clickElement(page, selector);
  if (name === "heading") {
    const placement = await page.evaluate(() => {
      const heading = document.querySelector<HTMLElement>("#md-preview h1.md-heading-toggle");
      const content = heading?.closest("details.heading-toggle")?.querySelector<HTMLElement>(":scope > .toggle-content");
      const editor = content?.querySelector<HTMLElement>(":scope > .yunomi-inline-comment-editor");
      if (!heading || !content || !editor) return null;
      const headingRect = heading.getBoundingClientRect();
      const contentRect = content.getBoundingClientRect();
      const editorRect = editor.getBoundingClientRect();
      return { headingBottom: headingRect.bottom, editorTop: editorRect.top, editorWidth: editorRect.width, contentWidth: contentRect.width };
    });
    assert(placement !== null && placement.editorTop >= placement.headingBottom && Math.abs(placement.editorWidth - placement.contentWidth) <= 1, "heading editor renders below the heading at the full content width", placement);
    const overlaps = await layoutOverlaps(page);
    assert(overlaps.length === 0, "opening an editor does not overlap any rendered block element", overlaps);
  }
  if (EVIDENCE_DIR && name === "heading") {
    await page.screenshot({ path: join(EVIDENCE_DIR, "01-inline-editor-under-heading.png"), fullPage: true });
  }
  const initial = `created ${name}`;
  await page.locator(".yunomi-inline-comment-editor #comment-input").fill(initial);
  await page.locator(".yunomi-inline-comment-editor #save-comment").click();
  await page.waitForFunction((text) => Array.from(document.querySelectorAll(".yunomi-inline-comment-text")).some((node) => node.textContent === text), initial, { timeout: 5_000 }).catch(async (error) => {
    throw new Error(`${name}: saved inline comment did not render; editor=${await page.locator(".yunomi-inline-comment-editor").count()} comments=${await page.locator(".yunomi-inline-comment-text").allTextContents()}\n${error}`);
  });
  const surfaces = await page.locator(`.yunomi-inline-comment-text:text-is("${initial}")`).count();
  assert(surfaces >= 2, `${name}: saved comment is visible below preview and source`, { surfaces });
  if (EVIDENCE_DIR && name === "heading") {
    await page.screenshot({ path: join(EVIDENCE_DIR, "02-saved-comment-both-panes.png"), fullPage: true });
  }

  await page.locator(`.yunomi-inline-comment-view:has-text("${initial}")`).first().click();
  const edited = `edited ${name}`;
  await page.locator(".yunomi-inline-comment-editor #comment-input").fill(edited);
  await page.locator(".yunomi-inline-comment-editor #save-comment").click();
  await page.waitForFunction((text) => Array.from(document.querySelectorAll(".yunomi-inline-comment-text")).some((node) => node.textContent === text), edited, { timeout: 5_000 });
  assert(await page.locator(`.yunomi-inline-comment-text:text-is("${edited}")`).count() >= 2, `${name}: clicking the inline comment edits it in place`);

  await page.locator(`.yunomi-inline-comment-view:has-text("${edited}")`).first().click();
  await page.locator(".yunomi-inline-comment-editor #comment-input").fill("");
  await page.locator(".yunomi-inline-comment-editor #save-comment").click();
  await page.waitForFunction((text) => !Array.from(document.querySelectorAll(".yunomi-inline-comment-text")).some((node) => node.textContent === text), edited, { timeout: 5_000 });
  assert(await page.locator(`.yunomi-inline-comment-text:text-is("${edited}")`).count() === 0, `${name}: empty save deletes the comment`);
}

const server = await startServer();
let browser: Browser | null = null;
try {
  browser = await chromium.launch({ headless: true });
  const page = await browser.newPage({ viewport: { width: 1440, height: 1000 } });
  await page.goto(`http://127.0.0.1:${server.port}`, { waitUntil: "domcontentloaded" });
  await page.waitForSelector("#md-preview [data-source-line],#md-preview [data-source-start-line]", { timeout: 10_000 });
  await page.evaluate(() => document.querySelectorAll("details").forEach((element) => (element.open = true)));

  assert(await page.locator("#comment-card").count() === 0, "floating comment card is absent");
  const titlePath = await page.locator("header h1 .title-path").evaluate((element) => ({ text: element.textContent || "", display: getComputedStyle(element).display }));
  assert(titlePath.display !== "none" && titlePath.text.includes("project-alpha/docs"), "header shows project and relative directory path", titlePath);
  const initialOverlaps = await layoutOverlaps(page);
  assert(initialOverlaps.length === 0, "rendered block elements do not overlap before an editor opens", initialOverlaps);
  if (EVIDENCE_DIR) {
    await page.locator("header").screenshot({ path: join(EVIDENCE_DIR, "00-header-project-path.png") });
  }

  await clickElement(page, "#md-preview p[data-source-start-line]");
  await page.locator(".yunomi-inline-comment-editor #comment-input").fill("draft before fullscreen");
  await page.locator("#md-preview img:not(.timeline-thumb)").first().click();
  await page.waitForSelector("#image-fullscreen.visible");
  const fullscreenFocus = await page.evaluate(() => ({
    editorCount: document.querySelectorAll(".yunomi-inline-comment-editor").length,
    hiddenTextareaFocused: document.activeElement?.matches("#comment-input,.yunomi-inline-comment-editor textarea") || false,
    draft: localStorage.getItem(`yunomi:comments:${window.__YUNOMI_FILENAME__}`) || "",
  }));
  assert(fullscreenFocus.editorCount === 0 && !fullscreenFocus.hiddenTextareaFocused && fullscreenFocus.draft.includes("draft before fullscreen"), "opening fullscreen closes the editor, moves focus, and preserves the local draft", fullscreenFocus);
  const draftBeforeFullscreenShortcuts = fullscreenFocus.draft;
  await page.keyboard.press("i");
  await page.keyboard.press("Enter");
  const fullscreenShortcutState = await page.evaluate(() => ({
    editorCount: document.querySelectorAll(".yunomi-inline-comment-editor").length,
    draft: localStorage.getItem(`yunomi:comments:${window.__YUNOMI_FILENAME__}`) || "",
  }));
  assert(fullscreenShortcutState.editorCount === 0 && fullscreenShortcutState.draft === draftBeforeFullscreenShortcuts, "fullscreen blocks i and Enter comment shortcuts without creating a draft", fullscreenShortcutState);
  await page.locator("#img-fs-close").click();
  await page.waitForSelector("#image-fullscreen.visible", { state: "hidden" });
  await page.waitForSelector(".yunomi-inline-comment-editor #comment-input", { state: "visible" });
  await page.locator('.yunomi-inline-comment-editor [data-action="cancel"]').click();
  await page.locator('.yunomi-inline-comment-view:has-text("draft before fullscreen")').first().click();
  await page.locator(".yunomi-inline-comment-editor #comment-input").fill("");
  await page.locator(".yunomi-inline-comment-editor #save-comment").click();

  const targets: Array<[string, string]> = [
    ["heading", "#md-preview h1[data-source-line]"], ["paragraph", "#md-preview p[data-source-start-line]"],
    ["unordered-list", "#md-preview ul[data-source-line]"], ["list-item", "#md-preview li[data-source-line]"],
    ["ordered-list", "#md-preview ol[data-source-line]"], ["blockquote", "#md-preview blockquote[data-source-line]"],
    ["horizontal-rule", "#md-preview hr[data-source-line]"], ["code", "#md-preview pre[data-source-start-line]"],
    ["table-header", "#md-preview table:not(.frontmatter-table) th[data-source-line]"],
    ["table-cell", "#md-preview table:not(.frontmatter-table) td[data-source-line]"],
    ["image", "#md-preview img:not(.timeline-thumb)"], ["video", "#md-preview video.video-preview"],
    ["mermaid", "#md-preview .mermaid-container[data-source-start-line]"], ["details", "#md-preview details[data-source-line]"],
    ["raw-html", "#md-preview .markdown-html-block[data-source-line]"],
  ];
  for (const [name, selector] of targets) await exerciseType(page, name, selector);

  await clickElement(page, "#md-preview h1[data-source-line]");
  await page.locator(".yunomi-inline-comment-editor #comment-input").fill("survives reload");
  await page.locator(".yunomi-inline-comment-editor #save-comment").click();
  await page.locator('.yunomi-inline-comment[data-comment-surface="preview"] .yunomi-inline-comment-view:has-text("survives reload")').click();
  await page.locator(".yunomi-inline-comment-editor #comment-input").fill("survives reload");
  const storageBefore = await page.evaluate(() => localStorage.getItem(`yunomi:comments:${window.__YUNOMI_FILENAME__}`) || "");
  assert(storageBefore.includes("survives reload") && storageBefore.includes('"pending":true') && storageBefore.includes('"sent":false'), "localStorage preserves the pending review state");

  if (await page.locator(".comment-list.collapsed").count() > 0) {
    await page.locator("#pill-comments").click();
    await page.waitForSelector(".comment-list:not(.collapsed)", { state: "visible" });
  }
  const expandedLayout = await page.evaluate(() => {
    const panel = document.querySelector<HTMLElement>(".comment-list");
    const sidebar = document.querySelector<HTMLElement>(".media-sidebar:not(.hidden)");
    if (!panel || !sidebar) return null;
    const panelRect = panel.getBoundingClientRect();
    const sidebarRect = sidebar.getBoundingClientRect();
    return { panelRight: panelRect.right, sidebarLeft: sidebarRect.left, cssOffset: getComputedStyle(document.documentElement).getPropertyValue("--media-sidebar-offset") };
  });
  assert(expandedLayout !== null && expandedLayout.panelRight <= expandedLayout.sidebarLeft, "Comments panel stays clear of the expanded media sidebar", expandedLayout);
  if (EVIDENCE_DIR) {
    await page.screenshot({ path: join(EVIDENCE_DIR, "04-comments-clear-media-sidebar.png"), fullPage: true });
  }

  await page.locator("#media-sidebar-toggle").click();
  await page.waitForFunction(() => {
    const panel = document.querySelector<HTMLElement>(".comment-list");
    return panel && getComputedStyle(panel).right === "14px";
  });
  assert(true, "Comments panel returns to the viewport edge when the media sidebar is collapsed");
  await page.locator("#media-sidebar-toggle").click();
  await page.waitForFunction(() => {
    const panel = document.querySelector<HTMLElement>(".comment-list");
    const sidebar = document.querySelector<HTMLElement>(".media-sidebar:not(.hidden)");
    return panel && sidebar && panel.getBoundingClientRect().right <= sidebar.getBoundingClientRect().left;
  });

  await page.reload({ waitUntil: "domcontentloaded" });
  await page.locator("#recovery-restore").click();
  await page.waitForSelector(".yunomi-inline-comment-editor #comment-input", { state: "visible" });
  const restoredEditingState = await page.evaluate(() => ({
    editors: document.querySelectorAll(".yunomi-inline-comment-editor").length,
    previewViews: document.querySelectorAll('.yunomi-inline-comment[data-comment-surface="preview"] .yunomi-inline-comment-view').length,
    sourceViews: document.querySelectorAll('.yunomi-inline-comment[data-comment-surface="source"] .yunomi-inline-comment-view').length,
  }));
  assert(restoredEditingState.editors === 1 && restoredEditingState.previewViews === 0 && restoredEditingState.sourceViews === 1, "restore shows one editor without a duplicate Pending view on the editing surface", restoredEditingState);
  await page.locator(".yunomi-inline-comment-editor #save-comment").click();
  await page.waitForFunction(() => document.querySelectorAll('.yunomi-inline-comment-view:has(.yunomi-inline-comment-text)').length >= 2);
  assert(await page.locator('.yunomi-inline-comment-text:text-is("survives reload")').count() >= 2, "reload restore recreates preview and source inline comments after editing finishes");
  assert(await page.locator('.yunomi-inline-comment-view:has-text("survives reload") .yunomi-inline-comment-pending').count() >= 2, "reload restore keeps the Pending badge on both inline surfaces");
  if (EVIDENCE_DIR) {
    await page.screenshot({ path: join(EVIDENCE_DIR, "03-comment-restored-after-reload.png"), fullPage: true });
  }
  assert(!server.output().includes("TypeError") && !server.output().includes("ReferenceError"), "server output has no runtime JS errors", server.output());
} finally {
  if (browser) await browser.close();
  await stopServer(server.proc);
  rmSync(WORK_DIR, { recursive: true, force: true });
}

if (failures > 0) process.exit(1);
