/**
 * Herdr delivery contract E2E with a fake `herdr` binary on PATH.
 *
 * - upstream shape: only `herdr agent send` exists (ogulcancelik/herdr).
 * - fork shape: `herdr agent send` plus durable `herdr send <to> <text> --room`.
 *
 * Asserts: yunomi never calls `agent prompt`, resolves the contract once,
 * uses `agent send` by default, uses `send --room` with --notify-room on the
 * fork, and refuses to start with --notify-room on the upstream shape.
 *
 * Run: node --experimental-strip-types v2/e2e/herdr_contract_fake.ts
 */
import { spawn, type ChildProcess } from "node:child_process";
import { chmodSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { chromium } from "playwright";

const SERVER_JS = new URL("../_build/js/release/build/server/server.js", import.meta.url).pathname;
const WORK = mkdtempSync(join(tmpdir(), "yunomi-herdr-fake-"));
const CALLS = join(WORK, "calls.log");
let failed = 0;
function assert(c: boolean, msg: string, detail?: unknown) {
  if (c) console.log(`PASS: ${msg}`);
  else { failed++; console.error(`FAIL: ${msg}`); if (detail !== undefined) console.error(JSON.stringify(detail, null, 2)); }
}

function fakeHerdr(shape: "upstream" | "fork"): string {
  const dir = join(WORK, `bin-${shape}`);
  mkdirSync(dir, { recursive: true });
  const send = shape === "fork"
    ? `if [ "$1" = "send" ]; then
  if [ "$2" = "--help" ]; then printf 'herdr send commands:\\n  herdr send <to> <text> [--room R] [--reply-to ID] [--from NAME]\\n'; exit 0; fi
  exit 0
fi`
    : `if [ "$1" = "send" ]; then echo "unknown command: send" >&2; exit 2; fi`;
  writeFileSync(join(dir, "herdr"), `#!/bin/sh
printf '%s\\n' "$*" >> "${CALLS}"
if [ "$1" = "agent" ]; then
  case "$2" in
    help|--help|-h) printf 'herdr agent commands:\\n  herdr agent list\\n  herdr agent send <target> <text>\\n'; exit 0;;
    send) exit 0;;
    *) printf 'herdr agent commands:\\n  herdr agent send <target> <text>\\n' >&2; exit 2;;
  esac
fi
${send}
echo "unknown" >&2; exit 2
`);
  chmodSync(join(dir, "herdr"), 0o755);
  return dir;
}

function startServer(binDir: string, extra: string[]): Promise<{ proc: ChildProcess; port: number; out: () => string; exited: Promise<number | null> }> {
  const report = join(WORK, "REPORT.md");
  writeFileSync(report, "# contract\n\nbody\n");
  const proc = spawn(process.execPath, [SERVER_JS, report, "--loop", "--no-open", "--port", "0", "--notify-pane", "p_7", ...extra], {
    cwd: WORK,
    env: { ...process.env, PATH: `${binDir}:${process.env.PATH}`, HERDR_PANE_ID: "", TMUX_PANE: "", YUNOMI_NOTIFY_CMD: "", YUNOMI_LOCK_DIR: join(WORK, "locks"), YUNOMI_REVIEW_DIR: join(WORK, "reviews-" + Date.now()) },
    stdio: ["ignore", "pipe", "pipe"],
  });
  let out = "";
  const exited = new Promise<number | null>((r) => proc.on("exit", (code) => r(code)));
  return new Promise((resolve, reject) => {
    const onData = (d: Buffer) => {
      out += String(d);
      const m = out.match(/http:\/\/127\.0\.0\.1:(\d+)/);
      if (m) resolve({ proc, port: Number(m[1]), out: () => out, exited });
    };
    proc.stdout.on("data", onData); proc.stderr.on("data", onData);
    exited.then(() => resolve({ proc, port: 0, out: () => out, exited }));
    setTimeout(() => reject(new Error(`server start timeout\n${out}`)), 10000);
  });
}
const stop = (p: ChildProcess) => new Promise<void>((r) => { p.on("exit", () => r()); p.kill("SIGINT"); setTimeout(() => { p.kill("SIGKILL"); r(); }, 3000); });
const calls = () => (readFileSync(CALLS, "utf8").trim() ? readFileSync(CALLS, "utf8").trim().split("\n") : []);

async function openAndClose(port: number) {
  const browser = await chromium.launch();
  const page = await browser.newPage();
  await page.goto(`http://127.0.0.1:${port}/`, { waitUntil: "domcontentloaded" });
  await page.waitForTimeout(300);
  await page.goto("about:blank");
  await new Promise((r) => setTimeout(r, 2200));
  await browser.close();
}

try {
  // A. upstream shape, default route → agent send, no agent prompt
  writeFileSync(CALLS, "");
  const up = await startServer(fakeHerdr("upstream"), []);
  await openAndClose(up.port);
  const upCalls = calls();
  assert(!upCalls.some((c) => c.startsWith("agent prompt")), "本家shapeで `agent prompt` を一切呼ばない", { upCalls });
  assert(upCalls.filter((c) => c === "agent help").length === 1, "契約解決は起動後1回だけ（`agent help` が1回）", { upCalls });
  assert(upCalls.some((c) => /^agent send p_7 \[yunomi\] tab closed/.test(c)), "本家shapeでは `agent send <pane> <msg>` で配送する", { upCalls });
  await stop(up.proc);

  // B. fork shape with --notify-room → send --room
  writeFileSync(CALLS, "");
  const fk = await startServer(fakeHerdr("fork"), ["--notify-room", "task-42"]);
  await openAndClose(fk.port);
  const fkCalls = calls();
  assert(fkCalls.some((c) => /^send p_7 \[yunomi\] tab closed .* --room task-42$/.test(c)), "fork shape + --notify-room では `herdr send <pane> <msg> --room <room>` で配送する", { fkCalls });
  assert(!fkCalls.some((c) => c.startsWith("agent send")), "--notify-room 指定時は pane への直打ち（agent send）をしない", { fkCalls });
  await stop(fk.proc);

  // C. upstream shape with --notify-room → refuse to start
  writeFileSync(CALLS, "");
  const refused = await startServer(fakeHerdr("upstream"), ["--notify-room", "task-42"]);
  const code = await refused.exited;
  assert(code === 1 && /does not expose `herdr send <to> <text> --room`/.test(refused.out()), "本家shape + --notify-room は起動を拒否する（exit 1・理由付き）", { code, out: refused.out() });
} finally {
  rmSync(WORK, { recursive: true, force: true });
}
console.log(`\nResults: ${failed === 0 ? "all passed" : failed + " failed"}`);
if (failed > 0) process.exitCode = 1;
