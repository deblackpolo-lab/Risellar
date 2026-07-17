# Risellar Backend Auth Role Foundation Report

## A. Recommended Clerk configuration

- Enable Clerk Google OAuth for sign-up and sign-in.
- Enable Clerk email/password for sign-up and sign-in.
- Do not enable phone OTP for MVP auth.
- Keep Clerk phone fields optional and profile-oriented only if used later; Risellar should collect phone and WhatsApp numbers in onboarding/profile flows, not as a verified login factor now.
- Store Clerk identity in the future backend through a trusted profile mapping keyed by `clerk_user_id`.
- Treat Clerk public metadata role claims as convenience/session hints only. Authoritative roles and permissions must come from the backend profile, supplier staff, and admin staff records.
- Assign admin access manually through backend/admin tooling later. Do not allow self-selected admin roles during sign-up.
- Use Resend later for transactional app notifications, not custom login links.

## B. Sign-up/sign-in methods

Approved now:

- Google login through Clerk.
- Email/password registration through Clerk.
- Email/password login through Clerk.

Not approved now:

- Phone OTP login.
- Custom email magic-link login owned by Risellar.
- Resend-powered auth links.

## C. Role model

Frontend-safe role types were added in `lib/auth/role-policy.ts`:

- `customer`: buys through reseller shops, completes checkout, tracks orders, opens support/disputes/returns.
- `reseller`: completes reseller onboarding, browses approved products, manages shop/listings, views orders, commissions, wallet, insights, promotions, and support.
- `supplier_owner`: owns supplier workspace, manages products, inventory, orders, settlements, finance, promotions, team, support, settings, and supplier onboarding.
- `supplier_inventory_manager`: supplier staff role limited to product, stock, restock, inventory activity, and order preparation flows.
- `admin`: accesses admin dashboard, operations, risk, product/supplier/reseller/customer review, finance queues, support, audit logs, and settings.

Backend enforcement still must happen later through database/RLS/service-layer authorization. The frontend policy file is a planning/types foundation only.

## D. Profile onboarding fields

Customer:

- Full name
- Email
- Phone
- WhatsApp number
- City/area
- Delivery address

Reseller:

- Full name
- Email
- Phone
- WhatsApp number
- Reseller type
- Shop name
- City/area
- Mobile money name
- Mobile money number
- Reseller rules acceptance

Supplier owner:

- Full name
- Email
- Phone
- WhatsApp number
- Business name
- Business type
- Primary category
- Location
- Verification documents
- Payout account
- Supplier agreement acceptance

Supplier inventory manager:

- Full name
- Email
- Phone
- WhatsApp number
- Assigned supplier/business reference

Admin:

- Full name
- Email
- Admin role assigned by trusted backend/admin process

## E. Protected route list

Planned protected route policies:

- `/checkout/account`: customer auth/profile entry before order placement.
- `/checkout/delivery`: authenticated customer profile required.
- `/checkout/payment`: authenticated customer required; Pay on Delivery only for now.
- `/checkout/review`: authenticated customer required before final order review.
- `/checkout/success`: authenticated customer order result.
- `/customer/:slug*`: customer-only order, support, return, refund, and dispute history.
- `/reseller/onboarding/:slug*`: signed-in reseller onboarding.
- `/reseller/:slug*`: completed reseller workspace.
- `/supplier/onboarding/:slug*`: signed-in supplier owner onboarding and approval states.
- `/supplier/inventory-manager/:slug*`: supplier inventory manager workspace only.
- `/supplier/:slug*`: supplier owner workspace.
- `/admin/:slug*`: admin-only workspace.

Important ordering note for future middleware: `/supplier/inventory-manager/:slug*` must be checked before the broader `/supplier/:slug*` policy.

## F. Public route list

Planned public route policies:

- `/`: current frontend shell/reviewer entry.
- `/preview`: internal frontend QA launcher, public only for the current mock-review phase.
- `/design-system`: design system gallery, public only for the current mock-review phase.
- `/shop/:shopSlug`: public reseller shop.
- `/shop/:shopSlug/product/:productId`: public reseller product page.
- `/checkout/cart`: public cart surface until account step; backend order creation must require auth later.
- `/edge-cases/:slug*`: mock edge-state gallery for QA.

## G. Role redirect rules

- Customer not started: `/checkout/account`
- Customer in progress: `/checkout/delivery`
- Customer pending review: `/checkout/account`
- Customer complete: `/customer/orders`
- Reseller not started: `/reseller/onboarding/welcome`
- Reseller in progress: `/reseller/onboarding/profile`
- Reseller pending review: `/reseller/onboarding/complete`
- Reseller complete: `/reseller/dashboard`
- Supplier owner not started: `/supplier/onboarding/welcome`
- Supplier owner in progress: `/supplier/onboarding/business`
- Supplier owner pending review: `/supplier/onboarding/pending`
- Supplier owner complete: `/supplier/dashboard`
- Supplier inventory manager not started/in progress/pending review: `/supplier/inventory-manager/settings`
- Supplier inventory manager complete: `/supplier/inventory-manager/dashboard`
- Admin any onboarding state: `/admin/dashboard`

## H. Phone number strategy now/later

Now:

- Collect phone and WhatsApp numbers during onboarding/profile.
- Use phone numbers as contact and fulfillment data only.
- Do not verify phone through OTP.
- Do not use phone as the primary login credential.
- Keep customer checkout copy aligned with the existing mock statement that no phone OTP is required.

Later:

- Add verification only if product, risk, delivery, or compliance needs justify it.
- If phone verification is added, model it separately from Clerk email/password and Google auth decisions.
- Continue to use Resend for app notifications, not login-link ownership.

## I. Required environment variable names only

Client/runtime:

- `NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY`
- `NEXT_PUBLIC_CLERK_SIGN_IN_URL`
- `NEXT_PUBLIC_CLERK_SIGN_UP_URL`
- `NEXT_PUBLIC_CLERK_AFTER_SIGN_IN_URL`
- `NEXT_PUBLIC_CLERK_AFTER_SIGN_UP_URL`

Server/backend later:

- `CLERK_SECRET_KEY`
- `CLERK_WEBHOOK_SECRET`
- `CLERK_JWT_ISSUER`
- `CLERK_JWT_AUDIENCE`

No values were added.

## J. Files changed

- `lib/auth/role-policy.ts`: added frontend-safe role types, onboarding field lists, public/protected route policy plans, and default redirect helper.
- `tests/auth-role-foundation.test.ts`: added coverage for role list, phone-as-profile-data strategy, public/protected route separation, and redirect rules.
- `docs/RISELLAR_BACKEND_AUTH_ROLE_FOUNDATION_REPORT.md`: added this backend auth/role foundation report.

## K. Tests run

- `npm test`: passed after running `npm ci`; 17 test files passed, 71 tests passed.
- `npm run typecheck`: passed.
- `npm run lint`: passed with `--max-warnings=0`.
- `npm run build`: passed; Next generated 160 static pages.

Additional setup command:

- `npm ci`: completed from the lockfile. It reported audit findings, but no `npm audit fix --force` was run.

Initial `npm test` before dependency install failed because `vitest` was not installed in the fresh worktree.

## L. Current git status

Before staging/commit, the branch status was:

```text
## backend/auth-role-foundation...origin/main
?? lib/auth/
?? tests/auth-role-foundation.test.ts
```

After this report is added, expected untracked files are:

```text
docs/RISELLAR_BACKEND_AUTH_ROLE_FOUNDATION_REPORT.md
lib/auth/role-policy.ts
tests/auth-role-foundation.test.ts
```

No Supabase migrations, secrets, `.env`, `.env.local`, payment/storage/email integrations, or backend mutations were added.
