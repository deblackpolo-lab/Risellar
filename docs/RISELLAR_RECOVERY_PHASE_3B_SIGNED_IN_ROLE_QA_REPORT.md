# Risellar Recovery Phase 3B Signed-In Role QA Report

## A. Executive summary

Recovery Phase 3B began live signed-in role routing QA from the Codex-controlled browser session.

The signed-in reseller session was verified successfully for reseller profile sync, reseller dashboard access, reseller catalog access, reseller my-products access, reseller product detail access, and denial from supplier/admin/customer-only route groups.

The signed-in customer session was then verified successfully for Clerk session persistence, QA profile sync, `/customer/addresses`, customer-to-reseller/supplier/admin route isolation, public route access, and sign-out.

The signed-in supplier_owner session was verified successfully for QA profile sync, supplier dashboard access, supplier product list/new/detail/edit access, denial from reseller/customer/admin route groups, public route access, and sign-out.

Sign-out/account switching was verified for reseller, customer, and supplier_owner sessions.

The signed-in admin_staff session was verified for admin_staff authorization, approved admin pages, product approval pages, onboarding review pages, public route access, cross-role routing behavior, and sign-out.

Phase 3B signed-in role QA is now complete as a verification pass. Important cleanup findings remain for mock/static order, checkout, settlement, commission, withdrawal, and role-preparation surfaces before checkout draft UI is reintroduced.

## B. Current HEAD and branch

- HEAD: `94f6eb69ca1d22c475997f52d4d7729d52dfd0b7`
- Branch: `main`
- Staged files: none at precheck

Precheck notes:

- `git diff --check` passed with CRLF warnings only for existing recovery config files.
- Development server was running at `http://localhost:400`.
- No migrations were applied.
- No checkout, order, stock, payment, delivery, commission, settlement, or withdrawal implementation was resumed.

## C. Customer account QA, masked

Status: PASS for this customer slice.

Masked account: development customer test account; email was not printed in the report.

Customer auth/session result:

- Current browser session began on `http://localhost:400/customer/orders`.
- Page rendered as a customer account mock order surface with no Next.js error overlay.
- Browser refresh kept the customer session active on `/customer/orders`.
- `/auth/qa-profile-sync` loaded for the signed-in customer.
- QA profile sync showed profile row created/found, Clerk user id stored, email stored, role `customer`, and account status `active`.
- No arbitrary role input appeared on the QA profile sync route.
- No self-promotion path was exposed.

Customer addresses result:

- `/customer/addresses` loaded.
- Contact and delivery address forms rendered.
- Saved delivery address section rendered safely and showed `0 saved`.
- Browser text explicitly stated that no checkout is started from the page.
- No server/client boundary error, missing RPC error, hydration error, or Next.js error overlay text appeared.

Contact/address mutation result:

- No mutation was performed in this slice.
- Reason: the page had no saved address data, and the prompt allowed skipping mutation when useful QA data could be avoided. This slice verified safe read/render behavior only.
- No order, order item, stock reservation, payment, delivery quote, commission, settlement, or withdrawal action was triggered from the browser.

Customer route isolation:

- `/reseller/dashboard`: REDIRECTED to `http://localhost:400/customer/orders`.
- `/reseller/products`: REDIRECTED to `http://localhost:400/customer/orders`.
- `/supplier/dashboard`: REDIRECTED to `http://localhost:400/customer/orders`.
- `/supplier/products`: REDIRECTED to `http://localhost:400/customer/orders`.
- `/admin`: REDIRECTED to `http://localhost:400/customer/orders`.
- `/admin/products`: REDIRECTED to `http://localhost:400/customer/orders`.

Public route access while signed in as customer:

- `/`: ALLOWED.
- `/shop/shop-5d2328c9d22f412e8bbb5cc1`: ALLOWED; showed active approved listing and read-only checkout copy.
- `/shop/shop-5d2328c9d22f412e8bbb5cc1/product/risellar-admin-approval-qa-approve-target-20260718132814-54d1f228-38a626`: ALLOWED; showed public-safe product information and disabled `Add to cart planned` / `Buy later` controls.

Customer navigation findings:

- `/customer/orders` is active and renders mock order text including delivery estimate copy. Classification: SAFE EXISTING MOCK/PLACEHOLDER for this browser slice, but IMPORTANT for recovery scope because customer order routes still exist.
- Build output confirms active static/mock route files remain under `/customer/orders`, `/checkout`, `/supplier/orders`, `/reseller/orders`, and `/admin/orders`.
- No active payment, delivery, checkout finalization, or order creation control was clicked or observed creating a live side effect.

Customer sign-out:

- The approved `Logout` control on `/auth/qa-profile-sync` signed the customer out.
- After sign-out, `/customer/addresses` redirected to Clerk sign-in with the customer address return URL.
- Refresh did not restore the signed-out customer session.

## D. Reseller account QA, masked

Status: PARTIAL PASS.

Observed signed-in reseller result:

- `/auth/qa-profile-sync`: ALLOWED.
- QA profile-sync showed profile row created/found, Clerk user id stored, email stored, role `reseller`, and account status `active`.
- `/reseller/dashboard`: ALLOWED.
- `/reseller/products`: ALLOWED.
- `/reseller/my-products`: ALLOWED.
- `/reseller/products/54d1f228-3eb9-4ae2-9e9c-eb7c36899c33`: ALLOWED.

Reseller denial checks:

- `/supplier/dashboard`: REDIRECTED to `http://localhost:400/reseller/dashboard`.
- `/supplier/products`: REDIRECTED to `http://localhost:400/reseller/dashboard`.
- `/admin`: REDIRECTED to `http://localhost:400/reseller/dashboard`.
- `/admin/products`: REDIRECTED to `http://localhost:400/reseller/dashboard`.
- `/customer/addresses`: REDIRECTED to `http://localhost:400/reseller/dashboard`.

No redirect loop or Next.js error overlay text was observed during the reseller route checks.

The reseller product catalog and product detail showed reseller-safe catalog/listing fields. Supplier private contact, payout, internal admin notes, and private team fields were not visible in the inspected browser text.

## E. Supplier owner account QA, masked

Status: PASS for this supplier_owner slice, with one IMPORTANT recovery-scope navigation finding.

Masked account: approved development supplier_owner test account; email was not printed in the report.

Supplier auth/session result:

- `/auth/qa-profile-sync`: ALLOWED.
- QA profile-sync showed profile row created/found, Clerk user id stored, email stored, display name stored, role `supplier_owner`, and account status `active`.
- The QA profile sync route exposed only the development-safe `Logout` control and no arbitrary role input.
- `/supplier/dashboard`: ALLOWED and survived direct navigation/refresh.
- CSS/runtime was healthy on the supplier pages tested; body background and app font loaded, and no missing chunk/module runtime error text appeared.

Supplier product route result:

- `/supplier/products`: ALLOWED and showed supplier product management UI.
- `/supplier/products/new`: ALLOWED and showed safe supplier-controlled fields only: product name, category, description, base price, and stock quantity.
- `/supplier/products/587f897c-6b86-4bf5-b93b-90e4685e53f6`: ALLOWED and showed product detail for a development QA product.
- `/supplier/products/587f897c-6b86-4bf5-b93b-90e4685e53f6/edit`: ALLOWED and showed safe editable fields.
- Supplier product UI did not expose an approve/review control, platform margin control, reseller pricing control, admin notes control, payment control, or checkout control in the inspected browser text.

Supplier route isolation:

- `/reseller/dashboard`: REDIRECTED to `http://localhost:400/supplier/dashboard`.
- `/reseller/products`: REDIRECTED to `http://localhost:400/supplier/dashboard`.
- `/customer/addresses`: REDIRECTED to `http://localhost:400/supplier/dashboard`.
- `/admin/dashboard`: REDIRECTED to `http://localhost:400/supplier/dashboard`.
- `/admin/products`: REDIRECTED to `http://localhost:400/supplier/dashboard`.
- `/admin/onboarding-requests`: REDIRECTED to `http://localhost:400/supplier/dashboard`.

Public route access while signed in as supplier_owner:

- `/`: ALLOWED.
- Valid public reseller shop route: ALLOWED.
- Valid public reseller shop product route: ALLOWED.

Supplier sign-out:

- The `Logout` control on `/auth/qa-profile-sync` signed the supplier_owner account out.
- After sign-out, a direct visit to `/supplier/dashboard` redirected to Clerk sign-in.
- No session cookie, JWT, or auth export was written to the repository.

Supplier navigation findings:

- `/supplier/dashboard` still exposes `View Orders`, `Prepare`, `Orders`, and settlement-related navigation.
- `/supplier/orders`, `/supplier/orders/rsr-20260713-00021`, `/supplier/orders/rsr-20260713-00021/prepare`, `/supplier/settlements`, and `/supplier/settlements/overdue` all loaded mock/static supplier order, preparation, and settlement screens.
- No live order, stock reservation, payment, delivery, commission, settlement, withdrawal, or checkout mutation was triggered during browser QA.
- Classification: IMPORTANT recovery-scope finding. These active links/routes conflict with the expectation that removed or unapproved supplier preparation/order/settlement paths should not be active during recovery, but this QA pass did not change source because the prompt was verification-only.

## F. Admin account QA, masked

Status: PASS for approved admin pages, with IMPORTANT recovery-scope findings.

Masked account: approved development admin_staff test account; email was not printed in the report.

Admin auth/session result:

- Clerk sign-in completed before this QA slice.
- The session survived route navigation and a browser refresh on `/admin`.
- `/auth/qa-profile-sync`: ALLOWED.
- QA profile sync showed profile row created/found, Clerk user id stored, email stored, display name stored, primary role `customer`, and account status `active`.
- The primary role staying `customer` is expected for the admin test profile; admin access is granted by active `admin_staff`.
- The QA page exposed no secret, token, cookie, JWT, or arbitrary role input.

Admin authorization result:

- Source inspection confirmed `lib/auth/admin-access.ts` calls `has_admin_role('admin')` through `createSupabaseUserServerClient(accessToken)`.
- Admin pages call Clerk `auth().getToken()` and pass the token to `createSupabaseUserServerClient(accessToken)`.
- `profiles.primary_role` alone is not sufficient for admin access.
- `RouteAccessBoundary` elevates to `role: "admin"` only when the route policy includes admin and active `admin_staff` is confirmed.
- No service-role client is used for normal admin route authorization.
- No client-side-only admin guard is relied upon for the tested admin pages.

Admin route results:

- `/admin`: ERROR/NOT FOUND. The route is protected by middleware but has no root page, so it rendered the safe Next.js 404 page. This is a route gap, not an auth bypass.
- `/admin/dashboard`: ALLOWED. Rendered the admin dashboard with admin shell/navigation.
- `/admin/products`: ALLOWED. Rendered product approval queue through the audited admin product review UI.
- `/admin/products/587f897c-6b86-4bf5-b93b-90e4685e53f6`: ALLOWED. Rendered product detail and review-state copy stating approval updates must go through `review_supplier_product`.
- `/admin/onboarding-requests`: ALLOWED. Rendered role onboarding review UI with no pending requests and copy stating profile roles are not mutated directly.
- `/admin/operations/product-approvals`: ALLOWED. Rendered product approval queue.

Admin cross-role route behavior:

- `/customer/addresses`: ALLOWED. Source rule: admin_staff elevation is only applied for admin-policy routes; this admin test profile's `profiles.primary_role` remains `customer`, so customer routes are allowed by the normal customer role policy.
- `/reseller/dashboard`: REDIRECTED to `http://localhost:400/customer/orders`.
- `/reseller/products`: REDIRECTED to `http://localhost:400/customer/orders`.
- `/supplier/dashboard`: REDIRECTED to `http://localhost:400/customer/orders`.
- `/supplier/products`: REDIRECTED to `http://localhost:400/customer/orders`.

Admin public route access:

- `/`: ALLOWED.
- Valid public reseller shop route: ALLOWED.
- Valid public reseller shop product route: ALLOWED, with read-only checkout-planned controls.

Admin navigation findings:

- Admin navigation includes approved existing admin pages such as `/admin/dashboard`, `/admin/products`, `/admin/onboarding-requests`, `/admin/operations`, and product approval operations.
- Admin navigation also exposes mock/static order and finance placeholders: `/admin/orders`, `/admin/settlements`, `/admin/commissions`, and `/admin/withdrawals`.
- `/admin/dashboard` includes `Review orders`, `View settlements`, and static order links such as `/admin/orders/rsr-20260713-00021`.
- Classification: IMPORTANT recovery-scope finding. These routes are existing mock/static admin surfaces and did not trigger live order/payment/delivery/settlement/commission/withdrawal mutation during this QA, but they should be hidden, removed, or explicitly labelled before checkout/order work resumes.

Admin sign-out:

- The `Logout` control signed the admin account out.
- After sign-out, `/admin/products` redirected to Clerk sign-in.
- Refresh stayed on Clerk sign-in and did not restore the admin session.
- No session export, JWT, cookie, or debug file was written to active repository paths.

## G. Sign-out/account-switching QA

Status: PASS for reseller, customer, supplier_owner, and admin_staff sign-out.

The approved QA profile sync route exposed one `Logout` control while the reseller session was active. After sign-out, a fresh visit to `/reseller/dashboard` redirected to Clerk sign-in:

`https://mutual-tiger-83.accounts.dev/sign-in?redirect_url=http%3A%2F%2Flocalhost%3A400%2Freseller%2Fdashboard`

No session cookies, JWTs, or auth export files were written into repository paths by this QA slice.

Customer sign-out result:

- Before sign-out, `/auth/qa-profile-sync` showed role `customer` and account status `active`.
- After clicking `Logout`, the browser landed on `/sign-in`.
- A direct visit to `/customer/addresses` redirected to Clerk sign-in.
- Refresh stayed on Clerk sign-in.

Supplier_owner sign-out result:

- Before sign-out, `/auth/qa-profile-sync` showed role `supplier_owner` and account status `active`.
- Clicking `Logout` left the QA page in a signing-out state and cleared access.
- A direct visit to `/supplier/dashboard` redirected to Clerk sign-in.

Admin_staff sign-out result:

- Before sign-out, `/auth/qa-profile-sync` showed primary role `customer` and account status `active`.
- Clicking `Logout` cleared the session.
- A direct visit to `/admin/products` redirected to Clerk sign-in.
- Refresh stayed on Clerk sign-in.

## H. Full role-routing matrix

Only results actually tested in browser are marked as ALLOWED, REDIRECTED, BLOCKED, or ERROR.

| Actor | Public route | Customer route | Reseller route | Supplier route | Admin route | QA profile-sync |
| --- | --- | --- | --- | --- | --- | --- |
| Unauthenticated | PREVIOUS PHASE 3 PASS | PREVIOUS PHASE 3 REDIRECTED to Clerk | PREVIOUS PHASE 3 REDIRECTED to Clerk | PREVIOUS PHASE 3 REDIRECTED to Clerk | PREVIOUS PHASE 3 REDIRECTED to Clerk | PREVIOUS PHASE 3 REDIRECTED to Clerk |
| Customer | ALLOWED | ALLOWED | REDIRECTED to `/customer/orders` | REDIRECTED to `/customer/orders` | REDIRECTED to `/customer/orders` | ALLOWED |
| Reseller | NOT RETESTED | REDIRECTED to `/reseller/dashboard` for `/customer/addresses` | ALLOWED | REDIRECTED to `/reseller/dashboard` | REDIRECTED to `/reseller/dashboard` | ALLOWED |
| Supplier owner | ALLOWED | REDIRECTED to `/supplier/dashboard` for `/customer/addresses` | REDIRECTED to `/supplier/dashboard` | ALLOWED | REDIRECTED to `/supplier/dashboard` | ALLOWED |
| Admin staff | ALLOWED | ALLOWED for `/customer/addresses` via primary role `customer` | REDIRECTED to `/customer/orders` | REDIRECTED to `/customer/orders` | ALLOWED for existing admin pages; `/admin` root is 404 | ALLOWED |

## I. Clerk session behavior

Clerk session behavior worked for the reseller, customer, supplier_owner, and admin_staff slices:

- Signed-in reseller session survived direct route navigation.
- Signed-in customer session survived browser refresh.
- Signed-in supplier_owner session survived direct route navigation.
- Signed-in admin_staff session survived route navigation and refresh.
- Signed-out protected route redirected to Clerk sign-in.
- Clerk development-key warnings were visible and classified as EXPECTED for local development.

## J. Clerk-to-Supabase token behavior

Runtime reseller, customer, supplier_owner, and admin_staff QA profile sync succeeded, which confirms the server path could identify the Clerk user and resolve the synced Supabase profile for these accounts.

Source inspection confirmed user-context Supabase clients are created with the public anon key plus Clerk native access token via `getToken()` and `createSupabaseUserServerClient(accessToken)`.

No normal user flow was observed using service role.

## K. Admin_staff authorization result

Browser admin QA passed for approved existing admin pages.

Source inspection confirmed admin route access asks `getRoleOnboardingAdminAccess`, which calls `has_admin_role` with a Clerk/Supabase user-context token. `profiles.primary_role` alone is not sufficient in the active admin route access boundary.

The admin test profile still reports primary role `customer`, which proves the tested admin access is not granted by `profiles.primary_role = admin`.

## L. Browser console/network findings

Observed browser logs during reseller/customer/supplier_owner QA:

- EXPECTED: Clerk development-key warning from the Clerk development instance.
- IMPORTANT / NON-BLOCKING: Clerk structural CSS warning for Clerk component selectors on the hosted Clerk sign-in surface.

No blocking browser runtime error, hydration error, missing module error, or Next.js error overlay text was observed during the reseller route checks.

No blocking browser runtime error, hydration error, missing chunk error, Supabase token error, or Next.js error overlay text was observed during the customer route checks.

No blocking browser runtime error, hydration error, missing chunk error, Supabase token error, or missing-module error was observed during the supplier_owner route checks. Supplier browser logs showed only repeated Clerk development-key warnings.

Admin browser logs showed repeated Clerk development-key warnings only. No blocking Supabase token error, hydration error, missing chunk error, failed admin RPC error, redirect loop, or Next.js missing-module error was observed on the approved admin pages.

## M. Dead or removed route-link findings

IMPORTANT finding:

- Reseller navigation still shows `Orders`, and the reseller dashboard still shows a `View Orders` action.
- `/reseller/orders` and `/reseller/orders/rsr-20260713-00021` both load mock order screens.
- No live order/payment/delivery mutation was observed from viewing those routes, but their presence conflicts with the Phase 3B expectation that removed order/payment/delivery links should not appear during recovery.
- Customer `/customer/orders` remains active as a mock/static route and rendered order/delivery estimate text in the signed-in customer session.
- Supplier navigation still exposes `Orders`, `Prepare`, `View Orders`, settlement links, and settlement actions.
- `/supplier/orders`, `/supplier/orders/rsr-20260713-00021`, `/supplier/orders/rsr-20260713-00021/prepare`, `/supplier/settlements`, and `/supplier/settlements/overdue` load mock/static order, preparation, and settlement screens.
- Admin navigation exposes mock/static order and finance pages including `/admin/orders`, `/admin/settlements`, `/admin/commissions`, and `/admin/withdrawals`, plus dashboard links such as `Review orders` and `View settlements`.
- `/admin` root is a protected route but has no page and renders the safe Next.js 404.
- Build output confirms active mock/static order, checkout, supplier preparation, and settlement route groups still exist. These did not create live side effects during browser QA, but they remain an IMPORTANT recovery-scope finding before checkout/order/supplier-preparation work resumes.

No source fix was made because the prompt requires a targeted fix only after a clear runtime failure, and this finding is a scope/navigation decision rather than a crash or auth bypass.

## N. Targeted fixes made, if any

None in this Phase 3B admin_staff slice.

The earlier local CSS/runtime cache issue was resolved by stale-cache recovery before this report. After the required `npm run build` command rewrote `.next`, the local dev server on port 400 returned HTTP 500 from a mismatched cache. The port-400 Node dev process was stopped, the stale `.next` cache was moved into ignored `.local-recovery/quarantine/runtime-cache/`, and `npm run dev:400` was restarted.

Post-restart sanity check:

- `http://localhost:400/`: HTTP 200.

No application source, auth architecture, migration, RPC, RLS, checkout, order, payment, delivery, settlement, commission, or withdrawal code was changed during signed-in reseller, customer, supplier_owner, or admin_staff QA.

## O. Automated verification results

Automated verification after admin_staff browser QA:

- `git diff --check`: passed with CRLF warnings only.
- `npm test`: passed, 29 test files and 151 tests.
- `npm run lint`: passed.
- `npm run build`: passed.
- `npm run typecheck`: passed.
- `npx tsc --noEmit`: passed.

## P. Security scan result

Phase 3B partial security/scope status:

- No secrets, cookies, JWTs, or session export files were printed.
- No migrations were applied.
- No production Supabase connection was used.
- No checkout, order, stock, payment, delivery, commission, settlement, or withdrawal code was reintroduced by this Phase 3B admin_staff QA task.
- No files were staged.
- `.env.local` is ignored.
- `supabase/.temp` is ignored.
- `.next` is ignored.
- `.local-recovery` is ignored.
- `.codex-dev-server.phase3b-supplier.out.log` is ignored.
- `.codex-dev-server.phase3b-supplier.err.log` is ignored.
- `.codex-dev-server.phase3b-admin.out.log` is ignored.
- `.codex-dev-server.phase3b-admin.err.log` is ignored.
- `session.cookie`, `session.jwt`, `debug.log`, `dev.err`, and `dev.out` were not present in the repository root.
- No `SUPABASE_SERVICE_ROLE_KEY` or server-only Supabase admin helper import was found in `app/` or `components/`.
- Focused scan found no service-role imports in `app/` or `components/`.
- Focused scan found three legacy docs with secret-like assignment or bearer markers; values were not printed and these should remain on the recovery follow-up list.
- Active mock/static route directories still exist for `app/customer/orders`, `app/checkout`, `app/supplier/orders`, `app/reseller/orders`, and `app/admin/orders`.
- Active supplier mock/static settlement/preparation route groups still exist under `app/supplier/settlements` and `app/supplier/orders/[id]/prepare`.
- Active admin mock/static finance route groups still exist under `app/admin/settlements`, `app/admin/commissions`, and `app/admin/withdrawals`.

Full Phase 3B security scan completed for the signed-in role QA pass.

## Q. Files changed

Created in this slice:

- `docs/RISELLAR_RECOVERY_PHASE_3B_SIGNED_IN_ROLE_QA_REPORT.md`

Updated in this slice:

- `docs/RISELLAR_RECOVERY_PHASE_3_RUNTIME_AUTH_ROUTING_QA_REPORT.md`
- `docs/RISELLAR_RECOVERY_PHASE_3B_SIGNED_IN_ROLE_QA_REPORT.md`

Ignored local runtime artifacts touched:

- `.next` moved into `.local-recovery/quarantine/runtime-cache/` after post-build dev-server cache mismatch.
- `.codex-dev-server.phase3b-customer.out.log`
- `.codex-dev-server.phase3b-customer.err.log`
- `.codex-dev-server.phase3b-supplier.out.log`
- `.codex-dev-server.phase3b-supplier.err.log`
- `.codex-dev-server.phase3b-admin.out.log`
- `.codex-dev-server.phase3b-admin.err.log`

Existing recovery config/docs remain uncommitted.

## R. Current Git status

Pending local recovery changes remain uncommitted. No files are staged.

`git status --short` currently includes recovery config changes, metadata/line-ending-only tracked modifications from the recovery baseline, and untracked recovery reports, including this Phase 3B report.

## S. Whether authentication is fully restored

Yes for the verified recovery scope.

Authentication is working for signed-out redirects and the signed-in customer, reseller, supplier_owner, and admin_staff slices. The root `/admin` path itself is a safe 404 because no page exists.

## T. Whether role routing is fully restored

Yes for the tested role-routing recovery matrix, with documented route-shape findings.

Customer, reseller, supplier_owner, and admin_staff route isolation has been browser-tested. Admin_staff access uses active `admin_staff`; customer-route access for the admin test profile follows its `primary_role = customer`, and reseller/supplier routes redirect to `/customer/orders`.

## U. Whether it is safe to commit recovery changes

Yes, after the user asks.

The recovery reports and narrow recovery config changes can be committed after the user asks. Do not stage ignored runtime caches/logs or unrelated local artifacts.

## V. Whether it is safe to reintroduce checkout draft UI

No.

No.

Checkout draft UI should remain deferred until the active mock/static order, checkout, supplier-preparation, settlement, commission, and withdrawal route findings are resolved or explicitly accepted as labelled placeholders.

## W. Exact recommended next step

Commit the recovery documentation/config changes in a scoped recovery commit, then run a cleanup pass for mock/static order, checkout, supplier-preparation, settlement, commission, and withdrawal navigation before reintroducing checkout draft UI.
