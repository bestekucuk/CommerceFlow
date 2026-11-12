<#
.SYNOPSIS
  Builds ONE service or app with its own tooling (and optionally its Docker image).
.EXAMPLE
  powershell -File scripts/build-service.ps1 order-service
  powershell -File scripts/build-service.ps1 storefront-web -Image
#>
param(
    [Parameter(Mandatory = $true)][string]$Name,
    [switch]$Image,
    [string]$Tag = 'dev'
)
. "$PSScriptRoot/lib/components.ps1"

$c = Resolve-Component $Name
$results = @()
$sw = [System.Diagnostics.Stopwatch]::StartNew()
Invoke-ComponentBuild $c
$results += [pscustomobject]@{ Component = $c.Rel; Step = 'build'; Result = $(if ($LASTEXITCODE -eq 0) { 'ok' } else { "failed ($LASTEXITCODE)" }); Seconds = [math]::Round($sw.Elapsed.TotalSeconds, 1) }
if ($Image -and $LASTEXITCODE -eq 0) {
    $sw.Restart()
    Invoke-ComponentImage $c $Tag
    $results += [pscustomobject]@{ Component = $c.Rel; Step = 'image'; Result = $(if ($LASTEXITCODE -eq 0) { 'ok' } else { "failed ($LASTEXITCODE)" }); Seconds = [math]::Round($sw.Elapsed.TotalSeconds, 1) }
}
Write-Summary $results
