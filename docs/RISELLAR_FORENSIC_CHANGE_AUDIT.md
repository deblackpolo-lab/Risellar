# Risellar Forensic Change Audit

Date: 2026-07-29

Safe baseline: `94f6eb69ca1d22c475997f52d4d7729d52dfd0b7`

## Summary

The working tree contains uncontrolled, uncommitted changes after the verified safe baseline. No new commits exist after the baseline on `main`; the damage is local working-tree pollution.

The changes are not safe to commit. They include package/runtime changes, removed verification scripts, malformed TypeScript/JSX, server/client boundary violations, unapproved order/delivery/payment/settlement code, unapproved migrations, debug artifacts, and session artifacts.

## Modified Tracked Files

| File | Area | Classification | Reason |
| --- | --- | --- | --- |
| `package.json` | package | REVERT | Removed `test`, `lint`, `build`, and `typecheck`; changed `dev` port behavior; upgraded Next/React; added unapproved packages. |
| `package-lock.json` | package | REVERT | Lockfile follows unapproved dependency/runtime changes. |
| `tsconfig.json` | package | REVERT | Changed JSX mode and generated type includes without approved migration. |
| `next-env.d.ts` | package | REVERT | Replaced stable Next generated routes reference with `.next/dev` import. |
| `middleware.ts` | routing/checkout | SALVAGE PARTS | Adding `/checkout/draft(.*)` protection is directionally aligned with draft UI, but must be reapplied cleanly after restore. |
| `app/shop/[shopSlug]/product/[productId]/page.tsx` | public shop/checkout | SALVAGE PARTS | Likely draft UI entry point; must be reviewed because checkout/order expansion contaminated adjacent files. |
| `components/customer/public-shop-rpc-screens.tsx` | public shop/checkout | SALVAGE PARTS | Likely added "start draft" UI; must be reviewed and stripped to draft-only behavior. |
| `app/supplier/orders/page.tsx` | supplier/orders | REVERT | Connects supplier order pages to live orders, outside approved scope. |
| `app/supplier/orders/[id]/page.tsx` | supplier/orders | REVERT | Connects supplier order detail to live orders/order items, outside approved scope. |
| `components/admin/admin-core-screens.tsx` | admin/shared | REVERT | Converted broad admin UI to client-heavy code, imports missing actions/server helpers, contains malformed JSX. |
| `components/supplier/screens.tsx` | supplier/shared | REVERT | Adds order/delivery/settlement behavior and malformed JSX; breaks supplier routes. |

## Untracked Files

### Safe or Potentially Salvageable

These may contain legitimate Checkout Phase B Group 3 draft UI ideas, but they must be reviewed line-by-line and reintroduced from a clean tree.

| File | Classification | Notes |
| --- | --- | --- |
| `app/checkout/draft/[draftId]/page.tsx` | SALVAGE PARTS | Route concept is approved for draft UI only. |
| `app/checkout/draft/[draftId]/actions.ts` | SALVAGE PARTS | Currently contaminated by order creation; salvage only draft-safe pieces. |
| `app/shop/[shopSlug]/product/actions.ts` | SALVAGE PARTS | May create drafts from public product page; verify no order/payment/stock side effects. |
| `components/customer/checkout-draft-screens.tsx` | SALVAGE PARTS | UI concept useful, but current copy/actions mention placing orders. |
| `lib/checkout/draft.ts` | SALVAGE PARTS | Draft helper concept useful; remove `createOrderFromDraft` and order side effects. |
| `lib/checkout/server.ts` | SALVAGE PARTS | Server helper concept useful only if it uses Clerk native token correctly. |
| `tests/checkout-draft-ui.test.tsx` | SALVAGE PARTS | Keep only tests for draft creation/review/abandon/address attach; remove order creation expectations. |
| `docs/RISELLAR_CHECKOUT_PHASE_B_DRAFT_UI_INTEGRATION_REPORT.md` | SALVAGE PARTS | Rewrite after clean implementation. |

### Suspicious Scope Expansion

| File or Directory | Classification | Reason |
| --- | --- | --- |
| `app/actions/orderActions.ts` | DELETE | Unapproved order/delivery/payment/settlement server actions; broken imports. |
| `lib/actions/adminActions.ts` | DELETE | Unapproved admin order actions. |
| `lib/actions/confirmation-actions.ts` | DELETE | Unapproved confirmation workflow. |
| `lib/actions/supplier-actions.ts` | DELETE | Unapproved supplier order workflow. |
| `lib/notifications/confirmation-failed.ts` | DELETE | Unapproved notification workflow. |
| `lib/supabase/hooks/useOrderRealtime.ts` | DELETE | Unapproved realtime orders hook; syntax error. |
| `lib/mock/delivery-core.ts` | DELETE | Delivery flow is out of scope. |
| `app/admin/operations/exceptions/page.tsx` | DELETE | Unapproved exception/payment flow; imports server-only code in client context. |
| `app/admin/orders/confirmation-queue/page.tsx` | DELETE | Unapproved confirmation queue; client imports `next/headers`. |
| `components/admin/confirmation-queue-table.tsx` | DELETE | Unapproved confirmation UI; malformed JSX. |
| `app/customer/orders/[orderId]/confirm/account.action.ts` | DELETE | Invalid TypeScript/Python syntax and unapproved order confirmation. |
| `app/customer/orders/[orderId]/confirm/account/route.ts` | DELETE | Unapproved confirmation API. |
| `app/confirmation/page.tsx` | DELETE | Unapproved confirmation flow. |
| `app/confirmation-failed/page.tsx` | DELETE | Unapproved failure flow. |
| `app/delivery/orders/page.tsx` | DELETE | Delivery flow out of scope. |
| `app/delivery/orders/[id]/page.tsx` | DELETE | Delivery flow out of scope. |
| `components/delivery/DeliveryShell.tsx` | DELETE | Delivery flow out of scope. |
| `components/delivery/DeliveryOrderList.tsx` | DELETE | Delivery flow out of scope. |
| `components/delivery/DeliveryOrderDetailScreen.tsx` | DELETE | Delivery flow out of scope and malformed JSX. |
| `supabase/functions/_shared/supabase-client.ts` | DELETE | Unapproved edge function service-role helper. |
| `supabase/functions/expire-unconfirmed-orders/index.ts` | DELETE | Unapproved cron/edge order expiry flow. |

### Unapproved API Routes

All of these should be deleted from the recovery branch unless deliberately rebuilt in a future phase:

- `app/api/admin/orders/[orderId]/assign-dispatch/route.ts`
- `app/api/admin/orders/[orderId]/force-transition/route.ts`
- `app/api/admin/orders/stalled/route.ts`
- `app/api/confirm/route.ts`
- `app/api/customer/orders/[orderId]/confirm/account/route.ts`
- `app/api/delivery/orders/[orderId]/confirm-payment/route.ts`
- `app/api/orders/[orderId]/initiate-settlement/route.ts`
- `app/api/supplier/orders/[orderId]/prepare/route.ts`
- `app/api/supplier/orders/[orderId]/ready/route.ts`

### Generated, Experimental, Debug, Temporary, or Secret Artifacts

These files are not application source and must not be committed:

- `CLAUDE.md`
- `IMPLEMENTATION_COMPLETE.md`
- `IMPLEMENTATION_SUMMARY.md`
- `TEST_RESULTS.md`
- `apply-migration.js`
- `back2.sh`
- `bash-test.js`
- `check-schema.js`
- `clerk-session-new.js`
- `clerk-session.js`
- `clerk-test.js`
- `corrected.js`
- `create-clerk-session.js`
- `debug-clerk.js`
- `debug.log`
- `debug_curl.sh`
- `debug_curl2.sh`
- `debug_script.sh`
- `dev.err`
- `dev.out`
- `fi_line.txt`
- `fix_profile.py`
- `new_block.txt`
- `newmain.js`
- `original.js`
- `part1.txt`
- `part2.txt`
- `query.sql`
- `reconstructed.txt`
- `replace.py`
- `run_phase2_e2e.sh`
- `run_phase2_e2e.sh.backup`
- `run_phase2_e2e.sh.backup2`
- `run_phase2_e2e_debug.sh`
- `run_phase2_e2e_fixed.sh`
- `session.cookie`
- `session.jwt`
- `temp_fixed.sh`
- `temp_fixed.sh.bak2`
- `test-clerk-final.js`
- `test-clerk-session.js`
- `test-clerk.js`
- `test-columns.js`
- `test-columns2.js`
- `test-connection.js`
- `test-create-client.js`
- `test-default.js`
- `test-final.js`
- `test-final2.js`
- `test-list-users.js`
- `test-session.js`
- `test-user-methods.js`
- `test-users.js`
- `test-users2.js`
- `test-users3.js`
- `test.sql`
- `test.txt`
- `test/`
- `test2.js`
- `test3.js`
- `test4.js`
- `test_api.sh`
- `test_env.sh`
- `test_parens.sh`
- `test_profile_lookup.sh`
- `test_profile_lookup_real.sh`
- `test_quote.sh`
- `test_var.sh`
- `workable.sh`

## New Migrations After Baseline

| Migration | Purpose | Touches | Recommendation |
| --- | --- | --- | --- |
| `20260718210000_create_order_from_draft_rpc.sql` | Creates `create_order_from_draft` RPC, order rows, stock reservations, order items, audit rows. | RPC, orders, stock reservations, order items, settlement/commission snapshots. | DELETE. Out of approved scope; order creation not approved. |
| `20260724000000_add_confirmation_fields.sql` | Adds `orders.expires_at` and updates existing rows. | orders table data and schema. | DELETE. Unapproved mutation of orders. |
| `20260724010000_prepare_supplier_for_order_rpc.sql` | Adds supplier order preparation RPC. | RPC, orders, order_items, audit logs. | DELETE. Supplier preparation out of scope. |
| `20260725000000_add_order_expires_index.sql` | Adds order expiry index. | orders index. | DELETE. Depends on unapproved confirmation flow. |
| `20260725020000_add_delivery_and_prepare_timestamps.sql` | Adds delivery/prep timestamps and `delivery_person` role. | orders schema, profiles FK, enum role. | DELETE. Delivery flow and role expansion out of scope. |
| `20260725030000_update_prepare_supplier_for_order_rpc.sql` | Replaces supplier preparation RPC. | RPC, orders, audit logs. | DELETE. Out of scope and duplicates previous unapproved RPC. |

## Overall Classification

KEEP: none of the uncontrolled changes should be kept wholesale.

SALVAGE PARTS: draft UI route/helper concept only, after full cleanup.

REVERT/DELETE: package/runtime changes, supplier/admin broad UI rewrites, order/delivery/payment/settlement APIs, migrations, debug/session artifacts.
