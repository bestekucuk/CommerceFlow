<#
.SYNOPSIS
  Builds every service and app, one after another, each with its own tooling. A failure
  in one component does not stop the others; the summary lists every result.
.EXAMPLE
  powershell -File scripts/build-all.ps1
  powershell -File scripts/build-all.ps1 -Image
#>
param([switch]$Image, [string]$Tag = 'dev')
. "$PSScriptRoot/lib/components.ps1"

$results = @()
foreach ($name in Get-ComponentNames) {
    $c = Resolve-Component $name
    Write-Host "`n#### $($c.Rel) ($($c.Type))" -ForegroundColor Yellow
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    Invoke-ComponentBuild $c
    $ok = $LASTEXITCODE -eq 0
    $results += [pscustomobject]@{ Component = $c.Rel; Step = 'build'; Result = $(if ($ok) { 'ok' } else { "failed ($LASTEXITCODE)" }); Seconds = [math]::Round($sw.Elapsed.TotalSeconds, 1) }
    if ($Image -and $ok) {
        $sw.Restart()
        Invoke-ComponentImage $c $Tag
        $results += [pscustomobject]@{ Component = $c.Rel; Step = 'image'; Result = $(if ($LASTEXITCODE -eq 0) { 'ok' } else { "failed ($LASTEXITCODE)" }); Seconds = [math]::Round($sw.Elapsed.TotalSeconds, 1) }
    }
}
Write-Summary $results
