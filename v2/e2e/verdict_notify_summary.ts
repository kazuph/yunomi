/**
 * Verdict notify must carry the human's summary text, not just counters.
 *
 * Regression: a human submitting `request_changes` with 0 line comments and
 * only a summary produced a notify line reading
 * `comments=0 url=...` with no trace of the summary anywhere in the
 * notification. The launching agent read "comments=0" and concluded there
 * was no feedback, even though the summary carried the actual instruction.
 * The summary was only ever visible in the server's own debug log
 * ([YUNOMI_SESSION] summary_len=N) and the stdout YAML, neither of which the
 * agent sees over the notification channel.
 *
 * This also asserts the request_changes-received log line names the exact
 * next command (`npx yunomi go`) and where to read the full summary/comments
 * text (`review.json`), so an agent tailing server stdout is not left
 * guessing.
 *
 * Run: node --experimental-strip-types v2/e2e/verdict_notify_summary.ts
 */
import assert from "node:assert/strict";
import http from "node:http";
import { spawn, type ChildProcess } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const SERVER_JS = new URL("../_build/js/release/build/server/server.js", import.meta.url).pathname;
const WORK = mkdtempSync(join(tmpdir(), "yunomi-verdict-summary-"));
const REPORT = join(WORK, "REPORT.md");
const NOTIFY_LOG = join(WORK, "notify.log");
const NOTIFY_SCRIPT = join(WORK, "notify-capture.mjs");
const LOCK_DIR = join(WORK, "locks");
const REVIEW_DIR = join(WORK, ".yunomi", "reviews", "verdict-summary");

writeFileSync(REPORT, "# Verdict summary\n\nBody line.\n");
writeFileSync(NOTIFY_LOG, "");
writeFileSync(
  NOTIFY_SCRIPT,
  "import { appendFileSync } from 'node:fs'; appendFileSync(process.env.NOTIFY_LOG, process.argv[2] + '\\n');\n",
);

let failed = 0;
function assertLine(cond: boolean, msg: string, detail?: unknown) {
  if (cond) { console.log(`PASS: ${msg}`); return; }
  failed++;
  console.error(`FAIL: ${msg}`);
  if (detail !== undefined) console.error(JSON.stringify(detail, null, 2));
}

function request(port: number, method: string, path: string, body?: string): Promise<{ status: number; body: string }> {
  return new Promise((resolve, reject) => {
    const req = http.request(
      { hostname: "127.0.0.1", port, path, method, headers: { "Content-Type": "application/json" } },
      (res) => {
        let data = "";
        res.on("data", (c) => (data += c));
        res.on("end", () => resolve({ status: res.statusCode || 0, body: data }));
      },
    );
    req.on("error", reject);
    if (body) req.write(body);
    req.end();
  });
}

function collectOutput(proc: ChildProcess): { get: () => string } {
  let output = "";
  proc.stdout?.on("data", (chunk: Buffer) => { output += String(chunk); });
  proc.stderr?.on("data", (chunk: Buffer) => { output += String(chunk); });
  return { get: () => output };
}

function stop(p: ChildProcess): Promise<void> {
  return new Promise((resolve) => {
    p.on("exit", () => resolve());
    p.kill("SIGINT");
    setTimeout(() => { p.kill("SIGKILL"); resolve(); }, 3000);
  });
}

async function main() {
  const env = {
    ...process.env,
    HERDR_PANE_ID: "",
    TMUX_PANE: "",
    YUNOMI_NOTIFY_CMD: `${process.execPath} ${NOTIFY_SCRIPT} {msg}`,
    NOTIFY_LOG,
    YUNOMI_LOCK_DIR: LOCK_DIR,
    YUNOMI_REVIEW_DIR: REVIEW_DIR,
  };
  const server = spawn(process.execPath, [SERVER_JS, REPORT, "--loop", "--no-open", "--port", "0"], {
    cwd: WORK,
    env,
    stdio: ["ignore", "pipe", "pipe"],
  });
  const out = collectOutput(server);
  const port = await new Promise<number>((resolve, reject) => {
    let buf = "";
    const onData = (chunk: Buffer) => {
      buf += String(chunk);
      const m = buf.match(/http:\/\/127\.0\.0\.1:(\d+)/);
      if (m) resolve(Number(m[1]));
    };
    server.stdout?.on("data", onData);
    server.stderr?.on("data", onData);
    server.once("exit", (code) => reject(new Error(`server exited before ready code=${code}\n${out.get()}`)));
    setTimeout(() => reject(new Error(`server start timeout\n${out.get()}`)), 10000);
  });

  try {
    // Case A: comments=0, non-empty summary, request_changes.
    const withSummary = await request(port, "POST", "/exit", JSON.stringify({
      summary: "Fix the Japanese wording in section 2 and rerun the build.",
      decision: "request_changes",
      action: "final_request_changes",
      comments: [],
    }));
    assertLine(withSummary.status === 200, "comments=0 + summary request_changes is accepted", withSummary);

    let notifyLog = readFileSync(NOTIFY_LOG, "utf-8");
    assertLine(
      /\[yunomi\] verdict REPORT\.md decision=request_changes action=final_request_changes comments=0\nhuman: Fix the Japanese wording in section 2 and rerun the build\.\nurl=/.test(notifyLog),
      "verdict notify carries the full summary text on the human: line even when comments=0",
      { notifyLog },
    );

    assertLine(
      /\[yunomi\] request_changes received; full summary\/comments: .*review\.json \(if launched via `herdr run`, read `herdr job log <job>` first\); next: fix the review items, then run `npx yunomi go`/.test(out.get()),
      "request_changes-received log names review.json and the exact next command (`npx yunomi go`)",
      { serverOutput: out.get() },
    );

    // Case B: same round, empty summary this time — must not silently drop
    // the summary field, must say so explicitly.
    const emptySummary = await request(port, "POST", "/exit", JSON.stringify({
      summary: "",
      decision: "request_changes",
      action: "final_request_changes",
      comments: [],
    }));
    assertLine(emptySummary.status === 200, "comments=0 + empty summary request_changes is accepted", emptySummary);

    notifyLog = readFileSync(NOTIFY_LOG, "utf-8");
    assertLine(
      /\[yunomi\] verdict REPORT\.md decision=request_changes action=final_request_changes comments=0\nsummary=\(empty\)\nurl=/.test(notifyLog),
      "verdict notify explicitly marks an empty summary as summary=(empty) instead of omitting it",
      { notifyLog },
    );
  } finally {
    await stop(server);
    rmSync(WORK, { recursive: true, force: true });
  }
}

await main();
console.log(`\nResults: ${failed === 0 ? "all passed" : failed + " failed"}`);
if (failed > 0) process.exitCode = 1;
