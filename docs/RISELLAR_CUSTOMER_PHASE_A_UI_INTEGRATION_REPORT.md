# Risellar Customer Phase A UI Integration Report

Date: 2026-07-18

## A. Summary

Customer Phase A UI integration was added for customer contact and delivery address management. The implementation connects a new protected customer address/contact setup page to the proven Customer Phase A RPCs only.

Checkout, order creation, stock reservation, payments, delivery quotes, settlements, commissions, withdrawals, and customer purchase flow remain unconnected.

## B. Routes/pages connected

- `/customer/addresses`

The route renders a customer account setup screen for contact details and delivery addresses. It is separate from checkout and does not submit an order.

## C. Server actions/helpers created

Created:

- `lib/customer/profile-address.ts`
- `app/customer/addresses/actions.ts`
- `app/customer/addresses/page.tsx`
- `components/customer/customer-profile-address-screens.tsx`

Server actions use a signed-in Clerk session, require the current synced profile, request the default Clerk session token, and call the Customer Phase A RPCs through the user-context Supabase client.

RPCs used:

- `upsert_customer_contact`
- `get_customer_delivery_addresses`
- `create_customer_delivery_address`
- `update_customer_delivery_address`
- `archive_customer_delivery_address`

## D. Contact behavior

The contact form accepts:

- full name
- email, optional
- phone
- WhatsApp, optional

Required values are validated before calling the contact RPC. Phone and WhatsApp are stored for account setup only; OTP verification is not enabled yet.

## E. Address behavior

The address UI supports:

- create delivery address
- update delivery address
- archive delivery address
- mark an address as default when supported by the RPC
- list saved addresses for the signed-in customer

Required address fields are validated before RPC calls.

## F. Security/scope protections

- No client component writes directly to customer tables.
- No service role key is imported in app/components.
- No `createSupabaseAdminClient` usage was added to app/components.
- Customer contact/address writes go through tested RPCs only.
- The UI does not expose role mutation or profile role escalation.
- Checkout/order/stock/payment/delivery/commission/settlement/withdrawal flows were not connected.
- Existing reseller browser session was blocked from customer address access and redirected back to `/reseller/dashboard`.

## G. Manual QA result

Automated browser/session state:

- Dev server was already running on `http://localhost:400`.
- The accessible in-app browser session was signed in as the approved reseller account.
- Navigating to `/customer/addresses` from that reseller session redirected back to `/reseller/dashboard`, confirming the route was not usable from the reseller session.
- A no-cookie HTTP check for `/customer/addresses` returned a protected/non-page response rather than loading the page.

Signed-in customer browser QA was later completed with a development customer test account.

Live browser QA result:

- `/auth/qa-profile-sync` loaded and showed:
  - profile row created or found
  - Clerk user id stored
  - email stored
  - default role `customer`
  - account status `active`
- `/customer/addresses` loaded for the signed-in customer.
- Contact save succeeded with the UI status `Contact details saved.`
- Delivery address create succeeded with the UI status `Delivery address created.`
- The created address appeared as `QA Home` and was marked default.
- Delivery address update succeeded with the UI status `Delivery address updated.`
- The updated address appeared as `QA Home Updated`.
- Delivery address archive succeeded.
- After archive, the saved address list returned to `0 saved`.

Read-only development Supabase verification:

- Contact marker was saved on an active customer profile.
- Archived QA address belonged to the same customer profile/customer row.
- Active QA address count after archive was `0`.
- QA address markers were not found on another customer.
- Recent orders for the QA customer: `0`.
- Recent stock reservations for the QA customer: `0`.
- Recent delivery quotes for the QA customer: `0`.
- `public.payments` table was not present.

## H. Tests added/updated

Added:

- `tests/customer-profile-address.test.ts`

Coverage includes:

- contact required-field validation
- address required-field validation
- contact RPC call mapping
- address create/update/archive/list RPC call mapping
- default address payload handling
- safe error mapping
- service role exclusion from Customer Phase A UI code
- checkout/order/payment/delivery integration exclusion from Customer Phase A UI code

## I. Commands run/results

- `git status --short` - showed new untracked Customer Phase A UI files.
- `npm test -- tests/customer-profile-address.test.ts` - passed, 6 tests.
- `git diff --check` - passed.
- `npm test` - passed, 29 files and 151 tests.
- `npm run lint` - passed with zero warnings.
- `npm run build` - passed; `/customer/addresses` appears in the Next route list.
- `npm run typecheck` - passed.
- HTTP route check for `/customer/addresses` without browser session cookies returned protected/non-page response.
- In-app browser route check from the signed-in reseller session redirected to `/reseller/dashboard`.
- Browser QA after customer sign-in:
  - `/auth/qa-profile-sync` confirmed default role `customer`.
  - `/customer/addresses` loaded.
  - contact save succeeded.
  - delivery address create/update/archive succeeded.
- Read-only linked development Supabase query confirmed Customer Phase A rows and zero recent order/stock/delivery side effects for the QA customer.

## J. Secret/scope scan result

- `.env.local` is ignored and not staged.
- `supabase/.temp` is ignored.
- `.next` is ignored.
- `.codex-dev-server.*.log` is ignored.
- No `SUPABASE_SERVICE_ROLE_KEY` reference exists in `app/` or `components/`.
- No `createSupabaseAdminClient` reference exists in `app/` or `components/`.
- Secret-name references found in existing docs/tests are documentation or negative assertions, not committed secret values.
- No bearer tokens, passwords, API secrets, or production data were added.
- New Customer Phase A UI code does not add checkout/order/stock/payment/delivery mutation integration.

## K. Files changed

- `app/customer/addresses/actions.ts`
- `app/customer/addresses/page.tsx`
- `components/customer/customer-profile-address-screens.tsx`
- `lib/customer/profile-address.ts`
- `tests/customer-profile-address.test.ts`
- `docs/RISELLAR_CUSTOMER_PHASE_A_UI_INTEGRATION_REPORT.md`

## L. Current git status

Pending local changes:

- modified `components/auth/AccountSignOutButton.tsx`
- untracked `app/customer/addresses/`
- untracked `components/customer/customer-profile-address-screens.tsx`
- untracked `lib/customer/`
- untracked `tests/customer-profile-address.test.ts`
- untracked `docs/RISELLAR_CUSTOMER_PHASE_A_UI_INTEGRATION_REPORT.md`

## M. Whether safe to commit

Automated tests, lint, build, typecheck, scope scans, and signed-in customer browser QA passed. The implementation is safe to commit as a Customer Phase A UI foundation.

The separate `AccountSignOutButton` change is present locally because the reseller QA session needed a working Clerk sign-out path before switching accounts. Keep it staged separately if committing Customer Phase A only.
