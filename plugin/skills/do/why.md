# Why this code exists

Not a slash command. `/do` reads this file from `investigation` and `bug-fix` when the question is motive, not runtime behavior. Use existing git and, when already available, `gh`. Do not add MCP servers, investigators, or logging scripts.

## What to recover

Anchor the question in concrete files, symbols, and line ranges. Then collect:

- `git blame` on the relevant lines
- `git log --follow` for the file, including renames
- merge commits and PR numbers in those messages
- `gh pr view` only when GitHub CLI already works in this repository

Do not invent a ticket, chat, or observability search. If Linear, Slack, or similar tools are already available in this environment, you may use them; missing tools are a gap, not a reason to install anything.

## Separate kinds of claim

Keep these apart in the record and in the reply:

- **recorded**: what a commit, PR, comment, or document actually says, with the path or URL
- **inferred**: a reasonable reading that is not written down
- **unknown**: what was not found

Do not treat the newest commit as the whole reason. The current shape may be several older decisions stacked together.

## Output

Answer the question, then list sources consulted, including empty searches. If this why is a precursor to a change, add Preserve / Change / Avoid / Risk from the recorded evidence. Hand that set to the selected implementation playbook. Do not start editing from this file.
