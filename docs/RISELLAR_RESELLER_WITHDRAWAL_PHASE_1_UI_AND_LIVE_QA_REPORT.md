# Risellar Reseller Withdrawal Phase 1 UI And Live QA Report

## Summary

Connected reseller withdrawal and finance-admin withdrawal review screens to the audited withdrawal RPC foundation.

Routes connected:

- `/reseller/wallet`
- `/reseller/withdrawals`
- `/reseller/withdrawals/[withdrawalId]`
- `/admin/withdrawals`
- `/admin/withdrawals/[withdrawalId]`

The UI clearly states that creating a withdrawal request does not send money. Finance admin marking a withdrawal paid records a manual payout reference only after money has been sent outside Risellar.

## Reseller UI

The reseller wallet/withdrawal screen shows:

- locked commission
- available commission
- pending withdrawal
- withdrawn total
- minimum withdrawal amount
- masked payout account
- withdrawal request form
- withdrawal history

The reseller form submits only:

- amount
- payout account ID
- acknowledgement
- idempotency key

The browser does not submit:

- reseller ID
- available balance
- locked balance
- pending balance
- withdrawn balance
- currency
- withdrawal status
- commission totals

Required acknowledgement:

`I understand that this creates a withdrawal request. Money has not been sent yet.`

## Admin UI

The admin finance UI shows:

- withdrawal reference
- masked reseller email
- reseller display name
- trusted amount/currency from the backend
- masked payout account
- requested date
- status
- balance consistency summary

The admin mark-paid form submits only:

- withdrawal ID
- payout reference
- optional private admin note
- acknowledgement
- idempotency key

The admin form does not submit amount, currency, reseller ID, balances, or status.

Required acknowledgement:

`I confirm that the withdrawal amount was sent manually to the reseller's payout account.`

## Route Access

`/admin/withdrawals` now uses finance-specific access through `admin_can_manage_reseller_withdrawals()` and the existing `current_finance_admin_profile_id()` helper.

This allows active `finance_staff`/`super_admin` members while avoiding the broader general-admin helper for manual payout authority.

## Browser QA Result

Admin browser QA passed with the development finance-admin session already signed in.

Verified:

- `/admin/withdrawals` loaded for the finance admin.
- Empty state appeared before creating a development pending request.
- A single fake/dev-only pending withdrawal was created using the audited user-context request RPC simulation for an approved development reseller.
- The pending request appeared in `/admin/withdrawals`.
- The request detail page loaded.
- Detail showed trusted amount/currency, masked reseller/payout data, pending status, and no editable amount.
- Manual payout form required a payout reference and acknowledgement.
- Submitting a fake development-only payout reference through the browser succeeded.
- Success copy appeared: `Withdrawal marked as paid.`
- Status became paid.
- Pending withdrawal balance showed zero.
- Withdrawn balance increased by the requested amount.
- Second payment control was hidden after paid.

Database verification passed:

- exactly one browser-QA withdrawal was marked paid with the development-only payout reference
- paid timestamp and paid actor fields were populated
- pending withdrawals returned to zero for the browser-QA request
- paid audit event with payout-reference presence signal exists
- no recent unrelated order, stock reservation, or settlement updates were observed from the withdrawal flow
- no supplier payout table exists

Additional backend safety verification:

- A forward accounting-safety patch was applied after review.
- Effective withdrawal RPCs no longer update `public.commissions` rows during Phase 1.
- Stored reseller wallet balances, withdrawal rows, and audit logs remain the Phase 1 source of truth.
- Withdrawal item/commission-row allocation is deferred to a later dedicated model.
- Boundary and concurrency/idempotency SQL tests passed again after the patch.

## Development Commission Setup For Reseller Browser QA

The approved development reseller account initially had zero available commission, so a browser withdrawal could not be submitted.

After explicit approval, one isolated DEVELOPMENT-only QA order/commission path was created for the signed-in approved reseller. The setup used fake customer, shop, product, listing, order, supplier payment report, settlement, commission, and stock-reservation fixture data. It then invoked the existing audited `admin_verify_supplier_settlement` RPC under finance-staff context to make the reseller commission available.

Important safety points:

- no direct reseller wallet credit was used
- no direct balance update was used
- no production data was used
- no provider payout was created
- no supplier payout row was used
- no withdrawal row was created by the commission setup
- the available credit came from immutable order-item commission snapshots
- the settlement verifier moved the order to completed/payment settlement verified
- other reseller balances were unchanged
- the fixture order is retained as development QA audit evidence

The first fixture attempt failed before persistence because an unrelated supplier transition RPC returned a shape mismatch. Marker cleanup verification found no partial marker rows from that failed attempt.

During reseller browser QA, saving the payout account exposed a real `reseller_upsert_payout_account` runtime bug: output column `is_default` shadowed an unqualified table column. A forward patch migration qualified the table update, was applied to development, and the withdrawal boundary/concurrency tests passed again. No policy, role check, balance math, or provider integration was weakened.

## Reseller Browser QA Result

Reseller browser QA passed with the approved development reseller session.

Verified from `/auth/qa-profile-sync` and `/reseller/wallet`:

- authenticated session exists
- profile row exists
- profile role is reseller
- account status is active
- reseller wallet route loads
- available commission became `GH₵30.00` through the audited settlement setup
- locked commission remained `GH₵0.00`
- pending withdrawal baseline remained `GH₵0.00`
- withdrawn baseline remained `GH₵0.00`
- minimum withdrawal was `GH₵10.00`
- payout-account form was available
- withdrawal request acknowledgement was present
- no instant payout or external provider button appeared
- no supplier/customer/admin private data appeared

Live browser actions:

- saved a fake development payout account after the forward RPC patch
- payout account displayed with masked phone data only
- requested a `GH₵10.00` withdrawal from `/reseller/withdrawals`
- UI showed `Withdrawal requested. Money has not been sent yet.`
- history showed exactly one Pending request for the reseller
- detail page showed Pending status, masked payout account, requested timestamp, and `Not paid yet`

Database verification passed:

- exactly one pending withdrawal exists for the development reseller
- available balance decreased once from `GH₵30.00` to `GH₵20.00`
- pending-withdrawal balance increased once from `GH₵0.00` to `GH₵10.00`
- locked balance remained `GH₵0.00`
- withdrawn balance remained `GH₵0.00`
- paid timestamp and payout reference are empty
- request audit event exists
- same-key retry returned safely without duplicate row, duplicate deduction, duplicate pending increase, or duplicate audit event
- overdraw/new-request attempt was blocked by the pending-withdrawal guard before mutation
- no provider payout or supplier payout rows were used

Admin payout was not repeated for this new request because the admin paid browser flow had already passed. The new reseller-created pending request is retained for review.

## Automated Tests

Added:

- `tests/reseller-withdrawal.test.ts`
- `scripts/rpc/reseller-withdrawal-rpc-tests-dev-only.sql`
- `scripts/rpc/reseller-withdrawal-concurrency-tests-dev-only.sql`

Updated:

- `tests/phase9.test.tsx` for the new admin withdrawal route.

Current result:

- `git diff --check` passed.
- `npm test` first full run failed only on the outdated Phase 9 expectation that withdrawals are hidden from admin nav. The test and dashboard copy were updated for the new finance queue.
- `npm test` passed after the Phase 9 expectation update: 43 test files and 247 tests.
- `npm run lint` passed after removing one unused icon import.
- `npm run build` passed.
- `npm run typecheck` passed.
- `npx tsc --noEmit` passed.
- `npx supabase db query --linked --file scripts/rpc/reseller-withdrawal-rpc-tests-dev-only.sql` passed after the payout-account ambiguity patch and added save assertion.
- `npx supabase db query --linked --file scripts/rpc/reseller-withdrawal-concurrency-tests-dev-only.sql` passed after the payout-account ambiguity patch.
- Final `git diff --check` passed with line-ending warnings only.
- Final `npm test` passed: 43 test files and 247 tests.
- Final `npm run lint` passed.
- Final `npm run build` passed.
- Final `npm run typecheck` passed.
- Final `npx tsc --noEmit` passed.

## Runtime Sweep

Runtime sweep passed:

- `/` returned 200 without runtime module errors
- `/sign-in` returned 200 without runtime module errors
- `/sign-up` returned 200 without runtime module errors
- known public shop returned 200 without runtime module errors
- known public product returned 200 without runtime module errors
- `/reseller/wallet` loaded for the signed-in reseller without runtime errors
- `/reseller/withdrawals` loaded for the signed-in reseller without runtime errors
- withdrawal detail loaded for the signed-in reseller without runtime errors
- `/admin/withdrawals` redirected the signed-in reseller away from the finance-admin route
- unauthenticated protected reseller/admin URLs did not render protected content
- browser console error count was zero after the withdrawal flow
- server logs showed clean post-patch save/request responses; the earlier UNKNOWN response was from the fixed payout-account ambiguity

## Security And Scope

Confirmed so far:

- no service-role import in new app/components/helpers
- no external payout provider integration
- no checkout, order, payment, delivery, stock reservation, supplier payout, settlement rewrite, commission recalculation, refund, cancellation, or withdrawal-provider integration
- effective Phase 1 withdrawal RPCs no longer mutate `public.commissions` rows; commission-row allocation remains deferred
- no production Supabase use
- no destructive reset command
- no `.env.local` commit/staging
- no account number, phone number, token, cookie, JWT, profile ID, supplier ID, reseller ID, database password, project ID, or connection string in this report
- no temporary fixture SQL is in the repository or staged
- local deletion of OS temp SQL files was attempted, but the command policy blocked deletion; those files remain outside the repo and are not stageable
- `.env.local`, `.local-recovery`, `.next`, `supabase/.temp`, and local Codex dev-server logs are ignored and not staged
- no service-role usage was found in `app/` or `components/`
- no withdrawal RPC references were found in checkout/customer/shop/supplier app flows
- secret-like scan matches are existing documentation/env-name references and the server-only Supabase admin helper; no real secrets or credential values were added

## Files Changed

- `supabase/migrations/20260731213000_reseller_withdrawal_request_payout_rpc.sql`
- `supabase/migrations/20260731214500_fix_reseller_withdrawal_paid_column_ambiguity.sql`
- `supabase/migrations/20260731220000_remove_reseller_withdrawal_commission_row_mutation.sql`
- `supabase/migrations/20260731221500_fix_reseller_payout_account_default_ambiguity.sql`
- `scripts/rpc/reseller-withdrawal-rpc-tests-dev-only.sql`
- `scripts/rpc/reseller-withdrawal-concurrency-tests-dev-only.sql`
- `app/reseller/wallet/page.tsx`
- `app/reseller/withdrawals/actions.ts`
- `app/reseller/withdrawals/page.tsx`
- `app/reseller/withdrawals/[withdrawalId]/page.tsx`
- `app/admin/withdrawals/actions.ts`
- `app/admin/withdrawals/page.tsx`
- `app/admin/withdrawals/[withdrawalId]/page.tsx`
- `components/reseller/reseller-withdrawal-rpc-screens.tsx`
- `components/admin/admin-reseller-withdrawal-rpc-screens.tsx`
- `components/admin/AdminSidebar.tsx`
- `components/admin/admin-core-screens.tsx`
- `lib/reseller/withdrawals/reseller-withdrawal.ts`
- `lib/admin/withdrawals/admin-reseller-withdrawal.ts`
- `lib/auth/admin-access.ts`
- `lib/auth/route-access-boundary.tsx`
- `tests/reseller-withdrawal.test.ts`
- `tests/phase9.test.tsx`
- `docs/RISELLAR_RESELLER_WITHDRAWAL_PHASE_1_BACKEND_REPORT.md`
- `docs/RISELLAR_RESELLER_WITHDRAWAL_PHASE_1_UI_AND_LIVE_QA_REPORT.md`

## Safe To Commit

Yes. Browser QA, database verification, boundary/concurrency tests, full automated verification, runtime sweep, and security/scope scan passed.
