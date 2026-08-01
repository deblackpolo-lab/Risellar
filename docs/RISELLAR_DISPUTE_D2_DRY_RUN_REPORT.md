# Risellar Dispute D2 Dry-Run Report

## A. Summary

D2 drafted the core dispute schema and read-only safe RPC foundation. The migration was not applied. No Supabase data was written. D1 documents remain uncommitted.

## B. Baseline

- Branch: `main`
- Baseline commit: `3a44db59879e76ebdb8bcb2204a70ca1fc4394cd`
- Pre-existing metadata status entries: `next-env.d.ts`, `tsconfig.json`
- Pre-existing D1 untracked docs remain uncommitted.

## C. Existing Artifact Audit

- Existing `public.disputes` and `public.returns` tables exist from the original schema foundation.
- Existing support/dispute/return/refund pages are mock-only Phase 13 artifacts.
- D2 does not activate or modify those artifacts.
- D2 creates a separate draft `public.order_disputes` foundation to avoid relying on old broad placeholder semantics.

## D. Schema Dependency Map

```text
order_disputes.order_id
  -> orders.id
  -> orders.customer_id -> customers.id -> customers.profile_id
  -> orders.reseller_id -> resellers.id -> resellers.profile_id
  -> order_items.order_id -> order_items.supplier_id -> suppliers.id -> suppliers.owner_profile_id
```

## E. Proposed Tables

- `public.order_disputes`
- `public.dispute_messages`
- `public.dispute_status_history`

No refund, return, finance-hold, wallet-adjustment, commission-adjustment, settlement-adjustment, withdrawal-allocation, evidence, notification, payment-provider, delivery-provider, stock, or reservation table was created.

## F. RLS And Grants

The draft enables and forces RLS, revokes direct table access from browser roles, and grants only safe RPC execute access to authenticated users.

## G. Safe-Read RPCs

- `list_customer_disputes_safe`
- `get_customer_dispute_safe`
- `list_supplier_disputes_safe`
- `get_supplier_dispute_safe`
- `get_reseller_dispute_impact_safe`
- `list_admin_disputes_safe`
- `get_admin_dispute_safe`

Helper functions resolve active role context from existing trusted profile/admin/supplier/customer/reseller tables.

## H. TypeScript Contract File Result

No TypeScript contract file was created. The project currently validates backend contract boundaries through migration text and SQL tests; adding a TS type file without UI/helper consumers would create an unused source artifact in a planning/dry-run phase.

## I. Static SQL Validation

Passed.

- `npx supabase db push --dry-run` completed successfully.
- Dry-run reported that migrations would not be pushed.
- Dry-run showed only `20260801120000_dispute_core_schema_and_safe_reads.sql` would be applied.
- Static scan found no D2 business-table mutations outside the new dispute tables.
- Static scan found no direct table grants to `authenticated`, `anon`, or `public`.
- Static scan found no direct helper-function execute grants to browser roles.
- Static scan found no `SELECT *` usage in the D2 migration.
- Safe-read RPCs use explicit return columns, filter validation, bounded pagination, and deterministic ordering.

## J. Automated Verification

- `git diff --check`: passed.
- `npm test`: passed, 48 test files and 289 tests.
- `npm run lint`: passed with zero warnings.
- `npm run build`: passed.
- `npm run typecheck`: passed.
- `npx tsc --noEmit`: passed.

## K. Security/Scope Scan

Passed with scoped findings.

- `.env.local` is ignored and not staged.
- `.next` is ignored.
- `.local-recovery` is ignored.
- `supabase/.temp` is ignored.
- `.codex-dev-server.*.log` files are ignored.
- No files are staged.
- No app, component, lib, or test source was intentionally modified for D2.
- No service-role usage was found in `app/`, `components/`, or the D2 migration/test script.
- Existing `lib/supabase/admin.ts` still contains the server-only service-role helper from previous work; D2 did not modify or consume it.
- No bearer tokens, provider credentials, passwords, database connection values, production data, private emails, profile IDs, supplier IDs, customer IDs, reseller IDs, order IDs, or JWT-like values were found in D2 files/docs.
- No checkout, order creation, stock reservation, payment, delivery, settlement, commission, withdrawal, refund, return, evidence, provider, or notification mutation was added.

## L. Files Changed

Intentional D2 files:

- `supabase/migrations/20260801120000_dispute_core_schema_and_safe_reads.sql`
- `scripts/rpc/dispute-core-schema-safe-reads-tests-dev-only.sql`
- `docs/RISELLAR_DISPUTE_D2_CORE_SCHEMA_DESIGN.md`
- `docs/RISELLAR_DISPUTE_D2_SAFE_READ_RPC_CONTRACTS.md`
- `docs/RISELLAR_DISPUTE_D2_RLS_AND_GRANT_REVIEW.md`
- `docs/RISELLAR_DISPUTE_D2_DRY_RUN_REPORT.md`

D1 docs remain untracked and uncommitted.

## M. Migration Apply Status

At D2 completion, this migration had not been applied and no real `supabase db push` had been run.

During D3, the approved D2 migration was applied to the confirmed DEVELOPMENT Supabase project. D3 found one schema omission after application: `dispute_status_history` needed the planned `idempotency_key`. That was fixed with a forward-only migration:

- `20260801123000_fix_dispute_status_history_idempotency.sql`

The D2 migration was not edited after application.

The SQL boundary test file was upgraded during D3 from a scaffolded assertion plan into an active rollback-scoped boundary suite. It passed 51 assertions in DEVELOPMENT.

## N. D3 Prerequisites

Before D3:

- User approval is required.
- Run `npx supabase db push --dry-run`.
- Review dry-run output.
- Apply only to confirmed development if approved.
- Run `scripts/rpc/dispute-core-schema-safe-reads-tests-dev-only.sql`.
- Add live fixtures only in development and clean them safely.
