# Risellar Supabase Schema/RLS Hardening Report

Date: 2026-07-17

Branch: `backend/supabase-schema-rls-hardening`

## A. Summary of fixes

This branch hardens the Supabase schema/RLS foundation after QA marked `backend/supabase-schema-rls-foundation` not safe to merge.

Fixes applied:

- Removed broad `FOR ALL` RLS policies.
- Removed implicit client DELETE policy coverage.
- Replaced risky owner/self row updates with conservative admin-only or RPC-deferred policies.
- Normalized inventory-manager role names to `supplier_inventory_manager`.
- Added comments documenting required future audited RPC/server-action paths for sensitive mutations.
- Fixed `supabase/config.toml` formatting so `git diff --check` passes.

## B. Broad FOR ALL policies removed

Removed every `FOR ALL` policy from the migration.

Replaced with explicit `FOR INSERT` and `FOR UPDATE` policies where direct table mutation is still part of the foundation:

- `admin_staff_insert_super_admins`
- `admin_staff_update_super_admins`
- `reseller_shops_insert_owner_or_admin`
- `reseller_shops_update_admin_only_until_shop_rpc`
- `supplier_team_insert_owner_or_admin`
- `supplier_team_update_owner_or_admin`
- `products_insert_supplier_product_permission_or_admin`
- `products_update_admin_only_until_product_rpc`
- `product_variants_insert_supplier_product_permission_or_admin`
- `product_variants_update_admin_only_until_stock_rpc`
- `product_images_insert_supplier_or_admin`
- `product_images_update_admin_only_until_media_rpc`
- `reseller_products_insert_owner_or_admin`
- `reseller_products_update_admin_only_until_listing_rpc`
- `delivery_quotes_insert_admin_or_supplier_member`
- `delivery_quotes_update_support_admin_until_quote_rpc`
- `settlements_insert_finance_admin`
- `settlements_update_finance_admin`
- `commissions_insert_finance_admin`
- `commissions_update_finance_admin`
- `admin_actions_insert_admins`
- `admin_actions_update_admins`

No client `FOR DELETE` policies were added.

## C. Sensitive update protections added

The following broad update policies were narrowed:

- `profiles_update_own_basic_or_admin` became `profiles_update_admin_only_until_profile_rpc`.
- `customers_update_own_or_admin` became `customers_update_support_admin_until_profile_rpc`.
- `resellers_update_own_limited_or_admin` became `resellers_update_admin_only_until_reseller_rpc`.
- `reseller_shops_update_owner_or_admin` became `reseller_shops_update_admin_only_until_shop_rpc`.
- `suppliers_update_owner_or_admin` became `suppliers_update_admin_only_until_supplier_rpc`.
- `products_update_admin_only_until_product_rpc` now blocks direct supplier product updates until a column-safe product RPC exists.
- `product_variants_update_admin_only_until_stock_rpc` now blocks direct stock/status updates until a stock RPC exists.
- `product_images_update_admin_only_until_media_rpc` now blocks direct media status changes until a media RPC exists.
- `reseller_products_update_admin_only_until_listing_rpc` now blocks direct reseller listing margin/status updates until a validated listing RPC exists.
- `orders_update_support_admin_until_order_rpc` now blocks participant direct order/payment/delivery status changes.

Rationale: PostgreSQL RLS is row-level, not column-level. Direct owner updates on these tables could otherwise mutate sensitive status, risk, approval, settlement, commission, payout, price, or ownership columns. This branch therefore blocks those direct table updates and documents future RPC/server-action boundaries.

## D. Role naming corrections

Updated SQL role values to align with current `main` role naming:

- `public.user_role`: `inventory_manager` changed to `supplier_inventory_manager`.
- `public.supplier_role`: `inventory_manager` changed to `supplier_inventory_manager`.
- `supplier_team_members.supplier_role` default changed to `supplier_inventory_manager`.

The migration no longer uses the bare `inventory_manager` role name.

## E. Admin/support/finance mutation restrictions

Admin/support/finance mutation policies remain intentionally narrow:

- Admin staff writes require `super_admin`.
- Profile/reseller/supplier/product/listing/status-style direct updates are admin-only or support/admin-only until safe RPCs exist.
- Settlement and commission writes remain finance/admin-only as foundation scaffolding, with comments requiring audited RPCs before production use.
- Order and delivery quote transitions are support/admin-only or insert-only where supplier operational participation is needed.

The migration does not claim audit logging is fully enforced for privileged transitions.

## F. Supplier inventory manager restrictions

Supplier inventory managers continue to be supplier-scoped through `supplier_team_members`.

They can participate only through supplier membership and permission helper checks for supplier operational areas. They are not given direct policies to mutate:

- supplier payout data
- settlements
- verification status
- supplier owner profile data
- staff permissions unless they are also a supplier owner/admin
- finance/commission records
- admin queues

Direct stock/product updates are deferred to future RPCs so inventory-manager permissions can be enforced per action and audited.

## G. Audit-log enforcement notes

The migration includes `audit_logs`, but it does not enforce audit rows for every privileged mutation.

This hardening branch avoids exposing broad direct update/delete policies that would bypass future audit requirements. Comments were added to document required future audited RPC/server-action paths for:

- profile/contact edits
- customer/reseller/supplier status and risk changes
- shop/listing edits
- product/media/stock updates
- order/payment/delivery transitions
- settlement verification
- commission release

## H. Customer/reseller/supplier isolation notes

Isolation remains strict at the row level:

- Customers can read only their profile/customer/order/support-related records.
- Resellers can read only their reseller/shop/listing/order/commission/withdrawal records.
- Supplier owners/team members can read supplier-scoped product, variant, image, inventory, order, and settlement context according to membership.
- Finance/admin/support access remains role-scoped through `admin_staff`.

Sensitive client writes now require future column-safe RPCs instead of broad direct table updates.

## I. SQL/local Supabase validation result

SQL/RLS was statically validated only; local Postgres/Supabase execution still required.

Local SQL execution was not run because the following tools were not available on PATH:

- `supabase`
- `psql`
- `docker`

No production Supabase connection was used.

## J. git diff --check result

`git diff --check`: passed.

## K. npm test/typecheck/lint/build results

Results after hardening:

- `npm test`: passed.
- `npm run typecheck`: passed.
- `npm run lint`: passed.
- `npm run build`: passed.

## L. Secret/env scan result

Secret/env scan result: passed.

No `.env`, `.env.local`, API key, token value, password assignment, Clerk secret, Supabase service-role key, Resend key, Paystack/Hubtel secret, private key, or bearer token value was added.

Pattern hits, if any, were documentation/comment-only references to secrets or provider names.

## M. Files changed

- `docs/RISELLAR_SUPABASE_SCHEMA_RLS_HARDENING_REPORT.md`
- `supabase/config.toml`
- `supabase/migrations/20260717000000_risellar_schema_rls_foundation.sql`

## N. Remaining risks

- Local Supabase/Postgres migration execution is still required.
- Representative RLS boundary tests are still required for customer, reseller, supplier owner, supplier inventory manager, support, finance, admin, and anonymous contexts.
- Future audited RPC/server-action migrations are required before production client wiring for sensitive mutations.
- Safe public/customer catalog views are still needed before exposing product catalog reads outside supplier/admin contexts.
- Storage bucket policies are still not implemented.

## O. Whether branch is now safe to QA review

Safe for QA re-review: yes.

Safe to merge without local SQL/RLS execution: not yet. The RLS design is hardened statically, but QA should still require local migration execution and representative RLS boundary tests before merge.
