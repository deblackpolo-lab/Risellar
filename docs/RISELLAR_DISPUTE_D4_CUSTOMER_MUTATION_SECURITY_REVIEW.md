# Risellar Dispute D4 Customer Mutation Security Review

## Scope

Reviewed the D4 customer dispute mutation backend:

- `customer_open_order_dispute`
- `customer_add_dispute_response`
- D4 validation helpers
- development-only SQL boundary tests

No UI or browser/client mutation path was added.

## Identity And Ownership

The RPCs resolve the caller through existing server-side profile/customer helpers and do not trust browser-supplied identity fields. A customer can open/respond only for disputes tied to their own order. Cross-customer open, detail, list, and response checks passed in the D4 SQL test.

## Role Gate

The customer helper requires an active customer profile/customer row and excludes active admin staff. Inactive customer records and suspended profiles are blocked. The implementation does not add an admin/supplier/reseller bypass and does not use a browser-supplied role.

## Direct Table Access

No `INSERT`, `UPDATE`, or `DELETE` grants were added to `order_disputes`, `dispute_messages`, or `dispute_status_history` for browser roles. The test confirmed direct table writes remain denied.

## RLS And SECURITY DEFINER Posture

The D4 RPCs use `SECURITY DEFINER` with fixed `search_path = public` and enforce ownership internally. Helper functions are not executable by `public`, `anon`, or `authenticated`.

## Data Validation

The RPCs validate:

- required order/dispute IDs
- active customer identity
- category/reason/outcome allowlists
- reason/category mapping
- reason/order-state mapping
- bounded plaintext descriptions/responses
- bounded idempotency keys
- no sensitive-keyword markers in text/key fields

## Idempotency And Duplicate Cases

Idempotency is durable:

- same open key and same payload returns the existing dispute
- same open key with different payload conflicts
- duplicate active case with the same live active fingerprint is not duplicated
- same response key and same body returns the existing message
- same response key with different body conflicts

The live D2 duplicate-active rule is stricter than the planning text: it keys active cases by order, opener profile, and reason code.

## Audit Privacy

Audit rows are written for dispute open, customer response, and the awaiting-customer transition. Metadata is limited to safe operational fields and excludes full descriptions, response bodies, contact details, evidence, private notes, and financial internals.

## Business Side Effects

D4 does not mutate:

- orders or order statuses
- payment statuses
- stock or reservations
- settlements
- commissions
- wallets
- withdrawals
- delivery arrangements
- notification outbox/provider events

The SQL test verified business counts/statuses remained unchanged.

## Static Scan Result

Static review found no service-role usage in app/components, no broad dispute table grants, no dispute UI activation, and no checkout/payment/delivery/finance/stock integration in D4 changes.

The D4 files were also scanned for high-confidence secret patterns. No real keys, bearer tokens, private keys, connection strings, production data, Clerk identifiers, private emails, phone numbers, cookies, or JWT values were found. SQL fixture identities use fake development-only labels and rollback or cleanup scope.

## Security Conclusion

D4 preserves the D2/D3 read/privacy boundary and adds only audited customer-owned mutation entry points. No confirmed RLS/RPC/security gap remains from D4 verification.
