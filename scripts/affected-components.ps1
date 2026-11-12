<#
.SYNOPSIS
  Lists CommerceFlow components affected by changes since a git ref (default: HEAD, i.e.
  uncommitted changes including untracked files).

.DESCRIPTION
  Deterministic, read-only. Mapping rules:
    services/<x>/...            -> services/<x>
    apps/<x>/...                -> apps/<x>
    contracts/events/<agg>/...  -> producer and consumers of topics cf.<agg>.* (from docs/event-catalog/README.md)
    contracts/events/common/... -> every service (all generate code from the shared envelope)
    contracts/openapi/<svc>.*   -> services/<svc> and every app whose CLAUDE.md lists <svc> under "Backend APIs used"
    anything else               -> platform:<top-level folder or file>
  Used by the implement-feature, code-review, run-e2e and prepare-pull-request workflows.

.EXAMPLE
  powershell -NoProfile -File scripts/affected-components.ps1
  powershell -NoProfile -File scripts/affected-components.ps1 main -Json
#>
param(
    [string]$Base = 'HEAD',
    [switch]$Json
)

$ErrorActionPreference = 'Continue'
[System.Threading.Thread]::CurrentThread.CurrentCulture = [Globalization.CultureInfo]::InvariantCulture
$root = (& git rev-parse --show-toplevel 2>$null)
if (-not $root) { Write-Error 'Not inside a git repository.'; exit 1 }

$paths = @(& git -C $root diff --name-only $Base 2>$null) + @(& git -C $root ls-files --others --exclude-standard 2>$null) |
    Where-Object { $_ } | Sort-Object -Unique

$services = @(Get-ChildItem -Directory (Join-Path $root 'services') -ErrorAction SilentlyContinue | ForEach-Object { $_.Name })
function To-Service([string]$short) {
    $s = $short.Trim()
    if ($services -contains "$s-service") { return "services/$s-service" }
    return $null
}

# Event catalog: topic -> producer + consumers
$catalogRows = @()
$catalogPath = Join-Path $root 'docs/event-catalog/README.md'
if (Test-Path $catalogPath) {
    foreach ($line in Get-Content $catalogPath) {
        $cells = $line -split '\|' | ForEach-Object { $_.Trim() }
        if ($cells.Count -ge 5 -and $cells[2] -match '^`(cf\.[^`]+)`$') {
            $catalogRows += [pscustomobject]@{ Name = $cells[1]; Topic = $Matches[1]; Producer = $cells[3]; Consumers = $cells[4] }
        }
    }
}

# Apps: which services they call
$appApis = @{}
foreach ($app in Get-ChildItem -Directory (Join-Path $root 'apps') -ErrorAction SilentlyContinue) {
    $md = Join-Path $app.FullName 'CLAUDE.md'
    if (Test-Path $md) {
        $text = Get-Content $md -Raw
        if ($text -match '(?s)## Backend APIs used\s+(.+?)\n\n') { $appApis["apps/$($app.Name)"] = $Matches[1] }
    }
}

$result = @{}
function Add-Hit([string]$component, [string]$reason, [string]$file) {
    if (-not $result.ContainsKey($component)) { $result[$component] = @{ Reasons = New-Object System.Collections.Generic.HashSet[string]; Files = New-Object System.Collections.Generic.List[string] } }
    [void]$result[$component].Reasons.Add($reason)
    $result[$component].Files.Add($file)
}

foreach ($p in $paths) {
    if ($p -match '^(services|apps)/([^/]+)/') { Add-Hit "$($Matches[1])/$($Matches[2])" 'changed directly' $p; continue }
    if ($p -match '^contracts/events/common/') {
        foreach ($s in $services) { Add-Hit "services/$s" 'shared event envelope changed' $p }
        continue
    }
    if ($p -match '^contracts/events/([^/]+)/') {
        $agg = $Matches[1]
        foreach ($row in $catalogRows | Where-Object { $_.Topic -like "cf.$agg.*" }) {
            $prod = To-Service $row.Producer
            if ($prod) { Add-Hit $prod "produces $($row.Name)" $p }
            foreach ($c in $row.Consumers -split ',') {
                $svc = To-Service $c
                if ($svc) { Add-Hit $svc "consumes $($row.Name)" $p }
                elseif ($c.Trim() -and $c.Trim() -ne '—') { Add-Hit "unresolved:$($c.Trim())" "consumes $($row.Name) (owner not decided)" $p }
            }
        }
        continue
    }
    if ($p -match '^contracts/openapi/([a-z0-9-]+-service)\.') {
        $svc = $Matches[1]
        Add-Hit "services/$svc" 'API spec changed' $p
        $short = $svc -replace '-service$', ''
        foreach ($app in $appApis.Keys) {
            if ($appApis[$app] -match "\b$short\b") { Add-Hit $app "calls $svc" $p }
        }
        continue
    }
    $top = ($p -split '/')[0]
    Add-Hit "platform:$top" 'platform/docs/config' $p
}

$rows = foreach ($k in ($result.Keys | Sort-Object)) {
    [pscustomobject]@{ Component = $k; Reasons = (@($result[$k].Reasons) -join '; '); Files = ($result[$k].Files | Sort-Object -Unique).Count }
}

if ($Json) { $rows | ConvertTo-Json -Depth 4; exit 0 }
if (-not $rows) { "No changes since $Base."; exit 0 }
"Changes since ${Base}: $($paths.Count) file(s)"
$rows | Format-Table -AutoSize | Out-String -Width 200
$deployable = @($rows | Where-Object { $_.Component -match '^(services|apps)/' })
if ($deployable.Count -gt 1) {
    "Note: $($deployable.Count) deployable components affected - they deploy separately; plan the order (implement-feature)."
}
