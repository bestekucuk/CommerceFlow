# Data retention policy

Status: **draft — not decided.** Nothing is stored yet. Values marked *proposed default*
come from the engineering skills and are starting points for technical data only.
Retention of business and personal data depends on legal and tax requirements of the
markets CommerceFlow will serve, which are **not known yet** (CF-026). No value below is
a commitment.

## Principles

1. Keep personal data only as long as needed for the purpose it was collected for.
2. Each service applies retention to the data it owns; projections follow the source
   (a deletion or anonymisation fact must be published as an event so consumers can apply
   it).
3. Events carry IDs rather than personal data wherever possible, which limits how much
   personal data sits in Kafka retention.
4. Retention jobs are idempotent, batched and observable.

## Technical data (proposed defaults)

| Data | Location | Proposed default | Reason |
|---|---|---|---|
| Outbox rows | every publishing service | delete after 24 h if captured | Debugging window; must exceed maximum CDC outage tolerated |
| Inbox rows | every consuming service | 30 days | Must exceed topic retention + replay window |
| Idempotency keys | order, payment | not set | Must exceed client retry window; decide with API design |
| Kafka event topics | `cf.*.events.v*` | 7 days (order 14 days) | Replay window for consumers and new projections |
| Kafka command topics | `cf.*.commands.v*` | 3 days | Commands are useless after the saga deadline |
| Dead-letter topics | `*.dlt` | 30 days | Time to fix and replay |
| Application logs (Loki) | observability | not set | Depends on storage cost and audit needs |
| Traces (Tempo) | observability | not set | Same |
| Metrics (Prometheus) | observability | not set | Same |

## Business and personal data (open)

| Data | Owner | Question to decide | Status |
|---|---|---|---|
| Orders and order lines | order-service | Legal retention for sales records | Open (CF-026) |
| Payments and refunds | payment-service | Tax/accounting retention; provider references only, no card data stored | Open |
| Customer profile, addresses | customer-service | Deletion on request; anonymisation of historical orders | Open |
| Notifications and delivery log | notification-service | How long to keep message content vs. delivery metadata | Open |
| Shipments and tracking | shipping-service | Claims period | Open |
| Backups | all | Backups contain personal data; deletion requests vs. backup retention | Open (see disaster-recovery.md) |

## Right to erasure (design intent)

- customer-service is the entry point for erasure requests.
- It anonymises its own records and publishes a fact (event to be defined, e.g.
  `CustomerErased`) so that order-, notification- and shipping-service can anonymise
  their copies. Kafka retention bounds how long older events containing personal data
  remain; this is a reason to keep personal data out of events.

## Card data

CommerceFlow does not store card numbers or security codes. payment-service stores
provider references only; the payment provider holds card data (CF-016).
