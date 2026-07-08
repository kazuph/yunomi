import { spawnSync } from "node:child_process";
import { existsSync, mkdirSync, mkdtempSync, readFileSync, realpathSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const SERVER_JS = new URL("../_build/js/release/build/server/server.js", import.meta.url).pathname;
const WORK_DIR = mkdtempSync(join(tmpdir(), "yunomi-init-template-"));
const TEMPLATE_DIR = join(WORK_DIR, "templates");

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

function run(args: string[], cwd = WORK_DIR) {
  return spawnSync(process.execPath, [SERVER_JS, ...args], {
    cwd,
    encoding: "utf8",
    env: {
      ...process.env,
      HERDR_PANE_ID: "",
      YUNOMI_NOTIFY_CMD: "",
      YUNOMI_TEMPLATE_DIR: TEMPLATE_DIR,
    },
  });
}

try {
  mkdirSync(TEMPLATE_DIR, { recursive: true });
  writeFileSync(join(TEMPLATE_DIR, "custom.md"), "# {{title}}\n\nCustom {{template}} {{feature}}\n");

  const list = run(["init", "--list-templates", "--json"]);
  const listed = JSON.parse(list.stdout);
  assert(list.status === 0, "init --list-templates --json exits 0", list);
  assert(listed.templates.includes("default") && listed.templates.includes("bugfix") && listed.templates.includes("feature") && listed.templates.includes("custom"), "list includes built-in and user templates", listed);

  const builtIn = run(["init", "--template", "bugfix", "--json"]);
  const builtInResult = JSON.parse(builtIn.stdout);
  const bugfixReport = join(WORK_DIR, ".artifacts", "yunomi-init-template-" + WORK_DIR.split("yunomi-init-template-").at(-1), "REPORT.md");
  const bugfixText = readFileSync(builtInResult.path, "utf8");
  assert(builtIn.status === 0 && existsSync(builtInResult.path), "init creates REPORT.md from built-in template", builtInResult);
  assert(realpathSync(builtInResult.path) === realpathSync(bugfixReport) && bugfixText.includes("## 1. 再現手順"), "built-in template renders expected artifact path and content", { path: builtInResult.path, bugfixReport, bugfixText });

  const duplicate = run(["init", "--template", "bugfix"]);
  assert(duplicate.status === 1 && duplicate.stderr.includes("REPORT.md already exists"), "init refuses to overwrite existing REPORT.md", duplicate);

  const customWork = mkdtempSync(join(tmpdir(), "yunomi-custom-template-"));
  const custom = run(["init", "--template", "custom", "--json"], customWork);
  const customResult = JSON.parse(custom.stdout);
  const customText = readFileSync(customResult.path, "utf8");
  assert(custom.status === 0 && customText.includes("Custom custom"), "init reads user-defined templates", { customResult, customText });

  const missing = run(["init", "--template", "missing-template"], customWork);
  assert(missing.status === 1 && missing.stderr.includes("template not found"), "missing template exits 1 with a clear error", missing);
} catch (error) {
  failed++;
  console.error(error instanceof Error ? error.stack || error.message : String(error));
} finally {
  rmSync(WORK_DIR, { recursive: true, force: true });
}

console.log(`Init template E2E: ${passed} passed, ${failed} failed`);
if (failed > 0) process.exit(1);
