# Risellar Customer Phase A Profile/Address RPC Report

Date: 2026-07-18

## A. Summary

Created the Customer Phase A backend foundation for safe customer profile/contact and delivery address management. This phase is limited to authenticated customer contact/address records and does not create checkout drafts, orders, stock reservations, delivery quotes, payments, settlements, commissions, withdrawals, or purchase-flow side effects.

No production Supabase connection was used. No real `supabase db push` was run.

## B. Migration Created

Created:

- `supabase/migrations/20260718193000_customer_profile_address_rpc_foundation.sql`

The migration adds:

- `public.customer_delivery_addresses`
- RLS policies for own-address access and support/admin read/update visibility
- a one-active-default-address partial unique index
- soft archive support through `deleted_at`

The existing `public.customers` and `public.profiles` tables are reused. `profiles.primary_role` is not mutated by the customer contact RPC.

## C. RPCs Created

Created authenticated customer-facing RPCs:

- `public.upsert_customer_contact(text, text, text, text)`
- `public.create_customer_delivery_address(text, text, text, text, text, text, text, text, boolean)`
- `public.update_customer_delivery_address(uuid, text, text, text, text, text, text, text, text, boolean)`
- `public.archive_customer_delivery_address(uuid)`
- `public.get_customer_delivery_addresses()`

Created internal helpers:

- `public.current_customer_id()`
- `public.customer_phase_a_normalize_required_text(text, text)`

Internal helper execution is revoked from public. Customer-facing RPC execution is granted to `authenticated`.

## D. Security Protections

Preserved protections:

- Anonymous users cannot create/update customer contact or delivery addresses.
- Customers can create/read/update/archive only their own delivery addresses.
- Cross-customer address reads and mutations are blocked.
- Reseller and supplier accounts can only create their own customer foundation/contact data for buyer use; they cannot mutate another customer's addresses.
- Admin/support visibility does not create a customer-facing bypass in the customer RPCs.
- Address archive is soft-delete only; no direct delete path was added.
- Required address/contact fields are validated server-side.
- Contact updates do not change `profiles.primary_role`.
- Audit logs are written for contact upsert, address create, address update, and address archive.

## E. Out-of-Scope Protections

No live integration was added for:

- checkout
- orders
- stock reservation
- delivery quotes
- payments
- settlements
- commissions
- withdrawals
- customer purchase flow

The migration does not create or mutate rows in those workflow tables.

## F. Development Test Script

Created:

- `scripts/rpc/customer-profile-address-rpc-tests-dev-only.sql`

The script is marked:

```text
DEVELOPMENT ONLY - DO NOT RUN AGAINST PRODUCTION.
```

It uses fake/dev-only fixture rows and ends with `rollback`.

Planned assertions cover:

- anonymous calls blocked
- own contact upsert allowed
- own customer foundation created
- own address create/read/update/archive allowed
- archived addresses hidden from customer RPC
- active cross-customer address read/update/archive blocked
- reseller/supplier cannot mutate another customer's address
- admin role does not bypass ownership through customer RPC
- required field validation
- no order/order item/stock reservation/delivery quote/commission/settlement/withdrawal rows created

The script was created but was not run in this step.

## G. Dry-Run Result

Command:

```bash
npx supabase db push --dry-run
```

Result: passed.

Dry-run output showed only this migration would be applied:

- `20260718193000_customer_profile_address_rpc_foundation.sql`

No real `npx supabase db push` was run.

## H. Commands Run

- `git status --short` - showed the new migration and test script as untracked before report creation.
- `npx supabase db push --dry-run` - passed; dry-run only.
- `git diff --check` - passed.
- `npm test` - passed, 28 files / 145 tests.
- `npm run lint` - passed.
- `npm run build` - passed.
- `npm run typecheck` - passed.
- Secret/scope scan - passed with one existing non-secret documentation reference noted below.

## I. Secret and Scope Scan

Secret/scope scan result:

- `.env.local` is ignored and not staged.
- `supabase/.temp` is ignored.
- `.next` is ignored.
- `.codex-dev-server.*.log` is ignored.
- No service role references were found in `app/` or `components/`.
- Filename-only sensitive-pattern scan found an existing setup report containing secret-safety references, not secret values.
- No real Clerk/Supabase/service-role values were added to docs/scripts/source.
- No bearer tokens, passwords, API secrets, or production data were added.
- No checkout/order/stock/payment/delivery mutation references were added to app/components/lib integration code.

## J. Files Changed

- `supabase/migrations/20260718193000_customer_profile_address_rpc_foundation.sql`
- `scripts/rpc/customer-profile-address-rpc-tests-dev-only.sql`
- `docs/RISELLAR_CUSTOMER_PHASE_A_PROFILE_ADDRESS_RPC_REPORT.md`

## K. Development Apply/Test Update

The Customer Phase A migration was applied successfully to the confirmed DEVELOPMENT Supabase project named `Risellar`:

- `20260718193000_customer_profile_address_rpc_foundation.sql`

The first development-only boundary test run failed before assertions with:

```text
ERROR: 42601: syntax error at or near "select"
```

Root cause: the development-only test script used nested `$$...$$` SQL strings inside an outer `DO $$ ... $$` block. PostgreSQL interpreted the first inner `$$` as the end of the outer block.

Classification: test assertion/harness bug.

No real customer profile/address security gap was confirmed by the initial failure. No migration, RPC, RLS, or storage policy was changed for this fix.

The test harness was updated so nested SQL assertion strings use `$sql$...$sql$` while the outer `DO $$ ... $$` block remains unchanged. All assertions were preserved.

The customer profile/address RPC boundary test was rerun once after explicit approval and passed. All returned assertion rows had `passed = true`.

Passed coverage confirmed:

- customer can upsert own contact
- customer can create, read, update, and archive own delivery address
- archived addresses are hidden from the customer RPC
- customer B cannot read, update, or archive customer A's active address
- default address behavior works
- required address/contact validation works
- reseller/supplier can only create their own buyer/customer foundation and cannot mutate another customer's address
- admin role does not bypass ownership through customer RPC
- no order, order item, stock reservation, delivery quote, commission, settlement, or withdrawal rows are created

## L. Current Status

Customer profile/address backend migration is applied to development, and the development-only Customer Phase A profile/address RPC boundary test passed.

Checkout, order creation, stock reservation, delivery quotes, payments, settlements, commissions, withdrawals, and purchase flow remain out of scope and unconnected.

## M. Exact Next Prompt

```text
Plan the next Customer Phase A UI/server-action integration step for customer contact and delivery address management.

Do NOT connect production Supabase.
Do NOT use production data.
Do NOT apply migrations.
Do NOT run destructive reset commands.
Do NOT run supabase db reset --linked.
Do NOT print secrets.
Do NOT commit .env.local.
Do NOT weaken RLS/RPC/storage policies.
Do NOT connect checkout, orders, stock reservation, payments, delivery, settlements, commissions, withdrawals, or customer purchase flow.
Do NOT run npm audit fix --force.
```
