///|
/// Unread tracking for agent messages in the conversation UI.
///
/// Every rendered message carries `data-message-key`; keys the human has
/// already looked at are remembered per review scope in localStorage. What is
/// left over drives three cues:
///   - the red counter in the header (unread replies inside inline threads),
///   - the red dot on the bottom-right chat (unread replies in the global chat),
///   - a short bell plus a `(N)` tab-title prefix when something new arrives.
///
/// An inline reply counts as seen only when the human consumes it: one badge
/// click scrolls to and reads exactly one message, or interacting with the
/// thread reads that thread. Scrolling past never reads anything. The global
/// chat is read once the panel is expanded on a visible tab.
extern "js" fn install_conversation_unread(scope : String) -> Unit =
  #|(scope) => {
  #|  if (window.__yunomiUnread) return;
  #|  const storageKey = `yunomi:conversation-seen:${scope || "current"}`;
  #|  const inlineSelector = ".review-loop-inline";
  #|  const readStore = () => {
  #|    try {
  #|      const raw = localStorage.getItem(storageKey);
  #|      if (raw === null) return null;
  #|      const parsed = JSON.parse(raw);
  #|      return parsed && typeof parsed === "object" ? parsed : {};
  #|    } catch (_) { return {}; }
  #|  };
  #|  const writeStore = (store) => {
  #|    try { localStorage.setItem(storageKey, JSON.stringify(store)); } catch (_) {}
  #|  };
  #|  const agentNodes = () => Array.from(document.querySelectorAll('[data-message-key][data-message-author="agent"]'));
  #|  const baseTitle = document.title.replace(/^\(\d+\)\s*/, "");
  #|  const known = new Set();
  #|  let primed = false;
  #|  let audio = null;
  #|  let lastBellAt = 0;
  #|  const unlockAudio = () => {
  #|    try {
  #|      const Ctx = window.AudioContext || window.webkitAudioContext;
  #|      if (!Ctx) return;
  #|      if (!audio) audio = new Ctx();
  #|      if (audio.state === "suspended") audio.resume().catch(() => {});
  #|    } catch (_) {}
  #|  };
  #|  // Browsers only let a page make sound after a user gesture; prepare the
  #|  // context on the first one so a later reply can ring immediately.
  #|  for (const type of ["pointerdown", "keydown"]) document.addEventListener(type, unlockAudio, { capture: true, passive: true });
  #|  const bell = () => {
  #|    if (window.__YUNOMI_SILENT__ === true) return;
  #|    const now = Date.now();
  #|    if (now - lastBellAt < 1500) return;
  #|    lastBellAt = now;
  #|    window.__YUNOMI_LAST_BELL_AT__ = now;
  #|    try {
  #|      unlockAudio();
  #|      if (!audio || audio.state !== "running") return;
  #|      const t0 = audio.currentTime;
  #|      const tone = (freq, at, duration, gain) => {
  #|        const osc = audio.createOscillator();
  #|        const amp = audio.createGain();
  #|        osc.type = "sine";
  #|        osc.frequency.setValueAtTime(freq, at);
  #|        amp.gain.setValueAtTime(0.0001, at);
  #|        amp.gain.exponentialRampToValueAtTime(gain, at + 0.012);
  #|        amp.gain.exponentialRampToValueAtTime(0.0001, at + duration);
  #|        osc.connect(amp).connect(audio.destination);
  #|        osc.start(at);
  #|        osc.stop(at + duration + 0.02);
  #|      };
  #|      tone(880, t0, 0.28, 0.06);
  #|      tone(1318.5, t0 + 0.16, 0.34, 0.05);
  #|    } catch (_) {}
  #|  };
  #|  const unreadKeys = () => {
  #|    const store = readStore() || {};
  #|    const keys = new Set();
  #|    for (const node of agentNodes()) {
  #|      const key = node.getAttribute("data-message-key") || "";
  #|      if (key && !store[key]) keys.add(key);
  #|    }
  #|    return keys;
  #|  };
  #|  const markSeen = (keys) => {
  #|    const list = Array.from(keys).filter(Boolean);
  #|    if (!list.length) return;
  #|    const store = readStore() || {};
  #|    let changed = false;
  #|    for (const key of list) {
  #|      if (!store[key]) { store[key] = 1; changed = true; }
  #|    }
  #|    if (changed) { writeStore(store); sync(); }
  #|  };
  #|  const keysIn = (root) => Array.from(root.querySelectorAll('[data-message-key][data-message-author="agent"]')).map(node => node.getAttribute("data-message-key") || "");
  #|  const panel = () => document.querySelector("#review-loop-panel");
  #|  const panelOpenAndVisible = () => {
  #|    const el = panel();
  #|    return !!el && !el.classList.contains("review-loop-sidebar-collapsed") && document.visibilityState === "visible";
  #|  };
  #|  let globalTimer = 0;
  #|  const scheduleGlobalSeen = () => {
  #|    clearTimeout(globalTimer);
  #|    if (!panelOpenAndVisible()) return;
  #|    globalTimer = setTimeout(() => {
  #|      const el = panel();
  #|      if (!el || !panelOpenAndVisible()) return;
  #|      markSeen(keysIn(el));
  #|    }, 1200);
  #|  };
  #|  // Inline threads are never auto-read by scrolling past them: the human
  #|  // consumes them one message per badge click, or by interacting with the
  #|  // thread (clicking into it / typing a reply).
  #|  const watchInlines = (_unread) => {};
  #|  const render = (unread) => {
  #|    const inlineUnread = new Set();
  #|    for (const inline of document.querySelectorAll(inlineSelector)) {
  #|      for (const key of keysIn(inline)) if (unread.has(key)) inlineUnread.add(key);
  #|    }
  #|    const globalUnread = new Set();
  #|    const el = panel();
  #|    if (el) for (const key of keysIn(el)) if (unread.has(key)) globalUnread.add(key);
  #|    const badge = document.querySelector("#conversation-unread");
  #|    if (badge) {
  #|      // The header counter is the one place that sums every unread reply,
  #|      // inline threads and the bottom-right chat alike.
  #|      const count = inlineUnread.size + globalUnread.size;
  #|      const previous = Number(badge.textContent || 0);
  #|      badge.textContent = String(count);
  #|      badge.hidden = count === 0;
  #|      if (count > previous && count > 0) {
  #|        badge.classList.remove("is-pulse");
  #|        void badge.offsetWidth;
  #|        badge.classList.add("is-pulse");
  #|      }
  #|    }
  #|    const dot = el?.querySelector(".review-loop-unread-dot");
  #|    if (dot) dot.hidden = globalUnread.size === 0;
  #|    for (const node of agentNodes()) {
  #|      node.classList.toggle("is-unread", unread.has(node.getAttribute("data-message-key") || ""));
  #|    }
  #|    const total = inlineUnread.size + globalUnread.size;
  #|    document.title = total > 0 ? `(${total}) ${baseTitle}` : baseTitle;
  #|    window.__YUNOMI_UNREAD__ = { inline: inlineUnread.size, global: globalUnread.size, total };
  #|    return { inlineUnread, globalUnread };
  #|  };
  #|  const sync = () => {
  #|    let store = readStore();
  #|    const nodes = agentNodes();
  #|    if (store === null) {
  #|      // First visit of this review: what is already on the page is history,
  #|      // not news. Start counting from here.
  #|      store = {};
  #|      for (const node of nodes) { const key = node.getAttribute("data-message-key") || ""; if (key) store[key] = 1; }
  #|      writeStore(store);
  #|    }
  #|    const unread = unreadKeys();
  #|    let fresh = 0;
  #|    for (const node of nodes) {
  #|      const key = node.getAttribute("data-message-key") || "";
  #|      if (!key || known.has(key)) continue;
  #|      known.add(key);
  #|      if (primed && unread.has(key)) fresh += 1;
  #|    }
  #|    primed = true;
  #|    render(unread);
  #|    watchInlines(unread);
  #|    if (fresh > 0) bell();
  #|    scheduleGlobalSeen();
  #|  };
  #|  const firstUnreadMessage = () => {
  #|    const unread = unreadKeys();
  #|    for (const inline of document.querySelectorAll(inlineSelector)) {
  #|      for (const node of inline.querySelectorAll('[data-message-key][data-message-author="agent"]')) {
  #|        if (unread.has(node.getAttribute("data-message-key") || "")) return node;
  #|      }
  #|    }
  #|    // Document threads first, then the chat (oldest unread first).
  #|    const el = panel();
  #|    if (el) {
  #|      for (const node of el.querySelectorAll('[data-message-key][data-message-author="agent"]')) {
  #|        if (unread.has(node.getAttribute("data-message-key") || "")) return node;
  #|      }
  #|    }
  #|    return null;
  #|  };
  #|  const expandPanel = () => {
  #|    const el = panel();
  #|    if (!el || !el.classList.contains("review-loop-sidebar-collapsed")) return;
  #|    el.querySelector(".review-loop-sidebar-toggle")?.click();
  #|  };
  #|  // One click, one message: scroll to the oldest unread reply, flash it,
  #|  // and count it as read. The badge goes 3 → 2 → 1 → 0, never 3 → 0.
  #|  document.addEventListener("click", (event) => {
  #|    const badge = event.target?.closest?.("#conversation-unread");
  #|    if (!badge) return;
  #|    event.preventDefault();
  #|    event.stopPropagation();
  #|    const node = firstUnreadMessage();
  #|    if (!node) return;
  #|    if (node.closest("#review-loop-panel")) expandPanel();
  #|    node.scrollIntoView({ block: "center", behavior: "smooth" });
  #|    node.classList.remove("is-flash");
  #|    void node.offsetWidth;
  #|    node.classList.add("is-flash");
  #|    setTimeout(() => node.classList.remove("is-flash"), 1600);
  #|    markSeen([node.getAttribute("data-message-key") || ""]);
  #|  }, true);
  #|  document.addEventListener("focusin", (event) => {
  #|    const inline = event.target?.closest?.(inlineSelector);
  #|    if (inline) markSeen(keysIn(inline));
  #|    else if (event.target?.closest?.("#review-loop-panel")) markSeen(keysIn(panel() || document.createElement("div")));
  #|  });
  #|  document.addEventListener("pointerdown", (event) => {
  #|    const inline = event.target?.closest?.(inlineSelector);
  #|    if (inline) markSeen(keysIn(inline));
  #|  }, { passive: true });
  #|  document.addEventListener("visibilitychange", () => {
  #|    if (document.visibilityState === "visible") sync();
  #|  });
  #|  window.__yunomiUnread = { sync, unreadKeys, markSeen, bell };
  #|}
