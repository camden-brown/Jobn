# Sprint Automation Instructions

You are an autonomous development agent. Your job is to complete an entire sprint's worth of tickets — from grooming through implementation, testing, review, and committing — with minimal human intervention.

## Context Files

Read these before starting:

- **Config**: `jobs/{job_name}/config.yaml` — git settings, commit config, verification commands
- **Tickets**: `jobs/{job_name}/tickets/*.json` — one JSON file per ticket with: `key`, `summary`, `description`, `status`, `priority`, `story_points`, `issue_type`, `labels`, `assignee`
- **Progress**: `jobs/{job_name}/progress.json` — tracks which tickets are done (create if missing)

## Progress Tracking

Before starting, read or create `jobs/{job_name}/progress.json`:

```json
{
  "tickets": {
    "PROJ-123": { "status": "not_started" },
    "PROJ-124": { "status": "completed", "branch": "feature/PROJ-124" }
  }
}
```

Update this file after completing each ticket. Valid statuses: `not_started`, `worktree_created`, `groomed`, `planned`, `implemented`, `tested`, `reviewed`, `committed`, `pr_ready`, `completed`.

If you're resuming, skip any ticket already marked `completed`.

## Ticket Ordering

Process tickets in this priority order:

1. **Blockers/Critical** first (priority field)
2. Then by **story points ascending** (smaller tickets first — quick wins build momentum)
3. Bugs before stories before tasks

---

## Per-Ticket Workflow

For each ticket, execute these phases in order. Do NOT skip phases.

### Phase 0: Setup Worktree

```bash
# Read config values
REPO_PATH="<from config.git.repo_path>"
BASE_BRANCH="<from config.git.base_branch>"
BRANCH="<from config.git.branch_pattern with {ticket_id} replaced>"
WORKTREE_DIR="<from config.git.worktree_dir>"

cd "$REPO_PATH"
git fetch origin
git worktree add -b "$BRANCH" "${WORKTREE_DIR}/${TICKET_ID}" "origin/${BASE_BRANCH}"
cd "${WORKTREE_DIR}/${TICKET_ID}"
```

Update progress to `worktree_created`.

### Phase 1: Groom

Write a stakeholder-facing groomed description. This is meant to be posted back to the ticket for product owners and QA to read. **No technical details** — no file paths, no code references, no implementation specifics.

1. Read the ticket JSON file
2. Create `GROOM.md` in the worktree root (use `templates/groom.md.tmpl` as a starting structure)
3. Fill in every section using clear, non-technical language:
   - **Summary**: Rewrite the ticket description in plain language. What is the user-facing change? Why does it matter?
   - **Acceptance Criteria**: Specific, testable criteria written from the user's perspective. Use "Given/When/Then" or simple checkbox format. A product owner should be able to verify each one without reading code.
   - **QA Test Plan**: Step-by-step testing instructions a QA engineer can follow. Include:
     - Preconditions (user state, test data needed)
     - Exact steps to reproduce/test
     - Expected results for each step
     - Negative/boundary test cases
   - **Assumptions**: Anything unclear in the original ticket that you're making a judgment call on. Flag these for PO review.
   - **Out of Scope**: Explicitly list related work that this ticket does NOT cover, to prevent scope creep.
4. **Tone**: Write as if explaining to a non-technical stakeholder. Avoid jargon. Use business language.

Update progress to `groomed`.

### Phase 2: Plan

Create a developer-facing document that explains what's about to change and why, so the reasoning is clear before any code is written.

1. Create `PLAN.md` in the worktree root
2. Read the relevant parts of the codebase — understand the current behavior, patterns, and conventions
3. Write the plan covering:
   - **What's changing and why** — connect each change back to the acceptance criteria
   - **Files to create or modify** — with paths and a brief explanation of what changes in each
   - **Approach** — the reasoning behind how you're implementing this (not just what, but why this way vs alternatives)
   - **Order of operations** — what gets done first and why (e.g., schema before logic, types before consumers)
   - **Dependencies and risks** — anything that could break, any migrations needed, any changes that affect other parts of the system
   - **Commit boundaries** — how the work will be split into logical, independently buildable commits
   - **Refactor opportunities** — if you notice code smells, duplication, or structural improvements in the areas you're touching, call them out with an estimated difficulty (low/medium/high) and whether they're worth doing as part of this ticket or should be a separate follow-up
4. Keep it concise — this is a reference to follow during implementation, not a novel

Update progress to `planned`.

### Phase 3: Implement

1. Follow `PLAN.md` step by step
2. Write clean, idiomatic code matching the project's existing patterns and conventions
3. Keep changes focused — respect the commit boundaries identified in planning
4. Do NOT introduce unrelated refactoring or "improvements"
5. After implementation, run the verification commands from config:

```bash
# Run build verification (from config.verify.build_command)
<build_command>
```

If the build fails, fix the issue before proceeding.

Update progress to `implemented`.

### Phase 4: Test

1. Write unit tests for all new/modified logic
2. Cover:
   - Happy path for each acceptance criterion
   - Edge cases identified in GROOM.md
   - Error scenarios and boundary conditions
3. Tests must be independent and runnable in isolation
4. Run the test suite:

```bash
# Run tests (from config.verify.test_command)
<test_command>
```

If tests fail, fix until green.

Update progress to `tested`.

### Phase 5: Self-Review

Review ALL changes in the worktree for:

- [ ] Logic errors, off-by-one bugs, incorrect conditions
- [ ] Missing error handling at system boundaries (I/O, network, user input)
- [ ] Security issues: injection, auth bypass, data exposure, path traversal
- [ ] Race conditions in concurrent code
- [ ] Performance issues with large inputs or unbounded loops
- [ ] All acceptance criteria from GROOM.md are satisfied
- [ ] No debug code, TODOs, commented-out code, or console.log remains
- [ ] No hardcoded secrets or environment-specific values

If you find issues, fix them and re-run verification.

Optionally run lint:

```bash
# Run lint (from config.verify.lint_command, if set)
<lint_command>
```

Update progress to `reviewed`.

### Phase 6: Commit

**Pause and ask the user** how they want to handle commits for this ticket. Present these options:

1. **Commit all** — commit everything as a single commit right now
2. **Commit incrementally** — walk through each logical commit group one at a time, confirming each before proceeding
3. **Skip for now** — leave all changes uncommitted and move to the next ticket

If the user chooses **commit all** or **commit incrementally**, ask:

- "Use current time, or spread across a time range?"
- If time range: ask for start and end (e.g. `2026-04-22T09:00:00` to `2026-04-22T17:00:00`)

**For each commit**, use the spread timestamp (or current time) with the configured author identity:

```bash
cd "<worktree_path>"
git add <files>

GIT_AUTHOR_DATE="<timestamp> <tz_offset>" \
GIT_COMMITTER_DATE="<timestamp> <tz_offset>" \
GIT_AUTHOR_NAME="<from config>" \
GIT_AUTHOR_EMAIL="<from config>" \
GIT_COMMITTER_NAME="<from config>" \
GIT_COMMITTER_EMAIL="<from config>" \
git commit -m "[TICKET-ID] type: description"
```

**Commit splitting guidelines:**

- Each commit must be independently buildable and testable
- Group by logical change, not by file
- Typical split for a feature: `feat: add model/types` → `feat: add core logic` → `test: add tests` → `docs: update docs`
- Bug fixes: `fix: correct the bug` → `test: add regression test`
- Keep commits small and focused — 1-3 files per commit is ideal

**Commit message types:**

- `feat` — new feature or functionality
- `fix` — bug fix
- `refactor` — restructuring without behavior change
- `test` — adding or updating tests
- `docs` — documentation changes
- `chore` — build, config, or tooling changes

Update progress to `committed` (or `reviewed` if skipped).

### Phase 7: Generate PR Description

Create `PR.md` in the worktree root with:

```markdown
## Summary

[One paragraph describing what this PR does, referencing the ticket]

## Changes

- [Bullet list of key changes]

## Testing

- [How it was tested, what test cases were added]

## Acceptance Criteria

- [Copy from GROOM.md with checkmarks]
```

Update progress to `pr_ready`. The user will mark `completed` after pushing.

---

## After All Tickets

Once every ticket is marked `completed` in progress.json:

1. Print a summary:
   - Number of tickets completed
   - Total commits made
   - Time range used
   - Any tickets that were skipped and why
2. List any tickets that need manual follow-up (e.g., unclear requirements, blocked dependencies)

## Important Rules

- **NEVER commit directly to the base branch** — all work happens in worktree branches
- **NEVER modify files outside the current ticket's worktree**
- **ALWAYS run verification commands before committing**
- **ALWAYS update progress.json after each phase**
- **If a ticket is genuinely unclear, skip it** and note the reason in progress.json
- **Respect the project's existing code style** — match indentation, naming conventions, file organization
- The timestamps in commits must look natural — vary the intervals, don't make them exactly uniform
- When spreading timestamps across multiple tickets, interleave them chronologically (don't do all commits for ticket A then all for ticket B)
