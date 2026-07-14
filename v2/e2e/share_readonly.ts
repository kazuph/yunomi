import { spawn, spawnSync, type ChildProcess } from "node:child_process";
import { existsSync, mkdtempSync, readFileSync, readdirSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { chromium } from "playwright";

const SERVER_JS = new URL("../_build/js/release/build/server/server.js", import.meta.url).pathname;
const WORK_DIR = mkdtempSync(join(tmpdir(), "yunomi-share-"));
const LOCK_DIR = join(WORK_DIR, "locks");
const REVIEW_DIR = join(WORK_DIR, "reviews");
const SHARE_DIR = join(WORK_DIR, "shares");
const BASE_PORT = 5866;

let passed = 0;
let failed = 0;

function assert(condition: boolean, message: string, detail?: unknown): void {
  if (condition) {
    passed++;
    console.log(`PASS: ${message}`);
  } else {
    failed++;
    console.error(`FAIL: ${message}`);
    if (detail !== undefined) console.error(JSON.stringify(detail, null, 2));
  }
}

function startShare(args: string[]): Promise<{ proc: ChildProcess; output: () => string; port: number }> {
  return new Promise((resolve, reject) => {
    const proc = spawn(process.execPath, [SERVER_JS, "share", ...args], {
      cwd: WORK_DIR,
      stdio: ["ignore", "pipe", "pipe"],
      env: {
        ...process.env,
        HERDR_PANE_ID: "",
        YUNOMI_NOTIFY_CMD: "",
        YUNOMI_LOCK_DIR: LOCK_DIR,
        YUNOMI_REVIEW_DIR: REVIEW_DIR,
        YUNOMI_SHARE_DIR: SHARE_DIR,
      },
    });
    let output = "";
    let settled = false;
    const startupTimer = setTimeout(() => {
      if (!settled) reject(new Error(`share server did not start\n${output}`));
    }, 15000);
    const check = () => {
      const match = output.match(/http:\/\/127\.0\.0\.1:(\d+)/);
      if (!settled && match && output.includes("yunomi sharing")) {
        settled = true;
        clearTimeout(startupTimer);
        resolve({ proc, output: () => output, port: Number(match[1]) });
      }
    };
    proc.stdout?.on("data", (chunk: Buffer) => { output += chunk.toString("utf8"); check(); });
    proc.stderr?.on("data", (chunk: Buffer) => { output += chunk.toString("utf8"); check(); });
    proc.on("exit", (code) => {
      if (!settled) reject(new Error(`share server exited early ${code}\n${output}`));
    });
  });
}

async function stop(proc: ChildProcess): Promise<void> {
  await new Promise<void>((resolve) => {
    const forceTimer = setTimeout(() => {
      proc.kill("SIGKILL");
      resolve();
    }, 3000);
    proc.once("exit", () => {
      clearTimeout(forceTimer);
      resolve();
    });
    proc.kill("SIGINT");
  });
}

async function get(port: number, path: string): Promise<{ status: number; text: string }> {
  const res = await fetch(`http://127.0.0.1:${port}${path}`);
  return { status: res.status, text: await res.text() };
}

async function post(port: number, path: string): Promise<{ status: number; text: string }> {
  const res = await fetch(`http://127.0.0.1:${port}${path}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ comments: [{ row: 1, col: 0, text: "must not write" }] }),
  });
  return { status: res.status, text: await res.text() };
}

const report = join(WORK_DIR, "report.md");
const notes = join(WORK_DIR, "notes.txt");
writeFileSync(report, "# Shared Report\n\nRead-only content.\n");
writeFileSync(notes, "plain shared text\n");

try {
  const unsafeHost = spawnSync(
    process.execPath,
    [SERVER_JS, "share", report, "--host", "0.0.0.0", "--no-open"],
    {
      cwd: WORK_DIR,
      encoding: "utf8",
      env: {
        ...process.env,
        HERDR_PANE_ID: "",
        YUNOMI_NOTIFY_CMD: "",
        YUNOMI_LOCK_DIR: LOCK_DIR,
        YUNOMI_REVIEW_DIR: REVIEW_DIR,
        YUNOMI_SHARE_DIR: SHARE_DIR,
      },
    },
  );
  assert(
    unsafeHost.status === 1 && unsafeHost.stderr.includes("requires --public"),
    "share rejects non-loopback binding unless --public is explicit",
    unsafeHost,
  );

  const share = await startShare([
    report,
    notes,
    "--no-open",
    "--port",
    String(BASE_PORT),
  ]);
  try {
    assert(share.output().includes("yunomi sharing report.md read-only"), "share command announces a read-only URL");
    assert(share.output().includes("yunomi share token"), "share command prints a revocable token URL");
    const tokenFiles = readdirSync(SHARE_DIR).filter((file) => file.endsWith(".json"));
    assert(tokenFiles.length === 1, "share writes exactly one token metadata file", tokenFiles);
    const tokenMeta = JSON.parse(readFileSync(join(SHARE_DIR, tokenFiles[0]), "utf8"));
    assert(tokenMeta.read_only === true && tokenMeta.expires_at && tokenMeta.files.length === 2, "share token metadata records read-only files and expiry", tokenMeta);
    const shareToken = String(tokenMeta.token);

    const unsigned = await get(share.port, "/?f=0");
    assert(unsigned.status === 403 && unsigned.text.includes("share token"), "share rejects unsigned page requests", unsigned);

    const page = await get(share.port, `/?f=0&share=${shareToken}`);
    assert(page.status === 200 && page.text.includes("Shared Report"), "share serves the reviewed markdown");
    assert(page.text.includes("share-readonly-banner"), "share page renders a read-only banner");
    assert(page.text.includes("__YUNOMI_SHARE_READONLY__=true"), "share page marks the browser as read-only");
    assert(page.text.includes("submit-exit-btn") && page.text.includes("display:none"), "share page hides submit/comment controls");
    assert(
      page.text.includes("review-file-switcher") &&
        (page.text.includes(`/?f=1&share=${shareToken}`) || page.text.includes(`/?f=1&amp;share=${shareToken}`)),
      "share supports read-only multi-file switching",
    );

    const browser = await chromium.launch();
    try {
      for (const width of [1280, 375]) {
        const tab = await browser.newPage({ viewport: { width, height: 800 } });
        await tab.goto(`http://127.0.0.1:${share.port}/?f=0&share=${shareToken}`, { waitUntil: "domcontentloaded" });
        const tabLayout = await tab.evaluate(() => {
          const nav = document.querySelector<HTMLElement>("#review-file-switcher");
          const tabs = Array.from(document.querySelectorAll<HTMLElement>("#review-file-switcher a"));
          const rects = tabs.map((item) => item.getBoundingClientRect());
          return {
            navHeight: nav?.getBoundingClientRect().height ?? 0,
            label: document.querySelector(".review-file-switcher-label")?.textContent?.trim() ?? "",
            tabCount: tabs.length,
            overlap: rects.some((rect, index) => index > 0 && rect.left < rects[index - 1].right),
          };
        });
        assert(
          tabLayout.navHeight >= 44 && tabLayout.label === "Review files" && tabLayout.tabCount === 2 && !tabLayout.overlap,
          `share file tabs stay labeled and non-overlapping at width=${width}`,
          tabLayout,
        );
        await tab.close();
      }
    } finally {
      await browser.close();
    }

    const second = await get(share.port, `/?f=1&share=${shareToken}`);
    assert(second.status === 200 && second.text.includes("plain shared text"), "share serves the second file read-only");

    const blockedComment = await post(share.port, "/comment");
    assert(blockedComment.status === 405 && blockedComment.text.includes("read_only_share"), "share rejects comment POSTs");
    const blockedExit = await post(share.port, "/exit");
    assert(blockedExit.status === 405 && blockedExit.text.includes("read_only_share"), "share rejects submit POSTs");
    assert(!existsSync(join(REVIEW_DIR, "server.json")), "share does not write review server metadata");

    const revokeToken = shareToken;
    const revoke = await new Promise<{ code: number | null; output: string }>((resolve) => {
      const proc = spawn(process.execPath, [SERVER_JS, "share", "--revoke", revokeToken], {
        cwd: WORK_DIR,
        stdio: ["ignore", "pipe", "pipe"],
        env: {
          ...process.env,
          YUNOMI_SHARE_DIR: SHARE_DIR,
        },
      });
      let output = "";
      proc.stdout?.on("data", (chunk: Buffer) => { output += chunk.toString("utf8"); });
      proc.stderr?.on("data", (chunk: Buffer) => { output += chunk.toString("utf8"); });
      proc.on("exit", (code) => resolve({ code, output }));
    });
    assert(revoke.code === 0 && revoke.output.includes("revoked") && !existsSync(join(SHARE_DIR, `${revokeToken}.json`)), "share --revoke removes the token metadata", revoke);
  } finally {
    await stop(share.proc);
  }

  const publicShare = await startShare([
    report,
    "--public",
    "--no-open",
    "--port",
    String(BASE_PORT + 1),
  ]);
  try {
    assert(
      publicShare.output().includes("yunomi share token") && publicShare.port >= BASE_PORT + 1,
      "share --public starts an explicitly public signed share server",
      publicShare.output(),
    );
  } finally {
    await stop(publicShare.proc);
  }
} catch (error) {
  failed++;
  console.error(error instanceof Error ? error.stack || error.message : String(error));
} finally {
  rmSync(WORK_DIR, { recursive: true, force: true });
}

console.log(`Share read-only E2E: ${passed} passed, ${failed} failed`);
if (failed > 0) process.exit(1);
