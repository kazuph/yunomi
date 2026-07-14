import { chmodSync, existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawnSync } from "node:child_process";

const SERVER_JS = new URL("../_build/js/release/build/server/server.js", import.meta.url).pathname;
const WORK_DIR = mkdtempSync(join(tmpdir(), "yunomi-pr-sync-"));
const REVIEW_DIR = join(WORK_DIR, "reviews");
const BIN_DIR = join(WORK_DIR, "bin");
const GH_LOG = join(WORK_DIR, "gh-calls.jsonl");
const PULL_REVIEW_JSON = join(REVIEW_DIR, "review.json");
const REVIEW_ID = "feature-pr-sync";
const PUSH_REVIEW_JSON = join(REVIEW_DIR, REVIEW_ID, "review.json");

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

function hasStructuredCommentSchema(comment: any): boolean {
  return ["file", "row", "col", "end_row", "end_col", "snippet", "context_before", "context_after", "selector", "bounds", "element_text", "attachments"]
    .every((key) => Object.prototype.hasOwnProperty.call(comment || {}, key)) &&
    Array.isArray(comment?.attachments);
}

mkdirSync(BIN_DIR, { recursive: true });
mkdirSync(REVIEW_DIR, { recursive: true });
mkdirSync(join(WORK_DIR, "src"), { recursive: true });
spawnSync("git", ["init"], { cwd: WORK_DIR, stdio: "ignore" });
writeFileSync(join(WORK_DIR, "src/local.ts"), "const target = true;\n");
writeFileSync(join(BIN_DIR, "gh"), `#!/usr/bin/env node
const fs = require("node:fs");
const log = process.env.YUNOMI_FAKE_GH_LOG;
const args = process.argv.slice(2);
fs.appendFileSync(log, JSON.stringify(args) + "\\n");
if (args[0] === "repo" && args[1] === "view") {
  console.log(JSON.stringify({ owner: { login: "kazuph" }, name: "yunomi" }));
  process.exit(0);
}
if (args[0] === "pr" && args[1] === "view") {
  console.log(JSON.stringify({ number: 42, headRefOid: "abc123", url: "https://github.com/kazuph/yunomi/pull/42" }));
  process.exit(0);
}
if (args[0] === "api" && args[1] === "repos/kazuph/yunomi/pulls/42/comments" && args.includes("--paginate")) {
  console.log(JSON.stringify([
    {
      id: 1001,
      path: "src/app.ts",
      line: 12,
      body: "GitHub review comment",
      html_url: "https://github.com/kazuph/yunomi/pull/42#discussion_r1001",
      pull_request_review_id: 77,
      diff_hunk: "@@ line context",
      user: { login: "reviewer" }
    },
    {
      id: 1002,
      in_reply_to_id: 1001,
      path: "src/app.ts",
      line: 12,
      body: "GitHub threaded reply",
      html_url: "https://github.com/kazuph/yunomi/pull/42#discussion_r1002",
      user: { login: "reviewer2" }
    }
  ]));
  process.exit(0);
}
if (args[0] === "api" && args[1] === "repos/kazuph/yunomi/pulls/42/comments") {
  console.log(JSON.stringify({ id: 9001, html_url: "https://github.com/kazuph/yunomi/pull/42#discussion_r9001" }));
  process.exit(0);
}
console.error("unexpected gh args: " + args.join(" "));
process.exit(1);
`);
chmodSync(join(BIN_DIR, "gh"), 0o755);

const env = {
  ...process.env,
  PATH: `${BIN_DIR}:${process.env.PATH || ""}`,
  YUNOMI_REVIEW_DIR: REVIEW_DIR,
  YUNOMI_FAKE_GH_LOG: GH_LOG,
};

function runYunomi(args: string[]) {
  return spawnSync(process.execPath, [SERVER_JS, ...args], {
    cwd: WORK_DIR,
    encoding: "utf8",
    env,
  });
}

try {
  const missingGh = spawnSync(process.execPath, [SERVER_JS, "pull", "42"], {
    cwd: WORK_DIR,
    encoding: "utf8",
    env: { ...process.env, PATH: "", YUNOMI_REVIEW_DIR: REVIEW_DIR },
  });
  assert(
    missingGh.status === 1 && missingGh.stderr.includes("gh repo view failed"),
    "GitHub sync explains that the gh command is unavailable",
    missingGh,
  );

  const pulled = runYunomi(["pull", "42"]);
  assert(pulled.status === 0 && pulled.stdout.includes('"imported":1'), "yunomi pull imports GitHub review comments", pulled);
  const afterPull = JSON.parse(readFileSync(PULL_REVIEW_JSON, "utf8"));
  const imported = afterPull.comments.find((comment: { id?: string }) => comment.id === "gh-1001");
  assert(imported?.text === "GitHub review comment", "pulled GitHub comment is stored as a yunomi comment", imported);
  assert(
    hasStructuredCommentSchema(imported) &&
      imported.row === 11 &&
      imported.col === 0 &&
      imported.end_row === 11 &&
      imported.end_col === 0 &&
      imported.snippet === "@@ line context" &&
      imported.context_before === "" &&
      imported.context_after === "" &&
      imported.selector === "" &&
      imported.bounds === "" &&
      imported.element_text === "@@ line context",
    "pulled GitHub comment has the common top-level structured schema",
    imported,
  );
  assert(imported?.github?.comment_id === "1001", "pulled comment records GitHub metadata", imported);
  assert(imported?.replies?.[0]?.text === "GitHub threaded reply", "pull maps GitHub threaded replies into yunomi replies", imported);

  afterPull.files.push("src/local.ts");
  afterPull.comments.push({
    id: "local-1",
    file: join(WORK_DIR, "src/local.ts"),
    line: 7,
    round: 1,
    text: "Push this yunomi comment",
    author: "human",
    status: "unresolved",
    replies: [],
    anchor: { snippet: "target", context_before: "", context_after: "" },
  });
  mkdirSync(join(REVIEW_DIR, REVIEW_ID), { recursive: true });
  writeFileSync(PUSH_REVIEW_JSON, JSON.stringify(afterPull, null, 2));

  const pushed = runYunomi(["push", REVIEW_ID, "42"]);
  assert(pushed.status === 0 && pushed.stdout.includes('"pushed":1'), "yunomi push sends unsynced yunomi comments to GitHub", pushed);
  const afterPush = JSON.parse(readFileSync(PUSH_REVIEW_JSON, "utf8"));
  const local = afterPush.comments.find((comment: { id?: string }) => comment.id === "local-1");
  assert(local?.github?.comment_id === "9001", "push marks the local comment as GitHub-synced", local);
  assert(
    hasStructuredCommentSchema(local) &&
      local.row === 6 &&
      local.end_row === 6 &&
      local.snippet === "target" &&
      local.context_before === "" &&
      local.context_after === "" &&
      local.selector === "" &&
      local.bounds === "" &&
      local.element_text === "target",
    "push normalizes old review.json comments that only had anchor context",
    local,
  );

  const ghCalls = readFileSync(GH_LOG, "utf8").trim().split("\n").map((line) => JSON.parse(line));
  const pushCall = ghCalls.find((args: string[]) => args[0] === "api" && args.includes("body=Push this yunomi comment"));
  assert(
    Array.isArray(pushCall) &&
      pushCall.includes("commit_id=abc123") &&
      pushCall.includes("path=src/local.ts") &&
      pushCall.includes("line=7") &&
      pushCall.includes("side=RIGHT"),
    "push uses GitHub PR review-comment API arguments",
    { pushCall, ghCalls },
  );

  const missingReviewId = runYunomi(["push", "42"]);
  assert(
    missingReviewId.status === 1 && missingReviewId.stderr.includes("review-id"),
    "push rejects the old ambiguous form without an explicit review id",
    missingReviewId,
  );

  const unknownReviewId = runYunomi(["push", "does-not-exist", "42"]);
  assert(
    unknownReviewId.status === 1 && unknownReviewId.stderr.includes("review-id not found"),
    "push rejects an unknown review id instead of silently creating an empty review",
    unknownReviewId,
  );
} catch (error) {
  failed++;
  console.error(error instanceof Error ? error.stack || error.message : String(error));
} finally {
  rmSync(WORK_DIR, { recursive: true, force: true });
}

console.log(`GitHub PR sync E2E: ${passed} passed, ${failed} failed`);
if (failed > 0) process.exit(1);
