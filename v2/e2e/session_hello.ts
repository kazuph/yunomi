/**
 * Session Hello E2E Test
 *
 * The server announces a per-process instance id as the SSE "hello"
 * event. A lingering browser tab that reconnects after a server restart
 * sees a different id and should retire itself instead of joining the new
 * review session.
 *
 * Run: node --experimental-strip-types v2/e2e/session_hello.ts
 */
import { spawn, type ChildProcess } from "node:child_process";
import { writeFileSync, mkdtempSync, rmSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { fileURLToPath } from "node:url";

const __dirname = fileURLToPath(new URL(".", import.meta.url));
const SERVER_JS = join(__dirname, "..", "_build", "js", "release", "build", "server", "server.js");
const WORK_DIR = mkdtempSync(join(tmpdir(), "yunomi-hello-"));
const PORT = 5917;

let passed = 0;
let failed = 0;

function assert(condition: boolean, msg: string, detail?: unknown): void {
  if (condition) {
    passed++;
    console.log(`  PASS: ${msg}`);
  } else {
    failed++;
    console.error(`  FAIL: ${msg}`);
    if (detail !== undefined) console.error(JSON.stringify(detail, null, 2));
  }
}

function startServer(file: string): Promise<ChildProcess> {
  return new Promise((resolve, reject) => {
    const proc = spawn("node", [SERVER_JS, file, "--no-open", "--port", String(PORT)], {
      stdio: ["ignore", "pipe", "pipe"],
      env: { ...process.env, YUNOMI_LOCK_DIR: join(WORK_DIR, "locks"), YUNOMI_REVIEW_DIR: join(WORK_DIR, "reviews-" + Date.now()) },
    });
    let out = "";
    const onData = (d: Buffer) => {
      out += String(d);
      if (out.includes(`http://127.0.0.1:${PORT}`)) resolve(proc);
    };
    proc.stdout.on("data", onData);
    proc.stderr.on("data", onData);
    proc.on("exit", () => reject(new Error(`server exited early:\n${out}`)));
    setTimeout(() => reject(new Error(`server did not start:\n${out}`)), 10000);
  });
}

async function readHello(): Promise<string> {
  const res = await fetch(`http://127.0.0.1:${PORT}/sse`, {
    headers: { Accept: "text/event-stream" },
  });
  const reader = res.body!.getReader();
  const decoder = new TextDecoder();
  let buf = "";
  const deadline = Date.now() + 5000;
  while (Date.now() < deadline) {
    const { value, done } = await reader.read();
    if (done) break;
    buf += decoder.decode(value, { stream: true });
    const m = buf.match(/event: hello\ndata: (.+)\n/);
    if (m) {
      await reader.cancel();
      return m[1];
    }
  }
  await reader.cancel();
  throw new Error(`no hello event within 5s. got: ${JSON.stringify(buf)}`);
}

function stop(proc: ChildProcess): Promise<void> {
  return new Promise((resolve) => {
    proc.on("exit", () => resolve());
    proc.kill("SIGINT");
    setTimeout(() => { proc.kill("SIGKILL"); resolve(); }, 3000);
  });
}

try {
  const md = join(WORK_DIR, "doc.md");
  writeFileSync(md, "# hello test\n\nbody\n");

  const a = await startServer(md);
  const idA1 = await readHello();
  const idA2 = await readHello();
  assert(idA1.length > 0, "SSE接続直後に hello でinstance idが届く", idA1);
  assert(idA1 === idA2, "同一サーバへの再接続では同じidが届く（リロードしない）", { idA1, idA2 });
  await stop(a);

  const b = await startServer(md);
  const idB = await readHello();
  assert(idB.length > 0 && idB !== idA1, "同一ポートで再起動した新サーバは異なるidを配る（残骸タブを退避させられる）", { idA1, idB });
  await stop(b);
} finally {
  rmSync(WORK_DIR, { recursive: true, force: true });
}

console.log(`\nResults: ${passed} passed, ${failed} failed`);
if (failed > 0) process.exitCode = 1;
