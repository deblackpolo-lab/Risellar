# Risellar Supplier Order Phase 1 Planning Report

## A. Executive Summary

Supplier Order Phase 1 planning is complete. The recommended MVP is supplier-safe read plus accept/reject only. Supplier preparation, delivery, payment collection, settlement, commission release, withdrawals, refunds, customer cancellation, and admin order transitions remain deferred.

## B. Baseline Commit and Branch

- Baseline commit: `20ecabeec8a435dbe54a83dafb478d42e325c0ef`
- Branch: `main`
- Staged files at precheck: none
- Pre-existing visible modified entries were metadata/no-content-diff items.

## C. Existing Order-State Findings

Current `public.order_status` values are `draft`, `placed_pending_confirmation`, `customer_confirmed`, `delivery_quote_pending`, `delivery_quote_ready`, `delivery_quote_approved`, `supplier_preparing`, `ready_for_pickup_or_dispatch`, `out_for_delivery`, `delivered_payment_pending`, `payment_collected`, `settlement_due`, `completed`, `cancelled`, `customer_refused`, `failed`, and `disputed`.

`supplier_confirmed`, `supplier_rejected`, and order-level `expired` do not exist today. `reservation_status` includes `pending`, `reserved`, `committed`, `released`, `expired`, and `failed`.

## D. Minimum Supplier-State Decision

Recommended Phase 1 transitions:

- `placed_pending_confirmation -> supplier_confirmed`
- `placed_pending_confirmation -> supplier_rejected`

This requires a future forward enum extension or another approved decision field. Do not use `supplier_preparing` as acceptance in this phase.

## E. Supplier-Safe Read Contract

Supplier reads must be scoped to the supplier resolved from the signed-in profile and `order_items.supplier_id`. The read should expose only order number/status, supplier-owned product snapshot, quantity, supplier expected amount, safe customer fulfilment snapshot, Pay on Delivery labels, reservation status, and timestamps.

## F. Supplier Order-List Contract

Planned RPC: `list_supplier_orders_safe(p_status text default null, p_limit integer default 50, p_cursor timestamptz default null)`.

It must require an active supplier actor, return only own supplier orders, paginate safely, filter statuses from an allowlist, and avoid mutations.

## G. Supplier Order-Detail Contract

Planned RPC: `get_supplier_order_safe(p_order_id uuid)`.

It must return no rows for unauthorized or missing orders and expose only the supplier-owned fulfilment slice.

## H. Accept RPC Contract

Planned RPC: `supplier_accept_order(p_order_id uuid, p_idempotency_key text default null)`.

It must lock the order, validate supplier ownership and active reservation, move to `supplier_confirmed`, preserve the reservation, write audit events, and return a safe summary.

## I. Reject RPC Contract

Planned RPC: `supplier_reject_order(p_order_id uuid, p_reason_code text, p_reason_note text default null, p_idempotency_key text default null)`.

It must lock order, reservation, and variant; validate ownership and status; move to `supplier_rejected`; release the reservation; decrement reserved stock once; write inventory/audit events; and return a safe summary.

## J. Rejection Reasons

Recommended reason codes: `out_of_stock`, `product_unavailable`, `unable_to_fulfil`, `incorrect_listing`, `supplier_temporarily_closed`, and `other`.

Customer-safe wording should avoid blame: `The supplier could not fulfil this order. No payment was collected.`

## K. Stock-Release Design

Reject releases only active `reserved` reservations, decrements `reserved_stock_quantity` once, preserves total and sold stock, records a movement, and prevents negative reserved stock.

## L. Reservation-Expiry Behavior

Phase 1 should reject accept attempts after reservation expiry with `RESERVATION_EXPIRED`. Do not reacquire stock automatically in this phase.

## M. Customer Status Updates

Customer-safe order read will need labels for the new supplier decision states. Accepted should show supplier confirmed, payment not collected, and delivery not arranged. Rejected should show supplier could not fulfil, no payment collected, and stock reservation released.

## N. Supplier UI Plan

Future routes:

- `/supplier/orders`
- `/supplier/orders/[orderId]`

UI should show New, Confirmed, and Rejected sections, plus Accept and Reject actions. Preparation, delivery, payment, settlement, commission, and withdrawal controls must stay absent or disabled.

## O. Idempotency

Use stable order-level keys such as `supplier-accept:{orderId}` and `supplier-reject:{orderId}`. Backend status and reservation state remain the source of truth.

## P. Error Mapping

Safe UI errors are planned for auth required, supplier required, unavailable order, not actionable order, missing/expired reservation, already confirmed, already rejected, invalid reason, stock release failure, and unknown failure. Raw SQL errors must not reach the browser.

## Q. Audit Events

Required events include supplier order accepted/rejected, stock reservation released, reserved stock decremented, duplicate action reused, and invalid transition blocked. Read auditing is optional.

## R. Security/RLS

No broad direct table writes. Supplier reads/writes must run through safe RPCs with server-side supplier resolution. No service-role imports in app/components. No customer, reseller, admin, or anonymous caller may use supplier decision RPCs.

## S. Test Plan

Future SQL tests should cover own-order reads, cross-supplier blocks, role blocks, sensitive-field absence, accept, reject, duplicate actions, stock-release idempotency, expired reservation behavior, and side-effect absence.

## T. Concurrency Plan

Run true two-session tests for accept versus reject, duplicate reject, repeated accept, and rejection versus future expiry release. Expected result is one terminal decision and valid stock counters.

## U. Implementation Groups

S1 planning, S2 read RPC dry-run, S3 read apply/test, S4 decision RPC dry-run, S5 decision apply/test/concurrency, S6 supplier UI, S7 browser QA, S8 commit/push.

## V. Risks

Top risks are cross-supplier order exposure, customer/private reseller data leakage, double stock release, accept/reject races, expired reservation acceptance, commercial snapshot mutation, payment collection bypass, and audit gaps.

## W. Documents Created

- `docs/RISELLAR_SUPPLIER_ORDER_PHASE_1_PLAN.md`
- `docs/RISELLAR_SUPPLIER_ORDER_SAFE_READ_MODEL_PLAN.md`
- `docs/RISELLAR_SUPPLIER_ORDER_ACCEPT_REJECT_STATE_MACHINE.md`
- `docs/RISELLAR_SUPPLIER_ORDER_STOCK_RELEASE_DESIGN.md`
- `docs/RISELLAR_SUPPLIER_ORDER_SECURITY_AND_RLS_PLAN.md`
- `docs/RISELLAR_SUPPLIER_ORDER_TEST_AND_QA_PLAN.md`
- `docs/RISELLAR_SUPPLIER_ORDER_IMPLEMENTATION_GROUPS.md`
- `docs/RISELLAR_SUPPLIER_ORDER_RISK_REGISTER.md`
- `docs/RISELLAR_SUPPLIER_ORDER_PHASE_1_PLANNING_REPORT.md`

## X. Commands/Results

- `git status --short`: showed the nine new supplier-order planning docs plus pre-existing metadata/no-content-diff entries in supplier order placeholder pages, `next-env.d.ts`, package files, and `tsconfig.json`; nothing staged.
- `git rev-parse HEAD`: `20ecabeec8a435dbe54a83dafb478d42e325c0ef`.
- `git branch --show-current`: `main`.
- `git diff --name-status`: no output.
- `git diff --numstat`: no output.
- `git diff --summary`: no output.
- `git diff --check`: passed.
- `npm test`: passed, 32 test files and 171 tests.
- `npm run lint`: passed.
- `npm run build`: passed, 168 app routes generated.
- `npm run typecheck`: passed.
- `npx tsc --noEmit`: passed.

## Y. Security/Scope Scan

- `.env.local`: ignored and not staged.
- `.local-recovery`: ignored and not staged.
- `.next`: ignored and not staged.
- `supabase/.temp`: ignored and not staged.
- `.codex-dev-server.*.log`: ignored and not staged.
- New supplier-order planning docs contain no UUID row identifiers, project identifiers, credentials, tokens, database passwords, connection strings, or environment values.
- New supplier-order planning docs mention service-role only as a prohibition.
- App/components scan found no service-role imports.
- No application source, migration, RPC script, or test implementation diff was introduced by this planning phase.
- No supplier order UI, supplier preparation, delivery, payment, settlement, commission, withdrawal, refund, or admin order transition implementation was added.
- No production Supabase project was accessed.

## Z. Files Changed

Planning docs only:

- `docs/RISELLAR_SUPPLIER_ORDER_PHASE_1_PLAN.md`
- `docs/RISELLAR_SUPPLIER_ORDER_SAFE_READ_MODEL_PLAN.md`
- `docs/RISELLAR_SUPPLIER_ORDER_ACCEPT_REJECT_STATE_MACHINE.md`
- `docs/RISELLAR_SUPPLIER_ORDER_STOCK_RELEASE_DESIGN.md`
- `docs/RISELLAR_SUPPLIER_ORDER_SECURITY_AND_RLS_PLAN.md`
- `docs/RISELLAR_SUPPLIER_ORDER_TEST_AND_QA_PLAN.md`
- `docs/RISELLAR_SUPPLIER_ORDER_IMPLEMENTATION_GROUPS.md`
- `docs/RISELLAR_SUPPLIER_ORDER_RISK_REGISTER.md`
- `docs/RISELLAR_SUPPLIER_ORDER_PHASE_1_PLANNING_REPORT.md`

## AA. Current Git Status

Working tree contains only the nine new supplier-order planning docs plus the pre-existing metadata/no-content-diff visible entries. Nothing is staged.

## AB. Whether Supplier Phase 1 Planning Is Complete

Complete.

## AC. Whether It Is Safe To Begin S2

Yes, after explicit user approval. S2 should create only the supplier-safe order read RPC migration and development-only boundary test harness, with dry-run only.

## AD. Exact Recommended Next Prompt

Approve Supplier Order Handling S2: create the supplier-safe order read RPC migration and development-only boundary test harness, run dry-run only, do not apply migrations, do not connect supplier order UI, and do not touch production.
