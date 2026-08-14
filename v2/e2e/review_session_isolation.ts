import { spawn, spawnSync, type ChildProcess } from "node:child_process";
import { existsSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, relative } from "node:path";
import { chromium } from "playwright";

const SERVER_JS = process.env.YUNOMI_SERVER_JS || new URL("../_build/js/release/build/server/server.js", import.meta.url).pathname;

type RunningServer = {
  proc: ChildProcess;
  port: number;
  output: () => string;
};

type ReviewRepo = {
  root: string;
  lockDir: string;
  firstFile: string;
  secondFile: string;
  sameNameA: string;
  sameNameB: string;
};

function check(condition: boolean, message: string, detail?: unknown): void {
  if (condition) {
    console.log(`PASS: ${message}`);
    return;
  }
  console.error(`FAIL: ${message}`);
  if (detail !== undefined) console.error(detail);
  process.exitCode = 1;
}

function run(command: string, args: string[], cwd: string): void {
  const result = spawnSync(command, args, { cwd, encoding: "utf8" });
  if (result.status !== 0) throw new Error(`${command} ${args.join(" ")}\n${result.stderr}`);
}

function isolationEnv(lockDir: string): NodeJS.ProcessEnv {
  const env = { ...process.env, HERDR_PANE_ID: "", YUNOMI_NOTIFY_CMD: "", YUNOMI_LOCK_DIR: lockDir };
  delete env.YUNOMI_REVIEW_DIR;
  return env;
}

function createRepo(label: string): ReviewRepo {
  const root = mkdtempSync(join(tmpdir(), `yunomi-session-isolation-${label}-`));
  run("git", ["init", "-b", "main"], root);
  run("git", ["config", "user.email", "yunomi@example.test"], root);
  run("git", ["config", "user.name", "yunomi"], root);
  mkdirSync(join(root, "first"), { recursive: true });
  mkdirSync(join(root, "second"), { recursive: true });
  mkdirSync(join(root, "alpha"), { recursive: true });
  mkdirSync(join(root, "beta"), { recursive: true });
  const firstFile = join(root, "first", "report.md");
  const secondFile = join(root, "second", "report.md");
  const sameNameA = join(root, "alpha", "REPORT.md");
  const sameNameB = join(root, "beta", "REPORT.md");
  writeFileSync(firstFile, "# First target\n\nunique-first-body\n");
  writeFileSync(secondFile, "# Second target\n\nunique-second-body\n");
  writeFileSync(sameNameA, "# Alpha REPORT\n\nalpha-body\n");
  writeFileSync(sameNameB, "# Beta REPORT\n\nbeta-body\n");
  run("git", ["add", "."], root);
  run("git", ["commit", "-m", "isolation fixtures"], root);
  run("git", ["checkout", "-b", "feature/session-isolation"], root);
  writeFileSync(firstFile, "# First target changed\n\nunique-first-body\n");
  writeFileSync(secondFile, "# Second target changed\n\nunique-second-body\n");
  run("git", ["add", "."], root);
  run("git", ["commit", "-m", "changed review targets"], root);
  return {
    root,
    lockDir: join(root, ".yunomi-locks"),
    firstFile,
    secondFile,
    sameNameA,
    sameNameB,
  };
}

function startServer(args: string[], cwd: string, lockDir: string): Promise<RunningServer> {
  return new Promise((resolve, reject) => {
    let output = "";
    const proc = spawn(process.execPath, [SERVER_JS, ...args, "--no-open", "--loop", "--port", "0"], {
      cwd,
      env: isolationEnv(lockDir),
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

async function stopServer(proc: ChildProcess): Promise<void> {
  if (proc.exitCode !== null) return;
  await new Promise<void>((resolve) => {
    proc.once("exit", () => resolve());
    proc.kill("SIGINT");
    setTimeout(resolve, 3_000);
  });
}

async function request(
  port: number,
  path: string,
  body?: unknown,
): Promise<{ status: number; text: string }> {
  const response = await fetch(`http://127.0.0.1:${port}${path}`, {
    method: body === undefined ? "GET" : "POST",
    headers: body === undefined ? undefined : { "Content-Type": "application/json" },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  return { status: response.status, text: await response.text() };
}

function commentTexts(stateText: string): string[] {
  const state = JSON.parse(stateText) as { review?: { comments?: Array<{ text?: string; replies?: Array<{ text?: string }> }> } };
  const texts: string[] = [];
  for (const comment of state.review?.comments || []) {
    if (comment.text) texts.push(String(comment.text));
    for (const reply of comment.replies || []) {
      if (reply.text) texts.push(String(reply.text));
    }
  }
  return texts;
}

function collectReviewJson(root: string): string[] {
  const out: string[] = [];
  const walk = (dir: string, depth: number) => {
    if (depth > 8 || !existsSync(dir)) return;
    const reviewPath = join(dir, "review.json");
    if (existsSync(reviewPath)) out.push(reviewPath);
    for (const entry of readdirSync(dir, { withFileTypes: true })) {
      if (entry.isDirectory() && entry.name !== ".git") walk(join(dir, entry.name), depth + 1);
    }
  };
  walk(join(root, ".yunomi"), 0);
  return out;
}

function reviewHasText(reviewPath: string, marker: string): boolean {
  if (!existsSync(reviewPath)) return false;
  return readFileSync(reviewPath, "utf8").includes(marker);
}

async function installEvaluateNamePolyfill(page: { addInitScript: (script: string | (() => void)) => Promise<void> }): Promise<void> {
  await page.addInitScript("globalThis.__name=globalThis.__name||((f)=>f);");
}

async function uiHasText(port: number, marker: string, path = "/"): Promise<boolean> {
  const browser = await chromium.launch({ headless: true });
  try {
    const page = await browser.newPage();
    await installEvaluateNamePolyfill(page);
    await page.goto(`http://127.0.0.1:${port}${path}`, { waitUntil: "domcontentloaded" });
    await page.waitForSelector("#review-loop-panel, .review-loop-sidebar", { timeout: 8000 }).catch(() => {});
    await page.waitForFunction((text) => document.body.innerText.includes(text), marker, { timeout: 4000 }).catch(() => {});
    const body = await page.locator("body").innerText();
    return body.includes(marker);
  } finally {
    await browser.close();
  }
}

async function createRoundComment(port: number, text: string, muxIndex?: number): Promise<string> {
  const path = muxIndex === undefined ? "/create-global-comment" : `/create-global-comment?f=${muxIndex}`;
  const created = await request(port, path, { text });
  check(created.status === 200, `create round comment ${text}`, created.text);
  if (created.status !== 200) return "";
  const id = JSON.parse(created.text).id as string;
  check(Boolean(id), `round comment ${text} returns an id`);
  return id;
}

async function main(): Promise<void> {
  const repo = createRepo("primary");
  const otherRepo = createRepo("worktree");
  const servers: ChildProcess[] = [];
  try {
    const firstMarker = "FOREIGN-FIRST-ROUND-THREAD";
    const secondMarker = "OWN-SECOND-ROUND-THREAD";
    const alphaMarker = "ALPHA-BASENAME-THREAD";
    const betaMarker = "BETA-BASENAME-THREAD";
    const muxABMarker = "MUX-AB-ORDER-THREAD";
    const muxBAMarker = "MUX-BA-ORDER-THREAD";
    const otherMarker = "OTHER-WORKTREE-THREAD";

    const first = await startServer([repo.firstFile], repo.root, repo.lockDir);
    servers.push(first.proc);
    await createRoundComment(first.port, firstMarker);
    const firstState = await request(first.port, "/review-state");
    check(commentTexts(firstState.text).includes(firstMarker), "first target API stores its own round thread");
    check(await uiHasText(first.port, firstMarker), "first target UI shows its own round thread");

    const second = await startServer([repo.secondFile], repo.root, repo.lockDir);
    servers.push(second.proc);
    await createRoundComment(second.port, secondMarker);
    const secondState = await request(second.port, "/review-state");
    const secondTexts = commentTexts(secondState.text);
    check(!secondTexts.includes(firstMarker), "different file on the same branch does not leak the previous round thread through the API", secondTexts);
    check(secondTexts.includes(secondMarker), "second target API shows only its own round thread", secondTexts);
    check(!(await uiHasText(second.port, firstMarker)), "different file on the same branch does not leak the previous conversation into the UI");
    check(await uiHasText(second.port, secondMarker), "second target UI shows its own round thread");

    const reviewFilesAfterSecond = collectReviewJson(repo.root);
    check(
      reviewFilesAfterSecond.some((path) => reviewHasText(path, firstMarker)),
      "the first target history remains on disk after a different target starts",
      reviewFilesAfterSecond,
    );
    check(
      reviewFilesAfterSecond.filter((path) => reviewHasText(path, firstMarker) && reviewHasText(path, secondMarker)).length === 0,
      "first and second markers are not mixed in one review.json",
      reviewFilesAfterSecond,
    );

    const sameNameA = await startServer([repo.sameNameA], repo.root, repo.lockDir);
    servers.push(sameNameA.proc);
    await createRoundComment(sameNameA.port, alphaMarker);
    const sameNameB = await startServer([repo.sameNameB], repo.root, repo.lockDir);
    servers.push(sameNameB.proc);
    await createRoundComment(sameNameB.port, betaMarker);
    const alphaState = commentTexts((await request(sameNameA.port, "/review-state")).text);
    const betaState = commentTexts((await request(sameNameB.port, "/review-state")).text);
    check(alphaState.includes(alphaMarker) && !alphaState.includes(betaMarker), "same basename in another directory stays isolated on A", alphaState);
    check(betaState.includes(betaMarker) && !betaState.includes(alphaMarker), "same basename in another directory stays isolated on B", betaState);
    check(!(await uiHasText(sameNameB.port, alphaMarker)), "same-basename UI does not show the other directory conversation");

    const ambiguousGo = spawnSync(process.execPath, [SERVER_JS, "go", "--no-open"], {
      cwd: repo.root,
      encoding: "utf8",
      env: isolationEnv(repo.lockDir),
    });
    check(ambiguousGo.status !== 0, "yunomi go refuses to guess when multiple live sessions exist", ambiguousGo.stdout + ambiguousGo.stderr);

    const retained = await request(first.port, "/exit", {
      decision: "request_changes",
      action: "final_request_changes",
      summary: "keep this target history",
    });
    check(retained.status === 200, "request_changes on the original target is accepted", retained.text);
    const go = await request(first.port, "/go", {});
    check(go.status === 200, "same-target go advances the live session", go.text);
    const afterGo = commentTexts((await request(first.port, "/review-state")).text);
    check(afterGo.includes(firstMarker), "Request Changes → go keeps the same-target round history", afterGo);
    check(!afterGo.includes(secondMarker), "same-target go does not import a different target conversation", afterGo);

    await stopServer(first.proc);
    await stopServer(second.proc);
    servers.splice(0, servers.length, sameNameA.proc, sameNameB.proc);

    const muxAB = await startServer(["review", "main"], repo.root, repo.lockDir);
    servers.push(muxAB.proc);
    await createRoundComment(muxAB.port, muxABMarker, 0);
    const muxABTexts = commentTexts((await request(muxAB.port, "/review-state?f=0")).text);
    check(muxABTexts.includes(muxABMarker) && !muxABTexts.includes(firstMarker) && !muxABTexts.includes(secondMarker), "mux AB does not inherit earlier single-file conversations", muxABTexts);
    check(await uiHasText(muxAB.port, muxABMarker, "/?f=0"), "mux AB UI shows its own round thread");
    check(!(await uiHasText(muxAB.port, firstMarker, "/?f=0")), "mux AB UI does not show the earlier single-file conversation");
    const reviewFilesAfterMuxAB = collectReviewJson(repo.root);
    check(reviewFilesAfterMuxAB.some((path) => reviewHasText(path, firstMarker)), "single-file history remains on disk after mux AB starts", reviewFilesAfterMuxAB);
    await stopServer(muxAB.proc);
    servers.splice(servers.indexOf(muxAB.proc), 1);

    const orderRepo = createRepo("order");
    const orderLegacyDir = join(orderRepo.root, ".yunomi", "reviews", "feature-session-isolation");
    mkdirSync(orderLegacyDir, { recursive: true });
    writeFileSync(
      join(orderLegacyDir, "review.json"),
      JSON.stringify(
        {
          version: 1,
          branch: "main",
          mux: true,
          files: ["second/report.md", "first/report.md"],
          rounds: [
            {
              round: 1,
              started_at: "2026-08-13T00:00:00.000Z",
              submitted_at: "2026-08-13T00:01:00.000Z",
              decision: "request_changes",
              summary: "reversed order session",
              results: {},
            },
          ],
          comments: [
            {
              id: "r-1",
              file: "",
              scope: "round",
              line: 0,
              round: 1,
              text: muxBAMarker,
              author: "human",
              status: "unresolved",
              replies: [],
              attachments: [],
            },
          ],
        },
        null,
        2,
      ),
    );
    const muxBA = await startServer(["go"], orderRepo.root, orderRepo.lockDir);
    servers.push(muxBA.proc);
    const muxBATexts = commentTexts((await request(muxBA.port, "/review-state?f=0")).text);
    check(muxBATexts.includes(muxBAMarker), "go continues the reversed-order mux session instead of dropping it", muxBATexts);
    await stopServer(muxBA.proc);
    servers.splice(servers.indexOf(muxBA.proc), 1);

    const muxABFromGit = await startServer(["review", "main"], orderRepo.root, orderRepo.lockDir);
    servers.push(muxABFromGit.proc);
    await createRoundComment(muxABFromGit.port, muxABMarker, 0);
    const muxGitTexts = commentTexts((await request(muxABFromGit.port, "/review-state?f=0")).text);
    check(muxGitTexts.includes(muxABMarker) && !muxGitTexts.includes(muxBAMarker), "mux file order AB does not receive BA conversation", muxGitTexts);
    check(!(await uiHasText(muxABFromGit.port, muxBAMarker, "/?f=0")), "mux order UI does not show the other ordered session");
    check(collectReviewJson(orderRepo.root).some((path) => reviewHasText(path, muxBAMarker)), "reversed-order mux history remains on disk after AB starts");
    await stopServer(muxABFromGit.proc);
    servers.splice(servers.indexOf(muxABFromGit.proc), 1);

    const firstAgain = await startServer([repo.firstFile], repo.root, repo.lockDir);
    servers.push(firstAgain.proc);
    const firstAgainTexts = commentTexts((await request(firstAgain.port, "/review-state")).text);
    check(firstAgainTexts.includes(firstMarker), "reopening the same target restores its round history", firstAgainTexts);
    check(!firstAgainTexts.includes(muxABMarker) && !firstAgainTexts.includes(secondMarker), "reopening the same target does not import mux or other-file conversations", firstAgainTexts);

    const other = await startServer([otherRepo.firstFile], otherRepo.root, otherRepo.lockDir);
    servers.push(other.proc);
    await createRoundComment(other.port, otherMarker);
    const otherTexts = commentTexts((await request(other.port, "/review-state")).text);
    check(otherTexts.includes(otherMarker) && !otherTexts.includes(firstMarker), "a different git root / worktree does not see this repo's conversation", otherTexts);

    const liveGo = spawnSync(process.execPath, [SERVER_JS, "go", "--no-open"], {
      cwd: otherRepo.root,
      encoding: "utf8",
      env: isolationEnv(otherRepo.lockDir),
    });
    check(liveGo.status === 0 && liveGo.stdout.includes("notified running review server"), "yunomi go notifies the unique live session for that identity", liveGo.stdout + liveGo.stderr);

    const identityFiles = collectReviewJson(repo.root).map((path) => relative(repo.root, path));
    check(
      identityFiles.some((path) => path.includes("sessions/")),
      "different identities are stored under session directories rather than overwriting the branch review.json",
      identityFiles,
    );
  } finally {
    await Promise.all(servers.map((proc) => stopServer(proc)));
  }

  if (process.exitCode && process.exitCode !== 0) {
    throw new Error("review session isolation contract failed");
  }
  console.log("review session isolation contract passed");
}

await main();
