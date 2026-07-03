///|
/// External reference type for opaque JS objects
#external
pub type JsValue

///|
/// Node.js fs module
#module("node:fs")
extern "js" fn read_file_sync(path : String, encoding : String) -> String = "readFileSync"

///|
#module("node:fs")
extern "js" fn write_file_sync(path : String, data : String) -> Unit = "writeFileSync"

///|
#module("node:fs")
extern "js" fn exists_sync(path : String) -> Bool = "existsSync"

///|
#module("node:fs")
extern "js" fn mkdir_sync(path : String, options : JsValue) -> Unit = "mkdirSync"

///|
#module("node:fs")
extern "js" fn fs_append_file_sync(path : String, data : String) -> Unit = "appendFileSync"

///|
#module("node:fs")
extern "js" fn unwatch_file(path : String) -> Unit = "unwatchFile"

///|
#module("node:fs")
extern "js" fn unlink_sync(path : String) -> Unit = "unlinkSync"

///|
/// watchFile - import via #module
#module("node:fs")
extern "js" fn watch_file(
  path : String,
  callback : (JsValue, JsValue) -> Unit,
) -> JsValue = "watchFile"

///|
/// Node.js path module
#module("node:path")
extern "js" fn path_basename(path : String) -> String = "basename"

///|
#module("node:path")
extern "js" fn path_extname(path : String) -> String = "extname"

///|
#module("node:path")
extern "js" fn path_join(a : String, b : String) -> String = "join"

///|
#module("node:path")
extern "js" fn path_resolve(path : String) -> String = "resolve"

///|
/// Node.js process
extern "js" fn get_argv() -> Array[String] =
  #|() => process.argv

///|
extern "js" fn process_exit(code : Int) -> Unit =
  #|(code) => process.exit(code)

///|
extern "js" fn process_pid() -> Int =
  #|() => process.pid

///|
/// Check if a process with given PID exists
extern "js" fn process_exists(pid : Int) -> Bool =
  #|(pid) => { try { process.kill(pid, 0); return true; } catch(e) { return false; } }

///|
extern "js" fn process_stdout_write(data : String) -> Unit =
  #|(data) => process.stdout.write(data)

///|
extern "js" fn js_null() -> JsValue =
  #|() => null

///|
extern "js" fn js_is_nullish(value : JsValue) -> Bool =
  #|(value) => value == null

///| readFileSync by file descriptor (avoids reopening /dev/stdin, which

///|
/// fails with EACCES when stdin is a spawned pipe on macOS)
#module("node:fs")
extern "js" fn fs_read_file_sync_fd(fd : Int, enc : String) -> String = "readFileSync"

///|
/// Guarded fd-0 read: closed/empty pipes read as "" instead of throwing
extern "js" fn js_read_fd_guarded(read_fn : (Int, String) -> String) -> String =
  #|(f) => { try { return f(0, "utf-8"); } catch (e) { return ""; } }

///|
/// Read all of stdin synchronously (fd 0)
fn read_stdin_sync() -> String {
  js_read_fd_guarded(fn(fd, enc) { fs_read_file_sync_fd(fd, enc) })
}

///|
extern "js" fn is_stdin_tty() -> Bool =
  #|() => process.stdin.isTTY || false

///| Unique-enough id for this server process, sent as SSE "hello" so

///|
/// lingering tabs can detect a new server on a reused port and reload
extern "js" fn gen_instance_id() -> String =
  #|() => Date.now().toString(36) + "-" + process.pid + "-" + Math.random().toString(36).slice(2, 8)

///|
/// Node.js http module - import createServer via #module
#module("node:http")
extern "js" fn http_create_server_raw(
  handler : (JsValue, JsValue) -> Unit,
) -> JsValue = "createServer"

///|
fn create_server(handler : (JsValue, JsValue) -> Unit) -> JsValue {
  http_create_server_raw(handler)
}

///|
extern "js" fn server_listen(
  server : JsValue,
  port : Int,
  host : String,
  callback : () -> Unit,
) -> Unit =
  #|(server, port, host, cb) => server.listen(port, host, cb)

///|
/// HTTP request helpers
extern "js" fn req_method(req : JsValue) -> String =
  #|(req) => req.method

///|
extern "js" fn req_url(req : JsValue) -> String =
  #|(req) => req.url

///|
/// Reads the raw request body as a byte-accurate UTF-8 string.
/// `body += chunk` (string-concatenating a Buffer) decodes each TCP chunk
/// independently with Buffer#toString('utf8'); when a multi-byte UTF-8
/// character (e.g. Japanese text) straddles a chunk boundary, each half
/// decodes to U+FFFD on its own, corrupting or truncating the payload.
/// Collecting raw Buffers and decoding once via Buffer.concat() after all
/// chunks have arrived is byte-safe regardless of how the OS/network
/// fragments the request.
extern "js" fn read_body(req : JsValue, callback : (String) -> Unit) -> Unit =
  #|(req, cb) => {
  #|  const chunks = [];
  #|  req.on("data", (chunk) => { chunks.push(chunk); });
  #|  req.on("end", () => cb(Buffer.concat(chunks).toString("utf8")));
  #|}

///|
/// HTTP response helpers
extern "js" fn res_write_head(
  res : JsValue,
  status : Int,
  content_type : String,
) -> Unit =
  #|(res, status, ct) => res.writeHead(status, {"Content-Type": ct})

///|
extern "js" fn res_end(res : JsValue, data : String) -> Unit =
  #|(res, data) => res.end(data)

///|
/// Fires once the HTTP response has been fully handed off to the socket —
/// the correct signal to wait on before exiting the process after a final
/// submit, instead of guessing a fixed delay (see handle_submit/handle_
/// request in main.mbt for why: process.exit() before this fires truncates
/// the in-flight response, which the browser observes as
/// net::ERR_EMPTY_RESPONSE / net::ERR_INCOMPLETE_CHUNKED_ENCODING).
extern "js" fn res_on_finish(res : JsValue, callback : () -> Unit) -> Unit =
  #|(res, cb) => res.on("finish", cb)

///|
/// SSE helpers
extern "js" fn setup_sse(res : JsValue) -> Unit =
  #|(res) => {
  #|  res.writeHead(200, {
  #|    "Content-Type": "text/event-stream",
  #|    "Cache-Control": "no-cache",
  #|    "Connection": "keep-alive",
  #|    "Access-Control-Allow-Origin": "*"
  #|  });
  #|  res.write("retry: 3000\n\n");
  #|}

///|
extern "js" fn sse_send(res : JsValue, event : String, data : String) -> Unit =
  #|(res, event, data) => res.write(`event: ${event}\ndata: ${data}\n\n`)

///|
extern "js" fn on_close(obj : JsValue, callback : () -> Unit) -> Unit =
  #|(obj, cb) => obj.on("close", cb)

///|
/// Timer
extern "js" fn set_interval(callback : () -> Unit, ms : Int) -> JsValue =
  #|(cb, ms) => setInterval(cb, ms)

///|
extern "js" fn set_timeout(callback : () -> Unit, ms : Int) -> JsValue =
  #|(cb, ms) => setTimeout(cb, ms)

///|
extern "js" fn clear_timeout(timer : JsValue) -> Unit =
  #|(timer) => { if (timer != null) clearTimeout(timer); }

///|
/// Open browser - import exec via #module
#module("node:child_process")
extern "js" fn _child_exec(cmd : String) -> Unit = "exec"

///| Safe exec using spawn (no shell expansion, no inline require)

///|
/// Uses dynamic import() which works in ESM context
extern "js" fn child_spawn_detached(cmd : String, args : Array[String]) -> Unit =
  #|(cmd, args) => {
  #|  import("node:child_process").then(m => {
  #|    const c = m.spawn(cmd, Array.from(args), { detached: true, stdio: 'ignore' });
  #|    if (c.unref) c.unref();
  #|  });
  #|}

///|
fn child_exec_file(cmd : String, args : Array[String]) -> Unit {
  child_spawn_detached(cmd, args)
}

///|
fn open_browser(url : String) -> Unit {
  let platform = get_platform()
  if platform == "darwin" {
    child_exec_file("open", [url])
  } else if platform == "win32" {
    child_exec_file("cmd", ["/c", "start", url])
  } else {
    child_exec_file("xdg-open", [url])
  }
}

///|
/// JSON string encoding helper
fn json_encode_value(s : String) -> String {
  let buf = StringBuilder::new()
  buf.write_char('"')
  let chars = s.to_array()
  for ch in chars {
    match ch {
      '\\' => buf.write_string("\\\\")
      '"' => buf.write_string("\\\"")
      '\n' => buf.write_string("\\n")
      '\r' => buf.write_string("\\r")
      '\t' => buf.write_string("\\t")
      _ => buf.write_char(ch)
    }
  }
  buf.write_char('"')
  buf.to_string()
}

extern "js" fn get_platform() -> String =
  #|() => process.platform

///|
/// Console
extern "js" fn console_log(msg : String) -> Unit =
  #|(msg) => console.log(msg)

///|
extern "js" fn console_error(msg : String) -> Unit =
  #|(msg) => console.error(msg)

///|
/// JSON
extern "js" fn json_parse_string(key : String, json_str : String) -> String =
  #|(key, s) => { try { const v = JSON.parse(s)[key]; return v == null ? "" : String(v); } catch(e) { return ""; } }

///|
/// JSON field that may hold an object/array: re-serialize instead of String() coercion
extern "js" fn json_parse_json_field(key : String, json_str : String) -> String =
  #|(key, s) => { try { const v = JSON.parse(s)[key]; if (v == null) return ""; return typeof v === "string" ? v : JSON.stringify(v); } catch(e) { return ""; } }

///|
/// Strip decision and action fields from JSON string (safety net for close-triggered submits)
extern "js" fn json_strip_decision(json_str : String) -> String =
  #|(s) => { try { const o = JSON.parse(s); delete o.decision; delete o.action; return JSON.stringify(o); } catch(e) { return s; } }

///|
/// Create options object for mkdirSync recursive
extern "js" fn mkdir_recursive_opts() -> JsValue =
  #|() => ({ recursive: true })

///|
/// Get the directory of the current script (ESM compatible)
extern "js" fn get_script_dir() -> String =
  #|() => {
  #|  const url = new URL(import.meta.url);
  #|  const path = decodeURIComponent(url.pathname);
  #|  return path.substring(0, path.lastIndexOf("/"));
  #|}

///|
/// Server error handler
extern "js" fn server_on_error(
  server : JsValue,
  callback : (JsValue) -> Unit,
) -> Unit =
  #|(server, cb) => server.on("error", cb)

///|
/// Get error code from error object
extern "js" fn error_code(err : JsValue) -> String =
  #|(err) => err.code || ""

///|
/// JSON parse comments array from body
extern "js" fn json_parse_comments(json_str : String) -> Array[Array[String]] =
  #|(s) => {
  #|  try {
  #|    const obj = JSON.parse(s);
  #|    return (obj.comments || []).map(c => [String(c.row), String(c.col), c.text || "", c.value || "", c.image || ""]);
  #|  } catch(e) { return []; }
  #|}

///|
/// Home directory
#module("node:os")
extern "js" fn os_homedir() -> String = "homedir"

///|
/// Get environment variable value (empty string if not set)
extern "js" fn get_env_var(name : String) -> String =
  #|(name) => process.env[name] || ""

///|
/// Process signal handler
extern "js" fn on_process_signal(signal : String, handler : () -> Unit) -> Unit =
  #|(sig, handler) => process.on(sig, handler)

///| ----- ESM-compatible module imports -----

///|
/// Read file as Buffer (no encoding = returns Buffer)
#module("node:fs")
extern "js" fn read_file_buffer(path : String) -> JsValue = "readFileSync"

///|
/// Write file from Buffer
#module("node:fs")
extern "js" fn write_file_sync_buf(path : String, data : JsValue) -> Unit = "writeFileSync"

///|
/// mkdtempSync
#module("node:fs")
extern "js" fn fs_mkdtemp_sync(prefix : String) -> String = "mkdtempSync"

///|
/// readdirSync
#module("node:fs")
extern "js" fn fs_readdir_sync_raw(path : String) -> Array[String] = "readdirSync"

///|
/// rmSync
#module("node:fs")
extern "js" fn fs_rm_sync(path : String, opts : JsValue) -> Unit = "rmSync"

///|
/// spawnSync
#module("node:child_process")
extern "js" fn child_spawn_sync(
  cmd : String,
  args : JsValue,
  opts : JsValue,
) -> JsValue = "spawnSync"

///|
/// spawn
#module("node:child_process")
extern "js" fn child_spawn(
  cmd : String,
  args : JsValue,
  opts : JsValue,
) -> JsValue = "spawn"

///|
/// createHash
#module("node:crypto")
extern "js" fn crypto_create_hash(algo : String) -> JsValue = "createHash"

///|
/// tmpdir
#module("node:os")
extern "js" fn os_tmpdir() -> String = "tmpdir"

///| ----- JS-level helpers (globals only, no require) -----

///|
/// Try-catch wrapper: () -> String
extern "js" fn try_call_string(
  func : () -> String,
  fallback : String,
) -> String =
  #|(fn, fb) => { try { return fn(); } catch(e) { return fb; } }

///|
/// Try-catch wrapper: () -> Unit
extern "js" fn try_call_void(func : () -> Unit) -> Unit =
  #|(fn) => { try { fn(); } catch(e) {} }

///|
/// Try-catch wrapper: () -> Array[String]
extern "js" fn try_call_array_string(
  func : () -> Array[String],
) -> Array[String] =
  #|(fn) => { try { return fn(); } catch(e) { return []; } }

///|
/// Decode buffer with encoding (TextDecoder is a global in Node.js)
extern "js" fn decode_buffer(buf : JsValue, encoding : String) -> String =
  #|(buf, enc) => {
  #|  try {
  #|    if (enc === "utf-8" || enc === "utf8") return buf.toString("utf-8");
  #|    const td = new TextDecoder(enc);
  #|    return td.decode(buf);
  #|  } catch(e) { return buf.toString("utf-8"); }
  #|}

///|
/// Buffer operations (Buffer is a global)
extern "js" fn buffer_length(buf : JsValue) -> Int =
  #|(buf) => buf.length

///|
extern "js" fn buffer_at(buf : JsValue, idx : Int) -> Int =
  #|(buf, idx) => buf[idx]

///|
extern "js" fn buf_to_base64(buf : JsValue) -> String =
  #|(buf) => buf.toString("base64")

///|
extern "js" fn buffer_from_base64(data : String) -> JsValue =
  #|(data) => Buffer.from(data, "base64")

///|
/// JSON helpers (JSON is a global)
extern "js" fn js_parse_json(s : String) -> JsValue =
  #|(s) => JSON.parse(s)

///|
/// Object property access
extern "js" fn js_obj_stdout(obj : JsValue) -> String =
  #|(obj) => obj?.stdout || ""

///|
extern "js" fn js_spawn_opts_pipe() -> JsValue =
  #|() => ({ stdio: ["pipe", "pipe", "pipe"] })

///|
extern "js" fn js_spawn_opts_utf8_pipe() -> JsValue =
  #|() => ({ encoding: "utf8", stdio: ["pipe", "pipe", "pipe"] })

///|
extern "js" fn js_rm_opts() -> JsValue =
  #|() => ({ recursive: true, force: true })

///|
/// Hash helper
extern "js" fn hash_update_digest_hex16(
  hash : JsValue,
  data : String,
) -> String =
  #|(h, d) => h.update(d).digest("hex").slice(0, 16)

///|
/// Extract image extension from base64 data URL
extern "js" fn extract_base64_ext(data : String) -> String =
  #|(data) => {
  #|  const m = data.match(/^data:image\/(\w+);base64,/);
  #|  return m ? (m[1] === "jpeg" ? "jpg" : m[1]) : "";
  #|}

///|
/// Extract base64 content from data URL
extern "js" fn extract_base64_data(data : String) -> String =
  #|(data) => {
  #|  const m = data.match(/^data:image\/(\w+);base64,(.+)$/);
  #|  return m ? m[2] : "";
  #|}

///|
/// ISO timestamp (Date is a global)
extern "js" fn iso_now() -> String =
  #|() => new Date().toISOString()

///|
/// Epoch milliseconds (Date is a global) — for correlating request timing
/// (close-vs-reload race detection), not for display.
extern "js" fn now_ms() -> Double =
  #|() => Date.now()

///|
/// JSON parse images array (JSON is a global)
extern "js" fn json_parse_images(json_str : String) -> Array[String] =
  #|(s) => { try { return JSON.parse(s).summaryImages || []; } catch(e) { return []; } }

///|
/// JSON parse mermaid errors array [{line, message}]
extern "js" fn json_parse_mermaid_errors(
  json_str : String,
) -> Array[Array[String]] =
  #|(s) => {
  #|  try {
  #|    const obj = JSON.parse(s);
  #|    return (obj.mermaidErrors || []).map(e => [String(e.line || 0), e.message || ""]);
  #|  } catch(e) { return []; }
  #|}

///|
/// Parse URL query parameters (URL is a global)
extern "js" fn parse_query_param(url : String, key : String) -> String =
  #|(url, key) => {
  #|  try {
  #|    const u = new URL("http://localhost" + url);
  #|    return u.searchParams.get(key) || "";
  #|  } catch(e) { return ""; }
  #|}

///|
/// Process event listeners (operate on passed object)
extern "js" fn _on_spawn_close(proc : JsValue, handler : (Int) -> Unit) -> Unit =
  #|(proc, handler) => proc.on("close", (code) => handler(code || 0))

///|
/// Close handler that also collects stderr output
extern "js" fn on_spawn_close_with_stderr(
  proc : JsValue,
  handler : (Int, String) -> Unit,
) -> Unit =
  #|(proc, handler) => {
  #|  let buf = '';
  #|  if (proc.stderr) proc.stderr.on('data', (chunk) => { buf += chunk.toString(); });
  #|  proc.on('close', (code) => handler(code || 0, buf));
  #|}

///|
/// Parse pts_time values from ffmpeg showinfo filter stderr output
extern "js" fn parse_showinfo_timestamps(stderr : String) -> Array[Double] =
  #|(stderr) => {
  #|  const times = [];
  #|  for (const line of stderr.split('\n')) {
  #|    const m = line.match(/pts_time:\s*([\d.]+)/);
  #|    if (m) times.push(parseFloat(m[1]));
  #|  }
  #|  return times;
  #|}

///|
/// Sort array of strings in place
extern "js" fn sort_strings(arr : Array[String]) -> Array[String] =
  #|(arr) => arr.sort()

///|
extern "js" fn on_spawn_error(proc : JsValue, handler : () -> Unit) -> Unit =
  #|(proc, handler) => proc.on("error", () => handler())

///| ----- MoonBit wrapper functions -----

///|
/// SHA256 hash (first 16 chars)
fn crypto_sha256(s : String) -> String {
  hash_update_digest_hex16(crypto_create_hash("sha256"), s)
}

///|
/// Read file with error handling (returns empty string on error)
fn read_file_safe(path : String) -> String {
  try_call_string(fn() { read_file_sync(path, "utf-8") }, "")
}

///|
/// Parse "version" field from JSON string
extern "js" fn parse_json_version(json : String) -> String =
  #|(s) => { try { return JSON.parse(s).version || "unknown"; } catch { return "unknown"; } }

///|
/// Get version from package.json (walks up from script dir)
fn get_package_version() -> String {
  let mut dir = get_script_dir()
  for i = 0; i < 5; i = i + 1 {
    let content = read_file_safe(path_join(dir, "package.json"))
    if content.length() > 0 {
      let ver = parse_json_version(content)
      if ver != "unknown" {
        return ver
      }
    }
    dir = path_dirname(dir)
  }
  "unknown"
}

///|
/// Write file with error handling
fn write_file_secure(path : String, data : String) -> Unit {
  try_call_void(fn() { write_file_sync(path, data) })
}

///|
/// Save base64 image to file, returns filepath or ""
fn base64_to_file(data : String, dir : String, index : Int) -> String {
  let ext = extract_base64_ext(data)
  if ext.length() == 0 {
    return ""
  }
  let b64_data = extract_base64_data(data)
  if b64_data.length() == 0 {
    return ""
  }
  try_call_string(
    fn() {
      if !exists_sync(dir) {
        mkdir_sync(dir, mkdir_recursive_opts())
      }
      let filepath = path_join(dir, "image_\{index}.\{ext}")
      write_file_sync_buf(filepath, buffer_from_base64(b64_data))
      filepath
    },
    "",
  )
}

///|
/// Spawn async process
fn spawn_async(cmd : String, args_json : String) -> JsValue {
  child_spawn(cmd, js_parse_json(args_json), js_spawn_opts_pipe())
}

///|
/// Make temp directory
fn make_temp_dir() -> String {
  fs_mkdtemp_sync(os_tmpdir() + "/yunomi-")
}

///|
/// Remove directory recursively
fn rm_dir_recursive(path : String) -> Unit {
  try_call_void(fn() { fs_rm_sync(path, js_rm_opts()) })
}

///|
/// Read directory listing (returns [] on error)
fn readdir_sync(path : String) -> Array[String] {
  try_call_array_string(fn() { fs_readdir_sync_raw(path) })
}

///|
/// Read file as base64 (returns "" on error)
fn read_file_base64(path : String) -> String {
  try_call_string(fn() { buf_to_base64(read_file_buffer(path)) }, "")
}

///|
extern "js" fn env_path() -> String =
  #|() => process.env.PATH || ""

///|
extern "js" fn split_path_list(path : String) -> Array[String] =
  #|(path) => path.split(":").filter(Boolean)

///|
fn resolve_command(cmd : String) -> String {
  if cmd.contains("/") && exists_sync(cmd) {
    return cmd
  }
  let dirs = split_path_list(env_path())
  dirs.push("/opt/homebrew/bin")
  dirs.push("/usr/local/bin")
  dirs.push("/usr/bin")
  dirs.push("/bin")
  for dir in dirs {
    let candidate = path_join(dir, cmd)
    if exists_sync(candidate) && is_file_sync(candidate) {
      return candidate
    }
  }
  ""
}

///|
/// Spawn sync and return stdout (returns "" on error)
fn spawn_sync_stdout(cmd : String, args_json : String) -> String {
  try_call_string(
    fn() {
      js_obj_stdout(
        child_spawn_sync(
          cmd,
          js_parse_json(args_json),
          js_spawn_opts_utf8_pipe(),
        ),
      )
    },
    "",
  )
}

///|
/// path.dirname
#module("node:path")
extern "js" fn path_dirname(path : String) -> String = "dirname"

///|
/// fs.statSync - returns raw JS Stats object
#module("node:fs")
extern "js" fn fs_stat_sync(path : String) -> JsValue = "statSync"

///|
/// fs.createReadStream
#module("node:fs")
extern "js" fn fs_create_read_stream(path : String) -> JsValue = "createReadStream"

///|
/// fs.createReadStream with options object
#module("node:fs")
extern "js" fn fs_create_read_stream_opts(
  path : String,
  opts : JsValue,
) -> JsValue = "createReadStream"

///|
/// Create {start, end} options for range requests
extern "js" fn js_range_opts(start : Int, end : Int) -> JsValue =
  #|(s, e) => ({start: s, end: e})

///|
/// Stats.isFile()
extern "js" fn js_stat_is_file(stat : JsValue) -> Bool =
  #|(s) => s.isFile()

///|
/// Stats.size
extern "js" fn js_stat_size(stat : JsValue) -> Int =
  #|(s) => s.size

///|
/// fs.statSync(path).size - safe wrapper
fn _stat_file_size(path : String) -> Int {
  js_stat_size(fs_stat_sync(path))
}

///|
/// fs.statSync(path).isFile() - safe wrapper
fn is_file_sync(path : String) -> Bool {
  js_stat_is_file(fs_stat_sync(path))
}

///|
/// Pipe file to response with Content-Type header (full file)
fn pipe_file_to_response(
  file_path : String,
  res : JsValue,
  content_type : String,
) -> Unit {
  let stat = fs_stat_sync(file_path)
  let size = js_stat_size(stat)
  res_set_header(res, "Accept-Ranges", "bytes")
  res_write_head_with_headers(res, 200, content_type, size, true)
  let stream = fs_create_read_stream(file_path)
  js_pipe(stream, res)
}

///|
/// Pipe file range to response (for video seeking)
fn pipe_file_range(
  file_path : String,
  res : JsValue,
  content_type : String,
  range_header : String,
) -> Unit {
  let stat = fs_stat_sync(file_path)
  let file_size = js_stat_size(stat)
  let range_info = parse_range_header(range_header, file_size)
  let start = range_info.0
  let end = range_info.1
  let chunk_size = end - start + 1
  res_write_head_range(res, content_type, start, end, file_size, chunk_size)
  let opts = js_range_opts(start, end)
  let stream = fs_create_read_stream_opts(file_path, opts)
  js_pipe(stream, res)
}

///|
/// Parse Range header → (start, end)
extern "js" fn parse_range_header(
  range : String,
  file_size : Int,
) -> (Int, Int) =
  #|(rangeHeader, fileSize) => {
  #|  const parts = rangeHeader.replace(/bytes=/, "").split("-");
  #|  const start = parseInt(parts[0], 10);
  #|  const end = parts[1] ? parseInt(parts[1], 10) : fileSize - 1;
  #|  return {_0: start, _1: end};
  #|}

///|
/// Write response headers for full file
extern "js" fn res_write_head_with_headers(
  res : JsValue,
  status : Int,
  content_type : String,
  content_length : Int,
  cache : Bool,
) -> Unit =
  #|(res, status, ct, cl, cache) => {
  #|  const headers = {"Content-Type": ct, "Content-Length": cl};
  #|  if (cache) headers["Cache-Control"] = "public, max-age=3600";
  #|  res.writeHead(status, headers);
  #|}

///|
/// Write response headers for range request
extern "js" fn res_write_head_range(
  res : JsValue,
  content_type : String,
  start : Int,
  end : Int,
  file_size : Int,
  chunk_size : Int,
) -> Unit =
  #|(res, ct, start, end, fileSize, chunkSize) => {
  #|  res.writeHead(206, {
  #|    "Content-Range": `bytes ${start}-${end}/${fileSize}`,
  #|    "Accept-Ranges": "bytes",
  #|    "Content-Length": chunkSize,
  #|    "Content-Type": ct
  #|  });
  #|}

///|
/// Pipe a readable stream to a writable stream
extern "js" fn js_pipe(readable : JsValue, writable : JsValue) -> Unit =
  #|(r, w) => r.pipe(w)

///|
/// Get Range header from request (empty string if not present)
extern "js" fn req_range_header(req : JsValue) -> String =
  #|(req) => req.headers.range || ""

///|
/// Set a single response header
extern "js" fn res_set_header(
  res : JsValue,
  name : String,
  value : String,
) -> Unit =
  #|(res, name, value) => { if (res && !res.headersSent) res.setHeader(name, value); }

///|
/// chmod file (best-effort, uses dynamic import)
extern "js" fn chmod_sync(path : String, mode : Int) -> Unit =
  #|(path, mode) => { try { import("node:fs").then(fs => fs.chmodSync(path, mode)); } catch(e) {} }
