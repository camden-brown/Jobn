---
description: 'Generate a PR description from committed changes. Use when: changes are already committed, need a PR description to copy into GitHub/ADO.'
---

Analyze the committed changes on the current branch (compared to the base branch) and generate a PR description.

## Procedure

1. Determine the base branch (usually `main` or `develop` — check git config or ask)
2. Run `git log --oneline origin/{base}..HEAD` to see all commits
3. Run `git diff origin/{base}..HEAD --stat` for a file summary
4. Read the changed files to understand the full scope

## Output

Create `PR.md` in the project root:

```markdown
## Summary

[One paragraph: what this PR does. Lead with user/business value, not technical details. Reference the ticket if applicable.]

Closes {ticket_id}

## Changes

- [Bullet list of key changes — what changed and WHY, not just file names]
- [Group by logical area if there are many changes]

## Testing

- [Unit tests added/modified — what scenarios they cover]
- [Manual testing steps for QA]
- [Edge cases verified]

## Acceptance Criteria

- [x] [Each criterion verified — copy from ticket/GROOM.md]

## Screenshots

[If UI changes — describe or note where to add before/after screenshots]

## Notes for Reviewers

[Optional: anything the reviewer should pay attention to, known trade-offs, follow-up work needed]
```

Also print the PR description to the chat so I can copy it directly.
