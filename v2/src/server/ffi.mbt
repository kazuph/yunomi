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
extern "js" fn fs_copy_file_sync(src : String, dest : String) -> Unit = "copyFileSync"

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
extern "js" fn file_content_signature(path : String) -> String =
  #|(path) => {
  #|  try {
  #|    const fs = process.getBuiltinModule("node:fs");
  #|    const crypto = process.getBuiltinModule("node:crypto");
  #|    return crypto.createHash("sha256").update(fs.readFileSync(path)).digest("hex");
  #|  } catch {
  #|    return "";
  #|  }
  #|}

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
#module("node:path")
extern "js" fn path_relative(from : String, to : String) -> String = "relative"

///|
#module("node:fs")
extern "js" fn fs_realpath_sync(path : String) -> String = "realpathSync"

///|
/// Node.js process
extern "js" fn get_argv() -> Array[String] =
  #|() => process.argv

///|
extern "js" fn process_exec_path() -> String =
  #|() => process.execPath

///|
extern "js" fn process_exit(code : Int) -> Unit =
  #|(code) => process.exit(code)

///|
extern "js" fn process_pid() -> Int =
  #|() => process.pid

///|
extern "js" fn process_cwd() -> String =
  #|() => process.cwd()

///|
/// Check if a process with given PID exists
extern "js" fn process_exists(pid : Int) -> Bool =
  #|(pid) => { try { process.kill(pid, 0); return true; } catch(e) { return e?.code === "EPERM"; } }

///|
extern "js" fn process_stdout_write(data : String) -> Unit =
  #|(data) => process.stdout.write(data)

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
extern "js" fn create_share_token(
  files : Array[String],
  host : String,
  port : Int,
) -> String =
  #|(filesArg, host, port) => {
  #|  const fs = process.getBuiltinModule("node:fs");
  #|  const path = process.getBuiltinModule("node:path");
  #|  const os = process.getBuiltinModule("node:os");
  #|  const crypto = process.getBuiltinModule("node:crypto");
  #|  const dir = process.env.YUNOMI_SHARE_DIR || path.join(os.homedir(), ".yunomi", "shares");
  #|  fs.mkdirSync(dir, { recursive: true });
  #|  const token = crypto.randomBytes(16).toString("hex");
  #|  const files = Array.isArray(filesArg) ? filesArg.map(String) : [];
  #|  const meta = {
  #|    token,
  #|    files,
  #|    host,
  #|    port,
  #|    read_only: true,
  #|    created_at: new Date().toISOString(),
  #|    expires_at: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString()
  #|  };
  #|  fs.writeFileSync(path.join(dir, `${token}.json`), JSON.stringify(meta, null, 2));
  #|  return token;
  #|}

///|
extern "js" fn update_share_token_port(token : String, port : Int) -> Unit =
  #|(token, port) => {
  #|  const fs = process.getBuiltinModule("node:fs");
  #|  const path = process.getBuiltinModule("node:path");
  #|  const os = process.getBuiltinModule("node:os");
  #|  const dir = process.env.YUNOMI_SHARE_DIR || path.join(os.homedir(), ".yunomi", "shares");
  #|  const file = path.join(dir, `${token}.json`);
  #|  if (!fs.existsSync(file)) return;
  #|  try {
  #|    const meta = JSON.parse(fs.readFileSync(file, "utf8"));
  #|    if (!meta || typeof meta !== "object" || Array.isArray(meta)) return;
  #|    meta.port = Number(port);
  #|    fs.writeFileSync(file, JSON.stringify(meta, null, 2));
  #|  } catch (error) {
  #|    console.warn(`Unable to update share metadata port: ${error instanceof Error ? error.message : String(error)}`);
  #|  }
  #|}

///|
extern "js" fn revoke_share_token(token : String) -> Bool =
  #|(token) => {
  #|  if (!/^[A-Za-z0-9._-]+$/.test(String(token || ""))) return false;
  #|  const fs = process.getBuiltinModule("node:fs");
  #|  const path = process.getBuiltinModule("node:path");
  #|  const os = process.getBuiltinModule("node:os");
  #|  const dir = process.env.YUNOMI_SHARE_DIR || path.join(os.homedir(), ".yunomi", "shares");
  #|  const file = path.join(dir, `${token}.json`);
  #|  if (!fs.existsSync(file)) return false;
  #|  fs.unlinkSync(file);
  #|  return true;
  #|}

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
extern "js" fn server_bound_port(server : JsValue) -> Int =
  #|(server) => Number(server.address()?.port || 0)

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
/// Start a localhost-only live review reverse proxy. The implementation stays
/// in JS because Node's HTTP upgrade and proxy streaming APIs are much simpler
/// to use directly than through many tiny FFI calls.
extern "js" fn start_live_proxy(
  target_url : String,
  port : Int,
  host : String,
  no_open : Bool,
  instance_id : String,
  persist_review : (String) -> Unit,
) -> Unit =
  #|(targetUrl, port, host, noOpen, instanceId, persistReview) => {
  #|  const yamlEscape = (value) => {
  #|    const s = String(value ?? "");
  #|    if (!/[:#'"\n\[\]{},&*!|>%@]/.test(s)) return s;
  #|    return "'" + s.replace(/'/g, "''") + "'";
  #|  };
  #|  const toYaml = (payload) => {
  #|    const comments = Array.isArray(payload.comments) ? payload.comments : [];
  #|    const lines = [];
  #|    lines.push(`action: ${payload.action || "final_request_changes"}`);
  #|    lines.push(`file: ${yamlEscape(targetUrl)}`);
  #|    lines.push("mode: live");
  #|    lines.push("comments:");
  #|    for (const comment of comments) {
  #|      const elementText = String(comment.element_text || comment.value || "");
  #|      const attachments = Array.isArray(comment.attachments) ? comment.attachments : [];
  #|      if (comment.screenshot) attachments.push(String(comment.screenshot));
  #|      const bounds = comment.bounds ? JSON.stringify(comment.bounds) : "";
  #|      lines.push(`  - file: ${yamlEscape(targetUrl)}`);
  #|      lines.push(`    row: ${Number(comment.row || 0)}`);
  #|      lines.push(`    col: ${Number(comment.col || 0)}`);
  #|      lines.push(`    end_row: ${Number(comment.end_row ?? comment.row ?? 0)}`);
  #|      lines.push(`    end_col: ${Number(comment.end_col ?? comment.col ?? 0)}`);
  #|      lines.push(`    text: ${yamlEscape(comment.text || "")}`);
  #|      lines.push(`    snippet: ${yamlEscape(elementText)}`);
  #|      lines.push(`    context_before: ${yamlEscape(comment.context_before || "")}`);
  #|      lines.push(`    context_after: ${yamlEscape(comment.context_after || "")}`);
  #|      lines.push(`    selector: ${yamlEscape(comment.selector || "")}`);
  #|      if (comment.value) lines.push(`    value: ${yamlEscape(comment.value)}`);
  #|      if (comment.screenshot) lines.push(`    screenshot: ${yamlEscape(comment.screenshot)}`);
  #|      lines.push(`    bounds: ${yamlEscape(bounds)}`);
  #|      lines.push(`    element_text: ${yamlEscape(elementText)}`);
  #|      if (attachments.length) {
  #|        lines.push("    attachments:");
  #|        for (const attachment of attachments) lines.push(`      - ${yamlEscape(attachment)}`);
  #|      } else {
  #|        lines.push("    attachments: []");
  #|      }
  #|    }
  #|    lines.push(`summary: ${yamlEscape(payload.summary || "")}`);
  #|    lines.push(`decision: ${payload.decision || "request_changes"}`);
  #|    return lines.join("\n") + "\n";
  #|  };
  #|  let target;
  #|  try { target = new URL(targetUrl); } catch (e) {
  #|    console.error("yunomi live: invalid URL");
  #|    process.exit(1);
  #|    return;
  #|  }
  #|  const allowedHost = target.hostname === "localhost" || target.hostname === "127.0.0.1";
  #|  if (target.protocol !== "http:" || !allowedHost) {
  #|    console.error("yunomi live: only http://localhost and http://127.0.0.1 targets are allowed");
  #|    process.exit(1);
  #|    return;
  #|  }
  #|  Promise.all([import("node:http"), import("node:net"), import("node:child_process")]).then(([http, net, childProcess]) => {
  #|    const overlayScript = `(() => {
  #|      if (window.__yunomiLiveInstalled) return;
  #|      window.__yunomiLiveInstalled = true;
  #|      const comments = [];
  #|      let enabled = true;
  #|      let active = null;
  #|      const style = document.createElement("style");
  #|      style.textContent = [
  #|        "/* yunomi live overlay tokens mirror the Primer-inspired app theme. */",
  #|        ":root{--yunomi-live-panel:rgba(255,255,255,.92);--yunomi-live-panel-solid:#ffffff;--yunomi-live-card-bg:rgba(255,255,255,.98);--yunomi-live-input-bg:#f6f8fa;--yunomi-live-border:#d0d7de;--yunomi-live-border-strong:#8c959f;--yunomi-live-accent:#0969da;--yunomi-live-accent-strong:#0550ae;--yunomi-live-accent-2:#8250df;--yunomi-live-accent-soft:rgba(9,105,218,.10);--yunomi-live-selected-bg:rgba(9,105,218,.16);--yunomi-live-hover-bg:rgba(9,105,218,.08);--yunomi-live-text:#24292f;--yunomi-live-text-inverse:#ffffff;--yunomi-live-muted:#57606a;--yunomi-live-shadow-soft:0 6px 18px rgba(31,35,40,.08);--yunomi-live-shadow-card:0 18px 36px rgba(31,35,40,.12);--yunomi-live-radius-sm:8px;--yunomi-live-radius-lg:16px;--yunomi-live-radius-pill:999px;--yunomi-live-font:'Inter','Hiragino Kaku Gothic ProN','Hiragino Sans',system-ui,-apple-system,sans-serif}",
  #|        "@media (prefers-color-scheme:dark){:root{--yunomi-live-panel:rgba(22,27,34,.88);--yunomi-live-panel-solid:#161b22;--yunomi-live-card-bg:rgba(22,27,34,.96);--yunomi-live-input-bg:#0d1117;--yunomi-live-border:#30363d;--yunomi-live-border-strong:#8b949e;--yunomi-live-accent:#2f81f7;--yunomi-live-accent-strong:#58a6ff;--yunomi-live-accent-2:#a371f7;--yunomi-live-accent-soft:rgba(47,129,247,.16);--yunomi-live-selected-bg:rgba(47,129,247,.22);--yunomi-live-hover-bg:rgba(47,129,247,.12);--yunomi-live-text:#e6edf3;--yunomi-live-text-inverse:#0d1117;--yunomi-live-muted:#8b949e;--yunomi-live-shadow-soft:0 10px 30px rgba(0,0,0,.35);--yunomi-live-shadow-card:0 20px 40px rgba(0,0,0,.4)}}",
  #|        ".yunomi-live-hover{outline:2px solid var(--yunomi-live-accent)!important;outline-offset:2px!important;box-shadow:0 0 0 4px var(--yunomi-live-accent-soft)!important;border-radius:4px!important}",
  #|        ".yunomi-live-pin{outline:2px solid var(--yunomi-live-accent)!important;outline-offset:2px!important;box-shadow:0 0 0 4px var(--yunomi-live-selected-bg)!important;border-radius:4px!important}",
  #|        "#yunomi-live-bar{position:fixed;z-index:2147483647;right:16px;top:16px;display:flex;gap:6px;align-items:center;background:var(--yunomi-live-panel);color:var(--yunomi-live-text);border:1px solid var(--yunomi-live-border);border-radius:var(--yunomi-live-radius-lg);padding:8px 10px;font:13px var(--yunomi-live-font);box-shadow:var(--yunomi-live-shadow-soft);backdrop-filter:saturate(140%) blur(18px);-webkit-backdrop-filter:saturate(140%) blur(18px);letter-spacing:0}",
  #|        "#yunomi-live-bar strong{font-size:13px;font-weight:700;letter-spacing:0;color:var(--yunomi-live-text)}",
  #|        "#yunomi-live-count{display:inline-flex;min-width:24px;height:24px;align-items:center;justify-content:center;border-radius:var(--yunomi-live-radius-pill);background:var(--yunomi-live-accent-soft);color:var(--yunomi-live-accent-strong);font-weight:700}",
  #|        "#yunomi-live-bar button,#yunomi-live-card button{font:inherit;border:1px solid transparent;background:transparent;color:var(--yunomi-live-text);border-radius:var(--yunomi-live-radius-sm);padding:6px 10px;min-height:32px;cursor:pointer;transition:background 160ms ease,border-color 160ms ease,box-shadow 160ms ease,color 160ms ease}",
  #|        "#yunomi-live-bar button:hover,#yunomi-live-card button:hover{background:var(--yunomi-live-hover-bg);border-color:var(--yunomi-live-border)}",
  #|        "#yunomi-live-submit,#yunomi-live-card [data-yunomi-save]{background:linear-gradient(135deg,var(--yunomi-live-accent) 0%,var(--yunomi-live-accent-2) 100%)!important;color:var(--yunomi-live-text-inverse)!important;border-color:transparent!important;font-weight:700;box-shadow:var(--yunomi-live-shadow-soft)}",
  #|        "#yunomi-live-submit:hover,#yunomi-live-card [data-yunomi-save]:hover{background:linear-gradient(135deg,var(--yunomi-live-accent-strong) 0%,var(--yunomi-live-accent) 100%)!important;box-shadow:var(--yunomi-live-shadow-card)}",
  #|        "#yunomi-live-card{position:fixed;z-index:2147483647;min-width:280px;max-width:360px;background:var(--yunomi-live-card-bg);color:var(--yunomi-live-text);border:1px solid var(--yunomi-live-border);border-radius:var(--yunomi-live-radius-lg);padding:12px;box-shadow:var(--yunomi-live-shadow-card);font:13px var(--yunomi-live-font);letter-spacing:0}",
  #|        "#yunomi-live-card textarea{width:100%;height:88px;box-sizing:border-box;border-radius:var(--yunomi-live-radius-sm);border:1px solid var(--yunomi-live-border);background:var(--yunomi-live-input-bg);color:var(--yunomi-live-text);padding:9px 10px;font:13px var(--yunomi-live-font);resize:vertical;outline:none}",
  #|        "#yunomi-live-card textarea:focus{border-color:var(--yunomi-live-accent);box-shadow:0 0 0 3px var(--yunomi-live-accent-soft)}",
  #|        "#yunomi-live-card .meta{font-size:11px;color:var(--yunomi-live-muted);margin:0 0 8px 0;word-break:break-all}"
  #|      ].join("\\n");
  #|      document.documentElement.appendChild(style);
  #|      const bar = document.createElement("div");
  #|      bar.id = "yunomi-live-bar";
  #|      bar.innerHTML = '<strong>yunomi live</strong><span id="yunomi-live-count">0</span><button id="yunomi-live-toggle">Comment mode</button><button id="yunomi-live-submit">Submit & Exit</button>';
  #|      document.documentElement.appendChild(bar);
  #|      const isUi = (el) => !!el.closest?.("#yunomi-live-bar,#yunomi-live-card");
  #|      const cssEscape = (value) => (window.CSS && CSS.escape) ? CSS.escape(value) : String(value).replace(/[^a-zA-Z0-9_-]/g, "\\\\$&");
  #|      const selectorFor = (el) => {
  #|        if (el.id && document.querySelectorAll("#" + cssEscape(el.id)).length === 1) return "#" + cssEscape(el.id);
  #|        const parts = [];
  #|        let node = el;
  #|        while (node && node.nodeType === 1 && node !== document.documentElement) {
  #|          let part = node.localName.toLowerCase();
  #|          const classes = [...node.classList].filter(c => !c.startsWith("yunomi-live-")).slice(0, 2);
  #|          if (classes.length) part += "." + classes.map(cssEscape).join(".");
  #|          const parent = node.parentElement;
  #|          if (parent) {
  #|            const same = [...parent.children].filter(c => c.localName === node.localName);
  #|            if (same.length > 1) part += ":nth-of-type(" + (same.indexOf(node) + 1) + ")";
  #|          }
  #|          parts.unshift(part);
  #|          const candidate = parts.join(" > ");
  #|          if (document.querySelectorAll(candidate).length === 1) return candidate;
  #|          node = parent;
  #|        }
  #|        return parts.join(" > ");
  #|      };
  #|      const elementText = (el) => (el.innerText || el.textContent || "").replace(/\\s+/g, " ").trim().slice(0, 500);
  #|      const boundsFor = (el) => {
  #|        const r = el.getBoundingClientRect();
  #|        return { x: Math.round(r.x), y: Math.round(r.y), width: Math.round(r.width), height: Math.round(r.height), viewportWidth: innerWidth, viewportHeight: innerHeight };
  #|      };
  #|      const updateCount = () => { document.getElementById("yunomi-live-count").textContent = String(comments.length); };
  #|      const closeCard = () => document.getElementById("yunomi-live-card")?.remove();
  #|      document.addEventListener("mouseover", (event) => {
  #|        if (!enabled || isUi(event.target)) return;
  #|        active?.classList.remove("yunomi-live-hover");
  #|        active = event.target;
  #|        active.classList.add("yunomi-live-hover");
  #|      }, true);
  #|      document.addEventListener("mouseout", (event) => {
  #|        if (event.target === active) active.classList.remove("yunomi-live-hover");
  #|      }, true);
  #|      document.addEventListener("click", (event) => {
  #|        if (!enabled || isUi(event.target)) return;
  #|        event.preventDefault();
  #|        event.stopPropagation();
  #|        const el = event.target;
  #|        const selector = selectorFor(el);
  #|        const rect = el.getBoundingClientRect();
  #|        closeCard();
  #|        const card = document.createElement("div");
  #|        card.id = "yunomi-live-card";
  #|        card.style.left = Math.min(Math.max(12, rect.left), innerWidth - 380) + "px";
  #|        card.style.top = Math.min(Math.max(12, rect.bottom + 8), innerHeight - 190) + "px";
  #|        card.innerHTML = '<p class="meta"></p><textarea placeholder="Comment for this element"></textarea><div style="display:flex;gap:8px;justify-content:flex-end;margin-top:8px"><button data-yunomi-cancel>Cancel</button><button data-yunomi-save>Save</button></div>';
  #|        card.querySelector(".meta").textContent = selector;
  #|        document.documentElement.appendChild(card);
  #|        card.querySelector("textarea").focus();
  #|        card.querySelector("[data-yunomi-cancel]").onclick = closeCard;
  #|        card.querySelector("[data-yunomi-save]").onclick = () => {
  #|          const text = card.querySelector("textarea").value.trim();
  #|          if (!text) return;
  #|          comments.push({ row: 0, col: 0, text, selector, value: elementText(el), screenshot: "", bounds: boundsFor(el) });
  #|          el.classList.add("yunomi-live-pin");
  #|          updateCount();
  #|          closeCard();
  #|        };
  #|      }, true);
  #|      document.getElementById("yunomi-live-toggle").onclick = () => {
  #|        enabled = !enabled;
  #|        document.getElementById("yunomi-live-toggle").textContent = enabled ? "Comment mode" : "Browsing mode";
  #|        active?.classList.remove("yunomi-live-hover");
  #|      };
  #|      document.getElementById("yunomi-live-submit").onclick = async () => {
  #|        const summary = window.prompt("Overall comment", "") || "";
  #|        await fetch("/exit", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ action: "final_request_changes", decision: "request_changes", summary, comments }) });
  #|        document.body.innerHTML = "<main style=\\"font:16px system-ui,sans-serif;padding:40px\\"><h1>Review submitted</h1><p>yunomi live can be closed.</p></main>";
  #|      };
  #|    })();`;
  #|    const inject = (html) => {
  #|      const tag = `<script data-yunomi-live="${instanceId}">${overlayScript.replaceAll("</script", "<\\\\/script")}</script>`;
  #|      return /<\/body>/i.test(html) ? html.replace(/<\/body>/i, tag + "</body>") : html + tag;
  #|    };
  #|    const server = http.createServer((req, res) => {
  #|      if (req.method === "GET" && req.url === "/healthz") {
  #|        res.writeHead(200, { "Content-Type": "application/json" });
  #|        res.end('{"ok":true,"mode":"live"}');
  #|        return;
  #|      }
  #|      if (req.method === "POST" && req.url === "/exit") {
  #|        const chunks = [];
  #|        req.on("data", chunk => chunks.push(chunk));
  #|        req.on("end", () => {
  #|          let payload = {};
  #|          try { payload = JSON.parse(Buffer.concat(chunks).toString("utf8")); } catch (e) {}
  #|          persistReview(JSON.stringify(payload));
  #|          process.stdout.write(toYaml(payload));
  #|          res.writeHead(200, { "Content-Type": "application/json" });
  #|          res.end('{"ok":true}', () => server.close(() => process.exit(0)));
  #|        });
  #|        return;
  #|      }
  #|      const headers = { ...req.headers, host: target.host };
  #|      delete headers["accept-encoding"];
  #|      const upstream = http.request({
  #|        protocol: target.protocol,
  #|        hostname: target.hostname,
  #|        port: target.port || 80,
  #|        method: req.method,
  #|        path: req.url,
  #|        headers
  #|      }, upstreamRes => {
  #|        const type = String(upstreamRes.headers["content-type"] || "");
  #|        if (req.method === "GET" && type.includes("text/html")) {
  #|          const chunks = [];
  #|          upstreamRes.on("data", chunk => chunks.push(chunk));
  #|          upstreamRes.on("end", () => {
  #|            const body = inject(Buffer.concat(chunks).toString("utf8"));
  #|            const outHeaders = { ...upstreamRes.headers, "content-length": Buffer.byteLength(body), "cache-control": "no-store" };
  #|            delete outHeaders["content-encoding"];
  #|            delete outHeaders["transfer-encoding"];
  #|            res.writeHead(upstreamRes.statusCode || 200, outHeaders);
  #|            res.end(body);
  #|          });
  #|        } else {
  #|          res.writeHead(upstreamRes.statusCode || 200, upstreamRes.headers);
  #|          upstreamRes.pipe(res);
  #|        }
  #|      });
  #|      upstream.on("error", err => {
  #|        res.writeHead(502, { "Content-Type": "text/plain" });
  #|        res.end("yunomi live proxy error: " + err.message);
  #|      });
  #|      req.pipe(upstream);
  #|    });
  #|    server.on("upgrade", (req, socket, head) => {
  #|      const upstream = net.connect(Number(target.port || 80), target.hostname, () => {
  #|        upstream.write(`${req.method} ${req.url} HTTP/${req.httpVersion}\r\n`);
  #|        const headers = { ...req.headers, host: target.host };
  #|        for (const [key, value] of Object.entries(headers)) upstream.write(`${key}: ${value}\r\n`);
  #|        upstream.write("\r\n");
  #|        if (head && head.length) upstream.write(head);
  #|        socket.pipe(upstream).pipe(socket);
  #|      });
  #|      upstream.on("error", () => socket.destroy());
  #|    });
  #|    server.listen(port, host, () => {
  #|      const displayHost = host === "0.0.0.0" ? "127.0.0.1" : host;
  #|      const url = `http://${displayHost}:${port}`;
  #|      console.log(`yunomi live proxying ${targetUrl} at ${url}`);
  #|      if (!noOpen) {
  #|        if (process.platform === "darwin") childProcess.spawn("open", [url], { detached: true, stdio: "ignore" }).unref();
  #|        else if (process.platform === "win32") childProcess.spawn("cmd", ["/c", "start", url], { detached: true, stdio: "ignore" }).unref();
  #|        else childProcess.spawn("xdg-open", [url], { detached: true, stdio: "ignore" }).unref();
  #|      }
  #|    });
  #|    server.on("error", err => {
  #|      console.error("yunomi live: " + err.message);
  #|      process.exit(1);
  #|    });
  #|  }).catch(err => {
  #|    console.error("yunomi live: " + err.message);
  #|    process.exit(1);
  #|  });
  #|}

///|
/// Start a static HTML preview server. The top page is a yunomi chrome with a
/// sandboxed iframe; the iframe target receives the same selector/bounds
/// commenting overlay as live review, but assets are served from the HTML
/// file's own directory.
extern "js" fn start_html_preview_server(
  file_path : String,
  port : Int,
  host : String,
  no_open : Bool,
  instance_id : String,
  max_port_attempts : Int,
  on_listening : (Int) -> Unit,
  on_finished : (Int) -> Unit,
  persist_review : (String) -> Unit,
) -> Unit =
  #|(filePath, port, host, noOpen, instanceId, maxPortAttempts, onListening, onFinished, persistReview) => {
  #|  const yamlEscape = (value) => {
  #|    const s = String(value ?? "");
  #|    if (!/[:#'"\n\[\]{},&*!|>%@]/.test(s)) return s;
  #|    return "'" + s.replace(/'/g, "''") + "'";
  #|  };
  #|  let displayFile = String(filePath || "");
  #|  const toYaml = (payload) => {
  #|    const comments = Array.isArray(payload.comments) ? payload.comments : [];
  #|    const lines = [];
  #|    lines.push(`action: ${payload.action || "final_request_changes"}`);
  #|    lines.push(`file: ${yamlEscape(displayFile)}`);
  #|    lines.push("mode: html");
  #|    lines.push("comments:");
  #|    for (const comment of comments) {
  #|      const elementText = String(comment.element_text || comment.value || "");
  #|      const bounds = comment.bounds ? JSON.stringify(comment.bounds) : "";
  #|      const attachments = Array.isArray(comment.attachments) ? comment.attachments : [];
  #|      lines.push(`  - file: ${yamlEscape(displayFile)}`);
  #|      lines.push(`    row: ${Number(comment.row || 0)}`);
  #|      lines.push(`    col: ${Number(comment.col || 0)}`);
  #|      lines.push(`    end_row: ${Number(comment.end_row ?? comment.row ?? 0)}`);
  #|      lines.push(`    end_col: ${Number(comment.end_col ?? comment.col ?? 0)}`);
  #|      lines.push(`    text: ${yamlEscape(comment.text || "")}`);
  #|      lines.push(`    snippet: ${yamlEscape(elementText)}`);
  #|      lines.push(`    context_before: ${yamlEscape(comment.context_before || "")}`);
  #|      lines.push(`    context_after: ${yamlEscape(comment.context_after || "")}`);
  #|      lines.push(`    selector: ${yamlEscape(comment.selector || "")}`);
  #|      if (comment.value) lines.push(`    value: ${yamlEscape(comment.value)}`);
  #|      lines.push(`    bounds: ${yamlEscape(bounds)}`);
  #|      lines.push(`    element_text: ${yamlEscape(elementText)}`);
  #|      if (attachments.length) {
  #|        lines.push("    attachments:");
  #|        for (const attachment of attachments) lines.push(`      - ${yamlEscape(attachment)}`);
  #|      } else {
  #|        lines.push("    attachments: []");
  #|      }
  #|    }
  #|    lines.push(`summary: ${yamlEscape(payload.summary || "")}`);
  #|    lines.push(`decision: ${payload.decision || "request_changes"}`);
  #|    return lines.join("\n") + "\n";
  #|  };
  #|  Promise.all([
  #|    import("node:http"),
  #|    import("node:fs"),
  #|    import("node:path"),
  #|    import("node:child_process")
  #|  ]).then(([http, fs, path, childProcess]) => {
  #|    const resolvedFile = path.resolve(filePath);
  #|    const baseDir = path.dirname(resolvedFile);
  #|    const filename = path.basename(resolvedFile);
  #|    const relFromCwd = path.relative(process.cwd(), resolvedFile);
  #|    displayFile = relFromCwd && !relFromCwd.startsWith("..") && !path.isAbsolute(relFromCwd) ? relFromCwd : filename;
  #|    const htmlEscape = (value) => String(value ?? "").replace(/[&<>"']/g, (ch) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[ch]));
  #|    const mime = (ext) => ({
  #|      ".html": "text/html; charset=utf-8",
  #|      ".htm": "text/html; charset=utf-8",
  #|      ".css": "text/css; charset=utf-8",
  #|      ".js": "application/javascript; charset=utf-8",
  #|      ".json": "application/json",
  #|      ".png": "image/png",
  #|      ".jpg": "image/jpeg",
  #|      ".jpeg": "image/jpeg",
  #|      ".gif": "image/gif",
  #|      ".webp": "image/webp",
  #|      ".svg": "image/svg+xml",
  #|      ".ico": "image/x-icon"
  #|    }[ext.toLowerCase()] || "application/octet-stream");
  #|    const underBase = (candidate) => {
  #|      const rel = path.relative(baseDir, candidate);
  #|      return rel === "" || (!!rel && !rel.startsWith("..") && !path.isAbsolute(rel));
  #|    };
  #|    const overlayScript = `(() => {
  #|      if (window.__yunomiHtmlInstalled) return;
  #|      window.__yunomiHtmlInstalled = true;
  #|      const externalizeLink = (link) => {
  #|        if (!link) return;
  #|        link.setAttribute("target", "_blank");
  #|        link.setAttribute("rel", "noopener noreferrer");
  #|      };
  #|      document.querySelectorAll("a[href]").forEach(externalizeLink);
  #|      const comments = [];
  #|      let enabled = true;
  #|      let active = null;
  #|      const style = document.createElement("style");
  #|      style.textContent = [
  #|        ":root{--yunomi-html-panel:rgba(255,255,255,.92);--yunomi-html-card-bg:rgba(255,255,255,.98);--yunomi-html-input-bg:#f6f8fa;--yunomi-html-border:#d0d7de;--yunomi-html-accent:#0969da;--yunomi-html-accent-strong:#0550ae;--yunomi-html-accent-2:#8250df;--yunomi-html-accent-soft:rgba(9,105,218,.10);--yunomi-html-selected-bg:rgba(9,105,218,.16);--yunomi-html-hover-bg:rgba(9,105,218,.08);--yunomi-html-text:#24292f;--yunomi-html-text-inverse:#ffffff;--yunomi-html-muted:#57606a;--yunomi-html-shadow:0 18px 36px rgba(31,35,40,.12);--yunomi-html-font:'Inter','Hiragino Kaku Gothic ProN','Hiragino Sans',system-ui,-apple-system,sans-serif}",
  #|        ".yunomi-html-hover{outline:2px solid var(--yunomi-html-accent)!important;outline-offset:2px!important;box-shadow:0 0 0 4px var(--yunomi-html-accent-soft)!important;border-radius:4px!important}",
  #|        ".yunomi-html-pin{outline:2px solid var(--yunomi-html-accent)!important;outline-offset:2px!important;box-shadow:0 0 0 4px var(--yunomi-html-selected-bg)!important;border-radius:4px!important}",
  #|        "#yunomi-html-bar{position:fixed;z-index:2147483647;right:16px;top:16px;display:flex;gap:6px;align-items:center;background:var(--yunomi-html-panel);color:var(--yunomi-html-text);border:1px solid var(--yunomi-html-border);border-radius:16px;padding:8px 10px;font:13px var(--yunomi-html-font);box-shadow:0 6px 18px rgba(31,35,40,.08);letter-spacing:0}",
  #|        "#yunomi-html-count{display:inline-flex;min-width:24px;height:24px;align-items:center;justify-content:center;border-radius:999px;background:var(--yunomi-html-accent-soft);color:var(--yunomi-html-accent-strong);font-weight:700}",
  #|        "#yunomi-html-bar button,#yunomi-html-card button,#yunomi-html-submit-card button{font:inherit;border:1px solid transparent;background:transparent;color:var(--yunomi-html-text);border-radius:8px;padding:6px 10px;min-height:32px;cursor:pointer}",
  #|        "#yunomi-html-card [data-yunomi-save],#yunomi-html-submit,#yunomi-html-submit-card [data-yunomi-submit]{background:linear-gradient(135deg,var(--yunomi-html-accent) 0%,var(--yunomi-html-accent-2) 100%)!important;color:var(--yunomi-html-text-inverse)!important;font-weight:700}",
  #|        "#yunomi-html-card,#yunomi-html-submit-card{position:fixed;z-index:2147483647;min-width:280px;max-width:360px;background:var(--yunomi-html-card-bg);color:var(--yunomi-html-text);border:1px solid var(--yunomi-html-border);border-radius:16px;padding:12px;box-shadow:var(--yunomi-html-shadow);font:13px var(--yunomi-html-font);letter-spacing:0}",
  #|        "#yunomi-html-card textarea,#yunomi-html-submit-card textarea{width:100%;height:88px;box-sizing:border-box;border-radius:8px;border:1px solid var(--yunomi-html-border);background:var(--yunomi-html-input-bg);color:var(--yunomi-html-text);padding:9px 10px;font:13px var(--yunomi-html-font);resize:vertical;outline:none}",
  #|        "#yunomi-html-submit-card{right:16px;top:64px}",
  #|        "#yunomi-html-submit-card .choices{display:flex;gap:8px;margin:8px 0}",
  #|        "#yunomi-html-submit-card label{display:inline-flex;align-items:center;gap:5px;color:var(--yunomi-html-muted)}",
  #|        "#yunomi-html-card .meta{font-size:11px;color:var(--yunomi-html-muted);margin:0 0 8px 0;word-break:break-all}"
  #|      ].join("\\n");
  #|      document.documentElement.appendChild(style);
  #|      const bar = document.createElement("div");
  #|      bar.id = "yunomi-html-bar";
  #|      bar.innerHTML = '<strong>🍵 yunomi html</strong><span id="yunomi-html-count">0</span><button id="yunomi-html-toggle">Comment mode</button><button id="yunomi-html-submit">Submit &amp; Exit</button>';
  #|      document.documentElement.appendChild(bar);
  #|      const publishComments = () => {
  #|        if (window.parent !== window) window.parent.postMessage({ type: "yunomi-html-comments", comments }, location.origin);
  #|      };
  #|      const isUi = (el) => !!el.closest?.("#yunomi-html-bar,#yunomi-html-card,#yunomi-html-submit-card");
  #|      const cssEscape = (value) => (window.CSS && CSS.escape) ? CSS.escape(value) : String(value).replace(/[^a-zA-Z0-9_-]/g, "\\\\$&");
  #|      const selectorFor = (el) => {
  #|        if (el.id && document.querySelectorAll("#" + cssEscape(el.id)).length === 1) return "#" + cssEscape(el.id);
  #|        const parts = [];
  #|        let node = el;
  #|        while (node && node.nodeType === 1 && node !== document.documentElement) {
  #|          let part = node.localName.toLowerCase();
  #|          const classes = [...node.classList].filter(c => !c.startsWith("yunomi-html-")).slice(0, 2);
  #|          if (classes.length) part += "." + classes.map(cssEscape).join(".");
  #|          const parent = node.parentElement;
  #|          if (parent) {
  #|            const same = [...parent.children].filter(c => c.localName === node.localName);
  #|            if (same.length > 1) part += ":nth-of-type(" + (same.indexOf(node) + 1) + ")";
  #|          }
  #|          parts.unshift(part);
  #|          const candidate = parts.join(" > ");
  #|          if (document.querySelectorAll(candidate).length === 1) return candidate;
  #|          node = parent;
  #|        }
  #|        return parts.join(" > ");
  #|      };
  #|      const elementText = (el) => (el.innerText || el.textContent || "").replace(/\\s+/g, " ").trim().slice(0, 500);
  #|      const boundsFor = (el) => {
  #|        const r = el.getBoundingClientRect();
  #|        return { x: Math.round(r.x), y: Math.round(r.y), width: Math.round(r.width), height: Math.round(r.height), viewportWidth: innerWidth, viewportHeight: innerHeight };
  #|      };
  #|      const updateCount = () => { document.getElementById("yunomi-html-count").textContent = String(comments.length); };
  #|      const closeCard = () => document.getElementById("yunomi-html-card")?.remove();
  #|      const closeSubmitCard = () => document.getElementById("yunomi-html-submit-card")?.remove();
  #|      const openSubmitCard = () => {
  #|        closeSubmitCard();
  #|        const card = document.createElement("div");
  #|        card.id = "yunomi-html-submit-card";
  #|        const defaultDecision = comments.length > 0 ? "request_changes" : "approve";
  #|        card.innerHTML = '<p class="meta">Submit HTML review</p><textarea placeholder="Overall comment"></textarea><div class="choices"><label><input type="radio" name="yunomi-html-decision" value="approve"> Approve</label><label><input type="radio" name="yunomi-html-decision" value="request_changes"> Request Changes</label></div><div style="display:flex;gap:8px;justify-content:flex-end;margin-top:8px"><button data-yunomi-cancel>Cancel</button><button data-yunomi-submit>Submit</button></div>';
  #|        document.documentElement.appendChild(card);
  #|        const radio = card.querySelector('input[value="' + defaultDecision + '"]');
  #|        if (radio) radio.checked = true;
  #|        card.querySelector("[data-yunomi-cancel]").onclick = closeSubmitCard;
  #|        card.querySelector("[data-yunomi-submit]").onclick = () => {
  #|          const decision = card.querySelector("input[name='yunomi-html-decision']:checked")?.value || defaultDecision;
  #|          const summary = card.querySelector("textarea")?.value || "";
  #|          const action = decision === "approve" ? "final_approve" : "final_request_changes";
  #|          if (window.parent !== window) window.parent.postMessage({ type: "yunomi-html-submit", comments, summary, decision, action }, location.origin);
  #|        };
  #|        card.querySelector("textarea")?.focus();
  #|      };
  #|      document.addEventListener("mouseover", (event) => {
  #|        if (!enabled || isUi(event.target)) return;
  #|        active?.classList.remove("yunomi-html-hover");
  #|        active = event.target;
  #|        active.classList.add("yunomi-html-hover");
  #|      }, true);
  #|      document.addEventListener("mouseout", (event) => {
  #|        if (event.target === active) active.classList.remove("yunomi-html-hover");
  #|      }, true);
  #|      document.addEventListener("click", (event) => {
  #|        const link = event.target.closest?.("a[href]");
  #|        if (link && !isUi(link)) {
  #|          externalizeLink(link);
  #|          return;
  #|        }
  #|        if (!enabled || isUi(event.target)) return;
  #|        event.preventDefault();
  #|        event.stopPropagation();
  #|        const el = event.target;
  #|        const selector = selectorFor(el);
  #|        const rect = el.getBoundingClientRect();
  #|        closeCard();
  #|        const card = document.createElement("div");
  #|        card.id = "yunomi-html-card";
  #|        card.style.left = Math.min(Math.max(12, rect.left), innerWidth - 380) + "px";
  #|        card.style.top = Math.min(Math.max(12, rect.bottom + 8), innerHeight - 190) + "px";
  #|        card.innerHTML = '<p class="meta"></p><textarea placeholder="Comment for this element"></textarea><div style="display:flex;gap:8px;justify-content:flex-end;margin-top:8px"><button data-yunomi-cancel>Cancel</button><button data-yunomi-save>Save</button></div>';
  #|        card.querySelector(".meta").textContent = selector;
  #|        document.documentElement.appendChild(card);
  #|        card.querySelector("textarea").focus();
  #|        card.querySelector("[data-yunomi-cancel]").onclick = closeCard;
  #|        card.querySelector("[data-yunomi-save]").onclick = () => {
  #|          const text = card.querySelector("textarea").value.trim();
  #|          if (!text) return;
  #|          comments.push({ row: 0, col: 0, text, selector, value: elementText(el), bounds: boundsFor(el) });
  #|          el.classList.add("yunomi-html-pin");
  #|          updateCount();
  #|          publishComments();
  #|          closeCard();
  #|        };
  #|      }, true);
  #|      document.getElementById("yunomi-html-toggle").onclick = () => {
  #|        enabled = !enabled;
  #|        document.getElementById("yunomi-html-toggle").textContent = enabled ? "Comment mode" : "Browsing mode";
  #|        active?.classList.remove("yunomi-html-hover");
  #|      };
  #|      publishComments();
  #|      document.getElementById("yunomi-html-submit").onclick = () => {
  #|        openSubmitCard();
  #|      };
  #|    })();`;
  #|    const inject = (html) => {
  #|      const tag = `<script data-yunomi-html="${instanceId}">${overlayScript.replaceAll("</script", "<\\\\/script")}</script>`;
  #|      return /<\/body>/i.test(html) ? html.replace(/<\/body>/i, tag + "</body>") : html + tag;
  #|    };
  #|    const shell = () => `<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>yunomi html - ${htmlEscape(filename)}</title><style>html,body{margin:0;height:100%;font:13px system-ui,-apple-system,sans-serif;background:#f6faf0;color:#3b2d20}header{height:44px;box-sizing:border-box;display:flex;align-items:center;justify-content:space-between;padding:8px 14px;border-bottom:1px solid #d7e2c4;background:rgba(246,250,240,.94)}strong{font-size:14px}span{color:#87735b}iframe{display:block;width:100%;height:calc(100vh - 44px);border:0;background:white}</style></head><body><header><strong>${htmlEscape(filename)}</strong><span>HTML preview</span></header><iframe id="yunomi-html-frame" sandbox="allow-scripts allow-same-origin allow-popups" src="/__yunomi_html_target"></iframe><script>window.addEventListener("message", event => { if (event.origin !== location.origin || event.data?.type !== "yunomi-html-submit") return; const comments = Array.isArray(event.data.comments) ? event.data.comments : []; const decision = event.data.decision || (comments.length > 0 ? "request_changes" : "approve"); const action = event.data.action || (decision === "approve" ? "final_approve" : "final_request_changes"); fetch("/exit", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ action, decision, summary: event.data.summary || "", comments }) }).then(() => { window.close(); setTimeout(() => location.replace("about:blank"), 400); }); });</script></body></html>`;
  #|    const sendFile = (res, target) => {
  #|      const ext = path.extname(target);
  #|      res.writeHead(200, { "Content-Type": mime(ext), "Cache-Control": "no-store" });
  #|      fs.createReadStream(target).pipe(res);
  #|    };
  #|    const listen = (candidatePort, attempt) => {
  #|    let boundPort = candidatePort;
  #|    const server = http.createServer((req, res) => {
  #|      const reqUrl = new URL(req.url || "/", "http://127.0.0.1");
  #|      if (req.method === "GET" && reqUrl.pathname === "/healthz") {
  #|        res.writeHead(200, { "Content-Type": "application/json" });
  #|        res.end('{"ok":true,"mode":"html"}');
  #|        return;
  #|      }
  #|      if (req.method === "GET" && (reqUrl.pathname === "/" || reqUrl.pathname === "/index.html")) {
  #|        res.writeHead(200, { "Content-Type": "text/html; charset=utf-8", "Cache-Control": "no-store" });
  #|        res.end(shell());
  #|        return;
  #|      }
  #|      if (req.method === "GET" && reqUrl.pathname === "/__yunomi_html_target") {
  #|        const body = inject(fs.readFileSync(resolvedFile, "utf8"));
  #|        res.writeHead(200, { "Content-Type": "text/html; charset=utf-8", "Content-Length": Buffer.byteLength(body), "Cache-Control": "no-store" });
  #|        res.end(body);
  #|        return;
  #|      }
  #|      if (req.method === "POST" && reqUrl.pathname === "/exit") {
  #|        const chunks = [];
  #|        req.on("data", chunk => chunks.push(chunk));
  #|        req.on("end", () => {
  #|          let payload = {};
  #|          try { payload = JSON.parse(Buffer.concat(chunks).toString("utf8")); } catch (e) {}
  #|          persistReview(JSON.stringify(payload));
  #|          process.stdout.write(toYaml(payload));
  #|          res.writeHead(200, { "Content-Type": "application/json" });
  #|          res.end('{"ok":true}', () => server.close(() => {
  #|            onFinished(boundPort);
  #|            process.exit(0);
  #|          }));
  #|        });
  #|        return;
  #|      }
  #|      if (req.method === "GET" || req.method === "HEAD") {
  #|        let rel;
  #|        try {
  #|          rel = decodeURIComponent(reqUrl.pathname);
  #|          while (rel.startsWith("/")) rel = rel.slice(1);
  #|        } catch (e) { rel = ""; }
  #|        const target = path.resolve(baseDir, rel);
  #|        if (!rel || !underBase(target) || !fs.existsSync(target) || !fs.statSync(target).isFile()) {
  #|          res.writeHead(rel && !underBase(target) ? 403 : 404, { "Content-Type": "text/plain" });
  #|          res.end(rel && !underBase(target) ? "Forbidden" : "Not Found");
  #|          return;
  #|        }
  #|        if (req.method === "HEAD") {
  #|          const stat = fs.statSync(target);
  #|          res.writeHead(200, { "Content-Type": mime(path.extname(target)), "Content-Length": stat.size, "Cache-Control": "no-store" });
  #|          res.end();
  #|        } else {
  #|          sendFile(res, target);
  #|        }
  #|        return;
  #|      }
  #|      res.writeHead(404, { "Content-Type": "text/plain" });
  #|      res.end("Not Found");
  #|    });
  #|    server.listen(candidatePort, host, () => {
  #|      boundPort = Number(server.address()?.port || candidatePort);
  #|      onListening(boundPort);
  #|      const displayHost = host === "0.0.0.0" ? "127.0.0.1" : host;
  #|      const url = `http://${displayHost}:${boundPort}`;
  #|      console.log(`yunomi html previewing ${resolvedFile} at ${url}`);
  #|      if (!noOpen) {
  #|        if (process.platform === "darwin") childProcess.spawn("open", [url], { detached: true, stdio: "ignore" }).unref();
  #|        else if (process.platform === "win32") childProcess.spawn("cmd", ["/c", "start", url], { detached: true, stdio: "ignore" }).unref();
  #|        else childProcess.spawn("xdg-open", [url], { detached: true, stdio: "ignore" }).unref();
  #|      }
  #|    });
  #|    server.on("error", err => {
  #|      if (err?.code === "EADDRINUSE" && candidatePort !== 0) {
  #|        if (attempt + 1 < maxPortAttempts) {
  #|          console.log(`Port ${candidatePort} in use, trying ${candidatePort + 1}...`);
  #|          listen(candidatePort + 1, attempt + 1);
  #|        } else {
  #|          console.log(`All ${maxPortAttempts} candidate ports are busy; asking the OS for an ephemeral port`);
  #|          listen(0, attempt + 1);
  #|        }
  #|      } else {
  #|        console.error("yunomi html: " + err.message);
  #|        onFinished(0);
  #|        process.exit(1);
  #|      }
  #|    });
  #|    };
  #|    listen(port, 0);
  #|  }).catch(err => {
  #|    console.error("yunomi html: " + err.message);
  #|    onFinished(0);
  #|    process.exit(1);
  #|  });
  #|}

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

///|
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
  #|    return (obj.comments || []).map(c => [
  #|      String(c.row ?? 0),
  #|      String(c.col ?? 0),
  #|      c.text || "",
  #|      c.value || c.element_text || "",
  #|      c.image || "",
  #|      String(c.end_row ?? c.row ?? 0),
  #|      String(c.end_col ?? c.col ?? 0),
  #|      c.selector || "",
  #|      c.bounds ? JSON.stringify(c.bounds) : "",
  #|      c.element_text || c.value || "",
  #|    ]);
  #|  } catch(e) { return []; }
  #|}

///|
extern "js" fn json_with_comment_image_paths(
  json_str : String,
  paths : Array[String],
  attachment_refs : Array[String],
) -> String =
  #|(s, paths, attachmentRefs) => {
  #|  try {
  #|    const obj = JSON.parse(s || "{}");
  #|    obj.comments = Array.isArray(obj.comments) ? obj.comments : [];
  #|    obj.comments.forEach((comment, index) => {
  #|      const imagePath = Array.isArray(paths) ? String(paths[index] || "") : "";
  #|      if (imagePath) comment.imagePath = imagePath;
  #|      const attachment = Array.isArray(attachmentRefs) ? String(attachmentRefs[index] || "") : "";
  #|      if (attachment) comment.attachments = [attachment];
  #|    });
  #|    return JSON.stringify(obj);
  #|  } catch(e) {
  #|    return s;
  #|  }
  #|}

///|
extern "js" fn json_parse_first_file(json_str : String) -> String =
  #|(s) => { try { const o = JSON.parse(s); return String((o.files || [])[0] || ""); } catch(e) { return ""; } }

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
extern "js" fn js_obj_stderr(obj : JsValue) -> String =
  #|(obj) => obj?.stderr || ""

///|
extern "js" fn js_obj_status(obj : JsValue) -> Int =
  #|(obj) => {
  #|  const status = Number(obj?.status);
  #|  return Number.isFinite(status) ? status : 1;
  #|}

///|
extern "js" fn js_obj_error_message(obj : JsValue) -> String =
  #|(obj) => obj?.error?.message || ""

///|
extern "js" fn js_inject_before_body_end(
  html : String,
  fragment : String,
) -> String =
  #|(html, fragment) => {
  #|  const text = String(html);
  #|  const header = text.indexOf("</header>");
  #|  if (header >= 0) {
  #|    const idx = header + "</header>".length;
  #|    return text.slice(0, idx) + fragment + text.slice(idx);
  #|  }
  #|  const body = text.lastIndexOf("</body>");
  #|  return body >= 0 ? text.slice(0, body) + fragment + text.slice(body) : text + fragment;
  #|}

///|
extern "js" fn js_spawn_opts_pipe() -> JsValue =
  #|() => ({ stdio: ["pipe", "pipe", "pipe"] })

///|
extern "js" fn js_spawn_opts_utf8_pipe() -> JsValue =
  #|() => ({ encoding: "utf8", stdio: ["pipe", "pipe", "pipe"] })

///|
extern "js" fn js_spawn_opts_utf8_pipe_cwd(cwd : String) -> JsValue =
  #|(cwd) => ({ cwd, encoding: "utf8", stdio: ["pipe", "pipe", "pipe"] })

///|
extern "js" fn js_array_from_strings(args : Array[String]) -> JsValue =
  #|(args) => Array.from(args)

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
extern "js" fn js_sanitize_branch(branch : String) -> String =
  #|(branch) => String(branch || "no-branch").replace(/[^A-Za-z0-9._-]+/g, "-").replace(/^-+|-+$/g, "") || "no-branch"

///|
fn git_stdout(cwd : String, args_json : String) -> String {
  try_call_string(
    fn() {
      js_obj_stdout(
        child_spawn_sync(
          "git",
          js_parse_json(args_json),
          js_spawn_opts_utf8_pipe_cwd(cwd),
        ),
      )
    },
    "",
  )
}

///|
fn trim_ascii(s : String) -> String {
  s.trim().to_owned()
}

///|
fn realpath_or_resolve(path : String) -> String {
  try_call_string(fn() { fs_realpath_sync(path) }, path_resolve(path))
}

///|
fn git_root_for(path : String) -> String {
  let dir = if exists_sync(path) && is_file_sync(path) {
    path_dirname(path)
  } else {
    path
  }
  let out = git_stdout(dir, "[\"rev-parse\",\"--show-toplevel\"]")
  let root = trim_ascii(out)
  if root.length() > 0 {
    realpath_or_resolve(root)
  } else {
    realpath_or_resolve(dir)
  }
}

///|
fn git_branch_for(root : String) -> String {
  let out = git_stdout(root, "[\"branch\",\"--show-current\"]")
  let branch = trim_ascii(out)
  if branch.length() > 0 {
    branch
  } else {
    "no-branch"
  }
}

///|
fn review_dir_for_file(file_path : String) -> String {
  let override_dir = get_env_var("YUNOMI_REVIEW_DIR")
  if override_dir.length() > 0 {
    return override_dir
  }
  let root = git_root_for(file_path)
  let branch = js_sanitize_branch(git_branch_for(root))
  path_join(path_join(path_join(root, ".yunomi"), "reviews"), branch)
}

///|
fn review_json_path_for_file(file_path : String) -> String {
  path_join(review_dir_for_file(file_path), "review.json")
}

///|
fn review_server_path_for_file(file_path : String) -> String {
  path_join(review_dir_for_file(file_path), "server.json")
}

///|
fn review_signal_path_for_file(file_path : String) -> String {
  path_join(review_dir_for_file(file_path), "go.signal")
}

///|
fn review_dir_for_cwd() -> String {
  let override_dir = get_env_var("YUNOMI_REVIEW_DIR")
  if override_dir.length() > 0 {
    return override_dir
  }
  let cwd = path_resolve(".")
  let root = git_root_for(cwd)
  let branch = js_sanitize_branch(git_branch_for(root))
  path_join(path_join(path_join(root, ".yunomi"), "reviews"), branch)
}

///|
fn review_json_path_for_cwd() -> String {
  path_join(review_dir_for_cwd(), "review.json")
}

///|
extern "js" fn js_external_review_submit(
  existing_json : String,
  body : String,
  file : String,
  branch : String,
  now : String,
) -> String =
  #|(existingJson, body, file, branch, now) => {
  #|  let review;
  #|  let submit;
  #|  try { review = JSON.parse(existingJson || "{}"); } catch (_) { review = {}; }
  #|  try { submit = JSON.parse(body || "{}"); } catch (_) { submit = {}; }
  #|  review.version = 1;
  #|  review.branch = String(review.branch || branch || "no-branch");
  #|  review.files = Array.isArray(review.files) ? review.files : [];
  #|  if (!review.files.includes(file)) review.files.push(file);
  #|  review.rounds = Array.isArray(review.rounds) ? review.rounds : [];
  #|  if (review.rounds.length === 0) {
  #|    review.rounds.push({ round: 1, started_at: now, submitted_at: null, decision: null, summary: "" });
  #|  }
  #|  const current = review.rounds.reduce((a, b) => (Number(b.round || 0) > Number(a.round || 0) ? b : a), review.rounds[0]);
  #|  current.submitted_at = now;
  #|  current.decision = submit.decision || null;
  #|  current.summary = String(submit.summary || "");
  #|  review.comments = Array.isArray(review.comments) ? review.comments : [];
  #|  const round = Number(current.round || review.rounds.length || 1);
  #|  let seq = review.comments.filter(comment => Number(comment?.round || 0) === round).length + 1;
  #|  for (const raw of Array.isArray(submit.comments) ? submit.comments : []) {
  #|    const row = Math.max(0, Number(raw?.row || 0));
  #|    const col = Math.max(0, Number(raw?.col || 0));
  #|    const elementText = String(raw?.element_text || raw?.value || "");
  #|    const snippet = String(raw?.snippet || elementText);
  #|    const before = String(raw?.context_before || "");
  #|    const after = String(raw?.context_after || "");
  #|    const bounds = raw?.bounds == null ? "" : (typeof raw.bounds === "string" ? raw.bounds : JSON.stringify(raw.bounds));
  #|    const attachments = Array.isArray(raw?.attachments) ? raw.attachments.map(String) : [];
  #|    review.comments.push({
  #|      id: `c-${round}-${seq++}`,
  #|      file,
  #|      row,
  #|      col,
  #|      end_row: Math.max(0, Number(raw?.end_row ?? row)),
  #|      end_col: Math.max(0, Number(raw?.end_col ?? col)),
  #|      line: row + 1,
  #|      round,
  #|      text: String(raw?.text || ""),
  #|      author: "human",
  #|      status: "unresolved",
  #|      replies: [],
  #|      snippet,
  #|      context_before: before,
  #|      context_after: after,
  #|      selector: String(raw?.selector || ""),
  #|      bounds,
  #|      element_text: elementText,
  #|      attachments,
  #|      anchor: { snippet, context_before: before, context_after: after }
  #|    });
  #|  }
  #|  return JSON.stringify(review, null, 2) + "\n";
  #|}

///|
fn persist_external_review(
  review_path : String,
  file : String,
  body : String,
) -> Unit {
  let parent = path_dirname(review_path)
  if !exists_sync(parent) {
    mkdir_sync(parent, mkdir_recursive_opts())
  }
  let cwd = path_resolve(".")
  let branch = git_branch_for(git_root_for(cwd))
  write_file_secure(
    review_path,
    js_external_review_submit(
      read_file_safe(review_path),
      body,
      file,
      branch,
      iso_now(),
    ),
  )
}

///|
fn review_json_path_for_id(review_id : String) -> String {
  let override_dir = get_env_var("YUNOMI_REVIEW_DIR")
  let reviews_root = if override_dir.length() > 0 {
    override_dir
  } else {
    let cwd = path_resolve(".")
    path_join(path_join(git_root_for(cwd), ".yunomi"), "reviews")
  }
  path_join(
    path_join(reviews_root, js_sanitize_branch(review_id)),
    "review.json",
  )
}

///|
fn review_server_path_for_cwd() -> String {
  path_join(review_dir_for_cwd(), "server.json")
}

///|
fn review_signal_path_for_cwd() -> String {
  path_join(review_dir_for_cwd(), "go.signal")
}

///|
fn review_snapshot_path(file_path : String, round : Int) -> String {
  path_join(review_dir_for_file(file_path), "round-\{round}-submitted.txt")
}

///|
fn review_display_file(file_path : String) -> String {
  let root = git_root_for(file_path)
  let rel = path_relative(root, realpath_or_resolve(file_path))
  if rel.length() > 0 && !rel.has_prefix("..") {
    rel
  } else {
    path_basename(file_path)
  }
}

///|
fn ensure_review_dir(file_path : String) -> Unit {
  let dir = review_dir_for_file(file_path)
  if !exists_sync(dir) {
    mkdir_sync(dir, mkdir_recursive_opts())
  }
}

///|
extern "js" fn js_review_init_json(
  version : Int,
  branch : String,
  file : String,
  started_at : String,
) -> String =
  #|(version, branch, file, startedAt) => JSON.stringify({
  #|  version,
  #|  branch,
  #|  files: [file],
  #|  rounds: [{ round: 1, started_at: startedAt, submitted_at: null, decision: null, summary: "" }],
  #|  comments: []
  #|}, null, 2)

///|
fn ensure_review_state(file_path : String) -> Unit {
  ensure_review_dir(file_path)
  let review_path = review_json_path_for_file(file_path)
  if !exists_sync(review_path) {
    let root = git_root_for(file_path)
    let branch = git_branch_for(root)
    write_file_secure(
      review_path,
      js_review_init_json(1, branch, review_display_file(file_path), iso_now()),
    )
  }
}

///|
extern "js" fn js_review_update_viewed_files(
  json : String,
  viewed_json : String,
) -> String =
  #|(json, viewedJson) => {
  #|  let review;
  #|  let viewed;
  #|  try { review = JSON.parse(json || "{}"); } catch { review = {}; }
  #|  try { viewed = JSON.parse(viewedJson || "{}"); } catch { viewed = {}; }
  #|  review.viewed_files = viewed && typeof viewed === "object" && !Array.isArray(viewed) ? viewed : {};
  #|  return JSON.stringify(review, null, 2);
  #|}

///|
fn update_review_viewed_files(file_path : String, viewed_json : String) -> Unit {
  ensure_review_state(file_path)
  let review_path = review_json_path_for_file(file_path)
  write_file_secure(
    review_path,
    js_review_update_viewed_files(read_file_safe(review_path), viewed_json),
  )
}

///|
fn write_review_server(
  file_path : String,
  port : Int,
  notify_pane : String,
) -> Unit {
  ensure_review_state(file_path)
  let data = "{\"pid\":" +
    process_pid().to_string() +
    ",\"port\":" +
    port.to_string() +
    ",\"file\":" +
    json_encode_value(path_resolve(file_path)) +
    ",\"notify_pane\":" +
    json_encode_value(notify_pane) +
    ",\"updated_at\":" +
    json_encode_value(iso_now()) +
    "}"
  write_file_secure(review_server_path_for_file(file_path), data)
}

///|
extern "js" fn js_review_submit_update(
  json : String,
  body : String,
  file : String,
  source_lines : Array[String],
) -> String =
  #|(json, body, file, sourceLines) => {
  #|  const review = JSON.parse(json || "{}");
  #|  const submit = JSON.parse(body || "{}");
  #|  review.version = 1;
  #|  review.files = review.files && review.files.length ? review.files : [file];
  #|  review.rounds = Array.isArray(review.rounds) ? review.rounds : [];
  #|  if (review.rounds.length === 0) review.rounds.push({ round: 1, started_at: new Date().toISOString(), submitted_at: null, decision: null, summary: "" });
  #|  const current = review.rounds.reduce((a, b) => (Number(b.round || 0) > Number(a.round || 0) ? b : a), review.rounds[0]);
  #|  current.submitted_at = new Date().toISOString();
  #|  current.decision = submit.decision || null;
  #|  current.summary = submit.summary || "";
  #|  review.comments = Array.isArray(review.comments) ? review.comments : [];
  #|  const roundNo = Number(current.round || review.rounds.length);
  #|  const summary = String(current.summary || "").trim();
  #|  if (summary) {
  #|    const id = `r-${roundNo}`;
  #|    const existingIndex = review.comments.findIndex(c => c && c.id === id);
  #|    if (existingIndex >= 0) review.comments.splice(existingIndex, 1);
  #|    review.comments.push({ id, scope: "round", file: "", line: 0, round: roundNo, text: summary, author: "human", status: "unresolved", replies: [], attachments: [] });
  #|  }
  #|  let seq = review.comments.filter(c => Number(c.round) === roundNo && c.scope !== "round").length + 1;
  #|  const lineWindow = (row, before, after) => {
  #|    const start = Math.max(0, row - before);
  #|    const end = Math.min(sourceLines.length, row + after + 1);
  #|    return sourceLines.slice(start, end).map(line => String(line || "")).join("\n");
  #|  };
  #|  const oneLineQuote = (...values) => {
  #|    const marker = " | source: ";
  #|    for (const value of values) {
  #|      const raw = String(value || "");
  #|      const idx = raw.indexOf(marker);
  #|      const quote = (idx >= 0 ? raw.slice(idx + marker.length) : raw).split(/\r?\n/, 1)[0].trim();
  #|      if (quote) return quote;
  #|    }
  #|    return "";
  #|  };
  #|  for (const c of submit.comments || []) {
  #|    const row = Number(c.row || 0);
  #|    const col = Number(c.col || 0);
  #|    const line = row + 1;
  #|    const snippet = String(c.snippet || lineWindow(row, 3, 3) || c.value || sourceLines[row] || "");
  #|    const before = String(c.context_before || lineWindow(row, 5, -1));
  #|    const after = String(c.context_after || lineWindow(row + 1, 0, 4));
  #|    const imagePath = String(c.imagePath || "");
  #|    const attachments = Array.isArray(c.attachments) ? c.attachments.map(String) : [];
  #|    const elementText = String(c.element_text || c.value || "");
  #|    const quote = oneLineQuote(c.value, c.element_text, sourceLines[row] || "");
  #|    const bounds = c.bounds == null ? "" : (typeof c.bounds === "string" ? c.bounds : JSON.stringify(c.bounds));
  #|    review.comments.push({
  #|      id: `c-${roundNo}-${seq++}`,
  #|      file,
  #|      row,
  #|      col,
  #|      end_row: Number(c.end_row ?? row),
  #|      end_col: Number(c.end_col ?? col),
  #|      line,
  #|      round: roundNo,
  #|      text: String(c.text || ""),
  #|      quote,
  #|      author: "human",
  #|      status: "unresolved",
  #|      replies: [],
  #|      snippet,
  #|      context_before: before,
  #|      context_after: after,
  #|      selector: String(c.selector || ""),
  #|      bounds,
  #|      element_text: elementText,
  #|      attachments,
  #|      anchor: { snippet, context_before: before, context_after: after },
  #|      image_path: imagePath
  #|    });
  #|  }
  #|  return JSON.stringify(review, null, 2);
  #|}

///|
fn update_review_on_submit(
  file_path : String,
  body : String,
  source_lines : Array[String],
  round : Int,
) -> Unit {
  ensure_review_state(file_path)
  let review_path = review_json_path_for_file(file_path)
  let current = read_file_safe(review_path)
  write_file_secure(
    review_path,
    js_review_submit_update(
      current,
      body,
      review_display_file(file_path),
      source_lines,
    ),
  )
  try_call_void(fn() {
    fs_copy_file_sync(file_path, review_snapshot_path(file_path, round))
  })
}

///|
extern "js" fn js_review_send_now_update(
  json : String,
  file : String,
  id : String,
  line : Int,
  text : String,
  snippet : String,
  quote : String,
  context_before : String,
  context_after : String,
  round : Int,
  target : String,
) -> String =
  #|(json, file, id, line, text, snippet, quote, before, after, round, target) => {
  #|  const review = JSON.parse(json || "{}");
  #|  review.version = review.version || 1;
  #|  review.files = Array.isArray(review.files) && review.files.length ? review.files : [file];
  #|  if (!review.files.includes(file)) review.files.push(file);
  #|  review.rounds = Array.isArray(review.rounds) ? review.rounds : [];
  #|  if (review.rounds.length === 0) review.rounds.push({ round: 1, started_at: new Date().toISOString(), submitted_at: null, decision: null, summary: "" });
  #|  review.comments = Array.isArray(review.comments) ? review.comments : [];
  #|  const commentId = String(id || `send-now-${Date.now()}`);
  #|  const existing = review.comments.find(c => c.id === commentId);
  #|  const anchor = { snippet: String(snippet || ""), context_before: String(before || ""), context_after: String(after || "") };
  #|  const structured = {
  #|    file,
  #|    row: Math.max(0, Number(line || 1) - 1),
  #|    col: 0,
  #|    end_row: Math.max(0, Number(line || 1) - 1),
  #|    end_col: 0,
  #|    snippet: String(snippet || ""),
  #|    quote: String(quote || ""),
  #|    context_before: String(before || ""),
  #|    context_after: String(after || ""),
  #|    selector: "",
  #|    bounds: "",
  #|    element_text: String(snippet || ""),
  #|    target: String(target || ""),
  #|    attachments: []
  #|  };
  #|  if (existing) {
  #|    existing.file = existing.file || file;
  #|    Object.assign(existing, { ...structured, ...existing, attachments: Array.isArray(existing.attachments) ? existing.attachments : structured.attachments });
  #|    existing.line = Number(line || existing.line || 1);
  #|    existing.round = Number(existing.round || round || 1);
  #|    existing.text = String(text || existing.text || "");
  #|    existing.author = existing.author || "human";
  #|    existing.status = existing.status || "unresolved";
  #|    existing.replies = Array.isArray(existing.replies) ? existing.replies : [];
  #|    existing.anchor = existing.anchor || anchor;
  #|    existing.quote = String(existing.quote || structured.quote || "");
  #|    existing.send_now = true;
  #|    existing.sent_at = existing.sent_at || new Date().toISOString();
  #|  } else {
  #|    review.comments.push({
  #|      id: commentId,
  #|      ...structured,
  #|      line: Number(line || 1),
  #|      round: Number(round || 1),
  #|      text: String(text || ""),
  #|      author: "human",
  #|      status: "unresolved",
  #|      replies: [],
  #|      anchor,
  #|      send_now: true,
  #|      sent_at: new Date().toISOString()
  #|    });
  #|  }
  #|  return JSON.stringify(review, null, 2);
  #|}

///|
fn update_review_on_send_now(
  file_path : String,
  id : String,
  line : Int,
  text : String,
  target : String,
) -> Unit {
  ensure_review_state(file_path)
  let review_path = review_json_path_for_file(file_path)
  let source_lines = @core.split_to_lines(read_file_safe(file_path))
  let idx = line - 1
  let quote = @core.quote_source_line(source_lines, idx)
  let snippet = comment_snippet(source_lines, idx)
  let before = comment_context_before(source_lines, idx)
  let after = comment_context_after(source_lines, idx)
  write_file_secure(
    review_path,
    js_review_send_now_update(
      read_file_safe(review_path),
      review_display_file(file_path),
      id,
      line,
      text,
      snippet,
      quote,
      before,
      after,
      current_review_round(file_path),
      target,
    ),
  )
}

///|
fn update_review_on_cli_comment(
  file_path : String,
  _id : String,
  line : Int,
  text : String,
  author : String,
) -> Unit {
  ensure_review_state(file_path)
  let review_path = review_json_path_for_file(file_path)
  let source_lines = @core.split_to_lines(read_file_safe(file_path))
  let idx = line - 1
  let quote = @core.quote_source_line(source_lines, idx)
  let snippet = comment_snippet(source_lines, idx)
  let before = comment_context_before(source_lines, idx)
  let after = comment_context_after(source_lines, idx)
  write_file_secure(
    review_path,
    js_update_review_json(
      read_file_safe(review_path),
      current_branch(),
      review_display_file(file_path),
      line,
      text,
      author,
      snippet,
      quote,
      before,
      after,
      iso_now(),
    ),
  )
}

///|
extern "js" fn js_review_current_round(json : String) -> Int =
  #|(json) => { try { const r = JSON.parse(json).rounds || []; return Number((r[r.length - 1] || {}).round || 1); } catch(e) { return 1; } }

///|
extern "js" fn js_review_next_comment_seq(json : String, round : Int) -> Int =
  #|(json, round) => {
  #|  try {
  #|    const review = JSON.parse(json || "{}");
  #|    const comments = Array.isArray(review.comments) ? review.comments : [];
  #|    return comments.filter((comment) => Number(comment?.round || 0) === Number(round || 1)).length + 1;
  #|  } catch (_) {
  #|    return 1;
  #|  }
  #|}

///|
fn current_review_round(file_path : String) -> Int {
  ensure_review_state(file_path)
  js_review_current_round(read_file_safe(review_json_path_for_file(file_path)))
}

///|
fn next_review_comment_seq(file_path : String, round : Int) -> Int {
  ensure_review_state(file_path)
  js_review_next_comment_seq(
    read_file_safe(review_json_path_for_file(file_path)),
    round,
  )
}

///|
extern "js" fn js_review_start_next_round(
  json : String,
  current_text : String,
) -> String =
  #|(json, currentText) => {
  #|  const review = JSON.parse(json || "{}");
  #|  review.rounds = Array.isArray(review.rounds) ? review.rounds : [];
  #|  const last = review.rounds.reduce((a, b) => (Number(b.round || 0) > Number(a.round || 0) ? b : a), review.rounds[0]);
  #|  if (!last || last.submitted_at) {
  #|    const next = last ? Number(last.round || review.rounds.length) + 1 : 1;
  #|    review.rounds.push({ round: next, started_at: new Date().toISOString(), submitted_at: null, decision: null, summary: "" });
  #|  }
  #|  const lines = String(currentText || "").split(/\r?\n/);
  #|  const normalized = (value) => String(value || "").trim();
  #|  const contextLines = (value) => {
  #|    const raw = String(value || "");
  #|    return raw === "" ? [] : raw.split(/\r?\n/).map(normalized);
  #|  };
  #|  const matchingBefore = (index, context) => {
  #|    let matched = 0;
  #|    for (let offset = 1; offset <= context.length && index - offset >= 0; offset += 1) {
  #|      if (normalized(lines[index - offset]) !== context[context.length - offset]) break;
  #|      matched += 1;
  #|    }
  #|    return matched;
  #|  };
  #|  const matchingAfter = (index, context) => {
  #|    let matched = 0;
  #|    for (let offset = 1; offset <= context.length && index + offset < lines.length; offset += 1) {
  #|      if (normalized(lines[index + offset]) !== context[offset - 1]) break;
  #|      matched += 1;
  #|    }
  #|    return matched;
  #|  };
  #|  const sourceQuote = (...values) => {
  #|    for (const value of values) {
  #|      const raw = String(value || "");
  #|      const marker = " | source: ";
  #|      const source = raw.includes(marker) ? raw.slice(raw.indexOf(marker) + marker.length) : raw;
  #|      const line = normalized(source.split(/\r?\n/, 1)[0]);
  #|      if (line) return line;
  #|    }
  #|    return "";
  #|  };
  #|  const continuousSnippetCandidates = (snippet) => {
  #|    const candidates = [];
  #|    for (let start = 0; start + snippet.length <= lines.length; start += 1) {
  #|      if (!snippet.every((line, offset) => normalized(lines[start + offset]) === line)) continue;
  #|      for (let offset = 0; offset < snippet.length; offset += 1) candidates.push(start + offset);
  #|    }
  #|    return candidates;
  #|  };
  #|  for (const c of review.comments || []) {
  #|    if (c.status !== "unresolved") continue;
  #|    const anchor = c.anchor && typeof c.anchor === "object" ? c.anchor : {};
  #|    const snippet = contextLines(anchor.snippet || c.snippet);
  #|    const quote = sourceQuote(c.quote, c.element_text, c.value);
  #|    const before = contextLines(c.context_before || anchor.context_before);
  #|    const after = contextLines(c.context_after || anchor.context_after);
  #|    const quoteCandidates = quote ? lines.map((line, index) => normalized(line) === quote ? index : -1).filter(index => index >= 0) : [];
  #|    const snippetCandidates = snippet.length > 0 ? continuousSnippetCandidates(snippet) : [];
  #|    const candidateIndexes = quoteCandidates.length > 0
  #|      ? quoteCandidates
  #|      : snippetCandidates.length > 0
  #|        ? snippetCandidates
  #|        : lines.map((_, index) => index);
  #|    let candidates = candidateIndexes.map(index => ({ index, before: matchingBefore(index, before), after: matchingAfter(index, after) }));
  #|    const contextOnly = quoteCandidates.length === 0;
  #|    if (contextOnly) {
  #|      if (before.length > 0 && after.length > 0) candidates = candidates.filter(candidate => candidate.before > 0 && candidate.after > 0);
  #|      else if (before.length > 0) candidates = candidates.filter(candidate => candidate.before > 0);
  #|      else if (after.length > 0) candidates = candidates.filter(candidate => candidate.after > 0);
  #|    }
  #|    if (candidates.length === 0) {
  #|      c.unanchored = true;
  #|      continue;
  #|    }
  #|    const bestScore = Math.max(...candidates.map(candidate => candidate.before + candidate.after));
  #|    const scoreCandidates = candidates.filter(candidate => candidate.before + candidate.after === bestScore);
  #|    const bestBothSides = Math.max(...scoreCandidates.map(candidate => candidate.before > 0 && candidate.after > 0 ? 1 : 0));
  #|    const matches = scoreCandidates.filter(candidate => (candidate.before > 0 && candidate.after > 0 ? 1 : 0) === bestBothSides);
  #|    if (matches.length !== 1 || (contextOnly && bestScore === 0)) {
  #|      c.unanchored = true;
  #|      continue;
  #|    }
  #|    const previousRow = Math.max(0, Number(c.row ?? ((Number(c.line || 1) || 1) - 1)));
  #|    const previousEndRow = Math.max(previousRow, Number(c.end_row ?? previousRow));
  #|    const row = matches[0].index;
  #|    c.row = row;
  #|    c.line = row + 1;
  #|    c.end_row = row + (previousEndRow - previousRow);
  #|    c.unanchored = false;
  #|  }
  #|  return JSON.stringify(review, null, 2);
  #|}

///|
fn start_next_review_round(file_path : String) -> Unit {
  ensure_review_state(file_path)
  let review_path = review_json_path_for_file(file_path)
  let current = read_file_safe(review_path)
  let text = read_file_safe(file_path)
  write_file_secure(review_path, js_review_start_next_round(current, text))
}

///|
extern "js" fn js_review_response_json(
  review_json : String,
  current_text : String,
  previous_text : String,
  gate_enabled : Bool,
  current_file : String,
) -> String =
  #|(reviewJson, currentText, previousText, gateEnabled, currentFile) => {
  #|  let review;
  #|  try { review = JSON.parse(reviewJson || "{}"); } catch { review = {}; }
  #|  const normalizeComment = (comment) => {
  #|    const c = comment && typeof comment === "object" ? comment : {};
  #|    const anchor = c.anchor && typeof c.anchor === "object" ? c.anchor : {};
  #|    const row = Math.max(0, Number(c.row ?? ((Number(c.line || 1) || 1) - 1)));
  #|    const col = Math.max(0, Number(c.col ?? 0));
  #|    const snippet = String(c.snippet ?? anchor.snippet ?? c.value ?? "");
  #|    const before = String(c.context_before ?? anchor.context_before ?? "");
  #|    const after = String(c.context_after ?? anchor.context_after ?? "");
  #|    const imagePath = String(c.image_path || c.imagePath || "");
  #|    const attachments = Array.isArray(c.attachments) ? c.attachments.map(String) : [];
  #|    return {
  #|      ...c,
  #|      file: String(c.file || ""),
  #|      row,
  #|      col,
  #|      end_row: Math.max(0, Number(c.end_row ?? row)),
  #|      end_col: Math.max(0, Number(c.end_col ?? col)),
  #|      snippet,
  #|      context_before: before,
  #|      context_after: after,
  #|      selector: String(c.selector || ""),
  #|      bounds: c.bounds == null ? "" : (typeof c.bounds === "string" ? c.bounds : JSON.stringify(c.bounds)),
  #|      element_text: String(c.element_text ?? c.value ?? snippet),
  #|      attachments,
  #|      anchor: { snippet, context_before: before, context_after: after },
  #|      image_path: imagePath
  #|    };
  #|  };
  #|  review.comments = Array.isArray(review.comments) ? review.comments.map(normalizeComment) : [];
  #|  const currentComments = review.comments.filter(c => c.scope === "round" || c.file === currentFile);
  #|  const prev = String(previousText || "").split(/\r?\n/);
  #|  const curr = String(currentText || "").split(/\r?\n/);
  #|  const max = Math.max(prev.length, curr.length);
  #|  const lines = [];
  #|  for (let i = 0; i < max; i++) {
  #|    if ((prev[i] || "") !== (curr[i] || "")) {
  #|      if (prev[i] != null && prev[i] !== "") lines.push({ kind: "deletion", line: i + 1, text: prev[i] });
  #|      if (curr[i] != null && curr[i] !== "") lines.push({ kind: "addition", line: i + 1, text: curr[i] });
  #|    }
  #|  }
  #|  const currentRound = Number(((review.rounds || []).reduce((a, b) => (Number(b.round || 0) > Number(a.round || 0) ? b : a), (review.rounds || [])[0]) || {}).round || 1);
  #|  const actionable = (c) => c && c.scope !== "round";
  #|  const unresolved = currentComments.filter(c => actionable(c) && c.status !== "resolved").length;
  #|  const gateUnresolved = gateEnabled ? currentComments.filter(c => actionable(c) && c.status !== "resolved" && Number(c.round || 0) < currentRound).length : 0;
  #|  return JSON.stringify({ review: { ...review, comments: currentComments }, diff: { lines }, unresolved_count: unresolved, gate_unresolved_count: gateUnresolved, is_loop: !!gateEnabled });
  #|}

///|
fn review_state_response(file_path : String, gate_enabled : Bool) -> String {
  ensure_review_state(file_path)
  let review_json = read_file_safe(review_json_path_for_file(file_path))
  let round = current_review_round(file_path)
  let prev_path = review_snapshot_path(file_path, round - 1)
  let previous_text = if exists_sync(prev_path) {
    read_file_safe(prev_path)
  } else {
    ""
  }
  js_review_response_json(
    review_json,
    read_file_safe(file_path),
    previous_text,
    gate_enabled,
    review_display_file(file_path),
  )
}

///|
extern "js" fn js_review_resolve(json : String, id : String) -> String =
  #|(json, id) => {
  #|  const review = JSON.parse(json || "{}");
  #|  for (const c of review.comments || []) {
  #|    if (c.id === id && c.scope !== "round") c.status = "resolved";
  #|  }
  #|  return JSON.stringify(review, null, 2);
  #|}

///|
fn resolve_review_comment(file_path : String, id : String) -> Unit {
  ensure_review_state(file_path)
  let review_path = review_json_path_for_file(file_path)
  write_file_secure(
    review_path,
    js_review_resolve(read_file_safe(review_path), id),
  )
}

///|
extern "js" fn js_review_reply(
  json : String,
  id : String,
  text : String,
  author : String,
  attachment : String,
) -> String =
  #|(json, id, text, author, attachment) => {
  #|  const review = JSON.parse(json || "{}");
  #|  const rounds = Array.isArray(review.rounds) ? review.rounds : [];
  #|  const latestRound = (rs) => rs.reduce((a, b) => (Number(b.round || 0) > Number(a.round || 0) ? b : a), rs[0] || {});
  #|  const currentRound = Number(latestRound(rounds).round || 1);
  #|  review.comments = Array.isArray(review.comments) ? review.comments : [];
  #|  for (const c of review.comments) {
  #|    if (c.id === id) {
  #|      c.replies = Array.isArray(c.replies) ? c.replies : [];
  #|      c.replies.push({
  #|        author: author || "agent",
  #|        round: currentRound,
  #|        text: String(text || ""),
  #|        attachments: attachment ? [String(attachment)] : []
  #|      });
  #|      break;
  #|    }
  #|  }
  #|  return JSON.stringify(review, null, 2);
  #|}

///|
extern "js" fn review_comment_is_replyable(json : String, id : String) -> Bool =
  #|(json, id) => {
  #|  try {
  #|    const review = JSON.parse(json || "{}");
  #|    const comment = (review.comments || []).find(c => c && c.id === id);
  #|    return !!comment && (comment.scope === "round" || comment.status !== "resolved");
  #|  } catch (_) {
  #|    return false;
  #|  }
  #|}

///|
extern "js" fn review_can_create_global_comment(json : String) -> Bool =
  #|(json) => {
  #|  try {
  #|    const review = JSON.parse(json || "{}");
  #|    const threads = (review.comments || []).filter(c => c && c.scope === "round");
  #|    const latest = threads[threads.length - 1];
  #|    return !latest;
  #|  } catch (_) {
  #|    return false;
  #|  }
  #|}

///|
extern "js" fn next_global_comment_id(json : String) -> String =
  #|(json) => {
  #|  const review = JSON.parse(json || "{}");
  #|  const rounds = Array.isArray(review.rounds) ? review.rounds : [];
  #|  const latestRound = (rs) => rs.reduce((a, b) => (Number(b.round || 0) > Number(a.round || 0) ? b : a), rs[0] || {});
  #|  const round = Number(latestRound(rounds).round || 1);
  #|  const ids = new Set((review.comments || []).map(c => String(c?.id || "")));
  #|  let sequence = 1;
  #|  while (ids.has(`r-${round}-${sequence}`)) sequence += 1;
  #|  return `r-${round}-${sequence}`;
  #|}

///|
extern "js" fn js_review_create_global_comment(
  json : String,
  id : String,
  text : String,
  author : String,
  attachment : String,
) -> String =
  #|(json, id, text, author, attachment) => {
  #|  const review = JSON.parse(json || "{}");
  #|  const rounds = Array.isArray(review.rounds) ? review.rounds : [];
  #|  const latestRound = (rs) => rs.reduce((a, b) => (Number(b.round || 0) > Number(a.round || 0) ? b : a), rs[0] || {});
  #|  const currentRound = Number(latestRound(rounds).round || 1);
  #|  review.comments = Array.isArray(review.comments) ? review.comments : [];
  #|  review.comments.push({
  #|    id,
  #|    scope: "round",
  #|    file: "",
  #|    line: 0,
  #|    round: currentRound,
  #|    text: String(text || ""),
  #|    author: author || "human",
  #|    status: "unresolved",
  #|    replies: [],
  #|    attachments: attachment ? [String(attachment)] : []
  #|  });
  #|  return JSON.stringify(review, null, 2);
  #|}

///|
fn create_global_review_comment(
  file_path : String,
  id : String,
  text : String,
  author : String,
  attachment : String,
) -> Unit {
  ensure_review_state(file_path)
  let review_path = review_json_path_for_file(file_path)
  write_file_secure(
    review_path,
    js_review_create_global_comment(
      read_file_safe(review_path),
      id,
      text,
      author,
      attachment,
    ),
  )
}

///|
fn reply_review_comment(
  file_path : String,
  id : String,
  text : String,
  author : String,
  attachment : String,
) -> Unit {
  ensure_review_state(file_path)
  let review_path = review_json_path_for_file(file_path)
  write_file_secure(
    review_path,
    js_review_reply(read_file_safe(review_path), id, text, author, attachment),
  )
}

///|
extern "js" fn review_comment_reply_count(json : String, id : String) -> Int =
  #|(json, id) => {
  #|  try {
  #|    const review = JSON.parse(json || "{}");
  #|    const comment = (review.comments || []).find(c => c && c.id === id);
  #|    return Array.isArray(comment?.replies) ? comment.replies.length : 0;
  #|  } catch (_) {
  #|    return 0;
  #|  }
  #|}

///|
extern "js" fn safe_attachment_name_component(value : String) -> String =
  #|(value) => String(value || "reply")
  #|  .replace(/[^A-Za-z0-9._-]+/g, "-")
  #|  .replace(/^-+|-+$/g, "") || "reply"

///|
fn reply_review_comment_cwd(
  id : String,
  text : String,
  author : String,
) -> Unit {
  let review_path = review_json_path_for_cwd()
  write_file_secure(
    review_path,
    js_review_reply(read_file_safe(review_path), id, text, author, ""),
  )
}

///|
extern "js" fn js_review_prior_unresolved_count(
  json : String,
  current_file : String,
) -> Int =
  #|(json, currentFile) => {
  #|  try {
  #|    const review = JSON.parse(json || "{}");
  #|    const currentRound = Number(((review.rounds || []).reduce((a, b) => (Number(b.round || 0) > Number(a.round || 0) ? b : a), (review.rounds || [])[0]) || {}).round || 1);
  #|    return (review.comments || []).filter(c => c && c.scope !== "round" && c.file === currentFile && c.status !== "resolved" && Number(c.round || 0) < currentRound).length;
  #|  } catch(e) {
  #|    return 0;
  #|  }
  #|}

///|
fn review_prior_unresolved_count(file_path : String) -> Int {
  ensure_review_state(file_path)
  js_review_prior_unresolved_count(
    read_file_safe(review_json_path_for_file(file_path)),
    review_display_file(file_path),
  )
}

///|
extern "js" fn js_github_pr_sync(
  mode : String,
  review_path : String,
  cwd : String,
  pr_arg : String,
  now : String,
) -> String =
  #|(mode, reviewPath, cwd, prArg, now) => {
  #|  const cp = process.getBuiltinModule("node:child_process");
  #|  const fs = process.getBuiltinModule("node:fs");
  #|  const path = process.getBuiltinModule("node:path");
  #|  const run = (args) => {
  #|    const r = cp.spawnSync("gh", args, { cwd, encoding: "utf8" });
  #|    if (r.error) return { ok: false, error: r.error.message, stdout: "", stderr: "" };
  #|    return { ok: r.status === 0, status: r.status || 0, stdout: r.stdout || "", stderr: r.stderr || "" };
  #|  };
  #|  const parseJson = (text, fallback) => {
  #|    try { return JSON.parse(text || ""); } catch { return fallback; }
  #|  };
  #|  const fail = (error, extra = {}) => JSON.stringify({ ok: false, error, ...extra });
  #|  const ghRepo = run(["repo", "view", "--json", "owner,name"]);
  #|  if (!ghRepo.ok) return fail("gh repo view failed", { stderr: ghRepo.stderr || ghRepo.error || "" });
  #|  const repo = parseJson(ghRepo.stdout, null);
  #|  const owner = String(repo?.owner?.login || repo?.owner?.name || "");
  #|  const name = String(repo?.name || "");
  #|  if (!owner || !name) return fail("gh repo view did not return owner/name", { stdout: ghRepo.stdout });
  #|  const prArgs = prArg ? ["pr", "view", String(prArg), "--json", "number,headRefOid,url"] : ["pr", "view", "--json", "number,headRefOid,url"];
  #|  const ghPr = run(prArgs);
  #|  if (!ghPr.ok) return fail("gh pr view failed", { stderr: ghPr.stderr || ghPr.error || "" });
  #|  const pr = parseJson(ghPr.stdout, null);
  #|  const prNumber = Number(pr?.number || 0);
  #|  const headSha = String(pr?.headRefOid || "");
  #|  if (!prNumber) return fail("gh pr view did not return a PR number", { stdout: ghPr.stdout });
  #|  const apiPath = `repos/${owner}/${name}/pulls/${prNumber}/comments`;
  #|  const loadReview = () => {
  #|    let review = null;
  #|    try { review = fs.existsSync(reviewPath) ? JSON.parse(fs.readFileSync(reviewPath, "utf8")) : null; } catch { review = null; }
  #|    if (!review || typeof review !== "object") review = { version: 1, branch: "github-pr-" + prNumber, files: [], rounds: [], comments: [] };
  #|    review.version = 1;
  #|    review.files = Array.isArray(review.files) ? review.files : [];
  #|    review.rounds = Array.isArray(review.rounds) ? review.rounds : [];
  #|    review.comments = Array.isArray(review.comments) ? review.comments : [];
  #|    if (review.rounds.length === 0) review.rounds.push({ round: 1, started_at: now, submitted_at: null, decision: null, summary: "" });
  #|    return review;
  #|  };
  #|  const normalizedComment = (comment) => {
  #|    const c = comment && typeof comment === "object" ? comment : {};
  #|    const anchor = c.anchor && typeof c.anchor === "object" ? c.anchor : {};
  #|    const row = Math.max(0, Number(c.row ?? ((Number(c.line || 1) || 1) - 1)));
  #|    const col = Math.max(0, Number(c.col ?? 0));
  #|    const snippet = String(c.snippet ?? anchor.snippet ?? c.value ?? "");
  #|    const before = String(c.context_before ?? anchor.context_before ?? "");
  #|    const after = String(c.context_after ?? anchor.context_after ?? "");
  #|    const imagePath = String(c.image_path || c.imagePath || "");
  #|    const attachments = Array.isArray(c.attachments) ? c.attachments.map(String) : [];
  #|    return {
  #|      ...c,
  #|      file: String(c.file || ""),
  #|      row,
  #|      col,
  #|      end_row: Math.max(0, Number(c.end_row ?? row)),
  #|      end_col: Math.max(0, Number(c.end_col ?? col)),
  #|      snippet,
  #|      context_before: before,
  #|      context_after: after,
  #|      selector: String(c.selector || ""),
  #|      bounds: c.bounds == null ? "" : (typeof c.bounds === "string" ? c.bounds : JSON.stringify(c.bounds)),
  #|      element_text: String(c.element_text ?? c.value ?? snippet),
  #|      attachments,
  #|      anchor: { snippet, context_before: before, context_after: after },
  #|      image_path: imagePath
  #|    };
  #|  };
  #|  const normalizeReview = (review) => {
  #|    review.comments = Array.isArray(review.comments) ? review.comments.map(normalizedComment) : [];
  #|    return review;
  #|  };
  #|  const saveReview = (review) => {
  #|    fs.mkdirSync(path.dirname(reviewPath), { recursive: true });
  #|    fs.writeFileSync(reviewPath, JSON.stringify(normalizeReview(review), null, 2) + "\n");
  #|  };
  #|  const currentRound = (review) => Number((review.rounds || []).reduce((a, b) => (Number(b.round || 0) > Number(a.round || 0) ? b : a), (review.rounds || [])[0] || {}).round || 1) || 1;
  #|  const real = (value) => {
  #|    try { return fs.realpathSync(value); } catch { return value; }
  #|  };
  #|  const repoRoot = (() => {
  #|    const r = cp.spawnSync("git", ["rev-parse", "--show-toplevel"], { cwd, encoding: "utf8" });
  #|    return real(r.status === 0 ? String(r.stdout || "").trim() : cwd);
  #|  })();
  #|  const displayPath = (file) => {
  #|    const s = real(String(file || ""));
  #|    if (!path.isAbsolute(s)) return s;
  #|    const rel = path.relative(repoRoot, s);
  #|    return rel && !rel.startsWith("..") ? rel : path.basename(s);
  #|  };
  #|  if (mode === "pull") {
  #|    const ghComments = run(["api", apiPath, "--paginate"]);
  #|    if (!ghComments.ok) return fail("gh api pull comments failed", { stderr: ghComments.stderr || ghComments.error || "" });
  #|    const incomingRaw = parseJson(ghComments.stdout, []);
  #|    const incoming = Array.isArray(incomingRaw) ? incomingRaw : [];
  #|    const review = loadReview();
  #|    const byGithubId = new Map();
  #|    for (const c of review.comments) {
  #|      const id = c?.github?.comment_id;
  #|      if (id != null) byGithubId.set(String(id), c);
  #|    }
  #|    let imported = 0;
  #|    let replied = 0;
  #|    for (const item of incoming) {
  #|      const gid = String(item?.id || "");
  #|      if (!gid || byGithubId.has(gid)) continue;
  #|      const parentId = item?.in_reply_to_id == null ? "" : String(item.in_reply_to_id);
  #|      if (parentId && byGithubId.has(parentId)) {
  #|        const parent = byGithubId.get(parentId);
  #|        parent.replies = Array.isArray(parent.replies) ? parent.replies : [];
  #|        parent.replies.push({
  #|          author: "github:" + String(item?.user?.login || "unknown"),
  #|          round: currentRound(review),
  #|          text: String(item?.body || ""),
  #|          github: { comment_id: gid, html_url: String(item?.html_url || ""), synced_at: now }
  #|        });
  #|        byGithubId.set(gid, parent);
  #|        replied += 1;
  #|        continue;
  #|      }
  #|      const file = String(item?.path || "");
  #|      const line = Number(item?.line || item?.original_line || 1) || 1;
  #|      if (!file) continue;
  #|      if (!review.files.includes(file)) review.files.push(file);
  #|      const row = Math.max(0, line - 1);
  #|      const snippet = String(item?.diff_hunk || "");
  #|      const comment = {
  #|        id: "gh-" + gid,
  #|        file,
  #|        row,
  #|        col: 0,
  #|        end_row: row,
  #|        end_col: 0,
  #|        line,
  #|        round: currentRound(review),
  #|        text: String(item?.body || ""),
  #|        author: "github:" + String(item?.user?.login || "unknown"),
  #|        status: "unresolved",
  #|        replies: [],
  #|        snippet,
  #|        context_before: "",
  #|        context_after: "",
  #|        selector: "",
  #|        bounds: "",
  #|        element_text: snippet,
  #|        attachments: [],
  #|        anchor: { snippet, context_before: "", context_after: "" },
  #|        github: {
  #|          comment_id: gid,
  #|          html_url: String(item?.html_url || ""),
  #|          pull_request_review_id: item?.pull_request_review_id == null ? "" : String(item.pull_request_review_id),
  #|          synced_at: now,
  #|          source: "github"
  #|        }
  #|      };
  #|      review.comments.push(comment);
  #|      byGithubId.set(gid, comment);
  #|      imported += 1;
  #|    }
  #|    saveReview(review);
  #|    return JSON.stringify({ ok: true, mode, pr: prNumber, imported, replies: replied, path: reviewPath });
  #|  }
  #|  if (mode === "push") {
  #|    if (!headSha) return fail("gh pr view did not return headRefOid");
  #|    const review = loadReview();
  #|    let pushed = 0;
  #|    const errors = [];
  #|    for (const c of review.comments) {
  #|      if (c?.github?.comment_id) continue;
  #|      const text = String(c?.text || "").trim();
  #|      const file = displayPath(c?.file || "");
  #|      const line = Number(c?.line || 0);
  #|      if (!text || !file || line <= 0) continue;
  #|      const created = run([
  #|        "api",
  #|        apiPath,
  #|        "-f", "body=" + text,
  #|        "-f", "commit_id=" + headSha,
  #|        "-f", "path=" + file,
  #|        "-F", "line=" + line,
  #|        "-f", "side=RIGHT"
  #|      ]);
  #|      if (!created.ok) {
  #|        errors.push(created.stderr || created.error || "gh api failed");
  #|        break;
  #|      }
  #|      const json = parseJson(created.stdout, {});
  #|      c.github = {
  #|        comment_id: json?.id == null ? "" : String(json.id),
  #|        html_url: String(json?.html_url || ""),
  #|        pull_request: String(prNumber),
  #|        pushed_at: now,
  #|        source: "yunomi"
  #|      };
  #|      pushed += 1;
  #|    }
  #|    saveReview(review);
  #|    if (errors.length) return fail("gh api push comment failed", { errors, pushed, path: reviewPath });
  #|    return JSON.stringify({ ok: true, mode, pr: prNumber, pushed, path: reviewPath });
  #|  }
  #|  return fail("unknown mode: " + mode);
  #|}

///|
fn json_parse_int_field(key : String, json_str : String) -> Int {
  @core.parse_int_safe(json_parse_string(key, json_str))
}

///|
extern "js" fn run_mcp_server() -> Unit =
  #|() => {
  #|  const fs = process.getBuiltinModule("node:fs");
  #|  const path = process.getBuiltinModule("node:path");
  #|  const childProcess = process.getBuiltinModule("node:child_process");
  #|  const iso = () => new Date().toISOString();
  #|  const escBranch = (s) => String(s || "no-branch").replace(/[^A-Za-z0-9._-]+/g, "-").replace(/^-+|-+$/g, "") || "no-branch";
  #|  const git = (cwd, args) => {
  #|    const result = childProcess.spawnSync("git", args, { cwd, encoding: "utf8" });
  #|    return result.status === 0 ? String(result.stdout || "").trim() : "";
  #|  };
  #|  const repoRoot = (cwd) => git(cwd, ["rev-parse", "--show-toplevel"]) || path.resolve(cwd || ".");
  #|  const branchName = (root) => git(root, ["branch", "--show-current"]) || "no-branch";
  #|  const reviewDir = (cwd) => {
  #|    if (process.env.YUNOMI_REVIEW_DIR) return process.env.YUNOMI_REVIEW_DIR;
  #|    const root = repoRoot(cwd);
  #|    return path.join(root, ".yunomi", "reviews", escBranch(branchName(root)));
  #|  };
  #|  const reviewPath = (cwd) => path.join(reviewDir(cwd), "review.json");
  #|  const serverPath = (cwd) => path.join(reviewDir(cwd), "server.json");
  #|  const signalPath = (cwd) => path.join(reviewDir(cwd), "go.signal");
  #|  const ensureDir = (dir) => fs.mkdirSync(dir, { recursive: true });
  #|  const displayFile = (cwd, file) => {
  #|    const abs = path.resolve(cwd || ".", file || "");
  #|    const root = repoRoot(path.dirname(abs));
  #|    const rel = path.relative(root, abs);
  #|    return rel && !rel.startsWith("..") ? rel : path.basename(abs);
  #|  };
  #|  const normalizeComment = (comment) => {
  #|    const c = comment && typeof comment === "object" ? comment : {};
  #|    const anchor = c.anchor && typeof c.anchor === "object" ? c.anchor : {};
  #|    const row = Math.max(0, Number(c.row ?? ((Number(c.line || 1) || 1) - 1)));
  #|    const col = Math.max(0, Number(c.col ?? 0));
  #|    const snippet = String(c.snippet ?? anchor.snippet ?? c.value ?? "");
  #|    const before = String(c.context_before ?? anchor.context_before ?? "");
  #|    const after = String(c.context_after ?? anchor.context_after ?? "");
  #|    const imagePath = String(c.image_path || c.imagePath || "");
  #|    const attachments = Array.isArray(c.attachments) ? c.attachments.map(String) : [];
  #|    return {
  #|      ...c,
  #|      file: String(c.file || ""),
  #|      row,
  #|      col,
  #|      end_row: Math.max(0, Number(c.end_row ?? row)),
  #|      end_col: Math.max(0, Number(c.end_col ?? col)),
  #|      snippet,
  #|      context_before: before,
  #|      context_after: after,
  #|      selector: String(c.selector || ""),
  #|      bounds: c.bounds == null ? "" : (typeof c.bounds === "string" ? c.bounds : JSON.stringify(c.bounds)),
  #|      element_text: String(c.element_text ?? c.value ?? snippet),
  #|      attachments,
  #|      anchor: { snippet, context_before: before, context_after: after },
  #|      image_path: imagePath
  #|    };
  #|  };
  #|  const normalizeReview = (review) => {
  #|    const r = review && typeof review === "object" ? review : {};
  #|    r.comments = Array.isArray(r.comments) ? r.comments.map(normalizeComment) : [];
  #|    return r;
  #|  };
  #|  const readReview = (cwd) => {
  #|    const p = reviewPath(cwd);
  #|    if (!fs.existsSync(p)) return normalizeReview({ version: 1, branch: branchName(repoRoot(cwd || ".")), files: [], rounds: [{ round: 1, started_at: iso(), submitted_at: null, decision: null, summary: "" }], comments: [] });
  #|    return normalizeReview(JSON.parse(fs.readFileSync(p, "utf8") || "{}"));
  #|  };
  #|  const listReviews = (args) => {
  #|    const base = process.env.YUNOMI_REVIEW_DIR || path.join(repoRoot((args && args.cwd) || process.cwd()), ".yunomi", "reviews");
  #|    if (!fs.existsSync(base)) return [];
  #|    const direct = path.join(base, "review.json");
  #|    if (fs.existsSync(direct)) {
  #|      let review = {};
  #|      try { review = JSON.parse(fs.readFileSync(direct, "utf8") || "{}"); } catch (_) {}
  #|      const comments = Array.isArray(review.comments) ? review.comments : [];
  #|      return [{
  #|        id: review.branch || path.basename(base),
  #|        path: direct,
  #|        branch: review.branch || path.basename(base),
  #|        round: Array.isArray(review.rounds) && review.rounds.length ? Number(review.rounds.reduce((a, b) => (Number(b.round || 0) > Number(a.round || 0) ? b : a), review.rounds[0]).round || review.rounds.length) : 1,
  #|        unresolved: comments.filter((comment) => comment && comment.status !== "resolved").length
  #|      }];
  #|    }
  #|    return fs.readdirSync(base, { withFileTypes: true }).filter((entry) => entry.isDirectory()).map((entry) => {
  #|      const p = path.join(base, entry.name, "review.json");
  #|      let review = {};
  #|      try { review = fs.existsSync(p) ? JSON.parse(fs.readFileSync(p, "utf8") || "{}") : {}; } catch (_) {}
  #|      const comments = Array.isArray(review.comments) ? review.comments : [];
  #|      return {
  #|        id: entry.name,
  #|        path: p,
  #|        branch: review.branch || entry.name,
  #|        round: Array.isArray(review.rounds) && review.rounds.length ? Number(review.rounds.reduce((a, b) => (Number(b.round || 0) > Number(a.round || 0) ? b : a), review.rounds[0]).round || review.rounds.length) : 1,
  #|        unresolved: comments.filter((comment) => comment && comment.status !== "resolved").length
  #|      };
  #|    });
  #|  };
  #|  const writeReview = (cwd, review) => {
  #|    const dir = reviewDir(cwd);
  #|    ensureDir(dir);
  #|    fs.writeFileSync(path.join(dir, "review.json"), JSON.stringify(normalizeReview(review), null, 2));
  #|    return path.join(dir, "review.json");
  #|  };
  #|  const lineContext = (file, line) => {
  #|    try {
  #|      const lines = fs.readFileSync(path.resolve(file), "utf8").split(/\r?\n/);
  #|      const idx = Math.max(0, Number(line || 1) - 1);
  #|      const window = (start, end) => lines.slice(Math.max(0, start), Math.min(lines.length, end)).map((value) => String(value || "")).join("\n");
  #|      return {
  #|        snippet: window(idx - 3, idx + 4),
  #|        context_before: window(idx - 5, idx),
  #|        context_after: window(idx + 1, idx + 6)
  #|      };
  #|    } catch (_) {
  #|      return { snippet: "", context_before: "", context_after: "" };
  #|    }
  #|  };
  #|  const addComment = (args) => {
  #|    const cwd = path.resolve(args.cwd || process.cwd());
  #|    const file = String(args.file || "");
  #|    const line = Number(args.line || 1);
  #|    const text = String(args.text || "");
  #|    if (!file || !text) throw new Error("file and text are required");
  #|    const review = readReview(cwd);
  #|    review.version = review.version || 1;
  #|    review.files = Array.isArray(review.files) ? review.files : [];
  #|    const display = displayFile(cwd, file);
  #|    if (!review.files.includes(display)) review.files.push(display);
  #|    review.rounds = Array.isArray(review.rounds) && review.rounds.length ? review.rounds : [{ round: 1, started_at: iso(), submitted_at: null, decision: null, summary: "" }];
  #|    review.comments = Array.isArray(review.comments) ? review.comments : [];
  #|    const currentRound = Number(((review.rounds || []).reduce((a, b) => (Number(b.round || 0) > Number(a.round || 0) ? b : a), (review.rounds || [])[0]) || {}).round || 1);
  #|    const id = String(args.id || `mcp-${currentRound}-${review.comments.length + 1}`);
  #|    const abs = path.resolve(cwd, file);
  #|    const row = Math.max(0, line - 1);
  #|    const anchor = lineContext(abs, line);
  #|    review.comments.push({
  #|      id,
  #|      file: display,
  #|      row,
  #|      col: 0,
  #|      end_row: row,
  #|      end_col: 0,
  #|      line,
  #|      round: currentRound,
  #|      text,
  #|      author: String(args.author || "mcp"),
  #|      status: "unresolved",
  #|      replies: [],
  #|      snippet: anchor.snippet,
  #|      context_before: anchor.context_before,
  #|      context_after: anchor.context_after,
  #|      selector: "",
  #|      bounds: "",
  #|      element_text: anchor.snippet,
  #|      attachments: [],
  #|      anchor
  #|    });
  #|    const p = writeReview(cwd, review);
  #|    return { id, path: p, comment_count: review.comments.length };
  #|  };
  #|  const goRound = (args) => {
  #|    const cwd = path.resolve(args.cwd || process.cwd());
  #|    const dir = reviewDir(cwd);
  #|    const sp = serverPath(cwd);
  #|    if (fs.existsSync(sp)) {
  #|      try {
  #|        const server = JSON.parse(fs.readFileSync(sp, "utf8") || "{}");
  #|        if (Number(server.pid) > 0) {
  #|          try {
  #|            process.kill(Number(server.pid), 0);
  #|            ensureDir(dir);
  #|            fs.writeFileSync(signalPath(cwd), iso());
  #|            return { notified: true, path: signalPath(cwd) };
  #|          } catch (_) {}
  #|        }
  #|      } catch (_) {}
  #|    }
  #|    const review = readReview(cwd);
  #|    review.rounds = Array.isArray(review.rounds) ? review.rounds : [];
  #|    const latestRound = (rs) => (rs || []).reduce((a, b) => (Number(b.round || 0) > Number(a.round || 0) ? b : a), (rs || [])[0]);
  #|    const last = latestRound(review.rounds);
  #|    const next = last ? Number(last.round || review.rounds.length) + 1 : 1;
  #|    if (!last || last.submitted_at) review.rounds.push({ round: next, started_at: iso(), submitted_at: null, decision: null, summary: "" });
  #|    const p = writeReview(cwd, review);
  #|    return { notified: false, path: p, round: Number((latestRound(review.rounds) || {}).round || 1) };
  #|  };
  #|  const tools = [
  #|    { name: "mcp__yunomi__list_reviews", description: "List yunomi review sessions.", inputSchema: { type: "object", properties: { cwd: { type: "string" } } } },
  #|    { name: "mcp__yunomi__get_review", description: "Read a yunomi review.json session.", inputSchema: { type: "object", properties: { cwd: { type: "string" } } } },
  #|    { name: "mcp__yunomi__add_comment", description: "Add a structured review comment to yunomi review.json.", inputSchema: { type: "object", required: ["file", "line", "text"], properties: { cwd: { type: "string" }, file: { type: "string" }, line: { type: "number" }, text: { type: "string" }, author: { type: "string" }, id: { type: "string" } } } },
  #|    { name: "mcp__yunomi__advance_round", description: "Advance or notify the next yunomi review round.", inputSchema: { type: "object", properties: { cwd: { type: "string" } } } },
  #|    { name: "yunomi_review_state", description: "Read the current yunomi review.json state for a repository branch.", inputSchema: { type: "object", properties: { cwd: { type: "string" } } } },
  #|    { name: "yunomi_add_comment", description: "Add a structured review comment to yunomi review.json.", inputSchema: { type: "object", required: ["file", "line", "text"], properties: { cwd: { type: "string" }, file: { type: "string" }, line: { type: "number" }, text: { type: "string" }, author: { type: "string" }, id: { type: "string" } } } },
  #|    { name: "yunomi_go", description: "Advance or notify the next yunomi review round.", inputSchema: { type: "object", properties: { cwd: { type: "string" } } } }
  #|  ];
  #|  const resultContent = (value) => ({ content: [{ type: "text", text: JSON.stringify(value, null, 2) }] });
  #|  const callTool = (name, args) => {
  #|    if (name === "mcp__yunomi__list_reviews") return resultContent(listReviews(args || {}));
  #|    if (name === "mcp__yunomi__get_review") return resultContent(readReview(path.resolve((args && args.cwd) || process.cwd())));
  #|    if (name === "mcp__yunomi__add_comment") return resultContent(addComment(args || {}));
  #|    if (name === "mcp__yunomi__advance_round") return resultContent(goRound(args || {}));
  #|    if (name === "yunomi_review_state") return resultContent(readReview(path.resolve((args && args.cwd) || process.cwd())));
  #|    if (name === "yunomi_add_comment") return resultContent(addComment(args || {}));
  #|    if (name === "yunomi_go") return resultContent(goRound(args || {}));
  #|    throw new Error(`unknown tool: ${name}`);
  #|  };
  #|  const send = (msg) => {
  #|    const body = JSON.stringify(msg);
  #|    process.stdout.write(`Content-Length: ${Buffer.byteLength(body, "utf8")}\r\n\r\n${body}`);
  #|  };
  #|  const handle = (msg) => {
  #|    if (!msg || !msg.method) return;
  #|    try {
  #|      if (msg.method === "initialize") {
  #|        send({ jsonrpc: "2.0", id: msg.id, result: { protocolVersion: "2024-11-05", capabilities: { tools: {} }, serverInfo: { name: "yunomi", version: "2.4.3" } } });
  #|      } else if (msg.method === "tools/list") {
  #|        send({ jsonrpc: "2.0", id: msg.id, result: { tools } });
  #|      } else if (msg.method === "tools/call") {
  #|        const params = msg.params || {};
  #|        send({ jsonrpc: "2.0", id: msg.id, result: callTool(String(params.name || ""), params.arguments || {}) });
  #|      } else if (msg.id != null) {
  #|        send({ jsonrpc: "2.0", id: msg.id, error: { code: -32601, message: `method not found: ${msg.method}` } });
  #|      }
  #|    } catch (e) {
  #|      if (msg.id != null) send({ jsonrpc: "2.0", id: msg.id, error: { code: -32000, message: e && e.message ? e.message : String(e) } });
  #|    }
  #|  };
  #|  let buffer = Buffer.alloc(0);
  #|  const pump = () => {
  #|    while (true) {
  #|      const sep = buffer.indexOf("\r\n\r\n");
  #|      if (sep < 0) return;
  #|      const header = buffer.slice(0, sep).toString("utf8");
  #|      const match = header.match(/Content-Length:\s*(\d+)/i);
  #|      if (!match) {
  #|        buffer = buffer.slice(sep + 4);
  #|        continue;
  #|      }
  #|      const length = Number(match[1]);
  #|      const total = sep + 4 + length;
  #|      if (buffer.length < total) return;
  #|      const body = buffer.slice(sep + 4, total).toString("utf8");
  #|      buffer = buffer.slice(total);
  #|      try { handle(JSON.parse(body)); } catch (e) { process.stderr.write(`yunomi mcp: invalid json ${e.message}\n`); }
  #|    }
  #|  };
  #|  process.stdin.on("data", chunk => { buffer = Buffer.concat([buffer, chunk]); pump(); });
  #|  process.stdin.on("end", () => process.exit(0));
  #|  process.stdin.resume();
  #|}

///|

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
fn base64_to_named_file(
  data : String,
  dir : String,
  filename : String,
) -> String {
  let b64_data = extract_base64_data(data)
  if b64_data.length() == 0 || filename.length() == 0 {
    return ""
  }
  try_call_string(
    fn() {
      if !exists_sync(dir) {
        mkdir_sync(dir, mkdir_recursive_opts())
      }
      let filepath = path_join(dir, filename)
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
extern "js" fn split_notify_command(
  command : String,
  msg : String,
) -> Array[String] =
  #|(command, msg) => {
  #|  const out = [];
  #|  let cur = "", quote = "";
  #|  for (let i = 0; i < command.length; i++) {
  #|    const ch = command[i];
  #|    if (quote) {
  #|      if (ch === quote) quote = "";
  #|      else cur += ch;
  #|    } else if (ch === '"' || ch === "'") {
  #|      quote = ch;
  #|    } else if (/\s/.test(ch)) {
  #|      if (cur) { out.push(cur); cur = ""; }
  #|    } else {
  #|      cur += ch;
  #|    }
  #|  }
  #|  if (cur) out.push(cur);
  #|  let hadPlaceholder = false;
  #|  const replaced = out.map(part => {
  #|    if (part.includes("{msg}")) {
  #|      hadPlaceholder = true;
  #|      return part.replaceAll("{msg}", msg);
  #|    }
  #|    return part;
  #|  });
  #|  if (replaced.length > 0 && !hadPlaceholder) replaced.push(msg);
  #|  return replaced;
  #|}

///|
fn json_array_of_strings(values : Array[String]) -> String {
  let buf = StringBuilder::new()
  buf.write_char('[')
  for i, value in values {
    if i > 0 {
      buf.write_char(',')
    }
    buf.write_string(json_encode_value(value))
  }
  buf.write_char(']')
  buf.to_string()
}

///|
extern "js" fn js_trim_string(s : String) -> String =
  #|(s) => String(s).trim()

///|
extern "js" fn js_lock_pid(content : String) -> Int =
  #|(s) => {
  #|  try {
  #|    const v = JSON.parse(s);
  #|    return Number(v?.pid || 0) || 0;
  #|  } catch {
  #|    return parseInt(String(s).trim(), 10) || 0;
  #|  }
  #|}

///|
extern "js" fn js_lock_matches_file(content : String, file : String) -> Bool =
  #|(s, file) => {
  #|  try {
  #|    const v = JSON.parse(s);
  #|    if (!v || !v.file) return true;
  #|    return String(v.file) === String(file);
  #|  } catch {
  #|    return true;
  #|  }
  #|}

///|
extern "js" fn js_claim_file_lock(dir : String, file : String) -> String =
  #|(dir, file) => {
  #|  const fs = process.getBuiltinModule("node:fs");
  #|  const path = process.getBuiltinModule("node:path");
  #|  const crypto = process.getBuiltinModule("node:crypto");
  #|  let resolved;
  #|  try { resolved = fs.realpathSync(file); } catch { resolved = path.resolve(file); }
  #|  fs.mkdirSync(dir, { recursive: true, mode: 0o700 });
  #|  const hash = crypto.createHash("sha256").update(resolved).digest("hex").slice(0, 32);
  #|  const lockPath = path.join(dir, `file-${hash}.lock`);
  #|  for (let attempt = 0; attempt < 3; attempt++) {
  #|    const tempPath = path.join(dir, `file-${hash}.${process.pid}.${crypto.randomUUID()}.tmp`);
  #|    try {
  #|      fs.writeFileSync(tempPath, JSON.stringify({ pid: process.pid, port: 0, file: resolved }), { flag: "wx", mode: 0o600 });
  #|      fs.linkSync(tempPath, lockPath);
  #|      fs.unlinkSync(tempPath);
  #|      return JSON.stringify({ status: "claimed", port: 0 });
  #|    } catch (error) {
  #|      try { fs.unlinkSync(tempPath); } catch {}
  #|      if (error?.code !== "EEXIST") return JSON.stringify({ status: "error", port: 0 });
  #|      let existing = {};
  #|      try { existing = JSON.parse(fs.readFileSync(lockPath, "utf8")); } catch {}
  #|      const pid = Number(existing?.pid || 0);
  #|      if (pid > 0) {
  #|        try {
  #|          process.kill(pid, 0);
  #|          return JSON.stringify({ status: "existing", port: Number(existing?.port || 0) });
  #|        } catch (error) {
  #|          if (error?.code !== "ESRCH") {
  #|            return JSON.stringify({ status: "existing", port: Number(existing?.port || 0) });
  #|          }
  #|        }
  #|      }
  #|      try { fs.unlinkSync(lockPath); } catch {}
  #|    }
  #|  }
  #|  return JSON.stringify({ status: "error", port: 0 });
  #|}

///|
extern "js" fn js_update_file_lock(dir : String, file : String, port : Int) -> Unit =
  #|(dir, file, port) => {
  #|  const fs = process.getBuiltinModule("node:fs");
  #|  const path = process.getBuiltinModule("node:path");
  #|  const crypto = process.getBuiltinModule("node:crypto");
  #|  let resolved;
  #|  try { resolved = fs.realpathSync(file); } catch { resolved = path.resolve(file); }
  #|  const hash = crypto.createHash("sha256").update(resolved).digest("hex").slice(0, 32);
  #|  const lockPath = path.join(dir, `file-${hash}.lock`);
  #|  let existing = {};
  #|  try { existing = JSON.parse(fs.readFileSync(lockPath, "utf8")); } catch {}
  #|  if (Number(existing?.pid || 0) !== process.pid) return;
  #|  const tempPath = path.join(dir, `file-${hash}.${process.pid}.${crypto.randomUUID()}.tmp`);
  #|  try {
  #|    fs.writeFileSync(tempPath, JSON.stringify({ pid: process.pid, port: Number(port), file: resolved }), { flag: "wx", mode: 0o600 });
  #|    fs.renameSync(tempPath, lockPath);
  #|  } finally {
  #|    try { fs.unlinkSync(tempPath); } catch {}
  #|  }
  #|}

///|
extern "js" fn js_remove_file_lock(dir : String, file : String) -> Unit =
  #|(dir, file) => {
  #|  const fs = process.getBuiltinModule("node:fs");
  #|  const path = process.getBuiltinModule("node:path");
  #|  const crypto = process.getBuiltinModule("node:crypto");
  #|  let resolved;
  #|  try { resolved = fs.realpathSync(file); } catch { resolved = path.resolve(file); }
  #|  const hash = crypto.createHash("sha256").update(resolved).digest("hex").slice(0, 32);
  #|  const lockPath = path.join(dir, `file-${hash}.lock`);
  #|  let existing = {};
  #|  try { existing = JSON.parse(fs.readFileSync(lockPath, "utf8")); } catch {}
  #|  if (Number(existing?.pid || 0) !== process.pid) return;
  #|  try { fs.unlinkSync(lockPath); } catch {}
  #|}

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
fn spawn_sync_status(cmd : String, args : Array[String]) -> String {
  let result = child_spawn_sync(
    cmd,
    js_parse_json(json_array_of_strings(args)),
    js_spawn_opts_utf8_pipe(),
  )
  let error = js_obj_error_message(result)
  if error.length() > 0 {
    return cmd + ": " + error
  }
  let status = js_obj_status(result)
  if status != 0 {
    let detail = js_obj_stderr(result)
    let out = js_obj_stdout(result)
    let message = if detail.length() > 0 { detail } else { out }
    return cmd + " exited " + status.to_string() + ": " + message
  }
  ""
}

///|
fn send_notify_message(notify_pane : String, msg : String) -> String {
  let custom = get_env_var("YUNOMI_NOTIFY_CMD")
  if custom.length() > 0 {
    let parts = split_notify_command(custom, msg)
    if parts.length() == 0 {
      return "YUNOMI_NOTIFY_CMD is empty"
    }
    let args : Array[String] = []
    for i = 1; i < parts.length(); i = i + 1 {
      args.push(parts[i])
    }
    return spawn_sync_status(parts[0], args)
  }
  if notify_pane.length() == 0 {
    return ""
  }
  spawn_sync_status("herdr", ["agent", "send", notify_pane, msg])
}

///|
fn spawn_sync_status_args(cmd : String, args : Array[String]) -> (Int, String) {
  let result = child_spawn_sync(
    cmd,
    js_array_from_strings(args),
    js_spawn_opts_utf8_pipe(),
  )
  (js_obj_status(result), js_obj_stderr(result))
}

///|
fn spawn_sync_result_args(
  cmd : String,
  args : Array[String],
) -> (Int, String, String) {
  let result = child_spawn_sync(
    cmd,
    js_array_from_strings(args),
    js_spawn_opts_utf8_pipe(),
  )
  (js_obj_status(result), js_obj_stdout(result), js_obj_stderr(result))
}

///|
fn spawn_sync_shell_status(cmd : String) -> (Int, String) {
  let result = child_spawn_sync(
    cmd,
    js_array_from_strings([]),
    js_spawn_opts_shell_utf8(),
  )
  (js_obj_status(result), js_obj_stderr(result))
}

///|
extern "js" fn js_spawn_opts_shell_utf8() -> JsValue =
  #|() => ({ encoding: "utf8", shell: true, stdio: ["ignore", "pipe", "pipe"] })

///|
/// Pick the single source line a comment points at. Element comments carry a
/// "<rendered text> | source: <markdown source>" composite, so the source half
/// wins when present.
extern "js" fn js_quote_from_candidates(
  value : String,
  element_text : String,
  fallback : String,
) -> String =
  #|(value, elementText, fallback) => {
  #|  const marker = " | source: ";
  #|  for (const candidate of [value, elementText, fallback]) {
  #|    const raw = String(candidate || "");
  #|    const idx = raw.indexOf(marker);
  #|    const quote = (idx >= 0 ? raw.slice(idx + marker.length) : raw).split(/\r?\n/, 1)[0].trim();
  #|    if (quote) return quote;
  #|  }
  #|  return "";
  #|}

///|
extern "js" fn replace_notify_placeholder(cmd : String, msg : String) -> String =
  #|(cmd, msg) => {
  #|  const quoted = "'" + String(msg).replace(/'/g, "'\\''") + "'";
  #|  return String(cmd).includes("{msg}") ? String(cmd).replaceAll("{msg}", quoted) : String(cmd) + " " + quoted;
  #|}

///|
extern "js" fn js_replace_task_checkbox_line(
  content : String,
  line : Int,
  checked : Bool,
) -> String =
  #|(content, line, checked) => {
  #|  const lines = String(content).split(/\n/);
  #|  const idx = Number(line) - 1;
  #|  if (idx < 0 || idx >= lines.length) return "";
  #|  const before = lines[idx];
  #|  const after = before.replace(/^(\s*[-*]\s+\[)( |x|X)(\]\s+.*)$/, `$1${checked ? "x" : " "}$3`);
  #|  if (after === before) return "";
  #|  lines[idx] = after;
  #|  return lines.join("\n");
  #|}

///|
extern "js" fn js_upsert_decision_review_json(
  existing : String,
  branch : String,
  file : String,
  path_hash : String,
  line : Int,
  text : String,
  checked : Bool,
  now : String,
) -> String =
  #|(existing, branch, file, pathHash, line, text, checked, now) => {
  #|  let review;
  #|  try { review = existing ? JSON.parse(existing) : null; } catch { review = null; }
  #|  if (!review || typeof review !== "object" || review.version !== 1) {
  #|    review = { version: 1, branch, files: [], rounds: [], comments: [], decisions: [] };
  #|  }
  #|  review.version = 1;
  #|  review.branch = review.branch || branch;
  #|  review.files = Array.isArray(review.files) ? review.files : [];
  #|  review.rounds = Array.isArray(review.rounds) ? review.rounds : [];
  #|  review.comments = Array.isArray(review.comments) ? review.comments : [];
  #|  review.decisions = Array.isArray(review.decisions) ? review.decisions : [];
  #|  review.files = Array.from(new Set(review.files.map(String).map((entry) => {
  #|    const normalized = entry.replaceAll("\\\\", "/");
  #|    return normalized === file || normalized.endsWith(`/${file}`) ? file : entry;
  #|  })));
  #|  if (!review.files.includes(file)) review.files.push(file);
  #|  const id = `d-${String(pathHash)}-${Number(line)}`;
  #|  const next = { id, file, line, text, checked: !!checked, decided_at: now };
  #|  const idx = review.decisions.findIndex((d) => d && d.file === file && Number(d.line) === Number(line));
  #|  if (idx >= 0) review.decisions[idx] = next; else review.decisions.push(next);
  #|  return JSON.stringify(review, null, 2) + "\n";
  #|}

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
extern "js" fn req_cookie_value(req : JsValue, name : String) -> String =
  #|(req, name) => {
  #|  const prefix = `${name}=`;
  #|  const entry = String(req?.headers?.cookie || "")
  #|    .split(";")
  #|    .map(value => value.trim())
  #|    .find(value => value.startsWith(prefix));
  #|  return entry ? entry.slice(prefix.length) : "";
  #|}

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

///|
extern "js" fn js_update_review_json(
  existing : String,
  branch : String,
  file : String,
  line : Int,
  text : String,
  author : String,
  snippet : String,
  quote : String,
  context_before : String,
  context_after : String,
  now : String,
) -> String =
  #|(existing, branch, file, line, text, author, snippet, quote, before, after, now) => {
  #|  let review;
  #|  try { review = existing ? JSON.parse(existing) : null; } catch { review = null; }
  #|  if (!review || typeof review !== "object" || review.version !== 1) {
  #|    review = { version: 1, branch, files: [], rounds: [], comments: [] };
  #|  }
  #|  review.version = 1;
  #|  review.branch = review.branch || branch;
  #|  review.files = Array.isArray(review.files) ? review.files : [];
  #|  review.rounds = Array.isArray(review.rounds) ? review.rounds : [];
  #|  review.comments = Array.isArray(review.comments) ? review.comments : [];
  #|  if (!review.files.includes(file)) review.files.push(file);
  #|  let round = 1;
  #|  if (review.rounds.length === 0) {
  #|    review.rounds.push({ round: 1, started_at: now, submitted_at: null, decision: null, summary: "" });
  #|  } else {
  #|    round = Number(review.rounds.reduce((a, b) => (Number(b.round || 0) > Number(a.round || 0) ? b : a), review.rounds[0])?.round || 1) || 1;
  #|  }
  #|  let seq = 1;
  #|  for (const c of review.comments) {
  #|    if (Number(c?.round || 0) === round) seq += 1;
  #|  }
  #|  const row = Math.max(0, Number(line || 1) - 1);
  #|  const safeSnippet = String(snippet || "");
  #|  const safeBefore = String(before || "");
  #|  const safeAfter = String(after || "");
  #|  review.comments.push({
  #|    id: `c-${round}-${seq}`,
  #|    file,
  #|    row,
  #|    col: 0,
  #|    end_row: row,
  #|    end_col: 0,
  #|    line,
  #|    round,
  #|    text,
  #|    quote: String(quote || ""),
  #|    author,
  #|    status: "unresolved",
  #|    replies: [],
  #|    snippet: safeSnippet,
  #|    context_before: safeBefore,
  #|    context_after: safeAfter,
  #|    selector: "",
  #|    bounds: "",
  #|    element_text: safeSnippet,
  #|    attachments: [],
  #|    anchor: { snippet: safeSnippet, context_before: safeBefore, context_after: safeAfter }
  #|  });
  #|  return JSON.stringify(review, null, 2) + "\n";
  #|}
