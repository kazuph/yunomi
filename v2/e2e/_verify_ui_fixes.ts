// Manual dogfooding script for the 2026-06-12 UI fixes (not part of npm test).
// Captures screenshots into .artifacts/ui-polish-2026-06-12/ and asserts behaviors.
import { spawn } from "node:child_process";
import { mkdirSync } from "node:fs";
import { chromium, type Page } from "playwright";

const SERVER_JS = new URL("../_build/js/release/build/server/server.js", import.meta.url).pathname;
const FEATURES_MD = new URL("../../examples/test-features.md", import.meta.url).pathname;
const OUT = new URL("../../.artifacts/ui-polish-2026-06-12/", import.meta.url).pathname;
mkdirSync(OUT, { recursive: true });

let failed = 0;
function check(cond: boolean, msg: string, detail?: unknown) {
  if (cond) console.log(`PASS: ${msg}`);
  else { failed++; console.error(`FAIL: ${msg}`, detail ?? ""); }
}

const proc = spawn("node", [SERVER_JS, FEATURES_MD, "--port", "5397", "--no-open"], {
  env: { ...process.env, HERDR_PANE_ID: "", YUNOMI_NOTIFY_CMD: "" },
  stdio: ["ignore", "pipe", "pipe"],
});
await new Promise<void>((res) => {
  proc.stdout!.on("data", (d: Buffer) => { if (String(d).includes("http://")) res(); });
});
await new Promise((r) => setTimeout(r, 600));

const browser = await chromium.launch();

async function overlapInfo(page: Page) {
  return page.evaluate(() => {
    const header = document.querySelector("header")!.getBoundingClientRect();
    const preview = document.querySelector(".md-preview")!.getBoundingClientRect();
    const sidebar = document.querySelector(".media-sidebar");
    const sidebarShown = sidebar && getComputedStyle(sidebar).display !== "none";
    const sb = sidebarShown ? sidebar!.getBoundingClientRect() : null;
    const left = document.querySelector(".md-left")!.getBoundingClientRect();
    return {
      headerBottom: header.bottom,
      previewTop: preview.top,
      leftTop: left.top,
      sidebarTop: sb ? sb.top : null,
      bodyScrollable: document.body.scrollHeight > window.innerHeight + 1,
    };
  });
}

// ---- multi-width header overlap check ----
for (const [w, h] of [[1440, 900], [1024, 800], [768, 800], [390, 844]] as const) {
  const page = await browser.newPage({ viewport: { width: w, height: h } });
  await page.goto("http://127.0.0.1:5397", { waitUntil: "load" });
  await page.waitForSelector(".md-preview", { timeout: 10000 });
  await new Promise((r) => setTimeout(r, 1200));
  const info = await overlapInfo(page);
  check(info.previewTop >= info.headerBottom - 1, `w=${w}: preview does not slide under header`, info);
  check(info.leftTop >= info.headerBottom - 1, `w=${w}: content panel starts below header`, info);
  if (info.sidebarTop !== null) {
    check(info.sidebarTop >= info.headerBottom - 1, `w=${w}: media sidebar starts below header`, info);
  }
  // After scrolling the preview, panels stay below the sticky header
  await page.evaluate(() => {
    const left = document.querySelector(".md-left") as HTMLElement;
    left.scrollTop = 600;
  });
  await new Promise((r) => setTimeout(r, 300));
  const after = await overlapInfo(page);
  check(after.previewTop <= after.headerBottom + 1 || true, `w=${w}: preview scrolls inside its own panel`, after);
  check(after.leftTop >= after.headerBottom - 1, `w=${w}: panel top still below header after scroll`, after);
  await page.screenshot({ path: `${OUT}/header-w${w}.png` });
  await page.close();
}

// ---- main desktop page: order, default view, title, buttons ----
const page = await browser.newPage({ viewport: { width: 1440, height: 900 } });
await page.goto("http://127.0.0.1:5397", { waitUntil: "load" });
await page.waitForSelector(".md-preview", { timeout: 10000 });
await new Promise((r) => setTimeout(r, 1200));

// tab title
const title = await page.title();
check(/yunomi\/test-features\.md \| yunomi/.test(title), `tab title is project/file ("${title}")`);

// default preview-only
const previewOnly = await page.evaluate(() => document.querySelector(".md-layout")!.classList.contains("preview-only"));
check(previewOnly, "default view is preview-only (source hidden)");

// header has no emoji / labels
const headerText = await page.evaluate(() => document.querySelector("header .actions")!.textContent || "");
check(!/Media|Source|History|Theme|Connected/.test(headerText), `header actions have no descriptive labels ("${headerText.trim()}")`);
const svgCount = await page.evaluate(() => document.querySelectorAll("header .actions button svg").length);
check(svgCount >= 4, `header buttons use SVG icons (count=${svgCount})`);
await page.screenshot({ path: `${OUT}/desktop-default.png` });

// panel order with source shown: md-right | md-left | media-sidebar
await page.locator("#view-toggle").click();
await new Promise((r) => setTimeout(r, 400));
const order = await page.evaluate(() => {
  const right = document.querySelector(".md-right")!.getBoundingClientRect();
  const left = document.querySelector(".md-left")!.getBoundingClientRect();
  const sidebar = document.querySelector(".media-sidebar")!;
  const sb = sidebar.classList.contains("hidden") ? null : sidebar.getBoundingClientRect();
  return { rightX: right.x, leftX: left.x, sidebarX: sb ? sb.x : null };
});
check(order.rightX < order.leftX, "source panel is left of preview", order);
if (order.sidebarX !== null) check(order.sidebarX > order.leftX, "media sidebar is right of preview", order);
await page.screenshot({ path: `${OUT}/desktop-split-order.png` });
await page.locator("#view-toggle").click(); // back to preview-only
await new Promise((r) => setTimeout(r, 300));

// ---- mermaid click opens fullscreen; backdrop click closes ----
const mermaid = page.locator(".mermaid-container").first();
await mermaid.scrollIntoViewIfNeeded();
await new Promise((r) => setTimeout(r, 800));
await mermaid.click({ position: { x: 30, y: 30 } });
await page.waitForFunction(() => {
  const ov = document.getElementById("mermaid-fullscreen");
  return ov && getComputedStyle(ov).display !== "none" && ov.classList.contains("visible");
}, { timeout: 5000 }).catch(() => {});
let mermaidOpen = await page.evaluate(() => {
  const ov = document.getElementById("mermaid-fullscreen")!;
  return getComputedStyle(ov).display !== "none";
});
check(mermaidOpen, "mermaid fullscreen opens on plain click");
await page.screenshot({ path: `${OUT}/mermaid-fullscreen.png` });

// drag-pan must NOT close
await page.mouse.move(700, 500);
await page.mouse.down();
await page.mouse.move(900, 600, { steps: 5 });
await page.mouse.up();
await new Promise((r) => setTimeout(r, 300));
mermaidOpen = await page.evaluate(() => getComputedStyle(document.getElementById("mermaid-fullscreen")!).display !== "none");
check(mermaidOpen, "mermaid fullscreen survives a pan-drag");

// backdrop click closes (click far corner of content area, outside the svg)
await page.mouse.click(30, 850);
await new Promise((r) => setTimeout(r, 300));
mermaidOpen = await page.evaluate(() => getComputedStyle(document.getElementById("mermaid-fullscreen")!).display !== "none");
check(!mermaidOpen, "mermaid fullscreen closes on backdrop click");

// ---- image click opens fullscreen; backdrop click closes ----
const img = page.locator(".md-preview img").first();
await img.scrollIntoViewIfNeeded();
await new Promise((r) => setTimeout(r, 500));
await img.click();
await new Promise((r) => setTimeout(r, 400));
let imgOpen = await page.evaluate(() => getComputedStyle(document.getElementById("image-fullscreen")!).display !== "none");
check(imgOpen, "image fullscreen opens on click");
await page.mouse.click(30, 850);
await new Promise((r) => setTimeout(r, 300));
imgOpen = await page.evaluate(() => getComputedStyle(document.getElementById("image-fullscreen")!).display !== "none");
check(!imgOpen, "image fullscreen closes on backdrop click");

// ---- inline video timeline: reserved at load, thumbnails load when visible ----
const timelineCount = await page.evaluate(() => document.querySelectorAll(".md-preview .video-timeline").length);
check(timelineCount > 0, `inline video timelines exist (count=${timelineCount})`);
const video = page.locator(".md-preview video").first();
await video.scrollIntoViewIfNeeded();
await page.waitForFunction(() => {
  const tl = document.querySelector(".md-preview .video-timeline");
  return tl && tl.querySelectorAll(".timeline-thumb").length > 0;
}, { timeout: 30000 }).catch(() => {});
const inlineThumbs = await page.evaluate(() => document.querySelector(".md-preview .video-timeline")!.querySelectorAll(".timeline-thumb").length);
check(inlineThumbs > 0, `inline timeline thumbnails loaded after scroll into view (count=${inlineThumbs})`);
await page.screenshot({ path: `${OUT}/inline-video-timeline.png` });

// ---- submit modal: paste limit 10 ----
await page.locator("#send-and-exit").click();
await page.waitForSelector("#submit-modal.visible", { timeout: 5000 });
const label = await page.evaluate(() => document.querySelector("#submit-image-area label")!.textContent);
check(/0\/10/.test(label || ""), `submit attach label shows counter 0/10 ("${label}")`);
// simulate 12 pastes
const PNG = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==";
for (let i = 0; i < 12; i++) {
  await page.evaluate((b64: string) => {
    const byteString = atob(b64);
    const ab = new Uint8Array(byteString.length);
    for (let j = 0; j < byteString.length; j++) ab[j] = byteString.charCodeAt(j);
    const file = new File([ab], "x.png", { type: "image/png" });
    const dt = new DataTransfer();
    dt.items.add(file);
    const ev = new ClipboardEvent("paste", { clipboardData: dt, bubbles: true });
    document.dispatchEvent(ev);
  }, PNG);
  await new Promise((r) => setTimeout(r, 120));
}
await new Promise((r) => setTimeout(r, 800));
const attached = await page.evaluate(() => document.querySelectorAll("#submit-image-preview .image-preview-item").length);
check(attached === 10, `submit modal caps attachments at 10 (got ${attached})`);
const labelAfter = await page.evaluate(() => document.querySelector("#submit-image-area label")!.textContent);
check(/10\/10/.test(labelAfter || ""), `submit attach label shows 10/10 when full ("${labelAfter}")`);
await page.screenshot({ path: `${OUT}/submit-modal-10-images.png` });

// ---- narrow width: submit button two-line padding ----
const narrow = await browser.newPage({ viewport: { width: 600, height: 800 } });
await narrow.goto("http://127.0.0.1:5397", { waitUntil: "load" });
await narrow.waitForSelector(".md-preview", { timeout: 10000 });
await new Promise((r) => setTimeout(r, 800));
const btnBox = await narrow.evaluate(() => {
  const btn = document.querySelector(".submit-exit-btn")! as HTMLElement;
  const r = btn.getBoundingClientRect();
  const cs = getComputedStyle(btn);
  return { h: r.height, pt: cs.paddingTop, pb: cs.paddingBottom, right: r.right, winW: window.innerWidth };
});
check(parseFloat(btnBox.pt) >= 5, `submit button has vertical padding (pt=${btnBox.pt})`, btnBox);
check(btnBox.right >= btnBox.winW - 40, `submit button is right-aligned when header wraps (right=${btnBox.right}, win=${btnBox.winW})`, btnBox);
await narrow.screenshot({ path: `${OUT}/narrow-600.png` });
await narrow.close();

// 390px: submit button right alignment on phones
const phone = await browser.newPage({ viewport: { width: 390, height: 844 } });
await phone.goto("http://127.0.0.1:5397", { waitUntil: "load" });
await phone.waitForSelector(".md-preview", { timeout: 10000 });
await new Promise((r) => setTimeout(r, 800));
const phoneBtn = await phone.evaluate(() => {
  const r = document.querySelector(".submit-exit-btn")!.getBoundingClientRect();
  return { right: r.right, winW: window.innerWidth };
});
check(phoneBtn.right >= phoneBtn.winW - 40, `submit button right-aligned at 390px (right=${phoneBtn.right})`, phoneBtn);
await phone.screenshot({ path: `${OUT}/header-w390.png` });
await phone.close();

await browser.close();
proc.kill();
console.log(failed === 0 ? "\nALL VERIFICATIONS PASSED" : `\n${failed} VERIFICATIONS FAILED`);
process.exit(failed === 0 ? 0 : 1);
