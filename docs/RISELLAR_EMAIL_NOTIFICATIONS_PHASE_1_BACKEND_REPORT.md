# Risellar Email Notifications Phase 1 Backend Report

## A. Summary

Implemented the server-only transactional email notification foundation for verified order, delivery, payment, settlement, commission, and withdrawal events.

The backend uses a durable database outbox plus a protected server worker. Email delivery is decoupled from business transitions: existing business RPCs write audited events, the new audit-log trigger attempts to enqueue safe notification rows, and failures inside the email enqueue trigger are swallowed so order, stock, payment, settlement, commission, wallet, and withdrawal transactions are not rolled back by notification problems.

Live Resend email QA is blocked until development-only email configuration is added manually to `.env.local`.

## B. Resend SDK

- SDK package added: `resend@6.18.1`.
- Official Resend contract reviewed:
  - server-side send through the Node SDK
  - `Idempotency-Key` support
  - 256-character maximum idempotency key
  - provider idempotency retention is 24 hours
  - webhook verification requires raw request body
  - webhook event names include `email.sent`, `email.delivered`, `email.delivery_delayed`, `email.bounced`, `email.complained`, `email.opened`, `email.clicked`, and related non-email events

## C. Environment Validation

Added server-only configuration support for:

- `RESEND_API_KEY`
- `EMAIL_FROM`
- `EMAIL_REPLY_TO`
- `EMAIL_SEND_MODE`
- `EMAIL_DEV_RECIPIENT`
- `RESEND_WEBHOOK_SECRET`
- `NOTIFICATION_PROCESSOR_SECRET`
- `NEXT_PUBLIC_APP_URL`

Safe policy:

- missing config defaults to `disabled`
- development `live` mode is blocked
- `redirect` mode requires `EMAIL_DEV_RECIPIENT`
- no secret values are printed or committed

Current `.env.local` presence check after user update:

- `.env.local` exists
- `.env.local` is ignored
- `.env.local` is not staged
- present: `RESEND_API_KEY`, `EMAIL_FROM`, `EMAIL_SEND_MODE`, `EMAIL_DEV_RECIPIENT`, `NOTIFICATION_PROCESSOR_SECRET`, `NEXT_PUBLIC_APP_URL`
- `EMAIL_SEND_MODE=redirect` confirmed
- `EMAIL_FROM` is present but currently fails safe sender-format validation / Resend validation
- live webhook secret is not required for this phase

## D. Architecture

Created:

- `public.notification_outbox`
- `public.notification_provider_events`
- `public.enqueue_email_notification(...)`
- `public.claim_pending_email_notifications(...)`
- `public.mark_email_notification_sent(...)`
- `public.mark_email_notification_retry(...)`
- `public.mark_email_notification_failed(...)`
- `public.record_email_provider_event(...)`
- `public.update_email_notification_provider_status(...)`
- `public.enqueue_email_notifications_from_audit_log()`

The outbox stores:

- deterministic `event_key`
- event type
- entity type/id
- recipient profile id or recipient role
- retry/claim state
- provider message/status metadata
- safe JSON template payload only

It does not store recipient emails, secrets, raw tokens, full payout details, platform margin, reseller margin, supplier private notes, admin notes, or customer-private finance details.

## E. Event Source Strategy

Chosen strategy: database trigger on trusted `public.audit_logs` inserts.

This avoids client/browser enqueue paths and avoids editing every existing business RPC. The trigger maps known audited actions to notification events and recipient roles.

Mapped audit actions include:

- `order_created`
- `supplier_order_accepted`
- `supplier_order_rejected`
- `supplier_order_preparation_started`
- `supplier_order_ready_for_delivery`
- `supplier_order_delivery_arranged`
- `supplier_order_out_for_delivery`
- `supplier_order_delivered`
- `supplier_order_payment_reported`
- `supplier_settlement_verified`
- `reseller_withdrawal_requested`
- `reseller_withdrawal_paid`

## F. Event/Recipient Matrix

Implemented all required event types:

- customer: order placed, accepted, rejected, preparing, ready, delivery arranged, out for delivery, delivered, payment reported, order complete
- supplier: new order received, settlement verified
- reseller: commission available, withdrawal requested, withdrawal paid
- finance admin: supplier settlement review, reseller withdrawal review

Finance-admin notifications target active `admin_staff` members with `finance_staff` or `super_admin`.

## G. Worker Security

Created protected processor route:

- `POST /api/internal/notifications/process`
- requires `x-risellar-notification-secret`
- returns safe counts only
- no GET processing
- no recipient email or payload returned

The worker uses server-only modules and the existing server-only Supabase admin helper. No service-role helper is imported by client components.

## H. Webhook Security

Created Resend webhook route:

- `POST /api/resend/webhook`
- reads raw request body with `request.text()`
- verifies signed webhook payload before status updates
- dedupes provider events
- updates only notification provider status
- does not mutate orders, payments, stock, delivery, settlements, commissions, wallets, or withdrawals

Live webhook delivery remains a deployment/dashboard setup task because no `RESEND_WEBHOOK_SECRET` is configured locally.

## I. Migration

Created and applied to the confirmed DEVELOPMENT Supabase project:

- `supabase/migrations/20260801090000_transactional_email_notification_outbox.sql`

Dry-run result:

- passed
- exactly one pending migration was listed: `20260801090000_transactional_email_notification_outbox.sql`

Apply result:

- passed in DEVELOPMENT
- no migration repair or reset was run
- production was not connected

## J. SQL Boundary Test

Created:

- `scripts/rpc/transactional-email-notification-outbox-tests-dev-only.sql`

Result:

- passed

Assertions verified:

- all required event rows can be enqueued
- deterministic event keys dedupe retries
- separate recipients create intentional separate rows
- unsafe payload fields are excluded
- batch claim limit is enforced
- two workers do not claim the same row
- sent status update is idempotent
- retry scheduling works
- missing verified email can be skipped safely
- provider event dedupe works
- provider delivery status updates notifications only
- processing creates no business rows
- fixture data rolls back

## K. Live Redirect-Mode Processor QA

Development server on port 400 was restarted after `.env.local` was updated.

Protected endpoint checks:

- missing processor secret: blocked with `401`
- invalid processor secret: blocked with `401`
- valid processor secret: accepted

Created six safe notification-only outbox rows:

- customer order event
- supplier order event
- customer delivery event
- finance-admin settlement-review event
- reseller commission event
- reseller withdrawal event

Processor result:

- first run: `claimed=6`, `sent=0`, `skipped=5`, `failed=1`
- second run: `claimed=0`, confirming no duplicate processing

Failure classification:

- five rows skipped as `SKIPPED_NO_VERIFIED_EMAIL`
- one provider attempt failed with Resend `validation_error` / HTTP `422`
- direct provider configuration check confirmed the sender field is invalid format

No real application users received email because no send succeeded and redirect mode remained enabled.

Live redirect-mode email QA is blocked until:

- `EMAIL_FROM` is corrected to Resend format, such as a verified bare email or `Name <email@example.com>`
- representative QA recipient profiles have resolvable Clerk primary verified emails, or safe notification-only QA is explicitly approved to target one verified development profile while rendering each role template

## L. Automated Tests

Created:

- `tests/transactional-email-notifications.test.ts`
- `tests/resend-webhook.test.ts`

Focused tests passed:

- 2 files
- 10 tests

Full test suite passed:

- 48 files
- 279 tests

This increased the baseline from 46 files / 269 tests.

## M. Security/Scope

Confirmed by implementation design and scoped scans:

- no client component sends email
- no browser-supplied recipient, subject, HTML, order, payment, commission, settlement, or payout details
- no `RESEND_API_KEY` in client code
- no `NEXT_PUBLIC` notification secret
- no service role in app/components
- no broad user grants for worker tables/functions
- no business-state mutation in processor/webhook code
- no stock/order/payment/delivery/finance transition was added
- live email sending remains disabled until explicit dev config exists
- `.env.local` ignored and not staged
- `.next`, `supabase/.temp`, and `.codex-dev-server.*.log` ignored

## N. Files Changed

- `.env.example`
- `app/api/internal/notifications/process/route.ts`
- `app/api/resend/webhook/route.ts`
- `lib/notifications/email.ts`
- `lib/notifications/processor.ts`
- `lib/notifications/resend-client.ts`
- `lib/notifications/resend-webhook.ts`
- `lib/notifications/service.ts`
- `package.json`
- `package-lock.json`
- `scripts/rpc/transactional-email-notification-outbox-tests-dev-only.sql`
- `supabase/migrations/20260801090000_transactional_email_notification_outbox.sql`
- `tests/resend-webhook.test.ts`
- `tests/transactional-email-notifications.test.ts`

## O. Current Status

Backend implementation and development database boundary testing are complete.

Verification completed:

- `git diff --check`: passed
- `npm test`: passed
- `npm run lint`: passed
- `npm run build`: passed
- `npm run typecheck`: passed
- `npx tsc --noEmit`: passed

Runtime sweep after clearing ignored stale `.next` cache:

- `/`: `200`
- `/sign-in`: `200`
- `/sign-up`: `200`
- `/shop/not-a-real-shop`: `200` safe unavailable state
- signed-out protected role routes checked: blocked with `404`
- `GET /api/internal/notifications/process`: `405`

Live DEVELOPMENT Resend QA is blocked by invalid sender configuration and by selected role profiles lacking resolvable verified Clerk primary emails. The phase is not ready to commit as fully complete unless the user corrects `EMAIL_FROM`, live redirect-mode email QA passes, and inbox arrival is confirmed.
