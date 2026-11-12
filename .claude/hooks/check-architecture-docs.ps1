# Stop: architecture documentation and boundary checks on uncommitted changes.
#
# Only paths changed in the working tree are inspected, so pre-existing state never nags.
# Rules (all deterministic, see docs/hook-catalog.md):
#   A1 contracts/events changed     -> docs/event-catalog/README.md changed too
#   A2 services/<x> or apps/<x>     -> listed in docs/architecture/service-catalog.md
#   A3 .claude/agents/<x>.md        -> listed in docs/agent-catalog.md
#   A4 .claude/skills/<x>/          -> listed in docs/skill-catalog.md or docs/workflow-catalog.md
#   A5 .claude/hooks/<x>.ps1        -> listed in docs/hook-catalog.md
#   A6 docs/adr/NNNN-*.md           -> listed in docs/adr/README.md
#   A7 Kotlin/Go file imports another service's package/module (blocking architecture rule)
# Claude is asked once per stop cycle (stop_hook_active guard) to fix or explain.

. "$PSScriptRoot/lib/common.ps1"

$payload = Read-HookInput
if (-not $payload) { exit 0 }
if ($payload.stop_hook_active -eq $true) { exit 0 }

$projectDir = Get-ProjectDir $payload
$changed = Get-ChangedPaths $projectDir
if ($changed.Count -eq 0) { exit 0 }

function Read-Doc([string]$rel) {
    $p = Join-Path $projectDir $rel
    if (Test-Path $p) { return [System.IO.File]::ReadAllText($p) } else { return '' }
}

$issues = @()

# A1
if (($changed | Where-Object { $_ -like 'contracts/events/*' -and $_ -notlike 'contracts/events/README.md' }) -and
    -not ($changed -contains 'docs/event-catalog/README.md')) {
    $issues += 'A1: contracts/events changed but docs/event-catalog/README.md was not updated'
}

# A2
$serviceCatalog = Read-Doc 'docs/architecture/service-catalog.md'
$components = $changed | ForEach-Object { Get-Component $_ } | Where-Object { $_ } | Sort-Object -Unique
foreach ($c in $components) {
    if ($serviceCatalog -notmatch [regex]::Escape("``$c``")) { $issues += "A2: $c is not listed in docs/architecture/service-catalog.md" }
}

# A3
$agentCatalog = Read-Doc 'docs/agent-catalog.md'
foreach ($p in $changed | Where-Object { $_ -match '^\.claude/agents/([^/]+)\.md$' }) {
    $n = [System.IO.Path]::GetFileNameWithoutExtension($p)
    if ((Test-Path (Join-Path $projectDir $p)) -and $agentCatalog -notmatch [regex]::Escape("``$n``")) { $issues += "A3: agent $n is not listed in docs/agent-catalog.md" }
}

# A4
$skillDocs = (Read-Doc 'docs/skill-catalog.md') + (Read-Doc 'docs/workflow-catalog.md')
$skills = $changed | Where-Object { $_ -match '^\.claude/skills/([^/]+)/' } | ForEach-Object { ($_ -split '/')[2] } | Sort-Object -Unique
foreach ($s in $skills) {
    if ((Test-Path (Join-Path $projectDir ".claude/skills/$s/SKILL.md")) -and $skillDocs -notmatch [regex]::Escape("``$s``")) {
        $issues += "A4: skill $s is not listed in docs/skill-catalog.md or docs/workflow-catalog.md"
    }
}

# A5
$hookCatalog = Read-Doc 'docs/hook-catalog.md'
foreach ($p in $changed | Where-Object { $_ -match '^\.claude/hooks/[^/]+\.ps1$' }) {
    $n = [System.IO.Path]::GetFileName($p)
    if ((Test-Path (Join-Path $projectDir $p)) -and $hookCatalog -notmatch [regex]::Escape($n)) { $issues += "A5: hook $n is not documented in docs/hook-catalog.md" }
}

# A6
$adrIndex = Read-Doc 'docs/adr/README.md'
foreach ($p in $changed | Where-Object { $_ -match '^docs/adr/(\d{4})-.+\.md$' }) {
    $n = [System.IO.Path]::GetFileName($p)
    if ($n -ne '0000-template.md' -and (Test-Path (Join-Path $projectDir $p)) -and $adrIndex -notmatch [regex]::Escape($n)) { $issues += "A6: $n is not in the docs/adr/README.md index" }
}

# A7
$kotlinContext = @{ 'product-service' = 'catalog'; 'order-service' = 'ordering'; 'payment-service' = 'payments';
                    'customer-service' = 'customer'; 'pricing-service' = 'pricing' }
$allContexts = @($kotlinContext.Values)
foreach ($p in $changed | Where-Object { $_ -match '^services/([^/]+)/.+\.(kt|go)$' }) {
    $svc = ($p -split '/')[1]
    $full = Join-Path $projectDir $p
    if (-not (Test-Path $full -PathType Leaf)) { continue }
    $src = Get-Content -LiteralPath $full
    if ($p.EndsWith('.kt') -and $kotlinContext.ContainsKey($svc)) {
        foreach ($ctx in $allContexts | Where-Object { $_ -ne $kotlinContext[$svc] }) {
            if ($src -match "^\s*import\s+com\.commerceflow\.$ctx\.") { $issues += "A7: $p imports com.commerceflow.$ctx (another service)"; break }
        }
    }
    if ($p.EndsWith('.go')) {
        $hits = $src | Select-String -Pattern '"github\.com/commerceflow/commerceflow/services/([^/"]+)' -AllMatches
        foreach ($m in $hits.Matches) {
            if ($m.Groups[1].Value -ne $svc) { $issues += "A7: $p imports services/$($m.Groups[1].Value) (another service)"; break }
        }
    }
}
foreach ($p in $changed | Where-Object { $_ -match '^services/([^/]+)/go\.mod$' }) {
    $full = Join-Path $projectDir $p
    if ((Test-Path $full) -and ((Get-Content $full) -match '^\s*replace\s+.*=>\s*\.\./')) { $issues += "A7: $p has a replace directive to a sibling folder" }
}

if ($issues.Count -gt 0) {
    Write-StopBlock ("check-architecture-docs: " + ($issues -join '; ') + ". Update the documentation or remove the violation; if a rule does not apply, say why.")
}
exit 0
