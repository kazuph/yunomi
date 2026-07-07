import { spawn, type ChildProcess } from "node:child_process";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { mkdirSync } from "node:fs";
import { chromium, type Browser, type Page } from "playwright";

const BASE_PORT = 5349;
const SERVER_JS = new URL(
  "../_build/js/release/build/server/server.js",
  import.meta.url,
).pathname;
const FEATURES_MD = new URL("../../examples/test-features.md", import.meta.url).pathname;
const LOCK_DIR = join(tmpdir(), "yunomi-media-sidebar-locks");

mkdirSync(LOCK_DIR, { recursive: true });

let failed = 0;

function pass(msg: string, detail?: unknown): void {
  console.log(`PASS: ${msg}`);
  if (detail !== undefined) {
    console.log(JSON.stringify(detail, null, 2));
  }
}

function fail(msg: string, detail?: unknown): void {
  failed++;
  console.error(`FAIL: ${msg}`);
  if (detail !== undefined) {
    console.error(JSON.stringify(detail, null, 2));
  }
}

function assert(condition: boolean, msg: string, detail?: unknown): void {
  if (condition) {
    pass(msg, detail);
  } else {
    fail(msg, detail);
  }
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

interface MinimapSelectors {
  source: string;
  wrapper: string;
  viewport: string;
  minimap: string;
  minimapSvg: string;
  minimapViewport: string;
}

interface MinimapMeasurement {
  ok: boolean;
  reason?: string;
  found?: Record<string, boolean>;
  sourceRect?: DOMRect;
  wrapperRect?: DOMRect;
  viewportRect?: DOMRect;
  minimapRect?: DOMRect;
  minimapSvgRect?: DOMRect;
  actualRect?: Record<string, number>;
  expectedRect?: Record<string, number>;
  delta?: Record<string, number>;
  maxAbsDelta?: number;
  zoom?: number;
  panX?: number;
  panY?: number;
}

async function measureMinimap(page: Page, selectors: MinimapSelectors): Promise<MinimapMeasurement> {
  return page.evaluate((sel) => {
    const source = document.querySelector(sel.source);
    const wrapper = document.querySelector(sel.wrapper);
    const viewport = document.querySelector(sel.viewport);
    const minimap = document.querySelector(sel.minimap);
    const minimapSvg = document.querySelector(sel.minimapSvg);
    const minimapViewport = document.querySelector(sel.minimapViewport);

    if (!source || !wrapper || !viewport || !minimap || !minimapSvg || !minimapViewport) {
      return {
        ok: false,
        reason: "missing-elements",
        found: {
          source: !!source,
          wrapper: !!wrapper,
          viewport: !!viewport,
          minimap: !!minimap,
          minimapSvg: !!minimapSvg,
          minimapViewport: !!minimapViewport,
        },
      };
    }

    const rect = (el: Element) => {
      const r = el.getBoundingClientRect();
      return {
        left: r.left,
        top: r.top,
        right: r.right,
        bottom: r.bottom,
        width: r.width,
        height: r.height,
      };
    };

    const sourceRect = rect(source);
    const wrapperRect = rect(wrapper);
    const viewportRect = rect(viewport);
    const minimapRect = rect(minimap);
    const minimapSvgRect = rect(minimapSvg);
    const actualRect = rect(minimapViewport);

    const matrix = new DOMMatrixReadOnly(
      getComputedStyle(wrapper).transform === "none" ? undefined : getComputedStyle(wrapper).transform,
    );
    const zoom = matrix.a || 1;
    const panX = matrix.e || 0;
    const panY = matrix.f || 0;
    const naturalWidth = wrapperRect.width / zoom;
    const naturalHeight = wrapperRect.height / zoom;

    if (
      sourceRect.width <= 0 ||
      sourceRect.height <= 0 ||
      naturalWidth <= 0 ||
      naturalHeight <= 0 ||
      viewportRect.width <= 0 ||
      viewportRect.height <= 0
    ) {
      return {
        ok: false,
        reason: "invalid-geometry",
        sourceRect,
        wrapperRect,
        viewportRect,
        minimapRect,
        minimapSvgRect,
        actualRect,
      } as any;
    }

    const visibleW = viewportRect.width / zoom;
    const visibleH = viewportRect.height / zoom;
    const worldX = -panX / zoom;
    const worldY = -panY / zoom;
    const clamp = (value: number, min: number, max: number) => Math.max(min, Math.min(max, value));
    const visibleLeft = clamp(worldX, 0, naturalWidth);
    const visibleTop = clamp(worldY, 0, naturalHeight);
    const visibleRight = clamp(worldX + visibleW, 0, naturalWidth);
    const visibleBottom = clamp(worldY + visibleH, 0, naturalHeight);
    const scaleX = minimapSvgRect.width / naturalWidth;
    const scaleY = minimapSvgRect.height / naturalHeight;
    const expectedRect = {
      left:
        (minimapSvgRect.left - minimapRect.left) +
        visibleLeft * scaleX,
      top:
        (minimapSvgRect.top - minimapRect.top) +
        visibleTop * scaleY,
      width: Math.max(0, visibleRight - visibleLeft) * scaleX,
      height: Math.max(0, visibleBottom - visibleTop) * scaleY,
    };
    const actualNormalized = {
      left: actualRect.left - minimapRect.left,
      top: actualRect.top - minimapRect.top,
      width: actualRect.width,
      height: actualRect.height,
    };

    const delta = {
      left: actualNormalized.left - expectedRect.left,
      top: actualNormalized.top - expectedRect.top,
      width: actualNormalized.width - expectedRect.width,
      height: actualNormalized.height - expectedRect.height,
    };
    const maxAbsDelta = Math.max(
      Math.abs(delta.left),
      Math.abs(delta.top),
      Math.abs(delta.width),
      Math.abs(delta.height),
    );

    return {
      ok: true,
      sourceRect,
      wrapperRect,
      viewportRect,
      minimapRect,
      minimapSvgRect,
      actualRect: actualNormalized,
      expectedRect,
      delta,
      maxAbsDelta,
      zoom,
      panX,
      panY,
    } as any;
  }, selectors);
}

interface NavState {
  activeIndex: number | null;
  highlightedIndex: number | null;
  highlightCount: number;
  visibleRatio: number | null;
}

// Video extensions accepted by the runtime (collect_media_items in media_sidebar.mbt).
// Keep in sync so test indices never drift from sidebar thumb indices.
const VIDEO_EXTS = [".mp4", ".mov", ".webm", ".avi", ".mkv", ".m4v", ".ogv"];

// Snapshot of the scroll-navigator state: which thumb is active, which
// preview media is highlighted, and how visible the media at `index` is.
async function measureNavState(page: Page, index: number): Promise<NavState> {
  return page.evaluate(({ idx, exts }) => {
    const preview = document.querySelector(".md-preview");
    const mediaEls = preview
      ? Array.from(preview.querySelectorAll("img, video.video-preview, .mermaid-container")).filter((el) => {
          if (el.tagName === "IMG" && el.closest(".video-timeline")) return false;
          if (el.tagName !== "VIDEO") return true;
          const src = (el.getAttribute("src") || "").toLowerCase();
          return exts.some((ext: string) => src.endsWith(ext));
        })
      : [];
    const activeThumb = document.querySelector(".media-sidebar-thumb.active");
    const activeIndex = activeThumb
      ? parseInt(activeThumb.getAttribute("data-media-index") || "-1", 10)
      : null;
    const highlighted = Array.from(document.querySelectorAll(".media-nav-highlight"));
    const highlightedIndex = highlighted.length === 1 ? mediaEls.indexOf(highlighted[0]) : null;

    let visibleRatio: number | null = null;
    const target = mediaEls[idx];
    if (target) {
      const r = target.getBoundingClientRect();
      const vh = window.innerHeight;
      const visible = Math.min(r.bottom, vh) - Math.max(r.top, 0);
      visibleRatio = visible / Math.min(r.height, vh);
    }

    return {
      activeIndex,
      highlightedIndex,
      highlightCount: highlighted.length,
      visibleRatio,
    };
  }, { idx: index, exts: VIDEO_EXTS });
}

// Wait until keyboard/click navigation actually selected `index` and the
// target media is visibly in the viewport.
async function waitForNavSettle(page: Page, index: number): Promise<void> {
  await page.waitForFunction(
    ({ idx, exts }) => {
      const preview = document.querySelector(".md-preview");
      if (!preview) return false;
      const activeIndex = Number(document.querySelector(".media-sidebar-thumb.active")?.getAttribute("data-media-index") ?? "-1");
      if (activeIndex !== idx) return false;
      const mediaEls = Array.from(preview.querySelectorAll("img, video.video-preview, .mermaid-container")).filter((el) => {
        if (el.tagName === "IMG" && el.closest(".video-timeline")) return false;
        if (el.tagName !== "VIDEO") return true;
        const src = (el.getAttribute("src") || "").toLowerCase();
        return exts.some((ext: string) => src.endsWith(ext));
      });
      const target = mediaEls[idx];
      if (!target) return false;
      const rect = target.getBoundingClientRect();
      const visible = Math.min(rect.bottom, window.innerHeight) - Math.max(rect.top, 0);
      const visibleRatio = visible / Math.min(rect.height || 1, window.innerHeight);
      return visibleRatio >= 0.5;
    },
    { idx: index, exts: VIDEO_EXTS },
    { timeout: 10000, polling: 100 },
  );
}

// Start sampling preview media counts (50ms interval) to prove nothing
// disappears mid-navigation — guards the original "blank flash" complaint.
async function startMediaSampler(page: Page): Promise<void> {
  await page.evaluate((exts) => {
    const w = window as any;
    w.__mediaSamples = [];
    w.__mediaSampler = setInterval(() => {
      const preview = document.querySelector(".md-preview");
      const els = preview
        ? Array.from(preview.querySelectorAll("img, video.video-preview, .mermaid-container")).filter((el) => {
            if (el.tagName === "IMG" && el.closest(".video-timeline")) return false;
            if (el.tagName !== "VIDEO") return true;
            const src = (el.getAttribute("src") || "").toLowerCase();
            return exts.some((ext: string) => src.endsWith(ext));
          })
        : [];
      let rendered = 0;
      els.forEach((el) => {
        const r = el.getBoundingClientRect();
        const style = getComputedStyle(el);
        if (r.width > 0 && r.height > 0 && style.visibility !== "hidden" && style.display !== "none") rendered++;
      });
      w.__mediaSamples.push({ total: els.length, rendered });
    }, 50);
  }, VIDEO_EXTS);
}

async function stopMediaSampler(page: Page): Promise<Array<{ total: number; rendered: number }>> {
  return page.evaluate(() => {
    const w = window as any;
    clearInterval(w.__mediaSampler);
    return w.__mediaSamples as Array<{ total: number; rendered: number }>;
  });
}

const proc = spawn(
  "node",
  [SERVER_JS, "--no-open", "--port", String(BASE_PORT), FEATURES_MD],
  {
    stdio: ["ignore", "pipe", "pipe"],
    env: { ...process.env, YUNOMI_LOCK_DIR: LOCK_DIR, YUNOMI_REVIEW_DIR: join(tmpdir(), "yunomi-review-" + Date.now() + "-" + Math.random().toString(36).slice(2,6)) },
  },
);

let browser: Browser | undefined;

try {
  const port = await waitForServerOutput(proc);
  await waitForHealth(port);

  browser = await chromium.launch({ headless: true });
  const page: Page = await browser.newPage({ viewport: { width: 1440, height: 1100 } });
  const pageErrors: string[] = [];

  page.on("pageerror", (err) => {
    pageErrors.push(String(err));
  });
  page.on("console", (msg) => {
    if (msg.type() === "error") {
      pageErrors.push(`console:${msg.text()}`);
    }
  });

  await page.goto(`http://127.0.0.1:${port}`, { waitUntil: "domcontentloaded", timeout: 30000 });
  await page.waitForTimeout(3000);

  const thumbSummary = await page.evaluate((exts) => {
    const preview = document.querySelector(".md-preview");
    const thumbs = Array.from(document.querySelectorAll(".media-sidebar-thumb"));
    const expected = preview
      ? Array.from(preview.querySelectorAll("img, video.video-preview, .mermaid-container")).filter((el) => {
          if (el.tagName === "IMG" && el.closest(".video-timeline")) return false;
          if (el.tagName !== "VIDEO") return true;
          const src = (el.getAttribute("src") || "").toLowerCase();
          return exts.some((ext: string) => src.endsWith(ext));
        }).length
      : 0;
    return {
      expected,
      actual: thumbs.length,
      details: thumbs.map((thumb, index) => {
        const media = thumb.querySelector("img, video, svg");
        const rect = media?.getBoundingClientRect();
        return {
          index,
          childTag: media?.tagName || null,
          width: rect?.width || 0,
          height: rect?.height || 0,
          text: thumb.textContent!.trim().slice(0, 80),
        };
      }),
    };
  }, VIDEO_EXTS);

  assert(pageErrors.length === 0, "ページ初期化でJS例外が出ない", pageErrors);
  assert(
    thumbSummary.actual === thumbSummary.expected && thumbSummary.actual > 0,
    "Media Sidebar が全メディア分のサムネイルを描画する",
    thumbSummary,
  );
  assert(
    thumbSummary.details.every((item) => item.width >= 20 && item.height >= 20),
    "各サムネイルに可視メディアが入る",
    thumbSummary.details,
  );

  await page.keyboard.press("Escape");
  for (let i = 0; i < thumbSummary.actual; i++) {
    await page.keyboard.press("ArrowDown");
    await waitForNavSettle(page, i);
    const state = await measureNavState(page, i);
    assert(
      state.activeIndex === i && state.highlightedIndex === i && state.highlightCount === 1,
      `ArrowDown だけでメディア ${i + 1}/${thumbSummary.actual} へ順番に移動する`,
      state,
    );
  }
  for (let i = thumbSummary.actual - 2; i >= 0; i--) {
    await page.keyboard.press("ArrowUp");
    await waitForNavSettle(page, i);
    const state = await measureNavState(page, i);
    assert(
      state.activeIndex === i && state.highlightedIndex === i && state.highlightCount === 1,
      `ArrowUp だけでメディア ${i + 1}/${thumbSummary.actual} へ順番に戻る`,
      state,
    );
  }
  await page.keyboard.press("Escape");
  for (let i = 0; i < thumbSummary.actual; i++) {
    await page.keyboard.press("j");
    await waitForNavSettle(page, i);
    const state = await measureNavState(page, i);
    assert(
      state.activeIndex === i && state.highlightedIndex === i && state.highlightCount === 1,
      `j だけでメディア ${i + 1}/${thumbSummary.actual} へ順番に移動する`,
      state,
    );
  }
  await page.keyboard.press("k");
  await waitForNavSettle(page, thumbSummary.actual - 2);
  const afterK = await measureNavState(page, thumbSummary.actual - 2);
  assert(
    afterK.activeIndex === thumbSummary.actual - 2 &&
      afterK.highlightedIndex === thumbSummary.actual - 2,
    "k は ArrowUp と同じく前のメディアへ戻る",
    afterK,
  );
  await page.locator("#send-and-exit").click();
  await page.waitForSelector("#submit-modal.visible", { timeout: 5000 });
  const beforeDialogKeys = await measureNavState(page, thumbSummary.actual - 2);
  for (const key of ["h", "j", "k", "l"]) {
    await page.keyboard.press(key);
  }
  const afterDialogKeys = await measureNavState(page, thumbSummary.actual - 2);
  assert(
    afterDialogKeys.activeIndex === beforeDialogKeys.activeIndex &&
      afterDialogKeys.highlightedIndex === beforeDialogKeys.highlightedIndex,
    "submit dialog 表示中は hjkl でメディア移動しない",
    { beforeDialogKeys, afterDialogKeys },
  );
  await page.locator("#modal-cancel").click();
  await page.waitForSelector("#submit-modal.visible", { state: "detached", timeout: 5000 }).catch(async () => {
    await page.waitForFunction(() => !document.querySelector("#submit-modal")?.classList.contains("visible"));
  });

  // --- Scroll-navigator spec: the 45vw sidebar viewer panel is gone ---
  const viewerGone = await page.evaluate(() => ({
    viewerEl: !!document.querySelector("#media-sidebar-viewer"),
    viewerClass: !!document.querySelector(".media-sidebar-viewer"),
  }));
  assert(
    !viewerGone.viewerEl && !viewerGone.viewerClass,
    "サイドバービューアパネルがDOMに存在しない（スクロールナビ仕様）",
    viewerGone,
  );

  // --- Click the last thumbnail: preview scrolls to that media + highlight ---
  const lastIdx = thumbSummary.actual - 1;
  await page.locator(`.media-sidebar-thumb[data-media-index="${lastIdx}"]`).click();
  await waitForNavSettle(page, lastIdx);

  const afterClick = await measureNavState(page, lastIdx);
  assert(
    afterClick.activeIndex === lastIdx,
    "サムネクリックで該当サムネが active になる",
    afterClick,
  );
  // Lazy media can still shift layout after the first settle; the nav
  // re-aims persistently, so poll visibility instead of trusting a
  // single post-settle measurement.
  let visState = afterClick;
  for (let retry = 0; retry < 15 && (visState.visibleRatio === null || visState.visibleRatio < 0.5); retry++) {
    await new Promise((r) => setTimeout(r, 200));
    visState = await measureNavState(page, lastIdx);
  }
  assert(
    visState.visibleRatio !== null && visState.visibleRatio >= 0.5,
    "サムネクリックでメインプレビューが該当メディアまでスクロールする",
    visState,
  );
  assert(
    afterClick.highlightCount === 1 && afterClick.highlightedIndex === lastIdx,
    "スクロール先のメディアにハイライトリングが付く",
    afterClick,
  );

  // --- Highlight auto-clears after a short dwell (poll instead of fixed sleep) ---
  const highlightCleared = await page.waitForFunction(
    () => document.querySelectorAll(".media-nav-highlight").length === 0,
    undefined,
    { timeout: 7000 },
  ).then(() => true).catch(() => false);
  assert(highlightCleared, "ハイライトリングは短い表示後に自動的に消える");

  // --- Arrow navigation while sampling media counts: nothing may disappear
  //     mid-transition (guards the original "blank flash" complaint) ---
  await startMediaSampler(page);

  await page.keyboard.press("ArrowUp");
  await waitForNavSettle(page, lastIdx - 1);
  const afterUp = await measureNavState(page, lastIdx - 1);
  assert(
    afterUp.activeIndex === lastIdx - 1 &&
      afterUp.visibleRatio !== null &&
      afterUp.visibleRatio >= 0.5 &&
      afterUp.highlightedIndex === lastIdx - 1,
    "ArrowUp で前のメディアへスクロール＆ハイライトする",
    afterUp,
  );

  await page.keyboard.press("ArrowDown");
  await waitForNavSettle(page, lastIdx);
  const afterDown = await measureNavState(page, lastIdx);
  assert(
    afterDown.activeIndex === lastIdx &&
      afterDown.visibleRatio !== null &&
      afterDown.visibleRatio >= 0.5,
    "ArrowDown で次のメディアへ戻る",
    afterDown,
  );

  // --- Inline video timeline keyboard contract:
  //     Left/Right move inside the focused video timeline; Up/Down move to
  //     previous/next document media through the media sidebar.
  const inlineVideoTarget = await page.evaluate((exts) => {
    const preview = document.querySelector(".md-preview");
    const mediaEls = preview
      ? Array.from(preview.querySelectorAll("img, video.video-preview, .mermaid-container")).filter((el) => {
          if (el.tagName === "IMG" && el.closest(".video-timeline")) return false;
          if (el.tagName !== "VIDEO") return true;
          const src = (el.getAttribute("src") || "").toLowerCase();
          return exts.some((ext: string) => src.endsWith(ext));
        })
      : [];
    const videoIndex = mediaEls.findIndex((el) => el.tagName === "VIDEO");
    return { videoIndex, total: mediaEls.length };
  }, VIDEO_EXTS);
  assert(
    inlineVideoTarget.videoIndex >= 0 && inlineVideoTarget.videoIndex < inlineVideoTarget.total - 1,
    "inline 動画 timeline の上下キー検証に使える動画がある",
    inlineVideoTarget,
  );

  if (inlineVideoTarget.videoIndex >= 0 && inlineVideoTarget.videoIndex < inlineVideoTarget.total - 1) {
    await page.locator(`.media-sidebar-thumb[data-media-index="${inlineVideoTarget.videoIndex}"]`).click();
    await waitForNavSettle(page, inlineVideoTarget.videoIndex);
    await page.waitForFunction((idx) => {
      const preview = document.querySelector(".md-preview");
      if (!preview) return false;
      const mediaEls = Array.from(preview.querySelectorAll("img, video.video-preview, .mermaid-container")).filter((el) => {
        if (el.tagName === "IMG" && el.closest(".video-timeline")) return false;
        if (el.tagName !== "VIDEO") return true;
        const src = (el.getAttribute("src") || "").toLowerCase();
        return [".mp4", ".mov", ".webm", ".avi", ".mkv", ".m4v", ".ogv"].some((ext) => src.endsWith(ext));
      });
      const video = mediaEls[idx];
      const wrapper = video?.closest(".video-overlay-wrapper");
      return !!wrapper && wrapper.querySelectorAll(".video-timeline .timeline-thumb").length >= 2;
    }, inlineVideoTarget.videoIndex, { timeout: 30000 });

    const timelinePrimed = await page.evaluate((idx) => {
      const preview = document.querySelector(".md-preview")!;
      const mediaEls = Array.from(preview.querySelectorAll("img, video.video-preview, .mermaid-container")).filter((el) => {
        if (el.tagName === "IMG" && el.closest(".video-timeline")) return false;
        if (el.tagName !== "VIDEO") return true;
        const src = (el.getAttribute("src") || "").toLowerCase();
        return [".mp4", ".mov", ".webm", ".avi", ".mkv", ".m4v", ".ogv"].some((ext) => src.endsWith(ext));
      });
      const video = mediaEls[idx] as HTMLVideoElement;
      const wrapper = video.closest(".video-overlay-wrapper")!;
      const thumbs = Array.from(wrapper.querySelectorAll<HTMLImageElement>(".video-timeline .timeline-thumb"));
      thumbs[0].click();
      return {
        time: video.currentTime,
        focusedTimeline: document.activeElement?.classList.contains("video-timeline") || false,
        thumbCount: thumbs.length,
      };
    }, inlineVideoTarget.videoIndex);
    assert(
      timelinePrimed.focusedTimeline && timelinePrimed.thumbCount >= 2,
      "inline timeline サムネクリックで timeline にフォーカスが残る",
      timelinePrimed,
    );

    const inlineTimelineLayout = await page.evaluate((idx) => {
      const preview = document.querySelector(".md-preview")!;
      const mediaEls = Array.from(preview.querySelectorAll("img, video.video-preview, .mermaid-container")).filter((el) => {
        if (el.tagName === "IMG" && el.closest(".video-timeline")) return false;
        if (el.tagName !== "VIDEO") return true;
        const src = (el.getAttribute("src") || "").toLowerCase();
        return [".mp4", ".mov", ".webm", ".avi", ".mkv", ".m4v", ".ogv"].some((ext) => src.endsWith(ext));
      });
      const video = mediaEls[idx] as HTMLVideoElement;
      const timeline = video.closest(".video-overlay-wrapper")!.querySelector(".video-timeline")!;
      const first = timeline.querySelector(".timeline-thumb-wrapper")!;
      const thumb = first.querySelector(".timeline-thumb")!;
      const label = first.querySelector(".timeline-time")!;
      const timelineStyle = getComputedStyle(timeline);
      const labelStyle = getComputedStyle(label);
      const thumbRect = thumb.getBoundingClientRect();
      const labelRect = label.getBoundingClientRect();
      return {
        timelineHeight: timeline.getBoundingClientRect().height,
        thumbWidth: thumbRect.width,
        thumbHeight: thumbRect.height,
        labelTop: labelRect.top,
        thumbBottom: thumbRect.bottom,
        labelPosition: labelStyle.position,
        labelBackground: labelStyle.backgroundColor,
        timelineAlignItems: timelineStyle.alignItems,
        overlapsThumb: labelRect.top < thumbRect.bottom - 1,
      };
    }, inlineVideoTarget.videoIndex);
    assert(
      !inlineTimelineLayout.overlapsThumb &&
        inlineTimelineLayout.labelPosition === "static" &&
        inlineTimelineLayout.timelineHeight >= inlineTimelineLayout.thumbHeight + 20,
      "inline 動画 timeline の時刻ラベルはサムネ画像と重ならない",
      inlineTimelineLayout,
    );

    await page.locator(`.media-sidebar-thumb[data-media-index="${inlineVideoTarget.videoIndex}"]`).click();
    await waitForNavSettle(page, inlineVideoTarget.videoIndex);
    const sidebarSelectedVideo = await page.evaluate((idx) => {
      const preview = document.querySelector(".md-preview")!;
      const mediaEls = Array.from(preview.querySelectorAll("img, video.video-preview, .mermaid-container")).filter((el) => {
        if (el.tagName === "IMG" && el.closest(".video-timeline")) return false;
        if (el.tagName !== "VIDEO") return true;
        const src = (el.getAttribute("src") || "").toLowerCase();
        return [".mp4", ".mov", ".webm", ".avi", ".mkv", ".m4v", ".ogv"].some((ext) => src.endsWith(ext));
      });
      const video = mediaEls[idx] as HTMLVideoElement;
      video.currentTime = 0;
      return {
        currentTime: video.currentTime,
        activeIndex: Number(document.querySelector(".media-sidebar-thumb.active")?.getAttribute("data-media-index") ?? "-1"),
        activeElementClass: (document.activeElement as HTMLElement | null)?.className || "",
      };
    }, inlineVideoTarget.videoIndex);
    await page.keyboard.press("ArrowRight");
    await page.waitForFunction((idx) => {
      const preview = document.querySelector(".md-preview")!;
      const mediaEls = Array.from(preview.querySelectorAll("img, video.video-preview, .mermaid-container")).filter((el) => {
        if (el.tagName === "IMG" && el.closest(".video-timeline")) return false;
        if (el.tagName !== "VIDEO") return true;
        const src = (el.getAttribute("src") || "").toLowerCase();
        return [".mp4", ".mov", ".webm", ".avi", ".mkv", ".m4v", ".ogv"].some((ext) => src.endsWith(ext));
      });
      return (mediaEls[idx] as HTMLVideoElement).currentTime > 0.1;
    }, inlineVideoTarget.videoIndex, { timeout: 5000 }).catch(() => {});
    const afterSidebarRight = await page.evaluate((idx) => {
      const preview = document.querySelector(".md-preview")!;
      const mediaEls = Array.from(preview.querySelectorAll("img, video.video-preview, .mermaid-container")).filter((el) => {
        if (el.tagName === "IMG" && el.closest(".video-timeline")) return false;
        if (el.tagName !== "VIDEO") return true;
        const src = (el.getAttribute("src") || "").toLowerCase();
        return [".mp4", ".mov", ".webm", ".avi", ".mkv", ".m4v", ".ogv"].some((ext) => src.endsWith(ext));
      });
      const video = mediaEls[idx] as HTMLVideoElement;
      return {
        currentTime: video.currentTime,
        activeIndex: Number(document.querySelector(".media-sidebar-thumb.active")?.getAttribute("data-media-index") ?? "-1"),
      };
    }, inlineVideoTarget.videoIndex);
    assert(
      afterSidebarRight.currentTime > sidebarSelectedVideo.currentTime &&
        afterSidebarRight.activeIndex === inlineVideoTarget.videoIndex,
      "ArrowRight はサイドバーで選択中の inline 動画 timeline も横移動する",
      { sidebarSelectedVideo, afterSidebarRight },
    );

    await page.evaluate((idx) => {
      const preview = document.querySelector(".md-preview")!;
      const mediaEls = Array.from(preview.querySelectorAll("img, video.video-preview, .mermaid-container")).filter((el) => {
        if (el.tagName === "IMG" && el.closest(".video-timeline")) return false;
        if (el.tagName !== "VIDEO") return true;
        const src = (el.getAttribute("src") || "").toLowerCase();
        return [".mp4", ".mov", ".webm", ".avi", ".mkv", ".m4v", ".ogv"].some((ext) => src.endsWith(ext));
      });
      const video = mediaEls[idx] as HTMLVideoElement;
      video.currentTime = 0;
      const wrapper = video.closest(".video-overlay-wrapper")!;
      (wrapper.querySelector(".video-timeline .timeline-thumb") as HTMLElement).click();
    }, inlineVideoTarget.videoIndex);

    await page.keyboard.press("ArrowRight");
    await page.waitForFunction((idx) => {
      const preview = document.querySelector(".md-preview")!;
      const mediaEls = Array.from(preview.querySelectorAll("img, video.video-preview, .mermaid-container")).filter((el) => {
        if (el.tagName === "IMG" && el.closest(".video-timeline")) return false;
        if (el.tagName !== "VIDEO") return true;
        const src = (el.getAttribute("src") || "").toLowerCase();
        return [".mp4", ".mov", ".webm", ".avi", ".mkv", ".m4v", ".ogv"].some((ext) => src.endsWith(ext));
      });
      return (mediaEls[idx] as HTMLVideoElement).currentTime > 0.1;
    }, inlineVideoTarget.videoIndex, { timeout: 5000 });
    const afterInlineRight = await page.evaluate((idx) => {
      const preview = document.querySelector(".md-preview")!;
      const mediaEls = Array.from(preview.querySelectorAll("img, video.video-preview, .mermaid-container")).filter((el) => {
        if (el.tagName === "IMG" && el.closest(".video-timeline")) return false;
        if (el.tagName !== "VIDEO") return true;
        const src = (el.getAttribute("src") || "").toLowerCase();
        return [".mp4", ".mov", ".webm", ".avi", ".mkv", ".m4v", ".ogv"].some((ext) => src.endsWith(ext));
      });
      const video = mediaEls[idx] as HTMLVideoElement;
      return {
        currentTime: video.currentTime,
        activeIndex: Number(document.querySelector(".media-sidebar-thumb.active")?.getAttribute("data-media-index") ?? "-1"),
      };
    }, inlineVideoTarget.videoIndex);
    assert(
      afterInlineRight.currentTime > timelinePrimed.time &&
        afterInlineRight.activeIndex === inlineVideoTarget.videoIndex,
      "ArrowRight は inline 動画 timeline 内だけを次サムネへ進める",
      { timelinePrimed, afterInlineRight },
    );

    await page.keyboard.press("ArrowLeft");
    const afterInlineLeft = await page.evaluate((idx) => {
      const preview = document.querySelector(".md-preview")!;
      const mediaEls = Array.from(preview.querySelectorAll("img, video.video-preview, .mermaid-container")).filter((el) => {
        if (el.tagName === "IMG" && el.closest(".video-timeline")) return false;
        if (el.tagName !== "VIDEO") return true;
        const src = (el.getAttribute("src") || "").toLowerCase();
        return [".mp4", ".mov", ".webm", ".avi", ".mkv", ".m4v", ".ogv"].some((ext) => src.endsWith(ext));
      });
      const video = mediaEls[idx] as HTMLVideoElement;
      return {
        currentTime: video.currentTime,
        activeIndex: Number(document.querySelector(".media-sidebar-thumb.active")?.getAttribute("data-media-index") ?? "-1"),
      };
    }, inlineVideoTarget.videoIndex);
    assert(
      afterInlineLeft.currentTime <= afterInlineRight.currentTime &&
        afterInlineLeft.activeIndex === inlineVideoTarget.videoIndex,
      "ArrowLeft は inline 動画 timeline 内だけを前サムネへ戻す",
      { afterInlineRight, afterInlineLeft },
    );

    await page.keyboard.press("ArrowDown");
    await waitForNavSettle(page, inlineVideoTarget.videoIndex + 1);
    const afterInlineDown = await measureNavState(page, inlineVideoTarget.videoIndex + 1);
    assert(
      afterInlineDown.activeIndex === inlineVideoTarget.videoIndex + 1 &&
        afterInlineDown.visibleRatio !== null &&
        afterInlineDown.visibleRatio >= 0.5,
      "ArrowDown は inline timeline から次の画像/動画へ移動する",
      afterInlineDown,
    );

    await page.locator(`.media-sidebar-thumb[data-media-index="${inlineVideoTarget.videoIndex}"]`).click();
    await waitForNavSettle(page, inlineVideoTarget.videoIndex);
    await page.evaluate((idx) => {
      const preview = document.querySelector(".md-preview")!;
      const mediaEls = Array.from(preview.querySelectorAll("img, video.video-preview, .mermaid-container")).filter((el) => {
        if (el.tagName === "IMG" && el.closest(".video-timeline")) return false;
        if (el.tagName !== "VIDEO") return true;
        const src = (el.getAttribute("src") || "").toLowerCase();
        return [".mp4", ".mov", ".webm", ".avi", ".mkv", ".m4v", ".ogv"].some((ext) => src.endsWith(ext));
      });
      const wrapper = mediaEls[idx].closest(".video-overlay-wrapper")!;
      (wrapper.querySelector(".video-timeline .timeline-thumb") as HTMLElement).click();
    }, inlineVideoTarget.videoIndex);
    await page.keyboard.press("ArrowUp");
    await waitForNavSettle(page, Math.max(0, inlineVideoTarget.videoIndex - 1));
    const afterInlineUp = await measureNavState(page, Math.max(0, inlineVideoTarget.videoIndex - 1));
    assert(
      afterInlineUp.activeIndex === Math.max(0, inlineVideoTarget.videoIndex - 1),
      "ArrowUp は inline timeline から前の画像/動画へ移動する",
      afterInlineUp,
    );
  }

  const samples = await stopMediaSampler(page);
  const expectedCount = thumbSummary.expected;
  const flickered = samples.filter((s) => s.total !== expectedCount || s.rendered !== expectedCount);
  assert(
    samples.length >= 5 && flickered.length === 0,
    "矢印キー遷移中もプレビューのメディアが一切消えない（チラつき非再発）",
    { sampleCount: samples.length, expectedCount, flickered: flickered.slice(0, 5) },
  );

  // --- Escape clears the active selection and highlight ---
  await page.keyboard.press("Escape");
  const escaped = await page.waitForFunction(
    () =>
      !document.querySelector(".media-sidebar-thumb.active") &&
      document.querySelectorAll(".media-nav-highlight").length === 0,
    undefined,
    { timeout: 3000 },
  ).then(() => true).catch(() => false);
  const afterEscape = await measureNavState(page, lastIdx);
  assert(
    escaped && afterEscape.activeIndex === null && afterEscape.highlightCount === 0,
    "Escape で active とハイライトが解除される",
    afterEscape,
  );

  // --- Fullscreen Mermaid minimap (full-size viewing opens from the diagram itself) ---
  await page.locator(".mermaid-container").first().click({ position: { x: 30, y: 30 } });
  await page.waitForTimeout(800);
  const fullscreenMeasure = await measureMinimap(page, {
    source: "#fs-wrapper svg",
    wrapper: "#fs-wrapper",
    viewport: "#fs-content",
    minimap: "#fs-minimap",
    minimapSvg: "#fs-minimap-content svg",
    minimapViewport: "#fs-minimap-viewport",
  });
  assert(
    fullscreenMeasure.ok && fullscreenMeasure.maxAbsDelta! <= 3,
    "Fullscreen Mermaid ミニマップが表示領域に追従する",
    fullscreenMeasure,
  );

  const fullscreenViewport = page.locator("#fs-content");
  const fullscreenBox = await fullscreenViewport.boundingBox();
  await page.mouse.move(fullscreenBox!.x + fullscreenBox!.width * 0.72, fullscreenBox!.y + fullscreenBox!.height * 0.46);
  await page.mouse.down();
  await page.mouse.move(fullscreenBox!.x + fullscreenBox!.width * 0.54, fullscreenBox!.y + fullscreenBox!.height * 0.34, {
    steps: 8,
  });
  await page.mouse.up();
  await page.waitForTimeout(250);
  const fullscreenAfterPan = await measureMinimap(page, {
    source: "#fs-wrapper svg",
    wrapper: "#fs-wrapper",
    viewport: "#fs-content",
    minimap: "#fs-minimap",
    minimapSvg: "#fs-minimap-content svg",
    minimapViewport: "#fs-minimap-viewport",
  });
  assert(
    fullscreenAfterPan.ok && fullscreenAfterPan.maxAbsDelta! <= 3,
    "Fullscreen Mermaid ミニマップがパン後も表示領域に追従する",
    fullscreenAfterPan,
  );

  await page.keyboard.down("Control");
  await page.mouse.move(fullscreenBox!.x + fullscreenBox!.width / 2, fullscreenBox!.y + fullscreenBox!.height / 2);
  await page.mouse.wheel(0, -500);
  await page.keyboard.up("Control");
  await page.waitForTimeout(250);
  const fullscreenAfterZoom = await measureMinimap(page, {
    source: "#fs-wrapper svg",
    wrapper: "#fs-wrapper",
    viewport: "#fs-content",
    minimap: "#fs-minimap",
    minimapSvg: "#fs-minimap-content svg",
    minimapViewport: "#fs-minimap-viewport",
  });
  assert(
    fullscreenAfterZoom.ok && fullscreenAfterZoom.maxAbsDelta! <= 3,
    "Fullscreen Mermaid ミニマップがズーム後も表示領域に追従する",
    fullscreenAfterZoom,
  );

  // --- Fullscreen video viewer: settings panel button functionality ---
  await page.keyboard.press("Escape");
  await page.waitForTimeout(300);
  const fsBtn = page.locator(".video-fs-overlay-btn").first();
  if (await fsBtn.count() > 0) {
    await fsBtn.click();
    await page.waitForTimeout(1500);

    const overlayVisible = await page.evaluate(() => {
      const overlay = document.querySelector("#video-fullscreen");
      return overlay ? overlay.classList.contains("visible") : false;
    });
    assert(overlayVisible, "動画フルスクリーンビューアが開く");

    // Open settings panel
    const settingsBtn = page.locator("#video-settings-btn");
    if (await settingsBtn.count() > 0) {
      await settingsBtn.click();
      await page.waitForTimeout(300);

      const panelVisible = await page.evaluate(() => {
        const p = document.querySelector("#video-settings-panel");
        return p ? p.classList.contains("visible") : false;
      });
      assert(panelVisible, "Video settings panel opens on button click");

      // Click a non-selected button in the first settings row
      const result = await page.evaluate(() => {
        const rows = document.querySelectorAll("#video-settings-panel .video-settings-buttons");
        if (!rows[0]) return { ok: false, reason: "no button row", rowCount: rows.length };
        const buttons = rows[0].querySelectorAll("button");
        if (buttons.length < 2) return { ok: false, reason: "not enough buttons", count: buttons.length };
        const initialSelected = Array.from(buttons).findIndex(b => b.classList.contains("selected"));
        const targetIdx = initialSelected === 0 ? 1 : 0;
        (buttons[targetIdx] as HTMLElement).click();
        const newSelected = Array.from(buttons).findIndex(b => b.classList.contains("selected"));
        return { ok: newSelected === targetIdx, initialSelected, newSelected, targetIdx };
      });
      assert(result.ok, "Video settings button click updates selected state", result);
    } else {
      fail("動画フルスクリーンの settings ボタンが見つからない");
    }
  } else {
    fail("動画の fullscreen ボタン (.video-fs-overlay-btn) が見つからない");
  }

  if (failed > 0) {
    process.exitCode = 1;
  }
} catch (err: unknown) {
  fail("media sidebar regression test aborted", { message: (err as Error).message, stack: (err as Error).stack });
  process.exitCode = 1;
} finally {
  if (browser) {
    await browser.close().catch(() => {});
  }
  proc.kill("SIGKILL");
}
