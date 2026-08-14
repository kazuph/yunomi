import assert from "node:assert/strict";
import http, { type IncomingMessage } from "node:http";
import { spawn, type ChildProcess } from "node:child_process";
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { chromium } from "playwright";

const SERVER_JS = process.env.YUNOMI_SERVER_JS || new URL("../_build/js/release/build/server/server.js", import.meta.url).pathname;
const TMP_DIR = join(tmpdir(), `yunomi-approve-unanchored-${Date.now()}`);
const LOCK_DIR = join(TMP_DIR, "locks");
const REVIEW_DIR = join(TMP_DIR, ".yunomi", "reviews", "unanchored");
const REPORT = join(TMP_DIR, "UNANCHORED.md");

mkdirSync(LOCK_DIR, { recursive: true });
mkdirSync(REVIEW_DIR, { recursive: true });
writeFileSync(REPORT, "# Unanchored Review\n");
writeFileSync(
  join(REVIEW_DIR, "review.json"),
  JSON.stringify(
    {
      version: 1,
      branch: "unanchored",
      files: [REPORT],
      rounds: [
        { round: 1, started_at: "2026-07-07T00:00:00.000Z", submitted_at: "2026-07-07T00:01:00.000Z", decision: "request_changes", summary: "old" },
        { round: 2, started_at: "2026-07-07T00:02:00.000Z", submitted_at: null, decision: null, summary: "" },
      ],
      comments: [
        {
          id: "unanchored-1",
          file: "UNANCHORED.md",
          line: 999,
          row: 998,
          round: 1,
          text: "stale detached thread must not block approve",
          author: "human",
          status: "unresolved",
          unanchored: true,
          replies: [],
          anchor: { snippet: "Detached target", context_before: "", context_after: "" },
        },
      ],
    },
    null,
    2,
  ),
);

function request(port: number, method: string, path: string, body = ""): Promise<{ status: number; body: string }> {
  return new Promise((resolve, reject) => {
    const req = http.request(
      `http://127.0.0.1:${port}${path}`,
      { method, headers: { "Content-Type": "application/json" } },
      (res: IncomingMessage) => {
        let data = "";
        res.on("data", (chunk: string) => { data += chunk; });
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
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error(`server startup timeout\n${output}`)), 10000);
    proc.stdout?.on("data", (chunk: Buffer) => {
      output += String(chunk);
      const match = output.match(/http:\/\/127\.0\.0\.1:(\d+)/);
      if (match) {
        clearTimeout(timer);
        resolve(Number(match[1]));
      }
    });
    proc.stderr?.on("data", (chunk: Buffer) => { output += String(chunk); });
    proc.once("exit", (code) => reject(new Error(`server exited before ready code=${code}\n${output}`)));
  });
}

async function waitForHealth(port: number): Promise<void> {
  for (let attempt = 0; attempt < 80; attempt += 1) {
    try {
      if ((await request(port, "GET", "/healthz")).status === 200) return;
    } catch (_error) {
      // The server may still be binding its port.
    }
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  throw new Error(`healthz timeout on ${port}`);
}

function waitForExit(proc: ChildProcess): Promise<number | null | "timeout"> {
  if (proc.exitCode !== null || proc.signalCode !== null) return Promise.resolve(proc.exitCode);
  return new Promise((resolve) => {
    const timer = setTimeout(() => resolve("timeout"), 10000);
    proc.once("exit", (code) => {
      clearTimeout(timer);
      resolve(code);
    });
  });
}

async function main(): Promise<void> {
  const server = spawn(process.execPath, [SERVER_JS, "--no-open", "--loop", "--port", "0", REPORT], {
    cwd: TMP_DIR,
    env: {
      ...process.env,
      HERDR_PANE_ID: "",
      YUNOMI_NOTIFY_CMD: "",
      YUNOMI_LOCK_DIR: LOCK_DIR,
      YUNOMI_REVIEW_DIR: REVIEW_DIR,
    },
    stdio: ["ignore", "pipe", "pipe"],
  });

  try {
    const port = await waitForServerOutput(server);
    await waitForHealth(port);
    const state = await request(port, "GET", "/review-state");
    assert.equal(state.status, 200);
    assert.equal(JSON.parse(state.body).gate_unresolved_count, 0, "an unanchored prior thread is outside the approve gate");

    const browser = await chromium.launch({ headless: true });
    const pageErrors: string[] = [];
    try {
      const page = await browser.newPage({ viewport: { width: 576, height: 486 } });
      page.on("pageerror", (error) => pageErrors.push(error.message));
      await page.goto(`http://127.0.0.1:${port}/`, { waitUntil: "domcontentloaded" });
      await page.waitForSelector("#review-loop-panel", { timeout: 10000 });
      await page.locator("#send-and-exit").click();
      await page.waitForSelector("#submit-modal.visible", { timeout: 5000 });
      assert.equal(await page.locator("#modal-approve").isEnabled(), true, "an unanchored prior thread leaves Approve enabled in the submit modal");
      const exitResponse = page.waitForResponse((response) => response.url().endsWith("/exit"), { timeout: 10000 });
      await page.locator("#modal-approve").click();
      assert.equal((await exitResponse).status(), 200, "clicking Approve succeeds when only an unanchored prior thread remains");
    } finally {
      await browser.close().catch(() => {});
    }
    assert.deepEqual(pageErrors, [], "Approve flow produces no browser errors");
    assert.equal(await waitForExit(server), 0, "Approve exits the loop server");
    const persisted = JSON.parse(readFileSync(join(REVIEW_DIR, "review.json"), "utf8"));
    const retained = persisted.comments.find((comment: { id: string }) => comment.id === "unanchored-1");
    assert.deepEqual(
      retained,
      {
        id: "unanchored-1",
        file: "UNANCHORED.md",
        line: 999,
        row: 998,
        round: 1,
        text: "stale detached thread must not block approve",
        author: "human",
        status: "unresolved",
        unanchored: true,
        replies: [],
        anchor: { snippet: "Detached target", context_before: "", context_after: "" },
      },
      "Approve preserves the unanchored unresolved thread as review history",
    );
  } finally {
    if (server.exitCode === null && server.signalCode === null) server.kill("SIGTERM");
  }
  console.log("PASS: approve unanchored regression");
}

await main();
