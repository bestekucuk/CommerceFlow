# tests/contract

Status: **Avro convention check implemented**: `avro/check_schemas.py` (parse with shared
types, namespace, file name, enum defaults), run by `.github/workflows/contracts.yml`.
Pact and registry-based compatibility checks are not implemented yet (CF-017, CF-040).

Will contain: Pact broker config and provider-verification wiring; consumer pacts are produced by `apps/*` and services. Avro compatibility checks for `contracts/events`.

Tests that cover a single service live inside that service's folder, not here.
