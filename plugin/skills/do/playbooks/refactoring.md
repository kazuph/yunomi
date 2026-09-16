# Refactoring

Not a slash command. `/do` reads this file when the request changes structure or placement while keeping behavior.

Do not delete a public API because the new shape exists. Caller migration needs an explicit user decision. Do not turn this into an unrelated cleanup.

## Steps

1. Record the behavior to preserve: inputs, outputs, errors, persisted results, and callers.
2. Capture a baseline: existing tests and, where they exist, real-surface checks that already prove that behavior.
3. Change structure in verifiable units. Each unit keeps the baseline green before the next unit starts.
4. After the change, the same callers and the same inputs must produce the same results. If a check is missing for a preserved path, add it as part of this playbook, not as a later guess.
5. Mutating operations must still converge after retry or interrupt.
6. Hand `/done` the before/after equivalence evidence and the list of APIs that were not removed.

Continue into `/done`.
