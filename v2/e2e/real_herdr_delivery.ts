/**
 * Real Herdr delivery check (local evidence, not a committed test).
 *
 * Starts an isolated `herdr server` from the given binary (own socket/config,
 * never the user's running Herdr), runs a stand-in agent process in its root
 * pane (a Node line reader started through a `pi` symlink so Herdr's process
 * detection sees a `pi` agent; it prints `AGENT_GOT:<line>` like an AI CLI
 * reading its prompt) and reports it as the pane's agent,
 * starts yunomi with `--notify-pane <that pane>`, clicks a checkbox decision
 * in a real browser, and reads the pane back through Herdr to see whether the
 * `[yunomi] ...` notification actually arrived.
 *
 * Opt-in (needs a real Herdr binary, so it is not part of `npm test`):
 *   YUNOMI_REAL_HERDR=/path/to/herdr [YUNOMI_REAL_HERDR_SERVER=/path/to/older/herdr] \
 *     node --experimental-strip-types v2/e2e/real_herdr_delivery.ts
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
const label = "real-delivery";
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
  const rep = herdr("pane", "report-agent", pane, "--source", "yunomi-check", "--agent", "pi", "--state", "idle");
  log(`pane=${pane} report-agent exit=${rep.status}`);

  const report = join(base, "REPORT.md");
  writeFileSync(report, "# delivery check\n\n- [ ] 通知が届くか確認する\n");
  let out = "";
  yunomi = spawn(process.execPath, [serverJs, report, "--loop", "--no-open", "--port", "0", "--notify-pane", pane], {
    cwd: base,
    env: { ...herdrEnv, YUNOMI_LOCK_DIR: join(base, "locks"), YUNOMI_REVIEW_DIR: join(base, "reviews") },
    stdio: ["ignore", "pipe", "pipe"],
  });
  yunomi.stdout!.on("data", (d) => (out += d));
  yunomi.stderr!.on("data", (d) => (out += d));
  let port = 0;
  for (let i = 0; i < 200 && !port; i++) { const m = out.match(/http:\/\/127\.0\.0\.1:(\d+)/); if (m) port = Number(m[1]); else await sleep(50); }
  log(`yunomi: ${spawnSync(process.execPath, [serverJs, "--version"], { encoding: "utf8" }).stdout.trim()} port=${port}`);

  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1100, height: 600 } });
  await page.goto(`http://127.0.0.1:${port}/`);
  await page.locator(".task-decision-checkbox").first().click();
  await page.waitForFunction(() => document.querySelector<HTMLInputElement>(".task-decision-checkbox")?.checked === true);
  await page.screenshot({ path: join(OUT, `${label}-browser.png`) });
  await browser.close();

  const expected = [
    "[yunomi] decision REPORT.md:3 checked=true",
    "> - [x] 通知が届くか確認する",
    `url=http://127.0.0.1:${port}`,
  ];
  for (let i = 0; i < 100 && received().length < expected.length && !out.includes("notify failed"); i++) await sleep(100);
  await sleep(500);
  const got = received();
  const delivered = JSON.stringify(got) === JSON.stringify(expected);
  log(`delivered_to_agent_process=${delivered}`);
  log(`agent received=${JSON.stringify(got)}`);
  const paneText = herdr("pane", "read", pane, "--source", "recent", "--lines", "40").stdout;
  log(`yunomi notify log: ${out.split("\n").filter((l) => /notify/.test(l)).join(" | ") || "(no notify lines)"}`);
  log("--- pane read (recent) ---");
  log(paneText.split("\n").filter((l) => l.trim()).slice(-8).join("\n"));
  writeFileSync(join(OUT, `${label}.log`), lines.join("\n") + "\n");
  process.exitCode = delivered ? 0 : 3;
} finally {
  yunomi?.kill("SIGINT");
  server?.kill("SIGTERM");
  await sleep(300);
  rmSync(base, { recursive: true, force: true });
}
