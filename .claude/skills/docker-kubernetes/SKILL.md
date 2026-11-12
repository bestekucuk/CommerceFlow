---
name: docker-kubernetes
description: Containerize and deploy CommerceFlow services independently - multi-stage Dockerfiles per service with a named build context for contracts/, non-root minimal images, docker-compose.yml wiring for local development, and Kubernetes/Helm per-service releases with probes, resources, security context, config and secrets. Use when creating or changing a Dockerfile, the Compose stack or Kubernetes manifests.
---

# Docker and Kubernetes

## Purpose

One image and one release per service, built from that service's folder (plus contracts),
running securely and observably in Compose and Kubernetes.

## When to use

- Adding a Dockerfile to a service or app.
- Adding a service or platform component to `docker-compose.yml`.
- Writing Helm values, probes, resources or policies.

## Prerequisites

- Service builds locally (`kotlin-springboot` / `golang-development` / `react-typescript`).
- Health endpoints: Spring Actuator `/actuator/health/{liveness,readiness}`; Go `/healthz`
  and `/readyz`.
- Owner: `devops-engineer` (Dockerfiles only when the task names the service).

## Concepts and architecture

- **Build context:** the service folder. Contracts are added with a BuildKit **named
  context** (`--build-context contracts=contracts`) so the image never sees other services.
- **Images:** multi-stage; runtime stage minimal (`eclipse-temurin:17-jre` — the repository targets Java 17 — or distroless
  Java, `gcr.io/distroless/static:nonroot` for Go, `nginx-unprivileged` for apps); non-root;
  pinned tags (digests in CI).
- **Compose:** the root `docker-compose.yml` runs platform components + services for local
  development and tests. It is not a deployment unit.
- **Kubernetes:** one Helm release per service using a common chart template located in
  `infrastructure/kubernetes/helm/service/` with per-service values; each release is
  deployed by that service's pipeline.

## Step-by-step workflow

1. Write `services/<svc>/Dockerfile` and `.dockerignore`.
2. Build: `docker build --build-context contracts=contracts -t commerceflow/<svc>:dev services/<svc>`.
3. Add the service to `docker-compose.yml` with `additional_contexts`, env, health check and
   dependencies.
4. Add `infrastructure/kubernetes/helm/values/<svc>.yaml` (image, resources, env, secrets refs).
5. Validate: `docker compose config`, `helm lint`, `helm template ... | kubeconform` (if available).
6. Verify the container runs as non-root and probes pass.

## Practical code examples

Kotlin service `services/order-service/Dockerfile`:

```dockerfile
# syntax=docker/dockerfile:1.7
FROM eclipse-temurin:17-jdk AS build
WORKDIR /src
COPY --from=contracts . /contracts
COPY gradlew settings.gradle.kts build.gradle.kts ./
COPY gradle ./gradle
RUN ./gradlew --no-daemon dependencies -PcontractsDir=/contracts > /dev/null
COPY src ./src
RUN ./gradlew --no-daemon bootJar -x test -PcontractsDir=/contracts \
 && java -Djarmode=tools -jar build/libs/*.jar extract --layers --launcher --destination /app

FROM eclipse-temurin:17-jre
RUN useradd --system --uid 10001 app
WORKDIR /app
COPY --from=build /app/dependencies/ ./
COPY --from=build /app/spring-boot-loader/ ./
COPY --from=build /app/snapshot-dependencies/ ./
COPY --from=build /app/application/ ./
USER 10001
EXPOSE 8082
ENTRYPOINT ["java", "-XX:MaxRAMPercentage=75", "org.springframework.boot.loader.launch.JarLauncher"]
```

(`-Djarmode=tools ... extract --layers --launcher` is Spring Boot 3.3+; older versions use
`-Djarmode=layertools extract`.)

Go service `services/inventory-service/Dockerfile`:

```dockerfile
# syntax=docker/dockerfile:1.7
FROM golang:1.23 AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
COPY --from=contracts . /contracts
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/inventory-service ./cmd/inventory-service

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /out/inventory-service /inventory-service
COPY --from=build /src/migrations /migrations
USER nonroot:nonroot
EXPOSE 8083
ENTRYPOINT ["/inventory-service"]
```

Compose entry:

```yaml
services:
  order-service:
    build:
      context: ./services/order-service
      additional_contexts:
        contracts: ./contracts
    environment:
      DB_URL: jdbc:postgresql://postgres:5432/order_db
      DB_USER: order_service
      DB_PASSWORD: ${ORDER_DB_PASSWORD:?set in .env}
      KAFKA_BOOTSTRAP: kafka:9092
      SCHEMA_REGISTRY_URL: http://schema-registry:8081      # container port; host maps 8090
      OTEL_EXPORTER_OTLP_ENDPOINT: http://otel-collector:4317
    ports: ["8082:8082"]
    depends_on:
      postgres: { condition: service_healthy }
      kafka: { condition: service_healthy }
    healthcheck:
      test: ["CMD-SHELL", "wget -qO- http://localhost:8082/actuator/health/readiness || exit 1"]
      interval: 10s
      retries: 10
```

(The JRE image has no `wget` by default; use a Spring Boot health check via a tiny
`HEALTHCHECK` binary, `curl` installed in the runtime stage, or rely on `depends_on`
without health checks for services. Decide once in CF-005.)

Helm values (`infrastructure/kubernetes/helm/values/order-service.yaml`):

```yaml
image:
  repository: registry.example/commerceflow/order-service   # registry not chosen yet
  tag: ""                                                   # set by CI to the git SHA
replicaCount: 2
containerPort: 8082
resources:
  requests: { cpu: 250m, memory: 512Mi }
  limits:   { memory: 768Mi }
probes:
  liveness:  { path: /actuator/health/liveness,  port: 8082 }
  readiness: { path: /actuator/health/readiness, port: 8082 }
env:
  KAFKA_BOOTSTRAP: kafka:9092
  SCHEMA_REGISTRY_URL: http://schema-registry:8081
secretEnv:
  DB_PASSWORD: { secretName: order-service-db, key: password }
podSecurityContext: { runAsNonRoot: true, runAsUser: 10001, fsGroup: 10001 }
securityContext:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities: { drop: ["ALL"] }
terminationGracePeriodSeconds: 40
```

Deployment template fragment (chart `templates/deployment.yaml`):

```yaml
        readinessProbe:
          httpGet: { path: {{ .Values.probes.readiness.path }}, port: {{ .Values.probes.readiness.port }} }
          periodSeconds: 5
        livenessProbe:
          httpGet: { path: {{ .Values.probes.liveness.path }}, port: {{ .Values.probes.liveness.port }} }
          initialDelaySeconds: 30
        {{- range $name, $ref := .Values.secretEnv }}
        - name: {{ $name }}
          valueFrom: { secretKeyRef: { name: {{ $ref.secretName }}, key: {{ $ref.key }} } }
        {{- end }}
```

## Recommended project structure

```text
services/<svc>/Dockerfile, .dockerignore
apps/<app>/Dockerfile
docker-compose.yml                                   local stack
infrastructure/docker/                               compose overrides, conventions
infrastructure/kubernetes/helm/service/              shared chart template (deployment config, not runtime code)
infrastructure/kubernetes/helm/values/<svc>.yaml     per-service values
infrastructure/kubernetes/base/                      namespaces, network policies, quotas
```

## Best practices

- Copy dependency manifests first for layer caching; source last.
- `.dockerignore` excludes `build/`, `bin/`, `node_modules/`, `.git`.
- One process per container; logs to stdout as JSON.
- `readOnlyRootFilesystem` + `emptyDir` for `/tmp` where needed.
- Resource requests from measurements (`performance-testing`), memory limit = request + headroom.
- NetworkPolicies: services reach only their own database, Kafka, Schema Registry, the
  collector and explicitly allowed APIs.

## Anti-patterns

- Building from the repo root context (every service image sees all code).
- `latest` tags in Compose or Helm.
- Running as root; mounting the Docker socket.
- Secrets in `environment:` with literal values, in Dockerfiles or in Helm values files.
- One Helm release containing all services.

## Failure scenarios

| Scenario | Handling |
|---|---|
| Pod OOMKilled | Check heap vs limit (`MaxRAMPercentage`), raise limit from measurements. |
| Readiness never ready | Dependency down → check readiness groups; do not include optional deps. |
| SIGTERM kills in-flight work | `terminationGracePeriodSeconds` > app drain timeout; graceful shutdown enabled. |
| Image cannot find contracts | Missing `--build-context contracts=...` / `additional_contexts`. |

## Testing strategy

- `docker build` of each touched image in its pipeline.
- Container smoke test: start image with Compose dependencies, hit readiness.
- `helm lint` and `helm template` + schema validation in CI.
- Trivy image scan (`security-review`).

## Definition of Done

- Image builds from the service folder + contracts context only; runs as non-root.
- Compose entry with env, ports and dependencies; `docker compose config` passes.
- Helm values with probes, resources, security context and secret references; lint passes.
- No secrets or `latest` tags committed.
