---
name: playwright-e2e
description: Write CommerceFlow end-to-end tests with Playwright - app-local flows in apps/*/tests/e2e and cross-app or full-stack flows in tests/e2e, role-based locators, API-based test data setup, authentication state reuse, asserting asynchronous saga outcomes with expect.poll, traces and CI configuration. Use when a user journey needs verification across UI and services.
---

# Playwright E2E

## Purpose

Prove the most important user journeys work through the real UI against the real stack,
with stable, readable tests.

## When to use

- A new or changed user journey (checkout, admin price edit, order cancellation).
- Release smoke tests on the Compose stack or staging.

## Prerequisites

- Stack running: `docker compose up -d` at the repo root (CF-005) with both apps.
- Test users in the local identity provider (seeded, non-production credentials).
- Owner: `test-engineer` (cross-app) and `frontend-engineer` (app-local).

## Concepts and architecture

| Location | Scope | Runs in |
|---|---|---|
| `apps/<app>/tests/e2e/` | One app, its services may be stubbed or real | that app's pipeline |
| `tests/e2e/` | Journeys spanning apps and services (admin publishes → storefront buys) | nightly / release pipeline |

- **Locators:** `getByRole`, `getByLabel`, `getByText` — they double as accessibility checks.
- **Setup via API**, not UI: create products/prices through service APIs before the test.
- **Async outcomes:** the order saga completes asynchronously; assert with `expect.poll` or
  web-first assertions with generous but bounded timeouts.
- **Auth:** log in once per role in a setup project and reuse `storageState`.

## Step-by-step workflow

1. Pick the journey and its observable end state.
2. Write API helpers for data setup (in the test project, using generated clients or raw
   requests).
3. Create an auth setup project per role.
4. Write the test with role-based locators; one journey per test.
5. Run headless locally, inspect traces on failure.
6. Wire into CI with retries=1 only in CI, traces on first retry.

## Practical code examples

`tests/e2e/playwright.config.ts`:

```ts
import { defineConfig, devices } from "@playwright/test";

export default defineConfig({
  testDir: "./specs",
  timeout: 60_000,
  expect: { timeout: 10_000 },
  retries: process.env.CI ? 1 : 0,
  reporter: [["html", { open: "never" }], ["list"]],
  use: { trace: "on-first-retry", screenshot: "only-on-failure" },
  projects: [
    { name: "setup-customer", testMatch: /customer\.setup\.ts/, use: { baseURL: process.env.STOREFRONT_URL ?? "http://localhost:5174" } },
    { name: "setup-admin", testMatch: /admin\.setup\.ts/, use: { baseURL: process.env.ADMIN_URL ?? "http://localhost:5173" } },
    {
      name: "storefront",
      dependencies: ["setup-customer"],
      use: { ...devices["Desktop Chrome"], baseURL: process.env.STOREFRONT_URL ?? "http://localhost:5174", storageState: ".auth/customer.json" },
    },
  ],
});
```

Auth setup (`specs/customer.setup.ts`):

```ts
import { test as setup, expect } from "@playwright/test";

setup("log in as customer", async ({ page }) => {
  await page.goto("/");
  await page.getByRole("button", { name: "Sign in" }).click();
  await page.getByLabel("Email").fill(process.env.E2E_CUSTOMER_EMAIL!);
  await page.getByLabel("Password").fill(process.env.E2E_CUSTOMER_PASSWORD!);
  await page.getByRole("button", { name: "Sign in" }).click();
  await expect(page.getByRole("button", { name: "Account" })).toBeVisible();
  await page.context().storageState({ path: ".auth/customer.json" });
});
```

Checkout journey with async saga assertion (`specs/checkout.spec.ts`):

```ts
import { test, expect } from "@playwright/test";
import { seedSellableProduct } from "../support/seed";

test("customer buys an in-stock product and sees it confirmed", async ({ page, request }) => {
  const product = await seedSellableProduct(request, { stock: 5, priceMinor: 1299 });

  await page.goto(`/products/${product.slug}`);
  await page.getByRole("button", { name: "Add to cart" }).click();
  await page.getByRole("link", { name: "Cart" }).click();
  await page.getByRole("button", { name: "Place order" }).click();

  await expect(page.getByRole("status")).toContainText("Order received");
  const orderId = await page.getByTestId("order-id").innerText();

  await expect
    .poll(async () => (await request.get(`${process.env.ORDER_API_URL}/v1/orders/${orderId}`)).json().then((o) => o.status),
          { timeout: 30_000, intervals: [500, 1_000, 2_000] })
    .toBe("CONFIRMED");

  await page.getByRole("link", { name: "My orders" }).click();
  await expect(page.getByRole("row", { name: new RegExp(orderId) })).toContainText("Confirmed");
});
```

The `request` fixture needs an authorized context for API calls (create it with
`request.newContext({ extraHTTPHeaders: { Authorization: ... } })` in `support/`).

Run:

```bash
npx playwright test --project=storefront
npx playwright show-trace test-results/**/trace.zip
```

## Recommended project structure

```text
tests/e2e/
  package.json  playwright.config.ts
  specs/*.spec.ts  specs/*.setup.ts
  support/seed.ts  support/api.ts
apps/<app>/tests/e2e/   app-local specs with the app's own config
```

## Best practices

- One user-visible outcome per test; independent data per test.
- No `page.waitForTimeout`; rely on auto-waiting assertions and `expect.poll`.
- Use `data-testid` only where no accessible role/label exists.
- Keep E2E suites small (critical journeys); push detail down to component/contract tests.
- Credentials only from environment variables, test-only accounts.

## Anti-patterns

- CSS/XPath selectors tied to layout.
- Tests that depend on each other's data or order.
- Seeding by writing directly into service databases.
- Retrying until green locally (hides real flakiness).

## Failure scenarios

| Scenario | Handling |
|---|---|
| Saga slower than expected | `expect.poll` with bounded timeout; investigate if exceeded (trace + service traces). |
| Stack not up | Global setup checks health endpoints and fails fast with a clear message. |
| Flaky locator | Switch to role/label; check for animations; never add sleeps. |
| Data collision | Unique SKUs/emails per test run. |

## Testing strategy

E2E sits at the top of the pyramid: only critical journeys. Failures should be
reproducible with the trace and correlated with service traces via the trace id shown in
error UI (`distributed-tracing`).

## Definition of Done

- Journey covered with role-based locators and API-seeded data.
- Asynchronous outcomes asserted with bounded polling.
- Runs headless locally and in CI; traces captured on retry.
- No sleeps, no direct DB access, no real credentials.
