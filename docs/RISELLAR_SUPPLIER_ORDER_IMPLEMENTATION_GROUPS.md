# Risellar Supplier Order Implementation Groups

## S1 - Planning Only

Scope:

- create supplier order planning docs only
- no migrations, RPCs, source, tests, commits, or pushes

Gate:

- docs validate with full test/lint/build/typecheck
- no application source changed

Stop conditions:

- schema mismatch needs product decision
- current dirty workspace contains meaningful source changes

## S2 - Supplier-Safe Read RPC Foundation

Scope:

- create forward migration for `list_supplier_orders_safe` and `get_supplier_order_safe`
- create development-only safe-read boundary test script
- dry-run only

Expected files:

- one migration
- one SQL test script
- read-foundation report

Gate:

- `npx supabase db push --dry-run` shows only intended migration
- tests/build pass
- no UI connected

## S3 - Apply Supplier-Safe Read in Development

Scope:

- apply S2 migration to confirmed development project only
- run supplier safe-read boundary tests
- document result

Stop conditions:

- db push fails
- SQL assertion fails
- real security gap appears

Commit boundary:

- commit only reports after passing or approved harness fix

## S4 - Accept/Reject RPC Foundation

Scope:

- create forward migration for enum extension if approved
- create accept/reject RPCs
- create decision boundary test script
- dry-run only

Migration impact:

- add `supplier_confirmed` and `supplier_rejected` status values, or a separately approved decision field
- add optional safe rejection reason storage if schema lacks a place

Gate:

- dry-run passes
- test harness includes idempotency, stock release, authorization, and concurrency plans
- no UI connected

## S5 - Apply Decision RPCs in Development

Scope:

- apply decision migration to confirmed development project only
- run boundary and concurrency tests
- document pass/failure

Stop conditions:

- stock release can double-decrement
- supplier can affect another supplier's order
- payment/delivery/finance side effects appear

## S6 - Supplier Order UI

Scope:

- connect `/supplier/orders` and `/supplier/orders/[orderId]` to safe read RPCs
- add accept/reject server actions
- keep preparation/delivery/payment/finance controls disabled
- automated tests only

Expected files:

- supplier order actions/helper
- supplier order screens/routes
- tests
- UI integration report

Browser gate:

- not live until S5 is proven in development

## S7 - Live Browser QA

Scope:

- use development supplier account
- verify read, accept, reject, customer status update, stock release, and blocked roles
- no production data

Required verification:

- one accept path
- one reject path
- duplicate action behavior
- audit logs
- no payment/delivery/preparation/finance rows

## S8 - Commit and Push

Scope:

- commit only explicitly requested files
- push to `origin main`

Gate:

- full validation passes
- secret/scope scan passes
- reports document safe development-only behavior
