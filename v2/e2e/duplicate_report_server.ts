import assert from "node:assert/strict";
import { spawn, spawnSync, type ChildProcess } from "node:child_process";
import { mkdirSync, mkdtempSync, readFileSync, readdirSync, realpathSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const SERVER_JS = new URL("../_build/js/release/build/server/server.js", import.meta.url).pathname;
const WORK_DIR = mkdtempSync(join(tmpdir(), "yunomi-duplicate-report-"));
const LOCK_DIR = join(WORK_DIR, "locks");
const REVIEW_DIR = join(WORK_DIR, "reviews");
const REPORT = join(WORK_DIR, "REPORT.md");
const OTHER_REPORT = join(WORK_DIR, "OTHER.md");
const RACE_REPORT = join(WORK_DIR, "RACE.md");
const HTML_REPORT = join(WORK_DIR, "report.html");
const SHARE_REPORT = join(WORK_DIR, "SHARE.md");
const SIGNAL_REPORT = join(WORK_DIR, "SIGNAL.md");
const MIXED_REPORT = join(WORK_DIR, "MIXED.md");
const children: ChildProcess[] = [];

type RunningServer = {
  proc: ChildProcess;
  port: number;
  output: () => string;
};

const env = {
  ...process.env,
  HERDR_PANE_ID: "",
  YUNOMI_NOTIFY_CMD: "",
  YUNOMI_LOCK_DIR: LOCK_DIR,
  YUNOMI_REVIEW_DIR: REVIEW_DIR,
};

function start(file: string | string[], cwd = WORK_DIR): Promise<RunningServer> {
  return new Promise((resolve, reject) => {
    const files = Array.isArray(file) ? file : [file];
    const proc = spawn(process.execPath, [SERVER_JS, ...files, "--no-open", "--port", "0"], {
      cwd,
      env,
      stdio: ["ignore", "pipe", "pipe"],
    });
    children.push(proc);
    let output = "";
    const onData = (chunk: Buffer) => {
      output += chunk.toString();
      const match = output.match(/yunomi (?:serving|html previewing|sharing) .* at http:\/\/127\.0\.0\.1:(\d+)/);
      if (match) resolve({ proc, port: Number(match[1]), output: () => output });
    };
    proc.stdout?.on("data", onData);
    proc.stderr?.on("data", onData);
    proc.once("error", reject);
    proc.once("exit", (code) => reject(new Error(`server exited before listening (${code})\n${output}`)));
  });
}

function runCommand(args: string[], cwd = WORK_DIR): Promise<{ code: number | null; output: string }> {
  return new Promise((resolve, reject) => {
    const proc = spawn(process.execPath, [SERVER_JS, ...args, "--no-open", "--port", "0"], {
      cwd,
      env,
      stdio: ["ignore", "pipe", "pipe"],
    });
    let output = "";
    proc.stdout?.on("data", (chunk: Buffer) => { output += chunk.toString(); });
    proc.stderr?.on("data", (chunk: Buffer) => { output += chunk.toString(); });
    proc.once("error", reject);
    proc.once("exit", (code) => resolve({ code, output }));
  });
}

function runDuplicate(file: string): Promise<{ code: number | null; output: string }> {
  return runCommand([file]);
}

async function healthy(port: number): Promise<boolean> {
  const response = await fetch(`http://127.0.0.1:${port}/healthz`);
  return response.status === 200;
}

function waitForExit(proc: ChildProcess): Promise<void> {
  if (proc.exitCode !== null) return Promise.resolve();
  return new Promise((resolve) => proc.once("exit", () => resolve()));
}

function locksFor(file: string): string[] {
  const target = realpathSync(file);
  return readdirSync(LOCK_DIR)
    .filter((entry) => entry.endsWith(".lock"))
    .filter((entry) => {
      try {
        return JSON.parse(readFileSync(join(LOCK_DIR, entry), "utf-8")).file === target;
      } catch {
        return false;
      }
    });
}

async function main(): Promise<void> {
  writeFileSync(REPORT, "# Same report\n");
  writeFileSync(OTHER_REPORT, "# Other report\n");
  writeFileSync(RACE_REPORT, "# Concurrent report\n");
  writeFileSync(HTML_REPORT, "<!doctype html><title>Same HTML report</title>");
  writeFileSync(SHARE_REPORT, "# Shared report\n");
  writeFileSync(SIGNAL_REPORT, "# Signal cleanup\n");
  writeFileSync(MIXED_REPORT, "# New file beside an existing report\n");

  const first = await start(REPORT);
  assert.equal(await healthy(first.port), true, "the first report server is healthy");
  const locksBeforeDuplicate = readdirSync(LOCK_DIR).filter((entry) => entry.endsWith(".lock"));

  const duplicate = await runDuplicate(REPORT);
  assert.equal(duplicate.code, 2, "a second launch for the same report is rejected distinctly from review completion");
  assert.match(duplicate.output, new RegExp(`already serves REPORT\\.md at http://127\\.0\\.0\\.1:${first.port}`));
  assert.deepEqual(
    readdirSync(LOCK_DIR).filter((entry) => entry.endsWith(".lock")),
    locksBeforeDuplicate,
    "the duplicate launch does not create another port lock",
  );
  assert.equal(await healthy(first.port), true, "rejecting the duplicate leaves the original review server alive");
  const mixed = await runCommand([REPORT, MIXED_REPORT]);
  assert.equal(mixed.code, 2, "mixing an existing report with a new file rejects the whole command");
  assert.deepEqual(locksFor(MIXED_REPORT), [], "whole-command rejection releases the new file claim");

  const other = await start(OTHER_REPORT);
  assert.notEqual(other.port, first.port, "a different report can still start its own server");
  assert.equal(await healthy(other.port), true, "the different report server is healthy");

  const repeatedArgument = await runCommand([RACE_REPORT, RACE_REPORT]);
  assert.equal(repeatedArgument.code, 2, "repeating one path rejects the whole command instead of partially serving it");
  assert.match(repeatedArgument.output, /already serves RACE\.md \(server startup in progress\)/);
  assert.deepEqual(locksFor(RACE_REPORT), [], "rejecting repeated arguments releases the lock claimed by that command");

  const concurrentFile = join(WORK_DIR, "CONCURRENT.md");
  writeFileSync(concurrentFile, "# Concurrent processes\n");
  const concurrent = await Promise.allSettled([start(concurrentFile), start(concurrentFile)]);
  const concurrentServers = concurrent
    .filter((result): result is PromiseFulfilledResult<RunningServer> => result.status === "fulfilled")
    .map((result) => result.value);
  const concurrentRejected = concurrent
    .filter((result): result is PromiseRejectedResult => result.status === "rejected")
    .map((result) => String(result.reason));
  assert.equal(
    concurrentServers.length,
    1,
    `simultaneous processes acquire only one file server lock: ${JSON.stringify(concurrentServers.map((server) => server.output()))}`,
  );
  assert.equal(concurrentRejected.length, 1, "the simultaneous duplicate process exits instead of binding another port");
  assert.match(concurrentRejected[0], /same file already served/);

  const html = await start(HTML_REPORT);
  assert.equal(await healthy(html.port), true, "the first HTML report server is healthy");
  const duplicateHtml = await runDuplicate(HTML_REPORT);
  assert.equal(duplicateHtml.code, 2, "a second launch for the same HTML report is rejected");
  assert.match(duplicateHtml.output, new RegExp(`already serves report\\.html at http://127\\.0\\.0\\.1:${html.port}`));

  const share = await start(["share", SHARE_REPORT]);
  assert.equal(await healthy(share.port), true, "the share server is healthy");
  const duplicateShare = await runDuplicate(SHARE_REPORT);
  assert.equal(duplicateShare.code, 2, "a normal launch cannot duplicate a file already served by share");
  assert.match(duplicateShare.output, new RegExp(`already serves SHARE\\.md at http://127\\.0\\.0\\.1:${share.port}`));

  const signaled = await start(SIGNAL_REPORT);
  assert.ok(
    locksFor(SIGNAL_REPORT).length >= 2,
    `a running server owns its port and file locks: ${JSON.stringify(readdirSync(LOCK_DIR).map((entry) => [entry, readFileSync(join(LOCK_DIR, entry), "utf-8")]))}`,
  );
  signaled.proc.kill("SIGTERM");
  await waitForExit(signaled.proc);
  assert.deepEqual(locksFor(SIGNAL_REPORT), [], "SIGTERM removes every lock owned for the report");

  const reviewRepo = join(WORK_DIR, "review-repo");
  const reviewFile = join(reviewRepo, "review.md");
  mkdirSync(reviewRepo);
  writeFileSync(reviewFile, "# Initial\n");
  assert.equal(spawnSync("git", ["init", "-q"], { cwd: reviewRepo }).status, 0);
  assert.equal(spawnSync("git", ["add", "review.md"], { cwd: reviewRepo }).status, 0);
  assert.equal(
    spawnSync("git", ["-c", "user.name=Yunomi E2E", "-c", "user.email=yunomi@example.invalid", "commit", "-qm", "initial"], { cwd: reviewRepo }).status,
    0,
  );
  writeFileSync(reviewFile, "# Changed\n");
  const review = await start(["review"], reviewRepo);
  assert.equal(await healthy(review.port), true, "the review mux server is healthy");
  const duplicateReview = await runCommand(["review"], reviewRepo);
  assert.equal(duplicateReview.code, 2, "a second review mux launch for the same changed file is rejected");
  assert.match(duplicateReview.output, new RegExp(`already serves review\\.md at http://127\\.0\\.0\\.1:${review.port}`));

  console.log("PASS: the same report cannot start on another port");
}

main()
  .catch((error) => {
    console.error(error instanceof Error ? error.stack || error.message : String(error));
    process.exitCode = 1;
  })
  .finally(() => {
    for (const child of children) {
      if (child.exitCode === null) child.kill("SIGTERM");
    }
    rmSync(WORK_DIR, { recursive: true, force: true });
  });
