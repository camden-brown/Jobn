---
description: 'Plan implementation for a single ticket — analyze codebase and create PLAN.md with file changes, approach, and commit boundaries'
agent: 'jobn'
argument-hint: 'job name and ticket ID (e.g. sympliact WEB-315)'
---

Plan only the specified ticket.

Parse the input: the first word is the job name, the second is the ticket ID.

1. Read `jobs/{job_name}/config.yaml`
2. Read the ticket JSON from `jobs/{job_name}/tickets/{ticket_id}.json`
3. Read the existing GROOM.md from the worktree (ticket must be groomed first)
4. Delegate to the `jobn-planner` subagent to create PLAN.md
5. Update progress.json to `planned`

Input: `$input`
