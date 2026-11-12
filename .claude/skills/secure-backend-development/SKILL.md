---
name: secure-backend-development
description: Implement security in CommerceFlow Kotlin and Go services - JWT resource-server validation (issuer, audience, algorithm), role and object-level authorization, input validation, injection prevention, secrets from environment, rate limiting, CORS, safe logging and secure service-to-service calls. Use while building any endpoint, consumer or configuration that handles identity, money or personal data.
---

# Secure backend development

## Purpose

Build security in while coding, so `security-reviewer` finds little. Every service
validates tokens itself (zero trust between services) and authorizes every request at
both the operation and the object level.

## When to use

- New endpoints or changes to authentication/authorization.
- Handling customer PII, addresses, payment references.
- Adding configuration, secrets, outbound calls or file/URL inputs.

## Prerequisites

- OIDC provider decided (issuer URL per environment) — until then use a local Keycloak in
  Compose.
- `rest-api-design`; OWASP API Security Top 10 awareness.

## Concepts and architecture

- **Authentication:** OAuth 2.0 / OIDC access tokens (JWT, RS256/ES256). Each service is a
  resource server with its own **audience** (`order-service`). Validate signature (JWKS),
  `iss`, `aud`, `exp`, `nbf`; pin allowed algorithms.
- **Authorization:**
  - Function level: scopes/roles (`orders:write`, `ROLE_ADMIN`).
  - Object level: the subject must own the resource (`order.customerId == jwt.sub`) or hold
    an admin role. Check in the application layer, not only in the controller.
- **Service-to-service:** client-credentials tokens with the callee's audience; no shared
  static API keys.
- **Secrets:** environment variables injected from Kubernetes Secrets / a secrets manager;
  `.env.example` documents names only.
- **Data:** PII minimised in events (IDs instead of names/addresses where possible), never
  logged.

## Step-by-step workflow

1. Define required scopes/roles per operation in the OpenAPI spec (`security` section).
2. Configure the resource server (below) with issuer, audience and algorithm pinning.
3. Add method-level authorization and object ownership checks in use cases.
4. Validate inputs (bean validation / explicit Go validation); bound sizes and lengths.
5. Use parameterized queries only.
6. Add rate limiting for public endpoints (gateway or per service).
7. Review logs: no tokens, passwords, card data or full addresses.
8. Write negative tests (no token, wrong audience, other user's resource).

## Practical code examples

Kotlin resource server:

```kotlin
@Configuration
@EnableMethodSecurity
class SecurityConfig {
    @Bean
    fun filterChain(http: HttpSecurity): SecurityFilterChain = http
        .csrf { it.disable() }                       // stateless bearer tokens only
        .sessionManagement { it.sessionCreationPolicy(SessionCreationPolicy.STATELESS) }
        .authorizeHttpRequests {
            it.requestMatchers("/actuator/health/**", "/actuator/prometheus").permitAll()
            it.requestMatchers(HttpMethod.POST, "/v1/orders").hasAuthority("SCOPE_orders:write")
            it.anyRequest().authenticated()
        }
        .oauth2ResourceServer { it.jwt { } }
        .build()

    @Bean
    fun jwtDecoder(props: OAuth2ResourceServerProperties): JwtDecoder {
        val decoder = NimbusJwtDecoder.withIssuerLocation(props.jwt.issuerUri)
            .jwsAlgorithm(SignatureAlgorithm.RS256).build()
        decoder.setJwtValidator(DelegatingOAuth2TokenValidator(
            JwtValidators.createDefaultWithIssuer(props.jwt.issuerUri),
            JwtClaimValidator<List<String>>("aud") { "order-service" in it }))
        return decoder
    }
}
```

Object-level check in the use case:

```kotlin
class GetOrder(private val orders: OrderRepository) {
    fun handle(orderId: OrderId, caller: Caller): Order {
        val order = orders.findById(orderId) ?: throw NotFound()
        if (order.customerId != caller.customerId && !caller.isAdmin) throw NotFound() // don't reveal existence
        return order
    }
}
```

Go JWT middleware (`github.com/golang-jwt/jwt/v5`, `github.com/MicahParks/keyfunc/v3`):

```go
func Auth(ctx context.Context, jwksURL, issuer, audience string) (func(http.Handler) http.Handler, error) {
	jwks, err := keyfunc.NewDefaultCtx(ctx, []string{jwksURL})
	if err != nil {
		return nil, fmt.Errorf("load jwks: %w", err)
	}
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			raw, ok := strings.CutPrefix(r.Header.Get("Authorization"), "Bearer ")
			if !ok {
				http.Error(w, "unauthorized", http.StatusUnauthorized)
				return
			}
			tok, err := jwt.Parse(raw, jwks.Keyfunc,
				jwt.WithValidMethods([]string{"RS256"}),
				jwt.WithIssuer(issuer), jwt.WithAudience(audience), jwt.WithExpirationRequired())
			if err != nil || !tok.Valid {
				http.Error(w, "unauthorized", http.StatusUnauthorized)
				return
			}
			next.ServeHTTP(w, r.WithContext(withClaims(r.Context(), tok.Claims)))
		})
	}, nil
}
```

Parameterized query (never string concatenation):

```go
row := pool.QueryRow(ctx, `SELECT on_hand, reserved, version FROM stock_item WHERE sku = $1`, sku)
```

Safe logging:

```kotlin
log.info("Order placed orderId={} lines={}", order.id.value, order.lines.size)   // no names, addresses, tokens
```

## Recommended project structure

```text
services/<svc>/.../config/SecurityConfig.kt      (Kotlin)
services/<svc>/internal/adapters/http/auth.go    (Go)
services/<svc>/.env.example                      secret names only
contracts/openapi/<svc>.v1.yaml                  securitySchemes + per-operation scopes
```

## Best practices

- Deny by default; explicitly permit health and metrics endpoints only.
- Return 404 instead of 403 for other users' objects to avoid enumeration.
- Short-lived access tokens; no refresh tokens in services.
- Validate `Content-Type`, body size limits (`server.tomcat.max-http-form-post-size`,
  `http.MaxBytesReader`).
- Dependency hygiene: pinned versions, scanner in CI (`security-review`).
- CORS only on endpoints used by browsers, with explicit origins.

## Anti-patterns

- Trusting `X-User-Id` headers from "internal" callers.
- Decoding JWTs without verifying the signature, or accepting `alg: none`/HS256 with a
  public key.
- Secrets in `application.yml`, Dockerfiles, Helm values or tests checked into git.
- Mass assignment: binding request bodies straight onto entities.
- Logging full request bodies.

## Failure scenarios

| Scenario | Handling |
|---|---|
| JWKS endpoint unavailable | Cached keys continue to work; new key IDs fail closed (401). |
| Key rotation | JWKS refresh on unknown `kid` (keyfunc / Nimbus do this). |
| Token for another service | `aud` validation rejects with 401. |
| Leaked secret | Rotate immediately, purge from history, add scanner rule. |

## Testing strategy

- Security slice tests: no token → 401, wrong scope → 403, wrong audience → 401, other
  customer's order → 404 (`spring-security-test` `jwt()` post-processor; Go `httptest`
  with locally signed tokens and a test JWKS).
- Input validation tests for boundaries and oversized payloads.
- Secret scanning and dependency scanning in CI.

## Definition of Done

- Every endpoint has authentication, function-level and object-level authorization.
- JWT validation pins issuer, audience and algorithm.
- No secrets or PII in code, config, logs or events beyond what the contract requires.
- Negative security tests pass.
