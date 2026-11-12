# PostToolUse: records which components were changed without running their tests.
#
# Write|Edit|MultiEdit on a non-Markdown file under services/<x>/ or apps/<x>/
#   -> adds the component to .claude/hooks/.state/test-debt-<session>.txt
# Bash|PowerShell running a test/build command for a component
#   (gradlew build|test|check, go test, make test|check, npm test, vitest, playwright test)
#   -> removes that component. scripts/{build,test}-service.ps1 <name> clears <name>;
#   scripts/{build,test}-all.ps1 clears everything.
# The Stop hook remind-tests.ps1 reads the file. No output here; always exit 0.

. "$PSScriptRoot/lib/common.ps1"

$payload = Read-HookInput
if (-not $payload) { exit 0 }
$projectDir = Get-ProjectDir $payload
$session = ([string]$payload.session_id) -replace '[^A-Za-z0-9_-]', ''
if (-not $session) { $session = 'default' }
$stateFile = Join-Path (Get-StateDir $projectDir) "test-debt-$session.txt"
$pending = @(if (Test-Path $stateFile) { Get-Content $stateFile | Where-Object { $_ } })

$tool = [string]$payload.tool_name
if ($tool -in @('Write', 'Edit', 'MultiEdit')) {
    $rel = Get-RelativePath ([string]$payload.tool_input.file_path) $projectDir
    $component = Get-Component $rel
    if ($component -and $rel -notmatch '\.md$' -and $pending -notcontains $component) {
        $pending += $component
    }
}
elseif ($tool -in @('Bash', 'PowerShell')) {
    $command = [string]$payload.tool_input.command
    $isTest = $command -match '(gradlew(\.bat)?\s+[^\n;&|]*\b(build|test|check|integrationTest)\b|\bgo\s+test\b|\bmake\s+[^\n;&|]*\b(test|check)\b|\bnpm\s+(run\s+)?test\b|\bnpx\s+(vitest|playwright\s+test)\b|\bvitest\s+run\b)'
    # If the tool response reports a non-zero exit code, the debt stays.
    $resp = $payload.tool_response
    $code = $null
    foreach ($k in @('exitCode', 'exit_code', 'returnCode')) { if ($resp -and $null -ne $resp.$k) { $code = [int]$resp.$k } }
    if ($isTest -and ($null -eq $code -or $code -eq 0)) {
        $targets = @([regex]::Matches($command, '\b(services|apps)/[A-Za-z0-9_-]+') | ForEach-Object { $_.Value })
        if ($targets.Count -eq 0) {
            $cwdRel = Get-RelativePath ([string]$payload.cwd + '/x') $projectDir
            $c = Get-Component $cwdRel
            if ($c) { $targets = @($c) }
        }
        $pending = @($pending | Where-Object { $targets -notcontains $_ })
    }
    # Repository scripts: scripts/{build,test}-service.ps1 <name> and scripts/{build,test}-all.ps1
    if ($null -eq $code -or $code -eq 0) {
        foreach ($m in [regex]::Matches($command, 'scripts[/\\](build|test)-service\.ps1\s+([A-Za-z0-9_-]+)')) {
            $n = $m.Groups[2].Value
            $pending = @($pending | Where-Object { $_ -ne "services/$n" -and $_ -ne "apps/$n" })
        }
        if ($command -match 'scripts[/\\](build|test)-all\.ps1') { $pending = @() }
    }
}

Set-Content -Path $stateFile -Value $pending -Encoding UTF8
exit 0
