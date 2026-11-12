# PreToolUse hook: blocks commands that publish code or configure remotes.
# No remotes have been supplied for CommerceFlow repositories, so Claude must never push
# or add/change a remote. Exit code 2 blocks the tool call and shows stderr to Claude.

$raw = [Console]::In.ReadToEnd()
try {
    $payload = $raw | ConvertFrom-Json
} catch {
    exit 0
}

$command = $payload.tool_input.command
if (-not $command) { exit 0 }

$blocked = @(
    @{ Pattern = '\bgit\b[^;&|]*\bpush\b';                 Reason = 'git push is not allowed: no remotes were supplied.' },
    @{ Pattern = '\bgit\b[^;&|]*\bremote\s+(add|set-url)\b'; Reason = 'Adding or changing git remotes is not allowed: the user configures remotes.' }
)

foreach ($rule in $blocked) {
    if ($command -match $rule.Pattern) {
        [Console]::Error.WriteLine("Blocked by .claude/hooks/guard-git.ps1: $($rule.Reason)")
        exit 2
    }
}

exit 0
