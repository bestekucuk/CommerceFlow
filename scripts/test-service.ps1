<#
.SYNOPSIS
  Tests ONE service or app from its own folder. -Integration adds Testcontainers tests
  (services) or Playwright E2E (apps); both need Docker / installed browsers.
.EXAMPLE
  powershell -File scripts/test-service.ps1 inventory-service
  powershell -File scripts/test-service.ps1 order-service -Integration
#>
param(
    [Parameter(Mandatory = $true)][string]$Name,
    [switch]$Integration
)
. "$PSScriptRoot/lib/components.ps1"

$c = Resolve-Component $Name
$sw = [System.Diagnostics.Stopwatch]::StartNew()
Invoke-ComponentTest $c -Integration:$Integration
$step = if ($Integration) { 'test+integration' } else { 'test' }
Write-Summary @([pscustomobject]@{ Component = $c.Rel; Step = $step; Result = $(if ($LASTEXITCODE -eq 0) { 'ok' } else { "failed ($LASTEXITCODE)" }); Seconds = [math]::Round($sw.Elapsed.TotalSeconds, 1) })
