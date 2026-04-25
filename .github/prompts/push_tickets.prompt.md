---
description: 'Push decomposed stories to JIRA or ADO — create tickets from a feature breakdown'
agent: 'jobn'
argument-hint: 'job name and feature slug (e.g. sympliact patient-portal-dashboard)'
---

Push decomposed stories to the ticket tracker.

Parse the input: the first word is the job name, the second is the feature slug.

1. Read `jobs/{job_name}/config.yaml` for provider credentials and push field mappings
2. Read `jobs/{job_name}/decompositions/{feature_slug}/stories.json`
3. Show a summary of what will be created (story count, total points, target project)
4. **Ask the user for confirmation** before creating any tickets
5. If confirmed, run: `./scripts/push-tickets.sh {job_name} {feature_slug}`
   - If user asks to preview first, run with `--dry-run`
6. Report results — tickets created, any failures
7. Optionally sync new tickets back: `./scripts/pull-tickets.sh {job_name}`

Input: `$input`
