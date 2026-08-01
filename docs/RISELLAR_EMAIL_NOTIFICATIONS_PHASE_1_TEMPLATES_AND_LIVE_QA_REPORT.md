# Risellar Email Notifications Phase 1 Templates And Live QA Report

## A. Template Inventory

Implemented server-rendered transactional templates for:

- `order_placed_customer`
- `order_placed_supplier`
- `supplier_order_accepted`
- `supplier_order_rejected`
- `supplier_order_preparing`
- `order_ready_for_delivery`
- `delivery_arranged`
- `order_out_for_delivery`
- `order_delivered`
- `supplier_payment_reported_customer`
- `supplier_payment_reported_finance`
- `settlement_verified_supplier`
- `settlement_verified_customer`
- `reseller_commission_available`
- `withdrawal_requested_reseller`
- `withdrawal_requested_finance`
- `withdrawal_paid_reseller`

Each template has:

- subject
- HTML body
- plain text fallback
- safe CTA path
- sanitized payload input

## B. Privacy Rules

Template payload sanitizer blocks keys and values associated with:

- recipient email
- private supplier notes
- private admin notes
- payout account details
- platform margin
- reseller margin
- supplier base price
- tokens
- secrets
- passwords
- raw private/risk fields

Customer templates do not include settlement amounts, commissions, platform margin, reseller margin, supplier base price, or payout data.

Supplier templates do not include admin private notes, reseller wallet data, or settlement controls.

Reseller templates do not include supplier private notes, admin private notes, customer private data, or another reseller finance data.

Finance-admin templates use safe links and safe summary payload only.

## C. DEVELOPMENT Send Mode

Configured modes:

- `disabled`: no provider send
- `redirect`: all sends go to `EMAIL_DEV_RECIPIENT`, subject gets `[DEV]`
- `live`: blocked in development

Current DEVELOPMENT live email QA status:

- partially passed on Vercel HTTPS, with blockers remaining

Presence-only env result:

- `RESEND_API_KEY`: present
- `EMAIL_FROM`: present
- `EMAIL_SEND_MODE`: present and set to `redirect`
- `EMAIL_DEV_RECIPIENT`: present
- `NOTIFICATION_PROCESSOR_SECRET`: present
- `NEXT_PUBLIC_APP_URL`: present

No values were printed. `.env.local` was not edited or staged.

Vercel Production for DEVELOPMENT QA:

- `https://risellar.vercel.app` loaded successfully
- required notification processor/redirect env names are present by name in Vercel Production
- no environment values were printed
- `RESEND_WEBHOOK_SECRET` is absent, so valid signed live webhook QA is blocked

## D. Live DEVELOPMENT Email QA

Attempted in redirect mode.

Setup:

- restarted exact Risellar dev server on port `400`
- verified missing and invalid processor secrets are blocked
- created six safe notification-only DEVELOPMENT outbox rows covering customer, supplier, delivery, finance-admin, reseller commission, and reseller withdrawal template categories
- invoked the protected notification processor with the configured secret

Result:

- processor claimed six rows
- zero emails were sent
- five rows were skipped with `SKIPPED_NO_VERIFIED_EMAIL`
- one row failed with a safe provider classification
- direct provider configuration check returned Resend `validation_error` / HTTP `422`
- the failure is the sender format for `EMAIL_FROM`

Required manual fix before live QA can pass:

- update ignored `.env.local` so `EMAIL_FROM` is a Resend-valid sender, for example a verified bare sender address or `Name <email@example.com>`
- ensure role QA recipients resolve to Clerk primary verified emails, or approve one verified development profile as the redirect-mode recipient target for all role-template sends

## E. Duplicate Send QA

Automated backend verification passed:

- database `event_key` dedupes retries beyond provider retention
- Resend request uses the same `event_key` as provider idempotency key
- SQL boundary test verified duplicate enqueue creates no extra row
- focused TypeScript test verified idempotency key is sent in the provider request

Live duplicate-send check:

- second protected processor invocation returned `claimed=0`, `sent=0`, `retried=0`, `failed=0`, `skipped=0`
- no duplicate provider send occurred because no live send succeeded

Full provider duplicate-send QA remains blocked until sender configuration is corrected.

Vercel HTTPS duplicate-send result:

- four representative notification-only rows were sent successfully through the production HTTPS processor
- a second protected processor invocation returned `claimed=0`, `sent=0`, `retried=0`, `failed=0`, `skipped=0`
- no duplicate provider send was attempted for the QA rows

Post-CTA-fix duplicate-send result:

- after deploying `02c951ce2012b8102fb4e5ba1ec9cd8391a8e91c`, a second processor invocation for the fresh CTA rows returned `claimed=0`, `sent=0`, `retried=0`, `failed=0`, `skipped=0`
- the already-sent outbox rows were unchanged

## F. Retry QA

Automated retry verification passed:

- retryable errors are classified
- permanent errors are not retried
- SQL boundary test verified retry scheduling
- maximum attempts are bounded in schema

Controlled retry/permanent failure tests:

- automated retryable and permanent error classification passed
- invalid sender configuration is now caught safely as disabled config by `EMAIL_FROM_INVALID`
- full live retry simulation remains blocked until sender configuration is corrected

Vercel HTTPS retry status:

- full controlled live retry/permanent-failure testing was not completed because the phase is blocked by missing signed webhook configuration and the CTA-link defect
- existing automated retry/permanent classification remains passing

## G. Webhook QA

Automated webhook verification passed:

- raw body is verified before processing
- invalid signature returns safe rejection
- provider replay is idempotent
- delivery status updates notification status only
- no business data mutation occurs

HTTP route check:

- missing local webhook secret currently returns safe `RESEND_WEBHOOK_SECRET_MISSING`

Vercel HTTPS webhook route check:

- unsigned webhook POST returned safe `RESEND_WEBHOOK_SECRET_MISSING`
- valid signature acceptance could not be tested because `RESEND_WEBHOOK_SECRET` is not configured in Vercel Production
- invalid signature rejection beyond the missing-secret guard could not be tested for the same reason
- provider event storage, duplicate webhook idempotency, and provider status update remain automated-test verified but not live-webhook verified on Vercel

Live webhook delivery is deferred until the Vercel Production deployment has `RESEND_WEBHOOK_SECRET` configured and Resend is pointed at the HTTPS webhook URL. No tunnel, Resend CLI, ngrok, or Cloudflare Tunnel is required for this phase.

## G2. Vercel HTTPS Email QA

Production alias:

- `https://risellar.vercel.app`

Fresh notification-only outbox rows:

- customer order template
- supplier order template
- reseller commission template
- finance-admin withdrawal template

Processor result:

- first protected invocation: `claimed=4`, `sent=4`, `retried=0`, `failed=0`, `skipped=0`
- outbox rows became `sent`
- provider message ids were stored
- Resend sent-message metadata was retrievable for all four messages
- all subjects began with `[DEV]`
- HTML body and plain-text fallback were present
- sensitive/private fields were not present in the outbox payload or Resend metadata scan
- all four sent messages used one recipient, consistent with redirect-mode behavior

CTA fix verification after deployment:

- commit `02c951ce2012b8102fb4e5ba1ec9cd8391a8e91c` added absolute CTA URL rendering from the configured app base URL
- customer CTA began with `https://risellar.vercel.app/`
- supplier CTA began with `https://risellar.vercel.app/`
- reseller CTA began with `https://risellar.vercel.app/`
- finance-admin CTA began with `https://risellar.vercel.app/`
- no relative-only `href` remained
- no localhost URL appeared
- no malformed double slash appeared
- query strings were preserved
- unsafe full/protocol-relative/script/data URL payloads are rejected by tests

Remaining blocker:

- valid signed webhook QA is blocked because the Vercel env-name listing still does not show `RESEND_WEBHOOK_SECRET`
- unsigned and fake invalid-signature webhook POSTs returned safe `RESEND_WEBHOOK_SECRET_MISSING`
- provider event count did not change for unsigned/invalid webhook checks
- Email Notifications Phase 1 is therefore not fully complete yet

Webhook redeploy update:

- after redeploy, the webhook route no longer returned `RESEND_WEBHOOK_SECRET_MISSING`
- `GET /api/resend/webhook` returned safe `405`
- unsigned webhook `POST` returned safe `401` / `INVALID_SIGNATURE`
- invalid signed webhook `POST` returned safe `401` / `INVALID_SIGNATURE`
- invalid webhook requests created no provider-event rows
- a correctly signed Standard Webhooks payload was accepted
- replaying the same signed payload was idempotent and did not create a duplicate provider-event row
- a signed `email.bounced` payload safely updated notification provider status only
- no business-state counts changed during signed webhook/replay/bounce checks
- Resend API metadata shows a webhook configured for the Risellar Vercel endpoint and subscribed to relevant email events

Live Resend delivery blocker:

- a fresh redirect-mode email was sent successfully after redeploy, but no real Resend-originated provider event arrived after polling
- a second fresh delivery probe was sent after confirming Resend webhook configuration, but no real provider event arrived after polling
- signed-route verification is passing, but live provider delivery is not yet verified
- final completion commit remains blocked until Resend-originated webhook delivery creates/stores at least one real provider event and updates notification status

Provider-originated webhook follow-up:

- Resend API showed exactly one webhook in the same workspace as the send API key
- endpoint matched `https://risellar.vercel.app/api/resend/webhook`
- webhook was enabled
- subscriptions included `email.sent`, `email.delivered`, `email.delivery_delayed`, `email.failed`, `email.bounced`, and `email.complained`
- a new deterministic notification-only QA email was sent through Risellar
- processor returned `claimed=1`, `sent=1`, `retried=0`, `failed=0`, `skipped=0`
- Resend email metadata was retrievable and reported `last_event=delivered`
- no provider-originated webhook row was stored after polling

Current blocker:

- the remaining missing proof is a real Resend-originated webhook delivery or dashboard replay that stores a non-synthetic provider event row
- do not commit the final verification report until that proof exists

## H. Commands Run

- `git status --short`
- `git rev-parse HEAD`
- `git branch --show-current`
- `git diff --name-status`
- `git diff --numstat`
- `git diff --summary`
- `git diff --check`
- `npx supabase --version`
- `npm install resend --save`
- `npm test -- tests/transactional-email-notifications.test.ts tests/resend-webhook.test.ts`
- `npm run typecheck`
- `npx supabase db push --dry-run --include-all`
- `npx supabase db push --include-all`
- `npx supabase db query --linked --file scripts/rpc/transactional-email-notification-outbox-tests-dev-only.sql`
- restart of the exact port `400` Risellar dev server
- unauthorised/invalid-secret HTTP checks for `/api/internal/notifications/process`
- protected processor invocation
- direct Resend provider configuration check without printing values
- missing-signature webhook route check

Results so far:

- focused notification tests passed
- typecheck passed after type fixes
- dry-run passed
- development migration apply passed
- SQL boundary test passed
- full `npm test` passed: 48 files / 284 tests
- `npm run lint` passed
- `npm run build` passed
- `npm run typecheck` passed
- `npx tsc --noEmit` passed
- focused post-hardening notification tests passed: 2 files / 11 tests
- local live redirect-mode email send did not pass due invalid `EMAIL_FROM`
- Vercel HTTPS redirect-mode processor sent four representative role-template emails
- Vercel HTTPS duplicate processor invocation sent no duplicates
- Vercel HTTPS email CTA verification failed because CTA links are relative paths
- Vercel HTTPS signed-route webhook QA passed after `RESEND_WEBHOOK_SECRET` was added and redeployed
- real provider-originated webhook QA remains blocked because no real Resend-originated provider event row was stored after a fresh delivered message
- runtime sweep passed for public/auth routes and notification endpoint method blocking after ignored `.next` cache was cleared
- protected role routes returned blocked states for signed-out access

Final provider-originated webhook follow-up verification:

- `https://risellar.vercel.app` returned HTTP `200`
- Resend API showed one enabled webhook for `https://risellar.vercel.app/api/resend/webhook` with the required subscriptions
- unsigned and invalid-signed webhook requests were rejected and created no provider-event rows
- one fresh redirect-mode QA email was sent and Resend metadata reported it delivered
- no real Resend-originated provider event was stored after polling
- final commit remains intentionally deferred until provider-originated webhook delivery or dashboard replay stores a real event

Real provider payload compatibility update:

- a real Resend `email.sent` webhook reached the deployed endpoint but returned HTTP `500`
- the safe payload shape did not include a top-level event `id`
- the webhook code incorrectly assumed synthetic-style `event.id` was available for provider-event deduplication
- the fix uses the verified `svix-id` header as the provider event identity and `data.email_id` as the Resend email/outbox match key
- `EMAIL_DEV_RECIPIENT` was corrected in Vercel so redirect-mode sends go to the approved development inbox value only
- final real provider replay and fresh provider-originated webhook proof still must pass after deployment of the fix

Fresh provider webhook proof after the compatibility fix:

- one fresh redirect-mode QA notification was processed successfully
- real provider-originated `email.sent` and `email.delivered` webhooks reached the deployed endpoint
- both real provider events were stored once for the fresh provider message
- the outbox status became `delivered`
- a follow-up ordering guard was added because Resend may deliver `email.sent` after `email.delivered`; the handler now records `email.sent` without downgrading outbox status

Final production HTTPS provider-originated QA:

- the ordering guard was deployed to Vercel Production
- a fresh notification-only QA email was processed in redirect mode
- the processor claimed and sent exactly one row with no retries, failures, or skips
- the provider message ID was stored
- real provider-originated `email.sent` and `email.delivered` webhooks reached the deployed endpoint
- both events were stored exactly once using verified `svix-id` identities
- the outbox remained `delivered` / provider status `delivered`
- a delayed duplicate check still showed two provider-event rows and two distinct event identities
- no HTTP `500` appeared in the observed Vercel webhook logs after the deployed fix
- original failed-event dashboard replay was not available to Codex, so the final passing proof is the fresh real provider-originated event pair

## I. Secret/Safety Status

- `.env.local` ignored and not staged
- no secret values printed
- no recipient addresses included in reports
- no email previews committed
- `.next` ignored
- `supabase/.temp` ignored
- `.codex-dev-server.*.log` ignored
- no production Supabase connection used
- scoped notification source scan found no Resend secrets, webhook secrets, processor secrets, service-role imports in client areas, or notification-side business table mutations
- `.env.local` was not committed
- `.codex-dev-server.*.log` files remained ignored and unstaged

## J. Completion Status

Email Notifications Phase 1 is partially complete:

- backend/outbox/server routes/templates/tests are implemented
- development migration and SQL boundary test passed
- automated verification passed
- Vercel HTTPS processor send path passed for customer, supplier, reseller, and finance-admin templates
- duplicate-send prevention passed on Vercel HTTPS
- CTA-link fix was committed, pushed, deployed, and verified with fresh sent messages
- final live provider-originated send/delivery QA passed on Vercel HTTPS after the real payload compatibility and ordering fixes
- signed-route replay and bounce/failure QA passed earlier
- dashboard replay of the original failed Resend delivery remains a manual dashboard-only check from Codex, but fresh real provider-originated webhook delivery is now proven
