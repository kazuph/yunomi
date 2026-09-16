# Authoring a skill

Not a slash command. `/do` reads this file when the request creates or changes a skill, playbook, or other agent instruction that Yunomi distributes.

Do not add a new slash command unless the user explicitly asked for a new entry. Nested playbooks under `/do` stay nested.

## Steps

1. Name the instruction being changed, who reads it, and the behavior it must cause.
2. Edit the Yunomi canonical source first (`plugin/skills/...`). Personal copies are distribution, not a second original.
3. Preserve existing obligations. Map each one to its new location. Do not replace a named review with "do the required reviews."
4. If the change is itself a workflow or architecture change, plan the side-by-side explanatory diagram required by `/do`.
5. Confirm distributed copies that this change owns will match the source. Record which destinations are in scope. Do not silently skip Codex, Agents, Claude, or Cursor when the task includes them.
6. Keep notification routing, human approval, and no-third-party-script rules intact.
7. Hand `/done` the source paths, the copy-match evidence, and the preserved obligations.

Continue into `/done`.
