# Stop: test execution reminder.
#
# If track-test-debt.ps1 recorded components that were edited after their tests last ran
# in this session, Claude is asked once (stop_hook_active guard) to run those tests or
# state why they cannot run. Never runs tests itself.

. "$PSScriptRoot/lib/common.ps1"

$payload = Read-HookInput
if (-not $payload) { exit 0 }
if ($payload.stop_hook_active -eq $true) { exit 0 }

$projectDir = Get-ProjectDir $payload
$session = ([string]$payload.session_id) -replace '[^A-Za-z0-9_-]', ''
if (-not $session) { $session = 'default' }
$stateFile = Join-Path (Get-StateDir $projectDir) "test-debt-$session.txt"
if (-not (Test-Path $stateFile)) { exit 0 }
$pending = @(Get-Content $stateFile | Where-Object { $_ })
if ($pending.Count -eq 0) { exit 0 }

$hints = foreach ($c in $pending) {
    $dir = Join-Path $projectDir $c
    if (Test-Path (Join-Path $dir 'gradlew')) { "$c -> (cd $c && ./gradlew build)" }
    elseif (Test-Path (Join-Path $dir 'go.mod')) { "$c -> (cd $c && go test -race ./...)" }
    elseif (Test-Path (Join-Path $dir 'package.json')) { "$c -> (cd $c && npm test)" }
    else { "$c -> no build file yet; say that tests cannot run" }
}
Write-StopBlock ("remind-tests: code changed without running tests in: " + ($hints -join '; ') + ". Run them and report the real result, or state explicitly why they were not run.")
