---
name: bucho
description: Delegate a complete yunomi workflow to an approved implementation lead through Herdr, while retaining outcome ownership and verifying the returned evidence.
---

# Own the outcome through delegation

Canonical source: `kazuph/yunomi`, `plugin/skills/bucho/`. Distribute it unchanged together with `/do` and `/done`; do not maintain another personal workflow.

Use when the user explicitly chooses delegated execution. `/bucho` changes who implements; it does not change the requirements or create another quality level. The implementation lead follows `/do` through `/done`, including existing-code reuse, behavior-preserving deslop, real verification, and human review.

Read the current user request, environment policy, and the `/do` and `/done` skills. Preserve every requested behavior, architecture constraint, quality requirement, and side-effect boundary. Do not install or execute pstack, ponytail, or other third-party workflow scripts.

## Include the diagram in delegation and acceptance

When the outcome includes a yunomi report, require an embedded explanatory diagram in the lead's deliverables and specify the agreed report/asset paths. For a change to an existing workflow, require side-by-side old/new flows with labeled colors for what stays and what changes. The diagram must retain existing functionality, security review, verification, and human approval where applicable.

The manager checks the source-based comparison, actual diagram file, report embedding, and proof that the image loaded in yunomi. A completion summary, text-only report, screenshot, or before/after code is not a substitute. Return missing or unverified diagrams to the same lead; do not hand a diagram-free report to the human. Follow the current image-generation and user-only regeneration policies.

## Establish ownership before launch

Carry the pre-change functionality and mandatory review/completion conditions from /do into the delegated acceptance criteria, separately from the new requirements. Inspect the /done regression results and every retained review responsibility yourself. A delegate completing the new feature does not excuse a removed existing feature, missing security review, or unresolved Critical/High finding. Restore task-introduced regressions before human acceptance.

- The manager owns the user's scope, decisions, progress, and final evidence assessment.
- One approved implementation lead owns the complete assigned implementation, verification, and acceptance preparation. Do not split a coupled outcome among uncoordinated workers.
- The human owns approval. Neither manager nor implementation lead may approve their own work.

Identify the actual terminal runtime and prove the current Herdr pane with `herdr pane current` and `herdr pane get`. Create the lead in that same validated workspace and tab. Do not infer identity from focus or a broad pane list, and do not substitute tmux, a built-in subagent, or a direct child CLI for Herdr.

Use the available Herdr orchestration skill and the current environment's approved runtime, exact model, reasoning level, and permission settings. Verify the catalog and launch result before submitting work. Do not import upstream model defaults or switch models after a failure. If the authorized lane or routing cannot be established, report the concrete blocker before launch.

Read the installed `herdr-pane-commander` before launch. Preserve the current policy's exact writable-implementation or read-only-review flags; these roles have different permissions. If `herdr pane current` fails, validate any environment-provided id with `herdr pane get` before using it. Missing proven routing blocks launch.

Before assigning multi-step work, require `/do`'s prerequisites, data/state ownership, shared contracts, and verifiable units. Dependent work waits for a verified prerequisite. One lead owns coupled writes; authorized independent roles need disjoint write boundaries and serialized shared-contract changes. A file count or throughput preference does not authorize more agents or fewer checks.

## Delegate a complete task

Start the initial task text with the exact prefix `/goal `. Include the original outcome, all acceptance criteria, protected behavior, relevant source paths, task worktree, permitted side effects, required evidence, and conditions that require the manager's decision. Include one validated parent pane as the only reporting destination; wildcard destinations are prohibited.

For an implementation lead, put the current Herdr helper's exact reporting command, concrete parent pane, and task room in both the initial prompt and persistent rule anchor. Explicitly authorize that reporting action. Delivery of completion, genuine blockers, and received human-review decisions to that parent is part of the assigned outcome, so compaction does not erase the wake-up route. Under the current mailbox protocol this is `herdr msg send <validated-parent> '<report>' --room <task-room>`. Verify the route instead of substituting another sender. The current read-only reviewer exception may require final-response collection instead; keep that role's narrower permissions.

Give the lead `/do` and `/done` by their actual available paths or registered skill names. If a required skill is unavailable to the child, arrange the authorized local distribution before launch rather than assuming inherited context. Use a short task-local record of decisions and remaining work for long tasks; point to it after compaction instead of repeatedly copying long prompts.

Explicitly authorize any required editing, commits, pushes, PR creation, messages, or deployment for that lead. Manager authority does not automatically transfer. A read-only assignment stays read-only. Follow the environment's rules for subordinate delegation and independent reviewers; implementation delegation does not authorize extra models.

Include the user story/scope, actual flow and all-caller evidence, reuse choices, domain invariants, design-review dispositions, TDD, prerequisites and unit verification, project-specific checks, required final reviews, report/diagram/video paths, and human-approval boundary. Separate known facts from unanswered decisions; observe technical facts rather than inventing intent or asking already-answered questions.

Pass the selected procedure name and the exact playbook path from `/do`. The lead follows that file and then `/done`. Do not let the lead invent a different quality level or skip a read-only investigation's no-edit rule.

### Persistent rule anchor and decision trail

For long work, likely compaction, or repeated corrective micro-instructions, establish one project-local rule anchor before continuing. Reuse an agreed existing record if it contains the complete contract; otherwise create the permitted project-local rule file. Do not create `.artifacts/` or relocate the report without authorization.

The anchor contains the original goal, role boundaries, source paths, allowed side effects, reporting destination, prohibitions, decisions with reasons/evidence, and remaining work. Verify the exact file exists. Put “After compaction, restart, or unclear state, read <exact path> first” at the top of manager and lead TODOs. Require the lead to acknowledge the path and TODO before treating the handoff as complete. Read it before resuming after interruption.

Keep consequential checkpoints and evidence-backed corrections in the same record. Reference paths instead of replaying transcripts. This preserves a reviewable decision trail without importing logging scripts or adding another transcript store.

## Supervise without taking over

Let the lead choose implementation details within the fixed requirements. Apply the `/do` reuse and design process and the `/done` deslop and proof standards to the result; do not replace them with a count of files, agents, or lines removed.

Follow meaningful progress and completion reports. If a report stops, is unclear, or lacks evidence, inspect the lead's current pane, final response, bounded execution logs, actual diff, verification results, and remaining processes. Do not merely repeat its completion declaration, leave it unattended, or take over its implementation without an explicit ownership change.

When a criterion is missed, preserve the work and evidence, explain the gap against the original requirement, and return the complete correction to the same approved lead. Keep the requirement and verification standard fixed. A model switch or reduced deliverable is not a recovery plan.

Under Herdr, use `herdr run` first for long commands and inspect durable completion/logs after notification. `herdr pane run-notify` is only for an authorized streaming command, never a yunomi launch. Do not sleep-wait or schedule polling loops. Use bounded `herdr pane read` when progress reporting is missing; do not leave a silent lead unexamined. Follow the current reporting protocol with one proven destination and explicit authorization for any message side effect.

## Accept evidence and finish

Inspect the final diff and real artifacts yourself and confirm that they correspond to the task's final state. Reconcile delegated findings with the original request and any human feedback. Do not duplicate already-proven checks unless changes, failures, or unresolved concerns justify them.

Continue the `/done` human-review and authorized-delivery flow until the outcome is actually complete. Keep one coherent user-facing report. Close only completed task-owned agent panes when permitted; retain the evidence and state needed to explain or resume the work.
