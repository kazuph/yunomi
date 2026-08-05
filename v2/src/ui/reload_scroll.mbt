///|
extern "js" fn save_reload_scroll_state(key : String) -> Unit =
  #|(key) => {
  #|  const read = (selector) => {
  #|    const element = document.querySelector(selector);
  #|    return element ? { left: element.scrollLeft, top: element.scrollTop } : { left: 0, top: 0 };
  #|  };
  #|  try {
  #|    const scrollRestoration = history.scrollRestoration;
  #|    history.scrollRestoration = "manual";
  #|    sessionStorage.setItem(key, JSON.stringify({
  #|      scrollRestoration,
  #|      window: { left: window.scrollX, top: window.scrollY },
  #|      preview: read(".md-left"),
  #|      source: read(".md-right"),
  #|    }));
  #|  } catch (_) {}
  #|}

///|
extern "js" fn restore_reload_scroll_state(key : String) -> Unit =
  #|(key) => {
  #|  let state;
  #|  try {
  #|    state = JSON.parse(sessionStorage.getItem(key) || "null");
  #|    sessionStorage.removeItem(key);
  #|  } catch (_) {
  #|    state = null;
  #|  }
  #|  if (!state) return;
  #|  const number = (value) => Number.isFinite(Number(value)) ? Number(value) : 0;
  #|  const restore = (selector, position) => {
  #|    const element = document.querySelector(selector);
  #|    if (!element) return;
  #|    const maxLeft = Math.max(0, element.scrollWidth - element.clientWidth);
  #|    const maxTop = Math.max(0, element.scrollHeight - element.clientHeight);
  #|    element.scrollLeft = Math.max(0, Math.min(number(position?.left), maxLeft));
  #|    element.scrollTop = Math.max(0, Math.min(number(position?.top), maxTop));
  #|  };
  #|  window.__YUNOMI_RELOAD_SCROLL_RESTORING__ = true;
  #|  history.scrollRestoration = "manual";
  #|  requestAnimationFrame(() => {
  #|    window.scrollTo({ left: number(state.window?.left), top: number(state.window?.top), behavior: "instant" });
  #|    restore(".md-left", state.preview);
  #|    restore(".md-right", state.source);
  #|    requestAnimationFrame(() => {
  #|      window.__YUNOMI_RELOAD_SCROLL_RESTORING__ = false;
  #|      history.scrollRestoration = state.scrollRestoration === "manual" ? "manual" : "auto";
  #|    });
  #|  });
  #|}

///|
extern "js" fn reload_scroll_restore_active() -> Bool =
  #|() => window.__YUNOMI_RELOAD_SCROLL_RESTORING__ === true
