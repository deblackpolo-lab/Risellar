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

D11 live redirect-mode email QA passed after the D1-D11 commit range was pushed to `origin/main` and deployed on Vercel Production for DEVELOPMENT QA.

- Vercel Production deployment for commit `f8c3aee091523d2d49a6f87fec381fcf47c75ea1` completed successfully.
- `https://risellar.vercel.app` returned HTTP `200`.
- Required notification environment names were present without printing values.
- `EMAIL_SEND_MODE` remained `redirect`.
- Five fresh notification-only D11 outbox rows were created for customer, supplier, reseller, support/admin, and finance-admin representative events.
- All five D11 rows were sent/delivered with provider message IDs and `sent_at` populated.
- Resend metadata confirmed all five messages were redirected to the configured development recipient and all subjects started with `[DEV]`.
- All five rendered bodies contained Vercel HTTPS CTA links and passed the private-field scan.
- Real provider-originated `email.sent` and `email.delivered` webhooks were stored for all five provider message IDs.
- A duplicate processor invocation claimed zero rows and sent no duplicates.
- The support/admin template was tested with `recipient_role = 'support_admin'`; the available verified recipient profile came from the active development finance-admin bucket because no active verified support/admin bucket was available.
- No business table counts changed during notification processing or webhook handling.

## Safety

- No production Supabase connection was used.
- No secrets were printed.
- No UI path was activated.
- No business mutation was added to notification processing.
