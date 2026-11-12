<#
.SYNOPSIS
  Stops the local infrastructure. Data volumes are kept unless -RemoveVolumes -Force is
  given (that deletes all local databases, topics and dashboards state).
.EXAMPLE
  powershell -File infrastructure/scripts/down.ps1
  powershell -File infrastructure/scripts/down.ps1 -RemoveVolumes -Force
#>
param([switch]$RemoveVolumes, [switch]$Force)
. "$PSScriptRoot/lib/infra.ps1"

if ($RemoveVolumes) {
    if (-not $Force) {
        Write-Host 'Refusing to delete volumes without -Force. This removes every local database, Kafka topic and Grafana state.' -ForegroundColor Yellow
        exit 1
    }
    Invoke-Compose down --volumes
} else {
    Invoke-Compose down
}
exit $LASTEXITCODE
