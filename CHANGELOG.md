# Changelog

## v2.6.0 - 2026-08-28

### Added

- Unread cues for agent replies: a header counter that sums unread replies across inline threads and the bottom-right chat, a red dot on the collapsed chat, a `(N)` tab-title prefix, and a short bell. One click on the counter jumps to exactly one unread message (opening the chat when the message lives there) and reads it; scrolling past never marks anything read.
- Markdown previews refresh in place when the reviewed file changes or a new round starts: only blocks whose source text changed are swapped, so open editors, reply forms, caret position, rendered Mermaid diagrams and scroll position all survive without a page reload.
- Drafts restore silently on reload with a small "Draft restored (N) · Discard" notice; the draft TTL is now 24 hours.

### Changed

- Media thumbnail numbering (header total and per-thumbnail index) is gone; the header number now means unread replies.
- The Restore / Discard confirmation modal shown on every manual reload is removed.

### Fixed

- Clicking a reply form or editor mounted inside a Mermaid block no longer opens the diagram fullscreen and hides the form; only the diagram itself does.
- Re-rendering conversation threads no longer recreates the form being typed in.

## v2.5.4 - 2026-08-27

### Added

- Markdown reports now expose a Print or save PDF action that sends only the rendered report content to the browser print dialog.

### Fixed

- Printed reports restore collapsed section content, constrain wide tables to the printable width, keep code readable from dark themes, and omit review/disclosure controls.

## v2.5.3 - 2026-08-25

### Fixed

- Verdict notifications now include the human's summary in full as a `human:` line (or an explicit `summary=(empty)`) on every delivery route, so a request_changes with zero inline comments is no longer read as "no instructions".
- request_changes and completion logs name where the full review lives (`.yunomi/reviews/<branch>/review.json`, or `herdr job log` when launched via `herdr run`) and the exact next command (`npx yunomi go`); the skill document and CLI reference are aligned with the implemented `yunomi go` contract.

## v2.5.2 - 2026-08-25

### Fixed

- A browser reload, back/forward navigation, or address-bar re-entry no longer sends `[yunomi] tab closed` to the launching agent: the server waits 1.5 s after a close beacon and drops the notification when the same tab re-registers.
- Herdr delivery no longer probes the non-existent `herdr agent prompt` subcommand on every event; the installed Herdr's contract is resolved once per process and only `herdr agent send` (present upstream and in the kazuph fork) is used.

### Added

- `--notify-room <room>` (or `YUNOMI_NOTIFY_ROOM`) delivers every comment, verdict, decision, and close event as durable mail through `herdr send <pane> <text> --room <room>` on a Herdr that exposes that contract; yunomi refuses to start with exit 1 when the installed Herdr lacks it.
- The generated skill document resolves the Herdr pane from `HERDR_PANE_ID` first (upstream exports `p_N`) and only falls back to the fork-only `herdr pane current`.

## v2.4.2 - 2026-08-05

### Fixed

- Durable inline conversations replace duplicate local sent cards, and reopening the same unresolved location focuses the existing conversation instead of creating another comment.
- Review conversations use a bounded, horizontally resizable layout with padded left/right message bubbles, icon-only image attachment controls, and consistent English actions.
- Long unanchored conversations scroll inside the fixed chat, keep the reply form reachable, and follow new human or agent replies without pulling reviewers away from older messages they are reading.
- Human and agent labels are omitted from bubbles, while Reply and Resolve conversation share the same size, padding, border, colors, radius, and typography.

## v2.4.1 - 2026-08-01

### Fixed

- Markdown, sanitized raw HTML, and static HTML preview links always open in a separate tab with `noopener noreferrer`, leaving the review tab in place.
- Saved inline comments re-anchor by quoted text and surrounding context, retain a stable order, render once at their canonical target, and remain explicitly unanchored when no unique target exists.
- Hot reloads preserve preview and source scroll positions, pending comment editors, and Submit Review input.
- Inline comments stay inside the selected table cell or beside their media block, Draft counts exclude sent threads, and Cmd/Ctrl+Enter shortcuts ignore active IME composition.
- Stale tabs retire without rejoining a review, completed reviews notify their originating pane once, and concurrent launches for the same report share one server and port.

## v2.4.0 - 2026-07-29

### Added

- Inline review threads now keep human and AI replies, image attachments, resolve state, Herdr notifications, and API replies at the reviewed source location.
- Global review conversation is available from a responsive, minimizable chat with durable replies and new-conversation creation.

### Changed

- Saved review threads and unsubmitted local drafts now have separate labels and counts; the Drafts control stays hidden when empty.
- Review counts and approval gating are scoped to the file currently being reviewed instead of stale comments from other files in the same branch store.

### Fixed

- Comment and checkbox notifications include the target-line quote, decision IDs remain unique by file and line, and decision paths use repository-relative files.
- Checkbox decisions update in place without reloading or moving the document scroll position.
- Inline editors stay clear of the expanded chat, use a visible Cancel action, preserve valid list markup, and keep focus outlines visible on all four sides.
- Signed read-only shares now require the share token for review state, history, UI assets, document media, and conversation attachments.
- npm, Claude Code plugin, and MCP server metadata now report version 2.4.0 consistently.

## v2.3.2 - 2026-07-22

### Fixed

- Mermaid fullscreen diagrams and their minimaps now preserve the preview background color, keeping black lines and text readable on diagrams designed for a light canvas.

## v2.3.1 - 2026-07-21

### Fixed

- Markdown comments now render inline at their source anchor across Markdown, diff, CSV, TSV, plain text, and HTML preview modes. Pending comments follow GitHub's review lifecycle and survive reloads.
- Media comment controls are limited to images, video, Mermaid diagrams, and timeline thumbnails; image comments now retain image identity in the immediate agent payload.
- Closing a browser tab now preserves the draft and keeps Yunomi running until an explicit Submit Review action. Default port discovery now scans 50 ports and falls back to an OS-assigned port.
- Raw HTML preserves safe `mark` inline markup instead of displaying its source text.

## v2.3.0 - 2026-07-14

### Added

- Summary review images are now persisted with collision-resistant filenames and surfaced in stdout YAML via `summary_images`, so agents can see and inspect human-attached summary images.
- Review loop pages now expose inline AI replies, human request context, and multi-round state without a separate sidebar.
- The review UI now includes a segmented Light/Dark button plus a right-side color-scheme menu with Primer, Tokyo Night, Catppuccin, Atom One, Solarized, and Gruvbox schemes.
- E2E coverage now verifies the theme menu contract, 12 light/dark scheme states, and readable contrast for body text, muted text, accent text, and accent-button text.
- Added design-reference documentation and screenshots for markdown review UI exploration.

### Changed

- The default visual theme moved away from the prior green-tinted base to a neutral Primer-inspired light/dark foundation.
- Color-scheme choices are stored in `localStorage` and invalid legacy values now fall back to Primer instead of leaving the UI in an undefined state.
- The CLI, npm package, Claude Code plugin manifest, and MCP server metadata now report `2.3.0`.

### Fixed

- Summary image filenames no longer overwrite each other across review submissions.
- Review loop Japanese labels no longer expose internal round wording in the main title.
- Light/Dark switching no longer makes supported scheme text disappear; unsupported invented light/dark pairs were removed from the menu.

## v3.0.0-alpha.1 - 2026-07-08

### Added

- Multi-round review sessions with durable `.yunomi/reviews/<branch>/review.json`, unresolved-thread gating, `yunomi go`, and `yunomi reply`.
- Realtime review relay for comments, answers, and final verdict notifications.
- `yunomi live <localhost-url>` reverse proxy review with DOM pin comments, selector text, and bounds in the submitted YAML.
- Agent interop commands: `yunomi comment` for posting into a running review server and `yunomi install` for installing the skill document.
- Checkbox decision flow for task lists, including source markdown updates, review decision persistence, and Herdr notification support.
- `yunomi review [base-ref]` change detection for Git, Jujutsu, and Sapling workspaces with one-process multi-file switching.
- Sandboxed static HTML review with relative assets and element-level selector, text, and bounds context.
- Unified/Split diff review, file navigation, and Reviewed state persisted to both local storage and `review.json`.
- Per-comment Send now delivery, inline agent replies, and durable reply history.
- A stdio MCP bridge for listing and reading reviews, adding structured comments, and advancing rounds.
- One structured comment schema across stdout YAML, `review.json`, MCP, live review, and static HTML review, including source windows, DOM context, and relative attachments.
- Read-only signed sharing, explicit `--public` binding, and token revocation.
- GitHub PR review comment pull/push synchronization with duplicate tracking.
- Vim-style review navigation, metadata commands, and built-in/user report templates.

### Changed

- `npm test` covers the review loop, realtime relay, live/static HTML review, VCS change detection, diff review, MCP, sharing, GitHub sync contracts, keyboard review, metadata commands, templates, and legacy modes.
- The CLI and Claude Code plugin manifest used the same prerelease version in this historical entry.

### Compatibility

- Existing `yunomi <file>` and `git diff | yunomi` one-shot review flows remain supported.
- `--loop` is opt-in for the alpha review loop behavior.
