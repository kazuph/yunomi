import assert from "node:assert/strict";
import http, { type IncomingMessage } from "node:http";
import { spawn, type ChildProcess } from "node:child_process";
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { chromium } from "playwright";

const SERVER_JS = new URL("../_build/js/release/build/server/server.js", import.meta.url).pathname;
const TMP_DIR = join(tmpdir(), `yunomi-review-loop-${Date.now()}`);
const LOCK_DIR = join(TMP_DIR, "locks");
const REPORT = join(TMP_DIR, "REPORT.md");
const PORT = 5167;
const NON_LOOP_REPORT = join(TMP_DIR, "NON_LOOP.md");
const NON_LOOP_REVIEW_DIR = join(TMP_DIR, ".yunomi", "reviews", "non-loop");
const NON_LOOP_PORT = PORT + 1;
const EMPTY_REPORT = join(TMP_DIR, "EMPTY.md");
const EMPTY_REVIEW_DIR = join(TMP_DIR, ".yunomi", "reviews", "empty");
const EMPTY_PORT = PORT + 2;
const childProcesses = new Set<ChildProcess>();

function trackProcess(proc: ChildProcess): ChildProcess {
  childProcesses.add(proc);
  proc.once("exit", () => childProcesses.delete(proc));
  return proc;
}

function stopChildProcesses(): void {
  for (const proc of childProcesses) {
    if (proc.exitCode === null && proc.signalCode === null) proc.kill("SIGTERM");
  }
}

mkdirSync(LOCK_DIR, { recursive: true });
writeFileSync(REPORT, "# Review Loop\n\nBefore line\n");
mkdirSync(NON_LOOP_REVIEW_DIR, { recursive: true });
writeFileSync(NON_LOOP_REPORT, "# Non Loop Review\n\nA normal review can approve with comments.\n");
mkdirSync(EMPTY_REVIEW_DIR, { recursive: true });
writeFileSync(EMPTY_REPORT, "# Empty Review\n");

function waitForServerOutput(proc: ChildProcess): Promise<number> {
  let output = "";
  let resolved = false;
  return new Promise((resolve, reject) => {
    proc.stdout?.on("data", (chunk: Buffer) => {
      output += String(chunk);
      if (resolved) return;
      const match = output.match(/http:\/\/127\.0\.0\.1:(\d+)/);
      if (match) {
        resolved = true;
        resolve(Number(match[1]));
      }
    });
    proc.stderr?.on("data", (chunk: Buffer) => {
      output += String(chunk);
    });
    proc.on("exit", (code) => {
      if (!resolved) {
        resolved = true;
        reject(new Error(`server exited before ready code=${code}\n${output}`));
      }
    });
    setTimeout(() => {
      if (!resolved) {
        resolved = true;
        reject(new Error(`server startup timeout\n${output}`));
      }
    }, 10000);
  });
}

function request(port: number, method: string, path: string, body = ""): Promise<{ status: number; body: string }> {
  return new Promise((resolve, reject) => {
    const req = http.request(
      `http://127.0.0.1:${port}${path}`,
      { method, headers: { "Content-Type": "application/json" } },
      (res: IncomingMessage) => {
        let data = "";
        res.on("data", (chunk: string) => {
          data += chunk;
        });
        res.on("end", () => resolve({ status: res.statusCode || 0, body: data }));
      },
    );
    req.on("error", reject);
    if (body.length > 0) req.write(body);
    req.end();
  });
}

async function waitForHealth(port: number): Promise<void> {
  for (let i = 0; i < 80; i++) {
    try {
      const res = await request(port, "GET", "/healthz");
      if (res.status === 200) return;
    } catch (_: unknown) {}
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  throw new Error(`healthz timeout on ${port}`);
}

function collectOutput(proc: ChildProcess): { get: () => string } {
  let output = "";
  proc.stdout?.on("data", (chunk: Buffer) => {
    output += String(chunk);
  });
  proc.stderr?.on("data", (chunk: Buffer) => {
    output += String(chunk);
  });
  return { get: () => output };
}

function waitForExit(proc: ChildProcess, timeoutMs: number): Promise<number | null | "timeout"> {
  return new Promise((resolve) => {
    const timer = setTimeout(() => resolve("timeout"), timeoutMs);
    proc.once("exit", (code) => {
      clearTimeout(timer);
      resolve(code);
    });
  });
}

async function waitForRound(port: number, round: number): Promise<any> {
  for (let i = 0; i < 80; i++) {
    const res = await request(port, "GET", "/review-state");
    assert.equal(res.status, 200);
    const state = JSON.parse(res.body);
    const rounds = state.review.rounds || [];
    if (rounds.at(-1)?.round === round) return state;
    await new Promise((resolve) => setTimeout(resolve, 150));
  }
  throw new Error(`round ${round} did not appear`);
}

async function main(): Promise<void> {
  const REVIEW_DIR = join(TMP_DIR, ".yunomi", "reviews", "no-branch");
  mkdirSync(REVIEW_DIR, { recursive: true });
  const env = { ...process.env, HERDR_PANE_ID: "", YUNOMI_NOTIFY_CMD: "", YUNOMI_LOCK_DIR: LOCK_DIR, YUNOMI_REVIEW_DIR: REVIEW_DIR };
  const server = trackProcess(spawn(process.execPath, [SERVER_JS, "--no-open", "--loop", "--port", String(PORT), REPORT], {
    cwd: TMP_DIR,
    env,
    stdio: ["ignore", "pipe", "pipe"],
  }));
  const serverOutput = collectOutput(server);

  const port = await waitForServerOutput(server);
  await waitForHealth(port);
  const initialHtml = await request(port, "GET", "/");
  assert.equal(initialHtml.status, 200);
  assert.doesNotMatch(initialHtml.body, /review-loop-sidebar/, "review loop sidebar is not rendered");
  assert.match(initialHtml.body, /id="md-preview"[\s\S]*id="review-loop-panel"/, "markdown page embeds the review loop mount inside the preview");
  const uiJs = await request(port, "GET", "/ui.js");
  assert.equal(uiJs.status, 200);
  assert.match(uiJs.body, /Previous request/, "review loop UI must state the reviewer request for every item");
  assert.match(uiJs.body, /AI reply/, "review loop UI must show the AI response or its absence");
  assert.match(uiJs.body, /Resolve only after verifying/, "review loop Resolve button must explain the condition via tooltip");
  assert.doesNotMatch(uiJs.body, /解決条件/, "review loop must not repeat a fixed resolution rule inside every card");
  assert.match(uiJs.body, /submission to current diff/, "review loop UI must demote unrelated full-file diffs to supporting context");
  assert.match(uiJs.body, /All resolved — enjoy your tea/, "review loop UI must show a tea-themed approve-ready moment when all threads resolve");
  assert.match(uiJs.body, /review-loop-submit-state/, "submit modal must render review loop status text");

  const firstSubmit = await request(
    port,
    "POST",
    "/exit",
    JSON.stringify({
      summary: "Round 1 needs a text update",
      decision: "request_changes",
      action: "final_request_changes",
      comments: [{ row: 2, col: 1, text: "Please update this line", value: "Before line" }],
    }),
  );
  assert.equal(firstSubmit.status, 200);
  assert.equal(server.exitCode, null, "--loop request_changes must keep the server alive");

  const reviewJson = readFileSync(join(TMP_DIR, ".yunomi", "reviews", "no-branch", "review.json"), "utf-8");
  const review = JSON.parse(reviewJson);
  assert.equal(review.version, 1);
  assert.equal(review.rounds[0].decision, "request_changes");
  assert.equal(review.comments[0].id, "c-1-1");
  assert.equal(review.comments[0].status, "unresolved");
  assert.match(review.comments[0].anchor.snippet, /# Review Loop/, "review loop anchor keeps nearby source context");
  assert.match(review.comments[0].anchor.snippet, /Before line/, "review loop anchor includes the referenced line");

  writeFileSync(REPORT, "# Review Loop\n\nAfter line\n");
  const go = trackProcess(spawn(process.execPath, [SERVER_JS, "go", "--no-open", "--port", String(PORT)], {
    cwd: TMP_DIR,
    env,
    stdio: ["ignore", "pipe", "pipe"],
  }));
  const goOutput = collectOutput(go);
  const goCode = await waitForExit(go, 10000);
  assert.equal(goCode, 0, `yunomi go should notify the running loop server\ngo output:\n${goOutput.get()}\nserver output:\n${serverOutput.get()}`);

  const state = await waitForRound(port, 2);
  assert.equal(state.unresolved_count, 1);
  assert.equal(state.review.comments[0].id, "c-1-1");
  assert.match(JSON.stringify(state.diff.lines), /Before line/);
  assert.match(JSON.stringify(state.diff.lines), /After line/);

  const browser = await chromium.launch({ headless: true });
  try {
    const page = await browser.newPage({ viewport: { width: 1280, height: 900 } });
    await page.goto(`http://127.0.0.1:${port}/`, { waitUntil: "domcontentloaded" });
    await page.waitForSelector("#review-loop-panel .review-loop-comment", { timeout: 10000 });
    assert.equal(await page.locator("#review-loop-sidebar").count(), 0, "review loop sidebar is absent in the browser DOM");
    assert.equal(await page.locator("#md-preview > #review-loop-panel").count(), 1, "review loop overview is embedded in the preview");
    assert.equal(await page.locator(".review-loop-inline").count(), 0, "review loop requests are shown only in the overview panel");
    const overviewText = await page.locator("#review-loop-panel").first().textContent();
    assert.match(overviewText || "", /Review items/, "review loop overview content is visible in the preview");
    assert.doesNotMatch(overviewText || "", /Round 2 review items/, "review loop overview does not expose the internal round number as its title");
    assert.match(overviewText || "", /Round 1 needs a text update/, "review loop round summary is visible inline in the preview");
    const overviewLayout = await page.evaluate(() => {
      const panel = document.querySelector<HTMLElement>("#review-loop-panel");
      const details = panel?.querySelector<HTMLElement>(".review-loop-details");
      const context = panel?.querySelector<HTMLElement>(".review-loop-context");
      const response = panel?.querySelector<HTMLElement>(".review-loop-response");
      const snippet = panel?.querySelector<HTMLElement>(".review-loop-snippet");
      if (!panel || !details || !context || !response) return null;
      const panelStyle = getComputedStyle(panel);
      const panelRect = panel.getBoundingClientRect();
      const preview = document.querySelector<HTMLElement>("#md-preview");
      const previewStyle = preview ? getComputedStyle(preview) : null;
      const titlePath = document.querySelector<HTMLElement>("header h1 .title-path");
      const request = panel.querySelector<HTMLElement>(".review-loop-request");
      return {
        titlePathDisplay: titlePath ? getComputedStyle(titlePath).display : "",
        previewBackground: previewStyle?.backgroundColor,
        previewBorderWidth: previewStyle?.borderTopWidth,
        previewPadding: previewStyle?.padding,
        previewBoxShadow: previewStyle?.boxShadow,
        width: Math.round(panelRect.width),
        marginLeft: Math.round(parseFloat(panelStyle.marginLeft)),
        marginRight: Math.round(parseFloat(panelStyle.marginRight)),
        padding: panelStyle.padding,
        borderLeftWidth: panelStyle.borderLeftWidth,
        detailsGap: getComputedStyle(details).gap,
        contextGap: getComputedStyle(context).gap,
        contextBorderBottomWidth: getComputedStyle(context).borderBottomWidth,
        snippetBorderTopWidth: snippet ? getComputedStyle(snippet).borderTopWidth : "",
        contextColumns: getComputedStyle(context.firstElementChild as HTMLElement).gridTemplateColumns,
        requestColumns: request ? getComputedStyle(request).gridTemplateColumns : "",
        responseBorderLeftWidth: getComputedStyle(response).borderLeftWidth,
      };
    });
    assert.ok(overviewLayout, "review loop overview layout is available");
    assert.notEqual(overviewLayout?.titlePathDisplay, "none", "header shows the project/path label in the top-left chrome");
    assert.equal(overviewLayout?.previewBorderWidth, "0px", "review loop page removes the outer preview card border");
    assert.equal(overviewLayout?.previewPadding, "0px", "review loop page removes the outer preview card padding");
    assert.equal(overviewLayout?.previewBoxShadow, "none", "review loop page removes the outer preview card shadow");
    assert.ok((overviewLayout?.width || 0) > 1100, "review loop overview uses the available page width");
    assert.equal(overviewLayout?.marginLeft, 0, "review loop overview is left-aligned");
    assert.equal(overviewLayout?.marginRight, 0, "review loop overview is not centered");
    assert.equal(overviewLayout?.padding, "14px 16px", "review loop overview uses dense panel padding");
    assert.equal(overviewLayout?.borderLeftWidth, "1px", "review loop overview does not use a decorative left rule");
    assert.equal(overviewLayout?.detailsGap, "10px", "review loop overview uses tighter issue-list spacing");
    assert.equal(overviewLayout?.contextGap, "8px", "review loop context uses compact spacing");
    assert.equal(overviewLayout?.contextBorderBottomWidth, "0px", "review loop context does not add a decorative horizontal rule");
    assert.equal(overviewLayout?.snippetBorderTopWidth, "0px", "review loop source evidence does not add an extra horizontal rule");
    assert.match(overviewLayout?.contextColumns || "", /^96px /, "review loop context uses a fixed label column");
    assert.match(overviewLayout?.requestColumns || "", /^96px /, "review loop request uses a fixed label column");
    assert.equal(overviewLayout?.responseBorderLeftWidth, "0px", "review loop response has no nested left rule");
    assert.match(overviewText || "", /Please update this line/, "review loop request is visible in the overview panel");

    const themeMenuState = await page.evaluate(() => {
      const root = document.documentElement;
      const mode = document.querySelector<HTMLButtonElement>("#theme-toggle");
      const arrow = document.querySelector<HTMLButtonElement>("#theme-menu-toggle");
      const menu = document.querySelector<HTMLElement>("#theme-menu");
      const history = document.querySelector<HTMLElement>("#history-toggle");
      if (!mode || !arrow || !menu || !history) return null;
      const modeHeight = Math.round(mode.getBoundingClientRect().height);
      const arrowHeight = Math.round(arrow.getBoundingClientRect().height);
      const historyHeight = Math.round(history.getBoundingClientRect().height);
      mode.click();
      const menuAfterModeClick = !menu.hidden;
      arrow.click();
      const menuAfterArrowClick = !menu.hidden;
      const expandedAfterArrowClick = arrow.getAttribute("aria-expanded");
      const tokyoButton = menu.querySelector<HTMLButtonElement>('[data-color-scheme="tokyo"]');
      tokyoButton?.click();
      return {
        modeHeight,
        arrowHeight,
        historyHeight,
        menuAfterModeClick,
        menuAfterArrowClick,
        expandedAfterArrowClick,
        scheme: root.getAttribute("data-color-scheme"),
        storedScheme: localStorage.getItem("yunomi:color-scheme"),
        hiddenAfterSelect: menu.hidden,
        selectCount: menu.querySelectorAll("select").length,
      };
    });
    assert.ok(themeMenuState, "theme menu is present");
    assert.equal(themeMenuState?.modeHeight, themeMenuState?.arrowHeight, "theme mode and scheme arrow buttons share the same height");
    assert.equal(themeMenuState?.modeHeight, themeMenuState?.historyHeight, "theme segmented control matches adjacent header controls");
    assert.equal(themeMenuState?.menuAfterModeClick, false, "light/dark button does not open the color scheme menu");
    assert.equal(themeMenuState?.menuAfterArrowClick, true, "only the right arrow opens the color scheme menu");
    assert.equal(themeMenuState?.expandedAfterArrowClick, "true", "arrow button exposes expanded state while the menu is open");
    assert.equal(themeMenuState?.scheme, "tokyo", "color scheme button changes the page scheme");
    assert.equal(themeMenuState?.storedScheme, "tokyo", "selected color scheme is persisted");
    assert.equal(themeMenuState?.hiddenAfterSelect, true, "scheme menu closes after selection");
    assert.equal(themeMenuState?.selectCount, 0, "scheme menu uses buttons rather than a pulldown select");

    const themeContrastChecks = await page.evaluate(() => {
      const root = document.documentElement;
      const panel = document.querySelector<HTMLElement>("#review-loop-panel");
      const schemes = ["primer", "tokyo", "catppuccin", "one-dark", "solarized", "gruvbox"];
      const themes = ["light", "dark"];
      return themes.flatMap((theme) => schemes.map((scheme) => {
        root.setAttribute("data-theme", theme);
        root.setAttribute("data-color-scheme", scheme);
        const style = getComputedStyle(root);
        return {
          theme,
          scheme,
          text: style.getPropertyValue("--text").trim(),
          muted: style.getPropertyValue("--muted").trim(),
          textInverse: style.getPropertyValue("--text-inverse").trim(),
          accent: style.getPropertyValue("--accent").trim(),
          accentStrong: style.getPropertyValue("--accent-strong").trim(),
          accent2: style.getPropertyValue("--accent-2").trim(),
          panel: style.getPropertyValue("--panel-solid").trim(),
        };
      }));
    });
    const rgb = (value: string): [number, number, number] => {
      if (value.startsWith("#") && value.length === 7) {
        return [
          Number.parseInt(value.slice(1, 3), 16),
          Number.parseInt(value.slice(3, 5), 16),
          Number.parseInt(value.slice(5, 7), 16),
        ];
      }
      const parts = value.match(/[\d.]+/g)?.slice(0, 3).map(Number) || [0, 0, 0];
      if (value.startsWith("color(srgb")) {
        return [
          Math.round((parts[0] || 0) * 255),
          Math.round((parts[1] || 0) * 255),
          Math.round((parts[2] || 0) * 255),
        ];
      }
      return [parts[0] || 0, parts[1] || 0, parts[2] || 0];
    };
    const channel = (value: number) => {
      const normalized = value / 255;
      return normalized <= 0.03928 ? normalized / 12.92 : Math.pow((normalized + 0.055) / 1.055, 2.4);
    };
    const luminance = ([r, g, b]: [number, number, number]) => 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b);
    const contrast = (fg: string, bg: string) => {
      const light = Math.max(luminance(rgb(fg)), luminance(rgb(bg)));
      const dark = Math.min(luminance(rgb(fg)), luminance(rgb(bg)));
      return (light + 0.05) / (dark + 0.05);
    };
    assert.equal(themeContrastChecks.length, 12, "six color schemes must exist in both light and dark modes");
    for (const check of themeContrastChecks) {
      const pairs = [
        ["text/panel", check.text, check.panel],
        ["muted/panel", check.muted, check.panel],
        ["accent-strong/panel", check.accentStrong, check.panel],
        ["text-inverse/accent", check.textInverse, check.accent],
        ["text-inverse/accent-2", check.textInverse, check.accent2],
      ] as const;
      for (const [label, foreground, background] of pairs) {
        const ratio = contrast(foreground, background);
        assert.ok(ratio >= 4.5, `${check.scheme}/${check.theme} ${label} contrast must stay readable; got ${ratio.toFixed(2)} (${foreground} on ${background})`);
      }
    }

    await page.click("#send-and-exit");
    const blockedApproval = await page.evaluate(() => {
      const modal = document.querySelector<HTMLElement>("#submit-modal");
      const approve = document.querySelector<HTMLButtonElement>("#modal-approve");
      const reason = document.querySelector<HTMLElement>("#approve-blocked-reason");
      if (!modal || !approve || !reason) return null;
      const style = getComputedStyle(approve);
      return {
        modalVisible: modal.classList.contains("visible"),
        disabled: approve.disabled,
        describedBy: approve.getAttribute("aria-describedby"),
        reasonVisible: getComputedStyle(reason).display !== "none",
        reasonText: reason.textContent,
        cursor: style.cursor,
        opacity: Number.parseFloat(style.opacity),
      };
    });
    assert.ok(blockedApproval, "blocked approval state is available");
    assert.equal(blockedApproval?.modalVisible, true, "submit modal opens while approval is blocked");
    assert.equal(blockedApproval?.disabled, true, "approve is disabled while review items remain unresolved");
    assert.equal(blockedApproval?.describedBy, "approve-blocked-reason", "approve exposes its blocked reason to assistive technology");
    assert.equal(blockedApproval?.reasonVisible, true, "blocked approval reason is visible");
    assert.match(blockedApproval?.reasonText || "", /1 review item remains unresolved/, "blocked reason includes the unresolved count");
    assert.equal(blockedApproval?.cursor, "not-allowed", "blocked approve uses a disabled cursor");
    assert.ok((blockedApproval?.opacity || 1) < 1, "blocked approve is visually distinct from an enabled action");

    await page.click("#review-unresolved-action");
    const recoveryNavigation = await page.evaluate(() => {
      const modal = document.querySelector<HTMLElement>("#submit-modal");
      const resolve = document.querySelector<HTMLElement>(".review-loop-resolve");
      const comment = resolve?.closest<HTMLElement>(".review-loop-comment");
      const rect = comment?.getBoundingClientRect();
      return {
        modalVisible: modal?.classList.contains("visible"),
        targetFocused: document.activeElement === comment,
        targetVisible: !!rect && rect.bottom > 0 && rect.top < window.innerHeight,
        detailsOpen: comment?.closest("details")?.hasAttribute("open"),
      };
    });
    assert.equal(recoveryNavigation.modalVisible, false, "recovery action closes the submit modal");
    assert.equal(recoveryNavigation.targetFocused, true, "recovery action focuses the first unresolved review item");
    assert.equal(recoveryNavigation.targetVisible, true, "recovery action brings the unresolved review item into view");
    assert.equal(recoveryNavigation.detailsOpen, true, "recovery action expands the unresolved review item container");

    const jaContext = await browser.newContext({ viewport: { width: 1280, height: 900 }, locale: "ja-JP" });
    try {
      const jaPage = await jaContext.newPage();
      await jaPage.goto(`http://127.0.0.1:${port}/`, { waitUntil: "domcontentloaded" });
      await jaPage.waitForSelector("#review-loop-panel .review-loop-comment", { timeout: 10000 });
      const jaOverviewText = await jaPage.locator("#review-loop-panel").first().textContent();
      assert.match(jaOverviewText || "", /確認項目/, "Japanese review loop overview uses a neutral review items title");
      assert.doesNotMatch(jaOverviewText || "", /Round \d+ の確認項目/, "Japanese review loop overview does not expose the internal round number as its title");
      assert.doesNotMatch(jaOverviewText || "", /Round \d+ 提出時/, "Japanese review loop diff label does not expose the internal round number");
      await jaPage.click("#send-and-exit");
      assert.match(await jaPage.locator("#approve-blocked-reason").textContent() || "", /未解決の確認項目が 1 件あるため、承認できません。/, "Japanese submit modal explains why approval is blocked");
      assert.equal(await jaPage.locator("#review-unresolved-action").textContent(), "未解決の確認項目を見る", "Japanese submit modal labels the recovery action");
    } finally {
      await jaContext.close().catch(() => {});
    }
  } finally {
    await browser.close().catch(() => {});
  }

  const blockedApprove = await request(
    port,
    "POST",
    "/exit",
    JSON.stringify({ summary: "try approve", decision: "approve", action: "final_approve", comments: [] }),
  );
  assert.equal(blockedApprove.status, 409, "server must reject approve while unresolved comments remain");

  const resolve = await request(port, "POST", "/resolve-comment", JSON.stringify({ id: "c-1-1" }));
  assert.equal(resolve.status, 200);

  const resolvedBrowser = await chromium.launch({ headless: true });
  try {
    const resolvedPage = await resolvedBrowser.newPage({ viewport: { width: 1280, height: 900 } });
    await resolvedPage.goto(`http://127.0.0.1:${port}/`, { waitUntil: "domcontentloaded" });
    await resolvedPage.waitForSelector("#review-loop-panel", { timeout: 10000 });
    await resolvedPage.click("#send-and-exit");
    assert.equal(await resolvedPage.locator("#modal-approve").isEnabled(), true, "approve is enabled after all review items are resolved");
    assert.equal(await resolvedPage.locator("#approve-blocked-reason").isVisible(), false, "blocked reason is hidden after all review items are resolved");
    assert.equal(await resolvedPage.locator("#modal-approve").getAttribute("aria-describedby"), null, "approve drops the blocked description after recovery");
  } finally {
    await resolvedBrowser.close().catch(() => {});
  }

  const finalApprove = await request(
    port,
    "POST",
    "/exit",
    JSON.stringify({ summary: "approved", decision: "approve", action: "final_approve", comments: [] }),
  );
  assert.equal(finalApprove.status, 200);

  const exitCode = await waitForExit(server, 10000);
  assert.equal(exitCode, 0, "approve should exit the loop server");

  writeFileSync(
    join(NON_LOOP_REVIEW_DIR, "review.json"),
    JSON.stringify(
      {
        version: 1,
        branch: "non-loop",
        files: [NON_LOOP_REPORT],
        rounds: [
          { round: 1, started_at: "2026-07-07T00:00:00.000Z", submitted_at: "2026-07-07T00:01:00.000Z", decision: "request_changes", summary: "old" },
          { round: 2, started_at: "2026-07-07T00:02:00.000Z", submitted_at: null, decision: null, summary: "" },
        ],
        comments: [
          {
            id: "c-1-1",
            file: "NON_LOOP.md",
            line: 3,
            round: 1,
            text: "stale non-loop thread must not block approve",
            author: "human",
            status: "unresolved",
            replies: [],
            anchor: { snippet: "A normal review can approve with comments.", context_before: "", context_after: "" },
          },
        ],
      },
      null,
      2,
    ),
  );
  const nonLoopEnv = { ...process.env, HERDR_PANE_ID: "", YUNOMI_NOTIFY_CMD: "", YUNOMI_LOCK_DIR: LOCK_DIR, YUNOMI_REVIEW_DIR: NON_LOOP_REVIEW_DIR };
  const nonLoop = trackProcess(spawn(process.execPath, [SERVER_JS, "--no-open", "--port", String(NON_LOOP_PORT), NON_LOOP_REPORT], {
    cwd: TMP_DIR,
    env: nonLoopEnv,
    stdio: ["ignore", "pipe", "pipe"],
  }));
  const nonLoopPort = await waitForServerOutput(nonLoop);
  await waitForHealth(nonLoopPort);
  const nonLoopHtml = await request(nonLoopPort, "GET", "/");
  assert.equal(nonLoopHtml.status, 200);
  assert.doesNotMatch(nonLoopHtml.body, /review-loop-sidebar/, "non-loop page does not render a review loop sidebar");
  assert.match(nonLoopHtml.body, /id="md-preview"[\s\S]*id="review-loop-panel"/, "non-loop page embeds the review loop mount inside the preview");
  assert.match(nonLoopHtml.body, /review-loop-submit-state/, "submit modal must include a review loop status row");
  const nonLoopState = await request(nonLoopPort, "GET", "/review-state");
  assert.equal(nonLoopState.status, 200);
  const nonLoopStateJson = JSON.parse(nonLoopState.body);
  assert.equal(nonLoopStateJson.review.rounds.at(-1)?.round, 2, "non-loop review-state must expose the current review round");
  assert.equal(nonLoopStateJson.review.comments[0]?.status, "unresolved", "non-loop review-state must expose thread status");
  assert.equal(nonLoopStateJson.unresolved_count, 1, "non-loop review-state must display unresolved thread count");
  assert.equal(nonLoopStateJson.gate_unresolved_count, 0, "non-loop review-state must not enable approve gate");
  const nonLoopApprove = await request(
    nonLoopPort,
    "POST",
    "/exit",
    JSON.stringify({
      summary: "normal approve",
      decision: "approve",
      action: "final_approve",
      comments: [{ row: 3, col: 1, text: "normal review comment", value: "A normal review can approve with comments." }],
    }),
  );
  assert.equal(nonLoopApprove.status, 200, "non-loop approve must accept freshly written comments");
  assert.equal(await waitForExit(nonLoop, 10000), 0, "non-loop approve with comments should exit normally");

  writeFileSync(
    join(EMPTY_REVIEW_DIR, "review.json"),
    JSON.stringify({
      version: 1,
      branch: "empty",
      files: [EMPTY_REPORT],
      rounds: [
        { round: 1, started_at: "2026-07-07T00:00:00.000Z", submitted_at: "2026-07-07T00:01:00.000Z", decision: "approve", summary: "done" },
        { round: 2, started_at: "2026-07-07T00:02:00.000Z", submitted_at: null, decision: null, summary: "" },
      ],
      comments: [],
    }, null, 2),
  );
  const emptyEnv = { ...process.env, HERDR_PANE_ID: "", YUNOMI_NOTIFY_CMD: "", YUNOMI_LOCK_DIR: LOCK_DIR, YUNOMI_REVIEW_DIR: EMPTY_REVIEW_DIR };
  const empty = trackProcess(spawn(process.execPath, [SERVER_JS, "--no-open", "--port", String(EMPTY_PORT), EMPTY_REPORT], {
    cwd: TMP_DIR,
    env: emptyEnv,
    stdio: ["ignore", "pipe", "pipe"],
  }));
  const emptyPort = await waitForServerOutput(empty);
  await waitForHealth(emptyPort);
  const emptyBrowser = await chromium.launch({ headless: true });
  try {
    const page = await emptyBrowser.newPage({ viewport: { width: 1280, height: 900 } });
    await page.goto(`http://127.0.0.1:${emptyPort}/`, { waitUntil: "domcontentloaded" });
    await page.waitForSelector("#review-loop-panel .review-loop-ready");
    const emptyText = await page.locator("#review-loop-panel").textContent();
    assert.equal((emptyText || "").trim(), "All resolved — enjoy your tea", "an empty resolved review shows only the success state");
    assert.equal(await page.locator("#review-loop-panel").getByText("No review threads yet").count(), 0, "empty resolved review does not show a competing no-threads message");
  } finally {
    await emptyBrowser.close().catch(() => {});
  }
  await request(emptyPort, "POST", "/exit", JSON.stringify({ summary: "", decision: "approve", action: "final_approve", comments: [] }));
  assert.equal(await waitForExit(empty, 10000), 0, "empty review server exits normally");
  console.log("PASS: review loop e2e");
}

try {
  await main();
} finally {
  stopChildProcesses();
}
