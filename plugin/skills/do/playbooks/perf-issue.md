# Perf issue

Not a slash command. `/do` reads this file when the request is measured slowness, not a guessed rewrite.

Use the repository's existing measurement. Do not add a profiler, control surface, or third-party workflow package.

## Steps

1. Name the slow path and the existing way to measure it. If there is no measurement, say so and measure once with tools already in the project or the environment.
2. Record the before number, input, and environment.
3. Form one cause at a time. Observe; do not ship a "might help" change.
4. Apply a cause-directed fix in authorized scope. Keep behavior. Verify with the same measurement.
5. Record the after number. If it did not improve, revert the speculative part and say what remains unknown.
6. Hand `/done` the before/after measurement and the retained behavior checks.

Sustained metric campaigns, live forensics, and saved-trace analysis are out of this playbook. Continue into `/done`.
