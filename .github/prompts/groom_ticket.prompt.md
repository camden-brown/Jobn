---
description: 'Groom a single ticket — generate stakeholder-facing GROOM.md with acceptance criteria and QA test plan'
agent: 'jobn'
argument-hint: 'job name and ticket ID (e.g. sympliact WEB-315)'
---

Groom only the specified ticket.

Parse the input: the first word is the job name, the second is the ticket ID.

1. Read `jobs/{job_name}/config.yaml`
2. Read the ticket JSON from `jobs/{job_name}/tickets/{ticket_id}.json`
3. Set up the worktree if not already created (check progress.json)
4. Delegate to the `jobn-groomer` subagent to create GROOM.md
5. Update progress.json to `groomed`

Input: `$input`
