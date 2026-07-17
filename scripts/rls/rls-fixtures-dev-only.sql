-- DEVELOPMENT ONLY - DO NOT RUN AGAINST PRODUCTION.
-- Fake RLS boundary fixture scaffolding for the Risellar development Supabase project.
-- Do not use real users, real orders, real emails, real phone numbers, or real payout data.
-- Do not run unless explicitly approved.

begin;

-- This script is intentionally a scaffold.
-- Recommended flow:
-- 1. Review every insert.
-- 2. Run against the confirmed development project only.
-- 3. Use the returned IDs to complete dependent fixture rows.
-- 4. Then run rls-boundary-test-plan.sql.

-- Identity fixture subjects:
-- dev_clerk_customer_a
-- dev_clerk_customer_b
-- dev_clerk_reseller_a
-- dev_clerk_reseller_b
-- dev_clerk_supplier_owner_a
-- dev_clerk_supplier_owner_b
-- dev_clerk_supplier_a_inventory_manager
-- dev_clerk_support_operator
-- dev_clerk_finance_operator
-- dev_clerk_admin
-- dev_clerk_super_admin

-- Example profile fixture shape:
-- insert into public.profiles (clerk_user_id, email, full_name, primary_role)
-- values
--   ('dev_clerk_customer_a', 'customer-a@example.invalid', 'Dev Customer A', 'customer'),
--   ('dev_clerk_customer_b', 'customer-b@example.invalid', 'Dev Customer B', 'customer'),
--   ('dev_clerk_reseller_a', 'reseller-a@example.invalid', 'Dev Reseller A', 'reseller'),
--   ('dev_clerk_reseller_b', 'reseller-b@example.invalid', 'Dev Reseller B', 'reseller'),
--   ('dev_clerk_supplier_owner_a', 'supplier-owner-a@example.invalid', 'Dev Supplier Owner A', 'supplier_owner'),
--   ('dev_clerk_supplier_owner_b', 'supplier-owner-b@example.invalid', 'Dev Supplier Owner B', 'supplier_owner'),
--   ('dev_clerk_supplier_a_inventory_manager', 'supplier-a-inventory@example.invalid', 'Dev Supplier A Inventory Manager', 'supplier_inventory_manager'),
--   ('dev_clerk_support_operator', 'support@example.invalid', 'Dev Support Operator', 'customer'),
--   ('dev_clerk_finance_operator', 'finance@example.invalid', 'Dev Finance Operator', 'customer'),
--   ('dev_clerk_admin', 'admin@example.invalid', 'Dev Admin', 'customer'),
--   ('dev_clerk_super_admin', 'super-admin@example.invalid', 'Dev Super Admin', 'customer');

-- Important:
-- The profiles table has a check constraint preventing direct admin/support/finance
-- primary_role values. Admin/support/finance/super-admin fixtures should use allowed
-- profile rows plus admin_staff.admin_role rows.

-- Example admin_staff fixture shape after profile IDs are known:
-- insert into public.admin_staff (profile_id, admin_role, permissions, staff_status)
-- values
--   (<support_profile_id>, 'support_staff', '{}'::jsonb, 'active'),
--   (<finance_profile_id>, 'finance_staff', '{}'::jsonb, 'active'),
--   (<admin_profile_id>, 'admin', '{}'::jsonb, 'active'),
--   (<super_admin_profile_id>, 'super_admin', '{}'::jsonb, 'active');

-- Additional fixture groups to create in child-safe order:
-- customers, resellers, reseller_shops, suppliers, supplier_team_members
-- products, product_variants, product_images
-- reseller_products, orders, order_items, stock_reservations
-- delivery_quotes, settlements, commissions, withdrawals
-- disputes, returns, notifications, audit_logs, admin_actions

-- Use fake storage paths only, such as:
-- dev-only/products/supplier-a-product-a.jpg

rollback;

-- The rollback is intentional while this file remains scaffolding.
-- Replace rollback with commit only after explicit approval and final fixture review.
