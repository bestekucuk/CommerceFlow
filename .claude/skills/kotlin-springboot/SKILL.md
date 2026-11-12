---
name: kotlin-springboot
description: Build a CommerceFlow Kotlin + Spring Boot service as an independent Gradle Kotlin DSL project inside its services/*-service folder - build files, Avro codegen from contracts/, configuration, Flyway, Actuator, JPA/JDBC, Spring Kafka wiring, Dockerfile hooks and JUnit 5 tests. Use for product, order, payment, customer and pricing services.
---

# Kotlin + Spring Boot service

## Purpose

Give every Kotlin service (product, order, payment, customer, pricing) the same
production-ready baseline while keeping each one an **independent Gradle build** — no root
`settings.gradle.kts`, no shared runtime library.

## When to use

- First code in a Kotlin service folder (scaffold).
- Adding Spring modules (Kafka, Security, JPA) to a service.
- Fixing build, configuration or startup problems in a Kotlin service.

## Prerequisites

- JDK 21 locally (`java -version`) and Docker for Testcontainers.
- Service `CLAUDE.md` (package root `com.commerceflow.<context>`, database `<name>_db`).
- `clean-architecture`, `transactional-outbox`, `idempotent-consumer`.

## Concepts and architecture

- **Independent build:** `services/<name>-service/settings.gradle.kts` makes the folder a
  root project. The Gradle wrapper is committed in the folder.
- **Contracts:** Avro classes are generated at build time from `../../contracts/events`
  (overridable with `-PcontractsDir=/contracts` inside Docker). Generated code lives in
  `build/`, never committed, never shared.
- **Versions:** pinned in the service's own `gradle/libs.versions.toml`. Services may
  upgrade independently; keep them aligned by convention, not by a shared BOM project.
- **Runtime:** Spring Boot 3.3, bytecode target Java 17 (current repository choice: builds on any JDK 17+, images use Temurin 17); moving to Java 21 and virtual threads is a later per-service decision.

## Step-by-step workflow

1. Generate the wrapper: `gradle wrapper --gradle-version 8.10.2` in the service folder
   (or copy from another service and run `./gradlew wrapper` to verify).
2. Create `settings.gradle.kts`, `build.gradle.kts`, `gradle/libs.versions.toml`.
3. Create the package layout from `clean-architecture`.
4. Add `application.yml` with env-driven configuration.
5. Add Flyway baseline migration `V1__outbox_inbox.sql` (`transactional-outbox`).
6. Add `Application.kt`, health/metrics configuration, and an architecture test.
7. Run `./gradlew build` from the service folder; it must pass with only Docker running.
8. Add the Dockerfile (`docker-kubernetes`) and CI workflow (`github-actions-cicd`).

## Practical code examples

`settings.gradle.kts`:

```kotlin
rootProject.name = "order-service"
```

`build.gradle.kts`:

```kotlin
plugins {
    id("org.springframework.boot") version "3.3.5"
    id("io.spring.dependency-management") version "1.1.6"
    kotlin("jvm") version "2.0.21"
    kotlin("plugin.spring") version "2.0.21"
    kotlin("plugin.jpa") version "2.0.21"
    id("com.github.davidmc24.gradle.plugin.avro") version "1.9.1"
}

group = "com.commerceflow"
java { toolchain { languageVersion = JavaLanguageVersion.of(21) } }
kotlin { compilerOptions { freeCompilerArgs.addAll("-Xjsr305=strict") } }

repositories {
    mavenCentral()
    maven("https://packages.confluent.io/maven/")
}

val contractsDir = providers.gradleProperty("contractsDir").orElse("../../contracts").get()

avro {
    // generate only the contracts this service produces or consumes
    stringType = "String"
}
tasks.named<com.github.davidmc24.gradle.plugin.avro.GenerateAvroJavaTask>("generateAvroJava") {
    source(file("$contractsDir/events/common"), file("$contractsDir/events/order"),
           file("$contractsDir/events/inventory"), file("$contractsDir/events/payment"))
}

dependencies {
    implementation("org.springframework.boot:spring-boot-starter-web")
    implementation("org.springframework.boot:spring-boot-starter-validation")
    implementation("org.springframework.boot:spring-boot-starter-actuator")
    implementation("org.springframework.boot:spring-boot-starter-data-jpa")
    implementation("org.springframework.boot:spring-boot-starter-oauth2-resource-server")
    implementation("org.springframework.kafka:spring-kafka")
    implementation("org.flywaydb:flyway-core")
    implementation("org.flywaydb:flyway-database-postgresql")
    implementation("com.fasterxml.jackson.module:jackson-module-kotlin")
    implementation("io.confluent:kafka-avro-serializer:7.7.1")
    implementation("io.micrometer:micrometer-registry-prometheus")
    runtimeOnly("org.postgresql:postgresql")

    testImplementation("org.springframework.boot:spring-boot-starter-test")
    testImplementation("org.springframework.boot:spring-boot-testcontainers")
    testImplementation("org.springframework.kafka:spring-kafka-test")
    testImplementation("org.testcontainers:junit-jupiter")
    testImplementation("org.testcontainers:postgresql")
    testImplementation("org.testcontainers:kafka")
    testImplementation("com.tngtech.archunit:archunit-junit5:1.3.0")
    testImplementation("io.mockk:mockk:1.13.13")
}

tasks.test { useJUnitPlatform() }
```

`src/main/resources/application.yml`:

```yaml
spring:
  application.name: order-service
  threads.virtual.enabled: true
  datasource:
    url: ${DB_URL:jdbc:postgresql://localhost:15432/order_db}
    username: ${DB_USER:order_service}
    password: ${DB_PASSWORD}
  jpa:
    open-in-view: false
    hibernate.ddl-auto: validate
  flyway.enabled: true
  kafka:
    bootstrap-servers: ${KAFKA_BOOTSTRAP:localhost:9092}
    consumer:
      group-id: order-service
      enable-auto-commit: false
      auto-offset-reset: earliest
    properties:
      schema.registry.url: ${SCHEMA_REGISTRY_URL:http://localhost:8090}   # 8081 is product-service locally
      specific.avro.reader: true
  security.oauth2.resourceserver.jwt:
    issuer-uri: ${OIDC_ISSUER_URI}
    audiences: order-service
server:
  port: ${PORT:8082}
  shutdown: graceful
management:
  endpoints.web.exposure.include: health,info,prometheus
  endpoint.health.probes.enabled: true
```

`Application.kt`:

```kotlin
@SpringBootApplication
class OrderServiceApplication

fun main(args: Array<String>) { runApplication<OrderServiceApplication>(*args) }
```

Use-case wiring without component scanning into domain:

```kotlin
@Configuration
class UseCaseConfig {
    @Bean fun placeOrder(orders: OrderRepository, events: OrderEvents) = PlaceOrder(orders, events)
}
```

## Recommended project structure

```text
services/order-service/
  settings.gradle.kts  build.gradle.kts  gradle/libs.versions.toml
  gradlew  gradlew.bat  gradle/wrapper/
  Dockerfile  .dockerignore
  src/main/kotlin/com/commerceflow/ordering/{domain,application,adapters,config}/
  src/main/resources/application.yml
  src/main/resources/db/migration/V1__outbox_inbox.sql
  src/test/kotlin/com/commerceflow/ordering/
```

## Best practices

- `open-in-view: false`, `ddl-auto: validate` — Flyway owns the schema.
- Constructor injection only; no field `@Autowired`.
- Configuration via environment variables with safe local defaults (never default secrets).
- `server.shutdown: graceful` plus a `terminationGracePeriodSeconds` larger than the drain.
- Keep Spring annotations out of `domain`; wire use cases in `config/`.
- Pin plugin and library versions; upgrade per service with its own PR.

## Anti-patterns

- A root `settings.gradle.kts` including all services.
- `buildSrc` or included builds shared by services — that is a shared runtime/build coupling.
- Committing generated Avro classes.
- Business logic in `@RestController` or `@KafkaListener` methods.
- `@Transactional` on private methods or self-invocation (proxy is bypassed).

## Failure scenarios

| Scenario | Symptom | Fix |
|---|---|---|
| Flyway and entities disagree | Startup fails on `validate` | Add a migration; never switch to `update`. |
| Schema Registry unreachable | Producer serialization fails | Fail fast at startup health check; do not swallow. |
| JWT issuer down at startup | `issuer-uri` discovery fails | Use `jwk-set-uri` for resilience or retry startup via orchestrator. |
| Codegen cannot find contracts in Docker | `generateAvroJava` empty | Build with `--build-context contracts=contracts` and `-PcontractsDir=/contracts`. |

## Testing strategy

- Unit: domain and use cases with MockK/fakes (`unit-integration-testing`).
- Slice tests: `@WebMvcTest` for controllers, `@DataJpaTest` + Testcontainers for repositories.
- Integration: `@SpringBootTest` with Testcontainers PostgreSQL and Kafka (`testcontainers`).
- Architecture: ArchUnit (`clean-architecture`).
- All run by `./gradlew build` from the service folder.

## Definition of Done

- `./gradlew build` passes from the service folder on a clean checkout.
- No dependency on files outside the folder except `contracts/` codegen input.
- Health, readiness and Prometheus endpoints exposed.
- Flyway baseline includes outbox and inbox tables.
- Configuration fully env-driven, no secrets committed.
