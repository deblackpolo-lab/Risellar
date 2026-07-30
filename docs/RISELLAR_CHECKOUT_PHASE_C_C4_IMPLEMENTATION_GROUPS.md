# Risellar Checkout Phase C C4 Implementation Groups

## Summary

This document refines the next checkout implementation groups after the verified backend order-creation and stock-reservation work.

## C4 - Planning Only

Status: current group.

Scope:

- audit current draft UI
- audit route protections
- identify order-read boundary requirements
- define disabled and future enabled copy
- define server-action contract
- define tests and browser QA plan
- document risks

Out of scope:

- source changes
- migrations
- server actions
- live DB operations
- final confirmation button enablement

## C5 - Customer Order Read Boundary

Goal:

Create or confirm a safe read path for customer order success/detail/list screens.

Possible outcomes:

- Use existing `checkout_order_safe_row(uuid)` through a server-only helper if it is sufficient.
- Add a dedicated `get_customer_order(uuid)` wrapper if the existing function needs a narrower app contract.
- Add `list_customer_orders()` if order history must become live.

Required verification:

- customer can read own order only
- cross-customer read is blocked
- reseller/supplier/customer route isolation is preserved
- sensitive supplier/reseller/admin/finance fields are hidden
- no payment, delivery, commission, settlement, or withdrawal integration is added

## C6 - Final Confirmation Server Action And UI Wiring

Goal:

Wire the draft review page to `create_order_from_checkout_draft(uuid,text)` through a server action.

Required behavior:

- user-context Supabase client only
- no service role
- no client price/status/margin/stock payload
- required acknowledgement
- idempotency key support
- pending/loading state
- mapped safe errors
- redirect to customer-safe order success/detail route

The final confirmation button can only be enabled in this group after tests pass.

## C7 - Browser QA And Development Data Verification

Goal:

Run live browser QA using development accounts and development data.

Checks:

- customer starts draft from public shop product
- customer attaches own delivery address
- customer places order once
- duplicate click does not create duplicate order
- insufficient stock is handled safely
- order, order item, reservation, inventory movement, and audit rows match expectations
- no payment, delivery quote, commission, settlement, or withdrawal rows are created

## C8 - Documentation, Commit, And Push

Goal:

Commit only after C6/C7 pass and the user explicitly asks.

Required before commit:

- `git status --short`
- `git diff --check`
- `npm test`
- `npm run lint`
- `npm run build`
- `npm run typecheck`
- `npx tsc --noEmit`
- secret/scope scan

Commit scope must exclude:

- `.env.local`
- `.local-recovery`
- `.next`
- `.codex-dev-server.*.log`
- unrelated business-flow files
- production data or identifiers

## Deferred Groups

Future phases only, not part of C4-C8:

- customer confirmation after order placement
- supplier preparation workflow
- delivery quote workflow
- delivery tracking
- payment collection
- commission release
- settlements
- withdrawals
- refunds
