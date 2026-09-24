/**
 * Undelivered agent notifications are visible and resendable.
 *
 * A fake `herdr` on PATH exposes the common `herdr agent prompt` contract but
 * refuses delivery with upstream's `agent_blocked` error until a "recovered"
 * flag file exists — the case where the launching agent is stopped at an
 * approval dialog. The human checks a decision checkbox in a real browser.
 *
 * Asserts: the failure is logged as before; the header shows an undelivered
 * counter with the reason (also to screen readers); the list survives a
 * reload; the counter opens from the keyboard even while a document line is
 * selected; a list update keeps focus on the same resend control; the resend
 * control re-delivers the exact original message once the agent recovers and
 * clears the counter; a resend request cannot inject arbitrary text (unknown
 * ids are rejected); a resend re-checks the Herdr contract after an upgrade;
 * a resend goes only to the route that failed (no duplicate to a route that
 * already received it); and a final approve made in the UI prints every
 * still-undelivered message in full on exit — even a 300 KB one while the
 * reader is not draining stdout — so the launching agent can still read it.
 *
 * Run: node --experimental-strip-types v2/e2e/notify_undelivered.ts
 */
import { spawn, type ChildProcess } from "node:child_process";
import { chmodSync, existsSync, mkdirSync, mkdtempSync, readdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { chromium } from "playwright";

const SERVER_JS = new URL("../_build/js/release/build/server/server.js", import.meta.url).pathname;
const ARTIFACTS = process.env.YUNOMI_E2E_ARTIFACTS || "";
const WORK = mkdtempSync(join(tmpdir(), "yunomi-notify-undelivered-"));
const CALLS = join(WORK, "calls.jsonl");
const RECOVERED = join(WORK, "recovered");
const LEGACY = join(WORK, "legacy");
let failed = 0;
function assert(c: boolean, msg: string, detail?: unknown) {
  if (c) console.log(`PASS: ${msg}`);
  else { failed++; console.error(`FAIL: ${msg}`); if (detail !== undefined) console.error(JSON.stringify(detail, null, 2)); }
}

const binDir = join(WORK, "bin");
mkdirSync(binDir);
writeFileSync(join(binDir, "herdr"), `#!${process.execPath}
const fs = require("node:fs");
const args = process.argv.slice(2);
fs.appendFileSync(${JSON.stringify(CALLS)}, JSON.stringify(args) + "\\n");
if (args[0] === "agent" && args[1] === "help") {
  process.stderr.write(fs.existsSync(${JSON.stringify(LEGACY)})
    ? "herdr agent commands:\\n  herdr agent send <target> <text>\\n"
    : "herdr agent commands:\\n  herdr agent prompt <target> <text> [--wait] [--until STATUS]... [--timeout MS]\\n");
  process.exit(0);
}
if (args[0] === "agent" && args[1] === "prompt" && args.length === 4) {
  if (fs.existsSync(${JSON.stringify(RECOVERED)})) process.exit(0);
  process.stderr.write(JSON.stringify({ error: { code: "agent_blocked", message: "agent p_7 is blocked and requires interactive input" }, id: "cli:agent:prompt" }) + "\\n");
  process.exit(1);
}
process.exit(2);
`);
chmodSync(join(binDir, "herdr"), 0o755);
// A tmux whose target pane never exists: every tmux delivery fails.
writeFileSync(join(binDir, "tmux"), `#!${process.execPath}
require("node:fs").appendFileSync(${JSON.stringify(CALLS)}, JSON.stringify(["tmux", ...process.argv.slice(2)]) + "\\n");
process.stderr.write("can't find pane: %9\\n");
process.exit(1);
`);
chmodSync(join(binDir, "tmux"), 0o755);

const calls = (): string[][] => (existsSync(CALLS) ? readFileSync(CALLS, "utf8").split("\n").filter(Boolean).map((l) => JSON.parse(l)) : []);
const prompts = () => calls().filter((c) => c[0] === "agent" && c[1] === "prompt");
const tmuxCalls = () => calls().filter((c) => c[0] === "tmux");

function startServer(extra: string[] = [], decisionText = "通知の再送を確認する", pauseStdout = false, files: string[] = ["REPORT.md"]): Promise<{ proc: ChildProcess; port: number; out: () => string; stdout: () => string; exited: Promise<number | null> }> {
  // decisionText lets a scenario vary the checkbox line.
  const reports = files.map((name) => join(WORK, name));
  for (const report of reports) writeFileSync(report, `# undelivered\n\n- [ ] ${decisionText}\n`);
  const proc = spawn(process.execPath, [SERVER_JS, ...reports, "--loop", "--no-open", "--port", "0", "--notify-pane", "p_7", ...extra], {
    cwd: WORK,
    env: { ...process.env, PATH: `${binDir}:${process.env.PATH}`, HERDR_PANE_ID: "", TMUX_PANE: "", YUNOMI_NOTIFY_CMD: "", YUNOMI_LOCK_DIR: join(WORK, "locks"), YUNOMI_REVIEW_DIR: join(WORK, "reviews") },
    stdio: ["ignore", "pipe", "pipe"],
  });
  let out = "";
  let stdout = "";
  // Decode as a stream: a multi-byte character can straddle two chunks.
  proc.stdout!.setEncoding("utf8");
  proc.stderr!.setEncoding("utf8");
  proc.stdout!.on("data", (d: string) => { stdout += d; });
  const exited = new Promise<number | null>((r) => proc.on("exit", (code) => r(code)));
  return new Promise((resolve, reject) => {
    const onData = (d: Buffer) => {
      out += String(d);
      const m = out.match(/http:\/\/127\.0\.0\.1:(\d+)/);
      if (m) resolve({ proc, port: Number(m[1]), out: () => out, stdout: () => stdout, exited });
    };
    proc.stdout!.on("data", onData); proc.stderr!.on("data", onData);
    // Stand in for a launching agent that drains yunomi's stdout slowly:
    // after the URL is known the test pauses reading and resumes it later.
    if (pauseStdout) proc.stdout!.once("data", () => proc.stdout!.pause());
    setTimeout(() => reject(new Error(`server start timeout\n${out}`)), 10000);
  });
}
const waitUntil = async (condition: () => boolean, timeoutMs = 8000) => {
  const deadline = Date.now() + timeoutMs;
  while (!condition() && Date.now() < deadline) await new Promise((r) => setTimeout(r, 50));
  return condition();
};
const stop = (p: ChildProcess) => new Promise<void>((r) => { p.on("exit", () => r()); p.kill("SIGINT"); setTimeout(() => { p.kill("SIGKILL"); r(); }, 3000); });
const shot = async (page: import("playwright").Page, name: string) => { if (ARTIFACTS) await page.screenshot({ path: join(ARTIFACTS, name) }); };

const server = await startServer();
const browser = await chromium.launch();
try {
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
  await page.goto(`http://127.0.0.1:${server.port}/`, { waitUntil: "domcontentloaded" });
  const badge = page.locator("#notify-undelivered");
  assert(await badge.isHidden(), "配送失敗がない間は未配送カウンターを出さない");

  await page.locator(".task-decision-checkbox").first().click();
  await badge.waitFor({ state: "visible", timeout: 8000 });
  assert((await badge.textContent())?.trim() === "1", "エージェントに届かなかった判定通知を未配送カウンター1件として表示する", { text: await badge.textContent() });
  assert(/notify failed: .*agent_blocked/.test(server.out()), "従来どおりサーバーログにも理由付きで配送失敗を出す", { out: server.out() });
  const failedMessage = prompts()[0]?.[3] ?? "";
  assert(/^\[yunomi\] decision REPORT\.md:3 checked=true\n> - \[x\] 通知の再送を確認する\nurl=/.test(failedMessage), "失敗したのは判定通知の本文そのもの", { failedMessage });

  assert(/1/.test((await badge.getAttribute("aria-label")) ?? ""), "カウンターの読み上げ名に件数を含める", { label: await badge.getAttribute("aria-label") });
  assert(/not delivered/i.test((await page.locator("#notify-undelivered-live").textContent()) ?? ""), "配送失敗の発生をライブ領域で読み上げる", { live: await page.locator("#notify-undelivered-live").textContent() });

  await page.reload({ waitUntil: "domcontentloaded" });
  await badge.waitFor({ state: "visible", timeout: 8000 });
  assert((await badge.textContent())?.trim() === "1", "再読み込み後も未配送の通知が残る");
  assert(((await page.locator("#notify-undelivered-live").textContent()) ?? "") === "", "再読み込みで表示しただけの既存の未配送は読み上げない", { live: await page.locator("#notify-undelivered-live").textContent() });

  // A document line selected with the keyboard must not swallow Enter on the counter.
  await page.locator("#md-preview").focus().catch(() => {});
  await page.keyboard.press("Shift+L");
  await badge.focus();
  await page.keyboard.press("Enter");
  const panel = page.locator("#notify-undelivered-panel");
  await panel.waitFor({ state: "visible", timeout: 3000 });
  assert(await panel.isVisible(), "本文の行を選択していても、キーボードの Enter でカウンターの一覧を開ける");
  assert(!(await page.locator(".inline-comment-editor, #inline-comment-editor").first().isVisible().catch(() => false)), "カウンターでの Enter が本文のコメント編集を開かない");
  const panelText = (await panel.textContent()) ?? "";
  assert(panelText.includes("decision REPORT.md:3") && panelText.includes("agent_blocked"), "一覧に未配送の通知と届かなかった理由を並べる", { panelText });
  await shot(page, "notify-undelivered-panel.png");

  const forged = await page.evaluate(async () => {
    const r = await fetch("/notify/retry", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ id: "does-not-exist", message: "rm -rf /" }) });
    return { status: r.status, body: await r.text() };
  });
  assert(forged.status === 404 && !prompts().some((c) => c[3] === "rm -rf /"), "再送APIは保存済みの通知IDしか受け付けず、任意の本文を送らない", forged);

  // Another failure arrives while focus sits on the first resend control.
  const firstId = await panel.locator("[data-notify-id]").first().getAttribute("data-notify-id");
  await panel.locator(".notify-undelivered-retry").first().focus();
  await page.evaluate(async () => {
    await fetch("/decision", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ file: "REPORT.md", line: 3, text: "通知の再送を確認する", checked: false }) });
  });
  await page.waitForFunction(() => document.querySelector("#notify-undelivered")?.textContent?.trim() === "2");
  const focusedId = await page.evaluate(() => (document.activeElement as HTMLElement | null)?.closest("[data-notify-id]")?.getAttribute("data-notify-id") ?? "");
  assert(focusedId === firstId, "一覧が更新されても、操作中の再送ボタンにフォーカスが残る", { focusedId, firstId });
  await page.evaluate(async () => {
    await fetch("/decision", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ file: "REPORT.md", line: 3, text: "通知の再送を確認する", checked: true }) });
  });
  await page.waitForFunction(() => document.querySelector("#notify-undelivered")?.textContent?.trim() === "3");
  for (const id of await panel.locator("[data-notify-id]").evaluateAll((rows) => rows.map((r) => r.getAttribute("data-notify-id")))) {
    if (id !== firstId) await page.evaluate(async (notifyId) => { await fetch("/notify/retry", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ id: notifyId }) }); }, id);
  }

  const stillBlocked = prompts().length;
  await panel.locator(".notify-undelivered-retry").first().click();
  await waitUntil(() => prompts().length > stillBlocked, 5000);
  assert(prompts().length === stillBlocked + 1 && (await badge.textContent())?.trim() === "3", "エージェントがまだ止まっている間の再送は失敗のまま残る", { prompts: prompts().length, count: await badge.textContent() });

  writeFileSync(RECOVERED, "1");
  while ((await panel.locator(".notify-undelivered-retry").count()) > 0) {
    const before = await panel.locator(".notify-undelivered-retry").count();
    await panel.locator(".notify-undelivered-retry").first().click();
    await page.waitForFunction((n) => document.querySelectorAll("#notify-undelivered-panel .notify-undelivered-retry").length < n || document.querySelector("#notify-undelivered-panel")?.hidden, before);
    if (await panel.isHidden()) break;
  }
  await badge.waitFor({ state: "hidden", timeout: 8000 });
  const focusVisible = await page.evaluate(() => {
    const el = document.activeElement as HTMLElement | null;
    return !!el && el.id === "sse-status" && !el.closest("[hidden]") && el.getClientRects().length > 0;
  });
  assert(focusVisible, "最後の未配送を再送して一覧が空になったら、フォーカスは隣の接続状態の表示へ移る");
  const delivered = prompts().filter((c) => c[2] === "p_7" && c[3] === failedMessage);
  assert(delivered.length >= 2, "エージェント復帰後の再送は元と同じ本文を同じ宛先へ届け、カウンターを消す", { prompts: prompts(), failedMessage });
  await shot(page, "notify-undelivered-cleared.png");
} finally {
  await browser.close();
  await stop(server.proc);
}

// The final verdict itself is not delivered: the exit is held so the human can
// resend it from the page; the Submit dialog already offers the earlier losses.
writeFileSync(CALLS, "");
rmSync(RECOVERED, { force: true });
const held = await startServer();
const heldBrowser = await chromium.launch();
try {
  const page = await heldBrowser.newPage({ viewport: { width: 1280, height: 720 } });
  await page.goto(`http://127.0.0.1:${held.port}/`, { waitUntil: "domcontentloaded" });
  const badge = page.locator("#notify-undelivered");
  await page.locator(".task-decision-checkbox").first().click();
  await badge.waitFor({ state: "visible", timeout: 8000 });

  await page.locator("#send-and-exit").click();
  await page.waitForSelector("#submit-modal.visible", { timeout: 5000 });
  const box = page.locator("#submit-undelivered");
  assert(await box.isVisible(), "提出ダイアログに、まだエージェントへ届いていない通知を出す");
  assert(/1 notification has not reached the agent/.test((await box.textContent()) ?? "") && ((await box.textContent()) ?? "").includes("decision REPORT.md:3"), "提出ダイアログの一覧に件数と未配送の通知を並べる", { text: await box.textContent() });
  await shot(page, "notify-undelivered-submit-dialog.png");
  const beforeDialogResend = prompts().length;
  await box.locator(".notify-undelivered-retry").first().focus();
  await page.keyboard.press("Enter");
  await waitUntil(() => prompts().length > beforeDialogResend, 5000);
  assert(prompts().length === beforeDialogResend + 1 && await page.locator("#submit-modal.visible").isVisible(), "提出ダイアログの再送ボタンはキーボードの Enter で再送し、ダイアログは開いたまま", { before: beforeDialogResend, after: prompts().length });

  await page.locator("#modal-approve").click();
  const heldPanel = page.locator("#notify-undelivered-panel");
  const finish = heldPanel.locator(".notify-undelivered-finish");
  await finish.waitFor({ state: "visible", timeout: 8000 });
  const stillRunning = await Promise.race([held.exited.then(() => false), new Promise((r) => setTimeout(() => r(true), 1500))]);
  assert(stillRunning && page.url().startsWith("http://127.0.0.1"), "最終承認の通知が届かなかったときは yunomi を終了せず、画面も閉じない", { url: page.url() });
  assert((await badge.textContent())?.trim() === "2" && ((await heldPanel.textContent()) ?? "").includes("[yunomi] verdict REPORT.md decision=approve"), "届かなかった最終承認の通知を一覧に加えて開く", { count: await badge.textContent(), panel: await heldPanel.textContent() });
  assert(((await heldPanel.textContent()) ?? "").includes("The agent has not received the verdict"), "一覧の先頭で、提出済みだが判定がエージェントに届いていないことを示す");
  const focusInPanel = await page.evaluate(() => !!document.activeElement?.closest("#notify-undelivered-panel .notify-undelivered-retry"));
  assert(focusInPanel, "保留になったら一覧の最初の再送ボタンへフォーカスを移す");
  const reachable = await page.evaluate(() => [...document.querySelectorAll("#notify-undelivered-panel button")].every((b) => {
    const r = b.getBoundingClientRect();
    // Inside the box for both the round resend buttons and the text button.
    const y = r.top + r.height / 2;
    const points = [[r.left + r.width * 0.2, y], [r.left + r.width / 2, y], [r.right - r.width * 0.2, y]];
    return points.every(([x, y]) => document.elementFromPoint(x, y)?.closest("button") === b);
  }));
  assert(reachable, "保留中の一覧のボタンはチャット欄などに隠れず押せる");
  assert(/exit held/.test(held.out()), "保留したことをサーバーログにも出す", { out: held.out().slice(-400) });
  await shot(page, "notify-undelivered-held.png");
  await page.setViewportSize({ width: 390, height: 780 });
  await page.evaluate(() => window.dispatchEvent(new Event("resize")));
  const phoneFit = await page.evaluate(() => {
    const r = document.querySelector("#notify-undelivered-panel")!.getBoundingClientRect();
    return r.left >= 16 && r.right <= window.innerWidth - 16;
  });
  assert(phoneFit, "スマホ幅でも保留中の一覧は画面内に収まる");
  await shot(page, "notify-undelivered-held-390.png");
  await page.setViewportSize({ width: 1280, height: 720 });

  await page.reload({ waitUntil: "domcontentloaded" });
  await finish.waitFor({ state: "visible", timeout: 8000 });
  const aliveAfterReload = await Promise.race([held.exited.then(() => false), new Promise((r) => setTimeout(() => r(true), 2500))]);
  assert(aliveAfterReload, "保留中に再読み込みしても終了せず、再送の一覧を開き直す");

  const locks = () => (existsSync(join(WORK, "locks")) ? readdirSync(join(WORK, "locks")) : []);
  assert(locks().length > 0, "保留中は二重起動防止のロックを持ったまま", { locks: locks() });
  const finishUrl = `http://127.0.0.1:${held.port}/notify/finish`;
  const crossSite = await fetch(finishUrl, { method: "POST", headers: { Origin: "http://127.0.0.1:1" } });
  const noOrigin = await fetch(finishUrl, { method: "POST" });
  const crossRetry = await fetch(`http://127.0.0.1:${held.port}/notify/retry`, { method: "POST", headers: { Origin: "http://evil.example", "Content-Type": "application/json" }, body: JSON.stringify({ id: "n1" }) });
  const aliveAfterForgery = await Promise.race([held.exited.then(() => false), new Promise((r) => setTimeout(() => r(true), 800))]);
  assert(crossSite.status === 403 && noOrigin.status === 403 && crossRetry.status === 403 && aliveAfterForgery, "別のサイト・別ポートからの終了や再送の POST は拒否し、終了しない", { crossSite: crossSite.status, noOrigin: noOrigin.status, crossRetry: crossRetry.status });

  const verdictsBefore = prompts().filter((c) => c[3]?.startsWith("[yunomi] verdict")).length;
  const resubmit = await page.evaluate(async () => {
    const r = await fetch("/exit", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ decision: "approve", action: "final_approve", comments: [] }) });
    return r.text();
  });
  assert(/"held":true/.test(resubmit) && prompts().filter((c) => c[3]?.startsWith("[yunomi] verdict")).length === verdictsBefore && (held.stdout().match(/decision: approve/g) ?? []).length === 1, "保留中にもう一度提出しても、判定を二重に記録・通知しない", { resubmit, stdoutApprovals: (held.stdout().match(/decision: approve/g) ?? []).length });

  writeFileSync(RECOVERED, "1");
  const verdictRow = heldPanel.locator("[data-notify-id]").filter({ hasText: "[yunomi] verdict" });
  const verdictMessage = await page.evaluate(async () => ((await (await fetch("/notify/undelivered")).json()).items as { message: string }[]).find((i) => i.message.startsWith("[yunomi] verdict"))!.message);
  await heldPanel.locator("[data-notify-id]").filter({ hasText: "decision REPORT.md:3" }).locator(".notify-undelivered-retry").click();
  await page.waitForFunction(() => document.querySelector("#notify-undelivered")?.textContent?.trim() === "1");
  const aliveAfterDecision = await Promise.race([held.exited.then(() => false), new Promise((r) => setTimeout(() => r(true), 1000))]);
  assert(aliveAfterDecision, "最終承認以外の通知を再送しても、判定が届くまでは終了しない");
  await verdictRow.locator(".notify-undelivered-retry").click();
  const code = await Promise.race([held.exited, new Promise((r) => setTimeout(() => r("timeout"), 8000))]);
  assert(code === 0 && prompts().some((c) => c[2] === "p_7" && c[3] === verdictMessage), "最終承認の通知を再送して届いたら yunomi は正常終了する", { code });
  await waitUntil(() => page.isClosed() || page.url() === "about:blank", 3000);
  assert(page.isClosed() || page.url() === "about:blank", "再送で終了したら通常の提出と同じくタブを閉じる", { url: page.isClosed() ? "closed" : page.url() });
  assert(/decision: approve/.test(held.stdout()) && !held.stdout().includes("undelivered notification (the agent did not receive it)"), "終了出力には判定を含め、届いた通知は未配送として残さない", { tail: held.stdout().slice(-600) });
  assert(locks().length === 0, "保留から終了したらロックを外す", { locks: locks() });
} finally {
  await heldBrowser.close();
  await stop(held.proc);
}

// Closing the last tab of a held review ends it after the reload grace.
writeFileSync(CALLS, "");
rmSync(RECOVERED, { force: true });
const closing = await startServer();
const closingBrowser = await chromium.launch();
try {
  const page = await closingBrowser.newPage();
  await page.goto(`http://127.0.0.1:${closing.port}/`, { waitUntil: "domcontentloaded" });
  await page.locator("#send-and-exit").click();
  await page.waitForSelector("#submit-modal.visible", { timeout: 5000 });
  await page.locator("#modal-approve").click();
  await page.locator("#notify-undelivered-panel .notify-undelivered-finish").waitFor({ state: "visible", timeout: 8000 });
  // Leaving the page fires the same pagehide close report as closing the tab.
  await page.goto("about:blank");
  const code = await Promise.race([closing.exited, new Promise((r) => setTimeout(() => r("timeout"), 8000))]);
  assert(code === 0 && closing.stdout().includes("[yunomi] undelivered notification (the agent did not receive it):\n[yunomi] verdict REPORT.md decision=approve"), "保留中に最後のタブを閉じたら終了し、届かなかった判定の全文を終了出力に残す", { code, tail: closing.stdout().slice(-400), log: closing.out().split("\n").filter((l) => /SESSION|held|close/.test(l)) });
} finally {
  await closingBrowser.close();
  await stop(closing.proc);
}

// Two files, each on its own port in one process: undelivered ids never
// collide across files, and a tab of either file keeps a held review alive.
writeFileSync(CALLS, "");
rmSync(RECOVERED, { force: true });
const multi = await startServer([], undefined, false, ["A.md", "B.md"]);
await waitUntil(() => (multi.out().match(/serving B\.md at http:\/\/127\.0\.0\.1:\d+/) ?? []).length > 0, 8000);
const portOf = (name: string) => Number(multi.out().match(new RegExp(`serving ${name.replace(".", "\\.")} at http://127\\.0\\.0\\.1:(\\d+)`))![1]);
const portA = portOf("A.md");
const portB = portOf("B.md");
const multiBrowser = await chromium.launch();
try {
  const first = await multiBrowser.newPage();
  await first.goto(`http://127.0.0.1:${portA}/`, { waitUntil: "domcontentloaded" });
  await first.locator(".task-decision-checkbox").first().click();
  await first.locator("#notify-undelivered").waitFor({ state: "visible", timeout: 8000 });
  await first.locator("#send-and-exit").click();
  await first.waitForSelector("#submit-modal.visible", { timeout: 5000 });
  await first.locator("#modal-approve").click();
  await waitUntil(() => first.isClosed() || first.url() === "about:blank", 5000);

  const second = await multiBrowser.newPage();
  await second.goto(`http://127.0.0.1:${portB}/`, { waitUntil: "domcontentloaded" });
  await second.locator("#send-and-exit").click();
  await second.waitForSelector("#submit-modal.visible", { timeout: 5000 });
  await second.locator("#modal-approve").click();
  const secondPanel = second.locator("#notify-undelivered-panel");
  await secondPanel.locator(".notify-undelivered-finish").waitFor({ state: "visible", timeout: 8000 });
  const ids = async (port: number) => ((await (await fetch(`http://127.0.0.1:${port}/notify/undelivered`)).json()).items as { id: string }[]).map((i) => i.id);
  const idsA = await ids(portA);
  const idsB = await ids(portB);
  assert(idsA.length >= 1 && idsB.length === 1 && !idsB.some((id) => idsA.includes(id)), "複数ファイルでも未配送の通知 ID は重ならない", { idsA, idsB });

  const verdictsHeld = prompts().filter((c) => c[3]?.startsWith("[yunomi] verdict")).length;
  const again = await (await fetch(`http://127.0.0.1:${portA}/exit`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ decision: "approve", action: "final_approve", comments: [] }) })).text();
  assert(/"held":true/.test(again) && prompts().filter((c) => c[3]?.startsWith("[yunomi] verdict")).length === verdictsHeld, "保留中に別ファイルからもう一度提出しても、判定を二重に記録・通知しない", { again, before: verdictsHeld, after: prompts().filter((c) => c[3]?.startsWith("[yunomi] verdict")).length });

  // Another file's tab is still open when the held file's last tab closes.
  const reopened = await multiBrowser.newPage();
  await reopened.goto(`http://127.0.0.1:${portA}/`, { waitUntil: "domcontentloaded" });
  await second.goto("about:blank");
  const aliveWithOtherTab = await Promise.race([multi.exited.then(() => false), new Promise((r) => setTimeout(() => r(true), 3000))]);
  assert(aliveWithOtherTab, "保留中に一方のファイルのタブを閉じても、別ファイルのタブが開いていれば終了しない");

  writeFileSync(RECOVERED, "1");
  const back = await multiBrowser.newPage();
  await back.goto(`http://127.0.0.1:${portB}/`, { waitUntil: "domcontentloaded" });
  const backPanel = back.locator("#notify-undelivered-panel");
  await backPanel.locator(".notify-undelivered-retry").first().waitFor({ state: "visible", timeout: 8000 });
  await backPanel.locator(".notify-undelivered-retry").first().click();
  const code = await Promise.race([multi.exited, new Promise((r) => setTimeout(() => r("timeout"), 8000))]);
  assert(code === 0 && multi.stdout().includes("[yunomi] undelivered notification (the agent did not receive it):\n[yunomi] decision A.md:3"), "保留中の判定を再送して届いたら、別ファイルに未配送が残っていても終了し、残りは全文を出力する", { code, tail: multi.stdout().slice(-500) });
} finally {
  await multiBrowser.close();
  await stop(multi.proc);
}

// Herdr upgraded while the review is open: a resend re-checks the contract.
writeFileSync(CALLS, "");
writeFileSync(RECOVERED, "1");
writeFileSync(LEGACY, "1");
const BIG = "大きな承認コメント".repeat(40000);
const upgrade = await startServer([], undefined, true);
const upgradeBrowser = await chromium.launch();
try {
  const page = await upgradeBrowser.newPage();
  await page.goto(`http://127.0.0.1:${upgrade.port}/`, { waitUntil: "domcontentloaded" });
  await page.locator(".task-decision-checkbox").first().click();
  const badge = page.locator("#notify-undelivered");
  await badge.waitFor({ state: "visible", timeout: 8000 });
  assert(prompts().length === 0 && /does not expose `herdr agent prompt/.test(upgrade.out()), "古いHerdrでは送らずに未配送として残す", { out: upgrade.out() });
  rmSync(LEGACY);
  await badge.click();
  await page.locator("#notify-undelivered-panel .notify-undelivered-retry").first().click();
  await badge.waitFor({ state: "hidden", timeout: 8000 });
  assert(prompts().length === 1, "Herdrを更新した後の再送は契約を調べ直して届ける", { calls: calls() });

  // Final approve while a notification is still undelivered (agent blocked).
  rmSync(RECOVERED, { force: true });
  await page.locator(".task-decision-checkbox").first().click();
  await badge.waitFor({ state: "visible", timeout: 8000 });
  const lost = await page.evaluate(async () => (await (await fetch("/notify/undelivered")).json()).items[0].message as string);
  await page.locator("#global-comment").evaluate((el, text) => {
    (el as HTMLTextAreaElement).value = text;
    el.dispatchEvent(new Event("input", { bubbles: true }));
  }, BIG);
  await page.locator("#send-and-exit").click();
  await page.waitForSelector("#submit-modal.visible", { timeout: 5000 });
  await page.locator("#modal-approve").click();
  // The verdict was not delivered either, so the exit is held until the
  // human resends it or exits from the list.
  const finish = page.locator("#notify-undelivered-panel .notify-undelivered-finish");
  await finish.waitFor({ state: "visible", timeout: 8000 });
  await finish.click();
  // The reader catches up only after yunomi has started exiting.
  setTimeout(() => upgrade.proc.stdout!.resume(), 1500);
  await Promise.race([upgrade.exited, new Promise((r) => setTimeout(r, 15000))]);
  const dump = "[yunomi] undelivered notification (the agent did not receive it):\n";
  // stdout alone: stderr chunks interleave with it in the combined log.
  await waitUntil(() => upgrade.stdout().includes(BIG + "\n"), 5000);
  const out = upgrade.stdout();
  assert(out.includes(dump + lost + "\n") && out.includes(dump + "[yunomi] verdict REPORT.md decision=approve") && out.includes("human: " + BIG + "\n"), "最終承認の通知も届かず「届けずに終了」したとき、読み手が止まっていても届かなかった通知（約36万文字の承認コメント入り）を全文そのまま終了出力に残す", { bigLength: BIG.length, outLength: out.length, hasDecision: out.includes(dump + lost + "\\n"), hasVerdict: out.includes(dump + "[yunomi] verdict REPORT.md decision=approve"), hasHuman: out.includes("human: " + BIG + "\\n"), around: out.slice(out.indexOf("[yunomi] verdict") - 100, out.indexOf("[yunomi] verdict") + 200), tail: out.slice(-200) });
} finally {
  await upgradeBrowser.close();
  await stop(upgrade.proc);
  rmSync(LEGACY, { force: true });
}

// Herdr delivered but tmux failed: a resend must not deliver to Herdr again.
writeFileSync(CALLS, "");
writeFileSync(RECOVERED, "1");
const partial = await startServer(["--notify-tmux-pane", "%9"]);
const partialBrowser = await chromium.launch();
try {
  const page = await partialBrowser.newPage();
  await page.goto(`http://127.0.0.1:${partial.port}/`, { waitUntil: "domcontentloaded" });
  await page.locator(".task-decision-checkbox").first().click();
  const badge = page.locator("#notify-undelivered");
  await badge.waitFor({ state: "visible", timeout: 8000 });
  assert(prompts().length === 1 && tmuxCalls().length >= 1, "Herdrには届き、tmuxだけ失敗した通知を未配送として残す", { calls: calls() });
  const tmuxBefore = tmuxCalls().length;
  await badge.click();
  await page.locator("#notify-undelivered-panel .notify-undelivered-retry").first().click();
  await waitUntil(() => tmuxCalls().length > tmuxBefore, 5000);
  assert(prompts().length === 1 && tmuxCalls().length > tmuxBefore, "再送は失敗した tmux だけに送り、受け取り済みの Herdr へ二重に送らない", { calls: calls() });
} finally {
  await partialBrowser.close();
  await stop(partial.proc);
}

rmSync(WORK, { recursive: true, force: true });
console.log(`\nResults: ${failed === 0 ? "all passed" : failed + " failed"}`);
if (failed > 0) process.exitCode = 1;
