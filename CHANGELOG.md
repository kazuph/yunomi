# Changelog

## v3.0.0-alpha.1 - 2026-07-08

### Added

- Multi-round review sessions with durable `.yunomi/reviews/<branch>/review.json`, unresolved-thread gating, `yunomi go`, and `yunomi reply`.
- Realtime review relay for comments, answers, and final verdict notifications.
- `yunomi live <localhost-url>` reverse proxy review with DOM pin comments, selector text, and bounds in the submitted YAML.
- Agent interop commands: `yunomi comment` for posting into a running review server and `yunomi install` for installing the skill document.
- Checkbox decision flow for task lists, including source markdown updates, review decision persistence, and Herdr notification support.

### Changed

- `npm test` now covers the v3 alpha surfaces: review loop, realtime relay, live review, agent interop comments, and checkbox decisions.
- The CLI version is now `3.0.0-alpha.1`; publish should use the `next` npm tag until GA.

### Compatibility

- Existing `yunomi <file>` and `git diff | yunomi` one-shot review flows remain supported.
- `--loop` is opt-in for the alpha review loop behavior.
