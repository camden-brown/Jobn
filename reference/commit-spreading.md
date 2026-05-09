# Commit Timestamp Spreading Algorithm

When spreading commits across a time range, the goal is to make the git history look natural — as if a developer wrote each commit during a normal workday.

## Configuration

These values come from `config.yaml` → `commit:` section:

```yaml
commit:
  time_range_start: '2026-04-21T09:00:00'
  time_range_end: '2026-04-25T17:00:00'
  timezone: 'America/Chicago'
  working_hours_only: true
  working_hour_start: 9 # 24h format
  working_hour_end: 17
  skip_weekends: true
  author_name: 'Your Name'
  author_email: 'you@company.com'
  message_pattern: '[{ticket_id}] {type}: {description}'
```

## Algorithm

### 1. Determine Available Time Slots

Given the time range, calculate available working minutes:

- If `working_hours_only: true` → only use hours between `working_hour_start` and `working_hour_end`
- If `skip_weekends: true` → exclude Saturday and Sunday
- Result: a list of valid time windows (e.g., Mon 9–17, Tue 9–17, Wed 9–17)

### 2. Distribute Commits

Given `N` commits to spread across the available time:

1. Calculate the total available minutes
2. Divide into `N` roughly equal intervals
3. **Add jitter** — shift each timestamp by a random offset (±15% of the interval) so commits are not evenly spaced
4. Ensure no two commits share the same minute

### 3. Natural Variance

To look realistic:

- **Morning commits** tend to be 5–15 minutes after the working hour start (developer settling in)
- **Lunch gap** — avoid commits between ~12:00–12:45 (optional, not enforced)
- **End-of-day** — last commit should be at least 10 minutes before working hour end
- **Interval variance** — adjacent commits should differ in gap size (some 20 min apart, some 45 min, some 90 min)
- **Never exactly uniform** — if interval is 60 min, actual gaps should be 45–75 min

### 4. Cross-Ticket Interleaving

When spreading commits from multiple tickets:

- Combine all commits from all tickets into one pool
- Sort by logical timestamp order
- Interleave chronologically (don't batch all commits for ticket A, then all for ticket B)
- Adjacent commits for the same ticket should have at least a 10-minute gap

## Git Commit with Spread Timestamp

```bash
GIT_AUTHOR_DATE="2026-04-22T10:23:00 -0500" \
GIT_COMMITTER_DATE="2026-04-22T10:23:00 -0500" \
GIT_AUTHOR_NAME="Your Name" \
GIT_AUTHOR_EMAIL="you@company.com" \
GIT_COMMITTER_NAME="Your Name" \
GIT_COMMITTER_EMAIL="you@company.com" \
git commit -m "[PROJ-123] feat: add user validation"
```

## Commit Message Pattern

The `message_pattern` from config uses placeholders:

| Placeholder     | Value                                                                        |
| --------------- | ---------------------------------------------------------------------------- |
| `{ticket_id}`   | The ticket key (e.g., `PROJ-123`)                                            |
| `{type}`        | Conventional commit type: `feat`, `fix`, `refactor`, `test`, `docs`, `chore` |
| `{description}` | Short description of the change                                              |

## Commit Splitting Guidelines

- Each commit must be independently buildable and testable
- Group by logical change, not by file
- Typical feature split: `feat: add model/types` → `feat: add core logic` → `test: add tests`
- Bug fix split: `fix: correct the bug` → `test: add regression test`
- Keep commits small and focused — 1–3 files per commit is ideal
