# PreToolUse (Bash|PowerShell): destructive command protection.
#
# deny - never run by Claude: publishing (push, PR merge), deployments, remote changes,
#        destructive migrations, destructive SQL.
# ask  - local but irreversible: recursive deletes, hard resets, volume removal. The user
#        decides in the permission prompt.
# Rules are evaluated in order; the first match wins. See docs/hook-catalog.md.

. "$PSScriptRoot/lib/common.ps1"

$payload = Read-HookInput
$command = if ($payload) { [string]$payload.tool_input.command } else { '' }
if ([string]::IsNullOrWhiteSpace($command)) { exit 0 }

$git = '\bgit\s+(?:-C\s+\S+\s+|-c\s+\S+\s+)*'

$rules = @(
    # --- deny: publishing and remotes
    @{ D = 'deny'; P = "${git}push\b";                         R = 'git push is not allowed: CommerceFlow has no remote and Claude never publishes code.' }
    @{ D = 'deny'; P = "${git}remote\s+(add|set-url|remove|rm)\b"; R = 'Changing git remotes is reserved for the user.' }
    @{ D = 'deny'; P = '\bgh\s+pr\s+merge\b';                  R = 'Merging pull requests is reserved for the user.' }
    @{ D = 'deny'; P = '\bgh\s+api\b[^\n]*/merge\b';           R = 'Merging pull requests is reserved for the user.' }
    # --- deny: deployments
    @{ D = 'deny'; P = '\bkubectl\s+(apply|create|delete|replace|patch|scale|rollout\s+restart|drain)\b'; R = 'Changing a Kubernetes cluster is a deployment; reserved for the user/CI.' }
    @{ D = 'deny'; P = '\bhelm\s+(install|upgrade|uninstall|delete|rollback)\b'; R = 'Helm releases are deployments; reserved for the user/CI.' }
    @{ D = 'deny'; P = '\bterraform\s+(apply|destroy|import|state\s+(rm|mv|push))\b'; R = 'Terraform changes real infrastructure; only fmt/validate/plan are allowed.' }
    @{ D = 'deny'; P = '\bdocker\s+(image\s+)?push\b';         R = 'Pushing images is a release step; reserved for CI.' }
    @{ D = 'deny'; P = '\bgh\s+(workflow\s+run|release\s+create)\b'; R = 'Triggering workflows or releases is reserved for the user.' }
    # --- deny: destructive migrations
    @{ D = 'deny'; P = '\bflyway\b[^\n;&|]*\b(clean|repair|undo)\b'; R = 'Destructive Flyway commands (clean/repair/undo) are never run automatically.' }
    @{ D = 'deny'; P = '\bgradlew(\.bat)?\b[^\n;&|]*\bflyway(Clean|Repair|Undo)\b'; R = 'Destructive Flyway tasks are never run automatically.' }
    @{ D = 'deny'; P = '\bmigrate\b[^\n;&|]*\s(down|drop|force)\b'; R = 'golang-migrate down/drop/force are never run automatically.' }
    # --- deny: destructive SQL through a client
    @{ D = 'deny'; P = '(?is)\b(psql|pgcli|sqlcmd|mysql)\b.*\b(drop\s+(database|schema|table|role|publication)|truncate\b)'; R = 'Destructive SQL (DROP/TRUNCATE) is never run automatically.' }
    @{ D = 'deny'; P = '(?is)\b(psql|pgcli)\b.*\bdelete\s+from\s+[\w."]+\s*(;|"|''|$)'; R = 'DELETE without WHERE is never run automatically.' }
    @{ D = 'deny'; P = '(?i)\bpg_drop_replication_slot\b';    R = 'Dropping a replication slot loses CDC position; reserved for the user (see debezium-cdc runbook).' }
    # --- ask: local, irreversible
    @{ D = 'ask'; P = '\brm\s+(-[a-zA-Z]*[rRf][a-zA-Z]*\s+)+';  R = 'Recursive/forced delete. Confirm the target is correct.' }
    @{ D = 'ask'; P = '(?i)\b(Remove-Item|rm|del|rd|rmdir)\b[^\n;|]*\s-(Recurse|r)\b'; R = 'Recursive delete. Confirm the target is correct.' }
    @{ D = 'ask'; P = "${git}(reset\s+--hard|clean\s+-[a-zA-Z]*f|checkout\s+--\s|restore\s+(--staged\s+|--worktree\s+)*\.(\s|$)|branch\s+-D|stash\s+(drop|clear)|filter-branch|filter-repo|update-ref\s+-d)"; R = 'This git command discards work or history. Confirm before running.' }
    @{ D = 'ask'; P = "${git}(rebase|commit\s+--amend)\b";      R = 'Rewrites history. Confirm before running.' }
    @{ D = 'ask'; P = '\bdocker\s+(compose\s+[^\n;|]*down\b[^\n;|]*\s(-v|--volumes)\b|volume\s+(rm|prune)|system\s+prune|container\s+prune)'; R = 'Removes Docker volumes or data. Confirm before running.' }
)

foreach ($rule in $rules) {
    if ($command -match $rule.P) {
        Write-PreToolDecision $rule.D "guard-destructive-commands: $($rule.R)"
    }
}
exit 0
