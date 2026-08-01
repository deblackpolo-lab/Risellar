# Risellar Email Notifications Phase 1 Backend Report

## A. Summary

Implemented the server-only transactional email notification foundation for verified order, delivery, payment, settlement, commission, and withdrawal events.

The backend uses a durable database outbox plus a protected server worker. Email delivery is decoupled from business transitions: existing business RPCs write audited events, the new audit-log trigger attempts to enqueue safe notification rows, and failures inside the email enqueue trigger are swallowed so order, stock, payment, settlement, commission, wallet, and withdrawal transactions are not rolled back by notification problems.

Live Resend email QA was resumed against the Vercel Production deployment that is temporarily wired to the confirmed DEVELOPMENT Supabase project.

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

Vercel Production presence-only check for DEVELOPMENT QA:

- deployment alias tested: `https://risellar.vercel.app`
- required processor/redirect env names are present in Vercel Production
- no environment values were printed
- `RESEND_WEBHOOK_SECRET` is not present in Vercel Production, so signed live webhook QA is blocked until it is added

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

Live webhook delivery remains blocked because `RESEND_WEBHOOK_SECRET` is not configured in Vercel Production.

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

## K2. Vercel HTTPS Redirect-Mode QA

Vercel Production deployment for DEVELOPMENT QA:

- public production alias loaded successfully: `/` returned `200`
- processor route without a secret returned `401`
- processor route with an invalid secret returned `401`
- unsigned webhook POST returned safe `RESEND_WEBHOOK_SECRET_MISSING` because `RESEND_WEBHOOK_SECRET` is absent

Fresh notification-only QA rows were created in the DEVELOPMENT Supabase project using active profiles with verified Clerk primary emails:

- customer template
- supplier template
- reseller template
- finance-admin template

Processor result from `https://risellar.vercel.app`:

- first run: `claimed=4`, `sent=4`, `retried=0`, `failed=0`, `skipped=0`
- provider message ids were stored for all four outbox rows
- outbox rows moved to `sent`
- Resend metadata retrieval succeeded for all four sent messages
- all subjects began with `[DEV]`
- HTML and plain-text bodies were present
- no private/internal notification payload fields were present
- all four messages were addressed to one recipient, consistent with redirect-mode behavior
- a second processor invocation returned `claimed=0`, confirming no duplicate sends

Remaining Vercel HTTPS QA blockers:

- fixed in commit `02c951ce2012b8102fb4e5ba1ec9cd8391a8e91c`: sent CTA links now use absolute `https://risellar.vercel.app/...` URLs
- the QA run could not prove the single Resend recipient equals the Vercel `EMAIL_DEV_RECIPIENT` value without retrieving/printing production env values, but all four messages used one recipient and every subject began with `[DEV]`
- valid signed webhook QA cannot run until `RESEND_WEBHOOK_SECRET` is added to Vercel Production

Business side-effect check:

- notification fixture creation changed only `notification_outbox`
- processor invocation changed only notification outbox/provider metadata
- order, order item, payment, delivery quote, delivery arrangement, settlement, commission, wallet, withdrawal, stock reservation, and inventory movement counts stayed unchanged during the side-effect checks

## L. Automated Tests

Created:

- `tests/transactional-email-notifications.test.ts`
- `tests/resend-webhook.test.ts`

Focused tests passed:

- 2 files
- 10 tests

Full test suite passed:

- 48 files
- 280 tests

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

Vercel HTTPS QA status:

- production alias loads successfully
- redirect-mode processor send path works for four representative role templates
- duplicate processing is blocked by durable outbox state
- webhook QA is blocked by missing `RESEND_WEBHOOK_SECRET`
- CTA links are fixed and verified in sent Resend metadata after deployment of `02c951ce2012b8102fb4e5ba1ec9cd8391a8e91c`
- final completion is blocked by missing live webhook secret in Vercel Production

## P. CTA Fix And Post-Deploy HTTPS QA

Root cause:

- email templates previously rendered the safe `ctaPath` as a relative `href`
- `NEXT_PUBLIC_APP_URL` was read into config but was not used when rendering templates

Fix:

- added server-only absolute CTA URL construction in `lib/notifications/email.ts`
- `NEXT_PUBLIC_APP_URL` is normalized and validated
- production no longer silently falls back to localhost
- local development can still use `http://localhost:400`
- only application-relative CTA payload paths are accepted
- absolute, protocol-relative, `javascript:`, and `data:` payload URLs fall back safely to the app root
- processor passes the validated app URL into template rendering

Local verification before deployment:

- focused notification tests passed: 2 files / 15 tests
- full `npm test` passed: 48 files / 284 tests
- `npm run lint` passed
- `npm run build` passed
- `npm run typecheck` passed
- `npx tsc --noEmit` passed

Deployment:

- commit pushed: `02c951ce2012b8102fb4e5ba1ec9cd8391a8e91c`
- Vercel Production deployment became `Ready`
- `https://risellar.vercel.app` remained public and returned `200`

Fresh post-deploy CTA email QA:

- created four fresh notification-only outbox rows for customer, supplier, reseller, and finance-admin templates
- processor result: `claimed=4`, `sent=4`, `retried=0`, `failed=0`, `skipped=0`
- all outbox rows became `sent`
- provider message ids were stored
- `sent_at` was populated
- Resend metadata was retrievable for all four messages
- all subjects began with `[DEV]`
- HTML and plain-text bodies were present
- every representative CTA began with `https://risellar.vercel.app/`
- no relative-only `href` remained
- no localhost URL was present
- no malformed double slash was present
- query strings were preserved
- no private token or internal field was found in the scanned email metadata

Duplicate processor check:

- second processor invocation returned `claimed=0`, `sent=0`, `retried=0`, `failed=0`, `skipped=0`
- sent outbox rows were unchanged
- no duplicate provider email was attempted

Webhook status:

- Vercel env-name listing still does not show `RESEND_WEBHOOK_SECRET`
- unsigned webhook POST returned safe `RESEND_WEBHOOK_SECRET_MISSING`
- fake invalid-signature POST also returned safe `RESEND_WEBHOOK_SECRET_MISSING`
- provider event row count did not change for unsigned/invalid webhook checks
- valid signed webhook, replay, and bounce/failure webhook QA remain blocked until `RESEND_WEBHOOK_SECRET` is actually present in Vercel Production

## Q. Webhook Secret Redeploy QA

After the webhook secret was reported as added and the Vercel Production deployment was redeployed:

- `https://risellar.vercel.app` returned `200`
- `GET /api/resend/webhook` returned safe `405`
- unsigned webhook `POST` returned safe `401` / `INVALID_SIGNATURE`
- invalid signed webhook `POST` returned safe `401` / `INVALID_SIGNATURE`
- provider-event row count did not change for invalid webhook requests

Signed-route verification:

- a correctly signed Standard Webhooks payload using the configured webhook secret was accepted by the deployed route
- raw-body signature verification happened before event processing
- provider event storage inserted exactly one event for the valid signed payload
- replaying the same signed event returned an idempotent duplicate result and did not insert a second provider event
- a signed `email.bounced` payload updated only notification provider status
- no order, order item, payment, delivery quote, delivery arrangement, settlement, commission, wallet, withdrawal, stock reservation, or inventory movement counts changed

Resend provider configuration:

- Resend API metadata shows one webhook configured for the Risellar Vercel endpoint
- configured event subscriptions include `email.sent`, `email.delivered`, `email.bounced`, `email.complained`, `email.delivery_delayed`, and related email events
- endpoint values and secret values were not printed

Live Resend delivery result:

- one fresh redirect-mode email was sent after the secret redeploy: `claimed=1`, `sent=1`
- provider message id was stored
- outbox status remained `sent`
- after polling for live provider events, no real Resend-originated `notification_provider_events` row was recorded
- one final delivery probe was sent after confirming the Resend webhook configuration: `claimed=1`, `sent=1`
- after a second polling window, no real Resend-originated provider event was recorded

Final blocker:

- live provider-originated webhook delivery from Resend to `https://risellar.vercel.app/api/resend/webhook` is not yet verified
- because live delivery did not arrive, Email Notifications Phase 1 is not fully complete and the final completion commit was not made

## R. Real Provider-Originated Webhook Follow-Up

Manual Resend dashboard/configuration follow-up was completed outside Codex, then Codex rechecked the provider via the Resend API:

- exactly one webhook was visible to the same `RESEND_API_KEY` used for sends
- endpoint matched `https://risellar.vercel.app/api/resend/webhook`
- webhook status was enabled
- required subscriptions were present:
  - `email.sent`
  - `email.delivered`
  - `email.delivery_delayed`
  - `email.failed`
  - `email.bounced`
  - `email.complained`

Fresh provider-originated webhook QA email:

- created one new notification-only outbox row with a fresh event key
- processor result: `claimed=1`, `sent=1`, `retried=0`, `failed=0`, `skipped=0`
- provider message id was stored
- Resend email metadata was retrievable
- Resend email metadata reported `last_event=delivered`
- outbox remained `sent` / provider status `sent`
- no real provider-originated `notification_provider_events` row appeared after polling

Conclusion:

- Resend send/delivery is proven for the fresh QA email
- the deployed webhook route is proven to accept valid signed webhook payloads
- replay and bounce/failure signed-route behavior are proven
- real Resend-originated webhook delivery is still not proven because no real provider event row was stored
- final completion commit remains blocked until the Resend dashboard message log shows a delivery that is successfully replayed or a fresh provider-originated webhook row appears in `notification_provider_events`

Final verification status for this follow-up:

- `https://risellar.vercel.app` returned HTTP `200`
- `GET /api/resend/webhook` was rejected safely with HTTP `405`
- unsigned and invalid-signed webhook posts were rejected with HTTP `401`
- invalid webhook requests did not create provider-event rows
- `git diff --check` passed with line-ending warnings only
- `npm test` passed: 48 files / 284 tests
- `npm run lint` passed
- `npm run build` passed
- `npm run typecheck` passed after rerunning sequentially once `.next/types` had settled
- `npx tsc --noEmit` passed
- secret/scope scan found no committed secrets, no service-role exposure in `app`/`components`, and no notification-side business table mutation references

## S. Real Resend Payload Compatibility Fix

A real Resend `email.sent` webhook reached the deployed endpoint and returned HTTP `500`. The safe real payload shape contained top-level `type`, `created_at`, and `data`, with `data.email_id` as the Resend email identifier. It did not contain a top-level payload `id`.

Root cause:

- the webhook helper and storage path had been tested with synthetic payloads that included `event.id`
- `record_email_provider_event` was called with the body-derived `event.id`
- for real Resend payloads that value is absent, which violates the provider-event identity requirement
- the provider-event table can already store the verified `svix-id` header as `provider_event_id`, so no migration is needed

Fix:

- raw body verification remains unchanged and still runs before parsing/trusting the payload
- the route now uses the verified `svix-id` request header as the provider event identity
- `payload.data.email_id` remains the provider message ID used to match notification outbox rows
- `email.failed` is mapped to a safe `failed` provider status
- unsupported signed event types return a safe ignored success instead of crashing
- no full webhook payloads are stored
- no business order, payment, settlement, commission, wallet, withdrawal, delivery, stock, or reservation records are modified

Regression tests added:

- real Resend payloads without top-level `id` are accepted
- `svix-id` is used for provider-event deduplication
- `data.email_id` is used for outbox provider-message matching
- replay returns duplicate without updating notification status again
- unmatched email IDs do not crash
- unsupported signed events do not store provider events

Follow-up ordering guard:

- fresh provider-originated QA proved real `email.sent` and `email.delivered` webhooks reached the deployed endpoint and were stored
- Resend delivered the two events close together, and a later `email.sent` can otherwise overwrite the outbox provider status after `email.delivered`
- the webhook handler now records `email.sent` provider events but skips outbox status mutation for `sent`
- the processor already marks the outbox sent immediately after the Resend send call
- delivered, bounced, complained, failed, and delivery-delayed webhooks remain status-updating events

Final deployed webhook verification:

- the ordering guard was committed, pushed, and deployed to Vercel Production
- one fresh notification-only QA row was enqueued and processed through the protected production processor
- processor result: `claimed=1`, `sent=1`, `retried=0`, `failed=0`, `skipped=0`
- provider message ID was stored for the outbox row
- real provider-originated `email.sent` and `email.delivered` webhooks reached `https://risellar.vercel.app/api/resend/webhook`
- both provider events were stored once using distinct verified `svix-id` identities
- `data.email_id` matched the outbox provider message ID
- final outbox status and provider status were both `delivered`
- a follow-up count check stayed at two provider-event rows, so no duplicate provider rows appeared from retries
- Vercel logs showed production POSTs for the processor and webhook route with no observed HTTP `500`
- dashboard replay of the original failed provider event was not available from Codex; final proof used a fresh real provider-originated send/delivery event after the fix
