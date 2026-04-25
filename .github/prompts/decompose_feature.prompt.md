---
description: 'Decompose a feature idea into user stories with acceptance criteria, dependencies, and story point estimates'
agent: 'jobn'
argument-hint: 'job name followed by feature description (e.g. sympliact Add a patient portal dashboard with appointment history and medication list)'
---

Decompose a feature idea into JIRA/ADO-ready user stories.

Parse the input: the first word is the job name, everything after is the feature description.

1. Read `jobs/{job_name}/config.yaml` for repo paths, provider, and point_scale
2. Delegate to the `jobn-decomposer` subagent with:
   - The feature description text
   - The job config (repo paths for codebase analysis)
   - The decomposition template from `templates/decomposition.md.tmpl`
3. The decomposer will analyze the target codebase and produce:
   - `jobs/{job_name}/decompositions/{feature_slug}/breakdown.md` (human review)
   - `jobs/{job_name}/decompositions/{feature_slug}/stories.json` (machine-readable)
4. Present the breakdown summary for review

After review, the user can request adjustments or run `/push_tickets` to create the stories in JIRA/ADO.

Input: `$input`
