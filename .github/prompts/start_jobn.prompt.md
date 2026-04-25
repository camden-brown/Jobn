---
description: 'Start the full Jobn sprint automation pipeline — read tickets, prioritize, then groom, plan, implement, test, review, and commit each one'
agent: 'jobn'
argument-hint: 'job name (e.g. sympliact)'
---

Start the full Jobn pipeline for the job named `$input`.

1. Read `jobs/$input/config.yaml` for all settings
2. Read all ticket JSON files from `jobs/$input/tickets/`
3. Read `jobs/$input/progress.json` to check for previously completed work
4. Process every non-completed ticket through the full pipeline: worktree → groom → plan → implement → test → review → commit → PR description
5. Update progress after each phase

Begin now.
