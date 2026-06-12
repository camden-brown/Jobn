#!/usr/bin/env bash
#
# update-description.sh — Update the description of an existing JIRA issue
#
# USAGE
#   ./scripts/update-description.sh <job-name> <TICKET-KEY> [file] [--dry-run] [--replace]
#
#   # Append an implementation section below the existing description (default):
#   ./scripts/update-description.sh sympliact WEB-357 notes.md
#
#   # Body from stdin (heredoc, pipe, etc.):
#   ./scripts/update-description.sh sympliact WEB-357 <<'EOF'
#   ## What changed
#   - first thing
#   - second thing
#   EOF
#
#   # Replace the description entirely:
#   ./scripts/update-description.sh sympliact WEB-357 notes.md --replace
#
#   # Preview the merged ADF payload without writing:
#   ./scripts/update-description.sh sympliact WEB-357 notes.md --dry-run
#
# DESCRIPTION
#   Reads jobs/<job-name>/config.yaml for JIRA credentials, converts a small
#   Markdown subset into Atlassian Document Format (ADF), and PUTs it to
#   /rest/api/3/issue/<TICKET-KEY> as the description field.
#
#   By default the new content is APPENDED below the issue's current
#   description (separated by a horizontal rule), preserving the original
#   requirement / acceptance criteria. Pass --replace to overwrite instead.
#
#   Supported Markdown:
#     ## / ### heading       → heading (level 3)
#     - item                 → bullet list (consecutive lines grouped)
#     **bold**               → strong text (inline)
#     `code`                 → inline code (inline)
#     blank line             → paragraph break
#     anything else          → paragraph
#
# PREREQUISITES
#   - bash, curl, python3
#   - yq (brew install yq)
#   - A configured job: run ./scripts/setup.sh <job-name> first
#
set -euo pipefail

JOB_NAME="${1:?Usage: update-description.sh <job-name> <TICKET-KEY> [file] [--dry-run] [--replace]}"
TICKET_KEY="${2:?Usage: update-description.sh <job-name> <TICKET-KEY> [file] [--dry-run] [--replace]}"
shift 2

DRY_RUN=""
REPLACE=""
DESC_FILE=""
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN="--dry-run" ;;
    --replace) REPLACE="--replace" ;;
    *) DESC_FILE="$arg" ;;
  esac
done

JOB_DIR="jobs/${JOB_NAME}"
CONFIG="${JOB_DIR}/config.yaml"

if [[ ! -f "$CONFIG" ]]; then
  echo "Error: Config not found at ${CONFIG}"
  echo "Run ./scripts/setup.sh ${JOB_NAME} first."
  exit 1
fi

provider=$(yq '.provider' "$CONFIG")
if [[ "$provider" != "jira" ]]; then
  echo "Error: update-description.sh currently supports JIRA only (provider is '${provider}')."
  exit 1
fi

url=$(yq '.jira.url' "$CONFIG")
email=$(yq '.jira.email' "$CONFIG")
token=$(yq '.jira.token' "$CONFIG")

# Read the new description body from the file argument or stdin.
if [[ -n "$DESC_FILE" ]]; then
  if [[ ! -f "$DESC_FILE" ]]; then
    echo "Error: Description file not found at ${DESC_FILE}"
    exit 1
  fi
  BODY=$(cat "$DESC_FILE")
else
  BODY=$(cat)
fi

if [[ -z "${BODY//[$'\t\r\n ']/}" ]]; then
  echo "Error: Description body is empty."
  exit 1
fi

JIRA_URL="$url" JIRA_EMAIL="$email" JIRA_TOKEN="$token" \
TICKET_KEY="$TICKET_KEY" DRY_RUN="$DRY_RUN" REPLACE="$REPLACE" DESC_BODY="$BODY" \
python3 -c "
import json, os, re, sys, urllib.request, urllib.error, base64

url = os.environ['JIRA_URL'].rstrip('/')
email = os.environ['JIRA_EMAIL']
token = os.environ['JIRA_TOKEN']
key = os.environ['TICKET_KEY']
dry_run = os.environ['DRY_RUN'] == '--dry-run'
replace = os.environ['REPLACE'] == '--replace'
body = os.environ['DESC_BODY']

auth = base64.b64encode(f'{email}:{token}'.encode()).decode()
headers = {
    'Authorization': f'Basic {auth}',
    'Content-Type': 'application/json',
    'Accept': 'application/json',
}


def inline(text):
    nodes = []
    for token in re.split(r'(\*\*[^*]+\*\*|\`[^\`]+\`)', text):
        if not token:
            continue
        if token.startswith('**') and token.endswith('**'):
            nodes.append({'type': 'text', 'text': token[2:-2], 'marks': [{'type': 'strong'}]})
        elif token.startswith('\`') and token.endswith('\`'):
            nodes.append({'type': 'text', 'text': token[1:-1], 'marks': [{'type': 'code'}]})
        else:
            nodes.append({'type': 'text', 'text': token})
    return nodes or [{'type': 'text', 'text': ''}]


def to_blocks(md):
    content = []
    bullets = []

    def flush_bullets():
        if bullets:
            content.append({
                'type': 'bulletList',
                'content': [
                    {'type': 'listItem',
                     'content': [{'type': 'paragraph', 'content': inline(b)}]}
                    for b in bullets
                ],
            })
            bullets.clear()

    for raw in md.split('\n'):
        line = raw.rstrip()
        if not line.strip():
            flush_bullets()
            continue
        if line.startswith('### '):
            flush_bullets()
            content.append({'type': 'heading', 'attrs': {'level': 3}, 'content': inline(line[4:].strip())})
        elif line.startswith('## '):
            flush_bullets()
            content.append({'type': 'heading', 'attrs': {'level': 3}, 'content': inline(line[3:].strip())})
        elif line.startswith('- '):
            bullets.append(line[2:].strip())
        else:
            flush_bullets()
            content.append({'type': 'paragraph', 'content': inline(line.strip())})

    flush_bullets()
    return content


def fetch_existing_content():
    req = urllib.request.Request(
        f'{url}/rest/api/3/issue/{key}?fields=description',
        headers=headers,
        method='GET',
    )
    with urllib.request.urlopen(req) as resp:
        data = json.loads(resp.read().decode())
    desc = (data.get('fields') or {}).get('description')
    if isinstance(desc, dict) and isinstance(desc.get('content'), list):
        return desc['content']
    return []


new_blocks = to_blocks(body)
if not new_blocks:
    print('Error: nothing to write (description body produced no content).', file=sys.stderr)
    sys.exit(1)

if replace:
    content = new_blocks
else:
    try:
        existing = fetch_existing_content()
    except urllib.error.HTTPError as e:
        print(f'Error {e.code} fetching {key}: {e.read().decode()}', file=sys.stderr)
        sys.exit(1)
    content = list(existing)
    if existing:
        content.append({'type': 'rule'})
    content.extend(new_blocks)

doc = {'type': 'doc', 'version': 1, 'content': content}
payload = {'fields': {'description': doc}}

if dry_run:
    mode = 'REPLACE' if replace else 'APPEND'
    print(f'=== DRY RUN ({mode}) — no write to {key} ===')
    print(json.dumps(payload, indent=2))
    sys.exit(0)

req = urllib.request.Request(
    f'{url}/rest/api/3/issue/{key}',
    data=json.dumps(payload).encode(),
    headers=headers,
    method='PUT',
)
try:
    with urllib.request.urlopen(req) as resp:
        resp.read()
    print(f'Description updated on {key}')
    print(f'{url}/browse/{key}')
except urllib.error.HTTPError as e:
    print(f'Error {e.code} updating {key}: {e.read().decode()}', file=sys.stderr)
    sys.exit(1)
"
