<#
.SYNOPSIS
  End-to-end CDC check for one service: inserts one outbox row (as the service's runtime
  role) that routes to the local-only topic cf.cdc-check.v1, then reads that topic and
  verifies key, headers and payload produced by Debezium + the Outbox Event Router.
  Requires: stack up, migrate.ps1 and register-connectors.ps1 run for the service.
.EXAMPLE
  powershell -File infrastructure/scripts/verify-cdc.ps1 -Service product
#>
param([string]$Service = 'product', [int]$TimeoutSeconds = 60)
. "$PSScriptRoot/lib/infra.ps1"

$svc = $Service
$pw = Get-EnvValue "$($svc.ToUpperInvariant())_DB_SERVICE_PASSWORD"
$eventId = [guid]::NewGuid().ToString()
$key = "cdc-check-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
$payload = "cdc-check $eventId"
$traceparent = '00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01'

$status = Invoke-RestMethod -Uri "$($script:ConnectUrl)/connectors/$svc-outbox/status" -ErrorAction SilentlyContinue
if (-not $status -or $status.connector.state -ne 'RUNNING' -or ($status.tasks | Where-Object { $_.state -ne 'RUNNING' })) {
    Write-Host "Connector $svc-outbox is not RUNNING. Run migrate.ps1 and register-connectors.ps1 first." -ForegroundColor Red
    exit 1
}

$sql = @"
INSERT INTO outbox (id, aggregate_type, aggregate_id, type, topic, payload, trace_parent)
VALUES ('$eventId', 'cdc-check', '$key', 'CdcCheck', 'cf.cdc-check.v1', convert_to('$payload', 'UTF8'), '$traceparent');
"@
Invoke-Psql "${svc}_service" $pw "${svc}_db" $sql | Out-Null
if ($LASTEXITCODE -ne 0) { Write-Host 'Insert into outbox failed.' -ForegroundColor Red; exit 1 }
Write-Host "Inserted outbox row id=$eventId key=$key into ${svc}_db as ${svc}_service"

$deadline = (Get-Date).AddSeconds($TimeoutSeconds)
$found = $null
while (-not $found -and (Get-Date) -lt $deadline) {
    $out = Invoke-Compose exec -T kafka /opt/kafka/bin/kafka-console-consumer.sh --bootstrap-server localhost:29092 `
        --topic cf.cdc-check.v1 --from-beginning --timeout-ms 8000 `
        --property print.key=true --property print.headers=true --property key.separator=' | ' 2>$null
    $found = @($out) | Where-Object { $_ -match [regex]::Escape($key) } | Select-Object -Last 1
}
if (-not $found) { Write-Host "No record with key $key arrived on cf.cdc-check.v1 within $TimeoutSeconds s." -ForegroundColor Red; exit 1 }

Write-Host "Kafka record: $found"
$checks = [ordered]@{
    'key = aggregate_id'          = $found -match [regex]::Escape("| $key |")
    'header id = outbox.id'       = $found -match "id:$([regex]::Escape($eventId))"
    'header eventType = CdcCheck' = $found -match 'eventType:CdcCheck'
    'header traceparent copied'   = $found -match [regex]::Escape("traceparent:$traceparent")
    'value = payload bytes'       = $found -match [regex]::Escape($payload)
}
$checks.GetEnumerator() | ForEach-Object { '{0,-30} {1}' -f $_.Key, $(if ($_.Value) { 'ok' } else { 'FAILED' }) } | Write-Host
if ($checks.Values -contains $false) { exit 1 }
Write-Host "CDC verified end to end for $svc-service: outbox -> WAL -> Debezium -> Outbox Event Router -> Kafka." -ForegroundColor Green
