///|
/// Build the main CSS styles
fn build_css() -> String {
  let css =
    #|/* Dark theme (default) — deep-green, matcha-accent (background is now
    #|   green-tinted charcoal, not warm brown, per rebrand feedback) */
    #|:root {
    #|  color-scheme: dark;
    #|  --bg: #131a12;
    #|  --bg-gradient: radial-gradient(120% 80% at 15% 0%, #1f2a1b 0%, #182016 40%, #131a12 80%);
    #|  --panel: #182116;
    #|  --panel-alpha: rgba(19, 26, 18, 0.82);
    #|  --panel-solid: #172014;
    #|  --card-bg: rgba(24, 32, 22, 0.96);
    #|  --input-bg: rgba(28, 37, 25, 0.75);
    #|  --border: #2a3524;
    #|  --border-strong: #37452e;
    #|  --accent: #9fc47c;
    #|  --accent-strong: #b9d99a;
    #|  --accent-2: #5c8a42;
    #|  --accent-soft: rgba(159, 196, 124, 0.14);
    #|  --text: #f1ebe1;
    #|  --text-inverse: #1a1612;
    #|  --muted: #9f9488;
    #|  --comment: #b78a5a;
    #|  --badge: #6bbf86;
    #|  --table-bg: rgba(24, 32, 22, 0.72);
    #|  --row-even: rgba(42, 52, 36, 0.5);
    #|  --row-odd: rgba(24, 32, 22, 0.25);
    #|  --selected-bg: rgba(159, 196, 124, 0.22);
    #|  --hover-bg: rgba(159, 196, 124, 0.14);
    #|  --shadow-color: rgba(0,0,0,0.45);
    #|  --shadow-soft: 0 10px 30px rgba(0,0,0,0.35);
    #|  --shadow-card: 0 20px 40px rgba(0,0,0,0.4);
    #|  --code-bg: #1e2819;
    #|  --error: #e06862;
    #|  --success: #6bbf86;
    #|  --warning: #e8b574;
    #|  --radius-sm: 8px;
    #|  --radius-md: 12px;
    #|  --radius-lg: 16px;
    #|  --radius-pill: 999px;
    #|  --font-display: "Inter", "Hiragino Kaku Gothic ProN", "Hiragino Sans", system-ui, -apple-system, sans-serif;
    #|}
    #|/* Light theme — wakakusa cream base with sencha/matcha green accent
    #|   (background is now softly green-tinted, not warm beige, per rebrand
    #|   feedback: "inside of a teacup filled with green tea") */
    #|[data-theme="light"] {
    #|  color-scheme: light;
    #|  --bg: #eef3e3;
    #|  --bg-gradient: linear-gradient(180deg, #f5f8ec 0%, #e3ead2 100%);
    #|  --panel: #f6faf0;
    #|  --panel-alpha: rgba(246, 250, 240, 0.92);
    #|  --panel-solid: #f6faf0;
    #|  --card-bg: rgba(248, 251, 243, 0.98);
    #|  --input-bg: #e9f0dc;
    #|  --border: #d7e2c4;
    #|  --border-strong: #c2d1a5;
    #|  --accent: #5c8a42;
    #|  --accent-strong: #466b30;
    #|  --accent-2: #9fc47c;
    #|  --accent-soft: rgba(92, 138, 66, 0.12);
    #|  --text: #3b2d20;
    #|  --text-inverse: #fffaf0;
    #|  --muted: #87735b;
    #|  --comment: #a8785a;
    #|  --badge: #4d9d63;
    #|  --table-bg: #f6faf0;
    #|  --row-even: #eaf1de;
    #|  --row-odd: #f6faf0;
    #|  --selected-bg: rgba(92, 138, 66, 0.20);
    #|  --hover-bg: rgba(92, 138, 66, 0.12);
    #|  --shadow-color: rgba(60, 40, 20, 0.08);
    #|  --shadow-soft: 0 6px 18px rgba(60, 40, 20, 0.08);
    #|  --shadow-card: 0 18px 36px rgba(60, 40, 20, 0.12);
    #|  --code-bg: #e9f0dc;
    #|  --error: #c9564f;
    #|  --success: #4d9d63;
    #|  --warning: #c58a40;
    #|}
    #|* { box-sizing: border-box; }
    #|:focus-visible { outline: 2px solid var(--accent); outline-offset: 2px; border-radius: 4px; }
    #|body {
    #|  margin: 0;
    #|  font-family: var(--font-display, "Inter", "Hiragino Kaku Gothic ProN", "Hiragino Sans", system-ui, -apple-system, sans-serif);
    #|  background: var(--bg-gradient);
    #|  color: var(--text);
    #|  height: 100vh;
    #|  display: flex;
    #|  flex-direction: column;
    #|  overflow: hidden;
    #|  -webkit-font-smoothing: antialiased;
    #|  -moz-osx-font-smoothing: grayscale;
    #|  letter-spacing: -0.005em;
    #|  transition: background 240ms ease, color 240ms ease;
    #|}
    #|header {
    #|  position: sticky;
    #|  top: 0;
    #|  z-index: 5;
    #|  flex-shrink: 0;
    #|  padding: 14px 20px;
    #|  background: var(--panel-alpha);
    #|  backdrop-filter: saturate(140%) blur(18px);
    #|  -webkit-backdrop-filter: saturate(140%) blur(18px);
    #|  border-bottom: 1px solid var(--border);
    #|  display: flex;
    #|  gap: 14px;
    #|  align-items: center;
    #|  justify-content: space-between;
    #|  transition: background 240ms ease, border-color 240ms ease;
    #|}
    #|header .meta { display: flex; gap: 14px; align-items: center; flex-wrap: wrap; }
    #|header .actions { display: flex; gap: 6px; align-items: center; }
    #|header h1 { display: flex; flex-direction: column; margin: 0; line-height: 1.3; }
    #|header h1 .title-path { font-size: 11px; font-weight: 500; color: var(--muted); letter-spacing: 0.02em; }
    #|header h1 .title-file { font-size: 16px; font-weight: 700; letter-spacing: -0.01em; }
    #|/* Default header icon buttons (ghost) */
    #|header button {
    #|  background: transparent;
    #|  color: var(--text);
    #|  border: 1px solid transparent;
    #|  border-radius: var(--radius-sm);
    #|  padding: 5px 12px;
    #|  min-height: 34px;
    #|  min-width: 34px;
    #|  font-size: 14px;
    #|  font-weight: 500;
    #|  cursor: pointer;
    #|  box-shadow: none;
    #|  transition: background 160ms ease, border-color 160ms ease, transform 120ms ease, color 160ms ease;
    #|  display: inline-flex;
    #|  align-items: center;
    #|  justify-content: center;
    #|  gap: 6px;
    #|}
    #|header button:hover { background: var(--hover-bg); border-color: var(--border); transform: none; box-shadow: none; }
    #|header button:active { transform: translateY(0); background: var(--selected-bg); }
    #|/* Primary submit button */
    #|header button.submit-exit-btn {
    #|  background: linear-gradient(135deg, var(--accent) 0%, var(--accent-2) 100%);
    #|  color: var(--text-inverse);
    #|  border: none;
    #|  padding: 6px 18px;
    #|  font-weight: 700;
    #|  letter-spacing: 0.01em;
    #|  box-shadow: var(--shadow-soft);
    #|}
    #|header button.submit-exit-btn:hover {
    #|  background: linear-gradient(135deg, var(--accent-strong) 0%, var(--accent) 100%);
    #|  border: none;
    #|  transform: translateY(-1px);
    #|  box-shadow: var(--shadow-card);
    #|}
    #|header button.submit-exit-btn:disabled {
    #|  opacity: 0.5;
    #|  cursor: not-allowed;
    #|  transform: none;
    #|  box-shadow: none;
    #|}
    #|/* Theme toggle button */
    #|.theme-toggle {
    #|  background: transparent;
    #|  color: var(--muted);
    #|  border: 1px solid transparent;
    #|  border-radius: var(--radius-sm);
    #|  font-size: 15px;
    #|  cursor: pointer;
    #|  transition: background 160ms ease, color 160ms ease;
    #|  display: flex;
    #|  align-items: center;
    #|  justify-content: center;
    #|  gap: 6px;
    #|  min-width: 34px;
    #|  padding: 0 10px;
    #|  height: 34px;
    #|}
    #|.theme-toggle:hover { background: var(--hover-bg); color: var(--text); }
    #|/* SSE status dot (header) */
    #|.sse-dot {
    #|  display: inline-flex;
    #|  align-items: center;
    #|  gap: 6px;
    #|  height: 34px;
    #|  padding: 0 10px 0 8px;
    #|  margin-right: 2px;
    #|  border-radius: var(--radius-pill);
    #|  position: relative;
    #|  cursor: default;
    #|  flex-shrink: 0;
    #|}
    #|.sse-dot::before {
    #|  content: "";
    #|  display: block;
    #|  width: 8px;
    #|  height: 8px;
    #|  border-radius: 50%;
    #|  background: var(--muted);
    #|  box-shadow: 0 0 0 0 currentColor;
    #|  transition: background 200ms ease;
    #|}
    #|.sse-dot-connected::before { background: var(--success); box-shadow: 0 0 8px rgba(107, 191, 134, 0.45); }
    #|.sse-dot-reconnecting::before { background: var(--error); animation: sseBlink 1.1s ease-in-out infinite; }
    #|.sse-dot-sending::before { background: var(--warning); animation: sseBlink 0.9s ease-in-out infinite; }
    #|@keyframes sseBlink { 0%, 100% { opacity: 1; } 50% { opacity: 0.35; } }
    #|
    #|.wrap {
    #|  padding: 12px 16px 12px;
    #|  flex: 1;
    #|  min-height: 0;
    #|  display: flex;
    #|  flex-direction: column;
    #|  overflow-y: auto;
    #|}
    #|.toolbar {
    #|  display: flex;
    #|  gap: 12px;
    #|  align-items: center;
    #|  flex-wrap: wrap;
    #|  margin: 10px 0 12px;
    #|  color: var(--muted);
    #|  font-size: 13px;
    #|}
    #|.toolbar button {
    #|  background: var(--accent-soft);
    #|  color: var(--text);
    #|  border: 1px solid var(--border);
    #|  border-radius: var(--radius-sm);
    #|  padding: 8px 12px;
    #|  font-size: 13px;
    #|  cursor: pointer;
    #|  transition: background 160ms ease, border-color 160ms ease;
    #|}
    #|.toolbar button:hover { background: var(--hover-bg); border-color: var(--border-strong); }
    #|
    #|.table-box {
    #|  background: var(--table-bg);
    #|  border: 1px solid var(--border);
    #|  border-radius: var(--radius-lg);
    #|  overflow: auto;
    #|  max-height: calc(100vh - 110px);
    #|  box-shadow: var(--shadow-soft);
    #|  transition: background 240ms ease, border-color 240ms ease;
    #|}
    #|table {
    #|  border-collapse: collapse;
    #|  width: 100%;
    #|  min-width: 540px;
    #|  table-layout: fixed;
    #|}
    #|.table-box thead th,
    #|.md-right thead th,
    #|#csv-table thead th {
    #|  position: sticky;
    #|  top: 0;
    #|  z-index: 3;
    #|  background: var(--panel-solid) !important;
    #|  color: var(--muted);
    #|  font-size: 12px;
    #|  text-align: center;
    #|  padding: 0;
    #|  border-bottom: 1px solid var(--border);
    #|  border-right: 1px solid var(--border);
    #|  white-space: nowrap;
    #|  transition: background 200ms ease;
    #|}
    #|.table-box thead th:not(.selected),
    #|.md-right thead th:not(.selected),
    #|#csv-table thead th:not(.selected) {
    #|  background: var(--panel-solid) !important;
    #|}
    #|.md-right thead th:first-child,
    #|.md-right tbody th {
    #|  width: 28px;
    #|  min-width: 28px;
    #|  max-width: 28px;
    #|}
    #|thead th .th-inner {
    #|  display: flex;
    #|  align-items: center;
    #|  justify-content: center;
    #|  gap: 4px;
    #|  padding: 8px 6px;
    #|  position: relative;
    #|  height: 100%;
    #|}
    #|thead th.filtered .th-inner {
    #|  background: var(--accent-soft);
    #|  color: var(--accent-strong);
    #|  border-radius: 6px;
    #|  box-shadow: inset 0 -1px 0 rgba(255,255,255,0.04);
    #|}
    #|thead th.filtered .th-inner::after {
    #|  content: 'FILTER';
    #|  font-size: 10px;
    #|  color: var(--accent-strong);
    #|  background: var(--accent-soft);
    #|  border: 1px solid var(--border-strong);
    #|  padding: 1px 6px;
    #|  border-radius: var(--radius-pill);
    #|  position: absolute;
    #|  bottom: 4px;
    #|  right: 6px;
    #|}
    #|.resizer {
    #|  position: absolute;
    #|  right: 2px;
    #|  top: 0;
    #|  width: 6px;
    #|  height: 100%;
    #|  cursor: col-resize;
    #|  user-select: none;
    #|  touch-action: none;
    #|  opacity: 0.6;
    #|}
    #|.resizer::after {
    #|  content: '';
    #|  position: absolute;
    #|  top: 10%;
    #|  bottom: 10%;
    #|  left: 2px;
    #|  width: 2px;
    #|  background: var(--accent);
    #|  border-radius: 2px;
    #|  opacity: 0;
    #|  transition: opacity 120ms ease;
    #|}
    #|thead th:hover .resizer::after { opacity: 1; }
    #|
    #|.freeze {
    #|  position: sticky !important;
    #|  background: var(--panel-solid);
    #|  z-index: 4;
    #|}
    #|.freeze-row {
    #|  position: sticky !important;
    #|  background: var(--panel-solid);
    #|}
    #|.freeze-row.freeze {
    #|  z-index: 6;
    #|}
    #|th.freeze-row {
    #|  z-index: 6;
    #|}
    #|tbody th {
    #|  position: sticky;
    #|  left: 0;
    #|  z-index: 2;
    #|  background: var(--panel-solid);
    #|  color: var(--muted);
    #|  text-align: right;
    #|  padding: 8px 10px;
    #|  font-size: 12px;
    #|  border-right: 1px solid var(--border);
    #|  border-bottom: 1px solid var(--border);
    #|  transition: background 200ms ease;
    #|}
    #|td {
    #|  padding: 10px 10px;
    #|  border-bottom: 1px solid var(--border);
    #|  border-right: 1px solid var(--border);
    #|  background: var(--row-odd);
    #|  color: var(--text);
    #|  font-size: 13px;
    #|  line-height: 1.45;
    #|  cursor: pointer;
    #|  transition: background 120ms ease, box-shadow 120ms ease;
    #|  position: relative;
    #|  white-space: pre-wrap;
    #|  word-break: break-word;
    #|  max-width: 320px;
    #|}
    #|tr:nth-child(even) td:not(.selected):not(.has-comment) { background: var(--row-even); }
    #|td:hover:not(.selected) { background: var(--hover-bg); box-shadow: inset 0 0 0 1px var(--accent-soft); }
    #|td.has-comment { background: rgba(77, 157, 99, 0.12); box-shadow: inset 0 0 0 1px rgba(77, 157, 99, 0.32); }
    #|[data-theme="dark"] td.has-comment { background: rgba(107, 191, 134, 0.14); box-shadow: inset 0 0 0 1px rgba(107, 191, 134, 0.32); }
    #|td.selected, tbody th.selected { background: var(--selected-bg) !important; box-shadow: inset 0 0 0 1px var(--accent) !important; }
    #|.preview-highlight { background: var(--selected-bg) !important; box-shadow: inset 0 0 0 2px var(--accent); border-radius: 4px; transition: background 150ms ease, box-shadow 150ms ease; padding-left: 8px; margin-left: -8px; }
    #|thead th.selected { background: var(--accent-soft) !important; color: var(--accent-strong); box-shadow: inset 0 0 0 1px var(--accent); }
    #|[data-theme="dark"] thead th.selected { background: var(--accent-soft) !important; color: var(--accent-strong); }
    #|body.dragging { user-select: none; cursor: crosshair; }
    #|body.dragging td, body.dragging tbody th { cursor: crosshair; }
    #|tbody th { cursor: pointer; }
    #|td .dot {
    #|  position: absolute;
    #|  right: 6px;
    #|  top: 6px;
    #|  width: 8px;
    #|  height: 8px;
    #|  border-radius: 99px;
    #|  background: var(--badge);
    #|  box-shadow: 0 0 0 4px rgba(77, 157, 99, 0.18);
    #|}
    #|.floating {
    #|  position: fixed;
    #|  z-index: 120;
    #|  background: var(--card-bg);
    #|  border: 1px solid var(--border);
    #|  border-radius: var(--radius-lg);
    #|  padding: 16px;
    #|  width: min(440px, calc(100vw - 32px));
    #|  box-shadow: var(--shadow-card);
    #|  backdrop-filter: blur(24px);
    #|  -webkit-backdrop-filter: blur(24px);
    #|  display: none;
    #|  transition: background 240ms ease, border-color 240ms ease;
    #|}
    #|.card-close-x {
    #|  position: absolute;
    #|  top: 8px;
    #|  right: 8px;
    #|  width: 28px;
    #|  height: 28px;
    #|  padding: 0;
    #|  background: transparent;
    #|  border: none;
    #|  color: var(--muted);
    #|  font-size: 20px;
    #|  line-height: 1;
    #|  cursor: pointer;
    #|  display: flex;
    #|  align-items: center;
    #|  justify-content: center;
    #|  border-radius: 6px;
    #|  transition: background 120ms ease, color 120ms ease;
    #|}
    #|.card-close-x:hover { background: var(--border); color: var(--text);
    #|}
    #|.floating header {
    #|  position: static;
    #|  background: transparent;
    #|  backdrop-filter: none;
    #|  border: none;
    #|  padding: 0 0 8px 0;
    #|  display: flex;
    #|  justify-content: space-between;
    #|  align-items: center;
    #|}
    #|.floating h2 { font-size: 14px; font-weight: 600; margin: 0; color: var(--text); letter-spacing: -0.005em; }
    #|.floating button {
    #|  margin-left: 8px;
    #|  background: var(--accent);
    #|  color: var(--text-inverse);
    #|  border: 1px solid var(--accent);
    #|  padding: 7px 12px;
    #|  border-radius: var(--radius-sm);
    #|  font-size: 12px;
    #|  font-weight: 600;
    #|  cursor: pointer;
    #|  transition: background 160ms ease, opacity 160ms ease, transform 120ms ease;
    #|}
    #|.floating button.icon-only {
    #|  width: 32px;
    #|  height: 32px;
    #|  padding: 0;
    #|  display: inline-flex;
    #|  align-items: center;
    #|  justify-content: center;
    #|  font-size: 14px;
    #|  line-height: 1;
    #|}
    #|.floating button:hover { opacity: 0.85; }
    #|.copy-btn-float {
    #|  position: absolute;
    #|  top: 4px;
    #|  right: 4px;
    #|  z-index: 2;
    #|  background: var(--panel-solid) !important;
    #|  border: 1px solid var(--border) !important;
    #|  color: var(--muted) !important;
    #|  opacity: 0.7;
    #|}
    #|.copy-btn-float:hover { opacity: 1 !important; }
    #|.card-actions-split {
    #|  display: flex;
    #|  justify-content: space-between !important;
    #|  align-items: center;
    #|  margin-top: 8px;
    #|}
    #|.danger-text {
    #|  background: transparent !important;
    #|  border: none !important;
    #|  color: #ef4444 !important;
    #|  font-size: 12px;
    #|  font-weight: 600;
    #|  cursor: pointer;
    #|  padding: 4px 8px;
    #|}
    #|.danger-text:hover { color: #dc2626 !important; text-decoration: underline; }
    #|.floating textarea {
    #|  width: 100%;
    #|  min-height: 70px;
    #|  resize: vertical;
    #|  border-radius: 8px;
    #|  border: 1px solid var(--border);
    #|  background: var(--input-bg);
    #|  color: var(--text);
    #|  padding: 10px;
    #|  font-size: 13px;
    #|  line-height: 1.4;
    #|  transition: background 200ms ease, border-color 200ms ease;
    #|}
    #|.floating textarea:focus {
    #|  outline: none;
    #|  border-color: var(--accent);
    #|}
    #|.floating .actions {
    #|  display: flex;
    #|  gap: 8px;
    #|  justify-content: flex-end;
    #|  margin-top: 10px;
    #|}
    #|.floating .actions button.primary {
    #|  background: linear-gradient(135deg, var(--accent) 0%, var(--accent-2) 100%);
    #|  color: var(--text-inverse);
    #|  border: none;
    #|  padding: 8px 18px;
    #|  font-weight: 700;
    #|  letter-spacing: 0.01em;
    #|  box-shadow: var(--shadow-soft);
    #|}
    #|.floating .actions button.primary:hover {
    #|  background: linear-gradient(135deg, var(--accent-strong) 0%, var(--accent) 100%);
    #|  box-shadow: var(--shadow-card);
    #|}
    #|.comment-list {
    #|  position: fixed;
    #|  right: 14px;
    #|  bottom: 14px;
    #|  width: 320px;
    #|  max-height: 60vh;
    #|  overflow: auto;
    #|  border: 1px solid var(--border);
    #|  border-radius: 12px;
    #|  background: var(--card-bg);
    #|  box-shadow: 0 18px 40px var(--shadow-color);
    #|  padding: 12px;
    #|  backdrop-filter: blur(6px);
    #|  transition: opacity 120ms ease, transform 120ms ease, background 200ms ease;
    #|}
    #|.comment-list h3 { margin: 0 0 8px 0; font-size: 13px; color: var(--muted); }
    #|.comment-list ol {
    #|  margin: 0;
    #|  padding-left: 18px;
    #|  color: var(--text);
    #|  font-size: 13px;
    #|  line-height: 1.45;
    #|}
    #|.comment-list li { margin-bottom: 6px; }
    #|.comment-list .hint { color: var(--muted); font-size: 12px; }
    #|.pill { display: inline-flex; align-items: center; gap: 6px; padding: 5px 12px; border-radius: var(--radius-pill); background: var(--accent-soft); border: 1px solid transparent; font-size: 12px; font-weight: 500; color: var(--accent-strong); cursor: pointer; transition: background 160ms ease, border-color 160ms ease, transform 120ms ease; }
    #|.pill:hover { background: var(--hover-bg); border-color: var(--border-strong); transform: translateY(-1px); }
    #|.pill strong { color: var(--accent-strong); font-weight: 700; }
    #|.review-loop-sidebar {
    #|  display: flex;
    #|  flex-shrink: 0;
    #|  width: 280px;
    #|  max-width: 34%;
    #|  order: 1;
    #|  min-height: 0;
    #|}
    #|.review-loop-panel:empty { display: none; }
    #|.review-loop-panel { width: 100%; padding: 8px; border-right: 1px solid var(--border); background: var(--panel); color: var(--text); display: grid; gap: 8px; overflow-y: auto; overflow-x: hidden; scrollbar-width: thin; scrollbar-color: var(--border) transparent; transition: background 240ms ease, border-color 240ms ease; }
    #|.review-loop-details { display: grid; gap: 8px; }
    #|.review-loop-header { display: flex; align-items: center; justify-content: space-between; gap: 8px; font-size: 13px; font-weight: 600; cursor: pointer; list-style: none; }
    #|.review-loop-header::-webkit-details-marker { display: none; }
    #|.review-loop-badge { min-width: 24px; height: 22px; padding: 0 7px; border: 1px solid var(--border); border-radius: var(--radius-pill); display: inline-flex; align-items: center; justify-content: center; color: var(--accent-strong); background: var(--accent-soft); font-size: 12px; font-weight: 700; }
    #|.review-loop-meta { color: var(--muted); font-weight: 500; font-size: 12px; }
    #|.review-loop-ready { border: 1px solid var(--border); border-radius: var(--radius-sm); background: var(--accent-soft); color: var(--accent-strong); padding: 6px 8px; font-size: 12px; font-weight: 600; }
    #|.review-loop-body { display: grid; gap: 10px; }
    #|.review-loop-list { margin: 0; padding-left: 0; list-style: none; display: grid; gap: 8px; color: var(--text); font-size: 13px; line-height: 1.45; }
    #|.review-loop-comment { border: 1px solid var(--border); border-radius: var(--radius-sm); padding: 8px; display: grid; gap: 7px; background: var(--bg); }
    #|.review-loop-comment-head { display: flex; flex-wrap: wrap; gap: 5px; color: var(--muted); font-size: 12px; }
    #|.review-loop-comment-text { font-weight: 600; }
    #|.review-loop-actions { display: flex; justify-content: flex-end; }
    #|.review-loop-resolved { color: var(--muted); font-size: 12px; }
    #|.review-loop-resolve { padding: 4px 8px; font-size: 12px; border-radius: var(--radius-sm); border: 1px solid var(--border); background: var(--button-bg); color: var(--text); cursor: pointer; transition: background 160ms ease, border-color 160ms ease; }
    #|.review-loop-resolve:hover { background: var(--hover-bg); border-color: var(--border-strong); }
    #|.review-loop-replies { margin: 5px 0 0; padding-left: 14px; color: var(--muted); }
    #|.review-loop-snippet { border: 1px solid var(--border); border-radius: var(--radius-sm); display: grid; gap: 4px; padding: 6px; background: var(--panel); }
    #|.review-loop-snippet-label, .review-loop-diff-label { color: var(--muted); font-size: 12px; font-weight: 600; }
    #|.review-loop-snip-row { display: grid; grid-template-columns: 48px minmax(0, 1fr); gap: 6px; align-items: start; font-size: 12px; }
    #|.review-loop-snip-row span { color: var(--muted); }
    #|.review-loop-snip-row code { min-width: 0; white-space: pre-wrap; overflow-wrap: anywhere; color: var(--text); }
    #|.review-loop-diff-block { display: grid; gap: 5px; }
    #|.review-loop-diff { margin: 0; max-height: 220px; overflow: auto; border: 1px solid var(--border); border-radius: var(--radius-sm); background: var(--bg); padding: 0; white-space: pre-wrap; }
    #|.review-loop-submit-state { display: none; margin: 0 0 10px; padding: 7px 9px; border: 1px solid var(--border); border-radius: var(--radius-sm); background: var(--panel); color: var(--text); font-size: 13px; font-weight: 600; }
    #|.comment-list.collapsed {
    #|  opacity: 0;
    #|  pointer-events: none;
    #|  transform: translateY(8px) scale(0.98);
    #|}
    #|.md-preview {
    #|  background: var(--panel);
    #|  border: 1px solid var(--border);
    #|  border-radius: var(--radius-lg);
    #|  padding: 20px 24px;
    #|  margin-bottom: 12px;
    #|  box-shadow: var(--shadow-soft);
    #|  line-height: 1.65;
    #|  transition: background 240ms ease, border-color 240ms ease;
    #|}
    #|.md-layout {
    #|  display: flex;
    #|  gap: 16px;
    #|  align-items: stretch;
    #|  margin-top: 8px;
    #|  flex: 1;
    #|  min-height: 0;
    #|}
    #|/* Panel order: review loop (left) | preview | source | media thumbs (right) */
    #|.md-layout > .md-left { order: 2; }
    #|.md-layout > .md-right { order: 3; }
    #|.md-layout > .media-sidebar { order: 4; }
    #|.md-left {
    #|  flex: 1;
    #|  min-width: 200px;
    #|  overflow-y: auto;
    #|  overflow-x: auto;
    #|  overscroll-behavior: contain;
    #|}
    #|.md-left .md-preview {
    #|  max-height: none;
    #|}
    #|.md-right {
    #|  flex: 1;
    #|  min-width: 0;
    #|  overflow-y: auto;
    #|  overflow-x: auto;
    #|  overscroll-behavior: contain;
    #|}
    #|.md-right .table-box {
    #|  max-width: none;
    #|  min-width: 0;
    #|  max-height: none;
    #|  overflow: visible;
    #|}
    #|/* Ensure thead is opaque in md-right to prevent content showing through */
    #|.md-right thead th {
    #|  background: var(--panel-solid) !important;
    #|}
    #|.md-right thead th.selected {
    #|  background: var(--accent-soft) !important;
    #|  color: var(--accent-strong);
    #|}
    #|[data-theme="dark"] .md-right thead th {
    #|  background: var(--panel-solid) !important;
    #|}
    #|[data-theme="dark"] .md-right thead th.selected {
    #|  background: var(--accent-soft) !important;
    #|  color: var(--accent-strong);
    #|}
    #|
    #|/* === Media Sidebar === */
    #|.media-sidebar {
    #|  display: flex;
    #|  flex-shrink: 0;
    #|  height: auto;
    #|  transition: width 0.3s cubic-bezier(0.4, 0, 0.2, 1);
    #|  position: relative;
    #|  z-index: 10;
    #|  max-width: 60%;
    #|}
    #|.media-sidebar.hidden {
    #|  display: none;
    #|}
    #|.media-sidebar-thumbs {
    #|  width: 96px;
    #|  overflow-y: auto;
    #|  overflow-x: hidden;
    #|  padding: 8px;
    #|  border-left: 1px solid var(--border);
    #|  display: flex;
    #|  flex-direction: column;
    #|  gap: 8px;
    #|  background: var(--panel);
    #|  scrollbar-width: thin;
    #|  scrollbar-color: var(--border) transparent;
    #|}
    #|.media-sidebar-thumbs::-webkit-scrollbar {
    #|  width: 4px;
    #|}
    #|.media-sidebar-thumbs::-webkit-scrollbar-track {
    #|  background: transparent;
    #|}
    #|.media-sidebar-thumbs::-webkit-scrollbar-thumb {
    #|  background: var(--border);
    #|  border-radius: 4px;
    #|}
    #|.media-sidebar-thumb {
    #|  width: 80px;
    #|  height: 60px;
    #|  border-radius: 6px;
    #|  border: 2px solid var(--border);
    #|  overflow: hidden;
    #|  cursor: pointer;
    #|  position: relative;
    #|  flex-shrink: 0;
    #|  background: var(--bg);
    #|  transition: border-color 0.2s ease, transform 0.15s ease, box-shadow 0.2s ease;
    #|}
    #|.media-sidebar-thumb:hover {
    #|  border-color: var(--accent);
    #|  transform: scale(1.05);
    #|  box-shadow: 0 2px 8px var(--shadow-color);
    #|}
    #|.media-sidebar-thumb.active {
    #|  border-color: var(--accent);
    #|  box-shadow: 0 0 0 2px var(--accent), 0 2px 8px var(--shadow-color);
    #|}
    #|.media-sidebar-thumb img {
    #|  width: 100%;
    #|  height: 100%;
    #|  object-fit: cover;
    #|  display: block;
    #|}
    #|.media-sidebar-thumb svg {
    #|  width: 100%;
    #|  height: 100%;
    #|  display: block;
    #|}
    #|.media-sidebar-thumb-video {
    #|  position: relative;
    #|  width: 100%;
    #|  height: 100%;
    #|  display: flex;
    #|  align-items: center;
    #|  justify-content: center;
    #|  background: #000;
    #|}
    #|.media-sidebar-thumb-video video {
    #|  width: 100%;
    #|  height: 100%;
    #|  object-fit: cover;
    #|}
    #|.media-sidebar-thumb-video::after {
    #|  content: '';
    #|  position: absolute;
    #|  width: 24px;
    #|  height: 24px;
    #|  background: rgba(255,255,255,0.85);
    #|  border-radius: 50%;
    #|  display: flex;
    #|  align-items: center;
    #|  justify-content: center;
    #|}
    #|.media-sidebar-thumb-video::before {
    #|  content: '';
    #|  position: absolute;
    #|  z-index: 1;
    #|  width: 0;
    #|  height: 0;
    #|  border-style: solid;
    #|  border-width: 5px 0 5px 9px;
    #|  border-color: transparent transparent transparent #000;
    #|  margin-left: 2px;
    #|}
    #|.media-sidebar-thumb-mermaid {
    #|  display: flex;
    #|  align-items: center;
    #|  justify-content: center;
    #|  width: 100%;
    #|  height: 100%;
    #|  padding: 2px;
    #|  background: var(--panel);
    #|  overflow: hidden;
    #|}
    #|.media-sidebar-thumb-mermaid svg {
    #|  width: 100% !important;
    #|  height: 100% !important;
    #|  max-width: 100%;
    #|  max-height: 100%;
    #|  display: block;
    #|}
    #|.media-sidebar-thumb-index {
    #|  position: absolute;
    #|  top: 2px;
    #|  left: 2px;
    #|  background: rgba(0,0,0,0.6);
    #|  color: #fff;
    #|  font-size: 9px;
    #|  font-weight: 600;
    #|  padding: 1px 4px;
    #|  border-radius: 3px;
    #|  line-height: 1.2;
    #|  pointer-events: none;
    #|  z-index: 1;
    #|}
    #|/* Highlight ring flashed on the preview media when navigating via sidebar thumbs */
    #|.media-nav-highlight {
    #|  outline: 3px solid var(--accent);
    #|  outline-offset: 4px;
    #|  border-radius: 4px;
    #|  animation: media-nav-flash 1.6s ease;
    #|}
    #|@keyframes media-nav-flash {
    #|  0% { box-shadow: 0 0 0 10px var(--accent-soft); }
    #|  100% { box-shadow: 0 0 0 0 rgba(0, 0, 0, 0); }
    #|}
    #|
    #|.media-sidebar-toggle {
    #|  background: transparent;
    #|  border: 1px solid transparent;
    #|  border-radius: var(--radius-sm);
    #|  padding: 0 10px;
    #|  height: 34px;
    #|  min-width: 34px;
    #|  cursor: pointer;
    #|  color: var(--text);
    #|  font-size: 14px;
    #|  transition: background 160ms ease, border-color 160ms ease;
    #|  display: none;
    #|  align-items: center;
    #|  justify-content: center;
    #|  gap: 6px;
    #|}
    #|.media-sidebar-toggle.has-media {
    #|  display: inline-flex;
    #|}
    #|.media-sidebar-toggle:hover {
    #|  background: var(--hover-bg);
    #|  border-color: var(--border);
    #|}
    #|.media-sidebar-toggle .toggle-count {
    #|  font-size: 10px;
    #|  font-weight: 700;
    #|  background: var(--accent);
    #|  color: var(--text-inverse);
    #|  padding: 1px 6px;
    #|  border-radius: var(--radius-pill);
    #|  line-height: 1.4;
    #|}
    #|/* Header action buttons are icon-only (SVG, currentColor) with title tooltips */
    #|header .actions button svg {
    #|  width: 16px;
    #|  height: 16px;
    #|  display: block;
    #|  flex-shrink: 0;
    #|}
    #|header .actions #theme-icon { display: inline-flex; }
    #|.view-toggle {
    #|  background: transparent;
    #|  border: 1px solid transparent;
    #|  border-radius: var(--radius-sm);
    #|  padding: 0 10px;
    #|  gap: 6px;
    #|  height: 34px;
    #|  min-width: 34px;
    #|  cursor: pointer;
    #|  color: var(--text);
    #|  font-size: 14px;
    #|  transition: background 160ms ease, border-color 160ms ease, color 160ms ease;
    #|  display: inline-flex;
    #|  align-items: center;
    #|  justify-content: center;
    #|}
    #|.view-toggle:hover { background: var(--hover-bg); border-color: var(--border); }
    #|.view-toggle.active { background: var(--accent-soft); color: var(--accent-strong); border-color: transparent; }
    #|@media (max-width: 900px) {
    #|  .media-sidebar-thumbs {
    #|    width: 72px;
    #|  }
    #|  .media-sidebar-thumb {
    #|    width: 56px;
    #|    height: 42px;
    #|  }
    #|}
    #|@media (prefers-reduced-motion: reduce) {
    #|  .media-sidebar,
    #|  .media-sidebar-thumb {
    #|    transition: none !important;
    #|  }
    #|}
    #|
    #|.md-preview h1, .md-preview h2, .md-preview h3, .md-preview h4 {
    #|  margin: 0.4em 0 0.2em;
    #|}
    #|/* Heading toggle feature */
    #|.md-preview .md-heading-toggle {
    #|  margin: 0;
    #|}
    #|.md-preview .heading-toggle-icon {
    #|  display: inline-flex;
    #|  align-items: center;
    #|  justify-content: center;
    #|  font-size: 0.6em;
    #|  transition: transform 150ms ease;
    #|  color: var(--muted);
    #|  flex-shrink: 0;
    #|  cursor: pointer;
    #|  padding: 4px 8px;
    #|  margin: -4px 0 -4px -8px;
    #|  border-radius: 4px;
    #|}
    #|.md-preview .heading-toggle-icon:hover {
    #|  background: var(--hover-bg);
    #|  color: var(--accent);
    #|}
    #|.md-preview .md-heading-toggle.collapsed .heading-toggle-icon {
    #|  transform: rotate(-90deg);
    #|}
    #|.md-preview details.heading-toggle {
    #|  margin: 0.2em 0;
    #|}
    #|.md-preview details.heading-toggle > summary {
    #|  list-style: none;
    #|  cursor: default;
    #|  display: flex;
    #|  align-items: center;
    #|  gap: 6px;
    #|}
    #|.md-preview details.heading-toggle > summary::-webkit-details-marker {
    #|  display: none;
    #|}
    #|.md-preview details.heading-toggle > summary > .md-heading-toggle {
    #|  flex: 1;
    #|}
    #|.md-preview details.heading-toggle:not([open]) > .toggle-content {
    #|  display: none;
    #|}
    #|.md-preview .heading-section-content {
    #|  /* Content wrapper for collapsible sections */
    #|}
    #|.md-preview .heading-section-content.hidden {
    #|  display: none;
    #|}
    #|.md-preview p { margin: 0.3em 0; line-height: 1.5; }
    #|.md-preview .task-list-item { list-style: none; margin-left: -1.2em; }
    #|.md-preview .task-list-item input[type="checkbox"] { margin-right: 0.45em; accent-color: var(--accent); cursor: pointer; }
    #|.md-preview .decision-done { color: var(--accent-strong); background: var(--accent-soft); border-left: 3px solid var(--accent); padding: 2px 8px; border-radius: var(--radius-sm); }
    #|.md-preview a { color: var(--accent); text-decoration: underline; text-underline-offset: 2px; text-decoration-color: var(--accent-soft); }
    #|.md-preview a:hover { color: var(--accent-strong); text-decoration-color: var(--accent-strong); }
    #|.md-preview a:visited { color: var(--accent-2); }
    #|.md-preview img { max-width: 100%; height: auto; border-radius: 8px; }
    #|.md-preview video.video-preview { max-width: 100%; height: auto; border-radius: 8px; background: #000; }
    #|.md-preview table video.video-preview {
    #|  display: block;
    #|  width: 100%;
    #|  height: auto;
    #|}
    #|.md-preview code { background: rgba(255,255,255,0.08); padding: 2px 4px; border-radius: 4px; }
    #|.md-preview pre {
    #|  background: var(--code-bg);
    #|  padding: 12px 16px;
    #|  border-radius: 8px;
    #|  overflow: auto;
    #|  border: 1px solid var(--border);
    #|}
    #|.md-preview pre code {
    #|  background: none;
    #|  padding: 0;
    #|  font-size: 13px;
    #|  line-height: 1.5;
    #|}
    #|.md-preview pre code.hljs {
    #|  background: transparent;
    #|  padding: 0;
    #|}
    #|/* YAML Frontmatter table */
    #|.frontmatter-table {
    #|  margin-bottom: 20px;
    #|  border-radius: 8px;
    #|  overflow: hidden;
    #|  border: 1px solid var(--border);
    #|  background: var(--panel);
    #|}
    #|.frontmatter-table table {
    #|  width: 100%;
    #|  border-collapse: collapse;
    #|  table-layout: fixed;
    #|}
    #|.frontmatter-table thead th {
    #|  background: linear-gradient(135deg, rgba(92, 138, 66, 0.15), rgba(159, 196, 124, 0.15));
    #|  color: var(--text);
    #|  font-size: 12px;
    #|  font-weight: 600;
    #|  padding: 10px 16px;
    #|  text-align: left;
    #|  border-bottom: 1px solid var(--border);
    #|}
    #|.frontmatter-table tbody th {
    #|  background: var(--accent-soft);
    #|  color: var(--accent);
    #|  font-weight: 500;
    #|  font-size: 12px;
    #|  padding: 8px 10px;
    #|  text-align: left;
    #|  border-bottom: 1px solid var(--border);
    #|  vertical-align: top;
    #|}
    #|.frontmatter-table tbody td {
    #|  padding: 8px 14px;
    #|  font-size: 13px;
    #|  border-bottom: 1px solid var(--border);
    #|  word-break: break-word;
    #|}
    #|.frontmatter-table tbody tr:last-child th,
    #|.frontmatter-table tbody tr:last-child td {
    #|  border-bottom: none;
    #|}
    #|.frontmatter-table .fm-tag {
    #|  display: inline-block;
    #|  background: var(--accent-soft);
    #|  color: var(--accent);
    #|  padding: 2px 8px;
    #|  border-radius: 12px;
    #|  font-size: 11px;
    #|  margin-right: 4px;
    #|  margin-bottom: 4px;
    #|}
    #|.frontmatter-table pre {
    #|  margin: 0;
    #|  background: var(--code-bg);
    #|  padding: 8px;
    #|  border-radius: 4px;
    #|  font-size: 11px;
    #|}
    #|/* Yunomi questions preview cards */
    #|.yunomi-questions-preview {
    #|  display: flex;
    #|  flex-direction: column;
    #|  gap: 8px;
    #|}
    #|.yunomi-q-card {
    #|  background: var(--code-bg);
    #|  border: 1px solid var(--border);
    #|  border-radius: 8px;
    #|  padding: 10px 12px;
    #|}
    #|.yunomi-q-card.resolved {
    #|  border-left: 3px solid #22c55e;
    #|}
    #|.yunomi-q-card.pending {
    #|  border-left: 3px solid #f59e0b;
    #|}
    #|.yunomi-q-header {
    #|  font-size: 12px;
    #|  color: var(--text-dim);
    #|  margin-bottom: 4px;
    #|}
    #|.yunomi-q-header strong {
    #|  color: var(--accent);
    #|}
    #|.yunomi-q-question {
    #|  font-size: 13px;
    #|  color: var(--text);
    #|  margin-bottom: 6px;
    #|}
    #|.yunomi-q-options {
    #|  display: flex;
    #|  flex-wrap: wrap;
    #|  gap: 4px;
    #|  margin-bottom: 6px;
    #|}
    #|.yunomi-q-answer {
    #|  font-size: 12px;
    #|  color: #22c55e;
    #|  background: rgba(34, 197, 94, 0.1);
    #|  padding: 4px 8px;
    #|  border-radius: 4px;
    #|}
    #|/* Table scroll container and indicator */
    #|.table-scroll-container {
    #|  position: relative;
    #|  margin: 16px 0;
    #|}
    #|.table-scroll-wrapper {
    #|  overflow-x: auto;
    #|  border-radius: 8px;
    #|}
    #|.scroll-hint {
    #|  text-align: right;
    #|  font-size: 12px;
    #|  color: var(--accent);
    #|  padding: 4px 8px;
    #|  margin-bottom: 4px;
    #|  opacity: 0;
    #|  visibility: hidden;
    #|  transition: opacity 200ms ease;
    #|}
    #|.table-scroll-container.can-scroll .scroll-hint {
    #|  opacity: 0.8;
    #|  visibility: visible;
    #|}
    #|.table-scroll-container.scrolled-end .scroll-hint {
    #|  opacity: 0;
    #|  visibility: hidden;
    #|}
    #|/* Markdown tables in preview — blends with md-preview panel */
    #|.md-preview table:not(.frontmatter-table table) {
    #|  min-width: 100%;
    #|  width: max-content;
    #|  border-collapse: collapse;
    #|  border: none;
    #|  background: transparent;
    #|  margin: 12px 0 16px;
    #|}
    #|.md-preview table:not(.frontmatter-table table) th,
    #|.md-preview table:not(.frontmatter-table table) td {
    #|  padding: 10px 16px;
    #|  text-align: left;
    #|  border-bottom: 1px solid var(--border);
    #|  vertical-align: top;
    #|  word-break: break-word;
    #|  overflow-wrap: anywhere;
    #|  width: auto;
    #|}
    #|/* Force equal column widths when colgroup is not specified */
    #|.md-preview table:not(.frontmatter-table table) colgroup ~ * th,
    #|.md-preview table:not(.frontmatter-table table) colgroup ~ * td {
    #|  width: auto;
    #|}
    #|.md-preview table:not(.frontmatter-table table) td:has(video),
    #|.md-preview table:not(.frontmatter-table table) td:has(img) {
    #|  padding: 4px;
    #|  line-height: 0;
    #|}
    #|.md-preview table:not(.frontmatter-table table) td video,
    #|.md-preview table:not(.frontmatter-table table) td img {
    #|  width: 100%;
    #|  max-width: 100%;
    #|  height: auto;
    #|}
    #|.md-preview table:not(.frontmatter-table table) thead th {
    #|  background: transparent;
    #|  color: var(--accent-strong);
    #|  font-weight: 700;
    #|  font-size: 11px;
    #|  letter-spacing: 0.06em;
    #|  text-transform: uppercase;
    #|  border-bottom: 2px solid var(--accent);
    #|  padding-top: 8px;
    #|  padding-bottom: 10px;
    #|}
    #|.md-preview table:not(.frontmatter-table table) tbody td {
    #|  font-size: 13px;
    #|  color: var(--text);
    #|}
    #|.md-preview table:not(.frontmatter-table table) tr:last-child td {
    #|  border-bottom: none;
    #|}
    #|.md-preview table:not(.frontmatter-table table) tbody tr:hover td {
    #|  background: var(--hover-bg);
    #|}
    #|/* Source table (右ペイン) */
    #|.table-box table {
    #|  table-layout: fixed;
    #|  width: 100%;
    #|}
    #|.table-box th,
    #|.table-box td {
    #|  word-break: break-word;
    #|  min-width: 140px;
    #|}
    #|.table-box th:first-child,
    #|.table-box td:first-child {
    #|  min-width: 320px;
    #|  max-width: 480px;
    #|}
    #|/* Image fullscreen overlay */
    #|.image-fullscreen-overlay {
    #|  position: fixed;
    #|  inset: 0;
    #|  background: var(--bg);
    #|  z-index: 1001;
    #|  display: none;
    #|  flex-direction: column;
    #|}
    #|.image-fullscreen-overlay.visible {
    #|  display: flex;
    #|}
    #|.image-fs-content {
    #|  flex: 1;
    #|  overflow: hidden;
    #|  position: relative;
    #|  cursor: grab;
    #|  touch-action: none;
    #|}
    #|.image-fs-content:active { cursor: grabbing; }
    #|.image-fs-content .image-fs-wrapper {
    #|  position: absolute;
    #|  transform-origin: 0 0;
    #|}
    #|.image-fs-content .image-fs-wrapper img {
    #|  display: block;
    #|}
    #|/* Video fullscreen overlay */
    #|.video-fullscreen-overlay {
    #|  position: fixed;
    #|  inset: 0;
    #|  background: rgba(0, 0, 0, 0.95);
    #|  z-index: 1001;
    #|  display: none;
    #|  justify-content: center;
    #|  align-items: center;
    #|}
    #|.video-fullscreen-overlay.visible {
    #|  display: flex;
    #|}
    #|.video-close-btn {
    #|  position: absolute;
    #|  top: 14px;
    #|  right: 14px;
    #|  width: 40px;
    #|  height: 40px;
    #|  display: flex;
    #|  align-items: center;
    #|  justify-content: center;
    #|  background: rgba(0, 0, 0, 0.55);
    #|  border: 1px solid rgba(255, 255, 255, 0.25);
    #|  border-radius: 50%;
    #|  cursor: pointer;
    #|  color: #fff;
    #|  font-size: 18px;
    #|  z-index: 10;
    #|  backdrop-filter: blur(4px);
    #|  transition: background 120ms ease, transform 120ms ease;
    #|}
    #|.video-close-btn:hover {
    #|  background: rgba(0, 0, 0, 0.75);
    #|  transform: scale(1.04);
    #|}
    #|.video-container {
    #|  width: 90vw;
    #|  height: 90vh;
    #|  display: flex;
    #|  justify-content: center;
    #|  align-items: center;
    #|}
    #|.video-container video {
    #|  width: 100%;
    #|  height: 100%;
    #|  object-fit: contain;
    #|  border-radius: 8px;
    #|  box-shadow: 0 20px 60px rgba(0, 0, 0, 0.5);
    #|}
    #|/* Video Timeline - shared base styles (used by both fullscreen and sidebar) */
    #|.video-timeline {
    #|  background: rgba(0, 0, 0, 0.85);
    #|  display: flex;
    #|  overflow-x: auto;
    #|  backdrop-filter: blur(8px);
    #|  height: 80px;
    #|  padding: 8px;
    #|  gap: 4px;
    #|}
    #|.video-timeline::-webkit-scrollbar {
    #|  height: 6px;
    #|}
    #|.video-timeline::-webkit-scrollbar-track {
    #|  background: rgba(255, 255, 255, 0.1);
    #|  border-radius: 3px;
    #|}
    #|.video-timeline::-webkit-scrollbar-thumb {
    #|  background: rgba(255, 255, 255, 0.3);
    #|  border-radius: 3px;
    #|}
    #|.video-timeline::-webkit-scrollbar-thumb:hover {
    #|  background: rgba(255, 255, 255, 0.5);
    #|}
    #|/* Fullscreen-specific video timeline positioning */
    #|.video-container .video-timeline {
    #|  position: absolute;
    #|  bottom: 0;
    #|  left: 0;
    #|  right: 0;
    #|  z-index: 5;
    #|}
    #|.timeline-thumb {
    #|  height: 64px;
    #|  cursor: pointer;
    #|  border: 2px solid transparent;
    #|  border-radius: 4px;
    #|  flex-shrink: 0;
    #|  transition: border-color 0.2s, transform 0.15s;
    #|  opacity: 0.85;
    #|}
    #|.timeline-thumb:hover {
    #|  border-color: rgba(159, 196, 124, 0.5);
    #|  opacity: 1;
    #|  transform: scale(1.05);
    #|}
    #|.timeline-thumb.active {
    #|  border-color: var(--accent);
    #|  opacity: 1;
    #|  box-shadow: 0 0 12px rgba(159, 196, 124, 0.5);
    #|}
    #|.timeline-loading {
    #|  color: rgba(255, 255, 255, 0.6);
    #|  font-size: 12px;
    #|  padding: 8px 12px;
    #|  display: flex;
    #|  align-items: center;
    #|  gap: 8px;
    #|}
    #|.timeline-loading::before {
    #|  content: '';
    #|  width: 14px;
    #|  height: 14px;
    #|  border: 2px solid rgba(255, 255, 255, 0.3);
    #|  border-top-color: var(--accent);
    #|  border-radius: 50%;
    #|  animation: timeline-spin 0.8s linear infinite;
    #|}
    #|@keyframes timeline-spin {
    #|  to { transform: rotate(360deg); }
    #|}
    #|.timeline-time {
    #|  position: absolute;
    #|  bottom: 2px;
    #|  right: 4px;
    #|  font-size: 9px;
    #|  color: #fff;
    #|  background: rgba(0, 0, 0, 0.7);
    #|  padding: 1px 4px;
    #|  border-radius: 2px;
    #|  pointer-events: none;
    #|}
    #|.timeline-thumb-wrapper {
    #|  position: relative;
    #|  flex-shrink: 0;
    #|}
    #|/* Video threshold settings panel */
    #|.video-settings-btn {
    #|  position: absolute;
    #|  top: 14px;
    #|  right: 64px;
    #|  width: 40px;
    #|  height: 40px;
    #|  display: flex;
    #|  align-items: center;
    #|  justify-content: center;
    #|  background: rgba(0, 0, 0, 0.55);
    #|  border: 1px solid rgba(255, 255, 255, 0.25);
    #|  border-radius: 50%;
    #|  cursor: pointer;
    #|  color: #fff;
    #|  font-size: 18px;
    #|  z-index: 10;
    #|  backdrop-filter: blur(4px);
    #|  transition: background 120ms ease, transform 120ms ease;
    #|}
    #|.video-settings-btn:hover {
    #|  background: rgba(0, 0, 0, 0.75);
    #|  transform: scale(1.04);
    #|}
    #|.video-settings-panel {
    #|  position: absolute;
    #|  top: 60px;
    #|  right: 14px;
    #|  background: rgba(0, 0, 0, 0.9);
    #|  border: 1px solid rgba(255, 255, 255, 0.2);
    #|  border-radius: 12px;
    #|  padding: 16px;
    #|  z-index: 15;
    #|  min-width: 280px;
    #|  display: none;
    #|  backdrop-filter: blur(8px);
    #|}
    #|.video-settings-panel.visible {
    #|  display: block;
    #|}
    #|.video-settings-panel h4 {
    #|  margin: 0 0 8px;
    #|  color: #fff;
    #|  font-size: 14px;
    #|  font-weight: 500;
    #|}
    #|.video-settings-desc {
    #|  margin: 0 0 12px;
    #|  color: rgba(255, 255, 255, 0.6);
    #|  font-size: 11px;
    #|  line-height: 1.4;
    #|}
    #|.video-settings-buttons {
    #|  display: flex;
    #|  gap: 6px;
    #|  margin-bottom: 12px;
    #|}
    #|.video-settings-buttons button {
    #|  flex: 1;
    #|  padding: 8px 4px;
    #|  border: 1px solid rgba(255, 255, 255, 0.2);
    #|  border-radius: 6px;
    #|  background: rgba(255, 255, 255, 0.1);
    #|  color: rgba(255, 255, 255, 0.8);
    #|  font-size: 11px;
    #|  cursor: pointer;
    #|  transition: all 120ms ease;
    #|}
    #|.video-settings-buttons button:hover {
    #|  background: rgba(255, 255, 255, 0.2);
    #|  border-color: rgba(255, 255, 255, 0.3);
    #|}
    #|.video-settings-buttons button.selected {
    #|  background: #5c8a42;
    #|  border-color: #5c8a42;
    #|  color: #fff;
    #|}
    #|.video-settings-actions {
    #|  display: flex;
    #|  gap: 8px;
    #|  margin-top: 8px;
    #|}
    #|.video-settings-actions button {
    #|  flex: 1;
    #|  padding: 8px 12px;
    #|  border: none;
    #|  border-radius: 6px;
    #|  font-size: 12px;
    #|  cursor: pointer;
    #|  transition: background 120ms ease;
    #|}
    #|.video-settings-actions .reset-btn {
    #|  background: rgba(255, 255, 255, 0.15);
    #|  color: #fff;
    #|}
    #|.video-settings-actions .reset-btn:hover {
    #|  background: rgba(255, 255, 255, 0.25);
    #|}
    #|/* Video Shortcuts Help */
    #|.video-shortcuts-help {
    #|  opacity: 0.85;
    #|  transition: opacity 0.2s;
    #|}
    #|.video-shortcuts-help:hover {
    #|  opacity: 1;
    #|}
    #|.video-shortcuts-help .shortcuts-title {
    #|  font-weight: 600;
    #|  font-size: 11px;
    #|  text-transform: uppercase;
    #|  letter-spacing: 0.5px;
    #|  margin-bottom: 10px;
    #|  color: rgba(255, 255, 255, 0.7);
    #|  display: flex;
    #|  align-items: center;
    #|  gap: 6px;
    #|}
    #|.video-shortcuts-help .shortcuts-title::before {
    #|  content: '\u2328';
    #|  font-size: 14px;
    #|}
    #|.video-shortcuts-help .shortcut-item {
    #|  margin-bottom: 6px;
    #|  display: flex;
    #|  align-items: center;
    #|  gap: 4px;
    #|  flex-wrap: wrap;
    #|}
    #|.video-shortcuts-help .shortcut-item:last-child {
    #|  margin-bottom: 0;
    #|}
    #|.video-shortcuts-help kbd {
    #|  display: inline-block;
    #|  background: rgba(255, 255, 255, 0.15);
    #|  border: 1px solid rgba(255, 255, 255, 0.25);
    #|  border-radius: 4px;
    #|  padding: 2px 6px;
    #|  font-family: system-ui, -apple-system, sans-serif;
    #|  font-size: 10px;
    #|  font-weight: 500;
    #|  min-width: 18px;
    #|  text-align: center;
    #|  margin-right: 2px;
    #|}
    #|/* Yunomi Questions Modal — one-question-per-screen stepper (mirrors
    #| * Claude Code's AskUserQuestion: answer, advance, never a tall
    #| * scrolling stack of every question at once). No emoji, no internal
    #| * question ID ever rendered as text. */
    #|.yunomi-questions-overlay {
    #|  display: none;
    #|  position: fixed;
    #|  inset: 0;
    #|  background: rgba(0, 0, 0, 0.55);
    #|  z-index: 1100;
    #|  justify-content: center;
    #|  align-items: center;
    #|  padding: 16px;
    #|}
    #|.yunomi-questions-overlay.visible {
    #|  display: flex;
    #|}
    #|.yunomi-questions-modal {
    #|  background: var(--card-bg);
    #|  border: 1px solid var(--border);
    #|  border-radius: 16px;
    #|  width: 100%;
    #|  max-width: 560px;
    #|  /* Long context text (fail-open/design-rationale explanations etc.)
    #|   * must fit without an internal scrollbar blocking Next/Complete —
    #|   * a fixed small cap here ("no way to proceed without scrolling
    #|   * first") is exactly what the human called out twice. Give the
    #|   * modal nearly the full viewport height; .yunomi-questions-body's
    #|   * own overflow-y: auto stays only as a last-resort safety net for
    #|   * pathological cases (tiny viewport + extremely long context). */
    #|  max-height: 90vh;
    #|  display: flex;
    #|  flex-direction: column;
    #|  box-shadow: 0 25px 80px rgba(0, 0, 0, 0.5);
    #|  overflow: hidden;
    #|}
    #|.yunomi-questions-header {
    #|  display: flex;
    #|  justify-content: space-between;
    #|  align-items: center;
    #|  padding: 12px 16px;
    #|  border-bottom: 1px solid var(--border);
    #|  flex-shrink: 0;
    #|}
    #|.yunomi-questions-progress {
    #|  font-size: 12px;
    #|  font-weight: 600;
    #|  color: var(--text-dim);
    #|  font-variant-numeric: tabular-nums;
    #|}
    #|.yunomi-questions-close {
    #|  width: 28px;
    #|  height: 28px;
    #|  border: none;
    #|  background: transparent;
    #|  color: var(--text-dim);
    #|  font-size: 18px;
    #|  line-height: 1;
    #|  cursor: pointer;
    #|  border-radius: 8px;
    #|  transition: all 150ms ease;
    #|}
    #|.yunomi-questions-close:hover {
    #|  background: var(--border);
    #|  color: var(--text);
    #|}
    #|.yunomi-questions-body {
    #|  flex: 1;
    #|  overflow-y: auto;
    #|  padding: 16px;
    #|  min-height: 0;
    #|}
    #|/* Only the active step's card is shown — the rest stay in the DOM
    #| * (unchanged) so collect_yunomi_answers()/persist_draft() keep working
    #| * across every question, not just the visible one. */
    #|.yunomi-questions-stepper .question-card {
    #|  display: none;
    #|}
    #|.yunomi-questions-stepper .question-card.step-active {
    #|  display: block;
    #|}
    #|/* Answer-summary confirmation screen (task #21) — the stepper's
    #| * virtual "last step + 1", shown instead of closing outright when
    #| * "完了" is clicked on the final question. app.mbt toggles
    #| * .summary-active on the body to swap the stepper/resolved-section for
    #| * this recap, so the human sees every answer before committing instead
    #| * of the dialog just vanishing with no feedback. */
    #|.yunomi-questions-summary {
    #|  display: none;
    #|}
    #|.yunomi-questions-body.summary-active .yunomi-questions-stepper,
    #|.yunomi-questions-body.summary-active .yunomi-resolved-section {
    #|  display: none;
    #|}
    #|.yunomi-questions-body.summary-active .yunomi-questions-summary {
    #|  display: block;
    #|}
    #|.q-summary-item {
    #|  display: block;
    #|  width: 100%;
    #|  text-align: left;
    #|  background: var(--input-bg);
    #|  border: 1px solid var(--border);
    #|  border-radius: 8px;
    #|  padding: 10px 12px;
    #|  margin-bottom: 8px;
    #|  cursor: pointer;
    #|  font-family: inherit;
    #|  transition: border-color 150ms ease, background 150ms ease;
    #|}
    #|.q-summary-item:last-child {
    #|  margin-bottom: 0;
    #|}
    #|.q-summary-item:hover {
    #|  border-color: var(--accent);
    #|  background: var(--accent-soft);
    #|}
    #|.q-summary-title {
    #|  font-size: 13px;
    #|  font-weight: 600;
    #|  color: var(--text);
    #|  margin-bottom: 4px;
    #|}
    #|.q-summary-answer {
    #|  font-size: 12px;
    #|  color: var(--text-dim);
    #|  white-space: pre-wrap;
    #|  overflow-wrap: anywhere;
    #|}
    #|.question-card .q-title {
    #|  font-size: 15px;
    #|  font-weight: 600;
    #|  color: var(--text);
    #|  line-height: 1.5;
    #|  margin-bottom: 10px;
    #|}
    #|.question-card .q-context {
    #|  font-size: 12px;
    #|  color: var(--text-dim);
    #|  line-height: 1.6;
    #|  background: var(--code-bg);
    #|  border: 1px solid var(--border);
    #|  border-radius: 8px;
    #|  padding: 8px 10px;
    #|  margin-bottom: 12px;
    #|  white-space: pre-wrap;
    #|}
    #|.question-card .q-options {
    #|  display: flex;
    #|  flex-wrap: wrap;
    #|  gap: 8px;
    #|  margin-bottom: 10px;
    #|}
    #|/* q-option-btn: frontmatter question choice buttons (question-card UI) */
    #|.q-option-btn {
    #|  margin: 0 6px 6px 0;
    #|  padding: 6px 12px;
    #|  border: 1px solid var(--border);
    #|  border-radius: 6px;
    #|  background: transparent;
    #|  color: var(--text);
    #|  font-family: inherit;
    #|  font-size: 13px;
    #|  cursor: pointer;
    #|  transition: background 150ms ease, border-color 150ms ease, box-shadow 150ms ease;
    #|}
    #|.q-option-btn:hover {
    #|  border-color: var(--accent);
    #|  background: var(--accent-soft);
    #|}
    #|.q-option-btn.selected {
    #|  border-color: var(--accent);
    #|  background: var(--selected-bg);
    #|  box-shadow: inset 0 0 0 1px var(--accent);
    #|  color: var(--text);
    #|  font-weight: 600;
    #|}
    #|.question-card .q-answer {
    #|  width: 100%;
    #|  min-height: 72px;
    #|  max-height: 160px;
    #|  background: var(--input-bg);
    #|  color: var(--text);
    #|  border: 1px solid var(--border);
    #|  border-radius: 8px;
    #|  padding: 10px 12px;
    #|  font-size: 13px;
    #|  font-family: inherit;
    #|  resize: vertical;
    #|}
    #|.question-card .q-answer:focus {
    #|  outline: none;
    #|  border-color: var(--accent);
    #|}
    #|.question-card .q-answer::placeholder {
    #|  color: var(--text-dim);
    #|}
    #|/* Resolved Section — collapsed by default, outside the step flow (no
    #| * action needed on an already-resolved question) */
    #|.yunomi-resolved-section {
    #|  margin-top: 16px;
    #|  border-top: 1px solid var(--border);
    #|  padding-top: 10px;
    #|}
    #|.yunomi-resolved-toggle {
    #|  display: flex;
    #|  align-items: center;
    #|  gap: 6px;
    #|  background: none;
    #|  border: none;
    #|  color: var(--text-dim);
    #|  font-size: 12px;
    #|  cursor: pointer;
    #|  padding: 4px 0;
    #|}
    #|.yunomi-resolved-toggle:hover {
    #|  color: var(--text);
    #|}
    #|.yunomi-resolved-toggle .arrow {
    #|  display: inline-block;
    #|  font-size: 10px;
    #|  transition: transform 150ms ease;
    #|}
    #|.yunomi-resolved-toggle.open .arrow {
    #|  transform: rotate(90deg);
    #|}
    #|.yunomi-resolved-list {
    #|  display: none;
    #|  margin-top: 10px;
    #|}
    #|.yunomi-resolved-list.visible {
    #|  display: block;
    #|}
    #|.yunomi-resolved-list .question-card {
    #|  padding: 10px 12px;
    #|  background: var(--input-bg);
    #|  border-radius: 8px;
    #|  margin-bottom: 8px;
    #|  opacity: 0.75;
    #|}
    #|.yunomi-resolved-list .question-card:last-child {
    #|  margin-bottom: 0;
    #|}
    #|.yunomi-resolved-list .q-title {
    #|  font-size: 12px;
    #|  font-weight: 500;
    #|  margin-bottom: 4px;
    #|}
    #|.yunomi-resolved-list .q-answer-display {
    #|  font-size: 12px;
    #|  color: var(--text);
    #|}
    #|.yunomi-questions-footer {
    #|  display: flex;
    #|  justify-content: space-between;
    #|  align-items: center;
    #|  gap: 12px;
    #|  padding: 12px 16px;
    #|  border-top: 1px solid var(--border);
    #|  flex-shrink: 0;
    #|}
    #|.yunomi-questions-later {
    #|  padding: 8px 14px;
    #|  border: 1px solid var(--border);
    #|  background: transparent;
    #|  color: var(--text-dim);
    #|  border-radius: 8px;
    #|  cursor: pointer;
    #|  font-size: 12px;
    #|  transition: all 150ms ease;
    #|}
    #|.yunomi-questions-later:hover {
    #|  background: var(--border);
    #|  color: var(--text);
    #|}
    #|.yunomi-questions-next {
    #|  margin-left: auto;
    #|  padding: 8px 20px;
    #|  border: none;
    #|  background: var(--accent);
    #|  color: var(--text-inverse);
    #|  border-radius: 8px;
    #|  cursor: pointer;
    #|  font-size: 13px;
    #|  font-weight: 600;
    #|  transition: filter 150ms ease;
    #|}
    #|.yunomi-questions-next:hover {
    #|  filter: brightness(1.1);
    #|}
    #|/* Unanswered-questions pill — a small floating badge, not a full-width
    #| * banner, so it never pushes the header/layout down. Bottom-LEFT,
    #| * deliberately: the header's action buttons (incl. Submit & Exit) and
    #| * #submit-modal's dialog (see "top-right position" above) both live in
    #| * the top-right corner, and this pill's z-index (1050) sits above both
    #| * — a top-right pill silently swallowed clicks meant for Submit & Exit
    #| * and made the Submit Review dialog appear to "not close" when the
    #| * click actually landed on the pill instead. Bottom-left has no other
    #| * fixed-position UI (comment list / mermaid error toast / history
    #| * panel all live elsewhere). */
    #|.yunomi-questions-bar {
    #|  display: none;
    #|  position: fixed;
    #|  bottom: 16px;
    #|  left: 16px;
    #|  align-items: center;
    #|  gap: 6px;
    #|  border: none;
    #|  background: var(--accent);
    #|  color: var(--text-inverse);
    #|  padding: 8px 12px;
    #|  border-radius: 999px;
    #|  cursor: pointer;
    #|  z-index: 1050;
    #|  box-shadow: 0 8px 24px rgba(0, 0, 0, 0.25);
    #|  transition: filter 150ms ease;
    #|}
    #|.yunomi-questions-bar:hover {
    #|  filter: brightness(1.1);
    #|}
    #|.yunomi-questions-bar.visible {
    #|  display: inline-flex;
    #|}
    #|.yunomi-questions-bar-count {
    #|  font-size: 11px;
    #|  font-weight: 700;
    #|  min-width: 14px;
    #|  text-align: center;
    #|}
    #|/* Task #21: a brief "all answered" acknowledgement flashed by
    #| * flash_answered_pill() right after confirming the summary screen —
    #| * closing straight from the last question's "完了" click with zero
    #| * feedback read as "did that just do nothing?" to a real reviewer.
    #| * Swaps the help icon for a check icon and tints the pill with
    #| * --success for a couple of seconds, then app.mbt reverts both. */
    #|.yunomi-questions-bar-icon-done {
    #|  display: none;
    #|}
    #|.yunomi-questions-bar.done {
    #|  background: var(--success);
    #|}
    #|.yunomi-questions-bar.done .yunomi-questions-bar-icon-pending {
    #|  display: none;
    #|}
    #|.yunomi-questions-bar.done .yunomi-questions-bar-icon-done {
    #|  display: inline-flex;
    #|}
    #|/* Copy notification toast */
    #|.copy-toast {
    #|  position: fixed;
    #|  bottom: 60px;
    #|  left: 50%;
    #|  transform: translateX(-50%) translateY(20px);
    #|  background: var(--accent);
    #|  color: var(--text-inverse);
    #|  padding: 8px 16px;
    #|  border-radius: 8px;
    #|  font-size: 13px;
    #|  opacity: 0;
    #|  pointer-events: none;
    #|  transition: opacity 200ms ease, transform 200ms ease;
    #|  z-index: 1000;
    #|}
    #|.copy-toast.visible {
    #|  opacity: 1;
    #|  transform: translateX(-50%) translateY(0);
    #|}
    #|@media (max-width: 960px) {
    #|  .md-layout { flex-direction: column; }
    #|  .md-left { max-width: 100%; flex: 1 1 0; min-height: 0; }
    #|  .md-right { display: none; }
    #|  .media-sidebar { display: none; }
    #|  .media-sidebar-toggle { display: none !important; }
    #|}
    #|.md-layout.preview-only .md-right { display: none; }
    #|.md-layout.preview-only .md-left { flex: 1 1 0; min-height: 0; max-width: 100%; }
    #|.filter-menu {
    #|  position: absolute;
    #|  background: var(--panel-solid);
    #|  border: 1px solid var(--border);
    #|  border-radius: 10px;
    #|  box-shadow: 0 14px 30px var(--shadow-color);
    #|  padding: 8px;
    #|  display: none;
    #|  z-index: 12;
    #|  width: 180px;
    #|  transition: background 200ms ease, border-color 200ms ease;
    #|}
    #|.filter-menu button {
    #|  width: 100%;
    #|  display: block;
    #|  margin: 4px 0;
    #|  padding: 8px 10px;
    #|  background: var(--selected-bg);
    #|  border: 1px solid var(--border);
    #|  border-radius: 8px;
    #|  color: var(--text);
    #|  cursor: pointer;
    #|  font-size: 13px;
    #|  text-align: left;
    #|}
    #|.filter-menu button:hover { background: var(--hover-bg); }
    #|.modal-overlay {
    #|  position: fixed;
    #|  inset: 0;
    #|  background: rgba(0,0,0,0.6);
    #|  display: none;
    #|  align-items: center;
    #|  justify-content: center;
    #|  z-index: 100;
    #|}
    #|.modal-overlay.visible { display: flex; }
    #|/* Submit modal: top-right position, no blocking overlay */
    #|#submit-modal {
    #|  background: transparent;
    #|  pointer-events: none;
    #|  align-items: flex-start;
    #|  justify-content: flex-end;
    #|}
    #|#submit-modal.visible { display: flex; }
    #|#submit-modal .modal-dialog {
    #|  pointer-events: auto;
    #|  margin: 60px 20px 20px 20px; /* top margin avoids header button overlap */
    #|}
    #|.modal-dialog {
    #|  background: var(--card-bg);
    #|  border: 1px solid var(--border);
    #|  border-radius: var(--radius-lg);
    #|  padding: 24px;
    #|  width: 90%;
    #|  max-width: 480px;
    #|  box-shadow: var(--shadow-card);
    #|  backdrop-filter: blur(24px);
    #|  -webkit-backdrop-filter: blur(24px);
    #|  transition: background 240ms ease, border-color 240ms ease;
    #|}
    #|.modal-dialog h3 { margin: 0 0 14px; font-size: 18px; font-weight: 700; color: var(--text); letter-spacing: -0.01em; }
    #|.modal-summary { color: var(--muted); font-size: 13px; margin-bottom: 14px; line-height: 1.5; }
    #|.modal-dialog label { display: block; font-size: 12px; font-weight: 600; margin-bottom: 8px; color: var(--muted); letter-spacing: 0.02em; text-transform: uppercase; }
    #|.modal-dialog textarea {
    #|  width: 100%;
    #|  min-height: 100px;
    #|  background: var(--input-bg);
    #|  border: 1px solid var(--border);
    #|  border-radius: var(--radius-sm);
    #|  color: var(--text);
    #|  padding: 12px 14px;
    #|  font-size: 14px;
    #|  font-family: inherit;
    #|  line-height: 1.5;
    #|  resize: vertical;
    #|  box-sizing: border-box;
    #|  transition: background 200ms ease, border-color 200ms ease, box-shadow 200ms ease;
    #|}
    #|.modal-dialog textarea:focus { outline: none; border-color: var(--accent); box-shadow: 0 0 0 3px var(--accent-soft); }
    #|.modal-actions { display: flex; gap: 10px; justify-content: flex-end; margin-top: 18px; }
    #|.modal-actions button {
    #|  padding: 9px 16px;
    #|  border-radius: var(--radius-sm);
    #|  border: 1px solid var(--border);
    #|  background: transparent;
    #|  color: var(--text);
    #|  cursor: pointer;
    #|  font-size: 13px;
    #|  font-weight: 600;
    #|  transition: background 160ms ease, border-color 160ms ease, transform 120ms ease;
    #|}
    #|.modal-actions button:hover { background: var(--hover-bg); border-color: var(--border-strong); }
    #|.modal-actions button.primary { background: var(--accent); color: var(--text-inverse); border-color: var(--accent); }
    #|.image-attach-area { margin: 12px 0; }
    #|.image-attach-area label { display: block; font-size: 12px; color: var(--muted); margin-bottom: 6px; }
    #|.image-attach-area.image-attach-small { margin: 8px 0; }
    #|.image-attach-area.image-attach-small label { font-size: 11px; }
    #|.image-preview-list { display: flex; flex-wrap: wrap; gap: 8px; min-height: 24px; }
    #|.image-preview-item { position: relative; }
    #|.image-preview-item img { max-width: 80px; max-height: 60px; border-radius: 4px; border: 1px solid var(--border); object-fit: cover; }
    #|.image-preview-item .remove-image { position: absolute; top: -6px; right: -6px; width: 18px; height: 18px; border-radius: 50%; background: var(--error, #ef4444); color: #fff; border: none; cursor: pointer; font-size: 12px; line-height: 1; display: flex; align-items: center; justify-content: center; }
    #|.image-preview-item .remove-image:hover { background: #dc2626; }
    #|.modal-actions button.primary:hover { background: var(--accent-strong); border-color: var(--accent-strong); }
    #|.modal-actions-decision { justify-content: space-between; align-items: center; }
    #|.kbd-hint { display: inline-block; font-size: 10px; padding: 1px 5px; border-radius: 3px; background: rgba(255,255,255,0.15); margin-left: 6px; font-family: system-ui; opacity: 0.8; }
    #|[data-theme="light"] .kbd-hint { background: rgba(0,0,0,0.08); }
    #|.decision-btn { padding: 9px 16px; border-radius: var(--radius-sm); border: 1px solid var(--border); cursor: pointer; font-size: 13px; font-weight: 700; letter-spacing: 0.01em; transition: background 160ms ease, border-color 160ms ease, transform 120ms ease, box-shadow 160ms ease; }
    #|.decision-btn:hover { transform: translateY(-1px); box-shadow: var(--shadow-soft); }
    #|.decision-approve { background: rgba(107, 191, 134, 0.14); color: var(--success); border-color: rgba(107, 191, 134, 0.42); }
    #|.decision-approve:hover { background: rgba(107, 191, 134, 0.22); border-color: var(--success); }
    #|.decision-request-changes { background: linear-gradient(135deg, var(--accent) 0%, var(--accent-2) 100%); color: var(--text-inverse); border-color: transparent; }
    #|.decision-request-changes:hover { background: linear-gradient(135deg, var(--accent-strong) 0%, var(--accent) 100%); }
    #|[data-theme="light"] .decision-approve { background: rgba(77, 157, 99, 0.14); color: var(--success); border-color: rgba(77, 157, 99, 0.38); }
    #|[data-theme="light"] .decision-approve:hover { background: rgba(77, 157, 99, 0.22); }
    #|.comment-sent-badge { display: inline-block; font-size: 10px; padding: 1px 6px; border-radius: 4px; margin-left: 6px; vertical-align: middle; }
    #|.comment-sent-badge.sent { background: #166534; color: #bbf7d0; }
    #|.comment-sent-badge.failed { background: #7f1d1d; color: #fecaca; }
    #|[data-theme="light"] .comment-sent-badge.sent { background: #dcfce7; color: #166534; }
    #|[data-theme="light"] .comment-sent-badge.failed { background: #fee2e2; color: #991b1b; }
    #|
    #|/* Submit & Exit disabled state */
    #|#send-and-exit:disabled { opacity: 0.4; cursor: not-allowed; }
    #|
    #|.modal-checkboxes { margin: 12px 0; }
    #|.modal-checkboxes label {
    #|  display: flex;
    #|  align-items: flex-start;
    #|  gap: 8px;
    #|  font-size: 12px;
    #|  color: var(--text);
    #|  margin-bottom: 8px;
    #|  cursor: pointer;
    #|}
    #|.modal-checkboxes input[type="checkbox"] {
    #|  margin-top: 2px;
    #|  accent-color: var(--accent);
    #|}
    #|
    #|body.dragging { user-select: none; cursor: crosshair; }
    #|body.dragging .diff-line { cursor: crosshair; }
    #|
    #|/* === Diff viewer === */
    #|.diff-view {
    #|  margin: 20px;
    #|  background: var(--panel);
    #|  border: 1px solid var(--border);
    #|  border-radius: var(--radius-lg);
    #|  padding: 0;
    #|  box-shadow: var(--shadow-soft);
    #|  overflow: hidden;
    #|  font-family: "JetBrains Mono", "SF Mono", "Menlo", "Consolas", ui-monospace, monospace;
    #|  font-size: 13px;
    #|  line-height: 1.55;
    #|}
    #|.diff-file-header {
    #|  padding: 12px 20px;
    #|  background: var(--accent-soft);
    #|  color: var(--accent-strong);
    #|  font-weight: 700;
    #|  font-size: 13px;
    #|  border-bottom: 1px solid var(--border);
    #|  display: flex;
    #|  align-items: center;
    #|  gap: 10px;
    #|}
    #|.diff-file-header:not(:first-child) { border-top: 1px solid var(--border); }
    #|.diff-label {
    #|  font-size: 10px;
    #|  font-weight: 700;
    #|  text-transform: uppercase;
    #|  letter-spacing: 0.04em;
    #|  padding: 2px 8px;
    #|  border-radius: var(--radius-pill);
    #|  background: var(--accent);
    #|  color: var(--text-inverse);
    #|}
    #|.diff-label.new { background: rgba(77, 157, 99, 0.18); color: var(--success); }
    #|.diff-label.deleted { background: rgba(201, 86, 79, 0.18); color: var(--error); }
    #|.diff-label.binary { background: var(--accent-soft); color: var(--muted); }
    #|.diff-hunk-header {
    #|  padding: 6px 20px;
    #|  background: var(--input-bg);
    #|  color: var(--muted);
    #|  font-size: 12px;
    #|  border-bottom: 1px solid var(--border);
    #|}
    #|.diff-line {
    #|  display: flex;
    #|  padding: 0 20px;
    #|  white-space: pre;
    #|  min-height: 20px;
    #|  border-left: 3px solid transparent;
    #|  transition: background 120ms ease;
    #|}
    #|.diff-line:hover { background: var(--hover-bg); }
    #|.diff-line.addition {
    #|  background: rgba(77, 157, 99, 0.10);
    #|  border-left-color: var(--success);
    #|  color: var(--text);
    #|}
    #|.diff-line.deletion {
    #|  background: rgba(201, 86, 79, 0.10);
    #|  border-left-color: var(--error);
    #|  color: var(--text);
    #|}
    #|[data-theme="dark"] .diff-line.addition { background: rgba(107, 191, 134, 0.10); }
    #|[data-theme="dark"] .diff-line.deletion { background: rgba(224, 104, 98, 0.12); }
    #|.diff-line .line-num {
    #|  display: inline-block;
    #|  width: 44px;
    #|  min-width: 44px;
    #|  text-align: right;
    #|  padding-right: 10px;
    #|  color: var(--muted);
    #|  font-size: 11px;
    #|  user-select: none;
    #|}
    #|.diff-line .line-content {
    #|  flex: 1;
    #|  padding-left: 4px;
    #|}
    #|.diff-line.addition .line-content::before { content: "+ "; color: var(--success); font-weight: 700; }
    #|.diff-line.deletion .line-content::before { content: "- "; color: var(--error); font-weight: 700; }
    #|.diff-line:not(.addition):not(.deletion) .line-content::before { content: "  "; }
    #|.diff-line.has-comment { outline: 2px dashed var(--accent); outline-offset: -2px; }
    #|
    #|/* === Plain text viewer === */
    #|.text-view {
    #|  margin: 20px;
    #|  background: var(--panel);
    #|  border: 1px solid var(--border);
    #|  border-radius: var(--radius-lg);
    #|  padding: 16px 0;
    #|  box-shadow: var(--shadow-soft);
    #|  font-family: "JetBrains Mono", "SF Mono", "Menlo", "Consolas", ui-monospace, monospace;
    #|  font-size: 13px;
    #|  line-height: 1.65;
    #|}
    #|.text-line {
    #|  display: flex;
    #|  padding: 0 20px;
    #|  white-space: pre-wrap;
    #|  word-break: break-word;
    #|  transition: background 120ms ease;
    #|  cursor: text;
    #|}
    #|.text-line:hover { background: var(--hover-bg); }
    #|.text-line.has-comment { background: var(--selected-bg); border-left: 3px solid var(--accent); padding-left: 17px; }
    #|.text-line .line-num {
    #|  display: inline-block;
    #|  width: 44px;
    #|  min-width: 44px;
    #|  text-align: right;
    #|  padding-right: 14px;
    #|  color: var(--muted);
    #|  font-size: 11px;
    #|  user-select: none;
    #|}
    #|.text-line .line-content { flex: 1; color: var(--text); }
    #|
    #|@media (max-width: 840px) {
    #|  header { flex-direction: column; align-items: stretch; }
    #|  /* Primary action (Submit & Exit) stays right-aligned when the header wraps */
    #|  header .actions { justify-content: flex-end; flex-wrap: wrap; }
    #|  .comment-list { width: calc(100% - 24px); right: 12px; }
    #|}
    #|/* Mermaid diagram styles */
    #|.mermaid-container {
    #|  position: relative;
    #|  margin: 16px 0;
    #|  background: var(--panel);
    #|  border: 1px solid var(--border);
    #|  border-radius: 8px;
    #|  padding: 16px;
    #|  overflow: hidden;
    #|}
    #|.mermaid-container .mermaid {
    #|  display: flex;
    #|  justify-content: center;
    #|}
    #|.mermaid-container .mermaid svg {
    #|  max-width: 100%;
    #|  height: auto;
    #|  cursor: pointer;
    #|  pointer-events: auto;
    #|}
    #|.mermaid-error-banner {
    #|  background: #fff3f3;
    #|  color: #c33;
    #|  border: 1px solid #e88;
    #|  border-radius: 4px;
    #|  padding: 6px 10px;
    #|  margin-bottom: 8px;
    #|  font-size: 12px;
    #|  font-weight: 500;
    #|}
    #|[data-theme="dark"] .mermaid-error-banner {
    #|  background: #3a1a1a;
    #|  color: #f88;
    #|  border-color: #744;
    #|}
    #|/* Fullscreen overlay */
    #|.fullscreen-overlay {
    #|  position: fixed;
    #|  inset: 0;
    #|  background: var(--bg);
    #|  z-index: 1000;
    #|  display: none;
    #|  flex-direction: column;
    #|}
    #|.fullscreen-overlay.visible { display: flex; }
    #|.fullscreen-header {
    #|  display: flex;
    #|  justify-content: space-between;
    #|  align-items: center;
    #|  padding: 12px 20px;
    #|  background: var(--panel-alpha);
    #|  border-bottom: 1px solid var(--border);
    #|}
    #|.fullscreen-header h3 { margin: 0; font-size: 14px; }
    #|.fullscreen-controls { display: flex; gap: 8px; align-items: center; }
    #|.fullscreen-controls button {
    #|  background: var(--selected-bg);
    #|  border: 1px solid var(--border);
    #|  border-radius: 6px;
    #|  padding: 6px 12px;
    #|  cursor: pointer;
    #|  color: var(--text);
    #|  font-size: 13px;
    #|}
    #|.fullscreen-controls button:hover { background: var(--hover-bg); }
    #|.fullscreen-controls .zoom-info { font-size: 12px; color: var(--muted); min-width: 50px; text-align: center; }
    #|.fullscreen-content {
    #|  flex: 1;
    #|  overflow: hidden;
    #|  position: relative;
    #|  cursor: grab;
    #|  touch-action: none;
    #|}
    #|.fullscreen-content:active { cursor: grabbing; }
    #|.fullscreen-content .mermaid-wrapper {
    #|  position: absolute;
    #|  transform-origin: 0 0;
    #|  padding: 40px;
    #|}
    #|.fullscreen-content .mermaid svg {
    #|  display: block;
    #|}
    #|/* Minimap */
    #|.minimap {
    #|  position: absolute;
    #|  top: 70px;
    #|  right: 20px;
    #|  width: 200px;
    #|  height: 150px;
    #|  background: var(--panel-alpha);
    #|  border: 1px solid var(--border);
    #|  border-radius: 8px;
    #|  overflow: hidden;
    #|  box-shadow: 0 4px 12px rgba(0,0,0,0.15);
    #|}
    #|.minimap-content {
    #|  width: 100%;
    #|  height: 100%;
    #|  box-sizing: border-box;
    #|  display: flex;
    #|  align-items: center;
    #|  justify-content: center;
    #|  padding: 8px;
    #|}
    #|.minimap-content svg {
    #|  max-width: 100%;
    #|  max-height: 100%;
    #|  opacity: 0.6;
    #|}
    #|.minimap-viewport {
    #|  position: absolute;
    #|  border: 2px solid var(--accent);
    #|  background: rgba(127, 168, 96, 0.25);
    #|  pointer-events: none;
    #|  border-radius: 2px;
    #|}
    #|/* Error toast */
    #|.mermaid-error-toast {
    #|  position: fixed;
    #|  bottom: 20px;
    #|  left: 50%;
    #|  transform: translateX(-50%);
    #|  background: var(--error);
    #|  color: white;
    #|  padding: 12px 24px;
    #|  border-radius: 8px;
    #|  font-size: 13px;
    #|  max-width: 80%;
    #|  z-index: 2000;
    #|  display: none;
    #|  box-shadow: 0 4px 12px rgba(0,0,0,0.3);
    #|  white-space: pre-wrap;
    #|  font-family: monospace;
    #|}
    #|.mermaid-error-toast.visible { display: block; }
    #|
    #|/* History Panel - Push layout */
    #|body { transition: margin-right 0.28s cubic-bezier(0.2, 0.8, 0.2, 1); }
    #|body.history-open { margin-right: 340px; }
    #|body.history-open header { right: 340px; }
    #|header { transition: right 0.28s cubic-bezier(0.2, 0.8, 0.2, 1); right: 0; }
    #|
    #|.history-toggle {
    #|  background: transparent;
    #|  color: var(--text);
    #|  border: 1px solid transparent;
    #|  border-radius: var(--radius-sm);
    #|  padding: 0 10px;
    #|  font-size: 14px;
    #|  cursor: pointer;
    #|  gap: 6px;
    #|  min-width: 34px;
    #|  height: 34px;
    #|  display: flex;
    #|  align-items: center;
    #|  justify-content: center;
    #|  transition: background 160ms ease, border-color 160ms ease;
    #|}
    #|.history-toggle:hover { background: var(--hover-bg); border-color: var(--border); }
    #|.history-panel {
    #|  position: fixed;
    #|  top: 0;
    #|  right: 0;
    #|  width: 340px;
    #|  height: 100vh;
    #|  background: var(--panel-alpha);
    #|  border-left: 1px solid var(--border);
    #|  backdrop-filter: saturate(140%) blur(24px);
    #|  -webkit-backdrop-filter: saturate(140%) blur(24px);
    #|  box-shadow: -20px 0 40px rgba(0, 0, 0, 0.08);
    #|  z-index: 90;
    #|  transform: translateX(100%);
    #|  transition: transform 0.28s cubic-bezier(0.2, 0.8, 0.2, 1);
    #|  display: flex;
    #|  flex-direction: column;
    #|}
    #|.history-panel.open { transform: translateX(0); }
    #|.history-panel-header {
    #|  padding: 16px;
    #|  border-bottom: 1px solid var(--border);
    #|  display: flex;
    #|  justify-content: space-between;
    #|  align-items: center;
    #|}
    #|.history-panel-header h3 { margin: 0; font-size: 14px; font-weight: 600; }
    #|.history-panel-close {
    #|  background: transparent;
    #|  border: none;
    #|  color: var(--muted);
    #|  cursor: pointer;
    #|  font-size: 18px;
    #|  padding: 4px;
    #|}
    #|.history-panel-close:hover { color: var(--text); }
    #|.history-panel-body {
    #|  flex: 1;
    #|  overflow-y: auto;
    #|  padding: 12px;
    #|}
    #|.history-empty {
    #|  color: var(--muted);
    #|  font-size: 13px;
    #|  text-align: center;
    #|  padding: 40px 20px;
    #|}
    #|.history-date-group { margin-bottom: 16px; }
    #|.history-date {
    #|  font-size: 11px;
    #|  font-weight: 600;
    #|  color: var(--muted);
    #|  margin-bottom: 8px;
    #|  text-transform: uppercase;
    #|}
    #|.history-item {
    #|  background: var(--bg);
    #|  border: 1px solid var(--border);
    #|  border-radius: 6px;
    #|  margin-bottom: 8px;
    #|  overflow: hidden;
    #|}
    #|.history-item-header {
    #|  display: flex;
    #|  justify-content: space-between;
    #|  align-items: center;
    #|  padding: 8px 10px;
    #|  background: var(--selected-bg);
    #|  cursor: pointer;
    #|}
    #|.history-item-header:hover { background: var(--hover-bg); }
    #|.history-item-file {
    #|  font-size: 12px;
    #|  font-weight: 600;
    #|  color: var(--text);
    #|  white-space: nowrap;
    #|  overflow: hidden;
    #|  text-overflow: ellipsis;
    #|  max-width: 180px;
    #|}
    #|.history-item-time { font-size: 10px; color: var(--muted); }
    #|.history-item-body {
    #|  display: none;
    #|  padding: 10px;
    #|  font-size: 12px;
    #|  border-top: 1px solid var(--border);
    #|}
    #|.history-item.expanded .history-item-body { display: block; }
    #|.history-summary {
    #|  color: var(--text);
    #|  margin-bottom: 8px;
    #|  padding-bottom: 8px;
    #|  border-bottom: 1px solid var(--border);
    #|}
    #|.history-summary-label {
    #|  font-size: 10px;
    #|  font-weight: 600;
    #|  color: var(--muted);
    #|  margin-bottom: 4px;
    #|}
    #|.history-summary-text { white-space: pre-wrap; line-height: 1.4; }
    #|.history-comments-label {
    #|  font-size: 10px;
    #|  font-weight: 600;
    #|  color: var(--muted);
    #|  margin-bottom: 6px;
    #|}
    #|.history-comment {
    #|  padding: 6px 0;
    #|  border-bottom: 1px solid var(--border);
    #|}
    #|.history-comment:last-child { border-bottom: none; }
    #|.history-comment-line {
    #|  font-size: 10px;
    #|  color: var(--accent);
    #|  font-weight: 600;
    #|  margin-bottom: 2px;
    #|}
    #|.history-comment-quote {
    #|  background: rgba(0, 0, 0, 0.3);
    #|  border-left: 2px solid var(--accent);
    #|  padding: 4px 8px;
    #|  margin: 4px 0;
    #|  font-family: 'SF Mono', Monaco, Consolas, monospace;
    #|  font-size: 11px;
    #|  color: var(--muted);
    #|  white-space: pre-wrap;
    #|  word-break: break-all;
    #|  max-height: 80px;
    #|  overflow-y: auto;
    #|}
    #|.history-comment-text {
    #|  color: var(--text);
    #|  line-height: 1.4;
    #|  white-space: pre-wrap;
    #|}
    #|.history-badge {
    #|  display: inline-block;
    #|  background: var(--accent);
    #|  color: var(--text-inverse);
    #|  font-size: 10px;
    #|  padding: 2px 6px;
    #|  border-radius: 10px;
    #|  margin-left: 6px;
    #|}
    #|/* Table scroll container */
    #|.table-container {
    #|  overflow-x: auto;
    #|  margin: 16px 0;
    #|  border-radius: 8px;
    #|  border: 1px solid var(--border);
    #|}
    #|.table-container table {
    #|  margin: 0;
    #|  border: none;
    #|  border-radius: 0;
    #|}
    #|.table-container::-webkit-scrollbar {
    #|  height: 6px;
    #|}
    #|.table-container::-webkit-scrollbar-track {
    #|  background: var(--bg);
    #|  border-radius: 3px;
    #|}
    #|.table-container::-webkit-scrollbar-thumb {
    #|  background: var(--border);
    #|  border-radius: 3px;
    #|}
    #|.table-container::-webkit-scrollbar-thumb:hover {
    #|  background: var(--muted);
    #|}
    #|/* Media sidebar */
    #|.media-sidebar {
    #|  display: flex;
    #|  flex-shrink: 0;
    #|  height: auto;
    #|  transition: width 0.3s cubic-bezier(0.4, 0, 0.2, 1);
    #|  position: relative;
    #|  z-index: 10;
    #|  max-width: 60%;
    #|}
    #|.media-sidebar.hidden { display: none; }
    #|.media-sidebar-thumbs {
    #|  width: 96px;
    #|  overflow-y: auto;
    #|  overflow-x: hidden;
    #|  padding: 8px;
    #|  border-left: 1px solid var(--border);
    #|  display: flex;
    #|  flex-direction: column;
    #|  gap: 8px;
    #|  background: var(--panel);
    #|  scrollbar-width: thin;
    #|  scrollbar-color: var(--border) transparent;
    #|}
    #|.media-sidebar-thumbs::-webkit-scrollbar { width: 4px; }
    #|.media-sidebar-thumbs::-webkit-scrollbar-track { background: transparent; }
    #|.media-sidebar-thumbs::-webkit-scrollbar-thumb { background: var(--border); border-radius: 4px; }
    #|.media-sidebar-thumb {
    #|  width: 80px;
    #|  height: 60px;
    #|  border-radius: 6px;
    #|  border: 2px solid var(--border);
    #|  overflow: hidden;
    #|  cursor: pointer;
    #|  position: relative;
    #|  flex-shrink: 0;
    #|  background: var(--bg);
    #|  transition: border-color 0.2s ease, transform 0.15s ease, box-shadow 0.2s ease;
    #|}
    #|.media-sidebar-thumb:hover { border-color: var(--accent); transform: scale(1.05); box-shadow: 0 2px 8px var(--shadow-color); }
    #|.media-sidebar-thumb.active { border-color: var(--accent); box-shadow: 0 0 0 2px var(--accent), 0 2px 8px var(--shadow-color); }
    #|.media-sidebar-thumb img { width: 100%; height: 100%; object-fit: cover; display: block; }
    #|.media-sidebar-thumb svg { width: 100%; height: 100%; display: block; }
    #|.media-sidebar-thumb-video {
    #|  position: relative;
    #|  width: 100%;
    #|  height: 100%;
    #|  display: flex;
    #|  align-items: center;
    #|  justify-content: center;
    #|  background: #000;
    #|}
    #|.media-sidebar-thumb-video video { width: 100%; height: 100%; object-fit: cover; }
    #|.media-sidebar-thumb-video::after {
    #|  content: '';
    #|  position: absolute;
    #|  width: 24px;
    #|  height: 24px;
    #|  background: rgba(255,255,255,0.85);
    #|  border-radius: 50%;
    #|}
    #|.media-sidebar-thumb-video::before {
    #|  content: '';
    #|  position: absolute;
    #|  z-index: 1;
    #|  width: 0;
    #|  height: 0;
    #|  border-style: solid;
    #|  border-width: 5px 0 5px 9px;
    #|  border-color: transparent transparent transparent #000;
    #|  margin-left: 2px;
    #|}
    #|.media-sidebar-thumb-mermaid {
    #|  display: flex;
    #|  align-items: center;
    #|  justify-content: center;
    #|  width: 100%;
    #|  height: 100%;
    #|  padding: 2px;
    #|  background: var(--panel);
    #|  overflow: hidden;
    #|}
    #|.media-sidebar-thumb-mermaid svg { width: 100% !important; height: 100% !important; max-width: 100%; max-height: 100%; display: block; }
    #|.media-sidebar-thumb-index {
    #|  position: absolute;
    #|  top: 2px;
    #|  left: 2px;
    #|  background: rgba(0,0,0,0.6);
    #|  color: #fff;
    #|  font-size: 9px;
    #|  font-weight: 600;
    #|  padding: 1px 4px;
    #|  border-radius: 3px;
    #|  line-height: 1.2;
    #|  pointer-events: none;
    #|  z-index: 1;
    #|}
    #|/* Video timeline */
    #|.video-timeline {
    #|  display: flex;
    #|  gap: 8px;
    #|  padding: 8px;
    #|  overflow-x: auto;
    #|  background: var(--panel);
    #|  border-radius: 8px;
    #|  margin-top: 8px;
    #|  scrollbar-width: thin;
    #|  scrollbar-color: var(--border) transparent;
    #|}
    #|.timeline-loading { color: var(--muted); font-size: 12px; padding: 8px; }
    #|.timeline-thumb-wrapper {
    #|  flex-shrink: 0;
    #|  display: flex;
    #|  flex-direction: column;
    #|  align-items: center;
    #|  gap: 4px;
    #|  cursor: pointer;
    #|}
    #|.timeline-thumb {
    #|  width: 80px;
    #|  height: 60px;
    #|  object-fit: cover;
    #|  border-radius: 4px;
    #|  border: 2px solid transparent;
    #|  transition: border-color 0.2s ease;
    #|}
    #|.timeline-thumb.active { border-color: var(--accent); }
    #|.timeline-thumb:hover { border-color: var(--accent); opacity: 0.8; }
    #|.timeline-time { font-size: 10px; color: var(--muted); }
    #|.md-preview .video-timeline {
    #|  height: auto;
    #|  min-height: 92px;
    #|  align-items: flex-start;
    #|}
    #|.md-preview .video-timeline .timeline-thumb-wrapper {
    #|  position: static;
    #|}
    #|.md-preview .video-timeline .timeline-time {
    #|  position: static;
    #|  right: auto;
    #|  bottom: auto;
    #|  display: block;
    #|  width: 100%;
    #|  max-width: 80px;
    #|  padding: 0;
    #|  background: transparent;
    #|  color: var(--muted);
    #|  text-align: center;
    #|  line-height: 1.2;
    #|}
    #|.yunomi-commentable {
    #|  position: relative;
    #|}
    #|.yunomi-comment-button {
    #|  position: absolute;
    #|  top: 6px;
    #|  right: 6px;
    #|  width: 24px;
    #|  height: 24px;
    #|  border: 1px solid rgba(0, 0, 0, 0.18);
    #|  border-radius: 6px;
    #|  background: rgba(255, 255, 255, 0.92);
    #|  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.16);
    #|  cursor: pointer;
    #|  z-index: 4;
    #|  opacity: 0;
    #|  color: var(--accent);
    #|  font-size: 15px;
    #|  font-weight: 700;
    #|  line-height: 1;
    #|  display: inline-flex;
    #|  align-items: center;
    #|  justify-content: center;
    #|  transition: opacity 0.12s ease, transform 0.12s ease, background 0.12s ease;
    #|}
    #|.yunomi-commentable:hover > .yunomi-comment-button,
    #|.yunomi-comment-button:focus-visible {
    #|  opacity: 1;
    #|  transform: translateY(-1px);
    #|  background: #fff;
    #|}
    #|.md-preview .video-timeline .timeline-thumb-wrapper.yunomi-commentable {
    #|  position: relative;
    #|}
    #|.md-preview .video-timeline .timeline-thumb-wrapper > .yunomi-comment-button {
    #|  top: 4px;
    #|  right: 4px;
    #|}
    #|.video-overlay-wrapper > .yunomi-comment-button {
    #|  top: 14px;
    #|  right: 52px;
    #|}
    #|.mermaid-container > .yunomi-comment-button {
    #|  top: 8px;
    #|  right: 8px;
    #|  z-index: 3;
    #|}
    #|/* Fullscreen overlay */
    #|.fullscreen-overlay {
    #|  display: none;
    #|  position: fixed;
    #|  top: 0;
    #|  left: 0;
    #|  width: 100%;
    #|  height: 100%;
    #|  background: rgba(0,0,0,0.9);
    #|  z-index: 1000;
    #|  flex-direction: column;
    #|}
    #|.fullscreen-overlay.visible { display: flex; }
    #|.fullscreen-header {
    #|  display: flex;
    #|  justify-content: space-between;
    #|  align-items: center;
    #|  padding: 12px 16px;
    #|  background: rgba(0,0,0,0.8);
    #|  border-bottom: 1px solid rgba(255,255,255,0.1);
    #|}
    #|.fullscreen-header h3 { margin: 0; color: #fff; font-size: 14px; }
    #|.fullscreen-controls { display: flex; gap: 6px; align-items: center; }
    #|.fullscreen-controls button {
    #|  background: rgba(255,255,255,0.1);
    #|  border: 1px solid rgba(255,255,255,0.2);
    #|  color: #fff;
    #|  padding: 6px 12px;
    #|  border-radius: 6px;
    #|  cursor: pointer;
    #|  font-size: 12px;
    #|}
    #|.fullscreen-controls button:hover { background: rgba(255,255,255,0.2); }
    #|.fullscreen-controls .zoom-info { color: #fff; font-size: 12px; min-width: 40px; text-align: center; }
    #|@media (max-width: 960px) {
    #|  .media-sidebar { display: none !important; }
    #|  .media-sidebar-toggle { display: none !important; }
    #|}
    #|.video-overlay-wrapper {
    #|  position: relative;
    #|  display: inline-block;
    #|}
    #|.video-fs-overlay-btn {
    #|  position: absolute;
    #|  top: 8px;
    #|  right: 8px;
    #|  width: 36px;
    #|  height: 36px;
    #|  padding: 0;
    #|  background: rgba(0,0,0,0.6);
    #|  border: 1px solid rgba(255,255,255,0.3);
    #|  color: #fff;
    #|  font-size: 18px;
    #|  line-height: 1;
    #|  cursor: pointer;
    #|  border-radius: 8px;
    #|  display: flex;
    #|  align-items: center;
    #|  justify-content: center;
    #|  z-index: 5;
    #|  transition: background 120ms ease;
    #|}
    #|.video-fs-overlay-btn:hover { background: rgba(0,0,0,0.8); }
    #|@media (max-width: 600px) {
    #|  .minimap { display: none !important; }
    #|  .fullscreen-header { padding: 8px 12px; }
    #|  .fullscreen-controls { gap: 4px; }
    #|  .fullscreen-controls button { padding: 6px 8px; font-size: 11px; }
    #|  .fullscreen-controls .zoom-info { font-size: 11px; min-width: 32px; }
    #|  .history-panel { width: 100vw; }
    #|  body.history-open header { right: 0; }
    #|}
  css
}
