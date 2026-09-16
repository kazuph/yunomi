# Bug fix

Not a slash command. `/do` reads this file when the request is a reported defect to reproduce, explain, and fix.

Keep `/do`'s required TDD, preservation, and real-surface verification. Do not weaken tests because a cheaper check exists. Do not require a subagent.

## Steps

1. Reproduce the defect yourself on the matching surface. A screenshot or a user report is not the reproduction. If it will not fire, tighten the trigger or instrument until it does, within authorized side effects.
2. Form competing causes and rule them out with observations. Read the real flow and all callers. For a regression, also read `../why.md` and separate recorded history from inference.
3. Fix the shared cause in authorized scope. If the repair needs an unapproved contract change, stop and say so. If the change crosses a function boundary and the structure is not determined, write two or more designs with a shared evaluation and the rejected reasons before editing.
4. Mutating operations must converge to the same correct state after a retry or a mid-run interrupt. Verify that, or record why this change has no such operation.
5. Verify on the same surface. The original reproduction now fails to appear. A unit test that never took the failing path is not enough.
6. Hand `/done` the reproduction, the surviving cause, the callers covered, and the same-surface result.

Continue into `/done`. Do not treat "Opening a PR" as the end of this playbook. Commit and push stay behind human approval.
