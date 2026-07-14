import { spawn, type ChildProcess } from "node:child_process";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import net from "node:net";

const SERVER_JS = new URL("../_build/js/release/build/server/server.js", import.meta.url).pathname;
const WORK_DIR = mkdtempSync(join(tmpdir(), "yunomi-port-fallback-"));
const TEST_MD = join(WORK_DIR, "port.md");
const PORT_SCAN_START = 5900;
const PORT_SCAN_END = 5990;

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

function canBind(port: number): Promise<boolean> {
  return new Promise((resolve) => {
    const server = net.createServer();
    server.once("error", () => resolve(false));
    server.once("listening", () => {
      server.close(() => resolve(true));
    });
    server.listen(port, "127.0.0.1");
  });
}

async function findConsecutivePorts(): Promise<number> {
  for (let port = PORT_SCAN_START; port < PORT_SCAN_END; port++) {
    if ((await canBind(port)) && (await canBind(port + 1))) return port;
  }
  throw new Error(`No consecutive free ports in ${PORT_SCAN_START}-${PORT_SCAN_END}`);
}

function startServer(port: number, label: string): Promise<{ proc: ChildProcess; output: () => string; port: number }> {
  return new Promise((resolve, reject) => {
    const lockDir = join(WORK_DIR, `locks-${label}`);
    const reviewDir = join(WORK_DIR, `reviews-${label}`);
    const proc = spawn(process.execPath, [SERVER_JS, TEST_MD, "--no-open", "--port", String(port)], {
      cwd: WORK_DIR,
      stdio: ["ignore", "pipe", "pipe"],
      env: {
        ...process.env,
        HERDR_PANE_ID: "",
        YUNOMI_NOTIFY_CMD: "",
        YUNOMI_LOCK_DIR: lockDir,
        YUNOMI_REVIEW_DIR: reviewDir,
      },
    });
    let output = "";
    let settled = false;
    const startupTimer = setTimeout(() => {
      if (!settled) reject(new Error(`${label} server did not start\n${output}`));
    }, 15000);
    const check = () => {
      const match = output.match(/http:\/\/127\.0\.0\.1:(\d+)/);
      if (!settled && match) {
        settled = true;
        clearTimeout(startupTimer);
        resolve({ proc, output: () => output, port: Number(match[1]) });
      }
    };
    proc.stdout?.on("data", (chunk: Buffer) => {
      output += chunk.toString("utf8");
      check();
    });
    proc.stderr?.on("data", (chunk: Buffer) => {
      output += chunk.toString("utf8");
      check();
    });
    proc.on("exit", (code) => {
      if (!settled) reject(new Error(`${label} server exited early ${code}\n${output}`));
    });
  });
}

async function stop(proc: ChildProcess): Promise<void> {
  await new Promise<void>((resolve) => {
    const forceTimer = setTimeout(() => {
      proc.kill("SIGKILL");
      resolve();
    }, 3000);
    proc.once("exit", () => {
      clearTimeout(forceTimer);
      resolve();
    });
    proc.kill("SIGINT");
  });
}

async function get(port: number, path: string): Promise<{ status: number; text: string }> {
  const res = await fetch(`http://127.0.0.1:${port}${path}`);
  return { status: res.status, text: await res.text() };
}

writeFileSync(TEST_MD, "# Port fallback\n\nThe second server should move to the next port.\n");

try {
  const basePort = await findConsecutivePorts();
  const first = await startServer(basePort, "first");
  try {
    const second = await startServer(basePort, "second");
    try {
      assert(first.port === basePort, "first server binds the requested port", { basePort, firstPort: first.port });
      assert(second.port === basePort + 1, "second server auto-falls back to the next port after EADDRINUSE", {
        basePort,
        secondPort: second.port,
        output: second.output(),
      });
      assert(second.output().includes(`Port ${basePort} in use, trying ${basePort + 1}`), "fallback path logs EADDRINUSE port retry", second.output());

      const firstHealth = await get(first.port, "/healthz");
      const secondHealth = await get(second.port, "/healthz");
      assert(firstHealth.status === 200 && firstHealth.text.includes("ok"), "first server stays healthy after second server starts", firstHealth);
      assert(secondHealth.status === 200 && secondHealth.text.includes("ok"), "fallback server responds on the next port", secondHealth);
    } finally {
      await stop(second.proc);
    }
  } finally {
    await stop(first.proc);
  }
} catch (error) {
  failed++;
  console.error(error instanceof Error ? error.stack || error.message : String(error));
} finally {
  rmSync(WORK_DIR, { recursive: true, force: true });
}

console.log(`Port auto fallback E2E: ${passed} passed, ${failed} failed`);
if (failed > 0) process.exit(1);
