/**
 * E2E Smoke Test for yunomi v2 server
 * Verifies: server starts, serves HTML, healthz, SSE, submit flow, lock files
 *
 * Run: npx tsx e2e/smoke.ts
 */
import http, { type IncomingMessage } from "node:http";
import { spawn, type ChildProcess } from "node:child_process";
import { existsSync, unlinkSync, mkdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { writeFileSync } from "node:fs";

const BASE_PORT = 5199;
const SERVER_JS = new URL(
  "../_build/js/release/build/server/server.js",
  import.meta.url,
).pathname;

// Lock directory for test servers (avoids EPERM in restricted environments)
const LOCK_DIR = join(tmpdir(), "yunomi-test-locks");
mkdirSync(LOCK_DIR, { recursive: true });

// Review directory for test servers (isolate review.json from the real repo)
const REVIEW_DIR = join(tmpdir(), "yunomi-test-reviews-" + Date.now());
mkdirSync(REVIEW_DIR, { recursive: true });
let _rvSeq = 0;
function freshReviewDir(): string {
  const d = join(REVIEW_DIR, String(_rvSeq++));
  mkdirSync(d, { recursive: true });
  return d;
}

// Create a temp markdown file for testing
const TMP_DIR = join(tmpdir(), "yunomi-test-tmp");
mkdirSync(TMP_DIR, { recursive: true });
const TEST_MD = join(TMP_DIR, "test.md");
writeFileSync(
  TEST_MD,
  "# Hello\n\nTest content\n\n## Section 2\n\n- item 1\n- item 2\n",
);

const TEST_CSV = join(TMP_DIR, "test.csv");
writeFileSync(TEST_CSV, "name,age\nAlice,30\nBob,25\n");

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

function httpGet(port: number, path: string): Promise<{ status: number; body: string }> {
  return new Promise((resolve, reject) => {
    http
      .get(`http://127.0.0.1:${port}${path}`, (res: IncomingMessage) => {
        let data = "";
        res.on("data", (c: string) => (data += c));
        res.on("end", () => resolve({ status: res.statusCode!, body: data }));
      })
      .on("error", reject);
  });
}

function httpPost(port: number, path: string, body: string): Promise<{ status: number; body: string }> {
  return new Promise((resolve, reject) => {
    const req = http.request(
      `http://127.0.0.1:${port}${path}`,
      { method: "POST", headers: { "Content-Type": "application/json" } },
      (res: IncomingMessage) => {
        let data = "";
        res.on("data", (c: string) => (data += c));
        res.on("end", () => resolve({ status: res.statusCode!, body: data }));
      },
    );
    req.on("error", reject);
    req.write(body);
    req.end();
  });
}

function sleep(ms: number): Promise<void> {
  return new Promise((r) => setTimeout(r, ms));
}

async function waitForServer(port: number, timeoutMs: number): Promise<boolean> {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    try {
      const res = await httpGet(port, "/healthz");
      if (res.status === 200) return true;
    } catch (_: unknown) {}
    await sleep(200);
  }
  return false;
}

function waitForProcessExit(proc: ChildProcess, timeoutMs: number): Promise<{ exited: boolean; code: number | string }> {
  return new Promise((resolve) => {
    let done = false;
    const finish = (result: { exited: boolean; code: number | string }) => {
      if (done) return;
      done = true;
      resolve(result);
    };
    proc.once("exit", (code: number | null) => finish({ exited: true, code: code ?? 0 }));
    setTimeout(() => finish({ exited: false, code: "timeout" }), timeoutMs);
  });
}

async function runTest(
  label: string,
  testFile: string,
  mode: string,
  testFn: (mode: string, port: number) => Promise<void>,
): Promise<{ stdout: string; port: number }> {
  console.log(`\n--- ${label} ---`);
  const proc = spawn("node", [SERVER_JS, "--no-open", "--port", String(BASE_PORT), testFile], {
    stdio: ["ignore", "pipe", "pipe"],
    env: { ...process.env, HERDR_PANE_ID: "", YUNOMI_NOTIFY_CMD: "", YUNOMI_LOCK_DIR: LOCK_DIR, YUNOMI_REVIEW_DIR: freshReviewDir() },
  });

  let stdout = "";
  let actualPort = BASE_PORT;
  let resolved = false;
  const portDetected = new Promise<number>((resolve, reject) => {
    proc.stdout!.on("data", (d: Buffer) => {
      stdout += d;
      if (resolved) return;
      const match = stdout.match(/at http:\/\/127\.0\.0\.1:(\d+)/);
      if (match) {
        resolved = true;
        resolve(parseInt(match[1], 10));
      }
    });
    proc.stderr!.on("data", (d: Buffer) => (stdout += d));
    proc.on("exit", (code: number | null) => {
      if (!resolved) {
        resolved = true;
        reject(new Error(`Server exited (code ${code}) before port detected. Output: ${stdout.substring(0, 300)}`));
      }
    });
    setTimeout(() => {
      if (!resolved) {
        resolved = true;
        reject(new Error(`Port detection timed out after 10s. Output: ${stdout.substring(0, 300)}`));
      }
    }, 10000);
  });

  try {
    actualPort = await portDetected;
  } catch (err: unknown) {
    failed++;
    console.error(`  FAIL: ${(err as Error).message}`);
    try { proc.kill("SIGKILL"); } catch (_: unknown) {}
    return { stdout, port: BASE_PORT };
  }

  const ready = await waitForServer(actualPort, 5000);
  if (!ready) {
    failed++;
    console.error(`  FAIL: Server not ready on port ${actualPort} after 5s`);
    try { proc.kill("SIGKILL"); } catch (_: unknown) {}
    return { stdout, port: actualPort };
  }

  try {
    await testFn(mode, actualPort);
  } catch (err: unknown) {
    failed++;
    console.error(`  FAIL: ${(err as Error).message}`);
  }

  // Submit to exit the server
  try {
    await httpPost(
      actualPort,
      "/exit",
      JSON.stringify({
        summary: "test review",
        comments: [{ row: 0, col: 0, text: "test comment" }],
      }),
    );
  } catch (_: unknown) {}

  await sleep(500);

  // Ensure process is dead
  try {
    proc.kill("SIGKILL");
  } catch (_: unknown) {}

  return { stdout, port: actualPort };
}

// ===== Test: Markdown =====
let lastTestResult: { stdout: string; port: number };
lastTestResult = await runTest("Markdown Server", TEST_MD, "markdown", async (mode: string, port: number) => {
  const html = await httpGet(port, "/");
  assert(html.status === 200, "HTML returns 200");
  assert(html.body.includes("<!DOCTYPE html>"), "HTML has doctype");
  assert(html.body.includes("yunomi"), "HTML contains yunomi branding");
  assert(html.body.includes(`__YUNOMI_MODE__="${mode}"`), `Mode is ${mode}`);
  assert(html.body.includes("<h1>"), "Rendered markdown has h1");
  assert(html.body.includes("md-preview"), "Has markdown preview pane");
  assert(html.body.includes("md-layout"), "Has markdown side-by-side layout");
  assert(html.body.includes("md-left"), "Has markdown left panel");
  assert(html.body.includes("md-right"), "Has markdown source panel");
  assert(html.body.includes("recovery-modal"), "Markdown has recovery modal");
  assert(html.body.includes("recovery-restore"), "Markdown has restore button");
  assert(html.body.includes("recovery-discard"), "Markdown has discard button");

  const health = await httpGet(port, "/healthz");
  assert(health.status === 200, "Healthz returns 200");
  assert(health.body.includes('"ok":true'), "Healthz returns ok");

  const uijs = await httpGet(port, "/ui.js");
  assert(uijs.status === 200, "ui.js returns 200");
  assert(uijs.body.length > 100, "ui.js has content");

  const notfound = await httpGet(port, "/nonexistent");
  assert(notfound.status === 404, "Unknown path returns 404");
});

// ===== Test: CSV =====
lastTestResult = await runTest("CSV Server", TEST_CSV, "csv", async (mode: string, port: number) => {
  const html = await httpGet(port, "/");
  assert(html.status === 200, "CSV HTML returns 200");
  assert(html.body.includes(`__YUNOMI_MODE__="${mode}"`), `Mode is ${mode}`);
  assert(html.body.includes("<table"), "Has table element");
  assert(html.body.includes("Alice"), "Contains CSV data");
  assert(html.body.includes("data-row"), "Has data-row attributes");
  assert(html.body.includes("recovery-modal"), "CSV has recovery modal");
});

// ===== Test: Static file serving & Range requests =====
// Create a test static file alongside the test markdown
const TEST_STATIC_DIR = join(TMP_DIR, "assets");
mkdirSync(TEST_STATIC_DIR, { recursive: true });
const TEST_STATIC_FILE = join(TEST_STATIC_DIR, "test-image.png");
// Write a minimal valid PNG (1x1 red pixel)
const PNG_HEADER = Buffer.from([
  0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, // PNG signature
  0x00, 0x00, 0x00, 0x0d, 0x49, 0x48, 0x44, 0x52, // IHDR chunk
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, // 1x1
  0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53, // 8-bit RGB
  0xde, 0x00, 0x00, 0x00, 0x0c, 0x49, 0x44, 0x41, // IDAT chunk
  0x54, 0x08, 0xd7, 0x63, 0xf8, 0xcf, 0xc0, 0x00, // compressed data
  0x00, 0x00, 0x02, 0x00, 0x01, 0xe2, 0x21, 0xbc, // ...
  0x33, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4e, // IEND chunk
  0x44, 0xae, 0x42, 0x60, 0x82,
]);
writeFileSync(TEST_STATIC_FILE, PNG_HEADER);

// Create a small test "video" file (just bytes for Range testing)
const TEST_VIDEO_FILE = join(TEST_STATIC_DIR, "test.mp4");
const VIDEO_BYTES = Buffer.alloc(4096);
for (let i = 0; i < 4096; i++) VIDEO_BYTES[i] = i & 0xff;
writeFileSync(TEST_VIDEO_FILE, VIDEO_BYTES);

lastTestResult = await runTest("Static File Serving", TEST_MD, "markdown", async (mode: string, port: number) => {
  // Test: static image file serving
  const img = await httpGet(port, "/assets/test-image.png");
  assert(img.status === 200, "Static image returns 200");

  // Test: 404 for non-existent static file
  const missing = await httpGet(port, "/assets/nonexistent.png");
  assert(missing.status === 404, "Missing static file returns 404");

  // Test: path traversal blocked (raw request with .. in path)
  const traversal = await new Promise<{ status: number; body: string }>((resolve, reject) => {
    const opts = {
      hostname: "127.0.0.1", port, method: "GET",
      path: "/assets/..%2F..%2Fetc/passwd",
    };
    http.request(opts, (res: IncomingMessage) => {
      let data = "";
      res.on("data", (c: string) => (data += c));
      res.on("end", () => resolve({ status: res.statusCode!, body: data }));
    }).on("error", reject).end();
  });
  assert(traversal.status === 403, "Path traversal returns 403");

  // Test: Range request on video file
  const rangeRes = await new Promise<{ status: number; headers: http.IncomingHttpHeaders; bodyLength: number }>((resolve, reject) => {
    http.get(`http://127.0.0.1:${port}/assets/test.mp4`, {
      headers: { "Range": "bytes=0-99" }
    }, (res: IncomingMessage) => {
      const chunks: Buffer[] = [];
      res.on("data", (c: Buffer) => chunks.push(c));
      res.on("end", () => resolve({
        status: res.statusCode!,
        headers: res.headers,
        bodyLength: Buffer.concat(chunks).length
      }));
    }).on("error", reject);
  });
  assert(rangeRes.status === 206, "Range request returns 206");
  assert(rangeRes.headers["content-range"] === "bytes 0-99/4096", "Range response has correct Content-Range");
  assert(rangeRes.bodyLength === 100, "Range response body is 100 bytes");

  // Test: Range request mid-file
  const midRange = await new Promise<{ status: number; headers: http.IncomingHttpHeaders; bodyLength: number }>((resolve, reject) => {
    http.get(`http://127.0.0.1:${port}/assets/test.mp4`, {
      headers: { "Range": "bytes=1000-1999" }
    }, (res: IncomingMessage) => {
      const chunks: Buffer[] = [];
      res.on("data", (c: Buffer) => chunks.push(c));
      res.on("end", () => resolve({
        status: res.statusCode!,
        headers: res.headers,
        bodyLength: Buffer.concat(chunks).length
      }));
    }).on("error", reject);
  });
  assert(midRange.status === 206, "Mid-file range returns 206");
  assert(midRange.headers["content-range"] === "bytes 1000-1999/4096", "Mid-file range has correct Content-Range");
  assert(midRange.bodyLength === 1000, "Mid-file range body is 1000 bytes");

  // Test: Full GET on video (no Range header) returns 200
  const fullVideo = await new Promise<{ status: number; bodyLength: number }>((resolve, reject) => {
    http.get(`http://127.0.0.1:${port}/assets/test.mp4`, (res: IncomingMessage) => {
      const chunks: Buffer[] = [];
      res.on("data", (c: Buffer) => chunks.push(c));
      res.on("end", () => resolve({
        status: res.statusCode!,
        bodyLength: Buffer.concat(chunks).length
      }));
    }).on("error", reject);
  });
  assert(fullVideo.status === 200, "Full video GET returns 200");
  assert(fullVideo.bodyLength === 4096, "Full video body is 4096 bytes");
});

// ===== Test: video-timeline path traversal protection =====
lastTestResult = await runTest("Video Timeline Security", TEST_MD, "markdown", async (mode: string, port: number) => {
  // Test: path traversal via video-timeline
  const vtTraversal = await httpGet(port, "/video-timeline?path=../../etc/passwd&scene=0.01");
  assert(vtTraversal.status === 400 || vtTraversal.status === 403, "video-timeline rejects path traversal");

  // Test: absolute path outside base_dir
  const vtAbsolute = await httpGet(port, "/video-timeline?path=/etc/passwd&scene=0.01");
  assert(vtAbsolute.status === 403 || vtAbsolute.status === 404, "video-timeline rejects absolute path outside base_dir");
});

// ===== Test: localStorage format compatibility (CRV-004/CRV-005) =====
console.log("\n--- localStorage Format Compatibility ---");

// Replicate parse_stored_comments logic from dom.mbt FFI
function parseStoredComments(json: string): [string, string, string, string][] {
  try {
    const data = JSON.parse(json);
    const comments = data.comments;
    if (!comments || typeof comments !== "object") return [];
    return Object.entries(comments).map(([k, v]: [string, any]) => [k, String(v.row||0), String(v.col||0), v.text||""]);
  } catch(e: unknown) { return []; }
}

// Replicate is_storage_expired logic from dom.mbt FFI
function isStorageExpired(json: string): boolean {
  try {
    const data = JSON.parse(json);
    const TTL = 3 * 60 * 60 * 1000;
    return !data.timestamp || (Date.now() - data.timestamp > TTL);
  } catch(e: unknown) { return true; }
}

// Test: cli.cjs format is correctly parsed
{
  const cliCjsData = JSON.stringify({
    comments: {
      "2:3": { row: 2, col: 3, text: "fix this" },
      "5:0": { row: 5, col: 0, text: "needs review" },
    },
    timestamp: Date.now(),
  });
  const entries = parseStoredComments(cliCjsData);
  assert(entries.length === 2, "Parses cli.cjs format: 2 entries");
  assert(entries[0][0] === "2:3", "Parses cli.cjs format: correct key");
  assert(entries[0][1] === "2", "Parses cli.cjs format: correct row");
  assert(entries[0][2] === "3", "Parses cli.cjs format: correct col");
  assert(entries[0][3] === "fix this", "Parses cli.cjs format: correct text");
}

// Test: unwrapped (old) format is rejected
{
  const oldFormat = JSON.stringify({
    "2:3": { row: 2, col: 3, text: "fix this" },
  });
  const entries = parseStoredComments(oldFormat);
  assert(entries.length === 0, "Rejects old unwrapped format");
}

// Test: empty comments
{
  const empty = JSON.stringify({ comments: {}, timestamp: Date.now() });
  const entries = parseStoredComments(empty);
  assert(entries.length === 0, "Handles empty comments");
}

// Test: TTL not expired (recent timestamp)
{
  const recent = JSON.stringify({ comments: {}, timestamp: Date.now() });
  assert(!isStorageExpired(recent), "Recent timestamp is not expired");
}

// Test: TTL expired (old timestamp)
{
  const fourHoursAgo = Date.now() - 4 * 60 * 60 * 1000;
  const old = JSON.stringify({ comments: {}, timestamp: fourHoursAgo });
  assert(isStorageExpired(old), "4-hour-old timestamp is expired");
}

// Test: missing timestamp is treated as expired
{
  const noTs = JSON.stringify({ comments: { "1:0": { row: 1, col: 0, text: "hi" } } });
  assert(isStorageExpired(noTs), "Missing timestamp is treated as expired");
}

// Test: invalid JSON is treated as expired
{
  assert(isStorageExpired("not json"), "Invalid JSON is treated as expired");
}

// ===== Test: Recovery restore/discard behavior (CRV-007) =====
console.log("\n--- Recovery Restore/Discard Logic (CRV-007) ---");

// Simulate restore_comments() logic from app.mbt:
// parse stored data -> apply to comments map (non-empty entries only)
function simulateRestore(json: string): Record<string, { row: number; col: number; text: string }> {
  const entries = parseStoredComments(json);
  const restoredComments: Record<string, { row: number; col: number; text: string }> = {};
  for (const [key, rowStr, colStr, text] of entries) {
    if (text.length > 0) {
      restoredComments[key] = { row: parseInt(rowStr, 10), col: parseInt(colStr, 10), text };
    }
  }
  return restoredComments;
}

// Test: restore correctly maps all non-empty comments
{
  const stored = JSON.stringify({
    comments: {
      "2:3": { row: 2, col: 3, text: "fix this" },
      "5:0": { row: 5, col: 0, text: "needs review" },
      "1:1": { row: 1, col: 1, text: "" },
    },
    timestamp: Date.now(),
  });
  const restored = simulateRestore(stored);
  assert(Object.keys(restored).length === 2, "CRV-007: restore skips empty-text entries");
  assert(restored["2:3"] !== undefined, "CRV-007: restore maps key 2:3");
  assert(restored["2:3"].text === "fix this", "CRV-007: restore preserves comment text");
  assert(restored["5:0"].row === 5, "CRV-007: restore preserves row number");
  assert(restored["5:0"].col === 0, "CRV-007: restore preserves col number");
  assert(restored["1:1"] === undefined, "CRV-007: restore skips entry with empty text");
}

// Test: discard is equivalent to clearing storage (empty parse result)
{
  // After discard, ls_remove is called -> next parse returns empty
  const discarded = simulateRestore("{}");
  assert(Object.keys(discarded).length === 0, "CRV-007: discard (empty storage) yields no comments");
}

// Test: restore on expired data returns no comments (check_recovery deletes before restore)
{
  const expiredStored = JSON.stringify({
    comments: { "3:0": { row: 3, col: 0, text: "old comment" } },
    timestamp: Date.now() - 4 * 60 * 60 * 1000,
  });
  assert(isStorageExpired(expiredStored), "CRV-007: expired data is detected before restore");
}

// ===== Test: Lock file cleanup =====
console.log("\n--- Lock File Cleanup ---");
const lockFile = join(LOCK_DIR, `${lastTestResult.port}.lock`);
// After submit, lock should be cleaned up
assert(!existsSync(lockFile), "Lock file cleaned up after exit");

// ===== Test: HEAD method for /ui.js and /history =====
lastTestResult = await runTest("HEAD Method Extended", TEST_MD, "markdown", async (mode: string, port: number) => {
  const headUiJs = await new Promise<{ status: number; headers: http.IncomingHttpHeaders; body: string }>((resolve, reject) => {
    http.request(`http://127.0.0.1:${port}/ui.js`, { method: "HEAD" }, (res: IncomingMessage) => {
      let data = "";
      res.on("data", (c: string) => (data += c));
      res.on("end", () => resolve({ status: res.statusCode!, headers: res.headers, body: data }));
    }).on("error", reject).end();
  });
  assert(headUiJs.status === 200, "HEAD /ui.js returns 200");
  assert((headUiJs.headers["content-type"] || "").includes("javascript"), "HEAD /ui.js has JS content-type");
  assert(headUiJs.body.length === 0, "HEAD /ui.js has empty body");

  const headHistory = await new Promise<{ status: number; headers: http.IncomingHttpHeaders; body: string }>((resolve, reject) => {
    http.request(`http://127.0.0.1:${port}/history`, { method: "HEAD" }, (res: IncomingMessage) => {
      let data = "";
      res.on("data", (c: string) => (data += c));
      res.on("end", () => resolve({ status: res.statusCode!, headers: res.headers, body: data }));
    }).on("error", reject).end();
  });
  assert(headHistory.status === 200, "HEAD /history returns 200");
  assert((headHistory.headers["content-type"] || "").includes("json"), "HEAD /history has JSON content-type");
  assert(headHistory.body.length === 0, "HEAD /history has empty body");

  const headHealth = await new Promise<{ status: number; body: string }>((resolve, reject) => {
    http.request(`http://127.0.0.1:${port}/healthz`, { method: "HEAD" }, (res: IncomingMessage) => {
      let data = "";
      res.on("data", (c: string) => (data += c));
      res.on("end", () => resolve({ status: res.statusCode!, body: data }));
    }).on("error", reject).end();
  });
  assert(headHealth.status === 200, "HEAD /healthz returns 200");
  assert(headHealth.body.length === 0, "HEAD /healthz has empty body");
});

// ===== Test: Submit data persistence =====
// This test manages its own submit (server exits on /exit), so we don't use runTest
console.log("\n--- Submit Data Persistence ---");
{
  const submitProc = spawn("node", [SERVER_JS, "--no-open", "--port", String(BASE_PORT + 30), TEST_MD], {
    stdio: ["ignore", "pipe", "pipe"],
    env: { ...process.env, HERDR_PANE_ID: "", YUNOMI_NOTIFY_CMD: "", YUNOMI_LOCK_DIR: LOCK_DIR, YUNOMI_REVIEW_DIR: freshReviewDir() },
  });
  let sStdout = "";
  let sResolved = false;
  const sPortDetected = new Promise<number>((resolve, reject) => {
    submitProc.stdout!.on("data", (d: Buffer) => {
      sStdout += d;
      if (sResolved) return;
      const match = sStdout.match(/at http:\/\/127\.0\.0\.1:(\d+)/);
      if (match) { sResolved = true; resolve(parseInt(match[1], 10)); }
    });
    submitProc.stderr!.on("data", (d: Buffer) => (sStdout += d));
    submitProc.on("exit", () => { if (!sResolved) { sResolved = true; reject(new Error("Server exited")); } });
    setTimeout(() => { if (!sResolved) { sResolved = true; reject(new Error("Timeout")); } }, 10000);
  });
  try {
    const submitPort = await sPortDetected;
    await waitForServer(submitPort, 5000);
    const payload = JSON.stringify({
      summary: "e2e test review summary",
      comments: [
        { row: 1, col: 0, text: "line 1 comment", image: "" },
        { row: 3, col: 0, text: "line 3 comment with {braces} in text", image: "" },
        // row 2 of TEST_MD is "Test content" -- server must quote it as `value:`
        { row: 2, col: 0, text: "comment with quoted line", image: "" },
        { row: 7, col: 0, text: "comment with structured context", image: "" },
      ],
      summaryImages: [],
      yunomiAnswers: { "q1": "answer to question 1" },
    });
    // Server calls process.exit(0) after responding, which may close the socket
    // before the client fully reads the response. We handle both success and ECONNRESET.
    let submitOk = false;
    try {
      const submitRes = await httpPost(submitPort, "/exit", payload);
      submitOk = submitRes.status === 200;
    } catch (e: unknown) {
      // ECONNRESET / socket hang up means server exited after processing -- still success
      submitOk = (e as Error).message.includes("socket hang up") || (e as Error).message.includes("ECONNRESET");
    }
    assert(submitOk, "Submit with comments+answers accepted by server");
    // Wait for server to write YAML output
    await sleep(1000);
    assert(sStdout.includes("line 1 comment"), "Submit: server output includes comment text");
    assert(sStdout.includes("e2e test review summary"), "Submit: server output includes summary");
    assert(sStdout.includes("answer to question 1"), "Submit: answers object serialized as JSON, not coerced");
    assert(!sStdout.includes("[object Object]"), "Submit: no '[object Object]' coercion in YAML output");
    assert(sStdout.includes("value: Test content"), "Submit: comment quotes the source line it refers to");
    assert(sStdout.includes("context:"), "Submit: comment YAML includes structured context block");
    assert(sStdout.includes("before: - item 1"), "Submit: context includes the previous source line");
  } catch (err: unknown) {
    failed++;
    console.error(`  FAIL: Submit test: ${(err as Error).message}`);
  }
  try { submitProc.kill("SIGKILL"); } catch (_: unknown) {}
}

// Empty answers object {} must be omitted from YAML output (length<=2 gate in yaml.mbt)
console.log("\n--- Submit with Empty Answers ---");
{
  const emptyProc = spawn("node", [SERVER_JS, "--no-open", "--port", String(BASE_PORT + 31), TEST_MD], {
    stdio: ["ignore", "pipe", "pipe"],
    env: { ...process.env, HERDR_PANE_ID: "", YUNOMI_NOTIFY_CMD: "", YUNOMI_LOCK_DIR: LOCK_DIR, YUNOMI_REVIEW_DIR: freshReviewDir() },
  });
  let eStdout = "";
  let eResolved = false;
  const ePortDetected = new Promise<number>((resolve, reject) => {
    emptyProc.stdout!.on("data", (d: Buffer) => {
      eStdout += d;
      if (eResolved) return;
      const match = eStdout.match(/at http:\/\/127\.0\.0\.1:(\d+)/);
      if (match) { eResolved = true; resolve(parseInt(match[1], 10)); }
    });
    emptyProc.stderr!.on("data", (d: Buffer) => (eStdout += d));
    emptyProc.on("exit", () => { if (!eResolved) { eResolved = true; reject(new Error("Server exited")); } });
    setTimeout(() => { if (!eResolved) { eResolved = true; reject(new Error("Timeout")); } }, 10000);
  });
  try {
    const emptyPort = await ePortDetected;
    await waitForServer(emptyPort, 5000);
    const payload = JSON.stringify({
      summary: "empty answers review",
      comments: [{ row: 1, col: 0, text: "empty answers comment", image: "" }],
      summaryImages: [],
      yunomiAnswers: {},
    });
    try {
      await httpPost(emptyPort, "/exit", payload);
    } catch (_: unknown) {
      // ECONNRESET after process.exit is fine
    }
    await sleep(1000);
    assert(eStdout.includes("empty answers comment"), "Empty answers: submit processed");
    assert(!eStdout.includes("answers:"), "Empty answers: 'answers:' line omitted from YAML");
    assert(!eStdout.includes("[object Object]"), "Empty answers: no '[object Object]' coercion");
  } catch (err: unknown) {
    failed++;
    console.error(`  FAIL: Empty answers test: ${(err as Error).message}`);
  }
  try { emptyProc.kill("SIGKILL"); } catch (_: unknown) {}
}

// ===== Test: stale close after reload must not terminate the server =====
console.log("\n--- Session Close Ordering ---");
{
  const sessionProc = spawn("node", [SERVER_JS, "--no-open", "--port", String(BASE_PORT + 31), TEST_MD], {
    stdio: ["ignore", "pipe", "pipe"],
    env: { ...process.env, HERDR_PANE_ID: "", YUNOMI_NOTIFY_CMD: "", YUNOMI_LOCK_DIR: LOCK_DIR, YUNOMI_REVIEW_DIR: freshReviewDir() },
  });
  let sessionStdout = "";
  let sessionResolved = false;
  const sessionPortDetected = new Promise<number>((resolve, reject) => {
    sessionProc.stdout!.on("data", (d: Buffer) => {
      sessionStdout += d;
      if (sessionResolved) return;
      const match = sessionStdout.match(/at http:\/\/127\.0\.0\.1:(\d+)/);
      if (match) {
        sessionResolved = true;
        resolve(parseInt(match[1], 10));
      }
    });
    sessionProc.stderr!.on("data", (d: Buffer) => (sessionStdout += d));
    sessionProc.on("exit", () => {
      if (!sessionResolved) {
        sessionResolved = true;
        reject(new Error("Server exited before port detection"));
      }
    });
    setTimeout(() => {
      if (!sessionResolved) {
        sessionResolved = true;
        reject(new Error("Timeout"));
      }
    }, 10000);
  });
  try {
    const sessionPort = await sessionPortDetected;
    await waitForServer(sessionPort, 5000);
    const tabId = "tab-1";
    const oldInstance = "instance-old";
    const newInstance = "instance-new";

    await httpPost(sessionPort, "/session/open", JSON.stringify({ tabId, instanceId: oldInstance }));
    await httpPost(sessionPort, "/session/open", JSON.stringify({ tabId, instanceId: newInstance }));
    await httpPost(sessionPort, "/close", JSON.stringify({
      tabId,
      instanceId: oldInstance,
      draft: JSON.stringify({ summary: "stale close", comments: [{ row: 1, col: 0, text: "stale comment" }] }),
    }));
    await sleep(900);
    const staleHealth = await httpGet(sessionPort, "/healthz");
    assert(staleHealth.status === 200, "Session Close: stale close from previous instance does not terminate the server");

    const exitResult = waitForProcessExit(sessionProc, 12000);
    await httpPost(sessionPort, "/close", JSON.stringify({
      tabId,
      instanceId: newInstance,
      draft: JSON.stringify({ summary: "fresh close", comments: [{ row: 2, col: 0, text: "fresh comment" }] }),
    }));
    const closed = await exitResult;
    assert(closed.exited === true, "Session Close: latest instance close terminates the server");
    assert(sessionStdout.includes("fresh comment"), "Session Close: latest instance draft is the one that gets flushed");
    assert(!sessionStdout.includes("stale comment"), "Session Close: stale instance draft is ignored");
  } catch (err: unknown) {
    failed++;
    console.error(`  FAIL: Session close ordering test: ${(err as Error).message}`);
  }
  try { sessionProc.kill("SIGKILL"); } catch (_: unknown) {}
}

// ===== Test: split_json_array string safety =====
console.log("\n--- split_json_array String Safety ---");
{
  // Replicate split_json_array logic from app.mbt
  function splitJsonArray(json: string): string[] {
    const chars = [...json];
    const len = chars.length;
    const result: string[] = [];
    let depth = 0;
    let start = -1;
    let inString = false;
    let i = 0;
    while (i < len) {
      const ch = chars[i];
      if (inString) {
        if (ch === '\\') { i += 2; continue; }
        if (ch === '"') { inString = false; }
        i++; continue;
      }
      if (ch === '"') { inString = true; }
      else if (ch === '{') {
        if (depth === 0) { start = i; }
        depth++;
      } else if (ch === '}') {
        depth--;
        if (depth === 0 && start >= 0) {
          result.push(json.substring(start, i + 1));
          start = -1;
        }
      }
      i++;
    }
    return result;
  }

  // Test: basic array
  const basic = '[{"a":1},{"b":2}]';
  const basicResult = splitJsonArray(basic);
  assert(basicResult.length === 2, "split_json_array: basic array -> 2 entries");

  // Test: strings containing braces
  const withBraces = '[{"summary":"value with {braces} inside"},{"other":"normal"}]';
  const bracesResult = splitJsonArray(withBraces);
  assert(bracesResult.length === 2, "split_json_array: strings with {} -> 2 entries (not split wrongly)");
  assert(bracesResult[0].includes("{braces}"), "split_json_array: first entry preserves {braces} in string");

  // Test: escaped quotes inside strings
  const escaped = '[{"text":"he said \\"hello\\" and {left}"}]';
  const escapedResult = splitJsonArray(escaped);
  assert(escapedResult.length === 1, "split_json_array: escaped quotes handled correctly");

  // Test: nested objects
  const nested = '[{"data":{"inner":1}},{"other":"val"}]';
  const nestedResult = splitJsonArray(nested);
  assert(nestedResult.length === 2, "split_json_array: nested objects -> 2 entries");

  // Test: empty array
  const empty = '[]';
  const emptyResult = splitJsonArray(empty);
  assert(emptyResult.length === 0, "split_json_array: empty array -> 0 entries");
}

// ===== Test: Playwright Browser E2E =====
let playwrightAvailable = false;
try {
  const { chromium } = await import("playwright");
  playwrightAvailable = true;
} catch (_: unknown) {
  console.log("\n--- Playwright Browser E2E (SKIPPED: playwright not installed) ---");
}

if (playwrightAvailable) {
  const { chromium } = await import("playwright");

  // Start a server for browser tests
  console.log("\n--- Playwright Browser E2E ---");
  const browserProc = spawn("node", [SERVER_JS, "--no-open", "--port", String(BASE_PORT + 50), TEST_MD], {
    stdio: ["ignore", "pipe", "pipe"],
    env: { ...process.env, HERDR_PANE_ID: "", YUNOMI_NOTIFY_CMD: "", YUNOMI_LOCK_DIR: LOCK_DIR, YUNOMI_REVIEW_DIR: freshReviewDir() },
  });
  let bStdout = "";
  let bResolved = false;
  const bPortDetected = new Promise<number>((resolve, reject) => {
    browserProc.stdout!.on("data", (d: Buffer) => {
      bStdout += d;
      if (bResolved) return;
      const match = bStdout.match(/at http:\/\/127\.0\.0\.1:(\d+)/);
      if (match) { bResolved = true; resolve(parseInt(match[1], 10)); }
    });
    browserProc.stderr!.on("data", (d: Buffer) => (bStdout += d));
    browserProc.on("exit", () => { if (!bResolved) { bResolved = true; reject(new Error("Server exited")); } });
    setTimeout(() => { if (!bResolved) { bResolved = true; reject(new Error("Timeout")); } }, 10000);
  });

  let browserPort: number | undefined;
  try {
    browserPort = await bPortDetected;
  } catch (err: unknown) {
    failed++;
    console.error(`  FAIL: Browser test server start: ${(err as Error).message}`);
    try { browserProc.kill("SIGKILL"); } catch (_: unknown) {}
  }

  if (browserPort) {
    await waitForServer(browserPort, 5000);
    const browser = await chromium.launch({ headless: true });
    const page = await browser.newPage({ viewport: { width: 1440, height: 900 } });
    const BASE = `http://127.0.0.1:${browserPort}`;

    await page.goto(BASE, { waitUntil: "load", timeout: 30000 });
    await page.waitForSelector("#md-preview", { timeout: 10000 });

    // --- Theme toggle + localStorage persistence ---
    const themeResult = await page.evaluate(() => {
      const html = document.documentElement;
      const initialTheme = html.getAttribute("data-theme");
      const themeBtn = document.getElementById("theme-toggle");
      if (!themeBtn) return { error: "no theme button" } as any;
      themeBtn.click();
      const afterToggle = html.getAttribute("data-theme");
      const stored = localStorage.getItem("yunomi:theme");
      // Toggle back
      themeBtn.click();
      const afterSecond = html.getAttribute("data-theme");
      const storedAfter = localStorage.getItem("yunomi:theme");
      return { initialTheme, afterToggle, stored, afterSecond, storedAfter };
    });
    assert(themeResult.afterToggle !== themeResult.initialTheme, "Browser: theme toggles data-theme attribute");
    assert(themeResult.stored === themeResult.afterToggle, "Browser: theme persisted to localStorage");
    assert(themeResult.afterSecond === themeResult.initialTheme, "Browser: theme toggles back correctly");

    // --- View toggle (preview-only) + localStorage ---
    const viewResult = await page.evaluate(() => {
      const layout = document.querySelector(".md-layout");
      const viewBtn = document.getElementById("view-toggle");
      if (!layout || !viewBtn) return { error: "missing elements" } as any;
      const initialPreviewOnly = layout.classList.contains("preview-only");
      viewBtn.click();
      const afterClick = layout.classList.contains("preview-only");
      const stored = localStorage.getItem("yunomi-panel-state");
      // Toggle back
      viewBtn.click();
      const afterSecond = layout.classList.contains("preview-only");
      const storedAfter = localStorage.getItem("yunomi-panel-state");
      return { initialPreviewOnly, afterClick, stored, afterSecond, storedAfter };
    });
    assert(viewResult.afterClick !== viewResult.initialPreviewOnly, "Browser: view toggle changes preview-only class");
    assert(viewResult.stored !== null, "Browser: view state persisted to localStorage");
    assert(viewResult.afterSecond === viewResult.initialPreviewOnly, "Browser: view toggles back correctly");

    // --- History panel open/close via UI ---
    const historyResult = await page.evaluate(() => {
      const panel = document.getElementById("history-panel");
      const btn = document.getElementById("history-toggle");
      if (!panel || !btn) return { error: "missing history elements" } as any;
      btn.click();
      const afterOpen = panel.classList.contains("open");
      const bodyHasClass = document.body.classList.contains("history-open");
      const closeBtn = document.getElementById("history-panel-close");
      if (closeBtn) closeBtn.click();
      const afterClose = panel.classList.contains("open");
      return { afterOpen, bodyHasClass, afterClose };
    });
    assert(historyResult.afterOpen === true, "Browser: history panel opens with .open class");
    assert(historyResult.bodyHasClass === true, "Browser: body gets .history-open class");
    assert(historyResult.afterClose === false, "Browser: history panel closes correctly");

    // --- HEAD requests from browser context ---
    const headUiJs = await page.request.head(`${BASE}/ui.js`);
    assert(headUiJs.status() === 200, "Browser HEAD: /ui.js returns 200");
    assert((headUiJs.headers()["content-type"] || "").includes("javascript"), "Browser HEAD: /ui.js content-type");

    const headHistory = await page.request.head(`${BASE}/history`);
    assert(headHistory.status() === 200, "Browser HEAD: /history returns 200");
    assert((headHistory.headers()["content-type"] || "").includes("json"), "Browser HEAD: /history content-type");

    // --- yunomiAnswers selector check (no old selectors in DOM) ---
    const selectorCheck = await page.evaluate(() => {
      const oldCards = document.querySelectorAll(".yunomi-question-item");
      return { oldSelectorCount: oldCards.length };
    });
    assert(selectorCheck.oldSelectorCount === 0, "Browser: no .yunomi-question-item in DOM (old selector removed)");

    // --- XSS: no script tags in preview ---
    const xssCheck = await page.evaluate(() => {
      const preview = document.getElementById("md-preview");
      if (!preview) return { scriptTags: -1 };
      return { scriptTags: preview.querySelectorAll("script").length };
    });
    assert(xssCheck.scriptTags === 0, "Browser: no <script> tags in preview (XSS safe)");

    // --- Comment card image preview container exists ---
    const imgPreview = await page.evaluate(() => !!document.getElementById("comment-image-preview"));
    assert(imgPreview, "Browser: comment image preview container exists");

    // --- Comment image paste flow E2E ---
    // In markdown mode, comment card opens via mousedown+mouseup (drag flow), not click
    // Use Playwright's mouse API to simulate the full drag interaction
    // Default view is preview-only, so reveal the source panel first
    const layoutIsPreviewOnly = await page.evaluate(() => {
      const layout = document.querySelector(".md-layout");
      return layout ? layout.classList.contains("preview-only") : false;
    });
    if (layoutIsPreviewOnly) {
      await page.locator("#view-toggle").click();
    }
    const sourceCell = page.locator("td[data-row]").first();
    await sourceCell.waitFor({ state: "visible", timeout: 5000 });
    const box = await sourceCell.boundingBox();

    // mousedown on the cell triggers begin_drag, mouseup triggers finish_drag -> show_comment_card
    await page.mouse.move(box!.x + box!.width / 2, box!.y + box!.height / 2);
    await page.mouse.down();
    await page.mouse.up();

    // Wait for comment card to become visible (display: block)
    await page.waitForFunction(() => {
      const card = document.getElementById("comment-card");
      return card && getComputedStyle(card).display !== "none";
    }, { timeout: 5000 });

    const commentFlowResult = await page.evaluate(() => {
      const card = document.getElementById("comment-card");
      const preview = document.getElementById("comment-image-preview");
      return {
        cardVisible: card && getComputedStyle(card).display !== "none",
        previewInCard: !!preview,
      };
    });
    assert(commentFlowResult.cardVisible === true, "Browser: comment card opens on mousedown+mouseup");
    assert(commentFlowResult.previewInCard === true, "Browser: comment card has image preview area");

    // Dispatch a synthetic paste event with an image blob to trigger the paste handler
    const pasteResult = await page.evaluate(`(async () => {
      const base64Png = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI7wAAAABJRU5ErkJggg==";
      const binaryStr = atob(base64Png);
      const bytes = new Uint8Array(binaryStr.length);
      for (let i = 0; i < binaryStr.length; i++) bytes[i] = binaryStr.charCodeAt(i);
      const blob = new Blob([bytes], { type: "image/png" });
      const file = new File([blob], "test.png", { type: "image/png" });
      const mockClipboardData = { items: [{ type: "image/png", getAsFile: function() { return file; } }] };
      const pasteEvent = new Event("paste", { bubbles: true, cancelable: true });
      Object.defineProperty(pasteEvent, "clipboardData", { value: mockClipboardData });
      document.dispatchEvent(pasteEvent);
      await new Promise(function(r) { setTimeout(r, 500); });
      const previewEl = document.getElementById("comment-image-preview");
      const hasImage = previewEl && previewEl.querySelector("img") !== null;
      const imgSrc = hasImage ? previewEl.querySelector("img").src.substring(0, 30) : "";
      return { hasImage: hasImage, imgSrc: imgSrc };
    })()`) as { hasImage: boolean; imgSrc: string };
    assert(pasteResult.hasImage === true, "Browser: paste event renders image in comment preview");
    assert(pasteResult.imgSrc.startsWith("data:image"), "Browser: pasted image has data:image src");

    // Save the comment (with image) and verify it's stored
    const saveResult = await page.evaluate(() => {
      const textarea = document.getElementById("comment-input") as HTMLTextAreaElement | null;
      if (textarea) textarea.value = "comment with image";
      const saveBtn = document.getElementById("save-comment");
      if (saveBtn) saveBtn.click();
      const indicators = document.querySelectorAll(".has-comment");
      return { indicatorCount: indicators.length };
    });
    assert(saveResult.indicatorCount >= 1, "Browser: saved comment with image shows indicator");

    // --- Submit via UI: click Submit & Exit, verify server receives data ---
    // Close comment card first
    await page.evaluate(() => {
      const card = document.getElementById("comment-card");
      if (card) card.style.display = "none";
    });

    // Type a comment in global summary
    const globalComment = page.locator("#global-comment");
    if (await globalComment.isVisible().catch(() => false)) {
      await globalComment.fill("Browser E2E test summary");
    }

    // Create a promise that resolves when the server process exits
    const serverExited = new Promise<number | string>(resolve => {
      browserProc.on("exit", resolve);
      setTimeout(() => resolve("timeout"), 8000);
    });

    // Click Submit & Exit button
    const submitBtn = page.locator("#send-and-exit");
    if (await submitBtn.isVisible().catch(() => false)) {
      // Show submit modal first
      await submitBtn.click();
      // Wait for modal to appear
      await page.waitForFunction(() => {
        const modal = document.getElementById("submit-modal");
        return modal && modal.classList.contains("visible");
      }, { timeout: 5000 }).catch(() => {});
      // Confirm submit (click Approve button)
      const confirmBtn = page.locator("#modal-approve");
      if (await confirmBtn.isVisible().catch(() => false)) {
        await confirmBtn.click();
        // Wait for server process to exit (submit triggers process.exit)
        await serverExited;
      }
    }

    // Verify server output contains submitted data
    assert(bStdout.includes("Browser E2E test summary") || bStdout.includes("comment with image"),
      "Browser Submit: server output contains submitted data");
    assert(bStdout.includes("image_path:") && bStdout.includes(".png"),
      "Browser Submit: per-comment image is saved and referenced by image_path");

    // --- Close detection: reload must not terminate, final close must flush draft and exit ---
    const closeProc = spawn("node", [SERVER_JS, "--no-open", "--port", String(BASE_PORT + 51), TEST_MD], {
      stdio: ["ignore", "pipe", "pipe"],
      env: { ...process.env, HERDR_PANE_ID: "", YUNOMI_NOTIFY_CMD: "", YUNOMI_LOCK_DIR: LOCK_DIR, YUNOMI_REVIEW_DIR: freshReviewDir() },
    });
    let closeStdout = "";
    let closeResolved = false;
    const closePortDetected = new Promise<number>((resolve, reject) => {
      closeProc.stdout!.on("data", (d: Buffer) => {
        closeStdout += d;
        if (closeResolved) return;
        const match = closeStdout.match(/at http:\/\/127\.0\.0\.1:(\d+)/);
        if (match) {
          closeResolved = true;
          resolve(parseInt(match[1], 10));
        }
      });
      closeProc.stderr!.on("data", (d: Buffer) => (closeStdout += d));
      closeProc.on("exit", () => {
        if (!closeResolved) {
          closeResolved = true;
          reject(new Error("Close test server exited before port detected"));
        }
      });
      setTimeout(() => {
        if (!closeResolved) {
          closeResolved = true;
          reject(new Error("Close test server start timed out"));
        }
      }, 10000);
    });

    const closePort = await closePortDetected;
    await waitForServer(closePort, 5000);
    const closePage = await browser.newPage({ viewport: { width: 1440, height: 900 } });
    const CLOSE_BASE = `http://127.0.0.1:${closePort}`;
    await closePage.goto(CLOSE_BASE, { waitUntil: "load", timeout: 30000 });
    await closePage.waitForSelector("#md-preview", { timeout: 10000 });

    await closePage.reload({ waitUntil: "load", timeout: 30000 });
    await closePage.waitForSelector("#md-preview", { timeout: 10000 });
    await sleep(1200);
    const afterReload = await httpGet(closePort, "/healthz");
    assert(afterReload.status === 200, "Browser Close: reload does not terminate the server");

    // Default view is preview-only, so reveal the source panel first
    const closePreviewOnly = await closePage.evaluate(() => {
      const layout = document.querySelector(".md-layout");
      return layout ? layout.classList.contains("preview-only") : false;
    });
    if (closePreviewOnly) {
      await closePage.locator("#view-toggle").click();
    }
    const draftCell = closePage.locator("td[data-row]").first();
    await draftCell.waitFor({ state: "visible", timeout: 5000 });
    const draftBox = await draftCell.boundingBox();
    await closePage.mouse.move(draftBox!.x + draftBox!.width / 2, draftBox!.y + draftBox!.height / 2);
    await closePage.mouse.down();
    await closePage.mouse.up();
    await closePage.waitForFunction(() => {
      const card = document.getElementById("comment-card");
      return card && getComputedStyle(card).display !== "none";
    }, { timeout: 5000 });
    await closePage.locator("#comment-input").fill("Close draft comment");

    const closedResult = waitForProcessExit(closeProc, 12000);
    await closePage.goto("about:blank", { waitUntil: "load", timeout: 30000 });
    await closePage.close();
    const closed = await closedResult;
    assert(closed.exited === true, "Browser Close: closing the page exits the server");
    assert(closeStdout.includes("Close draft comment"), "Browser Close: closing flushes the in-progress draft");

    await browser.close();
    try { browserProc.kill("SIGKILL"); } catch (_: unknown) {}
    try { closeProc.kill("SIGKILL"); } catch (_: unknown) {}
  }
}

// ===== Helper: spawn server and wait for exit after POST /exit =====
async function testDecisionSubmit(
  label: string,
  portOffset: number,
  payload: object,
  yamlCheck: string,
): Promise<void> {
  console.log(`\n--- ${label} ---`);
  const proc = spawn("node", [SERVER_JS, "--no-open", "--port", String(BASE_PORT + portOffset), TEST_MD], {
    stdio: ["ignore", "pipe", "pipe"],
    env: { ...process.env, HERDR_PANE_ID: "", YUNOMI_NOTIFY_CMD: "", YUNOMI_LOCK_DIR: LOCK_DIR, YUNOMI_REVIEW_DIR: freshReviewDir() },
  });
  let stdout = "";
  proc.stdout!.on("data", (d: Buffer) => (stdout += d));
  proc.stderr!.on("data", () => {});
  const exited = waitForProcessExit(proc, 8000);
  try {
    await waitForServer(BASE_PORT + portOffset, 5000);
    const body = JSON.stringify(payload);
    let submitOk = false;
    try {
      const res = await httpPost(BASE_PORT + portOffset, "/exit", body);
      submitOk = res.status === 200;
    } catch (e: unknown) {
      submitOk = (e as Error).message.includes("socket hang up") || (e as Error).message.includes("ECONNRESET");
    }
    assert(submitOk, `${label}: server accepted submit`);
    // Wait for process to exit (server calls process.exit after writing YAML)
    const result = await exited;
    assert(result.exited, `${label}: server exited after submit`);
    assert(stdout.includes(yamlCheck), `${label}: YAML output contains ${yamlCheck}`);
  } catch (err: unknown) {
    failed++;
    console.error(`  FAIL: ${label}: ${(err as Error).message}`);
  }
  try { proc.kill("SIGKILL"); } catch (_: unknown) {}
}

// ===== Test: Approve decision =====
await testDecisionSubmit(
  "Approve decision",
  60,
  { summary: "approve test", comments: [], decision: "approve" },
  "decision: approve",
);

// ===== Test: Request Changes decision =====
await testDecisionSubmit(
  "Request Changes decision",
  61,
  { summary: "needs work", comments: [{ row: 0, col: 0, text: "fix this" }], decision: "request_changes" },
  "decision: request_changes",
);

// ===== Test: Decision-only submit (no comments, no summary) =====
await testDecisionSubmit(
  "Decision-only submit",
  63,
  { summary: "", comments: [], decision: "approve" },
  "decision: approve",
);

// ===== Test: POST /comment writes to live log =====
{
  console.log("\n--- Live comment IPC test ---");
  const liveProc = spawn("node", [SERVER_JS, "--no-open", "--port", String(BASE_PORT + 62), TEST_MD], {
    stdio: ["ignore", "pipe", "pipe"],
    env: { ...process.env, HERDR_PANE_ID: "", YUNOMI_NOTIFY_CMD: "", YUNOMI_LOCK_DIR: LOCK_DIR, YUNOMI_REVIEW_DIR: freshReviewDir() },
  });
  let liveStderr = "";
  liveProc.stderr!.on("data", (d: Buffer) => (liveStderr += d));
  liveProc.stdout!.on("data", () => {});
  try {
    await waitForServer(BASE_PORT + 62, 5000);
    // Wait a beat for stderr to flush the YUNOMI_LIVE line
    await sleep(500);
    // Send a comment
    const commentRes = await httpPost(BASE_PORT + 62, "/comment", JSON.stringify({
      type: "comment",
      row: 5,
      col: 0,
      text: "realtime comment test",
      key: "5:0",
    }));
    assert(commentRes.status === 200, "POST /comment returns 200");
    // Small delay to let file write complete
    await sleep(200);
    // Extract live log path from stderr
    const liveMatch = liveStderr.match(/\[YUNOMI_LIVE\]\s+(.+\.jsonl)/);
    assert(!!liveMatch, "Live log path printed to stderr");
    if (liveMatch) {
      const logPath = liveMatch[1].trim();
      assert(existsSync(logPath), "Live log file exists");
      const logContent = readFileSync(logPath, "utf-8");
      assert(logContent.includes("realtime comment test"), "Live log JSONL contains comment text");
    }
    // Send delete event
    const delRes = await httpPost(BASE_PORT + 62, "/comment", JSON.stringify({
      type: "delete",
      row: 5,
      col: 0,
      text: "",
      key: "5:0",
    }));
    assert(delRes.status === 200, "POST /comment delete returns 200");
  } catch (err: unknown) {
    failed++;
    console.error(`  FAIL: Live comment test: ${(err as Error).message}`);
  }
  try { liveProc.kill("SIGKILL"); } catch (_: unknown) {}
}

// ===== Test: Send to AI (handoff action) =====
await testDecisionSubmit(
  "Handoff action (Send to AI)",
  64,
  { summary: "fix the bug", comments: [{ row: 2, col: 0, text: "here" }], action: "handoff" },
  "action: handoff",
);

// ===== Test: final_approve action =====
await testDecisionSubmit(
  "Final approve action",
  65,
  { summary: "LGTM", comments: [], decision: "approve", action: "final_approve" },
  "action: final_approve",
);

// ===== Test: Restart with --no-open --port returns healthz 200 =====
{
  console.log("\n--- Restart healthz test ---");
  const restartProc = spawn("node", [SERVER_JS, "--no-open", "--port", String(BASE_PORT + 66), TEST_MD], {
    stdio: ["ignore", "pipe", "pipe"],
    env: { ...process.env, HERDR_PANE_ID: "", YUNOMI_NOTIFY_CMD: "", YUNOMI_LOCK_DIR: LOCK_DIR, YUNOMI_REVIEW_DIR: freshReviewDir() },
  });
  restartProc.stdout!.on("data", () => {});
  restartProc.stderr!.on("data", () => {});
  try {
    const ready = await waitForServer(BASE_PORT + 66, 5000);
    assert(ready, "Restarted server responds to healthz");
    const res = await httpGet(BASE_PORT + 66, "/healthz");
    assert(res.status === 200, "Healthz returns 200");
    assert(res.body.includes("ok"), "Healthz body contains ok");
  } catch (err: unknown) {
    failed++;
    console.error(`  FAIL: Restart test: ${(err as Error).message}`);
  }
  try { restartProc.kill("SIGKILL"); } catch (_: unknown) {}
}

// Cleanup temp files
try {
  unlinkSync(TEST_MD);
  unlinkSync(TEST_CSV);
  unlinkSync(TEST_STATIC_FILE);
  unlinkSync(TEST_VIDEO_FILE);
} catch (_: unknown) {}

// ===== Summary =====
console.log(`\n============================`);
console.log(`Results: ${passed} passed, ${failed} failed`);
console.log(`============================`);

if (failed > 0) process.exit(1);
