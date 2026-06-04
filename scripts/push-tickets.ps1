# push-tickets.ps1 - Push all stories from a decomposition to ADO
#
# Usage:
#   .\scripts\push-tickets.ps1 -JobName dcp-ui -FeatureSlug template-library
#   .\scripts\push-tickets.ps1 -JobName dcp-ui -FeatureSlug template-library -DryRun

param(
    [Parameter(Mandatory)]
    [string]$JobName,

    [Parameter(Mandatory)]
    [string]$FeatureSlug,

    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$jobnRoot = Split-Path -Parent $scriptDir
$decompDir = Join-Path $jobnRoot ('jobs/' + $JobName + '/decompositions/' + $FeatureSlug)
$storiesPath = Join-Path $decompDir 'stories.json'
$pushedPath = Join-Path $decompDir 'pushed.json'
$createScript = Join-Path $scriptDir 'create-work-item.ps1'

if (-not (Test-Path $storiesPath)) {
    Write-Host ('Stories file not found: ' + $storiesPath) -ForegroundColor Red
    exit 1
}

$data = Get-Content $storiesPath -Raw | ConvertFrom-Json
$stories = $data.stories | Sort-Object { $_.order }
$totalCount = $stories.Count

Write-Host ('Pushing ' + $totalCount + ' stories for ' + $FeatureSlug + ' via job ' + $JobName) -ForegroundColor Cyan
if ($DryRun) {
    Write-Host '=== DRY RUN - no tickets will be created ===' -ForegroundColor Yellow
    Write-Host ''
}

$ticketsList = @()
$errorsList = @()

foreach ($story in $stories) {
    $order = $story.order
    $summary = $story.summary
    Write-Host ('[' + $order + '/' + $totalCount + '] ' + $summary) -ForegroundColor White

    # Build description HTML
    $desc = '<p>' + $story.description + '</p>'

    $errStates = @($story.error_states | Where-Object { $_ })
    if ($errStates.Count -gt 0) {
        $desc += '<h3>Error States</h3><ul>'
        foreach ($e in $errStates) { $desc += '<li>' + $e + '</li>' }
        $desc += '</ul>'
    }

    $loadStates = @($story.loading_states | Where-Object { $_ })
    if ($loadStates.Count -gt 0) {
        $desc += '<h3>Loading States</h3><ul>'
        foreach ($l in $loadStates) { $desc += '<li>' + $l + '</li>' }
        $desc += '</ul>'
    }

    $deps = @($story.dependencies | Where-Object { $_ })
    if ($deps.Count -gt 0) {
        $desc += '<h3>Dependencies</h3><ul>'
        foreach ($d in $deps) {
            if ($d.type) {
                $desc += '<li>[' + $d.type + '] ' + $d.description + '</li>'
            }
            else {
                $desc += '<li>' + $d + '</li>'
            }
        }
        $desc += '</ul>'
    }

    # Build acceptance criteria HTML
    $acHtml = ''
    $ac = @($story.acceptance_criteria | Where-Object { $_ })
    if ($ac.Count -gt 0) {
        $acHtml = '<ul>'
        foreach ($criterion in $ac) {
            if ($criterion.given) {
                $acHtml += '<li>Given ' + $criterion.given + ', when ' + $criterion.when + ', then ' + $criterion.then + '</li>'
            }
            else {
                $acHtml += '<li>' + $criterion + '</li>'
            }
        }
        $acHtml += '</ul>'
    }

    # Map issue type
    $issueType = $story.issue_type
    if ($issueType -eq 'Story') { $issueType = 'User Story' }
    if (-not $issueType) { $issueType = 'User Story' }

    # Tags from labels
    $tags = ($story.labels -join '; ')

    # Points
    $points = [int]$story.story_points

    if ($DryRun) {
        Write-Host ('  Type: ' + $issueType + ' | Priority: ' + $story.priority + ' | Points: ' + $points) -ForegroundColor Gray
        Write-Host ('  Tags: ' + $tags) -ForegroundColor Gray
        Write-Host ('  Description: ' + $desc.Length + ' chars') -ForegroundColor Gray
        Write-Host ('  AC: ' + $acHtml.Length + ' chars') -ForegroundColor Gray
        Write-Host ''
        $ticketsList += [PSCustomObject]@{
            order   = $order
            key     = 'DRY-RUN'
            summary = $summary
            url     = 'n/a'
        }
        continue
    }

    try {
        $createArgs = @{
            JobName            = $JobName
            Title              = $summary
            Type               = $issueType
            Description        = $desc
            AcceptanceCriteria = $acHtml
            Points             = $points
            Tags               = $tags
        }

        $output = & $createScript @createArgs *>&1
        $outputText = ($output | ForEach-Object { $_.ToString() }) -join "`n"
        foreach ($line in $output) { Write-Host ('  ' + $line) }

        # Extract the work item ID from the output
        $idMatch = [regex]::Match($outputText, 'Created work item #(\d+)')
        if ($idMatch.Success) {
            $wiId = $idMatch.Groups[1].Value
            $urlMatch = [regex]::Match($outputText, 'URL\s*:\s*(https?://\S+)')
            $wiUrl = if ($urlMatch.Success) { $urlMatch.Groups[1].Value } else { '' }
            $ticketsList += [PSCustomObject]@{
                order   = $order
                key     = $wiId
                summary = $summary
                url     = $wiUrl
            }
        }
        else {
            throw 'Could not parse work item ID from output'
        }
    }
    catch {
        $errMsg = 'Error creating story ' + $order + ': ' + $_.Exception.Message
        Write-Host ('  ERROR: ' + $errMsg) -ForegroundColor Red
        $errorsList += [PSCustomObject]@{
            order   = $order
            summary = $summary
            error   = $errMsg
        }
    }
}

# Save results
$resultObj = [PSCustomObject]@{
    pushed_at = (Get-Date).ToUniversalTime().ToString('o')
    tickets   = $ticketsList
    errors    = $errorsList
}
$resultObj | ConvertTo-Json -Depth 5 | Set-Content $pushedPath -Encoding UTF8

$created = $ticketsList.Count
$failed = $errorsList.Count

Write-Host ''
if ($DryRun) {
    Write-Host ('Dry run complete: ' + $created + ' stories would be created') -ForegroundColor Green
}
else {
    $color = if ($failed -gt 0) { 'Yellow' } else { 'Green' }
    Write-Host ('Done: ' + $created + ' created, ' + $failed + ' failed') -ForegroundColor $color
}
Write-Host ('Results saved to ' + $pushedPath)

if ($failed -gt 0) { exit 1 }
