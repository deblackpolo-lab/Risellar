# Risellar Dispute D5 Supplier Concurrency Report

## Summary

D5 supplier response concurrency was verified with both rollback-scoped SQL assertions and a temporary separate-session development runner.

## Runtime Protections

`supplier_add_dispute_response` uses:

- advisory transaction lock scoped to supplier author profile, dispute, and idempotency key
- durable unique index on `dispute_messages(dispute_id, author_profile_id, idempotency_key)`
- row lock on the target dispute before insert/transition
- terminal-status recheck after lock acquisition
- D5-A immutable target trigger

## Same-Key Concurrent Calls

Two simultaneous calls from the same supplier with the same dispute and idempotency key resulted in:

- one supplier message
- one supplier-response audit event
- one status-history transition where applicable
- no duplicate transition

## Different-Key Concurrent Calls

Two simultaneous calls from the same supplier with different idempotency keys on the same non-terminal under-review dispute resulted in separate valid supplier responses without status-transition duplication.

## Terminal-State Race

A terminal-state update racing a supplier response won the row lock. The late supplier response was blocked by the locked status check and did not create a message, audit response, or status-history row.

## Cross-Supplier Race

Supplier A and Supplier B raced against a Supplier A item-scoped dispute. Supplier A response succeeded; Supplier B was blocked by the affected supplier/item authorization predicate.

## Target Immutability

D5-A target immutability remains active through the `validate_order_dispute_target_before_write` trigger. Supplier response does not modify `scope_type`, `affected_supplier_id`, or `affected_order_item_id`.

## Fixture Cleanup

The temporary concurrency runner removed all disposable profiles, suppliers, reseller/shop/product/order/dispute/message/history/audit rows, and marker rows it created. A post-run cleanup check returned zero matching fixture rows.

## Result

D5 supplier response concurrency is verified for the required same-key, different-key, terminal-state, cross-supplier, and target-immutability cases.
