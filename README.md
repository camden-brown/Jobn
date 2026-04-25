# Jobn

Automate an entire sprint with one command. Pull tickets from JIRA/ADO, then let Copilot groom, plan, implement, test, review, and commit — with naturally spread timestamps.

## Architecture

The core idea: **Copilot IS the automation engine.** The only scripts needed are for authenticated API calls (JIRA/ADO). Everything else — worktree creation, grooming, coding, testing, committing with timestamps — is driven by a well-crafted `.instructions.md` file that Copilot follows autonomously.

```
Jobn/
├── scripts/
│   ├── pull-tickets.sh        # Fetch tickets from JIRA or ADO → JSON
│   └── setup.sh               # Initialize a new job directory
├── templates/
│   ├── config.example.yaml    # Example config (safe to commit)
│   ├── instructions.md        # THE BRAIN — Copilot workflow instructions
│   └── groom.md.tmpl          # Grooming markdown structure reference
├── jobs/                      # GITIGNORED — all job data lives here
│   └── <job-name>/
│       ├── config.yaml        # Creds, git settings, commit config
│       ├── tickets/*.json     # Pulled ticket data
│       ├── progress.json      # Tracks which tickets are done
│       └── .instructions.md   # Customized copy of the instructions
└── README.md
```

## Quick Start

```bash
# 1. Set up a new job
./scripts/setup.sh myjob

# 2. Edit config with your credentials and repo settings
$EDITOR jobs/myjob/config.yaml

# 3. Pull tickets from JIRA/ADO
./scripts/pull-tickets.sh myjob

# 4. Copy and customize the instructions
cp templates/instructions.md jobs/myjob/.instructions.md

# 5. Open your workspace with both repos, point Copilot at the instructions
#    → Copilot handles everything from here
```

## Multi-Repo Workspace Setup

The intended setup is a VS Code workspace with two folders:

```
workspace/
├── Jobn/                      # This repo (automation config + instructions)
└── your-code-repo/            # The actual code repo Copilot works on
```

The `config.yaml` points `git.repo_path` to your code repo. Copilot creates worktrees inside it and works on tickets there.

## Configuration

Edit `jobs/<job-name>/config.yaml`:

| Section        | Purpose                                                            |
| -------------- | ------------------------------------------------------------------ |
| `provider`     | `"jira"` or `"ado"`                                                |
| `jira` / `ado` | API credentials and query filters (project, sprint, assignee)      |
| `git`          | Repo path, base branch, branch naming pattern, worktree directory  |
| `commit`       | Time range for timestamp spreading, working hours, author identity |
| `verify`       | Build, test, and lint commands Copilot runs as verification gates  |

## What Copilot Does (The Full Workflow)

When you point Copilot at the `.instructions.md`, it autonomously:

1. **Reads all ticket JSON** and prioritizes (blockers first, then by story points)
2. **Creates a git worktree** per ticket with the configured branch pattern
3. **Grooms each ticket** — generates a stakeholder-facing `GROOM.md` with acceptance criteria, QA test plan, assumptions, and scope (written for PO/QA, not developers)
4. **Plans implementation** — writes `PLAN.md` with technical details: files to modify, approach, edge cases, commit boundaries
5. **Implements changes** — writes code following existing patterns, runs build verification
6. **Writes tests** — covers happy path, edge cases, and error scenarios; runs test suite
7. **Self-reviews** — checks for logic errors, security issues, missing error handling
8. **Commits interactively** — asks you whether to commit all changes at once, commit incrementally, or skip for now. Uses `GIT_AUTHOR_DATE`/`GIT_COMMITTER_DATE` to spread commits naturally across the configured time window (respecting working hours and weekends)
9. **Generates PR description** — creates `PR.md` with summary, changes, testing, and acceptance criteria
10. **Tracks progress** — updates `progress.json` after each phase so it can resume if interrupted

## Scripts

The only "real code" — handles authenticated API calls that Copilot can't make:

### Pull Tickets

```bash
# Fetch tickets from JIRA or ADO (based on provider in config)
./scripts/pull-tickets.sh myjob
```

**Dependencies**: `curl`, `python3`, `yq` (`brew install yq`)

Each ticket is stored as a JSON file:

```json
{
  "key": "PROJ-123",
  "summary": "Add user validation",
  "description": "Full description text...",
  "status": "To Do",
  "priority": "High",
  "story_points": 3,
  "issue_type": "Story",
  "labels": ["backend", "api"],
  "assignee": "Dev Name"
}
```

## Customizing the Workflow

The `templates/instructions.md` is the starting point. Copy it to your job directory and customize:

- **Skip phases**: Remove sections you don't need (e.g., if you handle grooming manually)
- **Add project-specific rules**: Coding conventions, framework-specific patterns, test strategies
- **Adjust commit splitting**: Change the guidelines for how granular commits should be
- **Add deployment steps**: Post-commit verification, staging deployment, etc.

## Security

- `jobs/` is gitignored — credentials and job names never enter version control
- JIRA uses basic auth (email + API token) per Atlassian's standard
- ADO uses Personal Access Token (PAT) auth
- No credentials are stored outside the gitignored job directory
- Ticket data (including descriptions) stays local

## Requirements

- `bash`, `curl`, `python3` (for pull script)
- `yq` for YAML parsing (`brew install yq`)
- VS Code with GitHub Copilot
- Git (for worktree operations)
