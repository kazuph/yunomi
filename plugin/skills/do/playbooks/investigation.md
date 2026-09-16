# Investigation

Not a slash command. `/do` reads this file when the request is to explain how something works, why it exists, or which option is safer, and the deliverable is a cited answer rather than a code change.

This playbook is **read-only**. Do not edit the repository. Do not run formatters, generators, or "while we're here" fixes. If the user then asks for a change, stop this playbook and select `bug-fix` or `feature`.

## Steps

1. State the question, the code or behavior it refers to, and what observable evidence would answer it.
2. Trace the real flow with `/do`'s understand-before-choosing rules. Name callers, data, and failure paths.
3. If the question is motive or history, read `../why.md`. Keep recorded, inferred, and unknown claims separate.
4. Write the answer as Overview, Key Concepts, How It Works, Where Things Live, and Gotchas. For a choice between options, add a comparison table and a recommendation.
5. Hand `/done` a record that this was an investigation: no task-owned diff, the cited answer as the deliverable.

Do not open a PR. Do not start TDD. `/do`'s later implementation sections do not apply until a different playbook is selected.
