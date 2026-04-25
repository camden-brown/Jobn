#!/usr/bin/env bash
#
# pull-tickets.sh — Fetch tickets from JIRA or ADO and store as JSON
#
# USAGE
#   ./scripts/pull-tickets.sh <job-name>
#
# DESCRIPTION
#   Reads jobs/<job-name>/config.yaml, queries the configured ticket provider
#   (JIRA or ADO), and saves each matching ticket as a JSON file in
#   jobs/<job-name>/tickets/<TICKET-KEY>.json.
#
#   The query is built from the config filters. All filters are optional and
#   combine with AND logic — only set what you need.
#
# PREREQUISITES
#   - bash, curl, python3
#   - yq (brew install yq)
#   - A configured job: run ./scripts/setup.sh <job-name> first
#
# CONFIG OPTIONS (in jobs/<job-name>/config.yaml)
#
#   provider: "jira" | "ado"      Which ticket system to query
#
#   ── JIRA (provider: "jira") ──────────────────────────────────────────
#   jira.url          Base URL          "https://company.atlassian.net"
#   jira.email        Auth email        "you@company.com"
#   jira.token        API token         Generate at id.atlassian.com
#   jira.project      Project key       "PROJ" (required)
#   jira.sprint       Sprint filter     "Sprint 42", "current", or "" to skip
#   jira.status       Column/status     "To Do", "In Progress", or "" to skip
#   jira.assignee     Assignee filter   "you@company.com" or "" to skip
#
#   Resulting JQL: project = "PROJ" [AND sprint = ...] [AND status = ...] [AND assignee = ...]
#
#   ── ADO (provider: "ado") ────────────────────────────────────────────
#   ado.organization  Org name          "yourorg"
#   ado.project       Project name      "YourProject" (required)
#   ado.token         PAT               Personal Access Token with work item read
#   ado.team          Team filter       "YourTeam" or "" to skip
#   ado.iteration     Iteration path    "current", "Project\Sprint 1", or "" to skip
#   ado.column        Board state       "New", "Active", or "" to skip
#   ado.assignee      Assignee filter   "you@company.com" or "" to skip
#
#   Resulting WIQL: [TeamProject] AND [IterationPath] AND [State] AND [AssignedTo]
#
# EXAMPLES
#
#   # Sprint-based: pull all my tickets in the current sprint
#   # config: sprint: "current", assignee: "me@co.com", status: ""
#   ./scripts/pull-tickets.sh myco
#
#   # Column-based (no sprints): pull all "To Do" tickets assigned to me
#   # config: sprint: "", status: "To Do", assignee: "me@co.com"
#   ./scripts/pull-tickets.sh myco
#
#   # Pull everything in a project assigned to me (no sprint/status filter)
#   # config: sprint: "", status: "", assignee: "me@co.com"
#   ./scripts/pull-tickets.sh myco
#
#   # Narrow: specific sprint + specific column
#   # config: sprint: "Sprint 42", status: "Ready for Dev", assignee: "me@co.com"
#   ./scripts/pull-tickets.sh myco
#
# OUTPUT
#   Each ticket is saved as jobs/<job-name>/tickets/<KEY>.json:
#   {
#     "id": "10001",
#     "key": "PROJ-123",
#     "summary": "Add user validation",
#     "description": "Plain text description...",
#     "status": "To Do",
#     "priority": "High",
#     "story_points": 3,
#     "issue_type": "Story",
#     "labels": ["backend"],
#     "assignee": "Dev Name"
#   }
#
set -euo pipefail

JOB_NAME="${1:?Usage: pull-tickets.sh <job-name>}"
JOB_DIR="jobs/${JOB_NAME}"
CONFIG="${JOB_DIR}/config.yaml"
TICKETS_DIR="${JOB_DIR}/tickets"

if [[ ! -f "$CONFIG" ]]; then
  echo "Error: Config not found at ${CONFIG}"
  echo "Run ./scripts/setup.sh ${JOB_NAME} first."
  exit 1
fi

# Parse config (requires yq — brew install yq)
provider=$(yq '.provider' "$CONFIG")

mkdir -p "$TICKETS_DIR"

# ---------- JIRA ----------
pull_jira() {
  local url email token project sprint assignee status
  url=$(yq '.jira.url' "$CONFIG")
  email=$(yq '.jira.email' "$CONFIG")
  token=$(yq '.jira.token' "$CONFIG")
  project=$(yq '.jira.project' "$CONFIG")
  sprint=$(yq '.jira.sprint // ""' "$CONFIG")
  assignee=$(yq '.jira.assignee // ""' "$CONFIG")
  status=$(yq '.jira.status // ""' "$CONFIG")

  # Build JQL
  local jql="project = \"${project}\""
  if [[ "$sprint" == "current" ]]; then
    jql="${jql} AND sprint in openSprints()"
  elif [[ -n "$sprint" && "$sprint" != "null" ]]; then
    jql="${jql} AND sprint = \"${sprint}\""
  fi
  if [[ -n "$status" && "$status" != "null" ]]; then
    jql="${jql} AND status = \"${status}\""
  fi
  if [[ -n "$assignee" && "$assignee" != "null" ]]; then
    jql="${jql} AND assignee = \"${assignee}\""
  fi

  echo "JQL: ${jql}"
  echo "Fetching from ${url}..."

  local json_body
  json_body=$(python3 -c "
import json
print(json.dumps({
    'jql': '''${jql}''',
    'maxResults': 50,
    'fields': ['summary','description','status','priority','labels','issuetype','assignee','customfield_10016']
}))
")

  local response
  response=$(curl -s -w "\n%{http_code}" \
    -u "${email}:${token}" \
    -H "Accept: application/json" \
    -H "Content-Type: application/json" \
    -X POST \
    -d "$json_body" \
    "${url}/rest/api/3/search/jql")

  local http_code body
  http_code=$(echo "$response" | tail -1)
  body=$(echo "$response" | sed '$d')

  if [[ "$http_code" -ne 200 ]]; then
    echo "Error: JIRA returned HTTP ${http_code}"
    echo "$body" | head -5
    exit 1
  fi

  local count
  count=$(echo "$body" | python3 -c "import sys,json; print(len(json.load(sys.stdin).get('issues',[])))")
  echo "Found ${count} tickets"

  # Extract each issue to its own JSON file
  echo "$body" | python3 -c "
import sys, json

data = json.load(sys.stdin)
for issue in data.get('issues', []):
    fields = issue['fields']
    
    # Flatten ADF description to plain text
    desc = ''
    if fields.get('description'):
        def extract_text(node):
            text = node.get('text', '')
            for child in node.get('content', []):
                text += extract_text(child)
            if node.get('type') in ('paragraph', 'heading', 'listItem', 'bulletList', 'orderedList'):
                text += '\n'
            return text
        desc = extract_text(fields['description']).strip()
    
    ticket = {
        'id': issue['id'],
        'key': issue['key'],
        'summary': fields.get('summary', ''),
        'description': desc,
        'status': (fields.get('status') or {}).get('name', ''),
        'priority': (fields.get('priority') or {}).get('name', ''),
        'labels': fields.get('labels', []),
        'story_points': fields.get('customfield_10016') or 0,
        'issue_type': (fields.get('issuetype') or {}).get('name', ''),
        'assignee': (fields.get('assignee') or {}).get('displayName', ''),
    }
    
    path = '${TICKETS_DIR}/' + issue['key'] + '.json'
    with open(path, 'w') as f:
        json.dump(ticket, f, indent=2)
    print(f\"  Saved {issue['key']}: {fields.get('summary', '')}\")
"

  echo ""
  echo "Done. Tickets saved to ${TICKETS_DIR}/"
}

# ---------- ADO ----------
pull_ado() {
  local org project token team iteration assignee column
  org=$(yq '.ado.organization' "$CONFIG")
  project=$(yq '.ado.project' "$CONFIG")
  token=$(yq '.ado.token' "$CONFIG")
  team=$(yq '.ado.team // ""' "$CONFIG")
  iteration=$(yq '.ado.iteration // ""' "$CONFIG")
  assignee=$(yq '.ado.assignee // ""' "$CONFIG")
  column=$(yq '.ado.column // ""' "$CONFIG")

  local base_url="https://dev.azure.com/${org}/${project}"

  # Build WIQL query
  local wiql="SELECT [System.Id] FROM WorkItems WHERE [System.TeamProject] = '${project}'"
  if [[ -n "$iteration" && "$iteration" != "null" ]]; then
    if [[ "$iteration" == "current" ]]; then
      wiql="${wiql} AND [System.IterationPath] UNDER @currentIteration"
    else
      wiql="${wiql} AND [System.IterationPath] UNDER '${iteration}'"
    fi
  fi
  if [[ -n "$column" && "$column" != "null" ]]; then
    wiql="${wiql} AND [System.State] = '${column}'"
  fi
  if [[ -n "$assignee" && "$assignee" != "null" ]]; then
    wiql="${wiql} AND [System.AssignedTo] = '${assignee}'"
  fi
  wiql="${wiql} AND [System.State] <> 'Removed'"

  echo "WIQL: ${wiql}"
  echo "Fetching from ${base_url}..."

  # Step 1: Run WIQL query to get IDs
  local query_response
  query_response=$(curl -s -w "\n%{http_code}" \
    -u ":${token}" \
    -H "Content-Type: application/json" \
    -d "{\"query\": \"${wiql}\"}" \
    "${base_url}/_apis/wit/wiql?api-version=7.0")

  local http_code body
  http_code=$(echo "$query_response" | tail -1)
  body=$(echo "$query_response" | sed '$d')

  if [[ "$http_code" -ne 200 ]]; then
    echo "Error: ADO returned HTTP ${http_code}"
    echo "$body" | head -5
    exit 1
  fi

  # Extract work item IDs
  local ids
  ids=$(echo "$body" | python3 -c "
import sys, json
data = json.load(sys.stdin)
items = data.get('workItems', [])
print(','.join(str(i['id']) for i in items))
")

  if [[ -z "$ids" ]]; then
    echo "No work items found."
    exit 0
  fi

  echo "Found work item IDs: ${ids}"

  # Step 2: Batch fetch work item details
  local details_response
  details_response=$(curl -s -w "\n%{http_code}" \
    -u ":${token}" \
    -H "Accept: application/json" \
    "${base_url}/_apis/wit/workitems?ids=${ids}&\$expand=all&api-version=7.0")

  http_code=$(echo "$details_response" | tail -1)
  body=$(echo "$details_response" | sed '$d')

  if [[ "$http_code" -ne 200 ]]; then
    echo "Error: ADO returned HTTP ${http_code} fetching details"
    echo "$body" | head -5
    exit 1
  fi

  # Extract each work item to JSON
  echo "$body" | python3 -c "
import sys, json

data = json.load(sys.stdin)
for item in data.get('value', []):
    fields = item.get('fields', {})
    
    # ADO uses plain HTML in description — strip tags simply
    desc = fields.get('System.Description', '') or ''
    import re
    desc = re.sub('<[^>]+>', '', desc).strip()
    
    ticket = {
        'id': str(item['id']),
        'key': str(item['id']),
        'summary': fields.get('System.Title', ''),
        'description': desc,
        'status': fields.get('System.State', ''),
        'priority': str(fields.get('Microsoft.VSTS.Common.Priority', '')),
        'labels': fields.get('System.Tags', '').split('; ') if fields.get('System.Tags') else [],
        'story_points': fields.get('Microsoft.VSTS.Scheduling.StoryPoints') or 0,
        'issue_type': fields.get('System.WorkItemType', ''),
        'assignee': (fields.get('System.AssignedTo') or {}).get('displayName', '') if isinstance(fields.get('System.AssignedTo'), dict) else str(fields.get('System.AssignedTo', '')),
    }
    
    path = '${TICKETS_DIR}/' + str(item['id']) + '.json'
    with open(path, 'w') as f:
        json.dump(ticket, f, indent=2)
    print(f\"  Saved {item['id']}: {fields.get('System.Title', '')}\")
"

  echo ""
  echo "Done. Tickets saved to ${TICKETS_DIR}/"
}

# ---------- Dispatch ----------
case "$provider" in
  jira) pull_jira ;;
  ado)  pull_ado ;;
  *)
    echo "Error: Unknown provider '${provider}' in config. Use 'jira' or 'ado'."
    exit 1
    ;;
esac
