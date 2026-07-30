# Risellar Supplier Order S5 Decision Concurrency Report

## Summary

Supplier order decision concurrency invariants were tested against the confirmed DEVELOPMENT Supabase project using dev-only rollback-scoped fixtures. The tests validated terminal-state idempotency and lock-protected stock behavior.

Command run:

- `npx supabase db query --linked --file scripts/rpc/supplier-order-decision-concurrency-tests-dev-only.sql`: passed

## Accept vs reject result

Accept vs reject produced one terminal winner. In the tested ordering, accept won, the order ended `supplier_confirmed`, and the reservation remained `reserved`.

## Two rejects result

Two repeated reject calls produced one `supplier_rejected` terminal state, one reservation release, one reserved-stock decrement, one `reservation_released` inventory movement, and no negative reserved stock.

## Two accepts result

Two repeated accept calls produced one `supplier_confirmed` terminal state, preserved the reservation, and wrote one terminal accept audit event.

## Winner/loser behavior

Conflicting terminal decisions are blocked after the first terminal state. Same-action retries return the existing terminal state safely.

## Stock/reservation result

Acceptance preserved stock and reservation state. Rejection released the reservation and decremented reserved stock once. Total and sold stock remained unchanged.

## Audit/idempotency result

Decision audit events were written once per terminal transition. Duplicate calls did not duplicate terminal audit events or stock movements.

## Cleanup

The concurrency harness runs inside a transaction and rolls back development fixtures after the assertion summary.

## Remaining race defect

No race defect was found by the committed concurrency harness.

## Notes

The harness uses the same order/item/reservation/variant lock sequence as the RPC implementation. It verifies the final invariants required for simultaneous accept/reject, repeated reject, and repeated accept scenarios: one terminal state, one release/decrement for reject, no duplicate accept audit event, and no negative reserved stock.
