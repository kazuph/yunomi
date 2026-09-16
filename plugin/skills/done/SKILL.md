---
name: done
description: Verify an existing task, remove unnecessary complexity without changing behavior, and carry the evidence through yunomi human review and authorized delivery.
---

# Complete and prove the work

Canonical source: `kazuph/yunomi`, `plugin/skills/done/`. Personal skill directories contain identical copies, distributed together with `/do` and `/bucho`.

Use after `/do`, after a `/bucho` implementation lead finishes its work, or when the user requests completion of an existing task. There is one completion standard, with no tiny/full or evidence-only choice. Required checks follow the actual requirements, affected behavior, and repository rules.

Recover the original request, corrections, decisions, worktree, diff, tests, and evidence. If a piece is missing, inspect the real state rather than guessing or restarting the task from scratch. Do not silently change the request to fit the implementation.

Read the adjacent `/do` verification contract. Resolve and read the applicable `review-code-security`, `review-e2e`, `review-ui-ux`, `report-builder`, and `report-validator` instruction files from the trusted Yunomi plugin/checkout, plus the installed testing, `artifact-proof`, `validate-report`, and `yunomi` skills. Record exact paths. A name in a prompt is not a completed review; missing required instructions/capability must be restored from an authorized local source or reported as a blocker, never silently skipped or downloaded as a new runner. Apply checklists without executing legacy secret-printing commands or violating the current read-only reviewer policy.

For standalone `/done` as well as a `/do` handoff, read the applicable `webapp-impl`, `backend-impl`, or `mobile-impl` checklist and, for Web UI, `frontend-design`. Verify the inherited implementation/design requirements, including reduced-motion preferences, against the existing user design system and current policy.

## Inherit the selected procedure

Recover the playbook name and exact path from `/do`, or classify a standalone completion the same way `/do` would. Do not reclassify unless the remaining work is a different kind of request. Then verify that playbook's completion condition:

| Selected procedure | `/done` must confirm |
|---|---|
| `investigation` | No task-owned edits. The deliverable is the cited answer. |
| `bug-fix` | The original reproduction is gone on the same surface, and the shared cause is covered beyond one caller. |
| `feature` | New behavior and retained behavior both have real-surface evidence. Rejected designs remain in the record. |
| `refactoring` | Before/after results match for preserved callers and inputs. Public APIs were not removed unless the user explicitly authorized it. |
| `perf-issue` | The same existing measurement has before and after numbers. Behavior is unchanged. |
| `authoring-a-skill` | Canonical source and in-scope distributed copies match. Named reviews were not replaced by a generic reminder. |
| `session-pickup` | Remaining work matches the existing record. The user was not asked to restart the task. |

Then continue with the rest of this skill. Deslop, specialist reviews, diagram, and human approval stay required for work that changed the product or the workflow. A read-only investigation still needs a reviewable answer; it does not need a code deslop.

## Check the requested outcome

For each requirement, identify the implemented behavior and the actual result that verifies it. Keep unmet, failed, and unverified items distinct. Fix missing work within the task's authorized scope. Do not ask the user to accept a partial or degraded substitute.

Confirm that every changed file belongs to this task, existing work is preserved, and design decisions are reflected in the code. The lead verifies subordinate artifacts and results directly; a delegate's summary is not evidence.

Reconcile every unit's verification and corrections with the final diff, domain/state/ownership decisions, and affected callers. Confirm coverage of the shared cause beyond the reported caller. Track implementation, build/runtime verification, evidence, human acceptance, and delivery separately; a checked implementation TODO does not prove the other stages.

## Required diagram before yunomi acceptance

Every yunomi acceptance report must include an explanatory diagram that makes the outcome or change understandable. For an existing-versus-new comparison, align both flows and label/color retained, added, changed, and explicitly retired behavior. Keep essential existing functions and review gates visible. Tables, before/after code, screenshots, or a bare image link alone do not satisfy this requirement; retain them as supporting evidence when needed.

Embed the actual diagram in a Markdown table with image syntax. Verify the file exists and the final report references it before launch. After launching yunomi, verify in the browser that the embedded image loads with nonzero natural dimensions before asking for acceptance. Compare required labels with the source-based specification using the runtime's numerical/OCR verification policy; do not claim semantic correctness from visual impression. Generation alone, an HTTP-success page without its image, or opening the separate PNG is not the final display check.

Pass the same report and diagram paths to artifact-proof, validate-report, and the report-validation role. Their older alternatives or aggregate scores must not waive this diagram requirement. Missing, inaccessible, or unverified diagrams remain unfinished: fix missing files or embedding before asking for acceptance. Follow the user-only regeneration rule for an already generated image; report a failed check and await the user's regeneration decision without declaring the image accepted.

## Verify preservation of existing functionality

Recover the pre-change baseline and the preservation record from /do, or reconstruct them from the actual base revision, specifications, callers, and tests. Check the requested additions separately from the retained functionality. Verify existing normal and failure behavior, affected shared callers, security boundaries, public contracts, and workflow completion conditions. Passing tests for only the new feature is insufficient.

For skill and plugin changes, compare each existing obligation with its new location, executor, and completion condition. A generic “follow repository rules” clause is not evidence that a specific review survived. Preserve all obligations not explicitly changed by the user. Restore regressions introduced by this task, rerun the affected checks, and report unverified behavior as unverified.

## Deslop the task diff

Review only this task's additions for unnecessary maintenance burden:

- Code that duplicates a repository helper, standard library facility, native platform capability, or installed dependency that meets the full requirement.
- Abstractions, wrappers, configuration, or indirection without a current purpose.
- Casts used to hide a type mismatch, inconsistent data ownership, and defensive checks that hide a broken internal contract.
- Comments that restate the code, repetitive explanations, and patterns inconsistent with the surrounding implementation.

Make focused, behavior-preserving corrections when the evidence supports them. Keep required validation at trust boundaries, data-loss handling, security, accessibility, diagnostics, and tests. Do not remove something merely to lower line count or shorten a prompt. Do not turn this pass into a repository-wide refactor or add an unrelated feature.

If no unnecessary complexity is found, continue without inventing a cleanup. If cleanup changes the code, rerun the affected checks before using previous results in the final report. Prose cleanup must retain the facts, reasoning, limitations, and decision context the reader needs.

## Verify the real result and review

Run the repository's required build and static checks, and exercise the changed behavior on the appropriate surface. A screenshot alone does not prove interaction or persistence; check the action and resulting state. Web work uses the real browser path, backend work uses real requests and persisted results through the permitted test framework, and mobile work uses the required emulator or device workflow.

For backend/fullstack, run the real test framework against the actual database or permitted local emulator and generate its coverage report (using its supported coverage option); curl or manual API calls do not replace this gate. For mobile, run the Maestro flow with assertions for the requested behavior and resulting screen state, and capture evidence at each step. For web, verify the user's requested action and record changes through the real UI before collecting screenshots. Inspect the evidence before accepting it; a successful command or image file alone is insufficient.

Choose additional checks from the change's claims and risks, not from a file-count threshold or a universal checklist. Do not skip a required gate, weaken its criteria, introduce mocks, or present an inconclusive result as a pass. Evidence must come from the final changed state; identify which checks a later edit invalidates.

Before recording screenshots/video, confirm that tests reach the requested change, perform its interaction, assert the result, and observe the changed records/screen. Preserve initial-entry-only navigation, real authentication, UI-operated flows, state-based waits, and no mocks/bypasses from `/do`. Retain mobile target devices/screen sizes and per-step before/after evidence. Repair and rerun tests that pass without exercising the requested behavior before collecting evidence.

Complete the environment's required independent reviews, CI, and delivery prerequisites in their required order. Reviewers receive the original request, exact diff, constraints, and evidence. Inspect their findings, fix valid issues, explain disagreements with evidence, and reverify the final state. Model and runtime selection belongs to the environment policy, not to this skill.

Load `herdr-pane-commander` before independent review. Prove the parent pane/workspace/tab, launch the required separate read-only reviewer sessions with the current environment's approved models and read-only flags, and supply the exact diff, applicable specialist instruction files, and evidence. Collect every final response with the validated pane's read command and record findings/dispositions yourself; reviewers must not edit the report. The implementing lead's own checklist pass does not satisfy independent review. Follow the environment's required reviewer count, review timing, and more specific routing policy without reinstating retired Task recipes.

The following review responsibilities remain mandatory; use the environment's approved independent reviewer routing and models, not a retired Task-tool launch recipe:
- Code & Security Review for every project type: type safety, error handling, duplication, OWASP-related risks, XSS/injection, authentication/authorization, and hardcoded or exposed secrets. Use the existing review-code-security instructions.
- E2E Test Review for every project type, adapted to web, backend, or mobile: real user/caller flows, meaningful assertions on resulting and persisted state, API contracts, mock/bypass detection, dependency injection, wait strategies, environment assumptions, and coverage of user feedback. Use the existing review-e2e instructions.
- UI/UX Review for affected web/mobile/fullstack UI: WCAG 2.2 AA, keyboard/focus behavior, design consistency, copy, and applicable internationalization. Backend-only work has no UI surface. Use the existing review-ui-ux instructions.
- The environment's required independent code reviews, with concrete findings and verification of the final changed state.

Read all findings before serving the acceptance report. If any Critical or High finding remains, fix it, rebuild and reverify, and obtain the affected re-review. Do not advance to human acceptance with unresolved Critical/High findings. Retain the complete finding dispositions and review evidence.

For each finding, fix a valid issue within scope, dismiss it with concrete source/test evidence, or obtain a decision on an unapproved behavior change. Do not blindly apply advice that drops a feature or boundary check. Supply the exact final revision/diff for review. An empty, missing, or unread final response is incomplete review.

## Serve the result with yunomi

Load the installed `yunomi` skill for the browser-review and notification protocol. If it is missing, the installed yunomi CLI's `--skill` output provides that protocol; do not download a third-party workflow runner. A missing required CLI is a concrete blocker.

Write one reviewable report using the user's or repository's required format. Lead with the original request and the resulting behavior. Explain consequential choices, show representative evidence, and identify unmet or unverified requirements. Use tables to connect requirements, results, and evidence; embed images in table cells when required. Keep old task logs out of the report unless they explain a current decision.

Write in the user's language; REPORT.md is not a PR-description template. Keep exact accumulated feedback and consequential decisions/corrections from `/do`. Put the outcome and decision material before raw logs. Tables carry comparable facts; prose explains reasoning. Put detailed passing output in `<details>`. Embed both images and videos with `![]()` in tables and verify links; bare download links do not replace embedded media.

Retain the former Full Review evidence requirement: screenshots and video of the verified operation, with a comprehensive REPORT.md. Screenshots alone do not replace the video evidence. Preserve the project-type-specific test and coverage evidence as well; changing the report presentation does not waive any of these requirements.

Preserve the existing report-builder/report-validator responsibilities: original request and feedback, decisions and reasoning, review results, embedded evidence, working evidence links, and report-format validation. Use their applicable instructions without overriding the current environment's execution and reporting rules. Deslop adds a behavior-preserving cleanup pass; it never replaces security review, test review, report validation, or human approval.

Run the existing validate-report skill before opening the acceptance report, then complete its browser image-load check after launch and before asking for acceptance. Its checks retain the original request followed by the outcome, the user's language, embedded media in tables, decision questions beside their evidence, verbatim accumulated feedback, useful factual tables, and the mandatory explanatory diagram. Screenshots and before/after code remain supporting evidence. Fix failed pre-launch checks before opening yunomi. Keep review findings and their dispositions available; presentation choices never waive required reviews or permit unresolved Critical/High findings.

Resolve one actual report path for this task and pass that same path to every review and report-validation role. If legacy helper instructions hardcode `.artifacts/<feature>/REPORT.md` or a retired agent launcher, apply their review checklist to the explicit report path through the environment's approved route. The lead incorporates read-only reviewers' results into that report. Do not create an unapproved directory, inspect an unrelated report, or skip validation because a legacy path or launcher differs.

Put a decision question beside the facts needed to answer it, with one checkbox per concrete option. The human grants approval; the agent must not resolve the human's comments or interpret silence, a closed tab, or successful process exit alone as acceptance.

Start a writable review only with a verified notification route and the required loop settings from the yunomi protocol. Read every returned verdict and its feedback. Request changes returns to implementation, affected verification, and the same review loop; it is not a new task. Do not require the user to invoke `/do` again.

Register each original comment and summary as implementation plus verification TODOs. Preserve earlier feedback and human-owned resolution state. Fix the implementation, rerun affected checks, refresh evidence, and update the same report before resubmitting. Do not merely explain an unfixed defect in the report or mark an edit verified without running its check.

## Deliver and hand back

After the human approves, finish the authorized commit, push, merge, release, installation, or deployment steps in the repository's required order. Approval to review does not authorize new external side effects. Verify the actual delivered state, and keep implementation, verification, review, and delivery status separate.

Keep task-owned services alive while the human needs them. Clean up only resources this task owns and is authorized to remove; preserve evidence and other work. Report the requested outcome, what remains, and the concrete evidence supporting completion.
