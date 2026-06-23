/**
 * PR Verification E2E Test
 * Test A: Image preview -> Fullscreen -> Esc -> Comment dialog
 * Test B: Submit & Exit flow
 *
 * Run: node --experimental-strip-types v2/e2e/pr_verification.ts
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
const FIXTURE_MD = join(ROOT, "examples", "preview-regression.md");
const LOCK_DIR = join(tmpdir(), "yunomi-pr-verification-locks");
const ARTIFACTS = join(tmpdir(), "yunomi-pr-verification");

mkdirSync(LOCK_DIR, { recursive: true });
mkdirSync(ARTIFACTS, { recursive: true });

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
  stdout: string;
}

async function startServer(testFile: string, preferredPort: number): Promise<ServerHandle> {
  const proc = spawn("node", [SERVER_JS, testFile, "--no-open", "--port", String(preferredPort)], {
    stdio: ["pipe", "pipe", "pipe"],
    env: { ...process.env, YUNOMI_LOCK_DIR: LOCK_DIR },
  });

  let stdout = "";
  proc.stdout!.on("data", (d: Buffer) => { stdout += d.toString(); });
  proc.stderr!.on("data", (d: Buffer) => { stdout += d.toString(); });

  // Detect actual port from output
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

  return { proc, port, get stdout() { return stdout; } } as unknown as ServerHandle;
}

function killServer(handle: ServerHandle): void {
  try { handle.proc.kill("SIGKILL"); } catch (_: unknown) {}
}

// ===== Test A: Image preview -> Fullscreen -> Esc -> Comment dialog =====
async function testA(): Promise<void> {
  console.log("\n--- Test A: Image preview -> Fullscreen -> Esc -> Comment dialog ---");
  const server = await startServer(FIXTURE_MD, 5200);
  const browser: Browser = await chromium.launch({ headless: true });
  const page: Page = await browser.newPage({ viewport: { width: 1280, height: 900 } });

  try {
    await page.goto(`http://127.0.0.1:${server.port}`, { waitUntil: "domcontentloaded", timeout: 15000 });
    await page.waitForSelector("#md-preview", { timeout: 10000 });
    await page.screenshot({ path: join(ARTIFACTS, "01-initial-page.png") });

    // Find images inside #md-preview (preview area where click triggers fullscreen)
    const mdPreviewImages = await page.$$("#md-preview img");
    assert(mdPreviewImages.length > 0, `Found ${mdPreviewImages.length} images in #md-preview`);

    // Click first visible non-mermaid image
    let clickedImage = false;
    for (const img of mdPreviewImages) {
      const isVisible = await img.isVisible();
      const isMermaid = await img.evaluate((el: Element) => el.closest(".mermaid-container") !== null);
      if (isVisible && !isMermaid) {
        await img.click();
        clickedImage = true;
        break;
      }
    }
    assert(clickedImage, "Clicked a visible image in #md-preview");

    if (clickedImage) {
      // Wait for fullscreen overlay to appear
      const fullscreenVisible = await page.waitForFunction(() => {
        const el = document.getElementById("image-fullscreen");
        return el && getComputedStyle(el).display !== "none";
      }, { timeout: 3000 }).then(() => true).catch(() => false);

      assert(fullscreenVisible, "Fullscreen overlay (#image-fullscreen) is visible after image click");
      await page.screenshot({ path: join(ARTIFACTS, "02-fullscreen-overlay.png") });

      // Press Escape to close fullscreen
      await page.keyboard.press("Escape");

      const fullscreenHidden = await page.waitForFunction(() => {
        const el = document.getElementById("image-fullscreen");
        return !el || getComputedStyle(el).display === "none";
      }, { timeout: 3000 }).then(() => true).catch(() => false);

      assert(fullscreenHidden, "Fullscreen overlay hidden after Escape");
      await page.screenshot({ path: join(ARTIFACTS, "03-after-escape.png") });
    }

    // Check for comment-related elements in DOM
    const hasCommentCard = await page.$("#comment-card") !== null;
    const hasCommentOverlay = await page.$("#comment-overlay") !== null;
    assert(hasCommentCard || hasCommentOverlay, "Comment card or overlay element exists in DOM");

    await page.screenshot({ path: join(ARTIFACTS, "04-comment-dialog.png") });
  } finally {
    await browser.close();
    killServer(server);
  }
}

// ===== Test B: Submit & Exit =====
async function testB(): Promise<void> {
  console.log("\n--- Test B: Submit & Exit ---");
  const server = await startServer(FIXTURE_MD, 5201);
  const browser: Browser = await chromium.launch({ headless: true });
  const page: Page = await browser.newPage({ viewport: { width: 1280, height: 900 } });

  try {
    await page.goto(`http://127.0.0.1:${server.port}`, { waitUntil: "domcontentloaded", timeout: 15000 });
    await page.waitForSelector("#md-preview", { timeout: 10000 });

    // Find Submit & Exit button
    const submitBtn = page.locator("#send-and-exit");
    const submitBtnExists = await submitBtn.isVisible().catch(() => false);
    assert(submitBtnExists, "Submit & Exit button (#send-and-exit) is visible");

    if (submitBtnExists) {
      await submitBtn.click();
      await page.screenshot({ path: join(ARTIFACTS, "05-submit-modal.png") });

      // Wait for submit modal to appear
      const modalVisible = await page.waitForFunction(() => {
        const modal = document.getElementById("submit-modal");
        return modal && (modal.classList.contains("visible") || getComputedStyle(modal).display !== "none");
      }, { timeout: 3000 }).then(() => true).catch(() => false);

      assert(modalVisible, "Submit modal appeared after clicking Submit & Exit");

      // The current submit modal is decision-based: approving is the positive
      // confirmation path, while request-changes is tested in smoke.ts.
      const confirmBtn = page.locator("#modal-approve");
      const confirmExists = await confirmBtn.isVisible().catch(() => false);

      if (confirmExists) {
        // Set up server exit listener before clicking confirm
        const serverExited = new Promise<boolean>((resolve) => {
          const timeout = setTimeout(() => resolve(false), 8000);
          server.proc.on("exit", () => {
            clearTimeout(timeout);
            resolve(true);
          });
          if (server.proc.exitCode !== null) {
            clearTimeout(timeout);
            resolve(true);
          }
        });

        await confirmBtn.click();
        await page.screenshot({ path: join(ARTIFACTS, "06-after-submit.png") });

        const exited = await serverExited;
        assert(exited, "Server process exited after approve confirmation");
      } else {
        assert(confirmExists, "Approve decision button (#modal-approve) is visible in submit modal");
      }
    }
  } finally {
    await browser.close();
    killServer(server);
  }
}

// ===== Run tests =====
try {
  await testA();
} catch (err: unknown) {
  failed++;
  console.error(`  FAIL: Test A threw: ${(err as Error).message}`);
}

try {
  await testB();
} catch (err: unknown) {
  failed++;
  console.error(`  FAIL: Test B threw: ${(err as Error).message}`);
}

console.log(`\n============================`);
console.log(`Results: ${passed} passed, ${failed} failed`);
console.log(`============================`);
if (failed > 0) process.exit(1);
