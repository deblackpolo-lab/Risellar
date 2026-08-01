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

- blocked

Presence-only env result:

- `RESEND_API_KEY`: present
- `EMAIL_FROM`: present
- `EMAIL_SEND_MODE`: present and set to `redirect`
- `EMAIL_DEV_RECIPIENT`: present
- `NOTIFICATION_PROCESSOR_SECRET`: present
- `NEXT_PUBLIC_APP_URL`: present

No values were printed. `.env.local` was not edited or staged.

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

## G. Webhook QA

Automated webhook verification passed:

- raw body is verified before processing
- invalid signature returns safe rejection
- provider replay is idempotent
- delivery status updates notification status only
- no business data mutation occurs

HTTP route check:

- missing local webhook secret currently returns safe `RESEND_WEBHOOK_SECRET_MISSING`

Live webhook delivery is explicitly deferred until a Vercel Preview or production HTTPS URL exists. No tunnel, Resend CLI, ngrok, or Cloudflare Tunnel is required for this phase.

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
- full `npm test` passed: 48 files / 279 tests
- `npm run lint` passed
- `npm run build` passed
- `npm run typecheck` passed
- `npx tsc --noEmit` passed
- focused post-hardening notification tests passed: 2 files / 11 tests
- live redirect-mode email send did not pass due invalid `EMAIL_FROM`
- runtime sweep passed for public/auth routes and notification endpoint method blocking after ignored `.next` cache was cleared
- protected role routes returned blocked states for signed-out access

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
- live Resend QA is blocked by invalid `EMAIL_FROM` sender format and unresolved verified recipient emails for selected role profiles
- commit/push is deferred until live email QA passes
