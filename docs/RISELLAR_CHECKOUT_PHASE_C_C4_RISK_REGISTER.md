# Risellar Checkout Phase C C4 Risk Register

## Summary

This register captures risks for enabling customer order confirmation after the backend order RPC has passed single-session and true two-session tests.

## Risks

| Risk | Impact | Mitigation |
| --- | --- | --- |
| Final CTA enabled before server action tests | Customer could create orders through an unreviewed path | Keep button disabled until C6 tests and browser QA pass |
| Client sends price or status fields | Price tampering or status manipulation | Server action accepts only draft id, acknowledgement, and idempotency key |
| Missing safe order read path | Success/detail page could use mock data or direct table reads | Complete C5 read boundary before C6 UI enablement |
| Duplicate submit creates duplicate orders | Customer could reserve stock twice | Require idempotency key and pending UI state |
| Insufficient stock message unclear | Customer confusion after concurrent purchase | Map `INSUFFICIENT_STOCK` to a clear no-order-created message |
| Payment or delivery copy overpromises | Customer may think payment or delivery was completed | Copy must say Pay on Delivery and delivery quote remain deferred |
| Sensitive fields leak on success/detail | Supplier/reseller/private finance data exposure | Map only safe order fields and test banned-field names |
| Service role used in customer action | RLS bypass in normal customer flow | Use user-context Supabase auth only |
| Direct table write appears in app code | Bypasses audited RPC | Source tests must reject direct writes to order/stock tables |
| Stale mock routes look live | QA/customer confusion | Label old order routes as placeholder until C5/C6 replaces them |
| Production project accidentally used | Data/security incident | Do not run live Supabase commands in C4; future phases must precheck development project |

## Current Risk Rating

Current C4 risk is low because no source changes are made and final order confirmation remains disabled.

Future C6 risk is medium because it will intentionally create orders and reserve stock in development. That work must be guarded by the C5 read boundary, source tests, browser QA, and explicit user approval.

## Non-Negotiable Controls

- No production Supabase connection.
- No service role in app/components.
- No client-controlled prices, margins, status, stock, settlement, commission, withdrawal, payment, or delivery fields.
- No direct table writes from the UI.
- No payment, delivery, supplier preparation, commission, settlement, withdrawal, or refund side effects.
- No secrets or private identifiers in docs or command output.

## Open Questions For Next Group

1. Should C5 wrap `checkout_order_safe_row(uuid)` directly, or introduce a narrower `get_customer_order(uuid)` RPC?
2. Does `/customer/orders` need a real list in the first enablement, or can C6 redirect only to a single success/detail page?
3. Should the idempotency key be generated client-side per form render or server-side during draft page data load?
4. What exact reservation expiry copy should be shown if the backend returns `reservation_expires_at`?
