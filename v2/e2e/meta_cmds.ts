import { spawnSync } from "node:child_process";
import { existsSync, mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const SERVER_JS = new URL("../_build/js/release/build/server/server.js", import.meta.url).pathname;
const WORK_DIR = mkdtempSync(join(tmpdir(), "yunomi-meta-"));
const REVIEW_ROOT = join(WORK_DIR, "reviews");
const HISTORY_ROOT = join(WORK_DIR, "history");

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

function run(args: string[]) {
  return spawnSync(process.execPath, [SERVER_JS, ...args], {
    cwd: WORK_DIR,
    encoding: "utf8",
    env: {
      ...process.env,
      HERDR_PANE_ID: "",
      YUNOMI_NOTIFY_CMD: "",
      YUNOMI_REVIEW_DIR: REVIEW_ROOT,
      YUNOMI_HISTORY_DIR: HISTORY_ROOT,
    },
  });
}

function writeReview(name: string, review: unknown): string {
  const dir = join(REVIEW_ROOT, name);
  mkdirSync(dir, { recursive: true });
  const path = join(dir, "review.json");
  writeFileSync(path, JSON.stringify(review, null, 2));
  return dir;
}

try {
  mkdirSync(REVIEW_ROOT, { recursive: true });
  mkdirSync(HISTORY_ROOT, { recursive: true });

  const oldApprovedDate = new Date(Date.now() - 120 * 24 * 60 * 60 * 1000).toISOString();
  const recentApprovedDate = new Date(Date.now() - 10 * 24 * 60 * 60 * 1000).toISOString();
  const activeDir = writeReview("feature-active", {
    version: 1,
    branch: "feature/active",
    files: ["REPORT.md", "src/app.ts"],
    rounds: [{ round: 2, started_at: recentApprovedDate, submitted_at: null, decision: "request_changes", summary: "fix" }],
    comments: [
      { id: "c1", status: "unresolved", round: 1 },
      { id: "c2", status: "resolved", round: 1 },
    ],
  });
  const oldApprovedDir = writeReview("feature-old-approved", {
    version: 1,
    branch: "feature/old-approved",
    files: ["old.md"],
    rounds: [{ round: 1, started_at: oldApprovedDate, submitted_at: oldApprovedDate, decision: "approve", summary: "ok" }],
    comments: [],
  });
  const recentApprovedDir = writeReview("feature-recent-approved", {
    version: 1,
    branch: "feature/recent-approved",
    files: ["recent.md"],
    rounds: [{ round: 1, started_at: recentApprovedDate, submitted_at: recentApprovedDate, decision: "approve", summary: "ok" }],
    comments: [],
  });

  writeFileSync(join(HISTORY_ROOT, "one.json"), JSON.stringify([
    { timestamp: new Date().toISOString(), file: "a.md", summary: "ok", commentCount: 2, decision: "approve", roundCount: 1 },
    { timestamp: new Date().toISOString(), file: "b.md", summary: "fix", commentCount: 4, decision: "request_changes", roundCount: 3 },
    { timestamp: new Date(Date.now() - 40 * 24 * 60 * 60 * 1000).toISOString(), file: "old.md", summary: "old", commentCount: 99, decision: "approve", roundCount: 9 },
  ], null, 2));

  const statusJson = run(["status", "--json"]);
  const status = JSON.parse(statusJson.stdout);
  assert(statusJson.status === 0, "yunomi status --json exits 0", statusJson);
  assert(status.reviews.length === 1 && status.reviews[0].branch === "feature/active", "status lists only in-progress reviews", status);
  assert(status.reviews[0].round === 2 && status.reviews[0].unresolved === 1, "status reports round and unresolved count", status);

  const statusText = run(["status"]);
  assert(statusText.stdout.includes("feature/active") && statusText.stdout.includes("UNRESOLVED"), "status human output is readable", statusText.stdout);

  const statsJson = run(["stats", "--json"]);
  const stats = JSON.parse(statsJson.stdout);
  assert(statsJson.status === 0, "yunomi stats --json exits 0", statsJson);
  assert(stats.entries === 2 && stats.approved === 1 && stats.decided === 2, "stats uses the last 30 days only", stats);
  assert(stats.approve_rate === 0.5 && stats.average_rounds === 2 && stats.average_comments === 3, "stats computes approve rate and averages", stats);

  const statsText = run(["stats"]);
  assert(statsText.stdout.includes("Approve rate: 50%") && statsText.stdout.includes("Average rounds: 2.00"), "stats human output is readable", statsText.stdout);

  const cleanupJson = run(["cleanup", "--older-than", "90", "--json"]);
  const cleanup = JSON.parse(cleanupJson.stdout);
  assert(cleanupJson.status === 0, "yunomi cleanup --json exits 0", cleanupJson);
  assert(cleanup.deleted === 1 && cleanup.paths[0] === oldApprovedDir, "cleanup deletes only old approved reviews", cleanup);
  assert(!existsSync(oldApprovedDir), "old approved review directory is removed");
  assert(existsSync(activeDir), "cleanup keeps in-progress review directory");
  assert(existsSync(recentApprovedDir), "cleanup keeps recent approved review directory");

  const cleanupText = run(["cleanup", "--older-than", "90"]);
  assert(cleanupText.stdout.includes("No approved yunomi reviews matched cleanup"), "cleanup human output handles no matches", cleanupText.stdout);
} catch (error) {
  failed++;
  console.error(error instanceof Error ? error.stack || error.message : String(error));
} finally {
  rmSync(WORK_DIR, { recursive: true, force: true });
}

console.log(`Meta commands E2E: ${passed} passed, ${failed} failed`);
if (failed > 0) process.exit(1);
