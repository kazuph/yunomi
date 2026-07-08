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
/// Start a localhost-only live review reverse proxy. The implementation stays
/// in JS because Node's HTTP upgrade and proxy streaming APIs are much simpler
/// to use directly than through many tiny FFI calls.
extern "js" fn start_live_proxy(
  target_url : String,
  port : Int,
  host : String,
  no_open : Bool,
  instance_id : String,
) -> Unit =
  #|(targetUrl, port, host, noOpen, instanceId) => {
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
  #|      lines.push(`  - row: ${Number(comment.row || 0)}`);
  #|      lines.push(`    col: ${Number(comment.col || 0)}`);
  #|      lines.push(`    text: ${yamlEscape(comment.text || "")}`);
  #|      lines.push(`    selector: ${yamlEscape(comment.selector || "")}`);
  #|      if (comment.value) lines.push(`    value: ${yamlEscape(comment.value)}`);
  #|      if (comment.screenshot) lines.push(`    screenshot: ${yamlEscape(comment.screenshot)}`);
  #|      if (comment.bounds) lines.push(`    bounds: ${yamlEscape(JSON.stringify(comment.bounds))}`);
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
  #|        "/* yunomi live overlay tokens copied from v2/src/core/css.mbt in .worktree/rebrand-sonnet (green tea theme). */",
  #|        ":root{--yunomi-live-panel:rgba(246,250,240,.92);--yunomi-live-panel-solid:#f6faf0;--yunomi-live-card-bg:rgba(248,251,243,.98);--yunomi-live-input-bg:#e9f0dc;--yunomi-live-border:#d7e2c4;--yunomi-live-border-strong:#c2d1a5;--yunomi-live-accent:#5c8a42;--yunomi-live-accent-strong:#466b30;--yunomi-live-accent-2:#9fc47c;--yunomi-live-accent-soft:rgba(92,138,66,.12);--yunomi-live-selected-bg:rgba(92,138,66,.20);--yunomi-live-hover-bg:rgba(92,138,66,.12);--yunomi-live-text:#3b2d20;--yunomi-live-text-inverse:#fffaf0;--yunomi-live-muted:#87735b;--yunomi-live-shadow-soft:0 6px 18px rgba(60,40,20,.08);--yunomi-live-shadow-card:0 18px 36px rgba(60,40,20,.12);--yunomi-live-radius-sm:8px;--yunomi-live-radius-lg:16px;--yunomi-live-radius-pill:999px;--yunomi-live-font:'Inter','Hiragino Kaku Gothic ProN','Hiragino Sans',system-ui,-apple-system,sans-serif}",
  #|        "@media (prefers-color-scheme:dark){:root{--yunomi-live-panel:rgba(19,26,18,.82);--yunomi-live-panel-solid:#172014;--yunomi-live-card-bg:rgba(24,32,22,.96);--yunomi-live-input-bg:rgba(28,37,25,.75);--yunomi-live-border:#2a3524;--yunomi-live-border-strong:#37452e;--yunomi-live-accent:#9fc47c;--yunomi-live-accent-strong:#b9d99a;--yunomi-live-accent-2:#5c8a42;--yunomi-live-accent-soft:rgba(159,196,124,.14);--yunomi-live-selected-bg:rgba(159,196,124,.22);--yunomi-live-hover-bg:rgba(159,196,124,.14);--yunomi-live-text:#f1ebe1;--yunomi-live-text-inverse:#1a1612;--yunomi-live-muted:#9f9488;--yunomi-live-shadow-soft:0 10px 30px rgba(0,0,0,.35);--yunomi-live-shadow-card:0 20px 40px rgba(0,0,0,.4)}}",
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
fn git_root_for(path : String) -> String {
  let dir = if exists_sync(path) && is_file_sync(path) {
    path_dirname(path)
  } else {
    path
  }
  let out = git_stdout(dir, "[\"rev-parse\",\"--show-toplevel\"]")
  let root = trim_ascii(out)
  if root.length() > 0 { root } else { path_resolve(dir) }
}

///|
fn git_branch_for(root : String) -> String {
  let out = git_stdout(root, "[\"branch\",\"--show-current\"]")
  let branch = trim_ascii(out)
  if branch.length() > 0 { branch } else { "no-branch" }
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
  let rel = path_relative(root, path_resolve(file_path))
  if rel.length() > 0 && !rel.has_prefix("..") { rel } else { path_basename(file_path) }
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
fn write_review_server(file_path : String, port : Int, notify_pane : String) -> Unit {
  ensure_review_state(file_path)
  let data = "{\"pid\":" + process_pid().to_string() + ",\"port\":" +
    port.to_string() + ",\"file\":" + json_encode_value(path_resolve(file_path)) +
    ",\"notify_pane\":" + json_encode_value(notify_pane) +
    ",\"updated_at\":" + json_encode_value(iso_now()) + "}"
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
  #|  const current = review.rounds[review.rounds.length - 1];
  #|  current.submitted_at = new Date().toISOString();
  #|  current.decision = submit.decision || null;
  #|  current.summary = submit.summary || "";
  #|  review.comments = Array.isArray(review.comments) ? review.comments : [];
  #|  const roundNo = Number(current.round || review.rounds.length);
  #|  let seq = review.comments.filter(c => Number(c.round) === roundNo).length + 1;
  #|  for (const c of submit.comments || []) {
  #|    const row = Number(c.row || 0);
  #|    const line = row + 1;
  #|    const snippet = String(c.value || sourceLines[row] || "");
  #|    const before = row > 0 ? String(sourceLines[row - 1] || "") : "";
  #|    const after = row + 1 < sourceLines.length ? String(sourceLines[row + 1] || "") : "";
  #|    review.comments.push({
  #|      id: `c-${roundNo}-${seq++}`,
  #|      file,
  #|      line,
  #|      round: roundNo,
  #|      text: String(c.text || ""),
  #|      author: "human",
  #|      status: "unresolved",
  #|      replies: [],
  #|      anchor: { snippet, context_before: before, context_after: after }
  #|    });
  #|  }
  #|  return JSON.stringify(review, null, 2);
  #|}

///|
fn update_review_on_submit(file_path : String, body : String, source_lines : Array[String], round : Int) -> Unit {
  ensure_review_state(file_path)
  let review_path = review_json_path_for_file(file_path)
  let current = read_file_safe(review_path)
  write_file_secure(
    review_path,
    js_review_submit_update(current, body, review_display_file(file_path), source_lines),
  )
  try_call_void(fn() { fs_copy_file_sync(file_path, review_snapshot_path(file_path, round)) })
}

///|
extern "js" fn js_review_current_round(json : String) -> Int =
  #|(json) => { try { const r = JSON.parse(json).rounds || []; return Number((r[r.length - 1] || {}).round || 1); } catch(e) { return 1; } }

///|
fn current_review_round(file_path : String) -> Int {
  ensure_review_state(file_path)
  js_review_current_round(read_file_safe(review_json_path_for_file(file_path)))
}

///|
extern "js" fn js_review_start_next_round(json : String, current_text : String) -> String =
  #|(json, currentText) => {
  #|  const review = JSON.parse(json || "{}");
  #|  review.rounds = Array.isArray(review.rounds) ? review.rounds : [];
  #|  const last = review.rounds[review.rounds.length - 1];
  #|  if (!last || last.submitted_at) {
  #|    const next = last ? Number(last.round || review.rounds.length) + 1 : 1;
  #|    review.rounds.push({ round: next, started_at: new Date().toISOString(), submitted_at: null, decision: null, summary: "" });
  #|  }
  #|  const lines = String(currentText || "").split(/\r?\n/);
  #|  for (const c of review.comments || []) {
  #|    if (c.status !== "unresolved") continue;
  #|    const snippet = c.anchor && c.anchor.snippet ? String(c.anchor.snippet) : "";
  #|    if (!snippet) continue;
  #|    const idx = lines.findIndex(line => line === snippet || line.includes(snippet));
  #|    if (idx >= 0) c.line = idx + 1;
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
) -> String =
  #|(reviewJson, currentText, previousText, gateEnabled) => {
  #|  let review;
  #|  try { review = JSON.parse(reviewJson || "{}"); } catch { review = {}; }
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
  #|  const currentRound = Number(((review.rounds || []).at(-1) || {}).round || 1);
  #|  const unresolved = (review.comments || []).filter(c => c.status !== "resolved").length;
  #|  const gateUnresolved = gateEnabled ? (review.comments || []).filter(c => c.status !== "resolved" && Number(c.round || 0) < currentRound).length : 0;
  #|  return JSON.stringify({ review, diff: { lines }, unresolved_count: unresolved, gate_unresolved_count: gateUnresolved, is_loop: !!gateEnabled });
  #|}

///|
fn review_state_response(file_path : String, gate_enabled : Bool) -> String {
  ensure_review_state(file_path)
  let review_json = read_file_safe(review_json_path_for_file(file_path))
  let round = current_review_round(file_path)
  let prev_path = review_snapshot_path(file_path, round - 1)
  let previous_text = if exists_sync(prev_path) { read_file_safe(prev_path) } else { "" }
  js_review_response_json(review_json, read_file_safe(file_path), previous_text, gate_enabled)
}

///|
extern "js" fn js_review_resolve(json : String, id : String) -> String =
  #|(json, id) => {
  #|  const review = JSON.parse(json || "{}");
  #|  for (const c of review.comments || []) if (c.id === id) c.status = "resolved";
  #|  return JSON.stringify(review, null, 2);
  #|}

///|
fn resolve_review_comment(file_path : String, id : String) -> Unit {
  ensure_review_state(file_path)
  let review_path = review_json_path_for_file(file_path)
  write_file_secure(review_path, js_review_resolve(read_file_safe(review_path), id))
}

///|
extern "js" fn js_review_reply(
  json : String,
  id : String,
  text : String,
  author : String,
) -> String =
  #|(json, id, text, author) => {
  #|  const review = JSON.parse(json || "{}");
  #|  const rounds = Array.isArray(review.rounds) ? review.rounds : [];
  #|  const currentRound = Number((rounds[rounds.length - 1] || {}).round || 1);
  #|  review.comments = Array.isArray(review.comments) ? review.comments : [];
  #|  for (const c of review.comments) {
  #|    if (c.id === id) {
  #|      c.replies = Array.isArray(c.replies) ? c.replies : [];
  #|      c.replies.push({ author: author || "agent", round: currentRound, text: String(text || "") });
  #|      break;
  #|    }
  #|  }
  #|  return JSON.stringify(review, null, 2);
  #|}

///|
fn reply_review_comment(file_path : String, id : String, text : String, author : String) -> Unit {
  ensure_review_state(file_path)
  let review_path = review_json_path_for_file(file_path)
  write_file_secure(review_path, js_review_reply(read_file_safe(review_path), id, text, author))
}

///|
fn reply_review_comment_cwd(id : String, text : String, author : String) -> Unit {
  let review_path = review_json_path_for_cwd()
  write_file_secure(review_path, js_review_reply(read_file_safe(review_path), id, text, author))
}

///|
extern "js" fn js_review_prior_unresolved_count(json : String) -> Int =
  #|(json) => {
  #|  try {
  #|    const review = JSON.parse(json || "{}");
  #|    const currentRound = Number(((review.rounds || []).at(-1) || {}).round || 1);
  #|    return (review.comments || []).filter(c => c.status !== "resolved" && Number(c.round || 0) < currentRound).length;
  #|  } catch(e) {
  #|    return 0;
  #|  }
  #|}

///|
fn review_prior_unresolved_count(file_path : String) -> Int {
  ensure_review_state(file_path)
  js_review_prior_unresolved_count(read_file_safe(review_json_path_for_file(file_path)))
}

///|
fn json_parse_int_field(key : String, json_str : String) -> Int {
  @core.parse_int_safe(json_parse_string(key, json_str))
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
extern "js" fn split_notify_command(command : String, msg : String) -> Array[String] =
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
  let result = child_spawn_sync(cmd, js_array_from_strings(args), js_spawn_opts_utf8_pipe())
  (js_obj_status(result), js_obj_stderr(result))
}

///|
fn spawn_sync_shell_status(cmd : String) -> (Int, String) {
  let result = child_spawn_sync(cmd, js_array_from_strings([]), js_spawn_opts_shell_utf8())
  (js_obj_status(result), js_obj_stderr(result))
}

///|
extern "js" fn js_spawn_opts_shell_utf8() -> JsValue =
  #|() => ({ encoding: "utf8", shell: true, stdio: ["ignore", "pipe", "pipe"] })

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
  line : Int,
  text : String,
  checked : Bool,
  now : String,
) -> String =
  #|(existing, branch, file, line, text, checked, now) => {
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
  #|  if (!review.files.includes(file)) review.files.push(file);
  #|  const id = `d-${Buffer.from(`${file}:${line}`).toString("base64url").slice(0, 16)}`;
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
  context_before : String,
  context_after : String,
  now : String,
) -> String =
  #|(existing, branch, file, line, text, author, snippet, before, after, now) => {
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
  #|    round = Number(review.rounds[review.rounds.length - 1]?.round || 1) || 1;
  #|  }
  #|  let seq = 1;
  #|  for (const c of review.comments) {
  #|    if (Number(c?.round || 0) === round) seq += 1;
  #|  }
  #|  review.comments.push({
  #|    id: `c-${round}-${seq}`,
  #|    file,
  #|    line,
  #|    round,
  #|    text,
  #|    author,
  #|    status: "unresolved",
  #|    replies: [],
  #|    anchor: { snippet, context_before: before, context_after: after }
  #|  });
  #|  return JSON.stringify(review, null, 2) + "\n";
  #|}
