<#
.SYNOPSIS
  Runs the cross-service E2E tests (build tag e2e) inside the Compose network, so they
  reach services by their container names. Needs the stack and the apps profile running:
    infrastructure/scripts/up.ps1
    infrastructure/scripts/migrate.ps1 -Service product; -Service inventory
    infrastructure/scripts/register-schemas.ps1
    docker compose --profile apps up -d --build product-service inventory-service
    infrastructure/scripts/register-connectors.ps1 -Service product
.EXAMPLE
  powershell -File tests/integration/run-e2e.ps1
#>
$ErrorActionPreference = 'Continue'
$root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path -replace '\\', '/'
$env:MSYS_NO_PATHCONV = '1'
& docker run --rm --network commerceflow_default `
    -v "${root}:/repo" -w /repo/tests/integration `
    -v commerceflow-go-mod:/go/pkg/mod -v commerceflow-go-build:/root/.cache/go-build `
    golang:1.23 sh -c 'go mod tidy && go vet -tags=e2e ./... && go test -tags=e2e -count=1 -v ./...'
exit $LASTEXITCODE
