import assert from "node:assert/strict";
import http, { type IncomingMessage } from "node:http";
import { spawn, type ChildProcess } from "node:child_process";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";

const SERVER_JS = new URL("../_build/js/release/build/server/server.js", import.meta.url).pathname;
const TMP_DIR = join(tmpdir(), `yunomi-realtime-relay-${Date.now()}`);
const LOCK_DIR = join(TMP_DIR, "locks");
const REVIEW_DIR = join(TMP_DIR, ".yunomi", "reviews", "no-branch");
const REPORT = join(TMP_DIR, "REPORT.md");
const NOTIFY_LOG = join(TMP_DIR, "notify.log");
const NOTIFY_SCRIPT = join(TMP_DIR, "notify-capture.mjs");
const PORT = 5173;
let activeServer: ChildProcess | null = null;

mkdirSync(REVIEW_DIR, { recursive: true });
mkdirSync(LOCK_DIR, { recursive: true });
writeFileSync(REPORT, "# Relay\n\nBefore relay\n");
writeFileSync(
  NOTIFY_SCRIPT,
  "import { appendFileSync } from 'node:fs'; appendFileSync(process.env.NOTIFY_LOG, process.argv[2] + '\\n');\n",
);

function request(port: number, method: string, path: string, body = ""): Promise<{ status: number; body: string }> {
  return new Promise((resolve, reject) => {
    const req = http.request(
      `http://127.0.0.1:${port}${path}`,
      { method, headers: { "Content-Type": "application/json" } },
      (res: IncomingMessage) => {
        let data = "";
        res.on("data", (chunk: Buffer) => {
          data += chunk.toString();
        });
        res.on("end", () => resolve({ status: res.statusCode || 0, body: data }));
      },
    );
    req.on("error", reject);
    if (body.length > 0) req.write(body);
    req.end();
  });
}

function waitForServerOutput(proc: ChildProcess): Promise<number> {
  let output = "";
  let resolved = false;
  return new Promise((resolve, reject) => {
    proc.stdout?.on("data", (chunk: Buffer) => {
      output += chunk.toString();
      const match = output.match(/http:\/\/127\.0\.0\.1:(\d+)/);
      if (!resolved && match) {
        resolved = true;
        resolve(Number(match[1]));
      }
    });
    proc.stderr?.on("data", (chunk: Buffer) => {
      output += chunk.toString();
    });
    proc.on("exit", (code) => {
      if (!resolved) {
        resolved = true;
        reject(new Error(`server exited before ready code=${code}\n${output}`));
      }
    });
    setTimeout(() => {
      if (!resolved) {
        resolved = true;
        reject(new Error(`server startup timeout\n${output}`));
      }
    }, 10000);
  });
}

async function waitForHealth(port: number): Promise<void> {
  for (let i = 0; i < 80; i++) {
    try {
      const res = await request(port, "GET", "/healthz");
      if (res.status === 200) return;
    } catch (_: unknown) {}
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  throw new Error(`healthz timeout on ${port}`);
}

function waitForNotify(pattern: RegExp): Promise<string> {
  return new Promise((resolve, reject) => {
    const started = Date.now();
    const tick = () => {
      const text = existsSync(NOTIFY_LOG) ? readFileSync(NOTIFY_LOG, "utf-8") : "";
      if (pattern.test(text)) {
        resolve(text);
        return;
      }
      if (Date.now() - started > 5000) {
        reject(new Error(`notify timeout for ${pattern}\n${text}`));
        return;
      }
      setTimeout(tick, 100);
    };
    tick();
  });
}

function waitForSseRound(port: number): Promise<string> {
  return new Promise((resolve, reject) => {
    const req = http.request(`http://127.0.0.1:${port}/sse`, { method: "GET" }, (res) => {
      let data = "";
      const timer = setTimeout(() => {
        req.destroy();
        reject(new Error(`SSE round timeout\n${data}`));
      }, 5000);
      res.on("data", (chunk: Buffer) => {
        data += chunk.toString();
        const match = data.match(/event: round\ndata: (.+)\n\n/s);
        if (match) {
          clearTimeout(timer);
          req.destroy();
          resolve(match[1]);
        }
      });
    });
    req.on("error", (err) => {
      if ((err as NodeJS.ErrnoException).code !== "ECONNRESET") reject(err);
    });
    req.end();
  });
}

function waitForExit(proc: ChildProcess, timeoutMs: number): Promise<number | null | "timeout"> {
  return new Promise((resolve) => {
    const timer = setTimeout(() => resolve("timeout"), timeoutMs);
    proc.once("exit", (code) => {
      clearTimeout(timer);
      resolve(code);
    });
  });
}

async function main(): Promise<void> {
  const env = {
    ...process.env,
    HERDR_PANE_ID: "",
    YUNOMI_LOCK_DIR: LOCK_DIR,
    YUNOMI_REVIEW_DIR: REVIEW_DIR,
    YUNOMI_NOTIFY_CMD: `${process.execPath} ${NOTIFY_SCRIPT} {msg}`,
    NOTIFY_LOG,
  };
  const server = activeServer = spawn(process.execPath, [SERVER_JS, "--no-open", "--loop", "--port", String(PORT), "--notify-pane", "p_test", REPORT], {
    cwd: TMP_DIR,
    env,
    stdio: ["ignore", "pipe", "pipe"],
  });
  const port = await waitForServerOutput(server);
  await waitForHealth(port);

  const metadata = JSON.parse(readFileSync(join(REVIEW_DIR, "server.json"), "utf-8"));
  assert.equal(metadata.notify_pane, "p_test");

  const comment = await request(
    port,
    "POST",
    "/comment",
    JSON.stringify({ type: "comment", row: 2, col: 1, text: "Relay this immediately", key: "2:1" }),
  );
  assert.equal(comment.status, 200);
  // The relayed notification must quote the commented source line, so the
  // agent can re-identify the target even after the file has moved on.
  await waitForNotify(/\[yunomi\] comment REPORT\.md:3 id=2:1 round=1\n> Before relay\nhuman: Relay this immediately\nurl=/);

  const submit = await request(
    port,
    "POST",
    "/exit",
    JSON.stringify({
      summary: "relay request changes",
      decision: "request_changes",
      action: "final_request_changes",
      comments: [{ row: 2, col: 1, text: "Please fix relay", value: "Before relay" }],
    }),
  );
  assert.equal(submit.status, 200);
  assert.equal(server.exitCode, null);
  await waitForNotify(/\[yunomi\] verdict REPORT\.md decision=request_changes/);

  const tabId = "relay-tab";
  const activeInstanceId = "relay-instance-current";
  const open = await request(
    port,
    "POST",
    "/session/open",
    JSON.stringify({ tabId, instanceId: activeInstanceId }),
  );
  assert.equal(open.status, 200);
  const close = await request(
    port,
    "POST",
    "/close",
    JSON.stringify({ tabId, instanceId: activeInstanceId, draft: "draft" }),
  );
  assert.equal(close.status, 200);
  const closeNotification = await waitForNotify(/\[yunomi\] tab closed REPORT\.md tab=relay-tab active=0/);
  const closeCount = () => (existsSync(NOTIFY_LOG) ? readFileSync(NOTIFY_LOG, "utf-8").match(/\[yunomi\] tab closed REPORT\.md/g)?.length || 0 : 0);
  assert.equal(closeCount(), 1, closeNotification);
  const duplicateClose = await request(
    port,
    "POST",
    "/close",
    JSON.stringify({ tabId, instanceId: activeInstanceId, draft: "draft" }),
  );
  assert.equal(duplicateClose.status, 200);
  const reopen = await request(
    port,
    "POST",
    "/session/open",
    JSON.stringify({ tabId, instanceId: "relay-instance-new" }),
  );
  assert.equal(reopen.status, 200);
  const staleClose = await request(
    port,
    "POST",
    "/close",
    JSON.stringify({ tabId, instanceId: activeInstanceId, draft: "draft" }),
  );
  assert.equal(staleClose.status, 200);
  assert.equal(closeCount(), 1, "duplicate and stale /close requests do not notify again");

  const sseRound = waitForSseRound(port);
  const reply = await request(
    port,
    "POST",
    "/reply-comment",
    JSON.stringify({ id: "c-1-1", text: "Fixed relay path", author: "agent" }),
  );
  assert.equal(reply.status, 200);
  const roundJson = JSON.parse(await sseRound);
  assert.equal(
    roundJson.review.comments.find((entry: { id: string }) => entry.id === "c-1-1")?.replies[0].text,
    "Fixed relay path",
  );

  const state = await request(port, "GET", "/review-state");
  assert.match(state.body, /unresolved/);
  assert.match(JSON.stringify(JSON.parse(state.body).review.comments), /Fixed relay path/);

  const resolve = await request(port, "POST", "/resolve-comment", JSON.stringify({ id: "c-1-1" }));
  assert.equal(resolve.status, 200);
  const approve = await request(
    port,
    "POST",
    "/exit",
    JSON.stringify({ summary: "approved", decision: "approve", action: "final_approve", comments: [] }),
  );
  assert.equal(approve.status, 200);
  assert.equal(await waitForExit(server, 10000), 0);
  console.log("PASS: realtime relay e2e");
}

try {
  await main();
} finally {
  if (activeServer?.exitCode === null && activeServer.signalCode === null) {
    activeServer.kill("SIGTERM");
  }
}
