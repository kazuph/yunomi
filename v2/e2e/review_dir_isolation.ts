import http from "node:http";
import { spawn, type ChildProcess } from "node:child_process";
import { existsSync, mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const SERVER_JS = new URL("../_build/js/release/build/server/server.js", import.meta.url).pathname;
const REPO_REVIEW = new URL("../../.yunomi/reviews/main/review.json", import.meta.url).pathname;
const WORK_DIR = mkdtempSync(join(tmpdir(), "yunomi-review-isolation-"));
const REVIEW_DIR = join(WORK_DIR, "reviews", "isolated");
const LOCK_DIR = join(WORK_DIR, "locks");
const REPORT = join(WORK_DIR, "REPORT.md");
const BASE_PORT = 5683;
writeFileSync(REPORT, "# Isolated E2E review\n");

function assert(condition: boolean, message: string, detail?: unknown): void {
  if (condition) {
    console.log(`PASS: ${message}`);
  } else {
    console.error(`FAIL: ${message}`);
    if (detail !== undefined) console.error(JSON.stringify(detail));
    process.exitCode = 1;
  }
}

function waitForServer(proc: ChildProcess): Promise<number> {
  let output = "";
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error(`server start timeout\n${output}`)), 10000);
    proc.stdout?.on("data", (chunk: Buffer) => {
      output += String(chunk);
      const match = output.match(/http:\/\/127\.0\.0\.1:(\d+)/);
      if (match) {
        clearTimeout(timer);
        resolve(Number(match[1]));
      }
    });
    proc.stderr?.on("data", (chunk: Buffer) => { output += String(chunk); });
    proc.on("exit", (code) => reject(new Error(`server exited before ready: ${code}\n${output}`)));
  });
}

function postExit(port: number): Promise<void> {
  const body = JSON.stringify({ action: "final_approve", decision: "approve", summary: "isolated e2e" });
  return new Promise((resolve, reject) => {
    const req = http.request(`http://127.0.0.1:${port}/exit`, {
      method: "POST",
      headers: { "Content-Type": "application/json", "Content-Length": Buffer.byteLength(body) },
    }, (res) => {
      res.resume();
      res.on("end", () => res.statusCode === 200 ? resolve() : reject(new Error(`exit status ${res.statusCode}`)));
    });
    req.on("error", reject);
    req.end(body);
  });
}

const before = existsSync(REPO_REVIEW) ? readFileSync(REPO_REVIEW, "utf8") : null;
const proc = spawn(process.execPath, [SERVER_JS, "--loop", "--no-open", "--port", String(BASE_PORT), REPORT], {
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

try {
  const port = await waitForServer(proc);
  await postExit(port);
  if (proc.exitCode === null) {
    await new Promise<void>((resolve) => proc.once("exit", () => resolve()));
  }
  const after = existsSync(REPO_REVIEW) ? readFileSync(REPO_REVIEW, "utf8") : null;
  const isolatedReview = join(REVIEW_DIR, "review.json");
  assert(before === after, "E2E never changes the repository review.json");
  assert(existsSync(isolatedReview), "E2E writes its review state only to its temporary directory");
  assert(readFileSync(isolatedReview, "utf8").includes("isolated e2e"), "temporary review state contains the test submission");
} finally {
  if (!proc.killed) proc.kill("SIGINT");
}
