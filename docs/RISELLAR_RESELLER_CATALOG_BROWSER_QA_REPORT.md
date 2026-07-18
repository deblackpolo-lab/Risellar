# Risellar Reseller Catalog Browser QA Report

Date: 2026-07-18

## A. Summary

Browser/manual QA was run against the local app on `http://localhost:400` using the approved development reseller account. The active profile sync route showed the signed-in profile role as `reseller` and `account_status = active`.

The reseller approved product catalog loaded through `/reseller/products`, displayed an approved active development product, and exposed reseller-safe product fields only. The product detail route loaded for the approved product and kept add-to-shop disabled/deferred.

No checkout, customer catalog, public shop, orders, stock reservation, payments, delivery, settlements, commissions, withdrawals, reseller checkout, or reseller shop write flow was connected during this QA pass.

## B. Account And Route Context

- QA account: approved development reseller account; credentials were not printed or stored.
- Profile route checked: `/auth/qa-profile-sync`
- Observed role signal: `reseller`
- Observed account status: `active`
- Dev server: `http://localhost:400`

## C. Product List Result

Route checked: `/reseller/products`

Result: page loaded for the approved reseller account.

Observed visible product:

- `Risellar Admin Approval QA Approve Target 20260718132814`
- Category: `QA Test`
- Approval/status signals: `approved`, `active`
- Reseller-safe pricing shown:
  - `Max customer price`
  - `Reseller cost`
- Stock signal shown: `Low stock`
- Product image/thumbnail rendered as a placeholder image.

List-page negative checks:

- `pending`: not visible
- `rejected`: not visible
- `archived`: not visible
- supplier base price/internal fields: not visible
- supplier contact/payout/admin/internal fields: not visible
- checkout/payment/order/reservation text or actions: not visible

## D. Product Detail Result

Route checked:

- `/reseller/products/54d1f228-3eb9-4ae2-9e9c-eb7c36899c33`

Result: detail page loaded.

Observed safe product information:

- Product name
- Supplier display name
- Description
- Category
- Reseller cost
- Max customer price
- Currency
- Available stock
- Product status
- Approval status
- Product image/gallery placeholder

Add-to-shop state:

- Button text: `Add to shop planned`
- Button state: disabled
- Safety copy states the page does not create listings, reserve stock, or start checkout.

## E. Sensitive Field Review

The browser-visible list and detail pages did not expose:

- supplier base price
- supplier contact phone
- payout details
- `admin_notes`
- `internal_notes`
- settlement data
- commission data
- withdrawal data
- service role references

The detail page includes only explicit safety copy that no checkout or stock reservation is triggered.

## F. Route Protection

Observed:

- Approved reseller account can access `/reseller/products`.
- Approved reseller account can access the product detail route.

Not completed in this browser session:

- Supplier-account denial was not browser-retested because the active browser session was the reseller account.
- An unauthenticated HTTP probe to `/reseller/products` returned `404` instead of a clear Clerk redirect signal, so no redirect claim is made from that probe.

Existing supporting evidence:

- Reseller catalog RPC boundary tests already passed.
- Prior role route-access QA covered non-reseller/supplier isolation.

## G. Scope Checks

Confirmed by source scan:

- No reseller catalog RPC references were found in checkout/customer/shop route trees.
- `get_reseller_approved_products` remains scoped to reseller catalog helper/tests.
- Add-to-shop/write flow remains disabled/deferred.

No live integrations were started for:

- checkout
- customer catalog
- public shop
- orders
- stock reservation
- payments
- delivery
- settlements
- commissions
- withdrawals
- reseller checkout
- reseller shop write flows

## H. Issues And Fixes

Issue encountered before QA:

- The in-app browser could not switch accounts because admin/customer screens lacked a real Clerk sign-out path.

Fix already applied locally but not committed:

- Admin and QA profile screens now expose a real Clerk-backed logout/sign-out control.

Browser QA issue:

- Supplier-account route-denial was not retested in this session because doing so would require switching away from the approved reseller browser session.

## I. Commands Run And Results

Commands run before/report creation:

- `git status --short` - working tree had existing uncommitted sign-out support changes.
- `Invoke-WebRequest http://localhost:400/` - returned `HTTP 200`.
- Browser `/auth/qa-profile-sync` - showed `reseller` and `active`.
- Browser `/reseller/products` - loaded approved reseller catalog.
- Browser product detail route - loaded safe detail view.
- `rg` source scan for reseller catalog RPC references in checkout/customer/shop flows - no matches.

Full verification commands are run after this report update and should be read with the final QA handoff.

## J. Secret Scan Result

Secret scan is run after this report update. Expected scope:

- `.env.local` remains ignored and not staged.
- `supabase/.temp/` remains ignored.
- `.codex-dev-server.*.log` remains ignored.
- No real Clerk/Supabase/service-role values in docs/source.
- No service role in app/components.
- No bearer tokens, passwords, API secrets, or production data.

## K. Current Git Status

At report creation time, the working tree already contained local sign-out support changes plus this new report. No commit was created.

## L. Safe To Commit

The reseller catalog browser QA report is safe to commit after the requested full verification and secret scan pass. The local sign-out support changes are separate but useful for QA account switching and should be committed only when explicitly requested.
