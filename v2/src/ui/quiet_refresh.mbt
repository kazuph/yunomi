///|
/// In-place refresh of the markdown preview when the reviewed file changes.
///
/// The old behaviour was `location.reload()` with a localStorage round trip
/// for drafts. That flashes the whole page and drops the caret. Instead the
/// fresh HTML is fetched in the background and only the blocks whose source
/// text actually changed are swapped; unchanged blocks keep their nodes
/// (rendered Mermaid SVGs, syntax highlighting, open editors, threads).
///
/// Blocks are matched by the source text behind them, not by line numbers,
/// so inserting a paragraph at the top does not invalidate everything below.
/// Line-number attributes on kept blocks are shifted to the new numbering.
extern "js" fn morph_markdown_preview(html : String) -> String =
  #|(html) => {
  #|  const preview = document.querySelector("#md-preview");
  #|  const tbody = document.querySelector("#tbody");
  #|  if (!preview || !tbody) return "reload";
  #|  let doc;
  #|  try { doc = new DOMParser().parseFromString(String(html || ""), "text/html"); } catch (_) { return "reload"; }
  #|  const nextPreview = doc.querySelector("#md-preview");
  #|  const nextTbody = doc.querySelector("#tbody");
  #|  if (!nextPreview || !nextTbody) return "reload";
  #|  const scriptText = (root, marker) => {
  #|    for (const script of root.querySelectorAll("script:not([src])")) {
  #|      const text = script.textContent || "";
  #|      if (text.startsWith(marker)) return text;
  #|    }
  #|    return "";
  #|  };
  #|  // Frontmatter questions are wired into the stepper dialog at boot; a
  #|  // changed question set needs the full boot, not a preview patch.
  #|  const questionsMarker = "window.__YUNOMI_QUESTIONS__=";
  #|  if (scriptText(document, questionsMarker) !== scriptText(doc, questionsMarker)) return "reload";
  #|  const dataText = scriptText(doc, "window.__DATA__=");
  #|  let nextLines = null;
  #|  if (dataText) {
  #|    try { nextLines = JSON.parse(dataText.slice("window.__DATA__=".length).replace(/;\s*$/, "")); } catch (_) { nextLines = null; }
  #|  }
  #|  if (!Array.isArray(nextLines)) return "reload";
  #|  const prevLines = Array.isArray(window.__DATA__) ? window.__DATA__ : [];
  #|  const runtimeSelector = ".review-loop-inline,.review-loop-inline-row,.review-loop-inline-item,.yunomi-inline-comment,.yunomi-inline-comment-editor-mount";
  #|  const lineAttr = (el, name) => {
  #|    const value = Number(el.getAttribute(name));
  #|    return Number.isFinite(value) && value > 0 ? value : 0;
  #|  };
  #|  const signature = (el, lines) => {
  #|    const start = lineAttr(el, "data-source-start-line");
  #|    const end = lineAttr(el, "data-source-end-line");
  #|    if (start && end && end >= start) return "L:" + el.tagName + ":" + lines.slice(start - 1, end).join("\n");
  #|    const line = lineAttr(el, "data-source-line");
  #|    if (line) {
  #|      // A single-line attribute usually marks a block whose body may span
  #|      // further lines (lists, tables). Extend to the next block start.
  #|      const next = el.nextElementSibling;
  #|      let stop = lines.length;
  #|      for (let cursor = next; cursor; cursor = cursor.nextElementSibling) {
  #|        if (cursor.matches(runtimeSelector)) continue;
  #|        const candidate = lineAttr(cursor, "data-source-start-line") || lineAttr(cursor, "data-source-line");
  #|        if (candidate) { stop = candidate - 1; break; }
  #|      }
  #|      return "L:" + el.tagName + ":" + lines.slice(line - 1, Math.max(line, stop)).join("\n");
  #|    }
  #|    return "H:" + el.tagName + ":" + (el.textContent || "").replace(/\s+/g, " ").trim();
  #|  };
  #|  const firstLine = (el) => lineAttr(el, "data-source-start-line") || lineAttr(el, "data-source-line");
  #|  const oldBlocks = Array.from(preview.children).filter(el => !el.matches(runtimeSelector));
  #|  const newBlocks = Array.from(nextPreview.children);
  #|  const oldSigs = oldBlocks.map(el => signature(el, prevLines));
  #|  const newSigs = newBlocks.map(el => signature(el, nextLines));
  #|  // Longest common subsequence over block signatures.
  #|  const n = oldSigs.length, m = newSigs.length;
  #|  let keepPairs = [];
  #|  if (n * m <= 4_000_000) {
  #|    const table = new Uint32Array((n + 1) * (m + 1));
  #|    for (let i = n - 1; i >= 0; i -= 1) {
  #|      for (let j = m - 1; j >= 0; j -= 1) {
  #|        table[i * (m + 1) + j] = oldSigs[i] === newSigs[j]
  #|          ? table[(i + 1) * (m + 1) + j + 1] + 1
  #|          : Math.max(table[(i + 1) * (m + 1) + j], table[i * (m + 1) + j + 1]);
  #|      }
  #|    }
  #|    let i = 0, j = 0;
  #|    while (i < n && j < m) {
  #|      if (oldSigs[i] === newSigs[j]) { keepPairs.push([i, j]); i += 1; j += 1; }
  #|      else if (table[(i + 1) * (m + 1) + j] >= table[i * (m + 1) + j + 1]) i += 1;
  #|      else j += 1;
  #|    }
  #|  }
  #|  const shiftAttrs = (root, delta) => {
  #|    if (!delta) return;
  #|    const nodes = [root, ...root.querySelectorAll("[data-source-line],[data-source-start-line],[data-source-end-line],[data-row]")];
  #|    for (const node of nodes) {
  #|      if (node.closest(runtimeSelector) && node !== root) continue;
  #|      for (const name of ["data-source-line", "data-source-start-line", "data-source-end-line"]) {
  #|        const value = lineAttr(node, name);
  #|        if (value) node.setAttribute(name, String(value + delta));
  #|      }
  #|      if (node.hasAttribute("data-row")) {
  #|        const row = Number(node.getAttribute("data-row"));
  #|        if (Number.isFinite(row)) node.setAttribute("data-row", String(row + delta));
  #|      }
  #|    }
  #|  };
  #|  const keptOld = new Set(keepPairs.map(pair => pair[0]));
  #|  const keptNew = new Map(keepPairs.map(pair => [pair[1], pair[0]]));
  #|  // Runtime nodes (threads, editors) that trail a block belong to it.
  #|  const trailing = (el) => {
  #|    const out = [];
  #|    for (let cursor = el.nextElementSibling; cursor && cursor.matches(runtimeSelector); cursor = cursor.nextElementSibling) out.push(cursor);
  #|    return out;
  #|  };
  #|  let replaced = 0, kept = 0, inserted = 0;
  #|  const removedOld = [];
  #|  oldBlocks.forEach((el, index) => {
  #|    if (keptOld.has(index)) return;
  #|    removedOld.push(el, ...trailing(el));
  #|  });
  #|  replaced = removedOld.length;
  #|  for (const el of removedOld) el.remove();
  #|  // Walk the new order. Kept nodes are never moved (a DOM move blurs a
  #|  // focused textarea inside); new nodes are inserted between them.
  #|  let prev = null;
  #|  const firstKept = oldBlocks.find((el, index) => keptOld.has(index)) || null;
  #|  newBlocks.forEach((nextEl, j) => {
  #|    const oldIndex = keptNew.get(j);
  #|    if (oldIndex !== undefined) {
  #|      const oldEl = oldBlocks[oldIndex];
  #|      const delta = firstLine(nextEl) - firstLine(oldEl);
  #|      shiftAttrs(oldEl, Number.isFinite(delta) ? delta : 0);
  #|      const tail = trailing(oldEl);
  #|      prev = tail.length ? tail[tail.length - 1] : oldEl;
  #|      kept += 1;
  #|    } else {
  #|      const node = document.importNode(nextEl, true);
  #|      if (prev) prev.after(node);
  #|      else if (firstKept) preview.insertBefore(node, firstKept);
  #|      else preview.appendChild(node);
  #|      prev = node;
  #|      inserted += 1;
  #|    }
  #|  });
  #|  window.__DATA__ = nextLines;
  #|  if (tbody.innerHTML !== nextTbody.innerHTML) tbody.innerHTML = nextTbody.innerHTML;
  #|  const summary = { status: "ok", kept, inserted, removed: replaced, at: Date.now() };
  #|  window.__YUNOMI_LAST_QUIET_REFRESH__ = summary;
  #|  window.__YUNOMI_QUIET_REFRESH_COUNT__ = (window.__YUNOMI_QUIET_REFRESH_COUNT__ || 0) + 1;
  #|  return JSON.stringify(summary);
  #|}

///|
/// Render Mermaid blocks that arrived with the patch (those without an SVG
/// yet) and highlight new code blocks. Already-rendered blocks are untouched.
extern "js" fn render_new_preview_blocks() -> Unit =
  #|() => {
  #|  try {
  #|    const pending = Array.from(document.querySelectorAll("#md-preview .mermaid")).filter(el => !el.querySelector("svg"));
  #|    if (pending.length > 0 && typeof mermaid !== "undefined") {
  #|      pending.forEach(el => { el.removeAttribute("data-processed"); el.innerHTML = el.getAttribute("data-source") || el.innerHTML; });
  #|      document.querySelectorAll(".mermaid-error-banner").forEach(b => b.remove());
  #|      mermaid.run({ nodes: pending })
  #|        .then(() => window.__collectMermaidErrors?.())
  #|        .catch(e => { console.error("[yunomi] Mermaid render error:", e); return window.__collectMermaidErrors?.(); });
  #|    }
  #|  } catch (_) {}
  #|  try {
  #|    if (typeof hljs !== "undefined") {
  #|      document.querySelectorAll("#md-preview pre code").forEach(block => {
  #|        if (block.closest(".mermaid-container") || block.classList.contains("hljs")) return;
  #|        hljs.highlightElement(block);
  #|      });
  #|    }
  #|  } catch (_) {}
  #|}

///|
/// Snapshot of the open inline comment editor (if any): which element has
/// the caret and where. `connected` tells whether the editor survived a patch.
extern "js" fn capture_inline_editor_state() -> String =
  #|() => {
  #|  const editor = document.querySelector(".yunomi-inline-comment-editor");
  #|  const input = editor?.querySelector("#comment-input");
  #|  if (!editor || !input) return "";
  #|  window.__yunomiEditorNode = editor;
  #|  return JSON.stringify({
  #|    key: editor.dataset.commentKey || "",
  #|    focused: document.activeElement === input,
  #|    start: input.selectionStart,
  #|    end: input.selectionEnd,
  #|    scrollTop: input.scrollTop,
  #|  });
  #|}

///|
extern "js" fn inline_editor_still_connected() -> Bool =
  #|() => !!(window.__yunomiEditorNode && window.__yunomiEditorNode.isConnected)

///|
extern "js" fn restore_inline_editor_focus(json : String) -> Unit =
  #|(json) => {
  #|  let state;
  #|  try { state = JSON.parse(json || "null"); } catch (_) { state = null; }
  #|  const input = document.querySelector(".yunomi-inline-comment-editor #comment-input");
  #|  if (!state || !input) return;
  #|  if (state.focused) {
  #|    input.focus({ preventScroll: true });
  #|    try { input.setSelectionRange(state.start, state.end); } catch (_) {}
  #|    input.scrollTop = state.scrollTop || 0;
  #|  }
  #|}

///|
/// True while the human is actively typing anywhere on the page. A refresh
/// waits for a pause so the swap never lands mid-keystroke.
extern "js" fn user_typing_recently(window_ms : Int) -> Bool =
  #|(windowMs) => {
  #|  if (!window.__yunomiTypingTracker) {
  #|    window.__yunomiTypingTracker = { last: 0 };
  #|    const bump = () => { window.__yunomiTypingTracker.last = Date.now(); };
  #|    document.addEventListener("input", bump, { capture: true, passive: true });
  #|    document.addEventListener("compositionstart", bump, { capture: true, passive: true });
  #|    document.addEventListener("compositionupdate", bump, { capture: true, passive: true });
  #|    document.addEventListener("keydown", (event) => {
  #|      const tag = document.activeElement?.tagName;
  #|      if (tag === "TEXTAREA" || tag === "INPUT" || event.isComposing) bump();
  #|    }, { capture: true, passive: true });
  #|  }
  #|  return Date.now() - window.__yunomiTypingTracker.last < windowMs;
  #|}

///|
extern "js" fn now_ms() -> Double =
  #|() => Date.now()

///|
/// Remember the focused control and its selection so it can be refocused
/// after DOM surgery moved it (a move blurs; the node itself survives).
extern "js" fn capture_active_control() -> Unit =
  #|() => {
  #|  const el = document.activeElement;
  #|  const editable = el && (el.tagName === "TEXTAREA" || el.tagName === "INPUT" || el.isContentEditable);
  #|  window.__yunomiActiveControl = editable ? { el, start: el.selectionStart, end: el.selectionEnd, scrollTop: el.scrollTop } : null;
  #|}

///|
extern "js" fn restore_active_control() -> Unit =
  #|() => {
  #|  const memo = window.__yunomiActiveControl;
  #|  window.__yunomiActiveControl = null;
  #|  if (!memo || !memo.el || !memo.el.isConnected) return;
  #|  if (document.activeElement === memo.el) return;
  #|  memo.el.focus({ preventScroll: true });
  #|  try { memo.el.setSelectionRange(memo.start, memo.end); } catch (_) {}
  #|  memo.el.scrollTop = memo.scrollTop || 0;
  #|}

///|
/// Scroll anchor: the first block visible in the preview pane and its offset.
/// Captured before any DOM work (toggles unwrapped, blocks swapped, toggles
/// rebuilt) and re-applied after, so a taller or shorter document above the
/// reading position does not move what the human is looking at.
extern "js" fn capture_preview_anchor() -> Unit =
  #|() => {
  #|  const preview = document.querySelector("#md-preview");
  #|  const pane = preview?.closest(".md-left") || preview?.parentElement;
  #|  window.__yunomiPreviewAnchor = null;
  #|  if (!preview || !pane) return;
  #|  const paneTop = pane.getBoundingClientRect().top;
  #|  const candidates = preview.querySelectorAll("[data-source-line],[data-source-start-line]");
  #|  for (const el of candidates) {
  #|    if (el.closest(".review-loop-inline,.yunomi-inline-comment,summary")) continue;
  #|    const rect = el.getBoundingClientRect();
  #|    if (rect.height > 0 && rect.bottom > paneTop) {
  #|      window.__yunomiPreviewAnchor = { el, offset: rect.top - paneTop, scrollTop: pane.scrollTop };
  #|      return;
  #|    }
  #|  }
  #|}

///|
extern "js" fn restore_preview_anchor() -> Unit =
  #|() => {
  #|  const memo = window.__yunomiPreviewAnchor;
  #|  window.__yunomiPreviewAnchor = null;
  #|  const preview = document.querySelector("#md-preview");
  #|  const pane = preview?.closest(".md-left") || preview?.parentElement;
  #|  if (!memo || !pane) return;
  #|  if (!memo.el.isConnected) { pane.scrollTop = memo.scrollTop; return; }
  #|  const rect = memo.el.getBoundingClientRect();
  #|  const drift = (rect.top - pane.getBoundingClientRect().top) - memo.offset;
  #|  if (Math.abs(drift) > 0.5) pane.scrollTop += drift;
  #|}
