/**
 * Real Herdr held-exit check (opt-in; needs a real Herdr binary).
 *
 * Starts an isolated `herdr server` (own socket/config, never the user's
 * running Herdr) with a stand-in `pi` agent in its root pane reported as
 * `blocked`, then approves the review in a real browser. The final verdict is
 * refused by Herdr, so yunomi must stay running with the verdict in its
 * undelivered list. After the agent is reported `idle`, resending the verdict
 * from that list must deliver it exactly and end yunomi with exit code 0.
 *
 * Opt-in (needs a real Herdr binary, so it is not part of `npm test`):
 *   YUNOMI_REAL_HERDR=/path/to/herdr \
 *     node --experimental-strip-types v2/e2e/real_herdr_held_exit.ts
 * The optional server binary runs the Herdr server while <herdr-binary> is the
 * CLI yunomi calls (an upgraded CLI talking to a still-running older server).
 */
import { spawn, spawnSync, type ChildProcess } from "node:child_process";
import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { chromium } from "playwright";

const herdrBin = process.env.YUNOMI_REAL_HERDR || "";
if (!herdrBin) {
  console.error("FAIL: set YUNOMI_REAL_HERDR to a real herdr binary (this check does not fall back to a fake)");
  process.exit(1);
}
const herdrServerBin = process.env.YUNOMI_REAL_HERDR_SERVER || herdrBin;
const serverJs = new URL("../_build/js/release/build/server/server.js", import.meta.url).pathname;
const label = "real-held-exit";
const OUT = process.env.YUNOMI_E2E_ARTIFACTS || mkdtempSync(join(tmpdir(), "yunomi-real-herdr-"));
// Short base path: macOS limits Unix socket paths to 104 bytes.
const base = mkdtempSync("/tmp/yh-");
const binDir = join(base, "bin");
mkdirSync(binDir);
symlinkSync(herdrBin, join(binDir, "herdr"));
symlinkSync(process.execPath, join(binDir, "pi"));
const socket = join(base, "run", "herdr.sock");
const herdrEnv: NodeJS.ProcessEnv = { ...process.env, PATH: `${binDir}:${process.env.PATH}`, XDG_CONFIG_HOME: join(base, "config"), XDG_RUNTIME_DIR: join(base, "run"), HERDR_SOCKET_PATH: socket, SHELL: "/bin/sh" };
for (const k of ["HERDR_ENV", "HERDR_PANE_ID", "HERDR_ACTIVE_PANE_ID", "HERDR_CLIENT_SOCKET_PATH", "TMUX", "TMUX_PANE", "YUNOMI_NOTIFY_CMD", "YUNOMI_NOTIFY_ROOM"]) delete herdrEnv[k];
const herdr = (...args: string[]) => spawnSync(join(binDir, "herdr"), args, { env: herdrEnv, encoding: "utf8" });
const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));
const lines: string[] = [];
const log = (s: string) => { lines.push(s); console.log(s); };

let server: ChildProcess | undefined;
let yunomi: ChildProcess | undefined;
try {
  log(`# ${label}`);
  log(`herdr: ${herdr("--version").stdout.trim()} (${herdrBin})`);
  log(`agent help prompt line: ${(herdr("agent", "help").stderr + herdr("agent", "help").stdout).split("\n").find((l) => l.includes("agent prompt")) ?? "(none)"}`);
  log(`herdr server: ${spawnSync(herdrServerBin, ["--version"], { encoding: "utf8" }).stdout.trim()} (${herdrServerBin})`);
  const srvDir = join(base, "srv");
  mkdirSync(srvDir);
  symlinkSync(herdrServerBin, join(srvDir, "herdr"));
  server = spawn(join(srvDir, "herdr"), ["server"], { env: herdrEnv, stdio: "ignore" });
  for (let i = 0; i < 300 && !existsSync(socket); i++) await sleep(50);
  log(`socket ready=${existsSync(socket)}`);
  const created = herdr("workspace", "create", "--cwd", base);
  if (created.status !== 0) throw new Error(`workspace create failed: ${created.stderr}${created.stdout}`);
  const ws = JSON.parse(created.stdout);
  const pane: string = ws.result.root_pane.pane_id;
  // The stand-in agent appends every line it reads to AGENT_LOG, so the check
  // compares exactly what the agent process received (not the pane screen).
  const agentLog = join(base, "agent-received.jsonl");
  writeFileSync(agentLog, "");
  herdr("pane", "run", pane, `AGENT_LOG=${agentLog} ${join(binDir, "pi")} -e 'const fs=require("fs");require("readline").createInterface({input:process.stdin}).on("line",(l)=>{fs.appendFileSync(process.env.AGENT_LOG,JSON.stringify(l)+"\\n");console.log("AGENT_GOT:"+l)})'`);
  const received = (): string[] => readFileSync(agentLog, "utf8").split("\n").filter(Boolean).map((l) => JSON.parse(l));
  await sleep(700);
  const rep = herdr("pane", "report-agent", pane, "--source", "yunomi-check", "--agent", "pi", "--state", "blocked");
  log(`pane=${pane} report-agent exit=${rep.status}`);

  const report = join(base, "REPORT.md");
  writeFileSync(report, "# held exit check\n\n最終承認の通知が届かない場合\n");
  let out = "";
  yunomi = spawn(process.execPath, [serverJs, report, "--loop", "--no-open", "--port", "0", "--notify-pane", pane], {
    cwd: base,
    env: { ...herdrEnv, YUNOMI_LOCK_DIR: join(base, "locks"), YUNOMI_REVIEW_DIR: join(base, "reviews") },
    stdio: ["ignore", "pipe", "pipe"],
  });
  yunomi.stdout!.on("data", (d) => (out += d));
  yunomi.stderr!.on("data", (d) => (out += d));
  const exited = new Promise<number | null>((r) => yunomi!.on("exit", (code) => r(code)));
  let port = 0;
  for (let i = 0; i < 200 && !port; i++) { const m = out.match(/http:\/\/127\.0\.0\.1:(\d+)/); if (m) port = Number(m[1]); else await sleep(50); }
  log(`yunomi: ${spawnSync(process.execPath, [serverJs, "--version"], { encoding: "utf8" }).stdout.trim()} port=${port}`);

  const browser = await chromium.launch();
  const context = await browser.newContext({ viewport: { width: 1100, height: 600 }, ...(process.env.RECORD_VIDEO ? { recordVideo: { dir: process.env.RECORD_VIDEO, size: { width: 1100, height: 600 } } } : {}) });
  const page = await context.newPage();
  const pause = (ms: number) => (process.env.RECORD_VIDEO ? sleep(ms) : Promise.resolve());
  await page.goto(`http://127.0.0.1:${port}/`);
  await pause(800);
  await page.locator("#send-and-exit").click();
  await page.waitForSelector("#submit-modal.visible", { timeout: 5000 });
  await pause(1000);
  await page.locator("#modal-approve").click();
  const panel = page.locator("#notify-undelivered-panel");
  await panel.locator(".notify-undelivered-finish").waitFor({ state: "visible", timeout: 10000 });
  const alive = await Promise.race([exited.then(() => false), sleep(1500).then(() => true)]);
  const verdict: string = await page.evaluate(async () => ((await (await fetch("/notify/undelivered")).json()).items as { message: string }[]).find((i) => i.message.startsWith("[yunomi] verdict"))!.message);
  log(`held: alive=${alive} panel=${(await panel.textContent()) ?? ""}`);
  await page.screenshot({ path: join(OUT, `${label}-held.png`) });
  const whileBlocked = received();
  log(`agent received while blocked=${JSON.stringify(whileBlocked)}`);

  await pause(2000);
  const idle = herdr("pane", "report-agent", pane, "--source", "yunomi-check", "--agent", "pi", "--state", "idle");
  log(`report idle exit=${idle.status}`);
  await panel.locator(".notify-undelivered-retry").first().click();
  const code = await Promise.race([exited, sleep(10000).then(() => "timeout")]);
  await pause(1000);
  await context.close();
  await browser.close();
  const expected = verdict.split("\n");
  for (let i = 0; i < 100 && received().length < expected.length; i++) await sleep(100);
  await sleep(500);
  const got = received();
  const ok = alive && whileBlocked.length === 0 && code === 0 && JSON.stringify(got) === JSON.stringify(expected);
  log(`exit code after resend=${code}`);
  log(`held_then_delivered=${ok}`);
  log(`agent received after resend=${JSON.stringify(got)}`);
  log(`yunomi log: ${out.split("\n").filter((l) => /notify|held|EXIT/.test(l)).join(" | ")}`);
  writeFileSync(join(OUT, `${label}.log`), lines.join("\n") + "\n");
  process.exitCode = ok ? 0 : 3;
} finally {
  yunomi?.kill("SIGINT");
  server?.kill("SIGTERM");
  await sleep(300);
  rmSync(base, { recursive: true, force: true });
}
