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
extern "js" fn _event_is_composing(e : Event) -> Bool =
  #|(e) => e.isComposing || e.keyCode === 229

///|
/// Set disabled attribute on element
extern "js" fn set_disabled(el : Element, disabled : Bool) -> Unit =
  #|(el, disabled) => { if (el) el.disabled = disabled; }

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
  #|    return Object.entries(comments).map(([k, v]) => [k, String(v.row||0), String(v.col||0), v.text||""]);
  #|  } catch(e) { return []; }
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
/// Collect yunomi answers from question panel
extern "js" fn collect_yunomi_answers() -> String =
  #|() => {
  #|  var answers = {};
  #|  document.querySelectorAll('.question-card').forEach(function(item) {
  #|    var id = item.dataset.qid || '';
  #|    var textarea = item.querySelector('.q-answer');
  #|    if (id && textarea && textarea.value) {
  #|      answers[id] = textarea.value;
  #|    }
  #|  });
  #|  return JSON.stringify(answers);
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
