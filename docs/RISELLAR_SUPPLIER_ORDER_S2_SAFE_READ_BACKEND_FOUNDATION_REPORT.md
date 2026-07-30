# Risellar Supplier Order S2 Safe Read Backend Foundation Report

## A. Executive Summary

Supplier Order Handling S2 creates a read-only supplier order backend foundation. It adds a forward migration for supplier-owned order list/detail RPCs, a development-only SQL boundary test harness, and TypeScript contract tests. It does not apply migrations, run the new SQL test, connect supplier order UI, add accept/reject behavior, release stock, change order status, or touch payment, delivery, settlement, commission, withdrawal, refund, or admin transition flows.

## B. Baseline Commit and Branch

- Baseline commit: `20ecabeec8a435dbe54a83dafb478d42e325c0ef`
- Branch: `main`
- Staged files at precheck: none
- Existing visible supplier/package/type-config entries had no content diff.

## C. Supplier Ownership Findings

Clerk maps to `public.profiles` through `public.current_profile_id()`, which resolves the active profile from the request JWT subject. The supplier owner relationship is `public.suppliers.owner_profile_id -> public.profiles.id`.

The schema also has `public.supplier_team_members`, but S2 intentionally uses the smaller safer actor rule: active approved `supplier_owner` only. Inventory-manager/staff order read can be added later through an explicit permission contract.

Approved S2 actor rule:

- authenticated profile exists
- no active `admin_staff` row for the profile
- profile `primary_role = 'supplier_owner'`
- profile `account_status = 'active'`
- supplier `supplier_status = 'active'`
- supplier `verification_status = 'approved'`
- supplier is not deleted

## D. Order Attribution Findings

`public.orders` does not store `supplier_id`. The authoritative supplier path for current order creation is `public.order_items.supplier_id`. The current checkout order RPC writes that value from the approved product's supplier and creates one order item for the MVP flow.

S2 read RPCs therefore scope orders through:

```text
orders -> order_items.supplier_id -> active approved supplier owned by current profile
```

## E. List Return Shape

The list RPC returns:

- order id and order number
- created/updated timestamps
- backend order status and supplier-safe label
- supplier actionability flag
- product name/slug/image snapshot
- quantity
- supplier expected amount
- currency
- Pay on Delivery/payment labels
- reservation label and expiry
- recipient name
- short location summary
- reseller shop name

It does not return customer email, customer account metadata, reseller private contact, supplier id, product id, variant id, platform margin, reseller margin, commission, settlement, raw stock counts, payment provider fields, delivery provider fields, or admin/risk notes.

## F. Detail Return Shape

The detail RPC returns the list-safe fields plus operational fulfilment details:

- variant SKU/name where useful for fulfilment
- customer total amount
- delivery status label
- reservation quantity
- recipient phone/WhatsApp
- sanitized delivery address snapshot
- reseller shop name/slug

It does not return customer login metadata, customer email, margin fields, commission, settlement, raw stock totals, admin/risk notes, payment-provider fields, or delivery-provider fields.

## G. List RPC Contract

Created planned RPC:

```sql
public.list_supplier_orders_safe(
  p_status text default null,
  p_limit integer default 50,
  p_cursor_created_at timestamptz default null,
  p_cursor_order_id uuid default null
)
```

The RPC resolves supplier ownership server-side, caps limit to 1-100, validates status by casting to the current `public.order_status` enum, orders by `created_at desc, order_id desc`, and mutates nothing.

## H. Detail RPC Contract

Created planned RPC:

```sql
public.get_supplier_order_safe(p_order_id uuid)
```

The RPC resolves supplier ownership server-side, accepts no supplier id, returns no rows for missing/unauthorized orders, and mutates nothing.

## I. Status Mapping

S2 maps only existing schema statuses. It does not add or reference `supplier_confirmed` or `supplier_rejected`.

- `placed_pending_confirmation`: `New order - confirm or reject`
- `supplier_preparing`: `Preparing`
- later existing operational/terminal states receive safe labels
- unknown/future fallback: `Order status unavailable`

## J. Reservation Mapping

S2 maps current reservation statuses:

- `pending`: `Reservation pending`
- `reserved`: `Stock reserved`
- `committed`: `Stock committed`
- `released`: `Reservation released`
- `expired`: `Reservation expired`
- `failed`: `Reservation unavailable`

Raw stock totals are not returned.

## K. Customer Fulfilment Privacy

List returns recipient name and short region/city/area summary only. Detail returns recipient phone/WhatsApp and sanitized address fields needed for fulfilment. Customer email is intentionally excluded even though current checkout contact snapshots may contain it.

## L. Direct-Table-Read Decision

Direct supplier reads of `orders`, `order_items`, and `stock_reservations` risk exposing internal fields such as customer ids, reseller ids, supplier ids, platform margin, reseller margin, commission amount, settlement amount, and raw stock data. S2 uses RPC-only read boundaries and does not broaden direct table `SELECT` or write grants.

## M. Migration Created

Created:

- `supabase/migrations/20260730130000_supplier_order_safe_read_rpc.sql`

The migration creates only read RPCs and function grants/comments.

## N. SQL Boundary Test Created

Created:

- `scripts/rpc/supplier-order-safe-read-rpc-tests-dev-only.sql`

The script uses fake development fixtures inside a transaction and ends with rollback. It is not run in S2.

## O. TypeScript Tests Created

Created:

- `tests/supplier-order-read.test.ts`

The tests statically inspect the migration and SQL harness for signatures, safe fields, forbidden fields, read-only behavior, grants, and boundary coverage.

## P. Static SQL Review

Static review checks:

- no business-table insert/update/delete inside read RPC function bodies
- no order status mutation
- no stock mutation
- no reservation release
- no accept/reject RPC
- no `supplier_confirmed` or `supplier_rejected`
- no supplier id input
- public/anon execute revoked
- authenticated execute granted

Result: passed. The only business-table inserts are in the development-only rollback SQL fixture harness, not in the read RPC migration function bodies.

## Q. Dry-Run Result

`npx supabase db push --dry-run --include-all` passed. It reported dry-run mode and showed only:

- `20260730130000_supplier_order_safe_read_rpc.sql`

No real schema/data mutation occurred.

## R. Confirmation No Real DB Push Occurred

No real `npx supabase db push` was run.

## S. Confirmation SQL Tests Were Not Run

The new supplier-order SQL boundary test was created but not run.

## T. Commands/Results

- `git status --short`: showed pre-existing metadata/no-content-diff entries, untracked S1 planning docs, and new S2 files. Nothing staged.
- `git rev-parse HEAD`: `20ecabeec8a435dbe54a83dafb478d42e325c0ef`.
- `git branch --show-current`: `main`.
- `git diff --name-status`: no output.
- `git diff --numstat`: no output.
- `git diff --summary`: no output.
- `git diff --check`: passed.
- `npx supabase --version`: `2.109.1`.
- `npm test -- tests/supplier-order-read.test.ts`: passed, 1 file and 7 tests.
- `npx supabase db push --dry-run --include-all`: passed; dry-run only; pending migration was `20260730130000_supplier_order_safe_read_rpc.sql`.
- `npm test`: passed, 33 files and 178 tests.
- `npm run lint`: passed.
- `npm run build`: passed, 168 routes generated.
- `npm run typecheck`: first caught a TypeScript test-harness import issue in `tests/supplier-order-read.test.ts`; after adding explicit Vitest imports, passed.
- `npx tsc --noEmit`: passed.

## U. Security/Privacy Scan

- `.env.local`: ignored and not staged.
- `.local-recovery`: ignored and not staged.
- `.next`: ignored and not staged.
- `supabase/.temp`: ignored and not staged.
- `.codex-dev-server.*.log`: ignored and not staged.
- Temporary SQL/output/logs: none staged.
- Credentials/project identifiers/connection strings/database passwords/JWTs/cookies/access tokens: not added or printed.
- Private customer/supplier/reseller/order row identifiers: not added to docs.
- App/components service-role imports: none found.
- Application source changed: no meaningful app/source diff.
- Supplier UI enabled: no.
- Accept/reject RPC added: no.
- Order/status/stock mutation added: no.
- Payment, delivery, preparation, settlement, commission, withdrawal, refund, or admin transition implementation added: no.
- Production project accessed: no.

## V. Files Changed

- `supabase/migrations/20260730130000_supplier_order_safe_read_rpc.sql`
- `scripts/rpc/supplier-order-safe-read-rpc-tests-dev-only.sql`
- `tests/supplier-order-read.test.ts`
- `docs/RISELLAR_SUPPLIER_ORDER_S2_SAFE_READ_BACKEND_FOUNDATION_REPORT.md`

The S1 planning docs also remain untracked from the previous planning phase.

## W. Current Git Status

Working tree contains:

- pre-existing metadata/no-content-diff visible entries: `app/supplier/orders/[id]/page.tsx`, `app/supplier/orders/page.tsx`, `next-env.d.ts`, `package-lock.json`, `package.json`, and `tsconfig.json`
- untracked S1 planning docs from the prior planning phase
- new S2 files listed above

Nothing is staged.

## X. Whether S2 Is Complete

Complete.

## Y. Whether Files Are Safe To Commit

Yes, after the user explicitly asks to commit and specifies scope. A later commit should avoid unrelated metadata/no-content-diff entries unless explicitly requested.

## Z. Whether It Is Safe To Begin S3

Yes, after explicit approval. S3 should apply only the S2 migration to the confirmed development project and then run the development-only supplier order safe-read RPC boundary test once.

## AA. Exact Recommended Next Prompt

Approve applying the Supplier Order Handling S2 supplier-safe read RPC migration to the confirmed DEVELOPMENT Supabase project named Risellar, then run the development-only supplier order safe-read RPC boundary tests once. Do not connect supplier order UI, do not add accept/reject behavior, do not release stock, do not connect production, and do not run destructive commands.
