///|
fn meta_reviews_root() -> String {
  let override_dir = get_env_var("YUNOMI_REVIEW_DIR")
  if override_dir.length() > 0 {
    override_dir
  } else {
    path_join(path_join(os_homedir(), ".yunomi"), "reviews")
  }
}

///|
fn meta_history_root() -> String {
  let override_dir = get_env_var("YUNOMI_HISTORY_DIR")
  if override_dir.length() > 0 {
    override_dir
  } else {
    path_join(path_join(os_homedir(), ".yunomi"), "history")
  }
}

///|
extern "js" fn js_stat_mtime_ms(stat : JsValue) -> Double =
  #|(s) => Number(s?.mtimeMs || 0)

///|
extern "js" fn try_call_double(
  func : () -> Double,
  fallback : Double,
) -> Double =
  #|(f, fallback) => { try { return f(); } catch (_) { return fallback; } }

///|
fn file_mtime_ms(path : String) -> Double {
  try_call_double(fn() { js_stat_mtime_ms(fs_stat_sync(path)) }, 0.0)
}

///|
fn collect_review_json_paths(root : String) -> Array[String] {
  let paths : Array[String] = []
  if root.length() == 0 || !exists_sync(root) {
    return paths
  }
  let direct = path_join(root, "review.json")
  if exists_sync(direct) && is_file_sync(direct) {
    paths.push(direct)
    return paths
  }
  for entry in readdir_sync(root) {
    let review_path = path_join(path_join(root, entry), "review.json")
    if exists_sync(review_path) && is_file_sync(review_path) {
      paths.push(review_path)
    }
  }
  paths
}

///|
fn collect_history_json(root : String) -> Array[String] {
  let out : Array[String] = []
  if root.length() == 0 || !exists_sync(root) {
    return out
  }
  for entry in readdir_sync(root) {
    if entry.has_suffix(".json") {
      let path = path_join(root, entry)
      if exists_sync(path) && is_file_sync(path) {
        out.push(read_file_safe(path))
      }
    }
  }
  out
}

///|
extern "js" fn js_status_output(
  paths : Array[String],
  jsons : Array[String],
  json_output : Bool,
) -> String =
  #|(paths, jsons, jsonOutput) => {
  #|  const rows = [];
  #|  for (let i = 0; i < jsons.length; i += 1) {
  #|    try {
  #|      const review = JSON.parse(jsons[i] || "{}");
  #|      const rounds = Array.isArray(review.rounds) ? review.rounds : [];
  #|      const current = rounds.reduce((a, b) => (Number(b.round || 0) > Number(a.round || 0) ? b : a), rounds[0] || {});
  #|      const decision = current.decision || null;
  #|      if (decision === "approve") continue;
  #|      const comments = Array.isArray(review.comments) ? review.comments : [];
  #|      const unresolved = comments.filter(c => c && c.status !== "resolved").length;
  #|      rows.push({
  #|        branch: String(review.branch || "detached"),
  #|        round: Number(current.round || rounds.length || 1),
  #|        unresolved,
  #|        files: Array.isArray(review.files) ? review.files.length : 0,
  #|        decision,
  #|        path: paths[i],
  #|      });
  #|    } catch (_) {}
  #|  }
  #|  if (jsonOutput) return JSON.stringify({ reviews: rows }, null, 2);
  #|  if (!rows.length) return "No in-progress yunomi reviews.\n";
  #|  const lines = ["In-progress yunomi reviews:", "BRANCH\tROUND\tUNRESOLVED\tFILES\tDECISION"];
  #|  for (const r of rows) lines.push(`${r.branch}\t${r.round}\t${r.unresolved}\t${r.files}\t${r.decision || "open"}`);
  #|  return lines.join("\n") + "\n";
  #|}

///|
extern "js" fn js_stats_output(
  history_jsons : Array[String],
  json_output : Bool,
) -> String =
  #|(historyJsons, jsonOutput) => {
  #|  const cutoff = Date.now() - 30 * 24 * 60 * 60 * 1000;
  #|  const entries = [];
  #|  for (const raw of historyJsons) {
  #|    try {
  #|      const parsed = JSON.parse(raw || "[]");
  #|      const arr = Array.isArray(parsed) ? parsed : [parsed];
  #|      for (const entry of arr) {
  #|        const t = Date.parse(entry?.timestamp || "");
  #|        if (Number.isFinite(t) && t >= cutoff) entries.push(entry);
  #|      }
  #|    } catch (_) {}
  #|  }
  #|  const decided = entries.filter(e => e.decision === "approve" || e.decision === "request_changes");
  #|  const approved = decided.filter(e => e.decision === "approve").length;
  #|  const roundEntries = entries.filter(e => Number.isFinite(Number(e.roundCount)));
  #|  const commentEntries = entries.filter(e => Number.isFinite(Number(e.commentCount)));
  #|  const avg = (arr, key) => arr.length ? arr.reduce((sum, e) => sum + Number(e[key] || 0), 0) / arr.length : 0;
  #|  const result = {
  #|    window_days: 30,
  #|    entries: entries.length,
  #|    decided: decided.length,
  #|    approved,
  #|    approve_rate: decided.length ? approved / decided.length : null,
  #|    average_rounds: avg(roundEntries, "roundCount"),
  #|    average_comments: avg(commentEntries, "commentCount"),
  #|  };
  #|  if (jsonOutput) return JSON.stringify(result, null, 2);
  #|  const rate = result.approve_rate == null ? "n/a" : `${Math.round(result.approve_rate * 100)}%`;
  #|  return [
  #|    "Yunomi stats for the last 30 days:",
  #|    `Reviews: ${result.entries}`,
  #|    `Approve rate: ${rate} (${approved}/${decided.length})`,
  #|    `Average rounds: ${result.average_rounds.toFixed(2)}`,
  #|    `Average comments: ${result.average_comments.toFixed(2)}`,
  #|  ].join("\n") + "\n";
  #|}

///|
extern "js" fn js_cleanup_candidates(
  paths : Array[String],
  jsons : Array[String],
  mtimes : Array[Double],
  older_than_days : Int,
) -> Array[String] =
  #|(paths, jsons, mtimes, days) => {
  #|  const cutoff = Date.now() - Number(days || 90) * 24 * 60 * 60 * 1000;
  #|  const out = [];
  #|  for (let i = 0; i < paths.length; i += 1) {
  #|    try {
  #|      const review = JSON.parse(jsons[i] || "{}");
  #|      const rounds = Array.isArray(review.rounds) ? review.rounds : [];
  #|      const current = rounds.reduce((a, b) => (Number(b.round || 0) > Number(a.round || 0) ? b : a), rounds[0] || {});
  #|      if (current.decision !== "approve") continue;
  #|      const submittedAt = Date.parse(current.submitted_at || "");
  #|      const ageMs = Number.isFinite(submittedAt) ? submittedAt : Number(mtimes[i] || 0);
  #|      if (ageMs > 0 && ageMs < cutoff) out.push(paths[i]);
  #|    } catch (_) {}
  #|  }
  #|  return out;
  #|}

///|
extern "js" fn js_cleanup_output(
  deleted : Array[String],
  json_output : Bool,
) -> String =
  #|(deleted, jsonOutput) => {
  #|  if (jsonOutput) return JSON.stringify({ deleted: deleted.length, paths: deleted }, null, 2);
  #|  if (!deleted.length) return "No approved yunomi reviews matched cleanup.\n";
  #|  return [`Deleted ${deleted.length} approved yunomi review(s):`, ...deleted].join("\n") + "\n";
  #|}

///|
fn handle_meta_status(json_output : Bool) -> Unit {
  let paths = collect_review_json_paths(meta_reviews_root())
  let jsons : Array[String] = []
  for path in paths {
    jsons.push(read_file_safe(path))
  }
  process_stdout_write(js_status_output(paths, jsons, json_output))
}

///|
fn handle_meta_stats(json_output : Bool) -> Unit {
  process_stdout_write(
    js_stats_output(collect_history_json(meta_history_root()), json_output),
  )
}

///|
fn handle_meta_cleanup(json_output : Bool, older_than_days : Int) -> Unit {
  let paths = collect_review_json_paths(meta_reviews_root())
  let jsons : Array[String] = []
  let mtimes : Array[Double] = []
  for path in paths {
    jsons.push(read_file_safe(path))
    mtimes.push(file_mtime_ms(path))
  }
  let candidates = js_cleanup_candidates(paths, jsons, mtimes, older_than_days)
  let deleted : Array[String] = []
  for review_path in candidates {
    let dir = path_dirname(review_path)
    rm_dir_recursive(dir)
    deleted.push(dir)
  }
  process_stdout_write(js_cleanup_output(deleted, json_output))
}

///|
fn parse_meta_json_flag(args : Array[String]) -> Bool {
  let mut json_output = false
  for arg in args {
    if arg == "--json" {
      json_output = true
    }
  }
  json_output
}

///|
fn parse_cleanup_older_than(args : Array[String]) -> Int {
  let mut days = 90
  let mut i = 1
  while i < args.length() {
    if args[i] == "--older-than" && i + 1 < args.length() {
      days = @core.parse_int_safe(args[i + 1])
      if days <= 0 {
        days = 90
      }
      i = i + 1
    }
    i = i + 1
  }
  days
}
