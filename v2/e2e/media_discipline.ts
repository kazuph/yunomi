/**
 * Media Embed Discipline E2E Test
 *
 * yunomi must refuse to start (exit 1, fix-it message) when a markdown file
 * references media with [text](path) link syntax instead of ![alt](path)
 * embeds, so the calling AI agent can auto-fix the markdown.
 *
 * Run: node --experimental-strip-types v2/e2e/media_discipline.ts
 */
import { spawn } from "node:child_process";
import { mkdtempSync, writeFileSync, rmSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { fileURLToPath } from "node:url";

const __dirname = fileURLToPath(new URL(".", import.meta.url));
const SERVER_JS = join(__dirname, "..", "_build", "js", "release", "build", "server", "server.js");
const WORK_DIR = mkdtempSync(join(tmpdir(), "yunomi-media-discipline-"));
const LOCK_DIR = join(WORK_DIR, "locks");

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

function runYunomi(file: string, port: number, killAfterMs: number): Promise<RunResult> {
  return new Promise((resolve) => {
    const proc = spawn("node", [SERVER_JS, file, "--no-open", "--port", String(port)], {
      stdio: ["ignore", "pipe", "pipe"],
      env: { ...process.env, YUNOMI_LOCK_DIR: LOCK_DIR, YUNOMI_REVIEW_DIR: join(tmpdir(), "yunomi-review-" + Date.now() + "-" + Math.random().toString(36).slice(2,6)) },
    });
    let stdout = "";
    let stderr = "";
    proc.stdout.on("data", (d: Buffer) => { stdout += String(d); });
    proc.stderr.on("data", (d: Buffer) => { stderr += String(d); });
    const killer = setTimeout(() => proc.kill("SIGKILL"), killAfterMs);
    proc.on("exit", (code: number | null) => {
      clearTimeout(killer);
      resolve({ code, stdout, stderr });
    });
  });
}

try {
  // --- Violating markdown: must exit 1 with actionable fix message ---
  const badMd = join(WORK_DIR, "bad.md");
  writeFileSync(badMd, [
    "# Report",
    "",
    "🎬 demo: [demo.webm](videos/demo.webm)",
    "",
    "[before](images/before.png) vs ![after](images/after.png)",
    "",
    "normal [docs](https://example.com/page) link is fine",
    "",
    "```",
    "[in fence](skip.mp4)",
    "```",
    "",
    "inline `[in code](skip2.mp4)` is fine",
  ].join("\n"));

  const bad = await runYunomi(badMd, 5371, 10000);
  assert(bad.code === 1, "違反markdownで exit code 1 になる", bad);
  const combined = bad.stdout + bad.stderr;
  assert(
    combined.includes("media embed discipline violation"),
    "規律違反のエラーヘッダーが出る",
    { combined },
  );
  assert(
    combined.includes("line 3:") && combined.includes("![demo.webm](videos/demo.webm)"),
    "違反行番号と ![]() の修正案が提示される（動画リンク）",
    { combined },
  );
  assert(
    combined.includes("line 5:") && combined.includes("![before](images/before.png)"),
    "画像リンクも検出される",
    { combined },
  );
  assert(
    !combined.includes("skip.mp4") && !combined.includes("skip2.mp4"),
    "コードフェンス/インラインコード内のリンクは検出されない",
    { combined },
  );
  assert(
    !combined.includes("example.com"),
    "メディア以外への通常リンクは検出されない",
    { combined },
  );

  // --- Clean markdown: must start the server normally ---
  const goodMd = join(WORK_DIR, "good.md");
  writeFileSync(goodMd, [
    "# Report",
    "",
    "| video | image |",
    "|---|---|",
    "| ![demo](videos/demo.webm) | ![before](images/before.png) |",
    "",
    "[docs](https://example.com/page)",
  ].join("\n"));

  const good = await runYunomi(goodMd, 5372, 4000);
  // Killed by our timeout (= server stayed up), so exit code is not 1
  assert(good.code !== 1, "規律準拠のmarkdownは正常にサーバー起動する", good);
  assert(
    (good.stdout + good.stderr).includes("yunomi serving"),
    "serving メッセージが出る",
    { stdout: good.stdout, stderr: good.stderr },
  );
} finally {
  rmSync(WORK_DIR, { recursive: true, force: true });
}

console.log(`\nResults: ${passed} passed, ${failed} failed`);
if (failed > 0) process.exitCode = 1;
