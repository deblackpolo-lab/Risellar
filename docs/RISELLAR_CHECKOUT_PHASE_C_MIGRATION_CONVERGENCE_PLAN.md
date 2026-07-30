# Risellar Checkout Phase C Migration Convergence Plan

## Summary

This plan explains how the existing contaminated DEVELOPMENT project, brand-new clean environments, and local CI/test databases can converge to the same approved schema without restoring unapproved Claude-era SQL.

## Recommended Migration Sequence

1. Six exact-version no-op tombstones:
   - `20260718210000_reviewed_tombstone_create_order_from_draft.sql`
   - `20260724000000_reviewed_tombstone_order_confirmation_expiry.sql`
   - `20260724010000_reviewed_tombstone_supplier_prepare_rpc.sql`
   - `20260725000000_reviewed_tombstone_order_expiry_index.sql`
   - `20260725020000_reviewed_tombstone_delivery_prepare_fields.sql`
   - `20260725030000_reviewed_tombstone_update_supplier_prepare_rpc.sql`
2. Forward cleanup migration:
   - `20260718212000_reconcile_checkout_phase_c_claude_artifacts.sql`
3. Approved Phase C order creation migration:
   - `20260718213000_create_order_from_checkout_draft_rpc.sql`

The Phase C migration should be revised before implementation if the cleanup removes `orders.expires_at`.

## Existing Contaminated DEVELOPMENT Project

Initial state:

- Six remote-only versions are already marked applied.
- Claude-era schema effects remain active.
- 23 orders have `orders.expires_at`.

Behavior:

- Tombstones are not executed because the remote history already contains those versions.
- Cleanup migration executes and removes stale functions, grants, index, and obsolete columns according to approved checks.
- Phase C migration executes after cleanup and creates only approved order-from-draft RPC behavior.

Expected final state:

- Migration history aligns with local source.
- Stale `create_order_from_draft` and `prepare_supplier_for_order` are absent.
- Approved `create_order_from_checkout_draft` exists.
- No payment, delivery, supplier-prep, commission, settlement, withdrawal, or refund flow is enabled.

## Brand-New Clean Environment

Initial state:

- No remote-only Claude-era history.
- No Claude-era schema effects.

Behavior:

- Six tombstones execute as comment-only no-ops.
- Cleanup migration uses guarded `if exists` statements and no-ops where Claude-era objects are absent.
- Phase C migration creates approved schema.

Expected final state:

- No Claude-era functions ever exist.
- Approved Phase C schema exists.
- Schema matches the cleaned DEVELOPMENT project, except for deferred enum cleanup if DEVELOPMENT temporarily keeps `delivery_person`.

## Local CI/Test Database

Initial state:

- Applies migrations from active source.

Behavior:

- Tombstones execute as no-ops.
- Cleanup migration must be safe when stale objects are absent.
- Phase C migration applies approved schema.

Expected final state:

- Tests see no Claude-era RPCs.
- Approved order creation boundary is available for Phase C tests.
- No final checkout confirmation UI or payment/delivery side effects are introduced.

## Preconditions

Before Group R2 implementation:

- Confirm HEAD/branch.
- Confirm DEVELOPMENT project name.
- Confirm `.env.local`, `.local-recovery`, `.next`, `supabase/.temp`, and dev logs are ignored.
- Confirm no staged files.
- Confirm all six original migrations remain quarantined.

Before future apply:

- Run approved dry-run after tombstones and cleanup migration exist.
- Confirm pending remote migrations are cleanup and Phase C only.
- Confirm no production project is linked.

## Assertions

Pre-apply read-only assertions:

- Old functions present or absent as expected.
- 23-order aggregate count is unchanged or explicitly reviewed.
- Preparation/delivery fields remain unpopulated.
- No delivery quotes, commissions, settlements, or stock reservations depend on stale order flow.
- `delivery_person` enum usage remains zero.

Cleanup migration assertions:

- Drop exact stale function signatures only.
- Drop exact stale index only.
- Drop exact obsolete columns only after dependency counts pass.
- Leave enum value temporarily.

Post-apply assertions:

- Stale functions absent.
- Stale index absent.
- Obsolete columns absent or preserved according to the approved plan.
- Approved Phase C RPC exists only after Phase C apply.
- No order/payment/delivery/settlement/commission/withdrawal rows created by cleanup.

## Validation Sequence

1. Create tombstone files.
2. Create cleanup migration.
3. Review all SQL.
4. Run local migration-chain verification if supported.
5. Run Supabase dry-run.
6. Confirm only cleanup plus Phase C appear pending remotely.
7. Commit migration foundation.
8. Back up DEVELOPMENT.
9. Apply cleanup to DEVELOPMENT.
10. Verify stale functions removed.
11. Verify expected fields/indexes removed or preserved.
12. Verify 23 rows handled correctly.
13. Apply Phase C migration.
14. Run Phase C RPC boundary tests.
15. Run true two-session concurrency test.
16. Run app tests/build/typecheck.
17. Run live order-confirmation QA only in a later approved group.

## Preserve Versus Rebuild Decision Matrix

| Factor | Preserve current DEVELOPMENT | Rebuild DEVELOPMENT |
| --- | --- | --- |
| Engineering effort | Medium; tombstones and cleanup required | High; relink services and recreate QA data |
| Data preservation | Preserves QA profiles/products/listings/addresses/drafts/orders | Loses or requires recreating QA state |
| Security risk | Requires careful cleanup of stale functions/grants | Lowest once rebuilt cleanly |
| Migration risk | Medium; cleanup must be guarded | Low after clean migration chain applies |
| Reproducibility | Good after tombstones/cleanup | Best |
| Time | Faster if cleanup is straightforward | Slower |
| Maintainability | Good if documented and tested | Best |

Recommendation:

- Preserve current DEVELOPMENT as primary because it retains useful QA state and contamination appears bounded.
- Rebuild only if cleanup dry-run or preconditions reveal broader hidden contamination.
