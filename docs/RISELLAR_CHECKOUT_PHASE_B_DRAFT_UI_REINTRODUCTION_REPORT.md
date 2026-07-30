# Risellar Checkout Phase B Draft UI Reintroduction Report

Date: 2026-07-30

## A. Masked customer account used

Live browser QA used a signed-in development-only Clerk customer test account. The exact email and credentials were not printed or recorded. `/auth/qa-profile-sync` confirmed a synced active customer profile, Clerk user id stored, email stored, no displayed token values, and no role-promotion input.

## B. Public product used, masked

QA used a development-only public reseller shop/product fixture:

- shop slug masked as `shop-5d...cc1`
- product slug masked as `risellar-admin...a626`
- displayed customer price: `GHS 102.77`

No supplier private/contact/payout/internal/admin fields were exposed in the browser flow.

## C. Start checkout browser result

The public product page loaded with CSS, showed `Start checkout`, kept add-to-shop/cart behavior separate, and submitted only trusted listing id, fixed quantity, and a safe return path. It did not submit price, product snapshot, supplier id, reseller id, platform margin, reseller margin, order, stock, payment, or delivery fields.

## D. Draft creation result

Clicking `Start checkout` as the signed-in customer created a checkout draft through `create_checkout_draft_from_listing` and redirected to `/checkout/draft/[draftId]`. No order-success, fake success, stock reservation, payment, or delivery flow appeared.

## E. Draft review result

The draft review page loaded through `get_checkout_draft` and showed:

- checkout draft heading
- product snapshot
- quantity `1`
- unit price and draft total
- currency
- draft status
- saved address options
- final confirmation disabled copy

## F. Snapshot verification result

Read-only development Supabase verification confirmed the tested draft row:

- belongs to the signed-in customer
- profile role is `customer`
- profile status is `active`
- product snapshot exists
- image snapshot exists
- price snapshot is server-calculated at `GHS 102.77`
- line total is `GHS 102.77`
- quantity is `1`
- attached address belongs to the same customer
- final status after QA is `abandoned`

Full private identifiers are intentionally omitted from this report.

## G. Address list result

`/customer/addresses` loaded for the signed-in customer. One fake/dev-only active saved delivery address was available and used for checkout draft QA.

## H. Address attachment result

The draft address form called `update_checkout_draft_contact_address`; after submission the draft returned with address snapshot data and `review_pending` status before abandonment. Read-only verification confirmed the selected delivery address belonged to the same signed-in customer.

## I. Disabled final confirmation result

The final CTA remained disabled and read `Order confirmation coming next`. It had `type="button"`, no form action, and did not say `Place Order`, `Pay Now`, or `Confirm Purchase`.

## J. Abandon result

Clicking `Abandon draft` called `abandon_checkout_draft`. The page returned with `Checkout draft abandoned.` and read-only Supabase verification confirmed draft status `abandoned`.

## K. Abandoned-draft protection result

After abandonment, the normal UI showed the draft as abandoned. Attach address and abandon controls were disabled, final confirmation stayed unavailable, and no raw database error or information leak appeared.

## L. Database side-effect verification

Read-only checks for rows created since the tested draft creation returned zero rows in:

- `orders`
- `order_items`
- `stock_reservations`
- `delivery_quotes`
- `commissions`
- `settlements`
- `withdrawals`

`payments` is not present as a public table in this development schema. No order/payment/delivery state was created or mutated because no order exists.

## M. Non-customer protection evidence

Browser role switching was not repeated during this customer QA pass. Existing route-policy tests and RPC boundary tests verify customer-only draft access, cross-customer draft/address ownership checks, and no service-role bypass. Source inspection confirms only the approved draft RPCs are called.

## N. Console/network findings

Findings:

- EXPECTED: Clerk development-key warnings.
- EXPECTED/IMPORTANT during active dev edits only: transient Fast Refresh, missing chunk, and Clerk Server Component render errors appeared before the clean dev-server restart.
- After the clean restart and live customer QA, no blocking runtime error, raw RPC error, order/payment/delivery request, or redirect loop was reproduced.

## O. Targeted fixes made

Minimal draft-only fixes were applied after real QA defects were reproduced:

- moved redirect calls outside broad `try/catch` blocks for start, attach, and abandon server actions so Next redirect control flow is not swallowed
- added direct form actions for address attach and abandon with safe redirect result messages
- split draft attach/abandon forms into a dedicated server component so Next server-action wiring renders reliably
- removed one unused import found by lint

No migration, RPC, RLS, service role, order, stock, payment, delivery, commission, settlement, withdrawal, or refund code was added.

## P. Automated verification result

Focused verification after the latest fix:

- `npm test -- tests/checkout-draft-ui.test.tsx` - passed, 7 tests
- `npm run lint` - passed
- `npm run typecheck` - passed

Full verification:

- `git diff --check` - passed with CRLF normalization warnings only
- `npm test` - passed, 30 files and 158 tests
- `npm run lint` - passed
- `npm run build` - passed; `/checkout/draft/[draftId]` appears in the Next route list
- `npm run typecheck` - passed
- `npx tsc --noEmit` - passed

## Q. Runtime HTTP result

The local dev server was restarted on port 400 after quarantining ignored `.next` runtime cache before QA and again after `npm run build`. Startup succeeded.

Final HTTP checks:

- `/` - 200
- `/sign-in` - 200
- `/sign-up` - 200
- valid public shop - 200
- valid public product - 200
- unsigned `/checkout/draft/[draftId]` - protected/non-public 404 response, not public content

The post-build dev error log contained a Clerk deprecation warning for `createRouteMatcher` and a webpack cache performance warning only. No blocking runtime, missing chunk, CSS, or RSC manifest error was present in the final smoke check.

## R. Security/scope scan result

Passed with documented benign hits:

- `.env.local` ignored and not staged
- `.local-recovery` ignored and not staged
- `.next` ignored and not staged
- `supabase/.temp` ignored and not staged
- dev-server logs ignored and not staged
- no staged files
- no active migration/RPC/RLS diff
- no service-role imports in `app/` or `components/`
- no real Clerk/Supabase/service-role values found in changed source/report paths
- no bearer tokens, passwords, API secrets, JWTs, cookies, or production data found in changed source/report paths
- literal `SUPABASE_SERVICE_ROLE_KEY` appears only in a negative test assertion
- deferred order/stock/payment/delivery/commission/settlement/withdrawal terms appear only in report text and negative test assertions

## S. Files changed

Task files changed:

- `app/checkout/draft/actions.ts`
- `app/checkout/draft/[draftId]/page.tsx`
- `app/shop/[shopSlug]/product/[productId]/page.tsx`
- `components/customer/checkout-draft-action-forms.tsx`
- `components/customer/checkout-draft-rpc-screens.tsx`
- `components/customer/checkout-draft-start-form.tsx`
- `components/customer/public-shop-rpc-screens.tsx`
- `lib/auth/role-policy.ts`
- `lib/checkout/draft.ts`
- `middleware.ts`
- `tests/checkout-draft-ui.test.tsx`
- `docs/RISELLAR_CHECKOUT_PHASE_B_DRAFT_UI_REINTRODUCTION_REPORT.md`

Pre-existing metadata/no-content-diff entries may still appear locally and were not treated as this task's source changes.

## T. Current Git status

Working tree remains uncommitted as requested.

Current changed/new task files:

- modified `app/shop/[shopSlug]/product/[productId]/page.tsx`
- modified `components/customer/public-shop-rpc-screens.tsx`
- modified `lib/auth/role-policy.ts`
- modified `middleware.ts`
- untracked `app/checkout/draft/`
- untracked `components/customer/checkout-draft-action-forms.tsx`
- untracked `components/customer/checkout-draft-rpc-screens.tsx`
- untracked `components/customer/checkout-draft-start-form.tsx`
- untracked `docs/RISELLAR_CHECKOUT_PHASE_B_DRAFT_UI_REINTRODUCTION_REPORT.md`
- untracked `lib/checkout/`
- untracked `tests/checkout-draft-ui.test.tsx`

Pre-existing metadata/no-content-diff entries remain visible:

- `app/supplier/orders/[id]/page.tsx`
- `app/supplier/orders/page.tsx`
- `next-env.d.ts`
- `package-lock.json`
- `package.json`
- `tsconfig.json`

## U. Whether live customer QA passed

Live signed-in customer QA passed for draft creation, review, address attachment, disabled final confirmation, abandonment, and read-only side-effect verification.

## V. Whether the draft-only UI is complete

The draft-only UI is complete for this phase. It creates and reviews drafts only; it does not place orders, reserve stock, collect payment, or arrange delivery.

## W. Whether changes are safe to commit

Yes. Full verification and secret/scope scan passed, and the implementation stayed draft-only.

## X. What remains deferred

Still deferred:

- final order confirmation
- order creation
- order item creation
- stock reservation or mutation
- delivery quotes or tracking
- payment
- supplier preparation
- commissions
- settlements
- withdrawals
- refunds

## Y. Exact recommended next step

After final verification passes, commit the Checkout Phase B Group 3 draft-only UI integration and live customer QA report. Then plan the next checkout backend phase separately before any order, stock, payment, or delivery work begins.
