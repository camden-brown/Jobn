# Azure DevOps Field Mappings

Reference for creating work items via Azure DevOps REST API and `az boards` CLI.

## CLI Approach (Primary — used by `create-work-item.ps1`)

```powershell
az boards work-item create --title "Story title" --type "User Story" --output json
az boards work-item update --id 12345 -f "Microsoft.VSTS.Scheduling.StoryPoints=3" --output none
```

### Prerequisites

```bash
az extension add --name azure-devops
az login
az devops configure --defaults organization=https://dev.azure.com/yourorg project=YourProject
```

## REST API Approach

```
POST https://dev.azure.com/{organization}/{project}/_apis/wit/workitems/$User%20Story?api-version=7.1
```

### Authentication

PAT token as Basic auth: `base64(:pat_token)` (note the leading colon).

## Standard Fields

| Display Name   | API Field              | CLI Flag                      |
| -------------- | ---------------------- | ----------------------------- |
| Title          | `System.Title`         | `--title`                     |
| Work Item Type | `System.WorkItemType`  | `--type`                      |
| State          | `System.State`         | `-f System.State=Active`      |
| Assigned To    | `System.AssignedTo`    | `--assigned-to`               |
| Area Path      | `System.AreaPath`      | `--area-path`                 |
| Iteration Path | `System.IterationPath` | `--iteration`                 |
| Tags           | `System.Tags`          | `-f System.Tags="tag1; tag2"` |
| Description    | `System.Description`   | `--description` (HTML)        |

## Custom / Scheduling Fields

| Display Name        | API Field                                  | Notes                                               |
| ------------------- | ------------------------------------------ | --------------------------------------------------- |
| Story Points        | `Microsoft.VSTS.Scheduling.StoryPoints`    | Must use `update` — `create` ignores numeric fields |
| Acceptance Criteria | `Microsoft.VSTS.Common.AcceptanceCriteria` | HTML format                                         |
| Priority            | `Microsoft.VSTS.Common.Priority`           | Integer: 1 (Critical) to 4 (Low)                    |
| Severity            | `Microsoft.VSTS.Common.Severity`           | For bugs: 1–4                                       |

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
