/**
 * Instant Skill E2E Test
 *
 * `yunomi` with no arguments must teach an AI agent the whole approval
 * protocol on the spot:
 *   - `yunomi --skill` prints the skill document and exits 0
 *   - no args + TTY stdin prints the same document (covered via --skill;
 *     the TTY branch is exercised with a pty when available)
 *   - empty piped stdin still prints usage and exits 1 (script safety)
 *   - the document carries the load-bearing sections an agent needs
 *
 * Run: node --experimental-strip-types v2/e2e/instant_skill.ts
 */
import { spawnSync } from "node:child_process";
import {
  closeSync,
  mkdtempSync,
  openSync,
  readFileSync,
  rmSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = fileURLToPath(new URL(".", import.meta.url));
const SERVER_JS = join(__dirname, "..", "_build", "js", "release", "build", "server", "server.js");

let passed = 0;
let failed = 0;

function assert(condition: boolean, msg: string, detail?: unknown): void {
  if (condition) {
    passed++;
    console.log(`  PASS: ${msg}`);
  } else {
    failed++;
    console.error(`  FAIL: ${msg}`);
    if (detail !== undefined) console.error(JSON.stringify(detail, null, 2));
  }
}

interface RunResult {
  code: number | null;
  stdout: string;
  stderr: string;
}

function run(cmd: string, args: string[], stdin: "ignore" | "pipe"): RunResult {
  const outputDir = mkdtempSync(join(tmpdir(), "yunomi-skill-e2e-"));
  const outputPath = join(outputDir, "stdout.txt");
  const outputFd = openSync(outputPath, "w");
  try {
    const result = spawnSync(cmd, args, {
      encoding: "utf8",
      input: stdin === "pipe" ? "" : undefined,
      stdio: [stdin, outputFd, "pipe"],
      timeout: 15000,
    });
    closeSync(outputFd);
    return {
      code: result.status,
      stdout: readFileSync(outputPath, "utf8"),
      stderr: result.stderr || "",
    };
  } finally {
    try { closeSync(outputFd); } catch {}
    rmSync(outputDir, { recursive: true, force: true });
  }
}

// --- yunomi --skill: skill document, exit 0 ---
const skill = await run("node", [SERVER_JS, "--skill"], "ignore");
assert(skill.code === 0, "--skill は exit 0", skill.code);
assert(skill.stdout.startsWith("# yunomi"), "出力はスキル文書タイトルから始まる（前置きノイズなし）", skill.stdout.slice(0, 80));
for (const section of [
  "## The approval loop",
  "## REPORT.md rules",
  "## Verdict schema",
  "## v3 review commands",
  "## Install this skill permanently",
  "Writable reviews must use --loop",
  "npx yunomi REPORT.md",
  "--notify-pane \"$PANE_ID\"",
  "herdr pane get \"$PANE_ID\"",
  "YUNOMI_ROUTE=herdr",
  "YUNOMI_ROUTE=tmux",
  "If `YUNOMI_ROUTE=herdr`",
  "If `YUNOMI_ROUTE=tmux`",
  "no proven yunomi notification route",
  "`--notify-pane` is Herdr-only",
  "`--notify-tmux-pane` is tmux-only",
  "--notify-tmux-pane \"$TMUX_PANE_ID\"",
  "tmux display-message -p -t \"$TMUX_PANE_ID\"",
  "`yunomi share` is the explicit read-only exception",
  "Never start a writable review without a proven notification route",
  "decision: approve | request_changes",
  "yunomi push <review-id> <pr>",
  "attachments: []",
  "![alt](path)",
  "~/.claude/skills/yunomi/SKILL.md",
]) {
  assert(skill.stdout.includes(section), `スキル文書に「${section}」が含まれる`);
}
assert(
  !skill.stdout.includes("herdr run --label yunomi --cwd /absolute/path/to/repo -- npx yunomi REPORT.md --loop\n"),
  "通知先なしのHerdr起動例をスキル文書に残さない",
);
assert(!skill.stdout.includes("YUNOMI_LIVE"), "スキル文書にライブログ行が混ざらない");

// --- no args + TTY: same document (via script(1) pty on macOS/Linux) ---
const tty = await run("script", ["-q", "/dev/null", "node", SERVER_JS], "ignore");
if (tty.code === 0 || tty.stdout.length > 0) {
  assert(tty.stdout.includes("# yunomi"), "TTYで引数なし実行するとスキル文書が出る", tty.stdout.slice(0, 120));
  assert(tty.stdout.includes("## Install this skill permanently"), "TTY出力にも永続インストール節がある");
} else {
  console.log("  SKIP: script(1) が使えない環境のため TTY 分岐は --skill で代替検証済み");
}

// --- empty piped stdin: usage + exit 1 (keeps broken pipelines loud) ---
const empty = await run("node", [SERVER_JS], "pipe");
assert(empty.code === 1, "空のパイプ入力は exit 1", empty.code);
assert(empty.stdout.includes("Usage: yunomi"), "空パイプではUsageを表示", empty.stdout.slice(0, 120));

console.log(`\nResults: ${passed} passed, ${failed} failed`);
if (failed > 0) process.exitCode = 1;
