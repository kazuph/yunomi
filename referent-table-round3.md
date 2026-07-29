# Round 3 referent table

| Name | Role | Source of truth | Verification |
|---|---|---|---|
| decision event | checkbox state synchronization event | `/decision` SSE payload | No `reload` follows it; matching checkbox changes in place |
| decision source change pending | one self-originated source-file watcher update to suppress | server context | The watcher refreshes cached HTML but emits no reload for that update |
| inline list holder | valid list child wrapping an inline review card | `ul` / `ol` direct child | It is an `li.review-loop-inline-item` |
| sidebar collapsed state | file-scoped persisted panel width choice | localStorage | Toggle restores it after reload |
| round thread | review summary conversation record | `review.comments` item with `id=r-<round>` and `scope=round` | reply and resolve use existing endpoints; not gate-counted |
| unresolved sidebar card | one visible unresolved review item | sidebar card list | Cards are numbered 1 through unresolved count |
