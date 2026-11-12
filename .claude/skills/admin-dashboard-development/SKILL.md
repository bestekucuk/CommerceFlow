---
name: admin-dashboard-development
description: Build back-office features in apps/admin-web - role-based routing, server-side paginated data tables, validated forms with react-hook-form and zod, optimistic concurrency with ETag/If-Match, confirmation of destructive actions, bulk operations, saga/order status views and audit-friendly UX. Use for any admin-web feature.
---

# Admin dashboard development

## Purpose

Give staff safe, efficient tools to manage catalog, pricing, inventory, orders and
shipments — without bypassing service ownership (every change goes through the owning
service's API).

## When to use

- Any feature in `apps/admin-web`.
- Designing admin endpoints together with service engineers.

## Prerequisites

- `react-typescript` baseline.
- Admin roles defined in the identity provider (`ROLE_CATALOG_ADMIN`, `ROLE_ORDER_ADMIN`, ...).
- Service APIs in `contracts/openapi/` supporting pagination and ETags (`rest-api-design`).

## Concepts and architecture

- **One API per context:** the product page calls product-service; price editing calls
  pricing-service. No "admin backend" that writes into several databases.
- **Authorization in two places:** UI hides what a role cannot do; the service enforces it.
- **Concurrency:** edits send `If-Match: <etag>`; `412` shows a "changed by someone else"
  dialog with a reload/diff option.
- **Async operations:** order cancellation returns `202`; the UI shows pending state and
  polls.
- **Read-heavy lists:** server-side filtering, sorting and cursor pagination.

## Step-by-step workflow

1. Define the user task and the role allowed to do it.
2. Confirm the owning service endpoint exists in the spec; if not, request it from the
   service owner (do not invent endpoints).
3. Build the list view with server pagination and URL-synced filters.
4. Build the edit form with zod schema matching the API constraints.
5. Add ETag handling, success/error toasts and destructive confirmations.
6. Add component tests, Pact interactions and a Playwright test for the main flow.

## Practical code examples

Role-gated route:

```tsx
function RequireRole({ role, children }: { role: Role; children: ReactNode }) {
  const { roles } = useSession();
  if (!roles.includes(role)) return <Navigate to="/forbidden" replace />;
  return <>{children}</>;
}

<Route path="/catalog/*" element={<RequireRole role="ROLE_CATALOG_ADMIN"><CatalogRoutes /></RequireRole>} />
```

Server-paginated list with URL state:

```tsx
export function ProductList() {
  const [params, setParams] = useSearchParams();
  const cursor = params.get("cursor") ?? undefined;
  const q = params.get("q") ?? "";
  const { data, isPending, error } = useQuery({
    queryKey: ["products", { q, cursor }],
    queryFn: async () => {
      const { data, error } = await productApi.GET("/v1/products", { params: { query: { q, cursor, limit: 50 } } });
      if (error) throw new ApiError(error);
      return data;
    },
    placeholderData: keepPreviousData,
  });
  if (error) return <ErrorPanel error={error} />;
  return (
    <>
      <SearchBox value={q} onChange={(v) => setParams({ q: v })} />
      <table aria-busy={isPending}>
        <caption>Products</caption>
        <thead><tr><th scope="col">SKU</th><th scope="col">Name</th><th scope="col">Status</th></tr></thead>
        <tbody>{data?.items.map((p) => <tr key={p.id}><td>{p.sku}</td><td>{p.name}</td><td>{p.status}</td></tr>)}</tbody>
      </table>
      {data?.nextCursor && <button onClick={() => setParams({ q, cursor: data.nextCursor! })}>Next page</button>}
    </>
  );
}
```

Form with zod + ETag:

```tsx
const PriceSchema = z.object({
  amountMinor: z.number().int().nonnegative(),
  currency: z.string().length(3),
});
type PriceForm = z.infer<typeof PriceSchema>;

export function EditPrice({ sku }: { sku: string }) {
  const { data } = usePrice(sku);                       // returns { price, etag }
  const form = useForm<PriceForm>({ resolver: zodResolver(PriceSchema), values: data?.price });
  const save = useMutation({
    mutationFn: (v: PriceForm) =>
      pricingApi.PUT("/v1/prices/{sku}", { params: { path: { sku }, header: { "If-Match": data!.etag } }, body: v }),
    onSuccess: ({ response }) => {
      if (response.status === 412) openConflictDialog();
    },
  });
  return (
    <form onSubmit={form.handleSubmit((v) => save.mutate(v))} noValidate>
      <label htmlFor="amount">Price (minor units)</label>
      <input id="amount" type="number" {...form.register("amountMinor", { valueAsNumber: true })}
             aria-invalid={!!form.formState.errors.amountMinor} aria-describedby="amount-error" />
      <p id="amount-error" role="alert">{form.formState.errors.amountMinor?.message}</p>
      <button type="submit" disabled={save.isPending}>Save</button>
    </form>
  );
}
```

Destructive action confirmation:

```tsx
<ConfirmDialog
  title={`Cancel order ${orderId}?`}
  description="Stock will be released and the payment refunded. This cannot be undone."
  confirmLabel="Cancel order"
  onConfirm={() => cancelOrder.mutate(orderId)}
/>
```

## Recommended project structure

```text
apps/admin-web/src/
  app/            router with RequireRole, layout, session
  features/catalog/  features/pricing/  features/inventory/  features/orders/  features/shipping/
  shared/table/   paginated table, filters
  shared/forms/   field components with labels and error wiring
```

## Best practices

- Show who/when last changed an entity if the API provides it.
- URL holds filters and pagination so views are shareable and back-button safe.
- Bulk operations call the owning API per item or a dedicated bulk endpoint; show per-item
  results.
- Disable submit while pending; never double-submit.
- Use the same terms as the bounded context (ubiquitous language).

## Anti-patterns

- An admin BFF writing directly to several service databases.
- Client-side pagination of large datasets.
- Hiding buttons as the only authorization.
- Silent last-write-wins edits without ETags.
- Free-text status fields instead of the service's enums.

## Failure scenarios

| Scenario | Handling |
|---|---|
| 412 on save | Conflict dialog: reload and reapply. |
| 403 from service | Show permission error; log for role misconfiguration. |
| Bulk op partially fails | Result table with retry for failed items. |
| Long-running cancel | Pending badge + polling until `CANCELLED`. |

## Testing strategy

- Component tests per form: validation messages, disabled states, 412 handling.
- Role tests: routes redirect without the role.
- Pact interactions for list, edit and action endpoints.
- Playwright: login as admin, edit price, verify list shows new price.

## Definition of Done

- Feature gated by role in UI and enforced by the service.
- Lists paginated server-side; forms validated; ETags used for edits.
- Destructive actions confirmed; async actions show progress.
- Tests (component, Pact, Playwright main flow) pass.
