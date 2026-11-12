<#
.SYNOPSIS
  Registers (create or update, idempotent PUT) the Debezium outbox connector for each
  publishing service whose outbox table and publication exist. Services that have not run
  their migrations yet are skipped with a message.
.EXAMPLE
  powershell -File infrastructure/scripts/register-connectors.ps1
  powershell -File infrastructure/scripts/register-connectors.ps1 -Service product
#>
param([string]$Service)
. "$PSScriptRoot/lib/infra.ps1"

$targets = if ($Service) { @($Service) } else { $script:Publishers }
$results = @()
foreach ($svc in $targets) {
    if ($script:Publishers -notcontains $svc) { throw "'$svc' publishes no events (no connector)." }
    $pw = Get-EnvValue "$($svc.ToUpperInvariant())_DB_MIGRATOR_PASSWORD"
    $ready = (Invoke-Psql "${svc}_migrator" $pw "${svc}_db" "SELECT count(*) FROM pg_publication WHERE pubname = 'cf_${svc}_outbox';") -join ''
    if ($ready.Trim() -ne '1') {
        $results += [pscustomobject]@{ Connector = "$svc-outbox"; Result = 'skipped: run migrate.ps1 -Service ' + $svc }
        continue
    }
    $file = Join-Path $script:Root "infrastructure/debezium/connectors/$svc-outbox.json"
    $body = Get-Content -Raw $file
    try {
        Invoke-RestMethod -Method Put -Uri "$($script:ConnectUrl)/connectors/$svc-outbox/config" -ContentType 'application/json' -Body $body | Out-Null
        Start-Sleep -Seconds 3
        $status = Invoke-RestMethod -Uri "$($script:ConnectUrl)/connectors/$svc-outbox/status"
        $tasks = ($status.tasks | ForEach-Object { $_.state }) -join ','
        $results += [pscustomobject]@{ Connector = "$svc-outbox"; Result = "connector=$($status.connector.state) tasks=$tasks" }
    } catch {
        $results += [pscustomobject]@{ Connector = "$svc-outbox"; Result = "FAILED: $($_.Exception.Message)" }
    }
}
$results | Format-Table -AutoSize | Out-String -Width 200 | Write-Host
if ($results | Where-Object { $_.Result -like 'FAILED*' -or $_.Result -like '*FAILED*' }) { exit 1 }
