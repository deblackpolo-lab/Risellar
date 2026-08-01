# Risellar Dispute Test and QA Plan

## SQL Boundary Tests

Future development-only SQL tests must cover:

1. Customer opens dispute for own order.
2. Customer cannot dispute another customer's order.
3. Customer cannot open outside allowed window.
4. Customer cannot open invalid reason for current order state.
5. Duplicate customer dispute open is idempotent.
6. Supplier sees only own supplier order disputes.
7. Supplier cannot resolve own dispute.
8. Supplier cannot access another supplier evidence.
9. Reseller sees only own commission impact.
10. Reseller cannot access customer/supplier private case details.
11. General admin cannot apply finance adjustment.
12. Finance_staff can apply approved finance hold through finance RPC only.
13. Anonymous blocked.
14. Private notes hidden from non-admin safe reads.
15. Evidence access scoped.
16. Refund maximum enforced from snapshots.
17. Currency consistency enforced.
18. Settlement verification blocked or flagged when active dispute requires it.
19. Available commission hold applies once.
20. Pending withdrawal interaction is safe.
21. Paid withdrawal is not silently reversed.
22. Stock is not restored before inspection.
23. Returned stock movement happens once after authorised inspection.
24. Full refund accounting is correct.
25. Partial refund accounting is correct.
26. No duplicate wallet, commission, stock, refund, or audit rows.
27. Failed transaction leaves no partial state.
28. Notification outbox dedupes dispute events.
29. Fixtures roll back or clean completely.

### D4 Customer Open/Response Coverage

`scripts/rpc/customer-dispute-open-response-tests-dev-only.sql` now covers the D4 customer mutation boundary with 51 passing DEVELOPMENT assertions:

- anonymous, inactive, and suspended callers are blocked
- customer ownership is enforced for open/list/detail/respond
- direct table writes remain denied
- invalid category/reason/outcome/reason-state/text/idempotency inputs are rejected
- valid open creates one dispute, one initial message, one initial history row, and one audit row
- valid response creates one message and one audit row
- `awaiting_customer` response moves the case to `under_review` once
- closed, rejected, and cancelled responses are blocked
- retries are idempotent and do not duplicate message/history/audit rows
- duplicate active disputes are not duplicated under the live D2 active-reason uniqueness rule
- order/payment/business/notification side effects are absent
- fixtures roll back

## Concurrency Tests

Required true-concurrency cases:

- duplicate dispute opening
- admin resolution versus supplier response
- refund verification versus settlement verification
- commission hold versus withdrawal request
- refund adjustment versus withdrawal payout
- return restock versus inventory sale
- two admin resolution attempts
- appeal open versus final close

Each concurrency test should assert row locks, idempotency keys, and no negative balances or stock counters.

D4 completed true parallel probes for:

- duplicate customer open with the same idempotency key
- duplicate customer open with different keys but the same active-dispute fingerprint
- duplicate customer response with the same idempotency key

Response versus case closure remains deferred until an admin closure RPC exists.

## Browser QA Plan

Customer:

- open dispute from own order detail
- select reason
- enter description
- submit
- see timeline
- respond to information request
- view return/refund outcome

Supplier:

- open own supplier dispute queue
- view only own orders
- respond
- confirm return receipt
- classify condition
- report refund sent when assigned

Admin/support:

- open queue
- filter by state
- inspect safe order timeline
- request information
- approve/reject return
- set resolution
- close case

Finance admin:

- review finance-impact cases
- hold/release/apply adjustment
- record manual refund completion
- verify no arbitrary money edit

Reseller:

- view commission hold/adjustment summary
- confirm private customer/supplier evidence is hidden

## Runtime and Privacy Checks

Every browser QA pass must inspect:

- console errors
- server logs
- network calls
- duplicate POSTs
- raw RPC errors
- 500 errors
- unauthorised route leaks
- evidence URL exposure
- private notes in UI
- private fields in emails

## Side-Effect Checks

For each dispute action, verify whether it should or should not change:

- orders
- order_items
- stock_reservations
- product_variants
- inventory_movements
- payments/payment reports
- settlements
- commissions
- withdrawals
- wallet balances
- notification outbox
- audit logs

No action may create payment-provider, delivery-provider, automatic refund, commission payout, settlement payout, stock reservation, or withdrawal records unless that future group explicitly owns it.

## Validation Commands

Each implementation group should run:

- `git status --short`
- `git diff --check`
- `npm test`
- `npm run lint`
- `npm run build`
- `npm run typecheck`
- `npx tsc --noEmit`

SQL groups should also run dry-run first, development apply only after approval, and development-only RPC boundary tests after apply.

## D5-A Test Addendum

D5-A adds `scripts/rpc/dispute-supplier-item-scoping-tests-dev-only.sql` for target shape, backend supplier derivation, target immutability, target-aware idempotency and uniqueness, multi-supplier supplier read isolation, customer ownership, reseller/admin privacy, direct grant posture, fixture cleanup, and no business side effects.
