/**
 * One verdict per round, resolve notifications, and the resolved-thread list.
 *
 * Runs the real server with --loop in a temporary git repository, drives a
 * real browser, and records every agent notification through
 * YUNOMI_NOTIFY_CMD (a script that appends each message to a file, and fails
 * while a flag file exists so undelivered handling can be exercised).
 *
 * Asserts:
 * - after request changes, the same submit sent again in that round records
 *   and notifies nothing more, while a different submit still replaces it;
 *   the Submit dialog says the round is submitted and a new submit replaces
 *   it; after `yunomi go` the note is gone
 * - resolving a thread notifies the agent once with file, line, id, round,
 *   quote, and the thread text; a refused resolve notification is kept in the
 *   undelivered list and a resend delivers it once
 * - the round badge opens a list of unresolved and resolved threads; choosing
 *   a resolved one reveals it read-only at its line (no reply form), and it
 *   can be closed again; the list works from the keyboard
 *
 * Run: node --experimental-strip-types v2/e2e/review_submit_resolve.ts
 */
import { spawn, spawnSync, type ChildProcess } from "node:child_process";
import { existsSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { chromium, type Page } from "playwright";

const SERVER_JS = new URL("../_build/js/release/build/server/server.js", import.meta.url).pathname;
const ARTIFACTS = process.env.YUNOMI_E2E_ARTIFACTS || "";
const WORK = mkdtempSync(join(tmpdir(), "yunomi-submit-resolve-"));
const LOG = join(WORK, "notify.log");
const FAIL = join(WORK, "fail");
let failed = 0;
function assert(c: boolean, msg: string, detail?: unknown) {
  if (c) console.log(`PASS: ${msg}`);
  else { failed++; console.error(`FAIL: ${msg}`); if (detail !== undefined) console.error(JSON.stringify(detail, null, 2)); }
}

writeFileSync(join(WORK, "doc.md"), "# Probe\n\nfirst paragraph line\n\nsecond paragraph line\n\n- [ ] ok\n");
spawnSync("git", ["init", "-q"], { cwd: WORK });
spawnSync("git", ["add", "."], { cwd: WORK });
spawnSync("git", ["-c", "user.email=e2e@example.com", "-c", "user.name=e2e", "commit", "-qm", "init"], { cwd: WORK });
writeFileSync(join(WORK, "notify.cjs"), `const fs = require("fs");
if (fs.existsSync(${JSON.stringify(FAIL)})) { process.stderr.write("refused for test"); process.exit(1); }
fs.appendFileSync(${JSON.stringify(LOG)}, process.argv[2] + "\\n<<END>>\\n");
`);
const env = {
  ...process.env,
  IKESU_PANE_ID: "", HERDR_PANE_ID: "", TMUX_PANE: "",
  YUNOMI_REVIEW_DIR: join(WORK, ".reviews"),
  YUNOMI_LOCK_DIR: join(WORK, ".locks"),
  YUNOMI_NOTIFY_CMD: `${process.execPath} ${join(WORK, "notify.cjs")} {msg}`,
};
const messages = () => (existsSync(LOG) ? readFileSync(LOG, "utf8").split("\n<<END>>\n").filter(Boolean) : []);
async function waitUntil(fn: () => boolean | Promise<boolean>, ms: number) {
  const end = Date.now() + ms;
  while (Date.now() < end) { if (await fn()) return true; await new Promise((r) => setTimeout(r, 100)); }
  return false;
}

let out = "";
const proc: ChildProcess = spawn(process.execPath, [SERVER_JS, "doc.md", "--loop", "--no-open", "--port", "0"], { cwd: WORK, env, stdio: ["ignore", "pipe", "pipe"] });
proc.stdout!.on("data", (d) => { out += String(d); });
proc.stderr!.on("data", (d) => { out += String(d); });
await waitUntil(() => /serving doc\.md at http:\/\/127\.0\.0\.1:\d+/.test(out), 10000);
const port = Number(out.match(/serving doc\.md at http:\/\/127\.0\.0\.1:(\d+)/)![1]);
const browser = await chromium.launch();
const shot = async (page: Page, name: string) => { if (ARTIFACTS) await page.screenshot({ path: join(ARTIFACTS, name) }); };

try {
  const page = await browser.newPage({ viewport: { width: 1280, height: 800 } });
  await page.goto(`http://127.0.0.1:${port}/`);
  await page.locator("p", { hasText: "first paragraph line" }).first().click();
  await page.locator(".yunomi-inline-comment-editor").waitFor({ state: "visible" });
  await page.locator("#comment-input").fill("probe comment one");
  await page.locator("#send-now-comment").click();
  await page.locator(".review-loop-inline .review-loop-resolve").first().waitFor({ state: "visible" });
  const threadId = await page.locator(".review-loop-inline .review-loop-comment").first().getAttribute("data-review-comment-id");

  // Resolve notifies the agent once.
  const before = messages().length;
  await page.locator(".review-loop-inline .review-loop-resolve").first().click();
  await waitUntil(() => messages().length > before, 5000);
  const resolved = messages().filter((m) => m.startsWith("[yunomi] resolved "));
  assert(resolved.length === 1, "解決すると、エージェントへ通知が1回だけ届く", { messages: messages() });
  assert(resolved[0]?.startsWith(`[yunomi] resolved doc.md:3 id=${threadId} round=1`) && resolved[0].includes("\n> first paragraph line") && resolved[0].includes("\nthread: probe comment one") && resolved[0].includes(`\nurl=http://127.0.0.1:${port}`), "解決の通知に、ファイル・行・ID・回・引用・スレッドの本文・URL が入る", resolved[0]);

  // The round badge lists unresolved and resolved threads.
  await page.locator(".review-loop-inline").first().waitFor({ state: "detached", timeout: 5000 });
  const badge = page.locator("#review-loop-header-badge");
  await badge.waitFor({ state: "visible" });
  assert(await badge.evaluate((el) => el.tagName === "BUTTON"), "回の丸い表示はボタンとして押せる");
  await badge.click();
  const list = page.locator("#review-thread-list");
  await list.waitFor({ state: "visible" });
  assert(await badge.getAttribute("aria-expanded") === "true", "一覧を開くと丸い表示が開いた状態を伝える");
  const resolvedItem = list.locator(`.review-thread-list-item.is-resolved[data-review-comment-id="${threadId}"]`);
  assert(await resolvedItem.count() === 1 && /probe comment one/.test(await resolvedItem.textContent() || ""), "一覧に解決済みのスレッドが本文つきで出る", { threadId, list: await list.innerHTML() });
  await shot(page, "list-open.png");
  await resolvedItem.click();
  const revealed = page.locator(`.review-loop-inline .review-loop-comment.is-resolved[data-review-comment-id="${threadId}"]`);
  await revealed.waitFor({ state: "visible", timeout: 5000 }).catch(() => {});
  assert(await revealed.count() === 1, "解決済みを選ぶと、本文の元の行にそのスレッドが開く");
  assert(await revealed.locator("form, textarea").count() === 0 && /probe comment one/.test(await revealed.textContent() || ""), "開いた解決済みスレッドは読むだけ（返信欄が無い）");
  assert(await list.isHidden(), "選ぶと一覧は閉じる");
  await shot(page, "resolved-revealed.png");
  await revealed.locator(".review-loop-reveal-close").click();
  assert(await waitUntil(async () => (await revealed.count()) === 0, 3000), "閉じるボタンで、開いた解決済みスレッドを閉じられる");

  // Keyboard: open the list and choose with Enter, close with Escape.
  await badge.focus();
  await page.keyboard.press("Enter");
  await list.waitFor({ state: "visible" });
  await page.keyboard.press("Escape");
  assert(await waitUntil(async () => await list.isHidden(), 2000), "Escape で一覧を閉じる");
  assert(await page.evaluate(() => document.activeElement?.id) === "review-loop-header-badge", "閉じたらフォーカスは丸い表示へ戻る");

  // A refused resolve notification is kept and resent once.
  await page.locator("p", { hasText: "second paragraph line" }).first().click();
  await page.locator(".yunomi-inline-comment-editor").waitFor({ state: "visible" });
  await page.locator("#comment-input").fill("probe comment two");
  await page.locator("#send-now-comment").click();
  await page.locator(".review-loop-inline .review-loop-resolve").first().waitFor({ state: "visible" });
  writeFileSync(FAIL, "1");
  await page.locator(".review-loop-inline .review-loop-resolve").first().click();
  const undelivered = await waitUntil(async () => {
    const r = await (await fetch(`http://127.0.0.1:${port}/notify/undelivered`)).json() as { items?: { id: string; message: string }[] };
    return (r.items || []).some((i) => i.message.startsWith("[yunomi] resolved doc.md:5"));
  }, 5000);
  assert(undelivered, "解決の通知が届かなかったら、未配送の一覧に残る");
  rmSync(FAIL);
  const items = ((await (await fetch(`http://127.0.0.1:${port}/notify/undelivered`)).json()) as { items: { id: string; message: string }[] }).items;
  const item = items.find((i) => i.message.startsWith("[yunomi] resolved doc.md:5"))!;
  await page.evaluate(async ({ id }) => { await fetch("/notify/retry", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ id }) }); }, { id: item.id });
  await waitUntil(() => messages().some((m) => m.startsWith("[yunomi] resolved doc.md:5")), 5000);
  assert(messages().filter((m) => m.startsWith("[yunomi] resolved doc.md:5")).length === 1, "再送すると、解決の通知が1回だけ届く");

  // The same verdict is recorded once per round; a different one replaces it.
  const submitCount = () => (out.match(/\[YUNOMI_SESSION\] submit /g) || []).length;
  const verdicts = () => messages().filter((m) => m.startsWith("[yunomi] verdict ")).length;
  let firstBody = "";
  page.on("request", (req) => { if (req.url().endsWith("/exit") && req.method() === "POST" && !firstBody) firstBody = req.postData() || ""; });
  await page.locator("#send-and-exit").click();
  await page.locator("#modal-request-changes").waitFor({ state: "visible" });
  await page.locator("#modal-request-changes").click();
  await waitUntil(() => verdicts() === 1, 5000);
  assert(submitCount() === 1 && verdicts() === 1 && firstBody.length > 0, "差し戻しは1回記録・1回通知される", { submits: submitCount(), verdicts: verdicts() });
  // The submitted tab leaves the review; a quick repeat sends the same body.
  await waitUntil(() => page.url() === "about:blank", 5000);
  const repeat = await (await fetch(`http://127.0.0.1:${port}/exit`, { method: "POST", headers: { "Content-Type": "application/json", Origin: `http://127.0.0.1:${port}` }, body: firstBody })).json() as { already_submitted?: boolean };
  assert(repeat.already_submitted === true, "同じ回に同じ内容をもう一度送ると、提出済みとして断る", repeat);
  await new Promise((r) => setTimeout(r, 800));
  assert(submitCount() === 1 && verdicts() === 1, "同じ内容の再提出は、記録も通知もしない", { submits: submitCount(), verdicts: verdicts() });
  // The reviewer comes back to the same URL before the agent starts the next round.
  await page.goto(`http://127.0.0.1:${port}/`);
  await page.locator("#send-and-exit").click();
  await page.locator("#submit-modal.visible").waitFor({ state: "visible" });
  const note = page.locator("#submit-round-submitted");
  assert(await waitUntil(async () => /Round 1 is already submitted/.test(await note.textContent() || "") && await note.isVisible(), 3000), "提出画面に、この回は提出済みで、もう一度送ると言い直しになると出る");
  assert(!(await page.locator("#modal-request-changes").isDisabled()), "言い直しのため、差し戻しボタンは押せるまま");
  await shot(page, "round-submitted.png");
  await page.locator("#modal-cancel").click();
  const replaced = JSON.parse(firstBody);
  replaced.summary = "replacement summary";
  const replacement = await (await fetch(`http://127.0.0.1:${port}/exit`, { method: "POST", headers: { "Content-Type": "application/json", Origin: `http://127.0.0.1:${port}` }, body: JSON.stringify(replaced) })).json() as { already_submitted?: boolean };
  await waitUntil(() => verdicts() === 2, 5000);
  assert(!replacement.already_submitted && submitCount() === 2 && verdicts() === 2 && messages().some((m) => m.includes("replacement summary")), "違う内容なら、今までどおり言い直しとして受け付ける", { replacement, submits: submitCount(), verdicts: verdicts() });

  // After `yunomi go`, the next round can be submitted.
  const go = spawnSync(process.execPath, [SERVER_JS, "go", "--no-open"], { cwd: WORK, env, encoding: "utf8" });
  assert(go.status === 0, "yunomi go で次の回を始められる", go.stderr);
  await waitUntil(async () => /Round 2/.test(await page.locator("#review-loop-header-badge").textContent() || ""), 8000);
  await page.locator("#send-and-exit").click();
  await page.locator("#submit-modal.visible").waitFor({ state: "visible" });
  assert(await waitUntil(async () => await page.locator("#submit-round-submitted").isHidden(), 3000) && !(await page.locator("#modal-request-changes").isDisabled()), "次の回では、提出済みの表示が消える");
} finally {
  await browser.close();
  proc.kill();
  rmSync(WORK, { recursive: true, force: true });
}
if (failed > 0) { console.error(`${failed} check(s) failed`); process.exit(1); }
console.log("review submit/resolve contract passed");
