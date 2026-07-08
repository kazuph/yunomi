///|
/// Server context for one file
struct ServerContext {
  file_path : String
  filename : String
  mode : @core.FileMode
  source_text : String // raw content for stdin servers ("" for file servers, which re-read on demand)
  mut port : Int
  mut html_cache : String
  sse_clients : Array[JsValue]
  active_tabs : Array[String]
  active_tab_instances : Map[String, String]
  mut pending_close_timer : JsValue
  mut finished : Bool
  is_loop : Bool
  // Epoch-ms timestamp of the most recent GET / (or /index.html) request —
  // i.e. the browser fetching the page document itself. Updated on every
  // such request, including reloads.
  mut last_index_get_ms : Double
  // Epoch-ms timestamp of the most recent close signal (last active tab
  // reporting itself closed). Used to correlate a close against a nearby
  // index GET to distinguish "tab reloading" from "tab genuinely abandoned".
  mut last_close_signal_ms : Double
  notify_pane : String
}

///|
/// All active server contexts
let active_servers : Array[ServerContext] = []

///|
/// Encoding override from CLI --encoding / -e flag
let encoding_override : Ref[String] = Ref("")

///|
/// Host address to bind to (default: 127.0.0.1)
let bind_host : Ref[String] = Ref("127.0.0.1")

///|
/// Optional pane to notify when human decisions are made in the preview.
let notify_pane_id : Ref[String] = Ref("")

///|
/// Results collected from submissions
let all_results : Array[@core.ReviewResult] = []

///|
/// Expected total number of files
let expected_count : Ref[Int] = Ref(0)

///|
/// Per-process id announced over SSE so reused-port tabs can self-reload
let server_instance_id : Ref[String] = Ref("")

///|
/// Live log file path for real-time comment IPC
let live_log_path : Ref[String] = Ref("")

// ===== Review Loop State =====

///|
let loop_mode : Ref[Bool] = Ref(false)

///|
let notify_pane_arg : Ref[String] = Ref("")

///|
let review_mux_mode : Ref[Bool] = Ref(false)

///| Read-only sharing mode. Explicitly enabled only by `yunomi share`.
let share_mode : Ref[Bool] = Ref(false)

///|
fn resolve_notify_pane() -> String {
  if notify_pane_arg.val.length() > 0 {
    notify_pane_arg.val
  } else {
    get_env_var("HERDR_PANE_ID")
  }
}

///|
fn review_url(ctx : ServerContext) -> String {
  let host = if bind_host.val == "0.0.0.0" { "127.0.0.1" } else { bind_host.val }
  "http://\{host}:\{ctx.port}"
}

///|
fn notify_reviewer(ctx : ServerContext, msg : String) -> Unit {
  let err = send_notify_message(ctx.notify_pane, msg)
  if err.length() > 0 {
    console_error("[yunomi] notify failed: " + err)
  }
}

///|
fn normalized_decision_for_notify(decision : String, action : String) -> String {
  if decision.length() > 0 {
    decision
  } else if action == "final_approve" {
    "approve"
  } else if action == "final_request_changes" {
    "request_changes"
  } else {
    ""
  }
}

///|
fn normalized_action_for_notify(decision : String, action : String) -> String {
  if action.length() > 0 {
    action
  } else if decision == "approve" {
    "final_approve"
  } else if decision == "request_changes" {
    "final_request_changes"
  } else {
    ""
  }
}

///|
fn verdict_notify_message(
  ctx : ServerContext,
  decision : String,
  action : String,
  comment_count : Int,
) -> String {
  let normalized_decision = normalized_decision_for_notify(decision, action)
  let normalized_action = normalized_action_for_notify(normalized_decision, action)
  let buf = StringBuilder::new()
  buf.write_string("[yunomi] verdict ")
  buf.write_string(ctx.filename)
  if normalized_decision.length() > 0 {
    buf.write_string(" decision=")
    buf.write_string(normalized_decision)
  }
  if normalized_action.length() > 0 {
    buf.write_string(" action=")
    buf.write_string(normalized_action)
  }
  buf.write_string(" comments=")
  buf.write_string(comment_count.to_string())
  buf.write_string(" url=")
  buf.write_string(review_url(ctx))
  buf.to_string()
}

///|
/// Initialize live log file
fn init_live_log() -> Unit {
  let pid = process_pid()
  let path = path_join(os_tmpdir(), "yunomi-live-\{pid}.jsonl")
  live_log_path.val = path
  write_file_secure(path, "")
  console_error("[YUNOMI_LIVE] \{path}")
}

///|
/// Append a JSONL line to the live log
fn append_live_log(json_line : String) -> Unit {
  if live_log_path.val.length() > 0 {
    try_call_void(fn() {
      fs_append_file_sync(live_log_path.val, json_line + "\n")
    })
  }
}

///|
/// Clean up live log file
fn cleanup_live_log() -> Unit {
  if live_log_path.val.length() > 0 && exists_sync(live_log_path.val) {
    try_call_void(fn() { unlink_sync(live_log_path.val) })
  }
}

///|
fn log_session_event(message : String) -> Unit {
  console_error("[YUNOMI_SESSION] " + message)
}

///|
fn exit_process(reason : String, code : Int) -> Unit {
  console_error("[YUNOMI_EXIT] " + reason + " code=" + code.to_string())
  process_exit(code)
}

///|
/// Cached ui.js content
let ui_js_cache : Ref[String] = Ref("")

///|
/// Load ui.js from build output
fn load_ui_js() -> String {
  if ui_js_cache.val.length() > 0 {
    return ui_js_cache.val
  }
  let script_dir = get_script_dir()
  let ui_path = path_join(script_dir, "../ui/ui.js")
  if exists_sync(ui_path) {
    let content = read_file_sync(ui_path, "utf-8")
    ui_js_cache.val = content
    content
  } else {
    console_error("Warning: ui.js not found at \{ui_path}")
    "// ui.js not found"
  }
}

///|
/// Get lock file directory
fn lock_dir() -> String {
  let override_dir = get_env_var("YUNOMI_LOCK_DIR")
  if override_dir.length() > 0 {
    override_dir
  } else {
    path_join(os_homedir(), ".yunomi/locks")
  }
}

///|
/// Get lock file path for a port
fn lock_path(port : Int) -> String {
  let dir = lock_dir()
  path_join(dir, "\{port}.lock")
}

///|
/// Ensure lock directory exists
fn ensure_lock_dir() -> Unit {
  let dir = lock_dir()
  if !exists_sync(dir) {
    mkdir_sync(dir, mkdir_recursive_opts())
  }
}

///|
/// Check if a port is locked by another process
fn is_port_locked(port : Int) -> Bool {
  let lp = lock_path(port)
  if !exists_sync(lp) {
    return false
  }
  // Read PID from lock file and check if process is alive
  let content = read_file_safe(lp)
  if content.length() == 0 {
    try_call_void(fn() { unlink_sync(lp) })
    return false
  }
  let pid = js_lock_pid(content)
  if pid <= 0 {
    try_call_void(fn() { unlink_sync(lp) })
    return false
  }
  if process_exists(pid) {
    true
  } else {
    // Stale lock: process no longer exists
    try_call_void(fn() { unlink_sync(lp) })
    false
  }
}

///|
/// Write lock file for a port (stores PID)
fn write_lock(port : Int, file_path : String) -> Unit {
  ensure_lock_dir()
  let lp = lock_path(port)
  let resolved_file = if file_path == "<stdin>" {
    file_path
  } else {
    path_resolve(file_path)
  }
  write_file_sync(
    lp,
    "{\"pid\":\{process_pid()},\"port\":\{port},\"file\":\{json_encode_value(resolved_file)}}",
  )
}

///|
/// Remove lock file for a port
fn remove_lock(port : Int) -> Unit {
  let lp = lock_path(port)
  if exists_sync(lp) {
    try_call_void(fn() { unlink_sync(lp) })
  }
}

///|
/// Find first available port starting from base, skipping locked ports
fn find_available_port(base : Int) -> Int {
  let mut port = base
  let mut attempts = 0
  while attempts < max_port_attempts {
    if !is_port_locked(port) {
      return port
    }
    console_log("Port \{port} locked, trying \{port + 1}...")
    port = port + 1
    attempts = attempts + 1
  }
  base // fallback
}

///|
/// Main entry point
fn main {
  let argv = get_argv()
  let args : Array[String] = []
  for i in 2..<argv.length() {
    args.push(argv[i])
  }
  if args.length() > 0 && args[0] == "live" && args.length() < 2 {
    console_error("yunomi live: target URL is required")
    print_usage()
    exit_process("live target missing", 1)
  }
  if args.length() >= 2 && args[0] == "live" {
    let mut port = 4989
    let mut no_open = false
    let mut i = 2
    while i < args.length() {
      let arg = args[i]
      if arg == "--port" {
        i = i + 1
        if i < args.length() {
          port = parse_port(args[i])
        }
      } else if arg == "--no-open" {
        no_open = true
      } else if arg == "--host" {
        i = i + 1
        if i < args.length() {
          bind_host.val = args[i]
        }
      }
      i = i + 1
    }
    server_instance_id.val = gen_instance_id()
    start_live_proxy(args[1], port, bind_host.val, no_open, server_instance_id.val)
    return
  }
  if args.length() > 0 {
    if args[0] == "comment" {
      handle_comment_command(args)
      exit_process("comment command", 0)
    } else if args[0] == "mcp" {
      run_mcp_server()
      return
    } else if args[0] == "share" {
      handle_share_command(args)
      return
    } else if args[0] == "pull" {
      handle_pr_sync_command("pull", args)
      return
    } else if args[0] == "push" {
      handle_pr_sync_command("push", args)
      return
    } else if args[0] == "install" {
      handle_install_command(args)
      exit_process("install command", 0)
    } else if args[0] == "review" {
      handle_review_command(args)
      return
    }
  }
  let mut port = 4989
  let mut no_open = false
  let mut go_mode = false
  let mut reply_mode = false
  let mut reply_id = ""
  let mut reply_text = ""
  let files : Array[String] = []
  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    if arg == "--help" || arg == "-h" {
      print_usage()
      exit_process("help requested", 0)
    } else if arg == "--skill" {
      print_skill_doc()
      exit_process("skill doc requested", 0)
    } else if arg == "--version" || arg == "-v" {
      let ver = get_package_version()
      console_log("yunomi " + ver + " (moonbit)")
      exit_process("version requested", 0)
    } else if arg == "go" && files.is_empty() {
      go_mode = true
    } else if arg == "reply" && files.is_empty() {
      reply_mode = true
      if i + 2 < args.length() {
        reply_id = args[i + 1]
        reply_text = args[i + 2]
        i = i + 2
      }
    } else if arg == "--loop" {
      loop_mode.val = true
    } else if arg == "--notify-pane" {
      i = i + 1
      if i < args.length() {
        notify_pane_arg.val = args[i]
        notify_pane_id.val = args[i]
      }
    } else if arg == "--port" {
      i = i + 1
      if i < args.length() {
        port = parse_port(args[i])
      }
    } else if arg == "--no-open" {
      no_open = true
    } else if arg == "--host" {
      i = i + 1
      if i < args.length() {
        bind_host.val = args[i]
      }
    } else if arg == "--encoding" || arg == "-e" {
      i = i + 1
      if i < args.length() {
        encoding_override.val = args[i]
      }
    } else if !arg.has_prefix("-") {
      files.push(arg)
    }
    i = i + 1
  }
  if go_mode {
    handle_go_command(port, no_open)
    return
  }
  if reply_mode {
    handle_reply_command(reply_id, reply_text)
    return
  }
  if notify_pane_id.val.length() == 0 {
    notify_pane_id.val = get_env_var("HERDR_PANE_ID")
  }
  // Interactive terminal with no files: the reader is almost always an
  // AI agent told "run npx yunomi". Serve the skill document before any
  // server setup so stdout is the pure markdown skill text.
  if files.is_empty() && is_stdin_tty() {
    print_skill_doc()
    exit_process("no args on tty", 0)
  }
  server_instance_id.val = gen_instance_id()
  // Initialize live log for real-time comment IPC
  init_live_log()
  // Cleanup locks and live log on SIGINT
  on_process_signal("SIGINT", fn() {
    cleanup_live_log()
    for srv in active_servers {
      remove_lock(srv.port)
    }
    exit_process("SIGINT", 0)
  })
  // Pre-load ui.js
  ignore(load_ui_js())
  // No files and stdin is piped: read a diff from stdin
  if files.is_empty() {
    let stdin_content = read_stdin_sync()
    if stdin_content.length() > 0 {
      start_stdin_server(stdin_content, port, no_open)
      return
    }
    // Piped but empty: a confused script — show usage and fail
    print_usage()
    exit_process("empty piped stdin", 1)
  }
  // Enforce media embed discipline before serving anything:
  // [text](media) links hide evidence from the reviewer — refuse and
  // let the caller (usually an AI agent) fix the markdown first.
  enforce_media_discipline(files)
  // Start servers for each file
  expected_count.val = files.length()
  ensure_lock_dir()
  for idx, file_path in files {
    let current_port = find_available_port(port + idx)
    start_file_server(file_path, current_port, no_open)
  }
}

///|
/// Exit with a fix-it message when markdown files link (instead of embed) media
fn enforce_media_discipline(files : Array[String]) -> Unit {
  let mut violation_total = 0
  for file_path in files {
    let resolved = path_resolve(file_path)
    if !exists_sync(resolved) {
      continue
    }
    if detect_mode(resolved) != @core.FileMode::Markdown {
      continue
    }
    let content = decode_file(resolved, encoding_override.val)
    let violations = @core.find_media_link_violations(content)
    if violations.is_empty() {
      continue
    }
    if violation_total == 0 {
      console_error("yunomi: media embed discipline violation")
    }
    console_error("")
    console_error(resolved)
    for v in violations {
      console_error("  line " + v.line_no.to_string() + ": " + v.snippet)
      console_error("    fix: " + v.fixed)
    }
    violation_total = violation_total + violations.length()
  }
  if violation_total > 0 {
    console_error("")
    console_error(
      "Images and videos must be EMBEDDED with ![alt](path) image syntax, not referenced as [text](path) links.",
    )
    console_error(
      "yunomi renders only embedded media; a plain link hides the evidence from the reviewer.",
    )
    console_error("Fix the lines above, then run yunomi again.")
    exit_process("media embed discipline violation", 1)
  }
}

///|
fn git_result(args : Array[String]) -> (Int, String, String) {
  let git = resolve_command("git")
  if git.length() == 0 {
    (1, "", "git command not found")
  } else {
    spawn_sync_result_args(git, args)
  }
}

///|
fn split_nonempty_lines(text : String) -> Array[String] {
  let out : Array[String] = []
  for line in @core.split_to_lines(text) {
    let trimmed = line.trim().to_owned()
    if trimmed.length() > 0 {
      out.push(trimmed)
    }
  }
  out
}

///|
fn push_unique(values : Array[String], value : String) -> Unit {
  for existing in values {
    if existing == value {
      return
    }
  }
  values.push(value)
}

///|
fn git_stdout_or_empty(args : Array[String]) -> String {
  let result = git_result(args)
  if result.0 == 0 {
    result.1.trim().to_owned()
  } else {
    ""
  }
}

///|
fn default_review_base() -> String {
  let upstream = git_stdout_or_empty([
    "rev-parse",
    "--abbrev-ref",
    "--symbolic-full-name",
    "@{upstream}",
  ])
  if upstream.length() > 0 { upstream } else { "main" }
}

///|
fn review_changed_files(base_ref : String) -> Array[String] {
  let root_result = git_result(["rev-parse", "--show-toplevel"])
  if root_result.0 != 0 {
    console_error("yunomi review: not a git repository")
    exit_process("review not git", 1)
  }
  let root = root_result.1.trim().to_owned()
  let files : Array[String] = []
  let base = if base_ref.length() > 0 { base_ref } else { default_review_base() }
  let committed = git_result([
    "diff",
    "--name-only",
    "--diff-filter=ACMR",
    base + "...HEAD",
  ])
  if committed.0 != 0 {
    let detail = committed.2.trim().to_owned()
    let detail_suffix = if detail.length() > 0 { ": " + detail } else { "" }
    console_error(
      "yunomi review: git diff failed for base '" + base + "'" + detail_suffix,
    )
    exit_process("review diff failed", 1)
  }
  for file in split_nonempty_lines(committed.1) {
    push_unique(files, path_join(root, file))
  }
  let working = git_result(["diff", "--name-only", "--diff-filter=ACMR"])
  if working.0 == 0 {
    for file in split_nonempty_lines(working.1) {
      push_unique(files, path_join(root, file))
    }
  }
  let staged = git_result(["diff", "--cached", "--name-only", "--diff-filter=ACMR"])
  if staged.0 == 0 {
    for file in split_nonempty_lines(staged.1) {
      push_unique(files, path_join(root, file))
    }
  }
  files
}

///|
fn handle_review_command(args : Array[String]) -> Unit {
  let mut port = 4989
  let mut no_open = false
  let mut base_ref = ""
  let mut i = 1
  while i < args.length() {
    let arg = args[i]
    if arg == "--port" {
      i = i + 1
      if i < args.length() {
        port = parse_port(args[i])
      }
    } else if arg == "--no-open" {
      no_open = true
    } else if arg == "--host" {
      i = i + 1
      if i < args.length() {
        bind_host.val = args[i]
      }
    } else if !arg.has_prefix("-") && base_ref.length() == 0 {
      base_ref = arg
    }
    i = i + 1
  }
  let files = review_changed_files(base_ref)
  if files.is_empty() {
    console_error("yunomi review: no changed files")
    exit_process("review no files", 1)
  }
  enforce_media_discipline(files)
  server_instance_id.val = gen_instance_id()
  init_live_log()
  start_review_mux_server(files, port, no_open)
}

///|
fn print_usage() -> Unit {
  let usage =
    #|Usage: yunomi <file...> [options]
    #|       yunomi review [base-ref] [options]
    #|       yunomi live <http://localhost:port> [options]
    #|       yunomi comment <file:line> <text> [--author <name>]
    #|       yunomi mcp
    #|       yunomi share <file...> [--host <addr>] [--port <n>] [--no-open]
    #|       yunomi pull [pr-number|url]
    #|       yunomi push [pr-number|url]
    #|       yunomi install <agent> [--global|--project] [--list]
    #|
    #|Options:
    #|  --port <n>        Base port (default: 4989)
    #|  --host <addr>     Bind address (default: 127.0.0.1, use 0.0.0.0 for remote)
    #|  --no-open         Don't open browser
    #|  --loop            Keep serving after request_changes; exit only on approve
    #|  --notify-pane id  Send live comments/verdicts to a Herdr agent pane
    #|  -e, --encoding <enc>  Force encoding (e.g. shift-jis, euc-jp)
    #|  --skill           Print the skill document for AI agents
    #|  -h, --help        Show help
    #|  -v, --version     Show version
    #|
    #|Supported formats: CSV, TSV, Markdown, Diff, Plain text
    #|Agents: claude, codex, cursor, opencode, cline, gemini
    #|Pipe stdin for diff: git diff | yunomi
    #|Review changed files: yunomi review main
    #|Continue a loop: yunomi go
    #|Reply to a thread: yunomi reply <comment-id> '<text>'
    #|MCP bridge: yunomi mcp
    #|Read-only share URL: yunomi share REPORT.md --host 0.0.0.0
    #|GitHub PR sync: yunomi pull 123 && yunomi push 123
    #|Live review accepts only http://localhost or http://127.0.0.1 targets.
    #|Run with no arguments to print the AI agent skill document.
  console_log(usage)
}

///|
fn handle_pr_sync_command(mode : String, args : Array[String]) -> Unit {
  let pr = if args.length() > 1 { args[1] } else { "" }
  let review_path = review_json_path_for_cwd()
  let result = js_github_pr_sync(mode, review_path, process_cwd(), pr, iso_now())
  if json_parse_string("ok", result) != "true" {
    let error = json_parse_string("error", result)
    let detail = if error.length() > 0 { error } else { result }
    console_error("yunomi " + mode + ": " + detail)
    exit_process("github pr sync failed", 1)
  }
  console_log("yunomi " + mode + ": " + result)
  exit_process("github pr sync complete", 0)
}

///|
struct CommentTarget {
  file : String
  line : Int
}

///|
fn last_index_of(s : String, target : Char) -> Int {
  let chars = s.to_array()
  let mut found = -1
  for i, ch in chars {
    if ch == target {
      found = i
    }
  }
  found
}

///|
pub fn parse_comment_target(raw : String) -> CommentTarget {
  let sep = last_index_of(raw, ':')
  if sep <= 0 || sep >= raw.length() - 1 {
    console_error("yunomi comment: target must be <file>:<line>")
    exit_process("invalid comment target", 1)
  }
  let file = @core.safe_slice_range(raw, 0, sep)
  let line = @core.parse_int_safe(@core.safe_slice(raw, sep + 1))
  if line <= 0 {
    console_error("yunomi comment: line must be a positive integer")
    exit_process("invalid comment line", 1)
  }
  { file, line }
}

///|
pub fn comment_target_file(raw : String) -> String {
  parse_comment_target(raw).file
}

///|
pub fn comment_target_line(raw : String) -> Int {
  parse_comment_target(raw).line
}

///|
pub fn sanitize_branch_name(branch : String) -> String {
  let buf = StringBuilder::new()
  let chars = branch.to_array()
  for ch in chars {
    match ch {
      '/' | '\\' | ':' | ' ' | '\t' | '\n' => buf.write_char('-')
      _ => buf.write_char(ch)
    }
  }
  let out = buf.to_string()
  if out.length() > 0 { out } else { "detached" }
}

///|
fn main_git_stdout(args_json : String) -> String {
  let git = resolve_command("git")
  if git.length() == 0 {
    return ""
  }
  js_trim_string(spawn_sync_stdout(git, args_json))
}

///|
fn repo_root() -> String {
  let root = main_git_stdout("[\"rev-parse\",\"--show-toplevel\"]")
  if root.length() > 0 { root } else { process_cwd() }
}

///|
fn current_branch() -> String {
  let branch = main_git_stdout("[\"branch\",\"--show-current\"]")
  if branch.length() > 0 { branch } else { "detached" }
}

///|
fn ensure_parent_dir(file_path : String) -> Unit {
  let dir = path_dirname(file_path)
  if dir.length() > 0 && !exists_sync(dir) {
    mkdir_sync(dir, mkdir_recursive_opts())
  }
}

///|
fn review_file_path() -> String {
  let root = repo_root()
  path_join(
    path_join(
      path_join(root, ".yunomi"),
      "reviews",
    ),
    path_join(sanitize_branch_name(current_branch()), "review.json"),
  )
}

///|
fn source_context(file_path : String, line : Int) -> (String, String, String) {
  let abs = path_resolve(file_path)
  let content = read_file_safe(abs)
  if content.length() == 0 {
    return ("", "", "")
  }
  let lines = @core.split_to_lines(content)
  let idx = line - 1
  let snippet = if idx >= 0 && idx < lines.length() { lines[idx] } else { "" }
  let before = if idx > 0 && idx - 1 < lines.length() { lines[idx - 1] } else { "" }
  let after = if idx + 1 < lines.length() { lines[idx + 1] } else { "" }
  (snippet, before, after)
}

///|
fn write_review_comment(target : CommentTarget, text : String, author : String) -> String {
  let path = review_file_path()
  ensure_parent_dir(path)
  let existing = read_file_safe(path)
  let ctx = source_context(target.file, target.line)
  let updated = js_update_review_json(
    existing,
    current_branch(),
    target.file,
    target.line,
    text,
    author,
    ctx.0,
    ctx.1,
    ctx.2,
    iso_now(),
  )
  write_file_sync(path, updated)
  path
}

///|
fn post_comment_to_running_servers(target : CommentTarget, text : String) -> String {
  let curl = resolve_command("curl")
  if curl.length() == 0 {
    return "curl command not found"
  }
  if !exists_sync(lock_dir()) {
    return "lock directory not found: " + lock_dir()
  }
  let entries = readdir_sync(lock_dir())
  if entries.length() == 0 {
    return "no lock files found in " + lock_dir()
  }
  let target_abs = path_resolve(target.file)
  let body = "{\"type\":\"comment\",\"key\":\"cli-\{target.line}\",\"row\":\{target.line},\"col\":0,\"text\":\{json_encode_value(text)}}"
  let mut scanned = 0
  let mut candidates = 0
  let mut last_error = ""
  for entry in entries {
    if !entry.contains(".lock") {
      continue
    }
    scanned = scanned + 1
    let port_s = @core.safe_slice_range(entry, 0, entry.length() - 5)
    let port = @core.parse_int_safe(port_s)
    if port <= 0 {
      last_error = "invalid lock filename: " + entry
      continue
    }
    let lp = path_join(lock_dir(), entry)
    let content = read_file_safe(lp)
    if content.length() > 0 && !js_lock_matches_file(content, target_abs) {
      continue
    }
    candidates = candidates + 1
    let result = spawn_sync_status_args(
      curl,
      [
        "-sS",
        "-f",
        "-X",
        "POST",
        "-H",
        "Content-Type: application/json",
        "--data-binary",
        body,
        "http://127.0.0.1:\{port}/comment",
      ],
    )
    if result.0 == 0 {
      return ""
    }
    let detail = js_trim_string(result.1)
    last_error = if detail.length() > 0 {
      "POST http://127.0.0.1:\{port}/comment failed: " + detail
    } else {
      "POST http://127.0.0.1:\{port}/comment failed with exit " + result.0.to_string()
    }
  }
  if candidates == 0 {
    if scanned == 0 {
      "no .lock files found in " + lock_dir()
    } else {
      "no running server lock matched " + target_abs
    }
  } else {
    last_error
  }
}

///|
fn handle_comment_command(args : Array[String]) -> Unit {
  if args.length() < 3 {
    console_error("Usage: yunomi comment <file:line> <text> [--author <name>]")
    exit_process("comment usage", 1)
  }
  let target = parse_comment_target(args[1])
  let mut text = args[2]
  let mut author = "cli"
  let mut i = 3
  while i < args.length() {
    if args[i] == "--author" {
      i = i + 1
      if i < args.length() {
        author = args[i]
      }
    } else if text.length() == 0 {
      text = args[i]
    }
    i = i + 1
  }
  let fallback_reason = post_comment_to_running_servers(target, text)
  if fallback_reason.length() == 0 {
    console_log("Posted comment to running yunomi server")
    return
  }
  console_error("yunomi comment: falling back to offline review.json: " + fallback_reason)
  let path = write_review_comment(target, text, author)
  console_log("Added comment to " + path)
}

///|
fn skill_file_body() -> String {
  let frontmatter =
    #|---
    #|name: yunomi
    #|description: Serve finished work to the human as a browsable report for review and approval.
    #|---
    #|
  frontmatter + print_skill_doc_text()
}

///|
fn install_base_path(agent : String, global : Bool) -> String {
  let home = os_homedir()
  let cwd = process_cwd()
  match agent {
    "claude" => if global { path_join(path_join(home, ".claude"), "skills") } else { path_join(path_join(cwd, ".claude"), "skills") }
    "codex" => if global { path_join(path_join(home, ".agents"), "skills") } else { path_join(path_join(cwd, ".agents"), "skills") }
    "cursor" => if global { path_join(path_join(home, ".cursor"), "skills") } else { path_join(path_join(cwd, ".cursor"), "skills") }
    "opencode" => if global { path_join(path_join(home, ".config"), path_join("opencode", "skills")) } else { path_join(path_join(cwd, ".opencode"), "skills") }
    "cline" => if global { path_join(path_join(home, ".cline"), "rules") } else { path_join(path_join(cwd, ".cline"), "rules") }
    "gemini" => if global { path_join(path_join(home, ".gemini"), "skills") } else { path_join(path_join(cwd, ".gemini"), "skills") }
    _ => ""
  }
}

///|
pub fn install_target_path(agent : String, global : Bool) -> String {
  let base = install_base_path(agent, global)
  if base.length() == 0 {
    return ""
  }
  match agent {
    "claude" | "codex" | "cursor" | "gemini" => path_join(path_join(base, "yunomi"), "SKILL.md")
    "opencode" | "cline" => path_join(base, "yunomi.md")
    _ => ""
  }
}

///|
fn is_supported_agent(agent : String) -> Bool {
  agent == "claude" || agent == "codex" || agent == "cursor" ||
  agent == "opencode" || agent == "cline" || agent == "gemini"
}

///|
fn print_install_list(global : Bool) -> Unit {
  let agents = ["claude", "codex", "cursor", "opencode", "cline", "gemini"]
  for agent in agents {
    console_log(agent + " -> " + install_target_path(agent, global))
  }
}

///|
fn backup_existing(path : String) -> Unit {
  if exists_sync(path) {
    write_file_sync(path + ".bak", read_file_safe(path))
  }
}

///|
fn handle_install_command(args : Array[String]) -> Unit {
  let mut global = true
  let mut list = false
  let mut agent = ""
  let mut i = 1
  while i < args.length() {
    let arg = args[i]
    if arg == "--global" {
      global = true
    } else if arg == "--project" {
      global = false
    } else if arg == "--list" {
      list = true
    } else if !arg.has_prefix("-") {
      agent = arg
    }
    i = i + 1
  }
  if list {
    print_install_list(global)
    return
  }
  if !is_supported_agent(agent) {
    console_error("Usage: yunomi install <claude|codex|cursor|opencode|cline|gemini> [--global|--project] [--list]")
    exit_process("install usage", 1)
  }
  let target = install_target_path(agent, global)
  ensure_parent_dir(target)
  backup_existing(target)
  write_file_sync(target, skill_file_body())
  console_log("Installed yunomi skill for " + agent + " at " + target)
}

///| The instant skill: everything an AI agent needs to serve work for

///| human approval. Printed when yunomi runs with no arguments on a TTY,

///|
/// so "just tell your AI to run npx yunomi" is the entire onboarding.
fn print_skill_doc_text() -> String {
  let doc =
    #|# yunomi 🍵 — skill document for AI agents
    #|
    #|You are reading this because you ran `yunomi` with no arguments.
    #|yunomi (湯のみ, the Japanese teacup) is how you serve finished work to
    #|your human for approval — brewed as a report, set down in front of
    #|them like a cup of tea, with a quiet "douzo" (here you go).
    #|Read this once and you know the whole protocol. At the end, offer to
    #|install it permanently.
    #|
    #|## The idea
    #|
    #|Humans do not review diffs line by line anymore. They review the work:
    #|intent, changes, and proof. You write a report; yunomi opens it in the
    #|human's browser; the human reads, comments, and decides; yunomi writes
    #|`.yunomi/reviews/<branch>/review.json` and still prints the compatible
    #|stdout YAML verdict. You read the review file and act.
    #|Never show raw code diffs when a report would do.
    #|
    #|## The approval loop (follow exactly)
    #|
    #|1. Finish the work: implement, test, and collect evidence
    #|   (screenshots, test output, logs, screen recordings).
    #|2. Write REPORT.md (rules below).
    #|3. Serve it in the FOREGROUND with loop mode and wait:
    #|
    #|   ```bash
    #|   npx yunomi REPORT.md --loop
    #|   ```
    #|
    #|4. If the human submits `request_changes`, the server stays alive.
    #|   Read `.yunomi/reviews/<branch>/review.json`, fix every unresolved
    #|   thread, update REPORT.md, then run:
    #|
    #|   ```bash
    #|   npx yunomi go
    #|   ```
    #|
    #|5. The browser updates to the next round at the same URL, showing the
    #|   previous submitted REPORT.md versus the current REPORT.md diff.
    #|   Comments remain unresolved until the human clicks Resolve.
    #|6. When yunomi sends you a live comment notification, fix the exact
    #|   referenced location immediately. If useful, report what you changed
    #|   back into the thread without resolving it yourself:
    #|
    #|   ```bash
    #|   npx yunomi reply c-2-3 'Fixed the Japanese error message wording.'
    #|   ```
    #|
    #|   Save the file; yunomi hot-reloads the browser. Wait for the human
    #|   to click Resolve, comment again, approve, or reject. Keep the
    #|   process alive until approval/rejection completes.
    #|7. Do not ask for or claim approval while unresolved comments remain:
    #|   yunomi blocks `approve` until every thread is resolved. Repeat
    #|   fix -> `yunomi go` until the human approves.
    #|8. Only after `decision: approve`: commit, push, publish, or report
    #|   completion.
    #|
    #|## REPORT.md rules
    #|
    #|- Open with the original request: 1-3 lines stating what the human
    #|  asked for. A report that doesn't say what it answers is worthless.
    #|- Structure as WHY (problem/motivation) → HOW (approach, alternatives
    #|  considered) → WHAT (files, functions, concrete changes).
    #|- EMBED all evidence: images and videos must use `![alt](path)`.
    #|  A bare `[text](path)` link to media makes yunomi refuse to start
    #|  (exit 1) and print the lines to fix — fix them and rerun.
    #|- Mermaid code blocks render as interactive diagrams. Raw inline
    #|  HTML/SVG does NOT render — save diagrams as .svg files and embed
    #|  them as images.
    #|- Put any question for the human right next to the facts needed to
    #|  answer it, so they can decide without reading the whole document.
    #|- For AskUserQ-style decisions, write choices as task items like
    #|  `- [ ] Use OAuth`. When the human checks one, yunomi notifies you
    #|  immediately and rewrites `[ ]` to `[x]` in the source. After receiving
    #|  that notification, replace the hearing item with `- ✅️ Use OAuth`
    #|  (the decided wording). Do not leave accepted decisions as `- [ ]`.
    #|
    #|## Verdict schema (stdout YAML, printed when the human submits)
    #|
    #|```yaml
    #|action: final_approve | final_request_changes
    #|file: REPORT.md
    #|mode: markdown
    #|comments:           # may be empty
    #|  - row: 12         # line/row the comment is anchored to
    #|    col: 0
    #|    text: the human's comment
    #|    value: the line content it refers to
    #|summary: overall feedback from the human
    #|decision: approve | request_changes
    #|```
    #|
    #|Treat `review.json` as the durable source of truth and stdout YAML as
    #|the compatibility channel. In `--loop`, `request_changes` does not end
    #|the process; `approve` exits 0. An early nonzero exit means yunomi
    #|refused to start or `yunomi go` could not find the active review.
    #|
    #|## review.json v1
    #|
    #|The durable review file lives at:
    #|
    #|```text
    #|.yunomi/reviews/<branch-sanitized>/review.json
    #|```
    #|
    #|It contains:
    #|
    #|```json
    #|{
    #|  "version": 1,
    #|  "branch": "feature/x",
    #|  "files": ["REPORT.md"],
    #|  "rounds": [
    #|    { "round": 1, "started_at": "ISO8601", "submitted_at": "ISO8601|null",
    #|      "decision": "approve|request_changes|null", "summary": "string" }
    #|  ],
    #|  "comments": [
    #|    { "id": "c-<round>-<seq>", "file": "REPORT.md", "line": 42, "round": 1,
    #|      "text": "string", "author": "human|agent|cli",
    #|      "status": "unresolved|resolved",
    #|      "replies": [ { "author": "agent", "round": 2, "text": "string" } ],
    #|      "anchor": { "snippet": "string", "context_before": "string", "context_after": "string" } }
    #|  ]
    #|}
    #|```
    #|
    #|## CLI reference
    #|
    #|```bash
    #|yunomi <file...> [--loop] [--port n] [--host addr] [--no-open] [-e encoding]
    #|yunomi <file...> --loop --notify-pane <pane-id>
    #|yunomi go              # start the next round for this branch
    #|yunomi reply <comment-id> '<text>'  # add an agent reply to a thread
    #|yunomi comment <file:line> <text> [--author <name>]
    #|yunomi install <agent> [--global|--project] [--list]
    #|git diff | yunomi      # review a diff from stdin
    #|yunomi --skill         # print this document again
    #|```
    #|
    #|Formats: Markdown, CSV, TSV, unified diff, plain text.
    #|Multiple files open on consecutive ports and are reviewed together.
    #|
    #|## Install this skill permanently (do this now)
    #|
    #|Ask your human ONE yes/no question using your question mechanism
    #|(e.g. AskUserQuestion): "Install yunomi as a permanent skill, so I
    #|always serve my work for your approval this way? 🍵"
    #|
    #|If yes, write this entire document (everything you just read) to the
    #|location your runtime loads skills from, prepending this frontmatter:
    #|
    #|```markdown
    #|---
    #|name: yunomi
    #|description: Serve finished work to the human as a browsable report
    #|  for review and approval. Use whenever a task is complete and needs
    #|  human sign-off before commit/publish/completion.
    #|---
    #|```
    #|
    #|- Claude Code:  ~/.claude/skills/yunomi/SKILL.md
    #|- Codex/agents: ~/.agents/skills/yunomi/SKILL.md
    #|- Project-local alternative: .claude/skills/yunomi/SKILL.md
    #|
    #|From then on, serve every finished task with `npx yunomi REPORT.md --loop`
    #|without being asked, and use `npx yunomi go` after each fix round.
  doc
}

///|
fn print_skill_doc() -> Unit {
  console_log(print_skill_doc_text())
}

///|
fn parse_port(s : String) -> Int {
  let mut n = 0
  let chars = s.to_array()
  for ch in chars {
    if ch >= '0' && ch <= '9' {
      n = n * 10 + (ch.to_int() - '0'.to_int())
    }
  }
  if n == 0 {
    4989
  } else {
    n
  }
}

///|
/// Detect encoding from buffer: BOM → UTF-8 validate → heuristic
fn detect_encoding(buf : JsValue) -> String {
  let len = buffer_length(buf)
  if len == 0 {
    return "utf-8"
  }
  // BOM check
  if len >= 3 &&
    buffer_at(buf, 0) == 0xEF &&
    buffer_at(buf, 1) == 0xBB &&
    buffer_at(buf, 2) == 0xBF {
    return "utf-8"
  }
  if len >= 2 && buffer_at(buf, 0) == 0xFF && buffer_at(buf, 1) == 0xFE {
    return "utf-16le"
  }
  if len >= 2 && buffer_at(buf, 0) == 0xFE && buffer_at(buf, 1) == 0xFF {
    return "utf-16be"
  }
  // Try UTF-8 validation
  let mut i = 0
  let mut is_utf8 = true
  let check_limit = if len < 4096 { len } else { 4096 }
  while i < check_limit {
    let b = buffer_at(buf, i)
    if b < 0x80 {
      i = i + 1
      continue
    }
    // Multi-byte UTF-8
    let expected = if b >= 0xF0 {
      4
    } else if b >= 0xE0 {
      3
    } else if b >= 0xC0 {
      2
    } else {
      0
    }
    if expected == 0 {
      is_utf8 = false
      break
    }
    if i + expected > check_limit {
      break
    }
    let mut valid = true
    for j in 1..<expected {
      let cb = buffer_at(buf, i + j)
      if cb < 0x80 || cb >= 0xC0 {
        valid = false
        break
      }
    }
    if !valid {
      is_utf8 = false
      break
    }
    i = i + expected
    continue
  }
  if is_utf8 {
    return "utf-8"
  }
  // Heuristic: Shift-JIS vs EUC-JP
  let mut sjis_score = 0
  let mut euc_score = 0
  i = 0
  while i < check_limit - 1 {
    let b1 = buffer_at(buf, i)
    let b2 = buffer_at(buf, i + 1)
    // Shift-JIS: lead byte 0x81-0x9F or 0xE0-0xFC, trail 0x40-0x7E or 0x80-0xFC
    if (b1 >= 0x81 && b1 <= 0x9F) || (b1 >= 0xE0 && b1 <= 0xFC) {
      if (b2 >= 0x40 && b2 <= 0x7E) || (b2 >= 0x80 && b2 <= 0xFC) {
        sjis_score = sjis_score + 1
        i = i + 2
        continue
      }
    }
    // EUC-JP: lead byte 0xA1-0xFE, trail 0xA1-0xFE
    if b1 >= 0xA1 && b1 <= 0xFE && b2 >= 0xA1 && b2 <= 0xFE {
      euc_score = euc_score + 1
      i = i + 2
      continue
    }
    i = i + 1
  }
  if sjis_score > euc_score && sjis_score > 0 {
    return "shift-jis"
  }
  if euc_score > sjis_score && euc_score > 0 {
    return "euc-jp"
  }
  "utf-8"
}

///|
/// Decode file with optional encoding override
fn decode_file(path : String, override_enc : String) -> String {
  let buf = read_file_buffer(path)
  let encoding = if override_enc.length() > 0 {
    override_enc
  } else {
    detect_encoding(buf)
  }
  if encoding != "utf-8" {
    console_log("Detected encoding: \{encoding}")
  }
  decode_buffer(buf, encoding)
}

///|
fn detect_mode(file_path : String) -> @core.FileMode {
  let ext = path_extname(file_path)
  let ext_lower = if ext.has_prefix(".") {
    @core.safe_slice(ext, 1).to_lower()
  } else {
    ext.to_lower()
  }
  @core.FileMode::from_extension(ext_lower)
}

///|
/// Browser tab title: "<project>/<filename>" so parallel reviews are distinguishable.
///  The project is the nearest ancestor directory containing .git; falls back to
///  the file's parent directory name.
fn compute_tab_title(file_path : String, filename : String) -> String {
  if file_path.length() == 0 || file_path == "<stdin>" {
    return filename
  }
  let mut dir = path_dirname(file_path)
  let mut depth = 0
  while depth < 16 {
    if exists_sync(path_join(dir, ".git")) {
      return path_basename(dir) + "/" + filename
    }
    let parent = path_dirname(dir)
    if parent == dir {
      break
    }
    dir = parent
    depth = depth + 1
  }
  let parent_name = path_basename(path_dirname(file_path))
  if parent_name.length() > 0 && parent_name != "/" {
    parent_name + "/" + filename
  } else {
    filename
  }
}

///|
fn load_and_build_html(ctx : ServerContext) -> String {
  let content = decode_file(ctx.file_path, encoding_override.val)
  let tab_title = compute_tab_title(ctx.file_path, ctx.filename)
  let html = match ctx.mode {
    @core.FileMode::Csv | @core.FileMode::Tsv => {
      let delimiter = if ctx.mode == @core.FileMode::Tsv { '\t' } else { ',' }
      let flat = @core.parse_csv(content, delimiter)
      let data = @core.csv_data_from_flat(flat)
      @core.build_csv_html(
        data,
        ctx.filename,
        ctx.port,
        tab_title~,
        server_instance_id=server_instance_id.val,
        mode=ctx.mode.to_string(),
      )
    }
    @core.FileMode::Diff => {
      let data = @core.parse_diff(content)
      @core.build_diff_html(
        data,
        ctx.filename,
        ctx.port,
        tab_title~,
        server_instance_id=server_instance_id.val,
      )
    }
    @core.FileMode::Markdown => {
      let md = @core.parse_markdown(content)
      @core.build_markdown_html(
        md,
        ctx.filename,
        ctx.port,
        file_path=ctx.file_path,
        tab_title~,
        server_instance_id=server_instance_id.val,
      )
    }
    @core.FileMode::Html => {
      let lines = @core.split_to_lines(content)
      @core.build_text_html(
        lines,
        ctx.filename,
        ctx.port,
        tab_title~,
        server_instance_id=server_instance_id.val,
      )
    }
    @core.FileMode::Text => {
      let lines = @core.split_to_lines(content)
      @core.build_text_html(
        lines,
        ctx.filename,
        ctx.port,
        tab_title~,
        server_instance_id=server_instance_id.val,
      )
    }
  }
  let with_switcher = inject_review_file_switcher(ctx, html)
  if share_mode.val {
    inject_share_readonly_ui(with_switcher)
  } else {
    with_switcher
  }
}

///|
fn inject_share_readonly_ui(html : String) -> String {
  let fragment =
    "<style>.share-readonly-banner{display:block;padding:8px 14px;border-bottom:1px solid var(--border);background:var(--accent-soft);color:var(--accent-strong);font-size:13px;font-weight:700}.share-readonly-banner span{color:var(--muted);font-weight:500;margin-left:8px}.submit-exit-btn,#pill-comments,#comment-card,.comment-list,#submit-modal,#recovery-modal{display:none!important}.has-comment{cursor:default!important}</style><div class=\"share-readonly-banner\">Read-only share<span>Comments and submit actions are disabled.</span></div><script>window.__YUNOMI_SHARE_READONLY__=true;</script>"
  js_inject_before_body_end(html, fragment)
}

///|
fn context_index(ctx : ServerContext) -> Int {
  for i, candidate in active_servers {
    if candidate.file_path == ctx.file_path {
      return i
    }
  }
  0
}

///|
fn inject_review_file_switcher(ctx : ServerContext, html : String) -> String {
  if !review_mux_mode.val || active_servers.length() <= 1 {
    return html
  }
  let active_idx = context_index(ctx)
  let nav = StringBuilder::new()
  nav.write_string("<nav id=\"review-file-switcher\" class=\"review-file-switcher\" aria-label=\"Review files\">")
  for i, candidate in active_servers {
    let cls = if i == active_idx { " class=\"active\"" } else { "" }
    nav.write_string("<a")
    nav.write_string(cls)
    nav.write_string(" href=\"/?f=")
    nav.write_string(i.to_string())
    nav.write_string("\">")
    nav.write_string((i + 1).to_string())
    nav.write_string(". ")
    nav.write_string(@core.escape_html(candidate.filename))
    nav.write_string("</a>")
  }
  nav.write_string("</nav>")
  js_inject_before_body_end(html, nav.to_string())
}

///|
fn start_stdin_server(content : String, port : Int, no_open : Bool) -> Unit {
  let data = @core.parse_diff(content)
  let html = @core.build_diff_html(data, "stdin", port)
  let ctx : ServerContext = {
    file_path: "<stdin>",
    filename: "stdin",
    mode: @core.FileMode::Diff,
    source_text: content,
    port,
    html_cache: html,
    sse_clients: [],
    active_tabs: [],
    active_tab_instances: {},
    pending_close_timer: js_null(),
    finished: false,
    is_loop: loop_mode.val,
    last_index_get_ms: 0.0,
    last_close_signal_ms: 0.0,
    notify_pane: resolve_notify_pane(),
  }
  active_servers.push(ctx)
  expected_count.val = 1
  start_http_server(ctx, no_open)
}

///|
fn start_file_server(file_path : String, port : Int, no_open : Bool) -> Unit {
  let ctx = create_file_context(file_path, port)
  if ctx.mode == @core.FileMode::Html {
    active_servers.push(ctx)
    start_html_preview_server(ctx.file_path, ctx.port, bind_host.val, no_open, server_instance_id.val)
    return
  }
  ctx.html_cache = load_and_build_html(ctx)
  ensure_review_state(ctx.file_path)
  active_servers.push(ctx)
  watch_review_file(ctx)
  start_http_server(ctx, no_open)
}

///|
fn create_file_context(file_path : String, port : Int) -> ServerContext {
  let resolved = path_resolve(file_path)
  {
    file_path: resolved,
    filename: path_basename(resolved),
    mode: detect_mode(resolved),
    source_text: "",
    port,
    html_cache: "",
    sse_clients: [],
    active_tabs: [],
    active_tab_instances: {},
    pending_close_timer: js_null(),
    finished: false,
    is_loop: loop_mode.val,
    last_index_get_ms: 0.0,
    last_close_signal_ms: 0.0,
    notify_pane: resolve_notify_pane(),
  }
}

///|
fn watch_review_file(ctx : ServerContext) -> Unit {
  if ctx.file_path != "<stdin>" {
    let clients = ctx.sse_clients
    ignore(
      watch_file(ctx.file_path, fn(_curr, _prev) {
        ctx.html_cache = load_and_build_html(ctx)
        for client in clients {
          sse_send(client, "reload", "")
        }
      }),
    )
    let signal_path = review_signal_path_for_file(ctx.file_path)
    write_file_secure(signal_path, "")
    ignore(
      watch_file(signal_path, fn(_curr, _prev) {
        handle_go_signal(ctx)
      }),
    )
  }
}

///|
fn refresh_review_mux_html() -> Unit {
  for ctx in active_servers {
    ctx.html_cache = load_and_build_html(ctx)
  }
}

///|
fn watch_share_file(ctx : ServerContext) -> Unit {
  if ctx.file_path != "<stdin>" {
    let clients = ctx.sse_clients
    ignore(
      watch_file(ctx.file_path, fn(_curr, _prev) {
        ctx.html_cache = load_and_build_html(ctx)
        for client in clients {
          sse_send(client, "reload", "")
        }
      }),
    )
  }
}

///|
fn start_share_server(files : Array[String], port : Int, no_open : Bool) -> Unit {
  if files.is_empty() {
    console_error("yunomi share: file path is required")
    print_usage()
    exit_process("share file missing", 1)
  }
  share_mode.val = true
  review_mux_mode.val = files.length() > 1
  expected_count.val = files.length()
  ensure_lock_dir()
  let actual_port = find_available_port(port)
  for file_path in files {
    let ctx = create_file_context(file_path, actual_port)
    active_servers.push(ctx)
  }
  refresh_review_mux_html()
  for ctx in active_servers {
    watch_share_file(ctx)
  }
  start_http_server(active_servers[0], no_open)
}

///|
fn handle_share_command(args : Array[String]) -> Unit {
  let mut port = 4989
  let mut no_open = false
  let files : Array[String] = []
  let mut i = 1
  while i < args.length() {
    let arg = args[i]
    if arg == "--port" {
      i = i + 1
      if i < args.length() {
        port = parse_port(args[i])
      }
    } else if arg == "--no-open" {
      no_open = true
    } else if arg == "--host" {
      i = i + 1
      if i < args.length() {
        bind_host.val = args[i]
      }
    } else if arg == "--encoding" || arg == "-e" {
      i = i + 1
      if i < args.length() {
        encoding_override.val = args[i]
      }
    } else if !arg.has_prefix("-") {
      files.push(arg)
    }
    i = i + 1
  }
  server_instance_id.val = gen_instance_id()
  start_share_server(files, port, no_open)
}

///|
fn start_review_mux_server(files : Array[String], port : Int, no_open : Bool) -> Unit {
  review_mux_mode.val = true
  expected_count.val = files.length()
  ensure_lock_dir()
  let actual_port = find_available_port(port)
  for file_path in files {
    let ctx = create_file_context(file_path, actual_port)
    ensure_review_state(ctx.file_path)
    active_servers.push(ctx)
  }
  refresh_review_mux_html()
  for ctx in active_servers {
    watch_review_file(ctx)
  }
  start_http_server(active_servers[0], no_open)
}

///|
fn handle_go_command(port : Int, no_open : Bool) -> Unit {
  let review_path = review_json_path_for_cwd()
  if !exists_sync(review_path) {
    console_error("yunomi go: no review.json found for this repository branch")
    exit_process("go missing review", 1)
  }
  let server_path = review_server_path_for_cwd()
  if exists_sync(server_path) {
    let server_json = read_file_safe(server_path)
    let pid = json_parse_int_field("pid", server_json)
    if pid > 0 && process_exists(pid) {
      write_file_secure(review_signal_path_for_cwd(), iso_now())
      console_log("yunomi go: notified running review server")
      exit_process("go notified", 0)
    }
  }
  let review_json = read_file_safe(review_path)
  let first_file = json_parse_first_file(review_json)
  if first_file.length() == 0 {
    console_error("yunomi go: review.json has no files")
    exit_process("go missing file", 1)
  }
  let file_path = path_resolve(first_file)
  loop_mode.val = true
  start_next_review_round(file_path)
  expected_count.val = 1
  start_file_server(file_path, port, no_open)
}

///|
fn post_reply_to_server(port : Int, body : String) -> String {
  let script =
    "const http=require('node:http');const port=Number(process.argv[1]);const path=process.argv[2];const body=process.argv[3];const req=http.request({hostname:'127.0.0.1',port,path,method:'POST',headers:{'Content-Type':'application/json','Content-Length':Buffer.byteLength(body)}},res=>{let data='';res.on('data',c=>data+=c);res.on('end',()=>{if(res.statusCode!==200){console.error(data);process.exit(1)}})});req.on('error',e=>{console.error(e.message);process.exit(1)});req.write(body);req.end();"
  spawn_sync_status(process_exec_path(), ["-e", script, port.to_string(), "/reply-comment", body])
}

///|
fn handle_reply_command(id : String, text : String) -> Unit {
  if id.length() == 0 || text.length() == 0 {
    console_error("yunomi reply: usage: yunomi reply <comment-id> '<text>'")
    exit_process("reply usage", 1)
  }
  let body = "{\"id\":" + json_encode_value(id) + ",\"text\":" +
    json_encode_value(text) + ",\"author\":\"agent\"}"
  let review_path = review_json_path_for_cwd()
  if !exists_sync(review_path) {
    console_error("yunomi reply: no review.json found for this repository branch")
    exit_process("reply missing review", 1)
  }
  let server_path = review_server_path_for_cwd()
  if exists_sync(server_path) {
    let server_json = read_file_safe(server_path)
    let pid = json_parse_int_field("pid", server_json)
    let server_port = json_parse_int_field("port", server_json)
    if pid > 0 && server_port > 0 && process_exists(pid) {
      let err = post_reply_to_server(server_port, body)
      if err.length() == 0 {
        console_log("yunomi reply: notified running review server")
        exit_process("reply notified", 0)
      }
      console_error("yunomi reply: server POST failed, writing review.json directly: " + err)
    } else {
      console_error("yunomi reply: server metadata is stale; writing review.json directly")
    }
  } else {
    console_error("yunomi reply: no running server metadata; writing review.json directly")
  }
  reply_review_comment_cwd(id, text, "agent")
  console_log("yunomi reply: wrote review.json")
  exit_process("reply wrote review", 0)
}

///|
fn handle_go_signal(ctx : ServerContext) -> Unit {
  if ctx.file_path == "<stdin>" {
    return
  }
  start_next_review_round(ctx.file_path)
  ctx.finished = false
  ctx.html_cache = load_and_build_html(ctx)
  for client in ctx.sse_clients {
    sse_send(client, "round", review_state_response(ctx.file_path, true))
  }
}

///|
/// History constants
let history_max : Int = 50

///|
/// Get history directory path
fn history_dir() -> String {
  path_join(os_homedir(), ".yunomi/history")
}

///|
/// Ensure history directory exists
fn ensure_history_dir() -> Unit {
  let dir = history_dir()
  if !exists_sync(dir) {
    mkdir_sync(dir, mkdir_recursive_opts())
    chmod_sync(dir, 448) // 0o700
  }
}

///|
/// Get history file path for a given file
fn history_path(file_path : String) -> String {
  let hash = crypto_sha256(path_resolve(file_path))
  path_join(history_dir(), hash + ".json")
}

///|
/// Load history from file
fn load_history(file_path : String) -> String {
  let hp = history_path(file_path)
  if !exists_sync(hp) {
    return "[]"
  }
  let data = read_file_safe(hp)
  if data.length() == 0 {
    "[]"
  } else {
    data
  }
}

///|
/// Save history entry (with trim to history_max)
fn save_history(file_path : String, entry_json : String) -> Unit {
  ensure_history_dir()
  let hp = history_path(file_path)
  let existing = read_file_safe(hp)
  let new_data = if existing.length() > 2 {
    "[" + entry_json + "," + @core.safe_slice(existing, 1)
  } else {
    "[" + entry_json + "]"
  }
  let trimmed = trim_json_array(new_data, history_max)
  write_file_secure(hp, trimmed)
  if exists_sync(hp) {
    chmod_sync(hp, 384) // 0o600
  }
}

///|
/// Trim a JSON array to at most max_entries objects
fn trim_json_array(json : String, max_entries : Int) -> String {
  let chars = json.to_array()
  let len = chars.length()
  let mut depth = 0
  let mut count = 0
  let mut cut_pos = -1
  let mut i = 0
  while i < len {
    match chars[i] {
      '{' => depth = depth + 1
      '}' => {
        depth = depth - 1
        if depth == 0 {
          count = count + 1
          if count == max_entries {
            cut_pos = i + 1
            break
          }
        }
      }
      _ => ()
    }
    i = i + 1
  }
  if cut_pos > 0 && count >= max_entries {
    @core.safe_slice_range(json, 0, cut_pos) + "]"
  } else {
    json
  }
}

///|
/// Find first occurrence of char in string, -1 if not found
fn index_of(s : String, target : Char) -> Int {
  let chars = s.to_array()
  for i, ch in chars {
    if ch == target {
      return i
    }
  }
  -1
}

///|
/// Max port retry attempts
let max_port_attempts : Int = 10

///|
fn start_http_server(ctx : ServerContext, no_open : Bool) -> Unit {
  try_listen(ctx, ctx.port, 0, no_open)
}

///|
fn is_index_url(url : String) -> Bool {
  url == "/" || url == "/index.html" || url.has_prefix("/?") ||
  url.has_prefix("/index.html?")
}

///|
fn selected_context(ctx : ServerContext, url : String) -> ServerContext {
  if !review_mux_mode.val {
    return ctx
  }
  let idx_s = parse_query_param(url, "f")
  if idx_s.length() == 0 {
    return ctx
  }
  let idx = @core.parse_int_safe(idx_s)
  if idx >= 0 && idx < active_servers.length() {
    active_servers[idx]
  } else {
    ctx
  }
}

///|
fn try_listen(
  ctx : ServerContext,
  port : Int,
  attempt : Int,
  no_open : Bool,
) -> Unit {
  if attempt >= max_port_attempts {
    console_error(
      "Failed to find available port after \{max_port_attempts} attempts",
    )
    exit_process("no available port", 1)
  }
  let server = create_server(fn(req, res) { handle_request(ctx, req, res) })
  server_on_error(server, fn(err) {
    if error_code(err) == "EADDRINUSE" {
      console_log("Port \{port} in use, trying \{port + 1}...")
      try_listen(ctx, port + 1, attempt + 1, no_open)
    } else {
      console_error("Server error")
      exit_process("server error", 1)
    }
  })
  let host = bind_host.val
  server_listen(server, port, host, fn() {
    ctx.port = port
    write_lock(port, ctx.file_path)
    if ctx.file_path != "<stdin>" && !share_mode.val {
      write_review_server(ctx.file_path, port, ctx.notify_pane)
    }
    let display_host = if host == "0.0.0.0" { "127.0.0.1" } else { host }
    let url = "http://\{display_host}:\{port}"
    if share_mode.val {
      console_log("yunomi sharing \{ctx.filename} read-only at \{url}")
    } else {
      console_log("yunomi serving \{ctx.filename} at \{url}")
    }
    if !no_open {
      open_browser(url)
    }
  })
  // Heartbeat for SSE
  ignore(
    set_interval(
      fn() {
        for client in ctx.sse_clients {
          sse_send(client, "ping", "")
        }
      },
      25000,
    ),
  )
}

///|
fn handle_request(ctx : ServerContext, req : JsValue, res : JsValue) -> Unit {
  let http_method = req_method(req)
  let url = req_url(req)
  let request_ctx = selected_context(ctx, url)
  if
    (http_method == "GET" || http_method == "HEAD") &&
    is_index_url(url) {
    // The browser is fetching the page document itself — the very first
    // thing a reload does, well before any client JS can run. Recording
    // this lets the close-abandonment timer tell "tab is reloading" apart
    // from "tab genuinely gone" even when the reload's own JS boot (and
    // therefore its /session/open re-registration) is slow to follow.
    request_ctx.last_index_get_ms = now_ms()
  }
  if http_method == "GET" && is_index_url(url) {
    res_write_head(res, 200, "text/html; charset=utf-8")
    res_end(res, request_ctx.html_cache)
  } else if http_method == "GET" && url == "/ui.js" {
    res_set_header(res, "Cache-Control", "no-store, no-cache, must-revalidate")
    res_write_head(res, 200, "application/javascript; charset=utf-8")
    res_end(res, load_ui_js())
  } else if http_method == "GET" && url == "/healthz" {
    res_write_head(res, 200, "application/json")
    res_end(res, "{\"ok\":true}")
  } else if http_method == "GET" && url == "/sse" {
    setup_sse(res)
    ctx.sse_clients.push(res)
    // Announce this server's identity: a tab reconnecting after a
    // restart sees a different id and reloads itself
    sse_send(res, "hello", server_instance_id.val)
    on_close(req, fn() { remove_sse_client(ctx, res) })
  } else if http_method == "GET" && url == "/history" {
    let history_json = load_history(ctx.file_path)
    res_write_head(res, 200, "application/json")
    res_end(res, history_json)
  } else if http_method == "GET" && url == "/review-state" {
    let state_json = if ctx.file_path == "<stdin>" {
      "{\"review\":{\"version\":1,\"branch\":\"stdin\",\"files\":[\"stdin\"],\"rounds\":[],\"comments\":[]},\"diff\":{\"lines\":[]},\"unresolved_count\":0,\"gate_unresolved_count\":0,\"is_loop\":false}"
    } else {
      review_state_response(ctx.file_path, ctx.is_loop)
    }
    res_write_head(res, 200, "application/json")
    res_end(res, state_json)
  } else if http_method == "GET" && url.has_prefix("/video-timeline?") {
    handle_video_timeline(ctx, url, res)
  } else if share_mode.val && http_method == "POST" {
    res_write_head(res, 405, "application/json")
    res_end(res, "{\"ok\":false,\"error\":\"read_only_share\"}")
  } else if http_method == "POST" && url == "/session/open" {
    read_body(req, fn(body) {
      handle_session_open(ctx, body)
      res_write_head(res, 200, "application/json")
      res_end(res, "{\"ok\":true}")
    })
  } else if http_method == "POST" && url == "/close" {
    read_body(req, fn(body) {
      handle_session_close(ctx, body)
      res_write_head(res, 200, "application/json")
      res_end(res, "{\"ok\":true}")
    })
  } else if http_method == "POST" && url == "/comment" {
    read_body(req, fn(body) {
      handle_comment(ctx, body)
      res_write_head(res, 200, "application/json")
      res_end(res, "{\"ok\":true}")
    })
  } else if http_method == "POST" && url == "/go" {
    if ctx.file_path != "<stdin>" {
      handle_go_signal(ctx)
    }
    res_write_head(res, 200, "application/json")
    res_end(res, "{\"ok\":true}")
  } else if http_method == "POST" && url == "/resolve-comment" {
    read_body(req, fn(body) {
      if ctx.file_path != "<stdin>" {
        resolve_review_comment(ctx.file_path, json_parse_string("id", body))
      }
      res_write_head(res, 200, "application/json")
      res_end(res, "{\"ok\":true}")
      if ctx.file_path != "<stdin>" {
        for client in ctx.sse_clients {
          sse_send(client, "round", review_state_response(ctx.file_path, ctx.is_loop))
        }
      }
    })
  } else if http_method == "POST" && url == "/reply-comment" {
    read_body(req, fn(body) {
      let id = json_parse_string("id", body)
      let text = json_parse_string("text", body)
      let author_raw = json_parse_string("author", body)
      let author = if author_raw.length() > 0 { author_raw } else { "agent" }
      if ctx.file_path != "<stdin>" {
        reply_review_comment(
          ctx.file_path,
          id,
          text,
          author,
        )
      }
      res_write_head(res, 200, "application/json")
      res_end(res, "{\"ok\":true}")
      if ctx.file_path != "<stdin>" {
        let round = current_review_round(ctx.file_path)
        let reply_event = "{\"id\":" + json_encode_value(id) + ",\"text\":" +
          json_encode_value(text) + ",\"author\":" + json_encode_value(author) +
          ",\"round\":" + round.to_string() + "}"
        for client in ctx.sse_clients {
          sse_send(client, "reply", reply_event)
          sse_send(client, "round", review_state_response(ctx.file_path, ctx.is_loop))
        }
      }
    })
  } else if http_method == "POST" && url == "/decision" {
    read_body(req, fn(body) {
      handle_decision(ctx, body)
      res_write_head(res, 200, "application/json")
      res_end(res, "{\"ok\":true}")
    })
  } else if http_method == "POST" && url == "/exit" {
    read_body(req, fn(body) {
      if
        ctx.file_path != "<stdin>" &&
        ctx.is_loop &&
        json_parse_string("decision", body) == "approve" &&
        review_prior_unresolved_count(ctx.file_path) > 0 {
        res_write_head(res, 409, "application/json")
        res_end(res, "{\"ok\":false,\"error\":\"unresolved_comments\"}")
        return
      }
      let should_exit = handle_submit(ctx, body)
      res_write_head(res, 200, "application/json")
      // Wait for the response to actually finish sending before killing
      // the process — process.exit() is synchronous/immediate, so calling
      // it before this event would truncate the very response that tells
      // the browser the submit succeeded, leaving its client-side
      // success callback (which hides the Submit Review dialog and closes
      // the tab) never invoked.
      if should_exit {
        // res "finish" fires once Node's http layer considers the response
        // fully written, but that's the JS-visible signal only — the
        // underlying OS socket write can still be in flight a moment
        // longer. A short extra delay after "finish" (instead of exiting
        // synchronously inside the handler) gives the loopback socket time
        // to actually deliver the bytes before the process dies.
        res_on_finish(res, fn() {
          ignore(
            set_timeout(fn() { exit_process("all reviews submitted", 0) }, 30),
          )
        })
      }
      res_end(res, "{\"ok\":true}")
    })
  } else if http_method == "HEAD" {
    // HEAD: same as GET but no body
    if is_index_url(url) {
      res_write_head(res, 200, "text/html; charset=utf-8")
      res_end(res, "")
    } else if url == "/healthz" {
      res_write_head(res, 200, "application/json")
      res_end(res, "")
    } else if url == "/ui.js" {
      res_write_head(res, 200, "application/javascript; charset=utf-8")
      res_end(res, "")
    } else if url == "/history" {
      res_write_head(res, 200, "application/json")
      res_end(res, "")
    } else {
      serve_static_file_head(ctx, url, res)
    }
  } else if http_method == "GET" {
    // Static file serving (images, videos, etc.) relative to file's directory
    serve_static_file(ctx, url, req, res)
  } else {
    res_write_head(res, 404, "text/plain")
    res_end(res, "Not Found")
  }
}

///|
/// MIME type lookup by extension
fn get_mime_type(ext : String) -> String {
  match ext {
    ".png" => "image/png"
    ".jpg" | ".jpeg" => "image/jpeg"
    ".gif" => "image/gif"
    ".webp" => "image/webp"
    ".svg" => "image/svg+xml"
    ".ico" => "image/x-icon"
    ".mp4" => "video/mp4"
    ".webm" => "video/webm"
    ".mov" => "video/quicktime"
    ".avi" => "video/x-msvideo"
    ".mkv" => "video/x-matroska"
    ".m4v" => "video/x-m4v"
    ".ogv" => "video/ogg"
    ".css" => "text/css"
    ".js" => "application/javascript"
    ".json" => "application/json"
    ".pdf" => "application/pdf"
    ".woff" => "font/woff"
    ".woff2" => "font/woff2"
    _ => "application/octet-stream"
  }
}

///|
/// Serve static files relative to the reviewed file's directory
fn serve_static_file(
  ctx : ServerContext,
  url : String,
  req : JsValue,
  res : JsValue,
) -> Unit {
  // Decode URL path (strip query string)
  let url_path = {
    let qmark = index_of(url, '?')
    if qmark >= 0 {
      @core.safe_slice_range(url, 0, qmark)
    } else {
      url
    }
  }
  // Remove leading slash
  let relative_path = if url_path.has_prefix("/") {
    @core.safe_slice(url_path, 1)
  } else {
    url_path
  }
  // Security: prevent path traversal
  if relative_path.contains("..") {
    res_write_head(res, 403, "text/plain")
    res_end(res, "Forbidden")
    return
  }
  // Resolve against file's directory
  let base_dir = path_dirname(ctx.file_path)
  let static_path = path_join(base_dir, relative_path)
  // Ensure resolved path is under base_dir
  let resolved_static = path_resolve(static_path)
  let resolved_base = path_resolve(base_dir)
  if !@core.is_path_under(resolved_base, resolved_static) {
    res_write_head(res, 403, "text/plain")
    res_end(res, "Forbidden")
    return
  }
  if exists_sync(resolved_static) && is_file_sync(resolved_static) {
    let ext = path_extname(resolved_static).to_lower()
    let content_type = get_mime_type(ext)
    // Video files: support Range requests for seeking
    let is_video = content_type.has_prefix("video/")
    let range = req_range_header(req)
    if is_video && range.length() > 0 {
      pipe_file_range(resolved_static, res, content_type, range)
    } else {
      pipe_file_to_response(resolved_static, res, content_type)
    }
  } else {
    res_write_head(res, 404, "text/plain")
    res_end(res, "Not Found")
  }
}

///|
/// Serve static file HEAD request (headers only, no body)
fn serve_static_file_head(
  ctx : ServerContext,
  url : String,
  res : JsValue,
) -> Unit {
  let url_path = {
    let qmark = index_of(url, '?')
    if qmark >= 0 {
      @core.safe_slice_range(url, 0, qmark)
    } else {
      url
    }
  }
  let relative_path = if url_path.has_prefix("/") {
    @core.safe_slice(url_path, 1)
  } else {
    url_path
  }
  if relative_path.contains("..") {
    res_write_head(res, 403, "text/plain")
    res_end(res, "")
    return
  }
  let base_dir = path_dirname(ctx.file_path)
  let static_path = path_join(base_dir, relative_path)
  let resolved_static = path_resolve(static_path)
  let resolved_base = path_resolve(base_dir)
  if !@core.is_path_under(resolved_base, resolved_static) {
    res_write_head(res, 403, "text/plain")
    res_end(res, "")
    return
  }
  if exists_sync(resolved_static) && is_file_sync(resolved_static) {
    let ext = path_extname(resolved_static).to_lower()
    let content_type = get_mime_type(ext)
    let stat = fs_stat_sync(resolved_static)
    let size = js_stat_size(stat)
    res_set_header(res, "Accept-Ranges", "bytes")
    res_write_head_with_headers(res, 200, content_type, size, true)
    res_end(res, "")
  } else {
    res_write_head(res, 404, "text/plain")
    res_end(res, "")
  }
}

///|
/// Remove SSE client by reference equality
extern "js" fn js_ref_eq(a : JsValue, b : JsValue) -> Bool =
  #|(a, b) => a === b

///|
fn remove_sse_client(ctx : ServerContext, client : JsValue) -> Unit {
  let mut idx = -1
  for i, c in ctx.sse_clients {
    if js_ref_eq(c, client) {
      idx = i
      break
    }
  }
  if idx >= 0 && idx < ctx.sse_clients.length() {
    ignore(ctx.sse_clients.remove(idx))
  }
}

///|
fn has_active_tab(ctx : ServerContext, tab_id : String) -> Bool {
  for existing in ctx.active_tabs {
    if existing == tab_id {
      return true
    }
  }
  false
}

///|
fn add_active_tab(ctx : ServerContext, tab_id : String) -> Unit {
  if tab_id.length() == 0 || has_active_tab(ctx, tab_id) {
    return
  }
  ctx.active_tabs.push(tab_id)
}

///|
fn remove_active_tab(ctx : ServerContext, tab_id : String) -> Unit {
  if tab_id.length() == 0 {
    return
  }
  let mut idx = -1
  for i, existing in ctx.active_tabs {
    if existing == tab_id {
      idx = i
      break
    }
  }
  if idx >= 0 && idx < ctx.active_tabs.length() {
    ignore(ctx.active_tabs.remove(idx))
  }
}

///|
fn cancel_pending_close(ctx : ServerContext) -> Unit {
  if !js_is_nullish(ctx.pending_close_timer) {
    clear_timeout(ctx.pending_close_timer)
    ctx.pending_close_timer = js_null()
  }
}

///|
fn write_review_decision(
  file_path : String,
  line : Int,
  text : String,
  checked : Bool,
  now : String,
) -> String {
  let path = review_file_path()
  ensure_parent_dir(path)
  let existing = read_file_safe(path)
  let updated = js_upsert_decision_review_json(
    existing,
    current_branch(),
    file_path,
    line,
    text,
    checked,
    now,
  )
  write_file_sync(path, updated)
  path
}

///|
fn update_task_decision_source(ctx : ServerContext, line : Int, checked : Bool) -> Bool {
  if ctx.file_path == "<stdin>" {
    return false
  }
  let content = decode_file(ctx.file_path, encoding_override.val)
  let updated = js_replace_task_checkbox_line(content, line, checked)
  if updated.length() == 0 {
    return false
  }
  write_file_sync(ctx.file_path, updated)
  ctx.html_cache = load_and_build_html(ctx)
  true
}

///|
fn decision_url(ctx : ServerContext) -> String {
  "http://127.0.0.1:\{ctx.port}"
}

///|
fn notify_decision(ctx : ServerContext, line : Int, text : String, checked : Bool) -> Unit {
  let msg = "[yunomi] decision \{ctx.filename}:\{line} checked=\{checked.to_string()} " +
    json_encode_value(text) + " url=" + decision_url(ctx)
  let custom_cmd = get_env_var("YUNOMI_NOTIFY_CMD")
  if custom_cmd.length() > 0 {
    let command = replace_notify_placeholder(custom_cmd, msg)
    let result = spawn_sync_shell_status(command)
    if result.0 != 0 {
      let detail = js_trim_string(result.1)
      let reason = if detail.length() > 0 { detail } else { "exit " + result.0.to_string() }
      console_error("yunomi decision: notify command failed: " + reason)
    }
    return
  }
  if notify_pane_id.val.length() == 0 {
    return
  }
  let herdr = resolve_command("herdr")
  if herdr.length() == 0 {
    console_error("yunomi decision: notify failed: herdr command not found")
    return
  }
  let result = spawn_sync_status_args(herdr, ["agent", "send", notify_pane_id.val, msg])
  if result.0 != 0 {
    let detail = js_trim_string(result.1)
    let reason = if detail.length() > 0 { detail } else { "exit " + result.0.to_string() }
    console_error(
      "yunomi decision: notify failed for pane " + notify_pane_id.val + ": " + reason,
    )
  }
}

///|
fn handle_decision(ctx : ServerContext, body : String) -> Unit {
  if ctx.finished {
    return
  }
  let line = @core.parse_int_safe(json_parse_string("line", body))
  if line <= 0 {
    console_error("yunomi decision: invalid line")
    return
  }
  let text = json_parse_string("text", body)
  let checked = json_parse_string("checked", body) == "true"
  let timestamp = iso_now()
  let source_updated = update_task_decision_source(ctx, line, checked)
  ignore(write_review_decision(ctx.file_path, line, text, checked, timestamp))
  let event = "{\"type\":\"decision\",\"file\":" + json_encode_value(ctx.filename) +
    ",\"line\":\{line},\"text\":" + json_encode_value(text) + ",\"checked\":" +
    checked.to_string() + ",\"decided_at\":" + json_encode_value(timestamp) + "}"
  append_live_log(event)
  for client in ctx.sse_clients {
    sse_send(client, "decision", event)
    if source_updated {
      sse_send(client, "reload", "")
    }
  }
  notify_decision(ctx, line, text, checked)
}

///|
/// Handle real-time comment from browser
fn handle_comment(ctx : ServerContext, body : String) -> Unit {
  if ctx.finished {
    return
  }
  let event_type = json_parse_string("type", body)
  // The questions stepper posts here too (app.mbt's
  // send_answer_event_to_server) instead of a dedicated endpoint — it's the
  // same real-time IPC channel comments already use, just a different
  // JSONL shape so an agent tailing the live log can tell "answer" events
  // apart from "comment" events without guessing from field presence.
  if event_type == "answer" {
    handle_answer_event(ctx, body)
    return
  }
  // Build JSONL entry: {timestamp, file, type, ...comment_data}
  let timestamp = iso_now()
  let buf = StringBuilder::new()
  buf.write_string("{\"timestamp\":\"")
  buf.write_string(@core.escape_js_string(timestamp))
  buf.write_string("\",\"file\":\"")
  buf.write_string(@core.escape_js_string(ctx.filename))
  buf.write_string("\",\"type\":\"")
  buf.write_string(
    @core.escape_js_string(
      if event_type.length() > 0 {
        event_type
      } else {
        "comment"
      },
    ),
  )
  buf.write_string("\"")
  let key = json_parse_string("key", body)
  if key.length() > 0 {
    buf.write_string(",\"key\":")
    buf.write_string(json_encode_value(key))
  }
  let row = json_parse_string("row", body)
  buf.write_string(",\"row\":")
  buf.write_string(if row.length() > 0 { row } else { "0" })
  let col = json_parse_string("col", body)
  buf.write_string(",\"col\":")
  buf.write_string(if col.length() > 0 { col } else { "0" })
  let text = json_parse_string("text", body)
  if text.length() > 0 {
    buf.write_string(",\"text\":")
    buf.write_string(json_encode_value(text))
  }
  let has_image = json_parse_string("hasImage", body)
  if has_image == "true" {
    buf.write_string(",\"hasImage\":true")
  }
  buf.write_string("}")
  append_live_log(buf.to_string())
  if text.length() > 0 && event_type == "send-now" && ctx.file_path != "<stdin>" {
    let line = json_parse_int_field("row", body) + 1
    let id = if key.length() > 0 { key } else { "draft" }
    update_review_on_send_now(ctx.file_path, id, line, text)
  }
  if text.length() > 0 && event_type != "delete" {
    let line = json_parse_int_field("row", body) + 1
    let round = if ctx.file_path == "<stdin>" { 1 } else { current_review_round(ctx.file_path) }
    let id = if key.length() > 0 { key } else { "draft" }
    let label = if event_type == "send-now" { "send-now" } else { "comment" }
    notify_reviewer(
      ctx,
      "[yunomi] " + label + " " + ctx.filename + ":" + line.to_string() +
      " id=" + id + " round=" + round.to_string() + " " +
      json_encode_value(text) + " url=" + review_url(ctx),
    )
  }
  // Notify SSE clients about the comment event
  for client in ctx.sse_clients {
    sse_send(client, if event_type == "send-now" { "send-now" } else { "comment" }, buf.to_string())
  }
}

///|
/// Handle a single frontmatter-question answer, fired the instant the
/// human clicks "Next"/"Complete" on the questions stepper — well before
/// the eventual /exit submit. Appended to the same live log file as
/// comments (see init_live_log) so an AI agent tailing that JSONL sees each
/// answer in real time instead of only finding out at the very end of the
/// review, which was the whole point of the redesign: "回答書いた後すぐに
/// あなたに伝わってほしい".
fn handle_answer_event(ctx : ServerContext, body : String) -> Unit {
  let id = json_parse_string("id", body)
  let question = json_parse_string("question", body)
  let answer = json_parse_string("answer", body)
  let buf = StringBuilder::new()
  buf.write_string("{\"type\":\"answer\",\"id\":")
  buf.write_string(json_encode_value(id))
  buf.write_string(",\"question\":")
  buf.write_string(json_encode_value(question))
  buf.write_string(",\"answer\":")
  buf.write_string(json_encode_value(answer))
  buf.write_string(",\"file\":")
  buf.write_string(json_encode_value(ctx.filename))
  buf.write_string(",\"ts\":")
  buf.write_string(json_encode_value(iso_now()))
  buf.write_string("}")
  append_live_log(buf.to_string())
  for client in ctx.sse_clients {
    sse_send(client, "answer", buf.to_string())
  }
}

///|
/// Returns true when this submission completed the review (all expected
/// files reported in) and the process should exit — the caller decides
/// WHEN to actually call exit_process(): the /exit HTTP route defers it
/// until the response has finished sending (see handle_request), while the
/// abandonment-timer path (arm_close_timer) has no response to wait for and
/// exits immediately.
fn handle_submit(ctx : ServerContext, body : String) -> Bool {
  if ctx.finished {
    log_session_event("ignored submit for finished context file=\{ctx.filename}")
    return false
  }
  cancel_pending_close(ctx)
  let summary = json_parse_string("summary", body)
  // Parse comments from JSON body
  let raw_comments = json_parse_comments(body)
  let comments : Array[@core.Comment] = []
  let output_dir = path_join(os_homedir(), ".yunomi/outputs")
  // Save summary images
  let images = json_parse_images(body)
  for i, img in images {
    if img.length() > 0 {
      ignore(base64_to_file(img, output_dir, i))
    }
  }
  let comment_image_paths : Array[String] = []
  let mut comment_img_idx = images.length()
  for c in raw_comments {
    if c.length() >= 5 && c[4].length() > 0 {
      comment_image_paths.push(base64_to_file(c[4], output_dir, comment_img_idx))
      comment_img_idx = comment_img_idx + 1
    } else {
      comment_image_paths.push("")
    }
  }
  // Source lines for quoting: agents consuming the verdict YAML only get a
  // row number otherwise, and resolving it against the file themselves is
  // error-prone (the documented schema promises `value: the line content`).
  let source_lines : Array[String] = if raw_comments.length() > 0 {
    if ctx.file_path == "<stdin>" {
      @core.split_to_lines(ctx.source_text)
    } else {
      @core.split_to_lines(decode_file(ctx.file_path, encoding_override.val))
    }
  } else {
    []
  }
  for i, c in raw_comments {
    if c.length() >= 3 {
      let row = @core.parse_int_safe(c[0])
      let sent_value = if c.length() > 3 { c[3] } else { "" }
      let before = if row > 0 && row - 1 < source_lines.length() {
        source_lines[row - 1]
      } else {
        ""
      }
      let after = if row + 1 < source_lines.length() {
        source_lines[row + 1]
      } else {
        ""
      }
      comments.push({
        row,
        col: @core.parse_int_safe(c[1]),
        text: c[2],
        value: if sent_value.length() > 0 {
          sent_value
        } else {
          @core.quote_source_line(source_lines, row)
        },
        context_before: before,
        context_after: after,
        image_path: if i < comment_image_paths.length() { comment_image_paths[i] } else { "" },
      })
    }
  }
  let current_round = if ctx.file_path != "<stdin>" {
    current_review_round(ctx.file_path)
  } else {
    1
  }
  let answers = json_parse_json_field("yunomiAnswers", body)
  let raw_merr = json_parse_mermaid_errors(body)
  let mermaid_errors : Array[@core.MermaidError] = []
  for me in raw_merr {
    if me.length() >= 2 {
      mermaid_errors.push({ line: @core.parse_int_safe(me[0]), message: me[1] })
    }
  }
  let decision_str = json_parse_string("decision", body)
  let decision = @core.ReviewDecision::from_string(decision_str)
  let action_str = json_parse_string("action", body)
  let action = @core.ReviewAction::from_string(action_str)
  log_session_event(
    "submit file=\{ctx.filename} comments=\{raw_comments.length()} summary_len=\{summary.length()} decision=\{decision_str} action=\{action_str}",
  )
  let result : @core.ReviewResult = {
    file: ctx.filename,
    mode: ctx.mode,
    comments,
    summary,
    answers,
    mermaid_errors,
    decision,
    action,
  }
  all_results.push(result)
  if ctx.file_path != "<stdin>" {
    update_review_on_submit(
      ctx.file_path,
      json_with_comment_image_paths(body, comment_image_paths),
      source_lines,
      current_round,
    )
  }
  // Save to history (including decision-only submits)
  if comments.length() > 0 || summary.length() > 0 || decision is Some(_) {
    let entry_buf = StringBuilder::new()
    entry_buf.write_string("{\"timestamp\":\"")
    entry_buf.write_string(iso_now())
    entry_buf.write_string("\",\"file\":\"")
    entry_buf.write_string(@core.escape_js_string(ctx.filename))
    entry_buf.write_string("\",\"summary\":\"")
    entry_buf.write_string(@core.escape_js_string(summary))
    entry_buf.write_string("\",\"commentCount\":")
    entry_buf.write_string(comments.length().to_string())
    entry_buf.write_string("}")
    save_history(ctx.file_path, entry_buf.to_string())
  }
  console_log(
    "Received review for \{ctx.filename} (\{comments.length()} comments)",
  )
  notify_reviewer(
    ctx,
    verdict_notify_message(ctx, decision_str, action_str, comments.length()),
  )
  let loop_waiting = ctx.is_loop && decision_str == "request_changes"
  if loop_waiting {
    let yaml = @core.reviews_to_yaml(all_results)
    process_stdout_write(yaml)
    all_results.clear()
    console_log("yunomi loop waiting for next round; run `yunomi go` after fixes")
    false
  } else if all_results.length() >= expected_count.val {
    ctx.finished = true
    let yaml = @core.reviews_to_yaml(all_results)
    process_stdout_write(yaml)
    cleanup_live_log()
    for srv in active_servers {
      if srv.file_path != "<stdin>" {
        unwatch_file(srv.file_path)
      }
      remove_lock(srv.port)
    }
    true
  } else {
    false
  }
}

///|
fn handle_session_open(ctx : ServerContext, body : String) -> Unit {
  if ctx.finished {
    log_session_event("ignored open for finished context file=\{ctx.filename}")
    return
  }
  let tab_id = json_parse_string("tabId", body)
  let instance_id = json_parse_string("instanceId", body)
  if tab_id.length() == 0 || instance_id.length() == 0 {
    log_session_event("ignored open missing id file=\{ctx.filename}")
    return
  }
  cancel_pending_close(ctx)
  add_active_tab(ctx, tab_id)
  ctx.active_tab_instances.set(tab_id, instance_id)
  log_session_event(
    "open file=\{ctx.filename} tab=\{tab_id} instance=\{instance_id} active=\{ctx.active_tabs.length()}",
  )
}

///|
/// Base wait before an abandoned tab's draft is auto-submitted.
let close_submit_delay_ms : Int = 5000

///|
/// If a close is closely correlated in time with a fresh index-page GET
/// (see `looks_like_reload_in_flight`), the browser is almost certainly
/// reloading rather than truly abandoning the review — but its JS may still
/// be booting (WASM parse/exec, slow network, contention) and hasn't
/// reached /session/open yet. Grant exactly one extension so the
/// re-registration has real breathing room, instead of confirming a
/// mid-typing snapshot just because a fixed timeout elapsed.
///
/// task #19 initially tried raising this to a bounded multi-extension
/// budget, on the theory that a burst of legitimate reloads (a busy
/// multi-agent session editing the same reviewed file twice in a row) would
/// exhaust a single extension. That theory didn't survive contact with
/// schedule_close_submit(): every NEW /close signal already cancels
/// whatever close-timer was pending and re-arms a completely fresh one
/// (see its call `arm_close_timer(ctx, draft_body, close_submit_delay_ms,
/// false)` — extension state always starts over at each genuinely new
/// close event), so back-to-back reload cycles were never actually
/// bottlenecked by "one extension per timer". Worse, looks_like_reload_in_
/// flight() compares two FIXED timestamps that don't change between
/// retries of the SAME timer — once true, it stays true on every
/// subsequent check regardless of whether any new reload activity
/// happened, so a bounded-but-plural budget just always burned through
/// every available extension whenever the first check happened to
/// correlate (confirmed by smoke.ts's close-flush test going from a
/// reliable ~5-10s to occasionally exceeding its 12s budget). One extension
/// is the right number here; the actual fix for symptom #3 (mid-typing
/// answer getting finalized) is the seamless-restore + auto-close-
/// suppression pair in app.mbt (check_recovery()/update_questions_badge()).
let close_submit_extension_ms : Int = 5000

///|
/// Window (ms) used to correlate a close signal with a nearby index-page
/// GET, in EITHER order: the reload's GET / and the closing tab's /close
/// beacon are two independent requests fired around the same navigation
/// instant, so which one the network delivers first is not guaranteed.
let reload_correlation_window_ms : Double = 3000.0

///|
/// True when the most recent index-page GET happened close enough to the
/// most recent close signal that it's overwhelmingly likely to be the same
/// reload event (as opposed to an old page load from a session that was
/// simply open for a while before really being abandoned).
fn looks_like_reload_in_flight(ctx : ServerContext) -> Bool {
  is_within_correlation_window(
    ctx.last_index_get_ms,
    ctx.last_close_signal_ms,
    reload_correlation_window_ms,
  )
}

///|
/// Pure symmetric-window comparison, extracted out of
/// `looks_like_reload_in_flight` so it can be unit-tested without
/// constructing a full `ServerContext`. True when `a` and `b` are within
/// `window_ms` of each other in EITHER direction (the index-GET and the
/// close-signal timestamps can arrive in any order — see the doc comment
/// on `reload_correlation_window_ms`).
pub fn is_within_correlation_window(
  a : Double,
  b : Double,
  window_ms : Double,
) -> Bool {
  (a - b).abs() <= window_ms
}

///|
fn arm_close_timer(
  ctx : ServerContext,
  draft_body : String,
  delay_ms : Int,
  already_extended : Bool,
) -> Unit {
  ctx.pending_close_timer = set_timeout(
    fn() {
      ctx.pending_close_timer = js_null()
      if ctx.finished || !ctx.active_tabs.is_empty() {
        log_session_event(
          "cancel close submit file=\{ctx.filename} finished=\{ctx.finished} active=\{ctx.active_tabs.length()}",
        )
        return
      }
      if !already_extended && looks_like_reload_in_flight(ctx) {
        log_session_event(
          "deferring close submit (reload signal detected) file=\{ctx.filename}",
        )
        arm_close_timer(ctx, draft_body, close_submit_extension_ms, true)
        return
      }
      log_session_event("auto submit after last tab close file=\{ctx.filename}")
      // No HTTP response is in flight for this path (it's the
      // abandonment-timer safety net, not a live /exit request), so exit
      // immediately when the review is complete — no response-flush to
      // wait for, unlike the /exit route in handle_request.
      if handle_submit(ctx, draft_body) {
        exit_process("all reviews submitted", 0)
      }
    },
    delay_ms,
  )
}

///|
fn schedule_close_submit(ctx : ServerContext, draft : String) -> Unit {
  if ctx.finished {
    log_session_event("ignored close scheduling for finished context file=\{ctx.filename}")
    return
  }
  cancel_pending_close(ctx)
  // Strip decision/action from close drafts — these should only come from explicit submit
  let draft_body = if draft.length() > 0 {
    json_strip_decision(draft)
  } else {
    "{\"summary\":\"\",\"comments\":[]}"
  }
  arm_close_timer(ctx, draft_body, close_submit_delay_ms, false)
  log_session_event("scheduled close submit file=\{ctx.filename}")
}

///|
fn handle_session_close(ctx : ServerContext, body : String) -> Unit {
  if ctx.finished {
    log_session_event("ignored close for finished context file=\{ctx.filename}")
    return
  }
  let tab_id = json_parse_string("tabId", body)
  let instance_id = json_parse_string("instanceId", body)
  let draft = json_parse_string("draft", body)
  if tab_id.length() == 0 || instance_id.length() == 0 {
    log_session_event("ignored close missing id file=\{ctx.filename}")
    return
  }
  match ctx.active_tab_instances.get(tab_id) {
    Some(active_instance) =>
      if active_instance != instance_id {
        log_session_event(
          "ignored stale close file=\{ctx.filename} tab=\{tab_id} active_instance=\{active_instance} close_instance=\{instance_id}",
        )
        return
      }
    None => {
      log_session_event(
        "ignored unknown close file=\{ctx.filename} tab=\{tab_id} instance=\{instance_id}",
      )
      return
    }
  }
  ignore(ctx.active_tab_instances.remove(tab_id))
  remove_active_tab(ctx, tab_id)
  log_session_event(
    "close file=\{ctx.filename} tab=\{tab_id} instance=\{instance_id} active=\{ctx.active_tabs.length()} draft_len=\{draft.length()}",
  )
  if ctx.active_tabs.is_empty() {
    ctx.last_close_signal_ms = now_ms()
    schedule_close_submit(ctx, draft)
  }
}

///|
/// Handle video timeline SSE endpoint
fn handle_video_timeline(
  ctx : ServerContext,
  url : String,
  res : JsValue,
) -> Unit {
  let video_path = parse_query_param(url, "path")
  let scene_str = parse_query_param(url, "scene")
  // Security: prevent path traversal
  if video_path.contains("..") {
    res_write_head(res, 400, "text/plain")
    res_end(res, "Invalid path")
    return
  }
  // Security: resolve and constrain to base_dir (same as serve_static_file)
  let base_dir = path_dirname(ctx.file_path)
  let resolved_video = path_resolve(path_join(base_dir, video_path))
  let resolved_base = path_resolve(base_dir)
  if !@core.is_path_under(resolved_base, resolved_video) {
    res_write_head(res, 403, "text/plain")
    res_end(res, "Forbidden")
    return
  }
  // Use resolved path from here
  let video_path = resolved_video
  if !exists_sync(video_path) {
    res_write_head(res, 404, "text/plain")
    res_end(res, "File not found")
    return
  }
  let ffmpeg = resolve_command("ffmpeg")
  if ffmpeg.length() == 0 {
    res_write_head(res, 500, "text/plain")
    res_end(res, "ffmpeg not available")
    return
  }
  // Setup SSE response
  setup_sse(res)
  let tmp_dir = make_temp_dir()
  // Extract first frame
  let first_frame = path_join(tmp_dir, "first_frame.jpg")
  ignore(
    spawn_sync_stdout(
      ffmpeg,
      "[\"-y\", \"-i\", " +
      json_encode_value(video_path) +
      ", \"-vf\", \"scale=160:-1\", \"-vframes\", \"1\", \"-q:v\", \"5\", " +
      json_encode_value(first_frame) +
      "]",
    ),
  )
  // Send first frame
  if exists_sync(first_frame) {
    let b64 = read_file_base64(first_frame)
    if b64.length() > 0 {
      sse_send(
        res,
        "message",
        "{\"type\":\"thumbnail\",\"time\":0,\"index\":0,\"data\":\"data:image/jpeg;base64," +
        b64 +
        "\"}",
      )
    }
  }
  // Scene detection with ffmpeg
  let scene_threshold = if scene_str.length() > 0 { scene_str } else { "0.01" }
  let ffmpeg_proc = spawn_async(
    ffmpeg,
    "[\"-i\", " +
    json_encode_value(video_path) +
    ", \"-vf\", \"select='gt(scene," +
    scene_threshold +
    ")',showinfo,scale=160:-1\", \"-vsync\", \"vfr\", \"-q:v\", \"5\", " +
    json_encode_value(path_join(tmp_dir, "scene_%04d.jpg")) +
    "]",
  )
  on_spawn_close_with_stderr(ffmpeg_proc, fn(_code, stderr) {
    // Parse actual timestamps from ffmpeg showinfo output
    let timestamps = parse_showinfo_timestamps(stderr)
    // Read and sort scene files to ensure correct order
    let files = readdir_sync(tmp_dir)
    let scene_files : Array[String] = []
    for file in files {
      if file.has_prefix("scene_") && file.has_suffix(".jpg") {
        scene_files.push(file)
      }
    }
    let sorted_files = sort_strings(scene_files)
    // Send scene thumbnails with correct timestamps
    let mut scene_idx = 0
    for file in sorted_files {
      let fpath = path_join(tmp_dir, file)
      let b64 = read_file_base64(fpath)
      if b64.length() > 0 {
        // Use actual timestamp from showinfo if available, otherwise estimate
        let time_val = if scene_idx < timestamps.length() {
          timestamps[scene_idx]
        } else {
          (scene_idx + 1).to_double()
        }
        sse_send(
          res,
          "message",
          "{\"type\":\"thumbnail\",\"time\":" +
          time_val.to_string() +
          ",\"index\":" +
          (scene_idx + 1).to_string() +
          ",\"data\":\"data:image/jpeg;base64," +
          b64 +
          "\"}",
        )
        scene_idx = scene_idx + 1
      }
    }
    // Send completion
    sse_send(
      res,
      "message",
      "{\"type\":\"complete\",\"total\":" + scene_idx.to_string() + "}",
    )
    res_end(res, "")
    // Cleanup
    rm_dir_recursive(tmp_dir)
  })
  on_spawn_error(ffmpeg_proc, fn() {
    sse_send(res, "message", "{\"type\":\"complete\",\"total\":1}")
    res_end(res, "")
    rm_dir_recursive(tmp_dir)
  })
}
