import { spawn, spawnSync, type ChildProcess } from "node:child_process";
import { mkdtempSync, rmSync, writeFileSync, mkdirSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const SERVER_JS = new URL("../_build/js/release/build/server/server.js", import.meta.url).pathname;
const WORK_DIR = mkdtempSync(join(tmpdir(), "yunomi-auto-review-"));
const REPO = join(WORK_DIR, "repo");
const LOCK_DIR = join(WORK_DIR, "locks");
const REVIEW_DIR = join(WORK_DIR, "reviews");
const BASE_PORT = 5861;

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

function run(cmd: string, args: string[], cwd: string): void {
  const result = spawnSync(cmd, args, { cwd, encoding: "utf8" });
  if (result.status !== 0) {
    throw new Error(`${cmd} ${args.join(" ")} failed\n${result.stdout}\n${result.stderr}`);
  }
}

function waitForServer(proc: ChildProcess): Promise<string> {
  return new Promise((resolve, reject) => {
    let output = "";
    const check = () => {
      if (output.includes(`http://127.0.0.1:${BASE_PORT}`)) resolve(output);
    };
    proc.stdout?.on("data", (d) => {
      output += String(d);
      check();
    });
    proc.stderr?.on("data", (d) => {
      output += String(d);
      check();
    });
    proc.on("exit", (code) => reject(new Error(`server exited early ${code}\n${output}`)));
    setTimeout(() => reject(new Error(`server did not start\n${output}`)), 15000);
  });
}

async function fetchText(path: string): Promise<string> {
  const res = await fetch(`http://127.0.0.1:${BASE_PORT}${path}`);
  return await res.text();
}

async function stop(proc: ChildProcess): Promise<void> {
  await new Promise<void>((resolve) => {
    proc.once("exit", () => resolve());
    proc.kill("SIGINT");
    setTimeout(() => {
      proc.kill("SIGKILL");
      resolve();
    }, 3000);
  });
}

try {
  mkdirSync(REPO, { recursive: true });
  run("git", ["init", "-b", "main"], REPO);
  run("git", ["config", "user.email", "yunomi@example.test"], REPO);
  run("git", ["config", "user.name", "yunomi"], REPO);
  writeFileSync(join(REPO, "report.md"), "# Base\n");
  writeFileSync(join(REPO, "data.csv"), "name,status\nbase,ok\n");
  writeFileSync(join(REPO, "notes.txt"), "base\n");
  run("git", ["add", "."], REPO);
  run("git", ["commit", "-m", "base"], REPO);
  run("git", ["checkout", "-b", "feature/auto-review-e2e"], REPO);
  writeFileSync(join(REPO, "report.md"), "# Changed report\n\nHello review.\n");
  writeFileSync(join(REPO, "data.csv"), "name,status\nalpha,ready\n");
  writeFileSync(join(REPO, "notes.txt"), "plain text changed\n");
  run("git", ["add", "."], REPO);
  run("git", ["commit", "-m", "change three files"], REPO);

  const proc = spawn(process.execPath, [
    SERVER_JS,
    "review",
    "main",
    "--no-open",
    "--port",
    String(BASE_PORT),
  ], {
    cwd: REPO,
    stdio: ["ignore", "pipe", "pipe"],
    env: { ...process.env, HERDR_PANE_ID: "", YUNOMI_NOTIFY_CMD: "", YUNOMI_LOCK_DIR: LOCK_DIR, YUNOMI_REVIEW_DIR: REVIEW_DIR },
  });

  await waitForServer(proc);
  try {
    const pages = [
      await fetchText("/?f=0"),
      await fetchText("/?f=1"),
      await fetchText("/?f=2"),
    ];
    const joined = pages.join("\n---PAGE---\n");
    const first = pages[0];
    assert(first.includes("review-file-switcher"), "yunomi review renders a file switcher");
    assert(joined.includes("report.md") && joined.includes("Changed report"), "one ?f page renders changed markdown");
    assert(joined.includes("__YUNOMI_MODE__=\"csv\"") && joined.includes("alpha"), "one ?f page renders changed CSV in the same server");
    assert(joined.includes("__YUNOMI_MODE__=\"text\"") && joined.includes("plain text changed"), "one ?f page renders changed text in the same server");
    assert(first.includes("/?f=1") && first.includes("/?f=2"), "file switcher links point at ?f indexes");
  } finally {
    await stop(proc);
  }

  const nonGit = spawnSync(process.execPath, [SERVER_JS, "review", "--no-open", "--port", String(BASE_PORT + 1)], {
    cwd: WORK_DIR,
    encoding: "utf8",
    env: { ...process.env, HERDR_PANE_ID: "", YUNOMI_NOTIFY_CMD: "", YUNOMI_LOCK_DIR: LOCK_DIR, YUNOMI_REVIEW_DIR: REVIEW_DIR },
  });
  assert(nonGit.status === 1, "non-git directory exits 1");
  assert((nonGit.stderr + nonGit.stdout).includes("not a git repository"), "non-git error explains repository requirement");

  if (failed > 0) process.exit(1);
  console.log(`\nAuto review E2E: ${passed} passed, ${failed} failed`);
} finally {
  rmSync(WORK_DIR, { recursive: true, force: true });
}
