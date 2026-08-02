# Risellar Disputes D11 Notification Privacy Review

## Summary

D11 notification templates and payloads are role-shaped and privacy-minimal. They use the existing email sanitizer and add stricter blocking for address and reference-like fields.

## Payload Rules

Allowed payload shape is limited to safe display fields such as:

- safe order reference
- safe item or product label
- safe status label
- safe amount and currency where the recipient is allowed to know it
- relative CTA path

Blocked payload fields include:

- recipient email
- phone or WhatsApp
- address
- customer private text
- supplier private response
- admin internal notes
- payment or refund references
- payout data
- settlement internals
- commission internals except safe reseller/finance events
- provider payloads
- tokens, cookies, and secrets

## Role Privacy

Customer emails do not expose supplier private responses, reseller commission, settlement context, payout data, or internal finance notes.

Supplier emails do not expose unrelated customer account details, other suppliers' disputes, reseller wallet data, or finance-only notes.

Reseller emails do not expose customer complaint bodies, supplier responses, refund payment references, or settlement internals.

Support/admin emails remain operational and avoid raw private notes, raw payment references, and provider payloads.

Finance emails are limited to finance-safe workflow status and do not include bank, Mobile Money, provider payload, or secret data.

## CTA Safety

Templates continue to use the existing absolute CTA helper. D11 default CTA paths are relative paths only, and full payload URLs remain rejected by tests.

## Verification

- Type-level tests render every D11 event in HTML and text.
- Redirect-mode subjects begin with `[DEV]`.
- Unsafe payload keys are omitted from rendered email content.
- D11 SQL boundary tests assert no recipient email, phone, address, private note, or reference fields are stored in outbox payloads.
- Existing webhook tests remain compatible with the expanded event catalog.
