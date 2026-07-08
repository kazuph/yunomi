/**
 * Video Timeline E2E Test (fullscreen video viewer)
 *
 * The sidebar is now a scroll navigator; the video timeline lives in the
 * fullscreen video viewer, opened via the ⛶ overlay button on preview videos.
 *
 * Tests:
 * - Video thumbnails render in the sidebar (navigator)
 * - Fullscreen viewer opens per video and loads metadata
 * - Timeline label extraction and duration validation
 * - ArrowDown switches videos inside the fullscreen viewer
 *
 * Run: node --experimental-strip-types v2/e2e/video_timeline.ts
 */
import http, { type IncomingMessage } from "node:http";
import { spawn, type ChildProcess } from "node:child_process";
import { mkdirSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { fileURLToPath } from "node:url";
import { chromium, type Browser, type Page } from "playwright";

const __dirname = fileURLToPath(new URL(".", import.meta.url));
const ROOT = join(__dirname, "..", "..");
const SERVER_JS = join(ROOT, "v2", "_build", "js", "release", "build", "server", "server.js");
const FIXTURE_MD = join(ROOT, "examples", "mixed-media-test.md");
const LOCK_DIR = join(tmpdir(), "yunomi-video-timeline-locks");
const ARTIFACTS_DIR = join(ROOT, ".artifacts", "video-timeline");
const BASE_PORT = 5361;

mkdirSync(LOCK_DIR, { recursive: true });
mkdirSync(ARTIFACTS_DIR, { recursive: true });

let passed = 0;
let failed = 0;

function assert(condition: boolean, msg: string): void {
  if (condition) {
    passed++;
    console.log(`  PASS: ${msg}`);
  } else {
    failed++;
    console.error(`  FAIL: ${msg}`);
  }
}

function sleep(ms: number): Promise<void> {
  return new Promise((r) => setTimeout(r, ms));
}

function waitForServer(port: number, timeoutMs = 15000): Promise<boolean> {
  return new Promise((resolve) => {
    const start = Date.now();
    const poll = () => {
      if (Date.now() - start > timeoutMs) { resolve(false); return; }
      http
        .get(`http://127.0.0.1:${port}/healthz`, (res: IncomingMessage) => {
          if (res.statusCode === 200) resolve(true);
          else setTimeout(poll, 200);
          res.resume();
        })
        .on("error", () => setTimeout(poll, 200));
    };
    poll();
  });
}

interface ServerHandle {
  proc: ChildProcess;
  port: number;
}

async function startServer(testFile: string, preferredPort: number): Promise<ServerHandle> {
  const proc = spawn("node", [SERVER_JS, testFile, "--no-open", "--port", String(preferredPort)], {
    stdio: ["pipe", "pipe", "pipe"],
    env: { ...process.env, HERDR_PANE_ID: "", YUNOMI_NOTIFY_CMD: "", YUNOMI_LOCK_DIR: LOCK_DIR, YUNOMI_REVIEW_DIR: join(tmpdir(), "yunomi-review-" + Date.now() + "-" + Math.random().toString(36).slice(2,6)) },
  });

  let stdout = "";
  proc.stdout!.on("data", (d: Buffer) => { stdout += d.toString(); });
  proc.stderr!.on("data", (d: Buffer) => { stdout += d.toString(); });

  const port = await new Promise<number>((resolve, reject) => {
    const timeout = setTimeout(() => reject(new Error(`Server start timed out. Output: ${stdout.substring(0, 300)}`)), 15000);
    const check = () => {
      const match = stdout.match(/http:\/\/127\.0\.0\.1:(\d+)/);
      if (match) {
        clearTimeout(timeout);
        resolve(parseInt(match[1], 10));
      } else if (proc.exitCode !== null) {
        clearTimeout(timeout);
        reject(new Error(`Server exited before ready. Output: ${stdout.substring(0, 300)}`));
      } else {
        setTimeout(check, 200);
      }
    };
    setTimeout(check, 300);
  });

  const ready = await waitForServer(port);
  if (!ready) throw new Error(`Server on port ${port} never became healthy`);

  return { proc, port };
}

function killServer(handle: ServerHandle): void {
  try { handle.proc.kill("SIGKILL"); } catch (_: unknown) {}
}

async function openFullscreenVideo(page: Page, videoIndex: number): Promise<boolean> {
  const btn = page.locator(`.video-fs-overlay-btn[data-video-index="${videoIndex}"]`);
  if (await btn.count() === 0) return false;
  await btn.click();
  return page.waitForFunction(() => {
    const overlay = document.querySelector("#video-fullscreen");
    if (!overlay || !overlay.classList.contains("visible")) return false;
    const video = overlay.querySelector("video");
    return !!video && video.readyState >= 1 && video.duration > 0;
  }, { timeout: 15000 }).then(() => true).catch(() => false);
}

async function closeFullscreenVideo(page: Page): Promise<void> {
  await page.keyboard.press("Escape");
  await page.waitForFunction(() => {
    const overlay = document.querySelector("#video-fullscreen");
    return !overlay || !overlay.classList.contains("visible");
  }, { timeout: 5000 }).catch(() => {});
}

async function run(): Promise<void> {
  const server = await startServer(FIXTURE_MD, BASE_PORT);
  const browser: Browser = await chromium.launch({ headless: true });
  const page: Page = await browser.newPage({ viewport: { width: 1400, height: 900 } });

  try {
    await page.goto(`http://127.0.0.1:${server.port}`, { waitUntil: "domcontentloaded", timeout: 30000 });

    // Sidebar navigator still shows video thumbnails
    const hasVideoThumbs = await page.waitForSelector(".media-sidebar-thumb-video", { timeout: 30000 })
      .then(() => true).catch(() => false);
    await page.screenshot({ path: join(ARTIFACTS_DIR, "01-sidebar-thumbnails.png") });
    assert(hasVideoThumbs, "Video thumbnails appeared in sidebar");

    const fsButtons = await page.$$(".video-fs-overlay-btn");
    assert(fsButtons.length > 0, `Found ${fsButtons.length} video fullscreen buttons in preview`);

    // --- Per-video: open fullscreen, validate timeline labels against duration ---
    for (let vi = 0; vi < fsButtons.length; vi++) {
      const opened = await openFullscreenVideo(page, vi);
      assert(opened, `Video ${vi + 1}: fullscreen viewer opened with valid duration`);
      if (!opened) continue;

      // Timeline thumbnails arrive asynchronously via /video-timeline SSE —
      // wait for at least one time label so the duration check below actually runs
      await page.waitForSelector("#video-fullscreen .video-timeline", { timeout: 10000 }).catch(() => {});
      const labelsArrived = await page.waitForFunction(() => {
        const overlay = document.querySelector("#video-fullscreen");
        return !!overlay && overlay.querySelectorAll(".timeline-time").length > 0;
      }, { timeout: 30000 }).then(() => true).catch(() => false);
      assert(labelsArrived, `Video ${vi + 1}: timeline time labels arrived (SSE)`);

      const result = await page.evaluate(() => {
        const overlay = document.querySelector("#video-fullscreen");
        const video = overlay?.querySelector("video");
        const duration = video ? video.duration : null;

        const timeElements = overlay ? overlay.querySelectorAll(".timeline-time") : [];
        const labels = Array.from(timeElements).map((el: Element) => el.textContent?.trim() || "").filter(Boolean);

        const labelSeconds = labels.map((label: string) => {
          const parts = label.split(":");
          return parseInt(parts[0]) * 60 + parseInt(parts[1]);
        });
        const maxLabelSeconds = labelSeconds.length > 0 ? Math.max(...labelSeconds) : null;

        return {
          videoDuration: duration,
          labels,
          maxLabelSeconds,
          exceedsDuration: duration !== null && maxLabelSeconds !== null && maxLabelSeconds > Math.ceil(duration),
        };
      });

      console.log(`  Video ${vi + 1}: duration=${result.videoDuration}s, labels=[${result.labels.join(", ")}]`);
      assert(result.labels.length > 0 && result.videoDuration !== null,
        `Video ${vi + 1}: timeline has time labels and video has duration`);
      assert(!result.exceedsDuration,
        `Video ${vi + 1}: labels within duration (max=${result.maxLabelSeconds}s, duration=${Math.ceil(result.videoDuration ?? 0)}s)`);

      const timeline = await page.$("#video-fullscreen .video-timeline");
      if (timeline) {
        await timeline.screenshot({ path: join(ARTIFACTS_DIR, `06-timeline-video-${vi + 1}.png`) }).catch(() => {});
      }

      await closeFullscreenVideo(page);
    }

    // --- ArrowDown switches to the next video inside the fullscreen viewer ---
    if (fsButtons.length > 1) {
      const opened = await openFullscreenVideo(page, 0);
      if (opened) {
        const srcBefore = await page.evaluate(() =>
          document.querySelector("#video-fullscreen video")?.getAttribute("src") || "");
        await page.keyboard.press("ArrowDown");
        // Wait until the NEW video is actually loaded (not just src swapped)
        const nextLoaded = await page.waitForFunction((prevSrc) => {
          const video = document.querySelector("#video-fullscreen video");
          if (!video) return false;
          const src = video.getAttribute("src") || "";
          return src !== prevSrc && video.readyState >= 1 && video.duration > 0;
        }, srcBefore, { timeout: 15000 }).then(() => true).catch(() => false);
        const srcAfter = await page.evaluate(() =>
          document.querySelector("#video-fullscreen video")?.getAttribute("src") || "");
        await page.screenshot({ path: join(ARTIFACTS_DIR, "04-after-arrow-down.png") });
        assert(nextLoaded && srcBefore !== srcAfter,
          `ArrowDown switches fullscreen video and it loads: ${srcBefore} -> ${srcAfter}`);
        await closeFullscreenVideo(page);
      } else {
        assert(false, "Could not reopen fullscreen viewer for arrow navigation test");
      }
    }
  } finally {
    await browser.close();
    killServer(server);
  }

  console.log(`\nResults: ${passed} passed, ${failed} failed`);
  if (failed > 0) process.exitCode = 1;
}

await run();
