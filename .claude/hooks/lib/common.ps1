# Shared helpers for CommerceFlow Claude Code hooks (dot-sourced by every hook).
# Compatible with Windows PowerShell 5.1 and PowerShell 7+. No network access, no state
# outside .claude/hooks/.state/.

# 'Continue': in Windows PowerShell 5.1, 'Stop' turns any native stderr line (e.g. git's
# CRLF warnings) into a terminating error. Hooks check $LASTEXITCODE explicitly instead.
$ErrorActionPreference = 'Continue'
# Culture-invariant matching. Under tr-TR (this machine) case-insensitive regex treats 'I'
# as dotless 'ı', so patterns like [A-Z]{16} silently fail on inputs containing 'I'.
[System.Threading.Thread]::CurrentThread.CurrentCulture = [Globalization.CultureInfo]::InvariantCulture
[System.Threading.Thread]::CurrentThread.CurrentUICulture = [Globalization.CultureInfo]::InvariantCulture
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)

function Read-HookInput {
    $stdin = New-Object System.IO.StreamReader([Console]::OpenStandardInput(), [System.Text.Encoding]::UTF8)
    $raw = $stdin.ReadToEnd().TrimStart([char]0xFEFF)   # tolerate a UTF-8 BOM from the caller
    if ([string]::IsNullOrWhiteSpace($raw)) { return $null }
    try { return $raw | ConvertFrom-Json } catch { return $null }
}

function Get-ProjectDir($payload) {
    if ($env:CLAUDE_PROJECT_DIR) { return ($env:CLAUDE_PROJECT_DIR -replace '\\', '/').TrimEnd('/') }
    if ($payload -and $payload.cwd) { return ($payload.cwd -replace '\\', '/').TrimEnd('/') }
    return ((Get-Location).Path -replace '\\', '/').TrimEnd('/')
}

# Repo-relative path with forward slashes, or $null when the path is outside the project.
function Get-RelativePath([string]$path, [string]$projectDir) {
    if (-not $path) { return $null }
    $p = $path -replace '\\', '/'
    # Git Bash style /c/Users/... -> C:/Users/...
    if ($p -match '^/([a-zA-Z])/(.*)$') { $p = "$($Matches[1]):/$($Matches[2])" }
    if ($p.StartsWith($projectDir + '/', [System.StringComparison]::OrdinalIgnoreCase)) {
        return $p.Substring($projectDir.Length + 1)
    }
    if (-not [System.IO.Path]::IsPathRooted($path)) { return $p.TrimStart('./') }
    return $null
}

# Component that owns a repo-relative path: services/<name>, apps/<name>, or $null.
function Get-Component([string]$relPath) {
    if ($relPath -match '^(services|apps)/([^/]+)/') { return "$($Matches[1])/$($Matches[2])" }
    return $null
}

# PreToolUse decision: allow | ask | deny. Printed as JSON on stdout, exit 0.
function Write-PreToolDecision([string]$decision, [string]$reason) {
    $out = @{ hookSpecificOutput = @{ hookEventName = 'PreToolUse'; permissionDecision = $decision; permissionDecisionReason = $reason } }
    [Console]::Out.Write(($out | ConvertTo-Json -Compress -Depth 5))
    exit 0
}

# Feedback to Claude after a tool ran (PostToolUse): stderr + exit 2.
function Write-Feedback([string]$message) {
    [Console]::Error.WriteLine($message)
    exit 2
}

# Stop-hook block: Claude must continue and address the reason. Only once per stop cycle.
function Write-StopBlock([string]$reason) {
    $out = @{ decision = 'block'; reason = $reason }
    [Console]::Out.Write(($out | ConvertTo-Json -Compress -Depth 5))
    exit 0
}

function Get-StateDir([string]$projectDir) {
    $dir = Join-Path $projectDir '.claude/hooks/.state'
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    return $dir
}

# Changed paths in the working tree (staged, unstaged, untracked), repo-relative.
function Get-ChangedPaths([string]$projectDir) {
    $lines = & git -C $projectDir status --porcelain=v1 --untracked-files=all 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $lines) { return @() }
    $paths = foreach ($l in $lines) {
        $p = $l.Substring(3)
        if ($p -match ' -> ') { $p = ($p -split ' -> ')[1] }
        $p.Trim('"')
    }
    return @($paths)
}
