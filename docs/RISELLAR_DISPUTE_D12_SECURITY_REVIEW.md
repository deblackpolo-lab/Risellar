# Risellar Dispute D12 Security Review

Date: 2026-08-02

## Security Findings

No new RLS, RPC, or migration weakening was performed in D12.

One test-harness defect was fixed:

- `scripts/rpc/dispute-core-schema-safe-reads-tests-dev-only.sql` was updated so D3 safe-read fixtures include explicit dispute target scope columns required by the later D5-A schema.
- The support-admin list assertions were scoped to the two rollback fixture dispute IDs instead of assuming the development database contains no other disputes.
- The final failure message now includes failed assertion details.

This was a development-only harness repair. It did not change application code, database policies, RPC definitions, grants, or migrations.

## Secret and Scope Scan

Checks performed:

- `.env.local` is ignored and not staged.
- `supabase/.temp` is ignored.
- `.next` is ignored.
- `.codex-dev-server.*.log` is ignored.
- No service-role import or service-role key reference exists in `app/` or `components/`.
- High-confidence secret scan found no real bearer tokens, JWTs, API secrets, passwords, or production data in tracked source/docs/scripts/tests.
- Expected historical matches are limited to documentation/test negative assertions, placeholder `.env.example` variable names, and the existing server-only `lib/supabase/admin.ts` helper.
- No order/payment/delivery/stock mutation integration references were added in `app/` or `components/`.

## Privacy Review

Backend tests verified safe reads and role separation for customer, supplier, reseller, support/admin, and finance contexts. Customer, supplier, reseller, support, and finance privacy matrices passed at the SQL/RPC level.

Browser privacy proof is incomplete for the mock-only dispute/return/refund/support UI routes and blocked support/super-admin sessions. These are release blockers for UI activation, not confirmed privacy leaks in the backend.

## Production Safety

Production application returned HTTP 200, but the root page still says the app is a Phase 1 design shell. Production protected-route behavior was not sufficient to claim full role-route browser readiness. Production Supabase was not connected during D12.
