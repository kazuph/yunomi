#!/usr/bin/env bash

# UserPromptSubmit hook: Output completion checklist
# This message is injected into AI's context BEFORE generating a response

cat << 'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "additionalContext": "[yunomi-plugin] Session Start & Task Resumption Guide\n\n【Task Resumption】When starting a session or after compact, verify the following:\n\n  → Check the verified task worktree with git wt; keep the original checkout on its default branch\n  → Read the agreed task report path for the current plan, decisions, and progress\n  → Review TODOs in REPORT.md and resume from incomplete items\n  → If user adds new requests during the session, ALWAYS add them to TodoList immediately\n\n【Report Location】\n  Use the exact report/evidence paths agreed for this task and pass them to /do, /done, and /bucho. Do not create or relocate .artifacts without authorization.\n\n【TodoList Management (CRITICAL)】\n  → When user adds new requests/tasks, IMMEDIATELY add them to TodoList\n  → TodoList is the contract with the user - never skip this step\n  → Update todo status in real-time as you work\n  → Mark tasks complete ONLY after user approval\n\n【Completion Criteria】Implementation alone is only 1/3. Verify the following:\n\n□ Implementation Complete (1/3)\n  → Did the build succeed? (npm run build / pnpm build)\n  → Are there no type errors or lint errors?\n\n□ Verification Complete (2/3)\n  → [Web] Did you verify with webapp-testing skill (Playwright)?\n  → [Backend] Did you run the test suite with backend-testing skill (vitest/go test/pytest/cargo test)?\n  → [Mobile] Did you run Maestro E2E flows with mobile-testing skill?\n  → Did you collect evidence (screenshots/test output)?\n\n□ Review Complete (3/3)\n  → Are the required explanatory diagram, screenshots, and video embedded in the agreed report, with actual image loading verified?\n  → Did you create a report using artifact-proof skill?\n  → Did you execute /done, retain Code & Security / E2E / applicable UI/UX reviews, and resolve Critical/High findings?\n  → Did you use the current yunomi protocol with --loop and a proven Herdr or tmux notification route?\n  → Did you get approval from the user?\n\n【Prohibited Actions】\n  ✗ Reporting only \"Implementation done!\"\n  ✗ Declaring completion without testing\n  ✗ Reporting \"It works!\" without evidence\n  ✗ Committing/pushing before yunomi review\n  ✗ Ignoring new user requests without adding to TodoList\n\n【If the above is incomplete】\n  → Do not report completion; communicate what should be done next\n  → Execute /done to proceed to the review flow"
  }
}
EOF

exit 0
