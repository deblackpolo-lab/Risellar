# Risellar D13-B Customer Disputes UI Report

Date: 2026-08-03

## A. Summary

D13-B connects the customer dispute browsing, detail, order problem-reporting, and customer response UI to audited customer dispute RPCs. The implementation replaces the mock customer dispute detail route, redirects the legacy report-issue route to the real report-problem flow, and adds a safe read-only order-item selector for item-specific dispute reporting.

## B. Routes Connected

- `/customer/disputes`
- `/customer/disputes/[id]`
- `/customer/orders/[id]/report-problem`
- `/customer/orders/[id]/report-issue` now redirects to `/customer/orders/[id]/report-problem`

## C. RPC Boundaries Used

- `list_customer_disputes_safe`
- `get_customer_dispute_safe`
- `customer_open_order_dispute`
- `customer_add_dispute_response`
- `list_customer_order_items_for_dispute_safe`

No direct customer dispute table reads or writes were added to UI code.

## D. UI Behavior

- Customer dispute list shows safe order reference, reason, affected summary, requested outcome, status, latest customer-visible message, and safe next action.
- Customer dispute detail shows customer-visible messages, public status history, public resolution message when present, and a customer response form.
- Customer report-problem page opens an audited dispute from the customer order detail flow.
- Item-specific reasons require selecting a safe customer-owned order item.
- Successful report-problem submissions return the real dispute detail href from the audited RPC and the client navigates to it.
- Terminal dispute statuses hide the customer response form and show a closed-response state.
- The older `/report-issue` route no longer renders the mock issue screen.

## E. Item-Specific Scope

The forward migration `20260803090000_customer_safe_dispute_order_item_selector.sql` adds `list_customer_order_items_for_dispute_safe`.

The RPC returns only public/customer-safe order item data needed by the form:

- safe item selector value
- safe item name
- safe variant summary
- quantity
- final customer price
- line total
- currency

It does not return supplier IDs, private supplier data, internal notes, private prices, margins, commissions, settlements, payout data, or stock internals. Supplier assignment remains backend-derived by `customer_open_order_dispute`.

## F. Security And Scope Protections

- Customer identity is resolved through Clerk and Supabase authenticated-user clients.
- Activated customer dispute routes do not import `lib/mock/support-disputes`.
- Supplier IDs, supplier private messages, internal notes, payout data, margins, commissions, settlements, withdrawal data, and finance-private records are not mapped to customer UI DTOs.
- Dispute opening and response submission use idempotency keys.
- No refund, return, evidence upload, payment, order-status, stock, delivery, commission, settlement, withdrawal, or notification mutation was added.

## G. Tests Added

- `tests/customer-disputes.test.ts`

Covered:

- bounded list payload construction
- customer-safe list/detail RPC names and payloads
- safe DTO mapping without internal fields
- audited open/response payload construction
- item-specific reason validation with the safe item selector
- safe item selector RPC payload mapping
- safe error mapping
- route policy coverage
- mock/service-role/unrelated-flow source guard
- successful dispute-open detail navigation behavior
- terminal dispute response-form hiding

## H. Commands Run So Far

- `git status --short`: clean before implementation.
- `npm test -- tests/customer-disputes.test.ts`: failed first because `@/lib/customer/disputes` did not exist.
- `npm test -- tests/customer-disputes.test.ts`: passed after helper implementation, 6 tests.
- `npm run typecheck`: passed.
- Browser route check for `/customer/disputes`: route rendered; unauthenticated browser session showed the safe sign-in-required customer state.
- `git diff --check`: passed with Windows line-ending warnings only.
- `npm test`: passed, 49 files and 298 tests.
- `npm run lint`: first run failed on two unused imports; fixed.
- `npm run lint`: passed after cleanup.
- `npm run build`: passed, Next.js compiled successfully and generated 175 static pages.
- `npm run typecheck`: passed when rerun sequentially after build.
- `npx tsc --noEmit`: passed when rerun sequentially after build.
- `npm test -- tests/customer-disputes.test.ts`: passed after redirect, terminal-response, and safe item selector refinements, 8 tests.
- `npx supabase db push --dry-run`: passed and showed only `20260803090000_customer_safe_dispute_order_item_selector.sql`.
- `npx supabase db push`: applied the safe item selector migration to the confirmed DEVELOPMENT Supabase project.
- `npx supabase db query --linked --file scripts/rpc/customer-dispute-item-selector-tests-dev-only.sql`: first run found a dev-only temp-table permission issue; fixed without changing the migration/RPC.
- `npx supabase db query --linked --file scripts/rpc/customer-dispute-item-selector-tests-dev-only.sql`: passed 12 active assertions.
- `npm run lint`: passed after redirect and terminal-response UI refinements.
- `npm run typecheck`: passed after redirect and terminal-response UI refinements.
- Pure-customer browser QA: `/auth/qa-profile-sync` confirmed an authenticated active customer session with no visible admin/supplier signal.
- Pure-customer browser QA: development-only fixture orders were created and cleaned up for the current customer.
- Pure-customer browser QA: `/customer/disputes`, `/customer/orders`, `/customer/orders/[id]`, `/customer/orders/[id]/report-problem`, and `/customer/disputes/[id]` loaded without 404 or server error.
- Pure-customer browser QA: order-wide dispute submission worked through `customer_open_order_dispute` and landed on the real dispute detail path.
- Pure-customer browser QA: item-specific delivered-order dispute submission used the safe selector and worked through `customer_open_order_dispute`.
- Pure-customer browser QA: customer response submission worked through `customer_add_dispute_response` and appeared once.
- Pure-customer browser QA: terminal dispute status hid the response form and showed the closed-response state.
- Pure-customer browser QA: mobile and desktop checks found no horizontal overflow.
- Pure-customer browser QA: marker-scoped side-effect checks found no return, refund, stock reservation, delivery quote, delivery arrangement, settlement, commission, withdrawal, or finance rows for D13B QA orders.

Note: one parallel typecheck attempt raced with `next build` while `.next/types` was being regenerated, producing temporary missing-file errors. Sequential reruns passed.

## I. Current Browser QA Status

Authenticated development customer browser QA is now completed for the item-specific and order-wide dispute paths with a pure customer session and cleaned development-only fixtures.

Verified:

- `/auth/qa-profile-sync` confirmed an authenticated, active customer profile.
- `/customer/orders` loaded for the customer session.
- `/customer/disputes` loaded without 404 or server error.
- A fake development-only eligible order appeared only for the signed-in customer.
- `/customer/orders/[id]/report-problem` opened the audited report-problem flow.
- The empty description submission was blocked by validation.
- A valid order-wide delivery issue opened a real dispute through `customer_open_order_dispute`.
- A valid item-specific delivered-order issue opened a real dispute through `customer_open_order_dispute` using the safe item selector.
- The dispute detail page showed safe order reference, affected summary, status, customer-visible message, and status history.
- One customer response was added through `customer_add_dispute_response` and appeared once.
- A controlled terminal fixture state hid the response form.
- No private supplier, admin, finance, margin, commission, settlement, payout, stock-internal, token, or raw identifier fields were visible.
- The development-only D13B order, dispute, product, and reseller-product markers were cleaned after QA.

## J. Files Changed

- `app/customer/disputes/actions.ts`
- `app/customer/disputes/page.tsx`
- `app/customer/disputes/[id]/page.tsx`
- `app/customer/orders/[id]/page.tsx`
- `app/customer/orders/[id]/report-issue/page.tsx`
- `app/customer/orders/[id]/report-problem/page.tsx`
- `components/customer/customer-dispute-rpc-screens.tsx`
- `lib/customer/dispute-shared.ts`
- `lib/customer/disputes.ts`
- `scripts/rpc/customer-dispute-item-selector-tests-dev-only.sql`
- `supabase/migrations/20260803090000_customer_safe_dispute_order_item_selector.sql`
- `tests/customer-disputes.test.ts`
- D13-B documentation files

## K. Whether Safe To Commit

Safe to commit. Browser QA has passed for the pure-customer list, detail, item-specific report-problem, order-wide report-problem, response, terminal-state, responsive, side-effect, and cleanup checks.

## L. Final Verification

- `git diff --check`: passed with Windows line-ending warnings only.
- `npm test`: passed, 49 files and 300 tests.
- `npm run lint`: passed.
- `npm run build`: passed.
- `npm run typecheck`: passed.
- `npx tsc --noEmit`: passed.
- `npx supabase db query --linked --file scripts/rpc/customer-dispute-item-selector-tests-dev-only.sql`: passed 12 active assertions.
- Local post-cleanup `/customer/disputes` browser check: loaded safe empty state without server error or horizontal overflow.
- Secret/scope scan: `.env.local`, `supabase/.temp`, `.next`, and `.codex-dev-server-401.*.log` are ignored; no service-role values were found in `app/` or `components`; scan hits were limited to existing server-only helpers, placeholder documentation, and negative test assertions.
- Business side-effect check: D13B QA orders had zero return, refund, stock reservation, delivery quote, delivery arrangement, settlement, commission, withdrawal, or finance side-effect rows; D13B order/dispute/product/listing markers were cleaned.
