# Risellar Checkout Phase B Draft Backend Foundation Report

## A. Summary

Implemented the Checkout Phase B Group 1 backend foundation for customer-owned checkout drafts. This phase persists a draft snapshot from an active approved reseller listing only. It does not create orders, reserve stock, connect payments, create delivery quotes, create commissions, create settlements, create withdrawals, or connect the customer purchase flow.

## B. Migration Created

- `supabase/migrations/20260718203000_checkout_draft_rpc_foundation.sql`

The migration creates `public.checkout_drafts` with owner-scoped RLS and draft-only snapshot fields.

## C. RPCs Created

- `public.create_checkout_draft_from_listing(p_listing_id uuid, p_quantity integer default 1)`
- `public.get_checkout_draft(p_draft_id uuid)`
- `public.update_checkout_draft_contact_address(p_draft_id uuid, p_address_id uuid, p_contact_phone text default null)`
- `public.abandon_checkout_draft(p_draft_id uuid)`

Internal helpers:

- `public.checkout_phase_b_normalize_quantity(p_quantity integer)`
- `public.checkout_draft_current_customer_context()`
- `public.checkout_draft_safe_row(p_draft_id uuid)`

## D. Snapshot Fields Stored

The draft stores server-derived, checkout-safe snapshot fields:

- customer/profile id
- reseller listing id
- reseller/shop id
- supplier id
- product id and optional variant id
- product name, slug, description, category, brand
- public image metadata snapshot
- final customer price snapshot
- line total snapshot
- currency
- quantity
- customer contact snapshot
- delivery address reference/snapshot when selected
- public listing snapshot
- draft status and audit timestamps

Supplier base price, platform margin, reseller margin, commission, settlement, payout, and internal/admin fields are not returned by the public draft RPC shape.

## E. Security Protections

- Authenticated active customer profile is required.
- Reseller and supplier primary roles are blocked from creating customer checkout drafts.
- Draft creation resolves listing/product/supplier/shop state server-side.
- Draft creation accepts only listing id and quantity; browser-sent price is not accepted.
- Listing must be active and non-deleted.
- Product must be active, approved, and non-deleted.
- Supplier must be active, approved, and non-deleted.
- Reseller must be approved and non-deleted.
- Shop must be active and non-deleted.
- Customer can read/update/abandon only their own draft.
- Address attachment requires the selected address to belong to the signed-in customer.
- Abandoned drafts cannot be updated.
- RPCs are `SECURITY DEFINER` with `set search_path = public`.
- No direct table grants were added for browser writes to `checkout_drafts`.
- Audit logs are written for create, contact/address update, and abandon.

## F. Deferred Scope

Still deferred:

- order creation
- order item creation
- stock reservation
- inventory movement
- payment/online payment
- delivery quote
- commission
- settlement
- withdrawal
- checkout submit/purchase flow UI

## G. Development-Only Test Script

Created:

- `scripts/rpc/checkout-draft-rpc-tests-dev-only.sql`

The script uses fake/dev-only fixture rows inside a transaction and rolls back all fixture data. It is not intended for production.

Covered assertions include:

- customer can create checkout draft from active approved listing
- server-calculated listing price is snapshotted
- existing draft snapshot is immutable after listing price changes
- invalid quantity is blocked
- pending/rejected/archived listings/products are blocked
- customer can attach own address
- customer cannot attach another customer address
- customer B cannot read/update/abandon customer A draft
- reseller/supplier cannot create customer checkout draft
- customer can abandon own draft
- abandoned draft cannot be updated
- audit logs are created
- no order, order item, stock reservation, delivery quote, settlement, commission, or withdrawal rows are created

## H. Dry-Run Result

`npx supabase db push --dry-run` passed.

Dry-run reported that only this migration would be pushed:

- `20260718203000_checkout_draft_rpc_foundation.sql`

Real `npx supabase db push` was not run.

Follow-up development apply status:

- The migration was later applied successfully to the confirmed development Supabase project named `Risellar`.
- The first checkout draft RPC boundary test run failed before assertions because of a SQL syntax bug in the development-only test script.
- Failure: trailing comma in `checkout_draft_expect_blocked('abandoned draft cannot be updated', ...)`.
- Classification: test assertion/harness bug.
- No real checkout draft security gap is confirmed yet.
- Test harness fix applied: removed the trailing comma from the malformed `checkout_draft_expect_blocked` call.
- Boundary test rerun still requires explicit approval.

## I. Commands Run/Results

- `git status --short` - clean before implementation; after implementation shows only the new checkout draft migration, development-only RPC test script, and this report as untracked.
- `npx supabase db push --dry-run` - passed; dry-run only; no migration applied.
- `git diff --check` - passed.
- `npm test` - passed: 29 test files, 151 tests.
- `npm run lint` - passed with `eslint . --max-warnings=0`.
- `npm run build` - passed.
- `npm run typecheck` - first parallel run failed because `.next/types` were being regenerated while `npm run build` was running; rerun after build passed with `tsc --noEmit`.
- Secret/scope scan - completed; see section J.

## J. Secret/Scope Scan Result

- `.env.local` is ignored and not staged.
- `supabase/.temp` is ignored.
- `.next` is ignored.
- `.codex-dev-server.*.log` is ignored.
- No Clerk secret key values were found.
- No Supabase service-role JWT values were found.
- No password/API-secret assignment patterns were found.
- One existing documentation line matched the bearer-token regex because it says bearer tokens were not found; it is a false positive and contains no token value.
- No service-role references were found in `app/` or `components/`.
- No `app/`, `components/`, or `lib/` files were changed.
- Checkout/order/stock/payment/delivery references appear only in the new migration comments/report and in development-only SQL no-side-effect assertions. No checkout order creation, stock reservation, payment, delivery quote, settlement, commission, withdrawal, or purchase-flow UI integration was added.

## K. Files Changed

- `supabase/migrations/20260718203000_checkout_draft_rpc_foundation.sql`
- `scripts/rpc/checkout-draft-rpc-tests-dev-only.sql`
- `docs/RISELLAR_CHECKOUT_PHASE_B_DRAFT_BACKEND_FOUNDATION_REPORT.md`

## L. Current Git Status

Untracked files:

- `supabase/migrations/20260718203000_checkout_draft_rpc_foundation.sql`
- `scripts/rpc/checkout-draft-rpc-tests-dev-only.sql`
- `docs/RISELLAR_CHECKOUT_PHASE_B_DRAFT_BACKEND_FOUNDATION_REPORT.md`

## M. Safe to Apply to Development

The dry-run passed and only the checkout draft migration would be applied. It is safe to request explicit approval for development apply and boundary test execution after final local verification passes.
