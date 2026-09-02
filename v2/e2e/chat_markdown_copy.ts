/**
 * Chat markdown rendering + copy buttons on image / mermaid / code.
 * Run: node --experimental-strip-types e2e/chat_markdown_copy.ts
 */
import assert from "node:assert/strict";
import http, { type IncomingMessage } from "node:http";
import { spawn, type ChildProcess } from "node:child_process";
import { mkdirSync, rmSync, writeFileSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { chromium } from "playwright";

const SERVER_JS = new URL("../_build/js/release/build/server/server.js", import.meta.url).pathname;
const TMP_DIR = join(tmpdir(), `yunomi-chat-md-${Date.now()}`);
const LOCK_DIR = join(TMP_DIR, "locks");
const REVIEW_DIR = join(TMP_DIR, ".yunomi", "reviews", "no-branch");
const REPORT = join(TMP_DIR, "REPORT.md");
const PORT = 5497;

const FIXTURE = `# Chat markdown

Intro paragraph.

<img src="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=" alt="swatch">

\`\`\`javascript
function greet(name) {
  return "hello " + name;
}
\`\`\`

\`\`\`mermaid
flowchart LR
  A --> B
\`\`\`
`;

function request(port: number, method: string, path: string, body = ""): Promise<{ status: number; body: string }> {
  return new Promise((resolve, reject) => {
    const req = http.request(
      `http://127.0.0.1:${port}${path}`,
      { method, headers: { "Content-Type": "application/json" } },
      (res: IncomingMessage) => {
        let data = "";
        res.on("data", (chunk: string) => (data += chunk));
        res.on("end", () => resolve({ status: res.statusCode || 0, body: data }));
      },
    );
    req.on("error", reject);
    if (body.length > 0) req.write(body);
    req.end();
  });
}

function waitForServerOutput(proc: ChildProcess): Promise<number> {
  let output = "";
  return new Promise((resolve, reject) => {
    const onData = (chunk: Buffer) => {
      output += String(chunk);
      const match = output.match(/http:\/\/127\.0\.0\.1:(\d+)/);
      if (match) resolve(Number(match[1]));
    };
    proc.stdout?.on("data", onData);
    proc.stderr?.on("data", onData);
    proc.on("exit", (code) => reject(new Error(`server exited early code=${code}\n${output}`)));
    setTimeout(() => reject(new Error(`server startup timeout\n${output}`)), 10000);
  });
}

async function waitForHealth(port: number): Promise<void> {
  for (let i = 0; i < 80; i++) {
    try {
      if ((await request(port, "GET", "/healthz")).status === 200) return;
    } catch (_) {}
    await new Promise((r) => setTimeout(r, 100));
  }
  throw new Error("healthz timeout");
}

let passed = 0;
let failed = 0;
function check(condition: boolean, message: string, detail?: unknown): void {
  if (condition) {
    passed++;
    console.log(`PASS: ${message}`);
  } else {
    failed++;
    console.error(`FAIL: ${message}`);
    if (detail !== undefined) console.error(detail);
  }
}

async function main(): Promise<void> {
  mkdirSync(REVIEW_DIR, { recursive: true });
  mkdirSync(LOCK_DIR, { recursive: true });
  writeFileSync(REPORT, FIXTURE);
  const server = spawn(process.execPath, [SERVER_JS, "--no-open", "--loop", "--port", String(PORT), REPORT], {
    cwd: TMP_DIR,
    env: { ...process.env, HERDR_PANE_ID: "", YUNOMI_NOTIFY_CMD: "", YUNOMI_LOCK_DIR: LOCK_DIR, YUNOMI_REVIEW_DIR: REVIEW_DIR },
    stdio: ["ignore", "pipe", "pipe"],
  });
  const port = await waitForServerOutput(server);
  await waitForHealth(port);

  const firstSubmit = await request(port, "POST", "/exit", JSON.stringify({
    summary: "Please render **bold** and a line\\nbreak",
    decision: "request_changes",
    action: "final_request_changes",
    comments: [
      { row: 2, col: 1, text: "Human says **ok**\\nnext line", value: "Intro paragraph." },
    ],
  }));
  check(firstSubmit.status === 200, "request_changes keeps the loop alive");

  const reviewPath = join(REVIEW_DIR, "review.json");
  const review = JSON.parse(readFileSync(reviewPath, "utf-8"));
  const inline = review.comments.find((c: { id: string }) => c.id === "c-1-1");
  inline.replies = [{ author: "agent", round: 1, text: "Agent **reply**\\nwith break", attachments: [] }];
  writeFileSync(reviewPath, JSON.stringify(review, null, 2));

  const browser = await chromium.launch({ headless: true });
  try {
    const context = await browser.newContext({ permissions: ["clipboard-read", "clipboard-write"] });
    const page = await context.newPage({ viewport: { width: 1280, height: 900 } });
    await page.goto(`http://127.0.0.1:${port}/`, { waitUntil: "domcontentloaded" });
    await page.waitForSelector("#md-preview .mermaid-container svg", { timeout: 15000 });
    await page.waitForSelector("#md-preview .yunomi-copy-button", { timeout: 10000 });

    const html = await page.evaluate(() => window.__yunomiFormatChatMarkdown?.("**bold** and `code`\\nnext") || "");
    check(html.includes("<strong>bold</strong>"), "formatter renders bold", html);
    check(html.includes("<code>code</code>"), "formatter renders inline code", html);
    check(html.includes("<br>") && !html.includes("\\n"), "formatter turns literal \\n into a break", html);

    const copyLayout = await page.evaluate(() => {
      const mermaid = document.querySelector<HTMLElement>("#md-preview .mermaid-container");
      const imageHost = document.querySelector<HTMLElement>("#md-preview .yunomi-media-comment-host");
      const pre = document.querySelector<HTMLElement>("#md-preview pre.yunomi-copyable");
      const pos = (host: HTMLElement | null, cls: string) => {
        const btn = host?.querySelector<HTMLElement>(`:scope > .${cls}`);
        if (!host || !btn) return null;
        const hostBox = host.getBoundingClientRect();
        const box = btn.getBoundingClientRect();
        return { right: hostBox.right - box.right, leftGap: host.querySelector<HTMLElement>(":scope > .yunomi-comment-button")
          ? host.querySelector<HTMLElement>(":scope > .yunomi-comment-button")!.getBoundingClientRect().left - box.right
          : null };
      };
      return {
        mermaidCopy: !!mermaid?.querySelector(":scope > .yunomi-copy-button"),
        mermaidPencil: !!mermaid?.querySelector(":scope > .yunomi-comment-button"),
        mermaidCopyRightOfPencil: (() => {
          const copy = mermaid?.querySelector<HTMLElement>(":scope > .yunomi-copy-button");
          const pencil = mermaid?.querySelector<HTMLElement>(":scope > .yunomi-comment-button");
          if (!copy || !pencil) return false;
          return copy.getBoundingClientRect().right <= pencil.getBoundingClientRect().left + 1;
        })(),
        imageCopy: !!imageHost?.querySelector(":scope > .yunomi-copy-button"),
        imagePencil: !!imageHost?.querySelector(":scope > .yunomi-comment-button"),
        codeCopy: !!pre?.querySelector(":scope > .yunomi-copy-button"),
        mermaidPos: pos(mermaid, "yunomi-copy-button"),
      };
    });
    check(copyLayout.mermaidCopy && copyLayout.mermaidPencil && copyLayout.mermaidCopyRightOfPencil, "mermaid copy sits left of the pencil", copyLayout);
    check(copyLayout.imageCopy && copyLayout.imagePencil, "image host has copy left of the pencil", copyLayout);
    check(copyLayout.codeCopy, "code block has a copy button", copyLayout);

    const mermaidCopy = await page.evaluate(async () => {
      const writes: { type: string; size: number }[] = [];
      const store = window as unknown as { __yunomiCopied?: string[] };
      try {
        Object.defineProperty(navigator, "clipboard", {
          configurable: true,
          value: {
            writeText: async (text: string) => { store.__yunomiCopied = [text]; },
            write: async (items: ClipboardItem[]) => {
              for (const item of items) {
                const type = item.types.find((t) => t.startsWith("image/")) || item.types[0];
                const blob = await item.getType(type);
                writes.push({ type, size: blob.size });
              }
            },
            readText: async () => store.__yunomiCopied?.[0] || "",
          },
        });
      } catch {
        (navigator.clipboard as { write: (items: ClipboardItem[]) => Promise<void> }).write = async (items) => {
          for (const item of items) {
            const type = item.types.find((t) => t.startsWith("image/")) || item.types[0];
            const blob = await item.getType(type);
            writes.push({ type, size: blob.size });
          }
        };
      }
      const btn = document.querySelector<HTMLButtonElement>("#md-preview .mermaid-container > .yunomi-copy-button");
      btn?.click();
      await new Promise((r) => setTimeout(r, 800));
      return { writes, toast: document.querySelector(".copy-toast")?.textContent || "" };
    });
    check(mermaidCopy.toast === "Copied diagram", "mermaid copy toasts success", mermaidCopy);
    check(
      mermaidCopy.writes.some((item) => item.type === "image/png" && item.size > 200),
      "mermaid copy writes a PNG image, not text",
      mermaidCopy,
    );

    const copyDebug = await page.evaluate(async () => {
      const store = window as unknown as { __yunomiCopied?: string[] };
      store.__yunomiCopied = [];
      try {
        Object.defineProperty(navigator, "clipboard", {
          configurable: true,
          value: {
            writeText: async (text: string) => { store.__yunomiCopied = [text]; },
            write: async () => {},
            readText: async () => store.__yunomiCopied?.[0] || "",
          },
        });
      } catch (error) {
        (navigator.clipboard as { writeText: (text: string) => Promise<void> }).writeText = async (text) => {
          store.__yunomiCopied = [text];
        };
      }
      const pres = Array.from(document.querySelectorAll<HTMLElement>("#md-preview pre.yunomi-copyable")).map((pre) => ({
        text: (pre.innerText || "").slice(0, 80),
        hasBtn: !!pre.querySelector(":scope > .yunomi-copy-button"),
      }));
      const btn = document.querySelector<HTMLButtonElement>("#md-preview pre.yunomi-copyable > .yunomi-copy-button");
      btn?.click();
      await new Promise((r) => setTimeout(r, 400));
      return { pres, copied: store.__yunomiCopied?.[0] || "", toast: document.querySelector(".copy-toast")?.textContent || "" };
    });
    check(!!copyDebug.copied?.includes("function greet"), "code copy writes source text", copyDebug);

    await page.waitForSelector(".review-loop-inline[data-review-comment-id='c-1-1'] .review-loop-markdown strong", { timeout: 10000 });
    const inlineHtml = await page.locator(".review-loop-inline[data-review-comment-id='c-1-1']").innerHTML();
    check(inlineHtml.includes("<strong>ok</strong>") || inlineHtml.includes("<strong>reply</strong>"), "inline chat renders markdown for human and agent", inlineHtml.slice(0, 800));
    check(!inlineHtml.includes("\\n"), "inline chat does not show literal \\n", inlineHtml.slice(0, 800));

    const globalHtml = await page.locator("#review-loop-panel .review-loop-conversation").innerHTML();
    check(globalHtml.includes("<strong>bold</strong>"), "bottom-right chat renders markdown", globalHtml.slice(0, 800));
    check(!globalHtml.includes("Please render **bold**") || globalHtml.includes("<strong>bold</strong>"), "global summary markdown is rendered", globalHtml.slice(0, 800));
  } finally {
    await browser.close();
    server.kill("SIGTERM");
    rmSync(TMP_DIR, { recursive: true, force: true });
  }

  console.log(`${passed} passed, ${failed} failed`);
  if (failed > 0) process.exit(1);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
