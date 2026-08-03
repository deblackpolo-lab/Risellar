# Risellar D13-B Customer Disputes Security Review

Date: 2026-08-03

## Summary

D13-B keeps customer dispute UI access behind existing customer route guards and uses only audited customer dispute RPCs through server actions.

## Data Access

- List: `list_customer_disputes_safe`
- Detail: `get_customer_dispute_safe`
- Open: `customer_open_order_dispute`
- Response: `customer_add_dispute_response`
- Item selector: `list_customer_order_items_for_dispute_safe`

The UI does not perform direct table reads or writes for dispute records.

## Privacy Controls

The customer DTO excludes:

- supplier private messages
- internal notes
- supplier IDs in visible UI
- supplier payout/contact/private data
- margins
- commissions
- settlements
- withdrawal data
- risk/internal/admin-only fields

The helper maps only the safe fields returned by the customer-safe RPCs.

## Mutation Scope

The only mutation paths added are:

- open customer dispute
- add customer dispute response

No UI integration was added for:

- refunds
- returns
- evidence uploads
- order status mutation
- payment mutation
- stock or reservation mutation
- delivery mutation
- settlement mutation
- commission mutation
- withdrawal mutation
- notification sending

## Item-Specific Reason Handling

Item-specific reasons now use `list_customer_order_items_for_dispute_safe`, a read-only authenticated RPC that returns only safe customer-owned order item selector data. The browser does not choose a supplier ID; supplier assignment remains backend-derived by `customer_open_order_dispute`.

## Browser QA Security Notes

- The authenticated pure customer session was verified as active customer through `/auth/qa-profile-sync`.
- `/customer/disputes` loaded without leaking cross-customer dispute data.
- `/customer/orders` exposed the development-only fixture order for the signed-in customer.
- A fake development-only fixture was created only after explicit approval and cleaned after browser QA.
- The UI now navigates successful dispute-open submissions to the real safe dispute detail URL returned by the RPC.
- Terminal dispute statuses hide the response form, preventing additional browser responses after closure.
- Item-specific delivered-order browser QA passed with a safe order item selector.
- Browser checks found no supplier-private messages, internal admin notes, finance data, margins, commissions, settlement data, payout data, stock internals, tokens, or raw private identifiers in customer-visible dispute screens.
- Marker-scoped side-effect checks found no return, refund, stock reservation, delivery quote, delivery arrangement, settlement, commission, withdrawal, or finance rows for D13B QA orders.
- D13B browser QA order/dispute/product/listing markers were cleaned after verification.

## Source Guard

The focused test verifies activated customer dispute sources do not import preserved mock dispute data, service-role clients, or unrelated business-flow mutation references.

## Secret And Scope Scan Status

- `.env.local`, `supabase/.temp`, `.next`, and `.codex-dev-server.*.log` are ignored and not tracked.
- Focused changed-file scan found only negative test assertions containing service-role strings.
- `app/` and `components/` scan found no service-role imports or service-role key references.
- Broad historical docs/source scan produced expected documentation-only safety wording hits, not new secret values.

## Remaining Security Work

Final secret/scope scan passed before commit. Broad historical hits were limited to existing server-only helper references, placeholder documentation, and negative test assertions. No D13-B customer UI source added service-role usage, direct table mutation, private supplier/finance mapping, or unrelated return/refund/payment/stock/delivery/settlement/commission/withdrawal integration.
