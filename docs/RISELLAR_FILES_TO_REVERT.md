# Risellar Files To Revert Or Delete

Date: 2026-07-29

Safe baseline: `94f6eb69ca1d22c475997f52d4d7729d52dfd0b7`

## Revert Tracked Files To Baseline

These files should be restored from the safe commit:

- `package.json`
- `package-lock.json`
- `tsconfig.json`
- `next-env.d.ts`
- `app/supplier/orders/page.tsx`
- `app/supplier/orders/[id]/page.tsx`
- `components/admin/admin-core-screens.tsx`
- `components/supplier/screens.tsx`

These files should be reviewed and selectively reapplied, not restored blindly if Checkout Phase B Group 3 is reintroduced:

- `middleware.ts`
- `app/shop/[shopSlug]/product/[productId]/page.tsx`
- `components/customer/public-shop-rpc-screens.tsx`

## Delete Untracked Unapproved Product Code

- `app/actions/`
- `app/admin/operations/exceptions/`
- `app/admin/orders/confirmation-queue/`
- `app/api/`
- `app/confirmation-failed/`
- `app/confirmation/`
- `app/customer/orders/[orderId]/`
- `app/delivery/`
- `components/admin/confirmation-queue-table.tsx`
- `components/delivery/`
- `lib/actions/`
- `lib/mock/delivery-core.ts`
- `lib/notifications/`
- `lib/supabase/hooks/`
- `supabase/functions/`

## Delete Unapproved Migrations

- `supabase/migrations/20260718210000_create_order_from_draft_rpc.sql`
- `supabase/migrations/20260724000000_add_confirmation_fields.sql`
- `supabase/migrations/20260724010000_prepare_supplier_for_order_rpc.sql`
- `supabase/migrations/20260725000000_add_order_expires_index.sql`
- `supabase/migrations/20260725020000_add_delivery_and_prepare_timestamps.sql`
- `supabase/migrations/20260725030000_update_prepare_supplier_for_order_rpc.sql`

## Delete Debug, Session, and Scratch Files

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

## Delete Or Rewrite Contaminated Draft UI Files

These are not safe as-is:

- `app/checkout/draft/[draftId]/actions.ts`
- `app/checkout/draft/[draftId]/page.tsx`
- `app/shop/[shopSlug]/product/actions.ts`
- `components/customer/checkout-draft-screens.tsx`
- `lib/checkout/draft.ts`
- `lib/checkout/server.ts`
- `tests/checkout-draft-ui.test.tsx`
- `docs/RISELLAR_CHECKOUT_PHASE_B_DRAFT_UI_INTEGRATION_REPORT.md`

They may be recreated after cleanup with only draft-safe behavior.
