# ──────────────────────────────────────────────────
# get-sprint-items.ps1
# Read all work items in the current sprint from ADO
# ──────────────────────────────────────────────────
#
# Prerequisites (one-time setup):
#   1. Install Azure CLI: winget install Microsoft.AzureCLI
#   2. Install DevOps extension: az extension add --name azure-devops
#   3. Sign in: az login
#
# Usage:
#   .\scripts\get-sprint-items.ps1 -JobName myjob                        # current sprint, all items
#   .\scripts\get-sprint-items.ps1 -JobName myjob -Person "John Doe"   # filter by assignee
#   .\scripts\get-sprint-items.ps1 -JobName myjob -Sprint "26.2.2"         # specific sprint
#   .\scripts\get-sprint-items.ps1 -Organization "https://dev.azure.com/org" -Project "MyProject" -Team "MyTeam"
# ──────────────────────────────────────────────────

param(
    [string]$JobName,
    [string]$Person,
    [string]$Sprint,
    [string]$Organization,
    [string]$Project,
    [string]$Team
)

# Resolve config from job if JobName provided
if ($JobName) {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $configPath = Join-Path (Split-Path -Parent $scriptDir) "jobs/$JobName/config.yaml"
    if (-not (Test-Path $configPath)) {
        Write-Host "Job config not found: $configPath" -ForegroundColor Red
        exit 1
    }
    $configText = Get-Content $configPath -Raw
    if (-not $Organization) { $Organization = "https://dev.azure.com/" + ($configText | Select-String 'organization:\s*"?([^"\r\n]+)' | ForEach-Object { $_.Matches[0].Groups[1].Value.Trim() }) }
    if (-not $Project)      { $Project = ($configText | Select-String 'project:\s*"?([^"\r\n]+)' | ForEach-Object { $_.Matches[0].Groups[1].Value.Trim('"', ' ') }) }
    if (-not $Team)         { $Team = ($configText | Select-String 'team:\s*"?([^"\r\n]+)' | ForEach-Object { $_.Matches[0].Groups[1].Value.Trim('"', ' ') }) }
    if (-not $Person) {
        $assignee = ($configText | Select-String 'assignee:\s*"?([^"\r\n]+)' | ForEach-Object { $_.Matches[0].Groups[1].Value.Trim('"', ' ') })
        if ($assignee) { $Person = $assignee }
    }
}

if (-not $Organization -or -not $Project -or -not $Team) {
    Write-Host "Provide -JobName or -Organization, -Project, and -Team parameters." -ForegroundColor Red
    exit 1
}

# Configure defaults for this session
az devops configure --defaults organization=$Organization project=$Project

# Get the current iteration for the team
Write-Host "Fetching sprint info for team '$Team'..." -ForegroundColor Cyan
$iterations = az boards iteration team list --team $Team --output json | ConvertFrom-Json

if ($Sprint) {
    $iteration = $iterations | Where-Object { $_.name -eq $Sprint } | Select-Object -First 1
    if (-not $iteration) {
        Write-Host "Sprint '$Sprint' not found. Available sprints:" -ForegroundColor Red
        $iterations | ForEach-Object { Write-Host "  $($_.name)" }
        exit 1
    }
} else {
    $iteration = $iterations | Where-Object { $_.attributes.timeFrame -eq "current" } | Select-Object -First 1
}

if (-not $iteration) {
    Write-Host "Could not determine the current sprint. Check your team name and permissions." -ForegroundColor Red
    exit 1
}

Write-Host "Current sprint: $($iteration.name) ($($iteration.attributes.startDate.Substring(0,10)) to $($iteration.attributes.finishDate.Substring(0,10)))" -ForegroundColor Green
Write-Host ""

# Build WIQL query
$iterPath = $iteration.path
$whereClause = "[System.IterationPath] = '$iterPath' AND [System.WorkItemType] IN ('User Story', 'Bug', 'Task')"

if ($Person) {
    $whereClause += " AND [System.AssignedTo] CONTAINS '$Person'"
}

$query = "SELECT [System.Id], [System.Title], [System.State], [System.AssignedTo], [Microsoft.VSTS.Scheduling.StoryPoints], [System.WorkItemType] FROM WorkItems WHERE $whereClause ORDER BY [System.WorkItemType], [System.State]"

$results = az boards query --wiql $query --output json | ConvertFrom-Json

if (-not $results -or $results.Count -eq 0) {
    $msg = "No work items found in sprint '$($iteration.name)'"
    if ($Person) { $msg += " for '$Person'" }
    Write-Host "$msg." -ForegroundColor Yellow
    exit 0
}

Write-Host "Found $($results.Count) work items:" -ForegroundColor Cyan
Write-Host ""

# Extract work item details from query results
$items = $results | ForEach-Object {
    [PSCustomObject]@{
        ID       = $_.fields.'System.Id'
        Type     = $_.fields.'System.WorkItemType'
        Title    = $_.fields.'System.Title'
        State    = $_.fields.'System.State'
        Points   = $_.fields.'Microsoft.VSTS.Scheduling.StoryPoints'
        Assigned = $_.fields.'System.AssignedTo'.displayName
    }
}

$items | Format-Table -AutoSize
