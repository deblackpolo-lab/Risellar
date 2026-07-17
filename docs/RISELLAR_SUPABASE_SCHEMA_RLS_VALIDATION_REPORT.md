# Risellar Supabase Schema RLS Validation Report

Date: 2026-07-17

## A. Files reviewed

Branch reviewed: `origin/backend/supabase-schema-rls-foundation`

Diff reviewed against clean `origin/main` at `9476043f`:

- `docs/RISELLAR_SUPABASE_SCHEMA_RLS_FOUNDATION_REPORT.md`
- `supabase/config.toml`
- `supabase/migrations/20260717000000_risellar_schema_rls_foundation.sql`

No `app`, `components`, `lib`, or `tests` files are changed by this branch.

## B. Tables / migrations reviewed

Migration reviewed:

- `supabase/migrations/20260717000000_risellar_schema_rls_foundation.sql`

The migration creates 24 application tables:

- `profiles`
- `admin_staff`
- `customers`
- `resellers`
- `reseller_shops`
- `suppliers`
- `supplier_team_members`
- `products`
- `product_variants`
- `product_images`
- `inventory_movements`
- `reseller_products`
- `orders`
- `order_items`
- `stock_reservations`
- `delivery_quotes`
- `settlements`
- `commissions`
- `withdrawals`
- `disputes`
- `returns`
- `notifications`
- `audit_logs`
- `admin_actions`

Static coverage check found:

- 24 `create table public.*` statements.
- 24 `enable row level security` statements.
- 24 `force row level security` statements.
- 43 `create policy` statements.

## C. RLS policy review

Positive findings:

- RLS is enabled and forced on every application table in the migration.
- No policies use `auth.uid()` directly.
- Identity is centralized through `public.jwt_subject()` and `public.current_profile_id()`.
- No obvious anonymous/public write policy with `using (true)` or `with check (true)` was found.
- Direct stock reservation and order item inserts are admin-only until RPCs exist.
- Sensitive catalog table comments correctly warn that base price/platform margin columns need safe views or RPCs.
- `search_path = public` is set on security-definer helper functions.

Important concerns:

- Several policies use `FOR ALL`, which includes DELETE. Examples include `reseller_shops_write_owner_or_admin`, `supplier_team_write_owner_or_admin`, `products_write_supplier_product_permission_or_admin`, `product_variants_write_stock_permission_or_admin`, `product_images_write_supplier_or_admin`, `reseller_products_write_owner_or_admin`, `delivery_quotes_write_admin_or_supplier_member`, `settlements_write_finance_admin`, `commissions_write_finance_admin`, and `admin_actions_write_admins`. The schema uses soft-delete columns, but these policies allow physical deletes for authorized actors unless the application never exposes direct table access.
- Several self/owner update policies are table-wide. Because PostgreSQL RLS is row-level, not column-level, these policies can allow clients to update sensitive columns if tables are exposed directly:
  - `profiles_update_own_basic_or_admin` can allow self-updates to role/status-style profile columns.
  - `resellers_update_own_limited_or_admin` can allow reseller-owned updates to `approval_status`, `risk_level`, payout status, and commission amounts.
  - `suppliers_update_owner_or_admin` can allow supplier owners to update verification, risk, settlement, and trust/status fields.
  - `customers_update_own_or_admin` can allow customers to update risk/status fields.
  - `orders_update_participants_or_admin` can allow participants to update order state fields.
- Admin/support/finance bypasses are present, but the migration does not enforce audit logging as part of those privileged updates. The `audit_logs` table exists, but RLS alone does not require writing audit rows.
- Role naming drifts from current `main`: the auth role policy uses `supplier_inventory_manager`, while the SQL uses `inventory_manager` / supplier role `inventory_manager`. This should be normalized before merge or before any app wiring.
- Security-definer helper functions are executable by default unless privileges are explicitly changed. Some helper functions only reveal booleans/current profile context, but direct execution permissions should still be reviewed and restricted if needed.
- Public/customer catalog reads are not provided yet. That is acceptable for a foundation draft, but direct table reads would expose sensitive columns to any role allowed by table policies.

## D. Security concerns

Severity for merge decision: not safe to merge yet.

Reasons:

- Table-wide self/owner update policies create privilege-escalation and financial-integrity risk if Supabase tables are directly available to authenticated clients.
- Broad `FOR ALL` policies allow physical DELETE paths where the data model appears to expect soft deletes and audited transitions.
- Admin/finance/support transitions are not tied to audit-log writes.
- No local Supabase/Postgres execution was available, so SQL syntax, function behavior, recursion behavior, and RLS boundaries were not proven.
- `git diff --check` failed on `supabase/config.toml` because of a blank line at EOF.

No production Supabase connection, production secrets, `.env`, or `.env.local` files were used or added.

## E. Local Supabase validation result

Local Supabase validation was not run.

Reason:

- `supabase` CLI was not found on PATH.
- `psql` was not found on PATH.
- `docker` was not found on PATH.

Therefore:

> SQL/RLS reviewed statically only; local Supabase validation still required.

No `supabase db reset` or `supabase test db` command was run.

## F. Secret scan result

Result: pass, with documentation-only false positives.

Findings:

- No `.env` or `.env.local` files found in the reviewed diff/worktrees.
- No production Supabase URL, project ID, access token, service-role key, Clerk secret, Resend key, Paystack/Hubtel secret, password assignment, private key, or bearer token value was found.
- Pattern matches were limited to explanatory documentation/comments such as "no secrets", "service_role" in scan-command text, and comments warning not to store secrets.

## G. Commands run / results

Setup and diff inspection:

- `git fetch origin main backend/supabase-schema-rls-foundation`
  - Passed.
- Clean validation worktree from `origin/main`
  - `HEAD`: `9476043f`
  - `git status --short`: clean.
- Branch validation worktree from `origin/backend/supabase-schema-rls-foundation`
  - `HEAD`: `05ac9544`
  - `git status --short`: clean before checks.
- `git diff --name-only origin/main...origin/backend/supabase-schema-rls-foundation`
  - Listed the three reviewed files.
- `git diff origin/main...origin/backend/supabase-schema-rls-foundation -- supabase docs tests lib app components`
  - Reviewed diff content.

Static SQL/RLS checks:

- `rg -n '^create table public\\.' supabase/migrations/20260717000000_risellar_schema_rls_foundation.sql`
  - Found 24 tables.
- `rg -n 'enable row level security|force row level security' ...`
  - Found enable/force RLS statements for all 24 tables.
- `rg -n '^create policy' ...`
  - Found 43 policies.
- `rg -n 'for all|for insert|for update|for delete|to public|to anon|to authenticated|using \\(true\\)|with check \\(true\\)' ...`
  - Found multiple `FOR ALL` policies; found no `using (true)` / `with check (true)` policies.
- `git diff --check origin/main...origin/backend/supabase-schema-rls-foundation`
  - Failed: `supabase/config.toml:10: new blank line at EOF.`
- `Get-Command supabase`, `Get-Command psql`, `Get-Command docker`
  - Not found on PATH.

Normal repo checks on the branch worktree:

- `npm ci`
  - Passed. NPM reported 7 vulnerabilities; no `npm audit fix --force` was run.
- `npm test`
  - Passed: 16 files, 67 tests.
- `npm run typecheck`
  - Passed.
- `npm run lint`
  - Passed.
- `npm run build`
  - Passed; generated 160 static pages.

## H. Whether this branch is safe to merge

Safe to merge: no.

Validation level: static only.

The branch is a useful schema/RLS foundation draft, and the regular frontend repo checks pass, but it should not merge to `main` until the RLS update/delete risks are narrowed and the migration has been executed locally against Supabase/Postgres with RLS boundary tests.

## I. Required fix prompt

```text
You are the Risellar Supabase schema/RLS hardening agent.

Work only on `backend/supabase-schema-rls-foundation`.
Do not connect to production Supabase.
Do not add `.env`, `.env.local`, secrets, service-role keys, production project IDs, or provider integrations.
Do not merge to main.
Do not run `npm audit fix --force`.

Fix the Supabase foundation migration so it is safe to merge:

1. Replace broad table-wide self/owner update policies with safer policies/RPC expectations.
   - Do not let customers update risk/status fields.
   - Do not let resellers update approval, risk, payout status, or commission amounts.
   - Do not let supplier owners update verification, risk, settlement, trust, or admin-controlled status fields.
   - Do not let order participants directly update sensitive order/payment/delivery status fields.

2. Replace `FOR ALL` policies where physical DELETE is not intended.
   - Use operation-specific `SELECT`, `INSERT`, and `UPDATE` policies.
   - Keep physical DELETE admin-only or unavailable unless an audited hard-delete path is explicitly required.

3. Add or document audited RPC-only paths for privileged admin/support/finance transitions.
   - Admin/finance/support mutations should require audit logging and reason metadata.

4. Normalize role naming with current main.
   - Align SQL role names with `lib/auth/role-policy.ts`, especially `supplier_inventory_manager` vs `inventory_manager`, or document a single canonical mapping with tests.

5. Fix `git diff --check`.
   - Remove the blank line issue in `supabase/config.toml`.

6. Validate locally without production credentials.
   - Run local Supabase/Postgres migration validation only.
   - Add representative RLS boundary tests for customer, reseller, supplier owner, inventory manager, finance/support/admin, and anonymous access.

Run and report:
- git diff --check
- local Supabase/Postgres migration validation command used
- local RLS boundary tests
- npm test
- npm run typecheck
- npm run lint
- npm run build
- secret/env scan

Report exact files changed, risks fixed, residual risks, and whether the branch is ready for QA re-review.
```

## End summary

- Safe to merge: no.
- Validation level: static only.
- Risks found: broad table-wide update policies, multiple `FOR ALL`/DELETE-capable policies, privileged bypasses not coupled to audit writes, role naming drift, no local SQL/RLS execution, and `git diff --check` failure.
- Required fixes: see section I.
- Current local repo status: original checkout remains locally divergent from `origin/main` due an earlier unpushed local-only merge; validation used clean temporary worktrees to avoid rewriting history or merging this branch.
