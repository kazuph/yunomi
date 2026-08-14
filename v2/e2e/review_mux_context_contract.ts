import { spawn, spawnSync, type ChildProcess } from "node:child_process";
import { mkdirSync, mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { chromium } from "playwright";

const SERVER_JS = process.env.YUNOMI_SERVER_JS || new URL("../_build/js/release/build/server/server.js", import.meta.url).pathname;

type RunningServer = {
  proc: ChildProcess;
  port: number;
  output: () => string;
};

type ReviewRepository = {
  root: string;
  reviewDir: string;
  lockDir: string;
  firstFile: string;
  secondFile: string;
};

type SseProbe = {
  events: Array<{ event: string; data: string }>;
  close: () => void;
};

function run(command: string, args: string[], cwd: string): void {
  const result = spawnSync(command, args, { cwd, encoding: "utf8" });
  if (result.status !== 0) throw new Error(`${command} ${args.join(" ")}\n${result.stderr}`);
}

function createReviewRepository(label: string): ReviewRepository {
  const root = mkdtempSync(join(tmpdir(), `yunomi-review-mux-${label}-`));
  run("git", ["init", "-b", "main"], root);
  run("git", ["config", "user.email", "yunomi@example.test"], root);
  run("git", ["config", "user.name", "yunomi"], root);
  mkdirSync(join(root, "first"), { recursive: true });
  mkdirSync(join(root, "second"), { recursive: true });
  const firstFile = join(root, "first", "report.md");
  const secondFile = join(root, "second", "report.md");
  writeFileSync(firstFile, "# First base\n- [ ] First decision\n\n[Jump](#target)\n\n## Target\n\n![Selected asset](shared.png)\n");
  writeFileSync(secondFile, "# Second base\n- [ ] Second decision\n\n[Jump](#target)\n\n## Target\n\n![Selected asset](shared.png)\n");
  run("git", ["add", "."], root);
  run("git", ["commit", "-m", "base"], root);
  run("git", ["checkout", "-b", "feature/review-mux-e2e"], root);
  writeFileSync(firstFile, "# First changed\n- [ ] First decision\n\n[Jump](#target)\n\n## Target\n\n![Selected asset](shared.png)\n");
  writeFileSync(secondFile, "# Second changed\n- [ ] Second decision\n\n[Jump](#target)\n\n## Target\n\n![Selected asset](shared.png)\n");
  run("git", ["add", "."], root);
  run("git", ["commit", "-m", "changed"], root);
  writeFileSync(join(root, "first", "shared.png"), Buffer.from("FIRST-PNG"));
  writeFileSync(join(root, "second", "shared.png"), Buffer.from("SECOND-PNG"));
  writeFileSync(join(root, "first", "theme.css"), "body{background:url('./shared.png')}\n");
  writeFileSync(join(root, "second", "theme.css"), "body{background:url('./shared.png')}\n");
  writeFileSync(join(root, "first", "clip.mp4"), Buffer.from("FIRST-VIDEO-BYTES"));
  writeFileSync(join(root, "second", "clip.mp4"), Buffer.from("SECOND-VIDEO-BYTES"));
  return { root, reviewDir: join(root, "reviews"), lockDir: join(root, "locks"), firstFile, secondFile };
}

function startReviewServer(
  repo: ReviewRepository,
  options: { go?: boolean; loop?: boolean; singleFile?: boolean } = {},
): Promise<RunningServer> {
  return new Promise((resolve, reject) => {
    let output = "";
    const args = options.go
      ? [SERVER_JS, "go", "--no-open", "--port", "0"]
      : options.singleFile
        ? [SERVER_JS, repo.firstFile, "--no-open", "--port", "0"]
        : [SERVER_JS, "review", "main", "--no-open", "--port", "0"];
    if (options.loop) args.push("--loop");
    const proc = spawn(process.execPath, args, {
      cwd: repo.root,
      env: {
        ...process.env,
        HERDR_PANE_ID: "",
        YUNOMI_NOTIFY_CMD: "",
        YUNOMI_REVIEW_DIR: repo.reviewDir,
        YUNOMI_LOCK_DIR: repo.lockDir,
      },
      stdio: ["ignore", "pipe", "pipe"],
    });
    const observe = (chunk: Buffer | string) => {
      output += String(chunk);
      const match = output.match(/http:\/\/127\.0\.0\.1:(\d+)/);
      if (match) resolve({ proc, port: Number(match[1]), output: () => output });
    };
    proc.stdout?.on("data", observe);
    proc.stderr?.on("data", observe);
    proc.once("error", reject);
    proc.once("exit", (code) => reject(new Error(`server exited before listening (${code})\n${output}`)));
    setTimeout(() => reject(new Error(`server did not start\n${output}`)), 15_000);
  });
}

async function request(
  port: number,
  path: string,
  body?: unknown,
  options: { method?: string; headers?: Record<string, string> } = {},
): Promise<{ status: number; text: string; headers: Headers }> {
  const response = await fetch(`http://127.0.0.1:${port}${path}`, {
    method: options.method || (body === undefined ? "GET" : "POST"),
    headers: body === undefined ? options.headers : { "Content-Type": "application/json", ...options.headers },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  return { status: response.status, text: await response.text(), headers: response.headers };
}

async function requestStatus(port: number, path: string, method = "GET"): Promise<number> {
  const response = await fetch(`http://127.0.0.1:${port}${path}`, { method });
  await response.body?.cancel();
  return response.status;
}

async function stopOwnServer(proc: ChildProcess): Promise<void> {
  if (proc.exitCode !== null) return;
  await new Promise<void>((resolve) => {
    proc.once("exit", () => resolve());
    proc.kill("SIGINT");
    setTimeout(resolve, 3_000);
  });
}

async function exitedWithin(proc: ChildProcess, timeoutMs: number): Promise<boolean> {
  if (proc.exitCode !== null) return true;
  return await new Promise((resolve) => {
    const timer = setTimeout(() => resolve(false), timeoutMs);
    proc.once("exit", () => {
      clearTimeout(timer);
      resolve(true);
    });
  });
}

async function waitFor(predicate: () => boolean, message: string, timeoutMs = 2_000): Promise<void> {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    if (predicate()) return;
    await new Promise((resolve) => setTimeout(resolve, 20));
  }
  throw new Error(`timeout: ${message}`);
}

async function openSse(port: number, path: string): Promise<SseProbe> {
  const controller = new AbortController();
  const response = await fetch(`http://127.0.0.1:${port}${path}`, {
    headers: { Accept: "text/event-stream" },
    signal: controller.signal,
  });
  if (response.status !== 200 || !response.body) throw new Error(`SSE ${path} returned ${response.status}`);
  const events: SseProbe["events"] = [];
  const reader = response.body.getReader();
  const decoder = new TextDecoder();
  void (async () => {
    let buffer = "";
    try {
      while (true) {
        const next = await reader.read();
        if (next.done) break;
        buffer += decoder.decode(next.value, { stream: true }).replace(/\r\n/g, "\n");
        let boundary = buffer.indexOf("\n\n");
        while (boundary >= 0) {
          const block = buffer.slice(0, boundary);
          buffer = buffer.slice(boundary + 2);
          let event = "message";
          const data: string[] = [];
          for (const line of block.split("\n")) {
            if (line.startsWith("event:")) event = line.slice(6).trim();
            if (line.startsWith("data:")) data.push(line.slice(5).trimStart());
          }
          if (data.length > 0 || event !== "message") events.push({ event, data: data.join("\n") });
          boundary = buffer.indexOf("\n\n");
        }
      }
    } catch (error) {
      if (!controller.signal.aborted) throw error;
    }
  })();
  return { events, close: () => controller.abort() };
}

const submit = { generation: 1, summary: "review", decision: "approve", action: "final_approve", comments: [] };
const failures: string[] = [];

function check(condition: boolean, message: string): void {
  if (condition) console.log(`PASS: ${message}`);
  else {
    console.error(`FAIL: ${message}`);
    failures.push(message);
  }
}

async function verifyBrowserContextPropagation(port: number): Promise<void> {
  const browser = await chromium.launch({ headless: true });
  const requested: string[] = [];
  const pageErrors: string[] = [];
  try {
    const page = await browser.newPage();
    page.on("request", (request) => requested.push(new URL(request.url()).pathname + new URL(request.url()).search));
    page.on("pageerror", (error) => pageErrors.push(error.message));
    await page.goto(`http://127.0.0.1:${port}/?f=1`, { waitUntil: "domcontentloaded" });
    await waitFor(() => requested.some((path) => path === "/review-state?f=1"), "browser review-state context");
    await waitFor(() => requested.some((path) => path === "/sse?f=1"), "browser SSE context");
    await waitFor(() => requested.some((path) => path === "/session/open?f=1"), "browser session-open context");
    await waitFor(() => requested.some((path) => path === "/_yunomi/mux/1/shared.png"), "browser selected static asset");
    await page.getByRole("link", { name: "Jump" }).click();
    const location = new URL(page.url());
    check(location.pathname === "/" && location.search === "?f=1" && location.hash === "#target", "fragment navigation preserves the selected mux document URL");
    check(await page.locator("#target").isVisible(), "fragment navigation reaches the selected document target");
    await page.goto("about:blank");
    await waitFor(() => requested.some((path) => path === "/close?f=1"), "browser session-close context");
    await page.close();
    const bareStateful = requested.filter((path) => ["/review-state", "/sse", "/session/open", "/close"].includes(path));
    check(bareStateful.length === 0, "the real browser emits no bare context-bound state route from f=1");
    check(pageErrors.length === 0, "the selected mux browser flow produces no page errors");
  } finally {
    await browser.close();
  }
}

async function verifyContextBoundRoutes(): Promise<void> {
  const repo = createReviewRepository("context");
  const server = await startReviewServer(repo);
  let firstSse: SseProbe | undefined;
  let secondSse: SseProbe | undefined;
  try {
    const selectedHtml = await request(server.port, "/?f=1");
    check(/Second changed/.test(selectedHtml.text), "the second mux page is rendered");
    check(!/First changed/.test(selectedHtml.text), "the second mux page excludes the first file source");
    check(/__YUNOMI_REQUEST_CONTEXT__=\"\?f=1\"/.test(selectedHtml.text), "the selected page gives every stateful browser API its explicit file context");
    check(/__YUNOMI_REVIEW_GENERATION__=1/.test(selectedHtml.text), "the selected page binds submissions to the current generation");
    const selectedState = await request(server.port, "/review-state?f=1");
    check(selectedState.status === 200, "the selected file reads its own review state through the explicit context route");
    check(/Second changed/.test(selectedState.text), "the selected review-state body contains the second file diff");
    check(!/First changed/.test(selectedState.text), "the selected review-state body excludes the first file diff");
    const selectedStateJson = selectedState.status === 200 ? JSON.parse(selectedState.text) : { review: { files: [] } };
    check(JSON.stringify(selectedStateJson.review.files) === JSON.stringify(["first/report.md", "second/report.md"]), "mux startup registers every reviewed file in display order");

    await verifyBrowserContextPropagation(server.port);

    firstSse = await openSse(server.port, "/sse?f=0");
    secondSse = await openSse(server.port, "/sse?f=1");
    await waitFor(() => firstSse!.events.some((event) => event.event === "hello"), "first SSE hello");
    await waitFor(() => secondSse!.events.some((event) => event.event === "hello"), "second SSE hello");

    const comment = await request(server.port, "/comment?f=1", {
      type: "comment", key: "mux-second-comment", row: 0, col: 0,
      text: "belongs to second", author: "human",
    });
    check(comment.status === 200, "a selected-file comment route is accepted");
    const reviewAfterComment = JSON.parse(readFileSync(join(repo.reviewDir, "review.json"), "utf8"));
    const storedComment = reviewAfterComment.comments.find((entry: { id?: string; text?: string }) =>
      entry.id === "mux-second-comment" || entry.text === "belongs to second");
    check(storedComment?.file === "second/report.md", "the comment persists with the second file owner");
    await waitFor(() => secondSse!.events.some((event) => event.event === "comment" && event.data.includes("belongs to second")), "second file comment SSE");
    check(!firstSse.events.some((event) => event.event === "comment" && event.data.includes("belongs to second")), "a file comment is not delivered to the other file SSE audience");

    const ownerBefore = readFileSync(join(repo.reviewDir, "review.json"), "utf8");
    const wrongReply = await request(server.port, "/reply-comment?f=0", {
      id: storedComment?.id || "mux-second-comment", text: "wrong owner", author: "agent",
    });
    const wrongResolve = await request(server.port, "/resolve-comment?f=0", { id: storedComment?.id || "mux-second-comment" });
    check(wrongReply.status === 400 && wrongResolve.status === 400, "a non-owner mux context rejects file-thread reply and resolve with 400");
    check(readFileSync(join(repo.reviewDir, "review.json"), "utf8") === ownerBefore, "a rejected non-owner file-thread request has no persistence side effect");

    const reply = await request(server.port, "/reply-comment?f=1", {
      id: storedComment?.id || "mux-second-comment", text: "second owner reply", author: "agent",
    });
    check(reply.status === 200, "a file-thread reply is accepted on its owner context");
    const reviewAfterReply = JSON.parse(readFileSync(join(repo.reviewDir, "review.json"), "utf8"));
    const persistedReply = reviewAfterReply.comments.find((entry: { id?: string }) => entry.id === storedComment?.id);
    check(persistedReply?.replies?.at(-1)?.text === "second owner reply", "the file-thread reply persists on its owner thread");
    await waitFor(() => secondSse!.events.some((event) => event.event === "reply" && event.data.includes("second owner reply")), "second file reply SSE");
    check(!firstSse.events.some((event) => event.event === "reply" && event.data.includes("second owner reply")), "a file-thread reply is not delivered to a non-owner context");

    const cliFileReply = spawnSync(process.execPath, [SERVER_JS, "reply", storedComment?.id || "mux-second-comment", "CLI file reply"], {
      cwd: repo.root,
      encoding: "utf8",
      env: { ...process.env, HERDR_PANE_ID: "", YUNOMI_NOTIFY_CMD: "", YUNOMI_REVIEW_DIR: repo.reviewDir, YUNOMI_LOCK_DIR: repo.lockDir },
    });
    check(cliFileReply.status === 0 && cliFileReply.stdout.includes("notified running review server"), "CLI resolves a file thread to its running owner context");
    const reviewAfterCliFileReply = JSON.parse(readFileSync(join(repo.reviewDir, "review.json"), "utf8"));
    const persistedCliFileReply = reviewAfterCliFileReply.comments.find((entry: { id?: string }) => entry.id === storedComment?.id);
    check(persistedCliFileReply?.replies?.at(-1)?.text === "CLI file reply", "the CLI file-thread reply persists on the same owner thread");
    await waitFor(() => secondSse!.events.some((event) => event.event === "reply" && event.data.includes("CLI file reply")), "CLI file reply SSE");
    check(!firstSse.events.some((event) => event.event === "reply" && event.data.includes("CLI file reply")), "CLI file-thread reply is not broadcast to a non-owner context");
    const resolve = await request(server.port, "/resolve-comment?f=1", { id: storedComment?.id || "mux-second-comment" });
    check(resolve.status === 200, "a file-thread resolve is accepted on its owner context");
    const reviewAfterResolve = JSON.parse(readFileSync(join(repo.reviewDir, "review.json"), "utf8"));
    check(reviewAfterResolve.comments.find((entry: { id?: string }) => entry.id === storedComment?.id)?.status === "resolved", "the file-thread resolve persists its resolved status");
    await waitFor(() => secondSse!.events.some((event) => event.event === "resolve"), "second file resolve SSE");
    check(!firstSse.events.some((event) => event.event === "resolve"), "a file-thread resolve is not delivered to a non-owner context");

    const roundComment = await request(server.port, "/create-global-comment?f=1", { text: "round-wide question" });
    check(roundComment.status === 200, "a round-scoped conversation is accepted from the second context");
    const roundId = JSON.parse(roundComment.text).id as string;
    const reviewAfterRoundComment = JSON.parse(readFileSync(join(repo.reviewDir, "review.json"), "utf8"));
    const persistedRoundComment = reviewAfterRoundComment.comments.find((entry: { id?: string }) => entry.id === roundId);
    check(persistedRoundComment?.scope === "round" && persistedRoundComment?.file === "" && persistedRoundComment?.status === "unresolved", "the round conversation persists session-wide rather than under one file");
    await waitFor(() => firstSse!.events.some((event) => event.event === "round" && event.data.includes("round-wide question")), "round event on first SSE");
    await waitFor(() => secondSse!.events.some((event) => event.event === "round" && event.data.includes("round-wide question")), "round event on second SSE");
    check(firstSse.events.some((event) => event.event === "round" && event.data.includes("round-wide question")), "a round-scoped conversation is delivered to the first context");
    check(secondSse.events.some((event) => event.event === "round" && event.data.includes("round-wide question")), "a round-scoped conversation is delivered to the second context");
    const cliRoundReply = spawnSync(process.execPath, [SERVER_JS, "reply", roundId, "CLI round reply"], {
      cwd: repo.root,
      encoding: "utf8",
      env: { ...process.env, HERDR_PANE_ID: "", YUNOMI_NOTIFY_CMD: "", YUNOMI_REVIEW_DIR: repo.reviewDir, YUNOMI_LOCK_DIR: repo.lockDir },
    });
    check(cliRoundReply.status === 0 && cliRoundReply.stdout.includes("notified running review server"), "CLI round-thread reply reaches the running mux session");
    const reviewAfterCliRoundReply = JSON.parse(readFileSync(join(repo.reviewDir, "review.json"), "utf8"));
    const persistedCliRoundReply = reviewAfterCliRoundReply.comments.find((entry: { id?: string }) => entry.id === roundId);
    check(persistedCliRoundReply?.replies?.at(-1)?.text === "CLI round reply", "the CLI round-thread reply persists in the session-wide conversation");
    await waitFor(() => firstSse!.events.some((event) => event.event === "reply" && event.data.includes("CLI round reply")), "CLI round reply first SSE");
    await waitFor(() => secondSse!.events.some((event) => event.event === "reply" && event.data.includes("CLI round reply")), "CLI round reply second SSE");
    const gateBeforeRoundResolve = JSON.parse((await request(server.port, "/review-state?f=1")).text).gate_unresolved_count;
    const resolvedRound = await request(server.port, "/resolve-comment?f=1", { id: roundId });
    check(resolvedRound.status === 200, "a round-scoped conversation can be resolved");
    await waitFor(() => firstSse!.events.some((event) => event.event === "resolve" && event.data.includes("round-wide question")), "round resolve reaches first SSE");
    await waitFor(() => secondSse!.events.some((event) => event.event === "resolve" && event.data.includes("round-wide question")), "round resolve reaches second SSE");
    const reviewAfterRoundResolveText = readFileSync(join(repo.reviewDir, "review.json"), "utf8");
    const reviewAfterRoundResolve = JSON.parse(reviewAfterRoundResolveText);
    check(reviewAfterRoundResolve.comments.find((entry: { id?: string }) => entry.id === roundId)?.status === "resolved", "round resolution persists session-wide");
    check(JSON.parse((await request(server.port, "/review-state?f=1")).text).gate_unresolved_count === gateBeforeRoundResolve, "round threads never enter the approve gate");
    const replayResolveEvents = {
      first: firstSse!.events.filter((event) => event.event === "resolve" && event.data.includes("round-wide question")).length,
      second: secondSse!.events.filter((event) => event.event === "resolve" && event.data.includes("round-wide question")).length,
    };
    check((await request(server.port, "/resolve-comment?f=1", { id: roundId })).status === 200, "replaying a resolved round resolve remains an idempotent 200");
    check(readFileSync(join(repo.reviewDir, "review.json"), "utf8") === reviewAfterRoundResolveText, "replaying a resolved round resolve leaves review persistence unchanged");
    const muxMissingResolveText = readFileSync(join(repo.reviewDir, "review.json"), "utf8");
    check((await request(server.port, "/resolve-comment?f=1", { id: "mux-missing-round-id" })).status === 400, "a mux missing round resolve rejects with 400");
    check(readFileSync(join(repo.reviewDir, "review.json"), "utf8") === muxMissingResolveText, "a mux missing round resolve leaves review persistence unchanged");
    check((await request(server.port, "/reply-comment?f=1", { id: roundId, text: "rejected round reply", author: "agent" })).status === 409, "HTTP reply rejects a resolved round conversation");
    check(readFileSync(join(repo.reviewDir, "review.json"), "utf8") === reviewAfterRoundResolveText, "rejected round reply has no persistence effect");
    const rejectedCliRoundReply = spawnSync(process.execPath, [SERVER_JS, "reply", roundId, "CLI rejected round reply"], {
      cwd: repo.root,
      encoding: "utf8",
      env: { ...process.env, HERDR_PANE_ID: "", YUNOMI_NOTIFY_CMD: "", YUNOMI_REVIEW_DIR: repo.reviewDir, YUNOMI_LOCK_DIR: repo.lockDir },
    });
    check(rejectedCliRoundReply.status !== 0, "CLI reply rejects a resolved round conversation");
    check(readFileSync(join(repo.reviewDir, "review.json"), "utf8") === reviewAfterRoundResolveText, "rejected CLI round reply has no persistence effect");
    const nextRoundComment = await request(server.port, "/create-global-comment?f=1", { text: "next round-wide question" });
    check(nextRoundComment.status === 200, "a resolved round conversation permits a new round conversation");
    const nextRoundId = JSON.parse(nextRoundComment.text).id as string;
    await waitFor(() => firstSse!.events.some((event) => event.event === "round" && event.data.includes("next round-wide question")), "new round conversation reaches first SSE");
    await waitFor(() => secondSse!.events.some((event) => event.event === "round" && event.data.includes("next round-wide question")), "new round conversation reaches second SSE");
    check(firstSse!.events.filter((event) => event.event === "resolve" && event.data.includes("round-wide question")).length === replayResolveEvents.first && secondSse!.events.filter((event) => event.event === "resolve" && event.data.includes("round-wide question")).length === replayResolveEvents.second, "replaying a resolved round resolve emits no additional SSE event before the FIFO round sentinel");
    const reviewAfterNextRound = JSON.parse(readFileSync(join(repo.reviewDir, "review.json"), "utf8"));
    check(reviewAfterNextRound.comments.find((entry: { id?: string }) => entry.id === roundId)?.status === "resolved" && reviewAfterNextRound.comments.find((entry: { id?: string }) => entry.id === nextRoundId)?.status === "unresolved", "resolved round history remains while its replacement opens");

    const cli = spawnSync(process.execPath, [SERVER_JS, "comment", "second/report.md:1", "CLI belongs to second"], {
      cwd: repo.root,
      encoding: "utf8",
      env: { ...process.env, HERDR_PANE_ID: "", YUNOMI_NOTIFY_CMD: "", YUNOMI_REVIEW_DIR: repo.reviewDir, YUNOMI_LOCK_DIR: repo.lockDir },
    });
    check(cli.status === 0 && cli.stdout.includes("Posted comment to running yunomi server"), "CLI comment reaches the running mux server instead of offline fallback");
    const reviewAfterCliComment = JSON.parse(readFileSync(join(repo.reviewDir, "review.json"), "utf8"));
    const persistedCliComment = reviewAfterCliComment.comments.find((entry: { text?: string }) => entry.text === "CLI belongs to second");
    check(persistedCliComment?.file === "second/report.md", "the CLI comment persists with the selected second-file owner");
    await waitFor(() => secondSse!.events.some((event) => event.event === "comment" && event.data.includes("CLI belongs to second")), "CLI second-file SSE");
    check(!firstSse.events.some((event) => event.event === "comment" && event.data.includes("CLI belongs to second")), "CLI file comment is delivered only to its owner context");

    const decision = await request(server.port, "/decision?f=1", {
      file: "second/report.md", line: 2, text: "Second decision", checked: "true",
    });
    check(decision.status === 200, "a selected-file decision route is accepted");
    check(readFileSync(repo.secondFile, "utf8").includes("- [x] Second decision"), "the decision mutates the second source");
    check(readFileSync(repo.firstFile, "utf8").includes("- [ ] First decision"), "the decision leaves the first source unchanged");

    await verifyMuxStaticResponses(server.port);

    const secondSubmit = {
      ...submit,
      summary: "second summary",
      comments: [{ row: 0, col: 0, text: "second submitted comment", value: "# Second changed", image: "data:image/png;base64,U0VDT05ELUNPTU1FTlQ=" }],
    };
    check((await request(server.port, "/exit?f=1", secondSubmit)).status === 200, "the selected second file submits once");
    check(!(await exitedWithin(server.proc, 250)), "one of two files cannot terminate the process");
    const reviewAfterSubmittedComment = JSON.parse(readFileSync(join(repo.reviewDir, "review.json"), "utf8"));
    const submittedComments = reviewAfterSubmittedComment.comments.filter((entry: { text?: string }) => entry.text === "second submitted comment");
    check(submittedComments.length === 1 && submittedComments[0]?.file === "second/report.md" && submittedComments[0]?.imagePath && submittedComments[0]?.attachments?.length === 1, "a mux submit persists its reflected file comment and attachment exactly once");
    check(!Object.hasOwn(reviewAfterSubmittedComment, "_mux_status"), "mux persistence does not store a transient submit status");
    check((await request(server.port, "/exit?f=1", secondSubmit)).status === 200, "an identical retry is acknowledged");
    check(!(await exitedWithin(server.proc, 250)), "an identical retry is side-effect idempotent");
    const reviewAfterRetry = JSON.parse(readFileSync(join(repo.reviewDir, "review.json"), "utf8"));
    check(reviewAfterRetry.comments.filter((entry: { text?: string }) => entry.text === "second submitted comment").length === 1, "an identical mux retry does not duplicate persisted comments");
    check((await request(server.port, "/exit?f=0", { ...submit, summary: "first summary" })).status === 200, "the remaining first file submits once");
    check(await exitedWithin(server.proc, 3_000), "the process exits only after both distinct files submit");
    const yaml = server.output();
    check((yaml.match(/^  - file: first\/report\.md$/gm) || []).length === 1, "final YAML contains the first file exactly once");
    check((yaml.match(/^  - file: second\/report\.md$/gm) || []).length === 1, "final YAML contains the second file exactly once");
    check(yaml.indexOf("first summary") < yaml.indexOf("second summary"), "final YAML follows mux display order rather than arrival order");
  } finally {
    firstSse?.close();
    secondSse?.close();
    await stopOwnServer(server.proc);
  }
}

async function verifyMuxStaticResponses(port: number): Promise<void> {
  const secondImage = await request(port, "/_yunomi/mux/1/shared.png");
  check(secondImage.status === 200 && secondImage.text === "SECOND-PNG", "static bytes come from the selected file directory");
  const firstImage = await request(port, "/_yunomi/mux/0/shared.png");
  check(firstImage.status === 200 && firstImage.text === "FIRST-PNG", "same-name assets remain isolated by mux index");
  const secondCss = await request(port, "/_yunomi/mux/1/theme.css");
  check(secondCss.status === 200 && secondCss.text.includes("url('./shared.png')"), "selected CSS keeps its relative nested asset URL");
  const videoRange = await request(port, "/_yunomi/mux/1/clip.mp4", undefined, { headers: { Range: "bytes=0-5" } });
  check(videoRange.status === 206 && videoRange.text === "SECOND", "selected MP4 range requests preserve partial-content semantics");
  const videoHead = await request(port, "/_yunomi/mux/1/clip.mp4", undefined, { method: "HEAD" });
  check(videoHead.status === 200 && videoHead.text === "" && videoHead.headers.get("content-length") === String(Buffer.byteLength("SECOND-VIDEO-BYTES")), "selected static HEAD returns length without a body");
  check((await request(port, "/shared.png")).status === 400, "a bare static path is rejected in mux mode");
  check((await request(port, "/_yunomi/mux/bad/shared.png")).status === 400, "a non-numeric mux static index is rejected");
  check((await request(port, "/_yunomi/mux/2/shared.png")).status === 400, "an out-of-range mux static index is rejected");
  check((await request(port, "/_yunomi/mux/-1/shared.png")).status === 400, "a negative mux static index is rejected");
  check((await request(port, "/_yunomi/mux/1.0/shared.png")).status === 400, "a decimal mux static index is rejected");
  check((await request(port, "/_yunomi/mux/1/..%2Fshared.png")).status === 403, "mux static traversal is rejected");
}

async function verifyMuxStaticRoutes(): Promise<void> {
  const server = await startReviewServer(createReviewRepository("mux-static"));
  try {
    await verifyMuxStaticResponses(server.port);
  } finally {
    await stopOwnServer(server.proc);
  }
}

async function verifyMissingContextAndDuplicateDelivery(): Promise<void> {
  const server = await startReviewServer(createReviewRepository("duplicate"));
  try {
    const bareSubmit = await request(server.port, "/exit", submit);
    check(bareSubmit.status === 400, "a mux submit without its file context is rejected");
    if (bareSubmit.status !== 400) {
      const repeatedBareSubmit = await request(server.port, "/exit", submit);
      check(!(await exitedWithin(server.proc, 250)), "repeating one file cannot complete a two-file review");
      check(repeatedBareSubmit.status === 400, "a repeated bare submit remains rejected");
    }
  } finally {
    await stopOwnServer(server.proc);
  }

  const selected = await startReviewServer(createReviewRepository("selected-duplicate"));
  try {
    const first = await request(selected.port, "/exit?f=1", submit);
    check(first.status === 200, "the selected second file submits once");
    const duplicate = await request(selected.port, "/exit?f=1", submit);
    check(duplicate.status === 200, "an identical selected-file retry is accepted without a second result");
    check(!(await exitedWithin(selected.proc, 250)), "a duplicate selected-file retry cannot complete the review");
  } finally {
    await stopOwnServer(selected.proc);
  }
}

async function verifyContextValidation(): Promise<void> {
  const server = await startReviewServer(createReviewRepository("invalid-context"));
  const statefulGetRoutes = ["/sse", "/history", "/review-state", "/video-timeline?time=0"];
  const statefulPostRoutes = new Map<string, unknown>([
    ["/session/open", { tabId: "strict-context-tab", instanceId: "strict-context-instance" }],
    ["/close", { tabId: "strict-context-tab", instanceId: "strict-context-instance", draft: "" }],
    ["/comment", { type: "comment", key: "strict-context", row: 1, col: 0, text: "strict context" }],
    ["/review-viewed", {}],
    ["/go", { generation: 1 }],
    ["/resolve-comment", { id: "strict-context-comment" }],
    ["/reply-comment", { id: "strict-context-comment", text: "strict context", author: "agent" }],
    ["/create-global-comment", { text: "strict context" }],
    ["/decision", { decision: "approve" }],
    ["/exit", submit],
  ]);
  try {
    for (const route of statefulGetRoutes) {
      const separator = route.includes("?") ? "&" : "?";
      check(await requestStatus(server.port, route) === 400, `${route} rejects a missing mux index`);
      check(await requestStatus(server.port, `${route}${separator}f=bad`) === 400, `${route} rejects a non-numeric mux index`);
      check(await requestStatus(server.port, `${route}${separator}f=2`) === 400, `${route} rejects an out-of-range mux index`);
      check(await requestStatus(server.port, `${route}${separator}f=-1`) === 400, `${route} rejects a negative mux index`);
      check(await requestStatus(server.port, `${route}${separator}f=1.0`) === 400, `${route} rejects a decimal mux index`);
      check(await requestStatus(server.port, `${route}${separator}f=0&f=1`) === 400, `${route} rejects duplicate mux index parameters`);
    }
    for (const [route, body] of statefulPostRoutes) {
      check((await request(server.port, route, body)).status === 400, `${route} rejects a missing mux index before route-specific processing`);
      check((await request(server.port, `${route}?f=bad`, body)).status === 400, `${route} rejects a non-numeric mux index`);
      check((await request(server.port, `${route}?f=2`, body)).status === 400, `${route} rejects an out-of-range mux index`);
      check((await request(server.port, `${route}?f=-1`, body)).status === 400, `${route} rejects a negative mux index`);
      check((await request(server.port, `${route}?f=1.0`, body)).status === 400, `${route} rejects a decimal mux index`);
      check((await request(server.port, `${route}?f=0&f=1`, body)).status === 400, `${route} rejects duplicate mux index parameters`);
    }
    check((await request(server.port, "/ui.js")).status === 200, "bare ui.js remains process-global");
    check((await request(server.port, "/healthz")).status === 200, "bare healthz remains process-global");
    check((await request(server.port, "/ui.js?f=1")).status === 400, "ui.js rejects a misleading file context");
    check((await request(server.port, "/healthz?f=1")).status === 400, "healthz rejects a misleading file context");
    check((await request(server.port, "/")).status === 400, "HTML rejects a missing mux index");
    check((await request(server.port, "/?f=bad")).status === 400, "HTML rejects a non-numeric mux index");
    check((await request(server.port, "/?f=2")).status === 400, "HTML rejects an out-of-range mux index");
    check((await request(server.port, "/?f=-1")).status === 400, "HTML rejects a negative mux index");
    check((await request(server.port, "/?f=1.0")).status === 400, "HTML rejects a decimal mux index");
    check((await request(server.port, "/?f=0&f=1")).status === 400, "HTML rejects duplicate mux index parameters");
  } finally {
    await stopOwnServer(server.proc);
  }
}

async function verifyRoundGenerationAndReplacement(): Promise<void> {
  const repo = createReviewRepository("round-generation");
  const server = await startReviewServer(repo, { loop: true });
  try {
    const secondOld = await request(server.port, "/exit?f=1", {
      ...submit, summary: "second old", decision: "approve", action: "final_approve",
    });
    check(secondOld.status === 200, "the second file can submit first in generation one");
    const secondLatest = await request(server.port, "/exit?f=1", {
      ...submit, summary: "second latest", decision: "approve", action: "final_approve",
    });
    check(secondLatest.status === 200, "a distinct payload replaces the same file and generation ledger entry");
    check(!(await exitedWithin(server.proc, 250)), "same-file replacement still counts as one collected file");

    const partial = JSON.parse(readFileSync(join(repo.reviewDir, "review.json"), "utf8"));
    check(partial.rounds.at(-1)?.submitted_at === null, "a partial multi-file round is not persisted as complete");
    check((await request(server.port, "/go?f=0", { generation: 1 })).status === 409, "go is rejected before every file has submitted");

    const firstRequestChanges = await request(server.port, "/exit?f=0", {
      ...submit, summary: "first needs changes", decision: "request_changes", action: "final_request_changes",
    });
    check(firstRequestChanges.status === 200, "the remaining request-changes result completes generation one");
    check(!(await exitedWithin(server.proc, 250)), "a complete request-changes round waits for go");
    const completed = JSON.parse(readFileSync(join(repo.reviewDir, "review.json"), "utf8"));
    const roundOne = completed.rounds.find((round: { round: number }) => round.round === 1);
    check(roundOne?.decision === "request_changes", "request_changes dominates approve independent of arrival order");
    check(roundOne?.summary === "first/report.md: first needs changes\nsecond/report.md: second latest", "shared round summary joins latest per-file summaries in mux order");
    check(!JSON.stringify(completed).includes("second old"), "a replaced payload does not survive in the completed round state");
    const firstHistory = await request(server.port, "/history?f=0");
    const secondHistory = await request(server.port, "/history?f=1");
    check(firstHistory.status === 200 && firstHistory.text.includes("first needs changes") && !firstHistory.text.includes("second latest"), "first history contains only the first file's latest payload");
    check(secondHistory.status === 200 && secondHistory.text.includes("second latest") && !secondHistory.text.includes("second old"), "second history contains only the second file's replacement payload");

    check((await request(server.port, "/go?f=1", { generation: 1 })).status === 200, "go advances a fully completed request-changes round");
    const generationTwoHtml = await request(server.port, "/?f=0");
    check(/__YUNOMI_REVIEW_GENERATION__=2/.test(generationTwoHtml.text), "go publishes generation two to reloaded pages");
    check((await request(server.port, "/exit?f=1", { ...submit, summary: "stale second" })).status === 409, "a delayed generation-one submit is rejected after go");
    check((await request(server.port, "/exit?f=1", { ...submit, generation: 2, summary: "second round-two approve" })).status === 200, "the second file submits for generation two");
    check(!(await exitedWithin(server.proc, 250)), "one generation-two approval cannot exit");
    check((await request(server.port, "/exit?f=0", {
      ...submit, generation: 2, summary: "first round-two changes", decision: "request_changes", action: "final_request_changes",
    })).status === 200, "generation two can complete with request changes");
    check(!(await exitedWithin(server.proc, 250)), "generation-two request changes waits for go");
    check((await request(server.port, "/go?f=0", { generation: 2 })).status === 200, "go advances a second completed request-changes round");
    const generationThreeHtml = await request(server.port, "/?f=1");
    check(/__YUNOMI_REVIEW_GENERATION__=3/.test(generationThreeHtml.text), "the second go publishes generation three");
    check((await request(server.port, "/exit?f=0", { ...submit, generation: 2, summary: "stale generation two" })).status === 409, "a delayed generation-two submit is rejected in generation three");
    check((await request(server.port, "/exit?f=1", { ...submit, generation: 3, summary: "second approved" })).status === 200, "the second file submits for generation three");
    check(!(await exitedWithin(server.proc, 250)), "one generation-three approval cannot exit");
    check((await request(server.port, "/exit?f=0", {
      ...submit, generation: 3, summary: "first round-three changes", decision: "request_changes", action: "final_request_changes",
    })).status === 200, "generation three can complete with request changes without imposing a product generation cap");
    check(!(await exitedWithin(server.proc, 250)), "generation-three request changes waits for go");
    check((await request(server.port, "/go?f=1", { generation: 3 })).status === 200, "go advances generation three to generation four");
    const generationFourHtml = await request(server.port, "/?f=0");
    check(/__YUNOMI_REVIEW_GENERATION__=4/.test(generationFourHtml.text), "the third go publishes generation four");
    check((await request(server.port, "/exit?f=0", { ...submit, generation: 3, summary: "stale generation three" })).status === 409, "a delayed generation-three submit is rejected in generation four");
    check((await request(server.port, "/exit?f=1", { ...submit, generation: 4, summary: "second generation-four approved" })).status === 200, "the second file submits for generation four");
    check((await request(server.port, "/exit?f=0", { ...submit, generation: 4, summary: "first generation-four approved" })).status === 200, "the first file submits for generation four");
    check(await exitedWithin(server.proc, 3_000), "all generation-four approvals exit exactly once");
    const yaml = server.output();
    check(!yaml.includes("stale second") && !yaml.includes("stale generation two") && !yaml.includes("stale generation three"), "rejected old-generation payloads are absent from emitted YAML");
    check((yaml.match(/file: first\/report\.md/g) || []).length === 4 && (yaml.match(/file: second\/report\.md/g) || []).length === 4, "each of four completed rounds emits each mux file exactly once");
  } finally {
    await stopOwnServer(server.proc);
  }
}

async function verifySingleFileStaticRegression(): Promise<void> {
  const repo = createReviewRepository("single-static");
  const server = await startReviewServer(repo, { singleFile: true });
  try {
    const image = await request(server.port, "/shared.png");
    check(image.status === 200 && image.text === "FIRST-PNG", "single-file static paths remain backward compatible");
    const head = await request(server.port, "/clip.mp4", undefined, { method: "HEAD" });
    check(head.status === 200 && head.headers.get("content-length") === String(Buffer.byteLength("FIRST-VIDEO-BYTES")), "single-file static HEAD remains backward compatible");
  } finally {
    await stopOwnServer(server.proc);
  }
}

async function verifyStoppedGoResumesEveryFile(): Promise<void> {
  const repo = createReviewRepository("stopped-go");
  const firstServer = await startReviewServer(repo, { loop: true });
  try {
    const requestChanges = { ...submit, decision: "request_changes", action: "final_request_changes" };
    check((await request(firstServer.port, "/exit?f=1", { ...requestChanges, summary: "second changes" })).status === 200, "stopped-go fixture collects the second file");
    check((await request(firstServer.port, "/exit?f=0", { ...requestChanges, summary: "first changes" })).status === 200, "stopped-go fixture completes the request-changes round");
    check(!(await exitedWithin(firstServer.proc, 250)), "request-changes fixture remains alive before the simulated stop");
  } finally {
    await stopOwnServer(firstServer.proc);
  }

  const resumed = await startReviewServer(repo, { go: true });
  try {
    const secondHtml = await request(resumed.port, "/?f=1");
    check(secondHtml.status === 200 && /Second changed/.test(secondHtml.text), "stopped yunomi go resumes the second reviewed file");
    check(/__YUNOMI_REVIEW_GENERATION__=2/.test(secondHtml.text), "stopped yunomi go resumes at the next generation");
    const state = await request(resumed.port, "/review-state?f=0");
    check(JSON.stringify(JSON.parse(state.text).review.files) === JSON.stringify(["first/report.md", "second/report.md"]), "stopped yunomi go preserves every mux file in review state");
  } finally {
    await stopOwnServer(resumed.proc);
  }
}

const selectedCase = process.env.YUNOMI_MUX_CASE || "all";
if (selectedCase === "all" || selectedCase === "context") await verifyContextBoundRoutes();
if (selectedCase === "all" || selectedCase === "mux-static") await verifyMuxStaticRoutes();
if (selectedCase === "all" || selectedCase === "validation") await verifyContextValidation();
if (selectedCase === "all" || selectedCase === "duplicate") await verifyMissingContextAndDuplicateDelivery();
if (selectedCase === "all" || selectedCase === "round") await verifyRoundGenerationAndReplacement();
if (selectedCase === "all" || selectedCase === "single-static") await verifySingleFileStaticRegression();
if (selectedCase === "all" || selectedCase === "stopped-go") await verifyStoppedGoResumesEveryFile();
if (!["all", "context", "mux-static", "validation", "duplicate", "round", "single-static", "stopped-go"].includes(selectedCase)) {
  throw new Error(`unknown YUNOMI_MUX_CASE=${selectedCase}`);
}
if (failures.length > 0) throw new Error(`Review mux context contract failed:\n- ${failures.join("\n- ")}`);
console.log("Review mux context contract: passed");
