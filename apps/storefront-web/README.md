# storefront-web

CommerceFlow web application for: Customers.

Browse and search catalog, product detail, cart, checkout, order history, account.

## Status

**Buildable scaffold.** React + TypeScript (strict) + Vite app shell with a unit test
(Vitest + Testing Library) and a Playwright smoke test. No features or API calls yet.

## Local development

From this folder:

| Task | Command |
|---|---|
| Install | `npm ci` |
| Dev server | `npm run dev` → http://localhost:5174 |
| Type check | `npm run typecheck` |
| Unit tests | `npm test` |
| Build | `npm run build` |
| E2E smoke (needs `npx playwright install chromium` once) | `npm run test:e2e` |
| Image | from the repo root: `powershell -File scripts/build-service.ps1 storefront-web -Image` |

Container: nginx on port 8080 with `GET /healthz` and `GET /readyz`.
Configuration: `VITE_API_BASE_URL` (public, build time; default `/api`).
