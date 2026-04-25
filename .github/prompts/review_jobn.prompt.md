---
description: 'Run only the review phase — self-review all changes in worktrees, check for bugs, security issues, and verify acceptance criteria'
agent: 'jobn'
argument-hint: 'job name (e.g. sympliact) or job name + ticket ID'
---

Run only the review phase for the specified job (all tested tickets) or a single ticket.

Parse the input:

- If one word: job name → review all tickets with status `tested`
- If two words: job name + ticket ID → review only that ticket

1. Read `jobs/{job_name}/config.yaml`
2. Read `jobs/{job_name}/progress.json`
3. For each applicable ticket, delegate to the `jobn-reviewer` subagent
4. If issues are found, delegate to `jobn-implementer` for fixes, then re-review
5. Update progress.json after each review

Input: `$input`
