---
name: rest-api-design
description: Design and implement CommerceFlow HTTP APIs API-first in contracts/openapi (one spec per service) - resources, versioning, RFC 9457 problem details, cursor pagination, idempotency keys, optimistic concurrency with ETags, status codes - and implement them in Kotlin or Go. Use when adding or changing any endpoint.
---

# REST API design

## Purpose

Consistent, evolvable HTTP APIs that frontends and (rarely) other services can rely on.
The OpenAPI document in `contracts/openapi/` is the contract; the service implements it
and consumers generate clients from it.

## When to use

- Adding, changing or deprecating an endpoint.
- Generating clients for `apps/*`.
- Reviewing error handling, pagination or retries of an API.

## Prerequisites

- `microservice-design` (is HTTP justified?), `secure-backend-development`.
- Owner: the service's language engineer; breaking changes need a `commerce-architect` plan.

## Concepts and architecture

| Concern | Convention |
|---|---|
| Base path | `/v1/...` per service; major version in path. |
| Resources | Plural nouns: `/v1/orders/{orderId}`, sub-resources for ownership: `/v1/orders/{id}/lines`. |
| Actions | State transitions as sub-resources: `POST /v1/orders/{id}/cancellation`. |
| IDs | UUIDs as strings; never database sequences. |
| Money | `{ "amountMinor": 1299, "currency": "EUR" }`. |
| Errors | `application/problem+json` (RFC 9457) with `type`, `title`, `status`, `detail`, `instance`, plus `errors[]` for validation. |
| Pagination | Cursor: `?limit=50&cursor=...` → `{ items, nextCursor }`. |
| Idempotency | `Idempotency-Key` header required on non-idempotent POSTs that create resources. |
| Concurrency | `ETag` on GET, `If-Match` required on PUT/PATCH/DELETE → `412` on mismatch. |
| Async results | `202 Accepted` + `Location` of a status resource (order placement is async). |

Status codes: 200, 201 (+ `Location`), 202, 204, 400 (malformed), 401, 403, 404, 409
(state conflict), 412, 422 (business rule), 429, 503.

## Step-by-step workflow

1. Write or extend `contracts/openapi/<service>.v1.yaml` first.
2. Classify the change: additive (new optional field, new endpoint) vs breaking (removed
   or renamed field, changed type, new required input) → breaking means `/v2`.
3. Lint the spec (`npx @redocly/cli lint contracts/openapi/<service>.v1.yaml`).
4. Implement controller/handler mapping DTO → command (`clean-architecture`).
5. Implement problem-details error mapping.
6. Add provider verification for consumer pacts (`contract-testing`).
7. Regenerate clients in the affected app(s) (frontend task).

## Practical code examples

OpenAPI excerpt (`contracts/openapi/order-service.v1.yaml`):

```yaml
openapi: 3.1.0
info: { title: order-service, version: 1.0.0 }
paths:
  /v1/orders:
    post:
      operationId: placeOrder
      parameters:
        - in: header
          name: Idempotency-Key
          required: true
          schema: { type: string, maxLength: 64 }
      requestBody:
        required: true
        content:
          application/json:
            schema: { $ref: "#/components/schemas/PlaceOrderRequest" }
      responses:
        "202":
          description: Order accepted, saga started
          headers: { Location: { schema: { type: string } } }
          content: { application/json: { schema: { $ref: "#/components/schemas/OrderSummary" } } }
        "422": { $ref: "#/components/responses/Problem" }
components:
  schemas:
    PlaceOrderRequest:
      type: object
      required: [lines]
      properties:
        lines:
          type: array
          minItems: 1
          items:
            type: object
            required: [sku, quantity]
            properties:
              sku: { type: string }
              quantity: { type: integer, minimum: 1 }
  responses:
    Problem:
      description: Problem details
      content: { application/problem+json: { schema: { $ref: "#/components/schemas/Problem" } } }
```

Kotlin controller + problem details:

```kotlin
@RestController
@RequestMapping("/v1/orders")
class OrderController(private val placeOrder: PlaceOrder) {
    @PostMapping
    fun place(
        @RequestHeader("Idempotency-Key") key: String,
        @Valid @RequestBody body: PlaceOrderRequest,
        @AuthenticationPrincipal jwt: Jwt,
    ): ResponseEntity<OrderSummary> {
        val id = placeOrder.handle(body.toCommand(customerId = UUID.fromString(jwt.subject), idempotencyKey = key))
        return ResponseEntity.accepted().location(URI.create("/v1/orders/${id.value}")).body(OrderSummary(id.value, "PENDING"))
    }
}

@RestControllerAdvice
class ProblemHandler {
    @ExceptionHandler(BusinessRuleViolation::class)
    fun rule(e: BusinessRuleViolation): ProblemDetail =
        ProblemDetail.forStatusAndDetail(HttpStatus.UNPROCESSABLE_ENTITY, e.message ?: "Rule violated").apply {
            type = URI.create("https://commerceflow.dev/problems/${e.code}")
            title = "Business rule violated"
        }
}
```

Enable RFC 9457 responses: `spring.mvc.problemdetails.enabled: true`.

Go handler with problem details:

```go
type Problem struct {
	Type   string `json:"type"`
	Title  string `json:"title"`
	Status int    `json:"status"`
	Detail string `json:"detail,omitempty"`
}

func writeProblem(w http.ResponseWriter, p Problem) {
	w.Header().Set("Content-Type", "application/problem+json")
	w.WriteHeader(p.Status)
	_ = json.NewEncoder(w).Encode(p)
}

func (h *Handler) GetStock(w http.ResponseWriter, r *http.Request) {
	item, err := h.stock.Get(r.Context(), domain.SKU(r.PathValue("sku")))
	switch {
	case errors.Is(err, domain.ErrNotFound):
		writeProblem(w, Problem{Type: "https://commerceflow.dev/problems/not-found", Title: "SKU not found", Status: 404})
		return
	case err != nil:
		writeProblem(w, Problem{Type: "about:blank", Title: "Internal error", Status: 500})
		return
	}
	w.Header().Set("ETag", fmt.Sprintf(`"%d"`, item.Version))
	_ = json.NewEncoder(w).Encode(toDTO(item))
}
```

Idempotency-key store (per service, own table):

```sql
CREATE TABLE idempotency_key (
  key          text PRIMARY KEY,
  request_hash text NOT NULL,
  response     jsonb NOT NULL,
  created_at   timestamptz NOT NULL DEFAULT now()
);
```

Same key + same hash → return stored response; same key + different hash → `422`.

## Recommended project structure

```text
contracts/openapi/<service>.v1.yaml
services/<svc>/.../adapters/in/web/        controllers/handlers, DTOs, error mapping
apps/<app>/src/api/                        generated client (frontend)
```

## Best practices

- API-first: spec change in the same commit as the implementation.
- Never expose domain or JPA classes as DTOs.
- Validate at the edge, enforce invariants in the domain.
- Include `traceparent` propagation and return `X-Request-Id`/trace id in problems' `instance`.
- Deprecate with `Deprecation` and `Sunset` headers before removing a `/v1` endpoint.

## Anti-patterns

- Verbs in paths (`/createOrder`), RPC over POST for everything.
- `200 OK` with an error body.
- Offset pagination on large, changing tables.
- Leaking stack traces or SQL errors in responses.
- Chained synchronous calls between services behind one endpoint.

## Failure scenarios

| Scenario | Handling |
|---|---|
| Client retries POST after timeout | `Idempotency-Key` returns the original result, no duplicate order. |
| Lost update | `If-Match` + `ETag` → `412`; client refetches. |
| Downstream unavailable | `503` with `Retry-After`, never hang beyond timeout. |
| Breaking change needed | New `/v2` path, both served until consumers migrate. |

## Testing strategy

- Controller slice tests (`@WebMvcTest`, `httptest`) for status codes and problem bodies.
- Spec lint in CI; response validation against OpenAPI in integration tests.
- Pact provider verification for every consumer (`contract-testing`).

## Definition of Done

- Spec updated, linted and classified (additive/breaking).
- Implementation matches the spec, errors are problem details.
- Idempotency and concurrency handled where applicable.
- Provider verification passes; clients regenerated by the app owner.
