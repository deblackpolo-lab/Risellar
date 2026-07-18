# Risellar Admin Product Approval Browser QA Report

## A. Admin Browser Access Result

Browser QA was completed on July 18, 2026 against the confirmed development Supabase project named `Risellar`.

The dev server was running on:

- `http://localhost:400`

The browser session was signed in with the development admin test account. The profile itself remains `primary_role = customer`; admin access is granted through `public.admin_staff`, as intended.

`/auth/qa-profile-sync` result:

- profile row: created or found
- Clerk user id stored: yes
- email stored: yes
- display name stored: yes
- default profile role: customer
- account status: active

Admin route access result:

- `/admin/products` loaded successfully
- `/admin/operations/product-approvals` loaded successfully

## B. Product Queue/List Result

Both fake, development-only supplier products appeared in the admin product approval queue before review:

- `Risellar Admin Approval QA Approve Target 20260718132814`
- `Risellar Admin Approval QA Reject Target 20260718132814`

The queue showed:

- supplier info: `Dev Supplier Activation QA`
- category: `QA Test`
- base price: `GHS 77.77` and `GHS 88.88`
- stock quantity: `3` and `2`
- image count: `0`
- status badges: `pending_review` / `pending_approval`

The queue also stated that approved products are not connected to customer or reseller catalogs yet.

## C. Product Detail Result

Both product detail pages loaded for the admin account.

The detail UI showed:

- product name
- supplier
- category
- base price
- stock quantity
- submitted/updated timestamps
- product description
- review notes field
- `Approve` and `Reject` buttons

The UI did not expose direct product status fields. The detail page explicitly states approval updates must go through `review_supplier_product`.

## D. Approve Result

Approved through the browser UI:

- product: `Risellar Admin Approval QA Approve Target 20260718132814`
- product id: `54d1f228-3eb9-4ae2-9e9c-eb7c36899c33`
- review note: development-only QA approve note

Development Supabase verification:

- `approval_status = approved`
- `product_status = active`
- `approved_by_profile_id = 50c02a70-be36-4d58-a206-103b44da7aef`
- `approved_at` is set
- `rejection_reason = null`
- `created_by_profile_id = e4daceac-478b-4ce5-8b5b-e85799e04532`

The approval actor differs from the product creator, confirming the supplier did not self-approve.

## E. Reject Result

Rejected through the browser UI:

- product: `Risellar Admin Approval QA Reject Target 20260718132814`
- product id: `587f897c-6b86-4bf5-b93b-90e4685e53f6`
- review note: development-only QA reject note

Development Supabase verification:

- `approval_status = rejected`
- `product_status = rejected`
- `approved_by_profile_id = null`
- `approved_at = null`
- `rejection_reason = Development-only admin browser QA reject`
- `created_by_profile_id = e4daceac-478b-4ce5-8b5b-e85799e04532`

## F. Supabase Row Verification

Read-back query verified both browser actions:

- approve target moved from `pending_review` / `pending_approval` to `approved` / `active`
- reject target moved from `pending_review` / `pending_approval` to `rejected` / `rejected`
- approval actor/review timestamp are set where the schema supports them for approval
- rejection stores the review note in `rejection_reason`

The admin queue reloaded after review and showed:

- `0 Pending`
- approved target: `approved` / `active`
- rejected target: `rejected` / `rejected`

## G. Audit Log Verification

Audit logs were created for both browser review actions.

Read-back query found two `review_supplier_product` audit rows:

- approve target audit row with actor profile `50c02a70-be36-4d58-a206-103b44da7aef`
- reject target audit row with actor profile `50c02a70-be36-4d58-a206-103b44da7aef`

Audit table details:

- `target_entity_type = products`
- `target_entity_id` matches each reviewed product id
- `action = review_supplier_product`
- `reason` stores the development-only review note

The audit rows record `actor_role = customer` because the admin test profile's primary profile role remains customer. Admin authority comes from active `admin_staff`, not `profiles.primary_role`.

## H. Non-Admin Block Result

Passed.

Before admin sign-in, the accessible browser session was `supplier_owner`. In that session:

- `/auth/qa-profile-sync` showed `Default role = supplier_owner`
- navigating to `/admin/products` redirected to `/supplier/dashboard`

This confirmed the supplier/non-admin session could not reach the admin product approval route.

RPC boundary tests also previously verified:

- supplier owner cannot self-approve product
- customer/reseller cannot approve or reject products
- active admin-staff context is required for review

## I. Security/Scope Checks

Confirmed:

- browser UI uses the admin server action and audited `review_supplier_product` RPC
- no direct client product status update is exposed
- no service role is used in `app` or `components`
- supplier self-approval remains blocked
- no checkout, customer catalog, reseller catalog, orders, stock reservation, settlements, commissions, payments, delivery, or reseller shop flows were connected
- production Supabase was not connected
- production data was not used
- no migrations were applied during this browser QA pass
- no destructive reset command was run
- `.env.local` was not committed

## J. Commands Run/Results

- browser open `/auth/qa-profile-sync` - passed; admin test profile found, role remained customer
- browser open `/admin/products` - passed; queue loaded
- browser open `/admin/operations/product-approvals` - passed; queue loaded
- browser approve target detail - passed; submitted `Approve`
- browser reject target detail - passed; submitted `Reject`
- `npx supabase db query --linked "<product read-back query>"` - passed; approval/rejection states verified
- `npx supabase db query --linked "<audit log read-back query>"` - passed; two audit rows found

Repository verification:

- `git status --short` - working tree contains report updates and `.gitignore`
- `git diff --check` - passed with LF/CRLF warnings only
- `npm test` - passed; 23 test files, 126 tests
- `npm run lint` - passed
- `npm run build` - passed
- `npm run typecheck` - passed

## K. Secret Scan Result

Passed.

- changed files scanned: 4
- changed-file secret findings: 0
- `.env.local` ignored and not staged
- `supabase/.temp/` ignored
- `.codex-dev-server.*.log` ignored and not staged
- no real Clerk/Supabase/service-role values found in docs/source
- no service role found in `app` or `components`
- no product review RPC references found in unrelated checkout, customer, reseller, or shop flows
- no bearer tokens, passwords, API secrets, or production data found

## L. Current Git Status

Working tree contains uncommitted QA documentation updates and a `.gitignore` safety update.

The `.codex-dev-server.*.log` files are generated local dev-server artifacts and are ignored by `.gitignore`.

## M. Whether Safe To Commit

Safe to commit after final verification commands and the secret scan pass.
