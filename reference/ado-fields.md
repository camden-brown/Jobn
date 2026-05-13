# Azure DevOps Field Mappings

Reference for creating work items via Azure DevOps REST API and `az boards` CLI.

## CLI Approach (Basic Fields Only)

The `az boards` CLI works for plain-text fields. **It silently drops HTML content**
passed via `-f` flags (angle brackets are swallowed by the argument parser).

```powershell
# Safe for plain-text fields
az boards work-item create --title "Story title" --type "User Story" --output json
az boards work-item update --id 12345 -f "Microsoft.VSTS.Scheduling.StoryPoints=3" --output none
az boards work-item update --id 12345 -f "System.Tags=tag1; tag2" --output none
```

### Prerequisites

```bash
az extension add --name azure-devops
az login
az devops configure --defaults organization=https://dev.azure.com/yourorg project=YourProject
```

## REST API Approach (Required for HTML Fields)

**Use the REST API for any field that contains HTML** (Description, Acceptance Criteria).
The CLI cannot reliably set these fields.

```
PATCH https://dev.azure.com/{organization}/{project}/_apis/wit/workitems/{id}?api-version=7.1
Content-Type: application/json-patch+json
```

### Authentication

PAT token as Basic auth: `base64(:pat_token)` (note the leading colon).

### JSON Patch Body

```json
[
  { "op": "add", "path": "/fields/System.Description", "value": "<p>HTML description</p>" },
  { "op": "add", "path": "/fields/Microsoft.VSTS.Common.AcceptanceCriteria", "value": "<ul><li>AC item</li></ul>" },
  { "op": "add", "path": "/fields/System.Tags", "value": "tag1; tag2" }
]
```

### PowerShell Example

```powershell
$token = "your-pat-token"
$headers = @{
    "Content-Type"  = "application/json-patch+json"
    "Authorization" = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$token"))
}
$body = @(
    @{ op = "add"; path = "/fields/System.Description"; value = "<p>My description</p>" }
    @{ op = "add"; path = "/fields/Microsoft.VSTS.Common.AcceptanceCriteria"; value = "<ul><li>AC</li></ul>" }
) | ConvertTo-Json -Depth 3

$uri = "https://dev.azure.com/{org}/{project}/_apis/wit/workitems/{id}?api-version=7.1"
Invoke-RestMethod -Uri $uri -Method Patch -Headers $headers -Body ([System.Text.Encoding]::UTF8.GetBytes($body))
```

## Standard Fields

| Display Name   | API Field              | CLI Flag                      | Supports HTML |
| -------------- | ---------------------- | ----------------------------- | ------------- |
| Title          | `System.Title`         | `--title`                     | No            |
| Work Item Type | `System.WorkItemType`  | `--type`                      | No            |
| State          | `System.State`         | `-f System.State=Active`      | No            |
| Assigned To    | `System.AssignedTo`    | `--assigned-to`               | No            |
| Area Path      | `System.AreaPath`      | `--area-path`                 | No            |
| Iteration Path | `System.IterationPath` | `--iteration`                 | No            |
| Tags           | `System.Tags`          | `-f System.Tags="tag1; tag2"` | No            |
| Description    | `System.Description`   | `--description` (basic only)  | **Yes — use REST API** |

## Custom / Scheduling Fields

| Display Name        | API Field                                  | Notes                                               |
| ------------------- | ------------------------------------------ | --------------------------------------------------- |
| Story Points        | `Microsoft.VSTS.Scheduling.StoryPoints`    | Must use `update` — `create` ignores numeric fields |
| Acceptance Criteria | `Microsoft.VSTS.Common.AcceptanceCriteria` | **HTML — must use REST API** (CLI silently drops it) |
| Priority            | `Microsoft.VSTS.Common.Priority`           | Integer: 1 (Critical) to 4 (Low)                    |
| Severity            | `Microsoft.VSTS.Common.Severity`           | For bugs: 1–4                                       |

## Known CLI Limitations

| Issue | Cause | Workaround |
| ----- | ----- | ---------- |
| AcceptanceCriteria is empty after create/update | CLI `-f` flag silently drops HTML angle brackets | Use REST API with `application/json-patch+json` |
| Description has corrupted special characters | PowerShell encoding issues with em dashes, smart quotes | Use REST API with UTF-8 encoded body |
| Tags empty after create | CLI `-f` on `create` is unreliable for Tags | Set Tags via `update` or REST API after creation |
| Story Points ignored on create | CLI `create` ignores numeric fields | Set via `update -f` after creation |

## Work Item Types

| Type         | When to Use                              |
| ------------ | ---------------------------------------- |
| `User Story` | Feature work with user value             |
| `Bug`        | Defect fix                               |
| `Task`       | Technical work without direct user value |
| `Feature`    | Parent grouping of stories               |
| `Epic`       | Large initiative grouping features       |

## Sprint / Iteration

Sprints are identified by iteration path. Use `az boards iteration team list` to find the path:

```powershell
$iterations = az boards iteration team list --team "MyTeam" --output json | ConvertFrom-Json
$current = $iterations | Where-Object { $_.attributes.timeFrame -eq "current" }
# Use $current.path as the --iteration value
```

## Parent Linking

After creating a work item, link it to a parent:

```powershell
az boards work-item relation add --id $childId --relation-type parent --target-id $parentId
```

## Recommended Create Workflow

1. **Create** via CLI with plain-text fields (title, type, assignee, area, iteration, state)
2. **Update points** via CLI: `az boards work-item update -f "StoryPoints=N"`
3. **Patch HTML fields** via REST API: Description, AcceptanceCriteria, Tags
4. **Link parent** via CLI: `az boards work-item relation add`

The `create-work-item.ps1` script handles this workflow automatically when a
PAT token is available (reads from `config.yaml` or `-Token` parameter).

## Config Field Mappings

From `config.yaml` → `push.field_mappings.ado`:

```yaml
push:
  field_mappings:
    ado:
      story_points_field: 'Microsoft.VSTS.Scheduling.StoryPoints'
      acceptance_criteria_field: 'Microsoft.VSTS.Common.AcceptanceCriteria'
```

## Common Errors

| Issue      | Cause                                                 |
| ---------- | ----------------------------------------------------- |
| `TF401019` | Work item type not valid for the process              |
| `TF400813` | Field not valid for the work item type                |
| `VS403496` | Area/Iteration path not found                         |
| 401        | PAT expired or lacks `Work Items: Read & Write` scope |
