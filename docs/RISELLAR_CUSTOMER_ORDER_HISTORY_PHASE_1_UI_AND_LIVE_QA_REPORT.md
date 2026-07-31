# Risellar Customer Order History Phase 1 UI And Live QA Report

## A. Summary

Customer Order History Phase 1 connects `/customer/orders` to the new customer-safe read RPCs. The page is read-only and shows customer order history, summary counts, filters, safe prices/status labels, and links to the existing safe order detail page.

No checkout submission, order mutation, cancellation, refund, dispute, return, payment collection, stock mutation, delivery mutation, commission, settlement, withdrawal, or customer purchase action was added.

## B. Routes Connected

- `/customer/orders`
- Existing `/customer/orders/[id]` remains connected to `get_customer_order_safe`.

No customer dashboard route was updated because there is no dedicated `/customer/dashboard` route in the current app tree.

## C. Server Helpers/UI Created

- `lib/orders/customer-order-history.ts`
  - validates filters
  - maps `list_customer_orders_safe`
  - maps `get_customer_order_summary_safe`
  - normalizes safe RPC errors

- `components/customer/customer-order-history-rpc-screen.tsx`
  - renders summary counts
  - renders active/completed/rejected filters
  - renders search form
  - renders read-only order cards and detail links
  - shows an explicit read-only/no-live-action notice

## D. List/Summary Behavior

Browser QA confirmed:

- customer session was authenticated
- profile status was active
- primary role was customer
- `/customer/orders` loaded
- order summary rendered
- order cards or safe empty state rendered
- Pay on Delivery labels rendered
- detail link rendered without printing database identifiers in this report
- `group=active`, `group=completed`, and `group=rejected` routes loaded
- empty search state loaded safely

## E. Detail Behavior

Browser QA confirmed the existing detail page loaded from a customer order-history detail link and showed:

- customer order header
- product block
- Pay on Delivery status block
- customer-safe progress/status text
- no online payment notice

## F. Sensitive Fields Hidden

Browser checks found none of these terms visible in the customer list/detail surfaces:

- supplier base price
- platform margin
- reseller margin
- commission amount
- settlement due
- risk score
- admin notes
- payment provider reference

Boundary tests also verified internal ID and private commercial fields are absent from the list RPC return shape.

## G. Filter/Search/Pagination QA

Verified in browser:

- `all` order list page loaded
- `active` filter route loaded
- `completed` filter route loaded
- `rejected` filter route loaded
- safe empty search state loaded

Cursor pagination was verified at helper/RPC boundary level. The current development customer session did not have enough visible live rows to exercise a next-page click-through in browser.

## H. Cross-Role/Cross-Customer Protection

Verified by RPC boundary tests and route-policy tests:

- customer can list own orders
- customer cannot list another customer order
- reseller is blocked
- supplier_owner is blocked
- active admin_staff is blocked from the customer boundary
- anonymous access is blocked

Cookie-less shell probes to protected customer routes returned Clerk-protected 404 behavior; signed-in browser QA verified the page works for the customer session.

## I. Mutation Safety

The feature is read-only. It did not create or connect:

- order creation
- order item mutation
- stock reservation mutation
- delivery quote mutation
- payment collection
- delivery arrangement mutation
- commission release
- settlement verification
- withdrawal
- refund
- cancellation
- return/dispute flows

The SQL boundary test confirmed no extra order/order item/stock reservation/delivery quote/commission/settlement/withdrawal side effects occurred from read calls beyond the temporary fixture rows that were rolled back.

## J. Commands Run/Results

- `git status --short`: intentional Customer Order History changes plus existing recurring metadata-only modified files.
- `git diff --check`: passed.
- `npx supabase db push --dry-run --include-all`: passed; only the new migration was listed.
- `npx supabase db push --include-all`: passed against the confirmed development project.
- `npx supabase db query --linked --file scripts/rpc/customer-order-history-safe-read-rpc-tests-dev-only.sql`: passed with active assertions.
- `npm test -- customer-order-history-safe-read.test.ts`: passed.
- `npm test`: passed, 45 files and 260 tests.
- `npm run lint`: passed.
- `npm run build`: passed.
- `npm run typecheck`: passed when run sequentially after build.
- `npx tsc --noEmit`: passed when run sequentially after build.

## K. Secret/Scope Scan Result

- `.env.local` is ignored and not staged.
- `supabase/.temp` is ignored.
- `.next` is ignored.
- `.codex-dev-server.*.log` is ignored.
- Changed files contain no real Clerk/Supabase/service-role values, bearer tokens, passwords, API secrets, JWTs, cookies, project identifiers, private database identifiers, or production data.
- No service role is imported into app/components.
- No checkout/order/stock/payment/delivery mutation UI integration was added.

## L. Runtime Notes

The local dev server on port 400 was restarted after a stale route manifest returned protected-route 404s from cookie-less shell probes. Signed-in in-app browser QA succeeded after the server was refreshed.

## M. Current Git Status

Intentional Customer Order History files are modified/untracked. Existing recurring metadata-only files remain modified and should not be staged.

## N. Whether Safe To Commit

Safe to commit after final verification and exact-path staging remain clean.
