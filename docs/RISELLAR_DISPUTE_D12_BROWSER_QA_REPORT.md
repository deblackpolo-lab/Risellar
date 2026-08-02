# Risellar Dispute D12 Browser QA Report

Date: 2026-08-02

## Production Browser Smoke

Checked with the Codex in-app browser:

- `https://risellar.vercel.app/`: loaded without horizontal overflow, but showed a Phase 1 design foundation shell.
- `https://risellar.vercel.app/shop/not-a-real-shop`: loaded safe unavailable/empty-state public shop UI without horizontal overflow.

Checked with HTTP header sweep:

- `/`: HTTP 200
- `/sign-in`: HTTP 200
- `/sign-up`: HTTP 200
- `/shop/not-a-real-shop`: HTTP 200 safe unavailable state
- `GET /api/internal/notifications/process`: HTTP 405
- `POST /api/internal/notifications/process` without authorization: HTTP 401
- `GET /api/resend/webhook`: HTTP 405
- `POST /api/resend/webhook` unsigned: HTTP 401

Protected role routes in the production header sweep returned safe non-content responses, but not the expected full Clerk redirect proof needed for MVP release. The production root also still describes the app as design-shell-only, so production browser activation is blocked.

## Local Source Route Inventory

Live/RPC-backed or previously verified surfaces include:

- Customer address/contact and order-history reads
- Checkout draft/order confirmation backend/UI phases through approved scope
- Supplier order decision, preparation, delivery, payment-reported, and finance read surfaces
- Reseller dashboard, wallet, earnings, withdrawals, product catalog, listing/add-to-shop, and public read-only shop
- Admin product approval, settlement verification, withdrawal review, finance dashboard, and notification APIs

Mock-only or UI-pending D12 surfaces include:

- Customer support tickets and several dispute/return/refund detail pages that render `support-disputes` mock screens
- Supplier support dispute/return pages that render mock screens
- Reseller commission-dispute support pages that render mock screens
- Admin disputes, returns, refunds, and support ticket routes that render mock support/dispute screens

## Browser QA Decision

Browser evidence is sufficient for existing live finance/order/dashboard/notification surfaces from prior phase reports plus D12 route smoke. Browser evidence is not sufficient to activate the D12 dispute/return/refund/support workflow UI because required screens remain mock-only and support/super-admin QA identities are unavailable.
