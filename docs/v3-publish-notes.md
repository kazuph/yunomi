# yunomi 2.3.0 publish notes

Publish this release with the npm `latest` tag.

## Release highlights

- Summary images attached in the final review summary are now written to stable files and reported in stdout YAML as `summary_images`.
- Review loop requests and replies are easier to inspect inline, with the old sidebar flow removed.
- The UI theme is now Primer-inspired by default and includes verified Light/Dark scheme pairs for Primer, Tokyo Night, Catppuccin, Atom One, Solarized, and Gruvbox.
- Theme E2E coverage now checks all 12 scheme states and readable contrast for body, muted, accent, and accent-button text.
- Invalid legacy color-scheme values in local storage fall back to Primer.

## What to try

- `yunomi review [base-ref]` for changed files from Git, Jujutsu, or Sapling.
- `yunomi <page.html>` for sandboxed static HTML review.
- Unified/Split diff review with durable per-file Reviewed state.
- Send now and inline agent replies during an open review.
- `yunomi mcp` with the project `.mcp.json` registration.
- `yunomi share <files>` for local read-only sharing; add `--public` explicitly for a public bind.
- `yunomi pull <pr>` and `yunomi push <review-id> <pr>` for GitHub review comment synchronization.
- `yunomi status`, `stats`, `cleanup`, and `init --template <name>`.

## Compatibility

The existing `yunomi <file>` and `git diff | yunomi` one-shot flows remain available. Multi-round review remains opt-in with `--loop`.

## Release limits

- Live GitHub PR round-trip verification must be performed on a designated test PR before GA.
- Jujutsu and Sapling command-level E2E requires those CLIs in the release environment.

## Publish command

```bash
npm run prepack
npm publish
```
