///|
/// Build the main CSS styles
fn build_css() -> String {
  let css =
    #|/* Dark theme (default) — GitHub Primer inspired neutral dark.
    #|   Green is reserved for success states, not the page base. */
    #|:root {
    #|  color-scheme: dark;
    #|  --bg: #0d1117;
    #|  --bg-gradient: linear-gradient(180deg, #0d1117 0%, #161b22 100%);
    #|  --panel: #161b22;
    #|  --panel-alpha: rgba(22, 27, 34, 0.88);
    #|  --panel-solid: #161b22;
    #|  --card-bg: rgba(22, 27, 34, 0.96);
    #|  --input-bg: #0d1117;
    #|  --border: #30363d;
    #|  --border-strong: #8b949e;
    #|  --accent: #2f81f7;
    #|  --accent-strong: #58a6ff;
    #|  --accent-2: #a371f7;
    #|  --accent-soft: rgba(47, 129, 247, 0.16);
    #|  --text: #e6edf3;
    #|  --text-inverse: #0d1117;
    #|  --on-accent: #ffffff;
    #|  --accent-fill: color-mix(in srgb, var(--accent) 58%, #000000);
    #|  --muted: #8b949e;
    #|  --comment: #d29922;
    #|  --badge: #2f81f7;
    #|  --table-bg: #161b22;
    #|  --row-even: rgba(48, 54, 61, 0.45);
    #|  --row-odd: rgba(13, 17, 23, 0.35);
    #|  --selected-bg: rgba(47, 129, 247, 0.22);
    #|  --hover-bg: rgba(47, 129, 247, 0.12);
    #|  --shadow-color: rgba(0,0,0,0.45);
    #|  --shadow-soft: 0 10px 30px rgba(0,0,0,0.35);
    #|  --shadow-card: 0 20px 40px rgba(0,0,0,0.4);
    #|  --code-bg: #0d1117;
    #|  --error: #f85149;
    #|  --success: #3fb950;
    #|  --warning: #d29922;
    #|  --radius-sm: 8px;
    #|  --radius-md: 12px;
    #|  --radius-lg: 16px;
    #|  --radius-pill: 999px;
    #|  --review-loop-sidebar-width: 300px;
    #|  --review-loop-sidebar-offset: 8px;
    #|  --font-display: "Inter", "Hiragino Kaku Gothic ProN", "Hiragino Sans", system-ui, -apple-system, sans-serif;
    #|}
    #|/* Light theme — GitHub Primer inspired neutral light.
    #|   Green is reserved for success states, not the page base. */
    #|[data-theme="light"] {
    #|  color-scheme: light;
    #|  --bg: #ffffff;
    #|  --bg-gradient: linear-gradient(180deg, #ffffff 0%, #f6f8fa 100%);
    #|  --panel: #ffffff;
    #|  --panel-alpha: rgba(255, 255, 255, 0.92);
    #|  --panel-solid: #ffffff;
    #|  --card-bg: rgba(255, 255, 255, 0.98);
    #|  --input-bg: #f6f8fa;
    #|  --border: #d0d7de;
    #|  --border-strong: #8c959f;
    #|  --accent: #0969da;
    #|  --accent-strong: #0550ae;
    #|  --accent-2: #8250df;
    #|  --accent-soft: rgba(9, 105, 218, 0.10);
    #|  --text: #24292f;
    #|  --text-inverse: #ffffff;
    #|  --on-accent: #ffffff;
    #|  --accent-fill: var(--accent);
    #|  --muted: #57606a;
    #|  --comment: #9a6700;
    #|  --badge: #0969da;
    #|  --table-bg: #ffffff;
    #|  --row-even: #f6f8fa;
    #|  --row-odd: #ffffff;
    #|  --selected-bg: rgba(9, 105, 218, 0.16);
    #|  --hover-bg: rgba(9, 105, 218, 0.08);
    #|  --shadow-color: rgba(31, 35, 40, 0.10);
    #|  --shadow-soft: 0 6px 18px rgba(31, 35, 40, 0.08);
    #|  --shadow-card: 0 18px 36px rgba(31, 35, 40, 0.12);
    #|  --code-bg: #f6f8fa;
    #|  --error: #cf222e;
    #|  --success: #1a7f37;
    #|  --warning: #9a6700;
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
    #|  letter-spacing: 0;
    #|  transition: background 240ms ease, color 240ms ease;
    #|}
    #|header {
    #|  position: sticky;
    #|  top: 0;
    #|  z-index: 5;
    #|  flex-shrink: 0;
    #|  padding: 14px 20px;
    #|  background: var(--panel-solid);
    #|  border-bottom: 1px solid var(--border);
    #|  display: flex;
    #|  gap: 14px;
    #|  align-items: center;
    #|  justify-content: space-between;
    #|  transition: background 240ms ease, border-color 240ms ease;
    #|}
    #|header .meta { display: flex; gap: 12px; align-items: center; min-width: 0; }
    #|.brand { position: relative; display: inline-flex; align-items: center; gap: 7px; flex: 0 0 auto; color: var(--accent-strong); text-decoration: none; font-weight: 800; letter-spacing: 0; }
    #|.brand-mark { position: relative; display: inline-grid; place-items: center; width: 28px; height: 28px; border-radius: 50%; background: var(--accent-soft); font-size: 18px; line-height: 1; animation: yunomi-steam 4.2s ease-in-out infinite; }
    #|@keyframes yunomi-steam { 0%, 100% { transform: translateY(0); filter: saturate(1); } 45% { transform: translateY(-1px); filter: saturate(1.18); } }
    #|header .actions { display: flex; gap: 6px; align-items: center; flex: 0 1 auto; min-width: 0; }
    #|header h1 { display: flex; flex-direction: column; margin: 0; line-height: 1.3; }
    #|header h1 { min-width: 0; }
    #|header h1 .title-path { display: block; max-width: min(48vw, 560px); overflow: hidden; color: var(--muted); font-size: 10px; font-weight: 600; line-height: 1.2; text-overflow: ellipsis; white-space: nowrap; }
    #|header h1 .title-file { font-size: 16px; font-weight: 700; letter-spacing: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; max-width: min(48vw, 560px); }
    #|.app-footer {
    #|  flex-shrink: 0;
    #|  display: flex;
    #|  align-items: baseline;
    #|  gap: 8px;
    #|  padding: 5px 16px;
    #|  border-top: 1px solid var(--border);
    #|  background: var(--panel-solid);
    #|  color: var(--muted);
    #|  font-size: 11px;
    #|  font-weight: 600;
    #|  line-height: 1.3;
    #|  z-index: 4;
    #|}
    #|.app-footer-version { font-variant-numeric: tabular-nums; letter-spacing: 0.02em; }
    #|.app-footer-link { color: inherit; text-decoration: none; display: inline-flex; align-items: baseline; gap: 8px; }
    #|.app-footer-link:hover, .app-footer-link:focus-visible { color: var(--text); text-decoration: underline; }
    #|.review-file-switcher {
    #|  display: flex;
    #|  align-items: center;
    #|  gap: 10px;
    #|  min-height: 44px;
    #|  flex: 0 0 auto;
    #|  padding: 6px 20px;
    #|  background: var(--bg);
    #|  border-bottom: 1px solid var(--border);
    #|  box-sizing: border-box;
    #|}
    #|.review-file-switcher-label {
    #|  flex: 0 0 auto;
    #|  color: var(--muted);
    #|  font-size: 11px;
    #|  font-weight: 700;
    #|  text-transform: uppercase;
    #|  letter-spacing: 0.04em;
    #|}
    #|.review-file-switcher-tabs {
    #|  display: flex;
    #|  min-width: 0;
    #|  gap: 6px;
    #|  overflow-x: auto;
    #|  padding: 2px 0;
    #|  scrollbar-width: thin;
    #|}
    #|.review-file-switcher a {
    #|  flex: 0 0 auto;
    #|  max-width: 260px;
    #|  overflow: hidden;
    #|  text-overflow: ellipsis;
    #|  white-space: nowrap;
    #|  padding: 5px 10px;
    #|  color: var(--muted);
    #|  text-decoration: none;
    #|  border: 1px solid var(--border);
    #|  border-radius: var(--radius-sm);
    #|  background: var(--panel);
    #|  font-size: 12px;
    #|  line-height: 1.4;
    #|}
    #|.review-file-switcher a:hover {
    #|  color: var(--text);
    #|  background: var(--hover-bg);
    #|}
    #|.review-file-switcher a.active {
    #|  color: var(--accent);
    #|  background: var(--selected-bg);
    #|  border-color: var(--accent);
    #|}
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
    #|  background: linear-gradient(135deg, var(--accent-fill) 0%, color-mix(in srgb, var(--accent-2) 62%, #000000) 100%);
    #|  color: var(--on-accent);
    #|  border: none;
    #|  padding: 6px 18px;
    #|  font-weight: 700;
    #|  letter-spacing: 0.01em;
    #|  box-shadow: var(--shadow-soft);
    #|}
    #|header button.submit-exit-btn:hover {
    #|  background: linear-gradient(135deg, color-mix(in srgb, var(--accent-fill) 86%, #000000) 0%, var(--accent-fill) 100%);
    #|  color: var(--on-accent);
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
    #|/* Theme buttons */
    #|.theme-picker {
    #|  position: relative;
    #|  display: inline-flex;
    #|  align-items: stretch;
    #|  height: 34px;
    #|  border: 1px solid var(--border);
    #|  border-radius: var(--radius-sm);
    #|  background: var(--panel);
    #|  overflow: visible;
    #|}
    #|.theme-toggle, .theme-menu-toggle {
    #|  background: transparent;
    #|  color: var(--muted);
    #|  border: 0;
    #|  font-size: 15px;
    #|  cursor: pointer;
    #|  transition: background 160ms ease, color 160ms ease, box-shadow 160ms ease;
    #|  display: flex;
    #|  align-items: center;
    #|  justify-content: center;
    #|  gap: 6px;
    #|  height: 34px;
    #|}
    #|.theme-toggle { min-width: 78px; padding: 0 10px; border-radius: calc(var(--radius-sm) - 1px) 0 0 calc(var(--radius-sm) - 1px); }
    #|.theme-menu-toggle { min-width: 32px; padding: 0 9px; border-left: 1px solid var(--border); border-radius: 0 calc(var(--radius-sm) - 1px) calc(var(--radius-sm) - 1px) 0; font-size: 11px; }
    #|.theme-toggle:hover, .theme-menu-toggle:hover, .theme-menu-toggle[aria-expanded="true"] { background: var(--hover-bg); color: var(--text); }
    #|#theme-label { font-size: 12px; font-weight: 700; color: var(--text); }
    #|.theme-menu {
    #|  position: absolute;
    #|  top: calc(100% + 6px);
    #|  right: 0;
    #|  z-index: 20;
    #|  min-width: 210px;
    #|  padding: 6px;
    #|  border: 1px solid var(--border);
    #|  border-radius: var(--radius-md);
    #|  background: var(--panel-solid);
    #|  box-shadow: var(--shadow-card);
    #|  display: grid;
    #|  gap: 4px;
    #|}
    #|.theme-menu[hidden] { display: none; }
    #|.theme-menu button {
    #|  width: 100%;
    #|  border: 0;
    #|  border-radius: var(--radius-sm);
    #|  background: transparent;
    #|  color: var(--text);
    #|  display: flex;
    #|  align-items: center;
    #|  justify-content: space-between;
    #|  gap: 12px;
    #|  padding: 8px 10px;
    #|  cursor: pointer;
    #|  text-align: left;
    #|}
    #|.theme-menu button:hover, .theme-menu button.active { background: var(--hover-bg); color: var(--accent-strong); }
    #|.theme-menu button span { font-size: 13px; font-weight: 700; }
    #|.theme-menu button small { color: var(--muted); font-size: 11px; }
    #|[data-theme="light"][data-color-scheme="tokyo"] {
    #|  --bg: #d5d6db; --bg-gradient: linear-gradient(180deg, #d5d6db 0%, #e1e2e7 100%); --panel: #e1e2e7; --panel-alpha: rgba(225, 226, 231, 0.92); --panel-solid: #e1e2e7; --card-bg: rgba(225, 226, 231, 0.98); --input-bg: #c8c9d1; --border: #b4b6c2; --border-strong: #7f8496; --accent: #34548a; --accent-strong: #34548a; --accent-2: #5a4a78; --accent-soft: rgba(52, 84, 138, 0.13); --text: #343b58; --text-inverse: #f2f3f7; --muted: #5c647e; --comment: #8f5e15; --badge: #34548a; --table-bg: #e1e2e7; --row-even: #d5d6db; --row-odd: #e1e2e7; --selected-bg: rgba(52, 84, 138, 0.18); --hover-bg: rgba(52, 84, 138, 0.10); --code-bg: #c8c9d1; --error: #8c4351; --success: #385f0d; --warning: #8f5e15;
    #|}
    #|[data-theme="dark"][data-color-scheme="tokyo"] {
    #|  --bg: #1a1b26; --bg-gradient: linear-gradient(180deg, #1a1b26 0%, #24283b 100%); --panel: #24283b; --panel-alpha: rgba(36, 40, 59, 0.9); --panel-solid: #24283b; --card-bg: rgba(36, 40, 59, 0.96); --input-bg: #1a1b26; --border: #414868; --border-strong: #565f89; --accent: #7aa2f7; --accent-strong: #7dcfff; --accent-2: #bb9af7; --accent-soft: rgba(122, 162, 247, 0.16); --text: #c0caf5; --text-inverse: #1a1b26; --muted: #9aa5ce; --comment: #e0af68; --badge: #7aa2f7; --table-bg: #24283b; --row-even: rgba(65, 72, 104, 0.45); --row-odd: rgba(26, 27, 38, 0.35); --selected-bg: rgba(122, 162, 247, 0.22); --hover-bg: rgba(122, 162, 247, 0.12); --code-bg: #1a1b26; --error: #f7768e; --success: #9ece6a; --warning: #e0af68;
    #|}
    #|[data-theme="light"][data-color-scheme="catppuccin"] {
    #|  --bg: #eff1f5; --bg-gradient: linear-gradient(180deg, #eff1f5 0%, #e6e9ef 100%); --panel: #eff1f5; --panel-alpha: rgba(239, 241, 245, 0.92); --panel-solid: #eff1f5; --card-bg: rgba(239, 241, 245, 0.98); --input-bg: #e6e9ef; --border: #ccd0da; --border-strong: #9ca0b0; --accent: #8839ef; --accent-strong: #4c4f69; --accent-2: #8839ef; --accent-soft: rgba(136, 57, 239, 0.12); --text: #4c4f69; --text-inverse: #eff1f5; --muted: #5c5f77; --comment: #df8e1d; --badge: #8839ef; --table-bg: #eff1f5; --row-even: #e6e9ef; --row-odd: #eff1f5; --selected-bg: rgba(136, 57, 239, 0.18); --hover-bg: rgba(136, 57, 239, 0.10); --code-bg: #e6e9ef; --error: #d20f39; --success: #40a02b; --warning: #df8e1d;
    #|}
    #|[data-theme="dark"][data-color-scheme="catppuccin"] {
    #|  --bg: #1e1e2e; --bg-gradient: linear-gradient(180deg, #1e1e2e 0%, #313244 100%); --panel: #313244; --panel-alpha: rgba(49, 50, 68, 0.9); --panel-solid: #313244; --card-bg: rgba(49, 50, 68, 0.96); --input-bg: #1e1e2e; --border: #45475a; --border-strong: #6c7086; --accent: #89b4fa; --accent-strong: #b4befe; --accent-2: #cba6f7; --accent-soft: rgba(137, 180, 250, 0.16); --text: #cdd6f4; --text-inverse: #1e1e2e; --muted: #a6adc8; --comment: #fab387; --badge: #89b4fa; --table-bg: #313244; --row-even: rgba(69, 71, 90, 0.45); --row-odd: rgba(30, 30, 46, 0.35); --selected-bg: rgba(137, 180, 250, 0.22); --hover-bg: rgba(137, 180, 250, 0.12); --code-bg: #1e1e2e; --error: #f38ba8; --success: #a6e3a1; --warning: #f9e2af;
    #|}
    #|[data-theme="light"][data-color-scheme="one-dark"] {
    #|  --bg: #fafafa; --bg-gradient: linear-gradient(180deg, #fafafa 0%, #f0f0f0 100%); --panel: #ffffff; --panel-alpha: rgba(255, 255, 255, 0.92); --panel-solid: #ffffff; --card-bg: rgba(255, 255, 255, 0.98); --input-bg: #f0f0f0; --border: #d0d0d0; --border-strong: #a0a1a7; --accent: #4078f2; --accent-strong: #383a42; --accent-2: #0184bc; --accent-soft: rgba(64, 120, 242, 0.12); --text: #383a42; --text-inverse: #0d1117; --muted: #696c77; --comment: #986801; --badge: #4078f2; --table-bg: #ffffff; --row-even: #f0f0f0; --row-odd: #ffffff; --selected-bg: rgba(64, 120, 242, 0.18); --hover-bg: rgba(64, 120, 242, 0.10); --code-bg: #f0f0f0; --error: #e45649; --success: #50a14f; --warning: #c18401;
    #|}
    #|[data-theme="dark"][data-color-scheme="one-dark"] {
    #|  --bg: #282c34; --bg-gradient: linear-gradient(180deg, #282c34 0%, #21252b 100%); --panel: #21252b; --panel-alpha: rgba(33, 37, 43, 0.9); --panel-solid: #21252b; --card-bg: rgba(33, 37, 43, 0.96); --input-bg: #282c34; --border: #3e4451; --border-strong: #5c6370; --accent: #61afef; --accent-strong: #56b6c2; --accent-2: #c678dd; --accent-soft: rgba(97, 175, 239, 0.16); --text: #abb2bf; --text-inverse: #282c34; --muted: #abb2bf; --comment: #d19a66; --badge: #61afef; --table-bg: #21252b; --row-even: rgba(62, 68, 81, 0.45); --row-odd: rgba(40, 44, 52, 0.35); --selected-bg: rgba(97, 175, 239, 0.22); --hover-bg: rgba(97, 175, 239, 0.12); --code-bg: #282c34; --error: #e06c75; --success: #98c379; --warning: #e5c07b;
    #|}
    #|[data-theme="light"][data-color-scheme="solarized"] {
    #|  --bg: #fdf6e3; --bg-gradient: linear-gradient(180deg, #fdf6e3 0%, #eee8d5 100%); --panel: #fdf6e3; --panel-alpha: rgba(253, 246, 227, 0.92); --panel-solid: #fdf6e3; --card-bg: rgba(253, 246, 227, 0.98); --input-bg: #eee8d5; --border: #d8d1b8; --border-strong: #93a1a1; --accent: #b58900; --accent-strong: #073642; --accent-2: #859900; --accent-soft: rgba(181, 137, 0, 0.14); --text: #586e75; --text-inverse: #002b36; --muted: #586e75; --comment: #cb4b16; --badge: #268bd2; --table-bg: #fdf6e3; --row-even: #eee8d5; --row-odd: #fdf6e3; --selected-bg: rgba(181, 137, 0, 0.20); --hover-bg: rgba(181, 137, 0, 0.12); --code-bg: #eee8d5; --error: #dc322f; --success: #859900; --warning: #b58900;
    #|}
    #|[data-theme="dark"][data-color-scheme="solarized"] {
    #|  --bg: #002b36; --bg-gradient: linear-gradient(180deg, #002b36 0%, #073642 100%); --panel: #073642; --panel-alpha: rgba(7, 54, 66, 0.9); --panel-solid: #073642; --card-bg: rgba(7, 54, 66, 0.96); --input-bg: #002b36; --border: #586e75; --border-strong: #839496; --accent: #b58900; --accent-strong: #93a1a1; --accent-2: #859900; --accent-soft: rgba(181, 137, 0, 0.18); --text: #93a1a1; --text-inverse: #002b36; --muted: #93a1a1; --comment: #cb4b16; --badge: #268bd2; --table-bg: #073642; --row-even: rgba(88, 110, 117, 0.32); --row-odd: rgba(0, 43, 54, 0.38); --selected-bg: rgba(181, 137, 0, 0.24); --hover-bg: rgba(181, 137, 0, 0.15); --code-bg: #002b36; --error: #dc322f; --success: #859900; --warning: #b58900;
    #|}
    #|[data-theme="light"][data-color-scheme="gruvbox"] {
    #|  --bg: #fbf1c7; --bg-gradient: linear-gradient(180deg, #fbf1c7 0%, #ebdbb2 100%); --panel: #fbf1c7; --panel-alpha: rgba(251, 241, 199, 0.92); --panel-solid: #fbf1c7; --card-bg: rgba(251, 241, 199, 0.98); --input-bg: #ebdbb2; --border: #d5c4a1; --border-strong: #928374; --accent: #d65d0e; --accent-strong: #3c3836; --accent-2: #98971a; --accent-soft: rgba(214, 93, 14, 0.14); --text: #3c3836; --text-inverse: #0d1117; --muted: #665c54; --comment: #af3a03; --badge: #458588; --table-bg: #fbf1c7; --row-even: #ebdbb2; --row-odd: #fbf1c7; --selected-bg: rgba(214, 93, 14, 0.20); --hover-bg: rgba(214, 93, 14, 0.12); --code-bg: #ebdbb2; --error: #cc241d; --success: #98971a; --warning: #d79921;
    #|}
    #|[data-theme="dark"][data-color-scheme="gruvbox"] {
    #|  --bg: #282828; --bg-gradient: linear-gradient(180deg, #282828 0%, #3c3836 100%); --panel: #3c3836; --panel-alpha: rgba(60, 56, 54, 0.9); --panel-solid: #3c3836; --card-bg: rgba(60, 56, 54, 0.96); --input-bg: #282828; --border: #504945; --border-strong: #928374; --accent: #d79921; --accent-strong: #ebdbb2; --accent-2: #98971a; --accent-soft: rgba(215, 153, 33, 0.18); --text: #ebdbb2; --text-inverse: #282828; --muted: #d5c4a1; --comment: #fe8019; --badge: #83a598; --table-bg: #3c3836; --row-even: rgba(80, 73, 69, 0.45); --row-odd: rgba(40, 40, 40, 0.35); --selected-bg: rgba(215, 153, 33, 0.24); --hover-bg: rgba(215, 153, 33, 0.14); --code-bg: #282828; --error: #fb4934; --success: #b8bb26; --warning: #fabd2f;
    #|}
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
    #|  cursor: help;
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
    #|.sse-dot::after {
    #|  content: attr(data-sse-hint);
    #|  position: absolute;
    #|  top: calc(100% + 8px);
    #|  left: 50%;
    #|  transform: translateX(-50%);
    #|  width: max-content;
    #|  max-width: 260px;
    #|  padding: 8px 10px;
    #|  border: 1px solid var(--border);
    #|  border-radius: var(--radius-sm);
    #|  background: var(--panel-solid);
    #|  color: var(--text);
    #|  font-size: 12px;
    #|  font-weight: 600;
    #|  line-height: 1.4;
    #|  letter-spacing: 0;
    #|  text-align: left;
    #|  white-space: normal;
    #|  box-shadow: var(--shadow-card);
    #|  opacity: 0;
    #|  pointer-events: none;
    #|  z-index: 40;
    #|  transition: opacity 120ms ease;
    #|}
    #|.sse-dot:hover::after, .sse-dot:focus-visible::after { opacity: 1; }
    #|@keyframes sseBlink { 0%, 100% { opacity: 1; } 50% { opacity: 0.35; } }
    #|
    #|.wrap {
    #|  padding: 0 16px 12px;
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
    #|/* Breathing room via offset shadows, not layout padding: a uniform 6px
    #|   spread hung left of the first glyph and missed the comment dialog's
    #|   left edge. Skip the left side so the glyph, highlight, and dialog share
    #|   one x. List ::marker still does not move. */
    #|.preview-highlight {
    #|  background: var(--selected-bg) !important;
    #|  outline: none;
    #|  box-shadow:
    #|    0 -6px 0 0 var(--selected-bg),
    #|    6px 0 0 0 var(--selected-bg),
    #|    0 6px 0 0 var(--selected-bg);
    #|  border-radius: 4px;
    #|  transition: background 150ms ease;
    #|}
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
    #|.yunomi-inline-comment {
    #|  box-sizing: border-box;
    #|  width: min(100%, calc(var(--review-loop-sidebar-width) * 1.5));
    #|  min-width: min(100%, var(--review-loop-sidebar-width));
    #|  max-width: 100%;
    #|  margin: 8px 0 12px;
    #|  padding: 10px 12px;
    #|  border: 1px solid var(--border);
    #|  border-radius: var(--radius-sm);
    #|  background: var(--panel);
    #|  color: var(--text);
    #|  font-family: var(--font-ui);
    #|}
    #|tr.yunomi-inline-comment { width: auto; min-width: 0; margin: 0; padding: 0; border: 0; background: transparent; }
    #|tr.yunomi-inline-comment > td { padding: 8px 12px; background: var(--panel); }
    #|.yunomi-inline-comment-view {
    #|  all: unset;
    #|  box-sizing: border-box;
    #|  display: grid;
    #|  gap: 8px;
    #|  width: 100%;
    #|  min-width: 0;
    #|  cursor: pointer;
    #|}
    #|.yunomi-inline-comment-view:hover .yunomi-inline-comment-text { filter: brightness(1.04); }
    #|.yunomi-inline-comment-view:focus-visible { outline: 2px solid var(--accent); outline-offset: 2px; }
    #|.yunomi-inline-comment-label { color: var(--muted); font-size: 12px; font-weight: 800; }
    #|.yunomi-inline-comment-pending { display: inline-flex; align-self: center; justify-self: start; margin: 0; padding: 1px 6px; border: 1px solid var(--border-strong); border-radius: var(--radius-pill); color: var(--accent-strong); font-size: 10px; font-weight: 700; }
    #|.yunomi-inline-comment-text { display: grid; gap: 3px; min-width: 0; padding: 8px 10px; border-radius: var(--radius-sm); background: var(--accent-soft); overflow-wrap: anywhere; font-size: 13px; line-height: 1.55; box-sizing: border-box; }
    #|.yunomi-inline-comment-text > .review-loop-markdown { margin: 0; font-size: inherit; line-height: inherit; }
    #|.yunomi-inline-comment-image { display: block; max-width: 180px; max-height: 120px; object-fit: contain; border-radius: var(--radius-sm); }
    #|.yunomi-inline-comment-editor { display: grid; gap: 10px; }
    #|:is(td, th) .yunomi-inline-comment-editor { margin-right: 0; }
    #|tr.yunomi-inline-comment-editor-mount { padding: 0; }
    #|tr.yunomi-inline-comment-editor-mount > td { padding: 8px 12px; }
    #|tr.yunomi-inline-comment-editor-mount .yunomi-inline-comment-editor { margin: 0; border: 0; box-shadow: none; padding: 0; }
    #|li.yunomi-inline-comment { margin: 6px 0 12px; list-style: none; }
    #|li.yunomi-inline-comment-editor-mount { margin: 6px 0 12px; padding: 0; list-style: none; }
    #|.yunomi-inline-comment-context { position: absolute; width: 1px; height: 1px; overflow: hidden; clip: rect(0, 0, 0, 0); }
    #|.yunomi-inline-comment-editor .review-loop-reply-form { padding-top: 0; border-top: 0; }
    #|.yunomi-inline-comment-editor .review-loop-reply-preview:not(:has(.image-preview-item, img)) { display: none; }
    #|.yunomi-inline-comment-editor .review-loop-reply-actions { flex-wrap: nowrap; gap: 8px; min-width: 0; }
    #|.yunomi-inline-comment-action-start { display: flex; align-items: center; gap: 6px; flex: 0 0 auto; }
    #|.yunomi-inline-comment-action-group { display: flex; align-items: center; justify-content: flex-end; flex-wrap: nowrap; gap: 6px; min-width: 0; }
    #|.yunomi-inline-comment-action-group button { white-space: nowrap; padding: 0 8px; }
    #|.send-now-btn {
    #|  border: 1px solid var(--border);
    #|  background: var(--button-bg);
    #|  color: var(--text);
    #|  padding: 8px 12px;
    #|  font-weight: 700;
    #|  cursor: pointer;
    #|}
    #|.send-now-btn:hover {
    #|  background: var(--hover-bg);
    #|  border-color: var(--border-strong);
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
    #|.comments-popover-anchor { display: inline-flex; align-items: center; anchor-name: --yunomi-comments-trigger; }
    #|.comment-list {
    #|  position: fixed;
    #|  position-anchor: --yunomi-comments-trigger;
    #|  top: 56px;
    #|  right: 16px;
    #|  top: calc(anchor(bottom, 48px) + 8px);
    #|  right: anchor(right, 16px);
    #|  bottom: auto;
    #|  width: min(320px, calc(100vw - 24px));
    #|  max-height: 60vh;
    #|  overflow: auto;
    #|  border: 1px solid var(--border);
    #|  border-radius: 12px;
    #|  background: var(--card-bg);
    #|  box-shadow: 0 18px 40px var(--shadow-color);
    #|  padding: 12px;
    #|  backdrop-filter: blur(6px);
    #|  transition: opacity 120ms ease, transform 120ms ease, background 200ms ease;
    #|  z-index: 90;
    #|}
    #|.comment-list-header { display: flex; align-items: center; justify-content: space-between; gap: 8px; margin-bottom: 8px; }
    #|.comment-list h3 { margin: 0; font-size: 13px; color: var(--muted); }
    #|.comment-list-minimize { display: inline-grid; place-items: center; width: 28px; height: 28px; padding: 0; border: 1px solid var(--border); border-radius: var(--radius-sm); background: var(--button-bg); color: var(--muted); font-size: 16px; font-weight: 600; line-height: 1; cursor: pointer; }
    #|.comment-list-minimize:hover, .comment-list-minimize:focus-visible { background: var(--hover-bg); color: var(--text); }
    #|.comment-list ol {
    #|  margin: 0;
    #|  padding-left: 18px;
    #|  color: var(--text);
    #|  font-size: 13px;
    #|  line-height: 1.45;
    #|}
    #|.comment-list li { margin-bottom: 6px; }
    #|.comment-inline-replies {
    #|  margin: 6px 0 0;
    #|  padding-left: 0;
    #|  display: grid;
    #|  gap: 4px;
    #|  list-style: none;
    #|  color: var(--muted);
    #|  font-size: 12px;
    #|}
    #|.comment-inline-replies li {
    #|  margin: 0;
    #|  padding: 5px 7px;
    #|  border: 1px solid var(--border);
    #|  border-radius: var(--radius-sm);
    #|  background: var(--panel);
    #|}
    #|.comment-inline-replies strong { color: var(--accent-strong); }
    #|.comment-list .hint { color: var(--muted); font-size: 12px; }
    #|.pill { display: inline-flex; align-items: center; gap: 6px; padding: 5px 12px; border-radius: var(--radius-pill); background: var(--accent-soft); border: 1px solid transparent; font-size: 12px; font-weight: 500; color: var(--accent-strong); cursor: pointer; transition: background 160ms ease, border-color 160ms ease, transform 120ms ease; }
    #|.pill:hover { background: var(--hover-bg); border-color: var(--border-strong); transform: translateY(-1px); }
    #|.pill strong { color: var(--accent-strong); font-weight: 700; }
    #|.review-loop-header-badge { display: none; align-items: center; max-width: 220px; min-height: 30px; padding: 4px 10px; border: 1px solid var(--border); border-radius: var(--radius-pill); background: var(--panel); color: var(--muted); font-size: 12px; font-weight: 700; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
    #|.review-loop-header-badge.ready { border-color: var(--accent); background: var(--accent-soft); color: var(--accent-strong); }
    #|/* Unresolved comments sit immediately left of the unread (red) counter.
    #|   ID selectors beat `header button { min-height: 34px }`, which otherwise
    #|   stretched these into vertical ovals. */
    #|#conversation-unresolved,
    #|#conversation-unread {
    #|  display: inline-grid;
    #|  place-items: center;
    #|  box-sizing: border-box;
    #|  flex: 0 0 auto;
    #|  align-self: center;
    #|  width: 22px;
    #|  height: 22px;
    #|  min-width: 22px;
    #|  min-height: 22px;
    #|  max-width: none;
    #|  max-height: 22px;
    #|  padding: 0;
    #|  border: 0;
    #|  border-radius: 50%;
    #|  font-size: 11px;
    #|  font-weight: 700;
    #|  line-height: 1;
    #|  cursor: pointer;
    #|  box-shadow: none;
    #|  -webkit-font-smoothing: antialiased;
    #|}
    #|#conversation-unresolved { margin: 0 6px 0 0; background: #f5c518; color: #3b2300; }
    #|#conversation-unresolved[hidden] { display: none; }
    #|#conversation-unresolved:hover { filter: none; background: #e8b80f; }
    #|.review-loop-inline.is-unresolved-flash,
    #|.review-loop-comment.is-unresolved-flash,
    #|.review-loop-conversation.is-unresolved-flash { animation: unresolved-comment-flash 1.5s ease-out 1; }
    #|@keyframes unresolved-comment-flash { 0% { box-shadow: 0 0 0 3px rgba(245, 197, 24, 0.9); } 100% { box-shadow: none; } }
    #|#conversation-unread { margin: 0; background: #e5484d; color: #fff; }
    #|#conversation-unread[hidden] { display: none; }
    #|#conversation-unread:hover { filter: brightness(1.08); background: #e5484d; border-color: transparent; }
    #|.conversation-unread.is-pulse { animation: conversation-unread-pulse 600ms ease-out 1; }
    #|@keyframes conversation-unread-pulse { 0% { transform: scale(1); } 40% { transform: scale(1.25); } 100% { transform: scale(1); } }
    #|/* Unread messages carry no per-message decoration (no side bar); the
    #|   badge, the chat dot and the click-to-read flash are the only cues. */
    #|.review-loop-thread-line.is-flash, .review-loop-conversation-message.is-flash { animation: conversation-flash 1.5s ease-out 1; }
    #|@keyframes conversation-flash { 0% { background: rgba(229, 72, 77, 0.28); } 100% { background: transparent; } }
    #|/* Red dot on the bottom-right chat: shown when an agent message has not
    #|   been seen yet (collapsed panel or hidden tab). */
    #|.review-loop-unread-dot { position: absolute; top: 2px; right: 2px; width: 9px; height: 9px; border-radius: 50%; background: #e5484d; box-shadow: 0 0 0 2px var(--panel-solid, var(--panel)); pointer-events: none; }
    #|.review-loop-unread-dot[hidden] { display: none; }
    #|/* Draft-restored notice: bottom-left so it never covers the chat. */
    #|.yunomi-restore-toast { position: fixed; left: 16px; bottom: 16px; z-index: 99998; display: inline-flex; align-items: center; gap: 10px; padding: 8px 10px 8px 14px; border: 1px solid var(--border); border-radius: var(--radius-pill); background: var(--panel-solid, var(--panel)); color: var(--text); font-size: 12px; font-weight: 600; box-shadow: 0 6px 20px rgba(0, 0, 0, 0.18); animation: conversation-unread-pulse 400ms ease-out 1; }
    #|.yunomi-restore-toast.is-leaving { opacity: 0; transition: opacity 400ms ease; }
    #|.yunomi-restore-discard { padding: 3px 9px; border: 1px solid var(--border); border-radius: var(--radius-pill); background: transparent; color: var(--muted); font-size: 11px; font-weight: 600; cursor: pointer; }
    #|.yunomi-restore-discard:hover { color: var(--error); border-color: var(--error); }
    #|.review-loop-sidebar-toggle { position: relative; }
    #|/* Must out-specify the sidebar rule below (id+class), or an empty review
    #|   still reserves 300px and squeezes the preview. */
    #|#review-loop-panel:empty, #review-loop-panel.review-loop-sidebar:empty { display: none; }
    #|#review-loop-panel.review-loop-sidebar {
    #|  order: 4;
    #|  flex: 0 0 calc(var(--review-loop-sidebar-width) * 1.5);
    #|  width: min(calc(var(--review-loop-sidebar-width) * 1.5), calc(100vw - var(--review-loop-sidebar-offset) * 2));
    #|  min-width: min(var(--review-loop-sidebar-width), calc(100vw - var(--review-loop-sidebar-offset) * 2));
    #|  max-width: calc(100vw - var(--review-loop-sidebar-offset) * 2);
    #|  height: min(60vh, calc(100vh - var(--review-loop-sidebar-offset) * 2));
    #|  max-height: calc(100vh - var(--review-loop-sidebar-offset) * 2);
    #|  position: fixed;
    #|  top: auto;
    #|  right: var(--review-loop-sidebar-offset);
    #|  bottom: var(--review-loop-sidebar-offset);
    #|  z-index: 80;
    #|  overflow: hidden;
    #|  resize: horizontal;
    #|  margin: 0;
    #|  padding: 10px;
    #|  border: 1px solid var(--border);
    #|  border-radius: var(--radius-sm);
    #|  background: var(--panel-solid);
    #|  color: var(--text);
    #|  display: grid;
    #|  grid-template-rows: minmax(0, 1fr);
    #|  gap: 8px;
    #|  box-shadow: var(--shadow-card);
    #|  transition: none;
    #|}
    #|/* The fixed chat is always present, but empty panel space must not block
    #|   document editors underneath it. Inputs, messages, and the header keep
    #|   their own hit targets. */
    #|#review-loop-panel.review-loop-sidebar { pointer-events: none; }
    #|#review-loop-panel.review-loop-sidebar .review-loop-header,
    #|#review-loop-panel.review-loop-sidebar .review-loop-conversation-message,
    #|#review-loop-panel.review-loop-sidebar .review-loop-reply-form,
    #|#review-loop-panel.review-loop-sidebar .review-loop-sidebar-toggle { pointer-events: auto; }
    #|#review-loop-panel.review-loop-sidebar .review-loop-conversation-stream:has(.review-loop-conversation-message) { pointer-events: auto; }
    #|#review-loop-panel.review-loop-sidebar .review-loop-jump-latest.is-visible { pointer-events: auto; }
    #|#review-loop-panel.review-loop-sidebar.review-loop-sidebar-collapsed {
    #|  flex-basis: 40px;
    #|  width: 40px;
    #|  min-width: 40px;
    #|  max-width: 40px;
    #|  height: 40px;
    #|  max-height: 40px;
    #|  padding: 0;
    #|  border: 0;
    #|  background: transparent;
    #|  box-shadow: none;
    #|  overflow: hidden;
    #|  resize: none;
    #|  transition: none;
    #|}
    #|.review-loop-details { display: flex; flex-direction: column; gap: 6px; height: 100%; min-height: 0; overflow: hidden; }
    #|/* Keep the tea icon and minimize toggle aligned at narrow widths. */
    #|.review-loop-header { display: grid; grid-template-columns: minmax(0, 1fr) auto; align-items: center; gap: 8px; min-height: 28px; font-size: 12px; font-weight: 700; }
    #|.review-loop-header-main { min-width: 0; font-size: 12px; white-space: nowrap; }
    #|.review-loop-meta { min-width: 0; color: var(--muted); font-weight: 600; font-size: 11px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
    #|.review-loop-sidebar-mini-count { display: none; }
    #|.review-loop-sidebar-toggle { display: inline-grid; place-items: center; width: 28px; height: 28px; padding: 0; border: 1px solid var(--border); border-radius: var(--radius-sm); background: var(--button-bg); color: var(--muted); cursor: pointer; }
    #|.review-loop-sidebar-toggle:hover { background: var(--hover-bg); color: var(--text); }
    #|#review-loop-panel.review-loop-sidebar-collapsed .review-loop-header { justify-content: center; gap: 2px; }
    #|#review-loop-panel.review-loop-sidebar-collapsed .review-loop-header-main, #review-loop-panel.review-loop-sidebar-collapsed .review-loop-meta, #review-loop-panel.review-loop-sidebar-collapsed .review-loop-body { display: none; }
    #|#review-loop-panel.review-loop-sidebar-collapsed .review-loop-sidebar-mini-count { display: none; }
    #|#review-loop-panel.review-loop-sidebar-collapsed .review-loop-sidebar-toggle { display: inline-grid; place-items: center; width: 40px; height: 40px; }
    #|.review-loop-sidebar-toggle svg { display: block; width: 16px; height: 16px; }
    #|.review-loop-body { display: flex; flex: 1 1 auto; flex-direction: column; gap: 6px; min-height: 0; overflow: hidden; }
    #|.review-loop-sidebar-card { border: 1px solid var(--border); border-radius: var(--radius-sm); padding: 10px; background: var(--panel); }
    #|.review-loop-list { margin: 0; padding-left: 0; list-style: none; display: grid; gap: 8px; color: var(--text); font-size: 13px; line-height: 1.45; }
    #|/* Set the size on the card itself: the fallback list is not a
    #|   .review-loop-list child, so inheriting left its text at the 16px
    #|   browser default while every neighbouring card sat at 12px. */
    #|.review-loop-comment { display: grid; gap: 8px; background: transparent; font-size: 13px; line-height: 1.5; }
    #|.review-loop-sidebar-card, .review-loop-sidebar-card .review-loop-comment { font-size: 12px; }
    #|/* Match the index rows: same size, weight and colour for the location. */
    #|.review-loop-sidebar-card .review-loop-comment-head > strong { font-weight: 600; color: var(--muted); }
    #|.review-loop-comment:focus { outline: 2px solid var(--accent); outline-offset: 4px; border-radius: var(--radius-sm); }
    #|/* One row, always: the file name truncates instead of wrapping the number
    #|   and the Resolve button onto lines of their own. */
    #|.review-loop-comment-head { display: grid; grid-template-columns: auto minmax(0, 1fr); align-items: center; gap: 7px; min-height: 24px; color: var(--muted); font-size: 12px; }
    #|.review-loop-comment-head > strong { min-width: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
    #|.review-loop-comment-head strong { color: var(--text); font-size: 12px; font-weight: 800; }
    #|.review-loop-actions { display: flex; justify-content: flex-end; margin-left: auto; }
    #|.review-loop-resolved { color: var(--muted); font-size: 12px; }
    #|.review-loop-thread-actions { display: flex; justify-content: flex-end; padding-top: 6px; }
    #|.review-loop-resolve { height: 28px; padding: 0 12px; border: 1px solid var(--border); border-radius: var(--radius-sm); background: var(--button-bg); color: var(--text); font-family: inherit; font-size: 12px; font-weight: 600; cursor: pointer; transition: background 160ms ease, border-color 160ms ease, color 160ms ease; }
    #|.review-loop-resolve:hover { background: var(--hover-bg); border-color: var(--border-strong); color: var(--text); }
    #|.review-loop-reply-form button[type="submit"] { height: 28px; padding: 0 12px; border: 1px solid var(--accent-fill); border-radius: var(--radius-sm); background: var(--accent-fill); color: var(--on-accent); font-family: inherit; font-size: 12px; font-weight: 600; cursor: pointer; transition: background 160ms ease, border-color 160ms ease, color 160ms ease; }
    #|.review-loop-reply-form button[type="submit"]:hover { background: color-mix(in srgb, var(--accent-fill) 86%, #000000); border-color: color-mix(in srgb, var(--accent-fill) 86%, #000000); color: var(--on-accent); }
    #|.yunomi-inline-comment-action-group button, .yunomi-inline-comment-action-start button { height: 28px; padding: 0 8px; border: 1px solid transparent; border-radius: var(--radius-sm); font-family: inherit; font-size: 12px; font-weight: 600; white-space: nowrap; cursor: pointer; transition: background 160ms ease, border-color 160ms ease, color 160ms ease; }
    #|.yunomi-inline-comment-action-start button[data-action="cancel"] { background: transparent; color: var(--muted); }
    #|.yunomi-inline-comment-action-start button[data-action="cancel"]:hover { background: var(--hover-bg); color: var(--text); }
    #|.yunomi-inline-comment-editor .review-loop-reply-attach { background: var(--input-bg); }
    #|#send-now-comment { background: var(--accent-fill); border-color: var(--accent-fill); color: var(--on-accent); }
    #|#send-now-comment:hover { background: color-mix(in srgb, var(--accent-fill) 86%, #000000); border-color: color-mix(in srgb, var(--accent-fill) 86%, #000000); color: var(--on-accent); }
    #|#save-comment { background: var(--accent-soft); border-color: var(--accent); color: var(--accent-strong); }
    #|#save-comment:hover { background: var(--hover-bg); border-color: var(--accent-strong); color: var(--accent-strong); }
    #|/* 15px = status dot (8px) + its gap (7px), so the quote and the thread
    #|   line up with the file name instead of stepping left or right. */
    #|.review-loop-snippet { border: 0; display: grid; gap: 4px; padding: 0 0 0 15px; background: transparent; }
    #|.review-loop-submit-state { display: none; margin: 0 0 10px; padding: 7px 9px; border: 1px solid var(--border); border-radius: var(--radius-sm); background: var(--panel); color: var(--text); font-size: 13px; font-weight: 600; }
    #|.review-loop-submit-state.ready { background: var(--accent-soft); color: var(--accent-strong); border-color: var(--accent); }
    #|.review-loop-status-dot { width: 8px; height: 8px; flex: 0 0 auto; border-radius: 50%; background: var(--accent); }
    #|.review-loop-card-number { display: inline-grid; place-items: center; min-width: 16px; height: 16px; border-radius: var(--radius-pill); background: var(--accent-soft); color: var(--accent-strong); font-size: 11px; font-weight: 800; }
    #|.review-loop-status-check { color: var(--muted); font-size: 14px; font-weight: 400; line-height: 1; }
    #|.review-loop-snippet { gap: 4px; }
    #|.review-loop-quote { margin: 0; padding: 0 0 0 10px; border-left: 2px solid var(--border-strong); color: var(--text); font-family: var(--font-mono); font-size: 12px; line-height: 1.5; white-space: pre-wrap; overflow-wrap: anywhere; }
    #|.review-loop-change { color: var(--muted); font-family: var(--font-mono); font-size: 12px; overflow-wrap: anywhere; }
    #|.review-loop-thread { display: grid; gap: 8px; padding-left: 15px; }
    #|.review-loop-thread-line { display: grid; gap: 3px; min-width: 0; padding: 8px 10px; border-radius: var(--radius-sm); background: var(--bg); overflow-wrap: anywhere; }
    #|.review-loop-thread-line.is-human { margin-left: 16px; width: calc(100% - 16px); max-width: calc(100% - 16px); box-sizing: border-box; background: var(--accent-soft); }
    #|.review-loop-thread-line.is-agent { margin-right: 16px; }
    #|.review-loop-thread-line > p,
    #|.review-loop-thread-line > .review-loop-markdown,
    #|.review-loop-thread-line > .review-loop-markdown-code { margin: 0; font-size: inherit; line-height: 1.55; }
    #|.review-loop-conversation { display: flex; flex: 1 1 auto; flex-direction: column; gap: 8px; min-width: 0; min-height: 0; overflow: hidden; color: var(--text); font-size: 12px; }
    #|.review-loop-conversation[hidden] { display: none; }
    #|.review-loop-conversation-head { display: grid; grid-template-columns: minmax(0, 1fr) auto; align-items: center; gap: 6px; padding-bottom: 5px; }
    #|.review-loop-conversation-head > strong { font-size: 12px; font-weight: 800; }
    #|.review-loop-conversation-scroller { position: relative; display: flex; flex: 1 1 auto; flex-direction: column; min-width: 0; min-height: 0; }
    #|.review-loop-conversation-stream { display: grid; flex: 1 1 auto; align-content: start; gap: 8px; min-width: 0; min-height: 0; overflow-y: auto; }
    #|.review-loop-jump-latest { position: absolute; right: 8px; bottom: 8px; z-index: 2; display: inline-grid; place-items: center; width: 28px; height: 28px; padding: 0; border: 1px solid var(--border); border-radius: var(--radius-pill); background: var(--panel-solid); color: var(--accent-strong); box-shadow: var(--shadow-soft); cursor: pointer; opacity: 0; pointer-events: none; transform: translateY(6px); transition: opacity 120ms ease, transform 120ms ease; }
    #|.review-loop-jump-latest.is-visible { opacity: 1; pointer-events: auto; transform: none; }
    #|.review-loop-jump-latest:hover { background: var(--hover-bg); color: var(--text); }
    #|.review-loop-jump-latest svg { display: block; width: 16px; height: 16px; }
    #|.review-loop-conversation-message { display: grid; gap: 3px; min-width: 0; padding: 8px 10px; border-radius: var(--radius-sm); background: var(--bg); }
    #|.review-loop-conversation-message.is-human { margin-left: 16px; background: var(--accent-soft); }
    #|.review-loop-conversation-message.is-agent { margin-right: 16px; }
    #|.review-loop-conversation-message > p,
    #|.review-loop-conversation-message > .review-loop-markdown { margin: 0; color: var(--text); font-size: 12px; line-height: 1.55; overflow-wrap: anywhere; }
    #|.review-loop-markdown strong { font-weight: 700; }
    #|.review-loop-markdown em { font-style: italic; }
    #|.review-loop-markdown code { font-family: var(--font-mono, ui-monospace, SFMono-Regular, Menlo, monospace); font-size: 0.92em; background: var(--code-bg); padding: 1px 4px; border-radius: 4px; }
    #|.review-loop-markdown ul { margin: 4px 0 0; padding-left: 1.2em; }
    #|.review-loop-markdown a { color: var(--accent); }
    #|.review-loop-markdown-code { margin: 4px 0 0; padding: 8px; max-height: 160px; overflow: auto; background: var(--code-bg); border: 1px solid var(--border); border-radius: var(--radius-sm); font-size: 11px; line-height: 1.45; white-space: pre-wrap; }
    #|.review-loop-conversation-image { display: block; width: auto; max-width: 100%; max-height: 180px; margin-top: 3px; border: 1px solid var(--border); border-radius: var(--radius-sm); object-fit: contain; }
    #|.review-loop-resolved-list, .review-loop-fallback-list { margin: 0; padding: 0; list-style: none; display: grid; gap: 5px; }
    #|.review-loop-resolved-list { margin-top: 8px; }
    #|.review-loop-fallback, .review-loop-resolved-item { display: grid; gap: 4px; min-width: 0; color: var(--muted); font-size: 12px; line-height: 1.4; }
    #|.review-loop-fallback { cursor: pointer; color: var(--text); }
    #|.review-loop-fallback:hover, .review-loop-fallback:focus { background: var(--hover-bg); outline: 0; }
    #|/* Two 1fr columns in a 276px sidebar truncated both the file name and the
    #|   note, so the note gets its own line under the location. */
    #|.review-loop-fallback-head { display: grid; grid-template-columns: auto auto minmax(0, 1fr) auto; grid-template-areas: "num dot loc action" "note note note note"; align-items: center; column-gap: 7px; row-gap: 2px; min-width: 0; }
    #|.review-loop-fallback-head > .review-loop-card-number { grid-area: num; }
    #|.review-loop-fallback-head > .review-loop-status-dot { grid-area: dot; }
    #|.review-loop-fallback-head > .review-loop-fallback-location { grid-area: loc; }
    #|.review-loop-fallback-head > .review-loop-actions { grid-area: action; }
    #|.review-loop-fallback-head > .review-loop-fallback-note { grid-area: note; padding-left: 30px; font-size: 11px; }
    #|.review-loop-resolved-item { display: grid; grid-template-columns: auto auto minmax(0, 1fr) auto; align-items: center; gap: 7px; min-width: 0; }
    #|.review-loop-fallback-note { min-width: 0; color: var(--muted); overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
    #|.review-loop-fallback-location, .review-loop-resolved-location { min-width: 0; color: var(--muted); font-family: var(--font-mono); font-weight: 600; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
    #|.review-loop-fallback-text { margin: 0; padding-left: 30px; color: var(--text); font-size: 12px; line-height: 1.55; overflow-wrap: anywhere; }
    #|.review-loop-resolved-item { color: var(--muted); opacity: .76; }
    #|.review-loop-resolved-text { min-width: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
    #|.review-loop-sidebar-card.is-resolved { background: var(--bg); border-color: var(--border); color: var(--muted); opacity: .76; }
    #|.review-loop-reply-form { display: grid; gap: 10px; padding-top: 10px; border-top: 1px solid var(--border); }
    #|#review-loop-panel .review-loop-conversation > .review-loop-reply-form { flex: 0 0 auto; background: var(--panel-solid); }
    #|.review-loop-reply-form textarea, .review-loop-reply-form input { box-sizing: border-box; width: 100%; min-width: 0; padding: 7px; border: 1px solid var(--border); border-radius: var(--radius-sm); background: var(--bg); color: var(--text); font: inherit; line-height: 1.45; resize: vertical; }
    #|.review-loop-reply-preview:empty { display: none; }
    #|.review-loop-reply-preview > div { display: grid; justify-items: start; gap: 4px; }
    #|.review-loop-reply-preview img { display: block; max-width: 100%; max-height: 120px; border: 1px solid var(--border); border-radius: var(--radius-sm); object-fit: contain; }
    #|.review-loop-reply-remove { padding: 0; border: 0; background: transparent; color: var(--muted); font: inherit; font-size: 11px; cursor: pointer; }
    #|.review-loop-reply-remove:hover { color: var(--text); text-decoration: underline; }
    #|.review-loop-reply-actions { display: flex; align-items: center; justify-content: space-between; gap: 10px; }
    #|.review-loop-reply-attach { position: relative; display: inline-grid; place-items: center; width: 28px; height: 28px; padding: 0; border: 1px solid var(--border); border-radius: var(--radius-sm); background: var(--button-bg); color: var(--muted); cursor: pointer; }
    #|.review-loop-reply-attach svg { display: block; width: 16px; height: 16px; }
    #|.review-loop-reply-attach:hover { background: var(--hover-bg); color: var(--text); }
    #|.review-loop-reply-attach:focus-within { outline: 2px solid var(--accent); outline-offset: 1px; }
    #|.review-loop-reply-file { position: absolute; width: 1px; height: 1px; overflow: hidden; opacity: 0; }
    #|#review-loop-panel .review-loop-reply-form :focus-visible { outline-offset: -2px; }
    #|#review-loop-panel .review-loop-reply-attach:focus-within { outline-offset: -2px; }
    #|.review-loop-inline { box-sizing: border-box; width: min(100%, calc(var(--review-loop-sidebar-width) * 1.5)); min-width: min(100%, var(--review-loop-sidebar-width)); max-width: 100%; margin: 8px 0 12px; padding: 10px 12px; border: 1px solid var(--border); border-radius: var(--radius-sm); background: var(--panel); color: var(--text); overflow: hidden; resize: horizontal; }
    #|.review-loop-inline-item { list-style: none; margin: 0; padding: 0; background: var(--panel); }
    #|.preview-highlight + .review-loop-inline-item .review-loop-inline { background: var(--panel); border-color: var(--border); }
    #|.review-loop-inline .review-loop-comment { padding: 0; }
    #|.review-loop-inline .review-loop-comment:last-child { padding-bottom: 0; }
    #|#md-preview :is(.yunomi-inline-comment, .review-loop-inline) {
    #|  margin-right: calc(var(--review-loop-sidebar-width) * 1.5 + var(--review-loop-sidebar-offset));
    #|}
    #|#md-preview :is(td, th) .yunomi-inline-comment { margin-right: 0; width: 100%; min-width: 0; }
    #|.review-loop-inline-highlight { animation: review-loop-inline-highlight 1.2s ease-out; }
    #|@keyframes review-loop-inline-highlight { from { box-shadow: 0 0 0 4px var(--accent-soft); border-color: var(--accent); } to { box-shadow: none; border-color: var(--border); } }
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
    #|.md-preview .footnotes { margin-top: 28px; padding-top: 14px; border-top: 1px solid var(--border); color: var(--muted); font-size: 0.92em; }
    #|.md-preview .footnotes ol { margin: 0; padding-left: 22px; }
    #|.md-preview .footnotes li { margin: 6px 0; }
    #|.md-preview .footnote-ref { margin-left: 2px; font-size: 0.78em; }
    #|.md-layout {
    #|  display: flex;
    #|  gap: 16px;
    #|  align-items: stretch;
    #|  margin-top: 0;
    #|  flex: 1;
    #|  min-height: 0;
    #|}
    #|/* Panel order: preview | source | review sidebar | media thumbs */
    #|.md-layout > .md-left { order: 2; }
    #|.md-layout > .md-right { order: 3; }
    #|.md-layout > .media-sidebar { order: 5; }
    #|.md-left {
    #|  flex: 1;
    #|  min-width: 200px;
    #|  overflow-y: auto;
    #|  overflow-x: auto;
    #|  overscroll-behavior: contain;
    #|}
    #|.md-left .md-preview {
    #|  max-height: none;
    #|  margin-top: 12px;
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
    #|  background: var(--accent-soft);
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
    #|  border-color: var(--accent);
    #|  opacity: 1;
    #|  transform: scale(1.05);
    #|}
    #|.timeline-thumb.active {
    #|  border-color: var(--accent);
    #|  opacity: 1;
    #|  box-shadow: 0 0 12px var(--accent-soft);
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
    #|  background: var(--accent);
    #|  border-color: var(--accent);
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
    #|@media (max-width: 960px), (max-device-width: 960px) {
    #|  .md-layout { flex-direction: column; }
    #|  .md-left { max-width: 100%; flex: 1 1 0; min-height: 0; }
    #|  .md-right { display: none; }
    #|  #md-preview :is(.yunomi-inline-comment, .review-loop-inline) { margin-right: 0; }
    #|  #review-loop-panel.review-loop-sidebar {
    #|    inset: auto 12px 12px auto;
    #|    width: calc(100% - 24px);
    #|    min-width: 0;
    #|    max-width: 320px;
    #|    height: 60dvh;
    #|    max-height: 60dvh;
    #|  }
    #|  #review-loop-panel.review-loop-sidebar.review-loop-sidebar-collapsed {
    #|    width: 40px;
    #|    min-width: 40px;
    #|    max-width: 40px;
    #|  }
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
    #|/* Submit modal: top-right position with a dismissible outside area. */
    #|#submit-modal {
    #|  background: rgba(0,0,0,0.16);
    #|  pointer-events: auto;
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
    #|.modal-dialog h3 { margin: 0 0 14px; font-size: 18px; font-weight: 700; color: var(--text); letter-spacing: 0; }
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
    #|.modal-actions button.primary { background: var(--accent-fill); color: var(--on-accent); border-color: var(--accent-fill); }
    #|.image-attach-area { margin: 12px 0; }
    #|.image-attach-area label { display: block; font-size: 12px; color: var(--muted); margin-bottom: 6px; }
    #|.image-attach-area.image-attach-small { margin: 8px 0; }
    #|.image-attach-area.image-attach-small label { font-size: 11px; }
    #|.image-preview-list { display: flex; flex-wrap: wrap; gap: 8px; min-height: 24px; }
    #|.image-preview-item { position: relative; }
    #|.image-preview-item img { max-width: 80px; max-height: 60px; border-radius: 4px; border: 1px solid var(--border); object-fit: cover; }
    #|.image-preview-item .remove-image { position: absolute; top: -6px; right: -6px; width: 18px; height: 18px; border-radius: 50%; background: var(--error, #ef4444); color: #fff; border: none; cursor: pointer; font-size: 12px; line-height: 1; display: flex; align-items: center; justify-content: center; }
    #|.image-preview-item .remove-image:hover { background: #dc2626; }
    #|.modal-actions button.primary:hover { background: color-mix(in srgb, var(--accent-fill) 86%, #000000); border-color: color-mix(in srgb, var(--accent-fill) 86%, #000000); color: var(--on-accent); }
    #|.modal-actions-decision { justify-content: space-between; align-items: center; }
    #|.modal-actions-decision button { box-sizing: border-box; min-height: 36px; white-space: nowrap; }
    #|.kbd-hint { display: inline-block; flex: 0 0 auto; font-size: 10px; padding: 1px 5px; border-radius: 3px; background: rgba(255,255,255,0.15); margin-left: 6px; font-family: system-ui; opacity: 0.8; white-space: nowrap; }
    #|[data-theme="light"] .kbd-hint { background: rgba(0,0,0,0.08); }
    #|.decision-btn { display: inline-flex; align-items: center; justify-content: center; gap: 6px; box-sizing: border-box; min-height: 36px; padding: 9px 16px; border-radius: var(--radius-sm); border: 1px solid var(--border); cursor: pointer; font-size: 13px; font-weight: 700; letter-spacing: 0.01em; white-space: nowrap; transition: background 160ms ease, border-color 160ms ease, transform 120ms ease, box-shadow 160ms ease; }
    #|.decision-btn svg { display: block; flex: 0 0 auto; width: 16px; height: 16px; }
    #|.decision-btn:hover { transform: translateY(-1px); box-shadow: var(--shadow-soft); }
    #|.decision-approve { background: rgba(107, 191, 134, 0.14); color: var(--success); border-color: rgba(107, 191, 134, 0.42); }
    #|.decision-approve:hover { background: rgba(107, 191, 134, 0.22); border-color: var(--success); }
    #|.decision-request-changes { background: linear-gradient(135deg, var(--accent-fill) 0%, color-mix(in srgb, var(--accent-2) 62%, #000000) 100%); color: var(--on-accent); border-color: transparent; }
    #|.decision-request-changes:hover { background: linear-gradient(135deg, color-mix(in srgb, var(--accent-fill) 86%, #000000) 0%, var(--accent-fill) 100%); color: var(--on-accent); }
    #|[data-theme="light"] .decision-approve { background: rgba(77, 157, 99, 0.14); color: var(--success); border-color: rgba(77, 157, 99, 0.38); }
    #|[data-theme="light"] .decision-approve:hover { background: rgba(77, 157, 99, 0.22); }
    #|.decision-btn:disabled, .decision-btn:disabled:hover { opacity: 0.55; cursor: not-allowed; transform: none; box-shadow: none; background: var(--panel); color: var(--muted); border-color: var(--border); }
    #|.approve-blocked-reason { display: none; flex-wrap: wrap; align-items: center; gap: 8px; margin-top: 12px; color: var(--text); font-size: 13px; line-height: 1.45; }
    #|.approve-blocked-message { color: var(--warning); font-weight: 600; }
    #|#review-unresolved-action { margin-left: auto; padding: 6px 10px; border: 1px solid var(--border-strong); border-radius: var(--radius-sm); background: var(--button-bg); color: var(--text); cursor: pointer; font: inherit; font-weight: 600; }
    #|#review-unresolved-action:hover { background: var(--hover-bg); border-color: var(--accent); }
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
    #|.diff-review-shell {
    #|  display: grid;
    #|  grid-template-columns: minmax(180px, 260px) minmax(0, 1fr);
    #|  flex: 1;
    #|  min-height: 0;
    #|  overflow-x: hidden;
    #|  overflow-y: auto;
    #|}
    #|.diff-file-tree {
    #|  position: sticky;
    #|  top: 0;
    #|  align-self: start;
    #|  max-height: 100%;
    #|  overflow: auto;
    #|  padding: 14px 10px;
    #|  border-right: 1px solid var(--border);
    #|  background: var(--panel);
    #|}
    #|.diff-file-tree-title {
    #|  padding: 0 8px 8px;
    #|  color: var(--muted);
    #|  font-size: 11px;
    #|  font-weight: 700;
    #|  text-transform: uppercase;
    #|  letter-spacing: 0.04em;
    #|}
    #|.diff-file-tree-item {
    #|  display: grid;
    #|  grid-template-columns: auto minmax(0, 1fr);
    #|  align-items: center;
    #|  gap: 4px;
    #|  padding: 4px 6px;
    #|  border-radius: var(--radius-sm);
    #|  color: var(--text);
    #|}
    #|.diff-file-tree-item:hover { background: var(--hover-bg); }
    #|.diff-file-tree-item.viewed { color: var(--muted); }
    #|.diff-viewed-control { display: inline-flex; align-items: center; gap: 5px; white-space: nowrap; color: var(--muted); font-size: 11px; cursor: pointer; }
    #|.diff-viewed-checkbox { accent-color: var(--accent); margin: 0; }
    #|.diff-file-tree-item.viewed .diff-viewed-state { color: var(--accent-strong); font-weight: 700; }
    #|.diff-file-link {
    #|  min-width: 0;
    #|  overflow: hidden;
    #|  text-overflow: ellipsis;
    #|  white-space: nowrap;
    #|  padding: 4px 2px;
    #|  border: 0;
    #|  background: transparent;
    #|  color: inherit;
    #|  text-align: left;
    #|  font: inherit;
    #|  cursor: pointer;
    #|}
    #|.diff-review-main { min-width: 0; }
    #|.diff-toolbar {
    #|  position: sticky;
    #|  top: 0;
    #|  z-index: 4;
    #|  display: flex;
    #|  justify-content: flex-end;
    #|  padding: 10px 20px 0;
    #|}
    #|.diff-view-mode {
    #|  display: inline-flex;
    #|  border: 1px solid var(--border);
    #|  border-radius: var(--radius-sm);
    #|  overflow: hidden;
    #|  background: var(--panel);
    #|  box-shadow: var(--shadow-soft);
    #|}
    #|.diff-view-mode button {
    #|  min-height: 32px;
    #|  padding: 5px 12px;
    #|  border: 0;
    #|  border-right: 1px solid var(--border);
    #|  background: transparent;
    #|  color: var(--muted);
    #|  font-size: 12px;
    #|  font-weight: 700;
    #|  cursor: pointer;
    #|}
    #|.diff-view-mode button:last-child { border-right: 0; }
    #|.diff-view-mode button.active {
    #|  background: var(--selected-bg);
    #|  color: var(--accent);
    #|}
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
    #|.diff-file-block.viewed { opacity: 0.62; }
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
    #|.diff-line .split-content { display: none; }
    #|.diff-line.addition .line-content::before { content: "+ "; color: var(--success); font-weight: 700; }
    #|.diff-line.deletion .line-content::before { content: "- "; color: var(--error); font-weight: 700; }
    #|.diff-line:not(.addition):not(.deletion) .line-content::before { content: "  "; }
    #|body.diff-split .diff-line {
    #|  display: grid;
    #|  grid-template-columns: 56px minmax(0, 1fr) 56px minmax(0, 1fr);
    #|  gap: 0;
    #|  padding: 0;
    #|}
    #|body.diff-split .diff-line .old-num,
    #|body.diff-split .diff-line .new-num {
    #|  width: auto;
    #|  min-width: 0;
    #|  padding: 0 8px;
    #|  border-right: 1px solid var(--border);
    #|}
    #|body.diff-split .diff-line .unified-content { display: none; }
    #|body.diff-split .diff-line .split-content {
    #|  display: block;
    #|  min-width: 0;
    #|  overflow-x: auto;
    #|  padding: 0 12px;
    #|  border-right: 1px solid var(--border);
    #|}
    #|body.diff-split .diff-line .new-content { border-right: 0; }
    #|.diff-line.has-comment { outline: 2px dashed var(--accent); outline-offset: -2px; }
    #|
    #|@media (max-width: 860px) {
    #|  .diff-review-shell { grid-template-columns: 1fr; }
    #|  .diff-file-tree { position: static; max-height: 180px; border-right: 0; border-bottom: 1px solid var(--border); }
    #|  .diff-toolbar { top: 0; }
    #|}
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
    #|@media (max-width: 840px), (max-device-width: 840px) {
    #|  header { display: grid; grid-template-columns: minmax(0, 1fr); grid-template-rows: auto auto; gap: 6px; padding: 8px 12px; align-items: center; }
    #|  header .meta { width: 100%; gap: 8px; }
    #|  header h1 { display: block; flex: 1 1 auto; min-width: 0; }
    #|  header h1 .title-path { display: block; max-width: 100%; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
    #|  header h1 .title-file { display: block; max-width: none; }
    #|  header .actions { width: 100%; justify-content: flex-start; flex-wrap: nowrap; overflow-x: auto; scrollbar-width: none; gap: 4px; min-height: 34px; }
    #|  header .actions::-webkit-scrollbar { display: none; }
    #|  .comment-list { width: calc(100% - 24px); }
    #|}
    #|@media (max-width: 420px), (max-device-width: 420px) {
    #|  header .actions button { min-width: 32px; height: 32px; padding: 4px 6px; }
    #|  #conversation-unresolved,
    #|  #conversation-unread { min-width: 22px; width: 22px; min-height: 22px; max-height: 22px; height: 22px; padding: 0; }
    #|  header .actions #pill-comments { min-width: 34px; font-size: 0; }
    #|  header .actions #pill-comments strong { font-size: 12px; }
    #|  header .actions #send-and-exit { min-width: 0; padding: 4px 10px; font-size: 12px; }
    #|  .review-loop-header-badge { max-width: 82px; min-height: 32px; padding: 4px 8px; }
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
    #|.yunomi-media-comment-host { display: inline-block; max-width: 100%; line-height: 0; position: relative; vertical-align: top; }
    #|.yunomi-media-comment-host > img { display: block; max-width: 100%; }
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
    #|.yunomi-commentable:hover > .yunomi-copy-button,
    #|.yunomi-comment-button:focus,
    #|.yunomi-copy-button:focus {
    #|  opacity: 1;
    #|  transform: translateY(-1px);
    #|  background: #fff;
    #|}
    #|.yunomi-media-comment-host:hover > .yunomi-comment-button,
    #|.yunomi-media-comment-host:hover > .yunomi-copy-button,
    #|.yunomi-media-comment-host > .yunomi-comment-button:focus,
    #|.yunomi-media-comment-host > .yunomi-copy-button:focus { transform: none; }
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
    #|.yunomi-copy-button {
    #|  position: absolute;
    #|  top: 6px;
    #|  right: 34px;
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
    #|  line-height: 1;
    #|  display: inline-flex;
    #|  align-items: center;
    #|  justify-content: center;
    #|  padding: 0;
    #|  transition: opacity 0.12s ease, transform 0.12s ease, background 0.12s ease;
    #|}
    #|.mermaid-container > .yunomi-copy-button {
    #|  top: 8px;
    #|  right: 36px;
    #|  z-index: 3;
    #|}
    #|.md-preview pre.yunomi-copyable {
    #|  position: relative;
    #|}
    #|.md-preview pre.yunomi-copyable > .yunomi-copy-button {
    #|  top: 8px;
    #|  right: 8px;
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
    #|@media (max-width: 960px), (max-device-width: 960px) {
    #|  .media-sidebar { display: none !important; }
    #|  .media-sidebar-toggle { display: none !important; }
    #|}
    #|.video-overlay-wrapper {
    #|  position: relative;
    #|  display: block;
    #|  width: fit-content;
    #|  max-width: 100%;
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
    #|@media print {
    #|  html, body {
    #|    height: auto !important;
    #|    overflow: visible !important;
    #|    background: #fff !important;
    #|    color: #111 !important;
    #|    color-scheme: light;
    #|  }
    #|  body { display: block !important; }
    #|  header,
    #|  .md-right,
    #|  .media-sidebar,
    #|  .media-sidebar-toggle,
    #|  .comment-list,
    #|  #review-loop-panel,
    #|  .modal-overlay,
    #|  .fullscreen-overlay,
    #|  .yunomi-comment-button,
    #|  .yunomi-copy-button,
    #|  .review-loop-jump-latest,
    #|  .yunomi-inline-comment,
    #|  .review-loop-inline,
    #|  .heading-toggle-icon,
    #|  .copy-toast,
    #|  .history-panel,
    #|  .review-file-switcher { display: none !important; }
    #|  .wrap,
    #|  .md-layout,
    #|  .md-left {
    #|    display: block !important;
    #|    height: auto !important;
    #|    min-height: 0 !important;
    #|    max-height: none !important;
    #|    overflow: visible !important;
    #|  }
    #|  .wrap { padding: 0 !important; }
    #|  .md-preview {
    #|    background: #fff !important;
    #|    color: #111 !important;
    #|    border: 0 !important;
    #|    border-radius: 0 !important;
    #|    box-shadow: none !important;
    #|    margin: 0 !important;
    #|    padding: 0 !important;
    #|  }
    #|  .md-preview details.heading-toggle > summary {
    #|    display: block !important;
    #|  }
    #|  .md-preview details.heading-toggle > .toggle-content,
    #|  .md-preview .heading-section-content.hidden {
    #|    display: block !important;
    #|    height: auto !important;
    #|    opacity: 1 !important;
    #|    overflow: visible !important;
    #|  }
    #|  .md-preview table:not(.frontmatter-table table) {
    #|    width: 100% !important;
    #|    min-width: 0 !important;
    #|    max-width: 100% !important;
    #|    table-layout: fixed !important;
    #|  }
    #|  .md-preview code { background: #f6f8fa !important; }
    #|  .md-preview pre {
    #|    background: #f6f8fa !important;
    #|    border-color: #d0d7de !important;
    #|    white-space: pre-wrap !important;
    #|    overflow: visible !important;
    #|    overflow-wrap: anywhere;
    #|    word-break: break-word;
    #|  }
    #|  .md-preview pre code { background: transparent !important; }
    #|  .md-preview :is(h1, h2, h3, h4, h5, h6, p, li, td, th, blockquote, pre, code) { color: #111 !important; }
    #|  .md-preview img, .md-preview video, .md-preview svg { max-width: 100% !important; height: auto !important; }
    #|  .md-preview tr, .md-preview blockquote, .md-preview figure { break-inside: avoid; }
    #|}
  css
}
