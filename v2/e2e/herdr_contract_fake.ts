/**
 * Herdr delivery contract E2E with a fake `herdr` binary on PATH.
 *
 * - upstream shape (herdrdev/herdr 0.7.5+): `herdr agent prompt` and
 *   `agent send-keys`; `agent send` was removed and there is no `herdr send`.
 * - fork shape (kazuph fork 0.2.5+): `herdr agent prompt`, the retained
 *   `agent send`, and the durable `herdr send <to> <text> --room`.
 * - legacy shape (upstream <= 0.7.4, kazuph fork <= 0.2.4): only
 *   `herdr agent send`.
 *
 * The fake prints each shape's real `herdr agent help` text to stderr (copied
 * from upstream 0.9.1, the fork build, and fork 0.2.3), rejects `agent prompt`
 * unless it gets exactly <target> <text>, and records every argv as JSON so a
 * multi-line notification can be compared as one exact argument.
 *
 * Asserts: yunomi resolves the contract once, delivers through the common
 * `agent prompt` on upstream and fork with the full multi-line message as one
 * argument, never calls `agent send`, reports a named delivery failure on the
 * legacy shape, uses `send --room` with --notify-room on the fork, and refuses
 * to start with --notify-room on the upstream shape.
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
const CALLS = join(WORK, "calls.jsonl");
let failed = 0;
function assert(c: boolean, msg: string, detail?: unknown) {
  if (c) console.log(`PASS: ${msg}`);
  else { failed++; console.error(`FAIL: ${msg}`); if (detail !== undefined) console.error(JSON.stringify(detail, null, 2)); }
}

type Shape = "upstream" | "fork" | "legacy";
const AGENT_HELP: Record<Shape, string> = {
  upstream: `herdr agent commands:
  herdr agent list
  herdr agent get <target>
  herdr agent read <target> [--source visible|recent|recent-unwrapped|detection] [--lines N] [--format text|ansi] [--ansi]
  herdr agent send-keys <target> <key> [key ...]
  herdr agent prompt <target> <text> [--wait] [--until STATUS]... [--timeout MS]
  herdr agent rename <target> <name>|--clear
  herdr agent focus <target>
  herdr agent wait <target> [--until STATUS]... [--timeout MS]
  herdr agent attach <target> [--takeover]
  herdr agent start <name> --kind KIND --pane ID [--timeout MS] [-- <agent-args...>]
  herdr agent explain <target> [--json|--format text|json] [--verbose]
  herdr agent explain --file PATH --agent LABEL [--json|--format text|json] [--verbose]
  targets accept unique agent names and pane ids that currently host agents
  kinds: pi|claude|codex|gemini|cursor|devin|agy|cline|omp|mastracode|opencode|copilot|kimi|kiro|droid|amp|grok|hermes|kilo|qodercli|qwen|letta|maki|muse
`,
  fork: `herdr agent commands:
  herdr agent list
  herdr agent get <target>
  herdr agent read <target> [--source visible|recent|recent-unwrapped] [--lines N] [--format text|ansi] [--ansi]
  herdr agent prompt <target> <text>
  herdr agent send <target> <text>
  herdr agent rename <target> <name>|--clear
  herdr agent focus <target>
  herdr agent wait <target> --status <idle|working|blocked|unknown> [--timeout MS]
  herdr agent attach <target> [--takeover]
  herdr agent start <name> [--cwd PATH] [--workspace ID] [--tab ID] [--split right|down] [--env KEY=VALUE] [--focus|--no-focus] -- <argv...>
  herdr agent restore [--dry-run]
  herdr agent explain <target> [--json]
  herdr agent explain --file PATH --agent LABEL [--json]
  targets accept terminal ids, unique agent names, detected/reported agent labels, and legacy pane ids
  agent prompt and agent send write text and submit it with Enter
`,
  legacy: `herdr agent commands:
  herdr agent list
  herdr agent get <target>
  herdr agent read <target> [--source visible|recent|recent-unwrapped] [--lines N] [--format text|ansi] [--ansi]
  herdr agent send <target> <text>
  herdr agent rename <target> <name>|--clear
  herdr agent focus <target>
  herdr agent wait <target> --status <idle|working|blocked|unknown> [--timeout MS]
  herdr agent attach <target> [--takeover]
  herdr agent start <name> [--cwd PATH] [--workspace ID] [--tab ID] [--split right|down] [--env KEY=VALUE] [--focus|--no-focus] -- <argv...>
  herdr agent restore [--dry-run]
  herdr agent explain <target> [--json]
  herdr agent explain --file PATH --agent LABEL [--json]
  targets accept terminal ids, unique agent names, detected/reported agent labels, and legacy pane ids
  agent send writes text and submits it with Enter
`,
};
const FORK_SEND_HELP = `herdr send commands:
  herdr send <to> <text> [--room R] [--reply-to ID] [--from NAME]
  targets accept agent names or pane targets
`;

function fakeHerdr(shape: Shape): string {
  const dir = join(WORK, `bin-${shape}`);
  mkdirSync(dir, { recursive: true });
  const has = { prompt: shape !== "legacy", agentSend: shape !== "upstream", sendRoom: shape === "fork" };
  writeFileSync(join(dir, "herdr"), `#!${process.execPath}
const fs = require("node:fs");
const args = process.argv.slice(2);
fs.appendFileSync(${JSON.stringify(CALLS)}, JSON.stringify(args) + "\\n");
const help = ${JSON.stringify(AGENT_HELP[shape])};
const has = ${JSON.stringify(has)};
const exit = (code, err) => { if (err) process.stderr.write(err); process.exit(code); };
if (args[0] === "agent") {
  if (["help", "--help", "-h"].includes(args[1])) exit(0, help);
  if (args[1] === "prompt" && has.prompt) exit(args.length === 4 ? 0 : 2, args.length === 4 ? "" : "usage: herdr agent prompt <target> <text>\\n");
  if (args[1] === "send" && has.agentSend) exit(args.length >= 4 ? 0 : 2);
  exit(2, help);
}
if (args[0] === "send" && has.sendRoom) {
  if (args[1] === "--help") { process.stdout.write(${JSON.stringify(FORK_SEND_HELP)}); exit(0); }
  exit(0);
}
exit(2, "herdr — terminal workspace manager for AI coding agents\\n");
`);
  chmodSync(join(dir, "herdr"), 0o755);
  return dir;
}

function startServer(binDir: string, extra: string[]): Promise<{ proc: ChildProcess; port: number; out: () => string; exited: Promise<number | null> }> {
  const report = join(WORK, "REPORT.md");
  writeFileSync(report, "# contract\n\n- [ ] 通知を確認する\n");
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
const calls = (): string[][] => readFileSync(CALLS, "utf8").split("\n").filter(Boolean).map((l) => JSON.parse(l));

async function waitFor(label: string, condition: () => boolean, detail: () => unknown, timeoutMs = 8000) {
  const deadline = Date.now() + timeoutMs;
  while (!condition() && Date.now() < deadline) await new Promise((r) => setTimeout(r, 50));
  assert(condition(), `${label}（${timeoutMs}ms以内に観測）`, condition() ? undefined : detail());
}

// Clicks the checkbox decision (a multi-line notification: header, quoted
// line, url) and then leaves the tab (a one-line `tab closed` notification).
async function decideAndClose(port: number) {
  const browser = await chromium.launch();
  const page = await browser.newPage();
  await page.goto(`http://127.0.0.1:${port}/`, { waitUntil: "domcontentloaded" });
  await page.locator(".task-decision-checkbox").first().click();
  await page.waitForFunction(() => document.querySelector<HTMLInputElement>(".task-decision-checkbox")?.checked === true);
  await page.goto("about:blank");
  await browser.close();
}

const isDecision = (text: string) => /^\[yunomi\] decision REPORT\.md:3 checked=true\n> - \[x\] 通知を確認する\nurl=http:\/\/127\.0\.0\.1:\d+$/.test(text);
const promptDecision = (c: string[]) => c.length === 4 && c[0] === "agent" && c[1] === "prompt" && c[2] === "p_7" && isDecision(c[3]);
const promptClosed = (c: string[]) => c[0] === "agent" && c[1] === "prompt" && c[2] === "p_7" && /^\[yunomi\] tab closed/.test(c[3] ?? "");

try {
  // A. upstream shape, default route → agent prompt with the exact message
  writeFileSync(CALLS, "");
  const up = await startServer(fakeHerdr("upstream"), []);
  await decideAndClose(up.port);
  await waitFor("本家shapeでは複数行の判定通知を `agent prompt <pane> <msg>` の1引数そのままで配送する", () => calls().some(promptDecision), calls);
  await waitFor("本家shapeではタブを閉じた通知も `agent prompt` で配送する", () => calls().some(promptClosed), calls);
  const upCalls = calls();
  assert(upCalls.filter((c) => c.join(" ") === "agent help").length === 1, "契約解決は起動後1回だけ（`agent help` が1回）", { upCalls });
  assert(!upCalls.some((c) => c[0] === "agent" && c[1] === "send"), "本家shapeで廃止済みの `agent send` を呼ばない", { upCalls });
  await stop(up.proc);

  // B. fork shape, default route → the same agent prompt
  writeFileSync(CALLS, "");
  const fkDefault = await startServer(fakeHerdr("fork"), []);
  await decideAndClose(fkDefault.port);
  await waitFor("fork shapeでも本家と共通の `agent prompt <pane> <msg>` で複数行の判定通知をそのまま配送する", () => calls().some(promptDecision), calls);
  await waitFor("fork shapeでもタブを閉じた通知を `agent prompt` で配送する", () => calls().some(promptClosed), calls);
  assert(!calls().some((c) => c[0] === "agent" && c[1] === "send"), "fork shapeでも `agent send` を使わない", calls());
  await stop(fkDefault.proc);

  // C. legacy shape (only agent send) → named failure, no agent send
  writeFileSync(CALLS, "");
  const legacy = await startServer(fakeHerdr("legacy"), []);
  await decideAndClose(legacy.port);
  await waitFor("古いHerdrでは不足している契約名付きで通知失敗を出す", () => /notify failed: installed herdr does not expose `herdr agent prompt <target> <text>`/.test(legacy.out()), () => ({ out: legacy.out() }));
  assert(!calls().some((c) => c[0] === "agent" && (c[1] === "send" || c[1] === "prompt")), "古いHerdr（agent sendのみ）では送信を試みない", calls());
  await stop(legacy.proc);

  // D. fork shape with --notify-room → send --room
  writeFileSync(CALLS, "");
  const fk = await startServer(fakeHerdr("fork"), ["--notify-room", "task-42"]);
  await decideAndClose(fk.port);
  const roomDecision = (c: string[]) => c.length === 5 && c[0] === "send" && c[1] === "p_7" && isDecision(c[2]) && c[3] === "--room" && c[4] === "task-42";
  await waitFor("fork shape + --notify-room では `herdr send <pane> <msg> --room <room>` で複数行の判定通知をそのまま配送する", () => calls().some(roomDecision), calls);
  assert(!calls().some((c) => c[0] === "agent" && c[1] !== "help"), "--notify-room 指定時は pane への直打ち（agent prompt / agent send）をしない", calls());
  await stop(fk.proc);

  // E. upstream shape with --notify-room → refuse to start
  writeFileSync(CALLS, "");
  const refused = await startServer(fakeHerdr("upstream"), ["--notify-room", "task-42"]);
  const code = await refused.exited;
  assert(code === 1 && /does not expose `herdr send <to> <text> --room`/.test(refused.out()), "本家shape + --notify-room は起動を拒否する（exit 1・理由付き）", { code, out: refused.out() });
} finally {
  rmSync(WORK, { recursive: true, force: true });
}
console.log(`\nResults: ${failed === 0 ? "all passed" : failed + " failed"}`);
if (failed > 0) process.exitCode = 1;
