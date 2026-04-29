---
description: 'Start the full Jobn sprint automation pipeline — read tickets, prioritize, then groom, plan, implement, test, review, and commit each one'
agent: 'jobn'
argument-hint: 'job name (e.g. sympliact)'
---

Start the full Jobn pipeline for the job named `$input`.

1. Read `jobs/$input/config.yaml` for all settings
2. Read all ticket JSON files from `jobs/$input/tickets/`
3. Read `jobs/$input/progress.json` to check for previously completed work
4. For every non-completed ticket: create a worktree, scaffold `.jobn/` context, and open it in a new VS Code window
5. After all worktrees are set up, tell me which windows to kick off and in what order

Begin now.
