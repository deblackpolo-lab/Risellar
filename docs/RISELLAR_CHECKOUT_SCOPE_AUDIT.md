# Risellar Checkout Scope Audit

Date: 2026-07-29

Safe baseline: `94f6eb69ca1d22c475997f52d4d7729d52dfd0b7`

## Approved Scope

Risellar is approved only through Checkout Phase B Group 1 backend:

- checkout draft RPC foundation
- customer creates checkout draft from active approved listing
- server-calculated draft price snapshot
- own address attachment
- own draft update/abandon
- no order creation
- no stock reservation
- no payment
- no delivery quote
- no commission
- no settlement
- no withdrawal
- no purchase flow submission

## Draft-Only Files That May Be Salvaged

| File | Status | Required Cleanup |
| --- | --- | --- |
| `app/checkout/draft/[draftId]/page.tsx` | SALVAGE PARTS | Keep only draft review/edit/abandon display. |
| `app/checkout/draft/[draftId]/actions.ts` | SALVAGE PARTS | Remove order creation and any submit/purchase action. |
| `app/shop/[shopSlug]/product/actions.ts` | SALVAGE PARTS | Keep only create-draft action via approved draft RPC. |
| `components/customer/checkout-draft-screens.tsx` | SALVAGE PARTS | Replace "place order" copy with "draft only" state. |
| `lib/checkout/draft.ts` | SALVAGE PARTS | Keep draft RPC wrappers only; remove `createOrderFromDraft`. |
| `lib/checkout/server.ts` | SALVAGE PARTS | Keep only token-safe user-context helper if needed. |
| `tests/checkout-draft-ui.test.tsx` | SALVAGE PARTS | Keep draft tests; remove order/payment/stock expectations. |

## Unapproved Checkout and Order Scope

| File | Forbidden Area |
| --- | --- |
| `supabase/migrations/20260718210000_create_order_from_draft_rpc.sql` | order creation, stock reservation, order items, settlement/commission snapshots |
| `app/actions/orderActions.ts` | delivery assignment, payment collection, settlement, stalled order actions |
| `app/api/orders/[orderId]/initiate-settlement/route.ts` | settlement |
| `app/api/delivery/orders/[orderId]/confirm-payment/route.ts` | payment collection |
| `app/api/supplier/orders/[orderId]/prepare/route.ts` | supplier order preparation |
| `app/api/supplier/orders/[orderId]/ready/route.ts` | supplier order fulfillment |
| `app/api/admin/orders/[orderId]/assign-dispatch/route.ts` | delivery dispatch |
| `app/api/admin/orders/[orderId]/force-transition/route.ts` | manual order state mutation |
| `app/api/admin/orders/stalled/route.ts` | operational order monitoring |
| `app/api/confirm/route.ts` | customer confirmation token flow |
| `app/customer/orders/[orderId]/confirm/account.action.ts` | customer confirmation |
| `app/admin/orders/confirmation-queue/page.tsx` | admin confirmation queue |
| `app/admin/operations/exceptions/page.tsx` | payment/order exception handling |
| `app/delivery/` | delivery app |
| `components/delivery/` | delivery UI |
| `lib/notifications/confirmation-failed.ts` | notification workflow |
| `supabase/functions/expire-unconfirmed-orders/index.ts` | order expiry automation |

## Forbidden Migration Effects

The unapproved migrations create or alter:

- order creation RPC
- stock reservation writes
- order item writes
- order expiry fields and index
- supplier order preparation RPC
- delivery timestamps
- delivery person role enum
- edge function infrastructure

None of these should be applied or committed as part of the current project state.

## Scope Root Cause

The recovery audit indicates the other agent skipped the phase boundary. It moved from draft review into order lifecycle, confirmation, delivery, and settlement without approved backend design, RPC boundary tests, browser QA, or security review.

## Recovery Rule

During recovery, checkout may only reintroduce:

1. create draft from public listing
2. show draft
3. update quantity/address/contact if backed by approved RPCs
4. abandon draft

Everything that creates orders or reserves stock must remain deleted until a new approved phase explicitly starts it.
