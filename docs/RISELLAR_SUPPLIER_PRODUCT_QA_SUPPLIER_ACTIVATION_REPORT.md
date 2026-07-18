# Risellar Supplier Product QA Supplier Activation Report

Date: 2026-07-18

## A. Why Product Create Was Blocked

Browser-level supplier product create initially returned `SUPPLIER_REQUIRED`.

The signed-in development supplier test account had:

- `profiles.primary_role = supplier_owner`
- `profiles.account_status = active`
- `suppliers.supplier_status = pending`
- `suppliers.verification_status = pending_review`

## B. Backend Protection Was Correct

The product RPC helper `current_verified_supplier_owner_id()` correctly requires:

- active authenticated profile
- `primary_role = supplier_owner`
- active supplier row
- approved supplier verification

The initial `SUPPLIER_REQUIRED` response was therefore expected and correct. Product RPC rules were not changed or weakened.

## C. Supplier Activation Bootstrap Performed

Development-only bootstrap was performed for the confirmed supplier test account only.

Masked supplier account:

- masked email: `bl***`
- profile id: `e4daceac-478b-4ce5-8b5b-e85799e04532`
- supplier id: `dcc8fe73-0945-4e8b-9367-74b9c2a40ce1`

SQL scope:

- updated only the matching `public.suppliers.id`
- updated only `supplier_status`, `verification_status`, and `updated_at`
- did not update `profiles.primary_role`
- did not update unrelated suppliers
- did not delete data
- did not run destructive reset commands

## D. Supplier Row Before / After

Before:

- `profiles.primary_role = supplier_owner`
- `profiles.account_status = active`
- `suppliers.supplier_status = pending`
- `suppliers.verification_status = pending_review`

After:

- `profiles.primary_role = supplier_owner`
- `profiles.account_status = active`
- `suppliers.supplier_status = active`
- `suppliers.verification_status = approved`

## E. Product Create Result

Created fake development-only product through `/supplier/products/new`:

- product name: `Risellar QA Product Visible State`
- category: `QA Test`
- description: development-only QA text
- base price: `99.99`
- stock quantity: `2`

UI result:

- success message shown: `Product saved for admin review.`

Supabase result:

- product id: `f440b335-4ddc-4b64-9c52-a1c2b198951a`
- product belonged to supplier `dcc8fe73-0945-4e8b-9367-74b9c2a40ce1`
- created by profile `e4daceac-478b-4ce5-8b5b-e85799e04532`
- `product_status = pending_approval`
- `approval_status = pending_review`
- platform margin remained `0.00`
- reseller margin remained `0.00`

## F. Product List / Detail / Edit / Archive Result

- `/supplier/products` displayed the created product.
- `/supplier/products/[id]` detail page loaded and showed pending statuses.
- `/supplier/products/[id]/edit` allowed only safe fields.
- Edit succeeded and UI showed `Product changes saved for review.`
- Product status became `price_change_pending`; approval remained `pending_review`.
- Archive succeeded and UI showed `Product archived.`
- Product and default variant were soft-archived with `deleted_at` set.
- No hard delete occurred.
- Archived product no longer appeared in the active supplier list.

## G. Supabase Row Verification

Product row after archive:

- `product_status = archived`
- `approval_status = archived`
- `deleted_at` set
- supplier id unchanged
- platform/reseller margin fields remained `0.00`

Default variant after archive:

- `variant_status = archived`
- `deleted_at` set

## H. Audit Log Verification

Audit rows exist for:

- `create_supplier_product`
- `update_supplier_product`
- `archive_supplier_product`

## I. Security / Scope Checks

- No product RPC rules were changed.
- No RLS/RPC/storage policies were weakened.
- No service role was used in supplier product UI code.
- No client approval/status/platform margin/reseller pricing fields were exposed.
- No UI self-approval path was created.
- No checkout integration was started.
- No orders integration was started.
- No reseller catalog integration was started.
- No customer catalog integration was started.
- No stock reservation integration was started.
- No settlement, commission, payment, delivery, or reseller shop integration was started.

## J. Commands Run / Results

- `git status --short` - dirty working tree with supplier product integration/report files.
- `npx supabase status` - local Docker status unavailable; linked DB queries continued to work against the confirmed development project.
- linked read-only supplier row query - confirmed before-state.
- linked update query - updated one intended supplier row.
- linked after-state query - confirmed supplier active/approved and profile role unchanged.
- browser QA on `http://localhost:401` - create/list/detail/edit/archive verified.
- linked product row queries - verified product create/update/archive state.
- linked audit log queries - verified create/update/archive audit rows.

## K. Secret Scan Result

Passed.

- `.env.local` is ignored by Git and not staged.
- `supabase/.temp/` is ignored.
- Changed files scanned: 10.
- Secret findings in changed files: 0.
- No real Clerk/Supabase/service-role values, bearer tokens, passwords, API secrets, or production data were found in changed docs/source.
- No service-role usage was found in `app` or `components`.
- No secrets were printed in this report.

## L. Current Git Status

Dirty working tree with supplier product integration files and reports uncommitted.

## M. Whether Safe To Commit Supplier Product UI Integration

Safe to commit after the final requested checks passed.
