/**
 * Regression: ATX `#` without a following space must not hang server startup,
 * and stale file locks (dead pid / port 0 past grace) must be reclaimed.
 *
 * Run: node --experimental-strip-types e2e/md_hash_nospace_hang.ts
 */
import assert from "node:assert/strict";
import { spawn, type ChildProcess } from "node:child_process";
import {
  createHash,
  randomUUID,
} from "node:crypto";
import {
  mkdirSync,
  mkdtempSync,
  readFileSync,
  realpathSync,
  readdirSync,
  rmSync,
  utimesSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import {
  basename,
  join,
} from "node:path";

const SERVER_JS = new URL("../_build/js/release/build/server/server.js", import.meta.url).pathname;
const WORK_DIR = mkdtempSync(join(tmpdir(), "yunomi-md-hash-hang-"));
const LOCK_DIR = join(WORK_DIR, "locks");
const REVIEW_DIR = join(WORK_DIR, "reviews");
const children: ChildProcess[] = [];

mkdirSync(LOCK_DIR, { recursive: true });
mkdirSync(REVIEW_DIR, { recursive: true });

const env = {
  ...process.env,
  HERDR_PANE_ID: "",
  YUNOMI_NOTIFY_CMD: "",
  YUNOMI_LOCK_DIR: LOCK_DIR,
  YUNOMI_REVIEW_DIR: REVIEW_DIR,
};

type RunningServer = {
  proc: ChildProcess;
  port: number;
  output: () => string;
};

function hangGuard<T>(promise: Promise<T>, label: string, timeoutMs = 15000): Promise<T> {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      reject(new Error(`HANG DETECTED: ${label} did not finish within ${timeoutMs}ms`));
    }, timeoutMs);
    promise.then(
      (value) => {
        clearTimeout(timer);
        resolve(value);
      },
      (error) => {
        clearTimeout(timer);
        reject(error);
      },
    );
  });
}

function start(file: string, port = 0): Promise<RunningServer> {
  return new Promise((resolve, reject) => {
    const proc = spawn(
      process.execPath,
      [SERVER_JS, file, "--no-open", "--port", String(port)],
      { cwd: WORK_DIR, env, stdio: ["ignore", "pipe", "pipe"] },
    );
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

async function healthy(port: number): Promise<boolean> {
  const response = await fetch(`http://127.0.0.1:${port}/healthz`);
  return response.status === 200;
}

function waitForExit(proc: ChildProcess): Promise<void> {
  if (proc.exitCode !== null) return Promise.resolve();
  return new Promise((resolve) => proc.once("exit", () => resolve()));
}

function fileLockPath(file: string): string {
  const resolved = realpathSync(file);
  const hash = createHash("sha256").update(resolved).digest("hex").slice(0, 32);
  return join(LOCK_DIR, `file-${hash}.lock`);
}

function writeFileLock(file: string, body: { pid: number; port: number }): string {
  const resolved = realpathSync(file);
  const lockPath = fileLockPath(file);
  writeFileSync(lockPath, JSON.stringify({ pid: body.pid, port: body.port, file: resolved }), {
    mode: 0o600,
  });
  return lockPath;
}

async function main(): Promise<void> {
  const cases: Array<{ name: string; body: string; expectHeading: boolean }> = [
    { name: "hash1-bug", body: "#1 bug\n", expectHeading: false },
    { name: "blockquote-hash1", body: "> #1【不具合】\n", expectHeading: false },
    { name: "hash-abc", body: "#abc\n", expectHeading: false },
    { name: "hash-alone", body: "#\n", expectHeading: true },
    { name: "hash2-digit", body: "##2\n", expectHeading: false },
    { name: "normal-heading", body: "# 見出し\n", expectHeading: true },
    { name: "seven-hashes", body: "####### x\n", expectHeading: false },
  ];

  for (const fixture of cases) {
    const md = join(WORK_DIR, `${fixture.name}.md`);
    writeFileSync(md, fixture.body);
    const server = await hangGuard(start(md), `start ${fixture.name}`);
    assert.equal(await healthy(server.port), true, `${fixture.name} healthz`);
    const page = await fetch(`http://127.0.0.1:${server.port}/`);
    assert.equal(page.status, 200, `${fixture.name} page status`);
    const html = await page.text();
    const previewIdx = html.indexOf('id="md-preview"');
    assert.ok(previewIdx >= 0, `${fixture.name} has md-preview`);
    const preview = html.slice(previewIdx, previewIdx + 4000);
    if (fixture.expectHeading) {
      assert.match(preview, /<h[1-6]\s+class="md-heading-toggle"/, `${fixture.name} should render heading in preview`);
    } else {
      assert.doesNotMatch(
        preview,
        /<h[1-6]\s+class="md-heading-toggle"/,
        `${fixture.name} should not render ATX heading in preview`,
      );
      const snippet = fixture.body.replace(/^>\s*/, "").trim();
      assert.ok(preview.includes(snippet) || preview.includes(snippet.replace("#", "")), `${fixture.name} keeps source text`);
    }
    server.proc.kill("SIGTERM");
    await waitForExit(server.proc);
  }

  // Dead-pid + port 0 residual lock must be reclaimed (isolated LOCK_DIR).
  const reclaimMd = join(WORK_DIR, "reclaim-dead.md");
  writeFileSync(reclaimMd, "# reclaim me\n");
  const deadLock = writeFileLock(reclaimMd, { pid: 999999999, port: 0 });
  assert.ok(readdirSync(LOCK_DIR).includes(basename(deadLock)), "planted dead lock");
  const afterDead = await hangGuard(start(reclaimMd), "start after dead lock");
  assert.equal(await healthy(afterDead.port), true, "reclaimed dead lock and listened");
  afterDead.proc.kill("SIGTERM");
  await waitForExit(afterDead.proc);

  // Other process stuck at port 0 past grace (mtime aged) must be reclaimed.
  const hungMd = join(WORK_DIR, "reclaim-hung.md");
  writeFileSync(hungMd, "# hung reclaim\n");
  const sleeper = spawn("sleep", ["30"], { stdio: "ignore" });
  children.push(sleeper);
  const hungLock = writeFileLock(hungMd, { pid: sleeper.pid!, port: 0 });
  const aged = Date.now() / 1000 - 10;
  utimesSync(hungLock, aged, aged);
  const afterHung = await hangGuard(start(hungMd), "start after aged port-0 lock");
  assert.equal(await healthy(afterHung.port), true, "reclaimed aged port-0 lock and listened");
  afterHung.proc.kill("SIGTERM");
  await waitForExit(afterHung.proc);
  sleeper.kill("SIGTERM");
  await waitForExit(sleeper);

  // Live lock with a real port must still block duplicates.
  const legitMd = join(WORK_DIR, "legit.md");
  writeFileSync(legitMd, "# legit\n");
  const first = await hangGuard(start(legitMd), "legit first");
  assert.equal(await healthy(first.port), true, "legit server healthy");
  const dup = await new Promise<{ code: number | null; output: string }>((resolve, reject) => {
    const proc = spawn(process.execPath, [SERVER_JS, legitMd, "--no-open", "--port", "0"], {
      cwd: WORK_DIR,
      env,
      stdio: ["ignore", "pipe", "pipe"],
    });
    let output = "";
    proc.stdout?.on("data", (chunk: Buffer) => {
      output += chunk.toString();
    });
    proc.stderr?.on("data", (chunk: Buffer) => {
      output += chunk.toString();
    });
    proc.once("error", reject);
    proc.once("exit", (code) => resolve({ code, output }));
  });
  assert.equal(dup.code, 2, "live port lock still rejects duplicate");
  assert.match(dup.output, /already serves/);
  first.proc.kill("SIGTERM");
  await waitForExit(first.proc);

  console.log("md_hash_nospace_hang: ok", { cases: cases.length, reclaim: true, uuid: randomUUID() });
}

main()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(() => {
    for (const child of children) {
      try {
        child.kill("SIGKILL");
      } catch {
        // ignore
      }
    }
    try {
      rmSync(WORK_DIR, { recursive: true, force: true });
    } catch {
      // ignore
    }
  });
