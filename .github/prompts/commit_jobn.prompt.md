---
description: 'Run only the commit phase — stage and commit changes in worktrees with spread timestamps'
agent: 'jobn'
argument-hint: 'job name (e.g. sympliact) or job name + ticket ID'
---

Run only the commit phase for the specified job (all reviewed tickets) or a single ticket.

Parse the input:

- If one word: job name → commit all tickets with status `reviewed`
- If two words: job name + ticket ID → commit only that ticket

1. Read `jobs/{job_name}/config.yaml` for commit settings
2. Read `jobs/{job_name}/progress.json`
3. For each applicable ticket, delegate to the `jobn-committer` subagent
4. Update progress.json after each commit

Input: `$input`
