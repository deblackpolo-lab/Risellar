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

## D5 Supplier Response Coverage

`scripts/rpc/supplier-dispute-response-tests-dev-only.sql` covers the D5 supplier response mutation boundary with 67 passing DEVELOPMENT assertions:

- anonymous, customer, reseller, support/admin, inactive supplier, unapproved supplier, and suspended supplier are blocked
- supplier A can respond to supplier-A supplier-scoped and item-scoped disputes
- supplier B cannot respond to supplier-A scoped disputes
- owning another item on the same multi-supplier order does not grant access
- multi-supplier order-wide disputes remain blocked for supplier response
- single-supplier order-wide disputes follow the D5-A policy
- author profile, author role, visibility, and message type are derived server-side
- invalid body and idempotency keys are rejected
- same key/body retries return the same message
- same key/different body conflicts safely
- retries do not duplicate messages, audit rows, or status-history rows
- `awaiting_supplier` moves once to `under_review`
- allowed non-terminal states accept responses without invented resolution
- terminal states are blocked
- supplier safe reads show own supplier-private response
- customer, reseller, and other-supplier safe reads hide it
- admin safe reads expose it through the admin contract
- direct table writes remain denied
- no order/payment/stock/reservation/settlement/commission/wallet/withdrawal/notification side effects occur

A separate temporary two-session development runner verified same-key concurrency, different-key concurrency, terminal-state race blocking, cross-supplier race isolation, and cleanup.

## D6 Admin/Support Investigation Coverage

`scripts/rpc/admin-dispute-investigation-resolution-tests-dev-only.sql` covers the D6 backend-only admin/support investigation boundary with 103 passing DEVELOPMENT assertions:

- anonymous, customer, supplier, reseller, inactive admin, suspended admin, finance_staff-only, and profile-without-admin_staff callers are blocked
- active `support_staff`, `admin`, and `super_admin` callers are authorized through `admin_staff`
- assignment, information-request, status-transition, resolution, and closure RPCs are explicit and idempotent
- supplier information requests require an explicit affected supplier and are blocked for ambiguous multi-supplier order-wide cases
- internal admin notes stay `admin_only`
- customer and supplier safe reads expose only targeted public messages and public resolution text
- reseller safe read remains impact-only
- direct dispute/action table writes remain blocked
- no order/payment/stock/reservation/settlement/commission/wallet/withdrawal/return/notification side effects occur

A dedicated external two-session D6 concurrency runner now covers 12 race scenarios with 61 passing invariant checks:

- same-key assignment retry
- competing assignee assignment
- customer information request racing customer response
- supplier information request racing supplier response
- competing status transitions
- competing non-financial resolutions
- resolution racing closure
- closure racing customer response
- closure racing supplier response
- same-key information request retry
- different-key information requests
- same-key resolution retry

The runner verifies two independent database backend sessions, overlapping call windows, exact row-count invariants, fixture cleanup, and no business side effects.

## D7 Return Workflow Coverage

`scripts/rpc/return-workflow-backend-tests-dev-only.sql` covers the D7 return workflow boundary with more than 77 passing DEVELOPMENT assertions:

- anonymous and wrong-role callers are blocked
- customer ownership and item-scoped dispute eligibility are enforced
- invalid method, quantity, note, and idempotency inputs are rejected
- duplicate active returns are not duplicated
- admin/support approval, rejection, acceptance, decline, and completion are controlled and idempotent
- supplier receipt and inspection are supplier-scoped
- supplier inventory manager cannot act as supplier owner
- customer, supplier, admin, and reseller safe-read shapes remain scoped
- direct table writes remain blocked
- return audit rows are created without note bodies
- orders, order items, stock, reservations, delivery, supplier payment reports, settlements, commissions, withdrawals, legacy returns, notifications, and provider events are unchanged

`scripts/rpc/return-workflow-d7-concurrency-dev-only.mjs` covers 11 true two-session return races and passed with side-effect and cleanup checks.

The D4 customer dispute regression harness was refreshed to the current D5-A target-aware seven-argument `customer_open_order_dispute` signature. No D4 RPC or policy was changed.

## D8 Refund Workflow Coverage

`scripts/rpc/refund-workflow-backend-tests-dev-only.sql` covers the D8 refund workflow boundary with 99 passing DEVELOPMENT assertions:

- anonymous and wrong-role callers are blocked
- finance authority uses active `admin_staff` finance roles, not `profiles.primary_role`
- support-only staff cannot approve or verify money
- disputes and optional returns must be eligible and related
- customer, supplier, order, item, supplier, amount caps, and currency are derived server-side
- current product price cannot affect refund maximums
- item, delivery-fee, order, active, verified, and completed obligations count against cumulative caps
- goodwill refunds remain deferred
- supplier sent reporting is scoped to the responsible supplier
- platform sent reporting requires finance authority
- customer confirmation/dispute is owner-scoped and does not verify accounting
- finance verification, rejection, and completion are controlled and idempotent
- safe reads hide private notes, raw references, and finance internals according to role
- direct table insert/update/delete remains blocked
- no order/payment/return/stock/reservation/delivery/settlement/commission/wallet/withdrawal/notification/provider side effects occur

`scripts/rpc/refund-workflow-d8-concurrency-dev-only.mjs` covers 12 true multi-process refund races and passed with side-effect and cleanup checks.

D8 verification also reran D4, D5, D6 SQL, D7 SQL, D7 external concurrency, and D8 SQL/external suites. D6 external concurrency was retried separately because the legacy harness can fail on timing-only overlap assertions or transient Supabase Management API 5xx responses.
## D9 Finance Holds QA Update

D9 adds the following backend-only QA assets:

- `scripts/rpc/dispute-finance-holds-d9-tests-dev-only.sql`
- `scripts/rpc/dispute-finance-holds-d9-concurrency-dev-only.mjs`

Coverage includes finance authorization, settlement blockers, commission holds, withdrawal boundaries, supplier/platform liabilities, direct grant posture, audit privacy, no stock/notification/provider side effects, and multi-process races.

Regression coverage includes D6 admin dispute, D7 return workflow, D8 refund workflow, reseller withdrawal, and finance visibility. Existing settlement verification regressions require a pending development settlement fixture; when none exists, they are fixture-blocked rather than D9-failed.
