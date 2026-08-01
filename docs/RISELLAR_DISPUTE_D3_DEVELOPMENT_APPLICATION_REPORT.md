# Risellar Dispute D3 Development Application Report

## A. Summary

D3 created a local D1/D2 checkpoint, applied the approved core dispute safe-read schema to the confirmed DEVELOPMENT Supabase project, fixed one proven D2 schema omission through a forward-only migration, and verified schema, RLS, grants, ownership, privacy, empty states, and no-side-effect behavior.

No production project was used. No customer dispute opening flow, supplier response flow, admin resolution flow, return flow, refund flow, finance hold, evidence upload, notification, order mutation, payment mutation, stock mutation, commission mutation, settlement mutation, wallet mutation, or withdrawal mutation was implemented.

## B. Development Project Confirmation

- Branch before D1/D2 checkpoint: `main`
- Baseline commit before local D1/D2 work: `3a44db59879e76ebdb8bcb2204a70ca1fc4394cd`
- Linked Supabase project name confirmed safely as `Risellar`.
- Local `.env.local` exists, is ignored, and matches the linked Supabase project without printing project references or secrets.
- `.next`, `.local-recovery`, `.codex-dev-server.*.log`, and `supabase/.temp` are ignored.

## C. Local Checkpoint

- D1/D2 checkpoint commit: `738384757bcdf7e32c787fa875d4861daefcc791`
- Commit message: `Design dispute core schema and safe reads`
- Push status: not pushed.
- Only D1/D2 docs, the D2 migration, and the D2 SQL verification script were committed.
- Generated metadata files `next-env.d.ts` and `tsconfig.json` remained unstaged.

## D. Migration Application

Applied to DEVELOPMENT:

- `20260801120000_dispute_core_schema_and_safe_reads.sql`

Forward fix applied to DEVELOPMENT:

- `20260801123000_fix_dispute_status_history_idempotency.sql`

The forward fix was needed because `dispute_status_history` had the intended append-only transition structure but lacked the planned idempotency field. The fix added only:

- nullable `idempotency_key`
- safety CHECK constraint
- scoped unique index on `(dispute_id, idempotency_key)` where key is present

No applied migration was edited in place.

## E. Schema Objects Created

Tables:

- `public.order_disputes`
- `public.dispute_messages`
- `public.dispute_status_history`

Safe-read RPCs:

- `public.list_customer_disputes_safe`
- `public.get_customer_dispute_safe`
- `public.list_supplier_disputes_safe`
- `public.get_supplier_dispute_safe`
- `public.get_reseller_dispute_impact_safe`
- `public.list_admin_disputes_safe`
- `public.get_admin_dispute_safe`

Internal helper functions remain ungranted directly to browser roles.

## F. Schema Verification

Verified:

- `order_disputes` has order/opened-by links, controlled category/reason/outcome/status/priority fields, assignment, action flags, finance/return review flags, resolution fields, idempotency, timestamps, and soft delete.
- `dispute_messages` has dispute link, author identity fields, sender role, message type, visibility, bounded plain-text body, system marker, timestamps, and soft delete.
- `dispute_status_history` has dispute link, old/new status, actor identity, actor role, public/internal notes, idempotency, append-only timestamp, and constraints.
- No refund amount fields, return shipment fields, finance hold fields, commission adjustment fields, wallet adjustment fields, or stock adjustment fields were added.

## G. RLS, Grants, And Security Definer

Verified:

- RLS is enabled and forced on all three D2 tables.
- `public`, `anon`, and `authenticated` have no direct table privileges for the D2 tables.
- Browser access is limited to safe-read RPC execution.
- Helper functions are not directly executable by browser roles.
- All new D2 functions are `SECURITY DEFINER` with fixed `search_path=public`.
- Safe-read RPCs resolve identity from the authenticated profile and do not trust caller-supplied profile/customer/supplier/reseller IDs.
- Pagination is bounded and filters fail safely.
- No D2 function changes business data.

## H. Boundary Test Result

`scripts/rpc/dispute-core-schema-safe-reads-tests-dev-only.sql` was upgraded from scaffold to an active transaction-wrapped boundary suite and run against DEVELOPMENT.

Result:

- 51 assertions passed.
- 0 assertions failed.
- Fixtures were created inside a transaction and rolled back.
- Final permanent dispute rows: zero in all three D2 tables.

Verified:

- anonymous and authenticated direct table access blocked
- customer A cannot read customer B disputes
- supplier A cannot read supplier B disputes
- reseller receives impact-only summary
- support/admin can read non-finance case context
- finance staff can see restricted finance-review indicators
- ordinary support/admin cannot see restricted finance context
- inactive admin blocked
- suspended profile blocked
- invalid controlled values rejected
- duplicate active disputes blocked
- duplicate status-history idempotency blocked
- empty-state lists/details are safe

## I. No-Business-Side-Effect Check

Aggregate counts before and after D3 matched for existing business tables:

- orders
- order items
- products
- stock reservations
- settlements
- commissions
- withdrawals
- audit logs
- notification outbox
- notification provider events

Optional/nonexistent payment and wallet table names were confirmed absent rather than assumed.

Allowed permanent changes:

- migration history
- D2 schema objects
- D3 idempotency fix schema object

## J. Defects And Fixes

Defect found:

- `dispute_status_history` lacked the planned idempotency key.

Forward fix:

- `20260801123000_fix_dispute_status_history_idempotency.sql`

No RLS, grants, safe-read visibility, finance, order, stock, payment, settlement, commission, withdrawal, return, refund, evidence, or notification behavior was weakened or broadened.

## K. Verification Commands

- `git diff --check`: passed.
- `npm test`: passed before D1/D2 checkpoint, 48 files / 289 tests.
- `npm run lint`: passed before D1/D2 checkpoint.
- `npm run build`: passed before D1/D2 checkpoint.
- `npm run typecheck`: passed before D1/D2 checkpoint.
- `npx tsc --noEmit`: passed before D1/D2 checkpoint.
- Final automated verification was rerun after D3 docs and fixes; see final response for exact final command results.

## L. Current Status

D3 is ready for the final local verification commit if the final command suite and security scan pass.

D4 may begin after the D3 verification commit. D4 should still avoid UI activation until explicit dispute-opening mutation RPCs are designed, applied, tested, and approved.
