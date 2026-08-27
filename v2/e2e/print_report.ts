import { spawn, type ChildProcess } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { chromium } from "playwright";

const SERVER_JS = new URL("../_build/js/release/build/server/server.js", import.meta.url).pathname;
const WORK_DIR = mkdtempSync(join(tmpdir(), "yunomi-print-report-"));
const REPORT = join(WORK_DIR, "REPORT.md");
const PDF = join(WORK_DIR, "report.pdf");

let passed = 0;
let failed = 0;

function assert(condition: boolean, message: string, detail?: unknown): void {
  if (condition) {
    passed++;
    console.log(`PASS: ${message}`);
    return;
  }
  failed++;
  console.error(`FAIL: ${message}`);
  if (detail !== undefined) console.error(JSON.stringify(detail, null, 2));
}

function startServer(): Promise<{ proc: ChildProcess; port: number }> {
  return new Promise((resolve, reject) => {
    const proc = spawn(process.execPath, [SERVER_JS, REPORT, "--no-open", "--port", "0"], {
      stdio: ["ignore", "pipe", "pipe"],
      env: {
        ...process.env,
        HERDR_PANE_ID: "",
        YUNOMI_NOTIFY_CMD: "",
        YUNOMI_LOCK_DIR: join(WORK_DIR, "locks"),
        YUNOMI_REVIEW_DIR: join(WORK_DIR, "reviews"),
      },
    });
    let output = "";
    let settled = false;
    const timer = setTimeout(() => {
      if (!settled) reject(new Error(`server did not start\n${output}`));
    }, 15000);
    const inspectOutput = () => {
      const match = output.match(/http:\/\/127\.0\.0\.1:(\d+)/);
      if (!settled && match) {
        settled = true;
        clearTimeout(timer);
        resolve({ proc, port: Number(match[1]) });
      }
    };
    proc.stdout?.on("data", (chunk: Buffer) => {
      output += chunk.toString("utf8");
      inspectOutput();
    });
    proc.stderr?.on("data", (chunk: Buffer) => {
      output += chunk.toString("utf8");
      inspectOutput();
    });
    proc.once("exit", (code) => {
      if (!settled) reject(new Error(`server exited before ready (${code})\n${output}`));
    });
  });
}

async function stopServer(proc: ChildProcess): Promise<void> {
  await new Promise<void>((resolve) => {
    const timer = setTimeout(() => {
      proc.kill("SIGKILL");
      resolve();
    }, 3000);
    proc.once("exit", () => {
      clearTimeout(timer);
      resolve();
    });
    proc.kill("SIGINT");
  });
}

function contrastRatio(foreground: string, background: string): number {
  const parse = (color: string): number[] => color.match(/\d+/g)?.slice(0, 3).map(Number) ?? [];
  const channel = (value: number): number => {
    const normalized = value / 255;
    return normalized <= 0.04045
      ? normalized / 12.92
      : ((normalized + 0.055) / 1.055) ** 2.4;
  };
  const luminance = (rgb: number[]): number =>
    0.2126 * channel(rgb[0]) + 0.7152 * channel(rgb[1]) + 0.0722 * channel(rgb[2]);
  const foregroundLuminance = luminance(parse(foreground));
  const backgroundLuminance = luminance(parse(background));
  return (Math.max(foregroundLuminance, backgroundLuminance) + 0.05) /
    (Math.min(foregroundLuminance, backgroundLuminance) + 0.05);
}

writeFileSync(REPORT, [
  "# Printable report",
  "",
  "## Collapsible section",
  "",
  "COLLAPSED_BODY_MUST_PRINT",
  "",
  "## Wide table",
  "",
  "| column one with long content | column two with long content | column three with long content | column four with long content | column five with long content | column six with long content |",
  "|---|---|---|---|---|---|",
  "| alpha alpha alpha alpha | beta beta beta beta | gamma gamma gamma gamma | delta delta delta delta | epsilon epsilon epsilon epsilon | zeta zeta zeta zeta |",
  "",
  "## Code",
  "",
  "```ts",
  "const darkPrintMustRemainReadable = true;",
  "```",
].join("\n"));

let server: ChildProcess | null = null;
try {
  const started = await startServer();
  server = started.proc;
  const browser = await chromium.launch({ channel: "chrome", headless: true });
  try {
    const page = await browser.newPage({ viewport: { width: 1200, height: 900 } });
    await page.goto(`http://127.0.0.1:${started.port}`, { waitUntil: "domcontentloaded" });

    assert(
      await page.getByRole("button", { name: "Print or save PDF" }).count() === 1,
      "Markdown report exposes one accessible print action",
    );

    const heading = page.locator("h2.md-heading-toggle").filter({ hasText: "Collapsible section" });
    const details = heading.locator("xpath=ancestor::details[1]");
    await heading.locator("xpath=preceding-sibling::*[contains(@class, 'heading-toggle-icon')]").click();
    assert(await details.getAttribute("open") === null, "screen heading can be collapsed before printing");

    await page.evaluate(() => document.documentElement.setAttribute("data-theme", "dark"));
    await page.emulateMedia({ media: "print" });
    const metrics = await page.evaluate(() => {
      const heading = Array.from(document.querySelectorAll("h2.md-heading-toggle"))
        .find((element) => element.textContent?.includes("Collapsible section"));
      const section = heading?.closest<HTMLElement>("details.heading-toggle");
      const content = section?.querySelector<HTMLElement>(".toggle-content");
      const marker = Array.from(document.querySelectorAll<HTMLElement>("p"))
        .find((element) => element.textContent?.includes("COLLAPSED_BODY_MUST_PRINT"));
      const table = document.querySelector<HTMLElement>(".md-preview table:not(.frontmatter-table table)");
      const preview = document.querySelector<HTMLElement>(".md-preview");
      const pre = document.querySelector<HTMLElement>(".md-preview pre");
      const code = document.querySelector<HTMLElement>(".md-preview pre code");
      const hiddenSelectors = [
        "header",
        ".md-right",
        ".comment-list",
        "#review-loop-panel",
        ".heading-toggle-icon",
      ];
      return {
        contentDisplay: content ? getComputedStyle(content).display : null,
        contentHeight: content?.getBoundingClientRect().height ?? 0,
        markerHeight: marker?.getBoundingClientRect().height ?? 0,
        tableWidth: table?.getBoundingClientRect().width ?? 0,
        previewWidth: preview?.getBoundingClientRect().width ?? 0,
        codeForeground: code ? getComputedStyle(code).color : "",
        codeBackground: pre ? getComputedStyle(pre).backgroundColor : "",
        visibleInteractiveUi: hiddenSelectors.filter((selector) => {
          const element = document.querySelector<HTMLElement>(selector);
          return element && getComputedStyle(element).display !== "none";
        }),
      };
    });

    assert(
      metrics.contentDisplay === "block" && metrics.contentHeight > 0 && metrics.markerHeight > 0,
      "print layout restores content from a collapsed screen section",
      metrics,
    );
    assert(
      Math.ceil(metrics.tableWidth) <= Math.ceil(metrics.previewWidth),
      "print table stays within the report content width",
      metrics,
    );
    const contrast = contrastRatio(metrics.codeForeground, metrics.codeBackground);
    assert(
      contrast >= 4.5,
      "dark-theme code remains readable in print at WCAG normal-text contrast",
      { ...metrics, contrast },
    );
    assert(
      metrics.visibleInteractiveUi.length === 0,
      "print output hides review and disclosure controls",
      metrics,
    );

    await page.pdf({ path: PDF, format: "A4", printBackground: true });
    const pdf = readFileSync(PDF);
    assert(pdf.subarray(0, 5).toString("ascii") === "%PDF-", "Chrome produces a PDF from the report print layout");
  } finally {
    await browser.close();
  }
} catch (error) {
  failed++;
  console.error(error instanceof Error ? error.stack || error.message : String(error));
} finally {
  if (server) await stopServer(server);
  rmSync(WORK_DIR, { recursive: true, force: true });
}

console.log(`Print report E2E: ${passed} passed, ${failed} failed`);
if (failed > 0) process.exit(1);
