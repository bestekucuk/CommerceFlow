<#
.SYNOPSIS
  Tests every service and app, each from its own folder. A failure in one component does
  not stop the others.
.EXAMPLE
  powershell -File scripts/test-all.ps1
  powershell -File scripts/test-all.ps1 -Integration
#>
param([switch]$Integration)
. "$PSScriptRoot/lib/components.ps1"

$results = @()
foreach ($name in Get-ComponentNames) {
    $c = Resolve-Component $name
    Write-Host "`n#### $($c.Rel) ($($c.Type))" -ForegroundColor Yellow
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    Invoke-ComponentTest $c -Integration:$Integration
    $step = if ($Integration) { 'test+integration' } else { 'test' }
    $results += [pscustomobject]@{ Component = $c.Rel; Step = $step; Result = $(if ($LASTEXITCODE -eq 0) { 'ok' } else { "failed ($LASTEXITCODE)" }); Seconds = [math]::Round($sw.Elapsed.TotalSeconds, 1) }
}
Write-Summary $results
