<h1 align="center">どうぞ 🍵</h1>

<p align="center">
  <img src="https://raw.githubusercontent.com/kazuph/yunomi/main/assets/hero.png" alt="a voxel robot quietly serving tea while an engineer reads a report" width="720">
</p>

<p align="center">
  <strong>Reviews, served like tea.</strong><br>
  <strong>yunomi</strong>（湯のみ）— a human-in-the-loop approval gate for AI coding workflows
</p>

<p align="center">
  <a href="https://www.npmjs.com/package/yunomi"><img src="https://img.shields.io/npm/v/yunomi.svg" alt="npm version"></a>
  <a href="https://github.com/kazuph/yunomi/blob/main/LICENSE"><img src="https://img.shields.io/npm/l/yunomi.svg" alt="license"></a>
  <a href="./README.ja.md">日本語</a>
</p>

<p align="center">
  <img src="https://raw.githubusercontent.com/kazuph/yunomi/main/assets/demo.gif" alt="yunomi demo: the agent serves its report, you scroll the evidence, leave a comment, and approve" width="960">
</p>

---

> **Installation: none.** Just tell your AI — *"run `npx yunomi`"* — and it will know what to do.

A **yunomi**（湯のみ）is the everyday Japanese teacup: no handle, no saucer, warm in both hands. Tea served in one always arrives the same way — set down gently in front of you, with a slight bow and a single word: *douzo* — "here you go."

## The story

yunomi was not built so humans can demand *"show me what you did."*
It is the opposite gesture.

When an AI agent finishes a piece of work, it shouldn't just say "done."
It should brew a report — what changed, why, the evidence, the test results — pour it into a cup, and set it down in front of you:

```bash
npx yunomi REPORT.md
```

*Douzo.* 🍵

Your browser opens. You read at your own pace. You leave comments; you approve — or you hand the cup back. The agent waits the way good service waits: quietly, until you decide. When you submit, yunomi exits and hands your verdict back to the agent as structured YAML, and the loop continues until you say it's good.

In the vibe coding era, humans no longer read every diff. We review the work itself: **intent, changes, and proof**. yunomi is the moment of handoff between AI work and human judgment — served politely, every single time.

## Review Loop 🔁

One cup is never the whole conversation. yunomi turns a single review into a **multi-round loop** — the defining workflow of AI-native review tools:

- **Rounds** — after you request changes, the agent fixes and runs `yunomi go`; your browser shows a fresh round with a **diff of what actually changed** since your comments
- **Threads that never get lost** — comments stay pinned to their lines across rounds, **unresolved until *you* resolve them**; "I think I fixed it" can no longer make feedback silently disappear
- **Review files** — verdicts persist to `.yunomi/reviews/` per branch, so any agent (Claude Code, Codex, Cursor, OpenCode, …) can pick the loop back up tomorrow, even after the terminal is gone
- **Change review** — `yunomi review [base-ref]` detects Git, Jujutsu, or Sapling changes and keeps their Markdown, text, table, and diff views in one review session
- **Live app review** — `yunomi live http://localhost:3000` proxies your dev server so you can pin comments **directly on DOM elements** of the running app
- **Static HTML review** — `yunomi page.html` renders a sandboxed local preview with its relative assets and records clicked-element context
- **Code review** — diff files have a file tree, Unified/Split views, and durable per-file Reviewed state
- **Talk back mid-review** — send a single comment to the agent *while you keep reading*, and watch the reply land in the thread
- **Read-only sharing** — `yunomi share REPORT.md` serves a review URL with comment and submit actions disabled; binding stays local unless you explicitly pass `--public`
- **GitHub PR sync** — `yunomi pull 123` imports PR review comments into `review.json`; `yunomi push <review-id> 123` sends that review's unsynced comments back through the GitHub CLI
- **Keyboard review** — `j/k` moves through review targets, `c` comments, `n/N` jumps comments, `r` resolves threads, and `?` opens the key help
- **Review metadata commands** — `yunomi status`, `yunomi stats`, and `yunomi cleanup` show active sessions, summarize recent review history, and remove old approved review files
- **Report templates** — `yunomi init --template bugfix` creates `.artifacts/<feature>/REPORT.md` from built-in or `~/.yunomi/templates/*.md` templates
- **`yunomi install <agent>`** / **`yunomi mcp`** — one-command skill distribution and a stdio MCP server exposing review state, comment creation, and next-round control

The full feature-by-feature plan — including a gap analysis against tools like [crit](https://crit.md/) — lives in [PLAN.md](./PLAN.md). Evidence-first reporting stays at the heart of it all: yunomi reviews **the work, not just the diff**.

## Getting started (the only step)

Tell your AI agent:

> *"From now on, run `npx yunomi` when you finish your work."*

That's it. When the agent runs `npx yunomi` with no arguments, yunomi prints a skill document that teaches the agent everything: how to write a good report, how to serve it, how to read your verdict, and how to loop until you approve. The agent will then offer to install yunomi as a permanent skill — answer yes once, and you never have to mention it again.

No global install. No plugin setup. No config. The tea serves itself.

---

yunomi (formerly **reviw**) is a lightweight browser-based tool for reviewing and annotating Markdown reports, tabular data, text, and diff files. Built entirely in [MoonBit](https://www.moonbitlang.com/) (zero hand-written JavaScript). Supports CSV, TSV, plain text, Markdown, and unified diff formats. Comments are output as YAML to stdout.

## Features

### File Format Support
- **CSV/TSV**: View tabular data with sticky headers, column freezing, filtering, and column resizing
- **Markdown**: Side-by-side preview with synchronized scrolling, click-to-comment from preview
- **Diff/Patch**: GitHub-style diff view with syntax highlighting, collapsible large files (500+ lines), and binary files sorted to end
- **Text**: Line-by-line commenting for plain text files

### Mermaid.js Diagrams
- Auto-detect and render Mermaid diagrams in Markdown files
- Click any diagram to open fullscreen viewer with minimap
- Zoom with mouse wheel (centered on cursor position, up to 10x)
- Pan with mouse drag
- Trackpad pinch-to-zoom and touch gesture support
- Shift+scroll zoom for Windows users
- Dark mode support for thumbnails
- Highlights corresponding source line after closing fullscreen
- Syntax error display in toast notifications

### Media Sidebar
- Thumbnail gallery of all images and videos in the left sidebar
- Click any thumbnail to scroll to the corresponding media and highlight it
- ArrowUp/ArrowDown to jump between media, Escape to clear the selection
- Numbered badges for quick identification

### Media Embed Discipline (AI-friendly)
- `yunomi file.md` refuses to start (exit 1) when media files are written as `[text](path)` links instead of `![alt](path)` embeds
- The error lists every violation with line numbers and ready-to-apply fixes, so AI agents can self-correct and retry

### Media Fullscreen
- Click images in Markdown preview to open fullscreen viewer
- Click videos to open fullscreen playback with YouTube-like keyboard shortcuts (Space/K, J/L, arrow keys, 0-9)
- Click anywhere (including the image/video itself) to close the fullscreen overlay
- Clicking media automatically highlights the corresponding source line in the Markdown panel
- Video timeline settings with adjustable scene detection sensitivity

### UI Features
- **Theme toggle**: Switch between light and dark modes
- **Preview-only mode**: Hide source panel for wide preview reading
- **Heading toggle**: Collapse/expand sections by clicking heading arrows
- **Print / PDF**: Print Markdown reports or save them as PDFs without source, comments, review controls, or collapsed-content loss
- **Multi-file support**: Open multiple files simultaneously on separate ports
- **Drag selection**: Select rectangular regions or multiple rows for batch comments
- **Real-time updates**: Hot reload on file changes via SSE
- **Comment persistence**: Auto-save comments to localStorage with recovery modal
- **Image attachment**: Attach images to comments and submit dialog (paste with Cmd/Ctrl+V)
- **Selected-lines copy**: Copy button in comment dialog to copy selected line text
- **Keyboard shortcuts**: Cmd/Ctrl+Enter to open submit modal
- **Multi-tab sync**: Submit from any tab closes all tabs for the same file
- **Server detection**: Reuse existing server instead of starting a new one (via lock files)
- **Tab activation (macOS)**: Automatically activates existing browser tab via AppleScript
- **Review history**: File-based persistent review history
- **details/summary support**: HTML details/summary tags rendered as collapsible sections

### Output
- YAML format with file, mode, row, col, value, and comment text
- Overall summary field for review notes
- Image attachments included as base64 data

## Installation

You usually don't need one — see [Getting started](#getting-started-the-only-step). If you prefer a global command:

```bash
npm install -g yunomi
```

Or run directly with npx:

```bash
npx yunomi <file>
```

## Usage

```bash
# No arguments: print the skill document for AI agents
yunomi

# Single file
yunomi <file> [--port 4989] [--encoding utf8|shift_jis|...]

# Multiple files (each opens on consecutive ports)
yunomi file1.csv file2.md file3.tsv --port 4989

# Diff from stdin
git diff HEAD | yunomi

# Diff file
yunomi changes.diff
```

### Options
- `--port <number>`: Specify starting port (default: 4989)
- `--encoding <encoding>`: Force specific encoding (auto-detected by default)
- `--no-open`: Prevent automatic browser opening
- `--skill`: Print the skill document for AI agents
- `--help, -h`: Show help message
- `--version, -v`: Show version number

### Workflow
1. Browser opens automatically (macOS: `open` / Linux: `xdg-open` / Windows: `start`)
2. Click cells/lines to add comments, or drag to select multiple
3. Use Cmd/Ctrl+Enter or click "Submit & Exit" to output comments
4. Comments are printed as YAML to stdout

## Screenshots

### Markdown View with Media Sidebar
![Markdown View with Media Sidebar](https://raw.githubusercontent.com/kazuph/yunomi/main/assets/screenshot-media-sidebar.png)

### Preview-only Mode
![Preview-only Mode](https://raw.githubusercontent.com/kazuph/yunomi/main/assets/screenshot-preview-only.png)

### Heading Toggle
![Heading Toggle](https://raw.githubusercontent.com/kazuph/yunomi/main/assets/screenshot-heading-toggle.png)

### Comment Dialog with Image Attachment
![Comment Dialog](https://raw.githubusercontent.com/kazuph/yunomi/main/assets/screenshot-comment-dialog.png)

### Video Fullscreen with Timeline Thumbnails
![Video Fullscreen](https://raw.githubusercontent.com/kazuph/yunomi/main/assets/screenshot-video-thumbnails.png)

### Mermaid Fullscreen with Minimap
![Mermaid Fullscreen](https://raw.githubusercontent.com/kazuph/yunomi/main/assets/screenshot-mermaid-fullscreen.png)

### Submit Review Dialog with Image Attachment
![Submit Review Dialog](https://raw.githubusercontent.com/kazuph/yunomi/main/assets/screenshot-submit-modal.png)

### CSV View
![CSV View](https://raw.githubusercontent.com/kazuph/yunomi/main/assets/screenshot-csv.png)

### Diff View
![Diff View](https://raw.githubusercontent.com/kazuph/yunomi/main/assets/screenshot-diff.png)

## Output Example

```yaml
file: data.csv
mode: csv
comments:
  - file: data.csv
    row: 2
    col: 3
    end_row: 2
    end_col: 3
    quote: '150'
    text: This value needs review
    value: '150'
    snippet: 'alpha,ready,150'
    context_before: 'name,status,total'
    context_after: ''
    selector: ''
    bounds: ''
    element_text: ''
    attachments: []
summary: Overall the data looks good, minor issues noted above.
decision: request_changes
```

## Claude Code Plugin

This repository also serves as a Claude Code plugin marketplace. The plugin integrates yunomi into Claude Code workflows with task management and review automation.

> Note: the plugin was renamed from `reviw-plugin` to `yunomi-plugin` in v2.0.0. If you installed the old plugin, remove it and install `yunomi-plugin@yunomi-plugins`.

### Installation

```bash
# In Claude Code
/plugin marketplace add kazuph/yunomi
/plugin install yunomi-plugin@yunomi-plugins
```

### Unified development workflow

The canonical sources are `plugin/skills/do/`, `done/`, and `bucho/`. Personal installations contain identical copies. `tiny-do` and `tiny-done` are retired into these entries; task size does not select a lower quality level.

| Entry | Responsibilities |
|---|---|
| `/do` | Discover requirements and protected behavior, **select the matching playbook**, trace all callers, choose reuse and domain/state ownership, obtain design advice, use a nested git-wt worktree, implement with TDD and verified prerequisites, and continue into `/done`. |
| `/done` | Verify additions and regressions, deslop without changing behavior, build and exercise real flows, complete specialist reviews, validate diagrams/screenshots/video/report, and continue the human feedback loop. |
| `/bucho` | Delegate the same complete `/do` → `/done` outcome to an approved Herdr lead, maintain a durable decision record, and inspect actual diffs and evidence before acceptance. |

Check the agent's skill list for any namespaced invocation. See the executable instructions in [do](plugin/skills/do/SKILL.md), [done](plugin/skills/done/SKILL.md), and [bucho](plugin/skills/bucho/SKILL.md).

### Adopted practices and retained guarantees

P-Stack contributes choosing a procedure from the request (investigation, bug-fix, feature, and the other nested playbooks under `/do`), understanding the real flow, modeling data/state/ownership, resolving observable questions with experiments, verifying prerequisites before dependent work, and retaining reasons and evidence for decisions. Ponytail contributes considering repository code, standard facilities, platform features, installed dependencies, then new code after understanding the full requirement, and fixing shared causes across callers.

Existing discovery, design advice, TDD, code/security and E2E reviews, applicable UI/UX review, screenshots and video, report validation, and human approval remain required. Deslop retains trust-boundary validation, data protection, security, accessibility, diagnostics, and necessary tests. No third-party workflow scripts, libraries, or model defaults are imported.

### Existing agent instructions

| File under `plugin/agents/` | Responsibility |
|---|---|
| `review-code-security.md` | Design advice and final code/security review: types, errors, reuse, injection, authentication/authorization, secrets, and cryptography. |
| `review-e2e.md` | Real flows, assertions, persisted state, mocks/bypasses, waits, and test environment across project types. |
| `review-ui-ux.md` | Applicable WCAG 2.2 AA, keyboard/focus, design consistency, copy, and internationalization. |
| `report-builder.md` / `report-validator.md` | Original request/feedback, decisions, embedded diagram/evidence, links, and report format. |
| `webapp-impl.md` / `backend-impl.md` / `mobile-impl.md` | Implementation and real verification for each project type. |
| `dogfooding.md` / `review-video.md` | Real operation and video review. |

Use the current environment's approved independent review routing, models, and permissions. Do not launch a fixed number of retired agents. Resolve Critical/High findings, reverify, and obtain the affected re-review before human acceptance.

### Distribute Markdown into an existing environment

Copy `plugin/skills/{do,done,bucho}/` from a trusted local Yunomi checkout into the existing skill directory after checking destination changes. Keep the three copies at the same revision, including `/do`'s nested `playbooks/` and `why.md`. No additional installer, script, or library is required. Copying skills does not enable plugin hooks.

Review instructions remain available at `plugin/agents/` in that checkout. The environment's existing `yunomi`, `artifact-proof`, `validate-report`, applicable testing skills, `frontend-design` for Web UI, and `herdr-pane-commander` for delegation remain prerequisites; they are not bundled with these three skill directories. Missing required instructions are a concrete blocker, not permission to skip a review or fetch an external runner.

### Evidence, review, and resumption

- Keep the original checkout on its default branch and work in a nested `git wt` worktree.
- Web uses the real browser; backend uses its actual test framework, database or permitted local emulator, and coverage; mobile uses Maestro assertions and per-step evidence. Fullstack verifies both sides and the request/response/persistence path.
- Embed the explanatory diagram, screenshots, and video in report tables. Comparisons place old and new flows side by side, labeling and coloring preserved, added, changed, and explicitly retired behavior. Check files/embedding before launch and actual browser image loading afterward.
- Use the agreed report/evidence location and retain consequential decisions for resumption after compaction. Creating or relocating `.artifacts/` requires authorization. Never commit evidence; use the existing PR attachment mechanism.
- Follow the installed `yunomi` protocol with a proven Herdr or tmux notification route and `--loop`. Convert exact human feedback into implementation and verification TODOs and continue the same review loop. Agents do not grant human approval.
- Distinguish implementation, build/operation/evidence verification, human acceptance, and authorized delivery.

### Existing hooks

`plugin/hooks/` and `plugin/hooks-handlers/` retain pre-commit/push review reminders, completion reminders, worktree protection, and test guards. The workflow integration adds no hooks or external executable dependencies. Markdown-only distribution does not activate hooks.

## Development

yunomi is written entirely in [MoonBit](https://www.moonbitlang.com/) and compiled to JavaScript.

```bash
# Build
cd v2 && moon build --target js --release

# Run tests
cd v2 && moon test --target js

# Package for npm (builds MoonBit + copies to dist/)
npm run prepack
```

- Source: `v2/src/` (MoonBit)
- Build output: `dist/server/server.js`, `dist/ui/ui.js`
- Plugin: `plugin/` directory

## License

MIT
