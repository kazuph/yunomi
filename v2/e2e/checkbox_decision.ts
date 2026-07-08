import http, { type IncomingMessage } from "node:http";
import { spawn, type ChildProcess } from "node:child_process";
import { existsSync, mkdirSync, mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const SERVER_JS = new URL(
  "../_build/js/release/build/server/server.js",
  import.meta.url,
).pathname;

const TMP_DIR = mkdtempSync(join(tmpdir(), "yunomi-checkbox-decision-"));
const LOCK_DIR = join(TMP_DIR, "locks");
mkdirSync(LOCK_DIR, { recursive: true });

const REPORT = join(TMP_DIR, "REPORT.md");
const NOTIFY_LOG = join(TMP_DIR, "notify.log");
const NOTIFY_HELPER = join(TMP_DIR, "notify.js");
writeFileSync(
  REPORT,
  [
    "# Checkbox decisions",
    "- [ ] 認証はOAuthにする",
    "- ✅️ デプロイは親が実行する",
    "",
  ].join("\n"),
);
writeFileSync(
  NOTIFY_HELPER,
  "const fs = require('node:fs'); fs.appendFileSync(process.argv[2], process.argv.slice(3).join(' ') + '\\n');\n",
);

function waitForServer(proc: ChildProcess): Promise<number> {
  let out = "";
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error(`server start timeout\n${out}`)), 10000);
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

function get(port: number, path: string): Promise<string> {
  return new Promise((resolve, reject) => {
    http.get(`http://127.0.0.1:${port}${path}`, (res: IncomingMessage) => {
      let body = "";
      res.on("data", (chunk: Buffer) => {
        body += chunk.toString();
      });
      res.on("end", () => resolve(body));
    }).on("error", reject);
  });
}

function post(port: number, path: string, body: string): Promise<number> {
  return new Promise((resolve, reject) => {
    const req = http.request(
      `http://127.0.0.1:${port}${path}`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Content-Length": Buffer.byteLength(body),
        },
      },
      (res) => {
        res.resume();
        res.on("end", () => resolve(res.statusCode || 0));
      },
    );
    req.on("error", reject);
    req.end(body);
  });
}

function openSse(port: number): Promise<{ body: () => string; close: () => void }> {
  let body = "";
  return new Promise((resolve, reject) => {
    const req = http.get(`http://127.0.0.1:${port}/sse`, (res: IncomingMessage) => {
      res.on("data", (chunk: Buffer) => {
        body += chunk.toString();
        if (body.includes("event: hello")) {
          resolve({ body: () => body, close: () => req.destroy() });
        }
      });
    });
    req.on("error", (err: Error & { code?: string }) => {
      if (err.code === "ECONNRESET") return;
      reject(err);
    });
  });
}

async function waitFor(predicate: () => boolean, label: string): Promise<void> {
  const deadline = Date.now() + 5000;
  while (Date.now() < deadline) {
    if (predicate()) return;
    await new Promise((resolve) => setTimeout(resolve, 50));
  }
  throw new Error(`timeout waiting for ${label}`);
}

async function main(): Promise<void> {
  const proc = spawn("node", [SERVER_JS, REPORT, "--port", "5437", "--no-open"], {
    stdio: ["ignore", "pipe", "pipe"],
    cwd: TMP_DIR,
    env: {
      ...process.env,
      YUNOMI_LOCK_DIR: LOCK_DIR,
      YUNOMI_NOTIFY_CMD: `node ${NOTIFY_HELPER} ${NOTIFY_LOG} {msg}`,
    },
  });
  try {
    const port = await waitForServer(proc);
    const html = await get(port, "/");
    if (!html.includes('class="task-decision-checkbox" type="checkbox" data-source-line="2"')) {
      throw new Error("task list checkbox was not rendered as an interactive checkbox");
    }
    if (html.includes("task-decision-checkbox\" type=\"checkbox\" disabled")) {
      throw new Error("task list checkbox is still disabled");
    }
    if (!html.includes('class="decision-done" data-source-line="3"')) {
      throw new Error("- ✅️ decision line did not render with decision-done class");
    }
    const ui = await get(port, "/ui.js");
    if (!ui.includes("/decision")) {
      throw new Error("served UI script does not post checkbox decisions");
    }

    const sse = await openSse(port);
    const status = await post(
      port,
      "/decision",
      JSON.stringify({ file: "REPORT.md", line: 2, text: "認証はOAuthにする", checked: true }),
    );
    if (status !== 200) {
      throw new Error(`POST /decision returned ${status}`);
    }
    await waitFor(() => readFileSync(REPORT, "utf8").includes("- [x] 認証はOAuthにする"), "markdown rewrite");
    await waitFor(() => sse.body().includes("event: decision") && sse.body().includes('"checked":true'), "decision SSE");
    await waitFor(() => existsSync(NOTIFY_LOG) && readFileSync(NOTIFY_LOG, "utf8").includes("[yunomi] decision REPORT.md:2 checked=true"), "notify command");
    sse.close();

    const reviewPath = join(TMP_DIR, ".yunomi", "reviews", "detached", "review.json");
    await waitFor(() => existsSync(reviewPath), "review.json");
    const review = readFileSync(reviewPath, "utf8");
    if (!review.includes('"decisions"') || !review.includes('"checked": true')) {
      throw new Error(`review.json does not contain the checked decision\n${review}`);
    }
    console.log("PASS: checkbox decisions update markdown, notify AI, and persist review decisions");
  } finally {
    try {
      proc.kill("SIGINT");
    } catch {
      // already gone
    }
  }
}

await main();
