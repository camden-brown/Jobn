#!/usr/bin/env bash
#
# push-tickets.sh — Create tickets in JIRA or ADO from a decomposition
#
# USAGE
#   ./scripts/push-tickets.sh <job-name> <feature-slug> [--dry-run]
#
# DESCRIPTION
#   Reads jobs/<job-name>/decompositions/<feature-slug>/stories.json and
#   creates a ticket in JIRA or ADO for each story. Field mappings come
#   from the push: section in jobs/<job-name>/config.yaml.
#
#   Use --dry-run to print API payloads without making any HTTP calls.
#
# PREREQUISITES
#   - bash, curl, python3
#   - yq (brew install yq)
#   - A decomposition: run /decompose_feature first
#
# OUTPUT
#   Creates jobs/<job-name>/decompositions/<feature-slug>/pushed.json:
#   {
#     "pushed_at": "2026-04-25T12:00:00Z",
#     "tickets": [
#       { "order": 1, "key": "WEB-320", "summary": "...", "url": "..." }
#     ],
#     "errors": []
#   }
#
set -euo pipefail

JOB_NAME="${1:?Usage: push-tickets.sh <job-name> <feature-slug> [--dry-run]}"
FEATURE_SLUG="${2:?Usage: push-tickets.sh <job-name> <feature-slug> [--dry-run]}"
DRY_RUN="${3:-}"

JOB_DIR="jobs/${JOB_NAME}"
CONFIG="${JOB_DIR}/config.yaml"
DECOMP_DIR="${JOB_DIR}/decompositions/${FEATURE_SLUG}"
STORIES_FILE="${DECOMP_DIR}/stories.json"
PUSHED_FILE="${DECOMP_DIR}/pushed.json"

if [[ ! -f "$CONFIG" ]]; then
  echo "Error: Config not found at ${CONFIG}"
  exit 1
fi

if [[ ! -f "$STORIES_FILE" ]]; then
  echo "Error: Stories file not found at ${STORIES_FILE}"
  echo "Run /decompose_feature first."
  exit 1
fi

provider=$(yq '.provider' "$CONFIG")

# ---------- JIRA ----------
push_jira() {
  local url email token project sp_field default_type default_priority
  url=$(yq '.jira.url' "$CONFIG")
  email=$(yq '.jira.email' "$CONFIG")
  token=$(yq '.jira.token' "$CONFIG")
  project=$(yq '.jira.project' "$CONFIG")
  sp_field=$(yq '.push.field_mappings.jira.story_points_field // "customfield_10016"' "$CONFIG")
  default_type=$(yq '.push.default_issue_type // "Story"' "$CONFIG")
  default_priority=$(yq '.push.default_priority // "Medium"' "$CONFIG")

  echo "Pushing stories to JIRA project ${project} at ${url}..."
  if [[ "$DRY_RUN" == "--dry-run" ]]; then
    echo "=== DRY RUN — no tickets will be created ==="
    echo ""
  fi

  python3 -c "
import json, sys, urllib.request, urllib.error, base64
from datetime import datetime, timezone

with open('${STORIES_FILE}') as f:
    data = json.load(f)

url = '${url}'
email = '${email}'
token = '${token}'
project = '${project}'
sp_field = '${sp_field}'
default_type = '${default_type}'
default_priority = '${default_priority}'
dry_run = '${DRY_RUN}' == '--dry-run'

auth = base64.b64encode(f'{email}:{token}'.encode()).decode()
headers = {
    'Authorization': f'Basic {auth}',
    'Content-Type': 'application/json',
    'Accept': 'application/json',
}

results = {'pushed_at': datetime.now(timezone.utc).isoformat(), 'tickets': [], 'errors': []}

for story in sorted(data.get('stories', []), key=lambda s: s.get('order', 0)):
    # Build description with acceptance criteria appended
    desc_parts = [story.get('description', '')]

    ac = story.get('acceptance_criteria', [])
    if ac:
        desc_parts.append('\n\nh3. Acceptance Criteria\n')
        for criterion in ac:
            if isinstance(criterion, dict):
                desc_parts.append(f\"* Given {criterion.get('given', '')}, when {criterion.get('when', '')}, then {criterion.get('then', '')}\")
            else:
                desc_parts.append(f'* {criterion}')

    errors = story.get('error_states', [])
    if errors:
        desc_parts.append('\n\nh3. Error States\n')
        for e in errors:
            desc_parts.append(f'* {e}')

    loading = story.get('loading_states', [])
    if loading:
        desc_parts.append('\n\nh3. Loading States\n')
        for l in loading:
            desc_parts.append(f'* {l}')

    deps = story.get('dependencies', [])
    if deps:
        desc_parts.append('\n\nh3. Dependencies\n')
        for d in deps:
            if isinstance(d, dict):
                desc_parts.append(f\"* [{d.get('type', 'other')}] {d.get('description', '')}\")
            else:
                desc_parts.append(f'* {d}')

    full_description = '\n'.join(desc_parts)

    issue_type = story.get('issue_type', default_type)
    priority = story.get('priority', default_priority)
    points = story.get('story_points', 0)
    labels = story.get('labels', [])

    payload = {
        'fields': {
            'project': {'key': project},
            'summary': story.get('summary', 'Untitled story'),
            'description': {
                'type': 'doc',
                'version': 1,
                'content': [
                    {
                        'type': 'paragraph',
                        'content': [{'type': 'text', 'text': full_description}]
                    }
                ]
            },
            'issuetype': {'name': issue_type},
            'priority': {'name': priority},
            'labels': labels,
            sp_field: points,
        }
    }

    if dry_run:
        print(f\"[DRY RUN] Story {story.get('order', '?')}: {story.get('summary', '')}\")
        print(f\"  Type: {issue_type} | Priority: {priority} | Points: {points}\")
        print(f\"  Labels: {labels}\")
        print(f\"  Description length: {len(full_description)} chars\")
        print(f\"  Payload:\")
        print(json.dumps(payload, indent=2))
        print()
        results['tickets'].append({
            'order': story.get('order', 0),
            'key': 'DRY-RUN',
            'summary': story.get('summary', ''),
            'url': 'n/a',
        })
        continue

    try:
        req = urllib.request.Request(
            f'{url}/rest/api/3/issue',
            data=json.dumps(payload).encode(),
            headers=headers,
            method='POST',
        )
        with urllib.request.urlopen(req) as resp:
            result = json.loads(resp.read().decode())
            key = result.get('key', 'UNKNOWN')
            print(f\"  Created {key}: {story.get('summary', '')}\")
            results['tickets'].append({
                'order': story.get('order', 0),
                'key': key,
                'summary': story.get('summary', ''),
                'url': f'{url}/browse/{key}',
            })
    except urllib.error.HTTPError as e:
        body = e.read().decode() if e.fp else ''
        err_msg = f\"HTTP {e.code} creating story {story.get('order', '?')}: {body[:200]}\"
        print(f'  ERROR: {err_msg}', file=sys.stderr)
        results['errors'].append({
            'order': story.get('order', 0),
            'summary': story.get('summary', ''),
            'error': err_msg,
        })
    except Exception as e:
        err_msg = f\"Error creating story {story.get('order', '?')}: {str(e)}\"
        print(f'  ERROR: {err_msg}', file=sys.stderr)
        results['errors'].append({
            'order': story.get('order', 0),
            'summary': story.get('summary', ''),
            'error': err_msg,
        })

with open('${PUSHED_FILE}', 'w') as f:
    json.dump(results, f, indent=2)

created = len(results['tickets'])
failed = len(results['errors'])
print()
if dry_run:
    print(f'Dry run complete: {created} stories would be created')
else:
    print(f'Done: {created} created, {failed} failed')
print(f'Results saved to ${PUSHED_FILE}')

if failed > 0:
    sys.exit(1)
"
}

# ---------- ADO ----------
push_ado() {
  local org project token sp_field ac_field default_type default_priority
  org=$(yq '.ado.organization' "$CONFIG")
  project=$(yq '.ado.project' "$CONFIG")
  token=$(yq '.ado.token' "$CONFIG")
  sp_field=$(yq '.push.field_mappings.ado.story_points_field // "Microsoft.VSTS.Scheduling.StoryPoints"' "$CONFIG")
  ac_field=$(yq '.push.field_mappings.ado.acceptance_criteria_field // "Microsoft.VSTS.Common.AcceptanceCriteria"' "$CONFIG")
  default_type=$(yq '.push.default_issue_type // "Story"' "$CONFIG")
  default_priority=$(yq '.push.default_priority // "Medium"' "$CONFIG")

  local base_url="https://dev.azure.com/${org}/${project}"

  echo "Pushing stories to ADO project ${project} at ${base_url}..."
  if [[ "$DRY_RUN" == "--dry-run" ]]; then
    echo "=== DRY RUN — no tickets will be created ==="
    echo ""
  fi

  python3 -c "
import json, sys, urllib.request, urllib.error, base64
from datetime import datetime, timezone

with open('${STORIES_FILE}') as f:
    data = json.load(f)

org = '${org}'
project = '${project}'
token = '${token}'
sp_field = '${sp_field}'
ac_field = '${ac_field}'
default_type = '${default_type}'
default_priority = '${default_priority}'
dry_run = '${DRY_RUN}' == '--dry-run'
base_url = '${base_url}'

auth = base64.b64encode(f':{token}'.encode()).decode()
headers = {
    'Authorization': f'Basic {auth}',
    'Content-Type': 'application/json-patch+json',
    'Accept': 'application/json',
}

# Map priority names to ADO values (1=Critical, 2=High, 3=Medium, 4=Low)
priority_map = {'Highest': 1, 'High': 2, 'Medium': 3, 'Low': 4, 'Lowest': 4}

results = {'pushed_at': datetime.now(timezone.utc).isoformat(), 'tickets': [], 'errors': []}

for story in sorted(data.get('stories', []), key=lambda s: s.get('order', 0)):
    # Build description HTML
    desc = f\"<p>{story.get('description', '')}</p>\"

    errors = story.get('error_states', [])
    if errors:
        desc += '<h3>Error States</h3><ul>'
        for e in errors:
            desc += f'<li>{e}</li>'
        desc += '</ul>'

    loading = story.get('loading_states', [])
    if loading:
        desc += '<h3>Loading States</h3><ul>'
        for l in loading:
            desc += f'<li>{l}</li>'
        desc += '</ul>'

    deps = story.get('dependencies', [])
    if deps:
        desc += '<h3>Dependencies</h3><ul>'
        for d in deps:
            if isinstance(d, dict):
                desc += f\"<li>[{d.get('type', 'other')}] {d.get('description', '')}</li>\"
            else:
                desc += f'<li>{d}</li>'
        desc += '</ul>'

    # Build acceptance criteria HTML
    ac_html = ''
    ac = story.get('acceptance_criteria', [])
    if ac:
        ac_html = '<ul>'
        for criterion in ac:
            if isinstance(criterion, dict):
                ac_html += f\"<li>Given {criterion.get('given', '')}, when {criterion.get('when', '')}, then {criterion.get('then', '')}</li>\"
            else:
                ac_html += f'<li>{criterion}</li>'
        ac_html += '</ul>'

    issue_type = story.get('issue_type', default_type)
    if issue_type == 'Story':
        issue_type = 'User Story'  # ADO uses 'User Story'
    priority = priority_map.get(story.get('priority', default_priority), 3)
    points = story.get('story_points', 0)

    payload = [
        {'op': 'add', 'path': '/fields/System.Title', 'value': story.get('summary', 'Untitled story')},
        {'op': 'add', 'path': '/fields/System.Description', 'value': desc},
        {'op': 'add', 'path': '/fields/Microsoft.VSTS.Common.Priority', 'value': priority},
        {'op': 'add', 'path': f'/fields/{sp_field}', 'value': points},
    ]
    if ac_html:
        payload.append({'op': 'add', 'path': f'/fields/{ac_field}', 'value': ac_html})

    labels = story.get('labels', [])
    if labels:
        payload.append({'op': 'add', 'path': '/fields/System.Tags', 'value': '; '.join(labels)})

    if dry_run:
        print(f\"[DRY RUN] Story {story.get('order', '?')}: {story.get('summary', '')}\")
        print(f\"  Type: {issue_type} | Priority: {story.get('priority', default_priority)} | Points: {points}\")
        print(f\"  Payload:\")
        print(json.dumps(payload, indent=2))
        print()
        results['tickets'].append({
            'order': story.get('order', 0),
            'key': 'DRY-RUN',
            'summary': story.get('summary', ''),
            'url': 'n/a',
        })
        continue

    try:
        api_url = f\"{base_url}/_apis/wit/workitems/\${'$'}{issue_type}?api-version=7.0\"
        req = urllib.request.Request(
            api_url,
            data=json.dumps(payload).encode(),
            headers=headers,
            method='POST',
        )
        with urllib.request.urlopen(req) as resp:
            result = json.loads(resp.read().decode())
            wi_id = result.get('id', 'UNKNOWN')
            print(f\"  Created #{wi_id}: {story.get('summary', '')}\")
            results['tickets'].append({
                'order': story.get('order', 0),
                'key': str(wi_id),
                'summary': story.get('summary', ''),
                'url': f'{base_url}/_workitems/edit/{wi_id}',
            })
    except urllib.error.HTTPError as e:
        body = e.read().decode() if e.fp else ''
        err_msg = f\"HTTP {e.code} creating story {story.get('order', '?')}: {body[:200]}\"
        print(f'  ERROR: {err_msg}', file=sys.stderr)
        results['errors'].append({
            'order': story.get('order', 0),
            'summary': story.get('summary', ''),
            'error': err_msg,
        })
    except Exception as e:
        err_msg = f\"Error creating story {story.get('order', '?')}: {str(e)}\"
        print(f'  ERROR: {err_msg}', file=sys.stderr)
        results['errors'].append({
            'order': story.get('order', 0),
            'summary': story.get('summary', ''),
            'error': err_msg,
        })

with open('${PUSHED_FILE}', 'w') as f:
    json.dump(results, f, indent=2)

created = len(results['tickets'])
failed = len(results['errors'])
print()
if dry_run:
    print(f'Dry run complete: {created} stories would be created')
else:
    print(f'Done: {created} created, {failed} failed')
print(f'Results saved to ${PUSHED_FILE}')

if failed > 0:
    sys.exit(1)
"
}

# ---------- DISPATCH ----------
case "$provider" in
  jira)  push_jira ;;
  ado)   push_ado  ;;
  *)     echo "Unknown provider: ${provider}. Use 'jira' or 'ado'."; exit 1 ;;
esac
