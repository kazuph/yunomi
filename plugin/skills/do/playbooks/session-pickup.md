# Session pickup

Not a slash command. `/do` reads this file when the request is to resume an in-flight task from an existing record, worktree, or previous agent.

Do not start a second copy of the work. Do not create `.artifacts/` without permission. Do not make a WIP commit to save state.

## Steps

1. Read the existing task record, worktree, diff, and TODOs before creating anything.
2. Verify current runtime and repository state against that record. Note drift.
3. Reclassify the remaining work. If it is now a different kind of request, select that playbook and record the change. If it is still the same kind, continue that playbook.
4. Carry user answers and unresolved review comments verbatim. A TODO is complete only with implementation and verification evidence.
5. Continue through `/done` without asking the user to restart the task.

If the record cannot be found, search the project for the agreed report path and say what is missing. That search is not permission to invent a new task.
