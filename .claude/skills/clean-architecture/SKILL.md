---
name: clean-architecture
description: Structure a CommerceFlow service with Clean/Hexagonal Architecture - domain, application (use cases and ports) and adapters - enforce the inward dependency rule with ArchUnit (Kotlin) or import checks (Go), and block cross-service imports in the monorepo. Use when creating packages, adding a use case or adapter, or reviewing layering.
---

# Clean Architecture

## Purpose

Make business logic independent of frameworks, databases and Kafka so it is testable in
isolation and adapters can change without touching rules. In the monorepo, the same
checks also stop one service from importing another.

## When to use

- Adding a use case, port or adapter.
- Creating the package layout of a new service.
- Reviewing code where Spring/JPA/Kafka types appear in business logic.

## Prerequisites

- `domain-driven-design` for what goes into `domain`.
- `kotlin-springboot` or `golang-development` for build setup.

## Concepts and architecture

```text
            adapters/in  (REST controllers, Kafka listeners)
                  │ calls
            application  (use cases = input ports; output port interfaces)
                  │ uses
               domain    (aggregates, value objects, domain events)
                  ▲ implements output ports
            adapters/out (PostgreSQL repositories, outbox writer, HTTP clients)
```

Dependency rule: source dependencies point inward only.

| Layer | May depend on | Must not depend on |
|---|---|---|
| domain | standard library | application, adapters, Spring, JPA, Kafka, Jackson, pgx |
| application | domain | adapters, web/persistence frameworks (Spring `@Transactional` allowed in Kotlin as a pragmatic exception) |
| adapters | application, domain, frameworks | other adapters' internals |
| config / main | everything | — |

Ports: **input ports** are use-case interfaces (or the use-case classes themselves);
**output ports** are interfaces declared in application/domain and implemented in
adapters (`OrderRepository`, `EventPublisher` → outbox writer, `PaymentGateway`).

## Step-by-step workflow

1. Write the use case in `application/` with its command object and result.
2. Declare the output ports it needs as interfaces next to it.
3. Implement domain behaviour in `domain/` (no I/O).
4. Implement adapters: inbound (controller/listener → command), outbound (port impls).
5. Wire everything in `config/` (Kotlin) or `cmd/<service>/main.go` (Go).
6. Add/extend the architecture test.

## Practical code examples

Kotlin use case with ports:

```kotlin
// application/PlaceOrder.kt
data class PlaceOrderCommand(val customerId: UUID, val lines: List<LineInput>, val idempotencyKey: String)

interface OrderRepository { fun save(order: Order); fun findById(id: OrderId): Order? }
interface OrderEvents { fun record(events: List<OrderDomainEvent>) }   // implemented by outbox writer

class PlaceOrder(
    private val orders: OrderRepository,
    private val events: OrderEvents,
    private val ids: () -> UUID = UUID::randomUUID,
) {
    @Transactional
    fun handle(cmd: PlaceOrderCommand): OrderId {
        val order = Order.place(OrderId(ids()), CustomerId(cmd.customerId), cmd.lines.map { it.toDomain() })
        orders.save(order)
        events.record(order.pullEvents())   // same transaction -> outbox
        return order.id
    }
}
```

ArchUnit rules (`src/test/kotlin/.../ArchitectureTest.kt`):

```kotlin
@AnalyzeClasses(packages = ["com.commerceflow.ordering"], importOptions = [ImportOption.DoNotIncludeTests::class])
class ArchitectureTest {
    @ArchTest
    val domainIsPure: ArchRule = noClasses().that().resideInAPackage("..domain..")
        .should().dependOnClassesThat().resideInAnyPackage(
            "org.springframework..", "jakarta.persistence..", "org.apache.kafka..", "com.fasterxml.jackson..",
            "..application..", "..adapters..")

    @ArchTest
    val applicationDoesNotKnowAdapters: ArchRule = noClasses().that().resideInAPackage("..application..")
        .should().dependOnClassesThat().resideInAPackage("..adapters..")

    @ArchTest
    val noOtherServices: ArchRule = noClasses().should().dependOnClassesThat()
        .resideInAnyPackage("com.commerceflow.catalog..", "com.commerceflow.payments..",
                            "com.commerceflow.customer..", "com.commerceflow.pricing..")
}
```

Dependency: `testImplementation("com.tngtech.archunit:archunit-junit5:1.3.0")`.

Go import check (`services/inventory-service/internal/archtest/arch_test.go`):

```go
func TestDomainHasNoInfrastructureImports(t *testing.T) {
	out, err := exec.Command("go", "list", "-f", `{{join .Imports "\n"}}`, "../domain/...").Output()
	if err != nil {
		t.Fatal(err)
	}
	forbidden := []string{"/internal/adapters", "/internal/application", "github.com/jackc/pgx",
		"github.com/twmb/franz-go", "net/http", "/services/"}
	for _, imp := range strings.Split(string(out), "\n") {
		for _, f := range forbidden {
			if strings.Contains(imp, f) {
				t.Errorf("domain imports forbidden package %q", imp)
			}
		}
	}
}
```

Go modules are per service, so importing another service's module would require a
`replace` directive — the review must reject any `replace ../` in `go.mod`.

## Recommended project structure

```text
Kotlin  com/commerceflow/<context>/{domain,application,adapters/in/{web,messaging},adapters/out/{persistence,messaging,http},config}
Go      cmd/<service>/  internal/{domain,application,adapters/{http,kafka,postgres,redis},platform}
```

## Best practices

- One use case per class/file; name it with a verb (`ReserveStock`).
- Commands and results are plain data, not HTTP DTOs or JPA entities.
- Map at the edges: DTO ↔ command in controllers, entity ↔ aggregate in repositories.
- Keep JPA entities in `adapters/out/persistence`, separate from domain classes.
- Time and IDs are injected (`Clock`, ID supplier) for deterministic tests.

## Anti-patterns

- JPA `@Entity` annotations on domain classes.
- Controllers calling repositories directly.
- Use cases returning `ResponseEntity` or Kafka records.
- "Utils" packages shared across layers or services.
- Skipping ports "because there is only one implementation" — the test double is the second.

## Failure scenarios

| Scenario | Effect | Prevention |
|---|---|---|
| Framework type leaks into domain | Domain tests need Spring context, slow & brittle | ArchUnit rule fails build |
| Adapter calls another adapter | Hidden coupling, transaction confusion | Rule: adapters depend on ports only |
| Service imports another service | Deploy coupling | Package rule + `go.mod` review |

## Testing strategy

- Domain: pure unit tests.
- Application: unit tests with in-memory port fakes.
- Adapters: Testcontainers integration tests (`testcontainers`).
- Architecture test runs in every build.

## Definition of Done

- Code placed in the correct layer; dependencies point inward.
- Architecture test present and passing.
- No cross-service imports or `replace` directives.
- Use case testable with fakes, without framework startup.
