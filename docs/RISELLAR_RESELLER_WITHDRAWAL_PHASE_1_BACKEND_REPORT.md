# Risellar Reseller Withdrawal Phase 1 Backend Report

## Summary

Implemented the development backend foundation for reseller withdrawal requests and finance-admin manual payout recording.

The safe MVP transition is:

`available reseller commission -> withdrawal requested -> finance admin manually pays outside Risellar -> withdrawal paid`

No external payout provider, Mobile Money API, bank API, checkout, order, stock, delivery, commission recalculation, settlement rewrite, refund, or supplier payout integration was added.

## Balance Model Audit

The current live development model stores reseller commission balances on `public.resellers`:

- `commission_pending_amount`: locked commission that is not withdrawable until supplier settlement verification.
- `commission_available_amount`: available commission credited by the existing settlement verification RPC.
- `commission_pending_withdrawal_amount`: added in this phase for reserved withdrawal funds.
- `commission_withdrawn_amount`: added in this phase for paid/manual payout totals.

No separate wallet ledger table exists yet. Audit events are written to `public.audit_logs`.

Accounting invariant used for this phase:

`earned commission = locked commission + available commission + pending withdrawal + withdrawn commission`

## Payout Account Model

Created `public.reseller_payout_accounts` for saved reseller payout accounts.

Phase 1 supports development-safe saved Mobile Money account data with:

- payout method
- account name
- Mobile Money network
- phone number
- masked safe reads
- active/default status

No PIN, OTP, card, password, token, or external provider credential is stored.

## Withdrawal Storage

Reused the existing `public.withdrawals` table and added forward-compatible fields:

- `payout_account_id`
- `currency_code`
- `request_reference`
- `request_idempotency_key`
- `paid_at`
- `payout_reference`
- `admin_private_note`
- `payout_idempotency_key`

Existing `withdrawal_status` enum values are reused. Phase 1 maps:

- `requested` = pending manual withdrawal
- `paid` = finance admin recorded manual payout

## RPCs Created

Migration:

- `supabase/migrations/20260731213000_reseller_withdrawal_request_payout_rpc.sql`

Forward runtime patch:

- `supabase/migrations/20260731214500_fix_reseller_withdrawal_paid_column_ambiguity.sql`

Forward accounting-safety patch:

- `supabase/migrations/20260731220000_remove_reseller_withdrawal_commission_row_mutation.sql`

Forward payout-account patch:

- `supabase/migrations/20260731221500_fix_reseller_payout_account_default_ambiguity.sql`

RPCs/functions:

- `reseller_upsert_payout_account`
- `list_reseller_payout_accounts_safe`
- `get_reseller_wallet_safe`
- `list_reseller_withdrawals_safe`
- `get_reseller_withdrawal_safe`
- `reseller_request_withdrawal`
- `admin_can_manage_reseller_withdrawals`
- `list_admin_reseller_withdrawals_safe`
- `get_admin_reseller_withdrawal_safe`
- `admin_mark_reseller_withdrawal_paid`

## Security Protections

- Reseller ID is resolved server-side.
- Finance admin is resolved through active `admin_staff` membership and `current_finance_admin_profile_id()`.
- General admin is not sufficient for the manual payout RPC.
- Browser does not send available balance, pending balance, withdrawn balance, status, currency, reseller ID, or admin-controlled amount.
- Same request idempotency key returns the existing withdrawal without duplicate reservation.
- Conflicting request retry is blocked.
- Same payout idempotency key returns the existing paid result without duplicate withdrawn movement.
- Conflicting payout retry is blocked.
- Pending withdrawal uniqueness prevents duplicate pending requests for one reseller.
- Admin private note is not returned to reseller-safe reads.
- Payout account values are masked in reseller/admin safe reads.
- Individual `public.commissions` row allocation is explicitly deferred; the effective Phase 1 RPCs move only trusted reseller balance columns and withdrawal/audit records to avoid broad commission-row status mutation before a withdrawal-items model exists.
- No direct client table mutation or service-role import was added.

## Test Result

Development SQL boundary test passed:

- reseller can request withdrawal
- available balance decreases once
- pending withdrawal increases once
- withdrawn balance is unchanged after request
- duplicate pending withdrawal is blocked
- conflicting request retry is blocked
- customer/supplier are blocked
- another reseller cannot use the payout account
- reseller cannot mark own withdrawal paid
- general admin cannot mark paid
- finance staff can mark paid
- pending withdrawal decreases after paid
- withdrawn increases after paid
- available balance is unchanged after paid
- request and paid audit events are created
- no order, stock reservation, or settlement rows are created by the withdrawal test

Development concurrency/idempotency test passed:

- same-key request returns the same withdrawal
- same-key request does not deduct available balance twice
- same-key request does not reserve pending withdrawal twice
- same-key request creates one audit event
- same-key payout preserves paid timestamp
- same-key payout does not credit withdrawn twice
- same-key payout creates one audit event
- paid conflicting retry is blocked as `CONFLICTING_PAYOUT_RETRY`

## Runtime Fix

The first boundary test run exposed a runtime bug in `admin_mark_reseller_withdrawal_paid`: an output-column name collided with the `withdrawal_status` table column in an update statement.

A forward patch migration was created and applied to development. No RLS/RPC policy was weakened.

Live reseller browser QA later exposed a second runtime bug in `reseller_upsert_payout_account`: the output column `is_default` shadowed the unqualified `is_default` column in the payout-account default update.

A forward patch migration was created and applied to development. It only qualifies the `public.reseller_payout_accounts` update with an alias. No RLS/RPC policy, grants, role checks, balance math, or provider integration was weakened.

## Accounting Safety Patch

Review found that the initially applied request/payout functions could broadly mark all available commission rows as withdrawal-related even when the withdrawal amount represented only part of the available balance.

A second forward patch replaced the effective withdrawal request and manual-paid RPCs so Phase 1 moves only the stored reseller wallet balances, withdrawal rows, and audit logs. Commission-row allocation remains deferred to a later dedicated withdrawal-items model. The patch does not weaken permissions, idempotency, RLS, RPC grants, or payout authority.

## Commands Run

- `npx vitest run tests/reseller-withdrawal.test.ts` - failed first as expected, then passed.
- `npx supabase db push --dry-run --include-all` - passed; only the withdrawal migration was pending.
- `npx supabase db push --include-all` - applied the withdrawal migration to development.
- `npx supabase db query --linked --file scripts/rpc/reseller-withdrawal-rpc-tests-dev-only.sql` - first run exposed a runtime ambiguity bug.
- `npx supabase db push --dry-run --include-all` - passed for the forward ambiguity patch.
- `npx supabase db push --include-all` - applied the forward ambiguity patch to development.
- `npx supabase db query --linked --file scripts/rpc/reseller-withdrawal-rpc-tests-dev-only.sql` - passed after the patch and harness context fix.
- `npx supabase db query --linked --file scripts/rpc/reseller-withdrawal-concurrency-tests-dev-only.sql` - passed after tightening the harness to verify the true conflicting-payout retry.
- `npx supabase db push --dry-run --include-all` - passed; only the commission-row mutation safety patch was pending.
- `npx supabase db push --include-all` - applied the commission-row mutation safety patch to development.
- `npx supabase db query --linked --file scripts/rpc/reseller-withdrawal-rpc-tests-dev-only.sql` - passed after the accounting-safety patch.
- `npx supabase db query --linked --file scripts/rpc/reseller-withdrawal-concurrency-tests-dev-only.sql` - passed after the accounting-safety patch.
- `npm run typecheck` - passed before full verification.
- `npx supabase db push --dry-run` - passed for the payout-account ambiguity patch; only `20260731221500_fix_reseller_payout_account_default_ambiguity.sql` was pending.
- `npx supabase db push` - applied the payout-account ambiguity patch to development.
- `npx supabase db query --linked --file scripts/rpc/reseller-withdrawal-rpc-tests-dev-only.sql` - passed after adding a payout-account save assertion.
- `npx supabase db query --linked --file scripts/rpc/reseller-withdrawal-concurrency-tests-dev-only.sql` - passed after the payout-account ambiguity patch.
- `git diff --check` - passed; only line-ending warnings were reported.
- `npm test` - passed: 43 test files and 247 tests.
- `npm run lint` - passed.
- `npm run build` - passed.
- `npm run typecheck` - passed.
- `npx tsc --noEmit` - passed.

## Secret And Scope Safety

- No production Supabase connection was used.
- No destructive reset, migration repair, or `supabase db reset --linked` was used.
- No external payout provider integration was added.
- No supplier payout table or provider row was created.
- No secrets, account numbers, full emails, profile IDs, supplier IDs, reseller IDs, tokens, JWTs, cookies, database passwords, project IDs, or connection strings are included in this report.
- `.env.local`, `.next`, `supabase/.temp`, local logs, temporary SQL diagnostics, and local evidence are not staged.

## Current Status

Backend migration, forward patches, SQL boundary tests, and concurrency/idempotency tests passed in the confirmed development project. Final reseller/admin browser evidence and full app verification are tracked in the UI/live QA report.
