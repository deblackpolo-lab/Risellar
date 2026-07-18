# Risellar Customer Phase A Development Apply and Test Report

Date: 2026-07-18

## A. Development Project Confirmation

The Customer Phase A profile/address RPC migration was applied to the confirmed DEVELOPMENT Supabase project named `Risellar`.

No production Supabase connection was used.

## B. Migration Applied

Applied to development:

- `20260718193000_customer_profile_address_rpc_foundation.sql`

The apply step used:

```bash
npx supabase db push
```

No destructive reset command was run.

## C. Boundary Test Result

The first development-only customer profile/address RPC boundary test run failed before assertions because of a test harness quoting bug. After the quoting fix in commit `4c8fc7656c0c6ae52c229410543cbcfe186741ef`, the test was rerun once with explicit approval.

Command:

```bash
npx supabase db query --linked --file scripts/rpc/customer-profile-address-rpc-tests-dev-only.sql
```

Initial failure:

```text
ERROR: 42601: syntax error at or near "select"
LINE 178: $$select count(*) from public.upsert_customer_contact(...)
```

Rerun result: passed.

All returned assertion rows had `passed = true`.

## D. Failure Classification

Initial failure classification: test assertion/harness bug.

Root cause: the script used nested `$$...$$` SQL string literals inside an outer `DO $$ ... $$` block. PostgreSQL treated the first inner `$$` as the end of the outer DO block, so the script failed parsing before meaningful assertions ran.

No real customer profile/address security gap was confirmed by the initial failure.

## E. Harness Fix Applied

Updated:

- `scripts/rpc/customer-profile-address-rpc-tests-dev-only.sql`

Fix:

- Replaced nested SQL assertion string delimiters from `$$...$$` to `$sql$...$sql$` inside the outer `DO $$ ... $$` block.
- Kept all assertions.
- Did not weaken RLS/RPC/storage policies.
- Did not change the applied migration.

The customer profile/address RPC boundary test was rerun once after explicit user approval and passed.

## F. Passed Assertions

The passing boundary test verified:

- anonymous users cannot upsert customer contact
- anonymous users cannot create delivery addresses
- customer can upsert own contact
- customer contact update preserves customer role
- customer contact upsert creates customer foundation
- customer can create own delivery address
- customer can read own delivery address through RPC
- default address is marked default
- customer can update own address
- customer own address update persisted
- customer can create a second active address
- second active address is visible to owner
- customer can archive own address
- archived address is soft deleted
- archived address is hidden from customer RPC
- required phone validation blocks bad address creation
- required recipient validation blocks bad address creation
- required city/area/street validation blocks bad address creation
- second customer can create own contact and own delivery address
- customer B cannot read customer A active address
- customer B cannot update customer A active address
- customer B cannot archive customer A active address
- reseller can use customer contact RPC only for own customer foundation
- reseller cannot update another customer address
- supplier can use customer contact RPC only for own customer foundation
- supplier cannot archive another customer address
- admin role does not bypass address ownership through customer RPC
- no order rows are created
- no order item rows are created
- no stock reservation rows are created
- no delivery quote rows are created
- no commission rows are created
- no settlement rows are created
- no withdrawal rows are created

## G. Security and Scope

No live integration was added for:

- checkout
- order creation
- stock reservation
- payments
- delivery quotes
- settlements
- commissions
- withdrawals
- customer purchase flow

No service role usage was added to app/components.

## H. Commands Run

Development apply/test commands already run:

- `git status --short` - clean before development apply.
- `npx supabase --version` - `2.109.1`.
- `npx supabase db push` - succeeded; applied `20260718193000_customer_profile_address_rpc_foundation.sql`.
- `npx supabase db query --linked --file scripts/rpc/customer-profile-address-rpc-tests-dev-only.sql` - failed before assertions with SQL quoting error.
- `npx supabase db query --linked --file scripts/rpc/customer-profile-address-rpc-tests-dev-only.sql` - rerun after quoting fix passed; all assertion rows returned `passed = true`.

Verification commands:

- `git status --short`
- `npm test` - passed, 28 files / 145 tests.
- `npm run lint` - passed.
- `npm run build` - passed.
- `npm run typecheck` - passed.

`git diff --check` and final secret/scope scan were run after report updates.

## I. Secret and Scope Scan

Secret/scope scan result:

- `.env.local` is ignored and not staged.
- `supabase/.temp` is ignored.
- `.next` is ignored.
- `.codex-dev-server.*.log` is ignored.
- No real Clerk/Supabase/service-role values were added to docs/scripts/source.
- No service role references were found in `app/` or `components/`.
- No bearer tokens, passwords, API secrets, or production data were added.
- No checkout/order/stock/payment/delivery mutation integration was added.

## J. Fixture Cleanup

The boundary test script is transaction-wrapped and ends with `rollback`, so fake/dev-only fixture profiles, customers, customer addresses, and audit rows are rolled back.

## K. Current Status

Development migration apply succeeded. Customer Phase A profile/address RPC boundary tests passed.

Customer profile/address backend is ready for the next explicitly approved customer-account UI/server-action planning step. Checkout, order creation, stock reservation, delivery quotes, payments, settlements, commissions, withdrawals, and purchase flow remain out of scope and unconnected.
