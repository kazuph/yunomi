import http, { type IncomingMessage } from "node:http";
import net from "node:net";
import { spawn, type ChildProcess } from "node:child_process";

const SERVER_JS = new URL(
  "../_build/js/release/build/server/server.js",
  import.meta.url,
).pathname;

const TARGET_PORT = 5311;
const PROXY_PORT = 5312;
const REJECT_PORT = 5313;

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
], { stdio: ["ignore", "pipe", "pipe"] });

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
  assert(output.includes("selector: '#save'") || output.includes("selector: #save"), "live submit YAML includes selector field");
  assert(output.includes("value: Save now"), "live submit YAML includes element text");
  assert(output.includes("bounds:"), "live submit YAML includes structured bounds");
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
  ], { stdio: ["ignore", "pipe", "pipe"] });
  let rejectOutput = "";
  rejected.stdout?.on("data", (chunk: Buffer) => { rejectOutput += chunk.toString("utf8"); });
  rejected.stderr?.on("data", (chunk: Buffer) => { rejectOutput += chunk.toString("utf8"); });
  const code = await waitForExit(rejected, 5000);
  assert(code === 1, "live rejects non-local external URL");
  assert(rejectOutput.includes("only http://localhost"), "live rejection explains localhost-only rule");
}

console.log(`\nLive review E2E: ${passed} passed, ${failed} failed`);
if (failed > 0) process.exit(1);
