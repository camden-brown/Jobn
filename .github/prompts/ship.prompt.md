---
description: 'Commit changes and generate a PR description. Use when: done implementing, ready to push a PR.'
---

Perform these steps in order:

## Step 1: Commit

Use `@committer` behavior — analyze all uncommitted changes:

1. Group changes into logical, independently buildable commits
2. Present the proposed commit groups
3. Ask if I want to spread timestamps
4. Commit with conventional commit messages

## Step 2: Generate PR Description

After committing, create `PR.md` in the project root with:

```markdown
## Summary

[One paragraph: what this PR does and which ticket it addresses]

Closes {ticket_id}

## Changes

- [Bullet list of key changes — what and why, focused on user/business value]

## Testing

- [How it was tested]
- [New test cases added]
- [Manual testing steps if applicable]

## Acceptance Criteria

- [x] [Each criterion from the ticket, verified]

## Screenshots

[If UI changes — before/after screenshots or description of visual changes]
```

## Step 3: Push Instructions

After generating `PR.md`, tell me:
- The branch name to push
- The `git push` command to run
- Remind me to create the PR on GitHub/ADO using the `PR.md` content
