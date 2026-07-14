import http, { type IncomingMessage } from "node:http";
import net from "node:net";
import { spawn, type ChildProcess } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const SERVER_JS = new URL(
  "../_build/js/release/build/server/server.js",
  import.meta.url,
).pathname;

const TARGET_PORT = 5311;
const PROXY_PORT = 5312;
const REJECT_PORT = 5313;
const REVIEW_DIR = mkdtempSync(join(tmpdir(), "yunomi-live-review-"));

let passed = 0;
let failed = 0;

function assert(condition: boolean, message: string): void {
  if (condition) {
    passed++;
    console.log(`  PASS: ${message}`);
  } else {
    failed++;
    console.error(`  FAIL: ${message}`);
  }
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function httpGet(port: number, path: string): Promise<{ status: number; body: string; headers: http.IncomingHttpHeaders }> {
  return new Promise((resolve, reject) => {
    http.get(`http://127.0.0.1:${port}${path}`, (res: IncomingMessage) => {
      const chunks: Buffer[] = [];
      res.on("data", (chunk: Buffer) => chunks.push(chunk));
      res.on("end", () => resolve({
        status: res.statusCode ?? 0,
        body: Buffer.concat(chunks).toString("utf8"),
        headers: res.headers,
      }));
    }).on("error", reject);
  });
}

function httpPost(port: number, path: string, payload: unknown): Promise<{ status: number; body: string }> {
  return new Promise((resolve, reject) => {
    const body = JSON.stringify(payload);
    const req = http.request(`http://127.0.0.1:${port}${path}`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Content-Length": Buffer.byteLength(body),
      },
    }, (res: IncomingMessage) => {
      const chunks: Buffer[] = [];
      res.on("data", (chunk: Buffer) => chunks.push(chunk));
      res.on("end", () => resolve({
        status: res.statusCode ?? 0,
        body: Buffer.concat(chunks).toString("utf8"),
      }));
    });
    req.on("error", reject);
    req.end(body);
  });
}

async function waitForProxy(port: number): Promise<boolean> {
  for (let i = 0; i < 50; i++) {
    try {
      const res = await httpGet(port, "/healthz");
      if (res.status === 200) return true;
    } catch (_err: unknown) {}
    await sleep(100);
  }
  return false;
}

function waitForExit(proc: ChildProcess, timeoutMs: number): Promise<number | "timeout"> {
  return new Promise((resolve) => {
    const timer = setTimeout(() => resolve("timeout"), timeoutMs);
    proc.once("exit", (code: number | null) => {
      clearTimeout(timer);
      resolve(code ?? 0);
    });
  });
}

function websocketUpgrade(port: number): Promise<string> {
  return new Promise((resolve, reject) => {
    const socket = net.connect(port, "127.0.0.1", () => {
      socket.write([
        "GET /socket HTTP/1.1",
        `Host: 127.0.0.1:${port}`,
        "Upgrade: websocket",
        "Connection: Upgrade",
        "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==",
        "Sec-WebSocket-Version: 13",
        "",
        "",
      ].join("\r\n"));
    });
    let data = "";
    socket.on("data", (chunk: Buffer) => {
      data += chunk.toString("utf8");
      socket.destroy();
      resolve(data);
    });
    socket.on("error", reject);
    setTimeout(() => {
      socket.destroy();
      reject(new Error("websocket upgrade timed out"));
    }, 3000);
  });
}

const target = http.createServer((req, res) => {
  if (req.url === "/plain") {
    res.writeHead(200, { "Content-Type": "text/plain" });
    res.end("plain target response");
    return;
  }
  res.writeHead(200, { "Content-Type": "text/html; charset=utf-8" });
  res.end("<!doctype html><html><body><main><button id=\"save\">Save now</button><p class=\"lead\">Target paragraph</p></main></body></html>");
});
target.on("upgrade", (_req, socket) => {
  socket.write("HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n\r\n");
  socket.destroy();
});
await new Promise<void>((resolve) => target.listen(TARGET_PORT, "127.0.0.1", resolve));

console.log("\n--- Live Review Proxy ---");
const proc = spawn("node", [
  SERVER_JS,
  "live",
  `http://127.0.0.1:${TARGET_PORT}`,
  "--no-open",
  "--port",
  String(PROXY_PORT),
], {
  stdio: ["ignore", "pipe", "pipe"],
  env: { ...process.env, HERDR_PANE_ID: "", YUNOMI_NOTIFY_CMD: "", YUNOMI_REVIEW_DIR: REVIEW_DIR },
});

let output = "";
proc.stdout?.on("data", (chunk: Buffer) => { output += chunk.toString("utf8"); });
proc.stderr?.on("data", (chunk: Buffer) => { output += chunk.toString("utf8"); });

try {
  assert(await waitForProxy(PROXY_PORT), "live proxy healthz becomes ready");
  const html = await httpGet(PROXY_PORT, "/");
  assert(html.status === 200, "live proxy serves target HTML");
  assert(html.body.includes("yunomi-live-bar"), "live proxy injects comment overlay");
  assert(html.body.includes("Save now"), "live proxy preserves target content");
  assert(String(html.headers["content-length"] || "").length > 0, "live proxy recalculates Content-Length");
  const injectedScript = html.body.match(/<script data-yunomi-live="[^"]*">([\s\S]*?)<\/script>/)?.[1] ?? "";
  assert(injectedScript.length > 0, "live proxy injects a script body");
  try {
    new Function(injectedScript);
    assert(true, "live injected script is valid JavaScript");
  } catch (err: unknown) {
    assert(false, `live injected script syntax is valid: ${(err as Error).message}`);
  }

  const plain = await httpGet(PROXY_PORT, "/plain");
  assert(plain.status === 200, "live proxy passes through non-HTML");
  assert(plain.body === "plain target response", "live proxy does not alter non-HTML body");

  const upgrade = await websocketUpgrade(PROXY_PORT);
  assert(upgrade.includes("101 Switching Protocols"), "live proxy passes through WebSocket upgrade");

  await httpPost(PROXY_PORT, "/exit", {
    action: "final_request_changes",
    decision: "request_changes",
    summary: "live review summary",
    comments: [{
      row: 0,
      col: 0,
      text: "Button label is unclear",
      selector: "#save",
      value: "Save now",
      screenshot: "",
      bounds: { x: 10, y: 20, width: 80, height: 30 },
    }],
  });
  const exitCode = await waitForExit(proc, 5000);
  assert(exitCode === 0, "live proxy exits after submit");
  assert(output.includes("mode: live"), "live submit YAML includes mode: live");
  assert(output.includes("file: 'http://127.0.0.1:") || output.includes("file: http://127.0.0.1:"), "live submit YAML includes URL file identifier");
  assert(output.includes("row: 0"), "live submit YAML includes row");
  assert(output.includes("col: 0"), "live submit YAML includes col");
  assert(output.includes("end_row: 0"), "live submit YAML includes end_row");
  assert(output.includes("end_col: 0"), "live submit YAML includes end_col");
  assert(output.includes("snippet: Save now"), "live submit YAML includes snippet");
  assert(output.includes("context_before:"), "live submit YAML includes context_before");
  assert(output.includes("context_after:"), "live submit YAML includes context_after");
  assert(output.includes("selector: '#save'") || output.includes("selector: #save"), "live submit YAML includes selector field");
  assert(output.includes("value: Save now"), "live submit YAML includes element text");
  assert(output.includes("bounds:"), "live submit YAML includes structured bounds");
  assert(output.includes("element_text: Save now"), "live submit YAML includes element_text");
  assert(output.includes("attachments: []"), "live submit YAML includes attachments");
  const review = JSON.parse(readFileSync(join(REVIEW_DIR, "review.json"), "utf8"));
  const persisted = review.comments?.find((comment: any) => comment.text === "Button label is unclear");
  const schemaKeys = ["file", "row", "col", "end_row", "end_col", "snippet", "context_before", "context_after", "selector", "bounds", "element_text", "attachments"];
  assert(schemaKeys.every((key) => Object.prototype.hasOwnProperty.call(persisted || {}, key)), "live /exit persists every common schema key to review.json");
  assert(persisted?.file?.startsWith("http://127.0.0.1:") && persisted?.selector === "#save" && persisted?.element_text === "Save now", "live review.json preserves URL and DOM context");
} catch (err: unknown) {
  failed++;
  console.error(`  FAIL: ${(err as Error).message}`);
} finally {
  try { proc.kill("SIGKILL"); } catch (_err: unknown) {}
  await new Promise<void>((resolve) => target.close(() => resolve()));
}

console.log("\n--- Live Review URL Guard ---");
{
  const rejected = spawn("node", [
    SERVER_JS,
    "live",
    "https://example.com",
    "--no-open",
    "--port",
    String(REJECT_PORT),
  ], {
    stdio: ["ignore", "pipe", "pipe"],
    env: { ...process.env, HERDR_PANE_ID: "", YUNOMI_NOTIFY_CMD: "", YUNOMI_REVIEW_DIR: REVIEW_DIR },
  });
  let rejectOutput = "";
  rejected.stdout?.on("data", (chunk: Buffer) => { rejectOutput += chunk.toString("utf8"); });
  rejected.stderr?.on("data", (chunk: Buffer) => { rejectOutput += chunk.toString("utf8"); });
  const code = await waitForExit(rejected, 5000);
  assert(code === 1, "live rejects non-local external URL");
  assert(rejectOutput.includes("only http://localhost"), "live rejection explains localhost-only rule");
}

console.log(`\nLive review E2E: ${passed} passed, ${failed} failed`);
rmSync(REVIEW_DIR, { recursive: true, force: true });
if (failed > 0) process.exit(1);
