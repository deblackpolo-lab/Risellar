# Risellar Local Supabase Validation Readiness Report

## A. Summary

Local Supabase/Postgres migration execution is not possible on this machine yet because the required local database tools are not installed or not available on `PATH`.

Production Supabase apply remains blocked.

The schema/RLS foundation was reviewed statically from `main` at `a08438ea2a3ef3366cd83deb0a2362cf3427c40d`. Normal repository checks passed, but the migration has not been executed locally and RLS boundary tests have not been run.

## B. Local Tools Found / Missing

| Tool | Result |
| --- | --- |
| Supabase CLI | Missing: `supabase` command not found |
| Docker | Missing: `docker` command not found |
| psql | Missing: `psql` command not found |
| Node.js | Found: `v24.16.0` |
| npm | Found: `11.13.0` |

Required setup before local database validation:

1. Install Docker Desktop and confirm `docker --version` works.
2. Install Supabase CLI and confirm `supabase --version` works.
3. Install PostgreSQL client tools or otherwise expose `psql --version`.
4. Re-run local-only validation commands from the repository root.

## C. Files Reviewed

- `supabase/config.toml`
- `supabase/migrations/20260717000000_risellar_schema_rls_foundation.sql`
- `docs/RISELLAR_SUPABASE_SCHEMA_RLS_FOUNDATION_REPORT.md`
- `docs/RISELLAR_SUPABASE_SCHEMA_RLS_HARDENING_REPORT.md`
- `docs/RISELLAR_SUPABASE_SCHEMA_RLS_FINAL_QA_REPORT.md`

## D. Migration Execution

Migration execution was not run.

Blocked commands:

- `supabase start`
- `supabase db reset`
- `supabase test db`
- direct `psql` syntax validation

Reason: Supabase CLI, Docker, and `psql` are not available locally.

## E. Migration Static Review Result

Static migration checks found:

| Check | Result |
| --- | --- |
| Tables created | 24 |
| Tables with RLS enabled | 24 |
| Tables with RLS forced | 24 |
| Policies created | 68 |
| `FOR ALL` policies | 0 |
| `FOR DELETE` policies | 0 |
| `USING (true)` | 0 |
| `WITH CHECK (true)` | 0 |
| Bare `inventory_manager` role drift | 0 |

The migration represents product images, supplier inventory manager roles, audit logs, product/order/stock/settlement/commission tables, and comments documenting future audited RPC/server-action requirements.

Static review does not prove SQL execution correctness, extension availability, trigger/function behavior, enum compatibility, or runtime RLS boundaries.

## F. RLS Tests Exist / Pass

No Supabase database RLS test suite was found under `supabase/`.

`supabase test db` was not run because local Supabase tooling is missing. Existing Vitest tests passed, but those are application/unit/UI tests and do not validate database RLS behavior.

## G. RLS Boundary Test Plan

Anonymous:

- Cannot select protected operational tables directly.
- Cannot insert, update, or delete any protected table.
- Can access only future public-safe catalog/shop views or RPCs once implemented.

Customer:

- Can read only own profile/customer/order/order-item/support/notification rows.
- Cannot read another customer account, order, support ticket, return, refund, or dispute.
- Cannot mutate role, status, verification status, risk score, approval fields, payment status, delivery status, price snapshots, ownership foreign keys, audit fields, or admin notes.
- Cannot delete any protected row.

Reseller:

- Can read only own reseller profile, shop, listings, orders, commissions, withdrawals, support, and relevant notifications.
- Cannot read another reseller's shop administration data, wallet, commissions, withdrawals, or customer/order internals outside owned order participation.
- Cannot directly change approval status, risk score, payout status, commission status, commission totals, listing ownership, internal notes, or price snapshot fields.
- Cannot delete any protected row.

Supplier owner:

- Can read own supplier profile, products, variants, images, inventory movements, order items, settlements, team members, support rows, and notifications.
- Cannot read another supplier's products, order items, inventory, settlements, team members, or verification data.
- Cannot directly mutate verification status, risk score, settlement status, trust score, ownership foreign keys, internal notes, audit fields, or immutable order/price snapshot data.
- Product, media, settlement, and stock mutations that affect sensitive fields must move through audited RPC/server actions before production use.

Supplier inventory manager:

- Can read supplier-scoped operational product, variant, image, inventory, and assigned order information as permitted by supplier membership.
- Cannot access supplier payout details, settlements, finance-only fields, team permission administration, owner-only settings, verification/risk fields, or admin notes.
- Cannot perform privileged product, price, or stock changes except through future permission-checked RPC/server actions.

Support, finance, and admin operators:

- Support can read support/admin queue data required for operations.
- Finance can access settlement, commission, and withdrawal queues as scoped by RLS.
- Admin and finance direct writes currently exist as foundation policies, but production mutation paths must be moved to audited RPC/server actions with reason metadata and same-transaction audit rows.
- Operator roles must not bypass audit requirements for sensitive status, payout, settlement, commission, risk, approval, or manual override changes.

Super admin:

- Can manage admin staff where policies permit.
- Cannot rely on direct deletes; destructive actions require explicit future audited hard-delete or soft-delete procedures.
- Role and permission changes must be audited in the same transaction before production use.

Audit logs:

- Admins can read audit logs.
- Actor/admin inserts are allowed by foundation policy.
- Updates and deletes must remain unavailable.
- Future privileged workflows must write audit records in the same transaction as the protected mutation.

## H. Blocked Items

- Install and verify Supabase CLI.
- Install and verify Docker.
- Install and verify `psql`.
- Execute `supabase start` and `supabase db reset` locally.
- Add database fixtures for each role boundary.
- Add RLS boundary tests for anonymous, customer, reseller, supplier owner, supplier inventory manager, support, finance, admin, and super admin.
- Implement or plan production-safe audited RPCs/views/grants for sensitive mutations and public reads.
- Implement storage bucket policies before any production storage rollout.

## I. Commands Run / Results

| Command | Result |
| --- | --- |
| `git status --short --branch` | Clean `main...origin/main` |
| `git rev-parse HEAD` | `a08438ea2a3ef3366cd83deb0a2362cf3427c40d` |
| `git log --oneline -5` | Latest commit `a08438ea Merge hardened Supabase schema RLS foundation` |
| `Get-Command supabase,docker,psql,node,npm` | Found Node/npm only; Supabase CLI, Docker, and `psql` missing |
| `supabase --version` | Command not found |
| `docker --version` | Command not found |
| `psql --version` | Command not found |
| `node --version` | `v24.16.0` |
| `npm --version` | `11.13.0` |
| `Test-Path` for reviewed files | All reviewed files present |
| Static migration count script | 24 tables, 24 RLS enabled, 24 RLS forced, 68 policies |
| `rg` risk scan for `FOR ALL`, `FOR DELETE`, `USING (true)`, `WITH CHECK (true)`, `service_role`, password/bearer patterns | SQL clean; documentation/comment-only hits |
| `rg --files supabase \| rg "(test|tests|spec|\\.sql$)"` | No database RLS tests found; only migration SQL matched |
| `git diff --check` | Passed |
| `npm test` | Passed: 19 files, 85 tests |
| `npm run typecheck` | Passed |
| `npm run lint` | Passed |
| `npm run build` | Passed |
| env-file scan with `rg --files -uu -g ".env" -g ".env.*"` | No `.env` or `.env.*` files found |
| secret-pattern scan across source/docs/supabase/tests | No secret values found; matches were package names and documentation/comment references |

## J. Secret / Env Scan Result

Pass.

No `.env`, `.env.local`, API key value, token value, password assignment, Clerk secret, Supabase service-role key, Resend key, Paystack/Hubtel secret, private key, or bearer token value was found.

Pattern matches were false positives or documentation/comment-only references, including package names such as `css-tokenizer` / `js-tokens` and reports that explicitly discuss not adding secrets.

## K. Files Changed

- `docs/RISELLAR_LOCAL_SUPABASE_VALIDATION_READINESS_REPORT.md`

## L. Current Git Status

Expected after this report is created:

- `?? docs/RISELLAR_LOCAL_SUPABASE_VALIDATION_READINESS_REPORT.md`

No commit was created.

## M. Recommendation

Local Supabase validation is not possible on this machine until Supabase CLI, Docker, and `psql` are installed.

Production Supabase apply remains blocked.

Recommended next step: install the missing local database tooling, then run `supabase start`, `supabase db reset`, add role-based RLS fixtures/tests, and run `supabase test db` before any production migration apply is considered.
