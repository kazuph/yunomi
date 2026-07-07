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
const NON_LOOP_REPORT = join(TMP_DIR, "NON_LOOP.md");
const NON_LOOP_REVIEW_DIR = join(TMP_DIR, ".yunomi", "reviews", "non-loop");
const NON_LOOP_PORT = PORT + 1;

mkdirSync(LOCK_DIR, { recursive: true });
writeFileSync(REPORT, "# Review Loop\n\nBefore line\n");
mkdirSync(NON_LOOP_REVIEW_DIR, { recursive: true });
writeFileSync(NON_LOOP_REPORT, "# Non Loop Review\n\nA normal review can approve with comments.\n");

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
  const env = { ...process.env, HERDR_PANE_ID: "", YUNOMI_NOTIFY_CMD: "", YUNOMI_LOCK_DIR: LOCK_DIR, YUNOMI_REVIEW_DIR: REVIEW_DIR };
  const server = spawn(process.execPath, [SERVER_JS, "--no-open", "--loop", "--port", String(PORT), REPORT], {
    cwd: TMP_DIR,
    env,
    stdio: ["ignore", "pipe", "pipe"],
  });
  const serverOutput = collectOutput(server);

  const port = await waitForServerOutput(server);
  await waitForHealth(port);
  const initialHtml = await request(port, "GET", "/");
  assert.equal(initialHtml.status, 200);
  assert.match(initialHtml.body, /review-loop-sidebar/, "markdown page must reserve a left review loop sidebar");
  const uiJs = await request(port, "GET", "/ui.js");
  assert.equal(uiJs.status, 200);
  assert.match(uiJs.body, /この課題の該当箇所/, "review loop UI must render per-comment before/after snippets");
  assert.match(uiJs.body, /提出時.*現在.*差分/, "review loop UI must label what the round diff compares");
  assert.match(uiJs.body, /All resolved.*Approve/, "review loop UI must show approve-ready state when all threads resolve");
  assert.match(uiJs.body, /review-loop-submit-state/, "submit modal must render review loop status text");

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

  writeFileSync(
    join(NON_LOOP_REVIEW_DIR, "review.json"),
    JSON.stringify(
      {
        version: 1,
        branch: "non-loop",
        files: [NON_LOOP_REPORT],
        rounds: [
          { round: 1, started_at: "2026-07-07T00:00:00.000Z", submitted_at: "2026-07-07T00:01:00.000Z", decision: "request_changes", summary: "old" },
          { round: 2, started_at: "2026-07-07T00:02:00.000Z", submitted_at: null, decision: null, summary: "" },
        ],
        comments: [
          {
            id: "c-1-1",
            file: "NON_LOOP.md",
            line: 3,
            round: 1,
            text: "stale non-loop thread must not block approve",
            author: "human",
            status: "unresolved",
            replies: [],
            anchor: { snippet: "A normal review can approve with comments.", context_before: "", context_after: "" },
          },
        ],
      },
      null,
      2,
    ),
  );
  const nonLoopEnv = { ...process.env, HERDR_PANE_ID: "", YUNOMI_NOTIFY_CMD: "", YUNOMI_LOCK_DIR: LOCK_DIR, YUNOMI_REVIEW_DIR: NON_LOOP_REVIEW_DIR };
  const nonLoop = spawn(process.execPath, [SERVER_JS, "--no-open", "--port", String(NON_LOOP_PORT), NON_LOOP_REPORT], {
    cwd: TMP_DIR,
    env: nonLoopEnv,
    stdio: ["ignore", "pipe", "pipe"],
  });
  const nonLoopPort = await waitForServerOutput(nonLoop);
  await waitForHealth(nonLoopPort);
  const nonLoopHtml = await request(nonLoopPort, "GET", "/");
  assert.equal(nonLoopHtml.status, 200);
  assert.match(nonLoopHtml.body, /review-loop-sidebar/, "non-loop page with review.json must still have the sidebar mount");
  assert.match(nonLoopHtml.body, /review-loop-submit-state/, "submit modal must include a review loop status row");
  const nonLoopState = await request(nonLoopPort, "GET", "/review-state");
  assert.equal(nonLoopState.status, 200);
  const nonLoopStateJson = JSON.parse(nonLoopState.body);
  assert.equal(nonLoopStateJson.review.rounds.at(-1)?.round, 2, "non-loop review-state must expose the current review round");
  assert.equal(nonLoopStateJson.review.comments[0]?.status, "unresolved", "non-loop review-state must expose thread status");
  assert.equal(nonLoopStateJson.unresolved_count, 1, "non-loop review-state must display unresolved thread count");
  assert.equal(nonLoopStateJson.gate_unresolved_count, 0, "non-loop review-state must not enable approve gate");
  const nonLoopApprove = await request(
    nonLoopPort,
    "POST",
    "/exit",
    JSON.stringify({
      summary: "normal approve",
      decision: "approve",
      action: "final_approve",
      comments: [{ row: 3, col: 1, text: "normal review comment", value: "A normal review can approve with comments." }],
    }),
  );
  assert.equal(nonLoopApprove.status, 200, "non-loop approve must accept freshly written comments");
  assert.equal(await waitForExit(nonLoop, 10000), 0, "non-loop approve with comments should exit normally");
  console.log("PASS: review loop e2e");
}

await main();
