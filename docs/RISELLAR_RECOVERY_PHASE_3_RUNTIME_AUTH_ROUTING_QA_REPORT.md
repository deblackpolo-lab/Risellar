# Risellar Recovery Phase 3 Runtime Auth Routing QA Report

## A. Executive summary

Recovery Phase 3 verified the cleaned repository at runtime for public pages, Clerk route rendering, unauthenticated protected-route redirects, static assets, and public reseller shop browsing.

The runtime chunk failure reported before recovery was reproduced from the stale `.next` cache, then resolved by stopping the stale local dev server, renaming the stale `.next` cache, and starting a fresh `npm run dev:400` process. No application source, migration, RPC, RLS, order, payment, delivery, settlement, or checkout draft UI code was changed.

Signed-in customer, reseller, supplier_owner, and admin_staff browser QA have now been completed after each development test account was signed into the Codex-controlled browser session.

Phase 3B began after the development reseller account was signed in. The signed-in reseller slice passed route access/isolation checks, and reseller sign-out was verified.

Phase 3B continued after the development customer account was signed in. The signed-in customer slice passed QA profile sync, `/customer/addresses`, public route access, cross-role denial checks, and customer sign-out.

Phase 3B continued again after the approved development supplier_owner account was signed in. The supplier_owner slice passed QA profile sync, supplier dashboard access, supplier product list/new/detail/edit route access, cross-role denial checks, public route access, and supplier sign-out.

Phase 3B completed after the approved development admin_staff account was signed in. The admin slice passed QA profile sync, approved admin route access, admin_staff authorization source inspection, admin product approval page access, onboarding review page access, product detail access, public route access, cross-role routing checks, and admin sign-out.

After the required `npm run build` verification rewrote `.next`, the local dev server returned HTTP 500 from a stale/mismatched cache. The port-400 Node dev server was restarted, the stale `.next` cache was moved into ignored `.local-recovery/quarantine/runtime-cache/`, and `http://localhost:400/` returned HTTP 200 afterward. No source code was changed for this runtime recovery.

## B. Current HEAD and branch

- HEAD: `94f6eb69ca1d22c475997f52d4d7729d52dfd0b7`
- Branch: `main`
- Staged files: none

## C. Development server result

Initial runtime check found a stale dev server on port 400 returning missing module/chunk errors from `.next`, including missing Clerk vendor chunks and numeric chunk files.

Targeted runtime recovery:

- Stopped local Risellar dev processes bound to port 400.
- Renamed stale `.next` cache to `.next.phase3-stale`.
- Moved `.next.phase3-stale` into `.local-recovery/quarantine/runtime-cache/`.
- Started a fresh local dev server with `npm run dev:400`.

Fresh server result:

- `http://localhost:400/` returned HTTP 200.
- Fresh browser navigation loaded pages without the missing `./vendor-chunks/@clerk.js` or `./5611.js` runtime errors.
- Fresh server log showed `Ready` and successful compilation for `/`, with no post-reset missing-module errors.

## D. Public route QA

Browser QA results:

- `/`: loaded with styles/scripts, HTTP/browser render OK.
- `/sign-in`: loaded Clerk sign-in after hydration.
- `/sign-up`: loaded Clerk sign-up after hydration.
- `/shop/shop-5d2328c9d22f412e8bbb5cc1`: loaded unauthenticated, showed one active approved product.
- `/shop/shop-5d2328c9d22f412e8bbb5cc1/product/risellar-admin-approval-qa-approve-target-20260718132814-54d1f228-38a626`: loaded unauthenticated and showed read-only product detail.
- `/shop/not-a-real-shop`: loaded safe unavailable/empty state.

Public shop visible safe fields included shop name, product name, category, low-stock label, final customer price, and read-only checkout messaging.

Sensitive supplier/reseller/internal fields were not visible in browser text inspected during QA.

## E. Clerk authentication QA

Clerk pages rendered after hydration:

- Sign-in text: `Sign in to Risellar`, Google option, email/password controls, development mode indicator.
- Sign-up text: `Create your account`, Google option, email/password controls, development mode indicator.

Observed warnings:

- Clerk development-key warning.
- Clerk structural CSS warning for Clerk component selectors.

No blocking Clerk runtime errors were observed after the stale cache reset.

Signed-in browser QA is now complete for customer, reseller, supplier_owner, and admin_staff accounts.

## F. QA profile-sync result

Signed-out `/auth/qa-profile-sync` redirected to Clerk:

`https://mutual-tiger-83.accounts.dev/sign-in?redirect_url=http%3A%2F%2Flocalhost%3A400%2Fauth%2Fqa-profile-sync`

Signed-in profile sync for customer, reseller, supplier_owner, and admin_staff was browser-tested in Phase 3B after the user supplied each browser session.

Source/test verification from previous recovery remains in place, but this report does not claim fresh signed-in profile-sync browser success.

## G. Customer route QA

Signed-out `/customer/addresses` redirected to Clerk sign-in with the correct return URL.

Signed-in customer QA was completed in Phase 3B after a development customer account was signed into the controlled browser session.

Phase 3B browser-tested:

- `/auth/qa-profile-sync`: showed profile row created/found, role `customer`, and account status `active`.
- Session survived browser refresh.
- `/customer/addresses`: loaded contact/address setup UI, rendered empty saved-address state, and showed copy that no checkout is started from the page.
- `/reseller/dashboard`, `/reseller/products`, `/supplier/dashboard`, `/supplier/products`, `/admin`, and `/admin/products`: redirected to `/customer/orders`.
- `/`, a valid public reseller shop, and a valid public product page loaded while signed in as customer.
- Public product page kept `Add to cart planned` and `Buy later` disabled.
- Customer sign-out redirected protected `/customer/addresses` to Clerk sign-in and refresh did not restore the session.

Not performed in Phase 3B customer slice:

- Contact/address mutation. The page had no saved address data; no write was needed for this recovery verification slice.

No order/payment/delivery rows were created by Phase 3 QA.

Phase 3B finding:

- `/customer/orders` remains active as a mock/static customer order route.
- Build output confirms `/checkout` and multiple role order route groups still exist as mock/static routes.
- No live order/payment/delivery mutation was triggered during browser QA, but these route groups remain a recovery-scope finding before checkout work resumes.

## H. Reseller route QA

Signed-out reseller routes redirected to Clerk:

- `/reseller/dashboard`
- `/reseller/products`
- `/reseller/my-products`

Signed-in reseller QA was completed in Phase 3B after a development reseller account was signed into the controlled browser session.

Phase 3B browser-tested:

- `/auth/qa-profile-sync`: showed profile row created/found, role `reseller`, and account status `active`.
- `/reseller/dashboard`: loaded.
- `/reseller/products`: loaded.
- `/reseller/my-products`: loaded.
- `/reseller/products/54d1f228-3eb9-4ae2-9e9c-eb7c36899c33`: loaded.
- `/supplier/dashboard`, `/supplier/products`, `/admin`, `/admin/products`, and `/customer/addresses`: redirected to `/reseller/dashboard`.

Phase 3B finding:

- Reseller navigation still exposes `Orders` and `View Orders`.
- `/reseller/orders` and `/reseller/orders/rsr-20260713-00021` load mock order screens.
- No live order/payment/delivery mutation was observed from viewing those screens, but the links conflict with the recovery expectation that removed order/payment/delivery links should not appear.

## I. Supplier route QA

Signed-out supplier routes redirected to Clerk:

- `/supplier/dashboard`
- `/supplier/products`

Signed-in supplier-owner QA was completed in Phase 3B after an approved development supplier_owner account was signed into the controlled browser session.

Phase 3B browser-tested:

- `/auth/qa-profile-sync`: showed profile row created/found, role `supplier_owner`, and account status `active`.
- `/supplier/dashboard`: loaded and showed supplier dashboard content.
- `/supplier/products`: loaded and showed supplier product management UI.
- `/supplier/products/new`: loaded and showed supplier-safe create form fields.
- `/supplier/products/587f897c-6b86-4bf5-b93b-90e4685e53f6`: loaded product detail.
- `/supplier/products/587f897c-6b86-4bf5-b93b-90e4685e53f6/edit`: loaded edit form for safe fields.
- `/reseller/dashboard`, `/reseller/products`, `/customer/addresses`, `/admin/dashboard`, `/admin/products`, and `/admin/onboarding-requests`: redirected to `/supplier/dashboard`.
- `/`, a valid public reseller shop, and a valid public product route loaded while signed in as supplier_owner.
- Supplier sign-out redirected protected `/supplier/dashboard` to Clerk sign-in.

Supplier product pages did not expose approval/review controls, platform margin controls, reseller pricing controls, payment controls, checkout controls, or admin-only review controls in the inspected browser text.

Phase 3B finding:

- Supplier dashboard/navigation still exposes `View Orders`, `Prepare`, `Orders`, and settlement links.
- `/supplier/orders`, `/supplier/orders/rsr-20260713-00021`, `/supplier/orders/rsr-20260713-00021/prepare`, `/supplier/settlements`, and `/supplier/settlements/overdue` load mock/static supplier order, preparation, and settlement screens.
- No live order, stock reservation, payment, delivery, commission, settlement, withdrawal, or checkout mutation was triggered during browser QA.
- Classification: IMPORTANT recovery-scope finding because these active links/routes conflict with the expectation that unapproved supplier preparation/order/settlement paths should not be active during recovery.

## J. Admin route QA

Signed-out admin routes redirected to Clerk:

- `/admin/dashboard`
- `/admin/products`
- `/admin/onboarding-requests`
- `/admin/operations/product-approvals`

Signed-in admin QA was completed in Phase 3B after the approved development admin_staff account was signed into the controlled browser session.

Phase 3B browser-tested:

- `/auth/qa-profile-sync`: showed profile row created/found, primary role `customer`, and account status `active`.
- `/admin`: safe 404 because no root admin page exists.
- `/admin/dashboard`: loaded.
- `/admin/products`: loaded product approval queue.
- `/admin/products/587f897c-6b86-4bf5-b93b-90e4685e53f6`: loaded product detail and review-state copy.
- `/admin/onboarding-requests`: loaded onboarding review UI.
- `/admin/operations/product-approvals`: loaded product approval queue.
- `/customer/addresses`: ALLOWED because this admin_staff test profile's primary role remains `customer` and admin elevation is applied only to admin-policy routes.
- `/reseller/dashboard`, `/reseller/products`, `/supplier/dashboard`, and `/supplier/products`: redirected to `/customer/orders`.
- `/`, a valid public reseller shop, and a valid public product route loaded while signed in as admin_staff.
- Admin sign-out redirected protected `/admin/products` to Clerk sign-in and refresh did not restore the session.

Admin authorization source inspection:

- Admin access calls `has_admin_role('admin')` through `lib/auth/admin-access.ts`.
- Admin pages use Clerk `getToken()` and pass the token to `createSupabaseUserServerClient(accessToken)`.
- `profiles.primary_role = admin` is not required and `profiles.primary_role` alone is not sufficient.
- The tested admin profile's primary role remained `customer`.
- No service-role client is used for normal admin route authorization.

Phase 3B finding:

- Admin navigation exposes mock/static admin order and finance pages including `/admin/orders`, `/admin/settlements`, `/admin/commissions`, and `/admin/withdrawals`.
- Admin dashboard exposes `Review orders`, `View settlements`, and static order links.
- No live order, stock reservation, payment, delivery, commission, settlement, withdrawal, or checkout mutation was triggered during browser QA.
- Classification: IMPORTANT recovery-scope finding because these active links/routes should be hidden, removed, or explicitly labelled before checkout/order work resumes.

## K. Role routing matrix

| Actor | Public route | Customer route | Reseller route | Supplier route | Admin route | QA profile-sync |
| --- | --- | --- | --- | --- | --- | --- |
| Unauthenticated | ALLOWED | REDIRECTED to Clerk | REDIRECTED to Clerk | REDIRECTED to Clerk | REDIRECTED to Clerk | REDIRECTED to Clerk |
| Customer | ALLOWED | ALLOWED | REDIRECTED to `/customer/orders` | REDIRECTED to `/customer/orders` | REDIRECTED to `/customer/orders` | ALLOWED |
| Reseller | NOT RETESTED IN 3B | REDIRECTED to `/reseller/dashboard` for `/customer/addresses` | ALLOWED | REDIRECTED to `/reseller/dashboard` | REDIRECTED to `/reseller/dashboard` | ALLOWED |
| Supplier owner | ALLOWED | REDIRECTED to `/supplier/dashboard` for `/customer/addresses` | REDIRECTED to `/supplier/dashboard` | ALLOWED | REDIRECTED to `/supplier/dashboard` | ALLOWED |
| Admin staff | ALLOWED | ALLOWED for `/customer/addresses` via primary role `customer` | REDIRECTED to `/customer/orders` | REDIRECTED to `/customer/orders` | ALLOWED for existing admin pages; `/admin` root is 404 | ALLOWED |

All Phase 3B role rows are now browser-tested.

## L. Static asset and browser console findings

Static/runtime findings:

- CSS loaded on public and Clerk routes.
- Next scripts loaded on public and Clerk routes.
- Public pages did not show React/Next error overlay.
- Missing chunk/module errors were resolved after stale `.next` cache recovery.
- No valid public page asset 404 was observed during browser QA.

Console/browser findings:

- Clerk development-key warning: pre-existing/development-only.
- Clerk structural CSS warning: important but non-blocking; should be reviewed later if Clerk UI styling is customized.
- No hydration mismatch, missing chunk, or client/server boundary browser error was observed after the cache reset.
- Phase 3B reseller browser QA observed only Clerk development-key warnings. No blocking console/runtime error or Next.js error overlay text was observed.
- Phase 3B customer browser QA observed Clerk development-key warnings and Clerk structural CSS warnings only. No blocking Clerk error, Supabase token error, hydration error, missing chunk error, or Next.js error overlay text was observed.
- Phase 3B supplier_owner browser QA observed repeated Clerk development-key warnings only. No blocking Clerk error, Supabase token error, hydration error, missing chunk error, missing-module error, or Next.js error overlay text was observed.
- Phase 3B admin_staff browser QA observed repeated Clerk development-key warnings only. No blocking Clerk error, Supabase token error, hydration error, missing chunk error, failed admin RPC error, redirect loop, or Next.js missing-module error was observed on approved admin pages.

## M. Runtime errors found

Blocking runtime error reproduced before targeted recovery:

- `Cannot find module './vendor-chunks/@clerk.js'`
- `Cannot find module './5611.js'`

Classification: stale/corrupt local `.next` runtime cache after dependency recovery, not an application source regression.

Resolution: stale `.next` cache moved into ignored recovery quarantine and fresh dev server started.

## N. Targeted fixes made, if any

No source-code fix was made in Phase 3.

Targeted local runtime recovery only:

- Renamed/moved stale `.next` cache into `.local-recovery/quarantine/runtime-cache/`.
- Started fresh dev server on port 400.

No migrations, RPCs, RLS, auth architecture, route guards, checkout UI, order, stock, payment, delivery, settlement, commission, or withdrawal code was changed.

After the supplier_owner `npm run build` verification rewrote `.next`, the local dev server health check timed out. The port-400 dev process was restarted, the generated `.next` cache was moved into ignored `.local-recovery/quarantine/runtime-cache/`, and `http://localhost:400/` returned HTTP 200 afterward.

After the admin_staff `npm run build` verification rewrote `.next`, the local dev server returned HTTP 500 from the same stale-cache pattern. The port-400 dev process was restarted, the generated `.next` cache was moved into ignored `.local-recovery/quarantine/runtime-cache/`, and `http://localhost:400/` returned HTTP 200 afterward.

## O. Automated verification results

Commands run after runtime recovery:

- `git diff --check`: passed with CRLF warnings only.
- `npm test`: passed, 29 test files and 151 tests.
- `npm run lint`: passed.
- `npm run build`: passed.
- `npm run typecheck`: passed.
- `npx tsc --noEmit`: passed.

Commands rerun after supplier_owner browser QA:

- `git diff --check`: passed with CRLF warnings only.
- `npm test`: passed, 29 test files and 151 tests.
- `npm run lint`: passed.
- `npm run build`: passed.
- `npm run typecheck`: passed.
- `npx tsc --noEmit`: passed.

Commands rerun after admin_staff browser QA:

- `git diff --check`: passed with CRLF warnings only.
- `npm test`: passed, 29 test files and 151 tests.
- `npm run lint`: passed.
- `npm run build`: passed.
- `npm run typecheck`: passed.
- `npx tsc --noEmit`: passed.

## P. Security scan result

Security/scope scan passed:

- `.env.local` ignored and not staged.
- `supabase/.temp` ignored and not staged.
- `.next` ignored.
- `.local-recovery` ignored.
- `.codex-dev-server.phase3.log` and `.codex-dev-server.phase3.err.log` ignored.
- `.codex-dev-server.phase3b-supplier.out.log` and `.codex-dev-server.phase3b-supplier.err.log` ignored.
- `.codex-dev-server.phase3b-admin.out.log` and `.codex-dev-server.phase3b-admin.err.log` ignored.
- `session.cookie`, `session.jwt`, `debug.log`, `dev.err`, and `dev.out` absent from active paths.
- Nothing staged.
- No service-role imports found in `app/` or `components/`.
- No likely Clerk/Supabase service-role values, bearer tokens, passwords, API secrets, or production data found in active docs/source by value-pattern scan.
- Known unapproved migrations absent from active `supabase/migrations/`.
- Service-role scan found no service-role imports in `app/` or `components/`.
- Existing secret-name hits are documentation/test placeholders or server-only `lib/supabase/admin.ts` references; no secret values were printed.
- Active mock/static checkout/order/supplier-preparation/settlement routes remain in source and are tracked as recovery-scope findings rather than new integrations from this QA pass.
- Active mock/static admin commission and withdrawal routes remain in source and are tracked as recovery-scope findings rather than new integrations from this QA pass.

## Q. Recovery config review

`.gitignore`: KEEP.

- Adds `.local-recovery/`, session/debug/auth scratch artifacts, and Playwright auth storage ignores.
- Scope is narrow and does not hide active app source.

`eslint.config.mjs`: KEEP.

- Adds only `.local-recovery/**` to ESLint ignore.
- Does not exclude `app/`, `components/`, `lib/`, `tests/`, `scripts/`, or `supabase/`.

`vitest.config.ts`: KEEP.

- Adds only `.local-recovery/**` to Vitest exclude, preserving default excludes.
- Prevents quarantined salvage tests from being discovered as active suites.
- Does not hide active tests.

Line-ending/stat metadata:

- `git diff --ignore-space-at-eol --name-only`, `git diff --numstat`, and `git diff --summary` show real content diffs only for `.gitignore`, `eslint.config.mjs`, and `vitest.config.ts`.
- Other tracked files shown by `git status --short` are metadata/line-ending noise and were not rewritten.

## R. Files changed in Phase 3

Content file created:

- `docs/RISELLAR_RECOVERY_PHASE_3_RUNTIME_AUTH_ROUTING_QA_REPORT.md`
- `docs/RISELLAR_RECOVERY_PHASE_3B_SIGNED_IN_ROLE_QA_REPORT.md`

Ignored local runtime/cache artifacts:

- `.local-recovery/quarantine/runtime-cache/.next.phase3-stale`
- `.codex-dev-server.phase3.log`
- `.codex-dev-server.phase3.err.log`
- `.codex-dev-server.phase3b-supplier.out.log`
- `.codex-dev-server.phase3b-supplier.err.log`
- `.codex-dev-server.phase3b-admin.out.log`
- `.codex-dev-server.phase3b-admin.err.log`
- fresh `.next/` cache

No source code was changed in Phase 3.

## S. Current git status

Real content diffs:

- `.gitignore`
- `eslint.config.mjs`
- `vitest.config.ts`

Untracked recovery documents:

- `docs/RISELLAR_AUTHENTICATION_AUDIT.md`
- `docs/RISELLAR_BUILD_FAILURE_REPORT.md`
- `docs/RISELLAR_CHECKOUT_SCOPE_AUDIT.md`
- `docs/RISELLAR_FILES_TO_REVERT.md`
- `docs/RISELLAR_FORENSIC_CHANGE_AUDIT.md`
- `docs/RISELLAR_NEXT_STEPS.md`
- `docs/RISELLAR_RECOVERY_PHASE_1_CONTAINMENT_REPORT.md`
- `docs/RISELLAR_RECOVERY_PHASE_2_SCOPE_REMOVAL_REPORT.md`
- `docs/RISELLAR_RECOVERY_PHASE_3_RUNTIME_AUTH_ROUTING_QA_REPORT.md`
- `docs/RISELLAR_RECOVERY_PLAN.md`
- `docs/RISELLAR_SAFE_FILES_TO_KEEP.md`

`git status --short` also shows metadata-only modified entries for previously restored tracked files, but they do not appear in `git diff --name-status`.

Nothing is staged.

## T. Whether auth is restored

Partially verified.

Verified:

- ClerkProvider/runtime loads after stale cache reset.
- Sign-in and sign-up pages render.
- Signed-out protected routes redirect to Clerk.
- QA profile-sync route is protected from signed-out access.

All requested signed-in Phase 3B role sessions have now been browser-tested.

## U. Whether role routing is restored

Verified for the Phase 3B recovery scope.

Verified:

- Unauthenticated protected routes redirect to Clerk.

Admin browser access through `admin_staff` was verified. Admin cross-role behavior was verified and documented: customer route access follows the test profile's primary role `customer`; reseller/supplier routes redirect to `/customer/orders`; approved admin pages load through active `admin_staff`.

## V. Whether static assets are healthy

Yes for the public/Clerk pages tested after stale cache reset.

The previously observed missing chunk/module error was a local stale `.next` cache issue and did not recur after cache recovery.

## W. Whether it is safe to commit recovery changes

Safe to commit the recovery reports and narrowly scoped recovery config changes after reviewing the metadata-only status entries carefully.

Suggested commit scope should include:

- `.gitignore`
- `eslint.config.mjs`
- `vitest.config.ts`
- recovery reports under `docs/`

Do not stage `.env.local`, `.next`, `.local-recovery`, or `.codex-dev-server.*.log`.

## X. Whether it is safe to reintroduce checkout draft UI

No.

Before reintroducing checkout draft UI, resolve or explicitly accept the active mock/static checkout, order, supplier-preparation, settlement, commission, and withdrawal route findings.

## Y. Exact recommended next step

Commit the recovery config/docs changes in a scoped recovery commit. Then run a cleanup pass for mock/static checkout, order, supplier-preparation, settlement, commission, and withdrawal navigation before starting a clean Checkout Phase B Group 3 draft UI task from the quarantined salvage candidates.
