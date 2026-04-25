---
description: 'Resume the Jobn pipeline from where it left off — read progress.json and continue with the next incomplete ticket or phase'
agent: 'jobn'
argument-hint: 'job name (e.g. sympliact)'
---

Resume the Jobn pipeline for the job named `$input`.

1. Read `jobs/$input/config.yaml`
2. Read `jobs/$input/progress.json` carefully
3. For each ticket that is NOT `completed`:
   - Determine which phase it's in based on its status
   - Resume from the next phase (e.g. if status is `groomed`, start from Phase 2: Plan)
4. Continue processing through the full pipeline from that point
5. Process remaining `not_started` tickets after finishing in-progress ones

Begin now.
