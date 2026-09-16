# Feature

Not a slash command. `/do` reads this file when the request adds or changes observable behavior.

Keep `/do`'s reuse order, domain model, TDD, verifiable units, and independent design advice. Implement directly unless an isolated role has a concrete benefit and delegation is authorized. Do not require arena, extra models, or stacked PRs.

## Steps

1. Restate the requested behavior and the protected existing behavior.
2. Trace the real flow and all callers before choosing a shape.
3. If more than one structure could satisfy the request, write at least two designs. Give them the same evaluation (callers, data ownership, testing, failure behavior) and record why the losers were rejected. Skipping this stays as `design comparison skipped:` with the reason that the existing structure already determines the work. Do not fold the choice silently into the first patch.
4. Record data shape, valid states, owners of mutation, and public contracts. Then follow `/do`'s model-the-domain and sequence-verifiable-units sections.
5. Mutating operations must converge to the same correct state after a retry or a mid-run interrupt. Verify that, or record why this change has no such operation.
6. Verify the new path and the retained paths on the real surface.
7. Hand `/done` the chosen design, rejected alternatives, unit results, and preservation record.

Continue into `/done`. Human approval still gates commit, push, and PR.
