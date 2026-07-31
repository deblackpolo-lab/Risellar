# Risellar Customer Order History Phase 1 Backend Report

## A. Summary

Customer Order History Phase 1 adds read-only customer order-history and order-summary RPCs for the confirmed development Supabase project named Risellar. The boundary exposes customer-safe order list fields only and keeps existing order detail reads on `get_customer_order_safe`.

No checkout submission, order mutation UI, payment collection, stock reservation mutation, delivery quote mutation, settlement, commission, withdrawal, refund, return, dispute, or cancellation workflow was added.

## B. Migration Created

- `supabase/migrations/20260731233000_customer_order_history_safe_read_rpcs.sql`

The migration creates:

- `public.list_customer_orders_safe(p_group, p_search, p_date_from, p_date_to, p_limit, p_cursor_created_at, p_cursor_order_id)`
- `public.get_customer_order_summary_safe()`

## C. RPC Behavior

`list_customer_orders_safe`:

- resolves the signed-in profile through `current_profile_id()`
- verifies the profile is an active `customer`
- verifies the matching `customers` row is active and not deleted
- blocks active `admin_staff`, reseller, supplier, anonymous, and cross-customer reads
- supports `all`, `active`, `completed`, and `rejected` groups
- supports bounded search, date filters, bounded limit, and cursor inputs
- orders results by `created_at desc, id::text desc`

`get_customer_order_summary_safe`:

- uses the same customer-only boundary
- returns aggregate counts and latest safe order status information
- returns no private commercial or operational internals

## D. Public/Customer-Safe Fields

The list RPC exposes:

- order id for customer detail linking
- order number
- created/updated timestamps
- customer-facing order status label and safe status group
- completed/rejected timestamps when relevant
- product name, slug, image snapshot, quantity
- final customer price, line total, total payable, currency
- Pay on Delivery/payment collection labels
- delivery status label
- reseller shop display name/slug
- customer detail href

## E. Sensitive Fields Blocked

The RPC does not expose:

- customer profile/customer IDs
- supplier IDs or private supplier data
- reseller IDs or private reseller finance data
- product/variant/listing internal IDs
- supplier base price
- platform margin
- reseller margin or cost
- commission amount
- settlement due amount
- stock reservation status/count internals
- risk score or admin/internal notes
- payment provider references
- supplier rejection private note

## F. Security Protections

- RPCs are `SECURITY DEFINER` with `set search_path = public`.
- Execute is granted to `authenticated` only.
- Public and anonymous execute privileges are revoked.
- The read RPCs do not call `current_customer_id()` because that helper can create customer rows.
- The functions do not write to any application table.
- No service role is used by app/components or normal customer flow code.

## G. Development Apply/Test Result

- Dry-run passed and showed only `20260731233000_customer_order_history_safe_read_rpcs.sql`.
- Development `db push` succeeded for the confirmed development project.
- Development-only boundary test script passed with all assertions `passed=true`.
- Test data is wrapped in a transaction and rolled back.

## H. Boundary Tests

Added:

- `scripts/rpc/customer-order-history-safe-read-rpc-tests-dev-only.sql`

Assertions cover:

- list and summary RPC signatures
- expected safe list columns
- forbidden internal columns absent
- own-customer list access
- cross-customer blocking
- reseller/supplier/admin-staff blocking
- anonymous blocking
- active/completed/rejected filters
- search and date filters
- safe detail link
- no order/order item/stock/delivery quote/commission/settlement/withdrawal side effects from reads

## I. Commands Run/Results

- `git status --short`: working tree had intentional new Customer Order History files plus recurring metadata-only modified files.
- `git diff --check`: passed.
- `npx supabase db push --dry-run --include-all`: passed; only the new migration would apply.
- `npx supabase db push --include-all`: passed against development.
- `npx supabase db query --linked --file scripts/rpc/customer-order-history-safe-read-rpc-tests-dev-only.sql`: passed.
- `npm test`: passed, 45 files and 260 tests.
- `npm run lint`: passed.
- `npm run build`: passed.
- `npm run typecheck`: passed when run sequentially after build.
- `npx tsc --noEmit`: passed when run sequentially after build.

## J. Secret/Scope Scan Result

- `.env.local` remains ignored and was not staged.
- `supabase/.temp` remains ignored.
- `.next` and `.codex-dev-server.*.log` remain ignored.
- Changed source/docs/scripts contain no real Clerk, Supabase, service-role, bearer token, password, API secret, JWT, cookie, project identifier, or production data.
- Service-role usage remains outside app/components normal flows.
- No checkout/order mutation/payment/delivery/finance mutation UI integration was added.

## K. Files Changed

- `supabase/migrations/20260731233000_customer_order_history_safe_read_rpcs.sql`
- `scripts/rpc/customer-order-history-safe-read-rpc-tests-dev-only.sql`
- `lib/orders/customer-order-history.ts`
- `components/customer/customer-order-history-rpc-screen.tsx`
- `app/customer/orders/page.tsx`
- `tests/customer-order-history-safe-read.test.ts`
- `docs/RISELLAR_CUSTOMER_ORDER_HISTORY_PHASE_1_BACKEND_REPORT.md`
- `docs/RISELLAR_CUSTOMER_ORDER_HISTORY_PHASE_1_UI_AND_LIVE_QA_REPORT.md`

## L. Current Git Status

Intentional Customer Order History files are modified/untracked. Existing recurring metadata files remain modified with no meaningful content diff and should not be staged for this commit.

## M. Whether Safe To Commit

Safe to commit after final verification and changed-file secret/scope scan remain green. Stage only the intentional Customer Order History source, migration, test script, tests, and reports.
