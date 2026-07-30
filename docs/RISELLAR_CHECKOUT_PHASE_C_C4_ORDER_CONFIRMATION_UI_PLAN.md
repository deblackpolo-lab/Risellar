# Risellar Checkout Phase C C4 Order Confirmation UI Plan

## Summary

This plan covers customer order-confirmation UI and server-action integration only. It does not implement source changes, enable the final confirmation button, create migrations, create RPCs, or run live database operations.

Current verified baseline:

- Branch: `main`
- Required HEAD: `90c94d2fa7d561bc6208e56d97c3440263177c7c`
- Backend order RPC exists and has passed single-session and true two-session boundary verification.
- `create_order_from_checkout_draft(uuid,text)` creates the order, order item, stock reservation, inventory movement, and audit rows inside the server-side transaction.
- R7 true concurrency verified one successful order and one `INSUFFICIENT_STOCK` loser without oversell or partial loser rows.
- Checkout draft UI remains draft-only and the final confirmation control remains disabled.

## Current Draft UI Audit

Current route: `/checkout/draft/[draftId]`

Observed safe behaviors from source review:

- Page data is loaded through server-only actions in `app/checkout/draft/actions.ts`.
- The user-context Supabase client uses the Clerk session token and anon/publishable Supabase client context.
- Draft review displays product snapshot, quantity, unit price, draft total, status, contact/address snapshot, and saved address selection.
- Address/contact attach uses `update_checkout_draft_contact_address`.
- Abandon uses `abandon_checkout_draft`.
- The visible final action is disabled and reads `Order confirmation coming next`.
- Copy states that this page cannot place an order.

No order creation server action exists in the current draft UI. That is the correct safe state for C4.

## Confirmation Flow Decision

Recommended flow for the next implementation group:

1. Customer opens `/checkout/draft/[draftId]`.
2. Customer confirms contact and delivery address on the draft.
3. UI displays an acknowledgement checkbox before enabling the final submit.
4. Server action calls `create_order_from_checkout_draft(draftId, idempotencyKey)`.
5. RPC returns a safe order summary.
6. Server action redirects to a customer-owned success/detail route.

C4 decision: keep the final confirmation button disabled until C5/C6 implementation explicitly wires and tests this flow.

## Final CTA Recommendation

Button label when still disabled:

`Order confirmation coming next`

Button label when enabled in a future implementation group:

`Place order and reserve stock`

Supporting copy must state:

- No online payment is collected.
- Pay on Delivery remains the only payment method for this phase.
- Placing the order reserves stock temporarily.
- Delivery quote and delivery tracking are not started by this action.
- Supplier preparation is not triggered by this action.

## Customer Acknowledgement

Before the final order action can become enabled, the UI should require a checked acknowledgement:

`I understand this places my order, reserves available stock, and I will pay on delivery after the seller confirms the order process.`

The acknowledgement must be required in the client UI and rechecked in the server action payload. The server action should reject missing acknowledgement before calling the RPC.

## Server Action Contract

Future server action name recommendation:

`confirmCheckoutDraftOrderAction`

Allowed input:

- `checkout_draft_id`
- `acknowledged_order_terms`
- optional `idempotency_key`

Forbidden client input:

- price
- product id
- reseller id
- supplier id
- quantity override unless the draft RPC contract explicitly supports it
- stock quantity
- order status
- payment status
- delivery status
- confirmation status
- commission, settlement, withdrawal, payout, or margin fields

Backend call:

`create_order_from_checkout_draft(p_checkout_draft_id, p_idempotency_key)`

The server action must not insert or update `orders`, `order_items`, `stock_reservations`, `product_variants`, `commissions`, `settlements`, `withdrawals`, `delivery_quotes`, or payment tables directly.

## Idempotency UX

The client should generate or submit an idempotency key per final attempt. A safe implementation may use a browser-generated UUID stored in form state or a server-provided hidden value generated during render.

UX rules:

- Disable the final submit while the action is pending.
- Reuse the same idempotency key during retry for the same visible attempt if the browser resubmits.
- If the RPC returns an existing order for the same draft/idempotency key, route to the same success/detail state.
- Do not create a second draft or second order from a duplicate click.

## Error Mapping

The server action should map RPC errors into safe user-facing messages:

| Backend code | User message |
| --- | --- |
| `AUTH_REQUIRED` | Sign in to place this order. |
| `PROFILE_SYNC_FAILED` | Finish account setup before placing this order. |
| `SUPABASE_AUTH_TOKEN_MISSING` | Your session could not be verified. Please sign in again. |
| `DRAFT_ID_REQUIRED` | This checkout draft could not be found. |
| `CHECKOUT_DRAFT_NOT_FOUND` | This checkout draft is no longer available. |
| `CHECKOUT_DRAFT_NOT_ACTIVE` | This checkout draft cannot be placed anymore. |
| `CUSTOMER_ADDRESS_NOT_FOUND` | Choose one of your saved delivery addresses. |
| `CHECKOUT_LISTING_NOT_AVAILABLE` | This product is no longer available from this shop. |
| `INSUFFICIENT_STOCK` | This product just sold out or has less stock than requested. |
| `IDEMPOTENCY_KEY_TOO_LONG` | Please refresh and try again. |
| `RPC_PERMISSION_DENIED` | You are not allowed to place this order. |
| unknown | We could not place the order. Please try again. |

Errors must not expose SQL details, IDs, tokens, internal table names, or stack traces to the browser.

## Success Route Decision

Preferred future redirect:

`/checkout/success?order=<opaque-order-id-or-number>`

Alternative:

`/customer/orders/[orderId]`

The route must resolve the order through a customer-safe read helper and must not trust query-string product, price, stock, or status values.

## Boundaries

C4 does not enable:

- checkout final submit
- online payment
- delivery quote creation
- delivery tracking
- supplier preparation
- supplier notification
- commission release
- settlement creation
- withdrawal changes
- refunds
