///|
/// DOM external types
#external
pub type Element

///|
#external
pub type Event

///|
#external
pub type EventSource

///|
/// Listener handle for event cleanup (ListenerHandle/unlisten pattern)
#external
pub type ListenerHandle

///|
/// DOM query
extern "js" fn query(selector : String) -> Element =
  #|(s) => document.querySelector(s)

///|
extern "js" fn query_all(selector : String) -> Array[Element] =
  #|(s) => [...document.querySelectorAll(s)]

///|
/// Element properties
extern "js" fn get_attr(el : Element, name : String) -> String =
  #|(el, name) => el?.getAttribute(name) || ""

///|
extern "js" fn set_inner_html(el : Element, html : String) -> Unit =
  #|(el, html) => { if (el) el.innerHTML = html; }

///|
extern "js" fn _get_inner_html(el : Element) -> String =
  #|(el) => el?.innerHTML || ""

///|
extern "js" fn get_text_content(el : Element) -> String =
  #|(el) => el?.textContent || ""

///|
extern "js" fn get_text_content_without_comment_buttons(el : Element) -> String =
  #|(el) => {
  #|  if (!el) return "";
  #|  const clone = el.cloneNode(true);
  #|  clone.querySelectorAll?.(".yunomi-comment-button").forEach((btn) => btn.remove());
  #|  return clone.textContent || "";
  #|}

///|
extern "js" fn get_value(el : Element) -> String =
  #|(el) => el?.value || ""

///|
extern "js" fn set_value(el : Element, val : String) -> Unit =
  #|(el, val) => { if (el) el.value = val; }

///|
extern "js" fn add_class(el : Element, cls : String) -> Unit =
  #|(el, cls) => el?.classList.add(cls)

///|
extern "js" fn remove_class(el : Element, cls : String) -> Unit =
  #|(el, cls) => el?.classList.remove(cls)

///| Event handling with ListenerHandle pattern for cleanup

///|
/// Returns a handle that can be used to remove the listener
extern "js" fn on_with_handle(
  el : Element,
  event : String,
  handler : (Event) -> Unit,
  capture? : Bool = false,
  passive? : Bool = true,
) -> ListenerHandle =
  #|(el, event, handler, capture, passive) => {
  #|  const wrapped = (e) => handler(e);
  #|  const options = { capture, passive };
  #|  el?.addEventListener(event, wrapped, options);
  #|  return { el, event, handler: wrapped, options };
  #|}

///|
/// Remove event listener using handle
extern "js" fn unlisten(handle : ListenerHandle) -> Unit =
  #|(handle) => {
  #|  if (handle?.disconnect) {
  #|    handle.disconnect();
  #|    return;
  #|  }
  #|  if (handle?.remove) {
  #|    handle.remove();
  #|    return;
  #|  }
  #|  if (handle && handle.el) {
  #|    handle.el.removeEventListener(handle.event, handle.handler, handle.options);
  #|  }
  #|}

///|
/// Legacy on() - kept for backward compatibility
extern "js" fn on(
  el : Element,
  event : String,
  handler : (Event) -> Unit,
) -> Unit =
  #|(el, event, handler) => el?.addEventListener(event, handler)

///|
/// Remove event listener (legacy)
extern "js" fn _off(
  el : Element,
  event : String,
  handler : (Event) -> Unit,
) -> Unit =
  #|(el, event, handler) => el?.removeEventListener(event, handler)

///|
extern "js" fn on_doc(event : String, handler : (Event) -> Unit) -> Unit =
  #|(event, handler) => document.addEventListener(event, handler)

///|
extern "js" fn _off_doc(event : String, handler : (Event) -> Unit) -> Unit =
  #|(event, handler) => document.removeEventListener(event, handler)

///|
extern "js" fn event_target(e : Event) -> Element =
  #|(e) => {
  #|  const target = e?.target;
  #|  if (!target) return null;
  #|  return target.nodeType === 3 ? target.parentElement : target;
  #|}

///|
extern "js" fn event_key(e : Event) -> String =
  #|(e) => e.key || ""

///|
extern "js" fn event_meta_key(e : Event) -> Bool =
  #|(e) => e.metaKey || false

///|
extern "js" fn event_ctrl_key(e : Event) -> Bool =
  #|(e) => e.ctrlKey || false

///|
extern "js" fn event_shift_key(e : Event) -> Bool =
  #|(e) => e.shiftKey || false

///|
extern "js" fn _event_is_composing(e : Event) -> Bool =
  #|(e) => e.isComposing || e.keyCode === 229

///|
/// Set disabled attribute on element
extern "js" fn set_disabled(el : Element, disabled : Bool) -> Unit =
  #|(el, disabled) => { if (el) el.disabled = disabled; }

///|
extern "js" fn is_checked(el : Element) -> Bool =
  #|(el) => !!el?.checked

///|
extern "js" fn set_checked(el : Element, checked : Bool) -> Unit =
  #|(el, checked) => { if (el) el.checked = checked; }

///|
extern "js" fn prevent_default(e : Event) -> Unit =
  #|(e) => e.preventDefault()

///|
extern "js" fn closest(el : Element, selector : String) -> Element =
  #|(el, sel) => el?.closest(sel)

///|
/// Position and size
extern "js" fn _get_bounding_rect_top(el : Element) -> Double =
  #|(el) => el?.getBoundingClientRect().top || 0

///|
extern "js" fn _get_bounding_rect_left(el : Element) -> Double =
  #|(el) => el?.getBoundingClientRect().left || 0

///|
extern "js" fn _get_bounding_rect_bottom(el : Element) -> Double =
  #|(el) => el?.getBoundingClientRect().bottom || 0

///|
extern "js" fn window_inner_height() -> Int =
  #|() => window.innerHeight

///|
/// Style
extern "js" fn set_style(el : Element, prop : String, value : String) -> Unit =
  #|(el, prop, val) => { if (el) el.style[prop] = val; }

///|
/// Theme
extern "js" fn get_theme() -> String =
  #|() => document.documentElement.getAttribute("data-theme") || "dark"

///|
extern "js" fn set_theme(theme : String) -> Unit =
  #|(theme) => document.documentElement.setAttribute("data-theme", theme)

///|
extern "js" fn rerender_mermaid(theme : String) -> Unit =
  #|(theme) => {
  #|  if (typeof window.__reRenderMermaid === "function") {
  #|    window.__reRenderMermaid(theme);
  #|  }
  #|}

///|
extern "js" fn init_color_scheme_menu() -> Unit =
  #|() => {
  #|  const root = document.documentElement;
  #|  const picker = document.getElementById("theme-picker");
  #|  const toggle = document.getElementById("theme-menu-toggle");
  #|  const menu = document.getElementById("theme-menu");
  #|  if (!picker || !toggle || !menu) return;
  #|  const buttons = Array.from(menu.querySelectorAll("[data-color-scheme]"));
  #|  const apply = (scheme) => {
  #|    const safe = buttons.some((btn) => btn.getAttribute("data-color-scheme") === scheme) ? scheme : "primer";
  #|    root.setAttribute("data-color-scheme", safe);
  #|    try { localStorage.setItem("yunomi:color-scheme", safe); } catch (_) {}
  #|    buttons.forEach((btn) => btn.classList.toggle("active", btn.getAttribute("data-color-scheme") === safe));
  #|  };
  #|  let saved = "";
  #|  try { saved = localStorage.getItem("yunomi:color-scheme") || ""; } catch (_) {}
  #|  apply(saved || root.getAttribute("data-color-scheme") || "primer");
  #|  const close = () => { menu.hidden = true; toggle.setAttribute("aria-expanded", "false"); };
  #|  toggle.addEventListener("click", (event) => {
  #|    event.stopPropagation();
  #|    const next = menu.hidden;
  #|    menu.hidden = !next;
  #|    toggle.setAttribute("aria-expanded", next ? "true" : "false");
  #|  });
  #|  buttons.forEach((btn) => btn.addEventListener("click", (event) => {
  #|    event.stopPropagation();
  #|    apply(btn.getAttribute("data-color-scheme") || "primer");
  #|    close();
  #|  }));
  #|  document.addEventListener("click", (event) => {
  #|    if (!picker.contains(event.target)) close();
  #|  });
  #|}

///|
/// SSE
extern "js" fn new_event_source(url : String) -> EventSource =
  #|(url) => new EventSource(url)

///|
extern "js" fn sse_on(
  es : EventSource,
  event : String,
  handler : (Event) -> Unit,
) -> Unit =
  #|(es, event, handler) => es.addEventListener(event, handler)

///|
/// Read the data payload from an SSE message event
extern "js" fn sse_event_data(e : Event) -> String =
  #|(e) => String((e && e.data) || "")

///|
extern "js" fn apply_comment_reply_event(
  filename : String,
  data : String,
) -> Unit =
  #|(filename, data) => {
  #|  let event;
  #|  try { event = JSON.parse(data || "{}"); } catch (_) { return; }
  #|  const id = String(event.id || "");
  #|  if (!id) return;
  #|  const esc = (s) => String(s || "").replace(/[&<>"']/g, ch => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", "\"": "&quot;", "'": "&#39;" }[ch]));
  #|  const key = `yunomi:comment-replies:${filename || "current"}`;
  #|  let store = {};
  #|  try { store = JSON.parse(localStorage.getItem(key) || "{}"); } catch (_) { store = {}; }
  #|  const list = Array.isArray(store[id]) ? store[id] : [];
  #|  list.push({
  #|    author: String(event.author || "agent"),
  #|    round: Number(event.round || 1),
  #|    text: String(event.text || "")
  #|  });
  #|  store[id] = list;
  #|  localStorage.setItem(key, JSON.stringify(store));
  #|  for (const item of document.querySelectorAll("#comment-list li[data-key]")) {
  #|    if ((item.getAttribute("data-key") || "") !== id) continue;
  #|    let replies = item.querySelector(".comment-inline-replies");
  #|    if (!replies) {
  #|      item.insertAdjacentHTML("beforeend", `<ul class="comment-inline-replies"></ul>`);
  #|      replies = item.querySelector(".comment-inline-replies");
  #|    }
  #|    replies?.insertAdjacentHTML("beforeend", `<li><strong>${esc(event.author || "agent")}</strong> R${esc(event.round || 1)}: ${esc(event.text || "")}</li>`);
  #|  }
  #|}

///|
extern "js" fn render_comment_replies_for_file(filename : String) -> Unit =
  #|(filename) => {
  #|  const key = `yunomi:comment-replies:${filename || "current"}`;
  #|  let store = {};
  #|  try { store = JSON.parse(localStorage.getItem(key) || "{}"); } catch (_) { store = {}; }
  #|  const esc = (s) => String(s || "").replace(/[&<>"']/g, ch => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", "\"": "&quot;", "'": "&#39;" }[ch]));
  #|  for (const item of document.querySelectorAll("#comment-list li[data-key]")) {
  #|    const id = item.getAttribute("data-key") || "";
  #|    item.querySelector(".comment-inline-replies")?.remove();
  #|    const replies = Array.isArray(store[id]) ? store[id] : [];
  #|    if (replies.length === 0) continue;
  #|    const html = replies.map(r => `<li><strong>${esc(r.author)}</strong> R${esc(r.round)}: ${esc(r.text)}</li>`).join("");
  #|    item.insertAdjacentHTML("beforeend", `<ul class="comment-inline-replies">${html}</ul>`);
  #|  }
  #|}

///|
extern "js" fn mark_send_now_event(data : String) -> Unit =
  #|(data) => {
  #|  let event;
  #|  try { event = JSON.parse(data || "{}"); } catch (_) { return; }
  #|  const id = String(event.key || "");
  #|  if (!id) return;
  #|  for (const item of document.querySelectorAll("#comment-list li[data-key]")) {
  #|    if ((item.getAttribute("data-key") || "") !== id) continue;
  #|    item.querySelector(".comment-sent-badge")?.remove();
  #|    item.insertAdjacentHTML("beforeend", `<span class="comment-sent-badge sent">sent</span>`);
  #|  }
  #|}

///|
/// Replace current location without adding a history entry
extern "js" fn location_replace(url : String) -> Unit =
  #|(url) => location.replace(url)

///|
/// Fetch POST
extern "js" fn fetch_post(
  url : String,
  body : String,
  callback : (String) -> Unit,
) -> Unit =
  #|(url, body, cb) => {
  #|  fetch(url, {
  #|    method: "POST",
  #|    headers: {"Content-Type": "application/json"},
  #|    body: body
  #|  }).then(r => r.text()).then(cb).catch(() => cb("error"));
  #|}

///|
extern "js" fn fetch_post_keepalive(url : String, body : String) -> Unit =
  #|(url, body) => {
  #|  fetch(url, {
  #|    method: "POST",
  #|    headers: {"Content-Type": "application/json"},
  #|    body: body,
  #|    keepalive: true
  #|  }).catch(() => {});
  #|}

///|
extern "js" fn send_beacon_json(url : String, body : String) -> Unit =
  #|(url, body) => {
  #|  try {
  #|    if (navigator.sendBeacon) {
  #|      const blob = new Blob([body], { type: "application/json" });
  #|      if (navigator.sendBeacon(url, blob)) {
  #|        return;
  #|      }
  #|    }
  #|  } catch (_) {}
  #|  fetch(url, {
  #|    method: "POST",
  #|    headers: {"Content-Type": "application/json"},
  #|    body: body,
  #|    keepalive: true
  #|  }).catch(() => {});
  #|}

///|
/// localStorage
extern "js" fn ls_get(key : String) -> String =
  #|(key) => localStorage.getItem(key) || ""

///|
extern "js" fn ls_set(key : String, value : String) -> Unit =
  #|(key, val) => localStorage.setItem(key, val)

///|
extern "js" fn ls_remove(key : String) -> Unit =
  #|(key) => localStorage.removeItem(key)

///|
/// Window globals
extern "js" fn get_yunomi_port() -> Int =
  #|() => window.__YUNOMI_PORT__ || 4989

///|
extern "js" fn get_yunomi_mode() -> String =
  #|() => window.__YUNOMI_MODE__ || "text"

///|
extern "js" fn get_yunomi_filename() -> String =
  #|() => window.__YUNOMI_FILENAME__ || ""

///|
extern "js" fn get_yunomi_server_instance() -> String =
  #|() => window.__YUNOMI_SERVER_INSTANCE__ || ""

///|
extern "js" fn retire_if_stale_review_session(current : String) -> Bool =
  #|(current) => {
  #|  if (!current) return false;
  #|  const tabKey = "yunomi:tab-id";
  #|  const serverKey = "yunomi:server-instance";
  #|  try {
  #|    const tabId = sessionStorage.getItem(tabKey) || "";
  #|    const previous = sessionStorage.getItem(serverKey) || "";
  #|    if (tabId && previous !== current) {
  #|      sessionStorage.setItem(serverKey, current);
  #|      return true;
  #|    }
  #|    sessionStorage.setItem(serverKey, current);
  #|    return false;
  #|  } catch (_) {
  #|    return false;
  #|  }
  #|}

///|
extern "js" fn get_or_create_tab_id() -> String =
  #|() => {
  #|  const key = "yunomi:tab-id";
  #|  try {
  #|    let id = sessionStorage.getItem(key);
  #|    if (!id) {
  #|      id = `${Date.now()}-${Math.random().toString(36).slice(2, 10)}`;
  #|      sessionStorage.setItem(key, id);
  #|    }
  #|    return id;
  #|  } catch (_) {
  #|    if (!window.name) {
  #|      window.name = `yunomi-${Date.now()}-${Math.random().toString(36).slice(2, 10)}`;
  #|    }
  #|    return window.name;
  #|  }
  #|}

///|
extern "js" fn create_page_instance_id() -> String =
  #|() => `${Date.now()}-${Math.random().toString(36).slice(2, 10)}`

///|
/// Focus
extern "js" fn focus_element(el : Element) -> Unit =
  #|(el) => el?.focus()

///|
/// is null check
extern "js" fn is_null(el : Element) -> Bool =
  #|(el) => el == null || el == undefined

///|
extern "js" fn null_element() -> Element =
  #|() => null

///|
/// Parse stored comments JSON (cli.cjs { comments, timestamp } format)
extern "js" fn parse_stored_comments(json : String) -> Array[Array[String]] =
  #|(json) => {
  #|  try {
  #|    const data = JSON.parse(json);
  #|    const comments = data.comments;
  #|    if (!comments || typeof comments !== "object") return [];
  #|    return Object.entries(comments).map(([k, v]) => [k, String(v.row||0), String(v.col||0), v.text||"", v.value||"", String(v.pending === true), String(v.sent !== false)]);
  #|  } catch(e) { return []; }
  #|}

///|
/// Extract the saved global summary/decision comment from the same draft
/// blob persisted by persist_draft() (comments + summary + answers share one
/// localStorage entry so a single Restore/Discard flow covers all of them).
extern "js" fn parse_stored_summary(json : String) -> String =
  #|(json) => {
  #|  try {
  #|    const data = JSON.parse(json);
  #|    return typeof data.summary === "string" ? data.summary : "";
  #|  } catch (e) { return ""; }
  #|}

///|
/// Extract the saved per-question draft answers (option + free text) as a
/// JSON string ready for apply_yunomi_draft_answers().
extern "js" fn parse_stored_answers(json : String) -> String =
  #|(json) => {
  #|  try {
  #|    const data = JSON.parse(json);
  #|    return JSON.stringify(data.answers && typeof data.answers === "object" ? data.answers : {});
  #|  } catch (e) { return "{}"; }
  #|}

///|
/// Extract the saved stepper position (frontmatter question stepper's
/// current step index) from the same draft blob persist_draft() writes.
/// Missing/invalid on older drafts (saved before the stepper existed) is
/// treated as step 0 — fully backward compatible.
extern "js" fn parse_stored_step(json : String) -> Int =
  #|(json) => {
  #|  try {
  #|    const data = JSON.parse(json);
  #|    const n = Number(data.step);
  #|    return Number.isFinite(n) && n >= 0 ? Math.floor(n) : 0;
  #|  } catch (e) { return 0; }
  #|}

///|
/// Extract the active inline editor target saved immediately before a preview
/// refresh. Older drafts return an empty array and simply restore comments.
extern "js" fn parse_stored_active_comment(json : String) -> Array[String] =
  #|(json) => {
  #|  try {
  #|    const ui = JSON.parse(json).ui || {};
  #|    if (!ui.comment_open || !ui.active_key) return [];
  #|    return [String(ui.active_key), String(ui.active_row || 0), String(ui.active_col || 0)];
  #|  } catch (e) { return []; }
  #|}

///|
/// Whether Submit Review was open when the preview refresh began.
extern "js" fn parse_stored_submit_open(json : String) -> Bool =
  #|(json) => {
  #|  try { return JSON.parse(json).ui?.submit_open === true; } catch (e) { return false; }
  #|}

///|
/// Resolve a restored editor against the newly rendered, visible DOM.
extern "js" fn resolve_restored_comment_target(
  key : String,
  row : Int,
  col : Int,
) -> Element =
  #|(key, row, col) => {
  #|  const visible = (element) => {
  #|    if (!element) return false;
  #|    if (element.closest?.("details:not([open])") && !element.closest?.("summary")) return false;
  #|    const style = getComputedStyle(element);
  #|    const rect = element.getBoundingClientRect();
  #|    return style.display !== "none" && style.visibility !== "hidden" && rect.width > 0 && rect.height > 0;
  #|  };
  #|  if (col > 0) {
  #|    const cell = document.querySelector(`#md-preview [data-row="${row}"][data-col="${col}"]`);
  #|    if (visible(cell)) return cell;
  #|  }
  #|  const parts = String(key || "").split(":");
  #|  const anchorTag = parts.length > 2 ? parts[parts.length - 1].toLowerCase() : "";
  #|  const candidates = Array.from(document.querySelectorAll(`#md-preview [data-source-line="${row + 1}"],#md-preview [data-source-start-line="${row + 1}"]`)).filter(visible);
  #|  const preview = anchorTag
  #|    ? candidates.find((element) => element.tagName.toLowerCase() === anchorTag)
  #|      || candidates.map((element) => element.querySelector?.(anchorTag)).find(visible)
  #|    : candidates[candidates.length - 1];
  #|  if (preview) return preview;
  #|  const source = document.querySelector(`td[data-row="${row}"][data-col="1"]:not(#md-preview *),.text-line[data-row="${row}"],.diff-line[data-row="${row}"]`);
  #|  return visible(source) ? source : null;
  #|}

///|
/// Check if stored comments JSON has expired (TTL: 3 hours)
extern "js" fn is_storage_expired(json : String) -> Bool =
  #|(json) => {
  #|  try {
  #|    const data = JSON.parse(json);
  #|    const TTL = 3 * 60 * 60 * 1000;
  #|    return !data.timestamp || (Date.now() - data.timestamp > TTL);
  #|  } catch(e) { return true; }
  #|}

///|
/// Current timestamp as string for JSON embedding
extern "js" fn date_now_string() -> String =
  #|() => String(Date.now())

///|
/// Window close
extern "js" fn window_close() -> Unit =
  #|() => window.close()

///|
/// Location origin (e.g. "http://127.0.0.1:4989")
extern "js" fn location_origin() -> String =
  #|() => location.origin

///|
/// Location reload
extern "js" fn location_reload() -> Unit =
  #|() => location.reload()

///|
/// Scroll
extern "js" fn get_scroll_top(el : Element) -> Double =
  #|(el) => el?.scrollTop || 0

///|
extern "js" fn set_scroll_top(el : Element, val : Double) -> Unit =
  #|(el, val) => { if (el) el.scrollTop = val; }

///|
extern "js" fn get_scroll_height(el : Element) -> Double =
  #|(el) => el?.scrollHeight || 0

///|
extern "js" fn get_client_height(el : Element) -> Double =
  #|(el) => el?.clientHeight || 0

///|
/// Animation frame
extern "js" fn request_animation_frame(callback : () -> Unit) -> Int =
  #|(cb) => requestAnimationFrame(cb)

///|
extern "js" fn cancel_animation_frame(id : Int) -> Unit =
  #|(id) => cancelAnimationFrame(id)

///|
/// Query within parent
extern "js" fn query_all_in(
  parent : Element,
  selector : String,
) -> Array[Element] =
  #|(parent, s) => [...(parent?.querySelectorAll(s) || [])]

///|
/// Timers
extern "js" fn date_now() -> Double =
  #|() => Date.now()

///|
extern "js" fn set_timeout(callback : () -> Unit, ms : Int) -> Int =
  #|(cb, ms) => setTimeout(cb, ms)

///|
extern "js" fn _clear_timeout(id : Int) -> Unit =
  #|(id) => clearTimeout(id)

///|
/// Window events
extern "js" fn on_window(event : String, handler : (Event) -> Unit) -> Unit =
  #|(event, handler) => window.addEventListener(event, handler)

///|
extern "js" fn _off_window(event : String, handler : (Event) -> Unit) -> Unit =
  #|(event, handler) => window.removeEventListener(event, handler)

///|
/// Body class manipulation
extern "js" fn add_class_body(cls : String) -> Unit =
  #|(cls) => document.body.classList.add(cls)

///|
extern "js" fn remove_class_body(cls : String) -> Unit =
  #|(cls) => document.body.classList.remove(cls)

///|
/// Event coordinates
extern "js" fn get_event_client_x(e : Event) -> Int =
  #|(e) => e.clientX || 0

///|
extern "js" fn get_event_client_y(e : Event) -> Int =
  #|(e) => e.clientY || 0

///|
extern "js" fn _get_event_offset_x(e : Event) -> Double =
  #|(e) => e.offsetX || 0

///|
extern "js" fn _get_event_offset_y(e : Event) -> Double =
  #|(e) => e.offsetY || 0

///|
extern "js" fn get_event_delta_x(e : Event) -> Double =
  #|(e) => e.deltaX || 0

///|
extern "js" fn get_event_delta_y(e : Event) -> Double =
  #|(e) => e.deltaY || 0

///|
extern "js" fn get_event_button(e : Event) -> Int =
  #|(e) => e.button || 0

///|
/// Pointer Events (unified mouse/touch)
extern "js" fn _get_pointer_id(e : Event) -> Int =
  #|(e) => e.pointerId || 0

///|
extern "js" fn _get_pointer_type(e : Event) -> String =
  #|(e) => e.pointerType || ""

///|
extern "js" fn _get_pressure(e : Event) -> Double =
  #|(e) => e.pressure || 0

///|
/// Touch Events (for pinch gestures)
extern "js" fn get_touches(e : Event) -> Array[Event] =
  #|(e) => Array.from(e.touches || [])

///|
extern "js" fn _get_changed_touches(e : Event) -> Array[Event] =
  #|(e) => Array.from(e.changedTouches || [])

///|
extern "js" fn touch_get_client_x(touch : Event) -> Double =
  #|(t) => t.clientX || 0

///|
extern "js" fn touch_get_client_y(touch : Event) -> Double =
  #|(t) => t.clientY || 0

///|
extern "js" fn element_from_point(x : Int, y : Int) -> Element =
  #|(x, y) => document.elementFromPoint(x, y)

///|
/// Fetch GET with callback
extern "js" fn fetch_get(url : String, callback : (String) -> Unit) -> Unit =
  #|(url, cb) => fetch(url).then(r => r.text()).then(cb).catch(() => cb("[]"))

///|
extern "js" fn render_review_loop_panel_json(json : String) -> Int =
  #|(json) => {
  #|  const panel = document.querySelector("#review-loop-panel");
  #|  if (!panel) return 0;
  #|  let state;
  #|  try { state = JSON.parse(json || "{}"); } catch { panel.innerHTML = ""; window.__YUNOMI_REVIEW_LOOP_STATUS__ = ""; window.__YUNOMI_REVIEW_LOOP_GATE__ = 0; return 0; }
  #|  const review = state.review || {};
  #|  const rounds = Array.isArray(review.rounds) ? review.rounds : [];
  #|  const round = rounds[rounds.length - 1] || {};
  #|  const comments = Array.isArray(review.comments) ? review.comments : [];
  #|  if (comments.length === 0 && rounds.length <= 1) {
  #|    panel.innerHTML = "";
  #|    window.__YUNOMI_REVIEW_LOOP_STATUS__ = "";
  #|    window.__YUNOMI_REVIEW_LOOP_GATE__ = 0;
  #|    return 0;
  #|  }
  #|  const currentRound = Number(round.round || 1);
  #|  const unresolved = comments.filter(c => c.status !== "resolved");
  #|  const gateUnresolved = Number(state.gate_unresolved_count || 0);
  #|  window.__YUNOMI_REVIEW_LOOP_STATUS__ = `Round ${currentRound} ・ ${unresolved.length > 0 ? `${unresolved.length} unresolved` : "All resolved"}`;
  #|  window.__YUNOMI_REVIEW_LOOP_GATE__ = gateUnresolved;
  #|  const esc = (s) => String(s ?? "").replace(/[&<>"']/g, ch => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[ch]));
  #|  const ja = /^ja\b/i.test(navigator.language || "");
  #|  const t = ja ? {
  #|    noReply: "AIからの返信はまだありません",
  #|    afterMissing: "この依頼に直接対応する変更は、まだ自動では確認できません",
  #|    afterChanged: "現在の変更",
  #|    checkState: "確認状況",
  #|    target: "確認する対象",
  #|    beforeTarget: "依頼時の対象",
  #|    resolved: "解決済み",
  #|    resolve: "確認して解決",
  #|    resolveTitle: "依頼どおりの結果を確認してから解決にします",
  #|    inlineLabel: "この箇所の確認項目",
  #|    itemLabel: "確認項目",
  #|    request: "レビューコメント",
  #|    response: "AIからの返信",
  #|    header: (_n) => "確認項目",
  #|    meta: (n) => `未解決 ${n} 件`,
  #|    reason: "今回の指摘",
  #|    guide: "レビューの進め方",
  #|    guideText: "依頼、現在の変更、AIからの返信を確認してから解決にします。",
  #|    noSummary: "前回の総評はありません。各確認項目の依頼を確認してください。",
  #|    diffLabel: (_n) => "前回提出時 → 現在の全体差分（補助情報）"
  #|  } : {
  #|    noReply: "No AI reply yet",
  #|    afterMissing: "No direct matching change was detected yet",
  #|    afterChanged: "Current change",
  #|    checkState: "Check status",
  #|    target: "Review target",
  #|    beforeTarget: "Original target",
  #|    resolved: "Resolved",
  #|    resolve: "Resolve",
  #|    resolveTitle: "Resolve only after verifying the requested result",
  #|    inlineLabel: "Review target",
  #|    itemLabel: "Review item",
  #|    request: "Previous request",
  #|    response: "AI reply",
  #|    header: (_n) => "Review items",
  #|    meta: (n) => `${n} unresolved`,
  #|    reason: "Latest reviewer note",
  #|    guide: "Review flow",
  #|    guideText: "Verify the request, current changes, and AI reply before resolving.",
  #|    noSummary: "No previous summary. Review each request.",
  #|    diffLabel: (_n) => "Previous submission to current diff"
  #|  };
  #|  const norm = (s) => String(s ?? "").replace(/\s+/g, " ").trim();
  #|  const lineText = (line) => String((line && line.text) || "");
  #|  const diffLines = state.diff && Array.isArray(state.diff.lines) ? state.diff.lines : [];
  #|  const matchCommentDiff = (c) => {
  #|    const anchor = c.anchor || {};
  #|    const original = String(anchor.snippet || "").trim();
  #|    // Line numbers drift after edits. Only call a changed line evidence
  #|    // when the old source text itself matches the comment's anchor.
  #|    // This avoids presenting an unrelated table header as the answer to
  #|    // a review request.
  #|    const deletionIndex = original
  #|      ? diffLines.findIndex(l => l.kind === "deletion" && lineText(l).trim() === original)
  #|      : -1;
  #|    let after = "";
  #|    if (deletionIndex >= 0) {
  #|      for (let i = deletionIndex + 1; i < Math.min(diffLines.length, deletionIndex + 5); i += 1) {
  #|        if (diffLines[i].kind === "addition") {
  #|          after = lineText(diffLines[i]);
  #|          break;
  #|        }
  #|      }
  #|    }
  #|    return { before: original || "No original source snippet was recorded", after };
  #|  };
  #|  const commentResponse = (c) => Array.isArray(c.replies)
  #|    ? c.replies.filter(r => String(r.author || "") === "agent").at(-1)?.text || t.noReply
  #|    : t.noReply;
  #|  const commentStateText = (c) => {
  #|    const hasAgentReply = Array.isArray(c.replies) && c.replies.some(r => String(r.author || "") === "agent");
  #|    return c.status === "resolved" ? "resolved" : (hasAgentReply ? "unresolved + replied" : "unresolved");
  #|  };
  #|  const snippetHtml = (c) => {
  #|    const s = matchCommentDiff(c);
  #|    const after = s.after || t.afterMissing;
  #|    const afterState = s.after ? t.afterChanged : t.checkState;
  #|    return `<div class="review-loop-snippet" aria-label="Review item source evidence"><div class="review-loop-snippet-label">${esc(t.target)}</div><div class="review-loop-snip-row"><span>${esc(t.beforeTarget)}</span><code>${esc(s.before)}</code></div><div class="review-loop-snip-row"><span>${esc(afterState)}</span><code>${esc(after)}</code></div></div>`;
  #|  };
  #|  const inlineTargetFor = (c) => {
  #|    const file = String(c.file || "");
  #|    const snippet = norm(c.element_text || c.value || c.anchor?.snippet || "");
  #|    const candidates = [];
  #|    const visibleCandidates = (items) => Array.from(items).filter(el => {
  #|      if (el.closest("#review-loop-panel,.comment-list,.modal-overlay,.yunomi-inline-comment")) return false;
  #|      const rect = el.getBoundingClientRect();
  #|      const style = getComputedStyle(el);
  #|      return rect.width > 0 && rect.height > 0 && style.display !== "none" && style.visibility !== "hidden";
  #|    });
  #|    if (file) candidates.push(...visibleCandidates(document.querySelectorAll(`.diff-line[data-file="${CSS.escape(file)}"]`)));
  #|    candidates.push(...visibleCandidates(document.querySelectorAll(".diff-line")));
  #|    if (snippet) {
  #|      for (const el of candidates) {
  #|        if (norm(el.textContent || "").includes(snippet)) return el;
  #|      }
  #|      const deletionIndex = diffLines.findIndex(l => l.kind === "deletion" && norm(lineText(l)) === snippet);
  #|      if (deletionIndex >= 0) {
  #|        const after = diffLines.slice(deletionIndex + 1, deletionIndex + 6).find(l => l.kind === "addition");
  #|        if (after) {
  #|          const afterText = norm(lineText(after));
  #|          for (const el of visibleCandidates(document.querySelectorAll(".diff-line.addition"))) {
  #|            if (norm(el.textContent || "").includes(afterText)) return el;
  #|          }
  #|          for (const el of visibleCandidates(document.querySelectorAll("[data-row],[data-source-line],[data-source-start-line]"))) {
  #|            if (norm(el.textContent || "").includes(afterText)) return el;
  #|          }
  #|        }
  #|      }
  #|      for (const el of visibleCandidates(document.querySelectorAll("[data-row],[data-source-line],[data-source-start-line]"))) {
  #|        if (norm(el.textContent || "").includes(snippet)) return el;
  #|      }
  #|    }
  #|    const line = Number(c.line || 0);
  #|    if (line > 0) {
  #|      const selectors = [
  #|        `[data-row="${line}"][data-col="${c.col || 0}"]`,
  #|        `[data-row="${line}"]`,
  #|        `[data-source-line="${line}"]`,
  #|        `[data-source-start-line="${line}"]`,
  #|      ];
  #|      for (const selector of selectors) {
  #|        const target = visibleCandidates(document.querySelectorAll(selector))[0];
  #|        if (target) return target;
  #|      }
  #|    }
  #|    return null;
  #|  };
  #|  const bindResolveButtons = (root) => {
  #|    root.querySelectorAll(".review-loop-resolve").forEach(btn => {
  #|      btn.addEventListener("click", () => {
  #|        fetch("/resolve-comment", {
  #|          method: "POST",
  #|          headers: { "Content-Type": "application/json" },
  #|          body: JSON.stringify({ id: btn.getAttribute("data-review-comment-id") || "" })
  #|        }).catch(() => {});
  #|      });
  #|    });
  #|  };
  #|  const reviewLoopCard = (c, inline) => {
  #|    const replies = Array.isArray(c.replies) && c.replies.length
  #|      ? `<ul class="review-loop-replies">${c.replies.map(r => `<li><strong>${esc(r.author)}</strong> R${esc(r.round)}: ${esc(r.text)}</li>`).join("")}</ul>`
  #|      : "";
  #|    const resolve = c.status === "resolved" ? `<span class="review-loop-resolved">${esc(t.resolved)}</span>` : `<button class="review-loop-resolve" data-review-comment-id="${esc(c.id)}" title="${esc(t.resolveTitle)}">${esc(t.resolve)}</button>`;
  #|    const klass = inline ? "review-loop-comment review-loop-inline-card" : "review-loop-comment";
  #|    const label = inline ? t.inlineLabel : t.itemLabel;
  #|    return `<li class="${klass}" data-review-comment-id="${esc(c.id)}"><div class="review-loop-comment-head"><strong>${esc(label)} ${esc(c.id)}</strong><span>${esc(c.file)}:${esc(c.line)} [${esc(commentStateText(c))}]</span></div><div class="review-loop-request"><span>${esc(t.request)}</span><p>${esc(c.text)}</p></div><div class="review-loop-response"><span>${esc(t.response)}</span><p>${esc(commentResponse(c))}</p></div>${snippetHtml(c)}${replies}<div class="review-loop-actions">${resolve}</div></li>`;
  #|  };
  #|  document.querySelectorAll(".review-loop-inline").forEach(el => el.remove());
  #|  if (comments.length === 0 && unresolved.length === 0) {
  #|    panel.innerHTML = `<div class="review-loop-ready">All resolved — enjoy your tea</div>`;
  #|    return gateUnresolved;
  #|  }
  #|  const commentHtml = comments.map(c => reviewLoopCard(c, false)).join("");
  #|  const diffHtml = diffLines.length
  #|    ? diffLines.slice(0, 120).map(l => {
  #|        const klass = l.kind === "addition" ? "diff-line addition" : "diff-line deletion";
  #|        const oldNo = l.kind === "deletion" ? esc(l.line) : "";
  #|        const newNo = l.kind === "addition" ? esc(l.line) : "";
  #|        return `<div class="${klass}"><span class="line-num">${oldNo}</span><span class="line-num">${newNo}</span><span class="line-content">${esc(l.text)}</span></div>`;
  #|      }).join("")
  #|    : `<div class="history-empty">No changes since previous submitted round</div>`;
  #|  const fromRound = Math.max(1, Number(round.round || 1) - 1);
  #|  const file = esc((review.files || [])[0] || "REPORT.md");
  #|  const status = unresolved.length === 0 ? `<div class="review-loop-ready">All resolved — enjoy your tea</div>` : "";
  #|  const previousSubmittedRound = rounds.slice(0, -1).reverse().find(r => String(r.summary || "").trim().length > 0);
  #|  const roundSummary = String(round.summary || previousSubmittedRound?.summary || "").trim() || t.noSummary;
  #|  panel.innerHTML = `<details class="review-loop-details" open><summary class="review-loop-header"><span class="review-loop-header-main"><span class="arrow">▸</span><span>${esc(t.header(round.round || 1))}</span></span><span class="review-loop-badge">${unresolved.length}</span></summary><div class="review-loop-meta">${esc(t.meta(unresolved.length))}</div><section class="review-loop-context"><div><span>${esc(t.reason)}</span><p>${esc(roundSummary)}</p></div><div><span>${esc(t.guide)}</span><p>${esc(t.guideText)}</p></div></section>${status}<div class="review-loop-body"><ol class="review-loop-list">${commentHtml}</ol><details class="review-loop-diff-block"><summary class="review-loop-diff-label">${esc(t.diffLabel(fromRound))}</summary><pre class="review-loop-diff">${diffHtml}</pre></details></div></details>`;
  #|  bindResolveButtons(panel);
  #|  return gateUnresolved;
  #|}

///|
extern "js" fn clear_inline_saved_comments() -> Unit =
  #|() => document.querySelectorAll(".yunomi-inline-comment:not(.yunomi-inline-comment-editor)").forEach(el => el.remove())

///|
extern "js" fn render_inline_saved_comment(
  key : String,
  row : Int,
  col : Int,
  text : String,
  image : String,
  value : String,
  pending : Bool,
) -> Unit =
  #|(key, row, col, text, image, value, pending) => {
  #|  const esc = (s) => String(s ?? "").replace(/[&<>"']/g, ch => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[ch]));
  #|  const videoTime = String(value || "").match(/^Video(?: thumbnail)?\s+(\d+:\d{2})\b/);
  #|  const label = videoTime ? `Video ${videoTime[1]} · Line ${row + 1}` : (col > 0 ? `R${row + 1} C${col}` : `Line ${row + 1}`);
  #|  const badge = pending ? `<span class="yunomi-inline-comment-pending">Pending</span>` : "";
  #|  const body = `<button type="button" class="yunomi-inline-comment-view" title="Edit comment"><span class="yunomi-inline-comment-label">${esc(label)}${badge}</span><span class="yunomi-inline-comment-text">${esc(text)}</span>${image ? `<img class="yunomi-inline-comment-image" src="${esc(image)}" alt="Attached comment image" />` : ""}</button>`;
  #|  const insert = (target, surface) => {
  #|    if (!target || !target.parentElement) return;
  #|    let holder;
  #|    if (target.closest?.("tr")) {
  #|      const rowEl = target.closest("tr");
  #|      holder = document.createElement("tr");
  #|      holder.innerHTML = `<td colspan="${Math.max(1, rowEl.children.length)}">${body}</td>`;
  #|      rowEl.insertAdjacentElement("afterend", holder);
  #|    } else {
  #|      holder = document.createElement("div");
  #|      holder.innerHTML = body;
  #|      const headingContent = target.matches?.("h1.md-heading-toggle,h2.md-heading-toggle,h3.md-heading-toggle,h4.md-heading-toggle,h5.md-heading-toggle,h6.md-heading-toggle")
  #|        ? target.closest("details.heading-toggle")?.querySelector(":scope > .toggle-content")
  #|        : null;
  #|      if (headingContent) headingContent.insertAdjacentElement("afterbegin", holder);
  #|      else target.insertAdjacentElement("afterend", holder);
  #|    }
  #|    holder.className = "yunomi-inline-comment";
  #|    holder.dataset.commentKey = String(key || "");
  #|    holder.dataset.commentRow = String(row);
  #|    holder.dataset.commentCol = String(col);
  #|    holder.dataset.commentSurface = surface;
  #|  };
  #|  const source = document.querySelector(`td[data-row="${row}"][data-col="1"]:not(#md-preview *)`) || document.querySelector(`.text-line[data-row="${row}"]`) || document.querySelector(`.diff-line[data-row="${row}"]`);
  #|  let preview = null;
  #|  if (col > 0) preview = document.querySelector(`#md-preview [data-row="${row}"][data-col="${col}"]`);
  #|  if (!preview) {
  #|    const parts = String(key || "").split(":");
  #|    const anchorTag = parts.length > 2 ? parts[parts.length - 1].toLowerCase() : "";
  #|    const candidates = Array.from(document.querySelectorAll(`#md-preview [data-source-line="${row + 1}"],#md-preview [data-source-start-line="${row + 1}"]`));
  #|    preview = anchorTag
  #|      ? candidates.find((element) => element.tagName.toLowerCase() === anchorTag)
  #|        || candidates.map((element) => element.querySelector?.(anchorTag)).find(Boolean)
  #|      : candidates[candidates.length - 1];
  #|  }
  #|  insert(preview, "preview");
  #|  if (source && source !== preview) insert(source, "source");
  #|}

///|
extern "js" fn close_inline_comment_editor() -> Unit =
  #|() => {
  #|  document.querySelectorAll(".yunomi-inline-comment-editor-mount").forEach(el => el.remove());
  #|  document.querySelectorAll(".yunomi-inline-comment-editor").forEach(el => el.remove());
  #|}

///|
extern "js" fn inline_comment_editor_open() -> Bool =
  #|() => !!document.querySelector(".yunomi-inline-comment-editor")

///|
extern "js" fn show_inline_comment_editor(
  target : Element,
  key : String,
  row : Int,
  col : Int,
  text : String,
  context : String,
  review_label : String,
  single_label : String,
  on_save : () -> Unit,
  on_send : () -> Unit,
  on_cancel : () -> Unit,
  on_input : () -> Unit,
) -> Unit =
  #|(target, key, row, col, text, context, reviewLabel, singleLabel, onSave, onSend, onCancel, onInput) => {
  #|  document.querySelectorAll(".yunomi-inline-comment-editor-mount").forEach(el => el.remove());
  #|  document.querySelectorAll(".yunomi-inline-comment-editor").forEach(el => el.remove());
  #|  if (!target) return;
  #|  const videoTime = String(context || "").match(/^Video(?: thumbnail)?\s+(\d+:\d{2})\b/);
  #|  const label = videoTime ? `Video ${videoTime[1]} · Line ${row + 1}` : (col > 0 ? `R${row + 1} C${col}` : `Line ${row + 1}`);
  #|  const section = document.createElement("section");
  #|  section.className = "yunomi-inline-comment yunomi-inline-comment-editor is-editing";
  #|  section.dataset.commentKey = String(key || "");
  #|  const surface = target.closest?.("#md-preview") ? "preview" : "source";
  #|  document.querySelectorAll(`.yunomi-inline-comment:not(.yunomi-inline-comment-editor)[data-comment-key="${CSS.escape(String(key || ""))}"]`).forEach(holder => {
  #|    if (holder.dataset.commentSurface === surface) holder.remove();
  #|  });
  #|  section.dataset.commentSurface = surface;
  #|  section.innerHTML = `<div class="yunomi-inline-comment-editor-head"><span class="yunomi-inline-comment-label">${label}</span><span id="cell-preview" class="yunomi-inline-comment-context"></span></div><textarea id="comment-input" aria-label="Comment" placeholder="Comment"></textarea><div class="image-attach-area image-attach-small" id="comment-image-area"><div class="image-preview-list" id="comment-image-preview"></div></div><div class="yunomi-inline-comment-actions"><button type="button" class="icon-only" data-action="cancel" title="Cancel" aria-label="Cancel">×</button><button type="button" class="comment-action send-now-btn" id="send-now-comment">${singleLabel}</button><button type="button" class="comment-action primary" id="save-comment">${reviewLabel}</button></div>`;
  #|  const rowEl = target.closest?.("tr");
  #|  let mount = section;
  #|  if (rowEl) {
  #|    mount = document.createElement("tr");
  #|    mount.className = "yunomi-inline-comment-editor-mount";
  #|    mount.dataset.commentKey = String(key || "");
  #|    const cell = document.createElement("td");
  #|    cell.colSpan = Math.max(1, rowEl.children.length);
  #|    cell.appendChild(section);
  #|    mount.appendChild(cell);
  #|    rowEl.insertAdjacentElement("afterend", mount);
  #|  } else {
  #|    const headingContent = target.matches?.("h1.md-heading-toggle,h2.md-heading-toggle,h3.md-heading-toggle,h4.md-heading-toggle,h5.md-heading-toggle,h6.md-heading-toggle")
  #|      ? target.closest("details.heading-toggle")?.querySelector(":scope > .toggle-content")
  #|      : null;
  #|    if (headingContent) headingContent.insertAdjacentElement("afterbegin", section);
  #|    else target.insertAdjacentElement("afterend", section);
  #|  }
  #|  const input = section.querySelector("#comment-input");
  #|  section.querySelector("#cell-preview").textContent = String(context || "");
  #|  input.value = String(text || "");
  #|  input.addEventListener("input", () => onInput());
  #|  input.addEventListener("keydown", event => {
  #|    if (event.key === "Enter" && (event.metaKey || event.ctrlKey)) { event.preventDefault(); event.stopPropagation(); onSave(); }
  #|    if (event.key === "Escape") { event.preventDefault(); event.stopPropagation(); onCancel(); }
  #|  });
  #|  section.querySelector('[data-action="cancel"]')?.addEventListener("click", () => onCancel());
  #|  section.querySelector("#save-comment")?.addEventListener("click", () => onSave());
  #|  section.querySelector("#send-now-comment")?.addEventListener("click", () => onSend());
  #|  input.focus();
  #|}

///|
extern "js" fn bind_inline_saved_comments(
  handler : (String, Element, Int, Int) -> Unit,
) -> Unit =
  #|(handler) => {
  #|  for (const holder of document.querySelectorAll(".yunomi-inline-comment:not(.yunomi-inline-comment-editor)")) {
  #|    const button = holder.querySelector(".yunomi-inline-comment-view");
  #|    if (!button) continue;
  #|    button.addEventListener("click", (event) => {
  #|      event.preventDefault();
  #|      event.stopPropagation();
  #|      const headingDetails = holder.parentElement?.matches?.(".toggle-content")
  #|        ? holder.parentElement.closest("details.heading-toggle")
  #|        : null;
  #|      let anchor = headingDetails?.querySelector(":scope > summary > .md-heading-toggle")
  #|        || holder.previousElementSibling;
  #|      if (holder.tagName === "TR") {
  #|        const col = Number(holder.dataset.commentCol || 0);
  #|        const cells = anchor?.querySelectorAll?.("td,th") || [];
  #|        anchor = col > 0 ? cells[Math.max(0, col - 1)] || cells[0] : cells[0];
  #|      }
  #|      handler(String(holder.dataset.commentKey || ""), anchor, Number(holder.dataset.commentRow || 0), Number(holder.dataset.commentCol || 0));
  #|    });
  #|  }
  #|}

///|
extern "js" fn get_review_loop_status_text() -> String =
  #|() => String(window.__YUNOMI_REVIEW_LOOP_STATUS__ || "")

///|
extern "js" fn is_japanese_locale() -> Bool =
  #|() => /^ja\b/i.test(navigator.language || "")

///|
/// Paste event handler for images
extern "js" fn on_paste_image(handler : (String) -> Unit) -> Unit =
  #|(handler) => {
  #|  document.addEventListener("paste", (e) => {
  #|    const items = e.clipboardData?.items;
  #|    if (!items) return;
  #|    for (const item of items) {
  #|      if (item.type.startsWith("image/")) {
  #|        e.preventDefault();
  #|        const file = item.getAsFile();
  #|        const reader = new FileReader();
  #|        reader.onload = () => handler(reader.result);
  #|        reader.readAsDataURL(file);
  #|        break;
  #|      }
  #|    }
  #|  });
  #|}

///|
/// Extract pathname from URL (e.g., "http://localhost:19876/videos/foo.mp4" → "/videos/foo.mp4")
extern "js" fn url_to_pathname(url : String) -> String =
  #|(u) => { try { return new URL(u).pathname; } catch(_) { return u; } }

///|
/// Create new EventSource by URL
extern "js" fn new_event_source_url(url : String) -> EventSource =
  #|(url) => new EventSource(url)

///|
/// EventSource on message
extern "js" fn sse_on_message(
  es : EventSource,
  handler : (String) -> Unit,
) -> Unit =
  #|(es, handler) => es.addEventListener("message", (e) => handler(e.data))

///|
/// SSE open event (connection established)
extern "js" fn sse_on_open(es : EventSource, handler : () -> Unit) -> Unit =
  #|(es, handler) => es.addEventListener("open", () => handler())

///|
/// SSE error event (connection lost / reconnecting)
extern "js" fn sse_on_error_status(
  es : EventSource,
  handler : () -> Unit,
) -> Unit =
  #|(es, handler) => es.addEventListener("error", () => handler())

///|
/// EventSource close
extern "js" fn sse_close(es : EventSource) -> Unit =
  #|(es) => es.close()

///|
/// Tag name
extern "js" fn get_tag_name(el : Element) -> String =
  #|(el) => (el?.tagName || "").toUpperCase()

///|
/// Get attribute (already exists as get_attr, but need src specifically)
extern "js" fn get_src(el : Element) -> String =
  #|(el) => el?.src || el?.getAttribute("src") || ""

///|
/// Parent element
extern "js" fn parent_element(el : Element) -> Element =
  #|(el) => el?.parentElement

///|
extern "js" fn get_active_element() -> Element =
  #|() => document.activeElement

///|
extern "js" fn comment_target_description(target : Element) -> String =
  #|(target) => {
  #|  if (!target) return "";
  #|  const image = target.matches?.("img:not(.timeline-thumb)")
  #|    ? target
  #|    : target.querySelector?.("img:not(.timeline-thumb)")
  #|      || target.closest?.(".yunomi-media-comment-host")?.querySelector("img:not(.timeline-thumb)");
  #|  if (image) return `image (alt="${image.getAttribute("alt") || ""}" src="${image.getAttribute("src") || ""}")`;
  #|  const video = target.matches?.("video.video-preview")
  #|    ? target
  #|    : target.querySelector?.("video.video-preview") || target.closest?.(".video-overlay-wrapper")?.querySelector("video.video-preview");
  #|  if (video) return `video (title="${video.getAttribute("title") || ""}" src="${video.getAttribute("src") || ""}")`;
  #|  if (target.matches?.(".timeline-thumb-wrapper") || target.closest?.(".timeline-thumb-wrapper")) {
  #|    const thumb = target.matches?.(".timeline-thumb-wrapper") ? target : target.closest(".timeline-thumb-wrapper");
  #|    return `video frame (${thumb?.textContent?.trim() || "unknown time"})`;
  #|  }
  #|  if (target.matches?.(".mermaid-container") || target.closest?.(".mermaid-container")) return "Mermaid diagram";
  #|  return "";
  #|}

///|
extern "js" fn blur_active_element() -> Unit =
  #|() => document.activeElement?.blur?.()

///|
/// Previous element sibling
extern "js" fn previous_element_sibling(el : Element) -> Element =
  #|(el) => el?.previousElementSibling

///|
/// Next element sibling
extern "js" fn next_element_sibling(el : Element) -> Element =
  #|(el) => el?.nextElementSibling

///|
/// Stop event propagation
extern "js" fn stop_propagation(e : Event) -> Unit =
  #|(e) => e.stopPropagation()

///|
extern "js" fn _get_event_property_name(e : Event) -> String =
  #|(e) => e?.propertyName || ""

///|
/// Scroll to position instantly
extern "js" fn scroll_to_instant(el : Element, top : Double) -> Unit =
  #|(el, top) => { if (el) el.scrollTo({ top, behavior: 'instant' }); }

///|
/// Offset properties
extern "js" fn get_offset_top(el : Element) -> Double =
  #|(el) => el?.offsetTop || 0

///|
extern "js" fn _get_offset_height(el : Element) -> Double =
  #|(el) => el?.offsetHeight || 0

///|
/// Window inner width
extern "js" fn window_inner_width() -> Int =
  #|() => window.innerWidth

///|
/// Get bounding rect right
extern "js" fn _get_bounding_rect_right(el : Element) -> Double =
  #|(el) => el?.getBoundingClientRect().right || 0

///|
/// Get bounding rect width
extern "js" fn get_bounding_rect_width(el : Element) -> Double =
  #|(el) => el?.getBoundingClientRect().width || 0

///|
/// Get bounding rect height
extern "js" fn get_bounding_rect_height(el : Element) -> Double =
  #|(el) => el?.getBoundingClientRect().height || 0

///|
/// Get DATA array from window (injected by server)
extern "js" fn js_get_data() -> Array[Array[String]] =
  #|() => window.__DATA__ || []

///|
/// Window selection API (returns Selection object, typed as Element for FFI convenience)
extern "js" fn window_get_selection() -> Element =
  #|() => window.getSelection()

///|
extern "js" fn selection_is_collapsed(sel : Element) -> Bool =
  #|(sel) => !sel || sel.isCollapsed

///|
extern "js" fn selection_to_string(sel : Element) -> String =
  #|(sel) => sel ? sel.toString() : ""

///|
extern "js" fn selection_remove_all_ranges(sel : Element) -> Unit =
  #|(sel) => { if (sel) sel.removeAllRanges(); }

///|
extern "js" fn selection_get_range_container(sel : Element) -> Element =
  #|(sel) => {
  #|  if (!sel || sel.rangeCount === 0) return null;
  #|  const range = sel.getRangeAt(0);
  #|  const c = range.commonAncestorContainer;
  #|  return c.nodeType === 3 ? c.parentElement : c;
  #|}

///|
/// Query within parent element
extern "js" fn query_in(parent : Element, selector : String) -> Element =
  #|(parent, s) => parent?.querySelector(s)

///|
/// Scroll element by delta
extern "js" fn _scroll_by_instant(el : Element, delta : Double) -> Unit =
  #|(el, delta) => { if (el) el.scrollBy({ top: delta, behavior: 'instant' }); }

///|
/// Check computed display
extern "js" fn is_element_hidden(el : Element) -> Bool =
  #|(el) => !el || el.offsetParent === null || getComputedStyle(el).display === 'none'

///|
/// Has class check
extern "js" fn has_class(el : Element, cls : String) -> Bool =
  #|(el, cls) => el?.classList.contains(cls) || false

///|
/// Toggle class
extern "js" fn toggle_class(el : Element, cls : String) -> Unit =
  #|(el, cls) => { if (el) el.classList.toggle(cls); }

///|
/// Remove element from its parent
extern "js" fn remove_element(el : Element) -> Unit =
  #|(el) => { if (el && el.parentNode) el.parentNode.removeChild(el); }

///|
/// Append HTML string to element
extern "js" fn append_html(el : Element, html : String) -> Unit =
  #|(el, html) => { if (el) el.insertAdjacentHTML("beforeend", html); }

///|
/// setTimeout for browser
extern "js" fn set_timeout_dom(callback : () -> Unit, ms : Int) -> Int =
  #|(cb, ms) => setTimeout(cb, ms)

///|
/// Parse float from string (returns 0.0 on failure)
extern "js" fn parse_float(s : String) -> Double =
  #|(s) => { var v = parseFloat(s); return isNaN(v) ? 0.0 : v; }

///|
extern "js" fn _parse_int_or(s : String, fallback : Int) -> Int =
  #|(s, fallback) => {
  #|  const v = parseInt(s, 10);
  #|  return Number.isNaN(v) ? fallback : v;
  #|}

///|
extern "js" fn join_strings(values : Array[String], sep : String) -> String =
  #|(values, sep) => values.join(sep)

///|
extern "js" fn replace_all_text(
  text : String,
  search : String,
  replacement : String,
) -> String =
  #|(text, search, replacement) => text.split(search).join(replacement)

///|
extern "js" fn math_abs(value : Double) -> Double =
  #|(value) => Math.abs(value)

///|
extern "js" fn math_sqrt(value : Double) -> Double =
  #|(value) => Math.sqrt(value)

///|
extern "js" fn _math_min(a : Double, b : Double) -> Double =
  #|(a, b) => Math.min(a, b)

///|
extern "js" fn _math_max(a : Double, b : Double) -> Double =
  #|(a, b) => Math.max(a, b)

///|
extern "js" fn math_round(value : Double) -> Double =
  #|(value) => Math.round(value)

///|
/// Create a video element with controls for fullscreen use
extern "js" fn create_video_element(src : String) -> Element =
  #|(src) => {
  #|  var v = document.createElement('video');
  #|  v.src = src; v.controls = true;
  #|  v.style.width = '100%';
  #|  v.style.height = 'calc(100% - 80px)';
  #|  v.style.objectFit = 'contain';
  #|  v.addEventListener('click', function(e) { e.stopPropagation(); });
  #|  return v;
  #|}

///|
/// Element reference equality
extern "js" fn elem_eq(a : Element, b : Element) -> Bool =
  #|(a, b) => a === b

///|
/// DOM element creation helpers for fullscreen overlays
extern "js" fn create_element(tag : String) -> Element =
  #|(tag) => document.createElement(tag)

///|
extern "js" fn set_class_name(el : Element, cls : String) -> Unit =
  #|(el, cls) => { if (el) el.className = cls; }

///|
extern "js" fn _set_id(el : Element, id : String) -> Unit =
  #|(el, id) => { if (el) el.id = id; }

///|
extern "js" fn append_child(parent : Element, child : Element) -> Unit =
  #|(p, c) => { if (p && c) p.appendChild(c); }

///|
extern "js" fn _remove_child(parent : Element, child : Element) -> Unit =
  #|(p, c) => { if (p && c) p.removeChild(c); }

///|
extern "js" fn set_text_content(el : Element, text : String) -> Unit =
  #|(el, t) => { if (el) el.textContent = t; }

///|
extern "js" fn set_attribute(
  el : Element,
  name : String,
  value : String,
) -> Unit =
  #|(el, n, v) => { if (el) el.setAttribute(n, v); }

///|
extern "js" fn get_attribute(el : Element, name : String) -> String =
  #|(el, n) => el?.getAttribute(n) || ""

///|
extern "js" fn remove_attribute(el : Element, name : String) -> Unit =
  #|(el, n) => { if (el) el.removeAttribute(n); }

///|
extern "js" fn clone_node_deep(el : Element) -> Element =
  #|(el) => el ? el.cloneNode(true) : null

///|
extern "js" fn get_natural_width(el : Element) -> Double =
  #|(el) => el?.naturalWidth || 0

///|
extern "js" fn get_natural_height(el : Element) -> Double =
  #|(el) => el?.naturalHeight || 0

///|
extern "js" fn set_draggable(el : Element, val : Bool) -> Unit =
  #|(el, v) => { if (el) el.draggable = v; }

///|
extern "js" fn set_tabindex(el : Element, val : Int) -> Unit =
  #|(el, v) => { if (el) el.tabIndex = v; }

///|
extern "js" fn set_aria_label(el : Element, label : String) -> Unit =
  #|(el, label) => { if (el) el.setAttribute('aria-label', label); }

///|
extern "js" fn get_dataset(el : Element, key : String) -> String =
  #|(el, key) => {
  #|  if (!el) return "";
  #|  const attr = "data-" + String(key || "").replace(/[A-Z]/g, m => "-" + m.toLowerCase());
  #|  return el.getAttribute?.(attr) || "";
  #|}

///|
extern "js" fn set_dataset(el : Element, key : String, value : String) -> Unit =
  #|(el, key, value) => {
  #|  if (!el) return;
  #|  const attr = "data-" + String(key || "").replace(/[A-Z]/g, m => "-" + m.toLowerCase());
  #|  el.setAttribute?.(attr, value);
  #|}

///|
extern "js" fn query_body() -> Element =
  #|() => document.body

///|
/// Element rect (returns [left, top, width, height])
extern "js" fn get_bounding_rect(el : Element) -> Array[Double] =
  #|(el) => {
  #|  if (!el) return [0, 0, 0, 0];
  #|  const r = el.getBoundingClientRect();
  #|  return [r.left, r.top, r.width, r.height];
  #|}

///|
/// Get SVG natural dimensions from viewBox or width/height attributes
extern "js" fn get_svg_natural_size(svg : Element) -> Array[Double] =
  #|(svg) => {
  #|  if (!svg) return [800, 600];
  #|  var vb = svg.getAttribute('viewBox');
  #|  if (vb) {
  #|    var p = vb.split(/[\s,]+/);
  #|    return [parseFloat(p[2]) || 800, parseFloat(p[3]) || 600];
  #|  }
  #|  return [parseFloat(svg.getAttribute('width')) || svg.getBoundingClientRect().width || 800,
  #|          parseFloat(svg.getAttribute('height')) || svg.getBoundingClientRect().height || 600];
  #|}

///| Expand SVG viewBox by padding (e.g. 40px each side for +80 total)

///|
/// This makes the minimap SVG match the padded naturalWidth/Height used by ZoomPanViewer
extern "js" fn _expand_svg_viewbox(svg : Element, pad : Double) -> Unit =
  #|(svg, pad) => {
  #|  if (!svg) return;
  #|  var vb = svg.getAttribute('viewBox');
  #|  if (vb) {
  #|    var p = vb.split(/[\s,]+/).map(Number);
  #|    svg.setAttribute('viewBox', (p[0]-pad)+' '+(p[1]-pad)+' '+(p[2]+pad*2)+' '+(p[3]+pad*2));
  #|  } else {
  #|    var w = parseFloat(svg.getAttribute('width')) || svg.getBoundingClientRect().width || 800;
  #|    var h = parseFloat(svg.getAttribute('height')) || svg.getBoundingClientRect().height || 600;
  #|    svg.setAttribute('viewBox', (-pad)+' '+(-pad)+' '+(w+pad*2)+' '+(h+pad*2));
  #|  }
  #|}

///|
/// Set element visibility
extern "js" fn set_visibility(el : Element, visible : Bool) -> Unit =
  #|(el, v) => { if (el) el.style.visibility = v ? 'visible' : 'hidden'; }

///|
/// Remove all children of an element
extern "js" fn clear_children(el : Element) -> Unit =
  #|(el) => { if (el) el.innerHTML = ''; }

///|
/// Get all children of an element
extern "js" fn _get_children(el : Element) -> Array[Element] =
  #|(el) => el ? Array.from(el.children) : []

///|
/// Shallow clone (no children)
extern "js" fn _clone_node_shallow(el : Element) -> Element =
  #|(el) => el ? el.cloneNode(false) : null

///|
/// Insert element before target
extern "js" fn insert_before(target : Element, new_el : Element) -> Unit =
  #|(target, new_el) => { if (target && target.parentNode) target.parentNode.insertBefore(new_el, target); }

///|
/// Check if element has attribute
extern "js" fn has_attribute(el : Element, name : String) -> Bool =
  #|(el, name) => el ? el.hasAttribute(name) : false

///|
/// Setup intersection observer
extern "js" fn setup_intersection_observer(
  target : Element,
  callback : (Array[Element]) -> Unit,
  config_root : Element,
  config_margin : String,
  config_threshold : Double,
) -> Unit =
  #|(target, callback, root, margin, threshold) => {
  #|  if (!target) return;
  #|  const observer = new IntersectionObserver((entries) => {
  #|    callback(entries.map(e => e.target));
  #|  }, { root, rootMargin: margin, threshold });
  #|  observer.observe(target);
  #|}

///|
/// Check if element has a specific CSS class (visible state)
extern "js" fn has_class_visible(el : Element) -> Bool =
  #|(el) => el?.classList.contains('visible') || false

///|
/// Add 'visible' class
extern "js" fn show_overlay(el : Element) -> Unit =
  #|(el) => { if (el) el.classList.add('visible'); }

///|
/// Remove 'visible' class
extern "js" fn hide_overlay(el : Element) -> Unit =
  #|(el) => { if (el) el.classList.remove('visible'); }

///|
/// Get computed style property value
extern "js" fn get_computed_style(el : Element, prop : String) -> String =
  #|(el, prop) => { if (!el) return ''; return el.style[prop] || getComputedStyle(el)[prop] || ''; }

///|
/// Get children count
extern "js" fn _children_count(el : Element) -> Int =
  #|(el) => el?.children?.length || 0

///|
extern "js" fn normalize_preview_commentable(el : Element) -> Element =
  #|(el) => {
  #|  if (!el) return null;
  #|  if (el.closest?.("#review-loop-panel,.yunomi-inline-comment")) return null;
  #|  if (el.classList?.contains("yunomi-comment-button")) {
  #|    el = el.__yunomiCommentTarget || el.parentElement;
  #|  }
  #|  const timeline = el.closest?.(".timeline-thumb-wrapper");
  #|  if (timeline) return timeline;
  #|  const image = el.closest?.("img:not(.timeline-thumb)");
  #|  if (image?.parentElement?.classList.contains("yunomi-media-comment-host")) return image.parentElement;
  #|  const media = el.closest?.("img:not(.timeline-thumb),video.video-preview,.mermaid-container,td,th");
  #|  if (media?.closest?.("[data-source-line],[data-source-start-line]")) return media;
  #|  return el.closest?.("[data-source-line],[data-source-start-line]");
  #|}

///|
extern "js" fn get_preview_comment_targets() -> Array[Element] =
  #|() => {
  #|  const preview = document.querySelector("#md-preview");
  #|  if (!preview) return [];
  #|  // Note: td/th are intentionally excluded here so narrow table cells never
  #|  // get an overlapping pencil button (it would cover the cell's own text).
  #|  // Table cells remain commentable via direct click (see setup_preview_click /
  #|  // open_or_select_preview_comment_target), which resolves per-cell row+col.
  #|  const selector = "[data-source-line],[data-source-start-line],.timeline-thumb-wrapper";
  #|  const out = [];
  #|  const seen = new Set();
  #|  const visible = (el) => {
  #|    if (!el || el.offsetParent === null) return false;
  #|    if (el.closest("details:not([open])") && !el.closest("summary")) return false;
  #|    const style = getComputedStyle(el);
  #|    if (style.display === "none" || style.visibility === "hidden") return false;
  #|    const rect = el.getBoundingClientRect();
  #|    return rect.width > 0 && rect.height > 0;
  #|  };
  #|  for (const raw of preview.querySelectorAll(selector)) {
  #|    const el = raw.closest(".timeline-thumb-wrapper") || raw;
  #|    if (el.closest?.("#review-loop-panel,.yunomi-inline-comment")) continue;
  #|    if (el.matches?.("img.timeline-thumb")) continue;
  #|    if (el.closest?.(".yunomi-comment-button")) continue;
  #|    if (el.closest?.(".video-timeline") && !el.classList?.contains("timeline-thumb-wrapper")) continue;
  #|    if (!visible(el)) continue;
  #|    if (!seen.has(el)) {
  #|      seen.add(el);
  #|      out.push(el);
  #|    }
  #|  }
  #|  return out;
  #|}

///|
extern "js" fn table_cell_neighbor(el : Element, direction : String) -> Element =
  #|(el, direction) => {
  #|  const cell = el?.closest?.("td,th");
  #|  if (!cell) return null;
  #|  const row = cell.parentElement;
  #|  if (!row) return null;
  #|  const cells = Array.from(row.children).filter((n) => n.matches?.("td,th"));
  #|  const idx = cells.indexOf(cell);
  #|  if (direction === "left") return cells[Math.max(0, idx - 1)] || null;
  #|  if (direction === "right") return cells[Math.min(cells.length - 1, idx + 1)] || null;
  #|  const sibling = direction === "up" ? row.previousElementSibling : row.nextElementSibling;
  #|  if (!sibling) return null;
  #|  const nextCells = Array.from(sibling.children).filter((n) => n.matches?.("td,th"));
  #|  return nextCells[Math.min(idx, nextCells.length - 1)] || null;
  #|}

///|
extern "js" fn install_preview_comment_buttons(
  handler : (Element) -> Unit,
) -> Unit =
  #|(handler) => {
  #|  const preview = document.querySelector("#md-preview");
  #|  if (!preview) return;
  #|  const selector = "img:not(.timeline-thumb),video.video-preview,.mermaid-container,.timeline-thumb-wrapper";
  #|  const hostFor = (target) => {
  #|    if (!target) return null;
  #|    if (target.classList?.contains("timeline-thumb-wrapper")) return target;
  #|    if (target.matches?.("video.video-preview")) return target.closest(".video-overlay-wrapper") || target.parentElement;
  #|    if (target.matches?.("img:not(.timeline-thumb)")) {
  #|      if (target.parentElement?.classList.contains("yunomi-media-comment-host")) return target.parentElement;
  #|      const host = document.createElement("span");
  #|      host.className = "yunomi-media-comment-host";
  #|      ["data-source-line", "data-source-start-line", "data-source-end-line"].forEach((name) => {
  #|        const value = target.getAttribute(name);
  #|        if (value) host.setAttribute(name, value);
  #|      });
  #|      target.parentNode?.insertBefore(host, target);
  #|      host.appendChild(target);
  #|      return host;
  #|    }
  #|    return target;
  #|  };
  #|  const decorate = () => {
  #|    const seen = new Set();
  #|    for (const raw of preview.querySelectorAll(selector)) {
  #|      const target = raw.closest(".timeline-thumb-wrapper") || raw;
  #|      if (target.closest?.("#review-loop-panel,.yunomi-inline-comment")) continue;
  #|      if (target.closest?.(".video-timeline") && !target.classList?.contains("timeline-thumb-wrapper")) continue;
  #|      if (seen.has(target)) continue;
  #|      seen.add(target);
  #|      const host = hostFor(target);
  #|      if (!host || host.querySelector?.(":scope > .yunomi-comment-button")) continue;
  #|      host.classList.add("yunomi-commentable");
  #|      const btn = document.createElement("button");
  #|      btn.type = "button";
  #|      btn.className = "yunomi-comment-button";
  #|      btn.textContent = "✎";
  #|      const subject = target.matches?.("img:not(.timeline-thumb)")
  #|        ? "image"
  #|        : target.matches?.("video.video-preview")
  #|          ? "video"
  #|          : target.classList?.contains("mermaid-container")
  #|            ? "diagram"
  #|            : "video frame";
  #|      const label = `Comment on ${subject}`;
  #|      btn.setAttribute("aria-label", label);
  #|      btn.__yunomiCommentTarget = target;
  #|      btn.addEventListener("click", (e) => {
  #|        e.preventDefault();
  #|        e.stopPropagation();
  #|        handler(target);
  #|      });
  #|      host.appendChild(btn);
  #|    }
  #|  };
  #|  decorate();
  #|  const observer = new MutationObserver(decorate);
  #|  observer.observe(preview, { childList: true, subtree: true });
  #|  setTimeout(decorate, 500);
  #|  setTimeout(decorate, 1500);
  #|  setTimeout(decorate, 3000);
  #|}

///|
/// Collect yunomi answers from question panel.
/// Combines a selected option button (if any) with free-text input (if any) —
/// previously only the textarea was read, silently dropping option-only answers.
extern "js" fn collect_yunomi_answers() -> String =
  #|() => {
  #|  var answers = {};
  #|  document.querySelectorAll('.question-card').forEach(function(item) {
  #|    var id = item.dataset.qid || '';
  #|    if (!id) return;
  #|    var textarea = item.querySelector('.q-answer');
  #|    var text = (textarea && textarea.value) ? textarea.value : '';
  #|    var selectedBtn = item.querySelector('.q-option-btn.selected');
  #|    var option = selectedBtn ? (selectedBtn.dataset.val || selectedBtn.textContent || '') : '';
  #|    var combined = (option && text) ? (option + '\n' + text) : (option || text);
  #|    if (combined) {
  #|      answers[id] = combined;
  #|    }
  #|  });
  #|  return JSON.stringify(answers);
  #|}

///|
/// Populate #yunomi-questions-summary with a scannable recap of every
/// question's current title + combined answer, one clickable item per
/// question (data-step points back at that question's stepper index) — the
/// confirmation screen shown before closing on "完了" (task #21). Built via
/// createElement/textContent, not innerHTML string concatenation, so
/// arbitrary reviewer-typed answer text can never be interpreted as markup.
extern "js" fn render_answer_summary() -> Unit =
  #|() => {
  #|  const list = document.querySelector("#yunomi-questions-summary");
  #|  if (!list) return;
  #|  list.innerHTML = "";
  #|  const cards = document.querySelectorAll("#yunomi-questions-stepper .question-card");
  #|  cards.forEach((card, idx) => {
  #|    const titleEl = card.querySelector(".q-title");
  #|    const title = titleEl ? titleEl.textContent : "";
  #|    const textarea = card.querySelector(".q-answer");
  #|    const text = textarea && textarea.value ? textarea.value : "";
  #|    const selectedBtn = card.querySelector(".q-option-btn.selected");
  #|    const option = selectedBtn ? (selectedBtn.dataset.val || selectedBtn.textContent || "") : "";
  #|    const combined = option && text ? option + "\n" + text : (option || text);
  #|    const item = document.createElement("button");
  #|    item.type = "button";
  #|    item.className = "q-summary-item";
  #|    item.dataset.step = String(idx);
  #|    const titleDiv = document.createElement("div");
  #|    titleDiv.className = "q-summary-title";
  #|    titleDiv.textContent = title;
  #|    const answerDiv = document.createElement("div");
  #|    answerDiv.className = "q-summary-answer";
  #|    answerDiv.textContent = combined;
  #|    item.appendChild(titleDiv);
  #|    item.appendChild(answerDiv);
  #|    list.appendChild(item);
  #|  });
  #|}

///|
/// Collect the RAW per-question draft state (option + free text kept
/// separate, unlike collect_yunomi_answers() which combines them for
/// submission) so it can be persisted to localStorage and restored without
/// re-combining an already-combined string on a later save.
extern "js" fn collect_yunomi_draft_answers() -> String =
  #|() => {
  #|  var out = {};
  #|  document.querySelectorAll('.question-card').forEach(function(item) {
  #|    var id = item.dataset.qid || '';
  #|    if (!id) return;
  #|    var textarea = item.querySelector('.q-answer');
  #|    var text = (textarea && textarea.value) ? textarea.value : '';
  #|    var selectedBtn = item.querySelector('.q-option-btn.selected');
  #|    var option = selectedBtn ? (selectedBtn.dataset.val || selectedBtn.textContent || '') : '';
  #|    if (option || text) {
  #|      out[id] = { option: option, text: text };
  #|    }
  #|  });
  #|  return JSON.stringify(out);
  #|}

///|
/// Restore per-question draft state (option selection + free text) saved by
/// collect_yunomi_draft_answers() back into the live question-card DOM.
extern "js" fn apply_yunomi_draft_answers(json : String) -> Unit =
  #|(json) => {
  #|  try {
  #|    var data = JSON.parse(json);
  #|    Object.keys(data).forEach(function(id) {
  #|      var item = document.querySelector('.question-card[data-qid="' + CSS.escape(id) + '"]');
  #|      if (!item) return;
  #|      var entry = data[id] || {};
  #|      if (entry.text) {
  #|        var textarea = item.querySelector('.q-answer');
  #|        if (textarea) textarea.value = entry.text;
  #|      }
  #|      if (entry.option) {
  #|        var btns = item.querySelectorAll('.q-option-btn');
  #|        btns.forEach(function(b) {
  #|          var val = b.dataset.val || b.textContent || '';
  #|          if (val === entry.option) {
  #|            b.classList.add('selected');
  #|          } else {
  #|            b.classList.remove('selected');
  #|          }
  #|        });
  #|      }
  #|    });
  #|  } catch (e) {}
  #|}

///|
/// Copy text to clipboard
extern "js" fn copy_to_clipboard(text : String) -> Unit =
  #|(text) => {
  #|  if (navigator.clipboard && navigator.clipboard.writeText) {
  #|    navigator.clipboard.writeText(text).catch(()=>{});
  #|  } else {
  #|    var ta=document.createElement('textarea');ta.value=text;ta.style.position='fixed';ta.style.opacity='0';
  #|    document.body.appendChild(ta);ta.select();document.execCommand('copy');ta.remove();
  #|  }
  #|}

///|
/// Show a brief toast notification
extern "js" fn show_toast(msg : String) -> Unit =
  #|(msg) => {
  #|  var t=document.createElement('div');t.textContent=msg;
  #|  t.style.cssText='position:fixed;bottom:20px;left:50%;transform:translateX(-50%);background:#333;color:#fff;padding:8px 16px;border-radius:6px;z-index:99999;font-size:13px;';
  #|  document.body.appendChild(t);setTimeout(()=>t.remove(),2000);
  #|}

///|
/// Scroll element into view
extern "js" fn scroll_into_view(el : Element) -> Unit =
  #|(el) => { if (el) el.scrollIntoView({ behavior: 'smooth', block: 'center' }); }

///|
/// Smooth-scroll to element and keep correcting until it is actually visible.
///  Lazy-loaded images/videos shift the layout while the smooth scroll is in
///  flight, which makes a single scrollIntoView land short — re-aim until the
///  target is at least 90% visible (or attempts run out).
extern "js" fn scroll_into_view_persistent(el : Element) -> Unit =
  #|(el) => {
  #|  if (!el) return;
  #|  const ratio = () => {
  #|    const r = el.getBoundingClientRect();
  #|    const vh = window.innerHeight;
  #|    const visible = Math.min(r.bottom, vh) - Math.max(r.top, 0);
  #|    return visible / Math.min(r.height || 1, vh);
  #|  };
  #|  const centerNow = () => {
  #|    const scroller = el.closest('.md-preview');
  #|    const r = el.getBoundingClientRect();
  #|    if (scroller) {
  #|      const sr = scroller.getBoundingClientRect();
  #|      const delta = (r.top - sr.top) + r.height / 2 - scroller.clientHeight / 2;
  #|      scroller.scrollTo({ top: Math.max(0, scroller.scrollTop + delta), behavior: 'auto' });
  #|      return;
  #|    }
  #|    const targetCenter = window.scrollY + r.top + r.height / 2;
  #|    window.scrollTo({ top: Math.max(0, targetCenter - window.innerHeight / 2), behavior: 'auto' });
  #|  };
  #|  el.scrollIntoView({ behavior: 'smooth', block: 'center' });
  #|  let attempts = 0;
  #|  const tick = () => {
  #|    attempts++;
  #|    if (ratio() >= 0.9) return;
  #|    if (attempts > 8) { centerNow(); return; }
  #|    el.scrollIntoView({ behavior: 'smooth', block: 'center' });
  #|    setTimeout(tick, 250);
  #|  };
  #|  setTimeout(tick, 300);
  #|}

///|
/// Get cell index of TD/TH element (-1 if not a table cell)
extern "js" fn get_cell_index(el : Element) -> Int =
  #|(el) => (el && el.cellIndex != null) ? el.cellIndex : -1

///|
/// Programmatic click
extern "js" fn _click_element(el : Element) -> Unit =
  #|(el) => { if (el) el.click(); }

///|
/// localStorage get (returns "" if not found)
extern "js" fn local_storage_get(key : String) -> String =
  #|(key) => { try { return localStorage.getItem(key) || ""; } catch(e) { return ""; } }

///|
/// localStorage set
extern "js" fn local_storage_set(key : String, value : String) -> Unit =
  #|(key, value) => { try { localStorage.setItem(key, value); } catch(e) {} }

///|
extern "js" fn setup_diff_enhancements_dom(filename : String) -> Unit =
  #|(filename) => {
  #|  const shell = document.querySelector(".diff-review-shell");
  #|  if (!shell) return;
  #|  const viewKey = `yunomi:diff-view:${filename}`;
  #|  const viewedKey = `yunomi:diff-viewed:${filename}`;
  #|  const ja = /^ja\b/i.test(navigator.language || "");
  #|  const reviewedText = ja ? "確認済み" : "Reviewed";
  #|  const unreviewedText = ja ? "未確認" : "Unreviewed";
  #|  const reviewLabel = (file, isViewed) => ja
  #|    ? `${file} を${isViewed ? "確認済み" : "未確認"}にする`
  #|    : `Mark ${file} as ${isViewed ? "reviewed" : "unreviewed"}`;
  #|  const getViewed = () => {
  #|    try { return JSON.parse(localStorage.getItem(viewedKey) || "{}") || {}; } catch (_) { return {}; }
  #|  };
  #|  const setViewed = (viewed) => {
  #|    try { localStorage.setItem(viewedKey, JSON.stringify(viewed)); } catch (_) {}
  #|  };
  #|  const setMode = (mode) => {
  #|    const split = mode === "split";
  #|    document.body.classList.toggle("diff-split", split);
  #|    document.body.classList.toggle("diff-unified", !split);
  #|    document.querySelectorAll(".diff-view-mode button").forEach((button) => {
  #|      const active = button.getAttribute("data-mode") === mode;
  #|      button.classList.toggle("active", active);
  #|      button.setAttribute("aria-pressed", String(active));
  #|    });
  #|    try { localStorage.setItem(viewKey, mode); } catch (_) {}
  #|  };
  #|  setMode(localStorage.getItem(viewKey) || "unified");
  #|  document.querySelectorAll(".diff-view-mode button").forEach((button) => {
  #|    button.addEventListener("click", () => setMode(button.getAttribute("data-mode") || "unified"));
  #|  });
  #|  const applyViewed = () => {
  #|    const viewed = getViewed();
  #|    document.querySelectorAll(".diff-viewed-checkbox").forEach((box) => {
  #|      const file = box.getAttribute("data-file") || "";
  #|      const isViewed = !!viewed[file];
  #|      box.checked = isViewed;
  #|      box.closest(".diff-file-tree-item")?.classList.toggle("viewed", isViewed);
  #|      const state = box.closest(".diff-viewed-control")?.querySelector(".diff-viewed-state");
  #|      if (state) state.textContent = isViewed ? reviewedText : unreviewedText;
  #|      box.setAttribute("aria-label", reviewLabel(file, isViewed));
  #|    });
  #|    document.querySelectorAll(".diff-file-block").forEach((block) => {
  #|      const file = block.getAttribute("data-file") || "";
  #|      block.classList.toggle("viewed", !!viewed[file]);
  #|    });
  #|  };
  #|  applyViewed();
  #|  if (!window.__YUNOMI_SHARE_READONLY__) {
  #|    fetch("/review-state").then((response) => response.json()).then((state) => {
  #|      const persisted = state?.review?.viewed_files;
  #|      if (!persisted || typeof persisted !== "object" || Array.isArray(persisted)) return;
  #|      setViewed({ ...getViewed(), ...persisted });
  #|      applyViewed();
  #|    }).catch(() => {});
  #|  }
  #|  document.querySelectorAll(".diff-viewed-checkbox").forEach((box) => {
  #|    box.addEventListener("change", () => {
  #|      const viewed = getViewed();
  #|      viewed[box.getAttribute("data-file") || ""] = !!box.checked;
  #|      setViewed(viewed);
  #|      if (!window.__YUNOMI_SHARE_READONLY__) {
  #|        fetch("/review-viewed", {
  #|          method: "POST",
  #|          headers: { "Content-Type": "application/json" },
  #|          body: JSON.stringify(viewed),
  #|        }).catch(() => {});
  #|      }
  #|      applyViewed();
  #|    });
  #|  });
  #|  document.querySelectorAll(".diff-file-link").forEach((button) => {
  #|    button.addEventListener("click", () => {
  #|      const file = button.getAttribute("data-file") || "";
  #|      const target = Array.from(document.querySelectorAll(".diff-file-block")).find((block) => block.getAttribute("data-file") === file);
  #|      target?.scrollIntoView({ block: "start", behavior: "smooth" });
  #|    });
  #|  });
  #|}

///|
extern "js" fn setup_vim_review_keyboard(filename : String) -> Unit =
  #|(filename) => {
  #|  if (window.__YUNOMI_VIM_KEYS_READY__) return;
  #|  window.__YUNOMI_VIM_KEYS_READY__ = true;
  #|  if (window.__YUNOMI_VIM_KEYS_DISABLED__) return;
  #|  const storageKey = `yunomi:vim-keys:${filename || "current"}`;
  #|  const state = { index: -1, enabled: localStorage.getItem(storageKey) !== "off" };
  #|  const style = document.createElement("style");
  #|  style.textContent = `
  #|    .vim-key-selected{outline:2px solid var(--accent)!important;outline-offset:2px!important;background:var(--accent-soft)!important}
  #|    .vim-key-help{position:fixed;inset:0;z-index:99999;display:flex;align-items:center;justify-content:center;background:rgba(0,0,0,.28)}
  #|    .vim-key-help.hidden{display:none}
  #|    .vim-key-help-dialog{width:min(420px,calc(100vw - 32px));background:var(--surface);color:var(--text);border:1px solid var(--border);border-radius:8px;box-shadow:var(--shadow-lg);padding:18px}
  #|    .vim-key-help-dialog h2{font-size:16px;margin:0 0 12px}
  #|    .vim-key-help-dialog p{margin:8px 0;color:var(--muted);font-size:13px}
  #|    .vim-key-help-dialog kbd{display:inline-block;min-width:24px;text-align:center;padding:2px 6px;border:1px solid var(--border);border-radius:4px;background:var(--bg);font-size:12px}
  #|    .vim-key-help-dialog button{margin-top:12px;padding:6px 10px;border:1px solid var(--border);border-radius:6px;background:var(--button-bg);color:var(--text);cursor:pointer}
  #|  `;
  #|  document.head.appendChild(style);
  #|  const isTyping = () => {
  #|    const active = document.activeElement;
  #|    const tag = active?.tagName || "";
  #|    const typingEl = tag === "INPUT" || tag === "TEXTAREA" || tag === "SELECT" || active?.isContentEditable;
  #|    return !!typingEl && visible(active);
  #|  };
  #|  const visible = (el) => {
  #|    if (!el) return false;
  #|    if (el.closest("details:not([open])")) return false;
  #|    const cs = getComputedStyle(el);
  #|    const rect = el.getBoundingClientRect();
  #|    return cs.display !== "none" && cs.visibility !== "hidden" && rect.width > 0 && rect.height > 0;
  #|  };
  #|  const dialogVisible = () => {
  #|    if (visible(document.querySelector(".yunomi-inline-comment-editor"))) return true;
  #|    return !!document.querySelector("#submit-modal.visible,#recovery-modal.visible,#yunomi-questions-overlay.visible,.image-fullscreen.visible,.video-fullscreen.visible");
  #|  };
  #|  const mediaSidebarActive = () => {
  #|    const active = document.activeElement;
  #|    const thumbs = Array.from(document.querySelectorAll(".media-sidebar-thumb")).filter(visible);
  #|    return thumbs.length > 0 || active?.classList?.contains("media-sidebar-thumb");
  #|  };
  #|  const targets = () => {
  #|    const selectors = [
  #|      ".text-line[data-row]",
  #|      "td[data-row]",
  #|      ".diff-line",
  #|      "#md-preview .mermaid-container",
  #|      "#md-preview h1,#md-preview h2,#md-preview h3,#md-preview h4,#md-preview h5,#md-preview h6",
  #|      "#md-preview p,#md-preview li,#md-preview blockquote,#md-preview pre",
  #|      "#md-preview img:not(.timeline-thumb),#md-preview video.video-preview,#md-preview .timeline-thumb-wrapper"
  #|    ].join(",");
  #|    const seen = new Set();
  #|    const out = [];
  #|    for (const raw of document.querySelectorAll(selectors)) {
  #|      const el = raw.closest(".timeline-thumb-wrapper") || raw;
  #|      if (el.closest?.("#review-loop-panel,.comment-list,.modal-overlay,.yunomi-inline-comment")) continue;
  #|      if (el.matches?.("td[data-row]") && el.closest?.("#md-preview")) continue;
  #|      if (seen.has(el) || !visible(el)) continue;
  #|      seen.add(el);
  #|      out.push(el);
  #|    }
  #|    return out;
  #|  };
  #|  const clear = () => document.querySelectorAll(".vim-key-selected").forEach((el) => el.classList.remove("vim-key-selected"));
  #|  const select = (next) => {
  #|    const list = targets();
  #|    if (!list.length) return null;
  #|    state.index = Math.max(0, Math.min(list.length - 1, next));
  #|    clear();
  #|    const el = list[state.index];
  #|    el.classList.add("vim-key-selected");
  #|    el.scrollIntoView({ block: "center", inline: "nearest" });
  #|    return el;
  #|  };
  #|  const move = (delta) => {
  #|    const list = targets();
  #|    window.__YUNOMI_VIM_TARGET_COUNT__ = list.length;
  #|    if (!list.length) return false;
  #|    const current = list.indexOf(document.querySelector(".vim-key-selected"));
  #|    const base = current >= 0 ? current : state.index;
  #|    select(base < 0 ? (delta < 0 ? list.length - 1 : 0) : base + delta);
  #|    return true;
  #|  };
  #|  const showHelp = () => {
  #|    let overlay = document.querySelector(".vim-key-help");
  #|    if (!overlay) {
  #|      overlay = document.createElement("div");
  #|      overlay.className = "vim-key-help hidden";
  #|      overlay.innerHTML = `<div class="vim-key-help-dialog" role="dialog" aria-modal="true"><h2>Keyboard review</h2><p><kbd>j</kbd>/<kbd>k</kbd> move · <kbd>c</kbd> comment · <kbd>n</kbd>/<kbd>N</kbd> comments · <kbd>r</kbd> resolve · <kbd>⌘↵</kbd> submit</p><p>Current: <strong data-vim-state></strong></p><button type="button" data-vim-toggle></button></div>`;
  #|      document.body.appendChild(overlay);
  #|      overlay.addEventListener("click", (event) => { if (event.target === overlay) overlay.classList.add("hidden"); });
  #|      overlay.querySelector("[data-vim-toggle]").addEventListener("click", () => {
  #|        state.enabled = !state.enabled;
  #|        localStorage.setItem(storageKey, state.enabled ? "on" : "off");
  #|        updateHelp();
  #|      });
  #|    }
  #|    const updateHelp = () => {
  #|      overlay.querySelector("[data-vim-state]").textContent = state.enabled ? "on" : "off";
  #|      overlay.querySelector("[data-vim-toggle]").textContent = state.enabled ? "Turn off" : "Turn on";
  #|    };
  #|    updateHelp();
  #|    overlay.classList.remove("hidden");
  #|  };
  #|  const clickCurrent = () => {
  #|    const selected = document.querySelector(".vim-key-selected") || select(Math.max(0, state.index));
  #|    if (!selected) return false;
  #|    selected.dispatchEvent(new MouseEvent("click", { bubbles: true, cancelable: true, view: window }));
  #|    return true;
  #|  };
  #|  const jumpComment = (delta) => {
  #|    const entries = Array.from(document.querySelectorAll(".comment-list-entry")).filter(visible);
  #|    if (!entries.length) {
  #|      document.querySelector("#pill-comments")?.click();
  #|      return false;
  #|    }
  #|    const current = entries.findIndex((el) => el.closest("li")?.classList.contains("vim-key-selected"));
  #|    const next = Math.max(0, Math.min(entries.length - 1, (current < 0 ? (delta > 0 ? -1 : entries.length) : current) + delta));
  #|    clear();
  #|    const entry = entries[next];
  #|    entry.closest("li")?.classList.add("vim-key-selected");
  #|    entry.dispatchEvent(new MouseEvent("click", { bubbles: true, cancelable: true, view: window }));
  #|    return true;
  #|  };
  #|  document.addEventListener("keydown", (event) => {
  #|    window.__YUNOMI_VIM_LAST_KEY__ = event.key;
  #|    const composing = event.isComposing || event.keyCode === 229;
  #|    const typing = isTyping();
  #|    const modalOpen = dialogVisible();
  #|    if ((event.key === "?" || event.key === "？") && !typing && !modalOpen && !composing) {
  #|      event.preventDefault();
  #|      showHelp();
  #|      return;
  #|    }
  #|    if (event.key === "Enter" && (event.metaKey || event.ctrlKey) && !typing && !composing) {
  #|      event.preventDefault();
  #|      const modal = document.querySelector("#submit-modal.visible");
  #|      if (!modal) {
  #|        const submit = document.querySelector("#send-and-exit");
  #|        if (submit && visible(submit)) {
  #|          submit.click();
  #|        }
  #|      }
  #|      return;
  #|    }
  #|    const navKey = event.key === "n" || event.key === "N" || event.key === "r";
  #|    if (!state.enabled || typing || composing || event.metaKey || event.ctrlKey || event.altKey) return;
  #|    if (dialogVisible() && event.key !== "n" && event.key !== "N" && event.key !== "r") return;
  #|    if ((event.key === "j" || event.key === "k") && mediaSidebarActive()) return;
  #|    let handled = false;
  #|    if (event.key === "j") handled = move(1);
  #|    else if (event.key === "k") handled = move(-1);
  #|    else if (event.key === "c") handled = clickCurrent();
  #|    else if (event.key === "n") handled = jumpComment(1);
  #|    else if (event.key === "N") handled = jumpComment(-1);
  #|    else if (event.key === "r") {
  #|      const resolve = document.querySelector(".review-loop-resolve");
  #|      if (resolve) {
  #|        resolve.dispatchEvent(new MouseEvent("click", { bubbles: true, cancelable: true, view: window }));
  #|        handled = true;
  #|      }
  #|    }
  #|    if (handled) {
  #|      window.__YUNOMI_VIM_HANDLED__ = event.key;
  #|      event.preventDefault();
  #|      event.stopPropagation();
  #|    }
  #|  }, true);
  #|}

///|
/// Video element control
extern "js" fn video_pause(el : Element) -> Unit =
  #|(el) => { if (el) el.pause(); }

///|
extern "js" fn video_play(el : Element) -> Unit =
  #|(el) => { if (el) el.play(); }

///|
extern "js" fn video_is_paused(el : Element) -> Bool =
  #|(el) => el?.paused !== false

///|
/// Initialize column resizers and filter menu (cli.cjs L6686-6720, L6428-6496)
extern "js" fn init_csv_resizers_and_filters() -> Unit =
  #|() => {
  #|  var table=document.getElementById('csv-table');if(!table)return;
  #|  var tbody=document.getElementById('tbody');if(!tbody)return;
  #|  var filterMenu=document.getElementById('filter-menu');
  #|  var rowMenu=document.getElementById('row-menu');
  #|  var freezeColCheck=document.getElementById('freeze-col-check');
  #|  var freezeRowCheck=document.getElementById('freeze-row-check');
  #|  var MIN_COL_WIDTH=40,MAX_COL_WIDTH=800,ROW_HEADER_WIDTH=50;
  #|  var colWidths=[],filters={},filterTargetCol=null,freezeCols=0,freezeRows=0;
  #|  var ths=table.querySelectorAll('thead th[data-col]');
  #|  ths.forEach(function(th){colWidths.push(th.offsetWidth||100);});
  #|  function clamp(v,min,max){return Math.max(min,Math.min(max,v));}
  #|  function syncColgroup(){
  #|    var cg=table.querySelector('colgroup');
  #|    if(!cg){cg=document.createElement('colgroup');table.prepend(cg);}
  #|    cg.innerHTML='';colWidths.forEach(function(w){var c=document.createElement('col');c.style.width=w+'px';cg.appendChild(c);});
  #|  }
  #|  function updateStickyOffsets(){
  #|    freezeCols=Number(freezeCols||0);freezeRows=Number(freezeRows||0);
  #|    var headCells=document.querySelectorAll('thead th[data-col]');
  #|    var hLeft=ROW_HEADER_WIDTH;
  #|    headCells.forEach(function(th,idx){if(idx<freezeCols){th.classList.add('freeze');th.style.left=hLeft+'px';hLeft+=colWidths[idx];}else{th.classList.remove('freeze');th.style.left=null;}});
  #|  }
  #|  function updateFilterIndicators(){
  #|    ths.forEach(function(th){var ci=Number(th.dataset.col);if(filters[ci])th.classList.add('filtered');else th.classList.remove('filtered');});
  #|  }
  #|  function applyFilters(){
  #|    var rows=tbody.querySelectorAll('tr');
  #|    rows.forEach(function(tr,rIdx){
  #|      var visible=Object.entries(filters).every(function(e){var c=e[0],fn=e[1];var val=(window.__DATA__&&window.__DATA__[rIdx]?window.__DATA__[rIdx][Number(c)]:'')||'';try{return fn(val);}catch(_){return true;}});
  #|      tr.style.display=visible?'':'none';
  #|    });
  #|    updateStickyOffsets();updateFilterIndicators();
  #|  }
  #|  function closeFilterMenu(){if(filterMenu)filterMenu.style.display='none';filterTargetCol=null;}
  #|  function openFilterMenu(col,rect){
  #|    if(!filterMenu)return;filterTargetCol=col;
  #|    var m=8,vw=window.innerWidth,mw=200,mh=260;
  #|    var left=window.scrollX+clamp(rect.left,m,vw-mw-m);
  #|    var top=window.scrollY+rect.bottom+m;
  #|    filterMenu.style.left=left+'px';filterMenu.style.top=top+'px';filterMenu.style.display='block';
  #|    if(freezeColCheck)freezeColCheck.checked=(freezeCols===col+1);
  #|  }
  #|  if(filterMenu)filterMenu.addEventListener('click',function(e){
  #|    var action=e.target.dataset.action;if(!action||filterTargetCol==null)return;
  #|    var col=filterTargetCol;
  #|    if(action==='not-empty')filters[col]=function(v){return(v||'').trim()!=='';};
  #|    else if(action==='empty')filters[col]=function(v){return(v||'').trim()==='';};
  #|    else if(action==='contains'||action==='not-contains'){
  #|      var kw=prompt('Enter text to filter by');if(kw==null||kw===''){closeFilterMenu();return;}
  #|      var lower=kw.toLowerCase();
  #|      if(action==='contains')filters[col]=function(v){return(v||'').toLowerCase().includes(lower);};
  #|      else filters[col]=function(v){return!(v||'').toLowerCase().includes(lower);};
  #|    }else if(action==='reset')delete filters[col];
  #|    closeFilterMenu();applyFilters();
  #|  });
  #|  if(freezeColCheck)freezeColCheck.addEventListener('change',function(){
  #|    if(filterTargetCol==null)return;freezeCols=freezeColCheck.checked?filterTargetCol+1:0;updateStickyOffsets();
  #|  });
  #|  document.addEventListener('click',function(e){if(filterMenu&&filterMenu.style.display==='block'&&!filterMenu.contains(e.target))closeFilterMenu();});
  #|  // Column resize
  #|  function startResize(colIdx,event){
  #|    event.preventDefault();var startX=event.clientX,startW=colWidths[colIdx];
  #|    function onMove(e){colWidths[colIdx]=clamp(startW+(e.clientX-startX),MIN_COL_WIDTH,MAX_COL_WIDTH);syncColgroup();updateStickyOffsets();}
  #|    function onUp(){window.removeEventListener('pointermove',onMove);window.removeEventListener('pointerup',onUp);}
  #|    window.addEventListener('pointermove',onMove);window.addEventListener('pointerup',onUp);
  #|  }
  #|  document.querySelectorAll('.resizer').forEach(function(r){
  #|    r.addEventListener('pointerdown',function(e){e.stopPropagation();startResize(Number(r.dataset.col),e);});
  #|  });
  #|  document.querySelectorAll('thead th .th-inner').forEach(function(h){
  #|    h.addEventListener('click',function(e){var col=Number(h.parentElement.dataset.col);var rect=h.getBoundingClientRect();openFilterMenu(col,rect);e.stopPropagation();});
  #|  });
  #|}

///|
/// Toggle highlight.js theme (dark/light stylesheets)
extern "js" fn toggle_hljs_theme(theme : String) -> Unit =
  #|(theme) => {
  #|  var dark = document.getElementById('hljs-theme-dark');
  #|  var light = document.getElementById('hljs-theme-light');
  #|  if (theme === 'light') {
  #|    if (dark) dark.disabled = true;
  #|    if (light) light.disabled = false;
  #|  } else {
  #|    if (dark) dark.disabled = false;
  #|    if (light) light.disabled = true;
  #|  }
  #|}

///|
/// Create img element and append to parent
extern "js" fn create_timeline_thumb(
  parent : Element,
  src : String,
  time : String,
) -> Unit =
  #|(parent, src, time) => {
  #|  const img = document.createElement("img");
  #|  img.src = src;
  #|  img.className = "timeline-thumb";
  #|  img.dataset.time = time;
  #|  img.style.maxHeight = "60px";
  #|  parent.appendChild(img);
  #|}

///|
/// Get mermaid error count from window.__mermaidErrors
extern "js" fn get_mermaid_error_count() -> Int =
  #|() => (window.__mermaidErrors || []).length

///|
/// Get mermaid error message by index
extern "js" fn get_mermaid_error_message(index : Int) -> String =
  #|(i) => {
  #|  const errs = window.__mermaidErrors || [];
  #|  return i < errs.length ? (errs[i].message || String(errs[i])) : "";
  #|}

///|
/// Get mermaid error source line number by index
extern "js" fn get_mermaid_error_line(index : Int) -> Int =
  #|(i) => {
  #|  const errs = window.__mermaidErrors || [];
  #|  return i < errs.length ? (errs[i].line || 0) : 0;
  #|}

///|
/// Log mermaid errors to console
extern "js" fn log_mermaid_errors_to_console() -> Unit =
  #|() => {
  #|  const errs = window.__mermaidErrors || [];
  #|  if (errs.length > 0) {
  #|    console.error('[yunomi] Mermaid has ' + errs.length + ' error(s):');
  #|    errs.forEach(function(e, i) { console.error('[yunomi] Mermaid error #' + (i+1) + ' (line ' + (e.line||'?') + '):', e.message || String(e)); });
  #|  }
  #|}
