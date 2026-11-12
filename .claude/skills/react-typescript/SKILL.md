---
name: react-typescript
description: Build CommerceFlow frontends (apps/storefront-web, apps/admin-web) with React and strict TypeScript - Vite setup per app, typed API clients generated from contracts/openapi, TanStack Query for server state, minimal client state, routing, error boundaries, accessibility and Vitest + Testing Library tests. Use for any frontend feature or app scaffold.
---

# React + TypeScript

## Purpose

Fast, accessible, type-safe frontends that consume service APIs only through generated
clients, with each app built and deployed independently.

## When to use

- Scaffolding `apps/<app>`.
- Adding a page, feature, form or API integration.
- Fixing type, state or rendering issues.

## Prerequisites

- Node.js 20 LTS+, the app's own `package.json`.
- OpenAPI specs in `contracts/openapi/` (`rest-api-design`).
- Owner: `frontend-engineer`.

## Concepts and architecture

- **Independent app:** own `package.json`, lockfile, Vite config, Dockerfile, CI workflow.
  No shared package between apps; duplication of small UI pieces is acceptable.
- **Server state** (orders, products): TanStack Query — caching, retries, invalidation.
- **Client state** (UI toggles, cart draft in storefront): React state/context; a store
  library only if state is shared across distant components.
- **API layer:** `openapi-typescript` generates types from `contracts/openapi/*.yaml`;
  `openapi-fetch` provides a typed client. Components never call `fetch` directly.
- **Auth:** OIDC Authorization Code + PKCE; access token kept in memory, attached by the
  API client; no tokens in `localStorage`.

## Step-by-step workflow

1. Scaffold: `npm create vite@latest storefront-web -- --template react-ts` inside `apps/`.
2. Enable strict TS options (below); add ESLint with `jsx-a11y`.
3. Add `api:generate` script and the API client in `src/api/`.
4. Add QueryClientProvider, router and an error boundary in `src/app/`.
5. Build features in `src/features/<feature>/` (components, hooks, tests).
6. Run `npm run typecheck && npm run lint && npm test && npm run build`.

## Practical code examples

`tsconfig.json` (relevant options):

```json
{
  "compilerOptions": {
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "exactOptionalPropertyTypes": true,
    "noImplicitOverride": true,
    "jsx": "react-jsx",
    "moduleResolution": "bundler",
    "target": "ES2022"
  }
}
```

`package.json` scripts:

```json
{
  "scripts": {
    "dev": "vite",
    "build": "tsc -b && vite build",
    "typecheck": "tsc -b --noEmit",
    "lint": "eslint .",
    "test": "vitest run",
    "api:generate": "openapi-typescript ../../contracts/openapi/order-service.v1.yaml -o src/api/generated/order.ts"
  }
}
```

Typed client (`src/api/orderClient.ts`):

```ts
import createClient from "openapi-fetch";
import type { paths } from "./generated/order";
import { getAccessToken } from "../app/auth";

export const orderApi = createClient<paths>({ baseUrl: import.meta.env.VITE_ORDER_API_URL });

orderApi.use({
  async onRequest({ request }) {
    const token = await getAccessToken();
    if (token) request.headers.set("Authorization", `Bearer ${token}`);
    return request;
  },
});
```

Query and mutation hooks (`src/features/checkout/useCheckout.ts`):

```ts
export function usePlaceOrder() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async (lines: { sku: string; quantity: number }[]) => {
      const { data, error } = await orderApi.POST("/v1/orders", {
        params: { header: { "Idempotency-Key": crypto.randomUUID() } },
        body: { lines },
      });
      if (error) throw new ApiError(error);
      return data;
    },
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["orders"] }),
  });
}
```

Generate the idempotency key once per checkout attempt (store it in state) so a retry
reuses it; the snippet above creates one per mutation call for brevity.

Accessible component:

```tsx
export function QuantityInput({ id, value, onChange }: { id: string; value: number; onChange: (v: number) => void }) {
  return (
    <div>
      <label htmlFor={id}>Quantity</label>
      <input id={id} type="number" min={1} inputMode="numeric" value={value}
             onChange={(e) => onChange(Number(e.target.value))} />
    </div>
  );
}
```

Component test (Vitest + Testing Library):

```tsx
it("submits the order and shows confirmation", async () => {
  server.use(http.post(`${API}/v1/orders`, () => HttpResponse.json({ orderId: "o-1", status: "PENDING" }, { status: 202 })));
  render(<CheckoutPage />, { wrapper: Providers });
  await userEvent.click(screen.getByRole("button", { name: /place order/i }));
  expect(await screen.findByRole("status")).toHaveTextContent(/order received/i);
});
```

(`server` is an MSW `setupServer()` instance in `tests/setup.ts`.)

## Recommended project structure

```text
apps/storefront-web/
  package.json  package-lock.json  vite.config.ts  tsconfig.json  Dockerfile
  src/app/            providers, router, auth, error boundary
  src/api/            clients + generated/ (generated, gitignored or committed by policy)
  src/features/<x>/   components, hooks, *.test.tsx
  src/shared/         app-local UI primitives
  tests/setup.ts  tests/e2e/  pacts/
```

## Best practices

- Derive UI types from generated API types; never hand-write response interfaces.
- Handle loading, empty, error and success states explicitly.
- Keyboard first: every action reachable by Tab/Enter/Space, visible focus styles.
- Format money from `amountMinor` + `currency` with `Intl.NumberFormat`.
- Environment config via `import.meta.env.VITE_*`, injected at build or runtime config.

## Anti-patterns

- `any`, non-null assertions on API data, `// @ts-ignore`.
- `fetch` in components; duplicated server state in global stores.
- A shared `ui-lib` package between admin and storefront.
- Tokens in `localStorage`; secrets in `VITE_*` variables (they are public).
- `div` with `onClick` instead of `button`.

## Failure scenarios

| Scenario | Handling |
|---|---|
| API 5xx / network error | Query retries (bounded), error UI with retry button. |
| 401 | Refresh via OIDC silent renew or redirect to login. |
| 202 async order | Poll order status with `refetchInterval` until terminal state. |
| Spec changed | `api:generate` + typecheck fails → update code. |

## Testing strategy

- Unit/component: Vitest + Testing Library + MSW.
- Accessibility: `jest-axe`/`vitest-axe` assertions on key pages.
- Contract: Pact consumer tests for every API call (`contract-testing`).
- E2E: Playwright (`playwright-e2e`).

## Definition of Done

- Typecheck, lint, tests and build pass from the app folder.
- All API calls go through generated clients; Pact tests updated.
- Loading/error/empty states and keyboard accessibility implemented.
- No tokens or secrets in storage or env.
