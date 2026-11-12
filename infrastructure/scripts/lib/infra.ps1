# Shared helpers for the local infrastructure scripts. Windows PowerShell 5.1+ / pwsh.
# Values are passed to containers through stdin or -e flags, never through files.

$ErrorActionPreference = 'Continue'
[System.Threading.Thread]::CurrentThread.CurrentCulture = [Globalization.CultureInfo]::InvariantCulture

$script:Root = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$script:Services = 'product', 'order', 'inventory', 'payment', 'customer', 'pricing', 'shipping', 'notification'
$script:Publishers = 'product', 'order', 'inventory', 'payment', 'customer', 'pricing', 'shipping'
$script:KotlinServices = 'product', 'order', 'payment', 'customer', 'pricing'
$script:ConnectUrl = 'http://localhost:8093'

function Get-DotEnv {
    $file = Join-Path $script:Root '.env'
    if (-not (Test-Path $file)) { throw ".env not found. Run infrastructure/scripts/up.ps1 (it creates .env from .env.example)." }
    $values = @{}
    foreach ($line in Get-Content $file) {
        if ($line -match '^\s*([A-Z0-9_]+)\s*=\s*(.*)\s*$') { $values[$Matches[1]] = $Matches[2] }
    }
    return $values
}

function Get-EnvValue([string]$name) {
    $v = (Get-DotEnv)[$name]
    if ([string]::IsNullOrEmpty($v)) { throw "$name is not set in .env" }
    return $v
}

function Invoke-Compose {
    Push-Location $script:Root
    try { & docker compose @args } finally { Pop-Location }
}

# Runs SQL (from a string, via stdin) inside the postgres container as the given role.
function Invoke-Psql([string]$user, [string]$password, [string]$database, [string]$sql, [string[]]$vars = @()) {
    $psqlArgs = @('compose', 'exec', '-T', '-e', "PGPASSWORD=$password", 'postgres',
                  'psql', '-X', '-q', '-t', '-A', '-v', 'ON_ERROR_STOP=1', '-h', 'localhost', '-U', $user, '-d', $database)
    foreach ($v in $vars) { $psqlArgs += @('-v', $v) }
    Push-Location $script:Root
    try { $sql | & docker @psqlArgs } finally { Pop-Location }
}

function Test-Http([string]$url, [int]$timeoutSec = 5) {
    try {
        $r = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec $timeoutSec
        return [pscustomobject]@{ Ok = ($r.StatusCode -ge 200 -and $r.StatusCode -lt 300); Status = $r.StatusCode; Body = $r.Content }
    } catch {
        $code = if ($_.Exception.Response) { [int]$_.Exception.Response.StatusCode } else { 0 }
        return [pscustomobject]@{ Ok = $false; Status = $code; Body = $_.Exception.Message }
    }
}

function Test-DockerRunning {
    & docker info --format '{{.ServerVersion}}' *> $null
    return $LASTEXITCODE -eq 0
}
