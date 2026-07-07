import assert from "node:assert/strict";
import http, { type IncomingMessage } from "node:http";
import { spawn, type ChildProcess } from "node:child_process";
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";

const SERVER_JS = new URL("../_build/js/release/build/server/server.js", import.meta.url).pathname;
const TMP_DIR = join(tmpdir(), `yunomi-review-loop-${Date.now()}`);
const LOCK_DIR = join(TMP_DIR, "locks");
const REPORT = join(TMP_DIR, "REPORT.md");
const PORT = 5167;

mkdirSync(LOCK_DIR, { recursive: true });
writeFileSync(REPORT, "# Review Loop\n\nBefore line\n");

function waitForServerOutput(proc: ChildProcess): Promise<number> {
  let output = "";
  let resolved = false;
  return new Promise((resolve, reject) => {
    proc.stdout?.on("data", (chunk: Buffer) => {
      output += String(chunk);
      if (resolved) return;
      const match = output.match(/http:\/\/127\.0\.0\.1:(\d+)/);
      if (match) {
        resolved = true;
        resolve(Number(match[1]));
      }
    });
    proc.stderr?.on("data", (chunk: Buffer) => {
      output += String(chunk);
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

function request(port: number, method: string, path: string, body = ""): Promise<{ status: number; body: string }> {
  return new Promise((resolve, reject) => {
    const req = http.request(
      `http://127.0.0.1:${port}${path}`,
      { method, headers: { "Content-Type": "application/json" } },
      (res: IncomingMessage) => {
        let data = "";
        res.on("data", (chunk: string) => {
          data += chunk;
        });
        res.on("end", () => resolve({ status: res.statusCode || 0, body: data }));
      },
    );
    req.on("error", reject);
    if (body.length > 0) req.write(body);
    req.end();
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

function collectOutput(proc: ChildProcess): { get: () => string } {
  let output = "";
  proc.stdout?.on("data", (chunk: Buffer) => {
    output += String(chunk);
  });
  proc.stderr?.on("data", (chunk: Buffer) => {
    output += String(chunk);
  });
  return { get: () => output };
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

async function waitForRound(port: number, round: number): Promise<any> {
  for (let i = 0; i < 80; i++) {
    const res = await request(port, "GET", "/review-state");
    assert.equal(res.status, 200);
    const state = JSON.parse(res.body);
    const rounds = state.review.rounds || [];
    if (rounds.at(-1)?.round === round) return state;
    await new Promise((resolve) => setTimeout(resolve, 150));
  }
  throw new Error(`round ${round} did not appear`);
}

async function main(): Promise<void> {
  const REVIEW_DIR = join(TMP_DIR, ".yunomi", "reviews", "no-branch");
  mkdirSync(REVIEW_DIR, { recursive: true });
  const env = { ...process.env, YUNOMI_LOCK_DIR: LOCK_DIR, YUNOMI_REVIEW_DIR: REVIEW_DIR };
  const server = spawn(process.execPath, [SERVER_JS, "--no-open", "--loop", "--port", String(PORT), REPORT], {
    cwd: TMP_DIR,
    env,
    stdio: ["ignore", "pipe", "pipe"],
  });
  const serverOutput = collectOutput(server);

  const port = await waitForServerOutput(server);
  await waitForHealth(port);

  const firstSubmit = await request(
    port,
    "POST",
    "/exit",
    JSON.stringify({
      summary: "Round 1 needs a text update",
      decision: "request_changes",
      action: "final_request_changes",
      comments: [{ row: 2, col: 1, text: "Please update this line", value: "Before line" }],
    }),
  );
  assert.equal(firstSubmit.status, 200);
  assert.equal(server.exitCode, null, "--loop request_changes must keep the server alive");

  const reviewJson = readFileSync(join(TMP_DIR, ".yunomi", "reviews", "no-branch", "review.json"), "utf-8");
  const review = JSON.parse(reviewJson);
  assert.equal(review.version, 1);
  assert.equal(review.rounds[0].decision, "request_changes");
  assert.equal(review.comments[0].id, "c-1-1");
  assert.equal(review.comments[0].status, "unresolved");
  assert.equal(review.comments[0].anchor.snippet, "Before line");

  writeFileSync(REPORT, "# Review Loop\n\nAfter line\n");
  const go = spawn(process.execPath, [SERVER_JS, "go", "--no-open", "--port", String(PORT)], {
    cwd: TMP_DIR,
    env,
    stdio: ["ignore", "pipe", "pipe"],
  });
  const goOutput = collectOutput(go);
  const goCode = await waitForExit(go, 10000);
  assert.equal(goCode, 0, `yunomi go should notify the running loop server\ngo output:\n${goOutput.get()}\nserver output:\n${serverOutput.get()}`);

  const state = await waitForRound(port, 2);
  assert.equal(state.unresolved_count, 1);
  assert.equal(state.review.comments[0].id, "c-1-1");
  assert.match(JSON.stringify(state.diff.lines), /Before line/);
  assert.match(JSON.stringify(state.diff.lines), /After line/);

  const blockedApprove = await request(
    port,
    "POST",
    "/exit",
    JSON.stringify({ summary: "try approve", decision: "approve", action: "final_approve", comments: [] }),
  );
  assert.equal(blockedApprove.status, 409, "server must reject approve while unresolved comments remain");

  const resolve = await request(port, "POST", "/resolve-comment", JSON.stringify({ id: "c-1-1" }));
  assert.equal(resolve.status, 200);

  const finalApprove = await request(
    port,
    "POST",
    "/exit",
    JSON.stringify({ summary: "approved", decision: "approve", action: "final_approve", comments: [] }),
  );
  assert.equal(finalApprove.status, 200);

  const exitCode = await waitForExit(server, 10000);
  assert.equal(exitCode, 0, "approve should exit the loop server");
  console.log("PASS: review loop e2e");
}

await main();
