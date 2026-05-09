---
description: 'Git workflow conventions: conventional commits, branch naming, commit splitting, PR descriptions. USE FOR: committing code, writing commit messages, structuring PRs.'
---

# Git Conventions

## Conventional Commits

Format: `[TICKET-ID] type: description`

### Types

| Type       | Use Case                                   | Example                                                    |
| ---------- | ------------------------------------------ | ---------------------------------------------------------- |
| `feat`     | New feature or functionality               | `[PROJ-123] feat: add user search endpoint`                |
| `fix`      | Bug fix                                    | `[PROJ-456] fix: prevent duplicate form submission`        |
| `refactor` | Code restructuring without behavior change | `[PROJ-789] refactor: extract validation logic to service` |
| `test`     | Adding or updating tests                   | `[PROJ-123] test: add unit tests for search service`       |
| `docs`     | Documentation changes                      | `[PROJ-123] docs: add API endpoint documentation`          |
| `chore`    | Build, config, tooling, dependencies       | `[PROJ-101] chore: update Angular to v18`                  |
| `style`    | Formatting, whitespace (no logic change)   | `[PROJ-101] style: fix linting errors`                     |
| `perf`     | Performance improvement                    | `[PROJ-202] perf: add pagination to user list query`       |

### Rules

- Type and description are lowercase
- Description is imperative mood: "add" not "added" or "adds"
- No period at the end
- Max 72 characters for the subject line
- Ticket ID prefix matches the configured `message_pattern`

## Branch Naming

| Branch Type | Pattern               | Example            |
| ----------- | --------------------- | ------------------ |
| Feature     | `feature/{ticket_id}` | `feature/PROJ-123` |
| Bug fix     | `bugfix/{ticket_id}`  | `bugfix/PROJ-456`  |
| Hotfix      | `hotfix/{ticket_id}`  | `hotfix/PROJ-789`  |

- Use the `branch_pattern` / `bugfix_branch_pattern` from config
- Always branch from the configured `base_branch`
- One branch per ticket — no multi-ticket branches

## Commit Splitting

Each commit must be **independently buildable and testable**. The test suite should pass after each commit.

### Typical Feature Split

1. `feat: add model/types/interfaces`
2. `feat: add core service logic`
3. `feat: add component/UI`
4. `test: add unit tests`
5. `docs: update API documentation` (if applicable)

### Typical Bug Fix Split

1. `fix: correct the bug`
2. `test: add regression test`

### Guidelines

- Group by **logical change**, not by file
- 1–3 files per commit is ideal
- If a commit touches 10+ files, consider splitting further
- Never commit generated files (build output, lock files without changes) in the same commit as source changes
- Config changes get their own commit: `chore: update config for X`

## PR Description Format

```markdown
## Summary

[One paragraph: what this PR does and which ticket it addresses]

Closes PROJ-123

## Changes

- [Bullet list of key changes — what and why]

## Testing

- [How it was tested]
- [New tests added]
- [Manual testing steps if applicable]

## Acceptance Criteria

- [x] [Copy from GROOM.md with checkmarks]
- [x] [Each criterion verified]

## Screenshots

[If UI changes — before/after screenshots]
```

## Protected Branches

- **NEVER** commit directly to `main`, `master`, or `develop`
- **NEVER** force push to shared branches
- **NEVER** use `git reset --hard` on shared branches
- Use `git push --force-with-lease` if rebase is necessary (and only on your own feature branch)

## Timestamp Spreading

When spreading commits, see `reference/commit-spreading.md` for the full algorithm. Key points:

- Vary intervals naturally — never uniform spacing
- Respect working hours and skip weekends (configurable)
- Interleave commits from different tickets chronologically
- Morning commits: 5–15 min after work start; evening: ≥10 min before end

## Semantic Release

Automates versioning and changelog generation from conventional commit messages.

### How It Works

1. Analyzes commits since last release
2. Determines version bump from commit types
3. Generates changelog
4. Creates git tag
5. Publishes package (npm, GitHub release, etc.)

### Commit → Version Mapping

| Commit Type | Version Bump | Example |
|-------------|-------------|---------|
| `fix:` | Patch (`1.0.0` → `1.0.1`) | `fix: prevent crash on empty input` |
| `feat:` | Minor (`1.0.0` → `1.1.0`) | `feat: add user search` |
| `feat:` + `BREAKING CHANGE` | Major (`1.0.0` → `2.0.0`) | See below |
| `perf:` | Patch | `perf: optimize query` |
| `refactor:`, `test:`, `docs:`, `chore:`, `style:` | No release | These don't trigger a release |

### Breaking Changes

Two ways to signal a breaking change (triggers **major** bump):

**Footer notation (preferred):**
```
feat: redesign the authentication API

BREAKING CHANGE: The login endpoint now returns a session object instead of a raw token.
Consumers must update to use `response.session.token` instead of `response.token`.
```

**Exclamation mark shorthand:**
```
feat!: redesign the authentication API
```

### Configuration

Minimal `.releaserc.json`:

```json
{
  "branches": ["main"],
  "plugins": [
    "@semantic-release/commit-analyzer",
    "@semantic-release/release-notes-generator",
    "@semantic-release/changelog",
    "@semantic-release/npm",
    "@semantic-release/git",
    "@semantic-release/github"
  ]
}
```

**Multi-branch releases:**
```json
{
  "branches": [
    "main",
    { "name": "next", "prerelease": true },
    { "name": "beta", "prerelease": true }
  ]
}
```

### Package Setup

```bash
npm i -D semantic-release @semantic-release/changelog @semantic-release/git @semantic-release/github
```

`package.json`:
```json
{
  "version": "0.0.0-semantically-released",
  "scripts": {
    "release": "semantic-release"
  }
}
```

The `version` field is managed by semantic-release — don't update it manually.

### CI Integration

**GitHub Actions:**
```yaml
- name: Release
  run: npx semantic-release
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
    NPM_TOKEN: ${{ secrets.NPM_TOKEN }}
```

**Azure Pipelines:**
```yaml
- script: npx semantic-release
  env:
    GH_TOKEN: $(GH_TOKEN)
    NPM_TOKEN: $(NPM_TOKEN)
```

### Rules for Commit Messages with Semantic Release

- Every `feat:` and `fix:` commit **will** trigger a release — be deliberate
- WIP commits should use `chore:` or `refactor:` to avoid accidental releases
- Squash PRs with a proper conventional commit message — don't merge "fix typo" as a `fix:`
- Breaking changes must include migration instructions in the commit body
- Keep commit scope consistent — `feat(auth):` not sometimes `feat(authentication):`
