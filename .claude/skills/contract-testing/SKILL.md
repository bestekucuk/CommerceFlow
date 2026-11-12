---
name: contract-testing
description: Protect CommerceFlow API and event contracts between independently deployed components - Pact consumer tests in the web apps (pact-js), Pact provider verification in Kotlin (JUnit 5) and Go, provider states, a Pact Broker with can-i-deploy, and Avro compatibility checks for Kafka events. Use when a consumer starts calling an API, an API changes, or an event schema changes.
---

# Contract testing

## Purpose

Let each app and service deploy alone while proving it still matches what its consumers
expect. HTTP contracts use Pact; event contracts use Avro + Schema Registry compatibility.

## When to use

- A frontend (or a service) adds or changes an API call.
- A provider changes an endpoint.
- Before deploying any provider or consumer (can-i-deploy).
- Event schema changes (compatibility check, see `schema-evolution`).

## Prerequisites

- OpenAPI spec in `contracts/openapi/` (`rest-api-design`).
- Pact Broker: local container from `tests/contract/` (Compose profile `contract`).
- Owner: `test-engineer`, with consumer tests written by the consumer's engineer.

## Concepts and architecture

```text
apps/storefront-web (consumer test) --writes--> pact file --publish--> Pact Broker
services/order-service (provider verification) <--fetch-- Pact Broker
CI of each component: can-i-deploy --pacticipant X --version <git sha> --to-environment <env>
```

- **Consumer-driven:** consumers specify only what they use (fields, status codes) using
  matchers, not exact values.
- **Provider states:** named preconditions ("order o-1 exists for customer c-1") set up by
  the provider test.
- **Versions:** pacticipant version = git SHA; branch = git branch. One repository, but each
  component is a separate pacticipant, so they still deploy independently.
- **Events:** Pact message pacts are optional; the primary guard is the BACKWARD
  compatibility check of the Avro subject in CI.

## Step-by-step workflow

1. Consumer: write a Pact test per API interaction in the app (or calling service).
2. Run it → pact JSON in `apps/<app>/pacts/`.
3. Publish to the broker with the git SHA and branch.
4. Provider: verification test fetches pacts for its pacticipant from the broker, sets
   provider states, runs against the real app (with Testcontainers DB).
5. Publish verification results.
6. Gate deployments with `can-i-deploy`.

## Practical code examples

Consumer test (storefront-web, `@pact-foundation/pact` v12+, Vitest):

```ts
import { PactV3, MatchersV3 } from "@pact-foundation/pact";
import path from "node:path";
import { createOrderClient } from "../src/api/orderClient";

const { like, uuid, eachLike, integer } = MatchersV3;

const provider = new PactV3({
  consumer: "storefront-web",
  provider: "order-service",
  dir: path.resolve(process.cwd(), "pacts"),
});

it("places an order", async () => {
  provider
    .given("sku SKU-1 is sellable")
    .uponReceiving("a request to place an order")
    .withRequest({
      method: "POST",
      path: "/v1/orders",
      headers: { "Content-Type": "application/json", "Idempotency-Key": like("k-1"), Authorization: like("Bearer token") },
      body: { lines: eachLike({ sku: "SKU-1", quantity: integer(1) }) },
    })
    .willRespondWith({
      status: 202,
      headers: { "Content-Type": "application/json" },
      body: { orderId: uuid("0190d1c4-6b8c-7c3e-9f5e-1a2b3c4d5e6f"), status: like("PENDING") },
    });

  await provider.executeTest(async (mock) => {
    const client = createOrderClient(mock.url, async () => "token");
    const result = await client.placeOrder([{ sku: "SKU-1", quantity: 1 }], "k-1");
    expect(result.status).toBe("PENDING");
  });
});
```

Publish (CI, from the app folder):

```bash
npx pact-broker publish pacts --consumer-app-version "$GITHUB_SHA" --branch "$GITHUB_REF_NAME" \
  --broker-base-url "$PACT_BROKER_URL"
```

Provider verification (order-service, `au.com.dius.pact.provider:junit5spring`):

```kotlin
@Provider("order-service")
@PactBroker(url = "\${PACT_BROKER_URL:http://localhost:9292}")
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@Tag("contract")
class OrderServicePactVerificationIT : IntegrationTest() {

    @LocalServerPort var port = 0
    @Autowired lateinit var fixtures: ProviderStateFixtures

    @BeforeEach
    fun target(context: PactVerificationContext) {
        context.target = HttpTestTarget("localhost", port)
    }

    @TestTemplate
    @ExtendWith(PactVerificationSpringProvider::class)
    fun verify(context: PactVerificationContext, request: ClassicHttpRequest) {
        request.setHeader("Authorization", "Bearer ${TestTokens.customer("c-1")}")  // provider-side valid token
        context.verifyInteraction()
    }

    @State("sku SKU-1 is sellable")
    fun skuSellable() = fixtures.priceQuote("SKU-1", 1299)
}
```

Set `pact.verifier.publishResults=true` and `pact.provider.version=$GITHUB_SHA` in CI.

Go provider verification (`github.com/pact-foundation/pact-go/v2/provider`):

```go
func TestPactProvider(t *testing.T) {
	srv := startServiceForTest(t) // real handlers, Testcontainers DB
	verifier := provider.NewVerifier()
	err := verifier.VerifyProvider(t, provider.VerifyRequest{
		Provider:                   "inventory-service",
		ProviderBaseURL:            srv.URL,
		BrokerURL:                  os.Getenv("PACT_BROKER_URL"),
		PublishVerificationResults: os.Getenv("CI") == "true",
		ProviderVersion:            os.Getenv("GITHUB_SHA"),
		StateHandlers: models.StateHandlers{
			"SKU-1 has 5 units": func(setup bool, s models.ProviderState) (models.ProviderStateResponse, error) {
				if setup {
					seedStock(t, "SKU-1", 5)
				}
				return nil, nil
			},
		},
	})
	if err != nil {
		t.Fatal(err)
	}
}
```

Deployment gate:

```bash
npx pact-broker can-i-deploy --pacticipant order-service --version "$GITHUB_SHA" --to-environment staging
```

## Recommended project structure

```text
apps/<app>/tests/pact/*.pact.test.ts     consumer tests
apps/<app>/pacts/                        generated pact files (gitignored)
services/<svc>/src/test/.../*PactVerificationIT.kt | *_pact_test.go
tests/contract/                          broker compose profile, CI scripts, Avro compatibility job
```

## Best practices

- Match types and shapes, not exact values.
- One interaction per behaviour; name provider states in business terms.
- Provider states use the service's own APIs/repositories, not raw SQL into other services.
- Run provider verification in the provider's own pipeline (path-filtered) and on new pacts
  via webhook.
- Never let a consumer test pass against a hand-written stub server instead of the Pact mock.

## Anti-patterns

- Pacts that assert entire response bodies with exact values.
- Provider verification against a mocked service layer.
- Sharing pact files by relative path into another component's build.
- Skipping can-i-deploy "because it's one repo".

## Failure scenarios

| Scenario | Outcome |
|---|---|
| Provider removes a field a consumer uses | Verification fails in provider CI → change blocked. |
| Consumer expects a new field not yet built | can-i-deploy blocks consumer until provider version with it is deployed. |
| Broker down | CI fails closed for deploy gates; local tests still produce pacts. |
| Provider state missing | Verification fails with "no state handler" → add it. |

## Testing strategy

- Consumer Pact tests in each app's unit suite.
- Provider verification in each provider's integration suite.
- Avro compatibility checks for changed subjects in `tests/contract` CI.

## Definition of Done

- Every API interaction of the consumer covered by a Pact test.
- Provider verifies all consumer pacts with provider states.
- Results published; can-i-deploy used in deployment pipelines.
- Event schema changes pass compatibility checks.
