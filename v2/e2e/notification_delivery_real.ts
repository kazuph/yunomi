/**
 * Real-runtime notification check.
 *
 * The caller must provide an actual Herdr or tmux pane that is already
 * recording its terminal input in YUNOMI_E2E_NOTIFY_LOG.
 */
import http from "node:http";
import { spawn, type ChildProcess } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const SERVER_JS = new URL(
  "../_build/js/release/build/server/server.js",
  import.meta.url,
).pathname;
const route = process.env.YUNOMI_E2E_ROUTE;
const target = process.env.YUNOMI_E2E_TARGET;
const notifyLog = process.env.YUNOMI_E2E_NOTIFY_LOG;

if ((route !== "herdr" && route !== "tmux") || !target || !notifyLog) {
  throw new Error(
    "YUNOMI_E2E_ROUTE=herdr|tmux, YUNOMI_E2E_TARGET, and YUNOMI_E2E_NOTIFY_LOG are required",
  );
}

const workDir = mkdtempSync(join(tmpdir(), "yunomi-notify-real-"));
const report = join(workDir, "REPORT.md");
writeFileSync(report, "# Notification delivery\n\nReal runtime check.\n");

function startServer(): Promise<{ proc: ChildProcess; port: number; output: () => string }> {
  const routeArgs = route === "herdr"
    ? ["--notify-pane", target]
    : ["--notify-tmux-pane", target];
  const proc = spawn(
    process.execPath,
    [SERVER_JS, report, "--loop", "--no-open", "--port", "0", ...routeArgs],
    {
      cwd: workDir,
      env: {
        ...process.env,
        HERDR_PANE_ID: "",
        TMUX_PANE: "",
        YUNOMI_NOTIFY_CMD: "",
        YUNOMI_LOCK_DIR: join(workDir, "locks"),
        YUNOMI_REVIEW_DIR: join(workDir, "reviews"),
      },
      stdio: ["ignore", "pipe", "pipe"],
    },
  );
  let output = "";
  return new Promise((resolve, reject) => {
    const timer = setTimeout(
      () => reject(new Error(`server start timeout\n${output}`)),
      10_000,
    );
    const onData = (chunk: Buffer) => {
      output += chunk.toString();
      const match = output.match(/http:\/\/127\.0\.0\.1:(\d+)/);
      if (match) {
        clearTimeout(timer);
        resolve({ proc, port: Number(match[1]), output: () => output });
      }
    };
    proc.stdout?.on("data", onData);
    proc.stderr?.on("data", onData);
    proc.once("exit", (code) => {
      clearTimeout(timer);
      reject(new Error(`server exited before ready: ${code}\n${output}`));
    });
  });
}

function post(port: number, path: string, body: object): Promise<void> {
  return new Promise((resolve, reject) => {
    const req = http.request(
      `http://127.0.0.1:${port}${path}`,
      { method: "POST", headers: { "Content-Type": "application/json" } },
      (res) => {
        res.resume();
        res.once("end", () => {
          if (res.statusCode === 200) resolve();
          else reject(new Error(`${path} returned ${res.statusCode}`));
        });
      },
    );
    req.once("error", reject);
    req.end(JSON.stringify(body));
  });
}

async function waitForNotifications(): Promise<string> {
  const expected = [
    "[yunomi] decision REPORT.md:1 checked=true",
    "[yunomi] comment REPORT.md:2 id=real-comment",
    "[yunomi] verdict REPORT.md decision=request_changes",
    "[yunomi] tab closed REPORT.md tab=real-tab active=0",
  ];
  const deadline = Date.now() + 10_000;
  while (Date.now() < deadline) {
    const content = readFileSync(notifyLog, "utf8");
    if (expected.every((line) => content.includes(line))) return content;
    await new Promise((resolve) => setTimeout(resolve, 50));
  }
  throw new Error(`notification timeout\n${readFileSync(notifyLog, "utf8")}`);
}

const server = await startServer();
try {
  await post(server.port, "/session/open", {
    tabId: "real-tab",
    instanceId: "real-instance",
  });
  await post(server.port, "/decision", {
    line: 1,
    text: "real runtime decision",
    checked: true,
  });
  await post(server.port, "/comment", {
    type: "comment",
    key: "real-comment",
    row: 1,
    col: 0,
    text: "real runtime comment",
    author: "human",
  });
  await post(server.port, "/exit", {
    summary: "real runtime submit",
    decision: "request_changes",
    action: "final_request_changes",
    comments: [],
  });
  await post(server.port, "/close", {
    tabId: "real-tab",
    instanceId: "real-instance",
    draft: "{}",
  });
  const notifications = await waitForNotifications();
  for (const prefix of ["decision", "comment", "verdict", "tab closed"]) {
    const count = notifications.split(`[yunomi] ${prefix}`).length - 1;
    if (count !== 1) throw new Error(`${prefix} delivered ${count} times`);
  }
  console.log(
    `PASS: ${route} delivered decision, comment, submit verdict, and close exactly once`,
  );
} finally {
  server.proc.kill("SIGINT");
  rmSync(workDir, { recursive: true, force: true });
}
