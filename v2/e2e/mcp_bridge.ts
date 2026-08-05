import { spawn, type ChildProcessWithoutNullStreams } from "node:child_process";
import { existsSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const SERVER_JS = new URL("../_build/js/release/build/server/server.js", import.meta.url).pathname;
const WORK_DIR = mkdtempSync(join(tmpdir(), "yunomi-mcp-"));
const REVIEW_DIR = join(WORK_DIR, "reviews");
const sampleFile = join(WORK_DIR, "sample.txt");

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

function encode(message: unknown): Buffer {
  const body = Buffer.from(JSON.stringify(message), "utf8");
  return Buffer.concat([
    Buffer.from(`Content-Length: ${body.length}\r\n\r\n`, "utf8"),
    body,
  ]);
}

function decode(buffer: Buffer): { messages: unknown[]; rest: Buffer } {
  const messages: unknown[] = [];
  let rest = buffer;
  while (true) {
    const sep = rest.indexOf("\r\n\r\n");
    if (sep < 0) return { messages, rest };
    const header = rest.subarray(0, sep).toString("utf8");
    const match = header.match(/Content-Length:\s*(\d+)/i);
    if (!match) return { messages, rest: rest.subarray(sep + 4) };
    const length = Number(match[1]);
    const start = sep + 4;
    const end = start + length;
    if (rest.length < end) return { messages, rest };
    messages.push(JSON.parse(rest.subarray(start, end).toString("utf8")));
    rest = rest.subarray(end);
  }
}

class McpClient {
  proc: ChildProcessWithoutNullStreams;
  buffer = Buffer.alloc(0);
  pending = new Map<number, (value: unknown) => void>();
  nextId = 1;
  stderr = "";

  constructor() {
    this.proc = spawn(process.execPath, [SERVER_JS, "mcp"], {
      cwd: WORK_DIR,
      env: {
        ...process.env,
        YUNOMI_REVIEW_DIR: REVIEW_DIR,
      },
      stdio: ["pipe", "pipe", "pipe"],
    });
    this.proc.stdout.on("data", (chunk: Buffer) => {
      this.buffer = Buffer.concat([this.buffer, chunk]);
      const decoded = decode(this.buffer);
      this.buffer = decoded.rest;
      for (const message of decoded.messages) {
        const id = (message as { id?: number }).id;
        if (typeof id === "number") {
          this.pending.get(id)?.(message);
          this.pending.delete(id);
        }
      }
    });
    this.proc.stderr.on("data", (chunk: Buffer) => {
      this.stderr += chunk.toString("utf8");
    });
  }

  request(method: string, params: Record<string, unknown> = {}): Promise<unknown> {
    const id = this.nextId++;
    const message = { jsonrpc: "2.0", id, method, params };
    this.proc.stdin.write(encode(message));
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        this.pending.delete(id);
        reject(new Error(`MCP request timeout: ${method}\n${this.stderr}`));
      }, 8000);
      this.pending.set(id, (value) => {
        clearTimeout(timer);
        resolve(value);
      });
    });
  }

  close(): void {
    this.proc.stdin.end();
    this.proc.kill("SIGTERM");
  }
}

function textContent(response: unknown): string {
  const content = (response as { result?: { content?: Array<{ text?: string }> } }).result?.content || [];
  return String(content[0]?.text || "");
}

function assertStructuredComment(comment: any, message: string): void {
  const keys = ["file", "row", "col", "end_row", "end_col", "snippet", "context_before", "context_after", "selector", "bounds", "element_text", "attachments"];
  assert(keys.every((key) => Object.prototype.hasOwnProperty.call(comment || {}, key)), message, comment);
  assert(Array.isArray(comment?.attachments), `${message}: attachments is an array`, comment);
}

writeFileSync(sampleFile, "alpha\nbeta target\ngamma\ndelta\nepsilon\n");

try {
  const projectMcp = JSON.parse(readFileSync(new URL("../../.mcp.json", import.meta.url), "utf8"));
  assert(
    projectMcp?.mcpServers?.yunomi?.command === "node" &&
      projectMcp?.mcpServers?.yunomi?.args?.join(" ") === "./dist/server/server.js mcp",
    "project .mcp.json registers the packaged yunomi stdio server",
    projectMcp,
  );

  const client = new McpClient();
  try {
    const init = await client.request("initialize", {
      protocolVersion: "2024-11-05",
      capabilities: {},
      clientInfo: { name: "yunomi-e2e", version: "0" },
    });
    const serverInfo = (init as { result?: { serverInfo?: { name?: string; version?: string } } }).result?.serverInfo;
    assert(
      serverInfo?.name === "yunomi" && serverInfo?.version === "2.4.2",
      "MCP initialize returns the published yunomi server identity and version",
      serverInfo,
    );

    const listed = await client.request("tools/list");
    const toolNames = ((listed as { result?: { tools?: Array<{ name: string }> } }).result?.tools || []).map((tool) => tool.name);
    assert(
      toolNames.includes("yunomi_review_state") &&
        toolNames.includes("yunomi_add_comment") &&
        toolNames.includes("yunomi_go") &&
        toolNames.includes("mcp__yunomi__list_reviews") &&
        toolNames.includes("mcp__yunomi__get_review") &&
        toolNames.includes("mcp__yunomi__add_comment") &&
        toolNames.includes("mcp__yunomi__advance_round"),
      "MCP tools/list exposes existing tools and PLAN-named aliases",
      { toolNames },
    );

    const added = await client.request("tools/call", {
      name: "yunomi_add_comment",
      arguments: {
        cwd: WORK_DIR,
        file: sampleFile,
        line: 2,
        text: "MCP comment text",
        author: "mcp-e2e",
      },
    });
    const addResult = JSON.parse(textContent(added));
    assert(addResult.id === "mcp-1-1" && existsSync(addResult.path), "MCP add_comment writes review.json and returns a comment id", addResult);

    const state = await client.request("tools/call", {
      name: "yunomi_review_state",
      arguments: { cwd: WORK_DIR },
    });
    const review = JSON.parse(textContent(state));
    const comment = review.comments?.[0];
    assertStructuredComment(comment, "MCP add_comment writes top-level structured comment schema");
    assert(
      comment?.text === "MCP comment text" &&
        comment?.row === 1 &&
        comment?.col === 0 &&
        comment?.end_row === 1 &&
        comment?.end_col === 0 &&
        comment?.snippet.includes("beta target") &&
        comment?.context_before === "alpha" &&
        comment?.context_after.includes("gamma") &&
        comment?.selector === "" &&
        comment?.bounds === "" &&
        comment?.element_text === comment?.snippet &&
        comment?.anchor?.snippet === comment?.snippet,
      "MCP review_state returns structured comment context",
      comment,
    );

    const go = await client.request("tools/call", {
      name: "yunomi_go",
      arguments: { cwd: WORK_DIR },
    });
    const goResult = JSON.parse(textContent(go));
    const afterGo = JSON.parse(readFileSync(join(REVIEW_DIR, "review.json"), "utf8"));
    assert(goResult.round === 1 && afterGo.rounds.length === 1, "MCP go is idempotent while the current round is still open", goResult);

    afterGo.comments.push({
      id: "legacy-1",
      file: "legacy.txt",
      line: 3,
      round: 1,
      text: "legacy anchor-only comment",
      author: "legacy",
      status: "unresolved",
      replies: [],
      anchor: { snippet: "legacy snippet", context_before: "legacy before", context_after: "legacy after" },
    });
    writeFileSync(join(REVIEW_DIR, "review.json"), JSON.stringify(afterGo, null, 2));

    const listedReviews = await client.request("tools/call", {
      name: "mcp__yunomi__list_reviews",
      arguments: { cwd: WORK_DIR },
    });
    const reviews = JSON.parse(textContent(listedReviews));
    assert(Array.isArray(reviews) && reviews.length >= 1 && reviews[0].unresolved >= 1, "MCP list_reviews alias returns review summaries", reviews);

    const aliasState = await client.request("tools/call", {
      name: "mcp__yunomi__get_review",
      arguments: { cwd: WORK_DIR },
    });
    const aliasReview = JSON.parse(textContent(aliasState));
    assert(aliasReview.comments?.[0]?.text === "MCP comment text", "MCP get_review alias returns review.json content", aliasReview.comments?.[0]);
    const legacy = aliasReview.comments?.find((entry: any) => entry.id === "legacy-1");
    assertStructuredComment(legacy, "MCP get_review alias normalizes legacy anchor-only review.json comments");
    assert(
      legacy?.row === 2 &&
        legacy?.col === 0 &&
        legacy?.end_row === 2 &&
        legacy?.end_col === 0 &&
        legacy?.snippet === "legacy snippet" &&
        legacy?.context_before === "legacy before" &&
        legacy?.context_after === "legacy after" &&
        legacy?.selector === "" &&
        legacy?.bounds === "" &&
        legacy?.element_text === "legacy snippet",
      "MCP legacy normalization preserves anchor context and fills common fields",
      legacy,
    );

    const aliasGo = await client.request("tools/call", {
      name: "mcp__yunomi__advance_round",
      arguments: { cwd: WORK_DIR },
    });
    const aliasGoResult = JSON.parse(textContent(aliasGo));
    assert(aliasGoResult.round === 1 || aliasGoResult.path, "MCP advance_round alias reaches the round transition handler", aliasGoResult);
  } finally {
    client.close();
  }
} catch (error) {
  failed++;
  console.error(error instanceof Error ? error.stack || error.message : String(error));
} finally {
  rmSync(WORK_DIR, { recursive: true, force: true });
}

console.log(`MCP bridge E2E: ${passed} passed, ${failed} failed`);
if (failed > 0) process.exit(1);
