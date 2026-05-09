# Jobn

A modular toolkit of VS Code Copilot agents and skills for sprint automation. Each agent does one thing well and can be invoked independently via `@agent-name` in Copilot chat. Reusable domain knowledge (Angular, testing, accessibility, etc.) lives in standalone SKILL.md files that agents reference automatically.

## Architecture

```
Jobn/
├── .github/
│   ├── agents/                  # 6 standalone, user-invocable agents
│   │   ├── spike.agent.md       # Research spike tickets
│   │   ├── implementer.agent.md # Implement tickets (code + tests)
│   │   ├── planner.agent.md     # Plan features → groom + decompose + CSV
│   │   ├── uploader.agent.md    # Push tickets to JIRA or ADO
│   │   ├── orchestrator.agent.md# Create worktrees from ticket sets
│   │   ├── committer.agent.md   # Smart commits with timestamp spreading
│   │   └── migrator.agent.md   # Framework upgrades and migrations
│   ├── prompts/                 # 3 slash commands (/review, /ship, /pr)
│   │   ├── review.prompt.md    # Code review on uncommitted changes
│   │   ├── ship.prompt.md      # Commit + PR description in one step
│   │   └── pr.prompt.md        # Generate PR description from commits
│   ├── skills/                  # 16 reusable domain knowledge files
│   │   ├── angular/             # Standalone components, signals, Material
│   │   ├── typescript/          # Strict mode, discriminated unions
│   │   ├── jsdoc/               # Documentation conventions
│   │   ├── unit-testing/        # Jest, Vitest, Angular TestBed
│   │   ├── playwright/          # E2E testing, page objects, a11y
│   │   ├── rxjs/                # Operators, subscriptions, testing
│   │   ├── accessibility/       # WCAG 2.1 AA, ARIA, keyboard nav
│   │   ├── aws/                 # DynamoDB, SQS, CloudWatch, S3
│   │   ├── git-conventions/     # Conventional commits, branching, semantic release
│   │   ├── posthog/             # Analytics, feature flags
│   │   ├── sentry/              # Error monitoring, breadcrumbs
│   │   ├── cdk/                 # AWS CDK constructs, stack design
│   │   ├── scss-css/            # BEM, CSS vars, Material theming
│   │   ├── debugging/           # Stack traces, error patterns, profiling
│   │   ├── api-design/          # REST conventions, OpenAPI, pagination
│   │   └── nx/                  # Nx monorepo, generators, caching, migrations
│   └── hooks/
│       └── jobn-guards.json     # Blocks dangerous git ops on main
├── scripts/
│   ├── install.sh               # Symlink agents+skills+prompts into a project
│   ├── setup.sh                 # Initialize a new job directory
│   ├── pull-tickets.sh          # Fetch tickets from JIRA/ADO → JSON
│   ├── push-tickets.sh          # Create tickets in JIRA/ADO
│   ├── create-work-item.ps1     # Create ADO work item (PowerShell)
│   ├── get-sprint-items.ps1     # List ADO sprint items (PowerShell)
│   └── guard-main-branch.sh     # Git safety hook
├── reference/                   # Reference docs for agents
│   ├── rtk-commands.md          # Token-optimized command reference
│   ├── commit-spreading.md      # Timestamp spreading algorithm
│   ├── jira-fields.md           # JIRA REST API field mappings
│   └── ado-fields.md            # ADO work item field mappings
├── templates/                   # Output templates
│   ├── config.example.yaml      # Job config template
│   ├── copilot-instructions.md.tmpl # Project-level Copilot instructions
│   ├── PROJECT.md.tmpl          # Project context for agents
│   ├── spike.md.tmpl            # Spike document (dual-audience)
│   ├── groom.md.tmpl            # Stakeholder-facing grooming
│   ├── decomposition.md.tmpl    # Story breakdown
│   ├── plan-overview.md.tmpl    # Feature plan overview
│   └── tickets.csv.tmpl         # JIRA/ADO CSV import format
└── jobs/                        # GITIGNORED — all job data lives here
    └── <job-name>/
        ├── config.yaml
        ├── tickets/*.json
        └── plans/<feature-slug>/
```

## Quick Start (New Machine)

```bash
# 1. Clone Jobn to your standard location
git clone <repo-url> ~/Workspace/Jobn

# 2. Set up a job (creates jobs/<name>/ with config template)
cd ~/Workspace/Jobn
./scripts/setup.sh myjob

# 3. Edit config with your credentials, repo paths, and settings
$EDITOR jobs/myjob/config.yaml

# 4. Install agents and skills into your target project
./scripts/install.sh /path/to/your/project

# 5. Open your project in VS Code
code /path/to/your/project

# 6. Use agents in Copilot chat:
#    @spike Research whether we should use Sentry vs Datadog
#    @planner Plan an analytics dashboard feature
#    @implementer Implement PROJ-123
#    @committer Commit all changes
```

## Installing into a Project

The `install.sh` script symlinks Jobn's agents, skills, and prompts into a target project's `.github/` directory, and scaffolds project context files:

```bash
# Install — symlinks .github/agents/, .github/skills/, .github/prompts/
# Also scaffolds .github/copilot-instructions.md and .github/PROJECT.md (if they don't exist)
~/Workspace/Jobn/scripts/install.sh /path/to/project

# Uninstall — removes the symlinks (keeps scaffolded files)
~/Workspace/Jobn/scripts/install.sh --uninstall /path/to/project
```

**Key details:**

- **Idempotent** — safe to run multiple times; existing symlinks are replaced
- **Symlinks, not copies** — editing files in Jobn automatically updates every linked project
- **Scaffolded files are copies** — `copilot-instructions.md` and `PROJECT.md` are copied (not symlinked) so you can customize per-project
- **Worktrees need separate installation** — git worktrees have independent working trees, so symlinks from the main repo don't carry over. Run `install.sh` on each worktree, or let `@orchestrator` handle it automatically
- **Won't overwrite real directories** — if `.github/agents/` exists as a real directory (not a symlink), the script refuses and tells you

## Agents

All agents are directly invocable via `@agent-name` in VS Code Copilot chat.

| Agent           | What It Does                                                                                   | Example                                                         |
| --------------- | ---------------------------------------------------------------------------------------------- | --------------------------------------------------------------- |
| `@spike`        | Research a topic and produce a dual-audience document (executive summary + technical analysis) | `@spike Should we use PostHog or Amplitude for analytics?`      |
| `@implementer`  | Implement a ticket: write code, tests, run verification, self-review                           | `@implementer Implement PROJ-123 following PLAN.md`             |
| `@planner`      | Plan a feature end-to-end: groom, decompose into stories, story-point, produce CSV             | `@planner Plan an error monitoring integration with Sentry`     |
| `@uploader`     | Upload tickets from CSV/JSON to JIRA or ADO (always previews first)                            | `@uploader Push plans/analytics/tickets.csv to JIRA`            |
| `@orchestrator` | Create git worktrees for a set of tickets, scaffold context, install agents                    | `@orchestrator Set up worktrees for all tickets in jobs/myjob/` |
| `@committer`    | Analyze changes, group into logical commits, optionally spread timestamps                      | `@committer Commit all changes in this worktree`                |
| `@migrator`     | Framework upgrades, dependency migrations, breaking-change remediation                         | `@migrator Upgrade Angular from 17 to 18`                      |

## Slash Commands

Slash commands are quick actions you invoke with `/command` in Copilot chat.

| Command     | What It Does                                                                              |
| ----------- | ----------------------------------------------------------------------------------------- |
| `/review`   | Review uncommitted changes for bugs, security issues, and best practices (read-only)      |
| `/ship`     | Commit all changes + generate PR description — shortcut for "I'm done, ship it"            |
| `/pr`       | Generate a PR description from already-committed changes on the current branch             |

## Skills

Skills are domain knowledge files that agents (primarily `@implementer`) reference automatically based on the detected tech stack. You don't invoke skills directly — agents pull them in as needed.

| Skill             | Key Content                                                              |
| ----------------- | ------------------------------------------------------------------------ |
| `angular`         | Standalone components, signals, OnPush, Material, PWA, routing, DI       |
| `typescript`      | Strict mode, discriminated unions, utility types, type guards, generics  |
| `jsdoc`           | When to document, tag reference, interface docs, module docs             |
| `unit-testing`    | Jest + Vitest + Angular TestBed, mocking, AAA pattern, coverage strategy |
| `playwright`      | Page objects, locator strategy, a11y assertions, network mocking         |
| `rxjs`            | Operator selection, subscription management, subject types, testing      |
| `accessibility`   | WCAG 2.1 AA, ARIA, keyboard nav, focus management, color contrast        |
| `aws`             | DynamoDB single-table, SQS, CloudWatch, S3, CloudFront, Elasticsearch    |
| `git-conventions` | Conventional commits, branch naming, commit splitting, PR format, semantic release |
| `posthog`         | Event taxonomy, feature flags, session recordings, group analytics       |
| `sentry`          | Error boundaries, breadcrumbs, performance tracing, source maps          |
| `cdk`             | Construct levels, stack organization, cross-stack refs, CDK testing      |
| `scss-css`        | BEM naming, CSS variables, Angular Material theming, relative units      |
| `debugging`       | Stack traces, Angular/Node error patterns, test isolation, profiling     |
| `api-design`      | REST conventions, HTTP methods, pagination, error format, OpenAPI        |
| `nx`              | Nx monorepo, workspace structure, generators, caching, affected, migrations |

## Common Workflows

### 1. Research a Spike

```
@spike Should we implement server-side rendering for the patient portal?
```

Produces `SPIKE-server-side-rendering.md` with executive summary (for PO) and technical analysis (for engineers).

### 2. Plan and Implement a Feature

```
# Step 1: Plan the feature → produces OVERVIEW.md, GROOM.md, BREAKDOWN.md, tickets.json, tickets.csv
@planner Plan an analytics dashboard with user engagement metrics

# Step 2: Upload stories to your tracker
@uploader Push plans/analytics-dashboard/tickets.csv to JIRA

# Step 3: Create worktrees for each ticket
@orchestrator Set up worktrees from plans/analytics-dashboard/tickets.json

# Step 4: In each worktree window, implement and commit
@implementer Implement this ticket
@committer Commit all changes
```

### 3. Quick Single-Ticket Work

```
# Implement directly (no planning phase)
@implementer Fix the date picker timezone bug in the appointment scheduler

# Review your work
/review

# Commit and ship when done
/ship
```

### 4. Upgrade a Dependency

```
@migrator Upgrade Angular from 17 to 18
```

### 5. Review and Ship

```
# Review changes first
/review

# Just generate a PR description (if already committed)
/pr

# Or commit + PR description in one step
/ship
```

## Configuration

Edit `jobs/<job-name>/config.yaml` (see `templates/config.example.yaml` for full reference):

| Section        | Purpose                                                              |
| -------------- | -------------------------------------------------------------------- |
| `provider`     | `"jira"` or `"ado"`                                                  |
| `jira` / `ado` | API credentials and query filters (project, sprint, assignee)        |
| `git`          | Repo path, base branch, branch naming pattern, worktree directory    |
| `commit`       | Time range for timestamp spreading, working hours, author identity   |
| `verify`       | Build, test, and lint commands (rtk-prefixed for token optimization) |
| `point_scale`  | Story point calibration for `@planner` (default: `1pt = 1 day`)      |
| `push`         | Field mappings for creating tickets via `@uploader`                  |

## Scripts

| Script                 | Purpose                                                       |
| ---------------------- | ------------------------------------------------------------- |
| `install.sh`           | Symlink agents + skills + prompts into a project, scaffold context files |
| `setup.sh`             | Initialize a new job directory with config template           |
| `pull-tickets.sh`      | Fetch tickets from JIRA or ADO → `jobs/<name>/tickets/*.json` |
| `push-tickets.sh`      | Create JIRA tickets from a decomposition's `stories.json`     |
| `create-work-item.ps1` | Create a single ADO work item (PowerShell)                    |
| `get-sprint-items.ps1` | List ADO sprint items (PowerShell)                            |
| `guard-main-branch.sh` | Git safety hook — blocks push to main, force push, etc.       |

**Dependencies**: `bash`, `curl`, `python3`, `yq` (`brew install yq`). ADO scripts also need Azure CLI with the `azure-devops` extension.

## Security

- `jobs/` is gitignored — credentials and job data never enter version control
- JIRA uses basic auth (email + API token) per Atlassian's standard
- ADO uses Personal Access Token (PAT) auth
- No credentials are stored outside the gitignored job directory
- The git guard hook blocks `git push` to main/master/develop and `git push --force`

## Requirements

- `bash`, `curl`, `python3` (for pull script)
- `yq` for YAML parsing (`brew install yq`)
- VS Code with GitHub Copilot
- Git (for worktree operations)
