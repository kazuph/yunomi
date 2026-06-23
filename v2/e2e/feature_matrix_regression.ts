/**
 * Feature matrix regression checks for user-story coverage gaps.
 *
 * Run: node --experimental-strip-types v2/e2e/feature_matrix_regression.ts
 */
import { spawn, type ChildProcess } from "node:child_process";
import { existsSync, readdirSync, readFileSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { fileURLToPath } from "node:url";
import { chromium, type Browser, type Page } from "playwright";

const __dirname = fileURLToPath(new URL(".", import.meta.url));
const ROOT = join(__dirname, "..", "..");
const SERVER_JS = join(ROOT, "v2", "_build", "js", "release", "build", "server", "server.js");
const WORK_DIR = mkdtempSync(join(tmpdir(), "yunomi-feature-matrix-"));
const LOCK_DIR = join(WORK_DIR, "locks");
const BASE_PORT = 5791;

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

interface ServerHandle {
  proc: ChildProcess;
  output: () => string;
}

function startYunomi(args: string[], expectedUrls: string[]): Promise<ServerHandle> {
  return new Promise((resolve, reject) => {
    const proc = spawn("node", [SERVER_JS, ...args], {
      stdio: ["ignore", "pipe", "pipe"],
      env: { ...process.env, YUNOMI_LOCK_DIR: LOCK_DIR },
    });
    let output = "";
    let resolved = false;
    const check = () => {
      if (!resolved && expectedUrls.every((url) => output.includes(url))) {
        resolved = true;
        resolve({ proc, output: () => output });
      }
    };
    proc.stdout.on("data", (d: Buffer) => {
      output += String(d);
      check();
    });
    proc.stderr.on("data", (d: Buffer) => {
      output += String(d);
      check();
    });
    proc.on("exit", (code) => {
      if (!resolved) reject(new Error(`server exited early with ${code}:\n${output}`));
    });
    setTimeout(() => {
      if (!resolved) reject(new Error(`server did not start:\n${output}`));
    }, 15000);
  });
}

async function stopServer(handle: ServerHandle): Promise<void> {
  await new Promise<void>((resolve) => {
    handle.proc.once("exit", () => resolve());
    handle.proc.kill("SIGINT");
    setTimeout(() => {
      handle.proc.kill("SIGKILL");
      resolve();
    }, 3000);
  });
}

async function fetchText(port: number, path = "/"): Promise<string> {
  const res = await fetch(`http://127.0.0.1:${port}${path}`);
  return await res.text();
}

async function withPage<T>(
  port: number,
  fn: (page: Page, browser: Browser) => Promise<T>,
): Promise<T> {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage({ viewport: { width: 1000, height: 800 } });
  try {
    await page.goto(`http://127.0.0.1:${port}`, { waitUntil: "domcontentloaded" });
    return await fn(page, browser);
  } finally {
    await browser.close();
  }
}

try {
  const md = join(WORK_DIR, "story.md");
  const tsv = join(WORK_DIR, "story.tsv");
  const txt = join(WORK_DIR, "story.txt");
  const diff = join(WORK_DIR, "story.diff");
  const sjis = join(WORK_DIR, "shift-jis.txt");
  const largeDiff = join(WORK_DIR, "large-binary.diff");

  writeFileSync(md, [
    "# Feature Matrix",
    "",
    "## Collapsible Section",
    "",
    "This body should hide when the heading toggle collapses.",
    "",
    "### Nested",
    "",
    "Nested body.",
  ].join("\n"));
  writeFileSync(tsv, "name\tstatus\nalpha\tready\nbeta\tblocked\n");
  writeFileSync(txt, "first line\nsecond line\nthird line\n");
  writeFileSync(diff, [
    "diff --git a/a.txt b/a.txt",
    "index 1111111..2222222 100644",
    "--- a/a.txt",
    "+++ b/a.txt",
    "@@ -1 +1 @@",
    "-old",
    "+new",
  ].join("\n"));
  writeFileSync(sjis, Buffer.from([
    0x83, 0x65, 0x83, 0x58, 0x83, 0x67, // テスト
    0x0a,
  ]));
  const largeLines = Array.from({ length: 505 }, (_, i) => ` line ${i + 1}`);
  writeFileSync(largeDiff, [
    "diff --git a/huge.txt b/huge.txt",
    "index 1111111..2222222 100644",
    "--- a/huge.txt",
    "+++ b/huge.txt",
    "@@ -1,505 +1,505 @@",
    ...largeLines,
    "diff --git a/image.bin b/image.bin",
    "index 3333333..4444444 100644",
    "Binary files a/image.bin and b/image.bin differ",
  ].join("\n"));

  // Multiple files should occupy consecutive ports and preserve mode per file.
  const multi = await startYunomi(
    [md, tsv, "--no-open", "--port", String(BASE_PORT)],
    [`http://127.0.0.1:${BASE_PORT}`, `http://127.0.0.1:${BASE_PORT + 1}`],
  );
  try {
    const mdHtml = await fetchText(BASE_PORT);
    const tsvHtml = await fetchText(BASE_PORT + 1);
    assert(mdHtml.includes('__YUNOMI_MODE__="markdown"'), "複数ファイル1つ目はmarkdown modeで起動する");
    assert(tsvHtml.includes('__YUNOMI_MODE__="tsv"'), "複数ファイル2つ目は連続ポートのtsv modeで起動する");
    assert(tsvHtml.includes("alpha") && tsvHtml.includes("blocked"), "TSVは表データをHTMLに描画する");
  } finally {
    await stopServer(multi);
  }

  const textServer = await startYunomi(
    [txt, "--no-open", "--port", String(BASE_PORT + 2)],
    [`http://127.0.0.1:${BASE_PORT + 2}`],
  );
  try {
    const html = await fetchText(BASE_PORT + 2);
    assert(html.includes('__YUNOMI_MODE__="text"'), "plain textはtext modeで起動する");
    assert(html.includes("first line") && html.includes("third line"), "plain textは行単位で描画する");
    assert(html.includes('class="text-line" data-row="0"'), "plain text行にはコメント用data-rowが付く");
  } finally {
    await stopServer(textServer);
  }

  const sjisServer = await startYunomi(
    [sjis, "--encoding", "shift_jis", "--no-open", "--port", String(BASE_PORT + 6)],
    [`http://127.0.0.1:${BASE_PORT + 6}`],
  );
  try {
    const html = await fetchText(BASE_PORT + 6);
    assert(html.includes("テスト"), "--encoding shift_jis でShift-JIS本文を正しくデコードする");
  } finally {
    await stopServer(sjisServer);
  }

  const diffServer = await startYunomi(
    [diff, "--no-open", "--port", String(BASE_PORT + 3)],
    [`http://127.0.0.1:${BASE_PORT + 3}`],
  );
  try {
    const html = await fetchText(BASE_PORT + 3);
    assert(html.includes('__YUNOMI_MODE__="diff"'), "diffファイルはdiff modeで起動する");
    assert(html.includes("a.txt") && html.includes("old") && html.includes("new"), "diff内容がHTMLに描画される");
  } finally {
    await stopServer(diffServer);
  }

  const largeDiffServer = await startYunomi(
    [largeDiff, "--no-open", "--port", String(BASE_PORT + 7)],
    [`http://127.0.0.1:${BASE_PORT + 7}`],
  );
  try {
    await withPage(BASE_PORT + 7, async (page) => {
      const large = page.locator("details.diff-file-large");
      const largeCount = await large.count();
      const openState = largeCount > 0 ? await large.first().evaluate((el) => (el as HTMLDetailsElement).open) : true;
      const headers = await page.locator(".diff-file-header").allTextContents();
      assert(largeCount === 1 && openState === false, "500行超diffはdetailsで初期折りたたみになる", { largeCount, openState });
      assert(headers.at(-1)?.includes("image.bin") && headers.at(-1)?.includes("binary"), "binary diffは末尾に表示される", headers);
    });
  } finally {
    await stopServer(largeDiffServer);
  }

  const hostServer = await startYunomi(
    [md, "--no-open", "--host", "127.0.0.1", "--port", String(BASE_PORT + 4)],
    [`http://127.0.0.1:${BASE_PORT + 4}`],
  );
  try {
    const health = await fetchText(BASE_PORT + 4, "/healthz");
    assert(health.includes('"ok":true'), "--host 127.0.0.1で起動してhealthzに応答する");
  } finally {
    await stopServer(hostServer);
  }

  const headingServer = await startYunomi(
    [md, "--no-open", "--port", String(BASE_PORT + 5)],
    [`http://127.0.0.1:${BASE_PORT + 5}`],
  );
  try {
    await withPage(BASE_PORT + 5, async (page) => {
      await page.waitForSelector(".heading-toggle-icon", { timeout: 10000 });
      const previewBody = page.locator("#md-preview").getByText("This body should hide when the heading toggle collapses.");
      const before = await previewBody.isVisible();
      await page.locator(".heading-toggle-icon").nth(1).click();
      await page.waitForTimeout(150);
      const after = await previewBody.isVisible();
      const collapsedIcon = await page.locator(".heading-toggle-icon").nth(1).evaluate((el) => el.classList.contains("collapsed"));
      assert(before && !after && collapsedIcon, "見出しトグルはセクション本文を折りたたむ", { before, after, collapsedIcon });
    });
  } finally {
    await stopServer(headingServer);
  }

  const commentServer = await startYunomi(
    [txt, "--no-open", "--port", String(BASE_PORT + 8)],
    [`http://127.0.0.1:${BASE_PORT + 8}`],
  );
  try {
    await withPage(BASE_PORT + 8, async (page) => {
      const line0 = page.locator('.text-line[data-row="0"]');
      await line0.click();
      await page.waitForSelector("#comment-card", { state: "visible" });
      const previewText = (await page.locator("#cell-preview").textContent()) || "";
      await page.locator("#copy-selection").click();
      const copiedToast = await page.waitForFunction(
        () => Array.from(document.body.children).some((el) => el.textContent === "Copied!"),
        undefined,
        { timeout: 3000 },
      ).then(() => true).catch(() => false);
      await page.locator("#comment-input").fill("comment lifecycle");
      await page.locator("#save-comment").click();
      await page.waitForTimeout(150);
      const saved = await page.locator('.text-line[data-row="0"].has-comment').count();
      const countAfterSave = await page.locator("#comment-count").textContent();
      await line0.click();
      await page.waitForSelector("#comment-card", { state: "visible" });
      await page.locator("#clear-comment").click();
      await page.waitForTimeout(150);
      const deleted = await page.locator('.text-line[data-row="0"].has-comment').count();
      const countAfterDelete = await page.locator("#comment-count").textContent();
      assert(previewText.length > 0 && copiedToast && saved === 1 && countAfterSave === "1" && deleted === 0 && countAfterDelete === "0", "コメントの保存・コピー・削除が機能する", {
        previewText,
        copiedToast,
        saved,
        countAfterSave,
        deleted,
        countAfterDelete,
      });

      const first = await page.locator('.text-line[data-row="0"]').boundingBox();
      const third = await page.locator('.text-line[data-row="2"]').boundingBox();
      if (!first || !third) {
        assert(false, "drag selection target rows have bounding boxes", { first, third });
        return;
      }
      await page.mouse.move(first.x + 20, first.y + first.height / 2);
      await page.mouse.down();
      await page.mouse.move(third.x + 20, third.y + third.height / 2, { steps: 6 });
      const selectedDuringDrag = await page.locator(".text-line.selected").count();
      await page.mouse.up();
      await page.waitForSelector("#comment-card", { state: "visible" });
      const cardVisible = await page.locator("#comment-card").isVisible();
      assert(selectedDuringDrag >= 2 && cardVisible, "ドラッグ選択で複数行が選択されコメントカードが開く", {
        selectedDuringDrag,
        cardVisible,
      });
    });
  } finally {
    await stopServer(commentServer);
  }

  const pluginRoot = join(ROOT, "plugin");
  const pluginSkills = join(pluginRoot, "skills");
  const pluginAgents = join(pluginRoot, "agents");
  const requiredPluginFiles = [
    ".claude-plugin/plugin.json",
    "README.md",
    "skills/do/SKILL.md",
    "skills/done/SKILL.md",
    "skills/tiny-do/SKILL.md",
    "skills/tiny-done/SKILL.md",
    "skills/webapp-testing/SKILL.md",
    "skills/exit-notifier/scripts/watch-exit-notify.sh",
    "hooks/hooks.json",
  ];
  const missingPluginFiles = requiredPluginFiles.filter((file) => !existsSync(join(pluginRoot, file)));
  const skillNames = new Set(readdirSync(pluginSkills));
  const agentNames = readdirSync(pluginAgents).filter((name) => name.endsWith(".md"));
  const doSkill = readFileSync(join(pluginSkills, "do", "SKILL.md"), "utf8");
  const doneSkill = readFileSync(join(pluginSkills, "done", "SKILL.md"), "utf8");
  const tinyDoSkill = readFileSync(join(pluginSkills, "tiny-do", "SKILL.md"), "utf8");
  const tinyDoneSkill = readFileSync(join(pluginSkills, "tiny-done", "SKILL.md"), "utf8");
  const webappSkill = readFileSync(join(pluginSkills, "webapp-testing", "SKILL.md"), "utf8");
  assert(missingPluginFiles.length === 0 && skillNames.size >= 20 && agentNames.length >= 8, "Claude Code plugin assets一式が存在する", {
    missingPluginFiles,
    skillCount: skillNames.size,
    agentCount: agentNames.length,
  });
  assert(
    doSkill.includes("Task Start") &&
      doneSkill.includes("Task Completion") &&
      tinyDoSkill.includes("tiny-do") &&
      tinyDoneSkill.includes("tiny-done"),
    "do/done/tiny-do/tiny-done skillがタスク開始・完了フローを記述している",
  );
  assert(
    webappSkill.includes("Playwright") &&
      webappSkill.includes("NEVER") &&
      webappSkill.includes("E2E tests should be permanent project assets"),
    "webapp-testing skillが恒久E2EとPlaywright検証を要求している",
  );
} finally {
  rmSync(WORK_DIR, { recursive: true, force: true });
}

console.log(`\nResults: ${passed} passed, ${failed} failed`);
if (failed > 0) process.exitCode = 1;
