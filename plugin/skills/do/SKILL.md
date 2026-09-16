---
name: do
description: Carry a requested change from understanding and design through implementation, verification, and human approval with yunomi.
---

# Own the requested outcome

Canonical source: `kazuph/yunomi`, `plugin/skills/do/`. Personal skill directories contain identical distribution copies. Maintain `/do`, `/done`, and `/bucho` together; edit the Yunomi source first.

Use this entry for a new task or to resume one. Keep the same lead responsible through `/done`; the user does not select a tiny/full mode or request the completion phase separately. For explicit delegated execution, use `/bucho`, which assigns this same workflow to an implementation lead.

Read the current task, repository instructions, and existing task state first. User requirements and environment policies take precedence over this skill. Keep the requested behavior, architecture, quality, and scope intact; never offer or deliver a reduced version to save time, cost, or tokens.

## Select the matching procedure

Before planning work, classify the request and read the matching file next to this skill. Record the chosen name and the exact path. These files are not slash commands; do not add `/investigation` or similar entries.

| Request | Read |
|---|---|
| Explain how something works, why it exists, or which option is safer, with a cited answer rather than a code change | `playbooks/investigation.md` |
| A reported defect to reproduce and fix | `playbooks/bug-fix.md` |
| New or changed observable behavior | `playbooks/feature.md` |
| Structure or placement change that must keep behavior | `playbooks/refactoring.md` |
| Measured slowness | `playbooks/perf-issue.md` |
| Create or change a skill, playbook, or distributed agent instruction | `playbooks/authoring-a-skill.md` |
| Resume an in-flight task from an existing record or worktree | `playbooks/session-pickup.md` |
| None of the above | Write the procedure first in the task record. Do not start implementation until that procedure exists. |

Resolve paths relative to this `SKILL.md`. Investigation is read-only and skips later implementation sections until a different playbook is selected. Other playbooks then continue with the rest of this skill. Hand the chosen name and path to `/done` and, when delegating, to `/bucho`.

## Plan the required explanatory diagram

When this task will be served for yunomi acceptance, plan an explanatory diagram as part of the deliverable before implementation. Name what it must explain, its source evidence, and the retained behavior versus requested changes. For a workflow or architecture change, align the existing and proposed flows side by side and label/color the unchanged, added, changed, and explicitly retired parts. Do not present existing capabilities as new.

Use the agreed artifact location and reference the diagram from the single report. Follow the current image-generation policy; for Codex infographic/image-like deliverables, use the actual image-generation tool. Code examples, tables, screenshots, and a link to an image do not replace the required embedded explanatory diagram. Hand its path, meaning, and verification status to /done. A missing diagram remains unfinished work.

## Preserve existing functionality before adding requirements

Treat the request as an addition to the existing product and workflow unless the user explicitly authorizes a change to existing behavior. Before editing, read the current implementation, specifications, callers, and tests. Record the existing behavior and mandatory checks to preserve separately from the requested additions, together with their source locations and verification methods.

For skill or plugin changes, map each existing obligation to its retained location and responsible executor. Preserve design advice, implementation methodology, code/security review, E2E integrity review, applicable UI/UX and accessibility review, evidence/report validation, and human approval. Do not replace explicit mandatory checks or completion conditions with generic statements such as “perform required reviews.” Runtime routing must follow the current environment policy without dropping review responsibilities.

Preserve requirements discovery: confirm the user story, scope, functional and nonfunctional needs, edge cases, and acceptance criteria; record the user's answers and consequential decisions. Inspect the actual project to select web, backend, mobile, or fullstack verification. Do not replace discovery with a fixed count of questions or infer missing requirements.

Requirements discovery is mandatory even when no new question is needed. For each of those areas, record what the existing request/answers and source evidence establish and what remains unknown. Resolve blocking intent before implementation; keep already confirmed requirements and approvals without asking for them again.

Before implementation, obtain Code & Security design advice, E2E advice when tests are affected, and UI/UX advice when UI is affected using the existing review-code-security, review-e2e, and review-ui-ux instructions. Use the current environment's approved review routing and incorporate findings into the design. Preserve required independent design review and obtain the user's decision on unresolved product or architectural choices; previously approved choices remain approved.

Resolve Critical/High design findings before presenting the approach to the user. Confirm the implementation approach with the user before implementation; do not ask again when that approach is already approved. Plan backend/fullstack test-suite coverage reports and mobile Maestro assertions with per-step screenshots alongside the implementation.

For independent design advice, load `herdr-pane-commander`, prove the parent pane/workspace/tab, and start a separate read-only reviewer session using the current environment's approved model and read-only flags. Pass the design, protected contracts, applicable review instructions, and evidence; collect its final response and disposition every finding. The implementing lead's self-application of a checklist does not count as this independent review. Follow any more specific current environment review policy; do not copy obsolete launchers or upstream model defaults.

Preserve the t-wada TDD cycle for implementation: write a test expressing the expected behavior, run it and confirm the relevant failure (RED), implement until it passes (GREEN), then refactor while it stays green. Include this obligation when delegating implementation. Add reuse decisions and verifiable implementation units within this process; they do not replace it. If a new requirement conflicts with an existing feature or contract, state the actual conflict and obtain an explicit decision before changing it. Do not infer permission from silence, brevity, deslop, or the absence of an old requirement in the latest prompt.

Include both new-behavior checks and regression checks for existing normal/failure paths and affected shared callers in the implementation plan. Hand this baseline, any explicitly approved changes, and the results to /done. If your change removes an existing function or obligation, restore it and reverify before proceeding.

## Understand before choosing

State the requested outcome, protected behavior, allowed changes, and what observable result will prove completion. Carry additions and corrections from the user into the same task. Separate confirmed facts from assumptions; do not invent a persona, acceptance threshold, or requirement.

Trace the real flow through callers, data, interfaces, and affected tests. Read existing helpers and similar features before proposing architecture. For a bug, reproduce the reported behavior and locate the shared cause before editing. Check sibling callers so a small local patch does not leave the same defect elsewhere.

Before changing a function or contract, search all callers, including indirect registrations, jobs, events, and clients where applicable. Read their inputs, outputs, error handling, and side effects. Record and verify the affected paths. Repair the shared cause within the authorized scope; if it requires an unapproved contract change, surface that conflict instead of claiming a one-caller patch fixed the shared defect.

Answer observable questions from the repository or a permitted experiment. Ask the user only for missing intent, a product choice, or an authority boundary that prevents progress. Do not run a fixed interview, ask for already-given permission, or ask the user to accept weaker requirements. A read-only investigation stays read-only.

For an uncertain technical claim, state the competing explanations and the observation that distinguishes them. Test at the actual boundary: UI interaction, API caller and persistence, or the existing performance measurement. Record the input, environment, observed result, and resulting decision. Experiments must stay inside authorized side effects; they do not authorize new tools, production mutations, or implementation during a read-only investigation.

## Choose what must be built

After understanding the flow, consider in order: an existing implementation in the repository; the standard library; a native platform feature; an already-installed dependency; then new code. Stop at a choice only if it satisfies every requested behavior and quality requirement. Native controls and library helpers are not substitutes when their behavior fails the request.

Record consequential design decisions with the reason and the concrete evidence that supports them. Name the data shape, ownership, state transitions, and failure behavior where they affect the task. Add a dependency, abstraction, configuration option, or layer only for a demonstrated requirement. Few lines are not a correctness measure; a readable design with fewer things to maintain is the objective.

Do not add unrelated cleanup. Scope-preserving simplification belongs in the current change; independently discovered improvements require a separate user decision.

### Model the domain before writing control flow

Read the existing model. Identify the affected data, valid states, source of truth, owner of each mutation, and invariants across transitions. Include invalid inputs, partial failure, recovery, and concurrency when present in the actual flow. Record those decisions and public input/output/error contracts before implementation.

Choose the existing type, constrained schema, transition table, or other supported representation that expresses those constraints without scattered flags or repeated branches. Explain how it covers observed cases and retained callers. Do not invent a state machine or abstraction when the current structure already represents the domain correctly.

When boundaries change, compare viable responsibilities and their effects on callers, data ownership, and testing. Read the actual `review-code-security`, `review-e2e`, and `review-ui-ux` instructions from the trusted Yunomi plugin/checkout and obtain the applicable design advice through the approved independent route. Naming a reviewer is not performing its review. Record its exact instruction path, findings, and dispositions; do not run legacy commands that expose secret values or violate current permissions.

## Prepare and implement

Prove the repository, branch, worktree, and existing changes before writing. Keep the original checkout on its verified default branch and create or reuse a task worktree with `git wt` beneath it. Preserve others' changes. If the required worktree operation is unavailable, report the blocker rather than switching the original checkout.

Use the repository's current environment and tools. Do not install third-party workflow scripts, create global hooks, initialize encryption, change authentication, or add dependencies as incidental setup. Any necessary new executable helper needs a specification of inputs, outputs, side effects, and failure behavior before implementation.

Plan implementation and verification together. Divide the work at boundaries where a real result can be checked before the next change. For a reproduced defect, keep an executable regression check; follow the repository's required test method. Use existing test frameworks and permitted local emulators; do not use mocks, bypasses, or fabricated successful output.

### Sequence dependencies and verifiable units

Before nontrivial multi-step work, identify prerequisites, shared mutable state, invariants, and independent parts. Give coupled work one owner. Resolve prerequisite decisions and contracts before dependent work, and serialize writes to shared contracts/files. Parallelism requires an independent or isolated purpose, not a target agent count.

For each unit, record purpose, preserved behavior, affected files/callers, prerequisite, owner, implementation work, and verification with the expected observable result. Establish the baseline, implement the unit, and verify it before starting a dependent unit. A failed or inconclusive check requires diagnosis and correction; never accumulate unverified migrations for a final batch check. Keep TDD and authorized commit boundaries intact.

### Preserve project-specific verification

Classify actual manifests, source, runtime, and affected surfaces; investigate an unfamiliar project instead of silently defaulting to web. Fullstack includes both client and backend checks, plus mobile when affected.

| Surface | Required verification |
|---|---|
| Web | Build/static checks, actual dev server, real browser interaction, meaningful UI assertions, and resulting stored records when changed. |
| Backend | Existing real test framework, actual database or permitted local emulator through DI, API input/output/error and persisted-result assertions, test suite and coverage report. Manual requests do not replace the suite. |
| Mobile | Build, required emulator/device, Maestro assertions such as `assertVisible`/`assertText`, screenshots at each step including before/after, and target devices/screen sizes. |
| Fullstack | Web and backend requirements plus evidence across the actual request/response/persistence path. |

E2E flows use real login and UI navigation after the initial page entry. Do not call APIs, change localStorage, or directly enter downstream routes to bypass the user's flow. Use real UI creation or explicitly permitted seed data; assert visible and persisted results and wait for actual elements/state, not arbitrary delays. Mocks, stubs, network interception, fake timers/databases, and authentication shortcuts are prohibited. DI may connect tests to local services such as Firebase Emulator or Mailpit, not fake replacements.

Load the applicable installed `webapp-testing`, `backend-testing`, or `mobile-testing` instructions and existing evidence/report helpers. Record their paths and the agreed task report path. Preserve their obligations under the current runtime/browser policy. Do not execute retired launchers or let a helper override the explicit report path. An already approved worktree artifact path remains valid; keep its report and evidence. For a new task with no authorized report location, resolve that missing location before creating files, while continuing independent authorized work. Never infer permission to create `.artifacts/` from an old helper example or silently scatter evidence into substitute directories.

Also read the applicable existing `webapp-impl`, `backend-impl`, or `mobile-impl` instruction file from the trusted Yunomi plugin/checkout and follow its implementation checklist, whether implementing directly or through a lead. For Web UI, read the installed `frontend-design` skill and carry its applicable design and accessibility requirements into the plan and verification, including reduced-motion preferences. Preserve the user's existing design system and current design policy over a helper's aesthetic presets. Direct implementation replaces the old mandatory agent launch, not the requirements that agent used to load. `/done` must verify these inherited requirements as well.

Implement directly unless an independent or isolated role has a concrete benefit and delegation is authorized. Follow the environment's runtime, model, permissions, and routing rules. Give each delegate the complete outcome, protected requirements, allowed files and side effects, stopping conditions, and evidence to return. The lead remains responsible and inspects the actual diff and results.

## Verify and finish without another prompt

Exercise the changed behavior through its real user or caller path. Build success alone is not a behavioral check. Verify the relevant input, visible result, and persisted or external effects; integrations require evidence across the communication path. Keep required security, accessibility, failure, and recovery checks.

Invoke `/done` with the original request, current worktree and diff, design decisions, verification commands and results, evidence locations, and unresolved items. `/done` owns deslop, final verification and review, the report, and the human approval loop. Do not duplicate those steps here or stop at implementation complete.

## Resume without losing the task

Keep a short task-local record of the original outcome, decisions, affected paths, verified results, and outstanding work. Reuse the repository's existing record; do not create `.artifacts/` without permission. Read it after context compaction and verify current runtime and repository state before resuming. Reference source paths instead of repeatedly pasting long logs or entire skills into prompts.

In that same record, keep consequential checkpoints: claim/question, decision, reason, alternatives considered, source/evidence path, result, and next dependency. Preserve user answers and feedback verbatim. Append corrections and their evidence when a decision proves wrong; do not rewrite history. Put the current outcome first and the compact decision trail in its own section, without adding a logger or transcript store.

After feedback or compaction, read the existing record/worktree/TODO before creating anything. Give each feedback item its original wording, required change, and verification method. A TODO is complete only with implementation and verification evidence; human approval stays separate. Continue through `/done` without requiring the user to restart the task.

Pause only for a real blocker, explicit user pause, or human approval. Report what cannot proceed and why, while continuing independent authorized work. Completion means the requested outcome and required evidence are accepted by the human and any authorized delivery steps are finished.
