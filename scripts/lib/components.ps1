# Shared helpers for the per-component build and test scripts.
# Each component is built with its OWN tooling from its OWN folder; nothing is compiled
# together. Go runs in the golang Docker image when Go is not installed locally.

$ErrorActionPreference = 'Continue'
[System.Threading.Thread]::CurrentThread.CurrentCulture = [Globalization.CultureInfo]::InvariantCulture

$script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$script:GoImage = 'golang:1.23'
$script:IsWin = [System.Environment]::OSVersion.Platform -eq 'Win32NT'

function Get-ComponentNames {
    $names = @()
    foreach ($top in 'services', 'apps') {
        $dir = Join-Path $script:RepoRoot $top
        if (Test-Path $dir) { $names += Get-ChildItem -Directory $dir | ForEach-Object { $_.Name } }
    }
    return $names | Sort-Object
}

function Resolve-Component([string]$name) {
    foreach ($top in 'services', 'apps') {
        $dir = Join-Path $script:RepoRoot "$top/$name"
        if (Test-Path $dir) {
            $type = if (Test-Path "$dir/build.gradle.kts") { 'kotlin' }
                    elseif (Test-Path "$dir/go.mod") { 'go' }
                    elseif (Test-Path "$dir/package.json") { 'web' }
                    else { 'none' }
            return [pscustomobject]@{ Name = $name; Path = $dir; Rel = "$top/$name"; Type = $type }
        }
    }
    throw "Unknown component '$name'. Known: $((Get-ComponentNames) -join ', ')"
}

function Install-NodeModules {
    if (Test-Path package-lock.json) { & npm ci --no-audit --no-fund } else { & npm install --no-audit --no-fund }
}

function Invoke-Go([pscustomobject]$c, [string]$command) {
    if (Get-Command go -ErrorAction SilentlyContinue) {
        Push-Location $c.Path; try { & sh -c $command } finally { Pop-Location }
        return
    }
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) { Write-Host 'Neither Go nor Docker is available.'; $global:LASTEXITCODE = 127; return }
    # Testcontainers inside the container talks to the host Docker engine.
    $mount = ($c.Path -replace '\\', '/')
    $dockerArgs = @('run', '--rm', '-v', "${mount}:/src", '-w', '/src',
        '-v', 'commerceflow-go-mod:/go/pkg/mod', '-v', 'commerceflow-go-build:/root/.cache/go-build',
        '-v', '/var/run/docker.sock:/var/run/docker.sock',
        '-e', 'TESTCONTAINERS_HOST_OVERRIDE=host.docker.internal',
        '--add-host', 'host.docker.internal:host-gateway',
        $script:GoImage, 'sh', '-c', $command)
    $env:MSYS_NO_PATHCONV = '1'
    & docker @dockerArgs
}

function Invoke-ComponentBuild([pscustomobject]$c) {
    switch ($c.Type) {
        'kotlin' {
            Push-Location $c.Path
            try { if ($script:IsWin) { & .\gradlew.bat --no-daemon build } else { & ./gradlew --no-daemon build } } finally { Pop-Location }
        }
        # No embedded double quotes: Windows PowerShell 5.1 mangles them when passing args to docker.
        'go' { Invoke-Go $c 'go vet ./... && gofmt -l . | (! grep .) && go test -count=1 ./... && CGO_ENABLED=0 go build -o bin/ ./cmd/...' }
        'web' {
            Push-Location $c.Path
            # npm ci needs the committed lockfile; the very first install creates it.
            try { Install-NodeModules; if ($LASTEXITCODE -eq 0) { & npm run build } } finally { Pop-Location }
        }
        default { Write-Host "$($c.Rel) has no build file yet."; $global:LASTEXITCODE = 1 }
    }
}

function Invoke-ComponentTest([pscustomobject]$c, [switch]$Integration) {
    switch ($c.Type) {
        'kotlin' {
            $tasks = @('test') + $(if ($Integration) { @('integrationTest') } else { @() })
            Push-Location $c.Path
            try { if ($script:IsWin) { & .\gradlew.bat --no-daemon @tasks } else { & ./gradlew --no-daemon @tasks } } finally { Pop-Location }
        }
        'go' {
            $cmd = 'go test -count=1 ./...'
            if ($Integration) { $cmd += ' && go test -tags=integration -count=1 ./tests/...' }
            Invoke-Go $c $cmd
        }
        'web' {
            Push-Location $c.Path
            try {
                if (-not (Test-Path node_modules)) { Install-NodeModules }
                & npm run typecheck; if ($LASTEXITCODE -eq 0) { & npm test }
                if ($LASTEXITCODE -eq 0 -and $Integration) { & npm run test:e2e }
            } finally { Pop-Location }
        }
        default { Write-Host "$($c.Rel) has no tests yet."; $global:LASTEXITCODE = 1 }
    }
}

function Invoke-ComponentImage([pscustomobject]$c, [string]$Tag = 'dev') {
    $image = "commerceflow/$($c.Name):$Tag"
    & docker build --build-context "contracts=$($script:RepoRoot)/contracts" -t $image $c.Path
    if ($LASTEXITCODE -eq 0) { Write-Host "    image $image" }
}

function Write-Summary($results) {
    Write-Host ''
    $results | Format-Table Component, Step, Result, Seconds -AutoSize | Out-String -Width 160 | Write-Host
    $failed = @($results | Where-Object { $_.Result -ne 'ok' })
    if ($failed.Count -gt 0) { Write-Host "$($failed.Count) step(s) failed." -ForegroundColor Red; exit 1 }
    Write-Host 'All steps succeeded.' -ForegroundColor Green
    exit 0
}
