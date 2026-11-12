# Milestones

Status legend: ✅ Done = verified in this repository (evidence given) · 🟡 In progress · ⛔ Blocked · ⬜ Not started.
Generated from one data source; IDs `CF-0xx` keep the numbers already used in `docs/`. Snapshot: 2026-11-12.

| Milestone | Phases | Exit criteria | Tasks done/total | Status |
|---|---|---|---|---|
| **M1** Foundation complete | 1, 2 | Monorepo, docs, scaffolds, Claude framework verified | 7/10 | 🟡 In progress |
| **M2** Local platform verified | 3 | health.ps1 green and verify-cdc.ps1 passes | 2/4 | 🟡 In progress |
| **M3** Vertical slice: product CDC | 4 | Product created via API arrives on Kafka with valid Avro; compatibility checks run | 3/5 | 🟡 In progress |
| **M4** Downstream projections | 5 | Inventory and pricing consume product events idempotently | 1/7 | 🟡 In progress |
| **M5** Orders and payments | 6 | Order creation with quote; payment authorization/void handlers | 0/6 | ⬜ Not started |
| **M6** Vertical slice: saga | 7 | Order saga happy path, compensation and timeouts verified on Compose | 0/10 | ⬜ Not started |
| **M7** Admin usable | 8 | Staff manage catalog, prices and orders with real login | 0/6 | ⬜ Not started |
| **M8** Storefront usable | 9 | Customer browse → checkout → order status | 0/5 | ⬜ Not started |
| **M9** Quality gates | 10 | All test layers in CI or nightly | 0/7 | 🟡 In progress |
| **M10** Operable and secure | 11 | Traces/dashboards/alerts/SLOs, scanning, audit with no open high findings | 0/5 | ⬜ Not started |
| **M11** Production ready | 12 | Per-component pipelines, Helm/Kubernetes, DR and retention | 0/18 | 🟡 In progress |

A milestone is reached only when every task in its phases is ✅ Done with evidence. No milestone is reached yet: M1 has open items
 ([CF-001](TASKS.md#cf-001), [CF-003](TASKS.md#cf-003), [CF-036](TASKS.md#cf-036)).
