<#
.SYNOPSIS
  Starts the local CommerceFlow infrastructure and waits until health checks pass.
  Creates .env from .env.example on first use (local-only credentials).
.EXAMPLE
  powershell -File infrastructure/scripts/up.ps1
#>
param([int]$TimeoutSeconds = 300)
. "$PSScriptRoot/lib/infra.ps1"

if (-not (Test-DockerRunning)) { Write-Host 'Docker is not running. Start Docker Desktop and retry.' -ForegroundColor Red; exit 1 }

$envFile = Join-Path $script:Root '.env'
if (-not (Test-Path $envFile)) {
    Copy-Item (Join-Path $script:Root '.env.example') $envFile
    Write-Host 'Created .env from .env.example (local-only credentials; .env is gitignored).' -ForegroundColor Yellow
}

Invoke-Compose up -d --wait --wait-timeout $TimeoutSeconds
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Some containers did not become healthy. Inspect with: docker compose ps; docker compose logs <service>' -ForegroundColor Red
    exit 1
}
Invoke-Compose ps --format 'table {{.Service}}\t{{.State}}\t{{.Health}}'
Write-Host ''
Write-Host 'Next: powershell -File infrastructure/scripts/health.ps1' -ForegroundColor Green
