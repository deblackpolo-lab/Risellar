# Risellar Recovery Phase 1 Containment Report

Date: 2026-07-29

## A. Executive Summary

Recovery Phase 1 contained the polluted working tree without continuing feature development.

Completed actions:

- Captured a pre-recovery inventory in `.local-recovery/claude-working-tree-inventory.txt`.
- Saved the pre-restore package/config diff in `.local-recovery/config-before-restore.diff`.
- Added narrow ignore rules for local recovery, session, cookie, debug, and auth-storage artifacts.
- Quarantined clearly disposable local session/debug/auth/scratch artifacts into `.local-recovery/quarantine/`.
- Restored `package.json`, `package-lock.json`, `tsconfig.json`, and `next-env.d.ts` from the verified safe baseline.
- Restored normal npm verification scripts.
- Ran limited validation and path-only security/scope scans.

Not performed:

- No commits.
- No pushes.
- No Supabase migrations.
- No Supabase production connection.
- No `npm install`, `npm ci`, or dependency repair.
- No code repair in auth, routing, admin, supplier, customer, reseller, checkout, migration, RPC, or RLS files.

## B. Safe Baseline Commit

Verified safe baseline:

`94f6eb69ca1d22c475997f52d4d7729d52dfd0b7`

## C. Current HEAD And Branch

- Current HEAD: `94f6eb69ca1d22c475997f52d4d7729d52dfd0b7`
- Current branch: `main`
- HEAD remains exactly the verified safe baseline commit.
- No staged files were present at the start of Phase 1.

## D. Initial Working Tree Counts

Initial counts before Phase 1 changes:

- Modified tracked files: 11
- Deleted tracked files: 0
- Untracked files: 131
- Staged files: 0
- Anything already staged: no

Initial modified tracked files:

- `app/shop/[shopSlug]/product/[productId]/page.tsx`
- `app/supplier/orders/[id]/page.tsx`
- `app/supplier/orders/page.tsx`
- `components/admin/admin-core-screens.tsx`
- `components/customer/public-shop-rpc-screens.tsx`
- `components/supplier/screens.tsx`
- `middleware.ts`
- `next-env.d.ts`
- `package-lock.json`
- `package.json`
- `tsconfig.json`

## E. Sensitive Artifacts Found

The following local artifact classes were found and quarantined by path only.

Quarantine location:

`.local-recovery/quarantine/`

Quarantined artifact count: 65

Representative quarantined paths:

| Path | Classification | Quarantined |
| --- | --- | --- |
| `session.cookie` | session artifact / potentially sensitive | yes |
| `session.jwt` | session artifact / potentially sensitive | yes |
| `debug.log` | debug artifact / potentially sensitive | yes |
| `debug_curl.sh` | debug/auth scratch script / potentially sensitive | yes |
| `debug_curl2.sh` | debug/auth scratch script / potentially sensitive | yes |
| `debug_script.sh` | debug scratch script | yes |
| `dev.err` | debug output | yes |
| `dev.out` | debug output | yes |
| `clerk-session-new.js` | auth scratch script / potentially sensitive | yes |
| `clerk-session.js` | auth scratch script / potentially sensitive | yes |
| `clerk-test.js` | auth scratch script / potentially sensitive | yes |
| `create-clerk-session.js` | auth scratch script / potentially sensitive | yes |
| `debug-clerk.js` | auth scratch script / potentially sensitive | yes |
| `run_phase2_e2e*.sh` | temporary test scripts | yes |
| `test-clerk*.js` | auth scratch scripts | yes |
| `test-session.js` | session/auth scratch script | yes |
| `test/` | untracked scratch test directory | yes |

The full path-only quarantine manifest is stored at:

`.local-recovery/quarantine/quarantine-manifest.txt`

Credential rotation recommendation:

- Recommended. Because `session.cookie`, `session.jwt`, Clerk session scripts, and debug artifacts were present on disk, any development test sessions or tokens used by those artifacts should be treated as exposed.
- No secret values were printed in this report.
- No credential rotation was performed automatically.

## F. Configuration Files Restored

Restored from `94f6eb69ca1d22c475997f52d4d7729d52dfd0b7`:

- `package.json`
- `package-lock.json`
- `tsconfig.json`
- `next-env.d.ts`

Pre-restore diff saved at:

`.local-recovery/config-before-restore.diff`

After restore, `git diff -- package.json package-lock.json tsconfig.json next-env.d.ts` returned no content diff.

Note: `git status --short` still reports these files as modified after `git update-index --refresh`, even though `git diff` and `git diff --numstat` show no content diff for the restored config files. This appears to be index/stat or line-ending metadata noise and should be revisited in Phase 2 before staging anything.

## G. Verification Scripts Restored

`package.json` again contains:

- `dev`
- `dev:400`
- `build`
- `lint`
- `typecheck`
- `test`

Restored script values:

- `dev`: `node scripts/disable-next-dev-indicator.mjs && next dev -p 400`
- `dev:400`: `node scripts/disable-next-dev-indicator.mjs && next dev -p 400`
- `build`: `next build`
- `lint`: `eslint . --max-warnings=0`
- `typecheck`: `tsc --noEmit`
- `test`: `vitest run`

## H. Dependency Versions Restored

Restored package architecture in `package.json`:

- `next`: `^15.1.3`
- `react`: `^19.0.0`
- `react-dom`: `^19.0.0`
- `@clerk/nextjs`: `^7.5.20`
- `@supabase/supabase-js`: `^2.110.7`
- `@supabase/ssr`: `^0.12.3`
- `vitest`: `^2.1.8`
- `typescript`: `^5.7.2`
- `eslint`: `^9.17.0`

Local runtime check:

- `node --version`: `v24.16.0`
- `npm --version`: `11.13.0`

Current `node_modules` compatibility caveat:

- Installed `node_modules/next` reports `16.2.12`.
- Installed `node_modules/react` reports `19.2.8`.
- This is inconsistent with the restored `package.json`/`package-lock.json`.
- No `npm install`, `npm ci`, node_modules deletion, or dependency repair was run in Phase 1.

## I. Commands Run And Exact Results

### Inventory

- `git status --short`: showed 11 modified tracked files and 131 untracked files initially.
- `git diff --stat`: showed 11 files changed, 2004 insertions, 606 deletions.
- `git diff --name-status`: showed 11 modified tracked files.
- `git ls-files --others --exclude-standard`: showed 131 untracked files initially.
- `git log --oneline -15`: HEAD at `94f6eb69`.
- `git rev-parse HEAD`: `94f6eb69ca1d22c475997f52d4d7729d52dfd0b7`.
- `git branch --show-current`: `main`.

### Config Restore

- `git restore --source=94f6eb69ca1d22c475997f52d4d7729d52dfd0b7 -- package.json package-lock.json tsconfig.json next-env.d.ts`: succeeded.
- `git diff -- package.json package-lock.json tsconfig.json next-env.d.ts`: no content diff after restore.

### Validation

- `git diff --check`: passed with line-ending warnings only.
- `npm test`: failed. Script exists and ran `vitest run`; first meaningful failures include zero-test polluted suites and checkout draft UI failures showing order-creation contamination.
- `npm run lint`: failed. First meaningful failures are in `.local-recovery/quarantine` scratch files because ESLint scans the local quarantine directory, followed by unapproved source lint/syntax failures.
- `npm run build`: failed. First meaningful error: malformed JSX in `components/admin/admin-core-screens.tsx`; additional errors include delivery/admin/supplier JSX, server/client boundary violations, and missing module aliases.
- `npm run typecheck`: failed. First meaningful error: invalid syntax in `app/customer/orders/[orderId]/confirm/account.action.ts`.
- `npx tsc --noEmit`: failed with the same syntax error set as `npm run typecheck`.

## J. Remaining Build, Type, Lint, And Test Failures

Primary remaining categories:

- Malformed JSX in admin, supplier, delivery, and confirmation components.
- Invalid TypeScript syntax in `app/customer/orders/[orderId]/confirm/account.action.ts`.
- Unapproved checkout draft UI still contains `Confirm & Place Order`.
- Unapproved checkout draft code still references `create_order`.
- Server/client boundary violations involving `next/headers` and `server-only`.
- Missing module aliases such as `@/actions/orderActions` and `@/lib/utils/format-ghc`.
- Unapproved order/delivery/payment/settlement routes remain in the tree.
- ESLint scans `.local-recovery/quarantine` despite Git ignoring it; Phase 2 should move `.local-recovery` outside the repo or add an explicit lint ignore only if approved.
- `node_modules` remains inconsistent with the restored package files.

## K. Unapproved Checkout, Order, Payment, Delivery File Inventory

Untracked or modified scope files identified: 36 untracked scope files plus 3 modified tracked scope files.

Untracked scope files include:

- `app/admin/orders/confirmation-queue/page.tsx`
- `app/api/admin/orders/[orderId]/assign-dispatch/route.ts`
- `app/api/admin/orders/[orderId]/force-transition/route.ts`
- `app/api/admin/orders/stalled/route.ts`
- `app/api/customer/orders/[orderId]/confirm/account/route.ts`
- `app/api/delivery/orders/[orderId]/confirm-payment/route.ts`
- `app/api/orders/[orderId]/initiate-settlement/route.ts`
- `app/api/supplier/orders/[orderId]/prepare/route.ts`
- `app/api/supplier/orders/[orderId]/ready/route.ts`
- `app/checkout/draft/[draftId]/actions.ts`
- `app/checkout/draft/[draftId]/page.tsx`
- `app/confirmation-failed/page.tsx`
- `app/confirmation/page.tsx`
- `app/customer/orders/[orderId]/confirm/account.action.ts`
- `app/delivery/orders/[id]/page.tsx`
- `app/delivery/orders/page.tsx`
- `components/admin/confirmation-queue-table.tsx`
- `components/customer/checkout-draft-screens.tsx`
- `components/delivery/DeliveryOrderDetailScreen.tsx`
- `components/delivery/DeliveryOrderList.tsx`
- `components/delivery/DeliveryShell.tsx`
- `docs/RISELLAR_CHECKOUT_PHASE_B_DRAFT_UI_INTEGRATION_REPORT.md`
- `docs/RISELLAR_CHECKOUT_SCOPE_AUDIT.md`
- `lib/actions/confirmation-actions.ts`
- `lib/actions/supplier-actions.ts`
- `lib/checkout/draft.ts`
- `lib/checkout/server.ts`
- `lib/mock/delivery-core.ts`
- `lib/notifications/confirmation-failed.ts`
- `supabase/functions/expire-unconfirmed-orders/index.ts`
- `supabase/migrations/20260718210000_create_order_from_draft_rpc.sql`
- `supabase/migrations/20260724000000_add_confirmation_fields.sql`
- `supabase/migrations/20260724010000_prepare_supplier_for_order_rpc.sql`
- `supabase/migrations/20260725020000_add_delivery_and_prepare_timestamps.sql`
- `supabase/migrations/20260725030000_update_prepare_supplier_for_order_rpc.sql`
- `tests/checkout-draft-ui.test.tsx`

Modified tracked scope files:

- `app/supplier/orders/[id]/page.tsx`
- `app/supplier/orders/page.tsx`
- `components/supplier/screens.tsx`

## L. Files Recommended For Phase 2 Deletion

Delete in Phase 2, after explicit approval:

- `app/actions/`
- `app/admin/operations/exceptions/`
- `app/admin/orders/confirmation-queue/`
- `app/api/`
- `app/confirmation-failed/`
- `app/confirmation/`
- `app/customer/orders/[orderId]/`
- `app/delivery/`
- `components/admin/confirmation-queue-table.tsx`
- `components/delivery/`
- `lib/actions/`
- `lib/mock/delivery-core.ts`
- `lib/notifications/`
- `lib/supabase/hooks/`
- `supabase/functions/`
- unapproved migrations from `20260718210000` through `20260725030000`

## M. Files Recommended For Later Salvage Review

Review for salvage only after Phase 2 cleanup:

- `middleware.ts`: likely salvage `/checkout/draft(.*)` protection only.
- `app/shop/[shopSlug]/product/[productId]/page.tsx`: salvage draft-start CTA only if no order side effects.
- `components/customer/public-shop-rpc-screens.tsx`: salvage draft-start UI only if safe.
- `app/shop/[shopSlug]/product/actions.ts`: salvage create-draft action only.
- `app/checkout/draft/[draftId]/page.tsx`: salvage draft review screen only.
- `app/checkout/draft/[draftId]/actions.ts`: salvage update/abandon/address actions only.
- `components/customer/checkout-draft-screens.tsx`: salvage review-only UI only.
- `lib/checkout/draft.ts`: salvage draft RPC wrappers only; remove order creation.
- `lib/checkout/server.ts`: salvage only if token-safe.
- `tests/checkout-draft-ui.test.tsx`: salvage tests that enforce draft-only behavior.

## N. Security Scan Result

Ignore/staging checks:

- `.env.local`: ignored and not staged.
- `supabase/.temp`: ignored and not staged.
- `.next`: ignored and not staged.
- `.local-recovery`: ignored and not staged.
- `.codex-dev-server.*.log`: ignored and not staged.
- `session.jwt`, `session.cookie`, `debug.log`, `dev.err`, and `dev.out`: ignored and quarantined.

Staging:

- `git diff --cached --name-only`: no staged files.
- No secrets, session cookies, JWT files, or production data are staged.

Service role:

- No service-role usage was found in `app/` or `components/`.
- Existing safe server-only `lib/supabase/admin.ts` still references `SUPABASE_SERVICE_ROLE_KEY`.
- Unapproved `supabase/functions/_shared/supabase-client.ts` references `SUPABASE_SERVICE_ROLE_KEY` and should be deleted in Phase 2.

Path-only pattern scan:

- Most `Bearer`, `CLERK_SECRET_KEY`, and `SUPABASE_SERVICE_ROLE_KEY` hits are documentation or tests that mention key names or "no bearer tokens" text.
- `app/api/confirm/route.ts` contains a fallback-secret pattern and is unapproved; delete in Phase 2.
- Quarantined session/cookie/JWT artifacts justify rotating development test sessions/credentials.

## O. Files Changed During Phase 1

Tracked files intentionally changed:

- `.gitignore`
- `package.json`
- `package-lock.json`
- `tsconfig.json`
- `next-env.d.ts`
- `docs/RISELLAR_RECOVERY_PHASE_1_CONTAINMENT_REPORT.md`

Ignored local recovery files created:

- `.local-recovery/claude-working-tree-inventory.txt`
- `.local-recovery/config-before-restore.diff`
- `.local-recovery/quarantine/quarantine-manifest.txt`
- quarantined local artifact copies under `.local-recovery/quarantine/`

Note: the four restored config files show no content diff after restore, although `git status` still lists them modified.

## P. Current Git Status

Current status after Phase 1:

- Modified tracked files: 12 according to `git status --short`:
  - `.gitignore`
  - `app/shop/[shopSlug]/product/[productId]/page.tsx`
  - `app/supplier/orders/[id]/page.tsx`
  - `app/supplier/orders/page.tsx`
  - `components/admin/admin-core-screens.tsx`
  - `components/customer/public-shop-rpc-screens.tsx`
  - `components/supplier/screens.tsx`
  - `middleware.ts`
  - `next-env.d.ts`
  - `package-lock.json`
  - `package.json`
  - `tsconfig.json`
- Deleted tracked files: 0
- Untracked files: 55
- Staged files: 0

Important: the restored package/config files have no content diff despite appearing in `git status`.

## Q. Safe To Proceed To Recovery Phase 2

Yes, with constraints.

Phase 1 succeeded at containment and package/config restoration. The repository is not buildable yet because Phase 2 must remove unapproved scope files and restore unsafe tracked source files from the baseline.

Do not commit yet.

## R. Recommended Recovery Phase 2 Objective

Recommended Phase 2 objective:

Restore the source tree architecture from the verified baseline by removing unapproved order/delivery/payment/settlement/confirmation files and restoring unsafe tracked source files, while preserving only the audit reports and any explicitly approved draft-only salvage candidates for later review.

Phase 2 should:

1. Move `.local-recovery` outside the repo or ensure validation tools ignore it.
2. Restore tracked unsafe source files:
   - `app/supplier/orders/page.tsx`
   - `app/supplier/orders/[id]/page.tsx`
   - `components/admin/admin-core-screens.tsx`
   - `components/supplier/screens.tsx`
3. Delete unapproved untracked order/delivery/payment/settlement/confirmation files.
4. Leave checkout draft salvage candidates uncommitted for a separate review.
5. Run full verification after cleanup.
