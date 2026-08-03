# Risellar D13-B Customer Disputes Browser QA

Date: 2026-08-03

## Scope

Browser QA covers the real customer dispute list, customer dispute detail, order report-problem flow, and customer response submission.

## Current Result

Current status: **passed for D13-B customer dispute browser QA**.

The Codex browser session was later signed in as a development customer. `/auth/qa-profile-sync` confirmed:

- profile sync working
- default role `customer`
- account status `active`

`/customer/disputes` loaded without 404 or server error. Fake development-only eligible order fixtures were created for the signed-in pure customer, exercised through the browser for both item-specific and order-wide reporting, and then cleaned up.

## Verified So Far

- `/customer/disputes` compiles and renders.
- The route uses the real customer dispute UI, not the preserved support-disputes mock component.
- Unauthenticated access does not expose dispute records.
- `/customer/orders` showed the development-only eligible order only after fixture setup.
- `/customer/orders/[id]` loaded and exposed the real `Report a problem` entry point.
- `/customer/orders/[id]/report-problem` loaded with safe order summary fields.
- Empty description submission was blocked by validation.
- Valid order-wide delivery issue submission created a dispute through the audited RPC.
- Valid item-specific delivered-order submission used the safe order-item selector and created a dispute through the audited RPC.
- Successful submission navigated to `/customer/disputes/[id]`.
- The dispute detail showed safe order reference, affected summary, status, timeline/history, and customer-visible messages only.
- One customer response was added and appeared once.
- Terminal dispute state hid the response form.
- Mobile and desktop checks found no horizontal overflow.

## Safe Item Selector

A forward migration added `list_customer_order_items_for_dispute_safe`, a read-only authenticated RPC for the current customer. It exposes only safe item label, variant summary, quantity, final customer price, line total, currency, and the safe order item selector value needed by `customer_open_order_dispute`.

The selector does not expose supplier IDs, private supplier data, margins, commissions, settlements, payout fields, stock internals, admin notes, or finance fields. Supplier assignment remains backend-derived by the audited dispute RPC.

## Browser Findings

- Initial unauthenticated state was safe.
- A real defect was found and fixed: a client component imported constants from a `server-only` helper. The constants and UI types were moved to `lib/customer/dispute-shared.ts`.
- Attempted automated navigation to `/sign-in` was blocked by the browser surface with `ERR_BLOCKED_BY_CLIENT`; the user needs to sign in manually in the Codex browser.
- Authenticated customer session verification passed through `/auth/qa-profile-sync`.
- `/customer/disputes` loaded for the pure customer session.
- A dev-only order-wide fixture was created and cleaned after QA.
- The first delivered-order fixture correctly rejected the default order-wide delivery-delay reason with `DISPUTE_NOT_ALLOWED_FOR_ORDER_STATE`; the fixture was cleaned and recreated in an eligible delivery-arranged state.
- The valid order-wide report-problem flow passed after the navigation fix.
- The valid item-specific report-problem flow passed after the safe selector migration and UI wiring.
- One customer response was added to the item-specific dispute and appeared exactly once after refresh.
- Console logs contained only expected Clerk development-key warnings.
- Marker-scoped side-effect checks found no return, refund, stock reservation, delivery quote, delivery arrangement, settlement, commission, withdrawal, or finance rows for D13B QA orders.
- D13B browser QA order/dispute/product/listing markers were cleaned after verification.

## Fixes Added After Authenticated QA

- Successful `customer_open_order_dispute` results now navigate to the returned dispute detail URL from the client after the server action returns the href.
- Terminal dispute statuses now render a closed response state instead of the customer response form.
- A focused regression assertion covers those two UI requirements.
- A safe customer order-item selector RPC and UI selector now support item-specific browser disputes without exposing private supplier or finance fields.

## Commit Readiness

Ready for full D13-B commit, push, and production smoke. Local browser QA passed for the pure-customer dispute list, detail, item-specific report-problem flow, order-wide report-problem flow, response path, terminal-state behavior, responsive layout, and marker-scoped cleanup.

## Final Verification

- SQL boundary test: passed 12 active assertions for `list_customer_order_items_for_dispute_safe`.
- Automated tests: `npm test`, `npm run lint`, `npm run build`, `npm run typecheck`, and `npx tsc --noEmit` passed.
- Local runtime: post-cleanup `/customer/disputes` loaded a safe empty state without server error or horizontal overflow.
- Secret/scope scan: ignored local files stayed untracked; no service-role values were found in `app/` or `components`; no return/refund/payment/stock/delivery/settlement/commission/withdrawal mutation integration was added.
