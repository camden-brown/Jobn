# ──────────────────────────────────────────────────
# update-work-item.ps1
# Update an existing work item in Azure DevOps
# ──────────────────────────────────────────────────
#
# Usage:
#   .\scripts\update-work-item.ps1 -JobName dcp-ui -Id 12345 -Description "<p>New desc</p>"
#   .\scripts\update-work-item.ps1 -JobName dcp-ui -Id 12345 -AcceptanceCriteria "<ul><li>AC</li></ul>"
#   .\scripts\update-work-item.ps1 -JobName dcp-ui -Id 12345 -Title "New title" -Points 5 -Tags "tag1; tag2"
#   .\scripts\update-work-item.ps1 -Organization "https://dev.azure.com/org" -Project "MyProject" -Id 12345 -Description "<p>desc</p>"
# ──────────────────────────────────────────────────

param(
    [string]$JobName,

    [Parameter(Mandatory)]
    [int]$Id,

    [string]$Title,
    [string]$Description,
    [string]$AcceptanceCriteria,
    [string]$Tags,
    [int]$Points,
    [ValidateSet("New", "Active", "Resolved", "Closed")]
    [string]$State,
    [string]$Sprint,
    [string]$Assignee,
    [string]$AreaPath,
    [string]$Organization,
    [string]$Project,
    [string]$Team,
    [string]$Token
)

$ErrorActionPreference = 'Stop'

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
    if (-not $Token) {
        $tokenMatch = $configText | Select-String 'token:\s*"?([^"\r\n]+)'
        if ($tokenMatch) { $Token = $tokenMatch.Matches[0].Groups[1].Value.Trim('"', ' ') }
    }
}

if (-not $Organization -or -not $Project) {
    Write-Host "Provide -JobName or -Organization and -Project parameters." -ForegroundColor Red
    exit 1
}

if (-not $Token) {
    Write-Host "No PAT token available. Provide -Token or set it in the job config." -ForegroundColor Red
    exit 1
}

# Build JSON Patch operations
$patchOps = @()

if ($Title)              { $patchOps += @{ op = "add"; path = "/fields/System.Title"; value = $Title } }
if ($Description)        { $patchOps += @{ op = "add"; path = "/fields/System.Description"; value = $Description } }
if ($AcceptanceCriteria) { $patchOps += @{ op = "add"; path = "/fields/Microsoft.VSTS.Common.AcceptanceCriteria"; value = $AcceptanceCriteria } }
if ($Tags)               { $patchOps += @{ op = "add"; path = "/fields/System.Tags"; value = $Tags } }
if ($State)              { $patchOps += @{ op = "add"; path = "/fields/System.State"; value = $State } }
if ($Assignee)           { $patchOps += @{ op = "add"; path = "/fields/System.AssignedTo"; value = $Assignee } }
if ($AreaPath)           { $patchOps += @{ op = "add"; path = "/fields/System.AreaPath"; value = $AreaPath } }
if ($Points)             { $patchOps += @{ op = "add"; path = "/fields/Microsoft.VSTS.Scheduling.StoryPoints"; value = $Points } }

# Resolve sprint
if ($Sprint -and $Team) {
    az devops configure --defaults organization=$Organization project=$Project 2>$null
    $iterations = az boards iteration team list --team $Team --output json | ConvertFrom-Json
    $match = $iterations | Where-Object { $_.name -eq $Sprint } | Select-Object -First 1
    if ($match) {
        $patchOps += @{ op = "add"; path = "/fields/System.IterationPath"; value = $match.path }
    } else {
        Write-Host "Sprint '$Sprint' not found." -ForegroundColor Yellow
    }
}

if ($patchOps.Count -eq 0) {
    Write-Host "No fields to update. Provide at least one field parameter." -ForegroundColor Yellow
    exit 0
}

# Call REST API
$headers = @{
    "Content-Type"  = "application/json-patch+json"
    "Authorization" = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$Token"))
}

$patchBody = $patchOps | ConvertTo-Json -Depth 3
if ($patchOps.Count -eq 1) { $patchBody = "[$patchBody]" }

$uri = "$Organization/$([uri]::EscapeDataString($Project))/_apis/wit/workitems/$($Id)?api-version=7.1"

Write-Host "Updating work item #$Id ($($patchOps.Count) fields)..." -ForegroundColor Cyan

try {
    $result = Invoke-RestMethod -Uri $uri -Method Patch -Headers $headers -Body ([System.Text.Encoding]::UTF8.GetBytes($patchBody))
    Write-Host "Updated work item #$Id successfully" -ForegroundColor Green
    Write-Host "  URL: $Organization/$([uri]::EscapeDataString($Project))/_workitems/edit/$Id" -ForegroundColor Gray
} catch {
    Write-Host "Failed to update work item #$Id`: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.Exception.Response) {
        $reader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
        $body = $reader.ReadToEnd()
        Write-Host "  Response: $body" -ForegroundColor Red
    }
    exit 1
}
