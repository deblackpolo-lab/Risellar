# Risellar Disputes, Returns, and Refunds Phase 1 Planning Report

## A. Executive Summary

Created a planning-only architecture pack for disputes, returns, refunds, evidence, finance holds, role privacy, tests, QA, implementation groups, risks, and required business decisions. No migrations, RPCs, RLS, app source, UI, stock movement, payment movement, settlement changes, commission changes, withdrawals, provider integrations, commits, or pushes were performed.

## B. Baseline Commit And Branch

- Branch: `main`
- Baseline commit observed before docs work: `3a44db59879e76ebdb8bcb2204a70ca1fc4394cd`
- Pre-existing metadata-only entries: `next-env.d.ts`, `tsconfig.json`

## C. Existing Dispute/Refund Artifact Audit

- Approved/reusable concepts: business rules for support/disputes/returns/refunds, finance hold vocabulary through existing commission/settlement statuses, stock movement vocabulary for `return_restock`, `damage`, and `correction`.
- Dormant but compatible: planned `support_tickets`, `disputes`, `returns`, `refunds` concepts in schema docs.
- Incomplete: Phase 13 support/dispute/return/refund routes and components are frontend mock-only.
- Unsafe to activate directly: any mock resolution, evidence upload placeholder, refund status, return request, or admin dispute control without new audited RPC/RLS.
- Requires later cleanup/review: old placeholder support screens should remain clearly separated from future live dispute implementation.

## D. Dispute Categories

Planned controlled categories cover pre-delivery, delivery, payment, post-completion, accounting, and `other`. See `docs/RISELLAR_DISPUTES_RETURNS_REFUNDS_PHASE_1_PLAN.md`.

## E. Role Permissions

Customers open own order cases, suppliers open/respond to own supplier-order cases, resellers get commission-impact visibility only, support/admin handles investigation, finance_staff handles money actions, and super_admin handles exceptional overrides.

## F. Dispute Windows

Recommended Ghana-MVP defaults are proposed but require approval: 24-hour operational delay triggers, 48-hour wrong/damaged/incomplete window, 72-hour non-delivery window, 3-day return window, and 14-day finance/accounting window.

## G. Dispute State Machine

Designed separate dispute states from `open` through `closed`, including awaiting-party, under-review, return, refund, resolved, rejected, cancelled, and appeal-compatible states.

## H. Order-State Interaction

Prefer separate dispute state over mutating every order to `disputed`. Opening a dispute should not directly change order status.

## I. Payment-State Interaction

Payment status changes only through explicit future finance/refund RPCs. Opening a dispute does not mark payment refunded or disputed.

## J. Settlement Interaction

Active payment/delivery/item-condition disputes can block or flag settlement verification. Verified settlements are not silently reversed.

## K. Commission Interaction

Commission should be held or adjusted non-destructively. Do not delete commission rows.

## L. Withdrawal Interaction

Pending withdrawals may need holds/rejections. Paid withdrawals must not be silently reversed. Missing withdrawal-items allocation is a hard accounting caveat.

## M. Return Workflow

Returns have their own states and methods. Return delivery provider automation remains deferred.

## N. Returned-Stock Model

No automatic restock. Only authorised inspection can create a stock outcome.

## O. Refund Types

Full, partial, delivery-fee-only, item-value-only, goodwill credit, and no-refund outcomes are planned.

## P. Refund Responsibility

Responsibility codes include supplier, customer, delivery partner, platform, reseller, shared, and no financial adjustment.

## Q. Refund Accounting

Refund maximums derive from immutable order snapshots. Browser/admin input cannot be authoritative for max amount, currency, margin, commission, or settlement impact.

## R. Finance Holds

Planned `finance_holds` concept supports settlement holds, commission holds, pending-withdrawal holds, platform goodwill holds, and paid-withdrawal recovery without destructive ledger changes.

## S. Evidence Model

Private storage, signed URLs, role-scoped access, file allowlists, size limits, audit, and retention are required. Text-only first implementation is acceptable if storage scope is split out.

## T. Admin Workflow

Admin/support queues should support triage, filters, safe order timeline, evidence, responses, return/refund state, audit history, and explicit RPC actions. No arbitrary set-any-status control.

## U. Customer Workflow

Customer opens a problem from own order detail, selects reason, adds description, views timeline, responds, and sees return/refund outcome with safe labels.

## V. Supplier Workflow

Supplier sees own disputes, responds, confirms returns, reports condition, and reports refund sent when assigned. Supplier cannot final-resolve its own case.

## W. Reseller Visibility

Reseller gets commission-impact visibility only: safe order reference, hold/adjustment status, and final commission effect.

## X. Appeals

Appeals are planned but recommended for Phase 2 unless business requires them in MVP.

## Y. RPC Boundaries

Planned narrow customer, supplier, reseller, admin, finance, and inventory RPCs. No all-powerful update RPC.

## Z. Idempotency

Every mutation action requires stable idempotency keys and no duplicate disputes, responses, refund obligations, holds, wallet adjustments, stock movements, audits, or notifications.

## AA. Audit Events

Planned audit events cover dispute, return, refund, finance hold, commission adjustment, liability, wallet, stock, resolution, close, and appeal events.

## AB. Notification Plan

Future transactional email events should use existing outbox patterns and safe payloads. No notification implementation was added.

## AC. Test Plan

SQL boundary tests cover ownership, roles, reason/window validation, safe fields, refund max, holds, withdrawals, stock inspection, idempotency, and fixture cleanup.

## AD. Concurrency Plan

Concurrency tests cover duplicate open, resolution versus response, refund versus settlement, hold versus withdrawal, adjustment versus payout, restock versus sale, and competing admin resolutions.

## AE. Browser QA Plan

Future browser QA covers customer, supplier, admin/support, finance admin, and reseller commission-impact flows with privacy and side-effect checks.

## AF. Implementation Groups

D1-D13 are defined in `docs/RISELLAR_DISPUTE_IMPLEMENTATION_GROUPS.md`.

## AG. Risk Register

Risk register created with likelihood, impact, prevention, detection, and recovery.

## AH. User Decisions Required

Decision list created with recommended Ghana-MVP defaults.

## AI. Recommended Ghana-MVP Defaults

Use short dispute windows, manual supplier refunds with proof, admin verification for every refund, text-only initial disputes if storage is too large, no silent paid-withdrawal reversal, and separate dispute state from order state.

## AJ. Documents Created

- `docs/RISELLAR_DISPUTES_RETURNS_REFUNDS_PHASE_1_PLAN.md`
- `docs/RISELLAR_DISPUTE_STATE_MACHINE.md`
- `docs/RISELLAR_RETURN_AND_INVENTORY_MODEL_PLAN.md`
- `docs/RISELLAR_REFUND_ACCOUNTING_AND_FINANCE_PLAN.md`
- `docs/RISELLAR_DISPUTE_SECURITY_AND_RLS_PLAN.md`
- `docs/RISELLAR_DISPUTE_ROLE_AND_PRIVACY_MATRIX.md`
- `docs/RISELLAR_DISPUTE_TEST_AND_QA_PLAN.md`
- `docs/RISELLAR_DISPUTE_IMPLEMENTATION_GROUPS.md`
- `docs/RISELLAR_DISPUTE_RISK_REGISTER.md`
- `docs/RISELLAR_DISPUTE_BUSINESS_DECISIONS_REQUIRED.md`
- `docs/RISELLAR_DISPUTES_RETURNS_REFUNDS_PHASE_1_PLANNING_REPORT.md`

## AK. Commands And Results

- `git status --short`: passed; only recurring metadata entries plus the new planning docs are present.
- `git diff --check`: passed with no whitespace errors.
- `npm test`: passed, 48 files and 289 tests.
- `npm run lint`: passed.
- `npm run build`: passed, Next.js compiled successfully and generated 174 static pages.
- `npm run typecheck`: passed.
- `npx tsc --noEmit`: passed.

## AL. Security/Scope Scan

- `.env.local`: ignored and not staged.
- `.next`: ignored and not staged.
- `.local-recovery`: ignored and not staged.
- `supabase/.temp`: ignored and not staged.
- No staged files.
- No app, component, lib, migration, script, or test source diffs.
- No secret/private-ID pattern matches in the created docs.
- No service-role references found in `app/` or `components/`.
- No migration, RPC, RLS, UI, refund/payment/stock/finance mutation, provider integration, production access, commit, or push was performed.

## AM. Files Changed

Docs only:

- `docs/RISELLAR_DISPUTES_RETURNS_REFUNDS_PHASE_1_PLAN.md`
- `docs/RISELLAR_DISPUTE_STATE_MACHINE.md`
- `docs/RISELLAR_RETURN_AND_INVENTORY_MODEL_PLAN.md`
- `docs/RISELLAR_REFUND_ACCOUNTING_AND_FINANCE_PLAN.md`
- `docs/RISELLAR_DISPUTE_SECURITY_AND_RLS_PLAN.md`
- `docs/RISELLAR_DISPUTE_ROLE_AND_PRIVACY_MATRIX.md`
- `docs/RISELLAR_DISPUTE_TEST_AND_QA_PLAN.md`
- `docs/RISELLAR_DISPUTE_IMPLEMENTATION_GROUPS.md`
- `docs/RISELLAR_DISPUTE_RISK_REGISTER.md`
- `docs/RISELLAR_DISPUTE_BUSINESS_DECISIONS_REQUIRED.md`
- `docs/RISELLAR_DISPUTES_RETURNS_REFUNDS_PHASE_1_PLANNING_REPORT.md`

## AN. Current Git Status

- `M next-env.d.ts`
- `M tsconfig.json`
- Untracked dispute/return/refund Phase 1 planning docs listed above.
- Nothing staged.

## AO. Whether Planning Is Complete

Planning is complete for Phase 1.

## AP. D2/D3 Follow-Up Status

After this planning pack, D2 and D3 were completed in the confirmed DEVELOPMENT Supabase project.

- D1/D2 local checkpoint commit: `738384757bcdf7e32c787fa875d4861daefcc791`
- D2 migration applied to DEVELOPMENT: `20260801120000_dispute_core_schema_and_safe_reads.sql`
- D3 forward fix applied to DEVELOPMENT: `20260801123000_fix_dispute_status_history_idempotency.sql`
- D3 SQL safe-read boundary assertions: 51 passed, 0 failed.
- Fixture cleanup left zero permanent rows in `order_disputes`, `dispute_messages`, and `dispute_status_history`.
- No dispute mutation RPC, customer dispute UI, supplier dispute UI, admin resolution action, return, refund, finance hold, stock, order, payment, settlement, commission, wallet, withdrawal, evidence, notification, or provider flow was activated.

## AQ. D4 Customer Backend Follow-Up Status

D4 customer open/respond backend is complete in the confirmed DEVELOPMENT Supabase project.

- D4 migration applied to DEVELOPMENT: `20260801130000_customer_dispute_open_and_response_rpcs.sql`
- D4 RPCs: `customer_open_order_dispute`, `customer_add_dispute_response`
- D4 SQL boundary assertions: 51 passed, 0 failed.
- D4 true-concurrency probes passed for same-key open, active-fingerprint open, and same-key response.
- Fixture cleanup left zero matching D4 concurrency fixture profiles, orders, and disputes.
- No dispute UI, supplier mutation, admin mutation, return, refund, finance hold, stock mutation, order mutation, payment mutation, settlement mutation, commission mutation, wallet mutation, withdrawal mutation, evidence upload, or notification flow was activated.

## AR. Whether Implementation May Begin

The next implementation group may begin only after explicit request.

## AS. Exact Recommended Next Prompt

Next: "Start Disputes D5 supplier dispute view/respond backend. Do not implement admin resolution, returns, refunds, finance holds, stock changes, or notifications."

## D5-A Addendum

D5-A updates the plan before supplier response. `customer_open_order_dispute` now uses the target-aware seven-argument contract with optional `p_order_item_id`. The old ambiguous browser-callable signature is revoked. Supplier response may resume after D5-A because the affected supplier/order-item target is now explicit and immutable.
