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

## AC. D10 Completion Update

D10 was implemented and verified in DEVELOPMENT as backend-only reseller liability and withdrawal recovery controls. It adds explicit liability/recovery records, finance-controlled future-earnings offsets, idempotent recovery behavior, and concurrency-safe withdrawal allocation boundaries.

No paid withdrawal was silently reversed, no historical allocation was guessed, and no provider collection, payment, refund, delivery, stock, order, settlement payout, commission payout, withdrawal payout, notification send, UI, or production behavior was added.

The final D10 regression batch passed after stabilizing development-only fixture and concurrency harness issues. The batch covered D6, D7, D8, D9, D10, settlement verification, reseller withdrawal, and finance-history regressions.

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

## AT. D12 Verification Follow-Up Status

D12 verified the completed D1-D11 backend stack in the confirmed DEVELOPMENT project. SQL regressions and D6-D11 external concurrency runners passed after a development-only D3 safe-read test-harness repair for target-aware dispute fixtures and fixture-scoped support-list assertions.

No production Supabase connection, destructive reset, blind migration repair, RLS/RPC weakening, service-role UI exposure, or real recipient email mode was used.

D12 release readiness is blocked for full browser/MVP activation because:

- No active support/dispute-admin QA browser account was available.
- No active super-admin QA browser account was available.
- Production `https://risellar.vercel.app` still displays the Phase 1 design-shell message.
- Several D12 dispute/return/refund/support UI routes remain preserved mock-only Phase 13 screens.

Updated release classification: **B. Backend and partial UI complete, more UI required.**

Recommended next prompt: "Start D13 live dispute/return/refund/support UI activation using the verified D1-D12 backend, first creating real DEVELOPMENT support and super-admin QA identities. Do not activate mock-only routes as live workflows."

## D5-A Addendum

D5-A updates the plan before supplier response. `customer_open_order_dispute` now uses the target-aware seven-argument contract with optional `p_order_item_id`. The old ambiguous browser-callable signature is revoked. Supplier response may resume after D5-A because the affected supplier/order-item target is now explicit and immutable.

## D5 Supplier Response Addendum

D5 supplier response backend is complete in the confirmed DEVELOPMENT Supabase project.

- D5 migration applied to DEVELOPMENT: `20260801150000_supplier_dispute_response_rpc.sql`
- D5 RPC: `supplier_add_dispute_response`
- D5 SQL boundary assertions: 67 passed, 0 failed
- D5 true-concurrency assertions: 9 passed, 0 failed
- Supplier authorization uses D5-A `affected_supplier_id` and `affected_order_item_id`
- Multi-supplier order-wide disputes remain blocked from broad supplier response
- Supplier messages use `supplier_and_admin` visibility
- Customer and reseller safe reads do not expose supplier-private response bodies
- Fixture cleanup left zero matching D5 concurrency rows
- No dispute UI, admin mutation, return, refund, finance hold, stock mutation, order mutation, payment mutation, settlement mutation, commission mutation, wallet mutation, withdrawal mutation, evidence upload, or notification flow was activated

D6 admin/support investigation and non-financial resolution has been implemented as a backend-only foundation on DEVELOPMENT. It adds controlled support/admin RPCs and a narrow idempotency action table, with no UI activation and no return/refund/finance/stock/order/payment/notification side effects.

D6 also passed the final external two-session concurrency hardening pass: 12 race scenarios and 61 invariant checks passed, fixture cleanup completed, and no business side effects were detected.

D7 return workflow backend is complete in the confirmed DEVELOPMENT Supabase project.

- D7 migrations applied to DEVELOPMENT: `20260801170000_return_workflow_backend_foundation.sql`, `20260801171000_fix_return_workflow_status_history_reason.sql`, `20260801172000_fix_return_workflow_idempotency_column_ambiguity.sql`
- D7 SQL boundary test passed with more than 77 assertions
- D7 external concurrency harness passed 11 true two-session races
- Legacy `public.returns` remains dormant
- `public.order_item_returns` records return workflow only
- Inspection inventory outcome is a recommendation marker only
- No refund, payment, finance hold, settlement, commission, wallet, withdrawal, stock, reservation, delivery, evidence, notification, or UI side effect was activated

D8 refund-obligation planning may proceed as a separate backend slice.

## AT. D8 Refund Workflow Backend Follow-Up Status

D8 refund workflow backend is complete in the confirmed DEVELOPMENT Supabase project as a backend-only foundation.

- D8 migrations applied to DEVELOPMENT: `20260801180000_refund_workflow_backend_foundation.sql`, `20260801181000_fix_refund_customer_confirmation_idempotency.sql`, `20260801182000_enforce_refund_cumulative_component_caps.sql`, `20260801183000_scrub_refund_audit_reason_notes.sql`
- D8 tables: `public.order_refunds`, `public.refund_actions`
- D8 SQL boundary test passed 99 rollback-scoped assertions
- D8 external concurrency harness passed 12 true multi-process races plus side-effect and cleanup checks
- Refund amounts are capped from immutable order/order-item snapshots
- Currency is derived from the order
- Goodwill refunds remain deferred
- Finance approval/verification requires active `admin_staff` finance authority
- Supplier sent reporting is scoped to the responsible supplier
- Customer confirmation is owner-scoped and does not verify accounting
- Safe reads hide private notes, raw references, supplier payout data, settlement data, commission data, wallet data, and withdrawal data
- No UI, provider refund, automatic payout, finance hold, settlement mutation, commission mutation, wallet mutation, withdrawal mutation, stock mutation, delivery mutation, order/payment status mutation, evidence upload, or notification event was activated

D9 may begin only after explicit approval for finance holds and accounting interactions.
## D9 Planning Status

D9 finance holds, settlement interaction, and commission hold backend controls were implemented and applied to the confirmed development Supabase project.

Forward fixes were required for audit role casting, reseller hold projection, and withdrawal review race guarding. The final D9 SQL and concurrency checks passed.

No UI was activated, and no production data or production Supabase connection was used.

## D11 Notification Status

D11 adds transactional notification coverage for dispute, return, refund, finance-hold, reseller-liability, and withdrawal-review workflows.

The implementation uses the existing notification outbox, processor, redirect-mode sender, and Resend webhook handling. SQL only enqueues notification outbox rows from trusted audit logs; it does not send provider emails directly and does not mutate business state.

Development verification passed:

- D11 SQL mapping assertions: 50 passed, 0 failed
- D11 concurrency harness: 10 scenarios, 13 invariant checks passed
- existing notification outbox regression passed after fixture scoping was corrected for the expanded event catalog

Live D11 redirect-mode QA is complete on the Vercel Production deployment connected to the confirmed DEVELOPMENT Supabase project.

- D1-D11 commit range pushed to `origin/main`; latest D11 commit: `f8c3aee0`.
- Vercel Production deployment for commit `f8c3aee091523d2d49a6f87fec381fcf47c75ea1` completed successfully.
- Five notification-only D11 QA events were processed for customer, supplier, reseller, support/admin, and finance-admin representative templates.
- Redirect-mode delivery sent all five emails to the configured development inbox only.
- All subjects used the `[DEV]` prefix.
- Real provider-originated `email.sent` and `email.delivered` events were stored for all five provider message IDs.
- Duplicate processor invocation claimed zero rows and sent no duplicates.
- No order, payment, stock, delivery, settlement, commission, wallet, withdrawal, dispute, return, refund, finance-hold, product, reservation, inventory, liability, or allocation business table counts changed during D11 live notification QA.
- No D11 UI was activated.
