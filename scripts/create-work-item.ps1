# ──────────────────────────────────────────────────
# create-work-item.ps1
# Create a work item in Azure DevOps
# ──────────────────────────────────────────────────
#
# Prerequisites (one-time setup):
#   1. Install Azure CLI: winget install Microsoft.AzureCLI
#   2. Install DevOps extension: az extension add --name azure-devops
#   3. Sign in: az login
#
# Usage:
#   .\scripts\create-work-item.ps1 -JobName myjob -Title "My story"
#   .\scripts\create-work-item.ps1 -JobName myjob -Title "Fix bug" -Type Bug -Sprint "26.2.2"
#   .\scripts\create-work-item.ps1 -Organization "https://dev.azure.com/org" -Project "MyProject" -Team "MyTeam" -Title "My story"
# ──────────────────────────────────────────────────

param(
    [string]$JobName,

    [Parameter(Mandatory)]
    [string]$Title,

    [ValidateSet("User Story", "Bug", "Task", "Feature", "Epic")]
    [string]$Type = "User Story",

    [string]$Description,
    [string]$AcceptanceCriteria,
    [string]$Sprint,
    [string]$Assignee,
    [int]$Points,
    [string]$Tags,
    [int]$ParentId,
    [ValidateSet("New", "Active", "Resolved", "Closed")]
    [string]$State,
    [string]$AreaPath,
    [hashtable]$Fields = @{},
    [string]$Organization,
    [string]$Project,
    [string]$Team,
    [string]$Token
)

# Resolve config from job if JobName provided
$configText = $null
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
    if (-not $Token) {
        $tokenMatch = $configText | Select-String 'token:\s*"?([^"\r\n]+)'
        if ($tokenMatch) { $Token = $tokenMatch.Matches[0].Groups[1].Value.Trim('"', ' ') }
    }
}

if (-not $Organization -or -not $Project -or -not $Team) {
    Write-Host "Provide -JobName or -Organization, -Project, and -Team parameters." -ForegroundColor Red
    exit 1
}

# Configure defaults for this session
az devops configure --defaults organization=$Organization project=$Project

# Resolve sprint name to iteration path
$iterationPath = $null
if ($Sprint) {
    $iterations = az boards iteration team list --team $Team --output json | ConvertFrom-Json
    $match = $iterations | Where-Object { $_.name -eq $Sprint } | Select-Object -First 1
    if (-not $match) {
        Write-Host "Sprint '$Sprint' not found. Available sprints:" -ForegroundColor Red
        $iterations | Sort-Object { $_.attributes.startDate } | ForEach-Object {
            $tf = $_.attributes.timeFrame
            $color = if ($tf -eq "current") { "Green" } elseif ($tf -eq "future") { "Yellow" } else { "Gray" }
            Write-Host "  $($_.name) ($tf)" -ForegroundColor $color
        }
        exit 1
    }
    $iterationPath = $match.path
}

# Build the base CLI command (plain-text fields only)
$cmdArgs = @(
    "boards", "work-item", "create"
    "--title", $Title
    "--type", $Type
    "--output", "json"
)

if ($Assignee)           { $cmdArgs += "--assigned-to";    $cmdArgs += $Assignee }
if ($AreaPath)           { $cmdArgs += "--area-path";      $cmdArgs += $AreaPath }
if ($iterationPath)      { $cmdArgs += "--iteration";      $cmdArgs += $iterationPath }

# Plain-text fields via -f (State is safe; HTML fields use REST API below)
$fieldArgs = @()
if ($State)              { $fieldArgs += "System.State=$State" }

foreach ($key in $Fields.Keys) {
    $fieldArgs += "$key=$($Fields[$key])"
}

foreach ($f in $fieldArgs) {
    $cmdArgs += "-f"
    $cmdArgs += $f
}

Write-Host "Creating $Type`: $Title" -ForegroundColor Cyan
$result = & az @cmdArgs | ConvertFrom-Json

if (-not $result) {
    Write-Host "Failed to create work item." -ForegroundColor Red
    exit 1
}

# Story points must be set via update (create ignores numeric fields)
if ($Points) {
    az boards work-item update --id $result.id -f "Microsoft.VSTS.Scheduling.StoryPoints=$Points" --output none 2>$null
}

# ──────────────────────────────────────────────────
# Set HTML / rich fields via REST API.
# The az CLI -f flag silently drops HTML content (angle brackets are
# swallowed by the argument parser). The REST API with JSON Patch
# handles HTML fields correctly.
# ──────────────────────────────────────────────────
$patchOps = @()
if ($Description)        { $patchOps += @{ op = "add"; path = "/fields/System.Description"; value = $Description } }
if ($AcceptanceCriteria) { $patchOps += @{ op = "add"; path = "/fields/Microsoft.VSTS.Common.AcceptanceCriteria"; value = $AcceptanceCriteria } }
if ($Tags)               { $patchOps += @{ op = "add"; path = "/fields/System.Tags"; value = $Tags } }

if ($patchOps.Count -gt 0) {
    if ($Token) {
        $patchHeaders = @{
            "Content-Type"  = "application/json-patch+json"
            "Authorization" = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$Token"))
        }
        $patchBody = $patchOps | ConvertTo-Json -Depth 3
        # Wrap single-op array (ConvertTo-Json unwraps arrays of length 1)
        if ($patchOps.Count -eq 1) { $patchBody = "[$patchBody]" }
        $patchUri = "$Organization/$([uri]::EscapeDataString($Project))/_apis/wit/workitems/$($result.id)?api-version=7.1"
        try {
            $null = Invoke-RestMethod -Uri $patchUri -Method Patch -Headers $patchHeaders -Body ([System.Text.Encoding]::UTF8.GetBytes($patchBody))
            Write-Host "Set rich fields (Description, AC, Tags) via REST API" -ForegroundColor Green
        } catch {
            Write-Host "Warning: REST API patch failed: $($_.Exception.Message)" -ForegroundColor Yellow
            Write-Host "  HTML fields (AcceptanceCriteria, Description) may be empty." -ForegroundColor Yellow
        }
    } else {
        Write-Host "Warning: no PAT token available — falling back to CLI for rich fields." -ForegroundColor Yellow
        Write-Host "  HTML content in AcceptanceCriteria / Description may be silently dropped." -ForegroundColor Yellow
        # Best-effort fallback via CLI update
        $fallbackArgs = @()
        if ($Description)        { $fallbackArgs += "System.Description=$Description" }
        if ($AcceptanceCriteria) { $fallbackArgs += "Microsoft.VSTS.Common.AcceptanceCriteria=$AcceptanceCriteria" }
        if ($Tags)               { $fallbackArgs += "System.Tags=$Tags" }
        foreach ($fb in $fallbackArgs) {
            az boards work-item update --id $result.id -f $fb --output none 2>$null
        }
    }
}

$item = [PSCustomObject]@{
    ID       = $result.id
    Type     = $result.fields.'System.WorkItemType'
    Title    = $result.fields.'System.Title'
    State    = $result.fields.'System.State'
    Sprint   = $result.fields.'System.IterationPath'
    Assigned = $result.fields.'System.AssignedTo'.displayName
    Points   = $Points
    URL      = $result._links.html.href
}

# Link to parent if specified
if ($ParentId) {
    Write-Host "Linking to parent work item #$ParentId..." -ForegroundColor Cyan
    az boards work-item relation add --id $result.id --relation-type parent --target-id $ParentId --output none
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Linked to parent #$ParentId" -ForegroundColor Green
    } else {
        Write-Host "Warning: failed to link to parent #$ParentId" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "Created work item #$($item.ID)" -ForegroundColor Green
$item | Format-List
