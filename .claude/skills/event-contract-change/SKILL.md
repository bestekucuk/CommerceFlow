---
name: event-contract-change
description: Step-by-step procedure for adding, evolving or deprecating a CommerceFlow Kafka event across contracts, producers and consumers. Use whenever an event schema changes.
---

# Event contract change

1. **Locate the contract** in `contracts/events/<aggregate>/`. Read
   `contracts/events/README.md` for naming and compatibility rules.
2. **Classify the change**
   - Additive (new optional field with default) → same subject, BACKWARD compatible.
   - Breaking (remove, rename, retype, make required) → new major version: new schema
     file `<Event>.v<N+1>.avsc` and new topic suffix `.v<N+1>`.
3. **Edit the schema** and update `docs/event-catalog/README.md` (producer, consumers,
   version).
4. **Ask the `event-contract-steward` agent** to review the change.
5. **Plan rollout** with `/cross-service-change`. Services deploy separately, so even in
   one repository the order matters:
   - Additive: consumers first (tolerant reader), then producer.
   - Breaking: producer dual-publishes v<N> and v<N+1>; consumers migrate one by one;
     producer stops v<N> after the last consumer moves.
6. **Commit** with the backlog ID. Keep producer and consumer changes in separate
   commits when they must be deployed at different times. Never push.
