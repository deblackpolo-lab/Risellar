# Risellar Dispute D12 Notification QA Report

Date: 2026-08-02

## D11 Baseline Rechecked

D12 reran:

- `scripts/rpc/dispute-notifications-d11-tests-dev-only.sql`: 50 assertions passed
- `scripts/rpc/dispute-notifications-d11-concurrency-dev-only.mjs`: 10 scenarios and 13 invariant checks passed

Verified backend notification behavior:

- One logical outbox event per intended role.
- Duplicate processor/concurrency paths do not create duplicate sends.
- Customer, supplier, reseller, finance, and support/admin template payloads are role-safe at the backend/test level.
- Notification processing does not mutate orders, payments, settlements, commissions, wallets, withdrawals, delivery, stock, or reservations.

## Redirect Mode and Recipient Caveat

Email Notifications Phase 1 remains in redirect mode. D12 did not switch `EMAIL_SEND_MODE` to live and did not send to real application recipients.

D11 caveat remains unresolved: no real verified support/dispute-admin recipient was available. The support/admin template delivery previously used an active verified finance-admin profile with `recipient_role = support_admin`; D12 does not count that as proof of a real support/dispute-admin authenticated browser session.

## Production Webhook/API Safety

Production API checks:

- Notification processor GET blocked with method-not-allowed behavior.
- Unauthorized processor POST blocked.
- Resend webhook GET blocked with method-not-allowed behavior.
- Unsigned webhook POST blocked.

No provider payloads, secrets, email addresses, or identifiers were printed.
