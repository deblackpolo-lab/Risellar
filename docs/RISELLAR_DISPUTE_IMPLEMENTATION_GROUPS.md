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

## D5 - Supplier View/Respond Backend/UI

Scope: supplier sees/responds to own supplier disputes.

UI: supplier dispute queue/detail.

Stop conditions: supplier final resolution, supplier finance verification, cross-supplier visibility.

## D6 - Admin Investigation and Non-Financial Resolution UI

Scope: admin/support triage, request info, non-finance resolution proposal, close no-action cases.

Stop conditions: arbitrary set-any-status panel, money movement, stock restoration.

## D7 - Return Workflow and Returned-Stock Inspection

Scope: return approval/rejection, return receipt, condition classification, inventory outcome planning.

RPCs: return approval, supplier/admin inspection, inventory adjustment after inspection.

Stop conditions: auto-restock before inspection, delivery-provider booking.

## D8 - Refund Obligation and Manual Refund Recording

Scope: refund obligation model, manual refund reported/verified states, proof metadata.

Stop conditions: provider refund, amount above snapshot max, unverified refund marked final.

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
