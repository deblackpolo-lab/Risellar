# Risellar Disputes D11 Notification Backend Report

## Summary

D11 adds backend-only transactional notification support for disputes, returns, refunds, finance holds, reseller liabilities, and withdrawal review events.

The implementation reuses the existing notification outbox and email processor. No new provider integration, UI, SMS, WhatsApp, checkout, order, stock, payment, delivery, settlement, commission, wallet, withdrawal, dispute, return, or refund business mutation path was added for notification processing.

## Files

- `lib/notifications/email.ts`
- `tests/transactional-email-notifications.test.ts`
- `supabase/migrations/20260801210000_dispute_return_refund_finance_notification_events.sql`
- `scripts/rpc/dispute-notifications-d11-tests-dev-only.sql`
- `scripts/rpc/dispute-notifications-d11-concurrency-dev-only.mjs`

Regression harnesses updated to treat D11 outbox enqueue rows as expected notification side effects while preserving business no-side-effect checks:

- `scripts/rpc/customer-dispute-open-response-tests-dev-only.sql`
- `scripts/rpc/supplier-dispute-response-tests-dev-only.sql`
- `scripts/rpc/dispute-supplier-item-scoping-tests-dev-only.sql`
- `scripts/rpc/admin-dispute-investigation-resolution-tests-dev-only.sql`
- `scripts/rpc/admin-dispute-d6-concurrency-dev-only.mjs`
- `scripts/rpc/return-workflow-backend-tests-dev-only.sql`
- `scripts/rpc/return-workflow-d7-concurrency-dev-only.mjs`
- `scripts/rpc/refund-workflow-backend-tests-dev-only.sql`
- `scripts/rpc/refund-workflow-d8-concurrency-dev-only.mjs`
- `scripts/rpc/dispute-finance-holds-d9-tests-dev-only.sql`
- `scripts/rpc/dispute-finance-holds-d9-concurrency-dev-only.mjs`
- `scripts/rpc/reseller-liability-withdrawal-recovery-d10-tests-dev-only.sql`
- `scripts/rpc/transactional-email-notification-outbox-tests-dev-only.sql`

## Migration

Migration:

- `20260801210000_dispute_return_refund_finance_notification_events.sql`

The migration expands the notification outbox allowed event type constraint, adds D11 notification helper functions, and maps trusted `audit_logs` rows to notification outbox rows.

The migration was dry-run checked and applied only to the confirmed DEVELOPMENT Supabase project.

## Mapping

Mapped source areas:

- disputes
- returns
- refunds
- finance holds
- reseller liabilities
- withdrawal commission allocation review

The mapper derives recipients from trusted database relationships and admin staff role rows. It does not accept recipient email or recipient identity from browser payloads.

## Verification

- D11 SQL suite passed: 50/50 assertions.
- D11 concurrency harness passed: 10 scenarios, 13 invariants.
- Transactional email unit tests passed in focused mode before full verification.
- Legacy D4-D10 regression harnesses were updated where their old "no notification rows" expectations conflicted with D11's intended outbox behavior.

## Live QA

Live redirect-mode email QA for D11-specific events is deferred until a deployment that includes D11 is intentionally made. Existing Phase 1 provider-originated webhook compatibility remains reused and covered by automated tests.

## Safety

- No production Supabase connection was used.
- No secrets were printed.
- No UI path was activated.
- No business mutation was added to notification processing.
