<#
.SYNOPSIS
  Checks every local infrastructure component and prints one table. Exit code 1 if any
  required check fails. Read-only.
.EXAMPLE
  powershell -File infrastructure/scripts/health.ps1
#>
. "$PSScriptRoot/lib/infra.ps1"

if (-not (Test-DockerRunning)) { Write-Host 'Docker is not running.' -ForegroundColor Red; exit 1 }
$rows = New-Object System.Collections.Generic.List[object]
function Add-Row($component, $check, [bool]$ok, $detail) { $rows.Add([pscustomobject]@{ Component = $component; Check = $check; Result = $(if ($ok) { 'ok' } else { 'FAIL' }); Detail = $detail }) }

# Containers
$ps = Invoke-Compose ps --all --format json | ForEach-Object { $_ | ConvertFrom-Json }
foreach ($c in $ps) {
    if ($c.Service -eq 'kafka-init') { Add-Row 'kafka-init' 'topic job' ($c.State -eq 'exited' -and $c.ExitCode -eq 0) "state=$($c.State) exit=$($c.ExitCode)"; continue }
    $ok = $c.State -eq 'running' -and ($c.Health -eq '' -or $c.Health -eq 'healthy')
    Add-Row $c.Service 'container' $ok "state=$($c.State) health=$(if ($c.Health) { $c.Health } else { 'n/a' })"
}

# HTTP endpoints
$http = [ordered]@{
    'schema-registry' = 'http://localhost:8090/subjects'
    'connect'         = 'http://localhost:8093/'
    'kafka-ui'        = 'http://localhost:8095/actuator/health'
    'otel-collector'  = 'http://localhost:13133/'
    'prometheus'      = 'http://localhost:9090/-/ready'
    'grafana'         = 'http://localhost:3000/api/health'
    'loki'            = 'http://localhost:3100/ready'
    'tempo'           = 'http://localhost:3200/ready'
}
foreach ($k in $http.Keys) { $r = Test-Http $http[$k]; Add-Row $k 'http' $r.Ok "$($http[$k]) -> $($r.Status)" }

# PostgreSQL
$superPw = Get-EnvValue 'POSTGRES_SUPERUSER_PASSWORD'
$wal = ((Invoke-Psql 'postgres' $superPw 'postgres' 'SHOW wal_level;') -join '').Trim()
Add-Row 'postgres' 'wal_level' ($wal -eq 'logical') "wal_level=$wal"
$dbs = @(Invoke-Psql 'postgres' $superPw 'postgres' "SELECT datname FROM pg_database WHERE datname LIKE '%\_db' ORDER BY 1;")
$missing = $script:Services | Where-Object { $dbs -notcontains "${_}_db" }
Add-Row 'postgres' 'service databases' ($missing.Count -eq 0) "$($dbs.Count)/8 present$(if ($missing) { '; missing: ' + ($missing -join ',') })"
$roles = @(Invoke-Psql 'postgres' $superPw 'postgres' "SELECT rolname FROM pg_roles WHERE rolname ~ '_(migrator|service|cdc)$';")
Add-Row 'postgres' 'per-service roles' ($roles.Count -eq 23) "$($roles.Count)/23 (8 migrator, 8 service, 7 cdc)"
foreach ($svc in $script:Services) {
    $pw = Get-EnvValue "$($svc.ToUpperInvariant())_DB_SERVICE_PASSWORD"
    $cross = $script:Services | Where-Object { $_ -ne $svc } | Select-Object -First 1
    Invoke-Psql "${svc}_service" $pw "${cross}_db" 'SELECT 1;' *> $null
    if ($LASTEXITCODE -eq 0) { Add-Row 'postgres' "isolation ${svc}_service" $false "can connect to ${cross}_db" }
}
if (-not ($rows | Where-Object { $_.Check -like 'isolation*' })) { Add-Row 'postgres' 'isolation' $true 'no service role can connect to another service database (sampled)' }
$slots = @(Invoke-Psql 'postgres' $superPw 'postgres' "SELECT slot_name || ' active=' || active || ' wal_status=' || coalesce(wal_status,'?') || ' lag=' || pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), confirmed_flush_lsn)) FROM pg_replication_slots ORDER BY 1;")
Add-Row 'postgres' 'replication slots' $true $(if ($slots) { $slots -join '; ' } else { 'none (no connector registered)' })

# Kafka
$topics = @(Invoke-Compose exec -T kafka /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:29092 --list 2>$null)
$declared = @(Get-Content (Join-Path $script:Root 'infrastructure/kafka/topics.csv') | Where-Object { $_ -and -not $_.StartsWith('#') } | ForEach-Object { ($_ -split ',')[0] })
$absent = $declared | Where-Object { $topics -notcontains $_ }
Add-Row 'kafka' 'declared topics' ($absent.Count -eq 0) "$($declared.Count - $absent.Count)/$($declared.Count) present$(if ($absent) { '; missing: ' + ($absent -join ',') })"
$auto = (Invoke-Compose exec -T kafka /opt/kafka/bin/kafka-configs.sh --bootstrap-server localhost:29092 --entity-type brokers --entity-name 1 --describe --all 2>$null) | Where-Object { $_ -match 'auto.create.topics.enable=' } | Select-Object -First 1
Add-Row 'kafka' 'auto topic creation' ($auto -match 'auto.create.topics.enable=false') ($auto -replace '^\s+', '')

# Connect
$connectors = @()
try { $connectors = Invoke-RestMethod -Uri "$($script:ConnectUrl)/connectors" } catch {}
if ($connectors.Count -eq 0) { Add-Row 'connect' 'connectors' $true 'none registered yet (register-connectors.ps1)' }
foreach ($n in $connectors) {
    $s = Invoke-RestMethod -Uri "$($script:ConnectUrl)/connectors/$n/status"
    $ok = $s.connector.state -eq 'RUNNING' -and -not ($s.tasks | Where-Object { $_.state -ne 'RUNNING' })
    Add-Row 'connect' $n $ok "connector=$($s.connector.state) tasks=$(($s.tasks | ForEach-Object { $_.state }) -join ',')"
}

# Redis
$rpw = Get-EnvValue 'MONITORING_REDIS_PASSWORD'
$pong = (Invoke-Compose exec -T redis redis-cli --no-auth-warning --user monitoring --pass $rpw ping 2>$null) -join ''
Add-Row 'redis' 'ping (monitoring user)' ($pong -eq 'PONG') $pong
$denied = (Invoke-Compose exec -T redis redis-cli --no-auth-warning ping 2>$null) -join ''
Add-Row 'redis' 'default user disabled' ($denied -ne 'PONG') $denied

# Prometheus targets
$t = Test-Http 'http://localhost:9090/api/v1/targets?state=active'
if ($t.Ok) {
    $targets = ($t.Body | ConvertFrom-Json).data.activeTargets
    # application jobs (app-*) are only up when the apps profile runs
    $targets = @($targets | Where-Object { $_.labels.job -notlike 'app-*' })
    $down = @($targets | Where-Object { $_.health -ne 'up' } | ForEach-Object { $_.labels.job })
    Add-Row 'prometheus' 'scrape targets' ($down.Count -eq 0) "$(@($targets).Count - $down.Count)/$(@($targets).Count) up$(if ($down) { '; down: ' + ($down -join ',') })"
}

$rows | Format-Table Component, Check, Result, Detail -AutoSize | Out-String -Width 250 | Write-Host
$failed = @($rows | Where-Object { $_.Result -ne 'ok' })
if ($failed.Count -gt 0) { Write-Host "$($failed.Count) check(s) failed." -ForegroundColor Red; exit 1 }
Write-Host 'All infrastructure checks passed.' -ForegroundColor Green
