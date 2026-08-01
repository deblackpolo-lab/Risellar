# Risellar Dispute D5-A Multi-Supplier Security Review

## Root Cause

The D2 supplier safe-read RPCs authorized access by checking whether the supplier owned any item on the disputed order. On a multi-supplier order, that could expose a dispute about Supplier A to Supplier B.

## Fix

D5-A stores immutable target fields on `public.order_disputes` and repairs supplier reads to require target equality through `affected_supplier_id`, with a narrow single-supplier order-wide exception.

## Protections Preserved

- Customers provide order ID and optional order item ID only.
- Supplier identity is derived server-side from `order_items.supplier_id`.
- Target fields are immutable.
- Direct dispute table access remains revoked from browser roles.
- RLS remains enabled and forced.
- SECURITY DEFINER functions use fixed `search_path = public`.
- The old ambiguous customer-open signature is not executable by browser roles.
- No service-role helper is used in app or component code.

## Privacy Results

Supplier A sees only Supplier A target cases. Supplier B sees only Supplier B target cases. Owning a different item on the same multi-supplier order is not sufficient.

Customers see their own cases. Other customers remain blocked.

Resellers receive safe impact summaries only and do not see complaint text, supplier private data, supplier IDs, payout data, settlement proof, or admin notes.

Admin/support reads include safe target context. Finance details remain gated by finance-admin role.

## Business Boundary

D5-A does not mutate orders, payment state, delivery state, stock, reservations, settlements, commissions, withdrawals, notification outbox, provider events, returns, refunds, or evidence records.

## Concurrency Caveat

The SQL suite verifies target-aware idempotency, uniqueness, and isolation invariants in a rollback-scoped script. The repository does not currently include a separate two-session dispute concurrency runner. Runtime protection is provided by advisory locks and target-aware uniqueness.
