<#
.SYNOPSIS
  Applies a service's OWN migrations to its OWN database with its migrator role, then runs
  infrastructure/postgres/post-migrate.sql (CDC grant + outbox publication).
  Kotlin services: Flyway CLI over src/main/resources/db/migration (same history table the
  application's Flyway uses). Go services: golang-migrate over migrations/.
.EXAMPLE
  powershell -File infrastructure/scripts/migrate.ps1 -Service product
  powershell -File infrastructure/scripts/migrate.ps1 -All
#>
param([string]$Service, [switch]$All)
. "$PSScriptRoot/lib/infra.ps1"

$targets = if ($All) { $script:Services } elseif ($Service) { @($Service) } else { throw 'Use -Service <name> or -All' }
$network = 'commerceflow_default'
$results = @()

foreach ($svc in $targets) {
    if ($script:Services -notcontains $svc) { throw "Unknown service '$svc'" }
    $upper = $svc.ToUpperInvariant()
    $pw = Get-EnvValue "${upper}_DB_MIGRATOR_PASSWORD"
    $dir = Join-Path $script:Root "services/$svc-service"
    $env:MSYS_NO_PATHCONV = '1'

    if ($script:KotlinServices -contains $svc) {
        $mount = ((Join-Path $dir 'src/main/resources/db/migration') -replace '\\', '/')
        & docker run --rm --network $network -v "${mount}:/flyway/sql:ro" flyway/flyway:10.17.3-alpine `
            "-url=jdbc:postgresql://postgres:5432/${svc}_db" "-user=${svc}_migrator" "-password=$pw" `
            -locations=filesystem:/flyway/sql -connectRetries=10 migrate
    } else {
        $mount = ((Join-Path $dir 'migrations') -replace '\\', '/')
        & docker run --rm --network $network -v "${mount}:/migrations:ro" migrate/migrate:v4.18.1 `
            -path /migrations -database "postgres://${svc}_migrator:${pw}@postgres:5432/${svc}_db?sslmode=disable" up
    }
    $migrated = $LASTEXITCODE -eq 0

    $post = 'skipped (no CDC role)'
    if ($migrated -and $script:Publishers -contains $svc) {
        $sql = Get-Content -Raw (Join-Path $script:Root 'infrastructure/postgres/post-migrate.sql')
        $post = (Invoke-Psql "${svc}_migrator" $pw "${svc}_db" $sql @("cdc=${svc}_cdc", "pub=cf_${svc}_outbox")) -join ' '
        if ($LASTEXITCODE -ne 0) { $post = 'FAILED' }
    }
    $results += [pscustomobject]@{ Service = $svc; Migrations = $(if ($migrated) { 'ok' } else { 'FAILED' }); PostMigrate = $post }
}

$results | Format-Table -AutoSize | Out-String -Width 200 | Write-Host
if ($results | Where-Object { $_.Migrations -ne 'ok' -or $_.PostMigrate -eq 'FAILED' }) { exit 1 }
