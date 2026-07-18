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

## C. First Boundary Test Result

The first development-only customer profile/address RPC boundary test run failed before assertions.

Command:

```bash
npx supabase db query --linked --file scripts/rpc/customer-profile-address-rpc-tests-dev-only.sql
```

Failure:

```text
ERROR: 42601: syntax error at or near "select"
LINE 178: $$select count(*) from public.upsert_customer_contact(...)
```

## D. Failure Classification

Classification: test assertion/harness bug.

Root cause: the script used nested `$$...$$` SQL string literals inside an outer `DO $$ ... $$` block. PostgreSQL treated the first inner `$$` as the end of the outer DO block, so the script failed parsing before meaningful assertions ran.

No real customer profile/address security gap is confirmed yet.

## E. Harness Fix Applied

Updated:

- `scripts/rpc/customer-profile-address-rpc-tests-dev-only.sql`

Fix:

- Replaced nested SQL assertion string delimiters from `$$...$$` to `$sql$...$sql$` inside the outer `DO $$ ... $$` block.
- Kept all assertions.
- Did not weaken RLS/RPC/storage policies.
- Did not change the applied migration.

The customer profile/address RPC boundary test was not rerun after this fix. Rerun still requires explicit user approval.

## F. Security and Scope

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

## G. Commands Run

Development apply/test commands already run:

- `git status --short` - clean before development apply.
- `npx supabase --version` - `2.109.1`.
- `npx supabase db push` - succeeded; applied `20260718193000_customer_profile_address_rpc_foundation.sql`.
- `npx supabase db query --linked --file scripts/rpc/customer-profile-address-rpc-tests-dev-only.sql` - failed before assertions with SQL quoting error.

Harness-fix verification commands:

- `git status --short`
- `git diff --check`
- `npm test`
- `npm run lint`
- `npm run build`
- `npm run typecheck`

Final results are recorded in the commit turn summary.

## H. Secret and Scope Scan

Secret/scope scan required before commit:

- confirm `.env.local` is ignored and not staged
- confirm `supabase/.temp` is ignored
- confirm `.next` is ignored
- confirm `.codex-dev-server.*.log` is ignored
- confirm no real Clerk/Supabase/service-role values in docs/scripts/source
- confirm no service role in app/components
- confirm no bearer tokens, passwords, API secrets, or production data
- confirm no checkout/order/stock/payment/delivery mutation integration was added

## I. Current Status

Development migration apply succeeded. Boundary-test verification is pending after the SQL quoting harness fix.

Production remains blocked. The next action is an explicitly approved rerun of:

```bash
npx supabase db query --linked --file scripts/rpc/customer-profile-address-rpc-tests-dev-only.sql
```
