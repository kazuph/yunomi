import assert from "node:assert/strict";
import http, { type IncomingMessage } from "node:http";
import { spawn, spawnSync, type ChildProcess } from "node:child_process";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { chromium } from "playwright";

const SERVER_JS = new URL("../_build/js/release/build/server/server.js", import.meta.url).pathname;
const TMP_DIR = join(tmpdir(), `yunomi-review-loop-${Date.now()}`);
const LOCK_DIR = join(TMP_DIR, "locks");
const REPORT = join(TMP_DIR, "REPORT.md");
const IMAGE = join(TMP_DIR, "review-image.png");
const NOTIFY_LOG = join(TMP_DIR, "notify.log");
const NOTIFY_SCRIPT = join(TMP_DIR, "notify-capture.mjs");
const PORT = 5167;
const NON_LOOP_REPORT = join(TMP_DIR, "NON_LOOP.md");
const NON_LOOP_REVIEW_DIR = join(TMP_DIR, ".yunomi", "reviews", "non-loop");
const NON_LOOP_PORT = PORT + 1;
const EMPTY_REPORT = join(TMP_DIR, "EMPTY.md");
const EMPTY_REVIEW_DIR = join(TMP_DIR, ".yunomi", "reviews", "empty");
const EMPTY_PORT = PORT + 2;
const APPROVED_REOPEN_PORT = PORT + 3;
const childProcesses = new Set<ChildProcess>();

function trackProcess(proc: ChildProcess): ChildProcess {
  childProcesses.add(proc);
  proc.once("exit", () => childProcesses.delete(proc));
  return proc;
}

function stopChildProcesses(): void {
  for (const proc of childProcesses) {
    if (proc.exitCode === null && proc.signalCode === null) proc.kill("SIGTERM");
  }
}

mkdirSync(LOCK_DIR, { recursive: true });
writeFileSync(REPORT, "# Review Loop\n\nBefore line\n\n![Review image](review-image.png)\n\n- List target\n\n1. Ordered target\n2. Ordered next\n");
writeFileSync(IMAGE, Buffer.from("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=", "base64"));
writeFileSync(
  NOTIFY_SCRIPT,
  "import { appendFileSync } from 'node:fs'; appendFileSync(process.env.NOTIFY_LOG, process.argv[2] + '\\n');\n",
);
mkdirSync(NON_LOOP_REVIEW_DIR, { recursive: true });
writeFileSync(NON_LOOP_REPORT, "# Non Loop Review\n\nA normal review can approve with comments.\n");
mkdirSync(EMPTY_REVIEW_DIR, { recursive: true });
writeFileSync(EMPTY_REPORT, "# Empty Review\n");

function waitForServerOutput(proc: ChildProcess): Promise<number> {
  let output = "";
  let resolved = false;
  return new Promise((resolve, reject) => {
    proc.stdout?.on("data", (chunk: Buffer) => {
      output += String(chunk);
      if (resolved) return;
      const match = output.match(/http:\/\/127\.0\.0\.1:(\d+)/);
      if (match) {
        resolved = true;
        resolve(Number(match[1]));
      }
    });
    proc.stderr?.on("data", (chunk: Buffer) => {
      output += String(chunk);
    });
    proc.on("exit", (code) => {
      if (!resolved) {
        resolved = true;
        reject(new Error(`server exited before ready code=${code}\n${output}`));
      }
    });
    setTimeout(() => {
      if (!resolved) {
        resolved = true;
        reject(new Error(`server startup timeout\n${output}`));
      }
    }, 10000);
  });
}

function request(port: number, method: string, path: string, body = ""): Promise<{ status: number; body: string }> {
  return new Promise((resolve, reject) => {
    const req = http.request(
      `http://127.0.0.1:${port}${path}`,
      { method, headers: { "Content-Type": "application/json" } },
      (res: IncomingMessage) => {
        let data = "";
        res.on("data", (chunk: string) => {
          data += chunk;
        });
        res.on("end", () => resolve({ status: res.statusCode || 0, body: data }));
      },
    );
    req.on("error", reject);
    if (body.length > 0) req.write(body);
    req.end();
  });
}

async function waitForHealth(port: number): Promise<void> {
  for (let i = 0; i < 80; i++) {
    try {
      const res = await request(port, "GET", "/healthz");
      if (res.status === 200) return;
    } catch (_: unknown) {}
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  throw new Error(`healthz timeout on ${port}`);
}

function collectOutput(proc: ChildProcess): { get: () => string } {
  let output = "";
  proc.stdout?.on("data", (chunk: Buffer) => {
    output += String(chunk);
  });
  proc.stderr?.on("data", (chunk: Buffer) => {
    output += String(chunk);
  });
  return { get: () => output };
}

function waitForExit(proc: ChildProcess, timeoutMs: number): Promise<number | null | "timeout"> {
  return new Promise((resolve) => {
    const timer = setTimeout(() => resolve("timeout"), timeoutMs);
    proc.once("exit", (code) => {
      clearTimeout(timer);
      resolve(code);
    });
  });
}

async function waitForRound(port: number, round: number): Promise<any> {
  for (let i = 0; i < 80; i++) {
    const res = await request(port, "GET", "/review-state");
    assert.equal(res.status, 200);
    const state = JSON.parse(res.body);
    const rounds = state.review.rounds || [];
    if (rounds.at(-1)?.round === round) return state;
    await new Promise((resolve) => setTimeout(resolve, 150));
  }
  throw new Error(`round ${round} did not appear`);
}

async function main(): Promise<void> {
  const REVIEW_DIR = join(TMP_DIR, ".yunomi", "reviews", "no-branch");
  mkdirSync(REVIEW_DIR, { recursive: true });
  const env = {
    ...process.env,
    HERDR_PANE_ID: "",
    YUNOMI_NOTIFY_CMD: `${process.execPath} ${NOTIFY_SCRIPT} {msg}`,
    NOTIFY_LOG,
    YUNOMI_LOCK_DIR: LOCK_DIR,
    YUNOMI_REVIEW_DIR: REVIEW_DIR,
  };
  const server = trackProcess(spawn(process.execPath, [SERVER_JS, "--no-open", "--loop", "--port", String(PORT), REPORT], {
    cwd: TMP_DIR,
    env,
    stdio: ["ignore", "pipe", "pipe"],
  }));
  const serverOutput = collectOutput(server);

  const port = await waitForServerOutput(server);
  await waitForHealth(port);
  const initialHtml = await request(port, "GET", "/");
  assert.equal(initialHtml.status, 200);
  assert.match(initialHtml.body, /id="review-loop-panel"[^>]*class="review-loop-sidebar"|class="review-loop-sidebar"[^>]*id="review-loop-panel"/, "markdown page renders the review loop mount as a sidebar");
  const uiJs = await request(port, "GET", "/ui.js");
  assert.equal(uiJs.status, 200);
  assert.match(uiJs.body, /Comments/, "review loop UI uses the familiar comments header");
  assert.match(uiJs.body, /review-loop-thread-line is-human/, "review loop UI renders the human message inside a thread");
  assert.match(uiJs.body, /r\.author === "human" \? t\.you : t\.agent/, "review loop UI renders reply authors inside the same thread");
  assert.match(uiJs.body, /Diff since last round/, "review loop UI keeps the collapsed round diff");
  assert.doesNotMatch(uiJs.body, /Previous request|AI reply|Review flow|Check status|Review target|Original target/, "review loop removes duplicated labels and fixed guidance");
  assert.match(uiJs.body, /All resolved — enjoy your tea/, "review loop UI keeps the tea-themed approve-ready moment for when every thread is resolved");
  assert.match(uiJs.body, /New conversation/, "review loop UI can start a global conversation when none exists");
  assert.doesNotMatch(uiJs.body, /Past conversation/, "global conversation has no per-thread resolved history");
  assert.match(uiJs.body, /review-loop-submit-state/, "submit modal must render review loop status text");

  const firstSubmit = await request(
    port,
    "POST",
    "/exit",
    JSON.stringify({
      summary: "Round 1 needs a text update",
      decision: "request_changes",
      action: "final_request_changes",
      comments: [
        { row: 2, col: 1, text: "Please update this line", value: "Before line" },
        { row: 4, col: 1, text: "Please review this image", value: "![Review image](review-image.png)" },
        { row: 6, col: 1, text: "Please review this list item", value: "List target" },
        { row: 999, col: 1, text: "Please review detached detail", value: "Detached target" },
        { row: 0, col: 1, text: "Please review this heading", value: "# Review Loop" },
        { row: 8, col: 1, text: "Please review this ordered item", value: "Ordered target" },
      ],
    }),
  );
  assert.equal(firstSubmit.status, 200);
  assert.equal(server.exitCode, null, "--loop request_changes must keep the server alive");

  const reviewPath = join(TMP_DIR, ".yunomi", "reviews", "no-branch", "review.json");
  const reviewJson = readFileSync(reviewPath, "utf-8");
  const review = JSON.parse(reviewJson);
  assert.equal(review.version, 1);
  assert.equal(review.rounds[0].decision, "request_changes");
  const roundThread = review.comments.find((comment: { id: string }) => comment.id === "r-1");
  const firstComment = review.comments.find((comment: { id: string }) => comment.id === "c-1-1");
  assert.deepEqual(
    { id: roundThread?.id, scope: roundThread?.scope, text: roundThread?.text, status: roundThread?.status },
    { id: "r-1", scope: "round", text: "Round 1 needs a text update", status: "unresolved" },
    "a submitted summary becomes one round-scoped conversation",
  );
  assert.equal(firstComment?.status, "unresolved");
  assert.match(firstComment?.anchor.snippet || "", /# Review Loop/, "review loop anchor keeps nearby source context");
  assert.match(firstComment?.anchor.snippet || "", /Before line/, "review loop anchor includes the referenced line");
  review.comments.push({
    id: "foreign-file-comment",
    file: "OTHER.md",
    line: 1,
    round: 1,
    text: "This belongs to another reviewed file",
    author: "human",
    status: "unresolved",
    replies: [],
    anchor: { snippet: "# Other", context_before: "", context_after: "" },
  });
  writeFileSync(reviewPath, JSON.stringify(review, null, 2));

  const currentRoundBrowser = await chromium.launch({ headless: true });
  try {
    const currentRoundPage = await currentRoundBrowser.newPage({ viewport: { width: 1280, height: 900 } });
    await currentRoundPage.goto(`http://127.0.0.1:${port}/`, { waitUntil: "domcontentloaded" });
    await currentRoundPage.waitForSelector("#review-loop-panel .review-loop-conversation[data-review-comment-id='r-1']", { timeout: 10000 });
    assert.match(
      await currentRoundPage.locator("#review-loop-panel .review-loop-conversation").textContent() || "",
      /Round 1 needs a text update/,
      "the global conversation remains visible in the same round that created it",
    );
    assert.equal(
      await currentRoundPage.locator("#review-loop-panel .review-loop-conversation textarea").count(),
      1,
      "the current round summary is immediately replyable",
    );
    assert.equal(
      await currentRoundPage.locator("#review-loop-panel [data-review-comment-id^='c-']").count(),
      0,
      "showing the current global conversation does not copy any line comment into the sidebar",
    );
  } finally {
    await currentRoundBrowser.close().catch(() => {});
  }

  const roundReply = await request(port, "POST", "/reply-comment", JSON.stringify({ id: "r-1", text: "Please keep this discussion together", author: "human" }));
  assert.equal(roundReply.status, 200);
  const reviewAfterReply = JSON.parse(readFileSync(join(TMP_DIR, ".yunomi", "reviews", "no-branch", "review.json"), "utf-8"));
  assert.deepEqual(
    reviewAfterReply.comments.find((comment: { id: string }) => comment.id === "r-1")?.replies,
    [{ author: "human", round: 1, text: "Please keep this discussion together", attachments: [] }],
    "round summary replies use the existing reply endpoint and retain the human author",
  );
  assert.match(readFileSync(NOTIFY_LOG, "utf-8"), /\[yunomi\] conversation reply id=r-1 round=1[\s\S]*human: Please keep this discussion together[\s\S]*reply with: yunomi reply r-1 <text>/, "a human sidebar reply immediately notifies the configured Herdr delivery path");
  const agentReply = await request(port, "POST", "/reply-comment", JSON.stringify({ id: "c-1-1", text: "I will revise it", author: "agent" }));
  assert.equal(agentReply.status, 200);

  writeFileSync(REPORT, "# Review Loop\n\nAfter line\n\n![Review image](review-image.png)\n\n- List target\n\n1. Ordered target\n2. Ordered next\n");
  const go = trackProcess(spawn(process.execPath, [SERVER_JS, "go", "--no-open", "--port", String(PORT)], {
    cwd: TMP_DIR,
    env,
    stdio: ["ignore", "pipe", "pipe"],
  }));
  const goOutput = collectOutput(go);
  const goCode = await waitForExit(go, 10000);
  assert.equal(goCode, 0, `yunomi go should notify the running loop server\ngo output:\n${goOutput.get()}\nserver output:\n${serverOutput.get()}`);

  const state = await waitForRound(port, 2);
  assert.equal(state.unresolved_count, 6);
  assert.equal(state.gate_unresolved_count, 6, "an unresolved round thread does not enter the approve gate");
  assert.equal(state.review.comments.find((comment: { id: string }) => comment.id === "c-1-1")?.id, "c-1-1");
  assert.equal(
    state.review.comments.some((comment: { id: string }) => comment.id === "foreign-file-comment"),
    false,
    "review state excludes unresolved comments that belong to another file in the branch review store",
  );
  assert.match(JSON.stringify(state.diff.lines), /Before line/);
  assert.match(JSON.stringify(state.diff.lines), /After line/);

  const browser = await chromium.launch({ headless: true });
  try {
    const page = await browser.newPage({ viewport: { width: 1280, height: 900 } });
    await page.goto(`http://127.0.0.1:${port}/`, { waitUntil: "domcontentloaded" });
    await page.waitForSelector("#review-loop-panel .review-loop-conversation", { timeout: 10000 });
    await page.waitForSelector(".review-loop-inline", { timeout: 10000 });
    assert.equal(await page.locator("#send-and-exit").textContent(), "Submit", "the primary action uses the requested Submit label without review");
    assert.equal(await page.locator("#submit-modal h3").textContent(), "Submit", "the submit dialog uses the same concise label");
    assert.equal(await page.locator(".md-layout > #review-loop-panel.review-loop-sidebar").count(), 1, "review loop chat mount remains outside preview content");
    assert.equal(await page.locator("#md-preview > #review-loop-panel").count(), 0, "preview no longer starts with a review-loop panel");
    assert.equal(await page.locator(".review-loop-inline").count(), 5, "each anchored unresolved comment renders one inline thread");
    const sidebarText = await page.locator("#review-loop-panel").first().textContent();
    assert.match(sidebarText || "", /Comments/, "sidebar shows the comments header");
    assert.equal(await page.locator("#pill-comments").isVisible(), false, "the unrelated Drafts control stays hidden when there are no unsubmitted drafts");
    assert.doesNotMatch(sidebarText || "", /Review items/, "sidebar no longer uses the old panel title");
    assert.match(sidebarText || "", /Round 1 needs a text update/, "sidebar contains the latest global conversation");
    assert.equal(await page.locator("#review-loop-panel .review-loop-index-list, #review-loop-panel .review-loop-index-item").count(), 0, "inline comments never reappear as a sidebar index");
    assert.equal(await page.locator("#review-loop-panel [data-review-comment-id^='c-']").count(), 0, "line comments never appear in the sidebar, including unanchored and resolved comments");
    assert.match(await page.locator("#review-loop-panel .review-loop-meta").textContent() || "", /6 open · 0 resolved/, "header keeps the total unresolved count rather than sidebar row count");
    assert.equal(await page.locator("#review-loop-panel .review-loop-quote").count(), 0, "sidebar never renders source quote blocks");
    assert.equal(await page.locator("#review-loop-panel .review-loop-conversation[data-review-comment-id='r-1'] .review-loop-reply-form").count(), 1, "latest global conversation has a reply editor");
    assert.equal(await page.locator("#review-loop-panel .review-loop-conversation textarea").count(), 1, "global conversation accepts multiline replies");
    assert.equal(await page.locator("#review-loop-panel .review-loop-conversation.review-loop-sidebar-card").count(), 0, "global conversation uses the sidebar itself instead of a nested card shell");
    const inlineLayout = await page.evaluate(() => {
      const panel = document.querySelector<HTMLElement>("#review-loop-panel");
      const inline = document.querySelector<HTMLElement>(".review-loop-inline");
      const thread = inline?.querySelector<HTMLElement>(".review-loop-thread");
      if (!panel || !inline || !thread) return null;
      const panelStyle = getComputedStyle(panel);
      const panelRect = panel.getBoundingClientRect();
      return {
        width: Math.round(panelRect.width),
        position: panelStyle.position,
        overflowY: panelStyle.overflowY,
        columnLefts: (() => {
          const left = (el: Element | null | undefined) => (el ? Math.round(el.getBoundingClientRect().left) : -1);
          return {
            file: left(inline.querySelector(".review-loop-comment-head strong")),
            speaker: left(inline.querySelector(".review-loop-thread-line > span")),
          };
        })(),
        resolve: (() => {
          const card = inline.querySelector(".review-loop-comment");
          const head = inline.querySelector(".review-loop-comment-head");
          const thread = inline.querySelector(".review-loop-thread");
          const actions = inline.querySelector(".review-loop-thread-actions");
          const button = inline.querySelector(".review-loop-resolve");
          const reply = inline.querySelector(".review-loop-reply-form");
          if (!card || !head || !thread || !actions || !button || !reply) return null;
          const children = Array.from(card.children);
          return {
            height: Math.round(button.getBoundingClientRect().height),
            label: button.textContent?.trim() || "",
            inHeader: head.contains(button),
            threadIndex: children.indexOf(thread),
            actionsIndex: children.indexOf(actions),
            replyIndex: children.indexOf(reply),
          };
        })(),
      };
    });
    assert.ok(inlineLayout, "review loop inline layout is available");
    assert.ok((inlineLayout?.width || 0) >= 280 && (inlineLayout?.width || 0) <= 320, "review sidebar keeps the specified fixed width");
    assert.equal(inlineLayout?.position, "fixed", "global conversation is a fixed bottom-right chat");
    assert.equal(inlineLayout?.overflowY, "hidden", "the fixed chat shell never scrolls the reply form away");
    assert.equal(
      inlineLayout?.columnLefts.speaker,
      inlineLayout?.columnLefts.file,
      "inline thread starts on the same column as its file name",
    );
    assert.equal(inlineLayout?.resolve?.height, 28, "Resolve conversation uses the same full-height control as reply actions");
    assert.equal(inlineLayout?.resolve?.label, "Resolve conversation", "Resolve conversation uses GitHub's full action label");
    assert.equal(inlineLayout?.resolve?.inHeader, false, "Resolve conversation is not squeezed into the file header");
    assert.ok(
      (inlineLayout?.resolve?.threadIndex ?? -1) < (inlineLayout?.resolve?.actionsIndex ?? -1)
        && (inlineLayout?.resolve?.actionsIndex ?? -1) < (inlineLayout?.resolve?.replyIndex ?? -1),
      "Resolve conversation appears after the thread and before the reply editor",
    );
    assert.equal(await page.locator(".review-loop-inline .review-loop-quote").count(), 0, "inline threads omit redundant source quotes");
    const firstInline = page.locator(".review-loop-inline[data-review-comment-id='c-1-1']");
    assert.match(await firstInline.textContent() || "", /Please update this line/, "human message is visible next to its target");
    assert.match(await firstInline.textContent() || "", /I will revise it/, "agent reply remains in the same inline thread");
    assert.equal(await firstInline.locator(".review-loop-reply-form").count(), 1, "an unresolved inline thread has its own reply editor");
    const scrollBeforeInlineWidgetClick = await page.evaluate(() => ({
      window: scrollY,
      preview: document.querySelector<HTMLElement>(".md-left")?.scrollTop || 0,
    }));
    await firstInline.locator(".review-loop-thread").click();
    assert.equal(await page.locator(".yunomi-inline-comment-editor").count(), 0, "clicking an existing inline conversation does not open a separate new-comment editor");
    await firstInline.locator("textarea").click();
    assert.equal(await page.locator(".yunomi-inline-comment-editor").count(), 0, "clicking an existing inline reply form does not open a separate new-comment editor");
    assert.equal(
      await page.evaluate(() => document.activeElement?.getAttribute("aria-label")),
      "Reply to this conversation",
      "the existing inline reply form keeps focus",
    );
    assert.equal(
      await firstInline.locator("textarea").evaluate((textarea) => getComputedStyle(textarea).outlineOffset),
      "2px",
      "the fixed-chat focus treatment does not change inline conversation controls",
    );
    assert.deepEqual(
      await page.evaluate(() => ({
        window: scrollY,
        preview: document.querySelector<HTMLElement>(".md-left")?.scrollTop || 0,
      })),
      scrollBeforeInlineWidgetClick,
      "clicking an existing inline reply form does not move either scroll position",
    );
    await firstInline.locator("textarea").fill("Human follow-up inside the inline thread");
    await firstInline.locator("input[type='file']").setInputFiles({
      name: "inline-reply-proof.png",
      mimeType: "image/png",
      buffer: readFileSync(IMAGE),
    });
    await firstInline.locator(".review-loop-reply-preview img").waitFor({ state: "visible" });
    await firstInline.locator("textarea").press(process.platform === "darwin" ? "Meta+Enter" : "Control+Enter");
    await page.waitForFunction(() => document.querySelector(".review-loop-inline[data-review-comment-id='c-1-1']")?.textContent?.includes("Human follow-up inside the inline thread"), undefined, { timeout: 3000 });
    assert.equal(await page.locator("#submit-modal.visible").count(), 0, "Cmd/Ctrl+Enter in an inline reply sends that reply without opening Submit");
    await page.waitForSelector(".review-loop-inline[data-review-comment-id='c-1-1'] .review-loop-conversation-image", { timeout: 3000 });
    const reviewAfterInlineReply = JSON.parse(readFileSync(join(REVIEW_DIR, "review.json"), "utf-8"));
    const savedInlineReply = reviewAfterInlineReply.comments.find((comment: { id: string }) => comment.id === "c-1-1")?.replies.at(-1);
    assert.equal(savedInlineReply?.text, "Human follow-up inside the inline thread", "the inline reply persists on the line comment");
    assert.equal(savedInlineReply?.attachments?.length, 1, "the inline reply persists its image");
    assert.match(
      readFileSync(NOTIFY_LOG, "utf-8"),
      /\[yunomi\] conversation reply id=c-1-1 round=2[\s\S]*human: Human follow-up inside the inline thread[\s\S]*reply with: yunomi reply c-1-1 <text>/,
      "a human inline reply immediately notifies Herdr with the exact comment id",
    );
    const notificationCountBeforeInlineAgent = (readFileSync(NOTIFY_LOG, "utf-8").match(/\[yunomi\] conversation reply/g) || []).length;
    const inlineAgentFollowUp = await request(port, "POST", "/reply-comment", JSON.stringify({ id: "c-1-1", text: "Agent follow-up in the inline thread", author: "agent" }));
    assert.equal(inlineAgentFollowUp.status, 200, "the AI reply API accepts the inline comment id");
    await page.waitForFunction(() => document.querySelector(".review-loop-inline[data-review-comment-id='c-1-1']")?.textContent?.includes("Agent follow-up in the inline thread"), undefined, { timeout: 3000 });
    assert.match(await firstInline.textContent() || "", /Agent follow-up in the inline thread/, "the AI follow-up appears in the same inline thread");
    assert.equal(
      (readFileSync(NOTIFY_LOG, "utf-8").match(/\[yunomi\] conversation reply/g) || []).length,
      notificationCountBeforeInlineAgent,
      "an AI inline reply does not notify the agent back",
    );
    const editorLayoutContext = await browser.newContext({ viewport: { width: 1280, height: 900 } });
    try {
      const editorLayoutPage = await editorLayoutContext.newPage();
      await editorLayoutPage.goto(`http://127.0.0.1:${port}/`, { waitUntil: "domcontentloaded" });
      await editorLayoutPage.waitForSelector("#review-loop-panel .review-loop-conversation", { timeout: 10000 });
      await editorLayoutPage.locator("#md-preview ol > li[data-source-line]").filter({ hasText: "Ordered next" }).click();
      await editorLayoutPage.waitForSelector(".yunomi-inline-comment-editor #comment-input", { state: "visible" });
      const newCommentEditorLayout = async () => editorLayoutPage.evaluate(() => {
        const editor = document.querySelector<HTMLElement>("#md-preview .yunomi-inline-comment-editor");
        const panel = document.querySelector<HTMLElement>("#review-loop-panel");
        const cancel = editor?.querySelector<HTMLElement>('[data-action="cancel"]');
        if (!editor || !panel || !cancel) return null;
        const editorBox = editor.getBoundingClientRect();
        const panelBox = panel.getBoundingClientRect();
        return {
          editorRight: Math.round(editorBox.right),
          panelLeft: Math.round(panelBox.left),
          separation: Math.round(panelBox.left - editorBox.right),
          marginRight: getComputedStyle(editor).marginRight,
          cancelText: cancel.textContent?.trim() || "",
          cancelIsIconOnly: cancel.classList.contains("icon-only"),
          horizontalOverflow: document.documentElement.scrollWidth > document.documentElement.clientWidth,
          actionsFit: Array.from(editor.querySelectorAll<HTMLElement>(".yunomi-inline-comment-actions button"))
            .every(button => button.getBoundingClientRect().right <= editorBox.right),
        };
      });
      const desktopEditorLayout = await newCommentEditorLayout();
      assert.ok(desktopEditorLayout, "new inline comment editor layout is available");
      assert.ok((desktopEditorLayout?.separation ?? -1) >= 0, "new inline comment editor stays clear of the expanded global chat");
      assert.equal(desktopEditorLayout?.marginRight, "308px", "editor clearance reuses the existing 300px sidebar width and 8px offset");
      assert.equal(desktopEditorLayout?.cancelText, "Cancel", "new inline comments use a normal Cancel action");
      assert.equal(desktopEditorLayout?.cancelIsIconOnly, false, "the Cancel action is not rendered as the old x icon");
      assert.equal(desktopEditorLayout?.horizontalOverflow, false, "the narrowed editor does not create page-level horizontal overflow");
      assert.equal(desktopEditorLayout?.actionsFit, true, "all inline comment actions remain inside the narrowed editor");
      await editorLayoutPage.setViewportSize({ width: 980, height: 900 });
      const narrowDesktopEditorLayout = await newCommentEditorLayout();
      assert.ok((narrowDesktopEditorLayout?.separation ?? -1) >= 0, "the editor stays clear of chat immediately above the mobile breakpoint");
      assert.equal(narrowDesktopEditorLayout?.horizontalOverflow, false, "the breakpoint-adjacent editor keeps the page width stable");
      assert.equal(narrowDesktopEditorLayout?.actionsFit, true, "the breakpoint-adjacent editor keeps every action clickable");
      await editorLayoutPage.locator('.yunomi-inline-comment-editor [data-action="cancel"]').click();
      assert.equal(await editorLayoutPage.locator(".yunomi-inline-comment-editor").count(), 0, "Cancel closes the new inline comment editor");
    } finally {
      await editorLayoutContext.close();
    }
    // The card is inserted after the image's block container, not inside it:
    // a <div> inside a <p> is invalid HTML and browsers would split the <p>.
    const imageInline = page.locator("#md-preview :is(p, figure):has(img[alt='Review image']) + .review-loop-inline");
    assert.equal(await imageInline.count(), 1, "image comments render immediately after the image block");
    const imageInlinePlacement = await page.evaluate(() => {
      const img = document.querySelector<HTMLImageElement>("#md-preview img[alt='Review image']");
      const inline = img?.closest("p, figure")?.nextElementSibling;
      if (!img || !inline?.classList.contains("review-loop-inline")) return null;
      const imageBox = img.getBoundingClientRect();
      const inlineBox = inline.getBoundingClientRect();
      return { below: inlineBox.top >= imageBox.bottom - 1, gap: Math.round(inlineBox.top - imageBox.bottom) };
    });
    assert.ok(imageInlinePlacement?.below, `image thread sits directly below the rendered image (gap=${imageInlinePlacement?.gap}px)`);
    const headingInline = page.locator("details.heading-toggle > .toggle-content > .review-loop-inline[data-review-comment-id='c-1-5']");
    assert.equal(await headingInline.count(), 1, "heading comments render in the heading content instead of inside its summary row");
    const headingLayout = await page.evaluate(() => {
      const details = document.querySelector<HTMLElement>("details.heading-toggle");
      const heading = details?.querySelector<HTMLElement>(":scope > summary .md-heading-toggle");
      const inline = details?.querySelector<HTMLElement>(":scope > .toggle-content > .review-loop-inline[data-review-comment-id='c-1-5']");
      if (!details || !heading || !inline) return null;
      return {
        headingWidth: Math.round(heading.getBoundingClientRect().width),
        detailsWidth: Math.round(details.getBoundingClientRect().width),
      };
    });
    assert.ok(
      headingLayout && headingLayout.headingWidth >= headingLayout.detailsWidth * 0.8,
      `heading keeps its full row width beside an inline thread (${headingLayout?.headingWidth}/${headingLayout?.detailsWidth})`,
    );
    assert.doesNotMatch(await imageInline.textContent() || "", /!\[Review image\]\(review-image\.png\)/, "image inline thread never repeats raw Markdown as a quote");
    assert.equal(await page.locator("#md-preview :is(ul,ol) > div.review-loop-inline").count(), 0, "a list never receives a raw div as a direct child");
    const listInline = page.locator(".review-loop-inline[data-review-comment-id='c-1-3']");
    assert.equal(await listInline.evaluate((inline) => inline.parentElement?.tagName), "LI", "list comments use an li wrapper around the inline card");
    assert.equal(await listInline.evaluate((inline) => inline.parentElement?.parentElement?.tagName), "UL", "the inline card holder stays inside the original unordered list");
    const orderedInline = page.locator(".review-loop-inline[data-review-comment-id='c-1-6']");
    assert.equal(await orderedInline.evaluate((inline) => inline.parentElement?.tagName), "LI", "ordered-list comments use an li wrapper around the inline card");
    assert.equal(await orderedInline.evaluate((inline) => inline.parentElement?.parentElement?.tagName), "OL", "the ordered inline card holder stays inside the original ordered list");
    assert.equal(await orderedInline.evaluate((inline) => inline.parentElement?.getAttribute("value")), "1", "the ordered inline card repeats the source item value so the following item remains number 2");
    const summaryInput = page.locator("#review-loop-panel .review-loop-conversation textarea");
    await summaryInput.click();
    const sidebarTextareaFocus = await summaryInput.evaluate((textarea) => {
      const conversation = textarea.closest<HTMLElement>(".review-loop-conversation");
      const body = textarea.closest<HTMLElement>(".review-loop-body");
      const textareaBox = textarea.getBoundingClientRect();
      const conversationBox = conversation?.getBoundingClientRect();
      const bodyBox = body?.getBoundingClientRect();
      const style = getComputedStyle(textarea);
      return {
        outlineWidth: style.outlineWidth,
        outlineOffset: style.outlineOffset,
        conversationOverflow: conversation ? getComputedStyle(conversation).overflow : "",
        bodyOverflow: body ? getComputedStyle(body).overflow : "",
        conversationHorizontalInset: conversationBox
          ? Math.round(Math.min(textareaBox.left - conversationBox.left, conversationBox.right - textareaBox.right))
          : -1,
        bodyHorizontalInset: bodyBox
          ? Math.round(Math.min(textareaBox.left - bodyBox.left, bodyBox.right - textareaBox.right))
          : -1,
      };
    });
    assert.deepEqual(
      sidebarTextareaFocus,
      {
        outlineWidth: "2px",
        outlineOffset: "-2px",
        conversationOverflow: "hidden",
        bodyOverflow: "hidden",
        conversationHorizontalInset: 0,
        bodyHorizontalInset: 0,
      },
      "the fixed-chat textarea keeps its full focus ring inside both clipping ancestors",
    );
    await page.keyboard.press("Tab");
    assert.deepEqual(
      await page.locator("#review-loop-panel .review-loop-reply-attach").evaluate((label) => {
        const style = getComputedStyle(label);
        return {
          activeClass: document.activeElement?.className || "",
          outlineWidth: style.outlineWidth,
          outlineOffset: style.outlineOffset,
        };
      }),
      {
        activeClass: "review-loop-reply-file",
        outlineWidth: "2px",
        outlineOffset: "-2px",
      },
      "the fixed-chat attachment control keeps its focus ring inside the clipping ancestors",
    );
    await page.keyboard.press("Tab");
    assert.deepEqual(
      await page.locator("#review-loop-panel .review-loop-reply-form button[type='submit']").evaluate((button) => {
        const style = getComputedStyle(button);
        return {
          activeTag: document.activeElement?.tagName || "",
          outlineWidth: style.outlineWidth,
          outlineOffset: style.outlineOffset,
        };
      }),
      {
        activeTag: "BUTTON",
        outlineWidth: "2px",
        outlineOffset: "-2px",
      },
      "the fixed-chat submit button keeps its focus ring inside the clipping ancestors",
    );
    await summaryInput.fill("Sidebar reply remains in the global conversation");
    const attachmentInput = page.locator("#review-loop-panel .review-loop-conversation input[type='file']");
    await attachmentInput.setInputFiles({
      name: "reply-proof.png",
      mimeType: "image/png",
      buffer: readFileSync(IMAGE),
    });
    await page.waitForSelector("#review-loop-panel .review-loop-reply-preview img", { timeout: 3000 });
    assert.equal(await page.locator("#review-loop-panel .review-loop-reply-preview img").count(), 1, "selected reply image is previewed before sending");
    await summaryInput.press(process.platform === "darwin" ? "Meta+Enter" : "Control+Enter");
    await page.waitForFunction(() => document.querySelector("#review-loop-panel")?.textContent?.includes("Sidebar reply remains in the global conversation"), undefined, { timeout: 3000 });
    assert.equal(await page.locator("#submit-modal.visible").count(), 0, "Cmd/Ctrl+Enter in the global conversation sends that reply without opening Submit");
    await page.waitForSelector("#review-loop-panel .review-loop-conversation-message .review-loop-conversation-image", { timeout: 3000 });
    const reviewAfterImageReply = JSON.parse(readFileSync(join(REVIEW_DIR, "review.json"), "utf-8"));
    const imageReply = reviewAfterImageReply.comments.find((comment: { id: string }) => comment.id === "r-1")?.replies.at(-1);
    assert.equal(imageReply?.text, "Sidebar reply remains in the global conversation", "image reply keeps its text");
    assert.equal(imageReply?.attachments?.length, 1, "image reply stores one attachment reference");
    const attachmentRef = String(imageReply?.attachments?.[0] || "");
    assert.match(attachmentRef, /^\.\/comment-attachments\/r-1-reply-\d+\.png$/, "image reply uses a review-relative attachment reference");
    const attachmentPath = join(REVIEW_DIR, attachmentRef.replace(/^\.\//, ""));
    assert.equal(existsSync(attachmentPath), true, "reply attachment file exists in the review directory");
    assert.equal((await request(port, "GET", attachmentRef.replace(/^\./, ""))).status, 200, "saved reply attachment is served to the conversation");
    const notificationAfterImage = readFileSync(NOTIFY_LOG, "utf-8");
    assert.match(notificationAfterImage, /human: Sidebar reply remains in the global conversation/, "the image reply text is sent immediately through the configured notification path");
    assert.match(notificationAfterImage, new RegExp(`attachment: ${attachmentPath.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}`), "the notification gives the AI the absolute saved image path");
    const notificationCountBeforeGlobalAgent = (readFileSync(NOTIFY_LOG, "utf-8").match(/\[yunomi\] conversation reply/g) || []).length;
    const agentConversationReply = await request(port, "POST", "/reply-comment", JSON.stringify({ id: "r-1", text: "Agent reply through the yunomi API", author: "agent" }));
    assert.equal(agentConversationReply.status, 200);
    await page.waitForFunction(() => document.querySelector("#review-loop-panel")?.textContent?.includes("Agent reply through the yunomi API"), undefined, { timeout: 3000 });
    const longAgentConversationReply = await request(port, "POST", "/reply-comment", JSON.stringify({
      id: "r-1",
      text: Array.from({ length: 30 }, (_, index) => `Long conversation line ${index + 1}`).join("\n"),
      author: "agent",
    }));
    assert.equal(longAgentConversationReply.status, 200);
    await page.waitForFunction(() => document.querySelector("#review-loop-panel")?.textContent?.includes("Long conversation line 30"), undefined, { timeout: 3000 });
    const fixedComposerLayout = await page.evaluate(() => {
      const panel = document.querySelector<HTMLElement>("#review-loop-panel");
      const stream = panel?.querySelector<HTMLElement>(".review-loop-conversation-stream");
      const form = panel?.querySelector<HTMLElement>(".review-loop-conversation > .review-loop-reply-form");
      if (!panel || !stream || !form) return null;
      const panelBox = panel.getBoundingClientRect();
      const formBox = form.getBoundingClientRect();
      return {
        streamOverflowY: getComputedStyle(stream).overflowY,
        streamScrolls: stream.scrollHeight > stream.clientHeight,
        formTop: Math.round(formBox.top),
        formBottom: Math.round(formBox.bottom),
        panelTop: Math.round(panelBox.top),
        panelBottom: Math.round(panelBox.bottom),
      };
    });
    assert.ok(fixedComposerLayout?.streamScrolls, "long global conversation scrolls inside the message history");
    assert.equal(fixedComposerLayout?.streamOverflowY, "auto", "only the global conversation history owns vertical scrolling");
    assert.ok(
      (fixedComposerLayout?.formTop ?? -1) >= (fixedComposerLayout?.panelTop ?? Number.MAX_SAFE_INTEGER)
        && (fixedComposerLayout?.formBottom ?? Number.MAX_SAFE_INTEGER) <= (fixedComposerLayout?.panelBottom ?? -1),
      "the global reply form remains fully visible while previous messages overflow",
    );
    assert.equal(
      (readFileSync(NOTIFY_LOG, "utf-8").match(/\[yunomi\] conversation reply/g) || []).length,
      notificationCountBeforeGlobalAgent,
      "agent API replies do not notify the agent back",
    );
    await page.reload({ waitUntil: "domcontentloaded" });
    await page.waitForSelector("#review-loop-panel .review-loop-conversation-image", { timeout: 3000 });
    assert.match(await page.locator("#review-loop-panel .review-loop-conversation").textContent() || "", /Sidebar reply remains in the global conversation/, "human conversation text survives reload");
    assert.match(await page.locator("#review-loop-panel .review-loop-conversation").textContent() || "", /Agent reply through the yunomi API/, "agent API reply survives reload");
    assert.equal(await page.locator("#review-loop-panel .review-loop-conversation-image").count(), 1, "conversation image survives reload");
    assert.equal(await page.locator("#review-loop-panel .review-loop-conversation-head").count(), 0, "global chat omits the redundant Conversation heading");
    assert.equal(await page.locator("#review-loop-panel .review-loop-conversation .review-loop-resolve").count(), 0, "global chat has no per-thread resolve action");
    assert.equal(await page.locator("#review-loop-panel .review-loop-conversation .review-loop-reply-form").count(), 1, "global chat remains replyable until review approval");
    assert.equal(await page.locator("#review-loop-panel .review-loop-new-global").count(), 0, "an existing global chat continues as one review conversation");
    const ignoredGlobalResolve = await request(port, "POST", "/resolve-comment", JSON.stringify({ id: "r-1" }));
    assert.equal(ignoredGlobalResolve.status, 200, "legacy resolve requests remain harmless");
    const replyAfterIgnoredResolve = await request(port, "POST", "/reply-comment", JSON.stringify({ id: "r-1", text: "still one review conversation", author: "human" }));
    assert.equal(replyAfterIgnoredResolve.status, 200, "global chat remains replyable after a legacy resolve request");
    const cliReply = spawnSync(process.execPath, [SERVER_JS, "reply", "r-1", "CLI continues the review conversation"], {
      cwd: TMP_DIR,
      env,
      encoding: "utf-8",
    });
    assert.equal(cliReply.status, 0, "yunomi reply continues the global review conversation");
    const reviewAfterContinuedReplies = JSON.parse(readFileSync(join(REVIEW_DIR, "review.json"), "utf-8"));
    const continuedThread = reviewAfterContinuedReplies.comments.find((comment: { id: string }) => comment.id === "r-1");
    assert.equal(continuedThread?.status, "unresolved", "global conversation cannot become resolved independently");
    assert.equal(continuedThread?.replies.at(-1)?.text, "CLI continues the review conversation", "CLI reply persists in the same global conversation");
    await page.reload({ waitUntil: "domcontentloaded" });
    await page.waitForSelector("#review-loop-panel .review-loop-conversation[data-review-comment-id='r-1'] .review-loop-conversation-image", { timeout: 3000 });
    assert.match(await page.locator("#review-loop-panel .review-loop-conversation").textContent() || "", /CLI continues the review conversation/, "continued global conversation survives reload");
    assert.equal(await page.locator("#review-loop-panel .review-loop-conversation-image").count(), 1, "new global comment image survives reload");
    assert.match(await page.locator("#review-loop-panel .review-loop-meta").textContent() || "", /6 open · 0 resolved/, "global conversation does not affect actionable totals");
    assert.equal(await page.locator(".review-loop-inline").count(), 5, "global conversation updates leave anchored inline threads in place");
    assert.equal(await page.locator("#review-loop-panel [data-review-comment-id^='c-']").count(), 0, "the sidebar remains free of line comments after global conversation updates");
    const previewWidthBeforeMinimize = await page.evaluate(() => document.querySelector<HTMLElement>(".md-left")?.getBoundingClientRect().width || 0);
    await page.locator("#review-loop-panel .review-loop-sidebar-toggle").click();
    await page.waitForSelector("#review-loop-panel.review-loop-sidebar-collapsed");
    assert.equal(await page.locator("#review-loop-panel").evaluate((panel) => Math.round(panel.getBoundingClientRect().width)), 40, "collapsed sidebar becomes an icon-only strip");
    assert.deepEqual(
      await page.locator("#review-loop-panel").evaluate((panel) => {
        const button = panel.querySelector<HTMLElement>(".review-loop-sidebar-toggle");
        const buttonRect = button?.getBoundingClientRect();
        const style = getComputedStyle(panel);
        return {
          borderWidth: style.borderWidth,
          backgroundColor: style.backgroundColor,
          boxShadow: style.boxShadow,
          overflowX: style.overflowX,
          overflowY: style.overflowY,
          panelHeight: Math.round(panel.getBoundingClientRect().height),
          buttonWidth: Math.round(buttonRect?.width || 0),
          buttonHeight: Math.round(buttonRect?.height || 0),
        };
      }),
      {
        borderWidth: "0px",
        backgroundColor: "rgba(0, 0, 0, 0)",
        boxShadow: "none",
        overflowX: "hidden",
        overflowY: "hidden",
        panelHeight: 40,
        buttonWidth: 40,
        buttonHeight: 40,
      },
      "collapsed chat has one 40px button frame without an outer border, shadow, or scrollbar",
    );
    assert.equal(
      await page.locator(".md-left").evaluate((left) => left.getBoundingClientRect().width),
      previewWidthBeforeMinimize,
      "minimizing the fixed chat does not reflow the preview",
    );
    await page.reload({ waitUntil: "domcontentloaded" });
    await page.waitForSelector("#review-loop-panel.review-loop-sidebar-collapsed");
    assert.match(
      await page.locator("#review-loop-panel .review-loop-sidebar-toggle").getAttribute("aria-label") || "",
      /6 open · 0 resolved/,
      "collapsed chat keeps the total unresolved count available to assistive technology across reload",
    );
    await page.locator("#review-loop-panel .review-loop-sidebar-toggle").click();
    await page.waitForFunction(() => !document.querySelector("#review-loop-panel")?.classList.contains("review-loop-sidebar-collapsed"));
    assert.equal(
      await page.locator("#review-loop-panel .review-loop-sidebar-toggle").textContent(),
      "−",
      "expanded chat uses a familiar minimize symbol",
    );

    const themeMenuState = await page.evaluate(() => {
      const root = document.documentElement;
      const mode = document.querySelector<HTMLButtonElement>("#theme-toggle");
      const arrow = document.querySelector<HTMLButtonElement>("#theme-menu-toggle");
      const menu = document.querySelector<HTMLElement>("#theme-menu");
      const history = document.querySelector<HTMLElement>("#history-toggle");
      if (!mode || !arrow || !menu || !history) return null;
      const modeHeight = Math.round(mode.getBoundingClientRect().height);
      const arrowHeight = Math.round(arrow.getBoundingClientRect().height);
      const historyHeight = Math.round(history.getBoundingClientRect().height);
      mode.click();
      const menuAfterModeClick = !menu.hidden;
      arrow.click();
      const menuAfterArrowClick = !menu.hidden;
      const expandedAfterArrowClick = arrow.getAttribute("aria-expanded");
      const tokyoButton = menu.querySelector<HTMLButtonElement>('[data-color-scheme="tokyo"]');
      tokyoButton?.click();
      return {
        modeHeight,
        arrowHeight,
        historyHeight,
        menuAfterModeClick,
        menuAfterArrowClick,
        expandedAfterArrowClick,
        scheme: root.getAttribute("data-color-scheme"),
        storedScheme: localStorage.getItem("yunomi:color-scheme"),
        hiddenAfterSelect: menu.hidden,
        selectCount: menu.querySelectorAll("select").length,
      };
    });
    assert.ok(themeMenuState, "theme menu is present");
    assert.equal(themeMenuState?.modeHeight, themeMenuState?.arrowHeight, "theme mode and scheme arrow buttons share the same height");
    assert.equal(themeMenuState?.modeHeight, themeMenuState?.historyHeight, "theme segmented control matches adjacent header controls");
    assert.equal(themeMenuState?.menuAfterModeClick, false, "light/dark button does not open the color scheme menu");
    assert.equal(themeMenuState?.menuAfterArrowClick, true, "only the right arrow opens the color scheme menu");
    assert.equal(themeMenuState?.expandedAfterArrowClick, "true", "arrow button exposes expanded state while the menu is open");
    assert.equal(themeMenuState?.scheme, "tokyo", "color scheme button changes the page scheme");
    assert.equal(themeMenuState?.storedScheme, "tokyo", "selected color scheme is persisted");
    assert.equal(themeMenuState?.hiddenAfterSelect, true, "scheme menu closes after selection");
    assert.equal(themeMenuState?.selectCount, 0, "scheme menu uses buttons rather than a pulldown select");

    for (const deviceWidth of [390, 430]) {
      const portraitContext = await browser.newContext({
        viewport: { width: 980, height: 844 },
        screen: { width: deviceWidth, height: 844 },
        isMobile: true,
      });
      try {
        const portraitPage = await portraitContext.newPage();
        await portraitPage.goto(`http://127.0.0.1:${port}/`, { waitUntil: "domcontentloaded" });
        await portraitPage.waitForSelector("#review-loop-panel .review-loop-conversation", {
          state: "attached",
          timeout: 10000,
        });
        const portraitLayout = await portraitPage.evaluate(() => {
          const rect = (selector: string) => {
            const element = document.querySelector<HTMLElement>(selector);
            if (!element) return null;
            const box = element.getBoundingClientRect();
            return {
              left: Math.round(box.left),
              right: Math.round(box.right),
              top: Math.round(box.top),
              bottom: Math.round(box.bottom),
              display: getComputedStyle(element).display,
            };
          };
          const preview = document.querySelector<HTMLElement>(".md-left");
          return {
            innerWidth,
            screenWidth: screen.width,
            desktopLayoutWidth: matchMedia("(max-width: 960px)").matches,
            phoneDeviceWidth: matchMedia("(max-device-width: 960px)").matches,
            horizontalOverflow: document.body.scrollWidth > innerWidth,
            header: rect("header"),
            wrap: rect(".wrap"),
            preview: rect(".md-left"),
            firstHeading: rect(".md-preview h1, .md-preview h2"),
            sidebar: rect("#review-loop-panel"),
            media: rect(".media-sidebar"),
            submit: rect("#send-and-exit"),
            previewScrollTop: preview?.scrollTop ?? -1,
          };
        });
        assert.equal(portraitLayout.innerWidth, 980, "portrait regression keeps the browser's forced desktop-site layout width");
        assert.equal(portraitLayout.screenWidth, deviceWidth, "portrait regression exposes the physical phone width");
        assert.equal(portraitLayout.desktopLayoutWidth, false, "desktop-site mode does not satisfy the ordinary viewport breakpoint");
        assert.equal(portraitLayout.phoneDeviceWidth, true, "physical phone width activates the device breakpoint");
        assert.equal(portraitLayout.horizontalOverflow, false, `portrait ${deviceWidth}px has no page-level horizontal overflow`);
        assert.equal(portraitLayout.sidebar?.display, "grid", `portrait ${deviceWidth}px keeps the minimized review chat visible`);
        assert.equal(
          (portraitLayout.sidebar?.right ?? 0) - (portraitLayout.sidebar?.left ?? 0),
          40,
          `portrait ${deviceWidth}px starts with the existing compact chat width`,
        );
        assert.equal(portraitLayout.media?.display, "none", `portrait ${deviceWidth}px removes the desktop thumbnail rail`);
        assert.ok(
          (portraitLayout.wrap?.top ?? -1) >= (portraitLayout.header?.bottom ?? Number.MAX_SAFE_INTEGER),
          `portrait ${deviceWidth}px content begins below the complete header`,
        );
        assert.ok(
          (portraitLayout.firstHeading?.top ?? -1) >= (portraitLayout.preview?.top ?? Number.MAX_SAFE_INTEGER),
          `portrait ${deviceWidth}px shows the report title inside the preview`,
        );
        assert.equal(portraitLayout.previewScrollTop, 0, `portrait ${deviceWidth}px opens the preview at its first line`);
        assert.ok(
          (portraitLayout.submit?.left ?? -1) >= 0 &&
            (portraitLayout.submit?.right ?? Number.MAX_SAFE_INTEGER) <= portraitLayout.innerWidth,
          `portrait ${deviceWidth}px keeps Submit completely inside the viewport`,
        );
        await portraitPage.locator("#review-loop-panel .review-loop-sidebar-toggle").click();
        const openConversation = await portraitPage.evaluate(() => {
          const panel = document.querySelector<HTMLElement>("#review-loop-panel");
          const box = panel?.getBoundingClientRect();
          return {
            collapsed: panel?.classList.contains("review-loop-sidebar-collapsed"),
            display: panel ? getComputedStyle(panel).display : "",
            left: Math.round(box?.left || -1),
            right: Math.round(box?.right || -1),
            top: Math.round(box?.top || -1),
            bottom: Math.round(box?.bottom || -1),
            viewportWidth: innerWidth,
            viewportHeight: innerHeight,
            hasConversation: Boolean(panel?.querySelector(".review-loop-conversation")),
            background: panel ? getComputedStyle(panel).backgroundColor : "",
          };
        });
        assert.equal(openConversation.collapsed, false, `portrait ${deviceWidth}px expands from the fixed chat control`);
        assert.equal(openConversation.display, "grid", `portrait ${deviceWidth}px opens the saved review conversation`);
        assert.equal(openConversation.hasConversation, true, `portrait ${deviceWidth}px keeps the persisted conversation readable`);
        assert.notEqual(openConversation.background, "transparent", `portrait ${deviceWidth}px conversation has a reading surface`);
        assert.doesNotMatch(
          openConversation.background,
          /rgba\(|\//,
          `portrait ${deviceWidth}px conversation reading surface is opaque`,
        );
        assert.ok(
          openConversation.left >= 0 &&
            openConversation.right <= openConversation.viewportWidth &&
            openConversation.top >= 0 &&
            openConversation.bottom <= openConversation.viewportHeight,
          `portrait ${deviceWidth}px keeps the opened conversation inside the viewport`,
        );
        assert.ok(
          openConversation.bottom - openConversation.top <= Math.ceil(openConversation.viewportHeight * 0.6),
          `portrait ${deviceWidth}px keeps the opened conversation to the existing 60% chat-height limit`,
        );
        await portraitPage.locator("#review-loop-panel .review-loop-sidebar-toggle").click();
        assert.equal(
          await portraitPage.locator("#review-loop-panel").evaluate((panel) =>
            panel.classList.contains("review-loop-sidebar-collapsed")
          ),
          true,
          `portrait ${deviceWidth}px closes the conversation from its existing sidebar control`,
        );
      } finally {
        await portraitContext.close();
      }
    }

    const themeContrastChecks = await page.evaluate(() => {
      const root = document.documentElement;
      const panel = document.querySelector<HTMLElement>("#review-loop-panel");
      const schemes = ["primer", "tokyo", "catppuccin", "one-dark", "solarized", "gruvbox"];
      const themes = ["light", "dark"];
      return themes.flatMap((theme) => schemes.map((scheme) => {
        root.setAttribute("data-theme", theme);
        root.setAttribute("data-color-scheme", scheme);
        const style = getComputedStyle(root);
        return {
          theme,
          scheme,
          text: style.getPropertyValue("--text").trim(),
          muted: style.getPropertyValue("--muted").trim(),
          textInverse: style.getPropertyValue("--text-inverse").trim(),
          accent: style.getPropertyValue("--accent").trim(),
          accentStrong: style.getPropertyValue("--accent-strong").trim(),
          accent2: style.getPropertyValue("--accent-2").trim(),
          panel: style.getPropertyValue("--panel-solid").trim(),
        };
      }));
    });
    const rgb = (value: string): [number, number, number] => {
      if (value.startsWith("#") && value.length === 7) {
        return [
          Number.parseInt(value.slice(1, 3), 16),
          Number.parseInt(value.slice(3, 5), 16),
          Number.parseInt(value.slice(5, 7), 16),
        ];
      }
      const parts = value.match(/[\d.]+/g)?.slice(0, 3).map(Number) || [0, 0, 0];
      if (value.startsWith("color(srgb")) {
        return [
          Math.round((parts[0] || 0) * 255),
          Math.round((parts[1] || 0) * 255),
          Math.round((parts[2] || 0) * 255),
        ];
      }
      return [parts[0] || 0, parts[1] || 0, parts[2] || 0];
    };
    const channel = (value: number) => {
      const normalized = value / 255;
      return normalized <= 0.03928 ? normalized / 12.92 : Math.pow((normalized + 0.055) / 1.055, 2.4);
    };
    const luminance = ([r, g, b]: [number, number, number]) => 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b);
    const contrast = (fg: string, bg: string) => {
      const light = Math.max(luminance(rgb(fg)), luminance(rgb(bg)));
      const dark = Math.min(luminance(rgb(fg)), luminance(rgb(bg)));
      return (light + 0.05) / (dark + 0.05);
    };
    assert.equal(themeContrastChecks.length, 12, "six color schemes must exist in both light and dark modes");
    for (const check of themeContrastChecks) {
      const pairs = [
        ["text/panel", check.text, check.panel],
        ["muted/panel", check.muted, check.panel],
        ["accent-strong/panel", check.accentStrong, check.panel],
        ["text-inverse/accent", check.textInverse, check.accent],
        ["text-inverse/accent-2", check.textInverse, check.accent2],
      ] as const;
      for (const [label, foreground, background] of pairs) {
        const ratio = contrast(foreground, background);
        assert.ok(ratio >= 4.5, `${check.scheme}/${check.theme} ${label} contrast must stay readable; got ${ratio.toFixed(2)} (${foreground} on ${background})`);
      }
    }

    const firstResolve = page.locator(".review-loop-inline .review-loop-resolve").first();
    await firstResolve.scrollIntoViewIfNeeded();
    const scrollBeforeResolve = await page.locator(".md-left").evaluate((element) => element.scrollTop);
    await firstResolve.click();
    await page.waitForFunction(() => document.querySelector(".review-loop-meta")?.textContent?.includes("5 open"));
    assert.equal(
      await page.locator(".md-left").evaluate((element) => element.scrollTop),
      scrollBeforeResolve,
      "resolving an inline thread updates in place without moving the preview scroll position",
    );
    assert.match(
      await page.locator("#review-loop-panel .review-loop-meta").textContent() || "",
      /5 open · 1 resolved/,
      "resolving an inline thread immediately decrements the visible open count",
    );

    await page.click("#send-and-exit");
    const blockedApproval = await page.evaluate(() => {
      const modal = document.querySelector<HTMLElement>("#submit-modal");
      const approve = document.querySelector<HTMLButtonElement>("#modal-approve");
      const reason = document.querySelector<HTMLElement>("#approve-blocked-reason");
      if (!modal || !approve || !reason) return null;
      const style = getComputedStyle(approve);
      return {
        modalVisible: modal.classList.contains("visible"),
        disabled: approve.disabled,
        describedBy: approve.getAttribute("aria-describedby"),
        reasonVisible: getComputedStyle(reason).display !== "none",
        reasonText: reason.textContent,
        cursor: style.cursor,
        opacity: Number.parseFloat(style.opacity),
      };
    });
    assert.ok(blockedApproval, "blocked approval state is available");
    assert.equal(blockedApproval?.modalVisible, true, "submit modal opens while approval is blocked");
    assert.equal(blockedApproval?.disabled, true, "approve is disabled while review items remain unresolved");
    assert.equal(blockedApproval?.describedBy, "approve-blocked-reason", "approve exposes its blocked reason to assistive technology");
    assert.equal(blockedApproval?.reasonVisible, true, "blocked approval reason is visible");
    assert.match(blockedApproval?.reasonText || "", /5 review items remain unresolved/, "blocked reason includes the unresolved count");
    assert.equal(blockedApproval?.cursor, "not-allowed", "blocked approve uses a disabled cursor");
    assert.ok((blockedApproval?.opacity || 1) < 1, "blocked approve is visually distinct from an enabled action");

    await page.click("#review-unresolved-action");
    const recoveryNavigation = await page.evaluate(() => {
      const modal = document.querySelector<HTMLElement>("#submit-modal");
      const resolve = document.querySelector<HTMLElement>(".review-loop-inline .review-loop-resolve");
      const comment = resolve?.closest<HTMLElement>(".review-loop-comment");
      const rect = comment?.getBoundingClientRect();
      return {
        modalVisible: modal?.classList.contains("visible"),
        targetFocused: document.activeElement === comment,
        targetVisible: !!rect && rect.bottom > 0 && rect.top < window.innerHeight,
        inlinePresent: !!comment?.closest(".review-loop-inline"),
      };
    });
    assert.equal(recoveryNavigation.modalVisible, false, "recovery action closes the submit modal");
    assert.equal(recoveryNavigation.targetFocused, true, "recovery action focuses the first unresolved review item");
    assert.equal(recoveryNavigation.targetVisible, true, "recovery action brings the unresolved review item into view");
    assert.equal(recoveryNavigation.inlinePresent, true, "recovery action targets the first unresolved inline thread");

    const jaContext = await browser.newContext({ viewport: { width: 1280, height: 900 }, locale: "ja-JP" });
    try {
      const jaPage = await jaContext.newPage();
      await jaPage.goto(`http://127.0.0.1:${port}/`, { waitUntil: "domcontentloaded" });
      await jaPage.waitForSelector("#review-loop-panel .review-loop-conversation", { timeout: 10000 });
      const jaSidebarText = await jaPage.locator("#review-loop-panel").first().textContent();
      assert.match(jaSidebarText || "", /コメント/, "Japanese review loop sidebar uses the comments title");
      assert.doesNotMatch(jaSidebarText || "", /確認項目/, "Japanese review loop sidebar no longer exposes the old title");
      assert.match(jaSidebarText || "", /前回からの差分/, "Japanese sidebar diff label is concise");
      await jaPage.click("#send-and-exit");
      assert.match(await jaPage.locator("#approve-blocked-reason").textContent() || "", /未解決の確認項目が 5 件あるため、承認できません。/, "Japanese submit modal explains why approval is blocked");
      assert.equal(await jaPage.locator("#review-unresolved-action").textContent(), "未解決の確認項目を見る", "Japanese submit modal labels the recovery action");
    } finally {
      await jaContext.close().catch(() => {});
    }
  } finally {
    await browser.close().catch(() => {});
  }

  const sameRoundResubmit = await request(
    port,
    "POST",
    "/exit",
    JSON.stringify({ summary: "Replacement request in the same round", decision: "request_changes", action: "final_request_changes", comments: [] }),
  );
  assert.equal(sameRoundResubmit.status, 200);
  const reviewAfterSameRoundResubmit = JSON.parse(readFileSync(join(REVIEW_DIR, "review.json"), "utf-8"));
  const replacementThread = reviewAfterSameRoundResubmit.comments.find((comment: { id: string }) => comment.id === "r-2");
  assert.deepEqual(
    {
      status: replacementThread?.status,
      text: replacementThread?.text,
      replies: replacementThread?.replies,
      attachments: replacementThread?.attachments,
      lastRoundThreadId: reviewAfterSameRoundResubmit.comments.filter((comment: { scope?: string }) => comment.scope === "round").at(-1)?.id,
    },
    {
      status: "unresolved",
      text: "Replacement request in the same round",
      replies: [],
      attachments: [],
      lastRoundThreadId: "r-2",
    },
    "resubmitting a summary in the same round creates the active unresolved thread instead of inheriting old resolved state",
  );

  const blockedApprove = await request(
    port,
    "POST",
    "/exit",
    JSON.stringify({ summary: "try approve", decision: "approve", action: "final_approve", comments: [] }),
  );
  assert.equal(blockedApprove.status, 409, "server must reject approve while unresolved comments remain");

  const resolve = await request(port, "POST", "/resolve-comment", JSON.stringify({ id: "c-1-1" }));
  assert.equal(resolve.status, 200);
  const resolveImage = await request(port, "POST", "/resolve-comment", JSON.stringify({ id: "c-1-2" }));
  assert.equal(resolveImage.status, 200);
  const resolveList = await request(port, "POST", "/resolve-comment", JSON.stringify({ id: "c-1-3" }));
  assert.equal(resolveList.status, 200);
  const resolveFallback = await request(port, "POST", "/resolve-comment", JSON.stringify({ id: "c-1-4" }));
  assert.equal(resolveFallback.status, 200);
  const resolveHeading = await request(port, "POST", "/resolve-comment", JSON.stringify({ id: "c-1-5" }));
  assert.equal(resolveHeading.status, 200);
  const resolveOrderedList = await request(port, "POST", "/resolve-comment", JSON.stringify({ id: "c-1-6" }));
  assert.equal(resolveOrderedList.status, 200);

  const resolvedBrowser = await chromium.launch({ headless: true });
  try {
    const resolvedPage = await resolvedBrowser.newPage({ viewport: { width: 1280, height: 900 } });
    await resolvedPage.goto(`http://127.0.0.1:${port}/`, { waitUntil: "domcontentloaded" });
    await resolvedPage.waitForSelector("#review-loop-panel", { timeout: 10000 });
    assert.equal(await resolvedPage.locator(".review-loop-inline").count(), 0, "resolved comments do not render inline");
    await resolvedPage.click("#send-and-exit");
    assert.equal(await resolvedPage.locator("#modal-approve").isEnabled(), true, "approve is enabled after all review items are resolved");
    assert.equal(await resolvedPage.locator("#approve-blocked-reason").isVisible(), false, "blocked reason is hidden after all review items are resolved");
    assert.equal(await resolvedPage.locator("#modal-approve").getAttribute("aria-describedby"), null, "approve drops the blocked description after recovery");
  } finally {
    await resolvedBrowser.close().catch(() => {});
  }

  const finalApprove = await request(
    port,
    "POST",
    "/exit",
    JSON.stringify({ summary: "approved", decision: "approve", action: "final_approve", comments: [] }),
  );
  assert.equal(finalApprove.status, 200);

  const exitCode = await waitForExit(server, 10000);
  assert.equal(exitCode, 0, "approve should exit the loop server");

  const approvedReopen = trackProcess(spawn(process.execPath, [SERVER_JS, "--no-open", "--port", String(APPROVED_REOPEN_PORT), REPORT], {
    cwd: TMP_DIR,
    env,
    stdio: ["ignore", "pipe", "pipe"],
  }));
  const approvedReopenPort = await waitForServerOutput(approvedReopen);
  await waitForHealth(approvedReopenPort);
  const approvedBrowser = await chromium.launch({ headless: true });
  try {
    const approvedPage = await approvedBrowser.newPage({ viewport: { width: 1280, height: 900 } });
    await approvedPage.goto(`http://127.0.0.1:${approvedReopenPort}/`, { waitUntil: "domcontentloaded" });
    await approvedPage.waitForSelector("#review-loop-panel", { state: "attached" });
    assert.equal((await approvedPage.locator("#review-loop-panel").textContent() || "").trim(), "", "approved conversation stays closed when the report is reopened");
  } finally {
    await approvedBrowser.close().catch(() => {});
  }
  await request(approvedReopenPort, "POST", "/exit", JSON.stringify({ summary: "approved", decision: "approve", action: "final_approve", comments: [] }));
  assert.equal(await waitForExit(approvedReopen, 10000), 0, "approved reopen server exits normally");

  writeFileSync(
    join(NON_LOOP_REVIEW_DIR, "review.json"),
    JSON.stringify(
      {
        version: 1,
        branch: "non-loop",
        files: [NON_LOOP_REPORT],
        rounds: [
          { round: 1, started_at: "2026-07-07T00:00:00.000Z", submitted_at: "2026-07-07T00:01:00.000Z", decision: "request_changes", summary: "old" },
          { round: 2, started_at: "2026-07-07T00:02:00.000Z", submitted_at: null, decision: null, summary: "" },
        ],
        comments: [
          {
            id: "c-1-1",
            file: "NON_LOOP.md",
            line: 3,
            round: 1,
            text: "stale non-loop thread must not block approve",
            author: "human",
            status: "unresolved",
            replies: [],
            anchor: { snippet: "A normal review can approve with comments.", context_before: "", context_after: "" },
          },
        ],
      },
      null,
      2,
    ),
  );
  const nonLoopEnv = { ...process.env, HERDR_PANE_ID: "", YUNOMI_NOTIFY_CMD: "", YUNOMI_LOCK_DIR: LOCK_DIR, YUNOMI_REVIEW_DIR: NON_LOOP_REVIEW_DIR };
  const nonLoop = trackProcess(spawn(process.execPath, [SERVER_JS, "--no-open", "--port", String(NON_LOOP_PORT), NON_LOOP_REPORT], {
    cwd: TMP_DIR,
    env: nonLoopEnv,
    stdio: ["ignore", "pipe", "pipe"],
  }));
  const nonLoopPort = await waitForServerOutput(nonLoop);
  await waitForHealth(nonLoopPort);
  const nonLoopHtml = await request(nonLoopPort, "GET", "/");
  assert.equal(nonLoopHtml.status, 200);
  assert.match(nonLoopHtml.body, /review-loop-sidebar/, "non-loop page retains the shared review loop sidebar mount");
  assert.match(nonLoopHtml.body, /review-loop-submit-state/, "submit modal must include a review loop status row");
  const nonLoopState = await request(nonLoopPort, "GET", "/review-state");
  assert.equal(nonLoopState.status, 200);
  const nonLoopStateJson = JSON.parse(nonLoopState.body);
  assert.equal(nonLoopStateJson.review.rounds.at(-1)?.round, 2, "non-loop review-state must expose the current review round");
  assert.equal(nonLoopStateJson.review.comments[0]?.status, "unresolved", "non-loop review-state must expose thread status");
  assert.equal(nonLoopStateJson.unresolved_count, 1, "non-loop review-state must display unresolved thread count");
  assert.equal(nonLoopStateJson.gate_unresolved_count, 0, "non-loop review-state must not enable approve gate");
  const nonLoopApprove = await request(
    nonLoopPort,
    "POST",
    "/exit",
    JSON.stringify({
      summary: "normal approve",
      decision: "approve",
      action: "final_approve",
      comments: [{ row: 3, col: 1, text: "normal review comment", value: "A normal review can approve with comments." }],
    }),
  );
  assert.equal(nonLoopApprove.status, 200, "non-loop approve must accept freshly written comments");
  assert.equal(await waitForExit(nonLoop, 10000), 0, "non-loop approve with comments should exit normally");

  writeFileSync(
    join(EMPTY_REVIEW_DIR, "review.json"),
    JSON.stringify({
      version: 1,
      branch: "empty",
      files: [EMPTY_REPORT],
      rounds: [
        { round: 1, started_at: "2026-07-07T00:00:00.000Z", submitted_at: "2026-07-07T00:01:00.000Z", decision: "approve", summary: "done" },
        { round: 2, started_at: "2026-07-07T00:02:00.000Z", submitted_at: null, decision: null, summary: "" },
      ],
      comments: [],
    }, null, 2),
  );
  const emptyEnv = { ...process.env, HERDR_PANE_ID: "", YUNOMI_NOTIFY_CMD: "", YUNOMI_LOCK_DIR: LOCK_DIR, YUNOMI_REVIEW_DIR: EMPTY_REVIEW_DIR };
  const empty = trackProcess(spawn(process.execPath, [SERVER_JS, "--no-open", "--port", String(EMPTY_PORT), EMPTY_REPORT], {
    cwd: TMP_DIR,
    env: emptyEnv,
    stdio: ["ignore", "pipe", "pipe"],
  }));
  const emptyPort = await waitForServerOutput(empty);
  await waitForHealth(emptyPort);
  const emptyBrowser = await chromium.launch({ headless: true });
  try {
    const page = await emptyBrowser.newPage({ viewport: { width: 1280, height: 900 } });
    await page.goto(`http://127.0.0.1:${emptyPort}/`, { waitUntil: "domcontentloaded" });
    // Attached, not visible: an empty sidebar is display:none on purpose.
    await page.waitForSelector("#review-loop-panel", { state: "attached" });
    const emptyText = await page.locator("#review-loop-panel").textContent();
    assert.equal((emptyText || "").trim(), "", "an empty review hides its sidebar instead of showing a fixed hint");
    // An empty sidebar must not reserve its 300px column: the id+class rule
    // out-specifies `#review-loop-panel:empty` unless that is spelled out too.
    assert.equal(
      await page.evaluate(() => getComputedStyle(document.querySelector("#review-loop-panel")!).display),
      "none",
      "an empty review sidebar takes no horizontal space from the preview",
    );
    assert.equal(await page.locator("#review-loop-panel .review-loop-ready").count(), 0, "empty review does not show a competing ready message");
  } finally {
    await emptyBrowser.close().catch(() => {});
  }
  await request(emptyPort, "POST", "/exit", JSON.stringify({ summary: "", decision: "approve", action: "final_approve", comments: [] }));
  assert.equal(await waitForExit(empty, 10000), 0, "empty review server exits normally");
  console.log("PASS: review loop e2e");
}

try {
  await main();
} finally {
  stopChildProcesses();
}
