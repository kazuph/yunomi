import { spawn, type ChildProcess } from "node:child_process";
import { existsSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const SERVER_JS = new URL("../_build/js/release/build/server/server.js", import.meta.url).pathname;
const WORK_DIR = mkdtempSync(join(tmpdir(), "yunomi-share-"));
const LOCK_DIR = join(WORK_DIR, "locks");
const REVIEW_DIR = join(WORK_DIR, "reviews");
const BASE_PORT = 5866;

let passed = 0;
let failed = 0;

function assert(condition: boolean, message: string, detail?: unknown): void {
  if (condition) {
    passed++;
    console.log(`PASS: ${message}`);
  } else {
    failed++;
    console.error(`FAIL: ${message}`);
    if (detail !== undefined) console.error(JSON.stringify(detail, null, 2));
  }
}

function startShare(args: string[]): Promise<{ proc: ChildProcess; output: () => string; port: number }> {
  return new Promise((resolve, reject) => {
    const proc = spawn(process.execPath, [SERVER_JS, "share", ...args], {
      cwd: WORK_DIR,
      stdio: ["ignore", "pipe", "pipe"],
      env: {
        ...process.env,
        HERDR_PANE_ID: "",
        YUNOMI_NOTIFY_CMD: "",
        YUNOMI_LOCK_DIR: LOCK_DIR,
        YUNOMI_REVIEW_DIR: REVIEW_DIR,
      },
    });
    let output = "";
    let settled = false;
    const check = () => {
      const match = output.match(/http:\/\/127\.0\.0\.1:(\d+)/);
      if (!settled && match) {
        settled = true;
        resolve({ proc, output: () => output, port: Number(match[1]) });
      }
    };
    proc.stdout?.on("data", (chunk: Buffer) => { output += chunk.toString("utf8"); check(); });
    proc.stderr?.on("data", (chunk: Buffer) => { output += chunk.toString("utf8"); check(); });
    proc.on("exit", (code) => {
      if (!settled) reject(new Error(`share server exited early ${code}\n${output}`));
    });
    setTimeout(() => {
      if (!settled) reject(new Error(`share server did not start\n${output}`));
    }, 15000);
  });
}

async function stop(proc: ChildProcess): Promise<void> {
  await new Promise<void>((resolve) => {
    proc.once("exit", () => resolve());
    proc.kill("SIGINT");
    setTimeout(() => {
      proc.kill("SIGKILL");
      resolve();
    }, 3000);
  });
}

async function get(port: number, path: string): Promise<{ status: number; text: string }> {
  const res = await fetch(`http://127.0.0.1:${port}${path}`);
  return { status: res.status, text: await res.text() };
}

async function post(port: number, path: string): Promise<{ status: number; text: string }> {
  const res = await fetch(`http://127.0.0.1:${port}${path}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ comments: [{ row: 1, col: 0, text: "must not write" }] }),
  });
  return { status: res.status, text: await res.text() };
}

const report = join(WORK_DIR, "report.md");
const notes = join(WORK_DIR, "notes.txt");
writeFileSync(report, "# Shared Report\n\nRead-only content.\n");
writeFileSync(notes, "plain shared text\n");

try {
  const share = await startShare([
    report,
    notes,
    "--no-open",
    "--port",
    String(BASE_PORT),
  ]);
  try {
    assert(share.output().includes("yunomi sharing report.md read-only"), "share command announces a read-only URL");

    const page = await get(share.port, "/?f=0");
    assert(page.status === 200 && page.text.includes("Shared Report"), "share serves the reviewed markdown");
    assert(page.text.includes("share-readonly-banner"), "share page renders a read-only banner");
    assert(page.text.includes("__YUNOMI_SHARE_READONLY__=true"), "share page marks the browser as read-only");
    assert(page.text.includes("submit-exit-btn") && page.text.includes("display:none"), "share page hides submit/comment controls");
    assert(page.text.includes("review-file-switcher") && page.text.includes("/?f=1"), "share supports read-only multi-file switching");

    const second = await get(share.port, "/?f=1");
    assert(second.status === 200 && second.text.includes("plain shared text"), "share serves the second file read-only");

    const blockedComment = await post(share.port, "/comment");
    assert(blockedComment.status === 405 && blockedComment.text.includes("read_only_share"), "share rejects comment POSTs");
    const blockedExit = await post(share.port, "/exit");
    assert(blockedExit.status === 405 && blockedExit.text.includes("read_only_share"), "share rejects submit POSTs");
    assert(!existsSync(join(REVIEW_DIR, "server.json")), "share does not write review server metadata");
  } finally {
    await stop(share.proc);
  }
} catch (error) {
  failed++;
  console.error(error instanceof Error ? error.stack || error.message : String(error));
} finally {
  rmSync(WORK_DIR, { recursive: true, force: true });
}

console.log(`Share read-only E2E: ${passed} passed, ${failed} failed`);
if (failed > 0) process.exit(1);
