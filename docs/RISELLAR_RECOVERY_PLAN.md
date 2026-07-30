# Risellar Recovery Plan

Date: 2026-07-29

Safe baseline: `94f6eb69ca1d22c475997f52d4d7729d52dfd0b7`

## Objective

Recover the repository to the last known healthy architecture without losing legitimate draft UI ideas. Do not commit the current dirty tree.

## Phase 1: Containment

1. Stop feature work.
2. Do not apply migrations.
3. Do not push current working tree.
4. Preserve this audit as the evidence set.
5. Rotate any Clerk/Supabase/session values that may have been copied into local debug/session artifacts.

## Phase 2: Restore Package System

Restore these tracked files from `94f6eb69ca1d22c475997f52d4d7729d52dfd0b7`:

- `package.json`
- `package-lock.json`
- `tsconfig.json`
- `next-env.d.ts`

Expected result:

- `npm test`
- `npm run lint`
- `npm run build`
- `npm run typecheck`
- `npm run dev` on port 400

are available again.

## Phase 3: Remove Unapproved Scope

Delete untracked files under:

- `app/api/`
- `app/actions/`
- `app/admin/orders/confirmation-queue/`
- `app/admin/operations/exceptions/`
- `app/customer/orders/[orderId]/`
- `app/delivery/`
- `components/delivery/`
- `components/admin/confirmation-queue-table.tsx`
- `lib/actions/`
- `lib/notifications/`
- `lib/supabase/hooks/`
- `supabase/functions/`

Delete unapproved migrations:

- `20260718210000_create_order_from_draft_rpc.sql`
- `20260724000000_add_confirmation_fields.sql`
- `20260724010000_prepare_supplier_for_order_rpc.sql`
- `20260725000000_add_order_expires_index.sql`
- `20260725020000_add_delivery_and_prepare_timestamps.sql`
- `20260725030000_update_prepare_supplier_for_order_rpc.sql`

## Phase 4: Restore Authentication and Routing

Restore these tracked files from the baseline:

- `components/admin/admin-core-screens.tsx`
- `components/supplier/screens.tsx`
- `app/supplier/orders/page.tsx`
- `app/supplier/orders/[id]/page.tsx`

Then reapply only safe routing:

- `/checkout/draft(.*)` may be added to Clerk-protected routes if draft UI is reintroduced.

## Phase 5: Remove Secret and Debug Artifacts

Delete and ignore local-only artifacts:

- `session.cookie`
- `session.jwt`
- `debug.log`
- `debug_curl*.sh`
- `dev.err`
- `dev.out`
- Clerk/session/test scripts
- temporary shell/python/js/text scratch files

Add ignore rules only after verifying the exact paths are local artifacts.

## Phase 6: Reintroduce Safe Checkout Draft UI

From the contaminated files, salvage only:

- draft review page layout
- create-draft action using approved draft RPC
- draft abandon/update/address behavior
- draft-only tests

Do not salvage:

- `create_order_from_draft`
- "Confirm & Place Order"
- stock reservation
- order item creation
- payment/delivery/settlement code

## Phase 7: Regression Testing

Run:

- `git diff --check`
- `npm test`
- `npm run lint`
- `npm run build`
- `npm run typecheck`
- targeted secret/scope scan

Then run browser QA for:

- public shop read-only
- reseller catalog
- customer address/contact
- protected route access
- checkout draft page only, if reintroduced

## Phase 8: Resume Development

Only after the tree is clean and verified:

1. Commit recovery cleanup.
2. Start a new scoped Checkout Phase B Group 3 draft UI task.
3. Keep order creation in a separate future phase with its own migration, RPC tests, and manual QA.

## Success Criteria

Recovery is complete when:

- package scripts are restored
- build/lint/typecheck/tests pass
- unapproved migrations are gone
- debug/session artifacts are gone
- auth follows Clerk native token + Supabase user-context pattern
- admin access uses `admin_staff`
- checkout remains draft-only
- no order/payment/delivery/settlement flow is connected
