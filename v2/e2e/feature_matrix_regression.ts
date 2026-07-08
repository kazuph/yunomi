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
      env: { ...process.env, HERDR_PANE_ID: "", YUNOMI_NOTIFY_CMD: "", YUNOMI_LOCK_DIR: LOCK_DIR, YUNOMI_REVIEW_DIR: join(tmpdir(), "yunomi-review-" + Date.now() + "-" + Math.random().toString(36).slice(2,6)) },
    });
    let output = "";
    let resolved = false;
    const startupTimer = setTimeout(() => {
      if (!resolved) reject(new Error(`server did not start:\n${output}`));
    }, 15000);
    const check = () => {
      if (!resolved && expectedUrls.every((url) => output.includes(url))) {
        resolved = true;
        clearTimeout(startupTimer);
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
      if (!resolved) {
        clearTimeout(startupTimer);
        reject(new Error(`server exited early with ${code}:\n${output}`));
      }
    });
  });
}

async function stopServer(handle: ServerHandle): Promise<void> {
  await new Promise<void>((resolve) => {
    let resolved = false;
    const forceTimer = setTimeout(() => {
      if (!resolved) {
        resolved = true;
        handle.proc.kill("SIGKILL");
        resolve();
      }
    }, 3000);
    handle.proc.once("exit", () => {
      if (!resolved) {
        resolved = true;
        clearTimeout(forceTimer);
        resolve();
      }
    });
    handle.proc.kill("SIGINT");
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
  const pluginHookHandlers = join(pluginRoot, "hooks-handlers");
  const requiredPluginFiles = [
    ".claude-plugin/plugin.json",
    "README.md",
    "hooks/hooks.json",
    "hooks-handlers/completion-checklist.sh",
    "hooks-handlers/git-wt-guard.sh",
    "hooks-handlers/test-mock-guard.sh",
    "hooks-handlers/test-mock-postcheck.sh",
    "agents/backend-impl.md",
    "agents/mobile-impl.md",
    "agents/webapp-impl.md",
    "agents/report-builder.md",
    "agents/report-validator.md",
    "agents/review-e2e.md",
  ];
  const missingPluginFiles = requiredPluginFiles.filter((file) => !existsSync(join(pluginRoot, file)));
  const pluginManifest = JSON.parse(readFileSync(join(pluginRoot, ".claude-plugin", "plugin.json"), "utf8"));
  const hooksConfig = JSON.parse(readFileSync(join(pluginRoot, "hooks", "hooks.json"), "utf8"));
  const skillFiles = existsSync(pluginSkills)
    ? readdirSync(pluginSkills, { recursive: true }).filter((name) => String(name).endsWith("SKILL.md"))
    : [];
  const agentNames = readdirSync(pluginAgents).filter((name) => name.endsWith(".md"));
  const hookHandlerNames = readdirSync(pluginHookHandlers).filter((name) => name.endsWith(".sh"));
  const webappAgent = readFileSync(join(pluginAgents, "webapp-impl.md"), "utf8");
  const backendAgent = readFileSync(join(pluginAgents, "backend-impl.md"), "utf8");
  const mobileAgent = readFileSync(join(pluginAgents, "mobile-impl.md"), "utf8");
  const completionChecklist = readFileSync(join(pluginHookHandlers, "completion-checklist.sh"), "utf8");
  assert(
    missingPluginFiles.length === 0 && agentNames.length >= 9 && hookHandlerNames.length >= 6,
    "Claude Code plugin assets一式がhooks/agents中心の2.1.0構造で存在する",
    {
      missingPluginFiles,
      agentCount: agentNames.length,
      hookHandlerCount: hookHandlerNames.length,
    },
  );
  assert(pluginManifest.version === "2.1.0" && pluginManifest.description.includes("Workflow skills"), "plugin.jsonが2.1.0のskill非同梱方針を明記している", {
    version: pluginManifest.version,
    description: pluginManifest.description,
  });
  assert(skillFiles.length === 0, "pluginはskills/SKILL.mdを同梱しない", {
    skillFiles,
  });
  assert(
    Array.isArray(hooksConfig.hooks?.PreToolUse) &&
      Array.isArray(hooksConfig.hooks?.PostToolUse) &&
      Array.isArray(hooksConfig.hooks?.UserPromptSubmit),
    "hooks.jsonがPreToolUse/PostToolUse/UserPromptSubmit hooksを定義している",
    {
      hookEvents: Object.keys(hooksConfig.hooks ?? {}),
    },
  );
  assert(
    webappAgent.includes("skills: frontend-design, webapp-testing, artifact-proof") &&
      backendAgent.includes("skills: backend-testing, artifact-proof") &&
      mobileAgent.includes("skills: mobile-testing, artifact-proof"),
    "実装agentはplugin内skill名ではなくグローバルskill名を参照している",
  );
  assert(
    completionChecklist.includes("Execute /done") && !completionChecklist.includes("/yunomi-plugin:done"),
    "completion checklistはplugin namespace付きskill実行を要求しない",
    {
      hasGlobalDone: completionChecklist.includes("Execute /done"),
      hasPluginDone: completionChecklist.includes("/yunomi-plugin:done"),
    },
  );
} finally {
  rmSync(WORK_DIR, { recursive: true, force: true });
}

console.log(`\nResults: ${passed} passed, ${failed} failed`);
if (failed > 0) process.exitCode = 1;
