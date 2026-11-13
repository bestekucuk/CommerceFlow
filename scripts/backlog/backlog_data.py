"""Single source of truth for the CommerceFlow backlog (rendered into backlog/*.md)."""

# Status values: "Done" (verified in this repository, evidence given), "In progress",
# "Blocked", "Not started". Nothing is Done without evidence.

PHASES = {
    1: "Engineering foundation", 2: "Claude Code framework", 3: "Local infrastructure",
    4: "Product Service and CDC", 5: "Inventory and Customer", 6: "Order and Payment",
    7: "Saga and asynchronous workflows", 8: "Admin Dashboard", 9: "Storefront",
    10: "Complete testing", 11: "Observability and security", 12: "Kubernetes and production readiness",
}

EPICS = {
    "CF-EPIC-01": ("Engineering Foundation", "Monorepo, architecture decisions, documentation, per-component builds and contract tooling.", [1]),
    "CF-EPIC-02": ("Claude Code Agent Framework", "Agents, skills, workflows and hooks that let Claude work safely in the monorepo.", [2]),
    "CF-EPIC-03": ("Local Infrastructure", "Docker Compose stack: PostgreSQL, Kafka, Debezium, Schema Registry, Redis, observability.", [3]),
    "CF-EPIC-04": ("Product Management", "Catalog bounded context: products, SKUs, lifecycle, product events.", [4]),
    "CF-EPIC-05": ("Customer Management", "Customer profiles, addresses, contact events.", [5]),
    "CF-EPIC-06": ("Inventory Management", "Stock, reservations, saga participation.", [5, 7]),
    "CF-EPIC-07": ("Pricing and Promotions", "Prices, price lists, quotes, promotions.", [5, 6]),
    "CF-EPIC-08": ("Order Management", "Order aggregate, order creation, order history, saga orchestration.", [6, 7]),
    "CF-EPIC-09": ("Payment Management", "Provider adapter, authorization, void, refund.", [6, 7]),
    "CF-EPIC-10": ("Shipping Management", "Shipments, carrier adapter, tracking.", [7]),
    "CF-EPIC-11": ("Notification Processing", "Customer notifications from order, payment and shipment events.", [7]),
    "CF-EPIC-12": ("Event Driven Architecture", "Contracts, schema registry, compatibility, outbox/CDC, DLT tooling.", [4, 7]),
    "CF-EPIC-13": ("Admin Dashboard", "Back-office UI through the admin BFF.", [8]),
    "CF-EPIC-14": ("Storefront", "Customer UI, catalog read model, checkout.", [9]),
    "CF-EPIC-15": ("Testing and Quality", "Architecture, contract, integration, E2E, performance and resilience tests.", [10]),
    "CF-EPIC-16": ("Observability", "Tracing, metrics, logs, dashboards, alerts, SLOs.", [11]),
    "CF-EPIC-17": ("Security", "Identity, authorization, secrets, scanning, threat models.", [8, 11]),
    "CF-EPIC-18": ("Production Readiness", "CI/CD, Helm, Kubernetes, Terraform, DR, retention.", [12]),
}

# feature id -> (epic, title)
FEATURES = {
    "F-01": ("CF-EPIC-01", "Repository and architecture baseline"),
    "F-02": ("CF-EPIC-01", "Per-component builds and scaffolds"),
    "F-03": ("CF-EPIC-01", "Contract code generation"),
    "F-04": ("CF-EPIC-02", "Agent team, skills and workflows"),
    "F-05": ("CF-EPIC-02", "Guardrail hooks"),
    "F-06": ("CF-EPIC-03", "Local Compose stack"),
    "F-07": ("CF-EPIC-03", "Local CDC pipeline"),
    "F-08": ("CF-EPIC-04", "Product catalog API"),
    "F-09": ("CF-EPIC-04", "Product events via CDC (vertical slice)"),
    "F-10": ("CF-EPIC-05", "Customer profile"),
    "F-11": ("CF-EPIC-06", "Stock projection and adjustments"),
    "F-12": ("CF-EPIC-06", "Reservations for the saga"),
    "F-13": ("CF-EPIC-07", "Prices and quotes"),
    "F-14": ("CF-EPIC-08", "Order creation and history"),
    "F-15": ("CF-EPIC-08", "Order saga"),
    "F-16": ("CF-EPIC-09", "Payment authorization and compensation"),
    "F-17": ("CF-EPIC-10", "Shipments"),
    "F-18": ("CF-EPIC-11", "Notifications"),
    "F-19": ("CF-EPIC-12", "Contracts and compatibility"),
    "F-20": ("CF-EPIC-12", "Operability of the event pipeline"),
    "F-21": ("CF-EPIC-13", "Admin access and management screens"),
    "F-22": ("CF-EPIC-14", "Catalog browsing"),
    "F-23": ("CF-EPIC-14", "Checkout and order tracking"),
    "F-24": ("CF-EPIC-15", "Automated test layers"),
    "F-25": ("CF-EPIC-16", "Telemetry and SLOs"),
    "F-26": ("CF-EPIC-17", "Identity and authorization"),
    "F-27": ("CF-EPIC-17", "Supply chain and secrets"),
    "F-28": ("CF-EPIC-18", "CI/CD per component"),
    "F-29": ("CF-EPIC-18", "Cluster and cloud"),
    "F-30": ("CF-EPIC-18", "Operations and data governance"),
}

GENERAL_DOD = "general DoD"

# MVP: the basic sales flow, run locally on Docker Compose. Staff enter products, prices
# and stock (admin-web, no login yet); customers browse, add to a cart in the browser,
# check out as guests and follow the order status; the order saga reserves stock,
# authorizes a fake payment and confirms, or compensates. Not in the MVP: login,
# shipping, notifications, real payment provider, production deployment.
MVP = {"CF-002", "CF-014", "CF-038", "CF-047", "CF-048", "CF-049", "CF-052", "CF-053",
       "CF-055", "CF-056", "CF-057", "CF-010", "CF-011", "CF-066", "CF-073", "CF-074"}

# Each task:
# id, feature, phase, title, owner, priority, deps, status, evidence,
# description, acceptance (list), agent, skills (list), tests (list), dod (list, task specific)
T = []


def task(id, feature, phase, title, owner, prio, deps, status, description, acceptance, agent, skills, tests,
         dod, evidence=""):
    T.append(dict(id=id, feature=feature, phase=phase, title=title, owner=owner, prio=prio, deps=deps,
                  status=status, description=description, acceptance=acceptance, agent=agent, skills=skills,
                  tests=tests, dod=dod, evidence=evidence))


# ---------------------------------------------------------------- Phase 1
task("CF-030", "F-01", 1, "Modular monorepo layout and root guides", "repository", "P0", [], "Done",
     "One Git repository with services/, apps/, contracts/, infrastructure/, tests/, docs/ and root CLAUDE.md/README.",
     ["Exactly one .git at the root", "Root CLAUDE.md states independence rules"],
     "commerce-architect", ["microservice-design"], ["none (structure)"], ["ADR-0004 accepted"],
     evidence="commit 2eabbd6; no nested .git verified 2026-11-12")
task("CF-031", "F-01", 1, "Architecture documentation set", "docs", "P0", ["CF-030"], "Done",
     "System, data, event, API and quality architecture documents with Mermaid diagrams and ADRs 0005-0011.",
     ["All documents carry Implemented/Planned/Open status", "22 Mermaid diagrams render", "No invented performance targets"],
     "commerce-architect", ["architecture-decision-records"], ["doc validator", "Mermaid parse+render"], ["Links resolve"],
     evidence="22/22 diagrams rendered with Mermaid 10.9.1; doc validator passed (not yet committed)")
task("CF-001", "F-01", 1, "Accept or revise ADRs 0005-0011", "docs", "P0", ["CF-031"], "Not started",
     "Project owner reviews the Proposed ADRs (database per service, outbox, Debezium, Kafka, saga, gateway/BFF, independent deployment).",
     ["Each ADR is Accepted, revised or rejected by the owner", "ADR index reflects the decision"],
     "commerce-architect", ["architecture-decision-records"], ["none (decision)"], ["Owner decision recorded in each ADR"])
task("CF-021", "F-02", 1, "Per-component build and test scripts", "scripts", "P0", ["CF-030"], "Done",
     "build-service, test-service, build-all, test-all and affected-components scripts; each component builds with its own tooling.",
     ["Building one component never builds another", "Failures in one component do not stop *-all scripts"],
     "devops-engineer", ["github-actions-cicd"], ["scripts executed for all 10 components"], ["Documented in docs/service-catalog.md"],
     evidence="all 10 components built and tested via the scripts on 2026-11-12 (not yet committed)")
task("CF-032", "F-02", 1, "Buildable scaffolds for 8 services and 2 apps", "services/*, apps/*", "P0", ["CF-021"], "Done",
     "Spring Boot/Go/React scaffolds with health and readiness, migration baselines, tests and Dockerfiles.",
     ["Each component builds and tests from its folder", "Each produces its own image", "No shared runtime library"],
     "devops-engineer", ["kotlin-springboot", "golang-development", "react-typescript", "docker-kubernetes"],
     ["unit + Testcontainers integration (services)", "Vitest (apps)"], ["Images built"],
     evidence="5x Kotlin build + 3/3 ArchUnit + 2/2 IT; 3x Go vet/test/IT; 2x web build + 1/1 test; 10/10 images (not yet committed)")
task("CF-003", "F-03", 1, "Contract code generation tooling", "contracts, services", "P0", ["CF-032"], "In progress",
     "Choose and wire Avro code generation from contracts/events for Kotlin (Gradle plugin) and Go, and OpenAPI client generation for apps.",
     ["Kotlin build generates classes from ../../contracts/events", "Go generation runs via go generate", "Generated code is never committed", "Docker builds use --build-context contracts"],
     "event-driven-engineer", ["schema-evolution", "kotlin-springboot", "golang-development"], ["build of product-service and inventory-service with one sample schema"],
     ["Decision recorded (ADR or contracts README)"],
     evidence="Kotlin Avro codegen from ../../contracts in product-service (Gradle + Docker build context); Go decodes with the registry writer schema (no codegen); OpenAPI client generation for apps open")
task("CF-004", "F-29", 12, "Choose cloud provider and Terraform state backend", "infrastructure", "P2", ["CF-001"], "Not started",
     "Decide provider, managed vs self-run PostgreSQL/Kafka/Redis, registry, Terraform location and state.",
     ["ADR written and accepted", "Managed PostgreSQL supports logical replication and slot management"],
     "commerce-architect", ["architecture-decision-records"], ["none (decision)"], ["ADR accepted"])

# ---------------------------------------------------------------- Phase 2
task("CF-033", "F-04", 2, "Claude Code agent team", ".claude/agents", "P0", ["CF-030"], "Done",
     "Ten least-privilege agents with ownership, workflow and DoD.",
     ["Frontmatter valid", "Reviewers have no write tools"], "commerce-architect", ["code-review"],
     ["agent validator"], ["Catalogued in docs/agent-catalog.md"], evidence="commit f32d821; validator passed")
task("CF-034", "F-04", 2, "Engineering skills library and workflows", ".claude/skills", "P0", ["CF-033"], "Done",
     "31 knowledge skills and 12 workflow skills.", ["12 sections per knowledge skill", "10 sections per workflow"],
     "commerce-architect", ["architecture-decision-records"], ["skill validator"], ["Catalogued"],
     evidence="commits e377ee9, d2a656a; validator passed")
task("CF-035", "F-05", 2, "Guardrail hooks with tests", ".claude/hooks", "P0", ["CF-034"], "Done",
     "Destructive-command guard, secret detection, formatting, architecture-docs and test-reminder hooks.",
     ["Hook suite passes", "No false positives on repository files"], "devops-engineer", ["security-review"],
     ["Test-Hooks.ps1"], ["Documented in docs/hook-catalog.md"], evidence="85/85 hook tests on 2026-11-12")
task("CF-036", "F-05", 2, "Observe hooks in a live Claude session", ".claude/hooks", "P3", ["CF-035"], "In progress",
     "Confirm each hook fires through Claude Code (not only via recorded payloads).",
     ["A denied command, a secret write and a Stop reminder observed in a session transcript"],
     "test-engineer", ["code-review"], ["manual session check"], ["Result added to docs/hook-catalog.md"],
     evidence="detect-secrets ran on a real commit; Stop hooks (remind-tests, architecture-docs A1) fired live and were satisfied; deny/ask not yet observed live")

# ---------------------------------------------------------------- Phase 3
task("CF-005", "F-06", 3, "Local Compose infrastructure stack", "infrastructure", "P0", ["CF-032"], "Done",
     "PostgreSQL (8 databases, per-service roles), Kafka, Connect/Debezium, Schema Registry, Kafka UI, Redis, OTel, Prometheus, Grafana, Loki, Tempo.",
     ["up.ps1 brings every container to healthy", "health.ps1 passes", "No credentials in files except local .env.example"],
     "devops-engineer", ["docker-kubernetes", "observability"], ["infrastructure/scripts/health.ps1"],
     ["Verification log in infrastructure/README.md filled"],
     evidence="up.ps1 + health.ps1 all checks passed 2026-11-12; verification log in infrastructure/README.md")
task("CF-037", "F-07", 3, "Verify CDC end to end locally", "infrastructure", "P0", ["CF-005"], "Done",
     "Run migrate, register-connectors and verify-cdc for product-service.",
     ["verify-cdc.ps1 passes: key, id/eventType/traceparent headers and payload bytes match the outbox row"],
     "event-driven-engineer", ["debezium-cdc", "transactional-outbox"], ["verify-cdc.ps1"],
     ["Result recorded in infrastructure/README.md verification log"],
     evidence="verify-cdc.ps1 passed 2026-11-12 after switching to BinaryDataConverter (ADR-0007)")
task("CF-038", "F-06", 3, "Wire application services and Toxiproxy into Compose", "infrastructure", "P1", ["CF-005", "CF-032"], "In progress",
     "Add the 10 images to Compose (profile `apps`) with env-based config and readiness-based dependencies; add Toxiproxy in front of PostgreSQL/Kafka for resilience tests.",
     ["`docker compose --profile apps up` starts all services healthy", "Each service connects with its own DB role"],
     "devops-engineer", ["docker-kubernetes", "resilience-testing"], ["health.ps1 extended to services"], ["README updated"],
     evidence="product-service and inventory-service in the `apps` profile, healthy; 8 components and Toxiproxy remain")
task("CF-039", "F-20", 3, "Expose Kafka Connect/Debezium metrics", "infrastructure", "P2", ["CF-005"], "Not started",
     "JMX exporter for Connect; dashboard panels for connector state and streaming lag.",
     ["Prometheus scrapes Connect metrics", "Dashboard shows connector state"], "devops-engineer", ["observability", "debezium-cdc"],
     ["Prometheus target up"], ["Dashboard committed"])

# ---------------------------------------------------------------- Phase 4 (vertical slice start)
task("CF-002", "F-19", 4, "v1 Avro schemas for the core event catalogue", "contracts/events", "P0", ["CF-031"], "In progress",
     "EventMetadata, Money and the 14 core events plus 4 saga commands as .avsc files.",
     ["Schemas match docs/event-catalog/event-catalog.md", "Every schema parses", "Enums have UNKNOWN default"],
     "event-driven-engineer", ["schema-evolution", "kafka-event-driven"], ["Avro parse of every file"],
     ["Catalogue and schemas updated in one commit (hook A1)"],
     evidence="EventMetadata, Money, ProductCreated and the 13 MVP saga messages (incl. 4 commands) written; check_schemas.py 16/16; registered in the local registry (ids 1-14) 2026-11-12. Remaining: ProductUpdated, ProductDiscontinued, ProductPriceChanged, Customer*, OrderCancelled, PaymentRefunded, StockLevelChanged, Shipment*")
task("CF-040", "F-19", 4, "Shared contract compatibility testing", "tests/contract", "P0", ["CF-002", "CF-005"], "Not started",
     "Script and CI job that registers schemas in a local registry and checks BACKWARD compatibility of changed subjects; runs for every consumer and producer affected.",
     ["Changing a field incompatibly fails the check", "Additive change passes", "Job triggered by any contracts/events change"],
     "test-engineer", ["contract-testing", "schema-evolution"], ["positive and negative compatibility fixtures"],
     ["Documented in tests/contract/README.md"])
task("CF-043", "F-08", 4, "product-service: Product aggregate and catalog API", "services/product-service", "P0", ["CF-032"], "Done",
     "OpenAPI spec, Product/SKU aggregate with lifecycle, POST/GET /v1/products, Flyway tables, problem details.",
     ["Spec linted", "Create and read product work against PostgreSQL", "Invariants unit-tested"],
     "kotlin-backend-engineer", ["create-api", "domain-driven-design", "rest-api-design", "database-migrations"],
     ["domain unit tests", "repository and API integration tests (Testcontainers)"], ["code-review approve"],
     evidence="POST/GET /v1/products; spec lint valid; 23 unit tests + ProductApiIT 6/6 (Testcontainers) 2026-11-12; code review approve-with-comments, fixes retested")
task("CF-044", "F-09", 4, "product-service: ProductCreated through the outbox", "services/product-service", "P0", ["CF-043"], "Done",
     "Map domain event to Avro, serialize with registered schema, write outbox row in the same transaction.",
     ["Commit writes exactly one outbox row with topic cf.product.events.v1 and key productId", "Rollback writes none"],
     "kotlin-backend-engineer", ["transactional-outbox", "schema-evolution"], ["outbox atomicity integration test"], ["code-review approve"],
     evidence="needed only the ProductCreated slices of CF-002/CF-003 (dependency narrowed 2026-11-12); OutboxAtomicityIT 3/3; writer schema pinned to the generated class (registry id 1), use.latest.version=false; retested 2026-11-12")
task("CF-045", "F-09", 4, "Vertical slice: product created reaches Kafka via Debezium", "tests/integration", "P0", ["CF-044", "CF-037"], "Done",
     "Create a product through the API on the Compose stack and observe ProductCreated on cf.product.events.v1 with headers and decodable Avro.",
     ["Record key = productId", "Payload decodes with the registered schema", "traceparent header present"],
     "test-engineer", ["playwright-e2e", "debezium-cdc", "distributed-tracing"], ["tests/integration product-cdc test"],
     ["Runs in CI nightly"],
     evidence="needed only the product/inventory part of CF-038 (dependency narrowed 2026-11-12); tests/integration/run-e2e.ps1 PASS 2026-11-12: key, headers, Avro envelope (schema id 1), correlation id, one Tempo trace across both services; not yet in CI (needs CF-020)")

# ---------------------------------------------------------------- Phase 5
task("CF-094", "F-11", 5, "Outbox and inbox retention jobs", "services/*", "P1", ["CF-044", "CF-046"], "Not started",
     "Delete published outbox rows and old inbox rows in batches (per service, own database) after a retention window agreed with ops; outbox rows are only needed until Debezium has read them.",
     ["Outbox/inbox tables stay bounded under load", "Deletion runs in small batches without long locks", "Inbox retention exceeds the maximum redelivery window"],
     "database-engineer", ["transactional-outbox", "idempotent-consumer", "database-migrations"], ["retention job integration test"],
     ["Retention documented in the service README"],
     evidence="raised by the Prompt 09 code review (2026-11-12)")
task("CF-046", "F-11", 5, "inventory-service: consume ProductCreated with inbox and DLT", "services/inventory-service", "P0", ["CF-045"], "Done",
     "Kafka consumer (franz-go), inbox dedupe, bounded retries, DLT, stock_item projection.",
     ["Duplicate delivery creates one stock item", "Poison message lands in DLT", "Offsets committed after DB commit"],
     "golang-backend-engineer", ["idempotent-consumer", "retry-and-dead-letter-queue", "kafka-event-driven"],
     ["duplicate, poison and crash-before-ack tests (Testcontainers Kafka + PostgreSQL)"], ["code-review approve"],
     evidence="inventory consumer: unit + Testcontainers (processing, duplicates, poison -> DLT, permanent data errors -> DLT, transient retries, restart from committed offsets) pass 2026-11-12")
task("CF-047", "F-11", 5, "inventory-service: stock adjustment API", "services/inventory-service", "P1", ["CF-046"], "Not started",
     "Admin endpoint to adjust on-hand stock with ETag; StockLevelChanged event.",
     ["Concurrent adjustments do not lose updates", "StockLevelChanged emitted via outbox"],
     "golang-backend-engineer", ["create-api", "transaction-management"], ["concurrency test"], ["code-review approve"])
task("CF-048", "F-12", 5, "inventory-service: ReserveInventory / ReleaseInventory handlers", "services/inventory-service", "P0", ["CF-046", "CF-002"], "Not started",
     "Atomic reservation, StockReserved/StockReservationFailed/StockReleased replies, idempotent release.",
     ["No oversell under concurrent reservations", "Release replies even when nothing was reserved"],
     "golang-backend-engineer", ["saga-pattern", "transaction-management", "idempotent-consumer"],
     ["concurrency test on last unit", "duplicate command test"], ["code-review approve"])
task("CF-050", "F-10", 5, "customer-service: profile and address API", "services/customer-service", "P1", ["CF-032"], "Not started",
     "Customer profile and addresses with object-level authorization.",
     ["Customer reads and edits only own profile"], "kotlin-backend-engineer", ["create-api", "secure-backend-development"],
     ["API integration tests", "authZ negative tests"], ["code-review approve"])
task("CF-051", "F-10", 5, "customer-service: CustomerRegistered / CustomerContactChanged", "services/customer-service", "P1", ["CF-050", "CF-002"], "Not started",
     "Publish customer facts via outbox; minimal personal data in events.",
     ["Events contain only fields notification needs"], "kotlin-backend-engineer", ["transactional-outbox", "create-domain-event"],
     ["outbox integration test"], ["security-audit on PII fields"])
task("CF-052", "F-13", 5, "pricing-service: prices with ETag and ProductPriceChanged", "services/pricing-service", "P0", ["CF-045"], "In progress",
     "Consume ProductCreated, manage prices (PUT with If-Match), publish ProductPriceChanged.",
     ["412 on stale ETag", "One ProductPriceChanged per committed change"], "kotlin-backend-engineer",
     ["create-api", "idempotent-consumer", "transactional-outbox"], ["consumer and API integration tests"], ["code-review approve"],
     evidence="PUT/GET /v1/prices with ETag/If-Match (412 stale, 428 missing) and list; code review (changes required) fixed; pricing-service unit 12/12, IT 12/12 on 2026-11-12. Not yet: ProductCreated consumer, ProductPriceChanged via outbox")

# ---------------------------------------------------------------- Phase 6
task("CF-053", "F-13", 6, "pricing-service: price quote API", "services/pricing-service", "P0", ["CF-052"], "In progress",
     "POST /v1/quotes returns a quote with expiry for SKUs and quantities.",
     ["Quote is stored and referenced by id", "Expired quotes are rejected"], "kotlin-backend-engineer", ["create-api"],
     ["API tests", "Pact provider verification for order-service"], ["code-review approve"],
     evidence="POST/GET /v1/quotes: stored, 15 min TTL, totals in minor units, 422 for unpriced SKUs/mixed currencies; server-computed expired flag; PricingApiIT 2026-11-12, review fixes retested. Expiry is enforced by order-service (CF-055); Pact pending")
task("CF-014", "F-14", 6, "Decide cart ownership", "docs", "P1", ["CF-001"], "In progress",
     "order-service vs dedicated context vs client-side cart.", ["ADR accepted"], "commerce-architect",
     ["microservice-design", "architecture-decision-records"], ["none (decision)"], ["ADR accepted"],
     evidence="MVP decision ADR-0012 (browser-side cart, guest checkout); the post-MVP cart owner is still open")
task("CF-055", "F-14", 6, "order-service: create order (202, idempotency key) and OrderCreated", "services/order-service", "P0", ["CF-053", "CF-050"], "Not started",
     "POST /v1/orders validates quote and customer, persists PENDING order and saga instance, writes OrderCreated + ReserveInventory to the outbox.",
     ["Retry with same Idempotency-Key returns the same order", "One transaction writes order, saga and outbox rows"],
     "kotlin-backend-engineer", ["create-api", "saga-pattern", "transactional-outbox"],
     ["API + outbox integration tests", "Pact consumer tests against pricing and customer"], ["code-review approve"])
task("CF-056", "F-14", 6, "order-service: order history read model and GET APIs", "services/order-service", "P1", ["CF-055"], "Not started",
     "Customer and admin order queries with cursor pagination.", ["Keyset pagination", "Customers see only own orders"],
     "kotlin-backend-engineer", ["create-api", "postgresql-design"], ["API and authZ tests"], ["code-review approve"])
task("CF-016", "F-16", 6, "Choose payment provider and sandbox; decide capture timing", "services/payment-service", "P1", ["CF-001"], "Not started",
     "Provider selection, sandbox access and capture policy (CF-028 merged).", ["ADR accepted", "Card data never touches CommerceFlow"],
     "commerce-architect", ["architecture-decision-records", "security-review"], ["none (decision)"], ["ADR accepted"])
task("CF-057", "F-16", 6, "payment-service: AuthorizePayment / VoidPayment with provider adapter", "services/payment-service", "P0", ["CF-002", "CF-032"], "Not started",
     "Anti-corruption adapter (stub until CF-016), idempotency keys toward the provider, PaymentAuthorized/Failed/Voided replies.",
     ["Duplicate command authorizes once", "Void replies even when nothing was authorized"],
     "kotlin-backend-engineer", ["saga-pattern", "domain-driven-design", "secure-backend-development"],
     ["handler integration tests with provider stub", "duplicate command test"], ["security-audit approve"])

# ---------------------------------------------------------------- Phase 7
task("CF-010", "F-15", 7, "Order saga happy path end to end", "services/order-service + inventory + payment", "P0", ["CF-055", "CF-048", "CF-057", "CF-038"], "Not started",
     "Order reaches CONFIRMED through StockReserved and PaymentAuthorized on the Compose stack.",
     ["Order CONFIRMED with one reservation and one authorization", "One trace spans order, inventory and payment"],
     "commerce-architect", ["implement-feature", "saga-pattern"], ["tests/integration saga happy path"], ["code-review approve"])
task("CF-011", "F-15", 7, "Saga compensation and timeouts", "services/order-service + inventory + payment", "P0", ["CF-010"], "Not started",
     "Failure and timeout transitions, VoidPayment/ReleaseInventory, late replies ignored.",
     ["Every path in communication-patterns.md state machine reaches a terminal state"],
     "kotlin-backend-engineer", ["saga-pattern", "resilience-testing"], ["Toxiproxy scenarios R3, R4, R6", "transition-table unit tests"], ["code-review approve"])
task("CF-059", "F-15", 7, "Stuck-saga metric and saga status endpoint", "services/order-service", "P1", ["CF-010"], "Not started",
     "commerceflow_sagas_past_deadline metric and an admin read endpoint for saga state.", ["Metric exposed", "Endpoint authorized for ROLE_ORDER_ADMIN"],
     "kotlin-backend-engineer", ["observability", "create-api"], ["metric unit test", "API test"], ["Alert rule drafted"])
task("CF-062", "F-15", 7, "Cancel a confirmed order (OrderCancelled flow)", "order + inventory + payment + shipping", "P1", ["CF-010", "CF-060"], "Not started",
     "Cancellation API, OrderCancelled consumers: release stock, refund, stop shipment.",
     ["Refund once per order", "Shipment stopped if not dispatched"], "commerce-architect", ["implement-feature", "saga-pattern"],
     ["tests/integration cancellation flow"], ["code-review approve"])
task("CF-049", "F-12", 7, "inventory-service: commit reservation on OrderConfirmed and expiry", "services/inventory-service", "P1", ["CF-048", "CF-010"], "Not started",
     "Committed reservations never expire; unconfirmed ones expire and release.", ["Confirmed order stock never released by expiry"],
     "golang-backend-engineer", ["saga-pattern", "transaction-management"], ["expiry job test"], ["code-review approve"])
task("CF-060", "F-17", 7, "shipping-service: shipment from OrderConfirmed", "services/shipping-service", "P1", ["CF-010"], "Not started",
     "Consume OrderConfirmed, create shipment, publish ShipmentCreated.", ["One shipment per order"],
     "golang-backend-engineer", ["idempotent-consumer", "transactional-outbox"], ["consumer integration test"], ["code-review approve"])
task("CF-061", "F-17", 7, "shipping-service: carrier adapter stub and tracking events", "services/shipping-service", "P2", ["CF-060"], "Not started",
     "Carrier ACL (stub), ShipmentDispatched/ShipmentDelivered with webhook dedupe.", ["Duplicate webhook publishes once"],
     "golang-backend-engineer", ["domain-driven-design", "secure-backend-development"], ["webhook tests"], ["security-audit approve"])
task("CF-063", "F-18", 7, "notification-service: email notifications for order lifecycle", "services/notification-service", "P1", ["CF-010", "CF-051"], "Not started",
     "Consumers for order/payment/shipment events, templates, delivery via a local SMTP catcher.",
     ["One email per event and channel", "Non-blocking retries; ordering not required"],
     "golang-backend-engineer", ["idempotent-consumer", "retry-and-dead-letter-queue"], ["consumer integration tests"], ["code-review approve"])
task("CF-042", "F-20", 7, "DLT replay tool", "scripts", "P1", ["CF-046"], "Not started",
     "Read DLT, re-publish to original topic with same key and id header, record progress; user-approved operation.",
     ["Replayed message processed once (inbox)"], "event-driven-engineer", ["retry-and-dead-letter-queue"], ["replay integration test"], ["Runbook written"])
task("CF-023", "F-20", 7, "Runbooks: slot growth, DLT replay, stuck saga, registry rejects schema", "docs/runbooks", "P1", ["CF-042", "CF-059"], "Not started",
     "Operational procedures linked from alerts.", ["Each alert links a runbook"], "devops-engineer", ["debug-event-flow", "observability"],
     ["dry run of each runbook locally"], ["Reviewed by event-driven-engineer"])

# ---------------------------------------------------------------- Phase 8
task("CF-065", "F-26", 8, "Local identity provider (Keycloak) and roles", "infrastructure", "P0", ["CF-005"], "Not started",
     "Keycloak in Compose with realm, clients (storefront PKCE, admin BFF, service clients) and roles from authentication-authorization.md.",
     ["Tokens carry correct issuer, audience and roles", "No credentials committed"], "devops-engineer", ["secure-backend-development"],
     ["token issuance smoke test"], ["security-audit approve"])
task("CF-068", "F-26", 8, "JWT resource server in every service", "services/*", "P0", ["CF-065"], "Not started",
     "Issuer, audience and algorithm validation; function- and object-level authorization.",
     ["401/403/404 negative tests pass for every protected endpoint"], "kotlin-backend-engineer", ["secure-backend-development", "security-audit"],
     ["security slice tests per service"], ["security-audit approve"])
task("CF-024", "F-21", 8, "API gateway and admin BFF", "apps/admin-web, infrastructure", "P0", ["CF-065", "CF-001"], "Not started",
     "Gateway routing, rate and size limits, CORS; admin BFF with token handler and read composition via service APIs only.",
     ["BFF has no business database", "Admin browser holds no tokens"], "frontend-engineer", ["admin-dashboard-development", "secure-backend-development"],
     ["BFF integration tests", "gateway routing tests"], ["security-audit approve"])
task("CF-064", "F-21", 8, "admin-web: login and role-gated routes", "apps/admin-web", "P1", ["CF-024"], "Not started",
     "Login via BFF, session handling, RequireRole routes.", ["Routes redirect without role"], "frontend-engineer",
     ["admin-dashboard-development", "react-typescript"], ["component tests", "Playwright login test"], ["a11y checks"])
task("CF-066", "F-21", 8, "admin-web: catalog and price management", "apps/admin-web", "P1", ["CF-064", "CF-043", "CF-052"], "Not started",
     "Paginated product list, product edit, price edit with ETag conflict handling.", ["412 shows conflict dialog"], "frontend-engineer",
     ["admin-dashboard-development", "contract-testing"], ["component tests", "Pact consumer tests"], ["code-review approve"])
task("CF-067", "F-21", 8, "admin-web: orders and saga status", "apps/admin-web", "P2", ["CF-064", "CF-059"], "Not started",
     "Order list, order detail with saga state, cancellation with confirmation.", ["Destructive action confirmed"],
     "frontend-engineer", ["admin-dashboard-development"], ["component tests", "Pact consumer tests"], ["code-review approve"])

# ---------------------------------------------------------------- Phase 9
task("CF-015", "F-22", 9, "Decide catalog read model ownership", "docs", "P1", ["CF-001"], "Not started",
     "Where the product+price+availability read model lives.", ["ADR accepted"], "commerce-architect",
     ["microservice-design", "architecture-decision-records"], ["none (decision)"], ["ADR accepted"])
task("CF-072", "F-22", 9, "Catalog read model", "per CF-015", "P1", ["CF-015", "CF-052", "CF-047"], "Not started",
     "Projection from ProductCreated/Updated, ProductPriceChanged, StockLevelChanged; rebuildable by replay.",
     ["Replay into a new group rebuilds the model"], "golang-backend-engineer", ["idempotent-consumer", "kafka-event-driven"],
     ["projection and replay tests"], ["code-review approve"])
task("CF-073", "F-22", 9, "storefront-web: browse and product detail", "apps/storefront-web", "P1", ["CF-072", "CF-024"], "Not started",
     "Product list and detail via gateway with generated clients.", ["Loading/empty/error states", "Keyboard accessible"],
     "frontend-engineer", ["react-typescript", "contract-testing"], ["component tests", "Pact consumer tests"], ["a11y checks"])
task("CF-074", "F-23", 9, "storefront-web: checkout and order status", "apps/storefront-web", "P0", ["CF-055", "CF-065", "CF-014"], "Not started",
     "Checkout with idempotency key reuse on retry, 202 handling and status polling.", ["Double click creates one order"],
     "frontend-engineer", ["react-typescript", "playwright-e2e"], ["component tests", "Playwright checkout journey"], ["code-review approve"])
task("CF-075", "F-23", 9, "storefront-web: order history", "apps/storefront-web", "P2", ["CF-056", "CF-074"], "Not started",
     "Paginated history of own orders.", ["Only own orders visible"], "frontend-engineer", ["react-typescript"],
     ["component tests", "Pact consumer test"], ["code-review approve"])

# ---------------------------------------------------------------- Phase 10
task("CF-022", "F-24", 10, "Architecture tests in every service", "services/*", "P1", ["CF-032"], "In progress",
     "Fail builds on layer violations and cross-service imports.", ["Kotlin ArchUnit rules", "Go import test per service"],
     "test-engineer", ["clean-architecture"], ["deliberate violation fails the build"], ["code-review approve"],
     evidence="ArchUnit rules run in all 5 Kotlin services (3/3 each); Go import tests not written yet")
task("CF-017", "F-24", 10, "Pact consumer/provider and broker", "apps, services, tests/contract", "P1", ["CF-073", "CF-055"], "Not started",
     "Local Pact broker, consumer pacts from apps and order-service, provider verification, can-i-deploy.",
     ["Removing a used field fails provider verification"], "test-engineer", ["contract-testing"], ["provider verification jobs"], ["Documented"])
task("CF-076", "F-24", 10, "Cross-service integration suite", "tests/integration", "P1", ["CF-010", "CF-038"], "Not started",
     "Saga, cancellation and CDC flows against Compose, bounded polling.", ["Suite runs from one command"], "test-engineer",
     ["write-tests", "testcontainers"], ["the suite itself"], ["Runs nightly"])
task("CF-077", "F-24", 10, "Cross-app Playwright journeys", "tests/e2e", "P2", ["CF-066", "CF-074"], "Not started",
     "Admin creates product and price, customer buys it, order confirmed.", ["Journey passes headless with traces"],
     "test-engineer", ["playwright-e2e", "run-e2e"], ["the journey"], ["Report via run-e2e"])
task("CF-018", "F-24", 10, "k6 baselines for browse and checkout", "tests/performance", "P2", ["CF-010", "CF-073"], "Not started",
     "Measure baselines (no thresholds until CF-025).", ["Baseline recorded with environment description"],
     "test-engineer", ["performance-testing"], ["k6 runs"], ["Results in tests/performance/README.md"])
task("CF-078", "F-24", 10, "Resilience scenario catalogue R1-R6", "tests/resilience", "P1", ["CF-011", "CF-038"], "Not started",
     "Toxiproxy scenarios with expected outcomes.", ["Each scenario asserts consistency after recovery"], "test-engineer",
     ["resilience-testing"], ["the scenarios"], ["Nightly"])

# ---------------------------------------------------------------- Phase 11
task("CF-012", "F-25", 11, "OpenTelemetry in all services, trace through outbox", "services/*", "P1", ["CF-045"], "Not started",
     "Java agent / Go SDK, traceparent into outbox and out of Kafka headers, trace ids in logs.",
     ["One trace for a placed order across services in Tempo"], "devops-engineer", ["distributed-tracing", "observability"],
     ["tracing unit test (in-memory exporter)", "Tempo query in integration test"], ["Dashboard links work"])
task("CF-079", "F-25", 11, "Service dashboards and alert rules", "infrastructure/monitoring", "P1", ["CF-012", "CF-059"], "Not started",
     "RED + messaging + business dashboards per service; alert rules with runbook links.", ["promtool check rules passes"],
     "devops-engineer", ["observability"], ["promtool test rules"], ["Runbooks linked"])
task("CF-025", "F-25", 11, "Define SLOs", "docs", "P1", ["CF-018"], "Not started",
     "Latency, availability and saga completion SLOs from business needs and baselines.", ["ADR accepted"], "commerce-architect",
     ["architecture-decision-records", "performance-testing"], ["none (decision)"], ["k6 thresholds read from SLO values"])
task("CF-070", "F-27", 11, "Secret and dependency scanning in CI", ".github/workflows", "P1", ["CF-020"], "Not started",
     "gitleaks, govulncheck, npm audit, Gradle dependency check, Trivy image scan per component.", ["High/critical findings fail the pipeline"],
     "devops-engineer", ["security-review", "github-actions-cicd"], ["seeded vulnerable fixture detected"], ["security-audit approve"])
task("CF-071", "F-26", 11, "Threat model and security audit per release", "all", "P1", ["CF-068", "CF-024"], "Not started",
     "STRIDE review of edge, identity, payment and data flows.", ["No open critical/high findings"], "security-reviewer",
     ["security-audit", "security-review"], ["scanner runs"], ["Findings tracked"])

# ---------------------------------------------------------------- Phase 12
task("CF-020", "F-28", 10, "Reusable CI workflows per language", ".github/workflows", "P1", ["CF-021"], "In progress",
     "_kotlin-service, _go-service, _web-app templates; contracts workflow.", ["actionlint passes", "Runs green on GitHub"],
     "devops-engineer", ["github-actions-cicd"], ["actionlint", "first runs"], ["Documented"],
     evidence="_kotlin-service, _go-service, _web-app + 10 callers + contracts.yml written; actionlint 1.7.7: 0 errors in 14 files (2026-11-12); Avro check passes and fails a seeded bad schema; first GitHub runs pending the owner's push")
task("CF-080", "F-28", 12, "Dependency-aware CI triggering", ".github/workflows", "P1", ["CF-020", "CF-002"], "In progress",
     "Path filters per component include consumed contracts (from the event catalogue); a contract change triggers every producer and consumer pipeline and the compatibility job.",
     ["Changing cf.order events triggers order, inventory, payment, shipping, notification", "Unrelated change triggers nothing else"],
     "devops-engineer", ["github-actions-cicd"], ["affected-components.ps1 parity test"], ["Documented"],
     evidence="path filters per component include consumed/produced contract folders from the event catalogue; parity test with affected-components.ps1 not written")
task("CF-019", "F-29", 12, "Helm chart template and per-service values", "infrastructure/kubernetes", "P1", ["CF-032"], "Not started",
     "One chart template; values per service with probes, resources, security context, secret refs.", ["helm lint/template pass for all 10"],
     "devops-engineer", ["docker-kubernetes"], ["helm template + schema validation"], ["code-review approve"])
task("CF-081", "F-29", 12, "Kubernetes base: namespaces, network policies, quotas", "infrastructure/kubernetes", "P1", ["CF-004"], "Not started",
     "Network policies enforce database-per-service and allowed APIs.", ["Policy test shows a service cannot reach another database"],
     "devops-engineer", ["docker-kubernetes", "security-review"], ["policy tests in a local cluster"], ["security-audit approve"])
task("CF-082", "F-29", 12, "Terraform baseline", "infrastructure", "P2", ["CF-004"], "Not started",
     "Network, cluster, managed data services; state backend.", ["terraform validate and plan succeed against a sandbox account"],
     "devops-engineer", ["docker-kubernetes"], ["terraform validate"], ["No apply by Claude"])
task("CF-083", "F-29", 12, "Production Debezium: heartbeats, failover slots, Connect HA", "infrastructure/debezium", "P1", ["CF-004", "CF-037"], "Not started",
     "Heartbeat action query, failover slot handling, multi-worker Connect.", ["Idle-database slot lag stays bounded in staging"],
     "event-driven-engineer", ["debezium-cdc"], ["staging failover drill"], ["Runbook updated"])
task("CF-027", "F-30", 12, "RPO/RTO, backups and restore drills", "infrastructure", "P1", ["CF-004"], "Not started",
     "Targets agreed with the business, backup topology, restore test.", ["Restore drill meets agreed targets"],
     "devops-engineer", ["observability"], ["restore drill"], ["disaster-recovery.md updated"])
task("CF-026", "F-30", 12, "Data retention with legal input", "docs, services", "P1", ["CF-001"], "Not started",
     "Retention for orders, payments, customer data, backups; erasure flow.", ["Policy approved", "Retention jobs implemented"],
     "commerce-architect", ["architecture-decision-records"], ["retention job tests"], ["data-retention-policy.md updated"])

# Service-level build and deployment tasks (one per component)
COMPONENTS = [
    ("product-service", "kotlin-backend-engineer"), ("order-service", "kotlin-backend-engineer"),
    ("payment-service", "kotlin-backend-engineer"), ("customer-service", "kotlin-backend-engineer"),
    ("pricing-service", "kotlin-backend-engineer"), ("inventory-service", "golang-backend-engineer"),
    ("shipping-service", "golang-backend-engineer"), ("notification-service", "golang-backend-engineer"),
    ("admin-web", "frontend-engineer"), ("storefront-web", "frontend-engineer"),
]
for i, (comp, _) in enumerate(COMPONENTS):
    path = ("apps/" if comp.endswith("-web") else "services/") + comp
    deps = ["CF-020", "CF-019", "CF-080"] + (["CF-040"] if not comp.endswith("-web") else []) + ["CF-017"]
    task(f"CF-{84 + i:03d}", "F-28", 12, f"{comp}: own CI pipeline, image publish and staged deployment", path, "P1", deps, "Not started",
         f"Workflow for {path} using the reusable template: build, unit + integration tests, contract checks, scans, image tagged by git SHA, Helm release to staging then production with approval and can-i-deploy.",
         [f"Only changes under {path} (or its contracts) trigger it", "Image digest promoted unchanged staging → production",
          "Deployment blocked when contract checks fail"],
         "devops-engineer", ["github-actions-cicd", "docker-kubernetes", "contract-testing"],
         ["pipeline dry run", "rollback by redeploying the previous image"], ["No deploy without approval"])
