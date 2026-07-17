# Risellar Supabase Schema RLS Foundation Report

## A. Schema Created Or Planned

Created a first Supabase migration foundation in `supabase/migrations/20260717000000_risellar_schema_rls_foundation.sql`.

The repo did not previously contain a `supabase/` directory, Supabase config, or migration history, so this branch adds a minimal local Supabase folder structure:

- `supabase/config.toml`
- `supabase/migrations/20260717000000_risellar_schema_rls_foundation.sql`

This is a database/schema foundation only. It does not add Clerk integration, Resend integration, payment integration, storage upload code, `.env`, `.env.local`, service role usage, or production connection details.

## B. Tables

Created/planned MVP foundation tables:

- `profiles`
- `admin_staff`
- `customers`
- `resellers`
- `reseller_shops`
- `suppliers`
- `supplier_team_members`
- `products`
- `product_variants`
- `product_images`
- `inventory_movements`
- `reseller_products`
- `orders`
- `order_items`
- `stock_reservations`
- `delivery_quotes`
- `settlements`
- `commissions`
- `withdrawals`
- `disputes`
- `returns`
- `notifications`
- `audit_logs`
- `admin_actions`

The migration also creates enum types for roles, account/status flows, stock movement types, order/payment/delivery states, settlement states, commission states, dispute/return states, notification states, and admin action states.

## C. Relationships

Core relationships:

- `profiles` owns one `customers` row and/or one `resellers` row.
- `profiles` can own `suppliers` through `suppliers.owner_profile_id`.
- `supplier_team_members` links supplier workspaces to staff profiles.
- `suppliers` own `products`; products own `product_variants` and `product_images`.
- `inventory_movements` links supplier, product, variant, optional order, and actor profile.
- `resellers` own `reseller_shops` and `reseller_products`.
- `orders` link customer, reseller, and reseller shop.
- `order_items` link order, supplier, product, variant, reseller product, and immutable price snapshots.
- `stock_reservations` link customer, reseller, reseller product, product, variant, and optional order.
- `delivery_quotes` link to orders.
- `settlements` link supplier and order.
- `commissions` link reseller, order, order item, settlement, and optional withdrawal.
- `withdrawals` link to reseller and finance/admin actor profiles.
- `disputes` and `returns` link to orders and actors.
- `audit_logs` and `admin_actions` preserve admin/manual override traceability.

## D. RLS Strategy

RLS is enabled and forced on all application tables in the migration.

The policy stance is intentionally conservative:

- Customers can access only their customer/order/dispute/return/notification records.
- Resellers can access their reseller/shop/listing/order/commission/withdrawal records.
- Supplier owners and supplier team members can access supplier-scoped product, variant, image, inventory, order, and settlement context according to membership.
- Inventory managers rely on `supplier_team_members.permissions` checks for product/stock work and cannot manage payout/settlement/staff/admin data.
- Finance/admin access is separated through `admin_staff`.
- Audit log reads are admin-only.
- Audit log inserts require the actor to be the current profile or an admin.
- Sensitive base tables that contain private price layers are not opened directly to public/customer catalog reads. Future safe views/RPCs should expose role-appropriate columns.

## E. Policies Added Or Planned

Added policies for:

- Own/admin profile reads and non-admin self profile insertion.
- Admin staff read/write separation, with super admin required for admin staff writes.
- Customer, reseller, supplier, and supplier team isolation.
- Supplier product and stock access through supplier membership and permission helpers.
- Reseller shop/product ownership isolation.
- Order and order item participant/admin reads.
- Admin-only direct stock reservation insert until secure checkout/reservation RPCs exist.
- Delivery quote participant/supplier/admin access.
- Settlement access for supplier owner, finance staff, and admin.
- Commission/withdrawal access for reseller, finance staff, and admin.
- Dispute/return participant and support/admin access.
- Notification recipient access.
- Audit log admin reads and actor/admin inserts.
- Admin action admin/support access.

Planned later:

- Safe public/customer catalog views that hide supplier base price, platform margin, and reseller margin.
- Safe reseller catalog views that show reseller cost/profit without supplier private contact or KYC/payout data.
- Secure RPC policies/functions for checkout, stock reservation, settlement verification, commission release, withdrawal requests, and admin overrides.
- Column-safe order views for suppliers so reseller margin strategy and customer private data are not overexposed.

## F. Storage Bucket Plan

No storage buckets or storage policies were created in this branch because the repo had no Supabase setup and the task prohibits storage integration work.

Planned buckets:

- `product-images`: public reads only for approved/active product images; supplier/admin writes.
- `supplier-kyc`: private; supplier owner can upload/read own submission through signed URL flow; admin/super admin review access.
- `settlement-proofs`: private; supplier owner upload/read own proofs; finance/admin review access.
- `dispute-evidence`: private; participants plus assigned support/admin access.
- `avatars`: public only for approved display assets.

Storage policy requirement: all private reads should be ownership-checked through table records and signed URLs. Do not expose public URLs for KYC, payout, settlement proof, or dispute evidence.

## G. Security Risks

- Clerk-to-Supabase identity mapping still needs a production-approved JWT/session design. The migration only prepares `profiles.clerk_user_id` and helper functions.
- RLS cannot hide columns. Tables containing sensitive price layers must not be exposed directly to customer/reseller clients; safe views/RPCs are required.
- Direct order creation and stock reservation must move to secure RPCs using row locks before launch.
- `profiles_update_own_basic_or_admin` is broad at table level; production should split sensitive role/status updates into admin-only RPCs or column-limited API handlers.
- Financial transitions need secure functions to prevent frontend-sent settlement, commission, and withdrawal amounts.
- Audit logging is structurally present but must be called from every sensitive server/RPC path.
- Storage bucket policies are not implemented yet.

## H. Migration Order

Recommended order:

1. Foundation schema/types/tables/indexes/RLS helper functions/policies: current migration.
2. Safe catalog/order/finance views for each role.
3. Secure RPCs for profile bootstrap, checkout, stock reservation, stock release, delivery quote approval, settlement proof submission, settlement verification, commission release, withdrawal request, and admin overrides.
4. Storage bucket creation and storage RLS policies.
5. Seed/config migration for launch categories, margin defaults, withdrawal minimums, settlement windows, and admin bootstrap SOP.
6. Security tests for RLS role boundaries and stock race conditions.

## I. Backend Functions/RPCs Needed Later

Needed before real app wiring:

- `create_or_get_profile_from_clerk`
- `create_checkout_order`
- `reserve_stock`
- `release_expired_reservations`
- `commit_stock_reservation`
- `calculate_listing_price`
- `mark_customer_confirmed`
- `submit_delivery_quote`
- `approve_delivery_quote`
- `submit_settlement_proof`
- `verify_supplier_settlement`
- `release_commission_after_settlement`
- `request_withdrawal`
- `apply_restriction`
- `write_audit_log`
- `perform_admin_action_with_reason`

## J. Files Changed

- `supabase/config.toml`
- `supabase/migrations/20260717000000_risellar_schema_rls_foundation.sql`
- `docs/RISELLAR_SUPABASE_SCHEMA_RLS_FOUNDATION_REPORT.md`

## K. Commands Run / Results

Initial inspection:

- `git status --short --branch`: showed `main` with existing unrelated frontend/doc changes before branch switch.
- `rg --files`: confirmed no existing `supabase/` structure.
- `rg -n "supabase|create table|row level security|policy|storage\\.buckets" -S .`: found documentation-only Supabase references, no migrations.
- `Get-Command supabase -ErrorAction SilentlyContinue`: Supabase CLI not found on PATH, so no Supabase CLI checks were run.
- `Get-Command psql -ErrorAction SilentlyContinue`: `psql` not found on PATH, so the migration was not executed against a local Postgres instance in this workspace.
- `Get-Command docker -ErrorAction SilentlyContinue`: Docker not found on PATH, so no disposable local Postgres container check was available.
- `rg -n "create table public\\.|enable row level security|force row level security|create policy" supabase\\migrations\\20260717000000_risellar_schema_rls_foundation.sql`: confirmed 24 application tables, forced RLS statements, and policy definitions are present.
- `rg -n "\\.env|service_role|SUPABASE_|CLERK_|RESEND_|PAYSTACK_|HUBTEL_|password\\s*=|secret\\s*=|bearer\\s+" supabase docs\\RISELLAR_SUPABASE_SCHEMA_RLS_FOUNDATION_REPORT.md`: found only explanatory documentation/comment text, no real secrets or environment files.
- Read required docs:
  - `docs/RISELLAR_DATABASE_SCHEMA_AND_SECURITY_PLAN.md`
  - `docs/RISELLAR_BUSINESS_RULES_AND_APP_LOGIC.md`
  - `docs/RISELLAR_FULL_PRD.md`
  - `docs/RISELLAR_FRONTEND_BACKEND_HANDOFF_CHECKLIST.md`
  - `docs/RISELLAR_FRONTEND_PRD_COVERAGE_MATRIX.md`

Verification commands:

- `npm test`: passed, 18 test files and 81 tests. Note: this workspace also contained unrelated untracked tests from another agent, and Vitest included them in the run.
- `npm run typecheck`: passed.
- `npm run lint`: passed.
- `npm run build`: passed; Next.js built 160 app routes.

## L. Current Git Status

Current working branch at report update: `backend/supabase-schema-rls-foundation`.

Expected new files from this agent:

- `supabase/config.toml`
- `supabase/migrations/20260717000000_risellar_schema_rls_foundation.sql`
- `docs/RISELLAR_SUPABASE_SCHEMA_RLS_FOUNDATION_REPORT.md`

Pre-existing unrelated changes were present before this work and should remain untouched. During the session, the shared workspace also briefly switched to `backend/settlement-commission-logic` and showed unrelated untracked backend files; this branch's commit should stage only the three files listed above.
