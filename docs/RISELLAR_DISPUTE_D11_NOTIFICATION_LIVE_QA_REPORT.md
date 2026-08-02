# Risellar Disputes D11 Notification Live QA Report

## Status

D11 live redirect-mode email QA passed on the Vercel Production deployment connected to the confirmed DEVELOPMENT Supabase project.

## Deployment

- D1-D11 commit range was pushed to `origin/main`.
- Latest pushed commit: `f8c3aee0 Add dispute and finance notifications`.
- GitHub deployment metadata shows a successful Vercel Production deployment for commit `f8c3aee091523d2d49a6f87fec381fcf47c75ea1`.
- `https://risellar.vercel.app` returned HTTP `200`.
- No production Supabase project was used.

## Environment Presence

Presence was confirmed without printing values:

- `NEXT_PUBLIC_APP_URL`
- `RESEND_API_KEY`
- `EMAIL_FROM`
- `EMAIL_SEND_MODE`
- `EMAIL_DEV_RECIPIENT`
- `NOTIFICATION_PROCESSOR_SECRET`
- `RESEND_WEBHOOK_SECRET`

`EMAIL_SEND_MODE` remained `redirect`.

## QA Events

Five fresh deterministic notification-only D11 QA outbox rows were created for:

- customer: dispute information requested
- supplier: return inspection required
- reseller: commission hold created
- support/admin: new dispute
- finance-admin: refund verification required

All selected recipients had verified Clerk primary emails. The development database had active `finance_staff` admin rows but no active verified `admin` or `support_staff` bucket available, so the support/admin template was tested with an active verified finance-admin profile while preserving `recipient_role = 'support_admin'`.

## Send Result

- Production processor endpoint accepted the protected request.
- The new D11 QA rows were reached after older pending development outbox rows were drained.
- D11 QA outbox result: 5 rows sent/delivered, 0 failed, 0 skipped.
- Provider message IDs were stored for all 5 rows.
- `sent_at` was populated for all 5 rows.
- Resend metadata confirmed all 5 messages were redirected to the configured development recipient.
- Resend metadata confirmed all 5 subjects began with `[DEV]`.
- HTML and plain-text bodies were present for all 5 messages.

## CTA And Privacy

- All 5 email bodies contained CTA links using `https://risellar.vercel.app/`.
- No `localhost`, unsafe protocol, bearer token, secret, password, or cookie marker appeared in the scanned bodies.
- Customer, supplier, reseller, support/admin, and finance-admin bodies did not expose private supplier notes, admin-private notes, payment references, payout data, platform margin, reseller margin, bank details, Mobile Money data, or provider payloads.
- Outbox payload privacy scan passed; no recipient email, phone, address, secret, token, password, private, payout, margin, commission, or settlement fields were present.

## Duplicate And Webhook Result

- A follow-up production processor call returned `claimed = 0`, `sent = 0`, `failed = 0`, `skipped = 0`.
- No duplicate provider send occurred for the D11 QA rows.
- Real provider-originated `email.sent` webhooks were stored for all 5 provider message IDs.
- Real provider-originated `email.delivered` webhooks were stored for all 5 provider message IDs.
- Outbox provider status settled at `delivered` for all 5 rows.
- Provider-event storage used unique verified provider event identities and matched the stored provider message IDs.
- Dashboard replay was not available to Codex, but replay/idempotency remains covered by the automated webhook tests and unique provider-event storage.

## Business Side Effects

Notification QA created only controlled notification outbox/provider-event records.

Count comparison found no changes to:

- orders
- order items
- payments
- supplier settlements
- reseller commissions
- reseller wallets
- reseller withdrawals
- disputes
- return requests
- refund requests
- finance holds
- reseller liabilities
- withdrawal commission allocations
- products
- stock reservations
- inventory movements
- delivery arrangements

## Verification

- `git diff --check`: passed
- D11 SQL suite: 50 passed, 0 failed
- D11 concurrency harness: 10 scenarios, 13 invariant checks passed
- focused notification/webhook tests: 2 files, 23 tests passed
- `npm test`: 48 files, 292 tests passed
- `npm run lint`: passed
- `npm run build`: passed
- `npm run typecheck`: passed
- `npx tsc --noEmit`: passed

## Safety

- `.env.local` remained ignored and unstaged.
- `supabase/.temp` remained ignored.
- `.next` remained ignored.
- `.codex-dev-server.*.log` remained ignored.
- No secrets, environment values, recipient emails, provider payloads, profile IDs, supplier IDs, or private database identifiers were printed in reports.
- No business mutation path was added to the notification processor or webhook handling.

## Completion

D11 notification live redirect-mode QA is complete. D12 may begin after the final live-QA report commit is pushed.
