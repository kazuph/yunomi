///|
/// Notifications the launching agent never received.
///
/// The server keeps every failed delivery (a refused `herdr agent prompt`, an
/// outdated Herdr, a missing tmux pane) until a resend succeeds. This module
/// shows the count in the header, lists each lost message with the reason,
/// and resends one through `/notify/retry`, which only accepts ids the server
/// stored. `render_notify_undelivered_json` receives the list from the
/// `notify-undelivered` SSE event; installation fetches the current list so a
/// reload or reconnect shows losses that happened while no tab was open.
extern "js" fn install_notify_undelivered(retry_icon : String) -> Unit =
  #|(retryIcon) => {
  #|  if (window.__yunomiNotifyUndelivered) return;
  #|  const url = (path) => {
  #|    const context = String(window.__YUNOMI_REQUEST_CONTEXT__ || "");
  #|    if (!context) return location.origin + path;
  #|    const separator = path.includes("?") ? "&" : "?";
  #|    return location.origin + path + (context.startsWith("?") ? separator + context.slice(1) : context);
  #|  };
  #|  const badge = () => document.querySelector("#notify-undelivered");
  #|  const panel = () => document.querySelector("#notify-undelivered-panel");
  #|  let items = [];
  #|  let version = -1;
  #|  const live = (text) => {
  #|    const region = document.querySelector("#notify-undelivered-live");
  #|    if (region) region.textContent = text;
  #|  };
  #|  // Herdr reports refusals as `<cmd> exited N: {"error":{"code","message"}}`;
  #|  // show `code: message` and keep the raw text in the tooltip.
  #|  const readableError = (raw) => {
  #|    const text = String(raw || "");
  #|    const start = text.indexOf("{");
  #|    if (start >= 0) {
  #|      try {
  #|        const parsed = JSON.parse(text.slice(start));
  #|        const code = parsed?.error?.code;
  #|        const message = parsed?.error?.message;
  #|        if (code || message) return [code, message].filter(Boolean).join(": ");
  #|      } catch (_) {}
  #|    }
  #|    return text;
  #|  };
  #|  const setOpen = (open) => {
  #|    const b = badge();
  #|    const p = panel();
  #|    if (!b || !p) return;
  #|    p.hidden = !open || items.length === 0;
  #|    b.setAttribute("aria-expanded", p.hidden ? "false" : "true");
  #|    if (!p.hidden) place();
  #|  };
  #|  // Open below the counter, right-aligned to it, but always fully inside
  #|  // the viewport with the 16px side gutter (the counter can sit near the
  #|  // left edge on a phone-width header).
  #|  const place = () => {
  #|    const b = badge();
  #|    const p = panel();
  #|    if (!b || !p || p.hidden) return;
  #|    const rect = b.getBoundingClientRect();
  #|    const width = p.offsetWidth;
  #|    const maxLeft = Math.max(16, window.innerWidth - width - 16);
  #|    p.style.top = Math.round(rect.bottom + 8) + "px";
  #|    p.style.left = Math.round(Math.min(Math.max(16, rect.right - width), maxLeft)) + "px";
  #|  };
  #|  window.addEventListener("resize", place);
  #|  const renderPanel = () => {
  #|    const p = panel();
  #|    if (!p) return;
  #|    // Rebuilding the rows must not drop keyboard focus: remember which
  #|    // notification's control had it and give it back to the same one.
  #|    const focusedId = p.contains(document.activeElement)
  #|      ? document.activeElement.closest("[data-notify-id]")?.dataset.notifyId || ""
  #|      : "";
  #|    p.replaceChildren(...items.map((item) => {
  #|      const row = document.createElement("div");
  #|      row.className = "notify-undelivered-item";
  #|      row.dataset.notifyId = item.id;
  #|      const summary = document.createElement("div");
  #|      summary.className = "notify-undelivered-summary";
  #|      summary.textContent = item.summary;
  #|      summary.title = item.message;
  #|      const error = document.createElement("div");
  #|      error.className = "notify-undelivered-error";
  #|      error.textContent = readableError(item.error);
  #|      error.title = item.error;
  #|      const retry = document.createElement("button");
  #|      retry.type = "button";
  #|      retry.className = "notify-undelivered-retry";
  #|      retry.title = "Resend to the agent";
  #|      retry.setAttribute("aria-label", "Resend to the agent: " + item.summary);
  #|      retry.innerHTML = retryIcon;
  #|      retry.addEventListener("click", async (event) => {
  #|        event.stopPropagation();
  #|        // aria-disabled instead of disabled: a disabled button drops
  #|        // keyboard focus, which the rebuilt row could then not restore.
  #|        if (retry.getAttribute("aria-disabled") === "true") return;
  #|        retry.setAttribute("aria-disabled", "true");
  #|        try {
  #|          const response = await fetch(url("/notify/retry"), {
  #|            method: "POST",
  #|            headers: { "Content-Type": "application/json" },
  #|            body: JSON.stringify({ id: item.id }),
  #|          });
  #|          if (response.status === 404) {
  #|            await refresh();
  #|          } else {
  #|            const result = await response.json();
  #|            live(result.delivered
  #|              ? "Resent to the agent: " + item.summary
  #|              : "Still not delivered to the agent: " + item.summary);
  #|          }
  #|        } catch (_) {
  #|          // The SSE list stays authoritative; a network error leaves the row.
  #|        } finally {
  #|          retry.removeAttribute("aria-disabled");
  #|        }
  #|      });
  #|      row.append(summary, retry, error);
  #|      return row;
  #|    }));
  #|    if (focusedId) {
  #|      const again = p.querySelector('[data-notify-id="' + CSS.escape(focusedId) + '"] .notify-undelivered-retry')
  #|        || p.querySelector(".notify-undelivered-retry");
  #|      // With nothing left the counter hides, so hand focus to the live
  #|      // connection status next to it instead of a hidden control.
  #|      if (again) again.focus();
  #|      else document.querySelector("#sse-status")?.focus();
  #|    }
  #|  };
  #|  const render = (next) => {
  #|    const previous = items.length;
  #|    const known = new Set(items.map((item) => item.id));
  #|    items = Array.isArray(next) ? next : [];
  #|    const added = items.filter((item) => !known.has(item.id));
  #|    const b = badge();
  #|    if (b) {
  #|      b.textContent = String(items.length);
  #|      b.hidden = items.length === 0;
  #|      b.setAttribute("aria-label", items.length + " undelivered agent notification" + (items.length === 1 ? "" : "s"));
  #|      if (previous >= 0 && added.length > 0) {
  #|        live("Not delivered to the agent: " + added[added.length - 1].summary);
  #|      }
  #|      if (items.length > previous) {
  #|        b.classList.remove("is-pulse");
  #|        void b.offsetWidth;
  #|        b.classList.add("is-pulse");
  #|      }
  #|    }
  #|    renderPanel();
  #|    const p = panel();
  #|    if (p && !p.hidden && items.length === 0) setOpen(false);
  #|  };
  #|  // The SSE event and the initial fetch can arrive in either order; only a
  #|  // list at least as new as the one on screen replaces it.
  #|  const renderJson = (raw) => {
  #|    try {
  #|      const data = JSON.parse(raw);
  #|      const next = Number(data.version ?? 0);
  #|      if (next < version) return;
  #|      version = next;
  #|      render(data.items);
  #|    } catch (_) {}
  #|  };
  #|  const refresh = async () => {
  #|    try {
  #|      const response = await fetch(url("/notify/undelivered"), { cache: "no-store" });
  #|      if (response.ok) renderJson(await response.text());
  #|    } catch (_) {}
  #|  };
  #|  document.addEventListener("click", (event) => {
  #|    const b = badge();
  #|    const p = panel();
  #|    if (!b || !p) return;
  #|    if (event.target === b || b.contains(event.target)) {
  #|      setOpen(p.hidden);
  #|    } else if (!p.hidden && !p.contains(event.target)) {
  #|      setOpen(false);
  #|    }
  #|  });
  #|  document.addEventListener("keydown", (event) => {
  #|    const p = panel();
  #|    if (event.key === "Escape" && p && !p.hidden) {
  #|      setOpen(false);
  #|      badge()?.focus();
  #|    }
  #|  });
  #|  window.__yunomiNotifyUndelivered = { renderJson, refresh };
  #|  refresh();
  #|}

///|
extern "js" fn render_notify_undelivered_json(data : String) -> Unit =
  #|(data) => window.__yunomiNotifyUndelivered?.renderJson(data)

///|
extern "js" fn refresh_notify_undelivered() -> Unit =
  #|() => window.__yunomiNotifyUndelivered?.refresh()

///|
/// Keyboard focus is on the undelivered counter or its panel, where Enter and
/// Space belong to those controls rather than to the document shortcuts.
extern "js" fn active_in_notify_undelivered() -> Bool =
  #|() => !!document.activeElement?.closest?.(".notify-undelivered-anchor")
