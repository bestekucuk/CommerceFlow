# Deterministic test suite for the CommerceFlow Claude Code hooks.
# Run from anywhere:  powershell -NoProfile -ExecutionPolicy Bypass -File .claude/hooks/tests/Test-Hooks.ps1
# Creates temporary git repositories under $env:TEMP and removes them afterwards.
# Fake secrets are assembled at runtime so this file never contains one literally.

$ErrorActionPreference = 'Continue'   # git/native stderr must not abort the suite in PowerShell 5.1
$OutputEncoding = New-Object System.Text.UTF8Encoding($false)   # UTF-8 without BOM, like Claude Code
$hooks = Resolve-Path (Join-Path $PSScriptRoot '..')
$repoRoot = Resolve-Path (Join-Path $hooks '../..')
$script:failures = 0
$script:passed = 0

function Invoke-Hook([string]$name, $payload, [string]$projectDir) {
    $env:CLAUDE_PROJECT_DIR = $projectDir
    $json = $payload | ConvertTo-Json -Compress -Depth 6
    $errFile = [System.IO.Path]::GetTempFileName()
    $out = $json | powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $hooks $name) 2> $errFile
    $code = $LASTEXITCODE
    $err = Get-Content $errFile -Raw; Remove-Item $errFile
    $decision = $null
    if ($out) { try { $o = ($out -join '') | ConvertFrom-Json; $decision = if ($o.hookSpecificOutput) { $o.hookSpecificOutput.permissionDecision } elseif ($o.decision) { $o.decision } } catch {} }
    return [pscustomobject]@{ Code = $code; Out = ($out -join ''); Err = $err; Decision = $decision }
}

function Assert([string]$label, [bool]$ok, $result) {
    if ($ok) { $script:passed++; Write-Host "  ok   $label" }
    else { $script:failures++; Write-Host "  FAIL $label  (code=$($result.Code) decision=$($result.Decision) out=$($result.Out) err=$($result.Err))" -ForegroundColor Red }
}

function New-TempRepo {
    $dir = Join-Path $env:TEMP ("cf-hooktest-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Path $dir | Out-Null
    & git -C $dir init -q -b main
    & git -C $dir config user.email 'hooktest@example.invalid'
    & git -C $dir config user.name 'hooktest'
    return ($dir -replace '\\', '/')
}
function Write-File([string]$root, [string]$rel, [string]$content) {
    $p = Join-Path $root $rel
    New-Item -ItemType Directory -Path (Split-Path $p) -Force | Out-Null
    [System.IO.File]::WriteAllText($p, $content)
    return ($p -replace '\\', '/')
}

$root = ($repoRoot.Path -replace '\\', '/')

# ---------------------------------------------------------------- guard-destructive-commands
Write-Host 'guard-destructive-commands.ps1'
$cases = @(
    @('git push origin main', 'deny'), @('git -C services/x push', 'deny'), @('git remote add origin https://x', 'deny'),
    @('git remote set-url origin y', 'deny'), @('gh pr merge 12 --squash', 'deny'), @('kubectl apply -f deploy.yaml', 'deny'),
    @('helm upgrade --install order-service chart', 'deny'), @('terraform apply -auto-approve', 'deny'), @('terraform destroy', 'deny'),
    @('docker push commerceflow/order-service:1', 'deny'), @('cd services/order-service && ./gradlew flywayClean', 'deny'),
    @('flyway -url=jdbc:x clean', 'deny'), @('migrate -path migrations -database pgx5://x down 1', 'deny'),
    @('psql -c "DROP TABLE outbox"', 'deny'), @('psql order_db -c "TRUNCATE inbox"', 'deny'), @('psql -c "DELETE FROM inbox;"', 'deny'),
    @("psql -c `"SELECT pg_drop_replication_slot('cf_order_slot')`"", 'deny'),
    @('psql -c "DROP TABLE INVENTORY_ITEM"', 'deny'), @('PSQL -C "TRUNCATE INBOX"', 'deny'),   # Turkish-I regression
    @('rm -rf build', 'ask'), @('Remove-Item -Recurse -Force .\build', 'ask'), @('git reset --hard HEAD~1', 'ask'), @('git clean -fdx', 'ask'),
    @('git commit --amend --no-edit', 'ask'), @('git branch -D feature/x', 'ask'), @('docker compose down -v', 'ask'), @('docker volume prune -f', 'ask'),
    @('git status', $null), @('git log --grep push', $null), @('git commit -m "docs: no push here"', $null), @('./gradlew build', $null),
    @('terraform plan', $null), @('docker compose down', $null), @('psql -c "DELETE FROM inbox WHERE received_at < now()"', $null),
    @('helm lint infrastructure/kubernetes/helm/service', $null), @('kubectl get pods', $null)
)
foreach ($c in $cases) {
    $r = Invoke-Hook 'guard-destructive-commands.ps1' @{ tool_name = 'Bash'; tool_input = @{ command = $c[0] } } $root
    Assert ("{0,-5} {1}" -f ($(if ($c[1]) { $c[1] } else { 'allow' })), $c[0]) ($r.Code -eq 0 -and $r.Decision -eq $c[1]) $r
}

# ---------------------------------------------------------------- detect-secrets (writes)
Write-Host 'detect-secrets.ps1 (writes)'
$aws = 'AKIA' + 'ABCDEFGHIJKLMNOP'
$pem = '-----BEGIN ' + 'RSA PRIVATE KEY-----'
$gh = 'ghp_' + ('a1B2c3D4e5' * 4)
$jwt = 'eyJ' + 'hbGciOiJIUzI1NiJ9' + '.eyJ' + 'zdWIiOiIxMjM0NTY3ODkwIn0' + '.' + 'dozjgNryP4J3jVmNHl0w5N_XgL0n3I9PlFUP0THsR8U'
$pw = 'pass' + 'word: Sup3rS3cretValue!'
$writeCases = @(
    @("aws_key = $aws", 'deny'), @($pem, 'deny'), @("token=$gh", 'deny'), @("Authorization: Bearer $jwt", 'deny'), @($pw, 'deny'),
    @(('postgres://order:' + 'Pa55word123@db:5432/order_db'), 'deny'),
    @('password: ${DB_PASSWORD}', $null), @("CREATE ROLE order_cdc PASSWORD :'order_cdc_password';", $null),
    @('DB_PASSWORD: ${ORDER_DB_PASSWORD:?set in .env}', $null), @("$pw  # secret-scan:allow", $null), @('withPassword("test")', $null)
)
foreach ($c in $writeCases) {
    $r = Invoke-Hook 'detect-secrets.ps1' @{ tool_name = 'Write'; tool_input = @{ file_path = "$root/services/order-service/x.yml"; content = $c[0] } } $root
    Assert ("{0,-5} write: {1}" -f ($(if ($c[1]) { $c[1] } else { 'allow' })), ($c[0].Substring(0, [Math]::Min(40, $c[0].Length)))) ($r.Code -eq 0 -and $r.Decision -eq $c[1]) $r
}
$r = Invoke-Hook 'detect-secrets.ps1' @{ tool_name = 'Edit'; tool_input = @{ file_path = "$root/a.kt"; old_string = 'x'; new_string = "val t = `"$gh`"" } } $root
Assert 'deny  edit with token' ($r.Decision -eq 'deny') $r
$r = Invoke-Hook 'detect-secrets.ps1' @{ tool_name = 'MultiEdit'; tool_input = @{ file_path = "$root/a.kt"; edits = @(@{ old_string = 'a'; new_string = 'ok' }, @{ old_string = 'b'; new_string = $pem }) } } $root
Assert 'deny  multiedit with private key' ($r.Decision -eq 'deny') $r
$r = Invoke-Hook 'detect-secrets.ps1' @{ tool_name = 'Write'; tool_input = @{ file_path = "$root/services/order-service/.env"; content = 'A=1' } } $root
Assert 'deny  write .env' ($r.Decision -eq 'deny') $r
$r = Invoke-Hook 'detect-secrets.ps1' @{ tool_name = 'Write'; tool_input = @{ file_path = "$root/services/order-service/.env.example"; content = "DB_PASSWORD=`n" } } $root
Assert 'allow write .env.example' ($r.Code -eq 0 -and -not $r.Decision) $r

# ---------------------------------------------------------------- detect-secrets (git commit)
Write-Host 'detect-secrets.ps1 (git commit)'
$t = New-TempRepo
Write-File $t 'README.md' "hello`n" | Out-Null
& git -C $t add -A; & git -C $t commit -q -m init
$r = Invoke-Hook 'detect-secrets.ps1' @{ tool_name = 'Bash'; tool_input = @{ command = 'git commit -m clean' } } $t
Assert 'allow commit without secrets' ($r.Code -eq 0 -and -not $r.Decision) $r
Write-File $t 'cfg/app.yml' "api_key: $('9f8e7d6c5b4a' + '3210ffee')`n" | Out-Null
$r = Invoke-Hook 'detect-secrets.ps1' @{ tool_name = 'Bash'; tool_input = @{ command = 'git add -A && git commit -m x' } } $t
Assert 'deny  commit with untracked secret' ($r.Decision -eq 'deny') $r
Remove-Item (Join-Path $t 'cfg') -Recurse -Force
Add-Content (Join-Path $t 'README.md') $aws
$r = Invoke-Hook 'detect-secrets.ps1' @{ tool_name = 'Bash'; tool_input = @{ command = 'git -C . commit -am x' } } $t
Assert 'deny  commit with secret in tracked change' ($r.Decision -eq 'deny') $r
Remove-Item $t -Recurse -Force

# ---------------------------------------------------------------- check-formatting
Write-Host 'check-formatting.ps1'
$t = New-TempRepo
$fmt = @(
    @('a.json', "{`"a`": 1}`n", 0), @('b.json', "{`"a`": }`n", 2), @('c.yaml', "a:`n`tb: 1`n", 2), @('d.kt', "val a = 1", 2),
    @('e.kt', "val a = 1   `n", 2), @('f.md', "line with break  `n", 0), @('g.kt', "val a = 1`n", 0),
    @('.claude/skills/demo/SKILL.md', "---`nname: demo`ndescription: Demo skill for tests.`n---`n# x`n", 0),
    @('.claude/skills/demo2/SKILL.md', "---`nname: other`ndescription: Wrong name.`n---`n", 2),
    @('.claude/agents/bot.md', "# no frontmatter`n", 2), @('h.txt', "<<<<<<< HEAD`nx`n", 2)
)
foreach ($c in $fmt) {
    $p = Write-File $t $c[0] $c[1]
    $r = Invoke-Hook 'check-formatting.ps1' @{ tool_name = 'Write'; tool_input = @{ file_path = $p } } $t
    Assert ("exit {0} {1}" -f $c[2], $c[0]) ($r.Code -eq $c[2]) $r
}
Remove-Item $t -Recurse -Force

# ---------------------------------------------------------------- track-test-debt + remind-tests
Write-Host 'track-test-debt.ps1 / remind-tests.ps1'
$t = New-TempRepo
$sid = 'test-session'
$kt = Write-File $t 'services/order-service/src/main/kotlin/A.kt' "class A`n"
Write-File $t 'services/order-service/gradlew' "#!/bin/sh`n" | Out-Null
Invoke-Hook 'track-test-debt.ps1' @{ session_id = $sid; tool_name = 'Edit'; tool_input = @{ file_path = $kt } } $t | Out-Null
$r = Invoke-Hook 'remind-tests.ps1' @{ session_id = $sid; stop_hook_active = $false } $t
Assert 'block stop after untested edit' ($r.Decision -eq 'block' -and $r.Out -match 'services/order-service') $r
$r = Invoke-Hook 'remind-tests.ps1' @{ session_id = $sid; stop_hook_active = $true } $t
Assert 'no block when stop_hook_active' ($r.Code -eq 0 -and -not $r.Decision) $r
Invoke-Hook 'track-test-debt.ps1' @{ session_id = $sid; tool_name = 'Bash'; tool_input = @{ command = 'npm test' }; cwd = $t } $t | Out-Null
$r = Invoke-Hook 'remind-tests.ps1' @{ session_id = $sid; stop_hook_active = $false } $t
Assert 'unrelated test command keeps debt' ($r.Decision -eq 'block') $r
Invoke-Hook 'track-test-debt.ps1' @{ session_id = $sid; tool_name = 'Bash'; tool_input = @{ command = 'cd services/order-service && ./gradlew build' }; tool_response = @{ exitCode = 1 } } $t | Out-Null
$r = Invoke-Hook 'remind-tests.ps1' @{ session_id = $sid; stop_hook_active = $false } $t
Assert 'failed test run keeps debt' ($r.Decision -eq 'block') $r
Invoke-Hook 'track-test-debt.ps1' @{ session_id = $sid; tool_name = 'Bash'; tool_input = @{ command = 'cd services/order-service && ./gradlew build' } } $t | Out-Null
$r = Invoke-Hook 'remind-tests.ps1' @{ session_id = $sid; stop_hook_active = $false } $t
Assert 'test run clears debt' ($r.Code -eq 0 -and -not $r.Decision) $r
$md = Write-File $t 'services/order-service/README.md' "x`n"
Invoke-Hook 'track-test-debt.ps1' @{ session_id = $sid; tool_name = 'Write'; tool_input = @{ file_path = $md } } $t | Out-Null
$r = Invoke-Hook 'remind-tests.ps1' @{ session_id = $sid; stop_hook_active = $false } $t
Assert 'markdown edit creates no debt' ($r.Code -eq 0 -and -not $r.Decision) $r
Invoke-Hook 'track-test-debt.ps1' @{ session_id = $sid; tool_name = 'Edit'; tool_input = @{ file_path = $kt } } $t | Out-Null
Invoke-Hook 'track-test-debt.ps1' @{ session_id = $sid; tool_name = 'Bash'; tool_input = @{ command = 'powershell -File scripts/test-service.ps1 order-service' } } $t | Out-Null
$r = Invoke-Hook 'remind-tests.ps1' @{ session_id = $sid; stop_hook_active = $false } $t
Assert 'test-service.ps1 clears debt' ($r.Code -eq 0 -and -not $r.Decision) $r
Invoke-Hook 'track-test-debt.ps1' @{ session_id = $sid; tool_name = 'Edit'; tool_input = @{ file_path = $kt } } $t | Out-Null
Invoke-Hook 'track-test-debt.ps1' @{ session_id = $sid; tool_name = 'Bash'; tool_input = @{ command = 'powershell -File scripts/test-all.ps1' } } $t | Out-Null
$r = Invoke-Hook 'remind-tests.ps1' @{ session_id = $sid; stop_hook_active = $false } $t
Assert 'test-all.ps1 clears debt' ($r.Code -eq 0 -and -not $r.Decision) $r
Remove-Item $t -Recurse -Force

# ---------------------------------------------------------------- check-architecture-docs
Write-Host 'check-architecture-docs.ps1'
$t = New-TempRepo
Write-File $t 'docs/event-catalog/README.md' "# Event Catalog`n" | Out-Null
Write-File $t 'docs/architecture/service-catalog.md' "| ``services/order-service`` |`n" | Out-Null
Write-File $t 'docs/skill-catalog.md' "| ``known-skill`` |`n" | Out-Null
Write-File $t 'docs/workflow-catalog.md' "x`n" | Out-Null
Write-File $t 'docs/agent-catalog.md' "x`n" | Out-Null
Write-File $t 'docs/hook-catalog.md' "x`n" | Out-Null
Write-File $t 'docs/adr/README.md' "x`n" | Out-Null
& git -C $t add -A; & git -C $t commit -q -m baseline
$stop = @{ session_id = 's'; stop_hook_active = $false }
$r = Invoke-Hook 'check-architecture-docs.ps1' $stop $t
Assert 'clean tree passes' ($r.Code -eq 0 -and -not $r.Decision) $r
Write-File $t 'contracts/events/order/OrderCreated.v1.avsc' "{}`n" | Out-Null
$r = Invoke-Hook 'check-architecture-docs.ps1' $stop $t
Assert 'A1 contract without catalog' ($r.Decision -eq 'block' -and $r.Out -match 'A1') $r
Add-Content (Join-Path $t 'docs/event-catalog/README.md') '| OrderCreated |'
$r = Invoke-Hook 'check-architecture-docs.ps1' $stop $t
Assert 'A1 satisfied when catalog changes' ($r.Code -eq 0 -and -not $r.Decision) $r
& git -C $t add -A; & git -C $t commit -q -m c1
Write-File $t 'contracts/events/order/OrderConfirmed.v1.avsc' "{}`n" | Out-Null
Write-File $t 'docs/event-catalog/event-catalog.md' "### OrderConfirmed`n" | Out-Null
$r = Invoke-Hook 'check-architecture-docs.ps1' $stop $t
Assert 'A1 satisfied by detailed event-catalog.md' ($r.Code -eq 0 -and -not $r.Decision) $r
& git -C $t add -A; & git -C $t commit -q -m c2
Write-File $t 'services/ghost-service/README.md' "x`n" | Out-Null
$r = Invoke-Hook 'check-architecture-docs.ps1' $stop $t
Assert 'A2 unknown service' ($r.Decision -eq 'block' -and $r.Out -match 'A2') $r
Remove-Item (Join-Path $t 'services/ghost-service') -Recurse -Force
Write-File $t '.claude/skills/new-skill/SKILL.md' "---`nname: new-skill`ndescription: x`n---`n" | Out-Null
$r = Invoke-Hook 'check-architecture-docs.ps1' $stop $t
Assert 'A4 skill missing from catalogs' ($r.Decision -eq 'block' -and $r.Out -match 'A4') $r
Remove-Item (Join-Path $t '.claude/skills/new-skill') -Recurse -Force
Write-File $t '.claude/hooks/new-hook.ps1' "exit 0`n" | Out-Null
$r = Invoke-Hook 'check-architecture-docs.ps1' $stop $t
Assert 'A5 hook missing from catalog' ($r.Decision -eq 'block' -and $r.Out -match 'A5') $r
Remove-Item (Join-Path $t '.claude/hooks') -Recurse -Force
Write-File $t 'docs/adr/0009-new.md' "x`n" | Out-Null
$r = Invoke-Hook 'check-architecture-docs.ps1' $stop $t
Assert 'A6 ADR missing from index' ($r.Decision -eq 'block' -and $r.Out -match 'A6') $r
Remove-Item (Join-Path $t 'docs/adr/0009-new.md')
Write-File $t 'services/order-service/src/main/kotlin/X.kt' "package com.commerceflow.ordering`nimport com.commerceflow.payments.domain.Payment`n" | Out-Null
$r = Invoke-Hook 'check-architecture-docs.ps1' $stop $t
Assert 'A7 Kotlin cross-service import' ($r.Decision -eq 'block' -and $r.Out -match 'A7') $r
Write-File $t 'services/order-service/src/main/kotlin/X.kt' "package com.commerceflow.ordering`nimport com.commerceflow.ordering.domain.Order`n" | Out-Null
$r = Invoke-Hook 'check-architecture-docs.ps1' $stop $t
Assert 'A7 own-context import passes' ($r.Code -eq 0 -and -not $r.Decision) $r
$r = Invoke-Hook 'check-architecture-docs.ps1' @{ session_id = 's'; stop_hook_active = $true } $t
Assert 'no block when stop_hook_active' ($r.Code -eq 0 -and -not $r.Decision) $r
Remove-Item $t -Recurse -Force

# ---------------------------------------------------------------- secret scan over the real repository (false positives)
Write-Host 'detect-secrets.ps1 over all tracked repository files'
$t = New-TempRepo
foreach ($f in (& git -C $root ls-files)) {
    $src = Join-Path $root $f
    $dst = Join-Path $t $f
    New-Item -ItemType Directory -Path (Split-Path $dst) -Force | Out-Null
    Copy-Item -LiteralPath $src -Destination $dst
}
$r = Invoke-Hook 'detect-secrets.ps1' @{ tool_name = 'Bash'; tool_input = @{ command = 'git commit -m all' } } $t
Assert 'no false positives in repository files' ($r.Code -eq 0 -and -not $r.Decision) $r
Remove-Item $t -Recurse -Force

Remove-Item Env:CLAUDE_PROJECT_DIR -ErrorAction SilentlyContinue
Write-Host ""
Write-Host "passed: $script:passed  failed: $script:failures"
if ($script:failures -gt 0) { exit 1 } else { exit 0 }
