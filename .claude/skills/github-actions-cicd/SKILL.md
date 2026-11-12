---
name: github-actions-cicd
description: Build CommerceFlow CI/CD in GitHub Actions for a monorepo of independently deployable services - one path-filtered workflow per service and app, reusable workflow templates per language, contract checks, image builds, can-i-deploy gates and per-service deployment with environment approvals. Use when adding or changing any workflow under .github/workflows.
---

# GitHub Actions CI/CD

## Purpose

Every service and app gets its own pipeline that runs only when its code or the contracts
it depends on change, and deploys only itself.

## When to use

- A new service/app needs CI.
- Changing build, test, scan, image or deploy steps.
- Contract or schema checks in CI.

## Prerequisites

- Service builds and tests from its folder.
- Remote `origin` is GitHub. Lint workflows locally with `actionlint` (for example
  `docker run --rm -v <repo>:/repo -w /repo rhysd/actionlint:1.7.7`); they run on GitHub
  only after the user pushes. Claude never pushes.
- Owner: `devops-engineer`.

## Concepts and architecture

```text
.github/workflows/
  _kotlin-service.yml     reusable (workflow_call): build, test, scan, image
  _go-service.yml         reusable
  _web-app.yml            reusable
  order-service.yml       caller: path filters + inputs -> _kotlin-service.yml
  inventory-service.yml   caller -> _go-service.yml
  contracts.yml           Avro parse + compatibility, OpenAPI lint
  e2e-nightly.yml         tests/e2e, tests/resilience on schedule
```

Reusable workflows share **CI definitions**, not runtime code — services stay independent.

**Path filters** per caller: the service folder, contracts it produces/consumes (from the
event catalog), its OpenAPI spec, and its own workflow file.

**Stages:** build+unit → integration (Testcontainers on `ubuntu-latest`, Docker available)
→ contract verification → scan → image build (push only when a registry is configured) →
deploy (environment with required reviewers).

## Step-by-step workflow

1. Create or reuse the language template (`_kotlin-service.yml` etc.).
2. Create the caller workflow with `paths` filters and `concurrency`.
3. Set least-privilege `permissions` (`contents: read`; add `packages: write` only for push).
4. Add caching (Gradle, Go modules, npm).
5. Add contract jobs (provider verification, can-i-deploy) once the broker exists.
6. Lint: `actionlint` locally.

## Practical code examples

Caller `.github/workflows/order-service.yml`:

```yaml
name: order-service
on:
  pull_request:
    paths: &paths
      - "services/order-service/**"
      - "contracts/events/common/**"
      - "contracts/events/order/**"
      - "contracts/events/inventory/**"
      - "contracts/events/payment/**"
      - "contracts/events/shipment/**"
      - "contracts/openapi/order-service.*"
      - ".github/workflows/order-service.yml"
      - ".github/workflows/_kotlin-service.yml"
  push:
    branches: [main]
    paths: *paths
concurrency:
  group: order-service-${{ github.ref }}
  cancel-in-progress: true
permissions:
  contents: read
jobs:
  ci:
    uses: ./.github/workflows/_kotlin-service.yml
    with:
      service: order-service
```

(YAML anchors are supported in GitHub Actions workflow files since 2025; if your runner/linter
rejects them, duplicate the list.)

Reusable `.github/workflows/_kotlin-service.yml`:

```yaml
name: kotlin-service
on:
  workflow_call:
    inputs:
      service: { type: string, required: true }
permissions:
  contents: read
jobs:
  build-test:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: services/${{ inputs.service }}
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with: { distribution: temurin, java-version: "17" }
      - uses: gradle/actions/setup-gradle@v4
      - run: ./gradlew build --no-daemon      # unit + Testcontainers integration + ArchUnit
      - uses: actions/upload-artifact@v4
        if: failure()
        with: { name: test-reports-${{ inputs.service }}, path: services/${{ inputs.service }}/build/reports }

  image:
    needs: build-test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: docker/setup-buildx-action@v3
      - uses: docker/build-push-action@v6
        with:
          context: services/${{ inputs.service }}
          build-contexts: contracts=contracts
          push: false                          # no registry configured yet
          tags: commerceflow/${{ inputs.service }}:${{ github.sha }}
          cache-from: type=gha,scope=${{ inputs.service }}
          cache-to: type=gha,mode=max,scope=${{ inputs.service }}
```

Go template core steps:

```yaml
      - uses: actions/setup-go@v5
        with: { go-version-file: services/${{ inputs.service }}/go.mod, cache-dependency-path: services/${{ inputs.service }}/go.sum }
      - run: make lint test build
      - run: go test -race -tags=integration ./...
      - run: go run golang.org/x/vuln/cmd/govulncheck@latest ./...
```

Contracts workflow job (Avro syntax check, compatibility against a registry started in the
job):

```yaml
  avro:
    runs-on: ubuntu-latest
    services:
      schema-registry: { image: "confluentinc/cp-schema-registry:7.7.1", ports: ["8081:8081"], env: { ... } }
    steps:
      - uses: actions/checkout@v4
      - run: ./tests/contract/check-avro-compatibility.sh   # parses all .avsc, checks changed subjects
```

Deployment (later, once a cluster exists):

```yaml
  deploy-staging:
    needs: image
    if: github.ref == 'refs/heads/main'
    environment: staging          # required reviewers configured in GitHub
    runs-on: ubuntu-latest
    steps:
      - run: npx pact-broker can-i-deploy --pacticipant order-service --version ${{ github.sha }} --to-environment staging
      - run: helm upgrade --install order-service infrastructure/kubernetes/helm/service -f infrastructure/kubernetes/helm/values/order-service.yaml --set image.tag=${{ github.sha }}
```

## Recommended project structure

```text
.github/workflows/_<language>-service.yml, _web-app.yml   reusable templates
.github/workflows/<component>.yml                          one per service/app
.github/workflows/contracts.yml, e2e-nightly.yml
```

## Best practices

- Pin actions to major versions at minimum (SHA pinning for third-party actions).
- `permissions` minimal per workflow; OIDC to the cloud instead of long-lived secrets.
- `concurrency` per component and ref.
- Fail fast on unit tests; upload reports on failure.
- Require the component's workflow as a status check only when its paths changed
  (use a summary job or path-aware rules).

## Anti-patterns

- One workflow that builds every service on every change.
- `pull_request_target` with checkout of PR code (secret exfiltration risk).
- Deploying all services together.
- Secrets in workflow files; `permissions: write-all`.
- Skipping tests to speed up image builds.

## Failure scenarios

| Scenario | Handling |
|---|---|
| Contract change not triggering consumers | Add the contract path to every consumer's filter (from the event catalog). |
| Flaky Testcontainers in CI | Pre-pull images, increase timeouts, investigate root cause. |
| Provider breaks consumer | Provider verification fails in provider workflow → blocked. |
| Required check never runs (paths) | Use a summary job pattern so the check reports success when skipped. |

## Testing strategy

- `actionlint` for all workflows.
- Dry run locally with `act` where feasible (optional).
- First real runs only after the user configures a remote.

## Definition of Done

- Workflow per component with correct path filters, minimal permissions and concurrency.
- Build, tests, scans and image build succeed (once runnable).
- Deployment, when added, is per component and gated by environment approval and
  can-i-deploy.
