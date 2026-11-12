<#
.SYNOPSIS
  Registers event schemas from contracts/events in the local Schema Registry, or only
  checks their compatibility (-CheckOnly). Shared types from contracts/events/common are
  inlined, so the registered schema is self-contained.

  Subject (TopicRecordNameStrategy): cf.<aggregate>.events.v<major>-<namespace>.<Record>
  Compatibility: BACKWARD (registry default, also set per subject).
.EXAMPLE
  powershell -File infrastructure/scripts/register-schemas.ps1
  powershell -File infrastructure/scripts/register-schemas.ps1 -CheckOnly
#>
param([switch]$CheckOnly, [string]$RegistryUrl = 'http://localhost:8090')
. "$PSScriptRoot/lib/infra.ps1"

$contracts = Join-Path $script:Root 'contracts/events'
$common = @{}
foreach ($f in Get-ChildItem (Join-Path $contracts 'common') -Filter *.avsc) {
    $s = Get-Content -Raw $f.FullName | ConvertFrom-Json
    $common["$($s.namespace).$($s.name)"] = $s
}

# Replace references to shared named types with their definition (first use only, as Avro requires).
function Expand-Type($node, [System.Collections.Generic.HashSet[string]]$defined) {
    if ($node -is [string]) {
        if ($common.ContainsKey($node) -and $defined.Add($node)) { return (Expand-Type $common[$node] $defined) }
        return $node
    }
    if ($node -is [System.Array]) { return , @($node | ForEach-Object { Expand-Type $_ $defined }) }
    if ($node -is [System.Management.Automation.PSCustomObject]) {
        $copy = [ordered]@{}
        foreach ($p in $node.PSObject.Properties) {
            $copy[$p.Name] = if ($p.Name -in 'type', 'items', 'values', 'fields') { Expand-Type $p.Value $defined } else { $p.Value }
        }
        if ($copy.Contains('namespace') -and $copy.Contains('name')) { [void]$defined.Add("$($copy.namespace).$($copy.name)") }
        return [pscustomobject]$copy
    }
    return $node
}

$results = @()
foreach ($f in Get-ChildItem $contracts -Recurse -Filter *.avsc | Where-Object { $_.Directory.Name -ne 'common' }) {
    if ($f.Name -notmatch '^(?<record>[A-Za-z]+)\.v(?<major>\d+)\.avsc$') { throw "Unexpected schema file name: $($f.Name)" }
    $major = $Matches.major
    $aggregate = $f.Directory.Name
    $kind = if ($Matches.record -match '^(Reserve|Release|Authorize|Void)') { 'commands' } else { 'events' }
    $topic = "cf.$aggregate.$kind.v$major"
    $schema = Get-Content -Raw $f.FullName | ConvertFrom-Json
    $expanded = Expand-Type $schema (New-Object 'System.Collections.Generic.HashSet[string]')
    $schemaJson = $expanded | ConvertTo-Json -Depth 64 -Compress
    $subject = "$topic-$($schema.namespace).$($schema.name)"
    $body = @{ schema = $schemaJson; schemaType = 'AVRO' } | ConvertTo-Json -Depth 3 -Compress
    $ct = 'application/vnd.schemaregistry.v1+json'
    try {
        $exists = $true
        try { Invoke-RestMethod -Uri "$RegistryUrl/subjects/$subject/versions/latest" | Out-Null } catch { $exists = $false }
        if ($CheckOnly) {
            if (-not $exists) { $results += [pscustomobject]@{ Subject = $subject; Result = 'new subject (nothing to compare)' }; continue }
            $r = Invoke-RestMethod -Method Post -Uri "$RegistryUrl/compatibility/subjects/$subject/versions/latest?verbose=true" -ContentType $ct -Body $body
            $results += [pscustomobject]@{ Subject = $subject; Result = $(if ($r.is_compatible) { 'compatible' } else { 'INCOMPATIBLE: ' + ($r.messages -join '; ') }) }
        } else {
            Invoke-RestMethod -Method Put -Uri "$RegistryUrl/config/$subject" -ContentType $ct -Body '{"compatibility":"BACKWARD"}' | Out-Null
            $r = Invoke-RestMethod -Method Post -Uri "$RegistryUrl/subjects/$subject/versions" -ContentType $ct -Body $body
            $results += [pscustomobject]@{ Subject = $subject; Result = "registered id=$($r.id)" }
        }
    } catch {
        $msg = $_.ErrorDetails.Message; if (-not $msg) { $msg = $_.Exception.Message }
        $results += [pscustomobject]@{ Subject = $subject; Result = "FAILED: $msg" }
    }
}
$results | Format-Table -AutoSize | Out-String -Width 250 | Write-Host
if ($results | Where-Object { $_.Result -match 'FAILED|INCOMPATIBLE' }) { exit 1 }
