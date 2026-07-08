import http, { type IncomingMessage } from "node:http";
import { spawn, type ChildProcess } from "node:child_process";
import { mkdtempSync, writeFileSync, rmSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";

const SERVER_JS = new URL(
  "../_build/js/release/build/server/server.js",
  import.meta.url,
).pathname;

const PORT = 5862;
let passed = 0;
let failed = 0;

function assert(condition: boolean, message: string): void {
  if (condition) {
    passed++;
    console.log(`PASS: ${message}`);
  } else {
    failed++;
    console.error(`FAIL: ${message}`);
  }
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function httpGet(path: string): Promise<{ status: number; body: Buffer; headers: http.IncomingHttpHeaders }> {
  return new Promise((resolve, reject) => {
    http.get(`http://127.0.0.1:${PORT}${path}`, (res: IncomingMessage) => {
      const chunks: Buffer[] = [];
      res.on("data", (chunk: Buffer) => chunks.push(chunk));
      res.on("end", () => resolve({
        status: res.statusCode ?? 0,
        body: Buffer.concat(chunks),
        headers: res.headers,
      }));
    }).on("error", reject);
  });
}

function httpPost(path: string, payload: unknown): Promise<{ status: number; body: string }> {
  return new Promise((resolve, reject) => {
    const body = JSON.stringify(payload);
    const req = http.request(`http://127.0.0.1:${PORT}${path}`, {
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

async function waitForReady(): Promise<boolean> {
  for (let i = 0; i < 50; i++) {
    try {
      const res = await httpGet("/healthz");
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

const dir = mkdtempSync(join(tmpdir(), "yunomi-html-preview-"));
const htmlFile = join(dir, "page.html");
const logoFile = join(dir, "logo.png");
writeFileSync(logoFile, Buffer.from(
  "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=",
  "base64",
));
writeFileSync(htmlFile, [
  "<!doctype html>",
  "<html>",
  "<body>",
  "<main>",
  "<button id=\"cta\">Buy</button>",
  "<img src=\"./logo.png\" alt=\"logo\">",
  "</main>",
  "</body>",
  "</html>",
].join("\n"));

const proc = spawn("node", [
  SERVER_JS,
  htmlFile,
  "--no-open",
  "--host",
  "127.0.0.1",
  "--port",
  String(PORT),
], { stdio: ["ignore", "pipe", "pipe"] });

let output = "";
proc.stdout?.on("data", (chunk: Buffer) => { output += chunk.toString("utf8"); });
proc.stderr?.on("data", (chunk: Buffer) => { output += chunk.toString("utf8"); });

try {
  assert(await waitForReady(), "HTML preview server becomes ready");

  const shell = await httpGet("/");
  const shellText = shell.body.toString("utf8");
  assert(shell.status === 200, "HTML preview shell returns 200");
  assert(shellText.includes("<iframe"), "HTML preview shell renders an iframe");
  assert(shellText.includes("sandbox=\"allow-scripts allow-same-origin\""), "iframe uses the expected sandbox policy");
  assert(shellText.includes("src=\"/__yunomi_html_target\""), "iframe points at the local HTML target");

  const target = await httpGet("/__yunomi_html_target");
  const targetText = target.body.toString("utf8");
  assert(target.status === 200, "iframe target returns the reviewed HTML");
  assert(targetText.includes("id=\"cta\""), "iframe target preserves the reviewed button");
  assert(targetText.includes("data-yunomi-html"), "iframe target injects the html comment overlay");

  const logo = await httpGet("/logo.png");
  assert(logo.status === 200, "relative image asset is served");
  assert(String(logo.headers["content-type"]).includes("image/png"), "relative image asset keeps image/png content type");
  assert(logo.body.length > 0, "relative image asset has a body");

  const submit = await httpPost("/exit", {
    action: "final_request_changes",
    decision: "request_changes",
    summary: "html preview summary",
    comments: [{
      row: 0,
      col: 0,
      text: "CTA wording is too terse",
      selector: "#cta",
      value: "Buy",
      bounds: { x: 10, y: 20, width: 80, height: 30 },
    }],
  });
  assert(submit.status === 200, "HTML preview /exit accepts comment payload");
  const exitCode = await waitForExit(proc, 5000);
  assert(exitCode === 0, "HTML preview exits after submit");
  assert(output.includes("mode: html"), "submitted YAML includes mode: html");
  assert(output.includes("selector: '#cta'") || output.includes("selector: #cta"), "submitted YAML includes selector");
  assert(output.includes("value: Buy"), "submitted YAML includes element text");
  assert(output.includes("bounds:"), "submitted YAML includes bounds");
} catch (err: unknown) {
  failed++;
  console.error(`FAIL: ${(err as Error).message}`);
} finally {
  try { proc.kill("SIGKILL"); } catch (_err: unknown) {}
  rmSync(dir, { recursive: true, force: true });
}

console.log(`HTML preview E2E: ${passed} passed, ${failed} failed`);
if (failed > 0) process.exit(1);
