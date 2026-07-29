# Changelog

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
