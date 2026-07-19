import { spawn, type ChildProcess } from "node:child_process";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { chromium, type Browser, type Page } from "playwright";

const SERVER_JS = new URL("../_build/js/release/build/server/server.js", import.meta.url).pathname;
const ROOT = new URL("../..", import.meta.url).pathname;
const SHOWCASE = join(ROOT, "examples", "complex-markdown-showcase.md");
const REPORT = join(ROOT, ".artifacts", "inline-comments", "REPORT.md");
const WORK_DIR = mkdtempSync(join(tmpdir(), "yunomi-complex-markdown-"));
const BASE_PORT = 5893;
let passed = 0;
let failed = 0;

function assert(condition: boolean, message: string, detail?: unknown): void {
  if (condition) { passed++; console.log(`PASS: ${message}`); }
  else { failed++; console.error(`FAIL: ${message}`); if (detail !== undefined) console.error(JSON.stringify(detail, null, 2)); }
}

function startServer(): Promise<{ proc: ChildProcess; port: number; output: () => string }> {
  return new Promise((resolve, reject) => {
    const proc = spawn(process.execPath, [SERVER_JS, SHOWCASE, REPORT, "--no-open", "--port", String(BASE_PORT)], {
      cwd: ROOT,
      env: { ...process.env, HERDR_PANE_ID: "", YUNOMI_NOTIFY_CMD: "", YUNOMI_LOCK_DIR: join(WORK_DIR, "locks"), YUNOMI_REVIEW_DIR: join(WORK_DIR, "reviews") },
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
    proc.on("exit", (code) => { if (!settled) reject(new Error(`server exited early ${code}\n${output}`)); });
    setTimeout(() => { if (!settled) reject(new Error(`server startup timeout\n${output}`)); }, 15_000);
  });
}

async function stopServer(proc: ChildProcess): Promise<void> {
  if (proc.exitCode !== null) return;
  await new Promise<void>((resolve) => { proc.once("exit", () => resolve()); proc.kill("SIGTERM"); setTimeout(resolve, 2_000); });
}

async function openAndCancelEditor(page: Page, selector: string): Promise<boolean> {
  const target = page.locator(selector).first();
  if (await target.count() === 0 || !await target.isVisible()) return false;
  if (await target.evaluate((element) => element.tagName === "SUMMARY")) {
    const clicked = await target.evaluate((summary) => {
      const button = summary.querySelector<HTMLButtonElement>(":scope > .yunomi-comment-button");
      button?.click();
      return !!button;
    });
    if (!clicked) return false;
  } else {
    await target.evaluate((element) => {
      const dedicatedButton = element.matches("img:not(.timeline-thumb),video.video-preview,.mermaid-container,.timeline-thumb-wrapper");
      const host = element.matches("video.video-preview")
        ? element.closest(".video-overlay-wrapper")
        : element.matches("img:not(.timeline-thumb)") ? element.parentElement : element;
      const button = host?.querySelector(":scope > .yunomi-comment-button")
        || element.querySelector(":scope > .yunomi-comment-button");
      ((dedicatedButton ? button : element) as HTMLElement | null)?.click();
    });
  }
  await page.waitForSelector(".yunomi-inline-comment-editor #comment-input", { state: "visible", timeout: 5_000 });
  await page.locator('.yunomi-inline-comment-editor [data-action="cancel"]').click();
  return true;
}

async function nonContainedOverlaps(page: Page): Promise<Array<{ first: string; second: string; area: number }>> {
  return page.evaluate(() => {
    const nodes = Array.from(document.querySelectorAll<HTMLElement>(
      "#md-preview [data-source-line],#md-preview [data-source-start-line]",
    )).filter((element) => {
      if (element.closest("details:not([open])")) return false;
      const rect = element.getBoundingClientRect();
      const style = getComputedStyle(element);
      return style.display !== "none" && style.visibility !== "hidden" && rect.width > 0 && rect.height > 0;
    });
    const overlaps: Array<{ first: string; second: string; area: number }> = [];
    for (let i = 0; i < nodes.length; i++) for (let j = i + 1; j < nodes.length; j++) {
      const first = nodes[i]; const second = nodes[j];
      if (first.contains(second) || second.contains(first)) continue;
      const a = first.getBoundingClientRect(); const b = second.getBoundingClientRect();
      const width = Math.max(0, Math.min(a.right, b.right) - Math.max(a.left, b.left));
      const height = Math.max(0, Math.min(a.bottom, b.bottom) - Math.max(a.top, b.top));
      if (width * height > 0) overlaps.push({ first: first.tagName, second: second.tagName, area: width * height });
    }
    return overlaps;
  });
}

const server = await startServer();
let browser: Browser | null = null;
try {
  browser = await chromium.launch({ headless: true });
  const page = await browser.newPage({ viewport: { width: 1440, height: 1000 } });
  await page.goto(`http://127.0.0.1:${server.port}`, { waitUntil: "domcontentloaded" });
  await page.waitForSelector("#md-preview [data-source-line],#md-preview [data-source-start-line]", { timeout: 10_000 });
  await page.waitForTimeout(600);

  const detailsState = await page.evaluate(() => Array.from(document.querySelectorAll<HTMLDetailsElement>("#md-preview details")).map((details) => ({
    open: details.open,
    summary: details.querySelector(":scope > summary")?.textContent?.trim() || "",
    summaryHtml: details.querySelector(":scope > summary")?.innerHTML || "",
  })));
  assert(detailsState.some((item) => item.open && item.summary.includes("Latest: 表示中の詳細") && item.summaryHtml.includes("<strong>")), "details preserves open and rich summary content", detailsState);
  assert(detailsState.some((item) => item.open && item.summary.includes("Nested: 二段目")), "nested open details renders its own summary", detailsState);
  assert(detailsState.some((item) => !item.open && item.summary.includes("Closed: 任意で開く詳細")), "closed details remains closed without replacing its summary", detailsState);

  if (await page.locator("html").getAttribute("data-theme") === "dark") {
    await page.locator("#theme-toggle").click();
    await page.waitForFunction(() => document.documentElement.getAttribute("data-theme") === "light");
  }
  await page.locator("#theme-toggle").click();
  await page.waitForFunction(() => {
    if (document.documentElement.getAttribute("data-theme") !== "dark") return false;
    const sequence = Array.from(document.querySelectorAll<HTMLElement>("#md-preview .mermaid"))
      .find((element) => element.getAttribute("data-source")?.includes("sequenceDiagram"));
    return !!sequence?.querySelector("svg .messageLine0,svg .messageLine1");
  });
  const darkSequenceContrast = await page.evaluate(() => {
    const parse = (color: string): [number, number, number] => {
      const values = color.match(/[\d.]+/g)?.slice(0, 3).map(Number) || [0, 0, 0];
      return [values[0], values[1], values[2]];
    };
    const luminance = ([r, g, b]: [number, number, number]): number => {
      const channel = (value: number) => {
        const normalized = value / 255;
        return normalized <= 0.04045 ? normalized / 12.92 : ((normalized + 0.055) / 1.055) ** 2.4;
      };
      return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b);
    };
    const ratio = (foreground: string, background: string): number => {
      const a = luminance(parse(foreground)); const b = luminance(parse(background));
      return (Math.max(a, b) + 0.05) / (Math.min(a, b) + 0.05);
    };
    const sequence = Array.from(document.querySelectorAll<HTMLElement>("#md-preview .mermaid"))
      .find((element) => element.getAttribute("data-source")?.includes("sequenceDiagram"));
    const line = sequence?.querySelector<SVGElement>("svg .messageLine0,svg .messageLine1");
    const label = sequence?.querySelector<SVGElement>("svg .messageText");
    const background = getComputedStyle(sequence!.closest<HTMLElement>(".mermaid-container")!).backgroundColor;
    const stroke = line ? getComputedStyle(line).stroke : "rgb(0, 0, 0)";
    const fill = label ? getComputedStyle(label).fill : "rgb(0, 0, 0)";
    return { stroke, fill, background, lineRatio: ratio(stroke, background), textRatio: ratio(fill, background) };
  });
  assert(darkSequenceContrast.lineRatio >= 3 && darkSequenceContrast.textRatio >= 4.5, "dark Mermaid sequence arrows and labels keep readable contrast after theme rerender", darkSequenceContrast);

  const missingAnchors = await page.evaluate(() => {
    const selector = "h1,h2,h3,h4,h5,h6,p,ul,ol,li,blockquote,pre,table,tr,th,td,details,summary,hr,img,.mermaid-container,.markdown-html-block";
    const preview = document.querySelector<HTMLElement>("#md-preview");
    if (!preview) return ["missing #md-preview"];
    return Array.from(preview.querySelectorAll<HTMLElement>(`:scope :is(${selector})`))
      .filter((element) => !element.closest(".markdown-html-block") || element.classList.contains("markdown-html-block"))
      .filter((element) => !element.closest(".fullscreen-overlay,.image-fullscreen-overlay,.video-fullscreen-overlay"))
      .filter((element) => !element.matches("details.heading-toggle,summary.heading-summary"))
      .filter((element) => !element.hasAttribute("data-source-line") && !element.hasAttribute("data-source-start-line"))
      .map((element) => `${element.tagName.toLowerCase()}.${element.className}`);
  });
  assert(missingAnchors.length === 0, "every rendered showcase block has a source-line anchor", missingAnchors);

  const closedSummary = page.locator('#md-preview summary:not(.heading-summary):has-text("Closed: 任意で開く詳細")');
  await closedSummary.click();
  const nativeSummaryState = {
    open: await closedSummary.evaluate((summary) => (summary.parentElement as HTMLDetailsElement | null)?.open || false),
    editors: await page.locator(".yunomi-inline-comment-editor").count(),
  };
  assert(nativeSummaryState.open && nativeSummaryState.editors === 0, "direct summary click keeps native toggle behavior without opening an editor", nativeSummaryState);
  await closedSummary.click();

  const categories: Array<[string, string]> = [
    ["deep nested list", "#md-preview li li li li"],
    ["code inside list", "#md-preview li pre,#md-preview pre"],
    ["list inside quote", "#md-preview blockquote li"],
    ["nested blockquote", "#md-preview blockquote blockquote"],
    ["second mermaid", "#md-preview .mermaid-container:nth-of-type(2),#md-preview .mermaid-container"],
    ["mixed table cell", "#md-preview table:not(.frontmatter-table) td"],
    ["details summary", "#md-preview details[open] > summary:not(.heading-summary)"],
    ["closed details summary", "#md-preview details:not([open]) > summary:not(.heading-summary)"],
    ["raw html", "#md-preview .markdown-html-block"],
    ["long Japanese paragraph", "#md-preview blockquote blockquote p,#md-preview blockquote blockquote"],
    ["footnote/reference paragraph", "#md-preview h2:last-of-type + p,#md-preview p"],
  ];
  for (const [name, selector] of categories) {
    const opened = await openAndCancelEditor(page, selector);
    assert(opened, `${name} accepts an inline comment`);
  }
  await page.waitForFunction(() => document.querySelectorAll("#md-preview .video-timeline .timeline-thumb-wrapper").length >= 2, undefined, { timeout: 20_000 });
  const videoState = await page.evaluate(() => {
    const video = document.querySelector<HTMLVideoElement>("#md-preview video.video-preview");
    return {
      rendered: !!video,
      source: video?.getAttribute("src") || "",
      anchored: !!video?.hasAttribute("data-source-line"),
      thumbnails: document.querySelectorAll("#md-preview .video-timeline .timeline-thumb-wrapper").length,
    };
  });
  assert(videoState.rendered && videoState.source.includes("videos/video-landscape.mp4") && videoState.anchored, "showcase renders the existing landscape video with a source-line anchor", videoState);
  assert(videoState.thumbnails >= 2, "showcase video renders timeline thumbnails", videoState);
  assert(await openAndCancelEditor(page, "#md-preview video.video-preview"), "showcase video accepts an inline comment");
  const timelineTarget = page.locator("#md-preview .video-timeline .timeline-thumb-wrapper").first();
  await timelineTarget.evaluate((element) => element.querySelector<HTMLButtonElement>(":scope > .yunomi-comment-button")?.click());
  await page.waitForSelector(".yunomi-inline-comment-editor #comment-input", { state: "visible", timeout: 5_000 });
  const timelineEditorLabel = await page.locator(".yunomi-inline-comment-editor .yunomi-inline-comment-label").textContent();
  assert(/^Video \d+:\d{2} · Line \d+$/.test(timelineEditorLabel || ""), "timeline thumbnail editor identifies video time before the source line", timelineEditorLabel);
  await page.locator(".yunomi-inline-comment-editor #comment-input").fill("timeline label persists");
  await page.locator(".yunomi-inline-comment-editor #save-comment").click();
  const timelineViewLabel = await page.locator('.yunomi-inline-comment-view:has-text("timeline label persists") .yunomi-inline-comment-label').first().textContent();
  assert(/^Video \d+:\d{2} · Line \d+/.test(timelineViewLabel || ""), "timeline thumbnail inline view keeps the video time label", timelineViewLabel);
  await page.locator('.yunomi-inline-comment-view:has-text("timeline label persists")').first().click();
  await page.locator(".yunomi-inline-comment-editor #comment-input").fill("");
  await page.locator(".yunomi-inline-comment-editor #save-comment").click();
  const overlaps = await nonContainedOverlaps(page);
  assert(overlaps.length === 0, "complex showcase blocks do not overlap", overlaps);

  const reportPage = await browser.newPage({ viewport: { width: 1440, height: 1000 } });
  await reportPage.goto(`http://127.0.0.1:${server.port + 1}`, { waitUntil: "domcontentloaded" });
  await reportPage.waitForSelector("#md-preview details > summary", { timeout: 10_000 });
  const reportLatest = await reportPage.evaluate(() => {
    const details = Array.from(document.querySelectorAll<HTMLDetailsElement>("#md-preview details"));
    const target = details.find((item) => item.querySelector(":scope > summary strong")?.textContent?.trim().startsWith("Latest:"));
    return target ? { open: target.open, summary: target.querySelector(":scope > summary")?.textContent || "", strong: !!target.querySelector(":scope > summary strong") } : null;
  });
  assert(reportLatest !== null && reportLatest.open && reportLatest.strong && !reportLatest.summary.includes("詳細"), "REPORT latest feedback keeps its summary and open state", reportLatest);
  await reportPage.close();
  assert(!server.output().includes("TypeError") && !server.output().includes("ReferenceError"), "showcase server has no runtime errors", server.output());
} catch (error) {
  failed++;
  console.error(error instanceof Error ? error.stack || error.message : String(error));
} finally {
  if (browser) await browser.close();
  await stopServer(server.proc);
  rmSync(WORK_DIR, { recursive: true, force: true });
}

console.log(`Complex markdown showcase E2E: ${passed} passed, ${failed} failed`);
if (failed > 0) process.exit(1);
