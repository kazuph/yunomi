import http, { type IncomingMessage } from "node:http";
import { spawn, spawnSync, type ChildProcess } from "node:child_process";
import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const SERVER_JS = new URL("../_build/js/release/build/server/server.js", import.meta.url).pathname;
const WORK_DIR = mkdtempSync(join(tmpdir(), "yunomi-structured-schema-"));
const REVIEW_DIR = join(WORK_DIR, ".yunomi", "reviews", "schema");
const REPORT = join(WORK_DIR, "src", "docs", "REPORT.md");
const PORT = 5884;
const WEBP_DATA = "data:image/webp;base64,UklGRiIAAABXRUJQVlA4IBYAAAAwAQCdASoBAAEADsD+JaQAA3AA/vuUAAA=";

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

function request(method: string, path: string, body = ""): Promise<{ status: number; body: string }> {
  return new Promise((resolve, reject) => {
    const req = http.request(
      `http://127.0.0.1:${PORT}${path}`,
      { method, headers: { "Content-Type": "application/json" } },
      (res: IncomingMessage) => {
        let data = "";
        res.on("data", (chunk: string) => { data += chunk; });
        res.on("end", () => resolve({ status: res.statusCode || 0, body: data }));
      },
    );
    req.on("error", reject);
    if (body) req.write(body);
    req.end();
  });
}

async function waitForReady(): Promise<void> {
  for (let i = 0; i < 80; i++) {
    try {
      const res = await request("GET", "/healthz");
      if (res.status === 200) return;
    } catch (_err: unknown) {}
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  throw new Error("server did not become ready");
}

function waitForExit(proc: ChildProcess, timeoutMs: number): Promise<number | "timeout"> {
  return new Promise((resolve) => {
    const timer = setTimeout(() => resolve("timeout"), timeoutMs);
    proc.once("exit", (code) => {
      clearTimeout(timer);
      resolve(code ?? 0);
    });
  });
}

function hasSchema(comment: any): boolean {
  return ["file", "row", "col", "end_row", "end_col", "snippet", "context_before", "context_after", "selector", "bounds", "element_text", "attachments"]
    .every((key) => Object.prototype.hasOwnProperty.call(comment || {}, key)) &&
    Array.isArray(comment?.attachments);
}

function assertSchema(comment: any, message: string): void {
  assert(hasSchema(comment), message, comment);
  assert(comment.file === "src/docs/REPORT.md", `${message}: file is repo-relative nested path`, comment);
  assert(!String(comment.file).startsWith(WORK_DIR), `${message}: file is not absolute`, comment);
}

mkdirSync(join(WORK_DIR, "src", "docs"), { recursive: true });
mkdirSync(REVIEW_DIR, { recursive: true });
spawnSync("git", ["init"], { cwd: WORK_DIR, stdio: "ignore" });
writeFileSync(REPORT, [
  "# Structured Schema",
  "",
  "line 1",
  "line 2",
  "line 3",
  "line 4",
  "line 5",
  "line 6",
  "line 7",
  "line 8 target",
  "line 9",
  "line 10",
  "line 11",
  "line 12",
  "line 13",
  "line 14",
  "",
].join("\n"));

const env = {
  ...process.env,
  HERDR_PANE_ID: "",
  YUNOMI_NOTIFY_CMD: "",
  YUNOMI_REVIEW_DIR: REVIEW_DIR,
};

const proc = spawn(process.execPath, [SERVER_JS, "--no-open", "--port", String(PORT), REPORT], {
  cwd: WORK_DIR,
  env,
  stdio: ["ignore", "pipe", "pipe"],
});

let output = "";
proc.stdout?.on("data", (chunk: Buffer) => { output += chunk.toString("utf8"); });
proc.stderr?.on("data", (chunk: Buffer) => { output += chunk.toString("utf8"); });

try {
  await waitForReady();

  const sendNow = await request("POST", "/comment", JSON.stringify({
    type: "send-now",
    key: "send-now-schema",
    row: 9,
    col: 0,
    text: "send-now schema comment",
  }));
  assert(sendNow.status === 200, "send-now comment accepted");

  const cliComment = await request("POST", "/comment", JSON.stringify({
    type: "comment",
    key: "cli-4",
    row: 10,
    col: 0,
    text: "CLI schema comment",
    author: "cli-e2e",
  }));
  assert(cliComment.status === 200, "CLI-style comment accepted");

  const exit = await request("POST", "/exit", JSON.stringify({
    summary: "structured schema submit",
    decision: "request_changes",
    comments: [{
      row: 9,
      col: 0,
      end_row: 9,
      end_col: 4,
      text: "normal submit schema comment",
      value: "line 8 target",
      image: WEBP_DATA,
      selector: "#schema",
      bounds: { x: 1, y: 2, width: 3, height: 4 },
      element_text: "line 8 target",
    }],
  }));
  assert(exit.status === 200, "normal submit accepted");
  assert(await waitForExit(proc, 5000) === 0, "server exits after submit");

  const review = JSON.parse(readFileSync(join(REVIEW_DIR, "review.json"), "utf8"));
  const normal = review.comments.find((comment: any) => comment.text === "normal submit schema comment");
  const now = review.comments.find((comment: any) => comment.text === "send-now schema comment");
  const cli = review.comments.find((comment: any) => comment.text === "CLI schema comment");

  assertSchema(normal, "normal submit review.json comment has common schema");
  assertSchema(now, "send-now review.json comment has common schema");
  assertSchema(cli, "CLI comment review.json comment has common schema");

  assert(normal.row === 9 && normal.col === 0 && normal.end_row === 9 && normal.end_col === 4, "normal submit preserves row/col/end_row/end_col", normal);
  assert(normal.snippet === "line 5\nline 6\nline 7\nline 8 target\nline 9\nline 10\nline 11", "normal submit snippet uses the target line plus three lines before and after", normal);
  assert(normal.context_before === "line 3\nline 4\nline 5\nline 6\nline 7", "normal submit context_before uses five preceding lines without the target", normal);
  assert(normal.context_after === "line 9\nline 10\nline 11\nline 12\nline 13", "normal submit context_after uses five following lines without the target", normal);
  assert(now.snippet === "line 5\nline 6\nline 7\nline 8 target\nline 9\nline 10\nline 11", "send-now snippet uses the target line plus three lines before and after", now);
  assert(now.context_before === "line 3\nline 4\nline 5\nline 6\nline 7", "send-now context_before uses five preceding lines without the target", now);
  assert(now.context_after === "line 9\nline 10\nline 11\nline 12\nline 13", "send-now context_after uses five following lines without the target", now);
  assert(cli.snippet === "line 5\nline 6\nline 7\nline 8 target\nline 9\nline 10\nline 11", "CLI comment snippet uses the target line plus three lines before and after", cli);
  assert(cli.context_before === "line 3\nline 4\nline 5\nline 6\nline 7", "CLI comment context_before uses five preceding lines without the target", cli);
  assert(cli.context_after === "line 9\nline 10\nline 11\nline 12\nline 13", "CLI comment context_after uses five following lines without the target", cli);
  assert(normal.selector === "#schema" && normal.bounds.includes("\"width\":3") && normal.element_text === "line 8 target", "normal submit writes DOM selector, bounds, and element_text", normal);
  const attachmentName = `${normal.id}.webp`;
  assert(normal.attachments.length === 1 && normal.attachments[0] === `./comment-attachments/${attachmentName}`, "normal submit attachments use review-relative PLAN id basename with MIME extension", normal);
  assert(!normal.attachments.some((value: string) => value.startsWith("/") || value.includes(WORK_DIR) || value.includes(".yunomi/outputs")), "normal submit attachments do not expose absolute local paths", normal);
  assert(typeof normal.image_path === "string" && normal.image_path.startsWith("/"), "legacy image_path remains absolute for compatibility", normal);
  assert(existsSync(join(REVIEW_DIR, "comment-attachments", attachmentName)), "relative attachment file exists under the review directory with the MIME extension");

  assert(output.includes("file: src/docs/REPORT.md"), "stdout YAML uses repo-relative nested file path");
  assert(output.includes(`attachments:\n      - ./comment-attachments/${attachmentName}`), "stdout YAML uses relative attachment path with review comment id basename");
  assert(!output.includes("attachments:\n      - /"), "stdout YAML common attachments do not contain absolute paths");
} catch (error) {
  failed++;
  console.error(error instanceof Error ? error.stack || error.message : String(error));
} finally {
  try { proc.kill("SIGKILL"); } catch (_err: unknown) {}
  rmSync(WORK_DIR, { recursive: true, force: true });
}

console.log(`Structured comment schema E2E: ${passed} passed, ${failed} failed`);
if (failed > 0) process.exit(1);
