import { spawn, spawnSync, type ChildProcess } from "node:child_process";
import { existsSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const SERVER_JS = process.env.YUNOMI_SERVER_JS || new URL("../_build/js/release/build/server/server.js", import.meta.url).pathname;
const DIST_SERVER_JS = process.env.YUNOMI_DIST_SERVER_JS || "";

type RunningServer = {
  proc: ChildProcess;
  port: number;
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

function isolationEnv(lockDir: string, extra: NodeJS.ProcessEnv = {}): NodeJS.ProcessEnv {
  const env = { ...process.env, HERDR_PANE_ID: "", YUNOMI_NOTIFY_CMD: "", YUNOMI_LOCK_DIR: lockDir, ...extra };
  delete env.YUNOMI_REVIEW_DIR;
  return env;
}

function createRepo(label: string): { root: string; lockDir: string; report: string } {
  const root = mkdtempSync(join(tmpdir(), `yunomi-cli-resolution-${label}-`));
  run("git", ["init", "-b", "main"], root);
  run("git", ["config", "user.email", "yunomi@example.test"], root);
  run("git", ["config", "user.name", "yunomi"], root);
  const report = join(root, "REPORT.md");
  writeFileSync(report, "# CLI resolution target\n\nbody\n");
  run("git", ["add", "."], root);
  run("git", ["commit", "-m", "cli resolution fixture"], root);
  return { root, lockDir: join(root, ".yunomi-locks"), report };
}

function writeLegacyReview(root: string, commentId: string, text: string, resolved = false): string {
  const dir = join(root, ".yunomi", "reviews", "main");
  mkdirSync(dir, { recursive: true });
  writeFileSync(
    join(dir, "review.json"),
    JSON.stringify(
      {
        version: 1,
        branch: "main",
        files: ["OTHER.md"],
        rounds: [{ round: 1, started_at: "2026-08-13T00:00:00.000Z", submitted_at: null, decision: null, summary: "" }],
        comments: [
          {
            id: commentId,
            file: "",
            scope: "round",
            round: 1,
            text,
            author: "human",
            status: resolved ? "resolved" : "unresolved",
            replies: [],
            attachments: [],
          },
        ],
      },
      null,
      2,
    ),
  );
  writeFileSync(join(dir, "server.json"), JSON.stringify({ pid: 2147483646, port: 1, file: "OTHER.md", updated_at: "2026-08-13T00:00:00.000Z" }));
  return dir;
}

function startServer(file: string, cwd: string, lockDir: string): Promise<RunningServer> {
  return new Promise((resolve, reject) => {
    let output = "";
    let started = false;
    const proc = spawn(process.execPath, [SERVER_JS, file, "--no-open", "--loop", "--port", "0"], {
      cwd,
      env: isolationEnv(lockDir),
      stdio: ["ignore", "pipe", "pipe"],
    });
    const observe = (chunk: Buffer | string) => {
      output += String(chunk);
      const match = output.match(/http:\/\/127\.0\.0\.1:(\d+)/);
      if (match && !started) {
        started = true;
        resolve({ proc, port: Number(match[1]) });
      }
    };
    proc.stdout?.on("data", observe);
    proc.stderr?.on("data", observe);
    proc.once("error", reject);
    proc.once("exit", (code) => {
      if (!started) reject(new Error(`server exited before listening (${code})\n${output}`));
    });
    setTimeout(() => {
      if (!started) reject(new Error(`server did not start\n${output}`));
    }, 15_000);
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

async function request(port: number, path: string, body?: unknown): Promise<{ status: number; text: string }> {
  const response = await fetch(`http://127.0.0.1:${port}${path}`, {
    method: body === undefined ? "GET" : "POST",
    headers: body === undefined ? undefined : { "Content-Type": "application/json" },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  return { status: response.status, text: await response.text() };
}

function cliReplyWith(serverJs: string, cwd: string, lockDir: string, id: string, text: string, extra: NodeJS.ProcessEnv = {}) {
  return spawnSync(process.execPath, [serverJs, "reply", id, text], {
    cwd,
    encoding: "utf8",
    env: isolationEnv(lockDir, extra),
  });
}

function cliReply(cwd: string, lockDir: string, id: string, text: string, extra: NodeJS.ProcessEnv = {}) {
  return cliReplyWith(SERVER_JS, cwd, lockDir, id, text, extra);
}

function cliGo(cwd: string, lockDir: string) {
  return spawnSync(process.execPath, [SERVER_JS, "go"], {
    cwd,
    encoding: "utf8",
    env: isolationEnv(lockDir),
  });
}

function sessionReviewHasReply(root: string, marker: string): boolean {
  const sessions = join(root, ".yunomi", "reviews", "main", "sessions");
  if (!existsSync(sessions)) return false;
  for (const name of readdirSync(sessions)) {
    const reviewPath = join(sessions, name, "review.json");
    if (existsSync(reviewPath) && readFileSync(reviewPath, "utf8").includes(marker)) return true;
  }
  return false;
}

async function main(): Promise<void> {
  const liveRepo = createRepo("live");
  const noLiveRepo = createRepo("nolive");
  const collisionRepo = createRepo("collision");
  const multiLiveRepo = createRepo("multilive");
  const servers: ChildProcess[] = [];
  try {
    writeLegacyReview(liveRepo.root, "legacy-round", "legacy leftover conversation");
    const live = await startServer(liveRepo.report, liveRepo.root, liveRepo.lockDir);
    servers.push(live.proc);
    const created = await request(live.port, "/create-global-comment", { text: "live session thread" });
    check(created.status === 200, "live session accepts a round comment", created.text);
    const liveId = JSON.parse(created.text).id as string;
    check(Boolean(liveId), "live session returns a comment id");

    if (DIST_SERVER_JS) {
      const red = cliReplyWith(DIST_SERVER_JS, liveRepo.root, liveRepo.lockDir, liveId, "old dist should miss unique live");
      check(
        red.status !== 0 && red.stderr.includes("does not exist"),
        "old packaged CLI misses the unique live session when leftover legacy review.json remains",
        red.stdout + red.stderr,
      );
    }

    const missed = cliReply(liveRepo.root, liveRepo.lockDir, liveId, "cli reply without override");
    check(
      missed.status === 0 && missed.stdout.includes("notified running review server"),
      "yunomi reply without YUNOMI_REVIEW_DIR reaches the unique live session",
      missed.stdout + missed.stderr,
    );
    const liveState = JSON.parse((await request(live.port, "/review-state")).text);
    const liveThread = (liveState.review?.comments || []).find((row: { id?: string }) => row.id === liveId);
    check(liveThread?.replies?.at(-1)?.text === "cli reply without override", "the unique live session stores the CLI reply", liveThread);
    check(
      !readFileSync(join(liveRepo.root, ".yunomi", "reviews", "main", "review.json"), "utf8").includes("cli reply without override"),
      "the leftover legacy review.json is not used for the live-session reply",
    );
    const goLive = cliGo(liveRepo.root, liveRepo.lockDir);
    check(
      goLive.status === 0 && goLive.stdout.includes("notified running review server"),
      "yunomi go without YUNOMI_REVIEW_DIR notifies the unique live session",
      goLive.stdout + goLive.stderr,
    );

    const missing = cliReply(liveRepo.root, liveRepo.lockDir, "no-such-thread", "ghost");
    check(missing.status !== 0 && missing.stderr.includes("does not exist"), "missing thread id fail-closes", missing.stderr);

    const resolvedId = liveId;
    await request(live.port, "/resolve-comment", { id: resolvedId });
    const resolvedReply = cliReply(liveRepo.root, liveRepo.lockDir, resolvedId, "after resolve");
    check(resolvedReply.status !== 0 && resolvedReply.stderr.includes("resolved or does not exist"), "resolved thread fail-closes", resolvedReply.stderr);

    writeLegacyReview(noLiveRepo.root, "stored-only", "stored thread without live server");
    const storedDir = join(noLiveRepo.root, ".yunomi", "reviews", "main", "sessions", "dead-session");
    mkdirSync(storedDir, { recursive: true });
    writeFileSync(
      join(storedDir, "review.json"),
      JSON.stringify(
        {
          version: 1,
          branch: "main",
          files: ["REPORT.md"],
          comments: [
            {
              id: "r-stored-1",
              file: "",
              scope: "round",
              round: 1,
              text: "unique stored thread",
              author: "human",
              status: "unresolved",
              replies: [],
            },
          ],
        },
        null,
        2,
      ),
    );
    const storedReply = cliReply(noLiveRepo.root, noLiveRepo.lockDir, "r-stored-1", "offline unique reply");
    check(
      storedReply.status === 0 && (storedReply.stdout.includes("wrote review.json") || storedReply.stdout.includes("notified")),
      "with no live server, a uniquely stored thread id is replied in that session",
      storedReply.stdout + storedReply.stderr,
    );
    check(readFileSync(join(storedDir, "review.json"), "utf8").includes("offline unique reply"), "the unique stored session keeps the offline reply");
    check(
      !readFileSync(join(noLiveRepo.root, ".yunomi", "reviews", "main", "review.json"), "utf8").includes("offline unique reply"),
      "offline unique-id reply does not write the leftover legacy review.json",
    );
    const goOffline = cliGo(noLiveRepo.root, noLiveRepo.lockDir);
    check(
      goOffline.status !== 0 && goOffline.stderr.includes("multiple"),
      "yunomi go fail-closes when leftover and stored sessions exist and nothing is live",
      goOffline.stdout + goOffline.stderr,
    );

    writeLegacyReview(collisionRepo.root, "r-1-1", "legacy collision thread");
    const collisionDir = join(collisionRepo.root, ".yunomi", "reviews", "main", "sessions", "other-session");
    mkdirSync(collisionDir, { recursive: true });
    writeFileSync(
      join(collisionDir, "review.json"),
      JSON.stringify(
        {
          version: 1,
          branch: "main",
          files: ["REPORT.md"],
          comments: [
            {
              id: "r-1-1",
              file: "",
              scope: "round",
              round: 1,
              text: "session collision thread",
              author: "human",
              status: "unresolved",
              replies: [],
            },
          ],
        },
        null,
        2,
      ),
    );
    const collision = cliReply(collisionRepo.root, collisionRepo.lockDir, "r-1-1", "should not guess");
    check(
      collision.status !== 0 && (collision.stderr.includes("multiple") || collision.stderr.includes("collision") || collision.stderr.includes("refuse")),
      "the same thread id in two stored sessions fail-closes",
      collision.stdout + collision.stderr,
    );

    const first = await startServer(multiLiveRepo.report, multiLiveRepo.root, multiLiveRepo.lockDir);
    servers.push(first.proc);
    const secondFile = join(multiLiveRepo.root, "SECOND.md");
    writeFileSync(secondFile, "# Second live target\n");
    run("git", ["add", "."], multiLiveRepo.root);
    run("git", ["commit", "-m", "second live file"], multiLiveRepo.root);
    const second = await startServer(secondFile, multiLiveRepo.root, multiLiveRepo.lockDir);
    servers.push(second.proc);
    const firstComment = await request(first.port, "/create-global-comment", { text: "first live thread" });
    check(firstComment.status === 200, "first live session accepts a round comment", firstComment.text);
    const firstId = JSON.parse(firstComment.text).id as string;
    const multi = cliReply(multiLiveRepo.root, multiLiveRepo.lockDir, firstId, "ambiguous live");
    check(
      multi.status !== 0 && (multi.stderr.includes("multiple") || multi.stderr.includes("refuse")),
      "multiple live sessions fail-closed even when one thread id is unique",
      multi.stdout + multi.stderr,
    );
    const goMulti = cliGo(multiLiveRepo.root, multiLiveRepo.lockDir);
    check(
      goMulti.status !== 0 && (goMulti.stderr.includes("multiple") || goMulti.stderr.includes("refuse")),
      "yunomi go fail-closes when multiple live sessions exist",
      goMulti.stdout + goMulti.stderr,
    );

    check(sessionReviewHasReply(liveRepo.root, "cli reply without override"), "live session directory remains after CLI reply");
  } finally {
    await Promise.all(servers.map((proc) => stopServer(proc)));
  }

  if (process.exitCode && process.exitCode !== 0) {
    throw new Error("review session CLI resolution contract failed");
  }
  console.log("review session CLI resolution contract passed");
}

await main();
