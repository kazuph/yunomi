import http, { type IncomingMessage } from "node:http";
import { spawn, spawnSync, type ChildProcess } from "node:child_process";
import { mkdirSync, mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const SERVER_JS = new URL(
  "../_build/js/release/build/server/server.js",
  import.meta.url,
).pathname;

const TMP_DIR = mkdtempSync(join(tmpdir(), "yunomi-agent-interop-"));
const LOCK_DIR = join(TMP_DIR, "locks");
mkdirSync(LOCK_DIR, { recursive: true });

const FILE_A = join(TMP_DIR, "served-a.md");
const FILE_B = join(TMP_DIR, "served-b.md");
writeFileSync(FILE_A, "# A\n\nfirst\n\nsecond\n");
writeFileSync(FILE_B, "# B\n\nfirst\n\nsecond\n");

function waitForServer(proc: ChildProcess): Promise<number> {
  let out = "";
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error("server start timeout")), 10000);
    proc.stdout?.on("data", (d: Buffer) => {
      out += d.toString();
      const match = out.match(/at http:\/\/127\.0\.0\.1:(\d+)/);
      if (match) {
        clearTimeout(timer);
        resolve(Number(match[1]));
      }
    });
    proc.stderr?.on("data", (d: Buffer) => {
      out += d.toString();
    });
    proc.on("exit", (code) => {
      clearTimeout(timer);
      reject(new Error(`server exited before ready: ${code}\n${out}`));
    });
  });
}

function startServer(file: string, port: number): ChildProcess {
  return spawn("node", [SERVER_JS, file, "--port", String(port), "--no-open"], {
    stdio: ["ignore", "pipe", "pipe"],
    env: { ...process.env, YUNOMI_LOCK_DIR: LOCK_DIR },
  });
}

type SseProbe = {
  ready: Promise<void>;
  waitFor: (needle: string, timeoutMs: number) => Promise<string>;
};

function openSse(port: number): SseProbe {
  let body = "";
  let readyResolve!: () => void;
  let readyReject!: (err: Error) => void;
  const ready = new Promise<void>((resolve, reject) => {
    readyResolve = resolve;
    readyReject = reject;
  });
  const waiters: Array<{
    needle: string;
    resolve: (body: string) => void;
  }> = [];
  const req = http.get(`http://127.0.0.1:${port}/sse`, (res: IncomingMessage) => {
    res.on("data", (chunk: Buffer) => {
      body += chunk.toString();
      if (body.includes("event: hello")) readyResolve();
      for (const waiter of waiters) {
        if (body.includes(waiter.needle)) waiter.resolve(body);
      }
    });
  });
  req.on("error", (err: Error & { code?: string }) => {
    if (err.code === "ECONNRESET") return;
    readyReject(err);
  });
  return {
    ready,
    waitFor: (needle: string, timeoutMs: number) =>
      new Promise((resolve) => {
        if (body.includes(needle)) {
          resolve(body);
          return;
        }
        const timer = setTimeout(() => {
          req.destroy();
          resolve(body);
        }, timeoutMs);
        waiters.push({
          needle,
          resolve: (value) => {
            clearTimeout(timer);
            req.destroy();
            resolve(value);
          },
        });
      }),
  };
}

function collectNoSse(port: number, needle: string, timeoutMs: number): Promise<string> {
  return new Promise((resolve, reject) => {
    const req = http.get(`http://127.0.0.1:${port}/sse`, (res: IncomingMessage) => {
      let body = "";
      const timer = setTimeout(() => {
        req.destroy();
        resolve(body);
      }, timeoutMs);
      res.on("data", (chunk: Buffer) => {
        body += chunk.toString();
        if (body.includes(needle)) {
          clearTimeout(timer);
          req.destroy();
          resolve(body);
        }
      });
    });
    req.on("error", (err: Error & { code?: string }) => {
      if (err.code === "ECONNRESET") return;
      reject(err);
    });
  });
}

async function main(): Promise<void> {
  const serverA = startServer(FILE_A, 5521);
  const serverB = startServer(FILE_B, 5522);
  const processes = [serverA, serverB];
  try {
    const [portA, portB] = await Promise.all([
      waitForServer(serverA),
      waitForServer(serverB),
    ]);
    writeFileSync(join(LOCK_DIR, "5518.lock"), "123");
    writeFileSync(
      join(LOCK_DIR, "5519.lock"),
      JSON.stringify({ pid: 999999, port: 5519, file: FILE_A }),
    );
    writeFileSync(
      join(LOCK_DIR, "5520.lock"),
      JSON.stringify({ pid: process.pid, port: 5520, file: FILE_B }),
    );
    const text = "agent interop server route";
    const sseA = openSse(portA);
    await sseA.ready;
    const sseB = collectNoSse(portB, text, 1200);
    const result = spawnSync(
      "node",
      [SERVER_JS, "comment", `${FILE_A}:3`, text, "--author", "agent"],
      {
        encoding: "utf8",
        cwd: TMP_DIR,
        env: { ...process.env, YUNOMI_LOCK_DIR: LOCK_DIR },
      },
    );
    if (result.status !== 0) {
      throw new Error(`comment command failed\n${result.stdout}\n${result.stderr}`);
    }
    if (result.stdout.includes("Added comment to")) {
      throw new Error(`comment command fell back to offline review.json\n${result.stdout}\n${result.stderr}`);
    }
    if (result.stderr.includes("falling back to offline review.json")) {
      throw new Error(`comment command printed fallback stderr despite server success\n${result.stderr}`);
    }
    const [eventA, eventB] = await Promise.all([sseA.waitFor(text, 3000), sseB]);
    if (!eventA.includes("event: comment") || !eventA.includes(text)) {
      throw new Error(`matching server did not receive CLI comment\n${eventA}`);
    }
    if (eventB.includes(text)) {
      throw new Error(`non-matching server received CLI comment\n${eventB}`);
    }
    const offlineFile = join(TMP_DIR, "offline.md");
    const offlineLockDir = join(TMP_DIR, "empty-locks");
    mkdirSync(offlineLockDir, { recursive: true });
    writeFileSync(offlineFile, "# Offline\n");
    const offline = spawnSync(
      "node",
      [SERVER_JS, "comment", `${offlineFile}:1`, "offline route", "--author", "agent"],
      {
        encoding: "utf8",
        cwd: TMP_DIR,
        env: { ...process.env, YUNOMI_LOCK_DIR: offlineLockDir },
      },
    );
    if (offline.status !== 0) {
      throw new Error(`offline comment command failed\n${offline.stdout}\n${offline.stderr}`);
    }
    if (!offline.stderr.includes("falling back to offline review.json")) {
      throw new Error(`offline fallback reason was not printed to stderr\n${offline.stdout}\n${offline.stderr}`);
    }
    if (!offline.stdout.includes("Added comment to")) {
      throw new Error(`offline fallback did not write review.json\n${offline.stdout}\n${offline.stderr}`);
    }
    console.log("PASS: yunomi comment posts to the running server for the same file");
  } finally {
    for (const proc of processes) {
      try {
        proc.kill("SIGINT");
      } catch {
        // already gone
      }
    }
  }
}

await main();
