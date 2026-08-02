# Risellar Dispute Implementation Groups

## D1 - Planning Documents

Scope: create the dispute/return/refund plan, state machine, security model, accounting model, test plan, risk register, and decision list.

Migrations: none.

RPCs: none.

UI: none.

Stop conditions: any source/migration/RPC/UI change is out of scope.

## D2 - Core Dispute Schema and Safe Reads, Dry-Run Only

Scope: forward migration for dispute cases, messages, minimal text evidence metadata, safe read RPC contracts, audit event taxonomy.

Migration draft: `supabase/migrations/20260801120000_dispute_core_schema_and_safe_reads.sql`.

RPCs: list/get customer, list/get supplier, reseller-impact, and admin safe reads.

Test script draft: `scripts/rpc/dispute-core-schema-safe-reads-tests-dev-only.sql`. It must not be run against development until the migration is approved and applied in D3.

Docs:

- `docs/RISELLAR_DISPUTE_D2_CORE_SCHEMA_DESIGN.md`
- `docs/RISELLAR_DISPUTE_D2_SAFE_READ_RPC_CONTRACTS.md`
- `docs/RISELLAR_DISPUTE_D2_RLS_AND_GRANT_REVIEW.md`
- `docs/RISELLAR_DISPUTE_D2_DRY_RUN_REPORT.md`

Stop conditions: finance, refund, stock, settlement, commission, or withdrawal mutation added.

## D3 - Apply Core Schema and Ownership Tests

Status: completed in DEVELOPMENT after approval.

Scope: apply D2 to development only after approval and run ownership/privacy boundary tests.

Dependencies: D2 dry-run.

Applied migrations:

- `20260801120000_dispute_core_schema_and_safe_reads.sql`
- `20260801123000_fix_dispute_status_history_idempotency.sql`

Verification:

- `scripts/rpc/dispute-core-schema-safe-reads-tests-dev-only.sql` now contains active rollback-scoped assertions.
- 51 SQL assertions passed in DEVELOPMENT.
- Fixtures rolled back and left zero permanent dispute rows.
- No dispute mutation RPCs or UI were activated.

Stop conditions: production link, broad grants, failed ownership test, service role exposure.

## D4 - Customer Open/View/Respond Backend

Status: completed in DEVELOPMENT after approval.

Scope: customer can open and respond to own order disputes using audited backend RPCs only. Customer viewing continues through the D3 safe-read RPCs.

Applied migration:

- `20260801130000_customer_dispute_open_and_response_rpcs.sql`

RPCs:

- `customer_open_order_dispute`
- `customer_add_dispute_response`

Verification:

- `scripts/rpc/customer-dispute-open-response-tests-dev-only.sql` passed 51 rollback-scoped assertions.
- True-concurrency probes verified same-key open, active-fingerprint open, and same-key response behavior.
- Fixture cleanup left zero matching concurrency fixture profiles, orders, and disputes.
- No UI was activated.

Stop conditions preserved: refund action, payment mutation, stock mutation, order mutation beyond allowed dispute creation, supplier mutation, admin mutation, evidence, notifications, finance holds.

## D5 - Supplier Response Backend

Status: completed in DEVELOPMENT after D5-A.

Scope: supplier can add backend-only responses to own scoped disputes through audited RPCs.

Applied migration:

- `20260801150000_supplier_dispute_response_rpc.sql`

RPC:

- `supplier_add_dispute_response`

Verification:

- `scripts/rpc/supplier-dispute-response-tests-dev-only.sql` passed 67 rollback-scoped assertions.
- Separate temporary two-session concurrency runner passed 9 assertions.
- No UI was activated.
- No supplier final resolution, admin mutation, return, refund, finance, order, payment, stock, reservation, settlement, commission, wallet, withdrawal, evidence, or notification flow was added.

Stop conditions preserved: supplier final resolution, supplier finance verification, cross-supplier visibility, UI activation.

## D6 - Admin Investigation and Non-Financial Resolution Backend

Status: completed in DEVELOPMENT as backend-only controlled RPCs.

Scope: admin/support assignment, request info, approved investigation transitions, non-financial resolution recording, and closure of eligible resolved/rejected/cancelled cases.

Applied migrations:

- `20260801160000_admin_dispute_investigation_and_resolution_rpcs.sql`
- `20260801161000_fix_admin_dispute_rowtype_reads.sql`

RPCs:

- `admin_assign_dispute`
- `admin_request_dispute_information`
- `admin_change_dispute_status`
- `admin_record_non_financial_resolution`
- `admin_close_dispute`

Verification:

- `scripts/rpc/admin-dispute-investigation-resolution-tests-dev-only.sql` passed 103 rollback-scoped assertions.
- `scripts/rpc/admin-dispute-d6-concurrency-dev-only.mjs` passed 12 true two-session race scenarios with 61 invariant checks.
- No UI was activated.
- No return, refund, finance, order, payment, stock, reservation, settlement, commission, wallet, withdrawal, evidence, or notification flow was added.

Stop conditions preserved: arbitrary set-any-status panel, money movement, stock restoration, return/refund execution, finance holds, and dispute UI activation.

## D7 - Return Workflow and Returned-Stock Inspection

Status: completed in DEVELOPMENT as backend-only controlled RPCs.

Scope: return request, approval/rejection, customer in-transit marker, supplier receipt, supplier condition classification, admin accept/decline/complete, and inventory outcome planning.

Applied migrations:

- `20260801170000_return_workflow_backend_foundation.sql`
- `20260801171000_fix_return_workflow_status_history_reason.sql`
- `20260801172000_fix_return_workflow_idempotency_column_ambiguity.sql`

RPCs:

- `customer_request_item_return`
- `admin_approve_return`
- `admin_reject_return`
- `customer_mark_return_in_transit`
- `supplier_confirm_return_received`
- `supplier_report_return_condition`
- `admin_accept_return`
- `admin_decline_return`
- `admin_complete_return`

Verification:

- `scripts/rpc/return-workflow-backend-tests-dev-only.sql` passed with more than 77 rollback-scoped assertions.
- `scripts/rpc/return-workflow-d7-concurrency-dev-only.mjs` passed 11 true two-session race scenarios plus side-effect and cleanup checks.
- D6/D5/D4 relevant regression suites passed after D7. The D4 dev-only harness was refreshed to the existing D5-A open-dispute signature.

Stop conditions preserved: auto-restock, stock mutation, delivery-provider booking, refunds, finance holds, settlement changes, commission changes, wallet changes, withdrawal changes, evidence uploads, notification outbox events, and UI activation.

## D8 - Refund Obligation and Manual Refund Recording

Status: completed in DEVELOPMENT as backend-only controlled RPCs.

Scope: refund obligation model, manual refund reported/verified states, customer confirmation, finance verification/rejection/completion, role-safe reads, idempotency, cumulative caps, and no-side-effect verification.

Applied migrations:

- `20260801180000_refund_workflow_backend_foundation.sql`
- `20260801181000_fix_refund_customer_confirmation_idempotency.sql`
- `20260801182000_enforce_refund_cumulative_component_caps.sql`
- `20260801183000_scrub_refund_audit_reason_notes.sql`

RPCs:

- `admin_approve_refund_obligation`
- `supplier_report_refund_sent`
- `admin_report_platform_refund_sent`
- `customer_confirm_refund_received`
- `admin_verify_refund_report`
- `admin_reject_refund_report`
- `admin_complete_refund`

Verification:

- `scripts/rpc/refund-workflow-backend-tests-dev-only.sql` passed 99 rollback-scoped assertions.
- `scripts/rpc/refund-workflow-d8-concurrency-dev-only.mjs` passed 12 true multi-process race scenarios plus side-effect and cleanup checks.
- D4, D5, D6 SQL, D7 SQL, and D7 external regressions passed during D8 verification.

Stop conditions preserved: provider refund, amount above immutable snapshot max, cumulative over-refund, unverified refund marked final, finance holds, settlement mutation, commission mutation, wallet mutation, withdrawal mutation, stock mutation, order/payment status mutation, notification outbox, evidence upload, and UI activation.

## D9 - Finance Holds, Commission Adjustments, Settlement Interaction

Scope: finance holds for settlement/commission/wallet; block/flag settlement verification; apply/release holds.

Stop conditions: deleting commissions, negative wallet, general admin finance access.

## D10 - Withdrawal Interaction and Recovery/Liability Model

Scope: pending withdrawal holds/rejections and paid-withdrawal liability/recovery records.

Dependencies: business decision on paid withdrawal treatment and withdrawal allocation.

Stop conditions: silently reversing paid withdrawal or claiming exact allocation without data.

## D11 - Notifications

Scope: extend transactional outbox with dispute/return/refund notification events.

Stop conditions: private evidence in emails, raw enum leakage, live mode changes without approval.

## D12 - Full Concurrency, Security, Browser QA

Scope: concurrency tests, SQL boundary tests, route/browser QA across customer/supplier/reseller/admin/finance.

Stop conditions: any unresolved security/privacy/accounting issue.

## D13 - Commit, Push, and Phase Close Review

Scope: stage exact files, run all validation, secret/scope scan, commit and push only after user request.

Stop conditions: `.env.local`, `.next`, `.local-recovery`, `supabase/.temp`, dev logs, private screenshots, or secrets staged.

## Sequencing Rule

Do not combine D8, D9, and D10 until refund responsibility, commission reversal, paid withdrawal recovery, and finance hold business rules are approved.

## D5-A Inserted Group

D5-A was inserted between D4 customer mutation and D5 supplier response. Scope: add supplier/item targets to `order_disputes`, update customer dispute creation to derive targets from `order_items.supplier_id`, repair supplier safe reads, and preserve all order/payment/finance/stock/notification boundaries. Supplier response remains a later group.
