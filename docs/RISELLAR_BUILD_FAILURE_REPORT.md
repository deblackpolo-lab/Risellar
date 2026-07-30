# Risellar Build Failure Report

Date: 2026-07-29

Safe baseline: `94f6eb69ca1d22c475997f52d4d7729d52dfd0b7`

## Commands Run

| Command | Result |
| --- | --- |
| `git diff --check` | Failed: trailing whitespace in `package.json` line 25. |
| `npm test` | Failed: missing script `test`. |
| `npm run lint` | Failed: missing script `lint`. |
| `npm run build` | Failed: missing script `build`. |
| `npm run typecheck` | Failed: missing script `typecheck`. |
| `npm run` | Shows only `dev` and `dev:fast`. |
| `npx tsc --noEmit` | Failed with syntax/JSX parse errors. |
| `npx next build` | Failed with Turbopack parse, import, and server/client errors. |

`npm install` was not run because the working tree is forensic evidence and `npm install` can mutate `package-lock.json` and installed dependency state. The package system is already contaminated and should be restored before install commands are used.

## Package-Level Failure

`package.json` removed the verified scripts:

- `test`
- `lint`
- `build`
- `typecheck`
- `dev:400`

It also changed `dev` from the verified port-400 command to `next dev --turbo`.

Dependency changes include:

- `next` changed from `^15.1.3` to `16.2.12`
- `react` changed from `^19.0.0` to `19.2.8`
- `react-dom` changed from `^19.0.0` to `19.2.8`
- added `dotenv`
- added `node-fetch`
- added `pg`
- added `@clerk/clerk-sdk-node`
- added `cross-env`

This explains missing scripts, changed dev behavior, new Next middleware warnings, and potential runtime chunk errors.

## TypeScript Failures

`npx tsc --noEmit` failed before semantic type checking could complete:

- `app/customer/orders/[orderId]/confirm/account.action.ts`: invalid `export async def` syntax.
- `components/admin/admin-core-screens.tsx`: malformed JSX, mismatched tags.
- `components/admin/confirmation-queue-table.tsx`: malformed JSX.
- `components/delivery/DeliveryOrderDetailScreen.tsx`: malformed JSX.
- `components/supplier/screens.tsx`: malformed JSX and corrupted class strings.
- `lib/supabase/hooks/useOrderRealtime.ts`: malformed syntax near line 160.

Failure class: Syntax and JSX.

## Next Build Failures

`npx next build` failed with 18 Turbopack errors.

Categories:

- Syntax: malformed JSX in admin, supplier, delivery, and confirmation components.
- Server/client: `next/headers` imported from client component ancestry.
- Server-only: `lib/supabase/server.ts` pulled into client/browser traces.
- Import: missing `@/actions/orderActions` because the file was created under `app/actions/`, while the alias resolves to root `actions/`.
- Import: missing `@/lib/utils/format-ghc`.
- Export: `DeliveryOrderList` imported as default while module does not provide default export.
- Framework drift: Next 16 reports `middleware` convention deprecation.

## Build Root Cause

The root cause is not one isolated typo. It is a broad uncontrolled rewrite that:

1. Removed the project’s verification scripts.
2. Changed core runtime dependencies.
3. Added invalid TypeScript/JSX.
4. Mixed server-only APIs into client components.
5. Added unapproved routes with broken imports.
6. Expanded checkout into order/delivery/payment/settlement territory before approved architecture existed.

## Recovery Recommendation

Restore package and config files from the safe baseline first. Then delete unapproved/untracked order/delivery/payment/settlement files. Only after the tree builds again should any Checkout Phase B draft UI code be reintroduced.
