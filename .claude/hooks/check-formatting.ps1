# PostToolUse (Write|Edit|MultiEdit): formatting validation of the file just written.
#
# Always: final newline, no trailing whitespace (except Markdown), no tabs in YAML,
#         valid JSON, no merge-conflict markers.
# Claude config: SKILL.md and agent files must start with frontmatter whose `name`
#         matches the directory/file name.
# Tool-based (only if the formatter is installed; skipped silently otherwise):
#         gofmt for .go, ktlint for .kt/.kts, the app's own prettier for .ts/.tsx/.css.
# Problems are reported to Claude (exit 2) so it fixes them; nothing is auto-rewritten.

. "$PSScriptRoot/lib/common.ps1"

$payload = Read-HookInput
if (-not $payload) { exit 0 }
$projectDir = Get-ProjectDir $payload
$path = [string]$payload.tool_input.file_path
$rel = Get-RelativePath $path $projectDir
if (-not $rel -or -not (Test-Path -LiteralPath $path -PathType Leaf)) { exit 0 }
if ((Get-Item -LiteralPath $path).Length -gt 2MB) { exit 0 }

$ext = [System.IO.Path]::GetExtension($path).ToLowerInvariant()
$binary = @('.png', '.jpg', '.jpeg', '.gif', '.ico', '.jar', '.zip', '.pdf', '.woff', '.woff2')
if ($binary -contains $ext) { exit 0 }

$text = [System.IO.File]::ReadAllText($path)
$lines = $text -split "`n"
$issues = @()

if ($text.Length -gt 0 -and -not $text.EndsWith("`n")) { $issues += 'missing final newline' }
if ($text -match '(?m)^(<<<<<<<|>>>>>>>) ') { $issues += 'merge conflict markers' }

if ($ext -ne '.md') {
    $trailing = @()
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '[ \t]+\r?$') { $trailing += ($i + 1) }
    }
    if ($trailing.Count -gt 0) { $issues += "trailing whitespace on line(s) $(($trailing | Select-Object -First 10) -join ', ')" }
}

if ($ext -in @('.yml', '.yaml')) {
    $tabs = @(); for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i] -match '^\s*\t') { $tabs += ($i + 1) } }
    if ($tabs.Count -gt 0) { $issues += "tab indentation in YAML on line(s) $(($tabs | Select-Object -First 10) -join ', ')" }
}

if ($ext -eq '.json') {
    try { $null = $text | ConvertFrom-Json } catch { $issues += "invalid JSON: $($_.Exception.Message.Split("`n")[0])" }
}

# Claude Code configuration files
$expectedName = $null
if ($rel -match '^\.claude/skills/([^/]+)/SKILL\.md$') { $expectedName = $Matches[1] }
elseif ($rel -match '^\.claude/agents/([^/]+)\.md$') { $expectedName = $Matches[1] }
if ($expectedName) {
    if ($lines[0].TrimEnd("`r") -ne '---') { $issues += 'frontmatter must start on line 1 with ---' }
    else {
        $end = -1; for ($i = 1; $i -lt $lines.Count; $i++) { if ($lines[$i].TrimEnd("`r") -eq '---') { $end = $i; break } }
        if ($end -lt 0) { $issues += 'frontmatter is not closed with ---' }
        else {
            $fm = $lines[1..($end - 1)] | ForEach-Object { $_.TrimEnd("`r") }
            $name = ($fm | Where-Object { $_ -match '^name:\s*' } | Select-Object -First 1) -replace '^name:\s*', ''
            if ($name -ne $expectedName) { $issues += "frontmatter name '$name' must equal '$expectedName'" }
            if (-not ($fm | Where-Object { $_ -match '^description:\s*\S' })) { $issues += 'frontmatter needs a description' }
        }
    }
}

# Optional formatters (deterministic, only when installed)
function Test-Tool([string]$name) { return [bool](Get-Command $name -ErrorAction SilentlyContinue) }
if ($ext -eq '.go' -and (Test-Tool 'gofmt')) {
    $out = & gofmt -l $path 2>&1
    if ($out) { $issues += 'not gofmt-formatted (run: gofmt -w <file>)' }
}
if ($ext -in @('.kt', '.kts') -and (Test-Tool 'ktlint')) {
    $out = & ktlint --relative $path 2>&1
    if ($LASTEXITCODE -ne 0) { $issues += "ktlint: $(($out | Select-Object -First 5) -join ' | ')" }
}
if ($ext -in @('.ts', '.tsx', '.css') -and $rel -match '^apps/([^/]+)/') {
    $prettier = Join-Path $projectDir "apps/$($Matches[1])/node_modules/.bin/prettier.cmd"
    if (-not (Test-Path $prettier)) { $prettier = Join-Path $projectDir "apps/$($Matches[1])/node_modules/.bin/prettier" }
    if (Test-Path $prettier) {
        & $prettier --check $path *> $null
        if ($LASTEXITCODE -ne 0) { $issues += 'not prettier-formatted (run the app formatter)' }
    }
}

if ($issues.Count -gt 0) {
    Write-Feedback "check-formatting: $rel - $($issues -join '; '). Fix the file (no auto-rewrite is done)."
}
exit 0
