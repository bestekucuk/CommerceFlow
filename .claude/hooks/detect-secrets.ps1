# PreToolUse: accidental secret detection.
#
# Write|Edit|MultiEdit|NotebookEdit - scans the text about to be written; blocks writes to
#   real .env files (only .env.example is allowed).
# Bash|PowerShell running `git commit` - scans added lines of tracked changes
#   (git diff HEAD) and untracked files, so `git add -A && git commit` is covered too.
#
# A line containing the marker `secret-scan:allow` is skipped (use only for documented
# test fixtures). Patterns are deterministic regular expressions; see docs/hook-catalog.md.

. "$PSScriptRoot/lib/common.ps1"

$Patterns = @(
    @{ N = 'private key block';        P = '-----BEGIN (RSA |EC |DSA |OPENSSH |PGP )?PRIVATE KEY( BLOCK)?-----' }
    @{ N = 'AWS access key id';        P = '\b(AKIA|ASIA)[0-9A-Z]{16}\b' }
    @{ N = 'GitHub token';             P = '\b(ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9]{36,}\b|\bgithub_pat_[A-Za-z0-9_]{60,}\b' }
    @{ N = 'Slack token';              P = '\bxox[abprs]-[A-Za-z0-9-]{10,}\b' }
    @{ N = 'Stripe live key';          P = '\b(sk|rk)_live_[A-Za-z0-9]{20,}\b' }
    @{ N = 'Google API key';           P = '\bAIza[0-9A-Za-z_-]{35}\b' }
    @{ N = 'JSON web token';           P = '\beyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\b' }
    @{ N = 'credentials in URL';       P = '\b[a-z][a-z0-9+.-]*://[^\s:/@''"]+:[^\s@''"${}<>]{6,}@[^\s''"]+' }
    # keyword = value, value >= 12 chars containing a digit, not a ${VAR}/{{ }}/<...> reference
    @{ N = 'hard-coded secret value';  P = '(?i)\b[A-Z0-9_]*(password|passwd|secret|api[_-]?key|access[_-]?key|private[_-]?key|client[_-]?secret|auth[_-]?token)\b["'']?\s*[:=]\s*["'']?(?![$%{<(]|changeme|change-me|example|dummy|xxx)(?=[^\s''",;)]*\d)[A-Za-z0-9/+_\-!@#^&*.=]{12,}' }
)

function Find-Secrets([string[]]$lines, [string]$source) {
    $hits = @()
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        if ($line -match 'secret-scan:allow') { continue }
        foreach ($p in $Patterns) {
            if ($line -match $p.P) { $hits += "${source}:$($i + 1): $($p.N)"; break }
        }
    }
    return $hits
}

$payload = Read-HookInput
if (-not $payload) { exit 0 }
$projectDir = Get-ProjectDir $payload
$tool = [string]$payload.tool_name
$findings = @()

if ($tool -in @('Write', 'Edit', 'MultiEdit', 'NotebookEdit')) {
    $path = [string]($payload.tool_input.file_path, $payload.tool_input.notebook_path | Where-Object { $_ } | Select-Object -First 1)
    $rel = Get-RelativePath $path $projectDir
    $name = [System.IO.Path]::GetFileName($path)
    if ($name -match '^\.env(\..+)?$' -and $name -ne '.env.example') {
        Write-PreToolDecision 'deny' "detect-secrets: writing '$name' is blocked. Put variable names in .env.example; real values stay outside the repository."
    }
    $texts = @()
    switch ($tool) {
        'Write'        { $texts += [string]$payload.tool_input.content }
        'Edit'         { $texts += [string]$payload.tool_input.new_string }
        'MultiEdit'    { $texts += @($payload.tool_input.edits | ForEach-Object { [string]$_.new_string }) }
        'NotebookEdit' { $texts += [string]$payload.tool_input.new_source }
    }
    foreach ($t in $texts) { $findings += Find-Secrets ($t -split "`r?`n") ($(if ($rel) { $rel } else { $name })) }
}
elseif ($tool -in @('Bash', 'PowerShell')) {
    $command = [string]$payload.tool_input.command
    if ($command -notmatch '\bgit\s+(?:-C\s+\S+\s+)*commit\b') { exit 0 }
    $diff = & git -C $projectDir diff HEAD --unified=0 --no-color 2>$null
    $file = ''
    foreach ($l in @($diff)) {
        if ($l -match '^\+\+\+ b/(.*)$') { $file = $Matches[1]; continue }
        if ($l -match '^\+(?!\+\+)') { $findings += Find-Secrets @($l.Substring(1)) $file }
    }
    $untracked = & git -C $projectDir ls-files --others --exclude-standard 2>$null
    foreach ($u in @($untracked)) {
        if (-not $u) { continue }
        $full = Join-Path $projectDir $u
        if (-not (Test-Path $full -PathType Leaf)) { continue }
        if ((Get-Item $full).Length -gt 1MB) { continue }
        $name = [System.IO.Path]::GetFileName($u)
        if ($name -match '^\.env(\..+)?$' -and $name -ne '.env.example') { $findings += "${u}: .env file must not be committed"; continue }
        $findings += Find-Secrets @(Get-Content -LiteralPath $full -ErrorAction SilentlyContinue) $u
    }
}

if ($findings.Count -gt 0) {
    $list = ($findings | Select-Object -First 10) -join '; '
    Write-PreToolDecision 'deny' "detect-secrets: possible secret(s) found - $list. Use environment variables or a secrets manager; values must not enter the repository. If this is a documented test fixture, add 'secret-scan:allow' to the line."
}
exit 0
