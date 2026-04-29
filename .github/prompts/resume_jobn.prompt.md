---
description: 'Resume the Jobn pipeline from where it left off — read progress.json and continue with the next incomplete ticket or phase'
agent: 'jobn'
argument-hint: 'job name (e.g. sympliact)'
---

Resume the Jobn pipeline for the job named `$input`.

1. Read `jobs/$input/config.yaml`
2. Read `jobs/$input/progress.json` carefully
3. For each ticket that is NOT `completed`:
   - If `not_started`: create worktree, scaffold `.jobn/`, and open in a new VS Code window
   - If `worktree_created` or any in-progress phase: check if the worktree already exists, re-scaffold `.jobn/` if missing, and open it
4. Report which tickets are in which phase and which windows need attention

Begin now.
