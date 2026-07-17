# Risellar Settlement and Commission Logic Report

## A. Logic Helpers Created

- `calculateSupplierSettlementDue` in `lib/business/settlement-commission.ts`
  - Calculates Risellar settlement due as platform margin plus reseller commission.
  - Returns customer paid amount and supplier base amount so future workflows can preserve the rule that the supplier keeps the base price.
- `getSettlementStatus`
  - Derives `Due`, `Overdue`, `Partially Paid`, `Proof Submitted`, `Verifying`, `Paid`, `Cancelled`, or `Disputed` from pure input state.
- `getCommissionStatus`
  - Keeps reseller commission unavailable until supplier settlement is verified.
  - Handles dispute, return hold, cancellation, withdrawal requested, and paid lifecycle states.
- `canReleaseCommission`
  - Allows release only after verified paid settlement and no blocking dispute, return, or cancellation.
- `canRequestWithdrawal`
  - Checks requested withdrawal against available commission balance, minimum withdrawal amount, payout review, and account hold.
- `getSupplierRestrictionState`
  - Maps overdue settlement exposure to `Good Standing`, `Warning`, `Limited`, `Restricted`, or `Suspended`.
  - Returns booleans for product creation, new orders, and product boosts.
- `calculatePartialSettlementBalance`
  - Calculates total due, paid amount, outstanding balance, partial state, and whether admin rules allow accepting the partial settlement.

## B. Business Rules Covered

- Supplier may receive customer Pay on Delivery payment directly at MVP.
- Supplier keeps base price.
- Supplier must settle Risellar platform margin plus reseller commission.
- Reseller commission stays pending until supplier settlement is admin verified.
- Admin verification is required before commission release.
- Overdue settlement can restrict supplier actions.
- Disputes and returns can hold commission.
- Partial settlement is represented, but only accepted when admin rules allow it.
- Withdrawals depend on available commission balance and payout/account eligibility.

## C. Tests Added

- `tests/settlement-commission-logic.test.ts`
  - Settlement amount calculation.
  - Settlement status lifecycle.
  - Commission lifecycle and admin release checks.
  - Withdrawal eligibility checks.
  - Partial settlement balance checks.
  - Supplier restriction state checks.

## D. Backend Integration Notes

- The helpers are pure TypeScript and accept plain input objects, so later server actions can map Supabase rows into these inputs without changing the business rules.
- Future order settlement creation can call `calculateSupplierSettlementDue` when a Pay on Delivery order is marked customer-paid.
- Supplier settlement admin review can call `getSettlementStatus` after proof metadata is submitted or verified.
- Commission release queues can call `getCommissionStatus` and `canReleaseCommission` before exposing any admin release mutation.
- Reseller withdrawal actions can call `canRequestWithdrawal` before creating a withdrawal request.
- Supplier risk and restriction workflows can call `getSupplierRestrictionState` from aggregated overdue settlement metrics.

## E. Still Needed Later

- Supabase tables or views for settlements, commission ledger entries, proof metadata, withdrawal requests, restriction events, disputes, and returns.
- Server actions/API routes that persist settlement proof submission and admin verification results.
- Admin workflows for proof approval/rejection, partial settlement policy, manual overrides, audit logging, and commission release.
- Reseller wallet ledger and withdrawal processing connected to real payment provider review.
- Supplier restriction enforcement in product creation, boost approval, visibility, and new-order flows.
- Reconciliation jobs for settlement aging, overdue detection, and commission release queue creation.

## F. Files Changed

- `lib/business/settlement-commission.ts`
- `tests/settlement-commission-logic.test.ts`
- `docs/RISELLAR_SETTLEMENT_COMMISSION_LOGIC_REPORT.md`

Unrelated working-tree changes were already present or appeared from parallel work and were not modified for this task.

## G. Commands Run and Results

- `npm test -- tests/settlement-commission-logic.test.ts`
  - First run failed as expected because `@/lib/business/settlement-commission` did not exist yet.
- `npm test -- tests/settlement-commission-logic.test.ts`
  - Passed: 1 test file, 6 tests.
- `npm test`
  - Passed: 18 test files, 81 tests.
- `npm run typecheck`
  - Passed: `tsc --noEmit`.
- `npm run lint`
  - Passed: `eslint . --max-warnings=0`.
- `npm run build`
  - Failed after compiling and generating 160 static pages.
  - Error: `ENOENT: no such file or directory, open 'C:\Users\Nana Kwadwo\Documents\Risellar\.next\server\pages-manifest.json'`.
- Cleaned generated `.next` and reran `npm run build`.
  - Failed with the same missing `.next\server\pages-manifest.json` error.
  - Diagnostics left `.next/export-detail.json` with `"success": true`, but no `.next/server` directory was produced.
  - This appears unrelated to the pure settlement/commission helper changes.

## H. Current Git Status

Branch: `backend/settlement-commission-logic`

Task files to commit:

- `docs/RISELLAR_SETTLEMENT_COMMISSION_LOGIC_REPORT.md`
- `lib/business/settlement-commission.ts`
- `tests/settlement-commission-logic.test.ts`

Other uncommitted files currently present in the shared worktree and intentionally not staged for this task:

- `docs/RISELLAR_FRONTEND_PRD_COVERAGE_AUDIT_REPORT.md`
- `docs/RISELLAR_FRONTEND_PRD_COVERAGE_MATRIX.md`
- `docs/RISELLAR_BACKEND_PHASE_0_MASTER_PLAN.md`
- `docs/RISELLAR_SUPABASE_SCHEMA_RLS_FOUNDATION_REPORT.md`
- `lib/mock/preview-routes.ts`
- `lib/order-stock-logic.ts`
- `supabase/`
- `tests/order-stock-logic.test.ts`
- `tests/phase15.test.tsx`
