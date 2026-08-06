import assert from "node:assert/strict";
import { spawn, type ChildProcess } from "node:child_process";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { chromium } from "playwright";

const SERVER_JS = new URL("../_build/js/release/build/server/server.js", import.meta.url).pathname;
const WORK_DIR = mkdtempSync(join(tmpdir(), "yunomi-storage-scope-"));
const FIRST_DIR = join(WORK_DIR, "first");
const SECOND_DIR = join(WORK_DIR, "second");
const FIRST_REPORT = join(FIRST_DIR, "REPORT.md");
const SECOND_REPORT = join(SECOND_DIR, "REPORT.md");

function startServer(file: string, port: number): Promise<{ proc: ChildProcess; port: number }> {
  return new Promise((resolveServer, reject) => {
    const proc = spawn(process.execPath, [SERVER_JS, file, "--no-open", "--port", String(port)], {
      cwd: WORK_DIR,
      env: { ...process.env, HERDR_PANE_ID: "", YUNOMI_NOTIFY_CMD: "" },
      stdio: ["ignore", "pipe", "pipe"],
    });
    let output = "";
    const onData = (chunk: Buffer) => {
      output += chunk.toString();
      const match = output.match(/yunomi serving .* at http:\/\/127\.0\.0\.1:(\d+)/);
      if (match) resolveServer({ proc, port: Number(match[1]) });
    };
    proc.stdout?.on("data", onData);
    proc.stderr?.on("data", onData);
    proc.once("error", reject);
    proc.once("exit", (code) => reject(new Error(`server exited before listening (${code})\n${output}`)));
  });
}

function waitForExit(proc: ChildProcess): Promise<void> {
  if (proc.exitCode !== null) return Promise.resolve();
  return new Promise((resolveExit) => proc.once("exit", () => resolveExit()));
}

async function main(): Promise<void> {
  mkdirSync(FIRST_DIR);
  mkdirSync(SECOND_DIR);
  writeFileSync(FIRST_REPORT, "# First report\n");
  writeFileSync(SECOND_REPORT, "# Second report\n");

  const firstServer = await startServer(FIRST_REPORT, 0);
  const browser = await chromium.launch({ headless: true });
  let activeServer = firstServer.proc;
  try {
    const page = await browser.newPage();
    await page.goto(`http://127.0.0.1:${firstServer.port}/`, { waitUntil: "domcontentloaded" });
    await page.waitForFunction(() => Boolean(window.__YUNOMI_STORAGE_SCOPE__));
    const first = await page.evaluate(() => ({
      filename: window.__YUNOMI_FILENAME__,
      scope: window.__YUNOMI_STORAGE_SCOPE__,
    }));
    assert.equal(first.filename, "REPORT.md");
    assert.equal(first.scope, resolve(FIRST_REPORT));

    await page.evaluate(() => {
      const key = `yunomi:comments:${window.__YUNOMI_STORAGE_SCOPE__}`;
      localStorage.setItem(key, JSON.stringify({ comments: {}, summary: "first report draft", timestamp: Date.now() }));
    });

    firstServer.proc.kill("SIGTERM");
    await waitForExit(firstServer.proc);
    const secondServer = await startServer(SECOND_REPORT, firstServer.port);
    activeServer = secondServer.proc;
    await page.goto(`http://127.0.0.1:${secondServer.port}/`, { waitUntil: "domcontentloaded" });
    await page.waitForFunction(() => Boolean(window.__YUNOMI_STORAGE_SCOPE__));
    const second = await page.evaluate(() => ({
      filename: window.__YUNOMI_FILENAME__,
      scope: window.__YUNOMI_STORAGE_SCOPE__,
      ownDraft: localStorage.getItem(`yunomi:comments:${window.__YUNOMI_STORAGE_SCOPE__}`),
      recoveryVisible: document.querySelector("#recovery-modal")?.classList.contains("visible") ?? false,
    }));
    assert.equal(second.filename, "REPORT.md");
    assert.equal(second.scope, resolve(SECOND_REPORT));
    assert.notEqual(second.scope, first.scope);
    assert.equal(second.ownDraft, null);
    assert.equal(second.recoveryVisible, false);

    const firstDraftStillExists = await page.evaluate(
      (scope) => localStorage.getItem(`yunomi:comments:${scope}`),
      first.scope,
    );
    assert.match(firstDraftStillExists ?? "", /first report draft/);
    console.log("PASS: same-named reports use path-scoped localStorage keys");
  } finally {
    await browser.close();
    if (activeServer.exitCode === null) activeServer.kill("SIGTERM");
  }
}

main()
  .catch((error) => {
    console.error(error instanceof Error ? error.stack || error.message : String(error));
    process.exitCode = 1;
  })
  .finally(() => rmSync(WORK_DIR, { recursive: true, force: true }));
